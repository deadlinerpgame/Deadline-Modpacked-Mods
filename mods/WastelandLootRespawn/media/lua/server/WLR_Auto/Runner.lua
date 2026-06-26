if isClient() then return end

WLR_Auto = WLR_Auto or {}

--- @class WLR_Auto.Runner
--- @field currentInstance WLR_Auto.Instance|nil
--- @field queuedInstances table<number, WLR_Auto.Instance>
WLR_Auto.Runner = WLR_Auto.Runner or WLBaseObject:derive("Runner")

--- @return WLR_Auto.Runner
function WLR_Auto.Runner:new()
    local o = self:super()
    o.currentInstance = nil
    o.queuedInstances = {}
    return o
end

--- @param self WLR_Auto.Runner
--- @param definition WLR_Auto.Definition
--- @param range WLR_Auto.Range
function WLR_Auto.Runner:queue(definition, range)
    local chunkInstance = WLR_Auto.Instance:new(definition, range)
    table.insert(self.queuedInstances, chunkInstance)
end

--- @param self WLR_Auto.Runner
--- @return boolean isDone
function WLR_Auto.Runner:run()
    if not self.currentInstance and #self.queuedInstances > 0 then
        self.currentInstance = table.remove(self.queuedInstances, 1)
        WLR_Auto.DebugLog(string.format(
            "Starting respawn: %s | Zone: %s",
            tostring(self.currentInstance.range),
            self.currentInstance.definition.id
        ))
    end

    if self.currentInstance then
        if self.currentInstance:run() then
            self.currentInstance = nil
        end
        return false
    end
    return true
end