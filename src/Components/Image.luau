return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Banner = setmetatable({}, { __index = Component.Base })
	Banner.__index = Banner

	function Banner:SetImage(spec)
		self._art:Set(spec)
		return self
	end

	function Banner:SetTitle(text)
		if self._title then
			self._title.SetText(text)
		end
		return self
	end

	function Banner:SetDescription(text)
		if self._description then
			self._description.SetText(text)
		end
		return self
	end

	function Banner:SetTransparency(value)
		local image = self._art.Instance:FindFirstChildWhichIsA("ImageLabel")
		if image then
			Animation:Play(image, { ImageTransparency = math.clamp(value, 0, 1) }, { Duration = 0.2 })
		end
		return self
	end

	return function(ctx, id, config)
		local height = config.Height or 120
		local self = Component.NewBare(ctx, Banner, "Image", id, config)
		local cleanup = self.Cleanup

		local frame = Widgets.Surface(cleanup, {
			Name = "Image",
			Parent = ctx.Parent,
			Fill = "SecondaryBackground",
			Transparency = "ComponentTransparency",
			Stroke = "Border",
			StrokeTransparency = "ComponentStrokeTransparency",
			Radius = config.Radius or 14,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = ctx.Order(),
		})
		cleanup:Add(frame)
		self.Frame = frame

		self._art = Icons.Create(frame, config.Image, Icons.Options(config, {
			Size = height,
			Color = config.Color or "Text",
			Shape = config.Shape,
			Corner = config.Corner,
			Tint = config.Tint,
			ScaleType = config.ScaleType or Enum.ScaleType.Crop,
			Cleanup = cleanup,
		}))
		self._art.Instance.Size = UDim2.fromScale(1, 1)
		self._art.Instance.Position = UDim2.new()

		if config.Title or config.Description then
			local shade = Utility.Create("Frame", {
				Name = "Shade",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.35,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 56),
				Parent = frame,
			})
			Utility.Create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Parent = shade,
			})
			local column = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 14, 1, -10),
				Size = UDim2.new(1, -28, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = frame,
			})
			Widgets.List(column, 2)
			if config.Title then
				local _, handle = Widgets.Text(cleanup, {
					Parent = column,
					Text = config.Title,
					Color = config.TitleColor or "#FFFFFF",
					Gradient = config.TitleGradient,
					Heavy = true,
					TextSize = 15,
					Size = UDim2.new(1, 0, 0, 18),
					LayoutOrder = 1,
				})
				self._title = handle
			end
			if config.Description then
				local _, handle = Widgets.Text(cleanup, {
					Parent = column,
					Text = config.Description,
					Color = config.DescriptionColor or "#D4D4D8",
					TextSize = 12,
					TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = 2,
				})
				self._description = handle
			end
		end

		if config.Callback then
			local hit = Utility.Create("TextButton", {
				Name = "Hit",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
				Parent = frame,
			})
			cleanup:Add(hit.Activated:Connect(function()
				Utility.SafeCall("Image " .. tostring(id), config.Callback)
			end))
			cleanup:Add(hit.MouseEnter:Connect(function()
				Widgets.Pulse(frame, 0.985, 0.25)
			end))
		end
		return self
	end
end
