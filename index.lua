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

local function readFile(filename)
	-- Reads the contents of a file from the sd card
	local handle = io.open(filename, FREAD)
	local contents = io.read(handle, 0, io.size(handle))
	io.close(handle)
	return contents
end

local function writeFile(filename, contents)
	local handle = io.open(filename, FWRITE)
	io.write(handle, 0, contents, #contents)
	io.close(handle)
end

local function utf8ToAscii(text)
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

	-- mdash
	text = text:gsub('\xe2\x80\x94', ' - ')

	return text
end

function unescapeEntities(value)
	-- converts the entities in html and xml to literal characters
	value = value:gsub('&#x([%x]+)%;', function(h)
		return string.char(tonumber(h, 16))
	end)
	value = value:gsub('&#([0-9]+)%;', function(h)
		return string.char(tonumber(h, 10))
	end)
	value = value:gsub('&quot;', '"')
	value = value:gsub('&apos;', "'")
	value = value:gsub('&gt;', '>')
	value = value:gsub('&lt;', '<')
	value = value:gsub('&nbsp;', ' ')
	value = value:gsub('&amp;', '&')
	return value
end

local function error(message)
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


--MODULE pathlib
local pathlib = (function()
	local mod = {}

	function mod.dirname(path)
		-- finds the directory that a file is in:
		-- /3ds/drider/drider.smdh -> /3ds/drider/
		return path:gsub('[^/]+$', '')
	end

	function mod.normalise(path)
		-- normalises a path, removing .. components:
		-- /3ds/drider/../meh -> /3ds/meh
		return path:gsub('//', '/'):gsub('([^/]+/%.%.)', '')
	end

	function mod.join(head, tail)
		-- joins two paths together
		return mod.normalise(head .. '/' .. tail)
	end

	return mod
end)()

--MODULE html
-- this module is responsible for tyaking an html string and reducing it
-- down to a simplified document outline. Unlike the xml module this
-- module does not, strictly speaking, parse the html; we're just
-- naively extracting the contents that are relevant to us.
local html = (function()
	local mod = {}

	function mod.parseAttribs(attrs)
		-- returns a table mapping attribute names to their values
		local node = {}
		string.gsub(attrs, '(%w+)=(["\'])(.-)%2', function(name, _, value)
			node[name] = unescapeEntities(value)
		end)
		return node
	end

	function mod.parse(contents)
		-- Parses the html and produces a flat table of items that are
		-- relevant to the display of the page. Each item is a table
		-- containing at least the key 'type', as well as any other
		-- data associated with that element, such as any text content.
		--
		-- only three types of content are supported:
		-- title, text, and image
		contents = utf8ToAscii(contents)
		local result = {}

		local index = 1 -- how far into contents we've parsed
		local start -- the start of the next tag match
		local finish -- the last matching character of the tag

		local isClosing -- equals '/' if the tag closes: </p>
		local label -- the name of the tag: h1/p/img
		local attrs -- the part of the tag containing attributes: href=''
		local empty -- equals '/' if the tag self-closes: <img />

		local text = ''
		local type = 'p'

		local function writeItem()
			local stripped = unescapeEntities(text:strip())
			if stripped ~= '' then
				table.insert(result, {type=type, content=stripped})
				type = 'p'
				text = ''
			end
		end

		-- the kinds of html _text content_ tags we support and what
		-- they map to
		local tagMap = {
			h1='h1', h2='h2', h3='h3',
			p='p',
		}

		while true do
			start, finish, isClosing, label, attrs, empty = contents:find(
				'<%??!?(%/?)([%w_:]+)(.-)(%/?)>', index)
			if not start then break end
			local newtext = contents:sub(index, start - 1)

			local stripped = newtext:strip()
			if stripped ~= '' then
				text = text .. ' ' .. stripped
			end

			local parsedAttrs = mod.parseAttribs(attrs)

			if empty == '/' then
				if label == 'img' then
					writeItem()
					table.insert(result, {type='img', src=parsedAttrs.src})
				end
			elseif isClosing == '' then
				local maybeType = tagMap[label]
				if maybeType ~= nil then
					writeItem()
					type = maybeType
				end
			else
				local maybeType = tagMap[label]
				if maybeType ~= nil then
					writeItem()
				end
			end

			index = finish + 1
		end

		return result
	end

	return mod
end)()


-- MODULE xml
-- based on SimpleXML.lua
-- https://github.com/Cluain/Lua-Simple-XML-Parser
-- this code has been massively refactored
-- this module takes an xml file and parses it down to a set of nested
-- lua tables that are easy to query and iterate over.
local xml = (function()
	local mod = {}

	function mod.parseAttributes(node, s)
		-- sets attributes parsed from s on node
		string.gsub(s, '(%w+)=(["\'])(.-)%2', function(w, _, a)
			node:addProperty(w, unescapeEntities(a))
		end)
	end

	function mod.load(file)
		-- loads an xml file from disk and returns a node table
		-- structure representing its parsed form.
		return mod.parse(readFile(file))
	end

	function mod.parse(contents)
		-- takes a string containing xml and returns a node table
		-- structure representing parsed xml.
		local stack = {}
		local top = mod.node()
		table.insert(stack, top)

		local index = 1 -- how far into contents we've parsed
		local start -- the start of the next tag match
		local finish -- the last matching character of the tag

		local isClosing -- equals '/' if the tag closes: </p>
		local label -- the name of the tag: h1/p/img
		local attrs -- the part of the tag containing attributes: href=''
		local empty -- equals '/' if the tag self-closes: <img />

		while true do
			start, finish, isClosing, label, attrs, empty = contents:find(
				'<(%/?)([%w_:]+)(.-)(%/?)>', index)
			if not start then break end

			local text = contents:sub(index, start - 1)

			-- if not only whitespace, add to stack
			if not text:find('^%s*$') then
				local lVal = (top:value() or '') .. unescapeEntities(text)
				stack[#stack]:setValue(lVal)
			end

			if empty == '/' then
				-- if self-closing, add node to top
				local lNode = mod.node(label)
				mod.parseAttributes(lNode, attrs)
				top:addChild(lNode)
			elseif isClosing == '' then
				-- if not closing, make node and add to stack
				local lNode = mod.node(label)
				mod.parseAttributes(lNode, attrs)
				table.insert(stack, lNode)
				top = lNode
			else
				-- if closing, pop stack
				local toClose = table.remove(stack)
				if #stack < 1 then
					error(('Trying to close unopen %s.')
						:format(toClose:name()))
				end
				if toClose:name() ~= label then
					error(('Trying to close %s but %s is active.')
						:format(label, toClose:name()))
				end
				top = stack[#stack]
				top:addChild(toClose)
			end
			index = finish + 1
		end
		local text = string.sub(contents, index)
		if #stack > 1 then
			error('Unclosed element at end of document')
		end
		return top
	end

	function mod.node(name)
		-- creates a new xml node object with the specified name
		local node = {}
		node.__value = nil
		node.__name = name
		node.__children = {}
		node.__props = {}

		function node:value() return self.__value end
		function node:setValue(val) self.__value = val end
		function node:name() return self.__name end
		function node:setName(name) self.__name = name end
		function node:children() return self.__children end
		function node:numChildren() return #self.__children end
		function node:addChild(child)
			if self[child:name()] ~= nil then
				if type(self[child:name()].name) == 'function' then
					local tempTable = {}
					table.insert(tempTable, self[child:name()])
					self[child:name()] = tempTable
				end
				table.insert(self[child:name()], child)
			else
				self[child:name()] = child
			end
			table.insert(self.__children, child)
		end
		function node:properties() return self.__props end
		function node:numProperties() return #self.__props end
		function node:addProperty(name, value)
			local lName = '@' .. name
			if self[lName] ~= nil then
				if type(self[lName]) == 'string' then
					local tempTable = {}
					table.insert(tempTable, self[lName])
					self[lName] = tempTable
				end
				table.insert(self[lName], value)
			else
				self[lName] = value
			end
			table.insert(self.__props, { name = name, value = self[name] })
		end

		return node
	end

	return mod
end)()


-- MODULE render
-- this module holds all the code for rendering an html fragment such as
-- that produced by the html module
local render = (function()
	local mod = {}

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
	local regularFont = Font.load('/3ds/drider/book_regular.ttf')
	local italicFont = Font.load('/3ds/drider/book_italic.ttf')
	-- local boldFont = Font.load('/3ds/drider/book_bold.ttf')
	-- local boldItalicFont = Font.load('/3ds/drider/book_bold_italic.ttf')
	local titleFont = Font.load('/3ds/drider/title.ttf')

	local bmImage = Screen.loadImage('/3ds/drider/bookmark.png')

	local loadedImages = {}

	function mod.loadImage(src, imageLoader)
		-- image loading isn't practical
		-- cannot load large jpgs and small images tend to be gifs which
		-- are not supported. For now just return nil.

		local ext = src:match('%.%w+$')
		ext = '' -- disable all image loading
		if ext == '.jpg' or ext == '.bmp' or ext == '.png' then
			local filename = imageLoader(src)
			local image = Screen.loadImage(filename)
			table.insert(loadedImages, image)
			return image
		else
			return nil
		end
	end

	function mod.freeImages()
		-- frees any images which have been loaded by mod.loadImage
		for _, image in ipairs(loadedImages) do
			Screen.freeImage(image)
		end
		loadedImages = {}
	end

	function mod.renderData(idata, screenTop, quick)
		-- Draws the compiled idata onto the screen. The screenTop
		-- parameter is how far down the content the user has scrolled.
		-- The quick parameter allows us to skip slow rendering if we're
		-- doing something where readability isn't too important, such
		-- as scrolling.
		local y = 0

		local screenMiddle = screenTop + 240
		local screenBottom = screenMiddle + 240

		-- page counter
		Font.setPixelSizes(italicFont, h1Size)
		Font.print(italicFont, 5, 0, idata.pagenum, bg, TOP_SCREEN)

		-- bookmark
		if idata.bookmarked then
			local x, h = 370, 24
			Screen.fillRect(x, x + 15, 0, h, red, TOP_SCREEN)
			Screen.drawImage(x, h + 1, bmImage, TOP_SCREEN)
		end

		-- scrollbar
		local maxY = mod.getHeight(idata)
		local sbTop = math.max(0, math.floor(screenTop * 239/maxY))
		local sbHeight = math.floor(480 * 239/maxY)
		local sbBottom = math.min(329, sbTop + sbHeight)
		if sbTop ~= 0 or sbBottom ~= 329 then
			Screen.fillRect(394, 399, sbTop, sbBottom, bg, TOP_SCREEN)
		end

		for _, item in ipairs(idata) do
			local screen, top, left
			local yH = y + item.height

			-- if y is too close to the middle bar than advance it so
			-- that we don't skip a line of text. We only need this hack
			-- because we can't render something only partially on
			-- screen and it's confusing to skip rendering text along
			-- the middle line
			if screenMiddle > y and yH >= screenMiddle then
				if not quick then
					y = screenMiddle
				end
			end

			if screenTop <= y and yH < screenMiddle then
				screen = TOP_SCREEN
				top = y - screenTop
				left = 40 + margin
			elseif screenMiddle <= y and yH < screenBottom then
				screen = BOTTOM_SCREEN
				top = y - screenMiddle
				left = margin
			elseif screenBottom <= y then
				break
			else
				-- the item's bounding box is partially offscreen
				-- or it intersects the middle line, would use a
				-- 'continue' here, but lua doesn't have it
				y = y + item.height
				goto continue
			end

			if item.type == 'text' and not quick then
				Font.setPixelSizes(item.font, item.fontSize)
				Font.print(item.font, left, top, item.content, ink, screen)
			elseif item.type == 'text' and quick then
				Screen.fillRect(left, left + item.width,
					top + math.floor(item.height/4),
					top + math.floor(item.height*3/4), bg, screen)
			elseif item.type == 'image' and not quick then
				Screen.fillRect(left, left + item.width, top,
					top + item.height, bg, screen)
				Font.setPixelSizes(italicFont, bookSize)
				Font.print(italicFont, left + 5, top + 5, item.src,
					paper, screen)
			end

			y = y + item.height
			::continue::
		end
	end

	function mod.compileHTML(data, imageLoader, pagenum, bookmarked)
		-- takes a flat html table structure as produced by the html
		-- module and compiles it down to a format more useful for
		-- rendering. This mostly involves adding padding between
		-- elements and working out the heights of everything in
		-- advance.
		--
		-- WARNING: assumes that the results of previous calls to this
		-- function are no longer needed because it frees old images
		local idata = {pagenum = pagenum, bookmarked = bookmarked}
		mod.freeImages()

		table.insert(idata, {type='space', height=margin})

		local function insertText(content, font, fontSize)
			-- approximate the width, so we can quick-draw text
			local avgCharW = fontSize * 0.33
			local probableTextW = math.floor(#content * avgCharW)
			local w = math.min(300, probableTextW)

			table.insert(idata, {
				type='text',
				height=fontSize, width=w,
				font=font, fontSize=fontSize,
				content=content,
			})
		end

		for _, item in ipairs(data) do
			if item.type == 'h1' then
				insertText(item.content, titleFont, h1Size)
			elseif item.type == 'h2' then
				insertText(item.content, titleFont, h2Size)
			elseif item.type == 'h3' then
				insertText(item.content, titleFont, h3Size)
			elseif item.type == 'p' then
				for _, line in ipairs(item.content:wrap(50)) do
					insertText(line, regularFont, bookSize)
				end
			elseif item.type == 'img' then
				local image = mod.loadImage(item.src, imageLoader)
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
				insertText(msg:format(item.type), italicFont, bookSize)
			end
			table.insert(idata, {type='space', height=padding})
		end

		table.insert(idata, {type='space', height=margin * 4 - padding})

		return idata
	end

	function mod.getHeight(idata)
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

	function mod.main(idata, top, quick)
		-- draws some compiled render data to the screen
		Screen.waitVblankStart()
		Screen.refresh()
		Screen.clear(TOP_SCREEN)
		Screen.clear(BOTTOM_SCREEN)
		Screen.fillRect(0, 399, 0, 239, paper, TOP_SCREEN)
		Screen.fillRect(0, 319, 0, 239, paper, BOTTOM_SCREEN)
		mod.renderData(idata, top, quick)
		Screen.flip()
	end

	function mod.idle()
		-- does basically nothing but waits. This is used when nothing
		-- has changed since the last call to mod.main, as it is faster
		-- to just not clear the screen.
		Screen.waitVblankStart()
		Screen.refresh()
	end

	return mod
end)()


-- MODULE bmFile
-- this module is in change of reading and writing the bookmark file
local bmFile = (function()
	local mod = {}
	local bmPath = '/3ds/drider/bookmarks.txt'
	local slate

	local function parseBookmarks(contents)
		local result = {}
		for line in contents:gmatch('[^\n]+') do
			key, value = line:match('([^=]+)=([^=]+)')
			result[key] = math.tointeger(value)
		end
		return result
	end

	local function unparseBookmarks(mapping)
		local result = {}
		for key, value in pairs(mapping) do
			table.insert(result, key .. '=' .. value)
		end
		return table.concat(result, '\n')
	end

	function mod.get(bookFile)
		return slate[bookFile]
	end

	function mod.set(bookFile, pageNum)
		slate[bookFile] = pageNum
		writeFile(bmPath, unparseBookmarks(slate))
	end

	function mod.remove(bookfile)
		slate[bookFile] = nil
		writeFile(bmPath, unparseBookmarks(slate))
	end

	if not System.doesFileExist(bmPath) then
		io.close(io.open(bmPath, FCREATE))
	end
	slate = parseBookmarks(readFile(bmPath))

	return mod
end)()


-- MODULE epub
-- this module is responsible for loading the epub off of the sd card
-- and parsing it down to a form that can be easily rendered
local epub = (function()
	local mod = {}

	function mod.load(file)
		-- loads an epub from a file on the sd card
		local book = {
			file = file,
			spine = {},
			pagenum = 1,
			opfDir = '',
		}

		function book:extractFile(filename)
			-- extracts a file from the epub that other components can
			-- read. The file name that it returns must be read from
			-- immediately because it may be deleted/reused by later
			-- calls to this function.
			local tmpFile = '/3ds/drider/tmp.bin'
			System.deleteFile(tmpFile)
			if filename == nil then
				error('Cannot extract nil filename')
			end
			System.extractFromZIP(self.file, filename, tmpFile)
			if not System.doesFileExist(tmpFile) then
				error(('Failed to extract %q from %q'):format(filename, self.file))
			end
			return tmpFile
		end

		function book:imageFile(imgSrc)
			-- takes an image src from a the current page and produces a
			-- file containing that image's contents
			local pagePath = self.spine[self.pagenum]
			local filename = pathlib.join(pathlib.dirname(pagePath), imgSrc)
			return self:extractFile(filename)
		end

		function book:currentPageHTML()
			-- returns the parsed html contents of the current page of
			-- the ebook
			local filename = self:extractFile(self.spine[self.pagenum])
			local text = readFile(filename)
			return html.parse(text)
		end

		function book:length()
			return #self.spine
		end

		function book:flipBackward()
			if self.pagenum > 1 then
				self.pagenum = self.pagenum - 1
			end
		end

		function book:flipForward()
			if self.pagenum < self:length() then
				self.pagenum = self.pagenum + 1
			end
		end

		function book:toggleBookmark()
			local currentBm = bmFile.get(self.file)
			if currentBm == self.pagenum then
				bmFile.remove(self.file)
				return false
			else
				bmFile.set(self.file, self.pagenum)
				return true
			end
		end

		function book:isCurrentBookmarked()
			return bmFile.get(self.file) == self.pagenum
		end

		-- find the book's opfFile (the main metadata)
		local inf = xml.load(book:extractFile('META-INF/container.xml'))
		local opfFile
		for _, rootfile in ipairs(inf.container.rootfiles:children()) do
			-- we find type rather than media-type because dashes
			if rootfile['@type'] == 'application/oebps-package+xml' then
				-- we find path rather than full-path because dashes
				opfFile = rootfile['@path']
				break
			end
			error('Cannot find opf file')
		end

		-- build the manifest form the opfFile
		book.opfDir = pathlib.dirname(opfFile)
		local opf = xml.load(book:extractFile(opfFile))
		local manifest = {}
		for _, item in ipairs(opf.package.manifest:children()) do
			manifest[item['@id'] ] = pathlib.join(book.opfDir, item['@href'])
		end

		-- build the spine from the opfFile and the manifest
		for _, item in ipairs(opf.package.spine:children()) do
			table.insert(book.spine, manifest[item['@idref'] ])
		end

		local currentBm = bmFile.get(book.file)
		if currentBm ~= nil then
			book.pagenum = currentBm
		end

		return book
	end
	return mod
end)()


--MODULE main
main = (function()
	mod = {}

	function mod.run()
		local bookfile = mod.chooseEbook()
		mod.readEbook(bookfile)
	end

	function mod.chooseEbook()
		local bookfile = '/book.epub'
		if not System.doesFileExist(bookfile) then
			error(('Cannot find %q'):format(bookfile))
		end
		return bookfile
	end

	function mod.readEbook(bookfile)
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
			local pad = Controls.read()
			
			-- handle exiting application
			if System.checkStatus() == APP_EXITING then System.exit() end
			if Controls.check(pad, KEY_START) then System.exit() end
			if Controls.check(pad, KEY_HOME) then
				System.showHomeMenu()
				dirty = true
				scrolling = true
			end

			if Controls.check(pad, KEY_A) then
				-- pageData.bookmarked = book:toggleBookmark()
				book:toggleBookmark()
				pageData = compileBook()
				dirty = true
			end

			-- flip pages
			if Controls.check(pad, KEY_DLEFT) then
				book:flipBackward()
				pageData = compileBook()
				y, dy, dirty = 0, 0, true
				scrolling = true -- hack to make it feel more snappy
			elseif Controls.check(pad, KEY_DRIGHT) then
				book:flipForward()
				pageData = compileBook()
				y, dy, dirty = 0, 0, true
				scrolling = true -- hack to make it feel more snappy
			end

			-- dpad controls have fixed velocity
			if Controls.check(pad, KEY_DUP) then
				dy = -dPadSpeed
				scrolling = true
			elseif Controls.check(pad, KEY_DDOWN) then
				dy = dPadSpeed
				scrolling = true
			end

			-- the circle pad scrolls proportionally
			local _, cPadY = Controls.readCirclePad()
			if math.abs(cPadY) > 30 then
				dy = math.floor(-cPadY/10)
				scrolling = true
			end

			-- touch controls have velocity based on previous position
			prevTouchY = touchY
			_, touchY = Controls.readTouch()
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

	return mod
end)()

main.run()
