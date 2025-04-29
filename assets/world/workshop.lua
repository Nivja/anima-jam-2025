local world = { }


------------------------------------

local g3d = require("libs.g3d")
local floor = g3d.newModel("assets/models/floor.obj", "assets/textures/prototype_texture_8.png", { 0, 0, 4 }, nil, nil, true, false)
floor.texture:setWrap("repeat")

world.drawFloor = function()
  floor:draw()
end

return world