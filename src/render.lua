-- this module holds all the code for rendering an html fragment such as
-- that produced by the html module
local render = {}
local utils = import('utils')
local pathlib = import('pathlib')

local ink = Color.new(0, 0, 0)
local paper = Color.new(255, 255, 200)
local pencil = Color.new(230, 230, 180)
local red = Color.new(175, 18, 18)

local regularFont = Font.load(pathlib.nearby('gentium_regular.ttf'))
local italicFont = Font.load(pathlib.nearby('gentium_italic.ttf'))

Graphics.init()

local function renderText(text, font, size, fgColor)
	local width, height, image, texture
	local magenta = Color.new(255, 0, 255)

	Font.setPixelSizes(font, size)
	width, height = Font.measureText(font, text)
	image = Screen.createImage(width, height, magenta)
	Font.print(font, 0, 0, text, fgColor, image)
	texture = Graphics.convertFrom(image)
	Screen.freeImage(image)
	return texture
end

-- CLASS: MenuRenderer
render.MenuRenderer = {}
render.MenuRenderer.__index = render.MenuRenderer
render.MenuRenderer.size = 20
render.MenuRenderer.banner = Graphics.loadImage(pathlib.nearby('banner.png'))
function render.MenuRenderer:new(choices)
	local obj = {}
	setmetatable(obj, render.MenuRenderer)
	obj.dirty = true
	obj.selected = 1
	obj.position = -100
	obj.choices = {}
	for _, choice in ipairs(choices) do
		local tex = renderText(choice, regularFont, self.size, ink, paper)
		table.insert(obj.choices, tex)
	end
	return obj
end

function render.MenuRenderer:free()
	for _, choice in ipairs(self.choices) do
		Graphics.freeImage(choice)
	end
end

function render.MenuRenderer:select(selected)
	self.selected = selected
	self.dirty = true
end

function render.MenuRenderer:drawChoices()
	local middle = 240 / 2
	for i, tex in ipairs(self.choices) do
		local rel_i = i - self.position
		local offset = middle - self.size/2
		local y = rel_i * self.size + offset
		local color = paper
		if i == self.selected then
			color = red
			Graphics.fillRect(0, 320, y, y + self.size, color)
		end
		Graphics.drawImage(10, y, tex, color)
	end
end

function render.MenuRenderer:update()
	if math.abs(self.position - self.selected) > 0.1 then
		self.position = utils.lerp(self.position, self.selected, 0.1)
		self.dirty = true
	end
end

function render.MenuRenderer:draw()
	Screen.waitVblankStart()
	if not self.dirty then
		return
	end

	Graphics.initBlend(TOP_SCREEN)
	Graphics.fillRect(0, 400, 0, 240, paper)
	Graphics.drawImage(75, 32, self.banner)
	Graphics.termBlend()

	Graphics.initBlend(BOTTOM_SCREEN)
	Graphics.fillRect(0, 320, 0, 240, paper)
	self:drawChoices()
	Graphics.termBlend()

	Graphics.flip()

	self.dirty = false
end


render.IDataRenderer = {}
render.IDataRenderer.__index = render.IDataRenderer
function render.IDataRenderer:new(idata)
	local obj = {}
	setmetatable(obj, render.IDataRenderer)
	obj.dirty = true
	obj.canvas = nil
	obj.idata = idata
	return obj
end

function render.IDataRenderer:scroll(amount)
	self.dirty = true
end

function render.IDataRenderer:draw()
	if self.dirty == true then
		self.dirty = false
	end

	Graphics.initBlend(TOP_SCREEN)
	Graphics.drawPartialImage(0, 0, 0, 0, 400, 240, self.canvas)
	-- render.renderBookmark(idata)
	-- render.renderScrollbar(idata, top)
	Graphics.termBlend()

	Graphics.initBlend(BOTTOM_SCREEN)
	Graphics.drawPartialImage(0, 0, 40, 240, 320, 240, self.canvas)
	Graphics.termBlend()

	Graphics.flip()
end








local width = 320
local minHeight = 480
local margin = 10
local padding = 5

local h1Size = 32
local h2Size = 28
local h3Size = 24
local bookSize = 16
local titleFont = italicFont

local bookmarkTex = Graphics.loadImage(pathlib.nearby('bookmark.png'))

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
		Font.print(italicFont, 5, 0, idata.pagenum, pencil, screen)
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
				top + math.floor(item.height*3/4), pencil, screen)
		elseif item.type == 'image' and not quick then
			if item.data == nil then
				Screen.fillRect(left, left + item.width, top,
					top + item.height, pencil, screen)
				Font.setPixelSizes(italicFont, bookSize)
				Font.print(italicFont, left + 5, top + 5, item.src,
					paper, screen)
			else
				Screen.drawImage(left, top, item.data, screen)
			end
		elseif item.type == 'image' and quick then
			Screen.fillEmptyRect(left, left + item.width, top,
				top + item.height, pencil, screen)
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
		Graphics.fillRect(394, 399, sbTop, sbBottom, pencil)
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
