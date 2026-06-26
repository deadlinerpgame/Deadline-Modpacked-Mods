# LayoutManager User Guide

This guide shows how to build Project Zomboid UI layouts with `LayoutManager`.

Reference implementation: `Contents/mods/WastelandLib/media/lua/client/UI/LayoutManager/LayoutManager.lua`.

Real example in your repo: `Contents/mods/WastelandZones/media/lua/server/WastelandZones/Plugins/AccessControl.lua`.

---

## What LayoutManager does

`LayoutManager:applyLayout(panel, layout)` takes a Lua table (`layout`) and creates/updates UI elements inside `panel`.

It handles:

- Nesting with `rows` and `columns`
- Sizing (`number`, `%`, `inherit`, `auto`, `*`, `*/N`)
- Margin and spacing (`margin`, `pad`)
- Re-using existing UI controls by `id`
- Returning a lookup table so you can read/write controls by `id`

---

## Quick start

```lua
panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 8, margin = { 10, 10, 10, 10 }, rows = {
        { type = "label", id = "title", height = 20, text = "Zone Access"},
        { type = "columns", height = 20, columns = {
            { type = "label", width = "30%", text = "Allowed names" },
            { type = "textbox", id = "allowedNamesCsv", width = "70%", text = "Alice,Bob" }
        }},
        { type = "columns", height = 24, columns = {
            { type = "gap", width = "*" },
            { type = "button", id = "saveBtn", width = 120, text = "Save", target = self, onClick = self.onSave }
        }}
    }
}

panel.elements = LayoutManager:applyLayout(panel, panel.layout)
```

Then use controls by `id`:

```lua
local namesCsv = panel.elements.allowedNamesCsv:getText()
panel.elements.saveBtn:setEnable(true)
```

---

## Built-in demo window

`LayoutManager` includes a comprehensive demo UI.

Open it with:

```lua
LayoutManager:showDemo()
```

Important:

- The demo is **debug-only**.

## LayoutMaker (live layout editor)

`LayoutManager` also includes a `LayoutMaker` tool window for authoring and previewing layouts quickly.

Open it with:

```lua
LayoutManager:showLayoutMaker()
```

How it works:

- Paste Lua source into the large **Layout Source** textbox.
- Your source can declare locals/functions/data first, but it must `return` the layout table.
- Press **Go** to compile via `loadstring`, execute, and apply the returned layout to a preview window.
- If a preview window is already visible, **Go** re-applies into that same window.
- If the preview window is closed or hidden, **Go** creates a new preview window and shows it.
- **Debug Output** shows:
  - compile/runtime errors (if any)
  - the discovered node tree
  - all exposed element ids returned by `LayoutManager:applyLayout`

Minimal example source for LayoutMaker:

```lua
local sampleText = "Sample"
return { type = "label", text = sampleText }
```

---

## Layout object basics

Every node is a Lua table with at least:

- `type`: one of `rows`, `columns`, `tabpanel`, `panel`, `scrollpanel`, `sliderpanel`, `scrollinglistbox`, `element`, `label`, `textbox`, `button`, `combobox`, `tickbox`, `gap`

Optional common fields:

- `id`: required for interactive controls (`textbox`, `button`, `tickbox`, and effectively for `label` if you need to reference it)
- `x`, `y`: root position offset (number or `%`)
- `width`, `height`: size expression
- `margin`: outside spacing

Container fields:

- `rows` container uses `rows = { ... }`
- `columns` container uses `columns = { ... }`
- both support `pad` (space between children)

---

## Size rules (important)

`width`/`height` accepts:

- `120` → fixed size scaled based on user settings
- `"120"` → fixed size scaled based on user settings
- `"120px"` → fixed static size (no scale applied)
- `"50%"` → percent of parent
- `"inherit"` → parent size on that axis
- `"auto"` → size from content (container measurement)
- `"*"` → 1 flex weight share on main axis
- `"*/2"` → 0.5 flex weight share on main axis

### Main axis behavior

- In `rows`, main axis is **height**.
- In `columns`, main axis is **width**.

If child size on main axis is omitted:

