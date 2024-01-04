let
  DEFAULT_SERVER_URL* = "ws://localhost:7654"
  DEFAULT_SERVER_SECRET* = "serversecret"

  #++++++++ GAME PHYSICS ++++++++ #
  # bots accelerate at the rate of 1 unit per turn but decelerate at the rate of 2 units per turn
  ACCELERATION*:float = 1
  DECELERATION*:float = -2
  ABS_DECELERATION*:float = abs(DECELERATION)

  # The speed can never exceed 8 units per turn
  MAX_SPEED*:float = 8

  # If standing still (0 units/turn), the maximum rate is 10° per turn
  MAX_TURN_RATE*:float = 10

  # The maximum rate of rotation is 20° per turn. This is added to the current rate of rotation of the bot
  MAX_GUN_TURN_RATE*:float = 20

  # The maximum rate of rotation is 45° per turn. This is added to the current rate of rotation of the gun
  MAX_RADAR_TURN_RATE*:float = 45

  # The maximum firepower is 3 and the minimum firepower is 0.1
  MAX_FIRE_POWER*:float = 3
  MIN_FIRE_POWER*:float = 0.1