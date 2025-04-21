local logger = require("util.logger")

local endTime = love.timer.getTime()
logger.info("Loaded framework in", (endTime-StartTime)*1000, "ms")
StartTime, endTime = nil, nil

local love = love
local le, lg, ltr, lfs, lw = love.event, love.graphics, love.timer, love.filesystem, love.window

require("errorhandler")
require("util.logSystemInfo")

local assetManager = require("util.assetManager")
assetManager.register("assets/")

local sceneManager = require("util.sceneManager")
local settings = require("util.settings")
local utf8 = require("util.utf8")
local flux = require("libs.flux")
local lang = require("util.lang")

local localFound, selectLang
if not settings.newSettings then
  localFound = lang.setLocale(settings.client.locale)
end

if settings.newSettings and not localFound then
  selectLang = true
  local locales = love.system.getPreferredLocales()
  logger.info("Preferred locales:", table.concat(locales, ", "))
  for _, locale in ipairs(locales) do
    local lower = locale:lower()
    if lang.setLocale(lower) then
      settings.client.locale = lower
      logger.info("Found locale match from perferred locales:", lower)
      localFound = true
      break
    end
  end
  if not localFound then
    local loadedLocales = lang.getLocales()
    for _, locale in ipairs(locales) do
      locale = locale:lower()
      if #locale > 2 then
        local sublocale = locale:sub(1,2)
        for _, loadedKey in ipairs(loadedLocales) do
          if sublocale == loadedKey or (#loadedKey > 2 and loadedKey:sub(1,2) == sublocale) then
            logger.info("Managed to find partial language locale match:", loadedKey, ", from", locale)
            settings.client.locale = loadedKey
            localFound = lang.setLocale(loadedKey)
            if localFound then
              goto continue
            end
          end
        end
      end
    end
    ::continue::
  end
end
if not localFound then
  lang.setLocale("en")
  logger.warn("Didn't find locale match. Selecting default English.")
end
love.mouse.setGrabbed(settings.client.mouselock)
love.mouse.setVisible(false)

local input
local processEvents = function()
  le.pump()
  for name, a, b, c, d, e, f in le.poll() do
    if name == "quit" then
      if not love.quit or not love.quit() then
        return a or 0
      end
    elseif name == "lowmemory" then
      assetManager.lowMemory()
    elseif name == "joystickadded" or name == "joystickremoved" or name == "gamepadpressed" then
      input[name](a)
    end
    love.handlers[name](a, b, c, d, e, f)
  end
  return nil
end

local min, max = math.min, math.max
local clamp = function(target, minimum, maximum)
  return min(max(target, minimum), maximum)
end

-- https://gist.github.com/1bardesign/3ed0fabfdcd2661d3308b4da7fa3076d
local manualGC = function(timeBudget, safetyNetMB)
  local limit, steps = 1000, 0
  local start = ltr.getTime()
  while ltr.getTime() - start < timeBudget and steps < limit do
    collectgarbage("step", 1)
    steps = steps + 1
  end
  if collectgarbage("count") / 1024 > safetyNetMB then
    collectgarbage("collect")
  end
end

love.run = function()
  local _, _, flags = lw.getMode()
  local desktopWidth, desktopHeight = lw.getDesktopDimensions(flags.display)
  if settings.client.windowMaximise or
    (lg.getWidth() >= desktopWidth * 0.95 and lg.getHeight() >= desktopHeight * 0.95)
  then
    logger.info("Maximizing window")
    lw.maximize()
  end

  love.keyboard.setKeyRepeat(true)
  input = require("util.input")

  logger.info("Starting load scene")
  sceneManager.changeScene("load")

  logger.info("Creating client gameloop")
  local frameTime, fuzzyTime = 1/60, {1/2,1,2} --todo make frameTime a setting
  local updateDelta, drawDelta = 0, 0

  local gameloop = function()
  -- event updates
    local quit = processEvents()
    if quit then
      require("libs.lily").quit()
      return quit
    end

  -- time
    local dt = ltr.step()
    -- fuzzy timing snapping
    for _, v in ipairs(fuzzyTime) do
      v = frameTime * v
      if math.abs(dt - v) < 0.002 then
        dt = v
      end
    end
    -- dt clamping
    dt = clamp(dt, 0, 2*frameTime)
    updateDelta = clamp(updateDelta + dt, 0, 8*frameTime)
    drawDelta = drawDelta + dt

  -- update
    while updateDelta > frameTime do
      input.update()
      flux.update(frameTime)
      love.update(frameTime)

      updateDelta = updateDelta - frameTime
    end

    -- draw
    local maxTime = 1 / settings.client.maxFPS
    if not lw.hasFocus() and not lw.hasMouseFocus() then
      maxTime = maxTime * 4 -- decrease FPS by 4 times
    end
    if lw.isVisible() and not lw.isMinimized() then
      if settings.client.maxFPS == -1 or drawDelta >= maxTime or lw.getVSync() ~= 0 then
        love.updateui()
        love.draw()
        lg.present()

        drawDelta = drawDelta - maxTime * math.floor(drawDelta / maxTime)
      end
    else
      ltr.sleep(maxTime)
      drawDelta = maxTime
    end

    -- clean up
    manualGC(2e-3, 128)
    ltr.sleep(5e-4)
  end
  --
  ltr.step()
  return gameloop
end