-- TileEditorPicker.lua
-- Handles the "Tile Picker" mode with advanced search and favorites

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"

-- ============================================================================
-- Tile Categories (Copied from BrushToolChooseTileUI.lua)
-- ============================================================================
local TileCategories = {}
TileCategories["advertising_01"] = "[OTHER] "
TileCategories["advertising_02"] = "[OTHER] "
TileCategories["appliances_01"] = "[DECOR] "
TileCategories["appliances_com_01"] = "[FURNITURE] "
TileCategories["appliances_cooking_01"] = "[FURNITURE] "
TileCategories["appliances_cooking_ON_01"] = "[OTHER] "
TileCategories["appliances_laundry_01"] = "[FURNITURE] "
TileCategories["appliances_misc_01"] = "[FURNITURE] "
TileCategories["appliances_radio_01"] = "[FURNITURE] "
TileCategories["appliances_refrigeration_01"] = "[FURNITURE] "
TileCategories["appliances_television_01"] = "[FURNITURE] "
TileCategories["blends_grassoverlays_01"] = "[DECOR] "
TileCategories["blends_natural_01"] = "[FLOOR] "
TileCategories["blends_natural_02"] = "[FLOOR] "
TileCategories["blends_street_01"] = "[FLOOR] "
TileCategories["blends_streetoverlays_01"] = "[DECOR] "
TileCategories["books&misc_01"] = "[DECOR] "
TileCategories["books&misc_02"] = "[DECOR] "
TileCategories["brokenglass_1"] = "[DECOR] "
TileCategories["camping_01"] = "[FURNITURE] "
TileCategories["carpentry_01"] = "[FURNITURE] "
TileCategories["carpentry_02"] = "[FURNITURE] "
TileCategories["clothing_01"] = "[FURNITURE] "
TileCategories["clothing_02"] = "[FURNITURE] "
TileCategories["constructedobjects_01"] = "[FURNITURE] "
TileCategories["construction_01"] = "[FURNITURE] "
TileCategories["crafted_01"] = "[OTHER] "
TileCategories["d_floorleaves_1"] = "[DECOR] "
TileCategories["d_generic_1"] = "[DECOR] "
TileCategories["d_plants_1"] = "[DECOR] "
TileCategories["d_streetcracks_1"] = "[DECOR] "
TileCategories["d_trash_1"] = "[DECOR] "
TileCategories["d_wallcracks_1"] = "[DECOR] "
TileCategories["damaged_objects_01"] = "[DECOR] "
TileCategories["desks_01"] = "[DECOR] "
TileCategories["e_americanholly_1"] = "[PLANT] "
TileCategories["e_americanlinden_1"] = "[PLANT] "
TileCategories["e_canadianhemlock_1"] = "[PLANT] "
TileCategories["e_carolinasilverbell_1"] = "[PLANT] "
TileCategories["e_cockspurhawthorn_1"] = "[PLANT] "
TileCategories["e_dogwood_1"] = "[PLANT] "
TileCategories["e_easternredbud_1"] = "[PLANT] "
TileCategories["e_exterior_snow_1"] = "[FLOOR] "
TileCategories["e_newgrass_1"] = "[DECOR] "
TileCategories["e_newsnow_ground_1"] = "[FLOOR] "
TileCategories["e_redmaple_1"] = "[PLANT] "
TileCategories["e_riverbirch_1"] = "[PLANT] "
TileCategories["e_roof_snow_1"] = "[ROOF] "
TileCategories["e_virginiapine_1"] = "[PLANT] "
TileCategories["e_yellowwood_1"] = "[PLANT] "
TileCategories["electricity_pylon"] = "[OTHER] "
TileCategories["f_bushes_1"] = "[PLANT] "
TileCategories["f_bushes_2"] = "[PLANT] "
TileCategories["f_flowerbed_1"] = "[DECOR] "
TileCategories["f_wallvines_1"] = "[DECOR] "
TileCategories["fencing_01"] = "[WALL] "
TileCategories["fencing_burnt_01"] = "[WALL] "
TileCategories["fencing_damaged_01"] = "[WALL] "
TileCategories["fencing_damaged_02"] = "[WALL] "
TileCategories["fixtures_01"] = "[DECOR] "
TileCategories["fixtures_bathroom_01"] = "[FURNITURE] "
TileCategories["fixtures_bathroom_02"] = "[FURNITURE] "
TileCategories["fixtures_counters_01"] = "[FURNITURE] "
TileCategories["fixtures_doors_01"] = "[DOOR] "
TileCategories["fixtures_doors_02"] = "[DOOR] "
TileCategories["fixtures_doors_fences_01"] = "[DOOR] "
TileCategories["fixtures_doors_frames_01"] = "[DOOR] "
TileCategories["fixtures_escalators_01"] = "[OTHER] "
TileCategories["fixtures_fireplaces_01"] = "[OTHER] "
TileCategories["fixtures_overlay_counters_01"] = "[DECOR] "
TileCategories["fixtures_railings_01"] = "[DECOR] "
TileCategories["fixtures_sinks_01"] = "[FURNITURE] "
TileCategories["fixtures_stairs_01"] = "[OTHER] "
TileCategories["fixtures_windows_01"] = "[WINDOW] "
TileCategories["fixtures_windows_curtains_01"] = "[WINDOW] "
TileCategories["fixtures_windows_curtains_02"] = "[WINDOW] "
TileCategories["floors_burnt_01"] = "[FLOOR] "
TileCategories["floors_exterior_natural_01"] = "[FLOOR] "
TileCategories["floors_exterior_street_01"] = "[FLOOR] "
TileCategories["floors_exterior_tilesandstone_01"] = "[FLOOR] "
TileCategories["floors_interior_carpet_01"] = "[FLOOR] "
TileCategories["floors_interior_tilesandwood_01"] = "[FLOOR] "
TileCategories["floors_overlay_street_01"] = "[DECOR] "
TileCategories["floors_overlay_tiles_01"] = "[DECOR] "
TileCategories["floors_overlay_tiles_02"] = "[DECOR] "
TileCategories["floors_overlay_wood_01"] = "[DECOR] "
TileCategories["floors_rugs_01"] = "[FLOOR] "
TileCategories["food_01"] = "[DECOR] "
TileCategories["food_02"] = "[DECOR] "
TileCategories["furniture_bedding_01"] = "[FURNITURE] "
TileCategories["furniture_seating_indoor_01"] = "[FURNITURE] "
TileCategories["furniture_seating_indoor_02"] = "[FURNITURE] "
TileCategories["furniture_seating_indoor_03"] = "[FURNITURE] "
TileCategories["furniture_seating_outdoor_01"] = "[FURNITURE] "
TileCategories["furniture_shelving_01"] = "[FURNITURE] "
TileCategories["furniture_storage_01"] = "[FURNITURE] "
TileCategories["furniture_storage_02"] = "[FURNITURE] "
TileCategories["furniture_tables_high_01"] = "[FURNITURE] "
TileCategories["furniture_tables_low_01"] = "[FURNITURE] "
TileCategories["industry_01"] = "[OTHER] "
TileCategories["industry_02"] = "[OTHER] "
TileCategories["industry_bunker_01"] = "[OTHER] "
TileCategories["industry_railroad_01"] = "[DECOR] "
TileCategories["industry_railroad_02"] = "[DECOR] "
TileCategories["industry_railroad_03"] = "[DECOR] "
TileCategories["industry_railroad_04"] = "[DECOR] "
TileCategories["industry_railroad_05"] = "[OTHER] "
TileCategories["industry_trucks_01"] = "[OTHER] "
TileCategories["industry_trucks_02"] = "[OTHER] "
TileCategories["invisible_01"] = "[OTHER] "
TileCategories["lighting_indoor_01"] = "[DECOR] "
TileCategories["lighting_outdoor_01"] = "[DECOR] "
TileCategories["location_barn_01"] = "[WALL] "
TileCategories["location_business_bank_01"] = "[OTHER] "
TileCategories["location_business_distillery_01"] = "[DECOR] "
TileCategories["location_business_machinery_01"] = "[DECOR] "
TileCategories["location_business_office_generic_01"] = "[FURNITURE] "
TileCategories["location_community_cemetary_01"] = "[DECOR] "
TileCategories["location_community_church_small_01"] = "[WALL] "
TileCategories["location_community_medical_01"] = "[FURNITURE] "
TileCategories["location_community_park_01"] = "[DECOR] "
TileCategories["location_community_police_01"] = "[DECOR] "
TileCategories["location_community_school_01"] = "[DECOR] "
TileCategories["location_entertainment_gallery_01"] = "[DECOR] "
TileCategories["location_entertainment_gallery_02"] = "[DECOR] "
TileCategories["location_entertainment_theatre_01"] = "[FURNITURE] "
TileCategories["location_farm_accesories_01"] = "[DECOR] "
TileCategories["location_hospitality_sunstarmotel_01"] = "[WALL] "
TileCategories["location_hospitality_sunstarmotel_02"] = "[DECOR] "
TileCategories["location_military_generic_01"] = "[DECOR] "
TileCategories["location_military_knox_01"] = "[DECOR] "
TileCategories["location_military_tent_01"] = "[WALL] "
TileCategories["location_restaurant_bar_01"] = "[FURNITURE] "
TileCategories["location_restaurant_diner_01"] = "[DECOR] "
TileCategories["location_restaurant_generic_01"] = "[FURNITURE] "
TileCategories["location_restaurant_pie_01"] = "[OTHER] "
TileCategories["location_restaurant_pileocrepe_01"] = "[DECOR] "
TileCategories["location_restaurant_pizzawhirled_01"] = "[DECOR] "
TileCategories["location_restaurant_seahorse_01"] = "[WALL] "
TileCategories["location_restaurant_spiffos_01"] = "[WALL] "
TileCategories["location_restaurant_spiffos_02"] = "[DECOR] "
TileCategories["location_restaurant_spiffos_03"] = "[DECOR] "
TileCategories["location_services_beauty_01"] = "[FURNITURE] "
TileCategories["location_sewer_01"] = "[WALL] "
TileCategories["location_shop_accessories_01"] = "[FURNITURE] "
TileCategories["location_shop_accessories_genericsigns_01"] = "[DECOR] "
TileCategories["location_shop_bargNclothes_01"] = "[DECOR] "
TileCategories["location_shop_fossoil_01"] = "[OTHER] "
TileCategories["location_shop_gas2go_01"] = "[OTHER] "
TileCategories["location_shop_generic_01"] = "[FURNITURE] "
TileCategories["location_shop_greenes_01"] = "[WALL] "
TileCategories["location_shop_mall_01"] = "[OTHER] "
TileCategories["location_shop_zippee_01"] = "[FURNITURE] "
TileCategories["location_trailer_01"] = "[WALL] "
TileCategories["location_trailer_02"] = "[FURNITURE] "
TileCategories["office_01"] = "[DECOR] "
TileCategories["overlay_blood_fence_01"] = "[DECOR] "
TileCategories["overlay_blood_floor_01"] = "[DECOR] "
TileCategories["overlay_blood_wall_01"] = "[DECOR] "
TileCategories["overlay_graffiti_wall_01"] = "[DECOR] "
TileCategories["overlay_grime_floor_01"] = "[DECOR] "
TileCategories["overlay_grime_wall_01"] = "[DECOR] "
TileCategories["overlay_messages_wall_01"] = "[DECOR] "
TileCategories["papernotices_01"] = "[DECOR] "
TileCategories["preset_depthmaps_01"] = "[DECOR] "
TileCategories["radio_tower"] = "[DECOR] "
TileCategories["recreational_01"] = "[FURNITURE] "
TileCategories["recreational_sports_01"] = "[OTHER] "
TileCategories["roofs_01"] = "[ROOF] "
TileCategories["roofs_02"] = "[ROOF] "
TileCategories["roofs_03"] = "[ROOF] "
TileCategories["roofs_04"] = "[ROOF] "
TileCategories["roofs_05"] = "[ROOF] "
TileCategories["roofs_accents_01"] = "[ROOF] "
TileCategories["roofs_burnt_01"] = "[ROOF] "
TileCategories["seating_01"] = "[DECOR] "
TileCategories["security_01"] = "[DECOR] "
TileCategories["signs_miscbrands_01"] = "[DECOR] "
TileCategories["signs_one-off_01"] = "[DECOR] "
TileCategories["signs_one-off_02"] = "[DECOR] "
TileCategories["signs_one-off_03"] = "[DECOR] "
TileCategories["signs_one-off_04"] = "[DECOR] "
TileCategories["signs_one-off_05"] = "[DECOR] "
TileCategories["stashes_01"] = "[DECOR] "
TileCategories["storage_01"] = "[DECOR] "
TileCategories["street_curbs_01"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_dark_grass"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_dirt"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_gravel"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_light_grass"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_medium_grass"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_sand"] = "[FLOOR] "
TileCategories["street_curbs_01_blend_street"] = "[FLOOR] "
TileCategories["street_curbs_01_diag"] = "[FLOOR] "
TileCategories["street_curbs_01_diag_2"] = "[FLOOR] "
TileCategories["street_decoration_01"] = "[DECOR] "
TileCategories["street_roadsigns_01"] = "[DECOR] "
TileCategories["street_trafficlines_01"] = "[DECOR] "
TileCategories["street_trafficlines_curb_white_faded"] = "[DECOR] "
TileCategories["street_trafficlines_curb_white_full"] = "[DECOR] "
TileCategories["street_trafficlines_curb_yellow_faded"] = "[DECOR] "
TileCategories["street_trafficlines_curb_yellow_full"] = "[DECOR] "
TileCategories["trash&junk_01"] = "[DECOR] "
TileCategories["trash_01"] = "[DECOR] "
TileCategories["trash_walls_01"] = "[DECOR] "
TileCategories["trashcontainers_01"] = "[FURNITURE] "
TileCategories["underground_01"] = "[WALL] "
TileCategories["vegetation_farm_01"] = "[DECOR] "
TileCategories["vegetation_farming_01"] = "[DECOR] "
TileCategories["vegetation_indoor_01"] = "[DECOR] "
TileCategories["vegetation_ornamental_01"] = "[PLANT] "
TileCategories["walls_burnt_01"] = "[WALL] "
TileCategories["walls_burnt_roofs_01"] = "[WALL] "
TileCategories["walls_commercial_01"] = "[WALL] "
TileCategories["walls_commercial_02"] = "[WALL] "
TileCategories["walls_commercial_03"] = "[WALL] "
TileCategories["walls_decoration_01"] = "[WALL] "
TileCategories["walls_detailing_01"] = "[WALL] "
TileCategories["walls_exterior_house_01"] = "[WALL] "
TileCategories["walls_exterior_house_02"] = "[WALL] "
TileCategories["walls_exterior_roofs_01"] = "[WALL] "
TileCategories["walls_exterior_roofs_02"] = "[WALL] "
TileCategories["walls_exterior_roofs_03"] = "[WALL] "
TileCategories["walls_exterior_roofs_04"] = "[WALL] "
TileCategories["walls_exterior_roofs_05"] = "[WALL] "
TileCategories["walls_exterior_roofs_06"] = "[WALL] "
TileCategories["walls_exterior_roofs_07"] = "[WALL] "
TileCategories["walls_exterior_roofs_08"] = "[WALL] "
TileCategories["walls_exterior_roofs_09"] = "[WALL] "
TileCategories["walls_exterior_wooden_01"] = "[WALL] "
TileCategories["walls_exterior_wooden_02"] = "[WALL] "
TileCategories["walls_garage_01"] = "[WALL] "
TileCategories["walls_garage_02"] = "[WALL] "
TileCategories["walls_house_blocks_01"] = "[DECOR] "
TileCategories["walls_house_blocks_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_blocks_LIGHT_01"] = "[DECOR] "
TileCategories["walls_house_blocks_LIGHT_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_brick_01"] = "[DECOR] "
TileCategories["walls_house_brick_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_brick_LIGHT_01"] = "[DECOR] "
TileCategories["walls_house_brick_LIGHT_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_clapboard_01"] = "[DECOR] "
TileCategories["walls_house_clapboard_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_clapboard_LIGHT_01"] = "[DECOR] "
TileCategories["walls_house_clapboard_LIGHT_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_flatstone_01"] = "[DECOR] "
TileCategories["walls_house_flatstone_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_smooth_01"] = "[DECOR] "
TileCategories["walls_house_smooth_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_stone_01"] = "[DECOR] "
TileCategories["walls_house_stone_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_trailer_01"] = "[DECOR] "
TileCategories["walls_house_trailer_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_house_wood_01"] = "[DECOR] "
TileCategories["walls_house_wood_01_MIRRORED"] = "[DECOR] "
TileCategories["walls_interior_bathroom_01"] = "[WALL] "
TileCategories["walls_interior_cutaways_01"] = "[DECOR] "
TileCategories["walls_interior_detailing_01"] = "[DECOR] "
TileCategories["walls_interior_house_01"] = "[WALL] "
TileCategories["walls_interior_house_02"] = "[WALL] "
TileCategories["walls_interior_house_03"] = "[WALL] "
TileCategories["walls_interior_house_04"] = "[WALL] "
TileCategories["walls_special_01"] = "[DECOR] "
TileCategories["weapons_01"] = "[DECOR] "
TileCategories["z_templates_wallcutaways"] = "[WALL] "

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function fetchField(o, patt)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if string.find(tostring(f), patt) then
            return getClassFieldVal(o, f)
        end
    end
