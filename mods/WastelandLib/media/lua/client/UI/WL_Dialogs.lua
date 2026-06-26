require "UI/WL_ItemPickerDialog"

---
--- WL_Dialogs.lua
--- 25/07/2024
---

WL_Dialogs = WL_Dialogs or {}
WL_Dialogs.currentModal = nil


function WL_Dialogs:promptItem(preselectedItem, callback, options)
	if type(preselectedItem) == "function" then
		options = callback
		callback = preselectedItem
		preselectedItem = nil
	end

	return WL_ItemPickerDialog:show(preselectedItem, callback, options)
end


function WL_Dialogs.showConfirmationDialog(message, onConfirm)
	if WL_Dialogs.currentModal then
		WL_Dialogs.currentModal:destroy()
	end

	local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 150, getCore():getScreenHeight() / 2 - 75,
			300, 150, message, true, nil,
			function(_, button)
				if button.internal == "YES" and onConfirm then
					onConfirm()
				end
			end
	)
	modal:initialise()
	modal:addToUIManager()
	--modal.ui = self
	modal.moveWithMouse = true

	local originalDestroy = modal.destroy
	modal.destroy = function(self)
		originalDestroy(self)
		WL_Dialogs.currentModal = nil
	end

	WL_Dialogs.currentModal = modal
end

function WL_Dialogs.showMessageDialog(message)
	if WL_Dialogs.currentModal then
		WL_Dialogs.currentModal:destroy()
	end

	local modal = ISModalDialog:new(
			(getCore():getScreenWidth() / 2) - 125,
			(getCore():getScreenHeight() / 2) - 25,
			250, 50, message, false, nil, nil
	)
	modal:initialise()
	modal:addToUIManager()
	modal.moveWithMouse = true

	local originalDestroy = modal.destroy
	modal.destroy = function(self)
		originalDestroy(self)
		WL_Dialogs.currentModal = nil
	end

	WL_Dialogs.currentModal = modal
end
