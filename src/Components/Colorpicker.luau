return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local State = import("Core/State")
	local Config = import("Core/Config")
	local Capabilities = import("Core/Capabilities")
	local Icons = import("Icons/Icon")
	local Drag = import("Services/Drag")
	local Animation = import("Services/Animation")

	local Colorpicker = setmetatable({}, { __index = Component.Base })
	Colorpicker.__index = Colorpicker

	local SWATCH_KEY = "DeaDx/Swatches"
	local DEFAULT_SWATCHES = { "#FF2D40", "#FB923C", "#FACC15", "#4ADE80", "#38BDF8", "#A855F7", "#FFFFFF" }

	local function to255(value)
		return math.floor(value * 255 + 0.5)
	end

	local function sameColor(a, b)
		return to255(a.R) == to255(b.R) and to255(a.G) == to255(b.G) and to255(a.B) == to255(b.B)
	end

	local function swatches()
		local state = Config:Register(SWATCH_KEY, table.clone(DEFAULT_SWATCHES))
		local value = state:Get()
		if type(value) ~= "table" then
			value = table.clone(DEFAULT_SWATCHES)
			state:Set(value)
		end
		return state, value
	end

	function Colorpicker:_Normalize(value)
		if typeof(value) == "Color3" then
			return true, value
		end
		if type(value) == "string" then
			local color = Utility.FromHex(value)
			if color then
				return true, color
			end
		end
		return false
	end

	function Colorpicker:_Emit(value)
		if self._destroyed then
			return
		end
		local transparency = self.TransparencyState:Get()
		Utility.SafeCall("Colorpicker " .. tostring(self.Id), self.Config.Callback, value, transparency)
		self.Changed:Fire(value, transparency)
	end

	function Colorpicker:GetTransparency()
		return self.TransparencyState:Get()
	end

	function Colorpicker:SetTransparency(value)
		if type(value) == "number" then
			self.TransparencyState:Set(math.clamp(value, 0, 1))
		end
		return self
	end

	function Colorpicker:SetValueRGB(color, transparency)
		self:SetValue(color)
		if transparency ~= nil then
			self:SetTransparency(transparency)
		end
		return self
	end

	function Colorpicker:GetHex()
		return Utility.ToHex(self.State:Get())
	end

	function Colorpicker:Copy()
		return Capabilities.SetClipboard(self:GetHex())
	end

	function Colorpicker:Paste()
		return false
	end

	function Colorpicker:Reset()
		self:SetRainbow(false)
		self.State:Set(self._default)
		if self._hasAlpha then
			self.TransparencyState:Set(self._defaultAlpha)
		end
		return self
	end

	function Colorpicker:IsRainbow()
		return self._rainbow == true
	end

	function Colorpicker:SetRainbow(enabled, speed)
		enabled = enabled == true
		if self._rainbowThread then
			pcall(task.cancel, self._rainbowThread)
			self._rainbowThread = nil
		end
		self._rainbow = enabled
		self._rainbowSpeed = speed or self._rainbowSpeed or 0.22
		if self._rainbowButton then
			self._rainbowButton()
		end
		if not enabled then
			return self
		end
		self._rainbowThread = task.spawn(function()
			while self._rainbow and not self._destroyed do
				local hue = (os.clock() * self._rainbowSpeed) % 1
				self._h = hue
				local saturation = self._s > 0.15 and self._s or 1
				local brightness = self._v > 0.15 and self._v or 1
				self.State:Set(Color3.fromHSV(hue, saturation, brightness))
				task.wait(0.05)
			end
		end)
		self.Cleanup:Add(self._rainbowThread)
		return self
	end

	function Colorpicker:Save()
		local state, list = swatches()
		local hex = self:GetHex()
		if not table.find(list, hex) then
			local copy = table.clone(list)
			table.insert(copy, 1, hex)
			while #copy > 18 do
				table.remove(copy)
			end
			state:Set(copy)
		end
		return self
	end

	function Colorpicker:Harmonies()
		local h, s, v = self._h, self._s, self._v
		return {
			{ Name = "Comp", Color = Color3.fromHSV((h + 0.5) % 1, s, v) },
			{ Name = "Tri A", Color = Color3.fromHSV((h + 1 / 3) % 1, s, v) },
			{ Name = "Tri B", Color = Color3.fromHSV((h + 2 / 3) % 1, s, v) },
			{ Name = "Ana A", Color = Color3.fromHSV((h + 0.083) % 1, s, v) },
			{ Name = "Ana B", Color = Color3.fromHSV((h - 0.083) % 1, s, v) },
			{ Name = "Shade", Color = Color3.fromHSV(h, s, math.clamp(v * 0.6, 0, 1)) },
			{ Name = "Tint", Color = Color3.fromHSV(h, math.clamp(s * 0.5, 0, 1), math.clamp(v * 1.2, 0, 1)) },
		}
	end

	local HUES = {}
	for step = 0, 6 do
		table.insert(HUES, ColorSequenceKeypoint.new(step / 6, Color3.fromHSV(math.min(step / 6, 1), 1, 1)))
	end

	return function(ctx, id, config)
		local default = config.Default or Color3.new(1, 1, 1)
		if type(default) == "string" then
			default = Utility.FromHex(default) or Color3.new(1, 1, 1)
		end
		Utility.Check(typeof(default) == "Color3", "Colorpicker", id, "Default must be a Color3 or a hex string.")
		local hasAlpha = config.Transparency ~= nil
		Utility.Check(
			not hasAlpha or (type(config.Transparency) == "number" and config.Transparency >= 0 and config.Transparency <= 1),
			"Colorpicker",
			id,
			"Transparency must be a number between 0 and 1."
		)

		local self = Component.New(ctx, Colorpicker, "Colorpicker", id, config, { RightWidth = 56, RightHeight = 22 })
		local cleanup = self.Cleanup
		self._default, self._hasAlpha, self._defaultAlpha = default, hasAlpha, config.Transparency or 0

		if id then
			self.TransparencyState = Config:Register(id .. "/Transparency", self._defaultAlpha)
		else
			self.TransparencyState = cleanup:Add(State.new(self._defaultAlpha))
		end
		self._h, self._s, self._v = default:ToHSV()

		local swatch = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "Swatch",
			Parent = self.Right,
			Stroke = "Border",
			StrokeTransparency = 0.3,
			Radius = 9,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(44, 22),
		})
		self._swatch = swatch

		local rainbowDot = Icons.Create(self.Right, "sparkles", {
			Size = 13,
			Color = "Accent",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Cleanup = cleanup,
		})
		rainbowDot.Instance.Visible = false

		local function paintSwatch()
			swatch.BackgroundColor3 = self.State:Get()
			swatch.BackgroundTransparency = hasAlpha and self.TransparencyState:Get() or 0
			rainbowDot.Instance.Visible = self._rainbow == true
		end
		Component.BindValue(self, id, default, function(color)
			if not sameColor(color, Color3.fromHSV(self._h, self._s, self._v)) then
				self._h, self._s, self._v = color:ToHSV()
			end
			paintSwatch()
		end)
		cleanup:Add(self.TransparencyState.Changed:Connect(function()
			if self._destroyed then
				return
			end
			paintSwatch()
			self:_Emit(self.State:Get())
		end))

		cleanup:Add(swatch.Activated:Connect(function()
			if self._destroyed or not self.Enabled or self:IsLocked() then
				return
			end
			local rows = 0
			if config.Swatches ~= false then
				rows += 26
			end
			if config.Harmony ~= false then
				rows += 26
			end
			local height = 150 + (hasAlpha and 20 or 0) + rows + 92
			local popup = self.Window:OpenPopup(swatch, 236, height)
			self._popup = popup
			local pcl, frame = popup.Cleanup, popup.Frame
			pcl:Add(popup.Closed:Connect(function()
				if self._popup == popup then
					self._popup = nil
				end
				self._rainbowButton = nil
			end))

			local hexBox, rBox, gBox, bBox, hBox, sBox, vBox
			local svBase, svCursor, hueCursor, alphaBar, alphaCursor
			local swatchRow, harmonyRow

			local function refresh()
				local color = self.State:Get()
				svBase.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
				svCursor.Position = UDim2.fromScale(self._s, 1 - self._v)
				svCursor.BackgroundColor3 = color
				hueCursor.Position = UDim2.fromScale(self._h, 0.5)
				if hasAlpha then
					alphaBar.BackgroundColor3 = color
					alphaCursor.Position = UDim2.fromScale(self.TransparencyState:Get(), 0.5)
				end
				local function put(box, text)
					if not box:IsFocused() then
						box.Text = text
					end
				end
				put(hexBox, Utility.ToHex(color))
				put(rBox, tostring(to255(color.R)))
				put(gBox, tostring(to255(color.G)))
				put(bBox, tostring(to255(color.B)))
				put(hBox, tostring(math.floor(self._h * 360 + 0.5)))
				put(sBox, tostring(math.floor(self._s * 100 + 0.5)))
				put(vBox, tostring(math.floor(self._v * 100 + 0.5)))
			end

			local function apply()
				self.State:Set(Color3.fromHSV(self._h, self._s, self._v))
				refresh()
			end

			local function bar(y)
				local strip = Widgets.Surface(pcl, {
					Parent = frame,
					BackgroundTransparency = 0,
					BackgroundColor3 = Color3.new(1, 1, 1),
					Radius = 5,
					Position = UDim2.fromOffset(12, y),
					Size = UDim2.fromOffset(212, 12),
				})
				local hit = Utility.Create("TextButton", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
					Parent = strip,
				})
				local cursor = Widgets.Surface(pcl, {
					Parent = strip,
					Fill = "Text",
					Stroke = "Background",
					Radius = 3,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(4, 18),
					ZIndex = 4,
				})
				return strip, hit, cursor
			end

			svBase = Widgets.Surface(pcl, {
				Parent = frame,
				BackgroundTransparency = 0,
				Radius = 8,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(212, 112),
			})
			local white = Utility.Create("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromScale(1, 1),
				Parent = svBase,
			})
			Utility.Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
			local black = Utility.Create("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				Size = UDim2.fromScale(1, 1),
				Parent = svBase,
			})
			Utility.Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
			local svHit = Utility.Create("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
				Parent = svBase,
			})
			svCursor = Widgets.Surface(pcl, {
				Parent = svBase,
				Stroke = "Text",
				Radius = "Full",
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(12, 12),
				ZIndex = 4,
			})
			Drag.Track(svHit, pcl, function(position)
				self:SetRainbow(false)
				self._s = math.clamp((position.X - svBase.AbsolutePosition.X) / math.max(svBase.AbsoluteSize.X, 1), 0, 1)
				self._v = 1 - math.clamp((position.Y - svBase.AbsolutePosition.Y) / math.max(svBase.AbsoluteSize.Y, 1), 0, 1)
				apply()
			end)

			local hueBar, hueHit
			hueBar, hueHit, hueCursor = bar(132)
			Utility.Create("UIGradient", { Color = ColorSequence.new(HUES), Parent = hueBar })
			Drag.Track(hueHit, pcl, function(position)
				self:SetRainbow(false)
				self._h = math.clamp((position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
				apply()
			end)

			local cursorY = 152
			if hasAlpha then
				local alphaHit
				alphaBar, alphaHit, alphaCursor = bar(152)
				Utility.Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = alphaBar })
				Drag.Track(alphaHit, pcl, function(position)
					local alpha = math.clamp(
						(position.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1),
						0,
						1
					)
					self.TransparencyState:Set(Utility.Round(alpha, 2))
				end)
				cursorY = 172
			end

			local function dot(parent, color, order, onPick, onDrop)
				local item = Widgets.Surface(pcl, {
					Class = "TextButton",
					Parent = parent,
					Stroke = "Border",
					StrokeTransparency = 0.4,
					Radius = "Full",
					BackgroundTransparency = 0,
					BackgroundColor3 = color,
					Size = UDim2.fromOffset(18, 18),
					LayoutOrder = order,
				})
				pcl:Add(item.Activated:Connect(function()
					Widgets.Pulse(item, 0.7, 0.3)
					onPick()
				end))
				if onDrop then
					pcl:Add(item.MouseButton2Click:Connect(onDrop))
				end
				return item
			end

			if config.Swatches ~= false then
				local header = Utility.Create("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(12, cursorY),
					Size = UDim2.fromOffset(212, 18),
					Parent = frame,
				})
				Widgets.List(header, 4, {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				})
				swatchRow = header

				local save = Widgets.Chip(pcl, {
					Parent = header,
					Radius = "Full",
					Fill = "Accent",
					Transparency = 0,
					Size = UDim2.fromOffset(18, 18),
					LayoutOrder = 0,
				})
				Icons.Create(save, "plus", {
					Size = 11,
					Color = "AccentText",
					Position = UDim2.fromOffset(3.5, 3.5),
					Cleanup = pcl,
				})
				pcl:Add(save.Activated:Connect(function()
					self:Save()
					Widgets.Pulse(save, 0.7, 0.3)
				end))

				local state = swatches()
				local list = pcl:Extend()
				local function rebuild()
					list:Clean()
					list = pcl:Extend()
					for index, hex in state:Get() do
						local color = Utility.FromHex(hex)
						if color then
							local item = dot(header, color, index, function()
								self:SetRainbow(false)
								self.State:Set(color)
								self._h, self._s, self._v = color:ToHSV()
								refresh()
							end, function()
								local copy = table.clone(state:Get())
								local at = table.find(copy, hex)
								if at then
									table.remove(copy, at)
									state:Set(copy)
								end
							end)
							list:Add(item)
						end
					end
				end
				pcl:Add(state.Changed:Connect(rebuild))
				rebuild()
				cursorY += 26
			end

			if config.Harmony ~= false then
				local row = Utility.Create("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(12, cursorY),
					Size = UDim2.fromOffset(212, 18),
					Parent = frame,
				})
				Widgets.List(row, 4, {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				})
				harmonyRow = row

				local items = {}
				local function rebuild()
					for _, item in items do
						item:Destroy()
					end
					table.clear(items)
					for index, entry in self:Harmonies() do
						local item = dot(row, entry.Color, index, function()
							self:SetRainbow(false)
							self.State:Set(entry.Color)
							self._h, self._s, self._v = entry.Color:ToHSV()
							refresh()
						end)
						table.insert(items, item)
					end
				end
				rebuild()
				pcl:Add(self.State.Changed:Connect(function()
					if harmonyRow.Parent then
						rebuild()
					end
				end))
				cursorY += 26
			end

			local function field(x, y, width, name, commit)
				Widgets.Text(pcl, {
					Parent = frame,
					Text = name,
					Color = "MutedText",
					TextSize = 10,
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(width, 11),
				})
				local _, box = Widgets.Field(pcl, {
					Parent = frame,
					Radius = 6,
					Position = UDim2.fromOffset(x, y + 12),
					Size = UDim2.fromOffset(width, 21),
					Inset = 2,
					Trail = 2,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				pcl:Add(box.FocusLost:Connect(function()
					commit(box.Text)
					refresh()
				end))
				return box
			end

			local function setRGB(r, g, b)
				self:SetRainbow(false)
				self.State:Set(Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255)))
			end
			local function channel(index)
				return function(text)
					local number = tonumber(text)
					if number then
						local color = self.State:Get()
						local values = { to255(color.R), to255(color.G), to255(color.B) }
						values[index] = number
						setRGB(values[1], values[2], values[3])
					end
				end
			end
			local function hsv(key, scale)
				return function(text)
					local number = tonumber(text)
					if number then
						self:SetRainbow(false)
						self[key] = math.clamp(number / scale, 0, 1)
						self.State:Set(Color3.fromHSV(self._h, self._s, self._v))
					end
				end
			end

			hexBox = field(12, cursorY, 70, "HEX", function(text)
				local color = Utility.FromHex(text)
				if color then
					self:SetRainbow(false)
					self.State:Set(color)
				end
			end)
			rBox = field(88, cursorY, 40, "R", channel(1))
			gBox = field(134, cursorY, 40, "G", channel(2))
			bBox = field(180, cursorY, 44, "B", channel(3))
			hBox = field(12, cursorY + 38, 66, "H", hsv("_h", 360))
			sBox = field(84, cursorY + 38, 66, "S", hsv("_s", 100))
			vBox = field(156, cursorY + 38, 68, "V", hsv("_v", 100))

			local buttonsY = cursorY + 78
			local function button(x, width, iconName, text, callback)
				local control = Widgets.Surface(pcl, {
					Class = "TextButton",
					Parent = frame,
					Fill = "TertiaryBackground",
					Stroke = "Border",
					StrokeTransparency = 0.4,
					Radius = 9,
					Position = UDim2.fromOffset(x, buttonsY),
					Size = UDim2.fromOffset(width, 24),
				})
				local icon = Icons.Create(control, iconName, {
					Size = 12,
					Position = UDim2.fromOffset(9, 6),
					Cleanup = pcl,
				})
				local _, label = Widgets.Text(pcl, {
					Parent = control,
					Text = text,
					TextSize = 11,
					Bold = true,
					Position = UDim2.fromOffset(25, 0),
					Size = UDim2.new(1, -29, 1, 0),
					Markup = false,
				})
				Widgets.Interactive(pcl, control, control, { Base = "TertiaryBackground" })
				pcl:Add(control.Activated:Connect(function()
					callback(control, icon, label)
				end))
				return control, icon, label
			end

			local copyable = Capabilities.Clipboard
			local rainbowWidth = copyable and 90 or 136
			local rainbow, rainbowIcon, rainbowLabel = button(12, rainbowWidth, "sparkles", "Rainbow", function()
				self:SetRainbow(not self._rainbow)
			end)
			self._rainbowButton = function()
				if not rainbow.Parent then
					return
				end
				local on = self._rainbow == true
				rainbowIcon:SetColor(on and "Accent" or "MutedText")
				rainbowLabel.SetColor(on and "Accent" or "Text")
				Animation:Play(rainbow, {
					BackgroundColor3 = Theme.Get(on and "Hover" or "TertiaryBackground"),
				}, { Duration = 0.15 })
				if on then
					Widgets.Pulse(rainbow, 0.9, 0.3)
				end
			end
			self._rainbowButton()

			button(12 + rainbowWidth + 6, 76, "rotate-ccw", "Reset", function()
				self:Reset()
				refresh()
			end)
			if copyable then
				button(12 + rainbowWidth + 88, 46, "copy", "", function()
					self:Copy()
				end)
			end

			popup.Resize(buttonsY + 36)
			pcl:Add(self.State.Changed:Connect(refresh))
			pcl:Add(self.TransparencyState.Changed:Connect(refresh))
			refresh()
		end))

		cleanup:Add(function()
			if self._popup then
				self._popup.Close()
			end
			if self._rainbowThread then
				pcall(task.cancel, self._rainbowThread)
			end
		end)

		if config.Rainbow then
			self:SetRainbow(true, config.RainbowSpeed)
		end
		return self
	end
end
