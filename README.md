# luau-signal
Fast and simple signal class for Luau, Lune, and Roblox

This project is a fork of [LemonSignal](https://github.com/Data-Oriented-House/LemonSignal)

## Installation
Install via pesde
```sh
pesde add jiwonz/signal
```

## Usage
```lua
local Signal = require("../luau_packages/signal")

local sig = Signal.new() :: Signal.Signal<number> -- Fully typed

local connection = sig:connect(function(x)
	print(`2 + {x} = {2 + x}`)
end)

sig:fire(1)
connection:disconnect()

-- Reconnection
local once = sig:once(function(x)
	print(x ^ 2)
end)

sig:fire(5) -- prints "25"
once:reconnect()
sig:fire(10) -- prints "100"
sig:fire(2) -- prints nothing

-- Destruction
sig:disconnectAll()
sig:delete() -- Disconnects all connections and makes itself unusable
```
