--!native

local go = require("@pkg/go")
local tableHelper = require("@luau_pkg/table_helper")
local task = require("@pkg/task")

--[=[
	@class Connection

	A connection object that represents a connection and relations between a signal and a function.
]=]
export type Connection<T...> = {
	__index: Connection<T...>,
	--[=[
		@within Connection

		Determines if the connection is connected.
	]=]
	connected: boolean,
	_next: Connection<T...>?,
	_prev: Connection<T...>?,
	--[=[
		@within Connection

		The signal that the connection is connected to.
	]=]
	signal: Signal<T...>,
	--[=[
		@within Connection

		The function that the connection is connected to.
	]=]
	fn: (T...) -> (),

	--[=[
		@within Connection

		Disconnects the connection from the signal.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		local con = sig:connect(function(num: number)
			print("Connected", num)
		end)

		con:disconnect()
		```
	]=]
	disconnect: (self: Connection<T...>) -> (),
	--[=[
		@within Connection

		Reconnects the connection to the signal.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		local con = sig:connect(function(num: number)
			print("Connected", num)
		end)

		con:disconnect()
		con:reconnect()
		```
	]=]
	reconnect: (self: Connection<T...>) -> (),
}

--[=[
	@class Signal

	A signal object that represents a signal and connections to functions.
]=]
export type Signal<T...> = {
	__index: Signal<T...>,
	_head: Connection<T...>?,

	--[=[
		@within Signal

		Connects a function to the signal.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		local con = sig:connect(function(num: number)
			print("Connected", num)
		end)
		```
	]=]
	connect: <U...>(self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	--[=[
		@within Signal

		Connects a function to the signal that will only be called once.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		local con = sig:once(function(num: number)
			print("Connected", num)
		end)

		con:fire(10) -- Prints "Connected 10" and disconnects the connection.
		```
	]=]
	once: <U...>(self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	--[=[
		@within Signal

		Yields the current thread until the signal is fired.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		task.spawn(function()
			local num = sig:wait()
			print("Waited", num)
		end)

		sig:fire(10) -- Prints "Waited 10"
		```
	]=]
	wait: (self: Signal<T...>) -> T...,
	--[=[
		@within Signal

		Fires the signal with the given arguments.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		sig:connect(function(num: number)
			print("Connected", num)
		end)

		sig:fire(10) -- Prints "Connected 10"
		```
	]=]
	fire: (self: Signal<T...>, T...) -> (),
	--[=[
		@within Signal

		Disconnects all connections from the signal.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		sig:connect(function(num: number)
			print("Connected", num)
		end)

		sig:disconnectAll()
		```
	]=]
	disconnectAll: (self: Signal<T...>) -> (),
	--[=[
		@within Signal

		Deletes the signal and disconnects all connections from the signal.

		Makes the signal unusable.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		sig:connect(function(num: number)
			print("Connected", num)
		end)

		sig:delete()

		sig:fire() -- Error: Signal is deleted
		```
	]=]
	delete: (self: Signal<T...>) -> (),
	--[=[
		@within Signal

		Creates a new signal.

		```lua
		local sig = Signal.new() :: Signal.Signal<number>
		```
	]=]
	new: () -> Signal<T...>,
}

local Connection = {} :: Connection<>
Connection.__index = Connection

function Connection.disconnect(self)
	if not self.connected then
		return
	end
	self.connected = false

	local next = self._next
	local prev = self._prev

	if next then
		next._prev = prev
	end
	if prev then
		prev._next = next
	end

	local signal = self.signal
	if signal._head == self then
		signal._head = next
	end
end

function Connection.reconnect(self)
	if self.connected then
		return
	end
	self.connected = true

	local signal = self.signal
	local head = signal._head
	if head then
		head._prev = self
	end
	signal._head = self

	self._next = head
	self._prev = false :: any
end

local Signal = {} :: Signal<...any>
Signal.__index = Signal

local deleted = tableHelper.Deleted.new(Signal, "Signal") :: tableHelper.Deleted<Signal<...any>>

function Signal.connect(self, fn)
	local head = self._head
	local cn: Connection<...any> = setmetatable({
		connected = true,
		signal = self,
		fn = fn,
		_next = head,
		_prev = false,
	}, Connection) :: any

	if head then
		head._prev = cn
	end
	self._head = cn

	return cn
end

function Signal.once(self, fn)
	local cn
	cn = self:connect(function(...)
		cn:disconnect()
		fn(...)
	end)
	return cn
end

function Signal.wait(self)
	local thread = coroutine.running()
	local cn
	cn = self:connect(function(...)
		cn:disconnect()
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end)
	return coroutine.yield()
end

function Signal.fire(self, ...)
	local cn = self._head
	while cn do
		go(cn.fn, ...)
		cn = cn._next
	end
end

function Signal.disconnectAll(self)
	local cn = self._head
	while cn do
		cn:disconnect()
		cn = cn._next
	end
end

function Signal.delete(self)
	self:disconnectAll()
	deleted:setmetatable(self)
end

function Signal.new()
	return setmetatable({ head = false }, Signal) :: any
end

return Signal
