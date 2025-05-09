local flux = require("libs.flux")

local sceneManager = require("util.sceneManager")
local assetManager = require("util.assetManager")
local settings = require("util.settings")
local logger = require("util.logger")
local args = require("util.args")
local ui = require("util.ui")

local lg = love.graphics
local floor, rad = math.floor, math.rad

-- local logo = lg.newImage("assets/UI/logoES.png")
-- logo:setFilter("nearest")

local logo = lg.newImage("assets/UI/Logo.png")
logo:setFilter("linear")

local assets = require("util.assets")

local bgColor = { .1, .1, .1, 1 }

local scene = {
  logo = {
    x = 0, y = 0, r = 0
  },
  lily = sceneManager.preload("scenes.mainmenu")
}

local splash
scene.load = function()
  if not args["--speed"] then
    splash = require("libs.splash").new({ background = bgColor })
  else
    splash = {
      done = true
    }
  end
end

scene.unload = function()
  love.mouse.setVisible(true)
  if splash.release then
    splash:release()
  end
end

lg.setFont(ui.getFont(18, "fonts.regular", 1))

local percentage = 1
local logoFadeTimer = 0
local nextScenetimer = args["--speed"] and 60 or 0

scene.update = function(dt)
  if not splash.done then
    splash:update(dt)
  else
    if scene.lily then
      percentage = scene.lily:getLoadedCount() / scene.lily:getCount()
    end
    if scene.lily:isComplete() then
      logoFadeTimer = logoFadeTimer + dt
      nextScenetimer = nextScenetimer + dt
      if nextScenetimer >= 2 then
        logger.info("Finished loading, moving to menu")
        if args["--speed"] then
          love.window.focus()
        else
          love.window.requestAttention(true)
        end
        sceneManager.changeScene("scenes.mainmenu")
      end
    end
  end
end

local w, h = lg.getDimensions()
w, h = floor(w/2), floor(h/2)

scene.resize = function(w_, h_)
  if not splash.done then
    splash:resize(w, h)
  end
  -- Update settings
  settings.client.resize(w, h)

  w, h = floor(w_/2), floor(h_/2)
end

local barW, barH = 400, 20
local lineWidth = 2
local lineWidth2, lineWidth4 = lineWidth*2, lineWidth*4
-- local scale = 12
local scale = 1/4

scene.draw = function()
  lg.clear(bgColor)
  if not splash.done then
    lg.push("all")
      splash:draw()
    lg.pop()
  else
    lg.push()
      lg.translate(w, h)
      lg.push("all")
        lg.setColor(1,1,1, logoFadeTimer)
        lg.draw(logo, scene.logo.x,scene.logo.y, scene.logo.r, scale,scale, logo:getWidth()/2, logo:getHeight()/2)

        lg.translate(0, logo:getHeight()*(scale))
        lg.translate(-floor(barW/2), -floor(barH/2))
        lg.setStencilMode("draw", 1)
        lg.rectangle("fill", lineWidth, lineWidth, barW-lineWidth2, barH-lineWidth2)
        lg.setStencilMode("test", 0)
        lg.setColor(.9,.9,.9, logoFadeTimer)
        lg.rectangle("fill", 0,0, barW, barH)
        lg.setStencilMode("off")
        lg.rectangle("fill", lineWidth2, lineWidth2, (barW-lineWidth4)*percentage, barH-lineWidth4)
      lg.pop()
    if scene.lily then
      local str = scene.lily:getLoadedCount().." / "..scene.lily:getCount()
      lg.print(str, -lg.getFont():getWidth(str)/2, logo:getHeight()*scale/2)
    end
    lg.pop()
  end
end

return scene