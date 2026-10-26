return function(import)
	local Theme = import("Core/Theme")
	local Utility = import("Core/Utility")
	local Markup = import("Core/Markup")
	local Animation = import("Services/Animation")

	local Widgets = {}

	local TEXT_KEYS = { Color = true, Bold = true, Heavy = true, Class = true, Gradient = true, Markup = true }
	local SURFACE_KEYS = { Fill = true, Stroke = true, Radius = true, Class = true, Transparency = true, Gradient = true, StrokeTransparency = true }

	local function without(props, keys)
		local out = {}
		for key, value in props do
			if not keys[key] then
				out[key] = value
			end
		end
		return out
	end

	local function stops(value)
		if typeof(value) == "ColorSequence" then
			return value
		end
		if type(value) == "table" then
			local keypoints = {}
			local count = #value
			if count == 1 then
				local color = Theme.Resolve(value[1])
				return color and ColorSequence.new(color) or nil
			end
			for index, entry in value do
				local color = Theme.Resolve(entry)
				if not color then
					return nil
				end
				table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (count - 1), color))
			end
			return #keypoints >= 2 and ColorSequence.new(keypoints) or nil
		end
		return nil
	end
	Widgets.Stops = stops

	function Widgets.Text(cleanup, props)
		props = props or {}
		local class = props.Class or "TextLabel"
		local raw = without(props, TEXT_KEYS)
		raw.BackgroundTransparency = 1
		raw.TextSize = raw.TextSize or 13
		raw.TextXAlignment = raw.TextXAlignment or Enum.TextXAlignment.Left

		local useMarkup = props.Markup ~= false and class ~= "TextBox"
		local source = raw.Text
		if source == nil then
			source = ""
		end
		if useMarkup then
			raw.Text = Markup.Parse(source)
			if raw.RichText == nil and raw.Text ~= source then
				raw.RichText = true
			end
		else
			raw.Text = source
		end

		local label = Utility.Create(class, raw)
		local colorSource = props.Color or "Text"
		local gradient
		local weight = props.Heavy and "FontHeavy" or (props.Bold and "FontBold" or "Font")

		local handle = { Instance = label, Source = source }

		local function applyColor()
			local sequence = stops(props.Gradient or (typeof(colorSource) == "ColorSequence" and colorSource or nil))
			if type(colorSource) == "table" and not sequence then
				sequence = stops(colorSource)
			end
			if sequence then
				if not gradient then
					gradient = Utility.Create("UIGradient", { Parent = label })
				end
				gradient.Color = sequence
				label.TextColor3 = Color3.new(1, 1, 1)
			else
				if gradient then
					gradient:Destroy()
					gradient = nil
				end
				label.TextColor3 = Theme.Resolve(colorSource, "Text")
			end
		end

		Theme.BindFn(function()
			applyColor()
			label.FontFace = Theme[weight]
			if class == "TextBox" then
				label.PlaceholderColor3 = Theme.Get("MutedText")
			end
		end, cleanup)

		function handle.SetText(value)
			value = value == nil and "" or tostring(value)
			handle.Source = value
			if useMarkup then
				local parsed = Markup.Parse(value)
				if parsed ~= value then
					label.RichText = true
				end
				label.Text = parsed
			else
				label.Text = value
			end
		end

		function handle.SetColor(value)
			colorSource = value or "Text"
			props.Gradient = nil
			applyColor()
		end

		function handle.SetGradient(value)
			props.Gradient = value
			applyColor()
		end

		function handle.SetWeight(value)
			weight = value == "Heavy" and "FontHeavy" or (value == "Bold" and "FontBold" or "Font")
			label.FontFace = Theme[weight]
		end

		return label, handle
	end

	function Widgets.Surface(cleanup, props)
		local raw = without(props, SURFACE_KEYS)
		local fill, strokeToken, radius, transparency = props.Fill, props.Stroke, props.Radius, props.Transparency
		if radius == nil then
			radius = 12
		end
		if fill == nil and transparency == nil and raw.BackgroundTransparency == nil then
			raw.BackgroundTransparency = 1
		end
		local instance = Utility.Create(props.Class or "Frame", raw)
		if radius ~= 0 then
			Utility.Create("UICorner", {
				CornerRadius = radius == "Full" and UDim.new(1, 0) or UDim.new(0, radius),
				Parent = instance,
			})
		end
		local gradient
		if props.Gradient then
			gradient = Utility.Create("UIGradient", { Parent = instance })
		end
		local stroke
		if strokeToken then
			stroke = Utility.Create("UIStroke", {
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = instance,
			})
		end
		Theme.BindFn(function()
			if fill then
				instance.BackgroundColor3 = Theme.Resolve(fill, "SecondaryBackground")
			end
			if transparency ~= nil then
				instance.BackgroundTransparency = type(transparency) == "number" and transparency or Theme.Get(transparency)
			end
			if gradient then
				local sequence = stops(props.Gradient)
				if sequence then
					gradient.Color = sequence
				end
			end
			if stroke then
				stroke.Color = Theme.Resolve(strokeToken, "Border")
				if props.StrokeTransparency ~= nil then
					stroke.Transparency = type(props.StrokeTransparency) == "number" and props.StrokeTransparency
						or Theme.Get(props.StrokeTransparency)
				end
			end
		end, cleanup)
		return instance, stroke
	end

	function Widgets.Interactive(cleanup, target, trigger, opts)
		opts = opts or {}
		local base = opts.Base or "SecondaryBackground"
		local hoverToken = opts.Hover or "Hover"
		local pressedToken = opts.Pressed or "Pressed"
		local hover, down, enabled = false, false, true
		local handle = {}

		local function apply(instant)
			local color = Theme.Get(base)
			local alpha = opts.Alpha and opts.Alpha[1]
			if enabled and down then
				color = Theme.Get(pressedToken)
				alpha = opts.Alpha and opts.Alpha[3]
			elseif enabled and hover then
				color = Theme.Get(hoverToken)
				alpha = opts.Alpha and opts.Alpha[2]
			end
			local goal = { BackgroundColor3 = color }
			if alpha then
				goal.BackgroundTransparency = alpha
			end
			if instant then
				for property, value in goal do
					target[property] = value
				end
			else
				Animation:Play(target, goal, {
					Duration = down and Animation.Duration.Instant or Animation.Duration.Normal,
					Ease = "Soft",
				})
			end
			if opts.OnState then
				opts.OnState(enabled and hover, enabled and down)
			end
		end

		local function isPress(input)
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end

		cleanup:Add(trigger.MouseEnter:Connect(function()
			hover = true
			apply()
		end))
		cleanup:Add(trigger.MouseLeave:Connect(function()
			hover = false
			down = false
			apply()
		end))
		cleanup:Add(trigger.InputBegan:Connect(function(input)
			if isPress(input) then
				down = true
				apply()
			end
		end))
		cleanup:Add(trigger.InputEnded:Connect(function(input)
			if isPress(input) then
				down = false
				if input.UserInputType == Enum.UserInputType.Touch then
					hover = false
				end
				apply()
			end
		end))
		Theme.BindFn(function()
			apply(true)
		end, cleanup)

		function handle.SetEnabled(value)
			enabled = value
			if not value then
				hover, down = false, false
			end
			apply()
		end
		handle.Refresh = apply
		return handle
	end

	function Widgets.Pulse(instance, amount, duration)
		if not instance or not instance.Parent then
			return nil
		end
		local scale = instance:FindFirstChild("PulseScale")
		if not scale then
			scale = Utility.Create("UIScale", { Name = "PulseScale", Parent = instance })
		end
		Animation:Cancel(scale)
		scale.Scale = amount or 0.9
		Animation:Play(scale, { Scale = 1 }, {
			Duration = duration or 0.28,
			Style = Enum.EasingStyle.Back,
			Direction = Enum.EasingDirection.Out,
		})
		return scale
	end

	function Widgets.Glow(stroke, token, duration)
		if not stroke or not stroke.Parent then
			return
		end
		local resting = stroke.Transparency
		local color = stroke.Color
		Animation:Play(stroke, { Color = Theme.Get(token or "Accent"), Transparency = 0 }, { Duration = 0.1 })
		task.delay(duration or 0.45, function()
			if stroke.Parent then
				Animation:Play(stroke, { Color = color, Transparency = resting }, { Duration = 0.3 })
			end
		end)
	end

	function Widgets.Padding(parent, left, top, right, bottom)
		top = top or left
		return Utility.Create("UIPadding", {
			PaddingLeft = UDim.new(0, left),
			PaddingTop = UDim.new(0, top),
			PaddingRight = UDim.new(0, right or left),
			PaddingBottom = UDim.new(0, bottom or top),
			Parent = parent,
		})
	end

	function Widgets.List(parent, gap, extra)
		local props = {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, gap or 0),
			Parent = parent,
		}
		for key, value in extra or {} do
			props[key] = value
		end
		return Utility.Create("UIListLayout", props)
	end

	function Widgets.Scroller(cleanup, props)
		local raw = props or {}
		local scroller = Utility.Create("ScrollingFrame", {
			Name = raw.Name or "Scroller",
			BackgroundTransparency = 1,
			Size = raw.Size or UDim2.fromScale(1, 1),
			Position = raw.Position or UDim2.new(),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = raw.Thickness or 3,
			ScrollBarImageTransparency = 0.4,
			ClipsDescendants = true,
			LayoutOrder = raw.LayoutOrder or 1,
			Visible = raw.Visible ~= false,
			Parent = raw.Parent,
		})
		Theme.BindFn(function()
			scroller.ScrollBarImageColor3 = Theme.Get("MutedText")
		end, cleanup)
		return scroller
	end

	function Widgets.Field(cleanup, props)
		props = props or {}
		local holder, stroke = Widgets.Surface(cleanup, {
			Name = props.Name or "Field",
			Parent = props.Parent,
			Fill = props.Fill or "TertiaryBackground",
			Transparency = props.Transparency or "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.45,
			Radius = props.Radius or 10,
			Size = props.Size or UDim2.fromScale(1, 1),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			LayoutOrder = props.LayoutOrder,
		})
		local box = Widgets.Text(cleanup, {
			Class = "TextBox",
			Name = "Box",
			Parent = holder,
			Text = props.Text or "",
			PlaceholderText = props.Placeholder or "",
			ClearTextOnFocus = false,
			TextSize = props.TextSize or 12,
			TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(props.Inset or 9, 0),
			Size = UDim2.new(1, -((props.Inset or 9) + (props.Trail or 9)), 1, 0),
		})

		local focused = false
		local function paint(instant)
			local color = Theme.Get(focused and "Accent" or "Border")
			local alpha = focused and 0.15 or 0.45
			if instant then
				stroke.Color = color
				stroke.Transparency = alpha
			else
				Animation:Play(stroke, { Color = color, Transparency = alpha }, { Duration = 0.12 })
			end
		end
		cleanup:Add(box.Focused:Connect(function()
			focused = true
			paint()
		end))
		cleanup:Add(box.FocusLost:Connect(function()
			focused = false
			paint()
		end))

		local handle = {}
		function handle.Flash(token)
			Animation:Play(stroke, { Color = Theme.Get(token or "Error"), Transparency = 0.1 }, { Duration = 0.1 })
			task.delay(0.5, function()
				if stroke.Parent then
					paint()
				end
			end)
		end
		handle.Refresh = paint

		return holder, box, stroke, handle
	end

	function Widgets.Chip(cleanup, props)
		props = props or {}
		local chip = Widgets.Surface(cleanup, {
			Class = props.Class or "TextButton",
			Name = props.Name or "Chip",
			Parent = props.Parent,
			Fill = props.Fill or "TertiaryBackground",
			Transparency = props.Transparency or "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.5,
			Radius = props.Radius or "Full",
			Size = props.Size or UDim2.fromOffset(24, 24),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			LayoutOrder = props.LayoutOrder,
			ZIndex = props.ZIndex or 1,
			Visible = props.Visible ~= false,
		})
		Widgets.Interactive(cleanup, chip, chip, { Base = props.Fill or "TertiaryBackground" })
		return chip
	end

	return Widgets
end
