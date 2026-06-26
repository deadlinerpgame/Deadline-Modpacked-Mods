---@class WastelandZones.Classes.WeatherOverride: WastelandZones.Classes.Plugin
local WeatherOverride = WastelandZones.Classes.WeatherOverride or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.WeatherOverride")
if not WastelandZones.Classes.WeatherOverride then
    WastelandZones.Classes.WeatherOverride = WeatherOverride
end

local runtime = {
    weatherApplied = {}
}

local function toNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then return fallback or 0 end
    return n
end

local function applyWeatherTabData(weatherTab, data)
    weatherTab.tickBoxWind.selected[1] = data.windEnabled == true
    weatherTab.tickBoxClouds.selected[1] = data.cloudsEnabled == true
    weatherTab.tickBoxFog.selected[1] = data.fogEnabled == true
    weatherTab.tickBoxPrecip.selected[1] = data.precipitationEnabled == true
    weatherTab.tickBoxPrecipIsSnow.selected[1] = data.precipitationIsSnow == true
    weatherTab.tickBoxTemp.selected[1] = data.temperatureEnabled == true
    weatherTab.tickBoxDarkness.selected[1] = data.darknessEnabled == true
    weatherTab.tickBoxDesaturation.selected[1] = data.desaturationEnabled == true
    weatherTab.tickBoxLightR_ext.selected[1] = data.lightEnabled == true

    weatherTab.sliderWindSlider:setCurrentValue(toNumber(data.wind, 0))
    weatherTab.sliderCloudsSlider:setCurrentValue(toNumber(data.clouds, 0))
    weatherTab.sliderFogSlider:setCurrentValue(toNumber(data.fog, 0))
    weatherTab.sliderPrecipSlider:setCurrentValue(toNumber(data.precipitation, 0))
    weatherTab.sliderTempSlider:setCurrentValue(toNumber(data.temperature, 0))
    weatherTab.sliderDarknessSlider:setCurrentValue(toNumber(data.darkness, 0))
    weatherTab.sliderDesaturationSlider:setCurrentValue(toNumber(data.desaturation, 0))
    weatherTab.sliderLightR_extSlider:setCurrentValue(toNumber(data.lightExtR, 0))
    weatherTab.sliderLightG_extSlider:setCurrentValue(toNumber(data.lightExtG, 0))
    weatherTab.sliderLightB_extSlider:setCurrentValue(toNumber(data.lightExtB, 0))
    weatherTab.sliderLightA_extSlider:setCurrentValue(toNumber(data.lightExtA, 0))
    weatherTab.sliderLightR_intSlider:setCurrentValue(toNumber(data.lightIntR, 0))
    weatherTab.sliderLightG_intSlider:setCurrentValue(toNumber(data.lightIntG, 0))
    weatherTab.sliderLightB_intSlider:setCurrentValue(toNumber(data.lightIntB, 0))
    weatherTab.sliderLightA_intSlider:setCurrentValue(toNumber(data.lightIntA, 0))

    weatherTab:onSliderChange(weatherTab.sliderWindSlider:getCurrentValue(), weatherTab.sliderWindSlider)
    weatherTab:onSliderChange(weatherTab.sliderCloudsSlider:getCurrentValue(), weatherTab.sliderCloudsSlider)
    weatherTab:onSliderChange(weatherTab.sliderFogSlider:getCurrentValue(), weatherTab.sliderFogSlider)
    weatherTab:onSliderChange(weatherTab.sliderPrecipSlider:getCurrentValue(), weatherTab.sliderPrecipSlider)
    weatherTab:onSliderChange(weatherTab.sliderTempSlider:getCurrentValue(), weatherTab.sliderTempSlider)
    weatherTab:onSliderChange(weatherTab.sliderDarknessSlider:getCurrentValue(), weatherTab.sliderDarknessSlider)
    weatherTab:onSliderChange(weatherTab.sliderDesaturationSlider:getCurrentValue(), weatherTab.sliderDesaturationSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightR_extSlider:getCurrentValue(), weatherTab.sliderLightR_extSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightG_extSlider:getCurrentValue(), weatherTab.sliderLightG_extSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightB_extSlider:getCurrentValue(), weatherTab.sliderLightB_extSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightA_extSlider:getCurrentValue(), weatherTab.sliderLightA_extSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightR_intSlider:getCurrentValue(), weatherTab.sliderLightR_intSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightG_intSlider:getCurrentValue(), weatherTab.sliderLightG_intSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightB_intSlider:getCurrentValue(), weatherTab.sliderLightB_intSlider)
    weatherTab:onSliderChange(weatherTab.sliderLightA_intSlider:getCurrentValue(), weatherTab.sliderLightA_intSlider)
