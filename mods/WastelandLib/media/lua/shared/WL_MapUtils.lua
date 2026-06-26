---
--- WL_MapUtils.lua
--- 30/10/2023
---

WL_MapUtils = {}

--- Take a table of cells and convert it to the map coordinates of a rectangular area. The cells are assumed to make up
--- a rectangular shape, so even if some are missing (e.g. forming an L shape) it will assume the missing cell is
--- included within the area bounds of the result.
---@param cells table in the format { {1, 3}, {2, 3}, {3, 3} } whereby the two numbers are x and y coords of the cells
---@return int values in the form: minX, minY, 0, maxX, maxY, 99 (The 0 and 99 represent Z values)
function WL_MapUtils.cellsToMapCoords(cells)
	if not cells then error("cells parameter is missing or nil") end
	local cellMinX, cellMinY, cellMaxX, cellMaxY = WL_MapUtils.getEncompassingCellRectangle(cells)
	return cellMinX * 300, cellMinY * 300, 0, (cellMaxX * 300) + 299, (cellMaxY * 300) + 299, 99
end

--- Returns the bounding rectangle around a group of cells, assuming that they are in a rectangular shape without
--- any missing cells. In this case the missing cell is included within the bounding shape even though it wasn't
--- in the parameters.
function WL_MapUtils.getEncompassingCellRectangle(cells)
	local cellMinX, cellMinY, cellMaxX, cellMaxY
	for _, mapCell in ipairs(cells) do
		local x = mapCell[1]
		local y = mapCell[2]
		if not cellMinX or x < cellMinX then cellMinX = x end
		if not cellMaxX or x > cellMaxX then cellMaxX = x end
		if not cellMinY or y < cellMinY then cellMinY = y end
		if not cellMaxY or y > cellMaxY then cellMaxY = y end
	end
	return cellMinX, cellMinY, cellMaxX, cellMaxY
end