local control = {}

-- CLASS: Button
control.Button = {}
control.Button.__index = control.Button
control.Button.repeat_delay = 15 -- lua runs at 30fps on 3ds
control.Button.repeat_rate = 5
function control.Button:new(id)
	local button = {}
	setmetatable(button, control.Button)
	button.id = id
	button.count = 0
	return button
end

function control.Button:update(pressed_down)
	if pressed_down then
		self.count = self.count + 1
	else
		self.count = 0
	end
end

function control.Button:pressed()
	if self.count == 0 then
		return false
	elseif self.count == 1 then
		return true
	elseif self.count < self.repeat_delay then
		return false
	end
	return ((self.count - self.repeat_delay - 1) % self.repeat_rate) == 0
end

function control.Button:check()
	return self.count ~= 0
end

-- CLASS: Circle
control.Circle = {}
control.Circle.__index = control.Circle
control.Circle.deadzone = 30
control.Circle.max = 150
function control.Circle:new(id)
	local circ = {}
	setmetatable(circ, control.Circle)

	circ.x = 0
	circ.y = 0

	circ.left = control.Button:new()
	circ.right = control.Button:new()
	circ.up = control.Button:new()
	circ.down = control.Button:new()

	return circ
end

function control.Circle:update()
	local x, y = Controls.readCirclePad()

	-- neg is down and pos is up for some reason
	y = -y

	self.x = self:normalise(x)
	self.y = self:normalise(y)

	self.left:update(self.x < 0)
	self.right:update(self.x > 0)
	self.up:update(self.y < 0)
	self.down:update(self.y > 0)
end

function control.Circle:normalise(value)
	if value < -self.max then
		return -1
	elseif value > self.max then
		return 1
	elseif value < -self.deadzone then
		return (value + self.deadzone) / (self.max - self.deadzone)
	elseif value > self.deadzone then
		return (value - self.deadzone) / (self.max - self.deadzone)
	else
		return 0
	end
end

function control.Circle:check()
	return self.x, self.y
end

-- CLASS: Touchpad
control.Touchpad = {}
control.Touchpad.__index = control.Touchpad
control.Touchpad.tap_limit = 5
function control.Touchpad:new()
	local touch = {}
	setmetatable(touch, control.Touchpad)
	touch.count = 0
	touch.prev_count = 0
	touch.x = 0
	touch.y = 0
	touch.prev_x = 0
	touch.prev_y = 0
	return touch
end

function control.Touchpad:update(touched)
	if not touched then
		self.prev_count = self.count
		self.count = 0
		return
	end
	self.prev_x = self.x
	self.prev_y = self.y
	self.x, self.y = Controls.readTouch()
	self.count = self.count + 1
end

function control.Touchpad:check()
	if self.count >= 1 then
		return self.x, self.y
	end
end

function control.Touchpad:diff()
	if self.count >= 2 then
		return self.x - self.prev_x, self.y - self.prev_y
	end
end

function control.Touchpad:tapped()
	if self.count > 0 then
		return
	elseif self.prev_count == 0 then
		return
	elseif self.prev_count <= self.tap_limit then
		return self.x, self.y
	end
end

-- CLASS: Controls
control.Controls = {}
control.Controls.__index = control.Controls
control.Controls.buttons = {
	left = KEY_DLEFT,
	right = KEY_DRIGHT,
	up = KEY_DUP,
	down = KEY_DDOWN,
	a = KEY_A,
	b = KEY_B,
	start = KEY_START,
	select = KEY_SELECT,
	home = KEY_HOME,
	power = KEY_POWER,
}
function control.Controls:new()
	local cont = {}
	setmetatable(cont, control.Controls)

	for name, _ in pairs(self.buttons) do
		cont[name] = control.Button:new()
	end

	cont.circle = control.Circle:new()
	cont.touchpad = control.Touchpad:new()

	return cont
end

function control.Controls:update()
	local pad = Controls.read()
	for name, id in pairs(self.buttons) do
		local pressed = Controls.check(pad, id)
		self[name]:update(pressed)
	end

	self.circle:update()
	self.touchpad:update(Controls.check(pad, KEY_TOUCH))
end

return control