end

-- ============================================================================
-- TileEditorPickerList
-- ============================================================================

TileEditorPickerList = ISPanel:derive("TileEditorPickerList")

function TileEditorPickerList:new(x, y, w, h, mainEditor)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.mainEditor = mainEditor
    o.backgroundColor = {r=0, g=0, b=0, a=1.0}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.imageName = nil
    o.posToTileNameTable = {}
    o.sprite_array = nil -- For advanced search results
    return o
end

function TileEditorPickerList:render()
    self:setStencilRect(0, 0, self.width, self.height)
    if self.mainEditor.lightMode then
        self.backgroundColor = {r=1, g=1, b=1, a=1.0}
        self.borderColor = {r=0.6, g=0.6, b=0.6, a=1}
    else
        self.backgroundColor = {r=0, g=0, b=0, a=1.0}
        self.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    end
    ISPanel.render(self)

    local tileWidth = 64
    local tileHeight = 128
    local maxRow = 1
    
    -- Handle Advanced Search Results (ArrayList of sprites)
    if self.sprite_array then
        local hover_c = math.floor(self:getMouseX() / tileWidth)
        local hover_r = math.floor(self:getMouseY() / tileHeight)
        
        local r = 0
        local c = 0
        
        for i=0,self.sprite_array:size()-1 do
            local v = self.sprite_array:get(i)
            local tileName = v ~= 0 and v:getName()
            
            local texture = type(tileName) == "string" and getTexture(tileName)
            if texture and texture ~= 0 then
                self:drawTextureScaledAspect(texture, c * tileWidth, r * tileHeight, tileWidth, tileHeight, 1.0, 1.0, 1.0, 1.0)
            end
            
            if c == hover_c and r == hover_r then
                self:drawRectBorder(hover_c * tileWidth, hover_r * tileHeight, tileWidth, tileHeight, 0.6, 1, 1, 1)
            end
            
            maxRow = r + 1
            c = (c + 1) % 8
            if c == 0 then r = r + 1 end
        end
        
        self:setScrollHeight(maxRow * tileHeight)
        self:clearStencilRect()
        return
    end
    
    -- Handle Standard Sheet View
    if not self.imageName then
        self:clearStencilRect()
        return
    end
    
    for r = 1, 256 do
        for c = 1, 8 do
            local tileName = self.imageName .. "_" .. tostring((c-1) + (r-1)*8)

            if self.posToTileNameTable[r] == nil then self.posToTileNameTable[r] = {} end
            self.posToTileNameTable[r][c] = tileName

            local texture = getTexture(tileName)
            if texture then
                self:drawTextureScaledAspect(texture, (c - 1) * tileWidth, (r - 1) * tileHeight, tileWidth, tileHeight, 1.0, 1.0, 1.0, 1.0)
                maxRow = r
            end
        end
    end

    self:setScrollHeight(maxRow * tileHeight)

    local c = math.floor(self:getMouseX() / tileWidth)
    local r = math.floor(self:getMouseY() / tileHeight)
    if c >= 0 and c < 8 and r >= 0 and r < 128 and self.posToTileNameTable[r+1] ~= nil and self.posToTileNameTable[r+1][c+1] ~= nil then
        self:drawRectBorder(c * tileWidth, r * tileHeight, tileWidth, tileHeight, 0.6, 1, 1, 1)
    end
    
    self:clearStencilRect()
