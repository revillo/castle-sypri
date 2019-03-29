local cs = require("cs")
local marshal = require 'marshal' -- Serialization
local List = require ("lib/list")

local Utils = {};

function Utils.overwrite(toTable, fromTable)
  
  for k,v in pairs(toTable) do
    toTable[k] = nil;
  end
  
  Utils.copyInto(toTable, fromTable);
  return toTable;
end

function Utils.copyInto(toTable, fromTable, keys)
  
  if (fromTable) then
    for k, v in pairs(keys or fromTable) do
        if (type(v) == "table") then
          toTable[k] = Utils.copyInto({}, v);
        else
          toTable[k] = v;
        end
    end  
  end
  return toTable;
  
end

function Utils.clone(fromTable)
  return Utils.overwrite({}, fromTable); 
end

function Utils.cloneKeys(fromTable, keys)
  
  if (not keys) then
    return Utils.clone(fromTable);
  end
  
  local result = {};
  
  for i, key in pairs(keys) do
    result[key] = fromTable[key]; 
  end

  return result;
end

function Utils.isEqual(a, b) 
  
    if (a == b) then
      return true;
    end
    
    if (type(a) == "table" and type(b) == "table") then
      for k, v in pairs(a) do
        if (v ~= b[k]) then
          return false
        end
      end
      
      return true;
    end
    
    return false;
  
end

function Utils.diff(tabl, prevTable, keys)
  if (not prevTable) then
    return Utils.cloneKeys(tabl, keys);
  end
  
  local result = {};
  
  for i, key in pairs(keys) do
    if (not Utils.isEqual(tabl[key], prevTable[key])) then
      result[key] = tabl[key];
    end
  end
  
  --Check for empty table
  if (next(result) == nil) then 
    
    return nil;
  
  end
  
  return result;
    
end

function Utils.merge(tabl, prevTable)
  
  local result = {};
  
  Utils.copyInto(result, prevTable);
  Utils.copyInto(result, tabl);
  
  return result;

end

local sypri = {
  isServer = false
};

local sRoutines = {};
local sTables = {};
local sRoutineID = 0;
local sTableHistory = {};
local sUpdateRoutines = {};
local sTableSaves = {};
local sClock = 0;

sypri.RoutineMode = {
  DIFF = 1,
  EXACT = 2,
  STATIC = 3 -- Send table data only spawn/despawn or client connect
}

sypri.RoutineProtocol = {
  UNRELIABLE = 1,
  RELIABLE = 2
}

function sypri.receiveTableData(tableID, data)
  
  print("id:", tableID);
  for k, v in pairs(data) do
    print(k, v);
  end
  
  sTableHistory[tableID] = sTableHistory[tableID] or List.new();
  local history = sTableHistory[tableID];
  
  List.pushright(history, Utils.merge(data, history[history.last]));

end

function sypri.setServer(toggle)
  
  sypri.isServer = toggle;
 
   cs.server.numChannels = 3;
   cs.client.numChannels = 3;
   
   if (sypri.isServer) then
    
    cs.server.receiveSypri = function(msg)
      sypri.receiveTableData(msg.id, msg.d);
    end
   
   else
    
    cs.client.receiveSypri = function(msg)
      sypri.receiveTableData(msg.id, msg.d);
    end
   
   end
   
end

function sypri.addTable(id, tabl, routines)
  sTables[id] = tabl;
  sTableHistory[id] = List.new();
  
  List.pushright(sTableHistory[id], Utils.clone(tabl));
  
  for i, routine in pairs(routines) do
    routine.tables[id] = tabl;
  end
  
end

function sypri.removeTable(id)
  sTables[id] = nil;
end

function sypri.addRoutine(parameters)

  local routine = parameters;
  
  routine.tables = routine.tables or {};
  routine.protocol = routine.protocol or sypri.RoutineProtocol.RELIABLE
  routine.minRate = routine.minRate or 1.0 / 1.0;
  routine.maxRate = routine.maxRate or 1.0 / 30.0;
  routine.maxHistory = routine.maxHistory or 2;
  routine.mode = routine.mode or sypri.RoutineMode.EXACT;
  
  routine.lastSync = -10.0;
  
  routine.id = sRoutineID;
  sRoutineID = sRoutineID + 1;
  sRoutines[routine.id] = routine;
  
  if (routine.mode ~= sypri.RoutineMode.STATIC) then
    sUpdateRoutines[routine.id] = routine;
  end
  
  return routine;
  
end

function sypri.removeRoutine(routine)
  sUpdateRoutines[routine.id] = nil;
  sRoutines[routine.id] = nil;
end

function sypri.transmitTableData(routine, tableID, tabl)
  
  local flag = "reliable";
  local channel = 0;
  
  if (routine.protocol == sypri.RoutineProtocol.UNRELIABLE) then
    flag = "unreliable";
    channel = 1;
  end
  

  local newData = nil;
  local encodedMsg = nil;
  
  if (routine.mode == sypri.RoutineMode.EXACT) then
    newData = Utils.cloneKeys(tabl, routine.keys);
  elseif (routine.mode == sypri.RoutineMode.DIFF) then
    local prevTable = sTableSaves[tableID];
    newData = Utils.diff(tabl, prevTable, routine.keys);
    sTableSaves[tableID] = Utils.cloneKeys(tabl, routine.keys);
  end
  
  if (not newData) then
    return
  end
  
  encodedMsg = marshal.encode({
    sypri = {
      id = tableID,
      d = newData
    }
  });
  
  if (sypri.isServer) then
    cs.server.sendEncoded('all', encodedMsg, channel, flag);
  else
    cs.client.sendEncoded(encodedMsg, channel, flag);
  end  
  
end

function sypri.update(dt)
  
  sClock = sClock + dt;
  
  for rID, routine in pairs(sUpdateRoutines) do
    
    local delta = sClock - routine.lastSync;
    
    if (delta >= routine.maxRate)  then
      
      routine.lastSync = sClock;
    
      for tID, tabl in pairs(routine.tables) do
    
        sypri.transmitTableData(routine, tID, tabl);
      
      end -- each table
    end -- should sync
  end -- each routine
  
end


sypri.cs = cs;

return sypri;