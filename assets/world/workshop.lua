local characterManager = require("src.characterManager")
local questManager = require("src.questManager")

local world = {
  min = 0,
  max =  10,
}

local player = characterManager.get("player")
player:setHome("workshop", 3, 4)
  :teleportHome()

questManager.unlockQuest("quest_1")

------------------------------------

world.update = function(dt, _, _)
  if player.x >= 4 then
    local _, questState = questManager.get("quest_1")
    if questState == "unlocked" then
      questManager.activateQuest("quest_1", true)
    end
  end
end

local g3d = require("libs.g3d")
local floor = g3d.newModel("assets/models/floor.obj", "assets/textures/prototype_texture_8.png", { 0, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.drawFloor = function()
  floor:draw()
end

return world