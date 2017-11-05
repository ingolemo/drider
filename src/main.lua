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

function main.system(cont)
	if System.checkStatus() == APP_EXITING then
		System.exit()
	end
	if cont.start:pressed() then
		System.exit()
	end
	if cont.home:pressed() then
		System.showHomeMenu()
	end
end

function main.choose(choices)
	local cont = control.Controls:new()
	local index = 0
	local menu = render.MenuRenderer:new(choices)

	while true do
		cont:update()
		main.system(cont)

		if cont.a:pressed() and #choices ~= 0 then
			break
		end

		if cont.up:pressed() or cont.circle.up:pressed() then
			index = (index - 1) % #choices
			menu:select(index + 1)
		elseif cont.down:pressed() or cont.circle.down:pressed() then
			index = (index + 1) % #choices
			menu:select(index + 1)
		end

		menu:update()
		menu:draw()
	end

	menu:free()
	return choices[index + 1]
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
	local cont = control.Controls:new()
	local book = epub.load(bookfile)
	local page = render.PageRenderer:new(book)

	while true do
		cont:update()
		main.system(cont)

		if cont.select:pressed() then break end

		if cont.a:pressed() then
			book:toggleBookmark()
			page.dirty = true
		end

		if cont.left:pressed() then
			book:flipBackward()
			page:free()
			page = render.PageRenderer:new(book)
		elseif cont.right:pressed() then
			book:flipForward()
			page:free()
			page = render.PageRenderer:new(book)
		end

		if cont.up:check() then
			page:scroll(-5)
		elseif cont.down:check() then
			page:scroll(5)
		end

		local _, dy = cont.circle:check()
		if dy ~= 0 then
			-- undo friction
			page.velocity = page.velocity * (1/page.friction) + dy
		end

		local _, dy = cont.touchpad:diff()
		if dy ~= nil then
			page.velocity = -dy
		end

		page:update()
		page:draw()
	end

	page:free()
end

return main
