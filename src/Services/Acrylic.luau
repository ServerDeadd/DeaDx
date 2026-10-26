return function(import)
	local Lighting = game:GetService("Lighting")
	local Workspace = game:GetService("Workspace")
	local Utility = import("Core/Utility")
	local Theme = import("Core/Theme")
	local Animation = import("Services/Animation")

	local Acrylic = {
		ShadowAsset = "",
		NoiseAsset = "",
		Radius = 16,
	}

	local folder
	local effect
	local defaults = {}
	local enabled = false

	local function ensureFolder()
		if folder and folder.Parent then
			return folder
		end
		folder = Instance.new("Folder")
		folder.Name = "DeaDxGlass"
		local camera = Workspace.CurrentCamera
		if camera then
			folder.Parent = camera
		end
		Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			local current = Workspace.CurrentCamera
			if folder and current and folder.Parent ~= current then
				folder.Parent = current
			end
		end)
		return folder
	end

	function Acrylic.Supported()
		local ok = pcall(function()
			local probe = Instance.new("DepthOfFieldEffect")
			probe.Parent = Lighting
			probe:Destroy()
		end)
		return ok and Workspace.CurrentCamera ~= nil
	end

	function Acrylic.Enable()
		if enabled then
			return
		end
		enabled = true
		if not effect then
			effect = Instance.new("DepthOfFieldEffect")
			effect.Name = "DeaDxDepth"
			effect.FarIntensity = 0
			effect.InFocusRadius = 0.1
			effect.NearIntensity = 1
		end
		table.clear(defaults)
		for _, child in Lighting:GetChildren() do
			if child:IsA("DepthOfFieldEffect") and child ~= effect then
				defaults[child] = child.Enabled
				child.Enabled = false
			end
		end
		effect.Parent = Lighting
	end

	function Acrylic.Disable()
		if not enabled then
			return
		end
		enabled = false
		for child, value in defaults do
			if child.Parent then
				child.Enabled = value
			end
		end
		table.clear(defaults)
		if effect then
			effect.Parent = nil
		end
	end

	function Acrylic.IsEnabled()
		return enabled
	end

	local function viewportToWorld(point, distance)
		local camera = Workspace.CurrentCamera
		if not camera then
			return Vector3.zero
		end
		local ray = camera:ScreenPointToRay(point.X, point.Y)
		return ray.Origin + ray.Direction * distance
	end

	local function inset()
		local camera = Workspace.CurrentCamera
		local height = camera and camera.ViewportSize.Y or 1080
		return Utility.Map(height, 0, 2560, 8, 56)
	end

	function Acrylic.Glass(cleanup, distance)
		distance = distance or 0.001
		local self = {}
		local part = Utility.Create("Part", {
			Name = "Glass",
			Color = Color3.new(0, 0, 0),
			Material = Enum.Material.Glass,
			Size = Vector3.new(1, 1, 0),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Locked = true,
			CastShadow = false,
			Transparency = 0.98,
			Parent = ensureFolder(),
		}, {
			Utility.Create("SpecialMesh", {
				Name = "Mesh",
				MeshType = Enum.MeshType.Brick,
				Offset = Vector3.new(0, 0, -0.000001),
			}),
		})
		cleanup:Add(part)

		local corners = { Vector2.zero, Vector2.zero, Vector2.zero }
		local visible = true

		local function render()
			local camera = Workspace.CurrentCamera
			if not camera or not part.Parent then
				return
			end
			local frame = camera.CFrame
			local topLeft = viewportToWorld(corners[1], distance)
			local topRight = viewportToWorld(corners[2], distance)
			local bottomRight = viewportToWorld(corners[3], distance)
			local width = (topRight - topLeft).Magnitude
			local height = (topRight - bottomRight).Magnitude
			part.CFrame = CFrame.fromMatrix((topLeft + bottomRight) / 2, frame.XVector, frame.YVector, frame.ZVector)
			part.Mesh.Scale = Vector3.new(width, height, 0)
		end

		local tracker = Utility.Create("Frame", {
			Name = "GlassTracker",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		})
		cleanup:Add(tracker)

		local function sync()
			local offset = inset()
			local size = tracker.AbsoluteSize - Vector2.new(offset, offset)
			local position = tracker.AbsolutePosition + Vector2.new(offset / 2, offset / 2)
			corners[1] = position
			corners[2] = position + Vector2.new(size.X, 0)
			corners[3] = position + size
			task.spawn(render)
		end

		cleanup:Add(tracker:GetPropertyChangedSignal("AbsolutePosition"):Connect(sync))
		cleanup:Add(tracker:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync))

		local hooks = {}
		local function hookCamera()
			for _, connection in hooks do
				connection:Disconnect()
			end
			table.clear(hooks)
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			table.insert(hooks, camera:GetPropertyChangedSignal("CFrame"):Connect(render))
			table.insert(hooks, camera:GetPropertyChangedSignal("ViewportSize"):Connect(sync))
			table.insert(hooks, camera:GetPropertyChangedSignal("FieldOfView"):Connect(render))
			task.spawn(render)
		end
		hookCamera()
		cleanup:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			ensureFolder()
			part.Parent = folder
			hookCamera()
		end))
		cleanup:Add(function()
			for _, connection in hooks do
				connection:Disconnect()
			end
			table.clear(hooks)
		end)

		self.Frame = tracker
		self.Part = part

		function self.SetVisible(value)
			visible = value == true
			part.Transparency = visible and 0.98 or 1
		end

		function self.Destroy()
			part:Destroy()
			tracker:Destroy()
		end

		return self
	end

	function Acrylic.Paint(cleanup, opts)
		opts = opts or {}
		local radius = opts.Radius or Acrylic.Radius
		local self = {}

		local root = Utility.Create("Frame", {
			Name = "Acrylic",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			Size = UDim2.fromScale(1, 1),
			Parent = opts.Parent,
		})
		cleanup:Add(root)
		Utility.Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = root })

		if Acrylic.ShadowAsset ~= "" then
			Utility.Create("ImageLabel", {
				Name = "Shadow",
				Image = Acrylic.ShadowAsset,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(Vector2.new(99, 99), Vector2.new(99, 99)),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 120, 1, 116),
				BackgroundTransparency = 1,
				ImageColor3 = Color3.new(0, 0, 0),
				ImageTransparency = 0.7,
				Parent = root,
			})
		end

		local tint = Utility.Create("Frame", {
			Name = "Tint",
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		})
		Utility.Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = tint })

		local sheen = Utility.Create("Frame", {
			Name = "Sheen",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.42,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		})
		Utility.Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = sheen })
		local gradient = Utility.Create("UIGradient", { Rotation = 90, Parent = sheen })

		local noise
		if Acrylic.NoiseAsset ~= "" then
			noise = Utility.Create("ImageLabel", {
				Name = "Noise",
				Image = Acrylic.NoiseAsset,
				ImageTransparency = 0.92,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(128, 128),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Parent = root,
			})
			Utility.Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = noise })
		end

		local outline = Utility.Create("Frame", {
			Name = "Outline",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = root,
		})
		Utility.Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = outline })
		local stroke = Utility.Create("UIStroke", {
			Thickness = 1,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = outline,
		})

		Theme.BindFn(function()
			tint.BackgroundColor3 = Theme.Get("AcrylicTint")
			gradient.Color = Theme.Get("AcrylicGradient")
			stroke.Color = Theme.Get("Border")
			if noise then
				noise.ImageTransparency = Theme.Get("AcrylicNoise")
			end
		end, cleanup)

		local glass
		if opts.Glass and Acrylic.Supported() then
			glass = Acrylic.Glass(cleanup, opts.Distance)
			glass.Frame.Parent = root
			self.Part = glass.Part
			Acrylic.Enable()
		end

		self.Frame = root
		self.Tint = tint

		function self.SetVisible(value)
			root.Visible = value == true
			if glass then
				glass.SetVisible(value)
			end
		end

		function self.SetTransparency(value)
			Animation:Play(root, { BackgroundTransparency = math.clamp(0.9 + value * 0.1, 0, 1) }, { Duration = 0.2 })
			Animation:Play(tint, { BackgroundTransparency = math.clamp(0.45 + value * 0.55, 0, 1) }, { Duration = 0.2 })
			Animation:Play(sheen, { BackgroundTransparency = math.clamp(0.42 + value * 0.58, 0, 1) }, { Duration = 0.2 })
		end

		return self
	end

	function Acrylic.Reset()
		Acrylic.Disable()
		if folder then
			folder:Destroy()
			folder = nil
		end
		if effect then
			effect:Destroy()
			effect = nil
		end
	end

	return Acrylic
end