- Child defaults to flex (`*`).

If child size on cross axis is omitted:

- Child defaults to inherit parent on cross axis.

---

## Margin and pad

`margin` supports:

- single value: `margin = 8`
- static px string: `margin = "8px"`
- CSS-like array forms:
  - `{8}`
  - `{"8px"}`
  - `{vertical, horizontal}`
  - `{top, horizontal, bottom}`
  - `{top, right, bottom, left}`
- keyed table: `{ top = 4, right = 8, bottom = 4, left = 8 }`

Margin values can be numbers (scaled), `%` strings, or `"Npx"` static strings.

`pad` is the gap between siblings in a `rows` or `columns` container.

---

## Node types and common fields

### `rows`

- Child array: `rows = { ... }`
- Uses `height` as main axis.
- Useful fields: `width`, `height`, `margin`, `pad`, `data`, `generator`

### `columns`

- Child array: `columns = { ... }`
- Uses `width` as main axis.
- Useful fields: `width`, `height`, `margin`, `pad`, `data`, `generator`

### `tabpanel`

- Creates an `ISTabPanel` and manages tab content using nested LayoutManager layouts.
- Primary tab API: `tabs = { ... }`
- Secondary dynamic API: `data = { ... }` with `tabGenerator = function(row, i, def) return tabDef end`

Required fields:

- `id`: tab panel id

Optional container fields:

- `width`, `height`, `margin`
- `activeTabId`: only used on first creation of this tab panel node

Optional `ISTabPanel` options:

- `equalTabWidth`, `centerTabs`
- `allowDraggingTabs`, `allowTornOffTabs`
- `tabTransparency`, `textTransparency`
- `target`, `onActivateView`

#### Static tabs (recommended, documented first)

```lua
panel.layout = { type = "tabpanel", id = "settingsTabs", width = "inherit", height = "inherit", activeTabId = "general", equalTabWidth = false, tabs = {
    { id = "general", title = "General", content = { type = "rows", width = "inherit", height = "inherit", pad = 6, rows = {
        { type = "label", id = "generalTitle", height = 20, text = "General Settings" },
        { type = "textbox", id = "serverName", height = 20, text = "My Server" }
    }}},
    { id = "advanced", title = "Advanced", content = { type = "rows", width = "inherit", height = "inherit", rows = {
        { type = "tickbox", id = "advancedFlags", height = 38, options = { "Verbose", "Unsafe" } }
    }}}
}}

panel.elements = LayoutManager:applyLayout(panel, panel.layout)
```

#### Dynamic tabs (`data` + `tabGenerator`)

```lua
local pluginRows = {
    { key = "pvp", title = "PVP" },
    { key = "loot", title = "Loot" }
}

panel.layout = { type = "tabpanel", id = "pluginTabs", width = "inherit", height = "inherit", data = pluginRows, tabGenerator = function(row)
    return { id = "plugin_" .. row.key, title = row.title, content = { type = "rows", width = "inherit", height = "inherit", rows = {
        { type = "label", id = "label_" .. row.key, height = 20, text = row.title .. " Settings" }
    }}}
end }

panel.elements = LayoutManager:applyLayout(panel, panel.layout)
```

Tab entry shape:

- `id` (required): stable id for tab identity/reuse
- `title` (required): visible tab name (`name` accepted as fallback)
- `content` (required): nested layout tree for this tab page

Selection behavior:

- First apply: uses `activeTabId` when valid, else first tab
- Later applies: preserves the currently active tab if still present and ignores `activeTabId`

Element exposure:

- The tab panel itself is exposed at `panel.elements.<tabpanelId>`
- Nested controls inside all tab pages are exposed directly into `panel.elements` by their own `id`
- If duplicate ids are used across tabs, later writes may overwrite earlier keys in `panel.elements`

### `panel`

- Creates/reuses an `ISPanel`.
- Supports normal layout sizing/position fields: `x`, `y`, `width`, `height`, `margin`.
- Supports panel visuals/options:
  - `background` (bool)
  - `noBackground` (bool)
  - `backgroundColor` (or alias `color`) = `{ r, g, b, a }`
  - `borderColor` = `{ r, g, b, a }`
  - `moveWithMouse` (bool)