end

function TileEditorPickerList:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * 128)
    return true
end

function TileEditorPickerList:onMouseDown(x, y)
    local tileWidth = 64
    local tileHeight = 128
    local c = math.floor(x / tileWidth)
    local r = math.floor(y / tileHeight)
    
    local tileName = nil
    
    if self.sprite_array then
        local i = (r*8)+c
        if i < self.sprite_array:size() then
            local sprite = self.sprite_array:get(i)
            tileName = sprite ~= 0 and sprite:getName()
        end
    else
        if c >= 0 and c < 8 and r >= 0 and r < 128 then
            if self.posToTileNameTable[r+1] ~= nil and self.posToTileNameTable[r+1][c+1] ~= nil then
                tileName = self.posToTileNameTable[r+1][c+1]
            end
        end
    end
    
    if tileName then
        local player = getPlayer()
        local cursor = ISBrushToolTileCursor:new(tileName, tileName, player)
        getCell():setDrag(cursor, player:getPlayerNum())
    end
end

function TileEditorPickerList:onRightMouseDown(x, y)
    local tileWidth = 64
    local tileHeight = 128
    local c = math.floor(x / tileWidth)
    local r = math.floor(y / tileHeight)
    
    local tileName = nil
    
    if self.sprite_array then
        local i = (r*8)+c
        if i < self.sprite_array:size() then
            local sprite = self.sprite_array:get(i)
            tileName = sprite ~= 0 and sprite:getName()
        end
    else
        if c >= 0 and c < 8 and r >= 0 and r < 128 then
            if self.posToTileNameTable[r+1] ~= nil and self.posToTileNameTable[r+1][c+1] ~= nil then
                tileName = self.posToTileNameTable[r+1][c+1]
            end
        end
    end
    
    if tileName then
        if self.mainEditor and self.mainEditor.palettePanel then
            self.mainEditor.palettePanel:addTile(tileName)
            self.mainEditor.statusMessage = "Added to palette: " .. tileName
        end
    end
