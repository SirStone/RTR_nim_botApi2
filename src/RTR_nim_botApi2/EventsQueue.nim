type
  EventsQueue* = ref object of RootObj
    events: seq[string] = @[]

proc newEventsQueue*():EventsQueue =
  result = new(EventsQueue)

proc init*(eq:EventsQueue) = eq.events = @[]

proc push*(eq:EventsQueue, e:string) = eq.events.add(e)

proc pop*(eq:EventsQueue):string =
  result = eq.events[0]
  eq.events.delete(0)

proc isEmpty*(eq:EventsQueue):bool = eq.events.len == 0

proc clear*(eq:EventsQueue) = eq.init

proc getEvents*(eq:EventsQueue):seq[string] = eq.events

proc len*(eq:EventsQueue):int = eq.events.len