- Supports nested layout via:
  - `child` = another layout node (such as `rows`, `columns`, `tabpanel`, etc.)

Example:

```lua
{ type = "panel", id = "myPanel", width = "inherit", height = "*", margin = 6, backgroundColor = { r = 0, g = 0, b = 0, a = 0.35 }, borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }, child = { type = "rows", width = "inherit", height = "inherit", pad = 4, rows = {
    { type = "label", id = "insideTitle", height = 20, text = "Inside panel" },
    { type = "button", id = "insideBtn", height = 24, text = "Click" }
}}}
```

### `scrollpanel`

- Creates/reuses a LayoutManager scrollable `ISPanel` that auto-sizes scroll height from children.
- Supports normal layout sizing/position fields: `x`, `y`, `width`, `height`, `margin`.
- Supports panel visuals/options:
  - `background` (bool)
  - `noBackground` (bool)
  - `backgroundColor` (or alias `color`) = `{ r, g, b, a }`
  - `borderColor` = `{ r, g, b, a }`
  - `moveWithMouse` (bool)
- Scroll behavior options:
  - `autoScrollBottomPadding` (number, default `12`)
  - `doRepaintStencil` (bool)
- Supports nested layout via:
  - `child` = another layout node (such as `rows`, `columns`, `tabpanel`, etc.)

Example:

```lua
{ type = "scrollpanel", id = "myScroll", width = "inherit", height = "*", autoScrollBottomPadding = 12, child = { type = "rows", width = "inherit", height = "auto", pad = 4, rows = {
    { type = "label", id = "scrollTitle", height = 20, text = "Scrollable content" },
    { type = "button", id = "scrollBtn1", height = 24, text = "Row 1" },
    { type = "button", id = "scrollBtn2", height = 24, text = "Row 2" }
}}}
```

### `sliderpanel`

- Creates/reuses an `ISSliderPanel`.
- Supports normal layout sizing/position fields: `x`, `y`, `width`, `height`, `margin`.

Required fields:

- `id`: slider id

Primary value fields:

- `minValue`, `maxValue`, `stepValue`, `shiftValue`
- `currentValue` (alias: `value`)

Behavior fields:

- `target`, `onValueChange`, `customPaginate`
- `doButtons` (bool)
- `doToolTip` (bool), `toolTipText`

Color fields:

- `buttonColor`, `buttonMouseOverColor`
- `sliderColor`, `sliderMouseOverColor`, `sliderBorderColor`
- `sliderBarColor`, `sliderBarBorderColor`

Example:

```lua
{ type = "sliderpanel", id = "volumeSlider", width = "inherit", height = 20, minValue = 0, maxValue = 100, stepValue = 1, shiftValue = 10, currentValue = 65, target = self, onValueChange = self.onVolumeChanged, doButtons = true }
```

### `scrollinglistbox`

- Creates/reuses an `ISScrollingListBox`.
- Supports normal layout sizing/position fields: `x`, `y`, `width`, `height`, `margin`.

Required fields:

- `id`: list box id

Data fields:

- `items = { ... }`
  - string item: `"Name"`
  - table item: `{ text = "Name", item = data, tooltip = "...", height = 24 }`
- `columns = { ... }`
  - table column: `{ name = "Column", size = 120 }`
  - number column: `120`

Behavior fields:

- `target`, `onMouseDown`, `onMouseDoubleClick`
- `selected`, `yScroll`
- `resetSelectionOnChangeFocus` (bool)

Style/options fields:

- `font` (UIFont enum), `itemPadY`, `itemheight`
- `drawBorder` (bool), `doRepaintStencil` (bool)
- `backgroundColor`, `borderColor`, `altBgColor`, `listHeaderColor`

Example:

```lua
{ type = "scrollinglistbox", id = "playerList", width = "inherit", height = "*", columns = { { name = "Player", size = 0 } }, items = { { text = "Alice", item = { id = 1 } }, { text = "Bob", item = { id = 2 } } }, target = self, onMouseDown = self.onPlayerSelected, onMouseDoubleClick = self.onPlayerActivated }
```

