local GapNode = {}

function GapNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    return
end

return function(layoutManager)
    layoutManager.registerNode("gap", GapNode)
end
