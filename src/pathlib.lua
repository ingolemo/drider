local pathlib = {}

function pathlib.dirname(path)
	-- finds the directory that a file is in:
	-- /3ds/drider/drider.smdh -> /3ds/drider/
	return path:gsub('[^/]+$', '')
end

function pathlib.normalise(path)
	-- normalises a path, removing .. components:
	-- /3ds/drider/../meh -> /3ds/meh
	return path:gsub('//', '/'):gsub('([^/]+/%.%.)', ''):gsub('//', '/')
end

function pathlib.join(head, tail)
	-- joins two paths together
	return pathlib.normalise(head .. '/' .. tail)
end

function pathlib.nearby(fname)
	-- decides whether to load files from the sd card or the romfs
	local sdname = '/3ds/drider/' .. fname
	if System.doesFileExist(sdname) then
		return sdname
	else
		return 'romfs:/' .. fname
	end
end

function pathlib.ensureDirectory(dir)
	if not System.doesFileExist(dir) then
		System.createDirectory(dir)
	end
end

pathlib.ensureDirectory('/3ds')
pathlib.ensureDirectory('/3ds/drider')
pathlib.ensureDirectory('/books')

return pathlib
