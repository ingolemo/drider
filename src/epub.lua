-- this module is responsible for loading the epub off of the sd card
-- and parsing it down to a form that can be easily rendered
local epub = {}
local utils = import('utils')
local pathlib = import('pathlib')
local html = import('html')
local xml = import('xml')
local bookmark = import('bookmark')

function epub.load(file)
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
		elseif filename:sub(1, 1) == '/' then
			-- don't start the zip file query with /
			filename = filename:sub(2)
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
		local text = utils.readFile(filename)
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
		local currentBm = bookmark.get(self.file)
		if currentBm == self.pagenum then
			bookmark.remove(self.file)
			return false
		else
			bookmark.set(self.file, self.pagenum)
			return true
		end
	end

	function book:isCurrentBookmarked()
		return bookmark.get(self.file) == self.pagenum
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

	local currentBm = bookmark.get(book.file)
	if currentBm ~= nil then
		book.pagenum = currentBm
	end

	return book
end

return epub
