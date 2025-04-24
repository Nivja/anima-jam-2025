local inventory = { }
inventory.__index = inventory

inventory.get = function(id)
  if id == "lastAdded" then
    return inventory.lastAddedItem
  end
  return inventory.lookup[id]
end

inventory.addItem = function(item)
  
end

return inventory