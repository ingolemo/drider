local imported = {}

function import(module_name)
	local mod = imported[module_name]
	if mod ~= nil then
		return mod
	end
	local module_path = 'romfs:/' .. module_name .. '.lua'
	mod = dofile(module_path)
	imported[module_name] = mod
	return mod
end

main = import('main')
main.run()
