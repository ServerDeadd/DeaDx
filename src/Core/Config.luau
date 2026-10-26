return function(import)
	local HttpService = game:GetService("HttpService")
	local State = import("Core/State")
	local Signal = import("Core/Signal")
	local Utility = import("Core/Utility")
	local Capabilities = import("Core/Capabilities")

	local Config = {
		Folder = "DeaDx/configs",
		Changed = Signal.new(),
		AutoSave = false,
		AutoSaveName = "autosave",
		History = 120,
		_states = {},
		_defaults = {},
		_connections = {},
		_previous = {},
		_history = {},
		_cursor = 0,
		_silent = false,
		_queued = false,
	}

	local function queueAutoSave()
		if not Config.AutoSave or Config._queued then
			return
		end
		Config._queued = true
		task.delay(0.5, function()
			Config._queued = false
			if Config.AutoSave then
				pcall(function()
					Config:Save(Config.AutoSaveName)
				end)
			end
		end)
	end

	function Config:_Record(key, value)
		local old = self._previous[key]
		self._previous[key] = Utility.DeepCopy(value)
		if self._silent or self.History <= 0 then
			return
		end
		for index = #self._history, self._cursor + 1, -1 do
			table.remove(self._history, index)
		end
		table.insert(self._history, { Key = key, Old = old, New = Utility.DeepCopy(value) })
		while #self._history > self.History do
			table.remove(self._history, 1)
		end
		self._cursor = #self._history
	end

	function Config:Register(key, default)
		local state = self._states[key]
		if not state then
			state = State.new(default)
			self._states[key] = state
			self._previous[key] = Utility.DeepCopy(default)
			self._connections[key] = state.Changed:Connect(function(value)
				self:_Record(key, value)
				self.Changed:Fire(key, value)
				queueAutoSave()
			end)
		end
		if self._defaults[key] == nil then
			self._defaults[key] = Utility.DeepCopy(default)
		end
		return state
	end

	function Config:_Apply(key, value)
		local state = self._states[key]
		if not state then
			return false
		end
		self._silent = true
		state:Set(Utility.DeepCopy(value))
		self._silent = false
		return true
	end

	function Config:CanUndo()
		return self._cursor > 0
	end

	function Config:CanRedo()
		return self._cursor < #self._history
	end

	function Config:Undo()
		if self._cursor <= 0 then
			return false
		end
		local entry = self._history[self._cursor]
		self._cursor -= 1
		if not entry then
			return false
		end
		self:_Apply(entry.Key, entry.Old)
		return true, entry.Key
	end

	function Config:Redo()
		if self._cursor >= #self._history then
			return false
		end
		self._cursor += 1
		local entry = self._history[self._cursor]
		if not entry then
			return false
		end
		self:_Apply(entry.Key, entry.New)
		return true, entry.Key
	end

	function Config:ClearHistory()
		table.clear(self._history)
		self._cursor = 0
		return self
	end

	function Config:Set(key, value)
		assert(type(key) == "string", "[DEADX] Config key must be a string")
		local state = self._states[key]
		if not state then
			state = self:Register(key, nil)
		end
		state:Set(value)
	end

	function Config:Get(key)
		local state = self._states[key]
		return state and state:Get()
	end

	function Config:Has(key)
		return self._states[key] ~= nil
	end

	function Config:Keys()
		local out = {}
		for key in self._states do
			table.insert(out, key)
		end
		table.sort(out)
		return out
	end

	function Config:Export()
		local out = {}
		for key, state in self._states do
			out[key] = Utility.DeepCopy(state:Get())
		end
		return out
	end

	function Config:Import(data)
		assert(type(data) == "table", "[DEADX] Config:Import expects a table")
		for key, value in data do
			self:Set(key, Utility.DeepCopy(value))
		end
	end

	function Config:Reset()
		for key, state in self._states do
			state:Set(Utility.DeepCopy(self._defaults[key]))
		end
	end

	function Config:Wipe()
		for _, connection in self._connections do
			connection:Disconnect()
		end
		table.clear(self._connections)
		for _, state in self._states do
			state:Destroy()
		end
		table.clear(self._states)
		table.clear(self._defaults)
	end

	local function encode(value)
		local kind = typeof(value)
		if kind == "Color3" then
			return { __t = "Color3", R = value.R, G = value.G, B = value.B }
		elseif kind == "EnumItem" then
			return { __t = "Enum", Type = tostring(value.EnumType), Name = value.Name }
		elseif kind == "Vector2" then
			return { __t = "Vector2", X = value.X, Y = value.Y }
		elseif kind == "table" then
			local out = {}
			for k, v in value do
				out[k] = encode(v)
			end
			return out
		end
		return value
	end

	local function decode(value)
		if type(value) ~= "table" then
			return value
		end
		if value.__t == "Color3" then
			return Color3.new(value.R, value.G, value.B)
		elseif value.__t == "Enum" then
			local ok, item = pcall(function()
				return Enum[value.Type][value.Name]
			end)
			return ok and item or nil
		elseif value.__t == "Vector2" then
			return Vector2.new(value.X, value.Y)
		end
		local out = {}
		for k, v in value do
			out[k] = decode(v)
		end
		return out
	end

	function Config:Serialize()
		return HttpService:JSONEncode(encode(self:Export()))
	end

	function Config:Deserialize(json)
		local ok, data = pcall(function()
			return decode(HttpService:JSONDecode(json))
		end)
		if not ok then
			return false, "invalid JSON"
		end
		self:Import(data)
		return true
	end

	function Config:Save(name)
		if not Capabilities.FileSystem then
			return false, "FileSystem capability unavailable"
		end
		name = tostring(name or self.AutoSaveName)
		local ok, err = pcall(function()
			Capabilities.EnsureFolder(self.Folder)
			Capabilities.FS.Write(self.Folder .. "/" .. name .. ".json", self:Serialize())
		end)
		return ok, not ok and tostring(err) or nil
	end

	function Config:Load(name)
		if not Capabilities.FileSystem then
			return false, "FileSystem capability unavailable"
		end
		name = tostring(name or self.AutoSaveName)
		local path = self.Folder .. "/" .. name .. ".json"
		if not Capabilities.FS.IsFile(path) then
			return false, "file not found"
		end
		local ok, content = pcall(Capabilities.FS.Read, path)
		if not ok then
			return false, tostring(content)
		end
		return self:Deserialize(content)
	end

	function Config:Delete(name)
		if not Capabilities.FileSystem or not Capabilities.FS.Delete then
			return false, "FileSystem capability unavailable"
		end
		local path = self.Folder .. "/" .. tostring(name) .. ".json"
		if not Capabilities.FS.IsFile(path) then
			return false, "file not found"
		end
		return pcall(Capabilities.FS.Delete, path)
	end

	function Config:List()
		if not Capabilities.FileSystem or not Capabilities.FS.List then
			return {}
		end
		Capabilities.EnsureFolder(self.Folder)
		local ok, files = pcall(Capabilities.FS.List, self.Folder)
		if not ok or type(files) ~= "table" then
			return {}
		end
		local out = {}
		for _, path in files do
			local name = string.match(tostring(path), "([^/\\]+)%.json$")
			if name then
				table.insert(out, name)
			end
		end
		table.sort(out)
		return out
	end

	function Config:SetAutoSave(enabled, name)
		self.AutoSave = enabled == true
		if name then
			self.AutoSaveName = tostring(name)
		end
		if self.AutoSave then
			queueAutoSave()
		end
		return self.AutoSave
	end

	return Config
end
