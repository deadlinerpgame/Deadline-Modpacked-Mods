---
--- WIN_LiteratureSkin.lua
--- 2025-12-03
---

WIN_LiteratureSkin = {}
WIN_LiteratureSkin.NOTEBOOK_TYPES = {
    ["Base.Notebook"] = {
        name = "Top Binder",
        texture = "media/textures/BlankNotepad.png",
        paddingTop = 60,
        paddingLeft = 35,
        paddingRight = 25,
        paddingBottom = 30,
    },
    ["Base.NotebookGrey"] = {
        name = "Notebook",
        texture = "media/textures/BlankNoteBook.png",
        paddingTop = 20,
        paddingLeft = 90,
        paddingRight = 25,
        paddingBottom = 30,
    },
    ["Base.NotebookLeather"] = {
        name = "Leather Bound",
        texture = "media/textures/BlankNotebookLeather.png",
        paddingTop = 20,
        paddingLeft = 110,
        paddingRight = 40,
        paddingBottom = 30,
    },
    ["Base.NotebookPink"] = {
        name = "Cute Diary",
        texture = "media/textures/BlankCuteDiary.png",
        paddingTop = 50,
        paddingLeft = 135,
        paddingRight = 65,
        paddingBottom = 85,
    },
}
WIN_LiteratureSkin.DEFAULT_NOTEBOOK_TYPE = "Base.Notebook"
WIN_LiteratureSkin.SHEET_PAPER_TYPES = {
    ["NotebookPage"] = {
        name = "Notebook Page",
        texture = "media/textures/BlankNotePaper.png",
        paddingTop = 20,
        paddingLeft = 35,
        paddingRight = 25,
        paddingBottom = 30,
    },
    ["BloodyCrumpled"] = {
        name = "Bloody and Crumpled",
        texture = "media/textures/BlankNotePaperBloody.png",
        paddingTop = 20,
        paddingLeft = 35,
        paddingRight = 25,
        paddingBottom = 30,
    },
    ["BlankPaperFresh"] = {
        name = "Fresh",
        texture = "media/textures/BlankPaperFresh.png",
        paddingTop = 20,
        paddingLeft = 35,
        paddingRight = 25,
        paddingBottom = 30,
    },
    ["DoorSign"] = {
        name = "Hanging Sign",
        texture = "media/textures/BlankDoorSign.png",
        paddingTop = 140,
        paddingLeft = 65,
        paddingRight = 25,
        paddingBottom = 30,
    }
}
WIN_LiteratureSkin.DEFAULT_SHEET_PAPER_TYPE = "NotebookPage"

function WIN_LiteratureSkin.findFromKey(typeKey)
    for key, textureName in pairs(WIN_LiteratureSkin.NOTEBOOK_TYPES) do
        if typeKey == key then
            return textureName
        end
    end
    for key, textureName in pairs(WIN_LiteratureSkin.SHEET_PAPER_TYPES) do
        if typeKey == key then
            return textureName
        end
    end
    return nil
end