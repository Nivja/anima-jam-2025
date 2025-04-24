local item = { }
item.__index = item

item.new = function()

end

item.newFromDefinition = function(definition)

end

item.hasTag = function(self, tagToFind)
  for _, tag in ipairs(self.tags) do
    if tag == tagToFind then
      return true
    end
  end
  return false
end

return item