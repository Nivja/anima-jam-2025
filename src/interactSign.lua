local lg = love.graphics

local createPlaneForQuad = require("src.createPlaneForQuad")

local cw, ch = 2*500, 0.25*500
local signCanvas = lg.newCanvas(cw, ch)
lg.push("all")
  lg.setCanvas(signCanvas)
  lg.clear(0,0,0,0)
  local font = require("util.ui").getFont(100, "fonts.regular.bold", 1)
  lg.setColor(1,1,1,1)
  local str = "Press   /  /  "
  lg.translate(cw/2-(font:getWidth(str)/2), 0)
  lg.print(str, font)
  local t = lg.newImage("assets/UI/input/pc/keyboard_space_icon_outline.png")
  x = font:getWidth("Press ")
  local w = font:getWidth(" ")
  x = x
  lg.draw(t, x, 0, 0, 2)
  local t = lg.newImage("assets/UI/input/pc/keyboard_return_outline.png")
  x = x + w * 3
  lg.draw(t, x, 0, 0, 2)
  local t = lg.newImage("assets/UI/input/steamdeck/steamdeck_button_a_outline.png")
  x = x + w * 3
  lg.draw(t, x, 0, 0, 2)
  t = nil
lg.pop()

local sign = createPlaneForQuad(0, 0, cw, ch, signCanvas)

return function()
  return sign:clone()
end