return function(import)
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Stats = game:GetService("Stats")
	local MarketplaceService = game:GetService("MarketplaceService")
	local Utility = import("Core/Utility")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Markup = import("Core/Markup")
	local Signal = import("Core/Signal")
	local Icons = import("Icons/Icon")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")
	local Drag = import("Services/Drag")

	local StatusBar = {}
	StatusBar.__index = StatusBar

	local ANCHORS = {
		topleft = { Vector2.new(0, 0), UDim2.fromScale(0, 0), Vector2.new(12, 12) },
		topcenter = { Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), Vector2.new(0, 12) },
		topright = { Vector2.new(1, 0), UDim2.fromScale(1, 0), Vector2.new(-12, 12) },
		middleleft = { Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), Vector2.new(12, 0) },
		middleright = { Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5), Vector2.new(-12, 0) },
		bottomleft = { Vector2.new(0, 1), UDim2.fromScale(0, 1), Vector2.new(12, -12) },
		bottomcenter = { Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), Vector2.new(0, -12) },
		bottomright = { Vector2.new(1, 1), UDim2.fromScale(1, 1), Vector2.new(-12, -12) },
		abovehotbar = { Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), Vector2.new(0, -86) },
		undertopbar = { Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), Vector2.new(0, 42) },
		center = { Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(0, 0) },
	}

	local ALIASES = {
		top = "topcenter",
		bottom = "bottomcenter",
		left = "middleleft",
		right = "middleright",
		["top-left"] = "topleft",
		["top-center"] = "topcenter",
		["top-right"] = "topright",
		["bottom-left"] = "bottomleft",
		["bottom-center"] = "bottomcenter",
		["bottom-right"] = "bottomright",
		["middle-left"] = "middleleft",
		["middle-right"] = "middleright",
		inventory = "abovehotbar",
		hotbar = "abovehotbar",
		topbar = "undertopbar",
	}

	local placeName

	local function resolveAnchor(value)
		if typeof(value) == "UDim2" then
			return nil, value, nil
		end
		local name = string.lower(tostring(value or "topcenter"))
		name = string.gsub(name, "%s+", "")
		name = ALIASES[name] or name
		local preset = ANCHORS[name] or ANCHORS.topcenter
		return preset[1], preset[2], preset[3]
	end

	function StatusBar.Anchors()
		local out = {}
		for name in ANCHORS do
			table.insert(out, name)
		end
		table.sort(out)
		return out
	end

	local BUILTIN = {
		{ key = "Fps", icon = "activity", label = "FPS" },
		{ key = "Ping", icon = "wifi", label = "Ping" },
		{ key = "Players", icon = "users", label = "Players" },
		{ key = "Memory", icon = "cpu", label = "Mem" },
		{ key = "Clock", icon = "clock", label = "Clock" },
		{ key = "Session", icon = "timer", label = "Session" },
		{ key = "Place", icon = "gamepad-2", label = "Place" },
	}

	function StatusBar.new(config)
		config = config or {}
		Utility.Check(type(config) == "table", "StatusBar", "?", "Config must be a table.")
		local self = setmetatable({}, StatusBar)
		self.Cleanup = Cleanup.new()
		self.Changed = Signal.new()
		self.Config = config
		self._fields = {}
		self._order = 0
		self._frames = 0
		self._elapsed = 0
		self._started = os.clock()
		self._destroyed = false
		self._interval = math.max(config.Interval or 0.5, 0.1)
		self._separator = config.Separator or "|"
		self._compact = config.Compact == true
		local cleanup = self.Cleanup
		cleanup:Add(self.Changed)

		local gui = cleanup:Add(Utility.NewScreenGui("DeaDx_StatusBar", config.DisplayOrder or 900))
		gui.IgnoreGuiInset = config.IgnoreInset == true
		self.Gui = gui

		local frame = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "StatusBar",
			Parent = gui,
			Fill = config.Background or "Background",
			Transparency = config.Transparency or 0.18,
			Stroke = config.Border or "Border",
			StrokeTransparency = 0.4,
			Radius = config.Radius or "Full",
			Size = UDim2.fromOffset(0, config.Height or 30),
			AutomaticSize = Enum.AutomaticSize.X,
			GroupTransparency = 1,
		})
		self.Frame = frame
		Widgets.Padding(frame, config.PaddingX or 12, 0)
		Widgets.List(frame, self._compact and 8 or 10, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local scale = Instance.new("UIScale")
		scale.Parent = frame
		Theme.BindScale(scale, cleanup)
		self._scale = scale

		local bounds = Instance.new("UISizeConstraint")
		bounds.MinSize = Vector2.new(config.MinWidth or 0, 0)
		bounds.MaxSize = Vector2.new(config.MaxWidth or 760, math.huge)
		bounds.Parent = frame

		if config.Icon then
			local holder = Utility.Create("Frame", {
				Name = "Brand",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(16, 16),
				LayoutOrder = 0,
				Parent = frame,
			})
			self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
				Size = config.IconSize or 16,
				Color = config.IconColor or config.TitleColor or "Accent",
				Cleanup = cleanup,
			}))
		end

		local title = config.Title or config.Name or config.Text
		if title and title ~= "" then
			self._order += 1
			local _, handle = Widgets.Text(cleanup, {
				Name = "Title",
				Parent = frame,
				Text = title,
				Color = config.TitleColor or "Text",
				Bold = true,
				TextSize = config.TextSize or 13,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = self._order,
			})
			self._title = handle
		end

		self._body = frame
		self:_Build()
		self:SetPosition(config.Position or "TopCenter", config.Offset)

		if config.Draggable ~= false then
			frame.Active = true
			Drag.Attach(frame, frame, cleanup, { Margin = 8 })
		end

		cleanup:Add(RunService.RenderStepped:Connect(function(delta)
			self._frames += 1
			self._elapsed += delta
			if self._elapsed >= self._interval then
				self._fps = self._frames / self._elapsed
				self._frames, self._elapsed = 0, 0
				self:Refresh()
			end
		end))

		Animation:Play(frame, { GroupTransparency = 0 }, { Duration = 0.25 })
		self:Refresh()
		return self
	end

	function StatusBar:_Separator()
		self._order += 1
		local label = Widgets.Text(self.Cleanup, {
			Name = "Separator",
			Parent = self._body,
			Text = self._separator,
			Color = "Border",
			TextSize = 12,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = self._order,
		})
		return label
	end

	function StatusBar:_Field(key, iconName, label, getter, options)
		local config = self.Config
		if self._fields[key] then
			return self._fields[key]
		end
		if #self._fields > 0 or self._title or self._icon then
			self:_Separator()
		end
		self._order += 1
		local holder = Utility.Create(options and options.Callback and "TextButton" or "Frame", {
			Name = "Field_" .. key,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = self._order,
			Parent = self._body,
		})
		if options and options.Callback then
			self.Cleanup:Add(holder.Activated:Connect(function()
				Utility.SafeCall("StatusBar field " .. key, options.Callback, self)
				Widgets.Pulse(holder, 0.84, 0.28)
				self:Refresh()
			end))
			self.Cleanup:Add(holder.MouseEnter:Connect(function()
				Widgets.Pulse(holder, 1.06, 0.24)
			end))
		end
		Widgets.List(holder, 5, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		local icon
		if config.Icons ~= false and iconName then
			local slot = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(13, 13),
				LayoutOrder = 1,
				Parent = holder,
			})
			icon = Icons.Create(slot, iconName, { Size = 13, Color = "MutedText", Cleanup = self.Cleanup })
		end
		local _, text = Widgets.Text(self.Cleanup, {
			Parent = holder,
			Text = "",
			Color = config.ValueColor or "MutedText",
			TextSize = config.TextSize and config.TextSize - 1 or 12,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		})
		local field = { Key = key, Label = label, Holder = holder, Icon = icon, Text = text, Getter = getter }
		self._fields[key] = field
		table.insert(self._fields, field)
		return field
	end

	function StatusBar:_Build()
		local config = self.Config
		for _, entry in BUILTIN do
			if config[entry.key] then
				self:_Field(entry.key, entry.icon, entry.label)
			end
		end
		for _, custom in config.Fields or {} do
			if type(custom) == "table" and custom.Key then
				self:_Field(custom.Key, custom.Icon, custom.Label, custom.Value, custom)
			end
		end
	end

	local function ping()
		local ok, value = pcall(function()
			return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok and type(value) == "number" then
			return math.floor(value + 0.5)
		end
		return nil
	end

	local function memory()
		local ok, value = pcall(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		if ok and type(value) == "number" then
			return math.floor(value + 0.5)
		end
		return nil
	end

	local function place()
		if placeName then
			return placeName
		end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		placeName = ok and type(info) == "table" and info.Name or "Unknown"
		return placeName
	end

	local function clock(format)
		return os.date(format or "%H:%M:%S")
	end

	local function duration(seconds)
		local total = math.floor(seconds)
		local hours = math.floor(total / 3600)
		local minutes = math.floor(total % 3600 / 60)
		local rest = total % 60
		if hours > 0 then
			return string.format("%d:%02d:%02d", hours, minutes, rest)
		end
		return string.format("%d:%02d", minutes, rest)
	end

	function StatusBar:_Value(field)
		local config = self.Config
		local key = field.Key
		if field.Getter then
			local ok, value = pcall(field.Getter, self)
			return ok and value ~= nil and tostring(value) or "-"
		end
		if key == "Fps" then
			return tostring(math.floor((self._fps or 0) + 0.5))
		elseif key == "Ping" then
			local value = ping()
			return value and (value .. "ms") or "-"
		elseif key == "Players" then
			return tostring(#Players:GetPlayers()) .. (config.MaxPlayers ~= false and ("/" .. tostring(Players.MaxPlayers)) or "")
		elseif key == "Memory" then
			local value = memory()
			return value and (value .. "mb") or "-"
		elseif key == "Clock" then
			return clock(config.ClockFormat)
		elseif key == "Session" then
			return duration(os.clock() - self._started)
		elseif key == "Place" then
			return place()
		end
		return field.Value or "-"
	end

	function StatusBar:Refresh()
		if self._destroyed then
			return
		end
		local compact = self._compact
		for _, field in self._fields do
			if type(field) == "table" and field.Text then
				local value = self:_Value(field)
				local prefix = (not compact and self.Config.Labels ~= false and field.Label) and (field.Label .. " ") or ""
				field.Text.SetText(prefix .. value)
			end
		end
	end

	function StatusBar:AddField(key, options)
		Utility.Check(type(key) == "string", "StatusBar field", key, "Key must be a string.")
		options = options or {}
		local field = self:_Field(key, options.Icon, options.Label, options.Value, options)
		if options.Text then
			field.Value = options.Text
		end
		self:Refresh()
		return self
	end

	function StatusBar:SetField(key, value)
		local field = self._fields[key]
		if not field then
			self:AddField(key, { Text = value })
			return self
		end
		field.Value = value
		field.Getter = nil
		self:Refresh()
		return self
	end

	function StatusBar:RemoveField(key)
		local field = self._fields[key]
		if not field then
			return self
		end
		field.Holder:Destroy()
		local index = table.find(self._fields, field)
		if index then
			table.remove(self._fields, index)
		end
		self._fields[key] = nil
		return self
	end

	function StatusBar:SetTitle(text)
		if self._title then
			self._title.SetText(text)
		end
		return self
	end

	function StatusBar:SetTitleColor(color)
		if self._title then
			self._title.SetColor(color)
		end
		return self
	end

	function StatusBar:SetIcon(spec)
		if self._icon then
			self._icon:Set(spec)
		end
		return self
	end

	function StatusBar:SetPosition(value, offset)
		local anchor, position, preset = resolveAnchor(value)
		offset = offset or preset or Vector2.zero
		if anchor then
			self.Frame.AnchorPoint = anchor
		end
		self.Frame.Position = UDim2.new(
			position.X.Scale,
			position.X.Offset + offset.X,
			position.Y.Scale,
			position.Y.Offset + offset.Y
		)
		self.Anchor = typeof(value) == "UDim2" and "custom" or string.lower(tostring(value))
		return self
	end

	function StatusBar:SetInterval(seconds)
		self._interval = math.max(tonumber(seconds) or 0.5, 0.1)
		return self
	end

	function StatusBar:SetCompact(value)
		self._compact = value == true
		self:Refresh()
		return self
	end

	function StatusBar:SetSeparator(text)
		self._separator = tostring(text)
		for _, child in self._body:GetChildren() do
			if child.Name == "Separator" then
				child.Text = Markup.Parse(self._separator)
			end
		end
		return self
	end

	function StatusBar:SetVisible(value)
		self.Frame.Visible = value == true
		return self
	end

	function StatusBar:Show()
		return self:SetVisible(true)
	end

	function StatusBar:Hide()
		return self:SetVisible(false)
	end

	function StatusBar:Toggle()
		return self:SetVisible(not self.Frame.Visible)
	end

	function StatusBar:IsVisible()
		return self.Frame.Visible
	end

	function StatusBar:GetFps()
		return self._fps or 0
	end

	function StatusBar:GetPing()
		return ping()
	end

	function StatusBar:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		Animation:CancelTree(self.Gui)
		self.Cleanup:Clean()
		table.clear(self._fields)
	end

	return StatusBar
end