### `element`

- Creates/reuses a blank `ISUIElement`.
- Supports normal layout sizing/position fields: `x`, `y`, `width`, `height`, `margin`.
- Intended as a lightweight base element for advanced/custom usage.

### `label`

- `id`, `text`, `font`, `color = {r,g,b,a}`, `center`

### `textbox`

- `id`, `text`/`value`, `target`
- Events: `onCommandEntered`, `onTextChange`, `onPressDown`, `onPressUp`
- Common options: `onlyNumbers`, `editable`, `selectable`, `multipleLine`, `maxLines`, `maxTextLength`, `forceUpperCase`, `masked`, `clearButton`, `hasFrame`, `frameAlpha`, `valid`, `tooltip`, `font`, `backgroundColor`, `borderColor`

### `button`

- `id`, `text`/`title`, `target`, `onClick`, `onMouseDown`, `args`
- Common options: `enabled`/`enable`, `tooltip`, `font`, `displayBackground`, `allowMouseUpProcessing`, `yoffset`, colors (`borderColor`, `backgroundColor`, `backgroundColorMouseOver`, `textureColor`, `textColor`), `soundActivate`

### `combobox`

- `id`, `options`, `target`, `onChange`, `args`
- Selection options: `selected` (index), `selectedText`, `selectedData`
- Common options: `enabled`/`enable` or `disabled`, `editable`, `filterText`, `font`, `noSelectionText`, `openUpwards`, `tooltip` (map), colors (`backgroundColor`, `backgroundColorMouseOver`, `borderColor`, `textColor`)

### `tickbox`

- `id`, `options`, `selected`, `target`, `onChange`, `args`
- Common options: `enabled`/`enable`, `disabledOptions`, `autoWidth`, `onlyOnePossibility`, `fitWidth`, `font`, `tooltip`, `leftMargin`, `boxSize`, `textGap`, `itemGap`, colors (`borderColor`, `backgroundColor`, `choicesColor`)

### `gap`

- Spacer node. No UI control created.
- Use with fixed/flex width or height to push other nodes.

---

## Dynamic rows from data (`generator`)

Use this when you need repeated rows from a list.

```lua
local data = {
    { key = "PVP", value = "On" },
    { key = "Loot", value = "Rare" }
}

panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 4, data = data, generator = function(row, i)
    return { type = "columns", height = 20, columns = {
        { type = "label", width = "40%", text = row.key },
        { type = "label", id = "value_" .. tostring(i), width = "60%", text = row.value }
    }}
end }

panel.elements = LayoutManager:applyLayout(panel, panel.layout)
```

---

## Re-apply pattern (important for live updates)

When your panel size or data changes, rebuild `panel.layout` and call:

```lua
panel.elements = LayoutManager:applyLayout(panel, panel.layout)
```

LayoutManager keeps prior controls by `id`, updates their frame/properties, and removes controls not present in the new layout.

---

## Common mistakes

1. Missing `id` on interactive controls.
   - `textbox`, `button`, and `tickbox` require `id`.
2. Expecting `gap` in `panel.elements`.
   - `gap` is layout-only and does not create a control.
3. Confusing `auto` vs flex.
   - `auto` measures content; `*` shares remaining space.
4. Overwriting user input unexpectedly.
   - `textbox` only auto-updates text when current text still matches last layout text.

---

## Minimal checklist for new panels

1. Build a root `rows` or `columns` layout.
2. Give every control you need later a stable `id`.
3. Call `panel.elements = LayoutManager:applyLayout(panel, panel.layout)`.
4. Read/write control values through `panel.elements.<id>`.
5. Re-apply layout after data/size changes.

---

# Standard in Writing Layouts

We recommend you write layout tables in a consistent style for readability:

- Keep layouts **condensed**.
- Write **one element per line** (one row/column child node per line).
- It is okay (and expected) for layout lines to be long.
- Prioritize quick visual scanning of structure over vertical expansion.
- Put data, colors, etc in variables and pass them in to keep layout definitions clean.

