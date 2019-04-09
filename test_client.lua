--castle://localhost:4000/test_client.lua

local sypri = require("sypri")
local cs = sypri.cs;


sypri.setServer(false);


function sypri.onReceiveData(tableID, data) 
  
  print(tableID)
  
  for k, v in pairs(data) do
    print(k, v);
  end

end);

cs.client.enabled = true;
cs.client.start("localhost:22122");