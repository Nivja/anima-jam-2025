local args = require("util.args")
if args["--speed"] then
  return
end

local logger = require("util.logger")

local ls, lw, lg = love.system, love.window, love.graphics

-- Computer
logger.info("System Info:")
logger.info("  OS :", ls.getOS(), jit and jit.arch or "")
logger.info("  Logic Cores :", ls.getProcessorCount())
logger.info("  Love :", love._version)
local powerState, powerPercentage, powerSeconds = ls.getPowerInfo()
if powerState == "nobattery" then powerState = "no battery" end
logger.info("  Power :", powerState)
if powerPercentage ~= nil then
  logger.info("    Percentage :", powerPercentage)
end
if powerSeconds ~= nil then
  logger.info("    Seconds :", powerSeconds)
end
local count = lw.getDisplayCount()
logger.info("  Display Count :", count)
for i = 1, count do
  local w, h = lw.getDesktopDimensions(i)
  logger.info("    Index", i, ":", lw.getDisplayName(i), w, "x", h)
  local modes = lw.getFullscreenModes(i)
  logger.info("      Nu. Fullscreen Modes :", #modes)
  logger.info("      Sleep Enabled :", lw.isDisplaySleepEnabled(i))
  logger.info("      Orientation :", lw.getDisplayOrientation(i))
end

-- Graphics
local name, version, vendor, device = lg.getRendererInfo()
logger.info("Render Info:")
logger.info("  Name :", name)
logger.info("  Version :", version)
logger.info("  Vendor :", vendor)
logger.info("  Device :", device)

local limits = lg.getSystemLimits()
logger.info("System Graphic Limits:")
for k, v in pairs(limits) do
  logger.info(" ", k, ":", v)
end

local features = lg.getSupported()
logger.info("Supported Graphic Features:")
for k, v in pairs(features) do
  logger.info(" ", k, ":", v)
end