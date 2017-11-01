local control = {}

function control.new()
	local cont = {}
	cont.prevPad = Controls.read()
	cont.pad = cont.prevPad
	cont.ctx, cont.cty = Controls.readTouch()
	cont.ptx, cont.pty = cont.ctx, cont.cty

	function cont:update()
		self.prevPad = self.pad
		self.pad = Controls.read()
		self.ptx, self.pty = self.ctx, self.cty
		self.ctx, self.cty = Controls.readTouch()
	end

	function cont:down(key)
		local prev = Controls.check(self.prevPad, key)
		local curr = Controls.check(self.pad, key)
		return curr and not prev
	end

	function cont:check(key)
		return Controls.check(self.pad, key)
	end

	function cont:circle()
		return Controls.readCirclePad()
	end

	function cont:touch()
		return self.ctx, self.cty
	end

	function cont:touchDiff()
		if self.ctx == 0 or self.cty == 0 or self.ptx == 0 or self.pty == 0 then
			return nil
		end
		return self.ctx - self.ptx, self.cty - self.pty
	end

	return cont
end

return control
