local logger = require("util.logger")

local inventory = {
  items = { },
  lookup = { },
  fabric = { },
}
inventory.__index = inventory

local inventoryItem = { }
inventoryItem.__index = inventoryItem

inventoryItem.hasTag = function(self, lookForTag)
  for _, tag in ipairs(self.tags) do
    if tag == lookForTag then
      return true
    end
  end
  return false
end

inventoryItem.getTagStartingWith = function(self, startingWith)
  local pattern = "^" .. startingWith
  for _, tag in ipairs(self.tags) do
    local matchStart, matchEnd = tag:find(pattern)
    if matchStart ~= nil then
      return tag, tag:sub(matchEnd + 1)
    end
  end
  return nil, nil
end

inventory.get = function(id)
  if id == "lastAdded" then
    return inventory.lastAddedItem
  end
  return inventory.lookup[id]
end

inventory.addItem = function(item)
  if not item then
    logger.warn("Tried to add nil item")
    return
  end

  setmetatable(item, inventoryItem)

  table.insert(inventory.items, item)
  if item.id then
    inventory.lookup[item.id] = item

    local path = "assets/items/"..item.id..".png"
    if love.filesystem.getInfo(path, "file") then
      item.texture = love.graphics.newImage(path)
      item.texture:setFilter("nearest")
    end
  end
  inventory.lastAddedItem = item

  if item:hasTag("fabric") then
    local texture = item:getTagStartingWith("texture.")
    if texture then
      local textureType = texture:sub(#("texture.")+1)
      if not inventory.fabric[textureType] then
        inventory.fabric[textureType] = 1
      else
        inventory.fabric[textureType] = inventory.fabric[textureType] + 1
      end
    else
      logger.warn("Fabric doesn't have a tag starting with `texture.` which defines it's render type")
    end
  end

  logger.info("Inventory: Added item", item.name or item.id or "UNKNOWN")
end

inventory.removeItem = function(id)
  local item = inventory.lookup[id]
  if not item then
    logger.warn("Couldn't remove", id, "as it isn't in the lookup")
    return
  end

  inventory.lookup[id] = nil

  if inventory.lastAddedItem == item then inventory.lastAddedItem = nil end

  for index, i in ipairs(inventory.items) do
    if i == item then
      table.remove(inventory.items, index)
      break
    end
  end
  logger.info("Inventory: Removed item", item.name or item.id or "UNKNOWN")
end

inventory.getPatchItems = function()
  local items = { }
  for _, item in ipairs(inventory.items) do
    if item:hasTag("issue.patch") then
      table.insert(items, item)
    end
  end
  return #items ~= 0 and items or nil
end

return inventory