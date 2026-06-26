WL_ChunkedProcessor = WL_ChunkedProcessor or {}
WL_ChunkedProcessor.pendingTasks = WL_ChunkedProcessor.pendingTasks or {}
WL_ChunkedProcessor.nextTaskId = WL_ChunkedProcessor.nextTaskId or 1
WL_ChunkedProcessor.isTicking = WL_ChunkedProcessor.isTicking or false

local function doTick()
    WL_ChunkedProcessor:processTasks()
end

--- Add a task to the chunked processor.
--- Will process a specified number of objects per tick.
--- @param task function The function to execute for each object.
--- @param countPer number The number of objects to process per tick.
--- @param objects any[] A table of objects to process.
--- @param completed function|nil A function to call when the task is completed.
--- @param additionalParam1 any|nil An optional additional parameter to pass to the task
--- @param additionalParam2 any|nil An optional additional parameter to pass to the task
--- @param additionalParam3 any|nil An optional additional parameter to pass to the task
--- @param additionalParam4 any|nil An optional additional parameter to pass to the task
function WL_ChunkedProcessor:addTask(task, countPer, objects, completed, additionalParam1, additionalParam2, additionalParam3, additionalParam4)
    local taskId = self.nextTaskId
    self.nextTaskId = self.nextTaskId + 1

    local total = #objects
    if total == 0 then
        -- If there are no objects, immediately complete the task
        if completed then
            completed(additionalParam1, additionalParam2, additionalParam3, additionalParam4)
        end
    end

    self.pendingTasks[taskId] = {
        task = task,
        countPer = countPer,
        objects = objects,
        completed = completed or function() end,
        total = #objects,
        additionalParams = {additionalParam1, additionalParam2, additionalParam3, additionalParam4},
        nextIndex = 1,
    }

    if not self.isTicking then
        self.isTicking = true
        Events.OnTick.Add(doTick)
    end
end

function WL_ChunkedProcessor:processTasks()
    local tasksToRemove = {}

    for taskId, taskData in pairs(self.pendingTasks) do
        local task = taskData.task
        local countPer = taskData.countPer
        local objects = taskData.objects
        local completed = taskData.completed

        local nextIndex = taskData.nextIndex
        local total = taskData.total
        local finalIndex = math.min(nextIndex + countPer - 1, total)

        for i = nextIndex, finalIndex do
            local object = objects[i]
            task(object, taskData.additionalParams[1], taskData.additionalParams[2], taskData.additionalParams[3], taskData.additionalParams[4])
        end

        if finalIndex >= total then
            -- Task completed
            if completed then
                completed(taskData.additionalParams[1], taskData.additionalParams[2], taskData.additionalParams[3], taskData.additionalParams[4])
            end
            table.insert(tasksToRemove, taskId)
        else
            -- Update next index for the next chunk
            taskData.nextIndex = nextIndex + countPer
        end
    end

    for _, taskId in ipairs(tasksToRemove) do
        self.pendingTasks[taskId] = nil
    end

    for _,_ in pairs(self.pendingTasks) do
        return -- If there are still tasks, keep ticking
    end
    Events.OnTick.Remove(doTick)
    self.isTicking = false
end