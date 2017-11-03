utils = {}

function string:wrap(width)
	-- A simple word wrapping function, turns a string into a table of
	-- strings where each item in the table should be on a new line.
	--
	-- It's easier to handle a table than a string containing newline
	-- characters.
	local lines = {}
	local partial = ''

	self:gsub('([^%s]+)', function(word)
		if #partial + #word + 1 < width then
			if partial ~= '' then partial = partial .. ' ' end
			partial = partial .. word
		elseif #word > width then
			table.insert(lines, partial)
			table.insert(lines, word)
			partial = ''
		else
			table.insert(lines, partial)
			partial = word
		end
	end)

	table.insert(lines, partial)
	return lines
end

function string:strip()
	-- Strips any whitespace from either end of a string
	return self:gsub('^%s*', ''):gsub('%s*$', '')
end

function utils.readFile(filename)
	-- Reads the contents of a file from the sd card
	local handle = io.open(filename, FREAD)
	local contents = io.read(handle, 0, io.size(handle))
	io.close(handle)
	return contents
end

function utils.writeFile(filename, contents)
	local handle = io.open(filename, FWRITE)
	io.write(handle, 0, contents, #contents)
	io.close(handle)
end

function utils.utf8ToAscii(text)
	-- tries to translate a string containing utf-8 characters to a
	-- string containing only ascii characters.
	--
	-- The lpp-3ds text rendering code seems to expect windows-1285, but
	-- most of my books seem to use utf8. I don't want to do full text
	-- re-encoding in lua so we just make some simple substitutions to
	-- increase readability.

	-- curly quotes
	text = text:gsub('\xe2\x80\x9c', '"')
	text = text:gsub('\xe2\x80\x9d', '"')
	text = text:gsub('\xe2\x80\x98', "'")
	text = text:gsub('\xe2\x80\x99', "'")

	text = text:gsub('\xe2\x80\x93', '-') -- ndash
	text = text:gsub('\xe2\x80\x94', ' - ') -- mdash
	text = text:gsub('\xe2\x80\xa6', '...')

	return text
end

function utils.unescapeEntities(value)
	local function codePointToChar(n)
		local ASCIImapping = {
			[8211]='-',
			[8212]=' - ',
			[8216]="'",
			[8217]="'",
			[8220]='"',
			[8221]='"',
			[8230]='...',
		}
		local char = ASCIImapping[n]
		if n < 128 then
			-- the character is ascii so just convert it
			return string.char(n)
		elseif char ~= nil then
			-- there's a decent ascii replacement symbol
			return char
		else
			-- our software stack doesn't support non-ascii
			return '?!?'
		end
	end
	-- converts the entities in html and xml to literal characters
	value = value:gsub('&#x([%x]+)%;', function(h)
		return codePointToChar(tonumber(h, 16))
	end)
	value = value:gsub('&#([0-9]+)%;', function(h)
		return codePointToChar(tonumber(h, 10))
	end)
	value = value:gsub('&quot;', '"')
	value = value:gsub('&apos;', "'")
	value = value:gsub('&gt;', '>')
	value = value:gsub('&lt;', '<')
	value = value:gsub('&nbsp;', ' ')
	value = value:gsub('&amp;', '&')
	return value
end

function utils.lerp(start, stop, amount)
	return start + (stop - start) * amount
end

function utils.sign_abs(number)
	local sign = 1
	if number < 0 then
		sign = -1
	end
	return sign, math.abs(number)
end

function error(message)
	-- a simple function that halts the program and displays a message
	-- on the screen until the user presses START. Used for debugging.
	local wrapped = message:wrap(30)
	while true do
		Screen.waitVblankStart()
		Screen.refresh()
		for n, line in ipairs(wrapped) do
			Screen.debugPrint(0, n*20, line, Color.new(255, 0, 255), BOTTOM_SCREEN)
		end
		Screen.flip()
		local pad = Controls.read()
		if Controls.check(pad, KEY_START) then System.exit() end
	end
end

return utils
