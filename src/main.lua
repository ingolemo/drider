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
		cont:update()

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
	local page = render.PageRenderer:new(book)

	while true do
		cont:update()

		if System.checkStatus() == APP_EXITING then System.exit() end
		if cont:check(KEY_START) then System.exit() end
		if cont:check(KEY_SELECT) then break end
		if cont:check(KEY_HOME) then
			System.showHomeMenu()
		end

		if cont:down(KEY_A) then
			book:toggleBookmark()
		end

		if cont:check(KEY_DLEFT) then
			book:flipBackward()
			page:free()
			page = render.PageRenderer:new(book)
		elseif cont:check(KEY_DRIGHT) then
			book:flipForward()
			page:free()
			page = render.PageRenderer:new(book)
		end

		if cont:check(KEY_DUP) then
			page:scroll(-10)
		elseif cont:check(KEY_DDOWN) then
			page:scroll(10)
		end

		local _, dy = cont:circle()
		if dy ~= nil and math.abs(dy) > 30 then
			dy = math.floor(dy/10)
			page:scroll(-dy)
		end

		local _, dy = cont:touchDiff()
		if dy ~= nil and dy ~= 0 then
			page:scroll(-dy)
		end

		page:update()
		page:draw()
	end

	page:free()
end

return main
