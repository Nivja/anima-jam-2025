local lg = love.graphics

local g3d = require("libs.g3d")

local logger = require("util.logger")

local door = {
  model = g3d.newModel("assets/models/door.obj"),
  halfWidth = 0.8,
}
door.__index = door

-- draw: {x, z, [r = 0]}, entry: {x, z, [flipped = ???magic???]}
door.new = function(worldA, drawA, entryA, worldB, drawB, entryB)
  if entryA[3] == nil then
    local min, max = require("src.worldManager").getWorldLimit(worldA)
    if entryA[2] == min then
      entryA[3] = false
    end
    if entryA[2] == max then
      entryA[3] = true
    end
  end

  if entryB[3] == nil then
    local min, max = require("src.worldManager").getWorldLimit(worldB)
    if entryB[2] == min then
      entryB[3] = false
    end
    if entryB[2] == max then
      entryB[3] = true
    end
  end

  -- R
  if type(drawA[3]) ~= "number" then drawA[3] = 0 end
  if type(drawB[3]) ~= "number" then drawB[3] = 0 end

  return setmetatable({
    worldA = worldA, drawA = drawA, entryA = entryA,
    worldB = worldB, drawB = drawB, entryB = entryB,
  }, door)
end

door.getCB = function(self, character)
  if character.world == self.worldA then -- moveTo worldB
    return function()
      character:setWorld(self.worldB, unpack(self.entryB))
    end
  elseif character.world == self.worldB then -- moveTo worldA
    return function()
      character:setWorld(self.worldA, unpack(self.entryA))
    end
  else
    logger.warn("Character tried to interact with door in world they were not in. Character:", character.world, ". Door:", self.worldA, self.worldB)
  end
  return nil
end

door.draw = function(self, world)
  if self.worldA ~= world and self.worldB ~= world then
    return
  end
  lg.push()
  lg.setColor(0,0,0,1)
  local position = world == self.worldA and self.drawA or self.drawB
  self.model:setTranslation(position[1], 0, position[2])
  self.model:setRotation(0, position[3], 0)
  self.model:draw()
  lg.setColor(1,1,1,1)
  lg.pop()
end

return door