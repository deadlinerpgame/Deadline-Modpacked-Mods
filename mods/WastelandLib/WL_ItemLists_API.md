# WL_ItemLists API

[`WL_ItemLists`](media/lua/shared/WL_ItemLists.lua) is the shared authoritative item-list system for [`WastelandLib`](mod.info).

It stores reusable weighted item lists in public mod data so other mods can:

- inspect available lists
- fetch one list by id
- roll one or many weighted nested definitions
- create one or many inventory items from flattened rolled results
- open a reusable picker dialog on the client

## Data model summary

Each saved list contains:

- stable list id
- display name
- soft-delete state
- create and update timestamps
- item rows

Each item row is a tagged union and contains:

- stable item-entry id
- `entryType` of `item` or `list`
- spawn weight
- quantity min
- quantity max

For `item` rows:

- `fullType`
- optional `customName`

For `list` rows:

- `childListId`

Derived read fields may also include:

- `displayName`
- `displaySubtext`
- `resolvedListName`
- `isMissingReference`

Deleted lists are hidden by default from read APIs and from the picker dialog.

## Nested reference validation

[`WL_ItemLists:upsertItemEntry()`](media/lua/shared/WL_ItemLists.lua) validates nested child-list references on the server before save.

Rules:

- direct self-reference is rejected
- deep cycles are rejected
- deleted child lists are rejected as save targets
- missing child lists are rejected as invalid references

Client tools may pre-filter likely-invalid child-list selections, but server validation is authoritative.

## Read APIs

### [`WL_ItemLists:getListSummaries()`](media/lua/shared/WL_ItemLists.lua)

Returns sorted summary rows for all active lists.

```lua
local summaries = WL_ItemLists:getListSummaries()
for i = 1, #summaries do
    local summary = summaries[i]
    print(summary.id, summary.name, summary.itemCount)
end
```

Pass `true` to include deleted lists:

```lua
local summaries = WL_ItemLists:getListSummaries(true)
```

[`WL_ItemLists:getAvailableLists()`](media/lua/shared/WL_ItemLists.lua) is a simple alias to the same summary API for consumers that prefer a more descriptive read method name.

### [`WL_ItemLists:getListById()`](media/lua/shared/WL_ItemLists.lua)

Returns one copied list record by id, or `nil` when not found.

```lua
local listData = WL_ItemLists:getListById(listId)
if listData then
    print(listData.name, #listData.items)
end
```

Pass `true` as the second argument to include deleted lists.

## Random roll APIs

The normal contract is now multi-item and flattened. Nested list qty means repeated independent child-list rolls, then all descendant concrete item definitions are flattened into one final array.

### [`WL_ItemLists:rollItemDefinitions()`](media/lua/shared/WL_ItemLists.lua)

Rolls an active list recursively and returns:

- `rolledDefinitions`: flat concrete item definitions only
- `rollReport`: structured trace metadata for UI, debugging, and simulation

Each rolled definition may include:

- `sourceRootListId`
- `sourceLeafListId`
- `sourceEntryId`
- `fullType`
- `customName`
- `quantity`
- `displayName`
- `path`

Each [`rollReport`](media/lua/shared/WL_ItemLists.lua) includes:

- `rootListId`
- `requestedRollCount`
- `executedRollCount`
- `flattenedItemCount`
- `traces`
- `errors`

Example:

```lua
local rolledDefinitions, rollReport = WL_ItemLists:rollItemDefinitions(listId, 3)
for i = 1, #(rolledDefinitions or {}) do
    local definition = rolledDefinitions[i]
    print(definition.displayName, definition.quantity, definition.fullType)
end
```

### [`WL_ItemLists:rollItemDefinition()`](media/lua/shared/WL_ItemLists.lua)

Legacy compatibility helper that returns only the first flattened concrete definition from [`WL_ItemLists:rollItemDefinitions()`](media/lua/shared/WL_ItemLists.lua).

It should not be the normal caller path for new code.

Returns `nil` when no concrete definitions are produced.

## Effective chance API

### [`WL_ItemLists:getEffectiveChances()`](media/lua/shared/WL_ItemLists.lua)

Computes theoretical per-parent-roll chance for each reachable concrete item.

Display math rules:

