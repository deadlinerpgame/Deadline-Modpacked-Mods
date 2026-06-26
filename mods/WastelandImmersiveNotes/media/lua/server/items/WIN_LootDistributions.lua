---
--- WIN_LootDistributions.lua
--- 2025-12-05
---

require "Items/LootTableEditor"
require 'Items/SuburbsDistributions'
require "Items/WL_LootTableEditor"

local addLootItem = WL_LootTableEditor.addZombieLootItem
local addItem = WL_LootTableEditor.addItemToProceduralDistributions

addItem("ArtStorePaper", "NotebookLeather", 5)
addItem("ArtStorePaper", "NotebookGrey", 10)
addItem("ArtStorePaper", "NotebookPink", 7)

addItem("BookstoreStationery", "NotebookLeather", 5)
addItem("BookstoreStationery", "NotebookGrey", 10)
addItem("BookstoreStationery", "NotebookPink", 7)

addItem("ClassroomDesk", "NotebookPink", 1)
addItem("ClassroomMisc", "NotebookPink", 4)
addItem("SchoolLockers", "NotebookPink", 4)

addItem("CrateOfficeSupplies", "NotebookGrey", 4)
addItem("OfficeDesk", "NotebookLeather", 1)
addItem("OfficeDesk", "NotebookGrey", 4)
addItem("OfficeDeskHome", "NotebookGrey", 2)
addItem("OfficeDeskHome", "NotebookLeather", 6)