return function(import)
	local Players = game:GetService("Players")
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Picker = setmetatable({}, { __index = Component.Base })
	Picker.__index = Picker

	local ROW = 34

	local function headshot(player)
		return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", player.UserId)
	end

	function Picker:_Normalize(value)
		if value == nil then
			return true, nil
		end
		if typeof(value) == "Instance" and value:IsA("Player") then
			return true, value.Name
		end
		if type(value) == "string" then
			return true, value
		end
		return false
	end

	function Picker:GetPlayer()
		local name = self.State:Get()
		return name and Players:FindFirstChild(name) or nil
	end

	function Picker:_List()
		local out = {}
		local me = Players.LocalPlayer
		for _, player in Players:GetPlayers() do
			if player ~= me or self.Config.IncludeSelf == true then
				if not self.Config.Filter or self.Config.Filter(player) then
					table.insert(out, player)
				end
			end
		end
		table.sort(out, function(a, b)
			return a.DisplayName:lower() < b.DisplayName:lower()
		end)
		return out
	end

	function Picker:Refresh()
		local name = self.State:Get()
		if name and not Players:FindFirstChild(name) and self.Config.Clear ~= false then
			self.State:Set(nil)
		end
		self._render(self.State:Get())
		if self._rebuild then
			self._rebuild()
		end
		return self
	end

	function Picker:Close()
		if self._popup then
			self._popup.Close()
		end
		return self
	end

	function Picker:_Open()
		if self._destroyed or not self.Enabled or self._popup then
			return
		end
		local button = self._button
		local width = math.max(self.Config.PopupWidth or 210, button.AbsoluteSize.X / Theme.Scale)
		local list = self:_List()
		local function measure(count)
			return math.min(math.clamp(count, 1, 6) * ROW + 10 + 34, 300)
		end
		local popup = self.Window:OpenPopup(button, width, measure(#list))
		self._popup = popup
		local cleanup = popup.Cleanup
		Animation:Play(self._chevron.Instance, { Rotation = 180 }, { Duration = 0.18 })
		cleanup:Add(popup.Closed:Connect(function()
			if self._popup == popup then
				self._popup = nil
			end
			self._rebuild = nil
			if self._chevron.Instance.Parent then
				Animation:Play(self._chevron.Instance, { Rotation = 0 }, { Duration = 0.18 })
			end
		end))

		local filterText = ""
		local _, filterBox = Widgets.Field(cleanup, {
			Name = "Filter",
			Parent = popup.Frame,
			Radius = 8,
			Placeholder = "Search player...",
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(1, -10, 0, 24),
		})

		local scroller = Widgets.Scroller(cleanup, {
			Name = "Players",
			Parent = popup.Frame,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 1, -34),
		})
		Widgets.Padding(scroller, 5)
		Widgets.List(scroller, 2)

		local rows = cleanup:Extend()

		local function build()
			rows:Clean()
			rows = cleanup:Extend()
			local shown = 0
			for index, player in self:_List() do
				local label = player.DisplayName
				if filterText == "" or string.find(string.lower(label .. player.Name), filterText, 1, true) then
					shown += 1
					local row = Widgets.Surface(rows, {
						Class = "TextButton",
						Name = player.Name,
						Parent = scroller,
						Fill = "SecondaryBackground",
						Transparency = 1,
						Radius = 9,
						Size = UDim2.new(1, 0, 0, ROW - 2),
						LayoutOrder = index,
					})
					rows:Add(row)
					local holder = Utility.Create("Frame", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 7, 0.5, 0),
						Size = UDim2.fromOffset(22, 22),
						Parent = row,
					})
					Icons.Create(holder, headshot(player), { Size = 22, Corner = "Full", Cleanup = rows })
					Widgets.Text(rows, {
						Parent = row,
						Text = label,
						TextSize = 12,
						Bold = true,
						Position = UDim2.new(0, 36, 0, 4),
						Size = UDim2.new(1, -62, 0, 13),
						TextTruncate = Enum.TextTruncate.AtEnd,
						Markup = false,
					})
					Widgets.Text(rows, {
						Parent = row,
						Text = "@" .. player.Name,
						Color = "MutedText",
						TextSize = 11,
						Position = UDim2.new(0, 36, 0, 16),
						Size = UDim2.new(1, -62, 0, 12),
						TextTruncate = Enum.TextTruncate.AtEnd,
						Markup = false,
					})
					local check = Icons.Create(row, "check", {
						Size = 13,
						Color = "Accent",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Cleanup = rows,
					})
					check.Instance.Visible = self.State:Get() == player.Name
					Widgets.Interactive(rows, row, row, { Alpha = { 1, 0.6, 0.45 } })
					rows:Add(row.Activated:Connect(function()
						self.State:Set(player.Name)
						popup.Close()
					end))
				end
			end
			if shown == 0 then
				rows:Add((Widgets.Text(rows, {
					Parent = scroller,
					Text = "No players",
					Color = "MutedText",
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, ROW),
				})))
				shown = 1
			end
			popup.Resize(measure(shown))
		end
		self._rebuild = build
		build()

		cleanup:Add(filterBox:GetPropertyChangedSignal("Text"):Connect(function()
			filterText = string.lower(filterBox.Text)
			build()
		end))
	end

	return function(ctx, id, config)
		local self = Component.New(ctx, Picker, "Player", id, config, {
			RightWidth = config.Width or 176,
			RightHeight = 26,
		})
		local cleanup = self.Cleanup
		self.Picked = Signal.new()
		cleanup:Add(self.Picked)

		local button = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "Select",
			Parent = self.Right,
			Fill = "TertiaryBackground",
			Transparency = "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.45,
			Radius = 10,
			Size = UDim2.fromScale(1, 1),
		})
		self._button = button

		local avatarHolder = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Visible = false,
			Parent = button,
		})
		self._avatar = Icons.Create(avatarHolder, nil, { Size = 18, Corner = "Full", Cleanup = cleanup })

		local _, label = Widgets.Text(cleanup, {
			Parent = button,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -32, 1, 0),
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Markup = false,
		})
		self._label = label
		self._chevron = Icons.Create(button, "chevron-down", {
			Size = 13,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Cleanup = cleanup,
		})
		Widgets.Interactive(cleanup, button, button, { Base = "TertiaryBackground" })

		self._render = function(value)
			local player = value and Players:FindFirstChild(value)
			if player then
				self._avatar:Set(headshot(player))
				avatarHolder.Visible = true
				label.Instance.Position = UDim2.fromOffset(28, 0)
				label.Instance.Size = UDim2.new(1, -50, 1, 0)
				label.SetText(player.DisplayName)
			else
				avatarHolder.Visible = false
				label.Instance.Position = UDim2.fromOffset(10, 0)
				label.Instance.Size = UDim2.new(1, -32, 1, 0)
				label.SetText(config.Placeholder or "Select player")
			end
		end

		Component.BindValue(self, id, config.Default, function(value)
			self._render(value)
			self.Picked:Fire(value and Players:FindFirstChild(value) or nil)
		end)

		cleanup:Add(button.Activated:Connect(function()
			if self._popup then
				self:Close()
				return
			end
			self:_Open()
		end))
		cleanup:Add(Players.PlayerAdded:Connect(function()
			if self._rebuild then
				self._rebuild()
			end
		end))
		cleanup:Add(Players.PlayerRemoving:Connect(function(player)
			task.defer(function()
				if not self._destroyed then
					if self.State:Get() == player.Name and config.Clear ~= false then
						self.State:Set(nil)
					end
					if self._rebuild then
						self._rebuild()
					end
				end
			end)
		end))
		cleanup:Add(function()
			if self._popup then
				self._popup.Close()
			end
		end)
		return self
	end
end