- parent entry chance = entry weight / total valid sibling weight
- direct item contribution = parent entry chance
- nested list contribution = parent entry chance multiplied through child effective chance
- nested repeated qty uses at-least-once complement math per qty outcome
- qty ranges are averaged across all equally likely qty results

The API returns a report with:

- `rootListId`
- `entries`
- `errors`

Each entry includes:

- `sourceRootListId`
- `sourceLeafListId`
- `sourceEntryId`
- `fullType`
- `customName`
- `displayName`
- `effectiveChance`
- `path`

Example:

```lua
local chanceReport = WL_ItemLists:getEffectiveChances(listId)
for i = 1, #chanceReport.entries do
    local entry = chanceReport.entries[i]
    print(entry.displayName, entry.effectiveChance)
end
```

## Item creation APIs

### [`WL_ItemLists:createRolledItems()`](media/lua/shared/WL_ItemLists.lua)

Rolls from the list and materializes all flattened concrete definitions into inventory items.

```lua
local items, rolledDefinitions, rollReport = WL_ItemLists:createRolledItems(listId, 2)
if items then
    for i = 1, #items do
        player:getInventory():AddItem(items[i])
    end
end
```

### [`WL_ItemLists:createItemsFromRolledDefinitions()`](media/lua/shared/WL_ItemLists.lua)

Creates all inventory items from a previously rolled flattened definition array.

This is useful if your mod needs to inspect or modify the rolled definition first.

```lua
local rolledDefinitions = WL_ItemLists:rollItemDefinitions(listId, 1)
if rolledDefinitions then
    local items = WL_ItemLists:createItemsFromRolledDefinitions(rolledDefinitions)
    if items then
        for i = 1, #items do
            player:getInventory():AddItem(items[i])
        end
    end
end
```

Custom names are applied to created items automatically.

## Staff mutation APIs

These methods are intended for staff tools and manager UIs. They validate on the server.

- [`WL_ItemLists:createList()`](media/lua/shared/WL_ItemLists.lua)
- [`WL_ItemLists:renameList()`](media/lua/shared/WL_ItemLists.lua)
- [`WL_ItemLists:setListDeleted()`](media/lua/shared/WL_ItemLists.lua)
- [`WL_ItemLists:upsertItemEntry()`](media/lua/shared/WL_ItemLists.lua)
- [`WL_ItemLists:deleteItemEntry()`](media/lua/shared/WL_ItemLists.lua)

Client callers can invoke them directly; they forward to the server automatically.

## Picker dialog

Use [`WL_ItemListPickerDialog:show()`](media/lua/client/UI/WL_ItemListPickerDialog.lua) to let a player choose an active list.

```lua
WL_ItemListPickerDialog:show(self, function(target, selectedListId)
    target.selectedListId = selectedListId
end, {
    title = "Choose Reward List"
})
```

Behavior:

- only active lists are shown
- optional child-list filtering can mark cyclic targets as non-selectable
- the callback receives only the selected list id
- cancel closes the dialog and does **not** call the callback

## Manager window

Staff can open the manager window with [`WL_ItemListManagerWindow:show()`](media/lua/client/UI/WL_ItemListManagerWindow.lua).

```lua
WL_ItemListManagerWindow:show(getPlayer())
```

Non-staff users are refused.

The manager now supports:

- mixed direct-item and child-list entries
- inline nested descendant expansion in the items list
- effective per-parent-roll chance display
- simulation launch via [`WL_ItemListRollSimulatorDialog`](media/lua/client/UI/WL_ItemListRollSimulatorDialog.lua)

Descendant rows are informational only; only top-level saved rows are editable.

## Simulator dialog

[`WL_ItemListRollSimulatorDialog`](media/lua/client/UI/WL_ItemListRollSimulatorDialog.lua) allows staff to inspect:

- observed roll outcomes over many samples
- theoretical effective chances
- last recursive roll trace tree

It does not spawn or materialize real inventory items into player inventories.

## Recommended consumer pattern

Use list ids as your persistent references.

```lua
local rewardListId = "your-saved-list-id"
local items, rolledDefinitions, rollReport = WL_ItemLists:createRolledItems(rewardListId, 1)
if items then
    for i = 1, #items do
        player:getInventory():AddItem(items[i])
    end
end
```

Do not read or mutate [`WL_ItemLists.publicData`](media/lua/shared/WL_ItemLists.lua) directly.
