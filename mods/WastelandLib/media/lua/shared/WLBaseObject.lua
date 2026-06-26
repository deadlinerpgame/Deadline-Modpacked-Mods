---
--- WLBaseObject.lua
--- Base class for all Wasteland classes.
--- Differs from ISBaseObject in that our derive offers the subclass access to the parent class, which makes it possible
--- to chain constructor calls neatly.
---
--- If you want to override and call a function in the superclass, you can use the following pattern:
--- function Zombie:teleport(x, y)
---     Zombie.parentClass.teleport(self, x, y)  -- call inherited method "teleport"
---     print("brains!")
--- end
---
--- 17/10/2023
---

---@class WLBaseObject
WLBaseObject = {}
WLBaseObject._type = "WLBaseObject"

---
--- Use this function to create a subclass of WLBaseObject, for example:
--- MyClass = WLBaseObject:derive("MyClass")
--- @param type string matching the class name of your new subclass
--- @return table your new derived class
---
function WLBaseObject:derive(type)
	self.__index = self
	return setmetatable({
		_type = type or "none",
		parentClass = self,
		super = self.new,
		__tostring = self.__tostring
	}, self)
end

---
--- Used to instantiate a WLBaseObject, usually called in a subclass constructor, for example:
--- function MyClass:new()
---     local o = MyClass.parentClass.new(self)
---     return o
--- end
--- @return table a new instance of this class which you can add extra properties to in the subclass constructor
---
function WLBaseObject:new()
	self.__index = self
	return setmetatable({}, self)
end

function WLBaseObject:__tostring()
	if rawget(self, "_type") then
		return "Class: "..tostring(self._type)
	else
		return "Type: "..tostring(self._type)
	end
end
