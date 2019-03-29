--castle://localhost:4000/test_client.lua

local sypri = require("sypri")
local cs = sypri.cs;


sypri.setServer(false);

cs.client.enabled = true;
cs.client.start("localhost:22122");