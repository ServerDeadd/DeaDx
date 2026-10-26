return function(import)
	local Store = import("Icons/Store")
	local Utility = import("Core/Utility")

	local Providers = {}

	local names
	local catalog

	local function entries()
		if catalog then
			return catalog
		end
		catalog = {}
		for name, id in string.gmatch(import("Icons/Catalog"), "([^;=]+)=([^;]+)") do
			catalog[name] = id
		end
		return catalog
	end
	Providers.Entries = entries

	Providers.Templates = {
		lucide = "https://unpkg.com/lucide-static@0.544.0/icons/%s.svg",
		iconsax = "https://raw.githubusercontent.com/lusaxweb/iconsax/master/svg/%s.svg",
		tabler = "https://unpkg.com/@tabler/icons@3.31.0/icons/outline/%s.svg",
		feather = "https://unpkg.com/feather-icons@4.29.2/dist/icons/%s.svg",
	}

	function Providers.SetTemplate(provider, template)
		Utility.Check(
			type(provider) == "string" and type(template) == "string" and string.find(template, "%%s") ~= nil,
			"IconTemplate",
			provider,
			"Expected (provider: string, template: string) where template contains %s."
		)
		Providers.Templates[string.lower(provider)] = template
	end

	function Providers.Template(provider)
		return Providers.Templates[string.lower(provider or "")]
	end

	local RENAMES = {
		house = "home",
		["square-pen"] = "edit-3",
		["pen-line"] = "edit-3",
		["loader-circle"] = "loader-2",
		["gauge-circle"] = "gauge",
		["circle-dot"] = "dot-circle",
		["message-circle-more"] = "message-circle",
		["panel-left"] = "sidebar",
		["panel-top"] = "panel-top",
		["chart-no-axes-column"] = "bar-chart",
		["chart-column"] = "bar-chart-3",
		["chart-line"] = "line-chart",
		["chart-pie"] = "pie-chart",
		["chart-bar"] = "bar-chart-horizontal",
		["arrow-up-narrow-wide"] = "arrow-up-narrow-wide",
		["ellipsis"] = "more-horizontal",
		["ellipsis-vertical"] = "more-vertical",
		["x-circle"] = "circle-x",
		["refresh-ccw-dot"] = "refresh-ccw",
	}

	local function rotate(name)
		local parts = string.split(name, "-")
		if #parts < 2 then
			return nil
		end
		local first = table.remove(parts, 1)
		table.insert(parts, first)
		return table.concat(parts, "-")
	end

	function Providers.Catalog(name)
		if type(name) ~= "string" then
			return nil
		end
		local key = string.lower(name)
		local source = entries()
		local id = source[key]
		if not id and RENAMES[key] then
			id = source[RENAMES[key]]
		end
		if not id then
			local rotated = rotate(key)
			if rotated then
				id = source[rotated]
			end
		end
		if not id then
			return nil
		end
		return { Type = "Image", Source = "rbxassetid://" .. id, Tint = true, Name = key }
	end

	function Providers.Names()
		if not names then
			names = {}
			for key in entries() do
				table.insert(names, key)
			end
			table.sort(names)
		end
		return table.clone(names)
	end

	function Providers.Count()
		return #Providers.Names()
	end

	local PHOTO = {
		png = true, jpg = true, jpeg = true, webp = true,
		bmp = true, tga = true, gif = true, avif = true,
	}

	function Providers.Kind(url)
		local path = string.lower(tostring(url))
		path = string.match(path, "^([^?#]+)") or path
		local extension = string.match(path, "%.(%w+)$")
		if extension == "svg" then
			return "Svg", true
		end
		if extension and PHOTO[extension] then
			return "Url", false
		end
		if string.find(path, "%.svg") then
			return "Svg", true
		end
		return "Url", false
	end

	function Providers.IsPhoto(url)
		local _, tint = Providers.Kind(url)
		return not tint
	end

	function Providers.Remote(provider, name)
		local template = Providers.Template(provider)
		if not template then
			return nil
		end
		local url = string.format(template, name)
		local kind = Providers.Kind(url)
		return {
			Type = kind,
			Source = url,
			Tint = true,
			Name = string.lower(provider) .. "-" .. Utility.Slug(name),
		}
	end

	function Providers.FromUrl(url, name, tint)
		local kind, monochrome = Providers.Kind(url)
		if tint == nil then
			tint = monochrome
		end
		return {
			Type = kind,
			Source = url,
			Tint = tint == true,
			Name = name or ("url-" .. Utility.Hash(url)),
		}
	end

	function Providers.Load(spec, callback)
		if spec.Type == "Url" then
			Store.Raster(spec.Name or Utility.Hash(spec.Source), spec.Source, callback)
		elseif spec.Type == "Svg" then
			Store.Vector(spec.Name or Utility.Hash(spec.Source), spec.Source, callback)
		else
			callback(nil)
		end
	end

	local fallback
	function Providers.GetFallback()
		if fallback == nil then
			fallback = Providers.Catalog(Providers.FallbackName or "circle-help") or false
		end
		return fallback or nil
	end

	return Providers
end

