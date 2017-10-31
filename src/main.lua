local render = import('render')
local epub = import('epub')
local control = import('control')

local main = {}

function main.run()
	while true do
		local bookfile = main.chooseEbook()
		main.readEbook(bookfile)
	end
end

function main.choose(choices)
	local cont = control.new()
	local index = 1
	local menu = render.MenuRenderer:new(choices)

	while true do
		cont:input()

		if System.checkStatus() == APP_EXITING then System.exit() end
		if cont:check(KEY_START) then System.exit() end
		if cont:check(KEY_HOME) then System.showHomeMenu() end

		if cont:down(KEY_A) and #choices ~= 0 then
			break
		end

		if cont:down(KEY_DUP) then
			index = math.max(1, index - 1)
			menu:select(index)
		elseif cont:down(KEY_DDOWN) then
			index = math.min(index + 1, #choices)
			menu:select(index)
		end

		menu:update()
		menu:draw()
	end

	menu:free()
	return choices[index]
end

function main.chooseEbook()
	local books = {}
	for _, file in ipairs(System.listDirectory('/books')) do
		if file.name:sub(-5) == '.epub' then
			table.insert(books, file.name)
		end
	end

	return '/books/' .. main.choose(books)
end

function main.readEbook(bookfile)
	local cont = control.new()
	local book = epub.load(bookfile)
	local function loadImage(src)
		return book:imageFile(src)
	end
	local function compileBook()
		return render.compileHTML(
			book:currentPageHTML(), loadImage,
			book.pagenum, book:isCurrentBookmarked()
		)
	end
	local pageData = compileBook()

	-- the position and velocity of the screen viewport relative to
	-- the top of the ebook
	local y, dy = 0, 0

	-- constants to specify how fast the screen scrolls and slows
	-- down
	local dPadSpeed, friction = 10, 2

	-- whether y has change since the last time the screen was fully
	-- drawn
	local dirty = true

	-- whether any screen scrolling inputs have been made since the
	-- last frame
	local scrolling = false

	-- vars to hold the state of the touchpad
	local touchY, prevTouchY = 0, 0

	while true do
		scrolling = false
		cont:input()

		-- handle exiting application
		if System.checkStatus() == APP_EXITING then System.exit() end
		if cont:check(KEY_START) then System.exit() end
		if cont:check(KEY_SELECT) then break end
		if cont:check(KEY_HOME) then
			System.showHomeMenu()
			dirty = true
			scrolling = true
		end

		if cont:down(KEY_A) then
			-- pageData.bookmarked = book:toggleBookmark()
			book:toggleBookmark()
			pageData = compileBook()
			dirty = true
		end

		-- flip pages
		if cont:check(KEY_DLEFT) then
			book:flipBackward()
			pageData = compileBook()
			y, dy, dirty = 0, 0, true
			scrolling = true -- hack to make it feel more snappy
		elseif cont:check(KEY_DRIGHT) then
			book:flipForward()
			pageData = compileBook()
			y, dy, dirty = 0, 0, true
			scrolling = true -- hack to make it feel more snappy
		end

		-- dpad controls have fixed velocity
		if cont:check(KEY_DUP) then
			dy = -dPadSpeed
			scrolling = true
		elseif cont:check(KEY_DDOWN) then
			dy = dPadSpeed
			scrolling = true
		end

		-- the circle pad scrolls proportionally
		local _, cPadY = cont:circle()
		if math.abs(cPadY) > 30 then
			dy = math.floor(-cPadY/10)
			scrolling = true
		end

		-- touch controls have velocity based on previous position
		prevTouchY = touchY
		_, touchY = cont:touch()
		if touchY ~= 0 and prevTouchY ~= 0 then
			dy = prevTouchY - touchY
			scrolling = true
		end

		-- apply velocity
		if dy ~= 0 then
			if not scrolling then
				-- apply friction
				local abs = math.abs(dy)
				dy = (math.max(0, abs - friction) * math.floor(dy / abs))
			end
			y, dirty = y + dy, true
		end

		--clamp vertical position and velocity when at edge of book
		local maxY = render.getHeight(pageData) - 480
		if y < 0 then y, dy, dirty = 0, 0, true end
		if y > maxY then y, dy, dirty = maxY, 0, true end

		-- draw to screen
		if not dirty then
			render.idle()
		elseif scrolling or dy ~= 0 then
			render.main(pageData, y, true)
		else
			render.main(pageData, y, false)
			dirty = false
		end
	end
end

return main
