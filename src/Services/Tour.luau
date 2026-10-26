return function(import)
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")
	local Input = import("Services/Input")

	local Tour = {}
	Tour.__index = Tour

	local PAD = 6

	function Tour.new(window, steps, config)
		config = config or {}
		Utility.Check(type(steps) == "table" and #steps > 0, "Tour", "?", "Steps must be a non-empty array.")
		local self = setmetatable({}, Tour)
		self.Window = window
		self.Steps = steps
		self.Config = config
		self.Cleanup = Cleanup.new()
		self.Finished = Signal.new()
		self.Changed = Signal.new()
		self._index = 0
		self._done = false
		local cleanup = self.Cleanup
		cleanup:Add(self.Finished)
		cleanup:Add(self.Changed)

		local gui = cleanup:Add(Utility.NewScreenGui("DeaDx_Tour", config.DisplayOrder or 2200))
		gui.IgnoreGuiInset = true
		self.Gui = gui

		local shade = Utility.Create("CanvasGroup", {
			Name = "Shade",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = 1,
			Parent = gui,
		})
		self._shade = shade

		self._panels = {}
		for _, name in { "Top", "Bottom", "Left", "Right" } do
			local panel = Utility.Create("Frame", {
				Name = name,
				BackgroundColor3 = config.Backdrop or Color3.fromRGB(4, 4, 6),
				BackgroundTransparency = config.Dim or 0.25,
				Size = UDim2.new(),
				Parent = shade,
			})
			self._panels[name] = panel
		end

		local halo = Widgets.Surface(cleanup, {
			Name = "Halo",
			Parent = gui,
			Stroke = config.Color or "Accent",
			StrokeTransparency = 0.1,
			Radius = 16,
			Size = UDim2.new(),
			Visible = false,
		})
		halo:FindFirstChildOfClass("UIStroke").Thickness = 2
		self._halo = halo

		local card = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Step",
			Parent = gui,
			Fill = "Background",
			Transparency = 0.04,
			Stroke = "Border",
			StrokeTransparency = 0.3,
			Radius = 16,
			Size = UDim2.fromOffset(config.Width or 268, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = 1,
		})
		self._card = card
		Widgets.Padding(card, 16, 15)
		Widgets.List(card, 9)

		local head = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = card,
		})
		local holder = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(15, 15),
			Parent = head,
		})
		self._icon = Icons.Create(holder, config.Icon or "compass", {
			Size = 15,
			Color = config.Color or "Accent",
			Cleanup = cleanup,
		})
		local _, title = Widgets.Text(cleanup, {
			Parent = head,
			Text = "",
			Bold = true,
			TextSize = 14,
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -62, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		self._title = title
		local _, counter = Widgets.Text(cleanup, {
			Parent = head,
			Text = "",
			Color = "MutedText",
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(40, 18),
			Markup = false,
		})
		self._counter = counter

		local _, body = Widgets.Text(cleanup, {
			Parent = card,
			Text = "",
			Color = "MutedText",
			TextSize = 12,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
		})
		self._body = body

		local track = Widgets.Surface(cleanup, {
			Parent = card,
			Fill = "SecondaryBackground",
			Transparency = 0.2,
			Radius = "Full",
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, 3),
			LayoutOrder = 3,
		})
		self._progress = Widgets.Surface(cleanup, {
			Parent = track,
			Fill = config.Color or "Accent",
			Radius = "Full",
			Size = UDim2.fromScale(0, 1),
		})

		local row = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 4,
			Parent = card,
		})
		Widgets.List(row, 7, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local function button(text, primary, order, width, callback)
			local control = Widgets.Surface(cleanup, {
				Class = "TextButton",
				Parent = row,
				Fill = primary and (config.Color or "Accent") or "SecondaryBackground",
				Stroke = (not primary) and "Border" or nil,
				StrokeTransparency = 0.4,
				Radius = 10,
				Size = UDim2.new(width, -4, 1, 0),
				LayoutOrder = order,
				Text = text,
				TextSize = 12,
			})
			Theme.BindFn(function()
				control.TextColor3 = Theme.Get(primary and "AccentText" or "Text")
				control.FontFace = Theme.FontBold
			end, cleanup)
			Widgets.Interactive(cleanup, control, control, {
				Base = primary and (config.Color or "Accent") or "SecondaryBackground",
				Hover = primary and (config.Color or "Accent") or "Hover",
				Pressed = primary and (config.Color or "Accent") or "Pressed",
				Alpha = primary and { 0, 0.12, 0.25 } or nil,
			})
			cleanup:Add(control.Activated:Connect(callback))
			return control
		end

		button(config.SkipText or "Skip", false, 1, 0.3, function()
			self:Finish(true)
		end)
		self._back = button(config.BackText or "Back", false, 2, 0.3, function()
			self:Prev()
		end)
		self._next = button(config.NextText or "Next", true, 3, 0.4, function()
			self:Next()
		end)

		cleanup:Add(Input.Began:Connect(function(input, processed)
			if self._done or processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				self:Finish(true)
			elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.Return then
				self:Next()
			elseif input.KeyCode == Enum.KeyCode.Left then
				self:Prev()
			end
		end))

		Animation:Play(shade, { GroupTransparency = 0 }, { Duration = 0.25, Ease = "Smooth" })
		self:Next()
		return self
	end

	function Tour:_Target(step)
		local window = self.Window
		if step.Tab then
			window:SelectTab(step.Tab)
		end
		local target = step.Target
		if type(target) == "string" then
			local component = window.Options[target]
			if component then
				if not step.Tab and component._entry then
					window:_GoTo(component._entry)
				end
				return component.Frame
			end
			local tab = window:GetTab(target)
			if tab then
				window:SelectTab(tab)
				return tab.Button
			end
			return nil
		end
		if typeof(target) == "Instance" and target:IsA("GuiObject") then
			return target
		end
		if type(target) == "table" and target.Frame then
			return target.Frame
		end
		return nil
	end

	function Tour:_Frame(rect, instant, override)
		local gui = self.Gui
		local origin = gui.AbsolutePosition
		local viewport = gui.AbsoluteSize
		local duration = instant and 0 or (override or 0.34)
		local panels = self._panels
		local x = rect.Position.X - origin.X
		local y = rect.Position.Y - origin.Y
		local w, h = rect.Size.X, rect.Size.Y

		local function move(panel, px, py, sx, sy)
			Animation:Play(panel, {
				Position = UDim2.fromOffset(px, py),
				Size = UDim2.fromOffset(math.max(sx, 0), math.max(sy, 0)),
			}, { Duration = duration, Ease = "Smooth" })
		end

		move(panels.Top, 0, 0, viewport.X, y)
		move(panels.Bottom, 0, y + h, viewport.X, viewport.Y - (y + h))
		move(panels.Left, 0, y, x, h)
		move(panels.Right, x + w, y, viewport.X - (x + w), h)

		self._halo.Visible = true
		Animation:Play(self._halo, {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
		}, { Duration = duration, Ease = "Smooth" })

		local card = self._card
		local cardWidth = card.AbsoluteSize.X
		local cardHeight = math.max(card.AbsoluteSize.Y, 120)
		local below = y + h + 12
		local cardY = below
		if below + cardHeight > viewport.Y - 12 then
			cardY = math.max(y - cardHeight - 12, 12)
		end
		local cardX = math.clamp(x + w / 2 - cardWidth / 2, 12, math.max(12, viewport.X - cardWidth - 12))
		Animation:Play(card, {
			Position = UDim2.fromOffset(cardX, cardY),
		}, { Duration = duration, Ease = "Smooth" })
	end

	function Tour:_Show(index)
		local step = self.Steps[index]
		if not step then
			return self:Finish()
		end
		self._index = index
		self._title.SetText(step.Title or "Step " .. index)
		self._body.SetText(step.Text or step.Description or "")
		self._counter.SetText(index .. "/" .. #self.Steps)
		self._back.Visible = index > 1
		self._next.Text = index == #self.Steps and (self.Config.DoneText or "Done") or (self.Config.NextText or "Next")
		Animation:Play(self._progress, { Size = UDim2.fromScale(index / #self.Steps, 1) }, {
			Duration = 0.3,
			Ease = "Smooth",
		})
		self.Changed:Fire(index, step)

		task.spawn(function()
			if self._done then
				return
			end
			local frame = self:_Target(step)
			local token = self._index

			local function rect()
				if frame and frame.Parent and frame.AbsoluteSize.Y > 0 then
					return {
						Position = frame.AbsolutePosition - Vector2.new(PAD, PAD),
						Size = frame.AbsoluteSize + Vector2.new(PAD * 2, PAD * 2),
					}
				end
				local gui = self.Gui
				self._halo.Visible = false
				return {
					Position = gui.AbsolutePosition + gui.AbsoluteSize / 2 - Vector2.new(1, 1),
					Size = Vector2.new(2, 2),
				}
			end

			task.wait(step.Delay or 0.34)
			if self._done or self._index ~= token then
				return
			end
			self:_Frame(rect(), not self._started)
			self._started = true
			if self._card.GroupTransparency > 0 then
				Animation:Play(self._card, { GroupTransparency = 0 }, { Duration = 0.2 })
			end
			if step.Run then
				Utility.SafeCall("Tour step", step.Run, self.Window)
			end

			local last
			for _ = 1, 9 do
				task.wait(0.12)
				if self._done or self._index ~= token then
					return
				end
				local settled = rect()
				if last and (settled.Position - last).Magnitude < 1 and (settled.Size - self._halo.AbsoluteSize).Magnitude < 2 then
					break
				end
				last = settled.Position
				self:_Frame(settled, false, 0.16)
			end
		end)
		return self
	end

	function Tour:Next()
		if self._done then
			return self
		end
		if self._index >= #self.Steps then
			return self:Finish()
		end
		return self:_Show(self._index + 1)
	end

	function Tour:Prev()
		if self._done or self._index <= 1 then
			return self
		end
		return self:_Show(self._index - 1)
	end

	function Tour:Goto(index)
		return self:_Show(math.clamp(index, 1, #self.Steps))
	end

	function Tour:IsRunning()
		return not self._done
	end

	function Tour:Finish(skipped)
		if self._done then
			return self
		end
		self._done = true
		self.Finished:Fire(skipped == true, self._index)
		Utility.SafeCall("Tour finish", self.Config.OnFinish, skipped == true)
		Animation:Play(self._card, { GroupTransparency = 1 }, { Duration = 0.18 })
		Animation:Play(self._shade, { GroupTransparency = 1 }, {
			Duration = 0.24,
			OnComplete = function()
				self.Cleanup:Clean()
			end,
		})
		task.delay(0.7, function()
			self.Cleanup:Clean()
		end)
		return self
	end

	function Tour:Destroy()
		self._done = true
		self.Cleanup:Clean()
	end

	return Tour
end
