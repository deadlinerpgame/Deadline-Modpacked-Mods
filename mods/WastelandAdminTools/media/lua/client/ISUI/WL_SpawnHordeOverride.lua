
local originalISSpawnHordeUI_createChildren = ISSpawnHordeUI.createChildren
function ISSpawnHordeUI:createChildren()
    originalISSpawnHordeUI_createChildren(self)
	self.healthSlider:setValues(0, 4, 0.1, 0.1, true)
end