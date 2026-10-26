return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Icons = import("Icons/Icon")
	local InputService = import("Services/Input")
	local Notification = import("Services/Notification")

	local Keybind = setmetatable({}, { __index = Component.Base })
	Keybind.__index = Keybind

	local MOUSE = {
		[Enum.UserInputType.MouseButton1] = "Mouse 1",
		[Enum.UserInputType.MouseButton2] = "Mouse 2",
		[Enum.UserInputType.MouseButton3] = "Mouse 3",
	}

	local MODES = { "Press", "Toggle", "Hold", "Always" }

	local function display(key)
		if typeof(key) ~= "EnumItem" or key == Enum.KeyCode.Unknown then
			return "None"
		end
		return MOUSE[key] or key.Name
	end

	local function parse(value)
		if typeof(value) == "EnumItem" then
			if value.EnumType == Enum.KeyCode or value.EnumType == Enum.UserInputType then
				return true, value
			end
			return false
		end
		if value == nil or value == "None" then
			return true, Enum.KeyCode.Unknown
		end
		if type(value) == "string" then
			local ok, item = pcall(function()
				return Enum.KeyCode[value]
			end)
			if ok and item then
				return true, item
			end
		end
		return false
	end

	function Keybind:_Normalize(value)
		return parse(value)
	end

	function Keybind:_Emit(value)
		if self._destroyed then
			return
		end
		Utility.SafeCall("Keybind " .. tostring(self.Id), self.Config.ChangedCallback, value)
		self.Changed:Fire(value)
	end

	function Keybind:OnClick(callback)
		return self.Clicked:Connect(callback)
	end

	function Keybind:GetState()
		if self.Mode == "Always" then
			return true
		end
		return self.Toggled == true
	end

	function Keybind:SetMode(mode)
		if not table.find(MODES, mode) then
			return self
		end
		local changed = self.Mode ~= mode
		self.Mode = mode
		if mode == "Always" then
			self.Toggled = true
		elseif mode ~= "Toggle" then
			self.Toggled = false
		end
		if self._modeLabel then
			self._modeLabel.SetText(mode)
			self._modeLabel.Instance.Visible = mode ~= "Press"
			if changed then
				Widgets.Pulse(self._modeLabel.Instance, 0.8, 0.3)
			end
		end
		Utility.SafeCall("Keybind " .. tostring(self.Id), self.Config.ModeCallback, mode)
		return self
	end

	function Keybind:Reset()
		self.State:Set(self._default)
		return self
	end

	return function(ctx, id, config)
		local valid, default = parse(config.Default)
		Utility.Check(valid, "Keybind", id, "Default must be an Enum.KeyCode, a mouse UserInputType or a key name.")
		local self = Component.New(ctx, Keybind, "Keybind", id, config, { RightWidth = 132, RightHeight = 26 })
		local cleanup = self.Cleanup
		self._default = default
		self.Mode = table.find(MODES, config.Mode or "") and config.Mode or "Press"
		self.Toggled = self.Mode == "Always"
		self.Clicked = Signal.new()
		cleanup:Add(self.Clicked)

		local modeHolder = Utility.Create("Frame", {
			Name = "Mode",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(52, 26),
			Parent = self.Right,
		})
		local _, modeLabel = Widgets.Text(cleanup, {
			Parent = modeHolder,
			Text = self.Mode,
			Color = "MutedText",
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(1, 1),
			Visible = self.Mode ~= "Press",
		})
		self._modeLabel = modeLabel

		local button = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "Key",
			Parent = self.Right,
			Fill = "TertiaryBackground",
			Transparency = "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.45,
			Radius = 10,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(74, 26),
		})
		local _, label = Widgets.Text(cleanup, {
			Parent = button,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Markup = false,
		})
		Widgets.Interactive(cleanup, button, button, { Base = "TertiaryBackground" })
		self._button, self._label = button, label

		local buttonStroke = button:FindFirstChildOfClass("UIStroke")
		Component.BindValue(self, id, default, function(value, animate)
			label.SetText(display(value))
			if self._bind then
				self._bind:SetKey(value)
			end
			if animate then
				Widgets.Pulse(button, 0.86, 0.3)
				Widgets.Glow(buttonStroke, "Accent", 0.4)
			end
		end)

		local function trigger(key)
			if not self.Enabled or self._destroyed then
				return
			end
			if self.Mode == "Toggle" then
				self.Toggled = not self.Toggled
				Utility.SafeCall("Keybind " .. tostring(self.Id), config.Callback, self.Toggled)
			elseif self.Mode == "Hold" or self.Mode == "Always" then
				Utility.SafeCall("Keybind " .. tostring(self.Id), config.Callback, true)
			else
				Utility.SafeCall("Keybind " .. tostring(self.Id), config.Callback, key)
			end
			self.Clicked:Fire(key)
		end

		self._bind = cleanup:Add(InputService.AddBind(
			self.State:Get(),
			trigger,
			"Keybind " .. tostring(config.Title or id or "?")
		))

		if self.Mode == "Hold" then
			cleanup:Add(InputService.Ended:Connect(function(input)
				local key = self.State:Get()
				if typeof(key) ~= "EnumItem" or not self.Enabled then
					return
				end
				local matched = key.EnumType == Enum.KeyCode and input.KeyCode == key or input.UserInputType == key
				if matched and self.Toggled then
					self.Toggled = false
					Utility.SafeCall("Keybind " .. tostring(self.Id), config.Callback, false)
				end
			end))
			cleanup:Add(self.Clicked:Connect(function()
				self.Toggled = true
			end))
		end

		cleanup:Add(button.Activated:Connect(function()
			if self._capturing or not self.Enabled then
				return
			end
			self._capturing = true
			label.SetText("...")
			Widgets.Pulse(button, 0.9, 0.25)
			Widgets.Glow(buttonStroke, "Accent", 6)
			self._cancel = InputService.Capture(function(key, cancelled)
				self._capturing, self._cancel = false, nil
				if self._destroyed then
					return
				end
				if not cancelled then
					local conflict = InputService.FindConflict(key, self._bind)
					if conflict then
						Notification.Notify({
							Type = "Warning",
							Title = "Keybind conflict",
							Content = string.format('%s is also used by "%s".', display(key), conflict.Label),
						})
					end
					self.State:Set(key)
				end
				label.SetText(display(self.State:Get()))
			end)
		end))

		cleanup:Add(button.MouseButton2Click:Connect(function()
			if self._capturing or not self.Enabled then
				return
			end
			local popup = self.Window:OpenPopup(button, 120, #MODES * 26 + 36)
			local pcl = popup.Cleanup
			Widgets.Padding(popup.Frame, 5)
			Widgets.List(popup.Frame, 2)
			for index, mode in MODES do
				local row = Widgets.Surface(pcl, {
					Class = "TextButton",
					Parent = popup.Frame,
					Fill = "SecondaryBackground",
					Transparency = 1,
					Radius = 8,
					Size = UDim2.new(1, 0, 0, 24),
					LayoutOrder = index,
				})
				Widgets.Text(pcl, {
					Parent = row,
					Text = mode,
					TextSize = 12,
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, -28, 1, 0),
				})
				local check = Icons.Create(row, "check", {
					Size = 13,
					Color = "Accent",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Cleanup = pcl,
				})
				check.Instance.Visible = self.Mode == mode
				Widgets.Interactive(pcl, row, row, { Alpha = { 1, 0.6, 0.45 } })
				pcl:Add(row.Activated:Connect(function()
					self:SetMode(mode)
					popup.Close()
				end))
			end
			local reset = Widgets.Surface(pcl, {
				Class = "TextButton",
				Parent = popup.Frame,
				Fill = "TertiaryBackground",
				Radius = 8,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = #MODES + 1,
			})
			Widgets.Text(pcl, {
				Parent = reset,
				Text = "Reset key",
				Color = "MutedText",
				TextSize = 12,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
			})
			Widgets.Interactive(pcl, reset, reset, { Base = "TertiaryBackground" })
			pcl:Add(reset.Activated:Connect(function()
				self:Reset()
				popup.Close()
			end))
		end))

		cleanup:Add(function()
			if self._cancel then
				self._cancel()
			end
		end)
		return self
	end
end
