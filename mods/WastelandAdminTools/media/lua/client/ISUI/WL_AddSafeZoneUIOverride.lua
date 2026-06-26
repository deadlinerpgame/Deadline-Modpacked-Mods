---
--- AddSafeZoneUIOverride.lua
--- 26/10/2023
---

require "ISUI/AdminPanel/ISAddSafeZoneUI"

function ISAddSafeZoneUI:checkIfAdmin()
	if self.character:getAccessLevel() ~= "Admin" and self.character:getAccessLevel() ~= "Moderator" then
		self:close();
	end;
end

function ISAddSafeZoneUI:updateButtons()
	self.ok.enable = self.size > 1
			and string.trim(self.ownerEntry:getInternalText()) ~= ""
			and string.trim(self.titleEntry:getInternalText()) ~= ""
			and self.notIntersecting
			and (self.character:getAccessLevel() == "Admin" or self.character:getAccessLevel() == "Moderator");
end

function ISAddSafeZoneUI:initialise()
	ISPanel.initialise(self);
	if self.character:getAccessLevel() ~= "Admin" and self.character:getAccessLevel() ~= "Moderator" then self:close(); return; end;

	local btnWid = 100
	local btnHgt = 25
	local btnHgt2 = 18
	local padBottom = 10

	--btnWid = getTextManager():MeasureStringX(UIFont.Medium, getText("UI_Cancel")) + 20;
	btnWid = 100;
	self.cancel = ISButton:new(self:getWidth() - btnWid - 10, self:getHeight() - padBottom - btnHgt, btnWid, btnHgt, getText("UI_Cancel"), self, ISAddSafeZoneUI.onClick);
	self.cancel.internal = "CANCEL";
	self.cancel.anchorTop = false
	self.cancel.anchorBottom = true
	self.cancel:initialise();
	self.cancel:instantiate();
	self.cancel.borderColor = {r=1, g=1, b=1, a=0.1};
	self:addChild(self.cancel);

	--btnWid = getTextManager():MeasureStringX(UIFont.Medium, getText("IGUI_PvpZone_AddZone")) + 20;
	btnWid = 100;
	self.ok = ISButton:new(10, self:getHeight() - padBottom - btnHgt, btnWid, btnHgt, getText("IGUI_PvpZone_AddZone"), self, ISAddSafeZoneUI.onClick);
	self.ok.internal = "OK";
	self.ok.anchorTop = false
	self.ok.anchorBottom = true
	self.ok:initialise();
	self.ok:instantiate();
	self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
	self:addChild(self.ok);

	btnWid = getTextManager():MeasureStringX(UIFont.Medium, getText("IGUI_PvpZone_RedefineStartingPoint")) + 20;
	self.startingPoint = ISButton:new((self.width/2) - (btnWid/2), self:getHeight() - padBottom - btnHgt, btnWid, btnHgt, getText("IGUI_PvpZone_RedefineStartingPoint"), self, ISAddSafeZoneUI.onClick);
	self.startingPoint.internal = "STARTINGPOINT";
	self.startingPoint.anchorTop = false
	self.startingPoint.anchorBottom = true
	self.startingPoint:initialise();
	self.startingPoint:instantiate();
	self.startingPoint.borderColor = {r=1, g=1, b=1, a=0.1};
	self:addChild(self.startingPoint);

	self.titleEntry = ISTextEntryBox:new("Safezone #" .. SafeHouse.getSafehouseList():size() + 1, 10, 10, 200, 18);
	self.titleEntry:initialise();
	self.titleEntry:instantiate();
	self:addChild(self.titleEntry);

	self.ownerEntry = ISTextEntryBox:new(self.character:getUsername(), 10, 10, 200, 18);
	self.ownerEntry:initialise();
	self.ownerEntry:instantiate();
	self:addChild(self.ownerEntry);

	self.claimOptions = ISTickBox:new(10, 270, 20, 18, "", self, ISAddSafeZoneUI.onClickClaimOptions);
	self.claimOptions:initialise();
	self.claimOptions:instantiate();
	self.claimOptions.selected[1] = false;
	self.claimOptions.selected[2] = true;
	self.claimOptions.selected[3] = true;
	self.claimOptions:addOption(getText("IGUI_Safezone_FullHighlight"));

	self:addChild(self.claimOptions);
end