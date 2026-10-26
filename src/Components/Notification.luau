return function(import)
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")
	local Cleanup = import("Services/Cleanup")

	local Toast = {}
	Toast.__index = Toast

	local TYPES = {
		Info = { Icon = "info", Token = "Info" },
		Success = { Icon = "circle-check", Token = "Success" },
		Warning = { Icon = "triangle-alert", Token = "Warning" },
		Error = { Icon = "alert-circle", Token = "Error" },
	}

	function Toast.new(holder, config, order, onClosed)
		local kind = TYPES[config.Type or "Info"]
		Utility.Check(kind ~= nil, "Notification", config.Title, "Type must be Info, Success, Warning or Error.")
		local self = setmetatable({}, Toast)
		self.Cleanup = Cleanup.new()
		self.Closed = Signal.new()
		self.Answered = Signal.new()
		self._closed = false
		self._answered = false
		local cleanup = self.Cleanup
		cleanup:Add(self.Answered)

		local wrapper = Utility.Create("Frame", {
			Name = "Toast",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = holder,
		})
		cleanup:Add(wrapper)

		local card = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Card",
			Parent = wrapper,
			Fill = "SecondaryBackground",
			BackgroundTransparency = 0.12,
			Stroke = "Border",
			StrokeTransparency = 0.4,
			Radius = 14,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(40, 0),
			GroupTransparency = 1,
		})
		self.Frame = card

		local accent = Widgets.Surface(cleanup, {
			Name = "Accent",
			Parent = card,
			Fill = config.Color or kind.Token,
			Radius = "Full",
			Position = UDim2.new(0, 6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0, 3, 1, -22),
			ZIndex = 2,
		})

		local body = Utility.Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		})
		Widgets.Padding(body, 17, 11, 11, 12)

		local icon = Icons.Create(body, config.Icon or kind.Icon, Icons.Options(config, {
			Size = config.IconSize or 17,
			Color = config.IconColor or kind.Token,
			Cleanup = cleanup,
		}))
		icon.Instance.Position = UDim2.fromOffset(0, 1)
		self._icon = icon

		local column = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -48, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = body,
		})
		Widgets.List(column, 2)

		local title = config.Title or ""
		self.TitleLabel, self._title = Widgets.Text(cleanup, {
			Parent = column,
			Text = title,
			Color = config.TitleColor or "Text",
			Bold = true,
			TextSize = 13,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Visible = title ~= "",
		})
		local content = config.Content or config.Description or ""
		self.ContentLabel, self._content = Widgets.Text(cleanup, {
			Parent = column,
			Text = content,
			Color = config.ContentColor or "MutedText",
			TextSize = 12,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Visible = content ~= "",
		})

		if config.Input then
			local _, box = Widgets.Field(cleanup, {
				Name = "Input",
				Parent = column,
				Radius = 8,
				Placeholder = type(config.Input) == "string" and config.Input or (config.Placeholder or ""),
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = 3,
			})
			if config.Default then
				box.Text = config.Default
			end
			self._input = box
			cleanup:Add(box.FocusLost:Connect(function(enter)
				if enter then
					self:Answer(box.Text)
				end
			end))
		end

		local buttons = config.Buttons
		if not buttons and config.Options then
			buttons = {}
			for index, option in config.Options do
				table.insert(buttons, {
					Title = option,
					Primary = index == 1,
					Answer = option,
				})
			end
		elseif not buttons and config.Input then
			buttons = { { Title = config.ConfirmText or "OK", Primary = true, Answer = true } }
		end

		if buttons then
			local row = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = 4,
				Parent = column,
			})
			Widgets.List(row, 6, {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			})
			for index, entry in buttons do
				local button = Widgets.Surface(cleanup, {
					Class = "TextButton",
					Parent = row,
					Fill = entry.Primary and (entry.Color or kind.Token) or "TertiaryBackground",
					Radius = 8,
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = index,
					Text = entry.Title or "OK",
					TextSize = 11,
				})
				Widgets.Padding(button, 11, 0)
				Theme.BindFn(function()
					button.TextColor3 = Theme.Get(entry.Primary and "AccentText" or "Text")
					button.FontFace = Theme.FontBold
				end, cleanup)
				Widgets.Interactive(cleanup, button, button, {
					Base = entry.Primary and (entry.Color or kind.Token) or "TertiaryBackground",
					Hover = entry.Primary and (entry.Color or kind.Token) or "Hover",
					Pressed = entry.Primary and (entry.Color or kind.Token) or "Pressed",
					Alpha = entry.Primary and { 0, 0.12, 0.25 } or nil,
				})
				cleanup:Add(button.Activated:Connect(function()
					Utility.SafeCall("Notification button", entry.Callback)
					if entry.Answer ~= nil then
						self:Answer(entry.Answer == true and (self._input and self._input.Text or true) or entry.Answer)
					else
						self:Close()
					end
				end))
			end
		end

		if config.Closable ~= false then
			local close = Utility.Create("TextButton", {
				Name = "Close",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(18, 18),
				Parent = body,
			})
			Icons.Create(close, "x", { Size = 12, Position = UDim2.fromOffset(3, 3), Cleanup = cleanup })
			cleanup:Add(close.Activated:Connect(function()
				self:Close()
			end))
		end

		local duration = config.Duration
		if duration == nil then
			duration = 4
		end
		local timed = type(duration) == "number" and duration > 0 and duration < math.huge
		if (timed or config.Progress == true) and config.Progress ~= false then
			local track = Utility.Create("Frame", {
				Name = "Progress",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 2),
				Parent = card,
			})
			local bar = Utility.Create("Frame", { Size = UDim2.fromScale(1, 1), Parent = track })
			Theme.BindFn(function()
				bar.BackgroundColor3 = Theme.Resolve(config.Color or kind.Token, "Info")
			end, cleanup)
			self._bar = bar
			if timed then
				Animation:Play(bar, { Size = UDim2.fromScale(0, 1) }, {
					Duration = duration,
					Style = Enum.EasingStyle.Linear,
				})
			end
		end

		Animation:Play(card, { GroupTransparency = 0, Position = UDim2.new() }, { Duration = 0.22 })
		if timed then
			cleanup:Add(task.delay(duration, function()
				self:Close()
			end))
		end

		self._accent = accent
		self._onClosed = onClosed
		self._onAnswer = config.OnAnswer or ((config.Options or config.Input) and config.Callback or nil)
		return self
	end

	function Toast:Update(config)
		if self._closed or type(config) ~= "table" then
			return self
		end
		if config.Title ~= nil then
			self._title.SetText(config.Title)
			self.TitleLabel.Visible = config.Title ~= ""
		end
		if config.Content ~= nil then
			self._content.SetText(config.Content)
			self.ContentLabel.Visible = config.Content ~= ""
		end
		if config.Icon ~= nil then
			self._icon:Set(config.Icon)
		end
		if config.Color ~= nil then
			self._accent.BackgroundColor3 = Theme.Resolve(config.Color, "Accent")
			if self._bar then
				self._bar.BackgroundColor3 = Theme.Resolve(config.Color, "Accent")
			end
		end
		if config.Type ~= nil and TYPES[config.Type] then
			local kind = TYPES[config.Type]
			self._icon:Set(config.Icon or kind.Icon)
			self._icon:SetColor(kind.Token)
			self._accent.BackgroundColor3 = Theme.Get(kind.Token)
		end
		return self
	end

	function Toast:Answer(value)
		if self._answered or self._closed then
			return self
		end
		self._answered = true
		self.Value = value
		Utility.SafeCall("Notification answer", self._onAnswer, value)
		self.Answered:FireSync(value)
		self:Close()
		return self
	end

	function Toast:OnAnswer(callback)
		return self.Answered:Connect(callback)
	end

	function Toast:GetInput()
		return self._input and self._input.Text or nil
	end

	function Toast:Wait(timeout)
		local deadline = os.clock() + (tonumber(timeout) or 120)
		while not self._answered and not self._closed and os.clock() < deadline do
			task.wait(0.05)
		end
		return self.Value
	end

	function Toast:SetProgress(alpha)
		if self._bar then
			Animation:Cancel(self._bar)
			self._bar.Size = UDim2.fromScale(math.clamp(tonumber(alpha) or 0, 0, 1), 1)
		end
		return self
	end

	function Toast:Close()
		if self._closed then
			return
		end
		self._closed = true
		self.Closed:Fire()
		if self._onClosed then
			self._onClosed(self)
		end
		Animation:Play(self.Frame, { GroupTransparency = 1, Position = UDim2.fromOffset(40, 0) }, {
			Duration = 0.15,
			OnComplete = function()
				self.Cleanup:Clean()
			end,
		})
		task.delay(0.4, function()
			self.Cleanup:Clean()
		end)
	end

	function Toast:Destroy()
		self._closed = true
		self.Cleanup:Clean()
		self.Closed:Destroy()
	end

	return Toast
end
