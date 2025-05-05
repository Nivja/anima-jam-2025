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
player:setHome("workshop", 4, 4.5, true)
  :teleportHome()

-- questManager.unlockQuest("quest_1")

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

world.get3DObjects = function()
  return {
    workstationModel,
  }
end

local player = characterManager.get("player")
world.draw = function()
  workstation.draw(player.x, player.z)
end

world.drawUI = function(scale)
  workstation.drawUI(scale)
end

local floor = g3d.newModel("assets/models/floor.obj", "assets/textures/prototype_texture_8.png", { 0, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.drawFloor = function()
  floor:draw()
end

return world