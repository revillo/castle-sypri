--castle://localhost:4000/test_server.lua

local sypri = require("sypri");
local cs = sypri.cs;

sypri.setServer(true);


xRoutine = sypri.addRoutine({
  
  keys = {"x"},
  maxRate = 2,
  protocol = sypri.RoutineProtocol.RELIABLE,
  mode = sypri.RoutineMode.EXACT

});

yRoutine = sypri.addRoutine({
  
  keys = {"y"},
  maxRate = 1.0;
  protocol = sypri.RoutineProtocol.UNRELIABLE,
  mode = sypri.RoutineMode.EXACT;

});

local dataTable = {
  x = 1,
  y = 1
}

sypri.addTable("data", dataTable, { xRoutine, yRoutine });

function cs.server.update(dt)
  
    dataTable.x = dataTable.x + dt;
    dataTable.y = dataTable.y + dt;
  
    sypri.update(dt);

end

cs.server.enabled = true
cs.server.start('22122') -- Port of server
