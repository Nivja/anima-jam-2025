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
    -- if tag:sub(1, #startingWith) == startingWith then
    if tag:find(pattern) ~= nil then
      return tag
    end
  end
  return nil
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

  logger.info("Inventory: Added item,", item.name or item.id or "UNKNOWN")
end

return inventory