return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Animation = import("Services/Animation")

	local Progress = setmetatable({}, { __index = Component.Base })
	Progress.__index = Progress

	function Progress:_Normalize(value)
		if type(value) ~= "number" or value ~= value then
			return false
		end
		return true, math.clamp(value, 0, 1)
	end

	function Progress:SetProgress(alpha)
		return self:SetValue(alpha)
	end

	function Progress:Increment(amount)
		return self:SetValue((self.State:Get() or 0) + (amount or 0.1))
	end

	function Progress:Complete()
		return self:SetValue(1)
	end

	function Progress:GetRemaining()
		return self._remaining or 0
	end

	function Progress:IsRunning()
		return self._running == true
	end

	function Progress:_Stop()
		self._running = false
		if self._thread then
			pcall(task.cancel, self._thread)
			self._thread = nil
		end
	end

	function Progress:Start(seconds)
		self:_Stop()
		self._total = tonumber(seconds) or self._total or self.Config.Seconds or 60
		self._remaining = self._total
		self:_Tick()
		return self:_Spin()
	end

	function Progress:_Spin()
		if self._running or (self._remaining or 0) <= 0 then
			return self
		end
		self._running = true
		self._thread = task.spawn(function()
			local last = os.clock()
			while self._running and not self._destroyed do
				task.wait(0.05)
				local now = os.clock()
				self._remaining = math.max(self._remaining - (now - last), 0)
				last = now
				self:_Tick()
				if self._remaining <= 0 then
					self._running = false
					self.Finished:Fire()
					Utility.SafeCall("Progress " .. tostring(self.Id), self.Config.OnFinish)
					if self.Config.Loop then
						task.wait(0.2)
						self:Start(self._total)
					end
					break
				end
			end
		end)
		self.Cleanup:Add(self._thread)
		return self
	end

	function Progress:Pause()
		self._running = false
		if self._thread then
			pcall(task.cancel, self._thread)
			self._thread = nil
		end
		return self
	end

	function Progress:Resume()
		return self:_Spin()
	end

	function Progress:Toggle()
		if self._running then
			return self:Pause()
		end
		if (self._remaining or 0) <= 0 then
			return self:Start(self._total)
		end
		return self:_Spin()
	end

	function Progress:Stop()
		self:_Stop()
		self._remaining = 0
		self:_Tick()
		return self
	end

	function Progress:Reset()
		self:_Stop()
		self._remaining = self._total or self.Config.Seconds or 0
		self:_Tick()
		return self
	end

	function Progress:AddTime(seconds)
		self._total = (self._total or 0) + seconds
		self._remaining = math.max((self._remaining or 0) + seconds, 0)
		self:_Tick()
		return self
	end

	function Progress:_Tick()
		local total = self._total or 1
		local alpha = total > 0 and math.clamp(self._remaining / total, 0, 1) or 0
		if self.Config.Fill == true then
			alpha = 1 - alpha
		end
		self._apply(alpha, false)
		if self._label then
			self._label.SetText(self:_Format(alpha))
		end
	end

	function Progress:_Format(alpha)
		local config = self.Config
		if type(config.Format) == "function" then
			local ok, text = pcall(config.Format, alpha, self._remaining or 0)
			return ok and tostring(text) or ""
		end
		if self._countdown then
			return Component.Clock(self._remaining or 0)
		end
		return string.format(config.Format or "%d%%", alpha * 100)
	end

	function Progress:SetIndeterminate(value)
		self._loop = value == true
		if not self._loop then
			Animation:Cancel(self._fill)
			self._fill.Position = UDim2.new()
			self._apply(self.State:Get(), true)
			return self
		end
		task.spawn(function()
			while self._loop and not self._destroyed do
				self._fill.Position = UDim2.fromScale(-0.35, 0)
				self._fill.Size = UDim2.fromScale(0.35, 1)
				Animation:Play(self._fill, { Position = UDim2.fromScale(1, 0) }, {
					Duration = 0.9,
					Style = Enum.EasingStyle.Sine,
					Direction = Enum.EasingDirection.InOut,
				})
				task.wait(1)
			end
		end)
		return self
	end

	return function(ctx, id, config)
		local countdown = config.Mode == "Countdown" or config.Seconds ~= nil
		local self = Component.New(ctx, Progress, countdown and "Countdown" or "Progress", id, config, {
			RightWidth = config.Width or 190,
			RightHeight = 20,
		})
		local cleanup = self.Cleanup
		local accent = config.Color or "Accent"
		local showValue = config.ShowValue ~= false
		self._countdown = countdown
		self.Finished = Signal.new()
		cleanup:Add(self.Finished)

		local label
		if showValue then
			local _, handle = Widgets.Text(cleanup, {
				Parent = self.Right,
				Text = countdown and "00:00" or "0%",
				Color = config.ValueColor or "MutedText",
				Bold = true,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(countdown and 46 or 38, 14),
				Markup = false,
			})
			label = handle
			self._label = handle
		end

		local reserved = showValue and (countdown and 52 or 44) or 0
		local track = Widgets.Surface(cleanup, {
			Name = "Track",
			Parent = self.Right,
			Fill = "TertiaryBackground",
			Transparency = "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.6,
			Radius = "Full",
			ClipsDescendants = true,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, -reserved, 0, config.Thickness or 6),
		})
		local fill = Widgets.Surface(cleanup, {
			Name = "Fill",
			Parent = track,
			Fill = accent,
			Radius = "Full",
			Size = UDim2.fromScale(0, 1),
		})
		self._track, self._fill = track, fill

		local stops = Widgets.Stops(config.Gradient)
		if stops then
			Utility.Create("UIGradient", { Color = stops, Parent = fill })
		end

		if config.Glow ~= false then
			local glow = Widgets.Surface(cleanup, {
				Name = "Head",
				Parent = fill,
				Fill = "Text",
				BackgroundTransparency = 0.75,
				Radius = "Full",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0, 10, 1, 0),
			})
			self._glow = glow
		end

		local function apply(value, animate)
			if self._loop then
				return
			end
			local size = UDim2.fromScale(math.clamp(value or 0, 0, 1), 1)
			if animate then
				Animation:Play(fill, { Size = size }, { Duration = 0.3, Style = Enum.EasingStyle.Quint })
			else
				fill.Size = size
			end
			if self._glow then
				self._glow.Visible = (value or 0) > 0.02
			end
		end
		self._apply = apply

		local function render(value, animate)
			if self._countdown then
				return
			end
			apply(value, animate)
			if label then
				label.SetText(self:_Format(value))
			end
		end
		self._render = render
		Component.BindValue(self, id, math.clamp(config.Default or 0, 0, 1), render)

		function self:SetColor(color)
			fill.BackgroundColor3 = Theme.Resolve(color, "Accent")
			return self
		end

		if countdown then
			self._total = config.Seconds or 60
			self._remaining = self._total
			self:_Tick()
			if config.AutoStart ~= false then
				self:Start(self._total)
			end
		end
		if config.Indeterminate then
			self:SetIndeterminate(true)
		end
		return self
	end
end
