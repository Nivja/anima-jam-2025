local lg = love.graphics

local logger = require("util.logger")

local characterManager = require("src.characterManager")
local questManager = require("src.questManager")

local world = {
  min = 0,
  max =  10,
  clearColor = { 44/255, 50/255, 82/255, 1, },
  musicKey = "audio.music.workshop",
}

local player = characterManager.get("player")
player:setHome("workshop", 5, 4.5, true)
  :teleportHome()

questManager.unlockQuest("quest_1")

-- Setup bark dialogue
questManager.unlockQuest("child_bark")
questManager.activateQuest("child_bark")
questManager.unlockQuest("electrician_bark")
questManager.activateQuest("electrician_bark")
questManager.unlockQuest("sami_bark")
questManager.activateQuest("sami_bark")
questManager.unlockQuest("zyla_bark")
questManager.activateQuest("zyla_bark")

------------------------------------

local g3d = require("libs.g3d")

local wsX, wsZ = -1, 4.5
local workstationModel = g3d.newModel("assets/models/cube.obj")
workstationModel:setTranslation(wsX, 0, wsZ)

local workstation = require("src.workstation")
workstation.set(wsX+.2, wsZ, wsX+1, wsZ)

local timer = 0
world.update = function(dt, scale, isGamepadActive)
  if timer then
    timer = timer + dt
    if timer >= 0 then
      timer = nil
      local _, questState = questManager.get("quest_1")
      if questState == "unlocked" then
        questManager.activateQuest("quest_1", true)
        player:moveX(0)
      else
        logger.error("quest_1 wasn't unlocked and was unable to activate tutorial quest!")
      end
    end
  end

  workstation.update(dt, scale, isGamepadActive)
end

local createPlaneForQuad = require("src.createPlaneForQuad")
local workshop_assets = lg.newImage("assets/textures/Workshop_Assets.png")
local pizzaShelf, _halfH = createPlaneForQuad(1166, 740, 363, 340, workshop_assets, 300)
pizzaShelf:setTranslation(8, _halfH-.1, 1.9)

local pizzaShelf2 = pizzaShelf:clone()
pizzaShelf2:setTranslation(6, _halfH-.1, 1.9)

local plant2, _halfH = createPlaneForQuad(12, 315, 181, 474, workshop_assets, 250)
plant2:setTranslation(-1, _halfH, 2.6)

world.get3DObjects = function()
  return {
    workstationModel,
    pizzaShelf,
    pizzaShelf2,
    plant2,
  }
end

local door_wall = g3d.newModel("assets/models/door_wall.obj", "assets/textures/door_wall.png", { 10.5, 0, 4 }, nil, nil, false, true)
local side_wall = g3d.newModel("assets/models/door_wall.obj", "assets/textures/side_wall.png", { -1.5, 0, 4 }, nil, nil, false, true)
local door = g3d.newModel("assets/models/workshop_door.obj", "assets/textures/Door.png", { 10.4, 0, 4.65 }, nil, nil, false, true)
local backwall = g3d.newModel("assets/models/workshop_backwall.obj", "assets/textures/front_wall.png", { .5, 0, 6, }, nil, nil, false, false)
local roof = g3d.newModel("assets/models/workshop_floor.obj", "assets/textures/Roof.png", { .5, 4, 4 }, nil, nil, true, true)

local plant, _halfH = createPlaneForQuad(12, 315, 181, 474, workshop_assets, 200)
plant:setTranslation(9.5, _halfH, 5.5)
local paintings, _halfH = createPlaneForQuad(267, 100, 263, 334, workshop_assets, 200)
paintings:setTranslation(8.2, _halfH+1.4, 5.9)
local rolls, _halfH = createPlaneForQuad(373, 616, 410, 411, workshop_assets, 200)
rolls:setTranslation(7.5, _halfH, 5.5)
local stringPainting, _halfH = createPlaneForQuad(623, 54, 234, 426, workshop_assets, 200)
stringPainting:setTranslation(6, _halfH+1.8, 5.9)
local standingShelf, _halfH = createPlaneForQuad(911, 169, 173, 591, workshop_assets, 200)
standingShelf:setTranslation(4.5, _halfH, 5.5)
local hangingShelf, _halfH = createPlaneForQuad(1129, 98, 604, 547, workshop_assets, 200)
hangingShelf:setTranslation(2, _halfH+0.5, 5.9)

local jar1, _halfH = createPlaneForQuad(1581, 913, 92, 113, workshop_assets, 200)
jar1:setTranslation(3, _halfH+1.2, 5.7)
local jar2, _halfH = createPlaneForQuad(1689, 913, 92, 108, workshop_assets, 200)
jar2:setTranslation(2.5, _halfH+1.15, 5.65)
local jar3, _halfH = createPlaneForQuad(1809, 912, 92, 109, workshop_assets, 200)
jar3:setTranslation(1.15, _halfH+1.2, 5.7)

local wallSandbag, _halfH = createPlaneForQuad(1740, 101, 191, 564, workshop_assets, 200)
wallSandbag:setTranslation(-.5, _halfH+1, 5.9)
local books, _halfH = createPlaneForQuad(1607, 691, 234, 150, workshop_assets, 200)
books:setTranslation(0.7, _halfH, 5.4)

local player = characterManager.get("player")
world.draw = function()
  lg.push("all")
  lg.setDepthMode("always", false)
    door_wall:draw()
    door:draw()
  lg.pop()
  backwall:draw()
  side_wall:draw()
  roof:draw()

  -- BG items
  plant:draw()
  paintings:draw()
  stringPainting:draw()
  rolls:draw()
  standingShelf:draw()
  hangingShelf:draw()
    jar1:draw()
    jar2:draw()
    jar3:draw()
  wallSandbag:draw()
  books:draw()
  --

  workstation.draw(player.x, player.z)
end

world.drawUI = function(scale)
  workstation.drawUI(scale)
end

local floor = g3d.newModel("assets/models/workshop_floor.obj", "assets/textures/workshop_floor.png", { .5, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.drawFloor = function()
  floor:draw()
end

return world