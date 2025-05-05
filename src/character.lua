local lfs, lg = love.filesystem, love.graphics

local audioManager = require("util.audioManager")
local logger = require("util.logger")
local flux = require("libs.flux")

local createPlaneForQuad = require("src.createPlaneForQuad")

local character = { }
character.__index = character

character.new = function(directory, dirName, definition, spritesheetDir)
  local self = {
    x = 0, y = 0, z = 4,
    rotation = 0,
    scale = 1,
    speedX = 4,
    flip = false,
    flipRY = 0,
    alpha = 1,
    shadowOffset = 0.1,
    state = nil, -- default state set in characterManager.load --> .initState 
    animations = { },
    animationTrackState = { },
    animationTweens = { },
    animationRequestQueue = { },
    shouldDraw = true,
    isCharacter = true,
    world = "town",
    canMove = true,
  }

  if definition.transform then
    for index, value in pairs(definition.transform) do
      if self[index] and type(value) == "number" then
        self[index] = value
      end
    end
  end

  if definition.spritesheet then
    local path = (spritesheetDir and spritesheetDir or directory) .. "/" .. definition.spritesheet
    if lfs.getInfo(path, "file") then
      self.spritesheet = lg.newImage(path)
    else
      error("Couldn't find spritesheet path:"..path)
    end
  else
    error("Character is missing spritesheet, of:"..dirName)
  end

  if type(definition.shadowOffset) == "number" then
    self.shadowOffset = definition.shadowOffset
  end

  local partLookup = { }
  -- Create and validate parts 
  for _, partDefinition in ipairs(definition.parts) do
    if not partDefinition.name then
      logger.warn("Character", dirName, "has a part that doesn't have a name")
      goto continue
    end

    local part = {
      name = partDefinition.name,
      x = 0, y = 0, r = 0, scale = 1, -- Defaults are actually set later for these values
      a0x = 0, a0y = 0, a0r = 0, a0scale = 1, -- Used for animation
      a1x = 0, a1y = 0, a1r = 0, a1scale = 1,
      a2x = 0, a2y = 0, a2r = 0, a2scale = 1,
      children = { }, -- populated later
    }
    partLookup[partDefinition.name] = part

    part.shouldDraw = not (partDefinition.draw == false)
    if self.spritesheet and type(partDefinition.texture) == "table" then
      local t = partDefinition.texture
      local x, y, w, h = t.x, t.y, t.width, t.height
      part.quad = lg.newQuad(x, y, w, h, self.spritesheet)
    else
      error("Missing texture property of part:", partDefinition.name, "of", dirName)
    end

    part.pivot = partDefinition.pivot
    local t = partDefinition.texture
    if type(part.pivot) ~= "table" then part.pivot = { t.x + t.width/2, t.y + t.height/2 } end
    if type(part.pivot[1]) ~= "number" then part.pivot[1] = t.x + t.width/2 end
    if type(part.pivot[2]) ~= "number" then part.pivot[2] = t.y + t.height/2 end

    part.pivot[1] = part.pivot[1] - t.x
    part.pivot[2] = part.pivot[2] - t.y

    part.offset = partDefinition.offset
    if type(part.offset) ~= "table" then part.offset = { 0, 0 } end
    if type(part.offset[1]) ~= "number" then part.offset[1] = 0 end
    if type(part.offset[2]) ~= "number" then part.offset[2] = 0 end

    part.zOffset = partDefinition.zOffset
    if type(part.zOffset) ~= "number" then part.zOffset = 0 end

    part.x = partDefinition.x
    if type(part.x) ~= "number" then part.x = 0 end

    part.y = partDefinition.y
    if type(part.y) ~= "number" then part.y = 0 end

    part.r = partDefinition.r
    if type(part.r) ~= "number" then part.r = 0 end

    part.scale = partDefinition.scale
    if type(part.scale) ~= "number" then part.scale = 1 end

    ::continue::
  end

  -- Relationship: children
  local root = nil
  for _, partDefinition in ipairs(definition.parts) do
    if partDefinition.parent == nil then
      if not root then
        root = partLookup[partDefinition.name]
      else
        logger.warn("Character", dirName, "has more than one part with parent property is null! Ignoring:", partDefinition.type)
      end
    else
      local parent = partLookup[partDefinition.parent]
      if not parent then
        logger.warn("Character", dirName, "part[", partDefinition.name,"] has parent that hasn't been defined! Ignoring:", partDefinition.parent)
      else
        table.insert(parent.children, partLookup[partDefinition.name])
      end
    end
  end

  self.partLookup = partLookup
  self.dirName = dirName
  self.root = root

  -- directory


  return setmetatable(self, character)
