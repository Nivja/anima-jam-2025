local baton = require("libs.baton")

local logger = require("util.logger")
local settings = require("util.settings")

local input = {
  baton = baton.new({
    controls = settings.client.input,
    pairs = {
      move = { "moveRight", "moveLeft", "moveUp", "moveDown" },
    },
    joystick = joystick,
    deadzone = settings.client.deadzone,
  }),
}

local setBatonJoystick = function(joystick)
  input.baton.config.joystick = joystick
end

input.update = function()
  input.baton:update()
end

input.joystickadded = function(joystick)
  if input.gamepad == nil and joystick:getGUID() == settings.client.gamepadGUID then
    input.setGamepad(joystick)
    logger.info("Joystick reconnected!")
  end
end

input.joystickremoved = function(joystick)
  if joystick == input.gamepad then
    input.gamepad = nil
    setBatonJoystick(nil)
  end
end

input.gamepadpressed = function(joystick, ...)
  if joystick ~= input.gamepad then
    input.setGamepad(joystick)
  end
end

input.isGamepadActive = function()
  return input.baton:getActiveDevice() == "joy"
end

local lastKnown
input.isMouseActive = function()
  local v = input.baton:getActiveDevice() == "kbm"
  return v
end

local stringsContain = function(pattern, ...)
  for i = 1, select('#', ...) do
    local str = select(i, ...)
    if type(str) == "string" and str:find(pattern) then
      return true
    end
  end
  return false
end

input.setGamepad = function(gamepad)
  if input.gamepad then
    input.gamepad:setPlayerIndex(0)
  end
  input.gamepad = gamepad
  input.gamepad:setPlayerIndex(1)
  setBatonJoystick(input.gamepad)

  local guid = input.gamepad:getGUID()
  if guid == settings.client.gamepadGUID then
    return
  end
  settings.client.gamepadGUID = guid

  local gamepadType = gamepad:getGamepadType()
  local name = gamepad:getName()
  if stringsContain("xbox", gamepadType, name) then
    settings.client.gamepadType = "xbox"
  elseif stringsContain("ps", gamepadType, name) then
    settings.client.gamepadType = "playstation"
  elseif stringsContain("switch", gamepadType, name) or
          stringsContain("joycon", gamepadType, name) then
    settings.client.gamepadType = "switch"
  elseif stringsContain("steamdeck", gamepadType, name) then
    settings.client.gamepadType = "steamdeck"
  else
    settings.client.gamepadType = "general"
  end
  logger.info("Gamepad input, type:", gamepadType, ", interal type:", settings.client.gamepadType)
  love.gamepadswitched(input.joystick, gamepadType, settings.client.gamepadType)
end

if settings.client.gamepadGUID ~= "nil" then
  local joysticks = love.joystick.getJoysticks()
  for _, joystick in ipairs(joysticks) do
    if joystick:getGUID() == settings.client.gamepadGUID then
      input.setGamepad(joystick)
      logger.info("Found previous gamepad via GUID!")
    end
  end
end

return input