return function(import)
	local Signal = import("Core/Signal")
	local Default = import("Themes/Default")

	local ALIASES = {
		Secondary = "SecondaryBackground",
		Tertiary = "TertiaryBackground",
		SubText = "MutedText",
		Element = "SecondaryBackground",
		Stroke = "Border",
	}

	local Theme = {
		Changed = Signal.new(),
		ScaleChanged = Signal.new(),
		Scale = 1,
	}

	local themes = {}
	local order = {}
	local current = "DeaDx"

	local function applyFont(font)
		Theme.Font = font
		Theme.FontBold = Font.new(font.Family, Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
		Theme.FontHeavy = Font.new(font.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end
	applyFont(Font.fromEnum(Enum.Font.GothamMedium))

	function Theme.Register(name, definition)
		if type(name) ~= "string" or type(definition) ~= "table" then
			error("[DEADX][ERROR] Theme.Register expects (name: string, definition: table)", 2)
		end
		local base = definition.Base and themes[definition.Base] or Default
		local merged = table.clone(base)
		for key, value in definition do
			if key ~= "Base" and key ~= "Name" then
				key = ALIASES[key] or key
				local expected = Default[key]
				if expected ~= nil and typeof(expected) ~= typeof(value) then
					error(string.format('[DEADX][ERROR] Theme "%s": token "%s" must be %s', name, key, typeof(expected)), 2)
				end
				merged[key] = value
			end
		end
		if not themes[name] then
			table.insert(order, name)
		end
		themes[name] = merged
		if name == current then
			Theme.Changed:Fire(current)
		end
	end

	function Theme.Set(name, force)
		if Theme.Locked and not force then
			return false, "theme is locked"
		end
		if type(name) == "table" then
			local custom = name.Name or "Custom"
			Theme.Register(custom, name)
			name = custom
		end
		if not themes[name] then
			warn(string.format('[DEADX][WARN] Theme "%s" is not registered.', tostring(name)))
			return false
		end
		current = name
		Theme.Changed:Fire(name)
		return true
	end

	function Theme.Lock(name)
		Theme.Locked = false
		if name ~= nil then
			Theme.Set(name, true)
		end
		Theme.Locked = true
		return current
	end

	function Theme.Unlock()
		Theme.Locked = false
		return current
	end

	function Theme.IsLocked()
		return Theme.Locked == true
	end

	function Theme.GetName()
		return current
	end

	function Theme.Names()
		return table.clone(order)
	end

	function Theme.Has(name)
		return themes[name] ~= nil
	end

	function Theme.Get(token)
		token = ALIASES[token] or token
		local active = themes[current]
		local value = active and active[token]
		if value == nil then
			value = Default[token]
		end
		return value
	end

	function Theme.Resolve(value, fallback)
		if value == nil then
			return fallback and Theme.Get(fallback) or nil
		end
		if typeof(value) == "Color3" then
			return value
		end
		if type(value) == "string" then
			local token = Theme.Get(value)
			if typeof(token) == "Color3" then
				return token
			end
			local hex = string.gsub(value, "^#", "")
			if #hex == 3 then
				hex = string.gsub(hex, ".", "%0%0")
			end
			if #hex == 6 and not string.find(hex, "%X") then
				return Color3.fromRGB(
					tonumber(string.sub(hex, 1, 2), 16),
					tonumber(string.sub(hex, 3, 4), 16),
					tonumber(string.sub(hex, 5, 6), 16)
				)
			end
		end
		return fallback and Theme.Get(fallback) or nil
	end

	function Theme.BindFn(callback, cleanup)
		callback()
		local connection = Theme.Changed:Connect(callback)
		if cleanup then
			cleanup:Add(connection)
		end
		return connection
	end

	function Theme.Bind(instance, map, cleanup)
		return Theme.BindFn(function()
			for property, token in map do
				if type(token) == "function" then
					instance[property] = token(Theme)
				else
					instance[property] = Theme.Get(token)
				end
			end
		end, cleanup)
	end

	function Theme.SetFont(font)
		if typeof(font) == "EnumItem" then
			applyFont(Font.fromEnum(font))
		elseif typeof(font) == "Font" then
			applyFont(font)
		elseif type(font) == "string" then
			applyFont(Font.new(font, Enum.FontWeight.Medium, Enum.FontStyle.Normal))
		else
			error("[DEADX][ERROR] SetFont expects an Enum.Font, a Font or a font asset id", 2)
		end
		Theme.Changed:Fire(current)
	end

	function Theme.SetScale(scale, force)
		if type(scale) ~= "number" then
			error("[DEADX][ERROR] SetScale expects a number", 2)
		end
		if Theme.ScaleLocked and not force then
			return false, "scale is locked"
		end
		Theme.Scale = math.clamp(scale, 0.5, 2)
		Theme.ScaleChanged:Fire(Theme.Scale)
		return true
	end

	function Theme.LockScale(scale)
		Theme.ScaleLocked = false
		if scale ~= nil then
			Theme.SetScale(scale, true)
		end
		Theme.ScaleLocked = true
		return Theme.Scale
	end

	function Theme.UnlockScale()
		Theme.ScaleLocked = false
		return Theme.Scale
	end

	function Theme.IsScaleLocked()
		return Theme.ScaleLocked == true
	end

	function Theme.BindScale(uiScale, cleanup)
		uiScale.Scale = Theme.Scale
		local connection = Theme.ScaleChanged:Connect(function(value)
			uiScale.Scale = value
		end)
		if cleanup then
			cleanup:Add(connection)
		end
		return connection
	end

	function Theme.Override(token, value)
		local active = themes[current]
		if active then
			active[ALIASES[token] or token] = value
			Theme.Changed:Fire(current)
		end
	end

	return Theme
end
