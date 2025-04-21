local lg = love.graphics

local assetManager = require("util.assetManager")

local threeSlices = { }
threeSlices.__index = threeSlices

threeSlices.new = function(texture, slice1, slice2, direction)
  local self = {
    texture = texture,
    isHorizontal = direction ~= "vertical",
    offset = slice1,
    length = slice2 - slice1,
  }

  local w, h = texture:getDimensions()
  if direction ~= "vertical" then
    self[1] = lg.newQuad(0,      0, slice1,        h, texture)
    self[2] = lg.newQuad(slice1, 0, slice2-slice1, h, texture)
    self[3] = lg.newQuad(slice2, 0, w-slice2,      h, texture)
    self.offset2 = w-slice2
    self.minimumLength = slice1 + w-slice2
  else
    self[1] = lg.newQuad(0,      0, w, slice1,        texture)
    self[2] = lg.newQuad(0, slice1, w, slice2-slice1, texture)
    self[3] = lg.newQuad(0, slice2, w, h-slice2,      texture)
    self.offset2 = h-slice2
    self.minimumLength = slice1 + h-slice2
  end

  return setmetatable(self, threeSlices)
end

threeSlices.getLength = function(self, length, j)
  local s = 1
  if self.isHorizontal then
    s = j/self.texture:getHeight()
  else
    s = j/self.texture:getWidth()
  end
  return (self.offset + self.offset2) * s + length
end

threeSlices.draw = function(self, length, j)
  local targetLength = length -- self.minimumLength
  lg.push()
  if self.isHorizontal then
    local s = j/self.texture:getHeight()
    lg.draw(self.texture, self[1], 0, 0, 0, s)
    lg.translate(self.offset*s, 0)
    if targetLength > 0 then
      lg.draw(self.texture, self[2], 0, 0, 0, targetLength/self.length, s)
      lg.translate(targetLength, 0)
    end
    lg.draw(self.texture, self[3], 0, 0, 0, s)
  else
    local s = j/self.texture:getWidth()
    lg.draw(self.texture, self[1], 0, 0, 0, s)
    lg.translate(0, self.offset)
    if targetLength > 0 then
      lg.draw(self.texture, self[2], 0, 0, 0, s, targetLength/self.length)
      lg.translate(0, targetLength)
    end
    lg.draw(self.texture, self[3], 0, 0, 0, s)
  end
  lg.pop()
end

return threeSlices