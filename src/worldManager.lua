local lfs, lg = love.filesystem, love.graphics

local logger = require("util.logger")
local flux = require("libs.flux")
local file = require("util.file")
local g3d = require("libs.g3d")

local characterManager = require("src.characterManager")
local door = require("src.door")

local worldManager = {
  worlds = { },
  doors = { },
  doorLookup = { },
  doorTransition = {
    radius = 0,
  },
  interactable = { },
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

    world.objects = w.objects

    world.setupColliders = w.setupColliders
    world.update = w.update
    world.get3DObjects = w.get3DObjects
    world.draw = w.draw
    world.drawFloor = w.drawFloor
    world.drawUI = w.drawUI
  end

  -- load doors
  lfs.load(dir .. "/doors.lua")()
end

worldManager.get = function(worldId)
  return worldManager.worlds[worldId]
end

worldManager.getDoor = function(doorID)
  return worldManager.doorLookup[doorID]
end

worldManager.newDoor = function(id, ...)
  local newDoor = door.new(...)
  table.insert(worldManager.doors, newDoor)
  worldManager.doorLookup[id] = newDoor
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
    enterDoor:use(character)
  end
end

worldManager.interact = function(playerX, playerZ)
  for _, object in ipairs(worldManager.interactable) do
    if object:interact(playerX, playerZ) then
      return true, object -- event consumed
    end
  end
  return false
end

worldManager.update = function(dt, scale)
  for _, world in pairs(worldManager.worlds) do
    if type(world.update) == "function" then
      world.update(dt, scale)
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

  if not a.isCharacter and not b.isCharacter then
    if a.name and b.name and a.name ~= b.name then
      return a.name < b.name
    end
    if a.id and b.id then
      return a.id < b.id
    end
    -- Catch : Slow and can cause frame times to rocket
    return tostring(a) < tostring(b)
  end

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

  ------ Get objects & sort

  local objects
  if world.get3DObjects then
    objects = world.get3DObjects()
  end

  objects = objects or { }
  local characters = characterManager.getCharactersInWorld(world, objects)
  table.sort(objects, sortObjectsFunc)

  ------ Draw

  for _, door in ipairs(worldManager.doors) do
    door:draw(world.name)
  end

  local shader = g3d.shader

  shader:send("numCharacters", #characters)
  if #characters > 0 then
    local temp = { }
    for _, character in ipairs(characters) do
      -- An attempt to centre shadow under the mass of the player character
      local offset = character.shadowOffset * (character.flip and -1 or 1)
      table.insert(temp, { character.x + offset, character.alpha, character.z })
    end
    shader:send("characterPositions", unpack(temp))
  end
  if type(world.drawFloor) == "function" then
    world.drawFloor()
  end
  shader:send("numCharacters", 0)

  if type(world.draw) == "function" then
    world.draw()
  end

  shader:send("opaque", true)
  if world.objects then
    for _, object in ipairs(world.objects) do
      object:draw()
    end
  end
  shader:send("opaque", false)

  for _, object in ipairs(objects) do
    object:draw()
  end
end

worldManager.drawUI = function(playerWorld, scale)
  local world = worldManager.get(playerWorld)
  if not world then
    logger.warn("Could not find player world:", playerWorld)
    return
  end
  if world.drawUI then
    world.drawUI(scale)
  end

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