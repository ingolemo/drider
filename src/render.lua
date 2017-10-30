-- this module holds all the code for rendering an html fragment such as
-- that produced by the html module
local render = {}
local pathlib = import('pathlib')

local width = 320
local minHeight = 480
local margin = 10
local padding = 5

local ink = Color.new(0, 0, 0)
local paper = Color.new(255, 255, 200)
local bg = Color.new(230, 230, 180)
local red = Color.new(175, 18, 18)

local h1Size = 32
local h2Size = 28
local h3Size = 24
local bookSize = 16
local regularFont = Font.load(pathlib.nearby('gentium_regular.ttf'))
local italicFont = Font.load(pathlib.nearby('gentium_italic.ttf'))
local titleFont = italicFont

Graphics.init()

local bookmarkTex = Graphics.loadImage(pathlib.nearby('bookmark.png'))
local bnImage = Screen.loadImage(pathlib.nearby('banner.png'))

local loadedImages = {}

function render.loadImage(src, imageLoader)
	-- image loading isn't practical
	-- cannot load large jpgs and small images tend to be gifs which
	-- are not supported. For now just return nil.

	local ext = src:match('%.%w+$')
	ext = '' -- disable all image loading
	if ext ~= '.jpg' and ext ~= '.bmp' and ext ~= '.png' then
		return nil
	end

	local filename = imageLoader(src)
	local image = Screen.loadImage(filename)
	table.insert(loadedImages, image)
	local w = Screen.getImageWidth(image)
	local h = Screen.getImageHeight(image)
	if w > 300 or h > 300 then
		return nil
	end
	return image
end

function render.freeImages()
	-- frees any images which have been loaded by render.loadImage
	for _, image in ipairs(loadedImages) do
		Screen.freeImage(image)
	end
	loadedImages = {}
end

function render.renderData(idata, screenTop, quick)
	-- Draws the compiled idata onto the screen. The screenTop
	-- parameter is how far down the content the user has scrolled.
	-- The quick parameter allows us to skip slow rendering if we're
	-- doing something where readability isn't too important, such
	-- as scrolling.
	local screen = Screen.createImage(400, 480, Color.new(255, 0, 255))
	local y = 0

	local screenBottom = screenTop + 480

	-- page counter
	if idata.pagenum ~= nil then
		Font.setPixelSizes(italicFont, h1Size)
		Font.print(italicFont, 5, 0, idata.pagenum, bg, screen)
	end

	for _, item in ipairs(idata) do
		local top = y - screenTop
		local left = 40 + margin
		local yH = y + item.height

		if y < screenTop then
			goto skip_render
		elseif yH >= screenBottom then
			break
		end

		if item.type == 'text' and not quick then
			Font.setPixelSizes(item.font, item.fontSize)
			Font.print(item.font, left, top, item.content, ink, screen)
		elseif item.type == 'text' and quick then
			Screen.fillRect(left, left + item.width,
				top + math.floor(item.height/4),
				top + math.floor(item.height*3/4), bg, screen)
		elseif item.type == 'image' and not quick then
			if item.data == nil then
				Screen.fillRect(left, left + item.width, top,
					top + item.height, bg, screen)
				Font.setPixelSizes(italicFont, bookSize)
				Font.print(italicFont, left + 5, top + 5, item.src,
					paper, screen)
			else
				Screen.drawImage(left, top, item.data, screen)
			end
		elseif item.type == 'image' and quick then
			Screen.fillEmptyRect(left, left + item.width, top,
				top + item.height, bg, screen)
		end

		::skip_render::
		y = y + item.height
	end

	return screen
end

local function insertText(idata, content, font, fontSize)
	-- approximate the width, so we can quick-draw text
	local w = 300
	local h = fontSize
	w, h = Font.measureText(font, content, 300)

	table.insert(idata, {
		type='text',
		height=h, width=w,
		font=font, fontSize=fontSize,
		content=content,
	})
end

