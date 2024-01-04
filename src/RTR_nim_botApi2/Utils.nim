import math

func toInfiniteValue*(value:float):float =
  ## Converts the given value to an infinite value.
  ## 
  ## `value` is the value to convert
  ## `return` is the infinite value
  if value > 0: return Inf
  if value < 0: return NegInf
  return 0

func isNearZero*(number:float):bool =
  ## returns true if the number is near zero
  ## 
  ## `number` is the number to check
  ## `return` is true if the number is near zero
  return abs(number) < 0.00001

func calcDeltaAngle*(targetAngle:float, sourceAngle:float):float =
  ## calculates the delta angle between two angles
  ## 
  ## `targetAngle` is the target angle
  ## `sourceAngle` is the source angle
  ## `return` is the delta angle
  var deltaAngle = targetAngle - sourceAngle
  if deltaAngle > 180.0:
      deltaAngle -= 360.0
  elif deltaAngle < -180.0:
      deltaAngle += 360.0
  return deltaAngle

func getMaxSpeed*(distance:float, ACCELERATION:float, ABS_DECELERATION:float, MAX_SPEED:float):float =
  ## Returns the maximum speed for the given distance.
  ## 
  ## `distance` is the distance to move
  ## `return` the maximum speed

  var decelerationTime = max(1, ceil((sqrt((4 * 2 / ABS_DECELERATION) * distance + 1) - 1) / 2))
  if decelerationTime.classify == fcInf:
    return MAX_SPEED
  var decelerationDistance = (decelerationTime / 2) * (decelerationTime - 1) * ABS_DECELERATION
  return ((decelerationTime - 1) * ACCELERATION) + ((distance - decelerationDistance) / decelerationTime)

func getMaxDeceleration*(speed:float, ACCELERATION:float, ABS_DECELERATION:float):float =
  ## Returns the maximum deceleration for the given speed.
  ## 
  ## `speed` is the speed to decelerate
  ## `return` the maximum deceleration
  var decelerationTime = speed / ABS_DECELERATION
  var accelerationTime = 1 - decelerationTime

  return min(1, decelerationTime) * ABS_DECELERATION + max(0, accelerationTime) * ACCELERATION

func getNewTargetSpeed*(speed:float, distance:float, MAX_SPEED:float, ACCELERATION:float, ABS_DECELERATION:float):float =
  ## Returns the new speed based on the current speed and distance to move.
  ## 
  ## `speed` is the current speed
  ## `distance` is the distance to move
  ## `return` the new speed
  ## 
  ## Credits for this algorithm goes to Patrick Cupka (aka Voidious),
  ## Julian Kent (aka Skilgannon), and Positive for the original version:
  ## https://robowiki.net/wiki/User:Voidious/Optimal_Velocity#Hijack_2
  if distance < 0:
    return -getNewTargetSpeed(-speed, -distance, MAX_SPEED, ACCELERATION, ABS_DECELERATION)
  var targetSpeed = if distance.classify == fcInf: MAX_SPEED else: min(MAX_SPEED, getMaxSpeed(distance, ACCELERATION, ABS_DECELERATION, MAX_SPEED))

  return
    if speed > 0:
      clamp(targetSpeed, speed - ABS_DECELERATION, speed + ACCELERATION)
    else:
      clamp(targetSpeed, speed - ACCELERATION, speed + getMaxDeceleration(-speed, ACCELERATION, ABS_DECELERATION))

func getDistanceTraveledUntilStop*(speed:float, MAX_SPEED:float, ACCELERATION:float, ABS_DECELERATION:float):float =
  ## Returns the distance traveled until the bot stops.
  ## 
  ## `speed` is the current speed
  ## `return` the distance traveled until the bot stops
  var speed:float = abs(speed)
  var distance:float = 0
  while speed > 0:
    speed = getNewTargetSpeed(speed, 0, MAX_SPEED, ACCELERATION, ABS_DECELERATION)
    distance += speed
  return distance