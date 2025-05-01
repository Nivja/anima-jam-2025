local lg = love.graphics

local audioManager = require("util.audioManager")
audioManager.setVolumeAll()

local flux = require("libs.flux")

local g3d = require("libs.g3d")
local cam = g3d.camera:current()
cam.fov = math.rad(70)
cam:updateProjectionMatrix()

local assetManager = require("util.assetManager")
local settings= require("util.settings")
local logger = require("util.logger")
local cursor = require("util.cursor")
local input = require("util.input")
local lang = require("util.lang")
local ui = require("util.ui")

local characterManager = require("src.characterManager")
local questManager = require("src.questManager")
local worldManager = require("src.worldManager")

local scene = {
  posX = 0,
  posY = 3,
  posZ = 0, -- shouldn't be touched realistically, added if needed later -- It was needed, thank you past Paul
  lookAt = { 0, -4.3, 25 }, -- Look at positive Z; Y is set to small amount as there is a issue with g3d
  gamepadActive = false,
}

local updateCamera = function()
  g3d.camera.current():lookAt(scene.posX, scene.posY, scene.posZ, scene.posX + scene.lookAt[1], scene.posY + scene.lookAt[2], scene.posZ + scene.lookAt[3])
end
updateCamera()

scene.load = function(gpMode)
  scene.gamepadActive = gpMode

  cursor.switch("arrow")
  characterManager.load("assets/animations", "assets/characters/")
  questManager.load("assets/quests")
  worldManager.load("assets/world")

  scene.playerChar = characterManager.get("player")
  scene.playerChar.world = "town"

  questManager.unlockQuest("test")
  questManager.unlockQuest("quest_1")
  questManager.unlockQuest("quest_2")
  questManager.unlockQuest("quest_3")

end

scene.unload = function()
  cursor.switch("arrow")
end

scene.resize = function(w, h)
  -- Update settings
  settings.client.resize(w, h)

-- scale scene
  local wsize = settings._default.client.windowSize
  local tw, th = wsize.width, wsize.height
  local sw, sh = w / tw, h / th
  scene.scale = sw < sh and sw or sh

-- scale Text
  local font = ui.getFont(18, "fonts.regular.bold", scene.scale)
  lg.setFont(font)

-- scale Cursor
  cursor.setScale(scene.scale)

-- scale Camera
  local cam = g3d.camera:current()
  cam.aspectRatio = (w/h)
  cam:updateProjectionMatrix()
end

local zProgress = 0
scene.update = function(dt)
  characterManager.update(dt)

  if scene.playerChar.canMove then
    local dx, dy = input.baton:get("move")

    if math.abs(dx) <= 0.2 then
      dx = 0
    end
    scene.playerChar:moveX(dx * scene.playerChar.speedX * dt)

    if math.abs(dy) > 0.3 then
      local speed = 8
      if scene.playerChar.zTween and scene.playerChar.zTween.progress < 1 then
        speed = 4
      end
      zProgress = zProgress + dy * speed * dt
    else
      zProgress = 0
    end
    if zProgress >= 1 or zProgress <= -1 then
      local level = zProgress >= 1 and 0.5 or -0.5
      zProgress = 0
      scene.playerChar:moveZ(level)
    end
  end

  local min, max = worldManager.getWorldLimit(scene.playerChar.world)
  local cameraDrag = 4 - math.max(-1, 5 - scene.playerChar.z)
  scene.posX = math.max(min+cameraDrag, math.min(max-cameraDrag, scene.playerChar.x))
  scene.posZ = 0.5 * scene.playerChar.z - 2
  updateCamera()

  if scene.gamepadActive then
    love.mouse.setRelativeMode(true)
    love.mouse.setVisible(false)
  else
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(true)
  end

  

  if input.baton:pressed("interact") then
    local consumed, object = worldManager.interact(scene.playerChar.x, scene.playerChar.z)
    if consumed then
      -- logger.info("INTERACTION SUCCESSFUL:", object.name)
      return -- so we don't double trigger any interaction within worldManager.Update
    end
  end

  worldManager.update(dt, scene.scale, scene.gamepadActive)
end

scene.draw = function()
  lg.clear(.5, 1, 1, 1)
  lg.origin()
  -- World
  lg.push("all")
  worldManager.draw(scene.playerChar.world or "town")
  lg.pop()
  -- UI
  lg.push("all")
  worldManager.drawUI(scene.playerChar.world or "town", scene.scale)
  lg.pop()
end

local inputDetected = function(inputType)
  scene.gamepadActive = inputType == "gamepad" or inputType == "keyboard"
end

scene.keypressed = function()
  inputDetected("keyboard")
end

scene.mousepressed = function()
  inputDetected("mouse")
end

scene.touchedpressed = scene.mousepressed

scene.mousemoved = function()
  inputDetected("mouse")
end

scene.wheelmoved = function()
  inputDetected("mouse")
end

scene.gamepadpressed = function()
  inputDetected("gamepad")
end
scene.joystickpressed = scene.gamepadpressed
scene.joystickaxis = scene.gamepadpressed

return scene