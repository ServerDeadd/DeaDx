return function(import)
	local UserInputService = game:GetService("UserInputService")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Markup = import("Core/Markup")
	local Component = import("Core/Component")
	local Icons = import("Icons/Icon")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")
	local Input = import("Services/Input")

	local Palette = {}
	Palette.__index = Palette

	local KINDS = {
		Tab = { Icon = "layout-dashboard", Verb = "open" },
		SubTab = { Icon = "layout-panel-top", Verb = "open" },
		Section = { Icon = "folder", Verb = "go" },
		Card = { Icon = "square", Verb = "go" },
		Toggle = { Icon = "toggle-left", Verb = "toggle" },
		Button = { Icon = "mouse-pointer-click", Verb = "run" },
		Slider = { Icon = "sliders-horizontal", Verb = "go" },
		Dropdown = { Icon = "list", Verb = "open" },
		MultiDropdown = { Icon = "list-checks", Verb = "open" },
		Input = { Icon = "text-cursor-input", Verb = "edit" },
		Keybind = { Icon = "keyboard", Verb = "go" },
		Colorpicker = { Icon = "palette", Verb = "open" },
		Segmented = { Icon = "columns-3", Verb = "go" },
	}

	local function score(text, needle)
		text = string.lower(text or "")
		if needle == "" then
			return 1
		end
		if text == needle then
			return 120
		end
		if string.sub(text, 1, #needle) == needle then
			return 90
		end
		if string.find(text, needle, 1, true) then
			return 60
		end
		local position, hits = 1, 0
		for index = 1, #needle do
			local char = string.sub(needle, index, index)
			local found = string.find(text, char, position, true)
			if not found then
				return 0
			end
			position = found + 1
			hits += 1
		end
		return 20 + hits
	end

	function Palette.new(window, config)
		config = config or {}
		local self = setmetatable({}, Palette)
		self.Window = window
		self.Config = config
		self.Cleanup = Cleanup.new()
		self.Opened = Signal.new()
		self.Actions = {}
		self._open = false
		self._index = 1
		self._rows = {}
		local cleanup = self.Cleanup
		cleanup:Add(self.Opened)

		local gui = cleanup:Add(Utility.NewScreenGui("DeaDx_Palette", config.DisplayOrder or 2300))
		gui.IgnoreGuiInset = true
		gui.Enabled = false
		self.Gui = gui

		local backdrop = Utility.Create("Frame", {
			Name = "Backdrop",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
			Active = true,
			Parent = gui,
		})
		local catcher = Utility.Create("TextButton", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			Parent = backdrop,
		})
		cleanup:Add(catcher.Activated:Connect(function()
			self:Close()
		end))

		local panel = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Palette",
			Parent = backdrop,
			Fill = "Background",
			Transparency = 0.04,
			Stroke = "Border",
			StrokeTransparency = 0.3,
			Radius = 18,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.fromOffset(config.Width or 460, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = 1,
		})
		self.Panel = panel
		Widgets.Padding(panel, 10, 10)
		Widgets.List(panel, 8)

		local scale = Instance.new("UIScale")
		scale.Scale = 0.97
		scale.Parent = panel
		self._scale = scale

		local bar = Utility.Create("Frame", {
			Name = "Bar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 1,
			Parent = panel,
		})
		Icons.Create(bar, "search", {
			Size = 15,
			Color = "MutedText",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Cleanup = cleanup,
		})
		local box = Widgets.Text(cleanup, {
			Class = "TextBox",
			Name = "Search",
			Parent = bar,
			PlaceholderText = config.Placeholder or "search an option or action...",
			ClearTextOnFocus = false,
			TextSize = 15,
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -36, 1, 0),
		})
		self._box = box

		Widgets.Surface(cleanup, {
			Name = "Rule",
			Parent = panel,
			Fill = "Border",
			Radius = 0,
			BackgroundTransparency = 0.45,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 2,
		})

		local list = Widgets.Scroller(cleanup, {
			Name = "Results",
			Parent = panel,
			Size = UDim2.new(1, 0, 0, config.Height or 232),
			LayoutOrder = 3,
		})
		Widgets.List(list, 3)
		self._list = list

		local hint = Utility.Create("Frame", {
			Name = "Hint",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 4,
			Parent = panel,
		})
		Widgets.Text(cleanup, {
			Parent = hint,
			Text = "<fade:0.35>arrows</fade> move   <fade:0.35>enter</fade> use   <fade:0.35>esc</fade> close",
			Color = "MutedText",
			TextSize = 11,
			Size = UDim2.fromScale(1, 1),
		})

		cleanup:Add(box:GetPropertyChangedSignal("Text"):Connect(function()
			self._index = 1
			self:_Render()
		end))

		cleanup:Add(Input.Began:Connect(function(input, processed)
			if not self._open or processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				self:Close()
			elseif input.KeyCode == Enum.KeyCode.Down then
				self:_Move(1)
			elseif input.KeyCode == Enum.KeyCode.Up then
				self:_Move(-1)
			elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				self:_Activate(self._index)
			end
		end))

		self:SetKey(config.Key or Enum.KeyCode.K, config.Modifier ~= false and (config.Modifier or Enum.KeyCode.LeftControl) or nil)
		self._panel = panel
		return self
	end

	function Palette:SetKey(key, modifier)
		if self._bind then
			self._bind:Destroy()
			self._bind = nil
		end
		self.Key, self.Modifier = key, modifier
		if not key then
			return self
		end
		self._bind = self.Cleanup:Add(Input.AddBind(key, function()
			if modifier and not UserInputService:IsKeyDown(modifier) then
				return
			end
			self:Toggle()
		end, "Command palette"))
		return self
	end

	function Palette:AddAction(config)
		Utility.Check(type(config) == "table" and type(config.Title) == "string", "Palette action", config and config.Title, "Title must be a string.")
		table.insert(self.Actions, config)
		return self
	end

	function Palette:_Entries(needle)
		local out = {}

		for _, action in self.Actions do
			local value = score(action.Title, needle)
			if value > 0 then
				table.insert(out, {
					Score = value + 15,
					Title = action.Title,
					Detail = action.Detail or "action",
					Icon = action.Icon or "zap",
					Run = action.Callback,
				})
			end
		end

		for _, entry in self.Window:Index()._entries do
			local title = Markup.Strip(entry.Title or "")
			local value = score(title, needle)
			if value == 0 then
				value = score(Markup.Strip(entry.Description or ""), needle) * 0.4
			end
			if value > 0 then
				local kind = KINDS[entry.Kind] or { Icon = "dot", Verb = "go" }
				local crumb = { entry.Tab and entry.Tab.Title or "" }
				if entry.SubTab then
					table.insert(crumb, entry.SubTab.Title)
				end
				if entry.Section and entry.Kind ~= "Section" then
					table.insert(crumb, entry.Section.Title)
				end
				local component = entry.Component
				local detail = table.concat(crumb, " / ")
				if component and component.State then
					detail ..= "   " .. Component.Describe(component.State:Get())
				end
				table.insert(out, {
					Score = value,
					Title = title,
					Detail = detail,
					Icon = entry.Component and entry.Component.Config.Icon or kind.Icon,
					Verb = kind.Verb,
					Entry = entry,
					Component = component,
				})
			end
		end

		table.sort(out, function(a, b)
			if a.Score ~= b.Score then
				return a.Score > b.Score
			end
			return a.Title < b.Title
		end)
		local limited = {}
		for index = 1, math.min(#out, self.Config.Limit or 40) do
			limited[index] = out[index]
		end
		return limited
	end

	function Palette:_Render()
		if self._scope then
			self._scope:Clean()
		end
		self._scope = self.Cleanup:Extend()
		local scope = self._scope
		local needle = string.lower((string.gsub(self._box.Text, "^%s*(.-)%s*$", "%1")))
		self._results = self:_Entries(needle)
		table.clear(self._rows)

		if #self._results == 0 then
			scope:Add((Widgets.Text(scope, {
				Parent = self._list,
				Text = "nothing found",
				Color = "MutedText",
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 40),
			})))
			return
		end

		for index, result in self._results do
			local row = Widgets.Surface(scope, {
				Class = "TextButton",
				Parent = self._list,
				Fill = "SecondaryBackground",
				Transparency = 1,
				Radius = 11,
				Size = UDim2.new(1, 0, 0, 42),
				LayoutOrder = index,
			})
			scope:Add(row)
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 11, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				Parent = row,
			})
			Icons.Create(holder, result.Icon, { Size = 16, Color = "MutedText", Cleanup = scope })
			Widgets.Text(scope, {
				Parent = row,
				Text = result.Title,
				Bold = true,
				TextSize = 13,
				Position = UDim2.fromOffset(37, 6),
				Size = UDim2.new(1, -90, 0, 16),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Markup = false,
			})
			Widgets.Text(scope, {
				Parent = row,
				Text = result.Detail,
				Color = "MutedText",
				TextSize = 11,
				Position = UDim2.fromOffset(37, 22),
				Size = UDim2.new(1, -90, 0, 14),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Markup = false,
			})
			local _, verb = Widgets.Text(scope, {
				Parent = row,
				Text = result.Verb or "run",
				Color = "MutedText",
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -11, 0.5, 0),
				Size = UDim2.fromOffset(60, 14),
				Markup = false,
			})
			scope:Add(row.Activated:Connect(function()
				self:_Activate(index)
			end))
			scope:Add(row.MouseEnter:Connect(function()
				self._index = index
				self:_Highlight()
			end))
			self._rows[index] = { Frame = row, Verb = verb }
		end
		self:_Highlight()
	end

	function Palette:_Highlight()
		for index, row in self._rows do
			local active = index == self._index
			Animation:Play(row.Frame, {
				BackgroundTransparency = active and 0.25 or 1,
				BackgroundColor3 = Theme.Get(active and "Hover" or "SecondaryBackground"),
			}, { Duration = 0.1 })
			row.Verb.SetColor(active and "Accent" or "MutedText")
		end
	end

	function Palette:_Move(delta)
		if #self._rows == 0 then
			return
		end
		self._index = (self._index - 1 + delta) % #self._rows + 1
		self:_Highlight()
		local row = self._rows[self._index]
		if row then
			local top = row.Frame.AbsolutePosition.Y - self._list.AbsolutePosition.Y + self._list.CanvasPosition.Y
			local height = self._list.AbsoluteSize.Y
			if top < self._list.CanvasPosition.Y then
				self._list.CanvasPosition = Vector2.new(0, math.max(top - 4, 0))
			elseif top + 42 > self._list.CanvasPosition.Y + height then
				self._list.CanvasPosition = Vector2.new(0, top + 46 - height)
			end
		end
	end

	function Palette:_Activate(index)
		local result = self._results and self._results[index]
		if not result then
			return
		end
		self:Close()
		task.defer(function()
			if result.Run then
				Utility.SafeCall("Palette action", result.Run)
				return
			end
			local component = result.Component
			if component and not component:IsLocked() and component.Enabled then
				if type(component.Fire) == "function" then
					component:Fire()
					return
				end
				if component.State and type(component.State:Get()) == "boolean" then
					component.State:Set(not component.State:Get())
					return
				end
			end
			if result.Entry then
				self.Window:_GoTo(result.Entry)
			end
		end)
	end

	function Palette:IsOpen()
		return self._open
	end

	function Palette:Open()
		if self._open then
			return self
		end
		self._open = true
		self.Gui.Enabled = true
		self._box.Text = ""
		self._index = 1
		self:_Render()
		Animation:Play(self._panel, { GroupTransparency = 0 }, { Duration = 0.14 })
		Animation:Play(self._scale, { Scale = 1 }, { Duration = 0.2, Style = Enum.EasingStyle.Back })
		task.defer(function()
			if self._open then
				self._box:CaptureFocus()
			end
		end)
		self.Opened:Fire()
		return self
	end

	function Palette:Close()
		if not self._open then
			return self
		end
		self._open = false
		self._box:ReleaseFocus()
		Animation:Play(self._scale, { Scale = 0.97 }, { Duration = 0.12 })
		Animation:Play(self._panel, { GroupTransparency = 1 }, {
			Duration = 0.12,
			OnComplete = function()
				if not self._open then
					self.Gui.Enabled = false
				end
			end,
		})
		return self
	end

	function Palette:Toggle()
		if self._open then
			return self:Close()
		end
		return self:Open()
	end

	function Palette:Destroy()
		self._open = false
		self.Cleanup:Clean()
	end

	return Palette
end

