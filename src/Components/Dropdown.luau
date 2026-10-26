return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Markup = import("Core/Markup")
	local Editable = import("Core/Editable")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")
	local Capabilities = import("Core/Capabilities")

	local Dropdown = setmetatable({}, { __index = Component.Base })
	Dropdown.__index = Dropdown

	local ROW = Capabilities.Mobile and 34 or 28

	function Dropdown:_Normalize(value)
		if self.Multi then
			if type(value) ~= "table" then
				return false
			end
			local isArray = value[1] ~= nil
			local map = {}
			for _, name in self.Values do
				if isArray then
					map[name] = table.find(value, name) ~= nil
				else
					map[name] = value[name] == true
				end
			end
			return true, map
		end
		if value == nil then
			return true, nil
		end
		if type(value) == "number" then
			local name = self.Values[value]
			if name == nil then
				return false
			end
			return true, name
		end
		if type(value) == "string" and table.find(self.Values, value) then
			return true, value
		end
		return false
	end

	function Dropdown:_Display(value)
		if self.Multi then
			local picked = {}
			for _, name in self.Values do
				if value and value[name] then
					table.insert(picked, self:GetLabel(name))
				end
			end
			if #picked == 0 then
				return self.Config.Placeholder or "None"
			end
			if #picked > 2 then
				return string.format("%d selected", #picked)
			end
			return table.concat(picked, ", ")
		end
		if value == nil then
			return self.Config.Placeholder or "None"
		end
		return self:GetLabel(value)
	end

	function Dropdown:GetLabel(name)
		local meta = self.Meta[name]
		return meta and meta.Title or name
	end

	function Dropdown:GetValues()
		return table.clone(self.Values)
	end

	function Dropdown:GetSelected()
		local value = self.State:Get()
		if not self.Multi then
			return value
		end
		local picked = {}
		for _, name in self.Values do
			if value and value[name] then
				table.insert(picked, name)
			end
		end
		return picked
	end

	function Dropdown:_Commit()
		local valid, normalized = self:_Normalize(self.State:Get())
		if not valid then
			if self.Multi then
				_, normalized = self:_Normalize({})
			else
				normalized = self.Values[1]
			end
		end
		self.State:Set(normalized)
		self._render(self.State:Get())
		self.ValuesChanged:Fire(self:GetValues())
		Utility.SafeCall("Dropdown " .. tostring(self.Id), self.Config.OnValuesChanged, self:GetValues())
		if self._rebuild then
			self._rebuild()
		end
	end

	function Dropdown:SetValues(values)
		Utility.Check(type(values) == "table", self.Kind, self.Id, "Values must be an array.")
		local names, meta = {}, {}
		for _, entry in values do
			if type(entry) == "string" then
				table.insert(names, entry)
			elseif type(entry) == "table" then
				local name = entry.Value or entry.Name or entry.Title
				Utility.Check(type(name) == "string", self.Kind, self.Id, "Each value needs a string Value or Title.")
				table.insert(names, name)
				meta[name] = { Title = entry.Title or name, Icon = entry.Icon, Color = entry.Color }
			else
				Utility.Fail(self.Kind, self.Id, "Values must be strings or tables.")
			end
		end
		for name, icon in self.Config.Icons or {} do
			meta[name] = meta[name] or {}
			meta[name].Icon = meta[name].Icon or icon
		end
		for name, color in self.Config.Colors or {} do
			meta[name] = meta[name] or {}
			meta[name].Color = meta[name].Color or color
		end
		self.Values, self.Meta = names, meta
		self:_Commit()
		return self
	end

	function Dropdown:AddValue(name, options)
		Utility.Check(type(name) == "string" and name ~= "", self.Kind, self.Id, "Value must be a non-empty string.")
		if table.find(self.Values, name) then
			return self
		end
		table.insert(self.Values, name)
		if type(options) == "table" then
			self.Meta[name] = { Title = options.Title or name, Icon = options.Icon, Color = options.Color }
		end
		if self.Multi then
			local value = table.clone(self.State:Get() or {})
			value[name] = false
			self.State:Set(value, true)
		end
		self:_Commit()
		Utility.SafeCall("Dropdown " .. tostring(self.Id), self.Config.OnAdd, name)
		return self
	end

	function Dropdown:RemoveValue(name)
		local index = table.find(self.Values, name)
		if not index then
			return self
		end
		table.remove(self.Values, index)
		self.Meta[name] = nil
		if self.Multi then
			local value = table.clone(self.State:Get() or {})
			value[name] = nil
			self.State:Set(value, true)
		elseif self.State:Get() == name then
			self.State:Set(self.Values[math.min(index, #self.Values)], true)
		end
		self:_Commit()
		Utility.SafeCall("Dropdown " .. tostring(self.Id), self.Config.OnRemove, name)
		return self
	end

	function Dropdown:RenameValue(old, new)
		Utility.Check(type(new) == "string" and new ~= "", self.Kind, self.Id, "New value must be a non-empty string.")
		local index = table.find(self.Values, old)
		if not index or old == new then
			return self
		end
		if table.find(self.Values, new) then
			return self
		end
		self.Values[index] = new
		local meta = self.Meta[old]
		self.Meta[old] = nil
		if meta then
			if meta.Title == old then
				meta.Title = new
			end
			self.Meta[new] = meta
		end
		if self.Multi then
			local value = table.clone(self.State:Get() or {})
			value[new] = value[old] == true
			value[old] = nil
			self.State:Set(value, true)
		elseif self.State:Get() == old then
			self.State:Set(new, true)
		end
		self:_Commit()
		Utility.SafeCall("Dropdown " .. tostring(self.Id), self.Config.OnRename, old, new)
		return self
	end

	function Dropdown:SetOption(name, options)
		if not table.find(self.Values, name) or type(options) ~= "table" then
			return self
		end
		local meta = self.Meta[name] or {}
		meta.Title = options.Title or meta.Title or name
		meta.Icon = options.Icon ~= nil and options.Icon or meta.Icon
		meta.Color = options.Color ~= nil and options.Color or meta.Color
		self.Meta[name] = meta
		self._render(self.State:Get())
		if self._rebuild then
			self._rebuild()
		end
		return self
	end

	function Dropdown:Clear()
		self.Values = {}
		self.Meta = {}
		self:_Commit()
		return self
	end

	function Dropdown:SelectAll()
		if not self.Multi then
			return self
		end
		local value = {}
		for _, name in self.Values do
			value[name] = true
		end
		self.State:Set(value)
		return self
	end

	function Dropdown:SelectNone()
		if not self.Multi then
			self.State:Set(nil)
			return self
		end
		self.State:Set({})
		return self
	end

	function Dropdown:Close()
		if self._popup then
			self._popup.Close()
		end
		return self
	end

	function Dropdown:Open()
		self:_Open()
		return self
	end

	function Dropdown:_Open()
		if self._destroyed or not self.Enabled or self._popup then
			return
		end
		local config = self.Config
		local button = self._button
		local editable = config.Editable == true
		local creatable = config.Creatable == true
		local removable = config.Removable == true or (editable and config.Removable ~= false)
		local searchable = config.Searchable == true or (config.Searchable ~= false and #self.Values > 8)
		local maxVisible = config.MaxVisible or 7

		local width = math.max(config.PopupWidth or 190, button.AbsoluteSize.X / Theme.Scale)
		local headerHeight = searchable and 34 or 0
		local footerHeight = creatable and 32 or 0

		local function measure(count)
			local rows = math.clamp(count, 1, maxVisible) * ROW + 10
			return math.min(rows + headerHeight + footerHeight, 320)
		end

		local popup = self.Window:OpenPopup(button, width, measure(#self.Values))
		self._popup = popup
		local cleanup = popup.Cleanup
		if self._chevron then
			Animation:Play(self._chevron.Instance, { Rotation = 180 }, { Duration = 0.18 })
		end
		cleanup:Add(popup.Closed:Connect(function()
			if self._popup == popup then
				self._popup = nil
			end
			self._rebuild = nil
			self._filter = nil
			if self._chevron and self._chevron.Instance.Parent then
				Animation:Play(self._chevron.Instance, { Rotation = 0 }, { Duration = 0.18 })
			end
		end))

		local filterText = ""
		if searchable then
			local _, filterBox = Widgets.Field(cleanup, {
				Name = "Filter",
				Parent = popup.Frame,
				Radius = 8,
				Placeholder = "Filter...",
				Position = UDim2.fromOffset(5, 5),
				Size = UDim2.new(1, -10, 0, 24),
			})
			cleanup:Add(filterBox:GetPropertyChangedSignal("Text"):Connect(function()
				filterText = string.lower(filterBox.Text)
				if self._rebuild then
					self._rebuild()
				end
			end))
		end

		local list = Widgets.Scroller(cleanup, {
			Name = "Options",
			Parent = popup.Frame,
			Position = UDim2.fromOffset(0, headerHeight),
			Size = UDim2.new(1, 0, 1, -(headerHeight + footerHeight)),
		})
		Widgets.Padding(list, 5)
		Widgets.List(list, 2)

		local rows = cleanup:Extend()

		local function selected(name)
			local value = self.State:Get()
			if self.Multi then
				return value ~= nil and value[name] == true
			end
			return value == name
		end

		local function build()
			rows:Clean()
			rows = cleanup:Extend()
			local shown = 0
			for index, name in self.Values do
				local label = self:GetLabel(name)
				if filterText == "" or string.find(string.lower(Markup.Strip(label)), filterText, 1, true) then
					shown += 1
					local meta = self.Meta[name] or {}
					local row = Widgets.Surface(rows, {
						Class = "TextButton",
						Name = "Option",
						Parent = list,
						Fill = "SecondaryBackground",
						Transparency = 1,
						Radius = 8,
						Size = UDim2.new(1, 0, 0, ROW - 2),
						LayoutOrder = index,
					})
					rows:Add(row)

					local inset = 9
					if meta.Icon then
						local holder = Utility.Create("Frame", {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(8, (ROW - 2) / 2 - 7),
							Size = UDim2.fromOffset(14, 14),
							Parent = row,
						})
						Icons.Create(holder, meta.Icon, {
							Size = 14,
							Color = meta.Color or "MutedText",
							Cleanup = rows,
						})
						inset = 29
					end

					local trail = 28
					if editable then
						trail += 22
					end
					if removable then
						trail += 22
					end

					local optionLabel, optionText = Widgets.Text(rows, {
						Class = editable and "TextBox" or "TextLabel",
						Parent = row,
						Text = label,
						Color = meta.Color,
						Position = UDim2.fromOffset(inset, 0),
						Size = UDim2.new(1, -(inset + trail), 1, 0),
						TextTruncate = Enum.TextTruncate.AtEnd,
						Markup = not editable,
					})

					local check = Icons.Create(row, config.CheckIcon or "check", {
						Size = 13,
						Color = config.CheckColor or "Accent",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -9, 0.5, 0),
						Cleanup = rows,
					})
					check.Instance.Visible = selected(name)
					check.Instance.ZIndex = 2

					local actions = {}
					local offset = 28
					if editable then
						local pencil = Widgets.Chip(rows, {
							Name = "Rename",
							Parent = row,
							Radius = "Full",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -offset, 0.5, 0),
							Size = UDim2.fromOffset(18, 18),
							ZIndex = 3,
							Visible = false,
						})
						Icons.Create(pencil, "pencil", {
							Size = 10,
							Position = UDim2.fromOffset(4, 4),
							Cleanup = rows,
						})
						table.insert(actions, pencil)
						offset += 22

						local editor = Editable.Attach(rows, optionLabel, optionText, {
							Label = "Dropdown option",
							Color = meta.Color,
							Trigger = pencil,
							Source = function()
								return self:GetLabel(name)
							end,
							Validate = function(value)
								return value ~= "" and (value == name or table.find(self.Values, value) == nil)
							end,
							OnCommit = function(value)
								self:RenameValue(name, value)
							end,
						})
						rows:Add(function()
							editor.Cancel()
						end)
					end
					if removable then
						local trash = Widgets.Chip(rows, {
							Name = "Remove",
							Parent = row,
							Radius = "Full",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -offset, 0.5, 0),
							Size = UDim2.fromOffset(18, 18),
							ZIndex = 3,
							Visible = false,
						})
						Icons.Create(trash, "trash-2", {
							Size = 10,
							Color = "Error",
							Position = UDim2.fromOffset(4, 4),
							Cleanup = rows,
						})
						table.insert(actions, trash)
						rows:Add(trash.Activated:Connect(function()
							self:RemoveValue(name)
						end))
					end

					if #actions > 0 then
						rows:Add(row.MouseEnter:Connect(function()
							for _, action in actions do
								action.Visible = true
							end
							check.Instance.Visible = false
						end))
						rows:Add(row.MouseLeave:Connect(function()
							for _, action in actions do
								action.Visible = false
							end
							check.Instance.Visible = selected(name)
						end))
					end

					Widgets.Interactive(rows, row, row, { Alpha = { 1, 0.6, 0.45 } })
					rows:Add(row.Activated:Connect(function()
						if editable and optionLabel:IsFocused() then
							return
						end
						if self.Multi then
							local value = table.clone(self.State:Get() or {})
							value[name] = not value[name]
							self.State:Set(value)
						else
							self.State:Set(name)
							popup.Close()
						end
					end))
				end
			end

			if shown == 0 then
				rows:Add((Widgets.Text(rows, {
					Parent = list,
					Text = #self.Values == 0 and "No options" or "No matches",
					Color = "MutedText",
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, ROW),
					LayoutOrder = 1,
				})))
				shown = 1
			end
			popup.Resize(measure(shown))
		end
		self._rebuild = build
		build()

		if creatable then
			local addRow = Widgets.Surface(cleanup, {
				Class = "TextButton",
				Name = "Add",
				Parent = popup.Frame,
				Fill = "TertiaryBackground",
				Transparency = "ElementTransparency",
				Radius = 8,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -5),
				Size = UDim2.new(1, -10, 0, 24),
			})
			Icons.Create(addRow, "plus", {
				Size = 12,
				Color = "Accent",
				Position = UDim2.fromOffset(8, 6),
				Cleanup = cleanup,
			})
			local addLabel, addText = Widgets.Text(cleanup, {
				Class = "TextBox",
				Parent = addRow,
				Text = config.AddText or "Add option",
				Color = "MutedText",
				TextSize = 12,
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(1, -34, 1, 0),
				Markup = false,
			})
			Widgets.Interactive(cleanup, addRow, addRow, { Base = "TertiaryBackground" })
			local adding = Editable.Attach(cleanup, addLabel, addText, {
				Label = "Dropdown add",
				Color = "MutedText",
				Trigger = addRow,
				Source = function()
					return ""
				end,
				Validate = function(value)
					return value ~= "" and table.find(self.Values, value) == nil
				end,
				OnCommit = function(value)
					self:AddValue(value)
					addText.SetText(config.AddText or "Add option")
				end,
			})
			cleanup:Add(function()
				adding.Cancel()
			end)
		end
	end

	return function(ctx, id, config)
		local values = config.Values or {}
		Utility.Check(type(values) == "table", "Dropdown", id, "Values must be an array.")
		local multi = config.Multi == true
		local self = Component.New(ctx, Dropdown, multi and "MultiDropdown" or "Dropdown", id, config, {
			RightWidth = config.Width or 172,
			RightHeight = 26,
		})
		self.Multi = multi
		self.Values, self.Meta = {}, {}
		self.ValuesChanged = Signal.new()
		local cleanup = self.Cleanup
		cleanup:Add(self.ValuesChanged)

		local names = {}
		for _, entry in values do
			if type(entry) == "string" then
				table.insert(names, entry)
			elseif type(entry) == "table" then
				local name = entry.Value or entry.Name or entry.Title
				Utility.Check(type(name) == "string", "Dropdown", id, "Each value needs a string Value or Title.")
				table.insert(names, name)
				self.Meta[name] = { Title = entry.Title or name, Icon = entry.Icon, Color = entry.Color }
			else
				Utility.Fail("Dropdown", id, "Values must be strings or tables.")
			end
		end
		for name, icon in config.Icons or {} do
			self.Meta[name] = self.Meta[name] or {}
			self.Meta[name].Icon = self.Meta[name].Icon or icon
		end
		for name, color in config.Colors or {} do
			self.Meta[name] = self.Meta[name] or {}
			self.Meta[name].Color = self.Meta[name].Color or color
		end
		self.Values = names

		local valid, default = self:_Normalize(multi and (config.Default or {}) or config.Default)
		Utility.Check(
			valid,
			self.Kind,
			id,
			multi and "Default must be a table ({ Name = true } or an array of names)."
				or "Default must be a value (or index) from Values."
		)

		local button, buttonStroke = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "Select",
			Parent = self.Right,
			Fill = "TertiaryBackground",
			Transparency = "ElementTransparency",
			Stroke = "Border",
			StrokeTransparency = 0.45,
			Radius = 10,
			Size = UDim2.fromScale(1, 1),
		})
		self._button, self._buttonStroke = button, buttonStroke
		local _, label = Widgets.Text(cleanup, {
			Parent = button,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -32, 1, 0),
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		self._label = label
		self._chevron = Icons.Create(button, "chevron-down", {
			Size = 13,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Cleanup = cleanup,
		})
		Widgets.Interactive(cleanup, button, button, { Base = "TertiaryBackground" })

		self._render = function(value)
			label.SetText(self:_Display(value))
		end
		Component.BindValue(self, id, default, function(value)
			self._render(value)
		end)
		cleanup:Add(button.Activated:Connect(function()
			if self._popup then
				self:Close()
				return
			end
			self:_Open()
		end))
		cleanup:Add(function()
			if self._popup then
				self._popup.Close()
			end
		end)
		return self
	end
end
