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

scene.load = function(gpMode, musicRef)
  scene.gamepadActive = gpMode

  cursor.switch("arrow")
  characterManager.load("assets/animations", "assets/characters/")
  questManager.load("assets/quests")
  worldManager.load("assets/world")

  scene.playerChar = characterManager.get("player")

  scene.playerChar.setMusicRef(musicRef)

  -- fade in to scene
  worldManager.doorTransition.radius = 1
  flux.to(worldManager.doorTransition, 1, { radius = 0 })
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

--
  questManager.resize(w, h, scene.scale)
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

  local inputConsumed = questManager.update(dt, scene.scale, scene.gamepadActive)

  if not inputConsumed and scene.playerChar.canMove and input.baton:pressed("interact") and not questManager.activeQuestScene then
    local range = 2.5
    for _, character in pairs(characterManager.characters) do
      if character ~= scene.playerChar and character.world == scene.playerChar.world and math.abs(character.z - scene.playerChar.z) < 0.1 and
          ((scene.playerChar.flip and character.x >= scene.playerChar.x and character.x < scene.playerChar.x + range) or
          (not scene.playerChar.flip and character.x <= scene.playerChar.x and character.x > scene.playerChar.x - range)) then
        local found = nil
        for _, quest in pairs(questManager.active) do
          if quest.npc == character.dirName and (quest.dialogue:canContinue() or not quest.dialogue.ran) then
            if found and found.importance < quest.importance or not found then
              found = quest
            end
          end
        end
        if found then
          found.dialogue:continue()
          questManager.activeQuestScene = found
          inputConsumed = true
          break
        end
      end
    end
  end

  if not inputConsumed then
    if input.baton:pressed("interact") then
      local consumed, object = worldManager.interact(scene.playerChar.x, scene.playerChar.z, scene.playerChar.world or "town")
      if consumed then
        -- logger.info("INTERACTION SUCCESSFUL:", object.name)
        return -- so we don't double trigger any interaction within worldManager.Update
      end
    end
  end

  worldManager.update(dt, scene.scale, scene.gamepadActive)
end

scene.draw = function()
  lg.origin()
  local playerWorld = scene.playerChar.world or "town"

  local clearColor = worldManager.get(playerWorld).clearColor or { 0, 0, 0, 1, }
  if type(clearColor) == "table" then
    lg.clear(clearColor)
  else
    local ww, wh = lg.getDimensions()
    local cw, ch = clearColor:getDimensions()
    lg.clear(0,0,0,1)
    lg.push("all")
    lg.setDepthMode("always", false)
    lg.draw(clearColor, 0,0, 0, ww/cw, wh/ch)
    lg.pop()
  end
  -- World
  lg.push("all")
  worldManager.draw(playerWorld)
  lg.pop()
  -- UI
  lg.push("all")
  worldManager.drawUI(playerWorld, scene.scale)
  questManager.drawUI(scene.scale)
  lg.pop()

  if love.keyboard.isScancodeDown("tab") then
    local str = love.timer.getFPS().." FPS"
    lg.setColor(1,1,1,1)
    lg.rectangle("fill", 10, 10, lg.getFont():getWidth(str), lg.getFont():getHeight())
    lg.setColor(0,0,0,1)
    lg.print(str, 10, 10)
    lg.setColor(1,1,1,1)
  end
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