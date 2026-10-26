return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Segmented = setmetatable({}, { __index = Component.Base })
	Segmented.__index = Segmented

	function Segmented:_Normalize(value)
		if type(value) == "number" then
			local name = self.Values[value]
			if name == nil then
				return false
			end
			return true, name
		end
		if type(value) == "string" and table.find(self.Values, value) then
			return true, value
		end
		return false
	end

	function Segmented:GetValues()
		return table.clone(self.Values)
	end

	function Segmented:Next()
		local index = table.find(self.Values, self.State:Get()) or 0
		self.State:Set(self.Values[index % #self.Values + 1])
		return self
	end

	return function(ctx, id, config)
		local values = config.Values
		Utility.Check(type(values) == "table" and #values > 0, "Segmented", id, "Values must be a non-empty array.")
		for _, name in values do
			Utility.Check(type(name) == "string", "Segmented", id, "Values must be strings.")
		end

		local width = config.Width or math.min(60 + #values * 56, 240)
		local self = Component.New(ctx, Segmented, "Segmented", id, config, { RightWidth = width, RightHeight = 26 })
		self.Values = table.clone(values)
		local cleanup = self.Cleanup

		local track = Widgets.Surface(cleanup, {
			Name = "Track",
			Parent = self.Right,
			Fill = "TertiaryBackground",
			Transparency = "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.5,
			Radius = "Full",
			Size = UDim2.fromScale(1, 1),
		})
		Widgets.Padding(track, 3, 3)

		local highlight = Widgets.Surface(cleanup, {
			Name = "Highlight",
			Parent = track,
			Fill = config.Color or "Accent",
			Radius = "Full",
			Size = UDim2.new(1 / #values, 0, 1, 0),
			Position = UDim2.new(),
		})

		local row = Utility.Create("Frame", {
			Name = "Options",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = track,
		})
		Widgets.List(row, 0, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local labels, icons = {}, {}
		for index, name in values do
			local button = Utility.Create("TextButton", {
				Name = name,
				BackgroundTransparency = 1,
				Size = UDim2.new(1 / #values, 0, 1, 0),
				LayoutOrder = index,
				Parent = row,
			})
			local iconName = config.Icons and config.Icons[name]
			local inset = 0
			if iconName then
				local holder = Utility.Create("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.fromOffset(13, 13),
					Parent = button,
				})
				icons[name] = Icons.Create(holder, iconName, { Size = 13, Color = "MutedText", Cleanup = cleanup })
				inset = 22
			end
			local _, label = Widgets.Text(cleanup, {
				Parent = button,
				Text = name,
				Color = "MutedText",
				TextSize = 12,
				Bold = true,
				TextXAlignment = iconName and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(inset, 0),
				Size = UDim2.new(1, -(inset + 4), 1, 0),
			})
			labels[name] = label
			cleanup:Add(button.Activated:Connect(function()
				if self.Enabled then
					self.State:Set(name)
				end
			end))
		end

		local valid, default = self:_Normalize(config.Default or values[1])
		Utility.Check(valid, "Segmented", id, "Default must be a value (or index) from Values.")

		local function render(value, animate)
			local index = table.find(self.Values, value) or 1
			local goal = UDim2.new((index - 1) / #self.Values, 0, 0, 0)
			if animate then
				Animation:Play(highlight, { Position = goal }, {
					Duration = 0.22,
					Style = Enum.EasingStyle.Back,
					Direction = Enum.EasingDirection.Out,
				})
			else
				highlight.Position = goal
			end
			for name, label in labels do
				local active = name == value
				local color = Theme.Resolve(active and (config.SelectedColor or "AccentText") or "MutedText", "MutedText")
				if animate then
					Animation:Play(label.Instance, { TextColor3 = color }, { Duration = 0.15 })
				else
					label.Instance.TextColor3 = color
				end
				if icons[name] then
					icons[name]:SetColor(active and (config.SelectedColor or "AccentText") or "MutedText")
				end
			end
		end
		Component.BindValue(self, id, default, render)

		function self:SetColor(color)
			highlight.BackgroundColor3 = Theme.Resolve(color, "Accent")
			return self
		end

		return self
	end
end
