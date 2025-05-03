local logger = require("util.logger")

local inventory = {
  items = { },
  lookup = { },
}
inventory.__index = inventory

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
  table.insert(inventory.items, item)
  if item.id then
    inventory.lookup[item.id] = item
  end
  inventory.lastAddedItem = item

  logger.info("Inventory: Added item,", item.name or item.id or "UNKNOWN")
end

return inventory