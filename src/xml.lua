-- based on SimpleXML.lua
-- https://github.com/Cluain/Lua-Simple-XML-Parser
-- this code has been massively refactored
-- this module takes an xml file and parses it down to a set of nested
-- lua tables that are easy to query and iterate over.
local xml = {}
local utils = import('utils')

function xml.parseAttributes(node, s)
	-- sets attributes parsed from s on node
	string.gsub(s, '(%w+)=(["\'])(.-)%2', function(w, _, a)
		node:addProperty(w, utils.unescapeEntities(a))
	end)
end

function xml.load(file)
	-- loads an xml file from disk and returns a node table
	-- structure representing its parsed form.
	return xml.parse(utils.readFile(file))
end

function xml.parse(contents)
	-- takes a string containing xml and returns a node table
	-- structure representing parsed xml.
	local stack = {}
	local top = xml.node()
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
			local lVal = (top:value() or '') .. utils.unescapeEntities(text)
			stack[#stack]:setValue(lVal)
		end

		if empty == '/' then
			-- if self-closing, add node to top
			local lNode = xml.node(label)
			xml.parseAttributes(lNode, attrs)
			top:addChild(lNode)
		elseif isClosing == '' then
			-- if not closing, make node and add to stack
			local lNode = xml.node(label)
			xml.parseAttributes(lNode, attrs)
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

function xml.node(name)
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

return xml