end

-- ============================================================================
-- TileEditorPicker
-- ============================================================================

TileEditorPicker = ISPanel:derive("TileEditorPicker")

function TileEditorPicker:new(x, y, width, height, mainEditor)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.mainEditor = mainEditor
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    
    o.advSearchEnabled = false
    o.humanNameTable = {}
    o.favorites = {}
    o.preferredHeight = 350 * (mainEditor.scale or 1)
    
    return o
end

function TileEditorPicker:initialise()
    ISPanel.initialise(self)
    
    -- Initialize sprite manager access for advanced search
    self.sprite_manager = getSpriteManager("")
    self.sm_instance = fetchField(self.sprite_manager, "instance")
    self.sm_map = fetchField(self.sm_instance, "NamedMap")
    
    self:loadFavorites()
end

function TileEditorPicker:createChildren()
    ISPanel.createChildren(self)
    
    local th = 25 -- Top height for search bar

    local tilePickerArea = 64 * 8 + 15
    local remainingWidth = self.width - tilePickerArea - 5
    
    -- Search Box
    self.searchEntryBox = ISTextEntryBox:new('', 0, 0, remainingWidth, 20)
    self.searchEntryBox.font = UIFont.Small
    self.searchEntryBox.onTextChange = function() self:populateList() end
    self:addChild(self.searchEntryBox)
    
    -- Advanced Search Checkbox
    self.advTickBox = ISTickBox:new(remainingWidth - 50, 0, 50, 20, "", self, self.onAdvSearchToggled)
    self.advTickBox.tooltip = "Enable searching through names of moveables that have them when picked up."
    self.advTickBox:initialise()
    self.advTickBox:addOption("Adv.", true)
    self.advTickBox:setSelected(1, false)
    self:addChild(self.advTickBox)
    
    -- Category List
    self.imageList = ISScrollingListBox:new(0, 25,  remainingWidth, self.height - 25);
    self.imageList.anchorBottom = true;
    self.imageList:initialise();
    self.imageList:instantiate();
    self.imageList.itemheight = 20;
    self.imageList.selected = 0;
    self.imageList.font = UIFont.Small;
    self.imageList.doDrawItem = self.doDrawImageListItem;
    self.imageList.drawBorder = true;
    self.imageList.onmousedown = self.onSelectImage
    self.imageList.target = self
    self.imageList.onRightMouseDown = self.onCategoryRightClick
    self:addChild(self.imageList);
    
    -- Tile List
    self.tilesList = TileEditorPickerList:new(remainingWidth + 5, 0, tilePickerArea, self.height, self.mainEditor)
    self.tilesList.anchorRight = true;
    self.tilesList.anchorBottom = true;
    self.tilesList:initialise();
    self.tilesList:instantiate();
    self.tilesList:addScrollBars();
    self:addChild(self.tilesList);
    
    self:populateList();
