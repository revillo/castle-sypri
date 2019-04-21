--castle://localhost:4000/shooter_server.lua

local sypri = require("sypri")
local cs = sypri.cs;
local server = cs.server;

sypri.setServer(true);

local playerPositionRoutine = sypri.addRoutine({
  keys = {"x", "y", "dx", "dy"},
  protocol = sypri.RoutineProtocol.UNRELIABLE,
  mode = sypri.RoutineMode.EXACT,
  globalPriority = 1
});


function server.connect(id)
  
  local ps = {
    x = 0,
    y = 0,
    dx = 0,
    dy = 0, 
    
    health = 10,
  
    name = "NoName",
    --wpn = WeaponType.NONE
  }
  
  sypri.addTable("ps "..id, ps, {
    playerPositionRoutine
  });
  
end


function receivePlayerData(tableID, data, clientID)
  
  local serverPlayer = sypri.getTable("ps "..clientID);
  
  sypri.utils.copyInto(serverPlayer, data);

end

function sypri.onAddTable(tableID, data, clientID)

  local fields = sypri.utils.splitString(tableID, " ");
    
  if (fields[1] == "pc") then
    sypri.setTableCallback(tableID, "onReceiveData", receivePlayerData);
  end

end

function server.load()
  
  

end

function server.update(dt)

  sypri.update(dt);

end


server.enabled = true
server.start('22122') -- Port of server