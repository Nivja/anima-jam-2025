local lfs, lg = love.filesystem, love.graphics

local flux = require("libs.flux")
local file = require("util.file")

local characterManager = require("src.characterManager")
local door = require("src.door")

local worldManager = {
  worlds = { },
  doors = { },
  doorTransition = {
    radius = 0,
  },
}

worldManager.load = function(dir)
  for _, worldFile in ipairs(lfs.getDirectoryItems(dir)) do
    local path = dir .. "/" .. worldFile
    if file.getFileExtension(worldFile) ~= "lua" and lfs.getInfo(path, "file") then
      goto continue
    end
    local name = file.getFileName(worldFile)
    if name == "doors" then
      -- not a world, it defines where doors are, and go
      goto continue
    end
    local chunk, errorMessage = lfs.load(path)
    if not chunk then
      error("Tried to load:".. path.. ", Error message: "..tostring(errorMessage))
      return
    end
    worldManager.worlds[name] = {
      name = name,
      chunk = chunk,
    }
    ::continue::
  end

  for _, world in pairs(worldManager.worlds) do
    local w = world.chunk()
    world.chunk = nil

    world.min, world.max = w.min or -10, w.max or 10

    world.setupColliders = w.setupColliders
    world.update = w.update
    world.get3DObjects = w.get3DObjects
    world.draw = w.draw
  end

  -- load doors
  lfs.load(dir .. "/doors.lua")()
end

worldManager.get = function(worldId)
  return worldManager.worlds[worldId]
end

worldManager.newDoor = function(...)
  table.insert(worldManager.doors, door.new(...))
end

worldManager.getWorldLimit = function(worldId)
  local world = worldManager.get(worldId)
  return world.min, world.max
end

worldManager.checkForDoor = function(character, axis)
  local enterDoor = false
  for _, door in ipairs(worldManager.doors) do
    local entry = door.worldA == character.world and door.entryA or
                  door.worldB == character.world and door.entryB or nil
    if entry then
      local isOnXAxis = entry[1] - door.halfWidth < character.x and
                        entry[1] + door.halfWidth > character.x
      local isOnZAxis = entry[2] - 0.1 < character.z and
                        entry[2] + 0.1 > character.z
      -- print(axis, isOnXAxis, character.x, entry[1])
      if (axis == "z" and isOnXAxis) or
         (axis == "x" and isOnXAxis and isOnZAxis) then
        enterDoor = door
        break
      end
    end
  end
  if enterDoor then
    local cb = enterDoor:getCB(character)
    if character.isPlayer then
      local time = 0.5
      flux.to(worldManager.doorTransition, time, { radius = 1 })
        :oncomplete(cb)
        :after(time, { radius = 0 })
    else
      local time = 0.4
      flux.to(character, time, { alpha = 0 })
        :oncomplete(cb)
        :after(time, { alpha = 1 })
    end
  end
end

worldManager.update = function(dt)
  for _, world in pairs(worldManager.worlds) do
    if type(world.update) == "function" then
      world.update(dt)
    end
  end
end

local sortObjectsFunc = function(a, b)
  local aZ = a.z or (a.translation and a.translation[3]) or 0
  local bZ = b.z or (b.translation and b.translation[3]) or 0
  if aZ ~= bZ then
    return aZ > bZ
  end

  if a.isCharacter and not b.isCharacter then return false end
  if not a.isCharacter and b.isCharacter then return true end

  if not a.isCharacter and not b.isCharacter then return a.fileName < b.fileName end

  -- if both character

  if a.isPlayer and not b.isPlayer then return false end
  if not a.isPlayer and b.isPlayer then return true end

  return a.dirName < b.dirName
end

worldManager.draw = function(playerWorld)
  local world = worldManager.get(playerWorld)
  if not world then
    logger.warn("Could not find player world:", playerWorld)
    return
  end

  love.graphics.setDepthMode("always", false)
  for _, door in ipairs(worldManager.doors) do
    door:draw(world.name)
  end
  love.graphics.setDepthMode("lequal", true)

  local objects
  if world.get3DObjects then
    objects = world.get3DObjects()
  end

  objects = objects or { }
  characterManager.getCharactersInWorld(world, objects)
  table.sort(objects, sortObjectsFunc)

  if type(world.draw) == "function" then
    world.draw()
  end

  for _, object in ipairs(objects) do
    object:draw()
  end
end

worldManager.drawUI = function()
  if worldManager.doorTransition.radius ~= 0 then
    local w, h = lg.getDimensions()
    local x = w / 2
    local y = (h / 3) * 2 -- 2/3
    lg.setColor(0,0,0,1)
    lg.circle("fill", x, y, (w > h and w or h) * worldManager.doorTransition.radius)
    lg.setColor(1,1,1,1)
  end
end

return worldManager