end

function TileEditorPicker:onAdvSearchToggled(index, selected)
    self.advSearchEnabled = selected
    
    if selected then
        -- Build humanNameTable
        local count = 0
        for k,v in pairs(transformIntoKahluaTable(self.sm_map)) do
            local props = v:getProperties();
            local groupName = props:Is("GroupName") and props:Val("GroupName") or nil;
            local fullName = (groupName and (groupName .. " ") or "") .. (props:Is("CustomName") and props:Val("CustomName") or "");
            if fullName ~= "" then
                if not self.humanNameTable[fullName] then self.humanNameTable[fullName] = ArrayList:new() end
                self.humanNameTable[fullName]:add(v)
            end
        end    
    else
        self.humanNameTable = {}
    end
    
    self:populateList()
end

function TileEditorPicker:populateList()
    local searchText = self.searchEntryBox:getInternalText()
    
    self.imageList:clear();
    local bufferImages = {}
    local resultImages = {}
    
    -- Standard Search
    local images = getWorld():getTileImageNames()
    for i = 0, images:size()-1 do
        local name = luautils.split(images:get(i), ".")[1]
        local catName = TileCategories[name] and TileCategories[name] or "[NEW] "
        if (string.contains(string.lower(catName .. name), string.lower(searchText)) or searchText == "") then
            bufferImages[name] = true
        end
    end

    for v, _ in pairs(bufferImages) do
        local catName = TileCategories[v] and TileCategories[v] or "[NEW] "
        table.insert(resultImages, {text = (catName .. v), item = v, favorite = self.favorites[v]})
    end
    
    -- Sort: Favorites first, then alphabetical
    table.sort(resultImages, function (a, b) 
        if a.favorite and not b.favorite then return true end
        if not a.favorite and b.favorite then return false end
        return a.text < b.text 
    end)

    -- Add Advanced Search Results Item if applicable
    if self.advSearchEnabled and string.len(searchText) > 2 then
        self.imageList:addItem("[IN-GAME NAMES SEARCH RESULTS]", "[search_results]");
    end

    for i = 1, #resultImages do
        local item = self.imageList:addItem(resultImages[i].text, resultImages[i].item);
        item.favorite = resultImages[i].favorite
    end

    if #self.imageList.items ~= 0 then
        self:selectImage(self.imageList.items[self.imageList.selected].item)
    end
