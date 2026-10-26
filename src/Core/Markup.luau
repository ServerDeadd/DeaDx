return function(import)
	local Markup = { Enabled = true }

	local NAMED = {
		black = "#000000",
		white = "#FFFFFF",
		red = "#FF5555",
		darkred = "#AA0000",
		green = "#55FF55",
		darkgreen = "#00AA00",
		lime = "#A3E635",
		blue = "#5555FF",
		darkblue = "#0000AA",
		aqua = "#55FFFF",
		cyan = "#22D3EE",
		teal = "#14B8A6",
		darkaqua = "#00AAAA",
		yellow = "#FACC15",
		gold = "#FFAA00",
		orange = "#FB923C",
		purple = "#A855F7",
		darkpurple = "#AA00AA",
		violet = "#8B5CF6",
		magenta = "#FF55FF",
		pink = "#F472B6",
		rose = "#FB7185",
		brown = "#AA5500",
		gray = "#AAAAAA",
		grey = "#AAAAAA",
		darkgray = "#555555",
		darkgrey = "#555555",
		silver = "#D4D4D8",
		slate = "#64748B",
		indigo = "#6366F1",
		emerald = "#34D399",
		amber = "#FBBF24",
		crimson = "#DC2626",
		mint = "#6EE7B7",
		sky = "#38BDF8",
		deadx = "#FF2D40",
	}

	local STYLES = {
		b = "b",
		bold = "b",
		i = "i",
		italic = "i",
		em = "i",
		u = "u",
		underline = "u",
		underlined = "u",
		s = "s",
		strike = "s",
		strikethrough = "s",
	}

	function Markup.RegisterColor(name, hex)
		if type(name) == "string" and type(hex) == "string" then
			NAMED[string.lower(name)] = hex
		end
	end

	function Markup.Colors()
		local out = {}
		for name in NAMED do
			table.insert(out, name)
		end
		table.sort(out)
		return out
	end

	local function toHex(value)
		if typeof(value) == "Color3" then
			return string.format(
				"#%02X%02X%02X",
				math.floor(value.R * 255 + 0.5),
				math.floor(value.G * 255 + 0.5),
				math.floor(value.B * 255 + 0.5)
			)
		end
		if type(value) ~= "string" then
			return nil
		end
		local text = string.gsub(value, "^#", "")
		if #text == 3 and not string.find(text, "%X") then
			text = string.gsub(text, ".", "%0%0")
		end
		if #text == 6 and not string.find(text, "%X") then
			return "#" .. string.upper(text)
		end
		return NAMED[string.lower(value)]
	end
	Markup.ToHex = toHex

	local function channels(hex)
		return tonumber(string.sub(hex, 2, 3), 16) or 0,
			tonumber(string.sub(hex, 4, 5), 16) or 0,
			tonumber(string.sub(hex, 6, 7), 16) or 0
	end

	local function mix(a, b, alpha)
		local r1, g1, b1 = channels(a)
		local r2, g2, b2 = channels(b)
		return string.format(
			"#%02X%02X%02X",
			math.floor(r1 + (r2 - r1) * alpha + 0.5),
			math.floor(g1 + (g2 - g1) * alpha + 0.5),
			math.floor(b1 + (b2 - b1) * alpha + 0.5)
		)
	end

	local function sample(stops, alpha)
		alpha = math.clamp(alpha, 0, 1)
		if #stops == 1 then
			return stops[1]
		end
		local segments = #stops - 1
		local scaled = alpha * segments
		local index = math.min(math.floor(scaled), segments - 1)
		return mix(stops[index + 1], stops[index + 2], scaled - index)
	end

	local function units(content)
		local list = {}
		local position = 1
		local length = #content
		while position <= length do
			local char = string.sub(content, position, position)
			if char == "<" then
				local close = string.find(content, ">", position, true)
				if close then
					table.insert(list, { tag = string.sub(content, position, close) })
					position = close + 1
					continue
				end
			elseif char == "&" then
				local close = string.find(content, ";", position, true)
				if close and close - position <= 8 then
					table.insert(list, { text = string.sub(content, position, close) })
					position = close + 1
					continue
				end
			end
			table.insert(list, { text = char })
			position += 1
		end
		return list
	end

	local function paint(content, pick)
		local parts = units(content)
		local total = 0
		for _, part in parts do
			if part.text and part.text ~= "\n" then
				total += 1
			end
		end
		if total == 0 then
			return content
		end
		local out, run, runColor = {}, "", nil
		local index = 0

		local function flush()
			if run ~= "" then
				if runColor then
					table.insert(out, string.format('<font color="%s">%s</font>', runColor, run))
				else
					table.insert(out, run)
				end
				run, runColor = "", nil
			end
		end

		for _, part in parts do
			if part.tag then
				flush()
				table.insert(out, part.tag)
			elseif part.text == "\n" then
				flush()
				table.insert(out, part.text)
			else
				local color = pick(total <= 1 and 0 or index / (total - 1), index, total)
				if color ~= runColor then
					flush()
					runColor = color
				end
				run ..= part.text
				index += 1
			end
		end
		flush()
		return table.concat(out)
	end

	local function gradient(spec, content)
		local stops = {}
		for token in string.gmatch(spec, "[^:,%s]+") do
			local hex = toHex(token)
			if hex then
				table.insert(stops, hex)
			end
		end
		if #stops == 0 then
			return content
		end
		return paint(content, function(alpha)
			return sample(stops, alpha)
		end)
	end

	local function rainbow(spec, content)
		local saturation = tonumber(string.match(spec or "", "s(%d+%.?%d*)")) or 0.85
		local offset = tonumber(string.match(spec or "", "o(%d+%.?%d*)")) or 0
		return paint(content, function(alpha)
			local color = Color3.fromHSV((offset + alpha * 0.85) % 1, math.clamp(saturation, 0, 1), 1)
			return toHex(color)
		end)
	end

	function Markup.Has(text)
		return type(text) == "string" and string.find(text, "<[^>]+>") ~= nil
	end

	function Markup.Parse(text)
		if not Markup.Enabled or type(text) ~= "string" or text == "" then
			return text
		end
		if not string.find(text, "<[^>]+>") then
			return text
		end

		local result = string.gsub(text, "<br%s*/?>", "\n")
		result = string.gsub(result, "<newline>", "\n")
		result = string.gsub(result, "<nl>", "\n")

		for _ = 1, 8 do
			local replaced, count = string.gsub(result, "<gradient:([^>]+)>(.-)</gradient>", gradient)
			result = replaced
			if count == 0 then
				break
			end
		end

		for _ = 1, 4 do
			local replaced, count = string.gsub(result, "<rainbow:?([^>]*)>(.-)</rainbow>", rainbow)
			result = replaced
			if count == 0 then
				break
			end
		end

		result = string.gsub(result, "<color:([^>]+)>", function(token)
			local hex = toHex(token)
			return hex and string.format('<font color="%s">', hex) or ""
		end)
		result = string.gsub(result, "</color>", "</font>")

		result = string.gsub(result, "<(#?%x%x%x%x%x%x)>", function(token)
			local hex = toHex(token)
			return hex and string.format('<font color="%s">', hex) or ""
		end)
		result = string.gsub(result, "</#?%x%x%x%x%x%x>", "</font>")

		result = string.gsub(result, "<size:(%d+)>", '<font size="%1">')
		result = string.gsub(result, "</size>", "</font>")
		result = string.gsub(result, "<fade:(%d*%.?%d+)>", '<font transparency="%1">')
		result = string.gsub(result, "</fade>", "</font>")
		result = string.gsub(result, "<stroke:([^>]+)>", function(token)
			local hex = toHex(token)
			return hex and string.format('<stroke color="%s" thickness="1">', hex) or ""
		end)

		result = string.gsub(result, "<(/?)(%a+)>", function(slash, name)
			local style = STYLES[string.lower(name)]
			if style then
				return "<" .. slash .. style .. ">"
			end
			local hex = NAMED[string.lower(name)]
			if hex then
				return slash == "/" and "</font>" or string.format('<font color="%s">', hex)
			end
			return "<" .. slash .. name .. ">"
		end)

		result = string.gsub(result, "<reset>", "</font></b></i></u></s>")
		result = string.gsub(result, '<font color="[^"]*"></font>', "")
		return result
	end

	function Markup.Strip(text)
		if type(text) ~= "string" then
			return text
		end
		local result = string.gsub(text, "<br%s*/?>", " ")
		result = string.gsub(result, "<[^>]+>", "")
		result = string.gsub(result, "&lt;", "<")
		result = string.gsub(result, "&gt;", ">")
		result = string.gsub(result, "&quot;", '"')
		result = string.gsub(result, "&apos;", "'")
		result = string.gsub(result, "&amp;", "&")
		return result
	end

	function Markup.Escape(text)
		if type(text) ~= "string" then
			return text
		end
		local result = string.gsub(text, "&", "&amp;")
		result = string.gsub(result, "<", "&lt;")
		result = string.gsub(result, ">", "&gt;")
		return result
	end

	function Markup.Color(value, text)
		local hex = toHex(value)
		if not hex then
			return text
		end
		return string.format("<color:%s>%s</color>", hex, text)
	end

	function Markup.Gradient(stops, text)
		local tokens = {}
		for _, stop in stops do
			local hex = toHex(stop)
			if hex then
				table.insert(tokens, hex)
			end
		end
		if #tokens == 0 then
			return text
		end
		return string.format("<gradient:%s>%s</gradient>", table.concat(tokens, ":"), text)
	end

	return Markup
end
