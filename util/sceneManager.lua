local assetManager =  require("util.assetManager")
local lang = require("util.lang")

local sceneManager = {
  currentScene = nil,
  nilFunc = function() end,
  sceneHandlers = {
    -- GAME LOOP
    "load", -- custom
    "unload", -- custom
    "update",
    "updateui", -- custom
    "draw",
    "quit",
    -- WINDOW
    "focus",
    "resize",
    "visable",
    "displayrotated",
    "filedropped",
    "directorydropped",
    -- TOUCH INPUT
    "touchpressed",
    "touchmoved",
    "touchreleased",
    -- MOUSE INPUT
    "mousepressed",
    "mousemoved",
    "mousereleased",
    "mousefocus",
    "wheelmoved",
    -- KEY INPUT,
    "keypressed",
    "keyreleased",
    "textinput",
    "textedited",
    -- JOYSTICK/GAMEPAD INPUT
    "joystickhat",
    "joystickaxis",
    "joystickpressed",
    "joystickreleased",
    "joystickadded",
    "joystickremoved",
    "gamepadpressed",
    "gamepadreleased",
    "gamepadaxis",
    "gamepadswitched", -- custom
    -- ERROR
    "threaderror",
    "lowmemory",
    -- OTHER
    "langchanged", -- custom
  },
  loadedScenes = { },
}

local love = love

sceneManager.isLoaded = function(sceneRequire)
  for i, loaded in ipairs(sceneManager.loadedScenes) do
    if loaded == sceneRequire then
      return true, i
    end
  end
  return false
end

sceneManager.preload = function(sceneRequire)
  if sceneManager.isLoaded(sceneRequire) then
    return nil
  end
  table.insert(sceneManager.loadedScenes, sceneRequire)

  local success, requiredAssets = pcall(require, sceneRequire..".assets")
  if success then
    return assetManager.load(requiredAssets)
  end
  return nil
end

sceneManager.unload = function(sceneRequire)
  local isLoaded, index = sceneManager.isLoaded(sceneRequire)
  if not isLoaded then
    return
  end
  table.remove(sceneManager.loadedScenes, index)

  local success, requiredAssets = pcall(require, sceneRequire..".assets")
  if success then
    assetManager.unload(requiredAssets)
  end
end

sceneManager.changeScene = function(sceneRequire, ...)
  sceneManager.preload(sceneRequire)

  local scene = require(sceneRequire)

  if sceneManager.currentScene then
    love.unload()
    sceneManager.unload(sceneManager.sceneRequire)
  end

  for _, v in ipairs(sceneManager.sceneHandlers) do
    love[v] = scene[v] or sceneManager.nilFunc
  end

  if love["quit"] ~= sceneManager.nilFunc then
    love["quit"] = sceneManager.quit
  end

  sceneManager.currentScene = scene
  sceneManager.sceneRequire = sceneRequire

  collectgarbage("collect")
  collectgarbage("collect")

  love.load(...)

  love.langchanged(lang.localeKey)

  if love.graphics then
    love.resize(love.graphics.getDimensions())
  end
end

sceneManager.quit = function()
  local quit = sceneManager.currentScene.quit()
  return quit
end

return sceneManager