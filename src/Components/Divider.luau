return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")

	local Divider = setmetatable({}, { __index = Component.Base })
	Divider.__index = Divider

	return function(ctx, id, config)
		local self = Component.NewBare(ctx, Divider, "Divider", id, config)
		local frame = Utility.Create("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, config.Height or 9),
			LayoutOrder = ctx.Order(),
			Parent = ctx.Parent,
		})
		self.Cleanup:Add(frame)

		if type(config.Title) == "string" and config.Title ~= "" then
			local row = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = frame,
			})
			Widgets.List(row, 8, {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			})
			Widgets.Surface(self.Cleanup, {
				Parent = row,
				Fill = config.Color or "Border",
				Radius = 0,
				Size = UDim2.new(0.5, -40, 0, 1),
				LayoutOrder = 1,
			})
			local _, handle = Widgets.Text(self.Cleanup, {
				Parent = row,
				Text = config.Title,
				Color = config.TitleColor or "MutedText",
				TextSize = 11,
				Bold = true,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = 2,
			})
			self._label = handle
			Widgets.Surface(self.Cleanup, {
				Parent = row,
				Fill = config.Color or "Border",
				Radius = 0,
				Size = UDim2.new(0.5, -40, 0, 1),
				LayoutOrder = 3,
			})
		else
			Widgets.Surface(self.Cleanup, {
				Parent = frame,
				Fill = config.Color or "Border",
				Radius = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0, 1),
			})
		end

		self.Frame = frame

		function self:SetTitle(text)
			if self._label then
				self._label.SetText(text)
			end
			return self
		end

		return self
	end
end
