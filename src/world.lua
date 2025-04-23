local g3d = require("libs.g3d")
local floor = g3d.newModel("assets/models/floor.obj", "assets/models/floor.png", { 0, 0, 4})
floor.texture:setWrap("repeat")

local world = { }
world.__index = world

world.draw = function()
  floor:draw()
end

return world