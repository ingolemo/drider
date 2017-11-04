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
	button.pressed = 0
	return button
end

function control.Button:update(pressed_down)
	if pressed_down then
		self.pressed = self.pressed + 1
	else
		self.pressed = 0
	end
end

function control.Button:down()
	if self.pressed == 0 then
		return false
	elseif self.pressed == 1 then
		return true
	elseif self.pressed < self.repeat_delay then
		return false
	end
	return ((self.pressed - self.repeat_delay - 1) % self.repeat_rate) == 0
end

function control.Button:check()
	return self.pressed ~= 0
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

	self.ptx, self.pty = self.ctx, self.cty
	self.ctx, self.cty = Controls.readTouch()
end

function control.Controls:key(key_id)
	return self.buttons[key_id]
end

function control.Controls:circle()
	return Controls.readCirclePad()
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
