local world = { }


------------------------------------

-- world.setupColliders = function() -- todo

-- end

-- world.update = function(dt)

-- end

-- world.get3DObjects = function()

-- end

local g3d = require("libs.g3d")
local floor = g3d.newModel("assets/models/floor.obj", "assets/models/prototype_texture_8.png", { 0, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.draw = function()
  floor:draw()
end

return world