end

---@return WastelandZones.Classes.WeatherOverride
function WeatherOverride:new()
    local o = WeatherOverride.parentClass.new(self)
    o.type = "WeatherOverride"
    o.priority = 80
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function WeatherOverride:buildPanel(zone, panel, data)
    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 6, margin = { 10, 20, 10, 10 }, rows = {
        { type = "columns", width = "inherit", height = 24, pad = 8, columns = {
            { type = "label", id = "transitionLabel", width = 120, text = "Transition Ticks" },
            { type = "textbox", id = "transitionInput", width = 120, text = tostring(math.floor(toNumber(data.transitionTicks, 600))), onlyNumbers = true },
            { type = "gap", width = "*" }
        }},
        { type = "element", id = "weatherTabHost", width = "inherit", height = 540 }
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)
    panel.transitionLabel = panel.elements.transitionLabel
    panel.transitionInput = panel.elements.transitionInput
    panel.transitionInput.tooltip = "How quickly weather transitions when entering/exiting this zone."

    local host = panel.elements.weatherTabHost
    if panel.weatherTab and panel.weatherTab.parent then
        panel.weatherTab.parent:removeChild(panel.weatherTab)
        panel.weatherTab = nil
    end

    local weatherTab = ISAdmPanelClimate:new(0, 0, host.width, host.height)
    weatherTab:initialise()
    weatherTab.onClick = function() end
    weatherTab.onMadeActive = function() end
    weatherTab.onTicked = function() end
    weatherTab.onSliderChange = function() end
    weatherTab.oCreateChildren = weatherTab.createChildren
    weatherTab.prerender = ISDebugSubPanelBase.prerender
    weatherTab.createChildren = function(_s)
        _s:oCreateChildren()

        for _, child in pairs(_s.children) do
            if child.Type == "ISButton" then
                _s:removeChild(child)
            end
        end

        applyWeatherTabData(_s, data)
    end

    host:addChild(weatherTab)
    weatherTab:setX(0)
    weatherTab:setY(0)
    weatherTab:setWidth(host.width)
    weatherTab:setHeight(host.height)
    panel.weatherTab = weatherTab
end

---@param panel ISUIElement
---@return table
function WeatherOverride:getSaveData(panel)
    local weatherTab = panel.weatherTab
    local data = {}
    data.transitionTicks = math.floor(toNumber(panel.transitionInput:getText(), 600))
    if weatherTab.tickBoxWind:isSelected(1) then
        data.windEnabled = true
        data.wind = weatherTab.sliderWindSlider:getCurrentValue()
    end
    if weatherTab.tickBoxClouds:isSelected(1) then
        data.cloudsEnabled = true
        data.clouds = weatherTab.sliderCloudsSlider:getCurrentValue()
    end
    if weatherTab.tickBoxFog:isSelected(1) then
        data.fogEnabled = true
        data.fog = weatherTab.sliderFogSlider:getCurrentValue()
    end
    if weatherTab.tickBoxPrecip:isSelected(1) then
        data.precipitationEnabled = true
        data.precipitation = weatherTab.sliderPrecipSlider:getCurrentValue()
        data.precipitationIsSnow = weatherTab.tickBoxPrecipIsSnow:isSelected(1)
    end
    if weatherTab.tickBoxTemp:isSelected(1) then
        data.temperatureEnabled = true
        data.temperature = weatherTab.sliderTempSlider:getCurrentValue()
    end
    if weatherTab.tickBoxDarkness:isSelected(1) then
        data.darknessEnabled = true
        data.darkness = weatherTab.sliderDarknessSlider:getCurrentValue()
    end
    if weatherTab.tickBoxDesaturation:isSelected(1) then
        data.desaturationEnabled = true
        data.desaturation = weatherTab.sliderDesaturationSlider:getCurrentValue()
    end
    if weatherTab.tickBoxLightR_ext:isSelected(1) then
        data.lightEnabled = true
        data.lightExtR = weatherTab.sliderLightR_extSlider:getCurrentValue()
        data.lightExtG = weatherTab.sliderLightG_extSlider:getCurrentValue()
        data.lightExtB = weatherTab.sliderLightB_extSlider:getCurrentValue()
        data.lightExtA = weatherTab.sliderLightA_extSlider:getCurrentValue()
        data.lightIntR = weatherTab.sliderLightR_intSlider:getCurrentValue()
        data.lightIntG = weatherTab.sliderLightG_intSlider:getCurrentValue()
        data.lightIntB = weatherTab.sliderLightB_intSlider:getCurrentValue()
        data.lightIntA = weatherTab.sliderLightA_intSlider:getCurrentValue()
    end
    return data
