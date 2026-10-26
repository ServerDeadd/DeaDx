return function(import)
	local Svg = { MaxSegments = 160 }

	local function attribute(source, name)
		local value = string.match(source, name .. '%s*=%s*"([^"]*)"')
		if value == nil then
			value = string.match(source, name .. "%s*=%s*'([^']*)'")
		end
		return value
	end

	local function numbers(source)
		local out = {}
		if type(source) ~= "string" then
			return out
		end
		for token in string.gmatch(source, "[-+]?%d*%.?%d+[eE]?[-+]?%d*") do
			local value = tonumber(token)
			if value then
				table.insert(out, value)
			end
		end
		return out
	end

	local function scan(data)
		local out = {}
		local index, length = 1, #data
		while index <= length do
			local char = string.sub(data, index, index)
			if string.match(char, "%a") then
				table.insert(out, { cmd = char })
				index += 1
			elseif string.match(char, "[%d%.%-+]") then
				local stop = index
				if string.match(string.sub(data, stop, stop), "[-+]") then
					stop += 1
				end
				while stop <= length and string.match(string.sub(data, stop, stop), "%d") do
					stop += 1
				end
				if string.sub(data, stop, stop) == "." then
					stop += 1
					while stop <= length and string.match(string.sub(data, stop, stop), "%d") do
						stop += 1
					end
				end
				local exponent = string.lower(string.sub(data, stop, stop))
				if exponent == "e" then
					stop += 1
					if string.match(string.sub(data, stop, stop), "[-+]") then
						stop += 1
					end
					while stop <= length and string.match(string.sub(data, stop, stop), "%d") do
						stop += 1
					end
				end
				local value = tonumber(string.sub(data, index, stop - 1))
				if value then
					table.insert(out, { num = value })
				end
				index = stop > index and stop or index + 1
			else
				index += 1
			end
		end
		return out
	end

	local function cubic(points, x0, y0, x1, y1, x2, y2, x3, y3)
		local rough = math.abs(x1 - x0) + math.abs(y1 - y0) + math.abs(x2 - x1) + math.abs(y2 - y1) + math.abs(x3 - x2) + math.abs(y3 - y2)
		local steps = math.clamp(math.floor(rough / 1.4 + 0.5), 3, 14)
		for step = 1, steps do
			local t = step / steps
			local u = 1 - t
			local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
			table.insert(points, {
				a * x0 + b * x1 + c * x2 + d * x3,
				a * y0 + b * y1 + c * y2 + d * y3,
			})
		end
	end

	local function arc(points, x0, y0, rx, ry, rotation, largeArc, sweep, x1, y1)
		if rx == 0 or ry == 0 then
			table.insert(points, { x1, y1 })
			return
		end
		rx, ry = math.abs(rx), math.abs(ry)
		local phi = math.rad(rotation or 0)
		local cosPhi, sinPhi = math.cos(phi), math.sin(phi)
		local dx2, dy2 = (x0 - x1) / 2, (y0 - y1) / 2
		local x1p = cosPhi * dx2 + sinPhi * dy2
		local y1p = -sinPhi * dx2 + cosPhi * dy2
		local check = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
		if check > 1 then
			local scale = math.sqrt(check)
			rx, ry = rx * scale, ry * scale
		end
		local denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
		local numerator = rx * rx * ry * ry - denominator
		if numerator < 0 then
			numerator = 0
		end
		local factor = math.sqrt(numerator / math.max(denominator, 1e-9))
		if largeArc == sweep then
			factor = -factor
		end
		local cxp = factor * rx * y1p / ry
		local cyp = -factor * ry * x1p / rx
		local cx = cosPhi * cxp - sinPhi * cyp + (x0 + x1) / 2
		local cy = sinPhi * cxp + cosPhi * cyp + (y0 + y1) / 2

		local function angle(ux, uy, vx, vy)
			local dot = ux * vx + uy * vy
			local len = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
			local value = math.acos(math.clamp(dot / math.max(len, 1e-9), -1, 1))
			if ux * vy - uy * vx < 0 then
				value = -value
			end
			return value
		end

		local start = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
		local delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
		if sweep == 0 and delta > 0 then
			delta -= math.pi * 2
		elseif sweep == 1 and delta < 0 then
			delta += math.pi * 2
		end

		local steps = math.clamp(math.ceil(math.abs(delta) / 0.32), 2, 20)
		for step = 1, steps do
			local theta = start + delta * (step / steps)
			local ex, ey = rx * math.cos(theta), ry * math.sin(theta)
			table.insert(points, {
				cosPhi * ex - sinPhi * ey + cx,
				sinPhi * ex + cosPhi * ey + cy,
			})
		end
	end

	local function path(data)
		local polylines = {}
		local items = scan(data)
		local current = {}
		local x, y, startX, startY = 0, 0, 0, 0
		local lastCommand
		local controlX, controlY
		local index = 1

		local function push()
			if #current > 1 then
				table.insert(polylines, current)
			end
			current = {}
		end

		local function take(count)
			local out = {}
			for offset = 0, count - 1 do
				local item = items[index + offset]
				if not item or not item.num then
					return nil
				end
				out[offset + 1] = item.num
			end
			index += count
			return out
		end

		while index <= #items do
			local item = items[index]
			local command
			if item.cmd then
				command = item.cmd
				index += 1
			elseif lastCommand then
				command = lastCommand == "M" and "L" or (lastCommand == "m" and "l" or lastCommand)
			else
				index += 1
				continue
			end
			lastCommand = command
			local upper = string.upper(command)
			local relative = command ~= upper

			if upper == "M" then
				local values = take(2)
				if not values then
					break
				end
				push()
				x = relative and x + values[1] or values[1]
				y = relative and y + values[2] or values[2]
				startX, startY = x, y
				current = { { x, y } }
				controlX, controlY = nil, nil
			elseif upper == "L" then
				local values = take(2)
				if not values then
					break
				end
				x = relative and x + values[1] or values[1]
				y = relative and y + values[2] or values[2]
				table.insert(current, { x, y })
				controlX, controlY = nil, nil
			elseif upper == "H" then
				local values = take(1)
				if not values then
					break
				end
				x = relative and x + values[1] or values[1]
				table.insert(current, { x, y })
				controlX, controlY = nil, nil
			elseif upper == "V" then
				local values = take(1)
				if not values then
					break
				end
				y = relative and y + values[1] or values[1]
				table.insert(current, { x, y })
				controlX, controlY = nil, nil
			elseif upper == "C" then
				local values = take(6)
				if not values then
					break
				end
				local x1 = relative and x + values[1] or values[1]
				local y1 = relative and y + values[2] or values[2]
				local x2 = relative and x + values[3] or values[3]
				local y2 = relative and y + values[4] or values[4]
				local x3 = relative and x + values[5] or values[5]
				local y3 = relative and y + values[6] or values[6]
				cubic(current, x, y, x1, y1, x2, y2, x3, y3)
				controlX, controlY = x2, y2
				x, y = x3, y3
			elseif upper == "S" then
				local values = take(4)
				if not values then
					break
				end
				local x1 = controlX and (2 * x - controlX) or x
				local y1 = controlY and (2 * y - controlY) or y
				local x2 = relative and x + values[1] or values[1]
				local y2 = relative and y + values[2] or values[2]
				local x3 = relative and x + values[3] or values[3]
				local y3 = relative and y + values[4] or values[4]
				cubic(current, x, y, x1, y1, x2, y2, x3, y3)
				controlX, controlY = x2, y2
				x, y = x3, y3
			elseif upper == "Q" then
				local values = take(4)
				if not values then
					break
				end
				local qx = relative and x + values[1] or values[1]
				local qy = relative and y + values[2] or values[2]
				local ex = relative and x + values[3] or values[3]
				local ey = relative and y + values[4] or values[4]
				cubic(current, x, y, x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey), ex, ey)
				controlX, controlY = qx, qy
				x, y = ex, ey
			elseif upper == "T" then
				local values = take(2)
				if not values then
					break
				end
				local qx = controlX and (2 * x - controlX) or x
				local qy = controlY and (2 * y - controlY) or y
				local ex = relative and x + values[1] or values[1]
				local ey = relative and y + values[2] or values[2]
				cubic(current, x, y, x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey), ex, ey)
				controlX, controlY = qx, qy
				x, y = ex, ey
			elseif upper == "A" then
				local values = take(7)
				if not values then
					break
				end
				local ex = relative and x + values[6] or values[6]
				local ey = relative and y + values[7] or values[7]
				arc(current, x, y, values[1], values[2], values[3], values[4], values[5], ex, ey)
				x, y = ex, ey
				controlX, controlY = nil, nil
			elseif upper == "Z" then
				if #current > 0 then
					table.insert(current, { startX, startY })
				end
				x, y = startX, startY
				push()
				lastCommand = nil
				controlX, controlY = nil, nil
			else
				index += 1
			end
		end
		push()
		return polylines
	end
	Svg.Path = path

	local function segments(spec, polylines)
		for _, line in polylines do
			for index = 1, #line - 1 do
				if #spec.L >= Svg.MaxSegments then
					return
				end
				local a, b = line[index], line[index + 1]
				if math.abs(a[1] - b[1]) > 0.01 or math.abs(a[2] - b[2]) > 0.01 then
					table.insert(spec.L, { a[1], a[2], b[1], b[2] })
				end
			end
		end
	end

	function Svg.Parse(text)
		if type(text) ~= "string" or not string.find(text, "<svg", 1, true) then
			return nil
		end
		local header = string.match(text, "<svg([^>]*)>") or ""
		local box = numbers(attribute(header, "viewBox"))
		local size = 24
		if #box >= 4 and box[3] > 0 then
			size = math.max(box[3], box[4])
		else
			local width = tonumber(attribute(header, "width") or "")
			if width and width > 0 then
				size = width
			end
		end
		local offsetX = #box >= 4 and box[1] or 0
		local offsetY = #box >= 4 and box[2] or 0

		local spec = {
			Type = "Vector",
			Size = size,
			Width = tonumber(attribute(header, "stroke%-width") or "") or 2,
			L = {},
			C = {},
			R = {},
		}

		for tag, body in string.gmatch(text, "<(%a+)([^>]*)>") do
			tag = string.lower(tag)
			if tag == "path" then
				local data = attribute(body, "d")
				if data then
					segments(spec, path(data))
				end
			elseif tag == "line" then
				local x1 = tonumber(attribute(body, "x1") or "") or 0
				local y1 = tonumber(attribute(body, "y1") or "") or 0
				local x2 = tonumber(attribute(body, "x2") or "") or 0
				local y2 = tonumber(attribute(body, "y2") or "") or 0
				table.insert(spec.L, { x1, y1, x2, y2 })
			elseif tag == "circle" then
				local cx = tonumber(attribute(body, "cx") or "") or 0
				local cy = tonumber(attribute(body, "cy") or "") or 0
				local r = tonumber(attribute(body, "r") or "") or 0
				if r > 0 then
					table.insert(spec.C, { cx, cy, r })
				end
			elseif tag == "ellipse" then
				local cx = tonumber(attribute(body, "cx") or "") or 0
				local cy = tonumber(attribute(body, "cy") or "") or 0
				local rx = tonumber(attribute(body, "rx") or "") or 0
				local ry = tonumber(attribute(body, "ry") or "") or 0
				if rx > 0 and ry > 0 then
					if math.abs(rx - ry) < 0.2 then
						table.insert(spec.C, { cx, cy, (rx + ry) / 2 })
					else
						local points = {}
						for step = 0, 20 do
							local theta = step / 20 * math.pi * 2
							table.insert(points, { cx + rx * math.cos(theta), cy + ry * math.sin(theta) })
						end
						segments(spec, { points })
					end
				end
			elseif tag == "rect" then
				local rx = tonumber(attribute(body, "x") or "") or 0
				local ry = tonumber(attribute(body, "y") or "") or 0
				local width = tonumber(attribute(body, "width") or "") or 0
				local height = tonumber(attribute(body, "height") or "") or 0
				local radius = tonumber(attribute(body, "rx") or "") or 0
				if width > 0 and height > 0 then
					table.insert(spec.R, { rx, ry, width, height, radius })
				end
			elseif tag == "polyline" or tag == "polygon" then
				local values = numbers(attribute(body, "points"))
				local points = {}
				for index = 1, #values - 1, 2 do
					table.insert(points, { values[index], values[index + 1] })
				end
				if tag == "polygon" and #points > 2 then
					table.insert(points, points[1])
				end
				segments(spec, { points })
			end
		end

		if offsetX ~= 0 or offsetY ~= 0 then
			for _, line in spec.L do
				line[1] -= offsetX
				line[2] -= offsetY
				line[3] -= offsetX
				line[4] -= offsetY
			end
			for _, circle in spec.C do
				circle[1] -= offsetX
				circle[2] -= offsetY
			end
			for _, rect in spec.R do
				rect[1] -= offsetX
				rect[2] -= offsetY
			end
		end

		if #spec.L == 0 and #spec.C == 0 and #spec.R == 0 then
			return nil
		end
		return spec
	end

	function Svg.Encode(spec)
		local HttpService = game:GetService("HttpService")
		local ok, json = pcall(HttpService.JSONEncode, HttpService, {
			Size = spec.Size,
			Width = spec.Width,
			L = spec.L,
			C = spec.C,
			R = spec.R,
		})
		return ok and json or nil
	end

	function Svg.Decode(json)
		local HttpService = game:GetService("HttpService")
		local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
		if not ok or type(data) ~= "table" then
			return nil
		end
		return {
			Type = "Vector",
			Size = data.Size or 24,
			Width = data.Width or 2,
			L = data.L or {},
			C = data.C or {},
			R = data.R or {},
		}
	end

	return Svg
end
