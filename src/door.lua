local lg = love.graphics

local audioManager = require("util.audioManager")
local logger = require("util.logger")
local flux = require("libs.flux")
local g3d = require("libs.g3d")


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

door.getCB = function(self, character, useEntry)
  if not useEntry and character.world == self.worldA or useEntry == self.entryA then -- moveTo worldB
    return function()
      character:setWorld(self.worldB, unpack(self.entryB))
    end, self.worldB
  elseif not useEntry and character.world == self.worldB or useEntry == self.entryB then -- moveTo worldA
    return function()
      character:setWorld(self.worldA, unpack(self.entryA))
    end, self.worldA
  else
    logger.warn("Character tried to interact with door in world they were not in. Character:", character.world, ". Door:", self.worldA, self.worldB)
  end
  return nil, nil
end

door.use = function(self, character, useEntry)
  local cb, toWorld = self:getCB(character, useEntry)
  local fluxTween
  if character.isPlayer then
    local time = 0.5
    fluxTween = flux.to(require("src.worldManager").doorTransition, time, { radius = 1 })
      :oncomplete(cb)
      :after(time, { radius = 0 })
    audioManager.play("audio.sfx.door")
  else
    local time = 0.4
    fluxTween = flux.to(character, time, { alpha = 0 })
      :oncomplete(cb)
      :after(time, { alpha = 1 })
    local p = require("src.characterManager").get("player")
    if p.world == toWorld or p.world == character.world then
      audioManager.play("audio.sfx.door")
    end
  end
  return fluxTween
end

door.draw = function(self, world)
  if self.worldA ~= world and self.worldB ~= world then
    return
  end
  lg.push()
  lg.setColor(0,0,0,1)
  if world == self.worldA then
    self.model:setTranslation(self.drawA[1], 0, self.drawA[2])
    self.model:setRotation(0, self.drawA[3], 0)
    lg.push("all")
    if self.drawA[3] ~= 0 then
      love.graphics.setDepthMode("always", false)
      self.model:setScale(0.4, 1, 1)
    else
      self.model:setScale(1,1,1,1)
    end
    self.model:draw()
    lg.pop()
  end
  if world == self.worldB then
    self.model:setTranslation(self.drawB[1], 0, self.drawB[2])
    self.model:setRotation(0, self.drawB[3], 0)
    lg.push("all")
    if self.drawB[3] ~= 0 then
      love.graphics.setDepthMode("always", false)
      self.model:setScale(0.4, 1, 1)
    else
      self.model:setScale(1,1,1,1)
    end
    self.model:draw()
    lg.pop()
  end
  lg.setColor(1,1,1,1)
  lg.pop()
end

return door