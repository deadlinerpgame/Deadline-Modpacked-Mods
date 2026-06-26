if not isClient() then return end

require "GravyUI"
require "ISUI/ISPanel"
require "UI/WEZ_ManageZone"
require "WEZ_MonitorPlayer"
require "WL_Utils"

WEZ_ListZones = ISPanel:derive("WEZ_ListZones")

WEZ_ListZones.instance = nil

---@param filter fun(zone:WEZ_EventZone):boolean optional A filter function to filter which zones are shown
function WEZ_ListZones:show(filter)
    if WEZ_ManageZone.instance then
        WEZ_ManageZone.instance:onClose()
    end
    if WEZ_ListZones.instance then
        WEZ_ListZones.instance:onClose()
    end
    local scale = getTextManager():MeasureStringY(UIFont.Small, "XXX") / 12
    local w = 250 * scale
    local h = 80 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    o.__index = self
    o.filter = filter or function(zone) return true end
    o:initialise()
    o:addToUIManager()
    WEZ_ListZones.instance = o
    return o
end

function WEZ_ListZones:initialise()
    self.moveWithMouse = true

    local window = GravyUI.Node(self.width, self.height):pad(5)
    local header, body, footer = window:rows({30, 1, 20}, 5)
    local leftBtn, rightBtn = footer:cols(2, 5)

    self.headerLabel = header

    self.selector = body:makeComboBox()
    self.goButton = leftBtn:makeButton("Go", self, self.onGo)
    self.cancelButton = rightBtn:makeButton("Close", self, self.onClose)

    self:addChild(self.selector)
    self:addChild(self.goButton)
    self:addChild(self.cancelButton)

    local didAdd = false
    local items = {}
    for _,zone in pairs(WEZ_EventZones) do
        if (not zone.external) and self.filter(zone) then
            didAdd = true
            table.insert(items, {
                zone.name .. " (" .. zone.minX .. "," .. zone.minY .. " - " .. zone.maxX .. "," .. zone.maxY .. ")",
                zone
            })
        end
    end
    if didAdd then
        table.sort(items, function(a,b) return string.lower(a[1]) < string.lower(b[1]) end)
        for _,item in ipairs(items) do
            self.selector:addOptionWithData(item[1], item[2])
        end
    else
        self.selector:addOption("No Zones")
        self.goButton:setEnable(false)
    end
end

function WEZ_ListZones:prerender()
    ISPanel.prerender(self)
    self:drawTextCentre("Event Zones", self.headerLabel.left + (self.headerLabel.width/2), self.headerLabel.top, 1, 1, 1, 1, UIFont.Medium)
end

function WEZ_ListZones:onGo()
    local zone = self.selector:getOptionData(self.selector.selected)
    WEZ_ManageZone:show(zone)
    local player = getPlayer()
    local x = zone.minX + ((zone.maxX - zone.minX) / 2)
    local y = zone.minY + ((zone.maxY - zone.minY) / 2)
    WL_Utils.teleportPlayerToCoords(player, x, y, 0)
end

function WEZ_ListZones:onClose()
    WEZ_ListZones.instance = nil
    self:removeFromUIManager()
end