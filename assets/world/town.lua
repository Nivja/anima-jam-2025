local characterManager = require("src.characterManager")

local world = {
  min = -10,
  max =  10,
}

-- Where characters appear in the world
  -- todo if polish involves saves, update how player spawns
local player = characterManager.get("player")
player.x, player.z = 0, 4

local child = characterManager.get("child")
child.x, child.z = -5, 5
child:setFlip(true)

local electrician = characterManager.get("electrician")
electrician.x, electrician.z = -3, 5

local sami = characterManager.get("sami")
sami.x, sami.z = 3, 5
sami:setFlip(true)

local zyla = characterManager.get("zyla")
zyla.x, zyla.z = 5, 5

------------------------------------

-- world.setupColliders = function() -- todo

-- end

-- world.update = function(dt)

-- end

world.get3DObjects = function()
  -- todo objects with (or)
    -- .z field
    -- .translation[3] field
end

local g3d = require("libs.g3d")
local floor = g3d.newModel("assets/models/floor.obj", "assets/models/grass.png", { 0, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.draw = function() 
  floor:draw()
end

return world