---
--- WIT_MaskVignette.lua
--- Does a vignette effect and plays sounds when a mask is put on or taken off
--- 06/10/2024
---
WIT_MaskVignette = {}
WIT_MaskVignette.NONE = 0
WIT_MaskVignette.GAS_MASK = 1
WIT_MaskVignette.HAZMAT_SUIT = 2

local fullMaskTexture = getTexture("media/textures/GUI/MaskVignette.png")
local hazmatMaskTexture = getTexture("media/textures/GUI/HazmatVignette.png")

local width;
local height;
local currentMask = WIT_MaskVignette.NONE

local function drawMaskTexture()
	if currentMask == WIT_MaskVignette.GAS_MASK then
		UIManager.DrawTexture( fullMaskTexture, 0, 0, width, height, 1.0)
	elseif currentMask == WIT_MaskVignette.HAZMAT_SUIT then
		UIManager.DrawTexture( hazmatMaskTexture, 0, 0, width, height, 1.0)
	end
end

local function setWidthAndHeight()
	width = getCore():getScreenWidth();
	height = getCore():getScreenHeight();
end

local function resolutionChanged(_ox, _oy, x, y)
	width = x;
	height = y;
end

Events.OnGameBoot.Add(setWidthAndHeight);
Events.OnResolutionChange.Add(resolutionChanged);
Events.OnPreUIDraw.Add(drawMaskTexture);

function WIT_MaskVignette.setMaskOn(newMaskEfficiency)
	local newMask = WIT_MaskVignette.NONE
	if newMaskEfficiency > 1.8 then
		newMask = WIT_MaskVignette.HAZMAT_SUIT
	elseif newMaskEfficiency > 0.8 then
		newMask = WIT_MaskVignette.GAS_MASK
	end
	if currentMask ~= newMask then
		currentMask = newMask;
		if currentMask ~= WIT_MaskVignette.NONE then
			getSoundManager():playUISound("GasMaskBreathing")
		else
			getSoundManager():playUISound("ExhaleMaskOff")
		end
	end
end

function WIT_MaskVignette.setMaskType(maskType)
	local newMask = WIT_MaskVignette.NONE
	if maskType == "HazmatSuit" then
		newMask = WIT_MaskVignette.HAZMAT_SUIT
	elseif maskType == "GasMask" then
		newMask = WIT_MaskVignette.GAS_MASK
	end
	if currentMask ~= newMask then
		currentMask = newMask;
		if currentMask ~= WIT_MaskVignette.NONE then
			getSoundManager():playUISound("GasMaskBreathing")
		else
			getSoundManager():playUISound("ExhaleMaskOff")
		end
	end
end
