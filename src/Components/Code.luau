return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Capabilities = import("Core/Capabilities")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Code = setmetatable({}, { __index = Component.Base })
	Code.__index = Code

	function Code:_Normalize(value)
		if value == nil then
			return true, ""
		end
		return true, tostring(value)
	end

	function Code:GetText()
		return self.State:Get()
	end

	function Code:SetText(text)
		return self:SetValue(text)
	end

	function Code:Copy()
		local ok = Capabilities.SetClipboard(self.State:Get())
		if ok and self._copyIcon then
			self._copyIcon:Set("check")
			Widgets.Pulse(self._copy, 0.8, 0.3)
			task.delay(1.2, function()
				if self._copyIcon and not self._destroyed then
					self._copyIcon:Set("copy")
				end
			end)
		end
		return ok
	end

	return function(ctx, id, config)
		local self = Component.NewBare(ctx, Code, "Code", id, config)
		local cleanup = self.Cleanup

		local frame = Utility.Create("Frame", {
			Name = "Code",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = ctx.Order(),
			Parent = ctx.Parent,
		})
		cleanup:Add(frame)
		Widgets.List(frame, 6)
		self.Frame = frame

		if config.Title then
			local _, handle = Widgets.Text(cleanup, {
				Parent = frame,
				Text = config.Title,
				Color = config.TitleColor or "MutedText",
				Bold = true,
				TextSize = 12,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 1,
			})
			self._label = handle
		end

		local block = Widgets.Surface(cleanup, {
			Name = "Block",
			Parent = frame,
			Fill = config.Background or "Background",
			Transparency = config.Transparency or 0.25,
			Stroke = "Border",
			StrokeTransparency = 0.5,
			Radius = 10,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
		})
		Widgets.Padding(block, 12, 11, 40, 11)

		local box = Widgets.Text(cleanup, {
			Class = "TextBox",
			Name = "Text",
			Parent = block,
			Text = config.Default or config.Text or "",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = config.TextSize or 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ClearTextOnFocus = false,
			MultiLine = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
		})
		box.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		box.TextEditable = config.Editable == true
		self._box = box

		Component.BindValue(self, id, config.Default or config.Text or "", function(value)
			if box.Text ~= value then
				box.Text = value
			end
		end)
		cleanup:Add(box.FocusLost:Connect(function()
			if config.Editable then
				self.State:Set(box.Text)
			else
				box.Text = self.State:Get()
			end
		end))

		if Capabilities.Clipboard and config.Copy ~= false then
			self._copy = Widgets.Chip(cleanup, {
				Name = "Copy",
				Parent = block,
				Radius = 8,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 7, 0, 0),
				Size = UDim2.fromOffset(24, 24),
			})
			self._copyIcon = Icons.Create(self._copy, "copy", {
				Size = 12,
				Position = UDim2.fromOffset(6, 6),
				Cleanup = cleanup,
			})
			cleanup:Add(self._copy.Activated:Connect(function()
				self:Copy()
			end))
		end
		return self
	end
end
