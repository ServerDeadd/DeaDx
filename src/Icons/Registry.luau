return function(import)
	local Providers = import("Icons/Providers")
	local Utility = import("Core/Utility")

	local Registry = {
		_providers = {},
		_current = "lucide",
		_aliases = {},
	}

	Registry._providers.lucide = function(name)
		return Providers.Catalog(name) or Providers.Remote("lucide", name)
	end
	Registry._providers.builtin = Registry._providers.lucide
	Registry._providers.iconsax = function(name)
		return Providers.Remote("iconsax", name)
	end
	Registry._providers.tabler = function(name)
		return Providers.Remote("tabler", name)
	end
	Registry._providers.feather = function(name)
		return Providers.Remote("feather", name)
	end

	function Registry.Register(name, resolve)
		Utility.Check(
			type(name) == "string" and type(resolve) == "function",
			"IconProvider",
			name,
			"Expected (name: string, resolve: function)."
		)
		Registry._providers[string.lower(name)] = resolve
	end

	function Registry.SetProvider(name)
		name = string.lower(tostring(name))
		if not Registry._providers[name] then
			Utility.Warn(string.format('Icon provider "%s" is not registered.', tostring(name)))
			return false
		end
		Registry._current = name
		return true
	end

	function Registry.GetProvider()
		return Registry._current
	end

	function Registry.Providers()
		local out = {}
		for name in Registry._providers do
			table.insert(out, name)
		end
		table.sort(out)
		return out
	end

	function Registry.Alias(alias, spec)
		Utility.Check(type(alias) == "string", "IconAlias", alias, "Alias must be a string.")
		Registry._aliases[string.lower(alias)] = spec
	end

	local function fromString(spec)
		local alias = Registry._aliases[string.lower(spec)]
		if alias ~= nil and type(alias) ~= "table" then
			spec = alias
		elseif type(alias) == "table" then
			return alias
		end

		if string.sub(spec, 1, 8) == "https://" or string.sub(spec, 1, 7) == "http://" then
			return Providers.FromUrl(spec)
		end
		if
			string.sub(spec, 1, 13) == "rbxassetid://"
			or string.sub(spec, 1, 9) == "rbxasset:"
			or string.sub(spec, 1, 11) == "rbxthumb://"
			or string.sub(spec, 1, 10) == "rbxhttp://"
		then
			return { Type = "Image", Source = spec, Tint = false, Name = spec }
		end
		if string.match(spec, "^%d+$") then
			return { Type = "Image", Source = "rbxassetid://" .. spec, Tint = false, Name = spec }
		end
		if string.sub(spec, 1, 5) == "file:" then
			return { Type = "File", Source = string.sub(spec, 6), Tint = false, Name = spec }
		end

		local provider, name = string.match(spec, "^(%w[%w%-_]*):(.+)$")
		if provider and Registry._providers[string.lower(provider)] then
			local ok, resolved = pcall(Registry._providers[string.lower(provider)], name)
			if ok and resolved then
				return resolved
			end
			return nil
		end

		local resolver = Registry._providers[Registry._current]
		if resolver then
			local ok, resolved = pcall(resolver, spec)
			if ok and resolved then
				return resolved
			end
		end
		return Providers.Catalog(spec)
	end

	function Registry.Resolve(spec)
		if type(spec) == "number" then
			return { Type = "Image", Source = "rbxassetid://" .. tostring(spec), Tint = false, Name = tostring(spec) }
		end
		if type(spec) == "string" then
			if spec == "" then
				return nil
			end
			return fromString(spec)
		end
		if type(spec) == "table" then
			if spec.Type == "Image" or spec.Type == "Url" or spec.Type == "Svg" or spec.Type == "Vector" or spec.Type == "File" then
				return spec
			end
			local source = spec.Source or spec.Image or spec.Url or spec.Icon
			if type(source) == "string" or type(source) == "number" then
				local resolved = Registry.Resolve(source)
				if resolved then
					resolved = table.clone(resolved)
					if spec.Tint ~= nil then
						resolved.Tint = spec.Tint == true
					end
					if spec.Name then
						resolved.Name = spec.Name
					end
					resolved.Shape = spec.Shape or resolved.Shape
					resolved.Corner = spec.Corner or resolved.Corner
					resolved.ScaleType = spec.ScaleType or resolved.ScaleType
					return resolved
				end
			end
		end
		return nil
	end

	function Registry.Exists(spec)
		return Registry.Resolve(spec) ~= nil
	end

	return Registry
end
