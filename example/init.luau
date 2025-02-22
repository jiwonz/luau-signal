local Signal = require("../src/lib")
local go = require("../lune_packages/go")

local sig = Signal.new() :: Signal.Signal<number>

local con = sig:connect(function(num: number)
	print("Connected", num)
end)

go(function()
	Signal.wait(sig)
	print("lol")
end)
sig:fire(10)
con:disconnect()
