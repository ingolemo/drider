-- this module is in charge of reading and writing the bookmark file
local bookmark = {}
local utils = import('utils')

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

function bookmark.get(bookFile)
	return slate[bookFile]
end

function bookmark.set(bookFile, pageNum)
	slate[bookFile] = pageNum
	utils.writeFile(bmPath, unparseBookmarks(slate))
end

function bookmark.remove(bookFile)
	slate[bookFile] = nil
	utils.writeFile(bmPath, unparseBookmarks(slate))
end

if not System.doesFileExist(bmPath) then
	io.close(io.open(bmPath, FCREATE))
end
slate = parseBookmarks(utils.readFile(bmPath))

return bookmark