end

function TileEditorPicker:doDrawImageListItem(y, item, alt)
    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
    end
    
    local text = item.text
    if item.item ~= "[search_results]" and self.parent.favorites[item.item] then
        self:drawText("* " .. text, 10, y + (self.itemheight - 20) / 2, 1, 1, 0, 0.9, self.font);
    else
        self:drawText(text, 10, y + (self.itemheight - 20) / 2, 1, 1, 1, 0.9, self.font);
    end
    
    return y + self.itemheight;
end

function TileEditorPicker:onSelectImage(item)
    self:selectImage(item)
end

function TileEditorPicker:selectImage(item)
    if item == "[search_results]" then
        self:generateAdvSearchResults()
    else
        self.tilesList.imageName = item
        self.tilesList.sprite_array = nil
    end
end

function TileEditorPicker:generateAdvSearchResults()
    self.tilesList.sprite_array = ArrayList:new()
    local search_text = self.searchEntryBox:getInternalText()
    if string.len(search_text) < 3 then return end
    
    for k, v in pairs(self.humanNameTable) do
        if string.contains(string.lower(k), string.lower(search_text)) then
            for i=0,v:size()-1 do
                self.tilesList.sprite_array:add(v:get(i))
            end
        end
    end
end

function TileEditorPicker.onCategoryRightClick(target, x, y)
    local row = target:rowAt(x, y)
    if row < 1 or row > #target.items then return end
    
    local item = target.items[row]
    if item.item == "[search_results]" then return end
    
    local categoryName = item.item
    target.parent:toggleFavorite(categoryName)
