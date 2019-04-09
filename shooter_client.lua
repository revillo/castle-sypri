--castle://localhost:4000/shooter_client.lua

local sypri = require("sypri")
local cs = sypri.cs;
local client = cs.client;

sypri.setServer(false);

local playerInited = false;

local playerClientID = nil;
local playerServerID = nil;

local serverPlayers = {};
local clientPlayers = {};
local sypLists = {};

local playerLocal = {
  x = 0,
  y = 0,
  dx = 0,
  dy = 0,  
  
  health = 10,
  
  name = "NoName",
  --wpn = WeaponType.NONE
};

function sypri.onAddTable(tableID)  
  local fields = sypri.utils.splitString(tableID, " ");
  
  local kind = fields[1];
  local id = fields[2];
  
  sypLists[kind] = sypLists[kind] or {};
  sypLists[kind][id] = tableID;
  
end


local playerPositionRoutine = sypri.addRoutine({

  keys = {"x", "y", "dx", "dy"},
  protocol = sypri.RoutineProtocol.UNRELIABLE,
  mode = sypri.RoutineMode.EXACT,
  globalPriority = 1

});

--[[
local playerETCRoutine = sypri.addRoutine({
  
  keys = {"name", "wpn"}
  mode = sypri.RoutineMode.DIFF,
  protocol = sypri.RoutineProtocol.RELIABLE,
  globalPriority = 30
  
});

local playerHealthRoutine = sypri.addRoutine({

  keys = {"health"},
  mode = sypri.RoutineMode.DIFF,
  protocol = sypri.RoutineProtocol.RELIABLE,
  globalPriority = 10,

});
]]


function client.update(dt)

  sypri.update(dt);
  
  local mx, my = 0, 0
  
  if (love.keyboard.isDown("w")) then
    my = -1;
  end
  
  if (love.keyboard.isDown("s")) then
    my = 1;
  end
  
  if (love.keyboard.isDown("a")) then
    mx = -1;
  end
  
  if (love.keyboard.isDown("d")) then
    mx = 1;
  end

  local mag = mx * mx + my * my;
  
  if (mag > 0) then
    mx = mx / mag;
    my = my / mag;
  end
  
  local speed = 40.0 * dt;
  
  playerLocal.x = playerLocal.x + mx * speed;
  playerLocal.y = playerLocal.y + my * speed;
end

function drawRect(x, y, w, h)

  love.graphics.rectangle("fill", x + 100, y + 100, w, h);

end;

function client.draw()

  if (not playerClientID) then
    return;
  end  

  local pc = playerLocal;
  --local ps = sypri.getTable(playerServerID);
  
  love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
  drawRect(pc.x, pc.y, 10, 10);
  
  --[[
  if (ps) then
    love.graphics.setColor(0.0, 1.0, 0.0, 1.0);
    drawRect(ps.x, ps.y, 10, 10);
  end
  ]]
  
  for clientID, tableID in pairs(sypLists["ps"] or {}) do
    local ps = sypri.getTable(tableID);
    love.graphics.setColor(0.0, 1.0, 0.0, 1.0);
    drawRect(ps.x, ps.y, 10, 10);
  end
  
end

function client.connect()
  
  playerClientID = "pc "..client.id;
  playerServerID = "ps "..client.id;
  
  sypri.addTable(playerClientID, playerLocal, 
    {
      playerPositionRoutine
    }
  ); 
  
end


function client.load()


end

client.enabled = true;
client.start("localhost:22122");