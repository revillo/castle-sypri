--castle://localhost:4000/test_server.lua

local sypri = require("sypri");
local cs = sypri.cs;

sypri.setServer(true);

local dataTable = {
  x = 1,
  y = 1,
  noupdate = "get me once"
}

xRoutine = sypri.addRoutine({
  
  keys = {"x", "noupdate"},
  globalPriority = 60,
  protocol = sypri.RoutineProtocol.RELIABLE,
  mode = sypri.RoutineMode.DIFF

});

yRoutine = sypri.addRoutine({
  
  keys = {"y"},
  globalPriority = 30,
  protocol = sypri.RoutineProtocol.UNRELIABLE,
  mode = sypri.RoutineMode.EXACT;

});

sypri.addTable("data", dataTable, { xRoutine, yRoutine });

cs.server.connect = function(clientID)
  
  sypri.addClient(clientID);
  
end


function cs.server.update(dt)
  
    dataTable.x = dataTable.x + dt;
    dataTable.y = dataTable.y + dt;
  
    sypri.update(dt);

end

cs.server.enabled = true
cs.server.start('22122') -- Port of server
