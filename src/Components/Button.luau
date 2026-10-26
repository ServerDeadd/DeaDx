return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Button = setmetatable({}, { __index = Component.Base })
	Button.__index = Button

	function Button:Fire(skipCooldown)
		if self._destroyed or not self.Enabled then
			return self
		end
		if self:IsLocked() then
			self:Shake()
			return self
		end
		Utility.SafeCall("Button " .. tostring(self.Config.Title), self.Config.Callback)
		self.Changed:Fire()
		local cooldown = tonumber(self.Config.Cooldown)
		if cooldown and cooldown > 0 and not skipCooldown then
			self:Lock(cooldown)
		end
		return self
	end

	return function(ctx, id, config)
		Utility.Check(
			config.Callback == nil or type(config.Callback) == "function",
			"Button",
			config.Title,
			"Callback must be a function."
		)
		local self = Component.New(ctx, Button, "Button", id, config, { RightWidth = 16, RightHeight = 16 })
		local cleanup = self.Cleanup
		self._arrow = Icons.Create(self.Right, config.Arrow or "chevron-right", {
			Size = 16,
			Color = config.ArrowColor or "MutedText",
			Cleanup = cleanup,
		})
		local hit = Utility.Create("TextButton", {
			Name = "Hit",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = self.Frame,
		})
		Widgets.Interactive(cleanup, self.Frame, hit, {})
		cleanup:Add(hit.Activated:Connect(function()
			if self.Enabled and not self:IsLocked() then
				Widgets.Pulse(self._arrow.Instance, 0.6, 0.35)
				Animation:Play(self._arrow.Instance, { Position = UDim2.fromOffset(4, 0) }, { Duration = 0.12 })
				task.delay(0.12, function()
					if self._arrow.Instance.Parent then
						Animation:Play(self._arrow.Instance, { Position = UDim2.new() }, { Duration = 0.18 })
					end
				end)
			end
			self:Fire()
		end))
		return self
	end
end
