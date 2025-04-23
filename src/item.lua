local item = { }
item.__index = item

item.new = function()

end

item.newFromDefinition = function(definition)

end

item.hasTag = function(self, tag)

end

item.draw = function(self)
  lg.push()
  lg.draw(itemIcons[self.type] or itemIcons["unknown"])
  lg.pop()
end

return item