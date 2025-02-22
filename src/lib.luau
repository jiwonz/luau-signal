--!native

local go = require("@pkg/go")
local tableHelper = require("@luau_pkg/table_helper")

export type Connection<T...> = {
	__index: Connection<T...>,
	connected: boolean,
	_next: Connection<T...>?,
	_prev: Connection<T...>?,
	signal: Signal<T...>,
	fn: (T...) -> (),

	disconnect: (self: Connection<T...>) -> (),
	reconnect: (self: Connection<T...>) -> (),
}

export type Signal<T...> = {
	__index: Signal<T...>,
	_head: Connection<T...>?,

	connect: <U...>(self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	once: <U...>(self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	wait: (self: Signal<T...>) -> T...,
	fire: (self: Signal<T...>, T...) -> (),
	disconnectAll: (self: Signal<T...>) -> (),
	delete: (self: Signal<T...>) -> (),
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
		_signal = self,
		_fn = fn,
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