end

character.applyAnimation = function(self, newState)
  local anim = require("src.characterManager").animations[newState]
  if anim then
    anim:apply(self)
  else
    logger.warn("Character[", self.dirName, "] Couldn't find animation for state:", newState, "[type:".. type(newState) .. "]")
  end
end

character.setHome = function(self, world, x, z, flip)
  self.homeWorld = world or self.homeWorld
  self.homeX = x or self.homeX
  self.homeZ = z or self.homeZ
  self.homeFlipped = flip or false
  return self
end

character.teleportHome = function(self)
  self:setWorld(self.homeWorld, self.homeX, self.homeZ, self.homeFlipped)
  return self
end

character.moveX = function(self, deltaX)
  self.x = self.x + deltaX

  if deltaX ~= 0 then
    local min, max = require("src.worldManager").getWorldLimit(self.world)
    local hit = false
    if self.x > max then
      self.x = max
      hit = true
    end
    if self.x < min then
      self.x = min
      hit = true
    end
    if hit then
      require("src.worldManager").checkForDoor(self, "x")
      self:applyAnimation("idle")
      return
    end
  end

  local state = math.abs(deltaX) > 0 and "walk" or "idle"
  self:applyAnimation(state)
  if state == "walk" then
    local currentFlip = self.flip
    self.flip = deltaX > 0
    if currentFlip ~= self.flip then
      if self.flipTween then
        self.flipTween:stop()
      end
      if self.flip then
        self.flipRY = math.rad(0)
        self.flipTween = flux.to(self, 0.15, { flipRY = math.rad(-180) })
      else
        self.flipRY = math.rad(-180)
        self.flipTween = flux.to(self, 0.15, { flipRY = math.rad(0) })
      end
    end
  end
end

local minZ, maxZ = 2, 5

local moveUnitZ, moveUnitZEpsilon = 0.5, 0.001
character.moveZ = function(self, deltaZ)
  if math.abs(deltaZ) < moveUnitZEpsilon then
    return
  end
  if math.abs(deltaZ) > moveUnitZ then
    local direction = math.sign(deltaZ) -- 1 or -1
    while math.abs(deltaZ) >= moveUnitZ - moveUnitZEpsilon do
      self:moveZ(moveUnitZ * direction)
      deltaZ = deltaZ - moveUnitZ * direction
    end
    return
  end
  local target = self.z - deltaZ
  if target > maxZ then
    require("src.worldManager").checkForDoor(self, "z")
    return
  end
  target = math.max(minZ, math.min(maxZ, target))
  if self.z == target then
    return
  end

  local newTween
  if not self.zTween or self.zTween.progress >= 1 then
    newTween = flux.to(self, 0.3, { z = target })
  else
    target = math.max(minZ, math.min(maxZ, self.zTarget - deltaZ))
    if self.zTarget ~= target then
      newTween = self.zTween:after(self, 0.3, { z = target })
    end
  end
  if newTween then
    self.zTween = newTween
    self.zTween:ease("cubicout")
    self:applyAnimation("zjump")
    self.zTarget = target
  end
end

character.setFlip = function(self, flipped)
  if flipped == nil then
    self.flip = self.flip
  else
    self.flip = flipped
  end
  -- update flipRY; so both flipping systems show the correct direction
  if self.flip then
    self.flipRY = math.rad(-180)
  else
    self.flipRY = math.rad(0)
  end
  return self
end


local worldMusicRef, newMusicRef, newMusicTween, oldMusicRef, oldMusicTween

character.setMusicRef = function(ref)
  worldMusicRef = ref
end

