local audioManager = require("util.audioManager")
audioManager.setVolumeAll()

local scene = { }

scene.draw = function()
  love.graphics.clear()
end

return scene