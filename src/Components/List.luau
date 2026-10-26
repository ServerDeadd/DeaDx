return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Widgets = import("Core/Widgets")
	local Editable = import("Core/Editable")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local List = setmetatable({}, { __index = Component.Base })
	List.__index = List

	function List:_Normalize(value)
		if type(value) ~= "table" then
			return false
		end
		local out = {}
		for _, entry in value do
			if type(entry) == "string" then
				table.insert(out, entry)
			end
		end
		return true, out
	end

	function List:SetTitle(text)
		self._title.SetText(text)
		return self
	end

	function List:GetItems()
		return table.clone(self.State:Get() or {})
	end

	function List:Has(item)
		return table.find(self.State:Get() or {}, item) ~= nil
	end

	function List:Add(item)
		if type(item) ~= "string" or item == "" then
			return self
		end
		local items = self:GetItems()
		if table.find(items, item) and not self.Config.Duplicates then
			return self
		end
		table.insert(items, item)
		self.State:Set(items)
		Utility.SafeCall("List " .. tostring(self.Id), self.Config.OnAdd, item)
		return self
	end

	function List:Remove(item)
		local items = self:GetItems()
		local index = type(item) == "number" and item or table.find(items, item)
		if not index then
			return self
		end
		local removed = table.remove(items, index)
		self.State:Set(items)
		Utility.SafeCall("List " .. tostring(self.Id), self.Config.OnRemove, removed)
		return self
	end

	function List:Rename(old, new)
		local items = self:GetItems()
		local index = table.find(items, old)
		if not index or type(new) ~= "string" or new == "" or old == new then
			return self
		end
		items[index] = new
		self.State:Set(items)
		Utility.SafeCall("List " .. tostring(self.Id), self.Config.OnRename, old, new)
		return self
	end

	function List:Move(item, offset)
		local items = self:GetItems()
		local index = table.find(items, item)
		if not index then
			return self
		end
		local target = math.clamp(index + offset, 1, #items)
		if target == index then
			return self
		end
		table.remove(items, index)
		table.insert(items, target, item)
		self.State:Set(items)
		return self
	end

	function List:Clear()
		self.State:Set({})
		return self
	end

	return function(ctx, id, config)
		local self = Component.NewBare(ctx, List, "List", id, config)
		local cleanup = self.Cleanup
		self.ItemsChanged = Signal.new()
		cleanup:Add(self.ItemsChanged)

		local frame = Widgets.Surface(cleanup, {
			Name = "List",
			Parent = ctx.Parent,
			Fill = "SecondaryBackground",
			Transparency = "ComponentTransparency",
			Stroke = "Border",
			StrokeTransparency = "ComponentStrokeTransparency",
			Radius = 14,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = ctx.Order(),
		})
		cleanup:Add(frame)
		Widgets.Padding(frame, 12, 11)
		Widgets.List(frame, 7)
		self.Frame, self.Stroke = frame, frame:FindFirstChildOfClass("UIStroke")

		local header = Utility.Create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = frame,
		})
		Widgets.List(header, 7, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		if config.Icon then
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(14, 14),
				LayoutOrder = 1,
				Parent = header,
			})
			self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
				Size = config.IconSize or 14,
				Color = config.IconColor or "MutedText",
				Cleanup = cleanup,
			}))
		end
		local _, titleHandle = Widgets.Text(cleanup, {
			Parent = header,
			Text = config.Title or "List",
			Color = config.TitleColor or "Text",
			Gradient = config.TitleGradient,
			Bold = true,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		})
		self._title = titleHandle
		local _, countHandle = Widgets.Text(cleanup, {
			Parent = header,
			Text = "0",
			Color = "MutedText",
			TextSize = 11,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 3,
		})

		local body = Utility.Create("Frame", {
			Name = "Items",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Parent = frame,
		})
		Widgets.List(body, 4)

		local rows = cleanup:Extend()
		local empty = config.Empty or "Nothing here yet"

		local function build(items)
			rows:Clean()
			rows = cleanup:Extend()
			countHandle.SetText(tostring(#items))
			if #items == 0 then
				rows:Add((Widgets.Text(rows, {
					Parent = body,
					Text = empty,
					Color = "MutedText",
					TextSize = 12,
					Size = UDim2.new(1, 0, 0, 24),
					LayoutOrder = 1,
				})))
				return
			end
			for index, item in items do
				local row = Widgets.Surface(rows, {
					Class = "TextButton",
					Name = "Item",
					Parent = body,
					Fill = "TertiaryBackground",
					Transparency = "ElementTransparency",
					Radius = 9,
					Size = UDim2.new(1, 0, 0, 28),
					LayoutOrder = index,
				})
				rows:Add(row)

				Widgets.Text(rows, {
					Parent = row,
					Text = tostring(index),
					Color = "MutedText",
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(4, 0),
					Size = UDim2.fromOffset(18, 28),
				})

				local label, text = Widgets.Text(rows, {
					Class = config.Editable ~= false and "TextBox" or "TextLabel",
					Parent = row,
					Text = item,
					Color = config.ItemColor,
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(24, 0),
					Size = UDim2.new(1, -(24 + (config.Removable ~= false and 30 or 8)), 1, 0),
					Markup = config.Editable == false,
				})

				if config.Editable ~= false then
					local editor = Editable.Attach(rows, label, text, {
						Label = "List item",
						Color = config.ItemColor,
						Source = function()
							return item
						end,
						Validate = function(value)
							return value ~= "" and (value == item or self:Has(value) == false)
						end,
						OnCommit = function(value)
							self:Rename(item, value)
						end,
					})
					rows:Add(row.Activated:Connect(function()
						editor.Begin()
					end))
				end

				if config.Removable ~= false then
					local trash = Widgets.Chip(rows, {
						Name = "Remove",
						Parent = row,
						Radius = "Full",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -5, 0.5, 0),
						Size = UDim2.fromOffset(19, 19),
						ZIndex = 3,
					})
					Icons.Create(trash, "x", { Size = 10, Color = "Error", Position = UDim2.fromOffset(4.5, 4.5), Cleanup = rows })
					rows:Add(trash.Activated:Connect(function()
						self:Remove(item)
					end))
				end
			end
		end

		if config.Creatable ~= false then
			local addRow = Utility.Create("Frame", {
				Name = "Add",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 3,
				Parent = frame,
			})
			local holder, box, _, field = Widgets.Field(cleanup, {
				Name = "Input",
				Parent = addRow,
				Radius = 9,
				Placeholder = config.Placeholder or "Add item...",
				Size = UDim2.new(1, -32, 1, 0),
			})
			local add = Widgets.Chip(cleanup, {
				Name = "Confirm",
				Parent = addRow,
				Radius = 9,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(28, 28),
				Fill = "Accent",
				Transparency = 0,
			})
			Icons.Create(add, "plus", { Size = 13, Color = "AccentText", Position = UDim2.fromOffset(7.5, 7.5), Cleanup = cleanup })

			local function commit()
				local value = box.Text
				if value == "" then
					return
				end
				if self:Has(value) and not config.Duplicates then
					field.Flash("Error")
					return
				end
				self:Add(value)
				box.Text = ""
				Widgets.Pulse(add, 0.8, 0.3)
			end
			cleanup:Add(add.Activated:Connect(commit))
			cleanup:Add(box.FocusLost:Connect(function(enter)
				if enter then
					commit()
				end
			end))
		end

		Component.BindValue(self, id, config.Default or {}, function(items)
			build(items)
			self.ItemsChanged:Fire(table.clone(items))
		end)
		return self
	end
end
