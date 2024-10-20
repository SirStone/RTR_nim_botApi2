proc calcDeltaAngle*(targetAngle, sourceAngle: float): float =
  ## Calculates the difference between two angles, i.e. the number of degrees from a source angle to a target angle.
  ## The delta angle will be in the range [-180,180]
  ##
  ## @param targetAngle is the target angle.
  ## @param sourceAngle is the source angle.
  ## @return The delta angle between a source angle and target angle.
  result = targetAngle - sourceAngle
  if result > 180: result -= 360
  elif result < -180: result += 360