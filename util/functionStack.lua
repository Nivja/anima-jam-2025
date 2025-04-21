local functionStack = { }
functionStack.__index = functionStack

functionStack.new = function()
  return setmetatable({
      stack = { }
    }, functionStack)
end

functionStack.push = function(self, func, userdata)
  assert(type(func) == "function")
  table.insert(self.stack, 1, { func, userdata })
end

functionStack.isEmpty = function(self)
  return #self.stack == 0
end

functionStack.pop = function(self)
  assert(not self:isEmpty())
  local func = self.stack[1][1]
  if type(func) == "function" then func(self.stack[1][2]) end
  table.remove(self.stack, 1)
end

functionStack.popAll = function(self)
  if self:isEmpty() then return end
  for _, tbl in ipairs(self.stack) do
    if type(tbl[1]) == "function" then
      tbl[1](tbl[2])
    end
  end
  self:clear()
end

functionStack.clear = function(self)
  self.stack = { }
end

return functionStack