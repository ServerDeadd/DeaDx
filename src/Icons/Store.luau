return function(import)
	local HttpService = game:GetService("HttpService")
	local Capabilities = import("Core/Capabilities")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Svg = import("Icons/Svg")

	local Store = {
		Folder = "DeaDx/icons",
		Index = "DeaDx/icons/index.json",
		MaxBytes = 524288,
		Verify = true,
		Updated = Signal.new(),
	}

	local manifest
	local assets = {}
	local vectors = {}
	local pending = {}
	local checked = {}
	local writeQueued = false
	local dirty = false

	local function available()
		return Capabilities.FileSystem and Capabilities.GetCustomAsset ~= nil
	end
	Store.Available = available

	local function load()
		if manifest then
			return manifest
		end
		manifest = {}
		if not available() then
			return manifest
		end
		Capabilities.EnsureFolder(Store.Folder)
		if Capabilities.FS.IsFile(Store.Index) then
			local ok, body = pcall(Capabilities.FS.Read, Store.Index)
			if ok and type(body) == "string" and body ~= "" then
				local parsed, data = pcall(HttpService.JSONDecode, HttpService, body)
				if parsed and type(data) == "table" then
					manifest = data
				end
			end
		end
		return manifest
	end

	local function flush()
		if not available() then
			return
		end
		dirty = true
		if writeQueued then
			return
		end
		writeQueued = true
		task.delay(0.6, function()
			writeQueued = false
			if not dirty then
				return
			end
			dirty = false
			local ok, body = pcall(HttpService.JSONEncode, HttpService, manifest or {})
			if ok then
				pcall(Capabilities.FS.Write, Store.Index, body)
			end
		end)
	end

	local function isRaster(body)
		if type(body) ~= "string" or #body < 12 then
			return false
		end
		if string.sub(body, 2, 4) == "PNG" then
			return true
		end
		if string.byte(body, 1) == 255 and string.byte(body, 2) == 216 then
			return true
		end
		return false
	end

	local function customAsset(path)
		local ok, asset = pcall(Capabilities.GetCustomAsset, path)
		if ok and type(asset) == "string" and asset ~= "" then
			return asset
		end
		return nil
	end

	local function download(url)
		local ok, body = Capabilities.HttpGet(url)
		if not ok or type(body) ~= "string" or body == "" then
			return nil, "download failed"
		end
		if #body > Store.MaxBytes then
			return nil, "icon too large"
		end
		return body
	end

	function Store.Entry(key)
		return load()[key]
	end

	function Store.List()
		local out = {}
		for key in load() do
			table.insert(out, key)
		end
		table.sort(out)
		return out
	end

	function Store.Forget(key)
		local data = load()
		local entry = data[key]
		if entry then
			if available() and Capabilities.FS.Delete and entry.file and Capabilities.FS.IsFile(entry.file) then
				pcall(Capabilities.FS.Delete, entry.file)
			end
			if available() and Capabilities.FS.Delete and entry.spec and Capabilities.FS.IsFile(entry.spec) then
				pcall(Capabilities.FS.Delete, entry.spec)
			end
			data[key] = nil
			flush()
		end
		assets[key] = nil
		vectors[key] = nil
		checked[key] = nil
		return entry ~= nil
	end

	function Store.Clear()
		for _, key in Store.List() do
			Store.Forget(key)
		end
		manifest = {}
		flush()
	end

	local function resolveRaster(key, url, body)
		local data = load()
		local path = string.format("%s/%s.png", Store.Folder, key)
		local written = pcall(Capabilities.FS.Write, path, body)
		if not written then
			return nil
		end
		local asset = customAsset(path)
		if not asset then
			return nil
		end
		data[key] = { kind = "raster", url = url, hash = Utility.Hash(body), file = path, size = #body }
		flush()
		assets[key] = asset
		return asset
	end

	local function resolveVector(key, url, body)
		local spec = Svg.Parse(body)
		if not spec then
			return nil
		end
		local data = load()
		local entry = { kind = "vector", url = url, hash = Utility.Hash(body) }
		if available() then
			local rawPath = string.format("%s/%s.svg", Store.Folder, key)
			local specPath = string.format("%s/%s.json", Store.Folder, key)
			local encoded = Svg.Encode(spec)
			if encoded then
				pcall(Capabilities.FS.Write, rawPath, body)
				pcall(Capabilities.FS.Write, specPath, encoded)
				entry.file = rawPath
				entry.spec = specPath
			end
		end
		data[key] = entry
		flush()
		vectors[key] = spec
		return spec
	end

	local function revalidate(key, url, vector)
		if not Store.Verify or checked[key] then
			return
		end
		checked[key] = true
		task.spawn(function()
			local body = download(url)
			if not body then
				return
			end
			local data = load()
			local entry = data[key]
			local hash = Utility.Hash(body)
			if entry and entry.hash == hash then
				return
			end
			if vector then
				local spec = resolveVector(key, url, body)
				if spec then
					Store.Updated:Fire(key, spec, true)
				end
			elseif isRaster(body) then
				assets[key] = nil
				local asset = resolveRaster(key, url, body)
				if asset then
					Store.Updated:Fire(key, asset, false)
				end
			end
		end)
	end

	local function queue(key, worker, callback)
		local waiting = pending[key]
		if waiting then
			table.insert(waiting, callback)
			return
		end
		pending[key] = { callback }
		task.spawn(function()
			local result = worker()
			local list = pending[key] or {}
			pending[key] = nil
			for _, listener in list do
				task.spawn(listener, result)
			end
		end)
	end

	local complained = {}

	function Store.Complain(key, message)
		if complained[key] then
			return false
		end
		complained[key] = true
		Utility.Warn(string.format("icon %s: %s", tostring(key), message))
		return true
	end

	function Store.Raster(key, url, callback)
		key = Utility.Slug(key)
		if assets[key] then
			callback(assets[key])
			revalidate(key, url, false)
			return
		end
		if not available() then
			Store.Complain(
				key,
				"this executor has no file access or getcustomasset, so a photo from a url cannot be drawn. Use rbxassetid:// instead."
			)
			callback(nil)
			return
		end
		local data = load()
		local entry = data[key]
		if entry and entry.kind == "raster" and entry.file and Capabilities.FS.IsFile(entry.file) then
			local asset = customAsset(entry.file)
			if asset then
				assets[key] = asset
				callback(asset)
				revalidate(key, url, false)
				return
			end
		end
		queue(key, function()
			local body, reason = download(url)
			if not body then
				Store.Complain(key, string.format('could not download "%s" (%s)', url, tostring(reason)))
				return nil
			end
			if not isRaster(body) then
				Store.Complain(
					key,
					string.format('"%s" did not answer with a png or jpg. Roblox only draws those two, and some sites refuse Roblox. Upload it as a Roblox decal and use rbxassetid:// instead.', url)
				)
				return nil
			end
			return resolveRaster(key, url, body)
		end, callback)
	end

	function Store.Vector(key, url, callback)
		key = Utility.Slug(key)
		if vectors[key] then
			callback(vectors[key])
			revalidate(key, url, true)
			return
		end
		local data = load()
		local entry = data[key]
		if entry and entry.kind == "vector" and entry.spec and available() and Capabilities.FS.IsFile(entry.spec) then
			local ok, body = pcall(Capabilities.FS.Read, entry.spec)
			if ok and type(body) == "string" then
				local spec = Svg.Decode(body)
				if spec then
					vectors[key] = spec
					callback(spec)
					revalidate(key, url, true)
					return
				end
			end
		end
		queue(key, function()
			local body, reason = download(url)
			if not body then
				Store.Complain(key, string.format('could not download the svg "%s" (%s)', url, tostring(reason)))
				return nil
			end
			local spec = resolveVector(key, url, body)
			if not spec then
				Store.Complain(key, string.format('could not read the svg at "%s"', url))
			end
			return spec
		end, callback)
	end

	function Store.Local(path)
		if not available() or not Capabilities.FS.IsFile(path) then
			return nil
		end
		return customAsset(path)
	end

	function Store.Import(key, body, url)
		key = Utility.Slug(key)
		if type(body) ~= "string" then
			return nil
		end
		if isRaster(body) then
			assets[key] = nil
			return resolveRaster(key, url or "", body)
		end
		return resolveVector(key, url or "", body)
	end

	function Store.Stats()
		local data = load()
		local count, bytes = 0, 0
		for _, entry in data do
			count += 1
			bytes += entry.size or 0
		end
		return { Count = count, Bytes = bytes, Cached = count, Folder = Store.Folder, Available = available() }
	end

	return Store
end
