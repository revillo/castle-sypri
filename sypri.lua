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


function Utils.splitString(str, sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   str:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

local sypri = {
  isServer = false,
  utils = Utils
};

-- Local Fields

local sRoutines = {};
local sTables = {};
local sRoutineID = 0;
local sTableHistory = {};
local sUpdateRoutines = {}; -- Routines involved in the update loop
local sBroadCastRoutines = {}; -- Routines that broadcast to all clients
local sTableSaves = {};
local sClock = 0;
local sTableCallbacks = {};
--local sGlobalCallbacks = {};
local sTimeStep = 0;
local sDirtyKeyTimes = {};
local sUpdateRate = 30;
local sCSHost = nil;

local sBandwidthCap = 1000;
local sCurrentBandwidth = 0;
local sCapBandwidth = false;

local sPriorityAccums = {};
local sAccumSorter = {};


-- Enums

sypri.EnetChannel = {
  RELIABLE = 0,
  UNRELIABLE = 1
}

sypri.RoutineMode = {
  DIFF = 1,
  EXACT = 2,
  STATIC = 3 -- Send table data only spawn/despawn or client connect
}

sypri.RoutineProtocol = {
  RELIABLE = 0,
  UNRELIABLE = 1
}

sypri.RoutineServerMode = {
  BROADCAST = 1,
  INDIVIDUAL = 2
}

sypri.RoutineDiffMode = {
  AUTO = 1,
  MANUAL = 2
}


-- Global callbacks
function sypri.onAddTable(tableID, data, clientID)

end

function sypri.onReceiveData(tableID, data, clientID)

end

function sypri.receiveEvent(event, clientID)

end

-- Sypri Implementation

function sypri.setUploadCap(cap)
  
  sBandwidthCap = cap;
  sCapBandwidth = true;

end

function sypri.receiveTableData(tableID, data, clientID)
  
  local callbacks = sTableCallbacks[tableID];

  
  if (not sTables[tableID]) then
	
    sTables[tableID] = Utils.clone(data);
    
    if (callbacks and callbacks.onTableAdded) then
      callbacks.onTableAdded(tableID, sTables[tableID]);
    end
    
    if (sypri.onAddTable) then
      sypri.onAddTable(tableID, sTables[tableID]);
    end
	
  end
  
  sTableHistory[tableID] = sTableHistory[tableID] or List.new();
  local history = sTableHistory[tableID];
  
  local addOrReject = true;
  
  if (callbacks and callbacks.onReceiveData) then
    addOrReject = callbacks.onReceiveData(tableID, data, clientID)
    if (addOrReject == nil) then
      addOrReject = true;
    end
  end
  
  sypri.onReceiveData(tableID, data, clientID);
  
  if (addOrReject) then
    List.pushright(history, Utils.merge(data, history[history.last]));
    
    if (List.length(history) > 60) then
      List.popleft(history);
    end
    
      Utils.copyInto(sTables[tableID], data);
  end

end

function sypri.setTableCallback(tableID, eventName, callback)
  sTableCallbacks[tableID] = sTableCallbacks[tableID] or {};
  sTableCallbacks[tableID][eventName] = callback;
end

function sypri.setGlobalCallback(eventName, callback)
  sGlobalCallbacks[eventName] = callback;
end

function sypri.getTableHistory(tableID) 
  return sTableHistory[tableID];
end

function sypri.getTable(tableID)
  return sTables[tableID];
end

function sypri.setServer(toggle)
  
  sypri.isServer = toggle;
  
  if (sypri.isServer) then
    sCSHost = cs.server
  else
    sCSHost = cs.client
  end
  
  sCSHost.numChannels = 3;  
    
  sCSHost.receiveSypriTable = function(msg, clientID)
    sypri.receiveTableData(msg.id, msg.d, clientID);
  end
 
  sCSHost.receiveSypriEvent = function(msg, clientID)
    sypri.receiveEvent(msg, clientID);
  end
   
end

function sypri.addRoutines(tableID, routines)
  for i, routine in pairs(routines) do
    routine.tables[id] = tabl;
  end
end

function sypri.addTable(id, tabl, routines)
  sTables[id] = tabl;
  sTableHistory[id] = List.new();
  
  List.pushright(sTableHistory[id], Utils.clone(tabl));
  
  for i, routine in pairs(routines) do
    routine.tables[id] = tabl;
    routine.priorityAccum[id] = 0;
  end
  
end

function sypri.removeTable(id)
  sTables[id] = nil;
end

function sypri.addRoutine(parameters)

  local routine = parameters;
  
  routine.tables = routine.tables or {};
  routine.protocol = routine.protocol or sypri.RoutineProtocol.RELIABLE
  routine.globalPriority = routine.globalPriority or 2; --Sets a global priority of every other frame for all tables and clients
  routine.mode = routine.mode or sypri.RoutineMode.EXACT;
  routine.lastSync = -10.0;
  routine.id = sRoutineID;
  routine.diffMode = routine.diffMode or sypri.RoutineDiffMode.AUTO;
  sRoutineID = sRoutineID + 1;
  sRoutines[routine.id] = routine;
  routine.priorityAccum = {};
  
  
  if (sypri.isServer) then
    routine.serverMode = routine.serverMode or sypri.RoutineServerMode.BROADCAST;
    
    if (routine.serverMode == sypri.RoutineServerMode.INDIVIDUAL) then
      sBroadCastRoutines[routine.id] = nil;
    else
      sBroadCastRoutines[routine.id] = routine;
    end
    
  else
    routine.serverMode = nil;
  end
  
  if (routine.mode ~= sypri.RoutineMode.STATIC) then
    sUpdateRoutines[routine.id] = routine;
  end
  
  sBroadCastRoutines[routine.id] = routine;
  
  return routine;
  
end

function sypri.setClientPriority(routine, clientID, tableID, priority)

  assert(sypri.isServer, 
    "Sypri Warning: should only set client priorities on server");
  assert(routine.serverMode == sypri.RoutineServerMode.INDIVIDUAL, 
    "Sypri Warning: can only set client priorities on routine with serverMode == sypri.RoutineServerMode.INDIVIDUAL");

  sBroadCastRoutines[routine.id] = nil;
  routine.tableClientLastSync = routine.tableClientLastSync or {};
  routine.tableClientLastSync[tableID] = routine.tableClientLastSync[tableID] or {};
  routine.tableClientPriority = routine.tableClientPriority or {};
  routine.tableClientPriority[tableID] = routine.tableClientPriority[tableID] or {};
  routine.tableClientPriority[tableID][clientID] = priority or routine.globalPriority;
  --routine.globalPriority = nil; -- Disable global priority if setClientPriority is used??
end 

function encodeEvent(event)
  return marshal.encode({
    syp_e = event
  });
end

function encodeTableData(tableID, data)
  return marshal.encode({
    syp_td = {
      id = tableID,
      d = data
    }
  });
end

function sypri.eachTableInRoutine(routine, fn, ...)
  for tableID, tabl in pairs(routine.tables) do
    fn(routine, tableID, tabl, ...);
  end 
end

function sendExactToClient(routine, tableID, tabl, clientID)
  exactData = Utils.cloneKeys(tabl, routine.keys);
  local encodedMsg = encodeTableData(tableID, exactData);
  cs.server.sendEncoded(clientID, encodedMsg, sypri.EnetChannel.RELIABLE, "reliable");
end

function sypri.addClient(clientID) 
  for routineID, routine in pairs(sBroadCastRoutines) do
    sypri.eachTableInRoutine(routine, sendExactToClient, clientID);
  end
end

function sypri.removeRoutine(routine)
  sUpdateRoutines[routine.id] = nil;
  sRoutines[routine.id] = nil;
end

function sypri.removeRoutineFromTable(routine, tableID)
  routine.tables[tableID] = nil;
  routine.priorityAccum[tableID] = nil;
end

function sendTableDataServer(routine, exactData, diffData, tableID, tabl, channel, flag)


  if (routine.serverMode == sypri.RoutineServerMode.BROADCAST) then
    
       ----------- Server to all -----------
      if (not exactData and not diffData) then
        return
      end
    
      local encodedMsg = encodeTableData(tableID, exactData or diffData);
      
      cs.server.sendEncoded('all', encodedMsg, channel, flag);
      
  elseif (routine.serverMode == sypri.RoutineServerMode.INDIVIDUAL) then
  
    ----------- Server to certain clients -----------
    for clientID, priority in pairs(routine.tableClientPriority) do
      
      local lastSync = routine.tableClientLastSync[tableID][clientID] or -1;
      
      -- Use client priority
      if (sClock - lastSync >= priority/sUpdateRate) then
        
        -- Exact --
        if (lastSync < 0 or routine.mode == sypri.RoutineMode.EXACT) then
          
          encodedMsg = encodeTableData(tableID, exactData);
          
          cs.server.sendEncoded(clientID, encodedMsg, channel, flag);        

        elseif (routine.mode == sypri.RoutineMode.DIFF) then
        -- Diff -- 
          local sendData = {};
          local shouldSend = false;
          
          for key, keyDirtyTime in sDirtyKeyTimes[tableID] do
            if (keyDirtyTime > lastSync) then
              shouldSend = true;
              sendKeys[key] = tabl[key];
            end
          end

          -- todo, reuse encoded msg for certain clients
          if (shouldSend) then
            local encodedMsg = encodeTableData(tableID, sendKeys);
            
            cs.server.sendEncoded(clientID, encodedMsg, channel, flag);   
          end
        end
        
        routine.tableClientLastSync[tableID][clientID] = sClock;
      end -- client priority

    end -- each client
  end 

end

function sendTableDataClient(routine, exactData, diffData, tableID, channel, flag)
    
    ----------- Client to Server ----------- 
    
    if (not exactData and not diffData) then
      return
    end
    
    if (sCapBandwidth and sCurrentBandwidth > sBandwidthCap) then return end;
    
    local encodedMsg = encodeTableData(tableID, exactData or diffData);
    
    if (sCapBandwidth) then
      local msgSize = #encodedMsg;
      
      sCurrentBandwidth = sCurrentBandwidth + msgSize;
      
      if (sCurrentBandwidth + msgSize > sBandwidthCap) then
        return;
      else -- bandwidth not exceeded, reset accum
      
        sCurrentBandwidth = sCurrentBandwidth + msgSize;
        
        local hash = routine.id.."+"..tableID;
        local fields = sPriorityAccums[hash];
        if (fields) then
          sPriorityAccums[hash].accum = 0;
        end
      end
    end
    
    cs.client.sendEncoded(encodedMsg, channel, flag);

end

--[[
function handleBandwidthExceeded(routine, tableID)

  

end
]]

function sypri.sendTableData(routine, tableID, tabl)
  
  local flag = "reliable";
  local channel = sypri.EnetChannel.RELIABLE;
  
  if (routine.protocol == sypri.RoutineProtocol.UNRELIABLE) then
    flag = "unreliable";
    channel = sypri.EnetChannel.UNRELIABLE;
  end
  

  local exactData = nil;
  local diffData = nil;
  local encodedMsg = nil;
  
  if (routine.mode == sypri.RoutineMode.EXACT) then
    exactData = Utils.cloneKeys(tabl, routine.keys);
  elseif (routine.mode == sypri.RoutineMode.DIFF) then
  
    -- TODO -- look at dirty key times if diff has already been run
    local prevTable = sTableSaves[tableID];
    diffData = Utils.diff(tabl, prevTable, routine.keys);
    sTableSaves[tableID] = Utils.cloneKeys(tabl, routine.keys);
    
    if (diffData) then
      sDirtyKeyTimes[tableID] = sDirtyKeyTimes[tableID] or {};
    
      for k, v in pairs(diffData) do
        sDirtyKeyTimes[tableID] = sClock;
      end
    end
    
  end
  
  if (sypri.isServer) then
    
    sendTableDataServer(routine, exactData, diffData, tableID, tabl, channel, flag);
    
  else -- is server
  
    sendTableDataClient(routine, exactData, diffData, tableID, channel, flag);
    
  end  
  
end

function sypri.sendEvent(event, clients)
  
  local encoded = encodeEvent(event);
  
  if (sypri.isServer) then
    
    if (clients) then
      
      for i, clientID in pairs(clients) do
        cs.server.sendEncoded(clientID, encoded, sypri.EnetChannel.RELIABLE, "reliable"); 
      end
           
    else
      cs.server.sendEncoded('all', encoded, sypri.EnetChannel.RELIABLE, "reliable"); 
    end
  
  else
    cs.client.sendEncoded(encoded, sypri.EnetChannel.RELIABLE, "reliable");
  end
end

function accumCompare(a, b) 

  return sPriorityAccums[a].accum > sPriorityAccums[b].accum;

end

function accumulatePriorities()

  sAccumSorter = {};

  local sorterIndex = 1;
  
  for rID, routine in pairs(sUpdateRoutines) do
    
    for tableID, tabl in pairs(routine.tables) do
      
      --routine.priorityAccum[tableID] = (routine.priorityAccum[tableID] or 0) + (30.0 / routine.globalPriority);
      
      local hash = rID.."+"..tableID;
      
      sPriorityAccums[hash] = sPriorityAccums[hash] or {
        routineID = rID,
        tableID = tableID,
        accum = 0
      }
      
      local addition = 0;
      
      if (routine.globalPriority > 0) then
        addition = (sUpdateRate/routine.globalPriority);
      end
      
      local accum = sPriorityAccums[hash].accum + addition;
      
      sPriorityAccums[hash].accum = accum;
      
      if (accum >= sUpdateRate) then
        sAccumSorter[sorterIndex] = hash;
        sorterIndex = sorterIndex + 1;
      end
      
    end
    
  end
  
  table.sort(sAccumSorter, accumCompare);
  
end

local sLastTick = -10;

function sypri.update(dt)
  
  sClock = sClock + dt;
  
  if (sClock - sLastTick < 1.0/sUpdateRate) then
    return;
  else
    sTimeStep = sTimeStep + 1;
    sLastTick = sClock;
    
    if (sTimeStep % sUpdateRate == 0) then
      print(sCurrentBandwidth);
      sCurrentBandwidth = 0;
    end
  end
  
  if (sCapBandwidth) then
  
    sAccumSorter = {};
    
    accumulatePriorities();
  
    for i, hash in ipairs(sAccumSorter) do
      local fields = sPriorityAccums[hash];
      local routine = sRoutines[fields.routineID];
      local tableID = fields.tableID;
      
      
      sypri.sendTableData(routine, tableID, routine.tables[tableID]);
    end
  
  else
  
    for rID, routine in pairs(sUpdateRoutines) do
      
      local delta = sClock - routine.lastSync;
      
      if (delta >= routine.globalPriority / sUpdateRate)  then
        
        routine.lastSync = sClock;
      
        for tableID, tabl in pairs(routine.tables) do
        
          sypri.sendTableData(routine, tableID, tabl);

        end -- each table
      end -- should sync
    end -- each routine
  end

  end
  
sypri.cs = cs;

return sypri;