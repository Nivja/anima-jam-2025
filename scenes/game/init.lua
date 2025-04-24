local lg = love.graphics

local audioManager = require("util.audioManager")
audioManager.setVolumeAll()

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
local dialogueManager = require("src.dialogueManager")
local world = require("src.world")

local scene = {
  posX = -0.5,
  posY = 2.6,
  posZ = 0, -- shouldn't be touched realistically, added if needed later -- It was needed, thank you past Paul
  lookAt = { 0, -5, 25 }, -- Look at positive Z; Y is set to small amount as there is a issue with g3d
}

local updateCamera = function()
  g3d.camera.current():lookAt(scene.posX, scene.posY, scene.posZ, scene.posX + scene.lookAt[1], scene.posY + scene.lookAt[2], scene.posZ + scene.lookAt[3])
end
updateCamera()

scene.load = function(restart)
  cursor.switch("arrow")
  characterManager.load("assets/animations", "assets/characters/")
  -- This should be replaced by quest load; which specifies what dialogue to load
  dialogueManager.load("assets/quests")

  -- for name, dialogue in pairs(dialogueManager.dialogue) do
  --   print(">", name)
  --   while not dialogue.isFinished do
  --     local text = dialogue:next()
  --     if text == nil and dialogue.isFinished then
  --       break
  --     end
  --     logger.info(dialogue.speaker, ">", text)
  --   end
  -- end

  scene.playerChar = characterManager.characters["player"]
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

scene.update = function(dt)
  characterManager.update(dt)

  local dx, dy = input.baton:get("move")

  scene.posX, scene.posY = scene.posX + dx * 5 * dt, scene.posY + -dy * 5 * dt
  updateCamera()
  --logger.info("Pos", scene.posX, scene.posY)
end

scene.draw = function()
  lg.clear(.5, 1, 1, 1)
  lg.origin()
  -- World
  lg.push("all")
  world.draw()
  characterManager.draw()
  lg.pop()
  -- UI
  lg.push("all")

  lg.pop()
end

return scene