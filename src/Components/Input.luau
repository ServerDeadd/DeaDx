return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")

	local TextInput = setmetatable({}, { __index = Component.Base })
	TextInput.__index = TextInput

	function TextInput:_Normalize(value)
		if type(value) == "string" then
			return true, value
		elseif type(value) == "number" then
			return true, tostring(value)
		elseif value == nil then
			return true, ""
		end
		return false
	end

	function TextInput:SetPlaceholder(text)
		self._box.PlaceholderText = text or ""
		return self
	end

	function TextInput:Focus()
		self._box:CaptureFocus()
		return self
	end

	function TextInput:Clear()
		self.State:Set("")
		return self
	end

	return function(ctx, id, config)
		Utility.Check(config.Default == nil or type(config.Default) == "string", "Input", id, "Default must be a string.")
		Utility.Check(
			config.MaxLength == nil or type(config.MaxLength) == "number",
			"Input",
			id,
			"MaxLength must be a number."
		)
		Utility.Check(
			config.Validate == nil or type(config.Validate) == "function",
			"Input",
			id,
			"Validate must be a function."
		)
		local self = Component.New(ctx, TextInput, "Input", id, config, {
			RightWidth = config.Width or 190,
			RightHeight = config.Height or 26,
		})
		local cleanup = self.Cleanup

		local holder, box, stroke, field = Widgets.Field(cleanup, {
			Name = "Input",
			Parent = self.Right,
			Radius = 10,
			Placeholder = config.Placeholder or "",
			Trail = 26,
			Size = UDim2.fromScale(1, 1),
		})
		self._box, self._field = box, field
		if config.TextColor then
			box.TextColor3 = Utility.FromHex(config.TextColor) or box.TextColor3
		end

		local clear = Utility.Create("TextButton", {
			Name = "Clear",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Visible = false,
			Parent = holder,
		})
		Icons.Create(clear, "x", { Size = 11, Position = UDim2.fromOffset(3.5, 3.5), Cleanup = cleanup })

		local function validate(text)
			if config.MaxLength and #text > config.MaxLength then
				return false
			end
			if config.Numeric and text ~= "" and tonumber(text) == nil then
				return false
			end
			if config.Validate then
				local ok, result = pcall(config.Validate, text)
				if not ok or result == false then
					return false
				end
			end
			return true
		end

		Component.BindValue(self, id, config.Default or "", function(value)
			if box.Text ~= value then
				box.Text = value
			end
		end)

		cleanup:Add(box:GetPropertyChangedSignal("Text"):Connect(function()
			local text = box.Text
			if config.MaxLength and #text > config.MaxLength then
				box.Text = string.sub(text, 1, config.MaxLength)
				return
			end
			clear.Visible = text ~= "" and config.ClearButton ~= false
			if config.Live and validate(text) then
				self.State:Set(text)
			end
		end))
		cleanup:Add(box.FocusLost:Connect(function()
			if validate(box.Text) then
				self.State:Set(box.Text)
			else
				box.Text = self.State:Get()
				field.Flash("Error")
			end
		end))
		cleanup:Add(clear.Activated:Connect(function()
			box.Text = ""
			self.State:Set("")
		end))
		clear.Visible = box.Text ~= "" and config.ClearButton ~= false
		return self
	end
end
