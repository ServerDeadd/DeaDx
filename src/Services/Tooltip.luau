return function(import)
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Animation = import("Services/Animation")
	local Input = import("Services/Input")
	local Cleanup = import("Services/Cleanup")

	local Tooltip = { Delay = 0.4 }

	local root, gui, frame, text

	local function ensure()
		if gui and gui.Parent then
			return
		end
		root = Cleanup.new()
		gui = root:Add(Utility.NewScreenGui("DeaDx_Tooltip", 2000))
		frame = Widgets.Surface(root, {
			Class = "CanvasGroup",
			Name = "Tooltip",
			Parent = gui,
			Fill = "SecondaryBackground",
			Stroke = "Border",
			Radius = 8,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),
			GroupTransparency = 1,
			Visible = false,
		})
		pcall(function()
			frame.Interactable = false
		end)
		Widgets.Padding(frame, 9, 6)
		local _, handle = Widgets.Text(root, {
			Parent = frame,
			TextSize = 12,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),
			TextWrapped = false,
		})
		text = handle
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		Theme.BindScale(scale, root)
	end

	local function place(override)
		if not frame then
			return
		end
		local point = override or Input.GetPointer()
		local viewport = gui.AbsoluteSize
		local size = frame.AbsoluteSize
		local x = math.clamp(point.X + 14, 4, math.max(4, viewport.X - size.X - 4))
		local y = math.clamp(point.Y + 18, 4, math.max(4, viewport.Y - size.Y - 4))
		frame.Position = UDim2.fromOffset(x, y)
	end

	function Tooltip.Attach(target, content, cleanup)
		Input.Init()
		local handle = { Text = content }
		local hovering = false
		local ticket = 0
		local shown = false
		local connections = {}

		local function hide()
			if shown and frame then
				shown = false
				Animation:Play(frame, { GroupTransparency = 1 }, { Duration = 0.08 })
				task.delay(0.12, function()
					if not shown and frame then
						frame.Visible = false
					end
				end)
			end
		end

		local function show(point)
			if type(handle.Text) ~= "string" or handle.Text == "" then
				return
			end
			ensure()
			text.SetText(handle.Text)
			frame.Visible = true
			shown = true
			place(point)
			Animation:Play(frame, { GroupTransparency = 0 }, { Duration = 0.1 })
		end

		table.insert(connections, target.MouseEnter:Connect(function()
			hovering = true
			ticket += 1
			local mine = ticket
			task.delay(Tooltip.Delay, function()
				if hovering and mine == ticket then
					show()
				end
			end)
		end))
		table.insert(connections, target.MouseLeave:Connect(function()
			hovering = false
			ticket += 1
			hide()
		end))
		table.insert(connections, target.MouseMoved:Connect(function()
			if shown then
				place()
			end
		end))
		table.insert(connections, target.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			ticket += 1
			local mine = ticket
			task.delay(Tooltip.Delay, function()
				if mine == ticket then
					show(input.Position)
				end
			end)
		end))
		table.insert(connections, target.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				ticket += 1
				hide()
			end
		end))

		function handle:Destroy()
			hovering = false
			ticket += 1
			hide()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end

		if cleanup then
			cleanup:Add(handle)
		end
		return handle
	end

	function Tooltip.Reset()
		if root then
			root:Clean()
		end
		root, gui, frame, text = nil, nil, nil, nil
	end

	return Tooltip
end