end

function TileEditorPicker:toggleFavorite(categoryName)
    if self.favorites[categoryName] then
        self.favorites[categoryName] = nil
    else
        self.favorites[categoryName] = true
    end
    self:saveFavorites()
    self:populateList()
end

function TileEditorPicker:selectCategory(categoryName)
    if not categoryName or categoryName == "" then return end
    
    -- Search in imageList items
    for i, item in ipairs(self.imageList.items) do
        if item.item == categoryName then
            self.imageList.selected = i
            self:selectImage(categoryName)
            -- Ensure visible
            if self.imageList.ensureVisible then
                self.imageList:ensureVisible(i)
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- Favorites Persistence
-- ============================================================================

local FAVORITES_FILE = "WAT_TileEditor_Favorites.txt"

function TileEditorPicker:saveFavorites()
    local fileWriter = getFileWriter(FAVORITES_FILE, true, false)
    if not fileWriter then return end
    
    for k,v in pairs(self.favorites) do
        fileWriter:write(k .. "\n")
    end
    fileWriter:close()
end

function TileEditorPicker:loadFavorites()
    self.favorites = {}
    local fileReader = getFileReader(FAVORITES_FILE, true)
    if not fileReader then return end
    
    local line = fileReader:readLine()
    while line ~= nil do
        if line ~= "" then
            self.favorites[line] = true
        end
        line = fileReader:readLine()
    end
    fileReader:close()
end

return TileEditorPicker
