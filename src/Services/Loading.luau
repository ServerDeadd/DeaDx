return function(import)
	local Lighting = game:GetService("Lighting")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")

	local Loading = {}
	Loading.__index = Loading

	local function viewportScale()
		local camera = Workspace.CurrentCamera
		if not camera then
			return 1
		end
		local height = camera.ViewportSize.Y
		if height <= 0 then
			return 1
		end
		return math.clamp(height / 900, 0.78, 1.35)
	end

	function Loading.new(config)
		config = config or {}
		Utility.Check(type(config) == "table", "LoadingScreen", "?", "Config must be a table.")
		local self = setmetatable({}, Loading)
		self.Cleanup = Cleanup.new()
		self.Finished = Signal.new()
		self.Config = config
		self.Steps = config.Steps or {}
		self._index = 0
		self._done = false
		self._progress = 0
		self._opened = os.clock()
		local cleanup = self.Cleanup
		cleanup:Add(self.Finished)

		local gui = cleanup:Add(Utility.NewScreenGui("DeaDx_Loading", config.DisplayOrder or 2500))
		gui.IgnoreGuiInset = true
		self.Gui = gui

		local root = Utility.Create("CanvasGroup", {
			Name = "Loading",
			BackgroundColor3 = config.Backdrop or Color3.fromRGB(6, 6, 8),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = 1,
			Parent = gui,
		})
		self.Root = root

		local vignette = Utility.Create("Frame", {
			Name = "Vignette",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		})
		Utility.Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.5, 0.85),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
			Parent = vignette,
		})

		if config.Blur ~= false then
			local blur = Instance.new("BlurEffect")
			blur.Name = "DeaDxLoadingBlur"
			blur.Size = 0
			blur.Parent = Lighting
			cleanup:Add(blur)
			Animation:Play(blur, { Size = config.BlurSize or 22 }, { Duration = 0.25 })
			self._blur = blur
		end

		local stage = Utility.Create("Frame", {
			Name = "Stage",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(config.Width or 420, 260),
			Parent = root,
		})
		local scale = Instance.new("UIScale")
		scale.Scale = viewportScale() * 0.96
		scale.Parent = stage
		self._scale = scale
		cleanup:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			scale.Scale = viewportScale()
		end))

		local glow = Utility.Create("Frame", {
			Name = "Glow",
			BackgroundColor3 = Theme.Resolve(config.Color, "Accent"),
			BackgroundTransparency = 0.88,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, 40),
			Size = UDim2.fromOffset(160, 160),
			Parent = stage,
		})
		Utility.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
		Utility.Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = glow,
		})
		self._glow = glow

		local card = Widgets.Surface(cleanup, {
			Name = "Card",
			Parent = stage,
			Fill = "Background",
			Transparency = 0.05,
			Stroke = "Border",
			StrokeTransparency = 0.35,
			Radius = 24,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		self.Card = card
		Widgets.Padding(card, 26, 26)
		Widgets.List(card, 14, { HorizontalAlignment = Enum.HorizontalAlignment.Center })

		local ring = Utility.Create("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(62, 62),
			LayoutOrder = 1,
			Parent = card,
		})
		local track = Widgets.Surface(cleanup, {
			Name = "RingTrack",
			Parent = ring,
			Radius = "Full",
			Stroke = "Border",
			StrokeTransparency = 0.6,
			Size = UDim2.fromScale(1, 1),
		})
		track:FindFirstChildOfClass("UIStroke").Thickness = 2
		local orbit = Widgets.Surface(cleanup, {
			Name = "Orbit",
			Parent = ring,
			Radius = "Full",
			Stroke = config.Color or "Accent",
			StrokeTransparency = 0,
			Size = UDim2.fromScale(1, 1),
		})
		orbit:FindFirstChildOfClass("UIStroke").Thickness = 2
		Utility.Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.42, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = orbit,
		})
		self._orbit = orbit

		local iconHolder = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 26),
			Parent = ring,
		})
		self._icon = Icons.Create(iconHolder, config.Icon or "zap", Icons.Options(config, {
			Size = config.IconSize or 26,
			Color = config.IconColor or config.Color or "Accent",
			Cleanup = cleanup,
		}))

		local _, title = Widgets.Text(cleanup, {
			Name = "Title",
			Parent = card,
			Text = config.Title or "DeaDx",
			Color = config.TitleColor or "Text",
			Gradient = config.TitleGradient,
			Heavy = true,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = 2,
		})
		self._title = title

		local subtitle = config.Subtitle or config.SubTitle or ""
		local subtitleLabel, subtitleHandle = Widgets.Text(cleanup, {
			Name = "Subtitle",
			Parent = card,
			Text = subtitle,
			Color = config.SubtitleColor or "MutedText",
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 3,
			Visible = subtitle ~= "",
		})
		self._subtitle, self._subtitleLabel = subtitleHandle, subtitleLabel

		local bar = Widgets.Surface(cleanup, {
			Name = "Bar",
			Parent = card,
			Fill = "SecondaryBackground",
			Transparency = 0.2,
			Radius = "Full",
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, 8),
			LayoutOrder = 4,
		})
		local fill = Widgets.Surface(cleanup, {
			Name = "Fill",
			Parent = bar,
			Fill = config.Color or "Accent",
			Radius = "Full",
			Size = UDim2.fromScale(0, 1),
		})
		local stops = Widgets.Stops(config.Gradient)
		if stops then
			Utility.Create("UIGradient", { Color = stops, Parent = fill })
		end
		local head = Widgets.Surface(cleanup, {
			Name = "Head",
			Parent = fill,
			Fill = "Text",
			BackgroundTransparency = 0.6,
			Radius = "Full",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0, 14, 1, 0),
		})
		self._fill, self._head = fill, head

		local statusRow = Utility.Create("Frame", {
			Name = "Status",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 5,
			Parent = card,
		})
		local _, status = Widgets.Text(cleanup, {
			Parent = statusRow,
			Text = config.Status or "Loading",
			Color = "MutedText",
			TextSize = 12,
			Size = UDim2.new(1, -48, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		self._status = status
		local _, percent = Widgets.Text(cleanup, {
			Parent = statusRow,
			Text = "0%",
			Color = config.Color or "Accent",
			Bold = true,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(46, 16),
			Markup = false,
		})
		self._percent = percent

		if #self.Steps > 0 and config.Dots ~= false then
			local dots = Utility.Create("Frame", {
				Name = "Dots",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 8),
				LayoutOrder = 6,
				Parent = card,
			})
			Widgets.List(dots, 6, {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			})
			self._dots = {}
			for index = 1, #self.Steps do
				local dot = Widgets.Surface(cleanup, {
					Parent = dots,
					Fill = "Border",
					Radius = "Full",
					Size = UDim2.fromOffset(6, 6),
					LayoutOrder = index,
				})
				table.insert(self._dots, dot)
			end
		end

		if config.Tips and #config.Tips > 0 then
			Widgets.Surface(cleanup, {
				Name = "Rule",
				Parent = card,
				Fill = "Border",
				Radius = 0,
				BackgroundTransparency = 0.4,
				Size = UDim2.new(1, 0, 0, 1),
				LayoutOrder = 7,
			})
			local _, tip = Widgets.Text(cleanup, {
				Name = "Tip",
				Parent = card,
				Text = config.Tips[1],
				Color = "MutedText",
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 8,
			})
			self._tip = tip
			cleanup:Add(task.spawn(function()
				local index = 1
				while not self._done do
					task.wait(config.TipInterval or 4)
					if self._done then
						break
					end
					index = index % #config.Tips + 1
					Animation:Play(tip.Instance, { TextTransparency = 1 }, { Duration = 0.18 })
					task.wait(0.2)
					tip.SetText(config.Tips[index])
					Animation:Play(tip.Instance, { TextTransparency = 0 }, { Duration = 0.22 })
				end
			end))
		end

		if config.Footer then
			Widgets.Text(cleanup, {
				Name = "Footer",
				Parent = card,
				Text = config.Footer,
				Color = "MutedText",
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 13),
				LayoutOrder = 9,
			})
		end

		local spin = 0
		cleanup:Add(RunService.RenderStepped:Connect(function(delta)
			if self._done then
				return
			end
			spin = (spin + delta * 220) % 360
			orbit.Rotation = spin
		end))

		Animation:Play(root, { GroupTransparency = 0, BackgroundTransparency = config.Dim or 0.12 }, { Duration = 0.18 })
		Animation:Play(scale, { Scale = viewportScale() }, { Duration = 0.26, Style = Enum.EasingStyle.Back })

		if config.Auto then
			self:Auto(config.Auto)
		end
		return self
	end

	function Loading:SetProgress(alpha, status)
		if self._done and alpha ~= 1 then
			return self
		end
		alpha = math.clamp(tonumber(alpha) or 0, 0, 1)
		self._progress = alpha
		Animation:Play(self._fill, { Size = UDim2.fromScale(alpha, 1) }, {
			Duration = 0.25,
			Style = Enum.EasingStyle.Quint,
		})
		self._head.Visible = alpha > 0.02
		self._percent.SetText(string.format("%d%%", alpha * 100 + 0.5))
		if status then
			self:SetStatus(status)
		end
		return self
	end

	function Loading:GetProgress()
		return self._progress or 0
	end

	function Loading:SetStatus(text)
		self._status.SetText(text)
		return self
	end

	function Loading:SetTitle(text)
		self._title.SetText(text)
		return self
	end

	function Loading:SetSubtitle(text)
		self._subtitle.SetText(text)
		self._subtitleLabel.Visible = text ~= nil and text ~= ""
		return self
	end

	function Loading:Step(status)
		if #self.Steps == 0 then
			return self:SetProgress(math.min(self._progress + 0.25, 1), status)
		end
		self._index = math.min(self._index + 1, #self.Steps)
		for index, dot in self._dots or {} do
			local active = index <= self._index
			Animation:Play(dot, {
				BackgroundColor3 = Theme.Resolve(active and (self.Config.Color or "Accent") or "Border", "Border"),
				Size = UDim2.fromOffset(active and 8 or 6, active and 8 or 6),
			}, { Duration = 0.18 })
		end
		self:SetProgress(self._index / #self.Steps, status or self.Steps[self._index])
		return self
	end

	function Loading:Run(tasks)
		task.spawn(function()
			for index, entry in tasks or {} do
				if self._done then
					return
				end
				local label = type(entry) == "table" and entry.Title or self.Steps[index]
				self:Step(label)
				local work = type(entry) == "table" and entry.Run or entry
				if type(work) == "function" then
					Utility.SafeCall("Loading step", work, self)
				end
			end
			self:Finish()
		end)
		return self
	end

	function Loading:Auto(duration)
		duration = tonumber(duration) or 1.2
		self.Cleanup:Add(task.spawn(function()
			local steps = math.max(#self.Steps, 1)
			for _ = 1, steps do
				if self._done then
					return
				end
				self:Step()
				task.wait(duration / steps)
			end
			self:Finish()
		end))
		return self
	end

	function Loading:IsFinished()
		return self._done
	end

	function Loading:Wait(timeout)
		local deadline = os.clock() + (tonumber(timeout) or 60)
		while not self._done and os.clock() < deadline do
			task.wait(0.03)
		end
		return self._done
	end

	function Loading:Finish(message)
		if self._done then
			return self
		end
		local minimum = tonumber(self.Config.MinDuration) or 0
		local elapsed = os.clock() - self._opened
		if minimum > elapsed then
			task.delay(minimum - elapsed, function()
				self:Finish(message)
			end)
			return self
		end

		self._done = true
		self:SetProgress(1, message)
		self.Finished:Fire()
		if self._blur then
			Animation:Play(self._blur, { Size = 0 }, { Duration = 0.22 })
		end
		Animation:Play(self._scale, { Scale = self._scale.Scale * 1.04 }, { Duration = 0.22 })
		Animation:Play(self.Root, { GroupTransparency = 1 }, {
			Duration = 0.22,
			Delay = 0.06,
			OnComplete = function()
				self.Cleanup:Clean()
			end,
		})
		task.delay(0.6, function()
			self.Cleanup:Clean()
		end)
		return self
	end

	function Loading:Destroy()
		self._done = true
		self.Cleanup:Clean()
	end

	return Loading
end