character.setWorld = function(self, world, x, z, flipped)
  local oldWorld = self.world
  self.world = world
  local min, max = require("src.worldManager").getWorldLimit(self.world)
  if x == min then x = x + 1 end
  if x == max then x = x - 1 end
  self.x, self.z = x, z
  self:setFlip(flipped)

  if oldWorld ~= self.world then
    if self.dirName == "player" then
      if newMusicRef then -- fast switching world handling
        newMusicTween:stop()
        worldMusicRef = newMusicRef
        newMusicRef = nil
      end
      if oldMusicRef then
        oldMusicTween._oncomplete()
        oldMusicTween:stop()
      end

      if worldMusicRef then
        oldMusicRef = worldMusicRef
        -- fade out
        local startingVolume = oldMusicRef:getVolume()
        oldMusicTween = flux.to({ }, 1, { }):ease("linear")
          :onupdate(function()
            oldMusicRef:setVolume(startingVolume * ( 1 - oldMusicTween.progress))
          end)
          :oncomplete(function()
            oldMusicRef:stop()
            oldMusicRef:seek(0) -- should it seek?
            oldMusicRef:setVolume(startingVolume)
            oldMusicRef = nil
          end)
      end

      local newMusicKey = require("src.worldManager").get(self.world).musicKey
      if newMusicKey then
        -- fade in
        newMusicRef = audioManager.play(newMusicKey)

        local startingVolume = newMusicRef:getVolume()
        newMusicRef:setVolume(0)
        newMusicTween = flux.to({ }, 1, { }):ease("linear")
          :onupdate(function()
            newMusicRef:setVolume(startingVolume * newMusicTween.progress)
          end)
          :oncomplete(function()
            worldMusicRef = newMusicRef
            newMusicRef = nil
            audioManager.setVolumeAll() -- todo what if this breaks other eases?
          end)
      else
        worldMusicRef = nil
      end
    end
  end

  return self
end

character.update = function(self, dt)
  -- self.root.y = self.root.y + dt
  -- self.root.scale = self.root.scale + dt * 0.5
end

local collectDrawItems
collectDrawItems = function(part, transform, z, drawingQueue, spritesheet)
  if not part.shouldDraw then
    return
  end

  local offsetX, offsetY = unpack(part.offset)
  local pivotX, pivotY = unpack(part.pivot)

  -- Animated layers
  local ax = part.a0x + part.a1x + part.a2x
  local ay = part.a0y + part.a1y + part.a2y
  local ar = math.rad(part.a0r + part.a1r + part.a2r)
  local ascale = part.a0scale * part.a1scale * part.a2scale

  transform:translate(part.x + ax + offsetX, part.y + ay + offsetY)
  transform:scale(part.scale * ascale)
  transform:rotate(part.r + ar)

  z = z + part.zOffset

  transform:translate(-pivotX, -pivotY)
  table.insert(drawingQueue, {
    name = part.name,
    texture = part.texture or spritesheet,
    quad = part.quad,
    transform = transform:clone(),
    zPosition = z,
  })
  transform:translate(pivotX, pivotY)

  for _, child in ipairs(part.children) do
    collectDrawItems(child, transform:clone(), z, drawingQueue, spritesheet)
  end
end

local characterCanvasSize = 1700
local characterCanvas = lg.newCanvas(characterCanvasSize, characterCanvasSize)
local characterCanvasPlane = createPlaneForQuad(0, 0, characterCanvasSize, characterCanvasSize, characterCanvas)

character.draw = function(self)
  local drawingQueue = { }

  collectDrawItems(self.root, love.math.newTransform(), 0, drawingQueue, self.spritesheet)
  table.sort(drawingQueue, function(a, b) return a.zPosition < b.zPosition end)

  lg.push("all")
  lg.origin()
  lg.setCanvas(characterCanvas)
  lg.clear(0, 0, 0, 0)
  local w, h = characterCanvas:getDimensions()
  lg.translate(w/2, h/2)
  if self.flip then -- cheap flip; see below :setRotation for fancy flip
    -- lg.scale(-1, 1)
  end
  for _, item in ipairs(drawingQueue) do
    lg.push()
    lg.applyTransform(item.transform)

    if item.quad then
      lg.draw(item.texture, item.quad)
    else
      lg.draw(item.texture)
    end
    lg.pop()
  end
  lg.pop()


  lg.push()
  lg.setColor(1,1,1,self.alpha)
  characterCanvasPlane:setTranslation(self.x, self.y, self.z)
  characterCanvasPlane:setRotation(0, self.flipRY, 0)
  characterCanvasPlane:draw()
  lg.setColor(1,1,1,1)
  lg.pop()
end

return character