### Preferred style rules

1. One node table per line inside `rows = { ... }` and `columns = { ... }`.
2. Keep node fields in a stable order when possible:
   - `type`, `id`, layout (`x`, `y`, `width`, `height`, `margin`, `pad`), then behavior (`text`, `target`, `onClick`, etc.), then nested `rows`/`columns`/`child`.
3. Keep small nested containers inline if still readable.
4. Do not split a single simple node across many lines unless needed for clarity.
5. Use ids consistently and keep them stable for re-apply behavior.

### Why this style

This is the style already used in real project code and demos. It makes large layouts easier to scan quickly because each child is one visual unit.

### Example: condensed (recommended)

```lua
panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 8, margin = {10, 20, 10, 10}, rows = {
    { type = "tickbox", id = "tickboxes", width = "inherit", height = 18*3, options = { "Staff Only", "Gate by Player", "Gate by Item" }},
    { type = "columns", width = "inherit", height = 20, columns = {
        { type = "label", width = "30%", text = "Allowed names csv" },
        { type = "textbox", id = "allowedNamesCsv", width = "70%", text = tostring(data.allowedNamesCsv or "") }
    }},
    { type = "columns", width = "inherit", height = 20, columns = {
        { type = "label", width = "30%", text = "Required item full type" },
        { type = "textbox", id = "requiredItemFullType", width = "70%", text = tostring(data.requiredItemFullType or "") }
    }}
}}
```

### Example: window-scale condensed structure

```lua
return { type = "rows", x = rootX, y = rootY, width = tostring(rootWidth) .. "px", height = tostring(rootHeight) .. "px", pad = pad, rows = {
    { type = "columns", width = "inherit", height = "*", pad = pad, columns = {
        { type = "panel", id = "sidebar", width = "28%", height = "inherit", backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 1 }, borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.7 } },
        { type = "rows", width = "*", height = "inherit", pad = pad, rows = {
            { type = "panel", id = "contentHeader", width = "inherit", height = headerHeight, child = { type = "columns", width = "inherit", height = "inherit", margin = { 3, 12, 3, 12 }, pad = 8, columns = {
                { type = "label", id = "contentHeaderTitle", width = "*", text = "General", font = UIFont.Medium },
                { type = "button", id = "contentHeaderToggleButton", width = 120, text = "Disable Plugin", target = self, onClick = self.onToggleSelectedPlugin }
            }}}
        }}
    }}
}}
```

### Example: generator callback style

When using `generator`, keep the returned node condensed too:

```lua
generator = function(row, i)
    local idx = tostring(i)
    return { type = "columns", height = 24, columns = {
        { type = "label", id = "dynamic_name_" .. idx, width = "34%", text = row.name },
        { type = "label", id = "dynamic_spec_" .. idx, width = "22%", text = row.spec },
        { type = "button", id = "dynamic_pick_" .. idx, width = "44%", text = "Pick", target = self, onClick = self.onDynamicPick, args = { row.name, row.spec } }
    }}
end
```

### Example: variables for data

```lua
local tickBoxOptions = {
    "Jail containment",
    "Teleport while inside",
    "Staff bypass"
}

local tickBoxState = {
    data.jailEnabled == true,
    data.teleportEnabled == true,
    data.staffBypass ~= false
}

return { type = "rows", width = "inherit", height = "auto", pad = 8, margin = {10, 0, 10, 10}, rows = {
    { type = "tickbox", id = "tickboxes", width = "inherit", height = 18 * 3, options = tickBoxOptions, selected = tickBoxState },
    { type = "label", id = "teleportPointLabel", width = "inherit", height = 18, text = "Teleport Point" },
    { type = "element", id = "teleportPointHost", width = "inherit", height = 48 }
}}
```

### Anti-pattern (avoid)

- Expanding each field onto separate lines for every small node.
- Mixing many different formatting styles in the same file.
- Breaking compact layout lists into highly vertical blocks that make sibling scanning harder.

Use the condensed style by default for layout tables in this codebase.
