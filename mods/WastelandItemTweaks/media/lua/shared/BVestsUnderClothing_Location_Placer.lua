local function addBodyLocationBefore(newLocation, movetoLocation) 
  local group = BodyLocations.getGroup("Human"); 
  local list = getClassFieldVal(group, getClassField(group, 1));
  group:getOrCreateLocation(newLocation);
  local newItem = list:get(list:size()-1); 
  list:remove(list:size()-1);
  local i = group:indexOf(movetoLocation) 
  list:add(i, newItem); 
end 

addBodyLocationBefore("TorsoExtraVestUnderJS", "Sweater")
