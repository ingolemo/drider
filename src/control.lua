local control = {}

function control.new()
	local cont = {}
	cont.prevPad = Controls.read()
	cont.pad = cont.prevPad

	function cont:input()
		self.prevPad = self.pad
		self.pad = Controls.read()
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
		return Controls.readTouch()
	end

	return cont
end

return control