end

---@param data table
---@return table
function WeatherOverride:buildOverridePayload(data)
    local payload = {}

    if data.windEnabled then
        payload.Wind = { intensity = toNumber(data.wind, 0) }
    end
    if data.cloudsEnabled then
        payload.Clouds = { intensity = toNumber(data.clouds, 0) }
    end
    if data.fogEnabled then
        payload.Fog = { intensity = toNumber(data.fog, 0) }
    end
    if data.precipitationEnabled then
        payload.Precipitation = {
            intensity = toNumber(data.precipitation, 0),
            isSnow = data.precipitationIsSnow == true
        }
    end
    if data.temperatureEnabled then
        payload.Temperature = { value = toNumber(data.temperature, 0) }
    end
    if data.darknessEnabled then
        payload.Darkness = { value = toNumber(data.darkness, 0) }
    end
    if data.desaturationEnabled then
        payload.Desaturation = { value = toNumber(data.desaturation, 0) }
    end
    if data.lightEnabled then
        payload.Light = {
            extR = toNumber(data.lightExtR, 0),
            extG = toNumber(data.lightExtG, 0),
            extB = toNumber(data.lightExtB, 0),
            extA = toNumber(data.lightExtA, 0),
            intR = toNumber(data.lightIntR, 0),
            intG = toNumber(data.lightIntG, 0),
            intB = toNumber(data.lightIntB, 0),
            intA = toNumber(data.lightIntA, 0)
        }
    end

    return payload
end

---@param oldZone WastelandZones.Classes.Zone|nil
---@param newZone WastelandZones.Classes.Zone
---@param oldData table|nil
---@param newData table|nil
function WeatherOverride:onRecreated(oldZone, newZone, oldData, newData)
    local key = "zone_" .. tostring(newZone.id)
    local ticks = toNumber((newData and newData.transitionTicks) or (oldData and oldData.transitionTicks), 600)

    for playerNum, zonesApplied in pairs(runtime.weatherApplied) do
        if zonesApplied[newZone.id] then
            if newZone.enabled == true and newData then
                local payload = self:buildOverridePayload(newData)
                WL_WeatherOverride.SetBulkOverrides(key, payload, ticks)
            else
                WL_WeatherOverride.UnsetAllOverrides(key, ticks)
                zonesApplied[newZone.id] = nil
            end
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function WeatherOverride:onPlayerEnter(zone, player, data)
    local playerNum = player:getPlayerNum()
    runtime.weatherApplied[playerNum] = runtime.weatherApplied[playerNum] or {}
    if runtime.weatherApplied[playerNum][zone.id] then
        return
    end

    local key = "zone_" .. tostring(zone.id)
    local payload = self:buildOverridePayload(data)
    WL_WeatherOverride.SetBulkOverrides(key, payload, toNumber(data.transitionTicks, 600))
    runtime.weatherApplied[playerNum][zone.id] = true
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function WeatherOverride:onPlayerExit(zone, player, data)
    local key = "zone_" .. tostring(zone.id)
    WL_WeatherOverride.UnsetAllOverrides(key, toNumber(data.transitionTicks, 600))

    local playerNum = player:getPlayerNum()
    if runtime.weatherApplied[playerNum] then
        runtime.weatherApplied[playerNum][zone.id] = nil
    end
end

WastelandZones.Plugins:register(WeatherOverride:new())
