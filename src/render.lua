-- this module holds all the code for rendering an html fragment such as
-- that produced by the html module
local render = {}
local utils = import('utils')
local pathlib = import('pathlib')

local padding = 5
local margin = 10

local ink = Color.new(0, 0, 0)
local paper = Color.new(255, 255, 200)
local pencil = Color.new(230, 230, 180)
local red = Color.new(175, 18, 18)

local regularFont = Font.load(pathlib.nearby('gentium_regular.ttf'))
local italicFont = Font.load(pathlib.nearby('gentium_italic.ttf'))
local titleFont = italicFont

Graphics.init()

local function renderText(text, font, size, fgColor, textwidth)
	if textwidth == nil then textwidth = 0 end
	local width, height, image, texture
	local magenta = Color.new(255, 0, 255)

	Font.setPixelSizes(font, size)
	width, height = Font.measureText(font, text, textwidth)
	image = Screen.createImage(width, height, magenta)
	Font.print(font, 0, 0, text, fgColor, image, 0, textwidth)
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
	obj.position = -10
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
		Graphics.drawImage(margin, y, tex, color)
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


render.PageRenderer = {}
render.PageRenderer.__index = render.PageRenderer
render.PageRenderer.bookmark = Graphics.loadImage(pathlib.nearby('bookmark.png'))
render.PageRenderer.h1size = 32
render.PageRenderer.h2size = 28
render.PageRenderer.h3size = 24
render.PageRenderer.psize = 16
render.PageRenderer.textwidth = 320 - margin*2
function render.PageRenderer:new(book)
	local obj = {}
	setmetatable(obj, render.PageRenderer)
	obj.book = book
	obj.textures = {}
	obj.position = 0
	obj.dirty = true
	obj:__compile()
	obj:__calcHeight()
	obj.pageNumTex = renderText(book.pagenum, italicFont, 32, pencil)
	table.insert(obj.textures, obj.pageNumTex)
	return obj
end

function render.PageRenderer:free()
	for i, texture in ipairs(self.textures) do
		Graphics.freeImage(texture)
	end
end

function render.PageRenderer:__compile()
	self.idata = {
		pagenum = self.book.pagenum,
	}
	local html = self.book:currentPageHTML()
	table.insert(self.idata, {type='space', height=margin})

	local function insertText(text, font, size)
		Font.setPixelSizes(font, size)
		local w, h = Font.measureText(font, text, self.textwidth)
		table.insert(self.idata, {
			type='text', height=h, width=w,
			font=font, size=size, content=text,
		})
	end

	for _, item in ipairs(html) do
		if item.type == 'h1' then
			insertText(item.content, titleFont, self.h1size)
		elseif item.type == 'h2' then
			insertText(item.content, titleFont, self.h2size)
		elseif item.type == 'h3' then
			insertText(item.content, titleFont, self.h3size)
		elseif item.type == 'p' then
			for _, line in ipairs(item.content:wrap(50)) do
				insertText(line, regularFont, self.psize)
			end
		elseif item.type == 'img' then
			local image, w, h = self:loadImage(item.src)
			table.insert(self.idata, {
				type='image', height=h, width=w,
				src=item.src, data=image,
			})
		else
			local msg = '[WARNING: Unknown tag %q]'
			insertText(msg:format(item.type), italicFont, self.psize)
		end
		table.insert(self.idata, {type='space', height=padding})
	end

	table.insert(self.idata, {type='space', height=padding * 3})
end

function render.PageRenderer:__calcHeight()
	self.height = 0
	for _, item in ipairs(self.idata) do
		self.height = self.height + item.height
	end
end

function render.PageRenderer:loadImage(src)
	local ext = src:match('%.%w+$')
	-- ext = '' -- disable all image loading
	if ext ~= '.jpg' and ext ~= '.bmp' and ext ~= '.png' then
		return nil, self.textwidth, 80
	end

	local filename = self.book:imageFile(src)
	local image = Graphics.loadImage(filename)
	table.insert(self.textures, image)
	local w = Graphics.getImageWidth(image)
	local h = Graphics.getImageHeight(image)

	if w > self.textwidth or h > 300 then
		return nil, self.textwidth, 80
	end

	return image, w, h
end

function render.PageRenderer:scroll(amount)
	self.position = self.position + amount
	self.position = math.max(0, math.min(self.position, self.height - 480))

	self.dirty = true
end

function render.PageRenderer:update()
end

function render.PageRenderer:drawBookmark()
	if self.book:isCurrentBookmarked() then
		local x, h = 370, 25
		Graphics.fillRect(x, x + 16, 0, h, red)
		Graphics.drawImage(x, h, self.bookmark)
	end
end

function render.PageRenderer:drawScrollbar()
	local sbTop = math.max(0, math.floor(self.position * 239/self.height))
	local sbHeight = math.floor(480 * 239/self.height)
	local sbBottom = math.min(329, sbTop + sbHeight)
	if sbTop ~= 0 or sbBottom ~= 329 then
		Graphics.fillRect(394, 399, sbTop, sbBottom, pencil)
	end
end

function render.PageRenderer:drawPageNum()
	Graphics.drawImage(margin, 0, self.pageNumTex, paper)
end

function render.PageRenderer:drawContents(left, top, bottom)
	local y = 0
	for _, item in ipairs(self.idata) do
		if y + item.height < top then
			goto skip_drawing
		elseif bottom < y then
			break
		end

		if item.type == 'text' then
			if item.render == nil then
				item.render = renderText(
					item.content, item.font, item.size, ink, self.textwidth
				)
				table.insert(self.textures, item.render)
			end
			Graphics.drawImage(left, y - top, item.render, paper)
		elseif item.type == 'image' then
			if item.data == nil then
				Graphics.fillRect(
					left, left + item.width,
					y - top, y - top + item.height,
					pencil
				)
				-- Screen.fillRect(left, left + item.width, top,
				-- 	top + item.height, pencil, screen)
				-- Font.setPixelSizes(italicFont, bookSize)
				-- Font.print(italicFont, left + 5, top + 5, item.src,
				-- 	paper, screen)
			else
				Graphics.drawImage(left, y - top, item.data)
			end
		end

		::skip_drawing::
		y = y + item.height
	end
end

function render.PageRenderer:draw()
	Screen.waitVblankStart()
	if not self.dirty then
		return
	end

	Graphics.initBlend(TOP_SCREEN)
	Graphics.fillRect(0, 400, 0, 240, paper)
	self:drawBookmark()
	self:drawScrollbar()
	self:drawPageNum()
	self:drawContents(40 + margin, self.position, self.position + 240)
	Graphics.termBlend()

	Graphics.initBlend(BOTTOM_SCREEN)
	Graphics.fillRect(0, 320, 0, 240, paper)
	self:drawContents(margin, self.position + 240, self.position + 480)
	Graphics.termBlend()

	Graphics.flip()

	self.dirty = false
end

return render
