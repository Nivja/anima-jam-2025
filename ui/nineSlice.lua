local lg = love.graphics

local nineSlices = { }
nineSlices.__index = nineSlices

nineSlices.new = function(texture, i, j, k, w)
  if type(texture) == "string" then
    texture = lg.newImage(texture)
  end

  local self = {
    texture = texture,
    quads = { },
  }

  local width, height = texture:getDimensions()
  local newQuad = function(x, y, w, h)
    return lg.newQuad(x, y, w, h, width, height)
  end
  -- Top
    -- Left
  self.quads[1] = newQuad(0, 0, i, k)
    -- Middle
  self.quads[2] = newQuad(i, 0, j - i, k)
    -- Right
  self.quads[3] = newQuad(j, 0, width - j, k)
  -- Middle
    -- Left
  self.quads[4] = newQuad(0, k, i, w - k)
    -- Middle
  self.quads[5] = newQuad(i, k, j - i, w - k)
    -- Right
  self.quads[6] = newQuad(j, k, width - j, w - k)
  -- Bottom
    -- Left
  self.quads[7] = newQuad(0, w, i, height - w)
  -- Middle
  self.quads[8] = newQuad(i, w, j - i, height - w)
  -- Right
  self.quads[9] = newQuad(j, w, width - j, height - w)

  local _
  self.width, self.height = { }, { }
  _, _, self.width[1], self.height[1] = self.quads[1]:getViewport()
  _, _, self.width[2], self.height[2] = self.quads[5]:getViewport()
  _, _, self.width[3], self.height[3] = self.quads[9]:getViewport()

  if self.width[2] == 0 or self.height[2] == 0 then
    error("Given 9slice; cannot have a center of 0")
  end

  self.drawQuad = function(quad, x, y, scaleX, scaleY)
    lg.draw(self.texture, quad, x, y, 0, scaleX or 1, scaleY or 1)
  end

  return setmetatable(self, nineSlices)
end

nineSlices.draw = function(self, width, height)
  local drawQuad = self.drawQuad
  local quads = self.quads

  local leftW, middleW, rightW = unpack(self.width)
  local topH, middleH, bottomH = unpack(self.height)

  local scaleX = (width - leftW - rightW) / middleW
  local scaleY = (height - topH - bottomH) / middleH

  lg.push()
  -- Top
    -- Left
  drawQuad(quads[1], 0, 0)
    -- Middle
  drawQuad(quads[2], leftW, 0, scaleX, 1)
    -- Right
  drawQuad(quads[3], leftW + middleW * scaleX, 0)
  -- Middle
    -- Left
  drawQuad(quads[4], 0, topH, 1, scaleY)
    -- Middle
  drawQuad(quads[5], leftW, topH, scaleX, scaleY)
    -- Right
  drawQuad(quads[6], leftW + middleW * scaleX, topH, 1, scaleY)
  -- Bottom
    -- Left
  drawQuad(quads[7], 0, topH + middleH * scaleY)
    -- Middle
  drawQuad(quads[8], leftW, topH + middleH * scaleY, scaleX, 1)
  -- Right
  drawQuad(quads[9], leftW + middleW * scaleX, topH + middleH * scaleY)

  lg.pop()
end

return nineSlices