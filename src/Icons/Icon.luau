return function(import)
	local Registry = import("Icons/Registry")
	local Providers = import("Icons/Providers")
	local Store = import("Icons/Store")
	local Theme = import("Core/Theme")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")

	local Icons = {}

	function Icons:Get(name)
		return Registry.Resolve(name)
	end

	function Icons:List()
		return Providers.Names()
	end

	function Icons:Count()
		return Providers.Count()
	end

	setmetatable(Icons, {
		__index = function(_, key)
			if type(key) ~= "string" then
				return nil
			end
			return Registry.Resolve(Utility.Kebab(key))
		end,
	})

	local SHAPES = {
		square = "Square", sharp = "Square", none = "Square",
		rounded = "Rounded", round = "Rounded", soft = "Rounded", squircle = "Rounded",
		circle = "Circle", circular = "Circle", full = "Circle", round_full = "Circle",
	}

	function Icons.Shape(value)
		if value == nil then
			return nil
		end
		if type(value) == "number" then
			return value
		end
		return SHAPES[string.lower(tostring(value))]
	end

	function Icons.Options(config, base)
		local opts = base or {}
		if type(config) ~= "table" then
			return opts
		end
		if config.IconShape ~= nil then
			opts.Shape = config.IconShape
		end
		if config.IconCorner ~= nil then
			opts.Corner = config.IconCorner
		end
		if config.IconTint ~= nil then
			opts.Tint = config.IconTint == true
		end
		if config.IconScale ~= nil then
			opts.ScaleType = config.IconScale
		end
		if config.IconColor ~= nil and opts.Color == nil then
			opts.Color = config.IconColor
		end
		return opts
	end

	function Icons.Create(parent, spec, opts)
		opts = opts or {}
		local size = opts.Size or 16
		local cleanup = opts.Cleanup and opts.Cleanup:Extend() or Cleanup.new()
		local self = {}

		local container = Utility.Create("Frame", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
			Position = opts.Position or UDim2.new(),
			AnchorPoint = opts.AnchorPoint or Vector2.zero,
			LayoutOrder = opts.LayoutOrder,
			ZIndex = opts.ZIndex or 1,
			Rotation = opts.Rotation or 0,
			Parent = parent,
		})
		cleanup:Add(container)
		self.Instance = container

		local colorSource = opts.Color or "MutedText"
		local parts = {}
		local image, tinted, gradient
		local ticket = 0
		local key

		local function paint(animate)
			local sequence = Widgets.Stops(colorSource)
			local color = sequence and Color3.new(1, 1, 1) or Theme.Resolve(colorSource, "MutedText")
			local tween = animate and opts.Tween ~= false
			for _, part in parts do
				if part.stroke then
					if tween then
						Animation:Play(part.stroke, { Color = color }, { Duration = 0.18, Ease = "Soft" })
					else
						part.stroke.Color = color
					end
				elseif tween then
					Animation:Play(part.instance, { BackgroundColor3 = color }, { Duration = 0.18, Ease = "Soft" })
				else
					part.instance.BackgroundColor3 = color
				end
			end
			if image then
				if sequence then
					if not gradient then
						gradient = Utility.Create("UIGradient", { Parent = image })
					end
					gradient.Color = sequence
					image.ImageColor3 = Color3.new(1, 1, 1)
				else
					if gradient then
						gradient:Destroy()
						gradient = nil
					end
					if tinted then
						if tween then
							Animation:Play(image, { ImageColor3 = color }, { Duration = 0.18, Ease = "Soft" })
						else
							image.ImageColor3 = color
						end
					end
				end
			end
		end

		local function clear()
			container:ClearAllChildren()
			table.clear(parts)
			image, tinted, gradient = nil, false, nil
		end

		local function drawVector(vector)
			local grid = vector.Size or 24
			local weight = vector.Width or 2
			local thickness = math.max(1.2, size / grid * weight * 0.9)
			for _, segment in vector.L or {} do
				local x1, y1, x2, y2 = segment[1], segment[2], segment[3], segment[4]
				local dx, dy = x2 - x1, y2 - y1
				local length = math.max(math.sqrt(dx * dx + dy * dy), 0.01)
				local line = Utility.Create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale((x1 + x2) / (grid * 2), (y1 + y2) / (grid * 2)),
					Size = UDim2.new(length / grid, thickness, 0, thickness),
					Rotation = math.deg(math.atan2(dy, dx)),
					Parent = container,
				})
				Utility.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = line })
				table.insert(parts, { instance = line })
			end
			for _, circle in vector.C or {} do
				local diameter = circle[3] * 2 / grid
				local ring = Utility.Create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(circle[1] / grid, circle[2] / grid),
					Size = UDim2.fromScale(diameter, diameter),
					Parent = container,
				})
				Utility.Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
				local stroke = Utility.Create("UIStroke", {
					Thickness = thickness,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = ring,
				})
				table.insert(parts, { instance = ring, stroke = stroke })
			end
			for _, rect in vector.R or {} do
				local box = Utility.Create("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(rect[1] / grid, rect[2] / grid),
					Size = UDim2.fromScale(rect[3] / grid, rect[4] / grid),
					Parent = container,
				})
				if (rect[5] or 0) > 0 then
					Utility.Create("UICorner", {
						CornerRadius = UDim.new(0, math.max(1, rect[5] / grid * size)),
						Parent = box,
					})
				end
				local stroke = Utility.Create("UIStroke", {
					Thickness = thickness,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = box,
				})
				table.insert(parts, { instance = box, stroke = stroke })
			end
		end

		local shape, shapeCorner, shapeScale

		local function radius()
			if type(shapeCorner) == "number" then
				return UDim.new(0, shapeCorner)
			end
			if shapeCorner == "Full" then
				return UDim.new(1, 0)
			end
			if shape == "Circle" then
				return UDim.new(1, 0)
			end
			if shape == "Rounded" then
				return UDim.new(0, math.max(2, math.floor(size * 0.28)))
			end
			return nil
		end

		local function scaleType()
			local wanted = shapeScale or opts.ScaleType
			if wanted == nil then
				if shape == "Circle" or shape == "Rounded" or shapeCorner ~= nil then
					return Enum.ScaleType.Crop
				end
				return Enum.ScaleType.Fit
			end
			if typeof(wanted) == "EnumItem" then
				return wanted
			end
			local name = string.lower(tostring(wanted))
			if name == "crop" or name == "cover" or name == "fill" then
				return Enum.ScaleType.Crop
			end
			if name == "stretch" then
				return Enum.ScaleType.Stretch
			end
			if name == "slice" then
				return Enum.ScaleType.Slice
			end
			return Enum.ScaleType.Fit
		end

		local function clipShape()
			local corner = radius()
			container.ClipsDescendants = corner ~= nil
			local existing = container:FindFirstChildOfClass("UICorner")
			if corner == nil then
				if existing then
					existing:Destroy()
				end
				return nil
			end
			if existing then
				existing.CornerRadius = corner
			else
				Utility.Create("UICorner", { CornerRadius = corner, Parent = container })
			end
			return corner
		end

		local function newImage(source, tint)
			image = Utility.Create("ImageLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = source or "",
				ScaleType = scaleType(),
				Parent = container,
			})
			local corner = radius()
			if corner then
				Utility.Create("UICorner", { CornerRadius = corner, Parent = image })
			end
			tinted = tint == true
			return image
		end

		local function fallback()
			clear()
			clipShape()
			local spare = Providers.GetFallback()
			if spare then
				newImage(spare.Source, spare.Tint)
				image.ScaleType = Enum.ScaleType.Fit
			else
				container.Visible = false
			end
			paint()
		end

		local function draw(newSpec)
			ticket += 1
			local mine = ticket
			key = nil
			clear()
			if newSpec == nil or newSpec == "" then
				container.Visible = false
				return
			end
			container.Visible = true
			local resolved = Registry.Resolve(newSpec)
			if not resolved then
				Store.Complain(
					"spec-" .. Utility.Slug(tostring(newSpec)),
					string.format('"%s" is not a catalog name, a url, an rbxassetid:// or a file: path.', tostring(newSpec))
				)
				resolved = Providers.GetFallback()
			end
			if not resolved then
				container.Visible = false
				return
			end

			shape = Icons.Shape(opts.Shape or resolved.Shape)
			shapeCorner = opts.Corner or resolved.Corner
			shapeScale = opts.ScaleType or resolved.ScaleType
			clipShape()

			if opts.Tint ~= nil then
				resolved = table.clone(resolved)
				resolved.Tint = opts.Tint == true
			end

			if resolved.Type == "Vector" then
				drawVector(resolved)
			elseif resolved.Type == "Image" then
				newImage(resolved.Source, resolved.Tint)
			elseif resolved.Type == "File" then
				local asset = Store.Local(resolved.Source)
				if asset then
					newImage(asset, resolved.Tint)
				else
					fallback()
					return
				end
			else
				key = Utility.Slug(resolved.Name or resolved.Source)
				newImage(nil, resolved.Tint)
				Providers.Load(resolved, function(result)
					if mine ~= ticket or not container.Parent then
						return
					end
					if result == nil then
						fallback()
						return
					end
					if type(result) == "table" then
						clear()
						clipShape()
						drawVector(result)
					elseif image then
						image.Image = result
					end
					paint()
				end)
			end
			paint()
		end

		cleanup:Add(Store.Updated:Connect(function(updatedKey, result)
			if key ~= updatedKey or not container.Parent then
				return
			end
			if type(result) == "table" then
				clear()
				clipShape()
				drawVector(result)
			elseif image then
				image.Image = result
			end
			paint()
		end))

		function self.Set(_, newSpec)
			self.Spec = newSpec
			draw(newSpec)
		end

		function self.SetShape(_, newShape, corner)
			opts.Shape = newShape
			if corner ~= nil then
				opts.Corner = corner
			end
			draw(self.Spec)
			return self
		end

		function self.SetTint(_, enabled)
			opts.Tint = enabled
			draw(self.Spec)
			return self
		end

		function self.SetColor(_, newColor)
			if colorSource == newColor then
				return
			end
			colorSource = newColor
			paint(true)
		end

		function self.SetSize(_, newSize)
			size = newSize
			container.Size = UDim2.fromOffset(newSize, newSize)
			draw(self.Spec)
		end

		function self.IsVisible()
			return container.Visible
		end

		function self.Destroy()
			cleanup:Clean()
		end

		Theme.BindFn(paint, cleanup)
		self.Spec = spec
		draw(spec)
		return self
	end

	return Icons
end

