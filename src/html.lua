-- this module is responsible for taking an html string and reducing it
-- down to a simplified document outline. Unlike the xml module this
-- module does not, strictly speaking, parse the html; we're just
-- naively extracting the contents that are relevant to us.
local html = {}

local utils = import('utils')

function html.parseAttribs(attrs)
	-- returns a table mapping attribute names to their values
	local node = {}
	string.gsub(attrs, '(%w+)=(["\'])(.-)%2', function(name, _, value)
		node[name] = utils.unescapeEntities(value)
	end)
	return node
end

function html.parse(contents)
	-- Parses the html and produces a flat table of items that are
	-- relevant to the display of the page. Each item is a table
	-- containing at least the key 'type', as well as any other
	-- data associated with that element, such as any text content.
	--
	-- only three types of content are supported:
	-- title, text, and image
	contents = utils.utf8ToAscii(contents)
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
		local stripped = utils.unescapeEntities(text:strip())
		if stripped ~= '' then
			if type ~= 'ignore' then
				table.insert(result, {type=type, content=stripped})
			end
			type = 'p'
			text = ''
		end
	end

	-- the kinds of html _text content_ tags we support and what
	-- they map to
	local tagMap = {
		title='ignore', style='ignore',
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

		local parsedAttrs = html.parseAttribs(attrs)

		if empty == '/' then
			if label == 'img' then
				writeItem()
				table.insert(result, {
					type='img', src=parsedAttrs.src, alt=parsedAttrs.alt,
				})
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

return html