function render.compileHTML(data, imageLoader, pagenum, bookmarked)
	-- takes a flat html table structure as produced by the html
	-- module and compiles it down to a format more useful for
	-- rendering. This mostly involves adding padding between
	-- elements and working out the heights of everything in
	-- advance.
	--
	-- WARNING: assumes that the results of previous calls to this
	-- function are no longer needed because it frees old images
	local idata = {pagenum = pagenum, bookmarked = bookmarked}
	render.freeImages()

	table.insert(idata, {type='space', height=margin})


	for _, item in ipairs(data) do
		if item.type == 'h1' then
			insertText(idata, item.content, titleFont, h1Size)
		elseif item.type == 'h2' then
			insertText(idata, item.content, titleFont, h2Size)
		elseif item.type == 'h3' then
			insertText(idata, item.content, titleFont, h3Size)
		elseif item.type == 'p' then
			for _, line in ipairs(item.content:wrap(50)) do
				insertText(idata, line, regularFont, bookSize)
			end
		elseif item.type == 'img' then
			local image = render.loadImage(item.src, imageLoader)
			w, h = 300, 80
			if image ~= nil then
				w = Screen.getImageWidth(image)
				h = Screen.getImageHeight(image)
			end
			table.insert(idata, {
				type='image',
				height=h,
				width=w,
				src=item.src,
				data=image,
			})
		else
			local msg = 'WARNING: Unknown tag %q.'
			insertText(idata, msg:format(item.type), italicFont, bookSize)
		end
		table.insert(idata, {type='space', height=padding})
	end

	table.insert(idata, {type='space', height=margin * 4 - padding})

	return idata
end

function render.getHeight(idata)
	-- takes some compiled rendering data and works out its total
	-- height in pixels. This would be more useful if we were doing
	-- off-screen rendering to know how big to make the texture.
	local height = 0
	for _, item in ipairs(idata) do
		height = height + item.height
	end
	if height < minHeight then height = minHeight end
	return height
end

function render.prepareScreens()
	Screen.waitVblankStart()
	Screen.refresh()
	Screen.clear(TOP_SCREEN)
	Screen.clear(BOTTOM_SCREEN)
	Screen.fillRect(0, 399, 0, 239, paper, TOP_SCREEN)
	Screen.fillRect(0, 319, 0, 239, paper, BOTTOM_SCREEN)
end

function render.finaliseScreens()
	Screen.flip()
end

function render.menu(choices, selected)
	local middle = math.floor(120 - h2Size/2)
	local context = 3
	Font.setPixelSizes(titleFont, h2Size)
	Font.setPixelSizes(regularFont, bookSize)
	render.prepareScreens()
	Screen.drawImage(75, 32, bnImage, TOP_SCREEN)
	if #choices == 0 then
		Font.print(titleFont, 40, middle, 'No books found',
			ink, BOTTOM_SCREEN)
		render.finaliseScreens()
		return
	end

	for index, choice in ipairs(choices) do
		local offset = index - selected
		if -context <= offset and offset < 0 then
			-- above
			local y = middle + offset * bookSize
			Font.print(regularFont, 40, y, choice, ink, BOTTOM_SCREEN)
		elseif offset == 0 then
			-- selected item
			Font.print(titleFont, 40, middle, choice, ink, BOTTOM_SCREEN)
		elseif 0 < offset and offset <= context then
			--below
			local y = middle + (offset-1) * bookSize + h2Size
			Font.print(regularFont, 40, y, choice, ink, BOTTOM_SCREEN)
		end
	end
	render.finaliseScreens()
end

function render.renderBookmark(idata)
	if idata.bookmarked then
		local x, h = 370, 24
		Graphics.fillRect(x, x + 16, 0, h + 1, red)
		Graphics.drawImage(x, h + 1, bookmarkTex)
	end
end

function render.renderScrollbar(idata, screenTop)
	local maxY = render.getHeight(idata)
	local sbTop = math.max(0, math.floor(screenTop * 239/maxY))
	local sbHeight = math.floor(480 * 239/maxY)
	local sbBottom = math.min(329, sbTop + sbHeight)
	if sbTop ~= 0 or sbBottom ~= 329 then
		Graphics.fillRect(394, 399, sbTop, sbBottom, bg)
	end
end

function render.main(idata, top, quick)
	-- draws some compiled render data to the screen
	local screen = render.renderData(idata, top, quick)
	local tex = Graphics.convertFrom(screen)
	Screen.freeImage(screen)

	Graphics.initBlend(TOP_SCREEN)
	Graphics.drawPartialImage(0, 0, 0, 0, 400, 240, tex)
	render.renderBookmark(idata)
	render.renderScrollbar(idata, top)
	Graphics.termBlend()

	Graphics.initBlend(BOTTOM_SCREEN)
	Graphics.drawPartialImage(0, 0, 40, 240, 320, 240, tex)
	Graphics.termBlend()

	Graphics.flip()

	Graphics.freeImage(tex)
end

function render.idle()
	-- does basically nothing but waits. This is used when nothing
	-- has changed since the last call to render.main, as it is faster
	-- to just not clear the screen.
	Screen.waitVblankStart()
	Screen.refresh()
end

return render
