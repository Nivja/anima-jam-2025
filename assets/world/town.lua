local characterManager = require("src.characterManager")

local world = {
  min = -10,
  max =  10,
}

-- Where characters appear in the world
  -- todo if polish involves saves, update how player spawns
local player = characterManager.get("player")
player:setHome("town", 0, 4)
  :teleportHome()

local child = characterManager.get("child")
child:setHome("town", -5, 5, true)
  :teleportHome()

local electrician = characterManager.get("electrician")
electrician.x, electrician.z = -3, 5
electrician:setHome("town", -3, 5)
  :teleportHome()

local sami = characterManager.get("sami")
sami:setHome("town", 5, 5, true)
  :teleportHome()

local zyla = characterManager.get("zyla")
zyla:setHome("town", 7, 5)
  :teleportHome()

------------------------------------

local lg = love.graphics
local g3d = require("libs.g3d")

-- world.setupColliders = function() -- todo

-- end

local foliage = g3d.newModel("assets/models/foliage.obj", nil, nil, nil, nil, true, false)

local texture_tuft_01 = lg.newImage("assets/textures/tuft_01.png")
texture_tuft_01:setFilter("nearest")

world.objects = { } -- for objects that don't have alpha considerations

local newTuft = function(x, z)
  foliage.texture = texture_tuft_01
  local tuft = foliage:clone()
  z = z - 0.1
  tuft:setTranslation(x, 0, z)
  table.insert(world.objects, tuft)
end

-- Near
newTuft(-7, 2.5)
newTuft(-2, 2)
newTuft(2, 2.5)
newTuft(3, 2)
newTuft(7, 3)
newTuft(9, 2.5)

-- Far
newTuft(-9, 5)
newTuft(-4, 5.5)
newTuft(4.5, 5.5)
newTuft(6, 6)
newTuft(9, 5)

local rbX, rbZ = 3.5, 5.5

local requestBoard = g3d.newModel("assets/models/request_board.obj", "assets/textures/request_board.png", { rbX, 0, rbZ }, nil, nil, false, false)
requestBoard.texture:setFilter("nearest")

local requestBoardSRC = require("src.requestBoard")
requestBoardSRC.set(rbX, rbZ, rbX, rbZ - 0.5)

world.update = function(dt, scale, isGamepadActive)
  requestBoardSRC.update(dt, scale, isGamepadActive)
end

world.get3DObjects = function() -- for alpha objects
  return {
    requestBoard,
  }
end

local workshopExterior = g3d.newModel("assets/models/workshop_exterior.obj", "assets/textures/workshop_exterior.png", { 0, 0, 6.005 }, nil, nil, false, true)

world.draw = function()
  workshopExterior:draw()
  requestBoardSRC.draw(player.x, player.z)
end

world.drawUI = function(scale)
  requestBoardSRC.drawUI(scale)
end

local floor = g3d.newModel("assets/models/floor.obj", "assets/textures/ground.png", { 0, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.drawFloor = function() 
  floor:draw()
end

return world