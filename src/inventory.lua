local logger = require("util.logger")

local inventory = {
  items = { },
  lookup = { },
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

  logger.info("Inventory: Added item,", item.name or item.id or "UNKNOWN")
end

return inventory