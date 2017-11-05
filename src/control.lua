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

-- CLASS: Controls
control.Controls = {}
control.Controls.__index = control.Controls
function control.Controls:new()
	local cont = {}
	setmetatable(cont, control.Controls)
	local button_ids = {
		KEY_A, KEY_B, KEY_R, KEY_L, KEY_START, KEY_SELECT,
		KEY_X, KEY_Y, KEY_ZL, KEY_ZR,
		KEY_DRIGHT, KEY_DLEFT, KEY_DUP, KEY_DDOWN,
		KEY_TOUCH, KEY_HOME, KEY_POWER,
	}
	self.buttons = {}
	for _, id in ipairs(button_ids) do
		self.buttons[id] = control.Button:new(id)
	end

	self.circle = control.Circle:new()

	cont.ctx, cont.cty = Controls.readTouch()
	cont.ptx, cont.pty = cont.ctx, cont.cty
	return cont
end

function control.Controls:update()
	local pad = Controls.read()
	for id, button in pairs(self.buttons) do
		local pressed = Controls.check(pad, id)
		button:update(pressed)
	end

	self.circle:update()

	self.ptx, self.pty = self.ctx, self.cty
	self.ctx, self.cty = Controls.readTouch()
end

function control.Controls:key(key_id)
	return self.buttons[key_id]
end

function control.Controls:touch()
	return self.ctx, self.cty
end

function control.Controls:touchDiff()
	if self.ctx == 0 or self.cty == 0 or self.ptx == 0 or self.pty == 0 then
		return nil
	end
	return self.ctx - self.ptx, self.cty - self.pty
end

return control
