local render = import('render')
local epub = import('epub')
local control = import('control')

local main = {}

function main.run()
	while true do
		local bookfile, showImages = main.chooseEbook()
		main.readEbook(bookfile, showImages)
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
	local showImages = true

	while true do
		cont:update()
		main.system(cont)

		if cont.a:pressed() and #choices ~= 0 then
			break
		end

		if cont.x:pressed() then
			showImages = not showImages
			menu.dirty = true
		end

		if cont.up:pressed() or cont.circle.up:pressed() then
			index = (index - 1) % #choices
			menu:select(index + 1)
		elseif cont.down:pressed() or cont.circle.down:pressed() then
			index = (index + 1) % #choices
			menu:select(index + 1)
		end

		menu:update()
		menu:draw(showImages)
	end

	menu:free()
	return choices[index + 1], showImages
end

function main.chooseEbook()
	local books = {}
	for _, file in ipairs(System.listDirectory('/books')) do
		if file.name:sub(-5) == '.epub' then
			table.insert(books, file.name)
		end
	end

	local book, showImages = main.choose(books)
	return '/books/' .. book, showImages
end

function main.readEbook(bookfile, showImages)
	local cont = control.Controls:new()
	local book = epub.load(bookfile)
	local page = render.PageRenderer:new(book, showImages)

	while true do
		cont:update()
		main.system(cont)

		if cont.select:pressed() then break end

		if cont.a:pressed() then
			book:toggleBookmark()
			page.dirty = true
		end

		if cont.left:pressed() then
			if book:flipBackward() then
				page:free()
				page = render.PageRenderer:new(book, showImages)
			end
		elseif cont.right:pressed() then
			if book:flipForward() then
				page:free()
				page = render.PageRenderer:new(book, showImages)
			end
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

		local x, y = cont.touchpad:tapped()
		if x ~= nil and y ~= nil then
			local img = page:getImage(x, y)
			if img ~= nil then
				main.viewImage(img, cont)
			end
		end

		page:update()
		page:draw()
	end

	page:free()
end

function main.viewImage(image, cont)
	local img = render.ImageRenderer:new(image)

	while true do
		cont:update()
		main.system(cont)

		if cont.b:pressed() then
			break
		end

		if cont.up:check() then
			img:zoomIn()
		elseif cont.down:check() then
			img:zoomOut()
		end

		local dx, dy = cont.circle:check()
		if dx ~= 0 or dy ~= 0 then
			img:scroll(dx * 10, dy * 10)
		end

		local dx, dy = cont.touchpad:diff()
		if dx ~= nil and dy ~= nil then
			img:scroll(-dx, -dy)
		end

		img:update()
		img:draw()
	end
end

return main
