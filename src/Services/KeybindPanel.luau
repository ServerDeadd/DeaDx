return function(import)
	local Utility = import("Core/Utility")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Markup = import("Core/Markup")
	local Icons = import("Icons/Icon")
	local Input = import("Services/Input")
	local Animation = import("Services/Animation")

	local KeybindPanel = {}

	local function label(key)
		if typeof(key) ~= "EnumItem" or key == Enum.KeyCode.Unknown then
			return "unbound"
		end
		if key.EnumType == Enum.UserInputType then
			return "Mouse " .. string.gsub(key.Name, "MouseButton", "")
		end
		return key.Name
	end

	function KeybindPanel.Collect(window)
		local out = {}
		for id, component in window.Options do
			if component.Kind == "Keybind" and component.State then
				table.insert(out, {
					Id = id,
					Title = component:GetTitle(),
					Key = component.State:Get(),
					Mode = component.Mode,
					Component = component,
					Kind = "Keybind",
				})
			elseif component.BoundKey then
				table.insert(out, {
					Id = id,
					Title = component:GetTitle(),
					Key = component.BoundKey,
					Component = component,
					Kind = component.Kind,
				})
			end
		end
		table.sort(out, function(a, b)
			return string.lower(a.Title) < string.lower(b.Title)
		end)
		return out
	end

	function KeybindPanel.Build(container, config)
		config = config or {}
		Utility.Check(
			type(container) == "table" and container.Container,
			"KeybindPanel",
			"?",
			"Needs a tab, section or card."
		)
		local window = container.Window
		local cleanup = container.Cleanup:Extend()

		local frame = Widgets.Surface(cleanup, {
			Name = "Keybinds",
			Parent = container.Container,
			Fill = "SecondaryBackground",
			Transparency = "ComponentTransparency",
			Stroke = "Border",
			StrokeTransparency = "ComponentStrokeTransparency",
			Radius = 14,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = container.NextOrder(),
		})
		cleanup:Add(frame)
		Widgets.Padding(frame, 12, 11)
		Widgets.List(frame, 7)

		local header = Utility.Create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = frame,
		})
		local holder = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			Parent = header,
		})
		Icons.Create(holder, config.Icon or "keyboard", {
			Size = 14,
			Color = config.IconColor or "Accent",
			Cleanup = cleanup,
		})
		Widgets.Text(cleanup, {
			Parent = header,
			Text = config.Title or "Keybinds",
			Bold = true,
			Position = UDim2.fromOffset(21, 0),
			Size = UDim2.new(1, -60, 1, 0),
		})
		local _, count = Widgets.Text(cleanup, {
			Parent = header,
			Text = "0",
			Color = "MutedText",
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(40, 18),
			Markup = false,
		})

		local body = Utility.Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Parent = frame,
		})
		Widgets.List(body, 4)

		local rows = cleanup:Extend()
		local handle = {}

		function handle:Refresh()
			rows:Clean()
			rows = cleanup:Extend()
			local entries = KeybindPanel.Collect(window)
			count.SetText(tostring(#entries))

			if #entries == 0 then
				rows:Add((Widgets.Text(rows, {
					Parent = body,
					Text = config.Empty or "no keys bound yet",
					Color = "MutedText",
					TextSize = 11,
					Size = UDim2.new(1, 0, 0, 24),
				})))
				return
			end

			for index, entry in entries do
				local row = Widgets.Surface(rows, {
					Class = "TextButton",
					Parent = body,
					Fill = "TertiaryBackground",
					Transparency = "ElementTransparency",
					Radius = 10,
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = index,
				})
				rows:Add(row)
				Widgets.Text(rows, {
					Parent = row,
					Text = Markup.Strip(entry.Title),
					TextSize = 12,
					Position = UDim2.fromOffset(11, 0),
					Size = UDim2.new(1, -108, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Markup = false,
				})
				if entry.Mode and entry.Mode ~= "Press" then
					Widgets.Text(rows, {
						Parent = row,
						Text = entry.Mode,
						Color = "MutedText",
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -78, 0.5, 0),
						Size = UDim2.fromOffset(44, 14),
						Markup = false,
					})
				end
				local chip = Widgets.Surface(rows, {
					Parent = row,
					Fill = "SecondaryBackground",
					Stroke = "Border",
					StrokeTransparency = 0.4,
					Radius = 8,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(66, 20),
				})
				local _, keyText = Widgets.Text(rows, {
					Parent = chip,
					Text = label(entry.Key),
					Color = entry.Key and entry.Key ~= Enum.KeyCode.Unknown and "Text" or "MutedText",
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Markup = false,
				})
				Widgets.Interactive(rows, row, row, { Base = "TertiaryBackground" })

				local capturing = false
				local function rebind()
					if capturing then
						return
					end
					capturing = true
					keyText.SetText("...")
					Widgets.Pulse(chip, 0.85, 0.3)
					local chipStroke = chip:FindFirstChildOfClass("UIStroke")
					Widgets.Glow(chipStroke, "Accent", 6)
					local cancel = Input.Capture(function(key, cancelled)
						capturing = false
						if cancelled then
							keyText.SetText(label(entry.Key))
							return
						end
						local chosen = key ~= Enum.KeyCode.Unknown and key or nil
						if entry.Kind == "Keybind" then
							entry.Component:SetValue(chosen or Enum.KeyCode.Unknown)
						else
							entry.Component:Bind(chosen)
						end
						handle:Refresh()
					end)
					rows:Add(cancel)
				end

				rows:Add(row.Activated:Connect(rebind))
				rows:Add(row.MouseButton2Click:Connect(function()
					if entry.Kind == "Keybind" then
						entry.Component:SetValue(Enum.KeyCode.Unknown)
					else
						entry.Component:Bind(nil)
					end
					handle:Refresh()
				end))
			end
		end

		Widgets.Text(cleanup, {
			Parent = frame,
			Text = "<fade:0.4>click to rebind, right click to clear</fade>",
			Color = "MutedText",
			TextSize = 10,
			Size = UDim2.new(1, 0, 0, 12),
			LayoutOrder = 3,
		})

		handle:Refresh()
		handle.Frame = frame
		function handle:Destroy()
			cleanup:Clean()
		end
		return handle
	end

	return KeybindPanel
end
