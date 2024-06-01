# This code aims to convert the schemas specifications to Nim code and write it to a file
# The schemas are located in the 'assets/schemas' folder and have the YAML extension and format
# The generated Nim code is located in the 'src/RTR_nim_botApi2/Schemas.nim' file

# import 3rd party libraries
import std/[times, os] # for working with files
import strutils # for working with strings
import trick/common

type
  Property = object
    name: string
    kind: string
    description: string
    ref_object_of: string
    
  Event = ref object of RootObj
    id: string #serpent_case
    description: string
    ref_object_of: string
    properties: seq[Property]

# events repository
var events: seq[Event] = @[]

# statics
const schemas_folder = "../../../assets/schemas"
const schemas_file = "../../RTR_nim_botApi2/Schemas.nim"
const imports = @["jsony", "json"]

# strings sections
var imports_section = "import "
var enums_section = "type\n  Type* = enum\n"

# proc to remove the ".yaml" extension from a file
proc removeYAMLExtension(file: string): string = file[0..^6]

proc addImport(imp: string) = imports_section.add(imp&", ")

proc addEnum(e: string) =
  # replace "-" with "_"
  let event = e.replace("-", "_")

  # add the event to the enums section
  enums_section.add("    " & event.toCamelCase() & " = \""& event.toCamelCase(firstUpper = true) & "\"\n")

# proc to get all yaml files in the 'assets/schemas' folder and return a list
proc get_yaml_files(): seq[string] =
  result = @[] # initialize the result list

  for kind, path in walkDir(schemas_folder):
    if kind == pcFile and path.endsWith(".yaml"):
      result.add(path)


proc `$`(p: Property): string =
  result = "    "
  if p.name == "type":
    result.add("`" & p.name & "`*:")
  else: result.add(p.name & "*:")

  if p.kind == "array":
    result.add("seq[" & p.ref_object_of & "]")
  else: 
    if p.kind == "":
      result.add(p.ref_object_of)
    else: result.add(p.kind)

  if p.description != "":result.add(" # " & p.description & "\n")
  else: result.add("\n")

proc `$`(e: Event): string =
  let obj = e.id.toCamelCase(firstUpper = true)
  let `ref` = e.ref_object_of
  result = "  " & obj & "* = ref object of " & `ref` & "\n"
  if e.description != "":
    result.add("    " & e.description.strip() & "\n")

  if e.properties.len > 0:
    for p in e.properties:
      result.add($p)

proc yaml2nim(yaml_file: string) =
  # read the yaml file from disk
  try:
    let path: string = joinPath(getAppDir(), yaml_file)
    let content: string = readFile(path)

    # variables to gather
    var
      properties: seq[Property] = @[]
      current_event: Event = Event(ref_object_of: "RootObj")
      current_property: Property = Property()
      is_example: bool = false
      is_multiline: bool = false
    
    # for each line in the yaml file
    for line in content.splitLines():
      # get the key and value
      let values = line.split(":")

      # get the key and value
      if values.len == 2:
        let key = values[0]
        let value = values[1]

        # echo "VALUES: ", key, " - ", value

        case key:
        of "$id":
          current_event.id = value.strip().removeYamlExtension()
        
        of "description":
          if value.strip() == "|":
            is_multiline = true
          else:
            current_event.description = "## " & value.strip()
          
        of "  $ref":
          current_event.ref_object_of = value.strip().removeYamlExtension().toCamelCase(firstUpper = true)

        of "    $ref":
          current_property.ref_object_of = value.strip().removeYamlExtension().toCamelCase(firstUpper = true)

        of "properties":
          current_property = Property()

        of "    description":
          current_property.description = value.strip()

        of "    type":
          current_property.kind = value.strip()
          if current_property.kind == "number":
            current_property.kind = "float"
          elif current_property.kind == "integer":
            current_property.kind = "int"
          elif current_property.kind == "boolean":
            current_property.kind = "bool"

        of "      type":
          current_property.ref_object_of = value.strip()
          if current_property.ref_object_of == "number":
            current_property.ref_object_of = "float"
          elif current_property.ref_object_of == "integer":
            current_property.ref_object_of = "int"
          elif current_property.ref_object_of == "boolean":
            current_property.ref_object_of = "bool"

        of "      $ref":
          current_property.ref_object_of = value.strip().removeYamlExtension().toCamelCase(firstUpper = true)

        of "    enum":
          current_property.kind = "Type"

        of "  See https":
          current_event.description.add("    ## See https:" & value.strip())

        of "$schemas": discard

        of "    items": discard

        of "extends": discard

        of "required": discard

        of "    examples":
          # entered a list of examples to add to the description
          current_event.description.add("\n    ## Examples:")
          is_example = true
          is_multiline = false
        else:
          case value:
          of "":
            # add the property to the properties list if it's not empty
            if current_property.name != "":
              properties.add(current_property.deepCopy())

            # start modify the new properties
            current_property = Property(name: key.strip())
            
      else: # case the split result is not 2
        if is_example:
          if values[0] == "    ]":
            is_example = false
          else:
            current_event.description.add("\n    ## - " & values[0].strip())
        if is_multiline:
          current_event.description.add("    ## " & values[0].strip() & "\n")

    # close the current property (if exists) and add it to the properties list
    if current_property.name != "":
      properties.add(current_property.deepCopy())

    # add the properties to the current event
    current_event.properties = properties

    # add the event to the events repository
    if current_event.id == "message" :
      # add Message as the first event
      events.insert(current_event, 0)
    elif current_event.id == "event":
      # add Event as the second event
      events.insert(current_event, 1)
    elif current_event.id == "bot-results-for-bot":
      # add BotResultsForBot as the third event
      events.insert(current_event, 2)
    else:
      events.add(current_event)

  except CatchableError:
    echo "ERROR: ",getCurrentExceptionMsg()
    quit(1)

  # for event in events: echo event

proc main() =
  # write the imports
  for imp in imports: addImport(imp)

  # get the list of yaml files
  let yaml_files = get_yaml_files()
  
  # iterate over the yaml files
  for yaml_file in yaml_files:
    yaml2nim(yaml_file)

  # open schema_file in writing mode
  let file = open(schemas_file, fmWrite)
  
  echo "writing to file: ", schemas_file

  # write comment that alerts of the file being generated automatically
  file.writeLine("# This file is generated automatically by the 'schemas2nim' script")

  # add the date of the generation
  file.writeLine("# Generated on: " & $(now().utc + 2.hours) & " (Italy time)")

  # write the imports only if there are any
  if imports_section.len > 0:
    # remove the last comma and space before writing
    file.writeLine(imports_section[0..^3])

    #add a new line
    file.writeLine("")

  # write the enums section
  for event in events:
    addEnum(event.id)
  file.writeLine(enums_section)

  # write the events
  for event in events:
    file.writeLine($event)

  # write the json2message proc
  file.writeLine("proc json2message*(json_message:string):Message =")
  file.writeLine("  let `type` = json_message.fromJson(Message).`type`")
  file.writeLine("  case `type`:")
  for event in events:
    if event.id != "message" and event.ref_object_of == "Message":
      file.writeLine("    of Type." & event.id.toCamelCase() & ":")
      file.writeLine("      result = json_message.fromJson(" & event.id.toCamelCase(firstUpper = true) & ")")
  file.writeLine("    else:")
  file.writeLine("      result = json_message.fromJson(Message)")

  # close the file
  file.close()

# run the proc
main()
