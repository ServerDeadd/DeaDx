return function(import)
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")
	local Drag = import("Services/Drag")
	local Animation = import("Services/Animation")

	local Preview = {}

	Preview.__index = function(object, key)
		local method = rawget(Preview, key)
		if method ~= nil then
			return method
		end
		local base = Component.Base[key]
		if base ~= nil then
			return base
		end
		local name = type(key) == "string" and string.match(key, "^Add(%u%w*)$")
		if name and Component.Registry[name] then
			return function(self, first, second)
				return Component.Add(self, name, first, second)
			end
		end
		return nil
	end

	local LIMBS = {
		{ "Head", "UpperTorso" },
		{ "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" },
		{ "LeftUpperArm", "LeftLowerArm" },
		{ "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" },
		{ "RightUpperArm", "RightLowerArm" },
		{ "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" },
		{ "LeftUpperLeg", "LeftLowerLeg" },
		{ "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" },
		{ "RightUpperLeg", "RightLowerLeg" },
		{ "RightLowerLeg", "RightFoot" },
		{ "Head", "Torso" },
		{ "Torso", "Left Arm" },
		{ "Torso", "Right Arm" },
		{ "Torso", "Left Leg" },
		{ "Torso", "Right Leg" },
	}

	local function dummy()
		local model = Instance.new("Model")
		model.Name = "Dummy"
		local function part(name, size, offset, color)
			local piece = Instance.new("Part")
			piece.Name = name
			piece.Size = size
			piece.CFrame = CFrame.new(offset)
			piece.Anchored = true
			piece.CanCollide = false
			piece.Color = color
			piece.TopSurface = Enum.SurfaceType.Smooth
			piece.BottomSurface = Enum.SurfaceType.Smooth
			piece.Parent = model
			return piece
		end
		local skin = Color3.fromRGB(234, 184, 146)
		local shirt = Color3.fromRGB(70, 90, 140)
		local pants = Color3.fromRGB(45, 48, 60)
		part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.5, 0), skin)
		local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt)
		part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), skin)
		part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), skin)
		part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), pants)
		part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), pants)
		model.PrimaryPart = torso
		return model
	end

	local function subject(source)
		if typeof(source) == "Instance" then
			if source:IsA("Model") then
				return source
			end
			if source:IsA("Player") then
				return source.Character
			end
		end
		if type(source) == "string" then
			local player = Players:FindFirstChild(source)
			return player and player.Character or nil
		end
		return nil
	end

	function Preview:SetModel(source)
		local target = subject(source)
		local model
		if target then
			local ok, clone = pcall(function()
				target.Archivable = true
				return target:Clone()
			end)
			model = ok and clone or nil
		end
		if not model then
			model = dummy()
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide = false
				item.CastShadow = false
			elseif item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Humanoid") then
				item:Destroy()
			end
		end
		if self._model then
			self._model:Destroy()
		end
		self._model = model
		model.Parent = self._world

		local pivot = model:GetPivot()
		self._origin = CFrame.new(pivot.Position)
		self:Refocus()
		self:_Apply()
		self.ModelChanged:Fire(model)
		return self
	end

	function Preview:GetModel()
		return self._model
	end

	function Preview:Refocus()
		local model, camera, viewport = self._model, self._camera, self.Viewport
		if not model or not model.Parent then
			return self
		end
		local box, size = model:GetBoundingBox()
		local view = viewport.AbsoluteSize
		local aspect = view.Y > 0 and math.max(view.X / view.Y, 0.05) or 1
		local half = math.tan(math.rad(camera.FieldOfView / 2))
		local spread = math.max(size.X, size.Z, 1)
		local vertical = (math.max(size.Y, 1) / 2) / half
		local horizontal = (spread / 2) / (half * aspect)
		local distance = math.max(vertical, horizontal) * (self.Config.Zoom or 1.3)
		self._distanceStuds = distance
		camera.CFrame = CFrame.new(box.Position + Vector3.new(0, 0, -distance), box.Position)
		return self
	end

	function Preview:SetFeature(name, enabled)
		self.Features[name] = enabled == true
		self:_Apply()
		return self
	end

	function Preview:GetFeature(name)
		return self.Features[name] == true
	end

	function Preview:ToggleFeature(name)
		return self:SetFeature(name, not self.Features[name])
	end

	function Preview:SetColor(color)
		self.Color = Theme.Resolve(color, "Accent")
		self:_Apply()
		return self
	end

	function Preview:SetThickness(value)
		self.Thickness = math.clamp(tonumber(value) or 1, 1, 6)
		self:_Apply()
		return self
	end

	function Preview:SetLabel(text)
		self._espName = text
		return self
	end

	function Preview:SetSpin(enabled)
		self._spin = enabled == true
		return self
	end

	function Preview:GetFeatures()
		return table.clone(self.Features)
	end

	function Preview:_Apply()
		local color = self.Color or Theme.Get("Accent")
		for _, item in self._parts do
			if item.stroke then
				item.stroke.Color = color
				item.stroke.Thickness = self.Thickness
			else
				item.instance.BackgroundColor3 = color
			end
		end
		if self._chams then
			local on = self.Features.Chams
			for _, piece in self._model and self._model:GetDescendants() or {} do
				if piece:IsA("BasePart") then
					if on then
						if self._original[piece] == nil then
							self._original[piece] = { piece.Color, piece.Material, piece.Transparency }
						end
						piece.Color = color
						piece.Material = Enum.Material.Neon
					elseif self._original[piece] then
						piece.Color = self._original[piece][1]
						piece.Material = self._original[piece][2]
						piece.Transparency = self._original[piece][3]
					end
				end
			end
		end
	end

	function Preview:_Draw()
		local model, camera = self._model, self._camera
		local overlay = self._overlay
		if not model or not model.Parent or not overlay.Parent then
			return
		end
		local size = overlay.AbsoluteSize
		if size.X < 4 or size.Y < 4 then
			return
		end

		local box3, extent = model:GetBoundingBox()
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local world = box3.Position + Vector3.new(extent.X / 2 * x, extent.Y / 2 * y, extent.Z / 2 * z)
					local point = camera:WorldToViewportPoint(world)
					minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
					minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
				end
			end
		end
		local width, height = maxX - minX, maxY - minY
		local box = self._box
		box.Position = UDim2.fromOffset(minX, minY)
		box.Size = UDim2.fromOffset(width, height)
		box.Visible = self.Features.Box == true

		for index, piece in self._corners do
			piece.Visible = self.Features.Corners == true
			local length = math.min(width, height) * 0.25
			if index == 1 then
				piece.Position = UDim2.fromOffset(minX, minY)
			elseif index == 2 then
				piece.Position = UDim2.fromOffset(maxX - length, minY)
			elseif index == 3 then
				piece.Position = UDim2.fromOffset(minX, maxY - length)
			else
				piece.Position = UDim2.fromOffset(maxX - length, maxY - length)
			end
			piece.Size = UDim2.fromOffset(length, length)
		end

		self._name.Visible = self.Features.Name == true
		self._name.Position = UDim2.fromOffset(minX + width / 2, minY - 15)
		self._name.Size = UDim2.fromOffset(math.max(width, 60), 13)

		self._distance.Visible = self.Features.Distance == true
		self._distance.Position = UDim2.fromOffset(minX + width / 2, maxY + 3)
		self._distance.Size = UDim2.fromOffset(math.max(width, 60), 12)

		local healthbar = self._health
		healthbar.Visible = self.Features.Health == true
		healthbar.Position = UDim2.fromOffset(minX - 6, minY)
		healthbar.Size = UDim2.fromOffset(3, height)
		self._healthFill.Size = UDim2.new(1, 0, self._healthValue, 0)

		local tracer = self._tracer
		tracer.Visible = self.Features.Tracer == true
		if tracer.Visible then
			local originX, originY = size.X / 2, size.Y
			local targetX, targetY = minX + width / 2, maxY
			local dx, dy = targetX - originX, targetY - originY
			local length = math.sqrt(dx * dx + dy * dy)
			tracer.Position = UDim2.fromOffset((originX + targetX) / 2, (originY + targetY) / 2)
			tracer.Size = UDim2.fromOffset(length, self.Thickness)
			tracer.Rotation = math.deg(math.atan2(dy, dx))
		end

		local skeleton = self.Features.Skeleton == true
		for index, line in self._bones do
			local pair = LIMBS[index]
			local a = model:FindFirstChild(pair[1])
			local b = model:FindFirstChild(pair[2])
			if skeleton and a and b then
				local pa = camera:WorldToViewportPoint(a.Position)
				local pb = camera:WorldToViewportPoint(b.Position)
				local dx, dy = pb.X - pa.X, pb.Y - pa.Y
				local length = math.sqrt(dx * dx + dy * dy)
				line.Visible = true
				line.Position = UDim2.fromOffset((pa.X + pb.X) / 2, (pa.Y + pb.Y) / 2)
				line.Size = UDim2.fromOffset(length, math.max(self.Thickness - 0.5, 1))
				line.Rotation = math.deg(math.atan2(dy, dx))
			else
				line.Visible = false
			end
		end
	end

	return function(ctx, id, config)
		local self = Component.NewBare(ctx, Preview, "Preview", id, config)
		local cleanup = self.Cleanup
		local height = config.Height or 186
		local paneWidth = config.PaneWidth or 136

		self.Window = ctx.Window
		self.TabRef, self.SectionRef = ctx.Tab, ctx.Section
		self.Features = config.Features or {}
		self.Color = Theme.Resolve(config.Color, "Accent")
		self.Thickness = config.Thickness or 1
		self.ModelChanged = Signal.new()
		self._parts, self._corners, self._bones, self._original = {}, {}, {}, {}
		self._healthValue = config.Health or 0.72
		self._espName = config.Label or "Player"
		self._spin = config.Spin ~= false
		self._order = 0
		self.NextOrder = function()
			self._order += 1
			return self._order
		end
		cleanup:Add(self.ModelChanged)

		local frame, stroke = Widgets.Surface(cleanup, {
			Name = "Preview",
			Parent = ctx.Parent,
			Fill = "SecondaryBackground",
			Transparency = "ComponentTransparency",
			Stroke = "Border",
			StrokeTransparency = "ComponentStrokeTransparency",
			Radius = 16,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = ctx.Order(),
		})
		cleanup:Add(frame)
		self.Frame, self.Stroke = frame, stroke
		Widgets.Padding(frame, 10, 10)

		local stage = Widgets.Surface(cleanup, {
			Name = "Stage",
			Parent = frame,
			Fill = config.StageColor or "Background",
			Transparency = config.StageTransparency or 0.25,
			Stroke = "Border",
			StrokeTransparency = 0.55,
			Radius = 12,
			ClipsDescendants = true,
			Size = UDim2.new(0, paneWidth, 1, 0),
		})
		self.Stage = stage

		local viewport = Utility.Create("ViewportFrame", {
			Name = "Viewport",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = config.Ambient or Color3.fromRGB(190, 190, 200),
			LightColor = config.LightColor or Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-0.3, -1, -0.6),
			Parent = stage,
		})
		self.Viewport = viewport

		local world = Instance.new("WorldModel")
		world.Parent = viewport
		self._world = world

		local camera = Instance.new("Camera")
		camera.FieldOfView = config.FieldOfView or 42
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		self._camera = camera

		local overlay = Utility.Create("Frame", {
			Name = "Esp",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
			ZIndex = 3,
			Parent = stage,
		})
		self._overlay = overlay

		local box = Utility.Create("Frame", {
			Name = "Box",
			BackgroundTransparency = 1,
			Visible = false,
			Parent = overlay,
		})
		local boxStroke = Utility.Create("UIStroke", { Thickness = 1, Parent = box })
		self._box = box
		table.insert(self._parts, { instance = box, stroke = boxStroke })

		for index = 1, 4 do
			local corner = Utility.Create("Frame", {
				Name = "Corner",
				BackgroundTransparency = 1,
				Visible = false,
				Parent = overlay,
			})
			local horizontal = Utility.Create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = index <= 2 and UDim2.new() or UDim2.new(0, 0, 1, -1),
				Parent = corner,
			})
			local vertical = Utility.Create("Frame", {
				Size = UDim2.new(0, 1, 1, 0),
				Position = (index % 2 == 1) and UDim2.new() or UDim2.new(1, -1, 0, 0),
				Parent = corner,
			})
			table.insert(self._parts, { instance = horizontal })
			table.insert(self._parts, { instance = vertical })
			table.insert(self._corners, corner)
		end

		local name = Widgets.Text(cleanup, {
			Name = "Name",
			Parent = overlay,
			Text = self._espName,
			Bold = true,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Visible = false,
			Markup = false,
		})
		self._name = name
		table.insert(self._parts, { instance = name, stroke = Utility.Create("UIStroke", { Thickness = 2, Color = Color3.new(), Transparency = 0.4, Parent = name }) })

		local distance = Widgets.Text(cleanup, {
			Name = "Distance",
			Parent = overlay,
			Text = config.Distance or "14 studs",
			TextSize = 10,
			Color = "MutedText",
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Visible = false,
			Markup = false,
		})
		self._distance = distance

		local health = Utility.Create("Frame", {
			Name = "Health",
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			Visible = false,
			Parent = overlay,
		})
		local healthFill = Utility.Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(80, 220, 120),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.7),
			Parent = health,
		})
		self._health, self._healthFill = health, healthFill

		local tracer = Utility.Create("Frame", {
			Name = "Tracer",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Visible = false,
			Parent = overlay,
		})
		self._tracer = tracer
		table.insert(self._parts, { instance = tracer })

		for _ = 1, #LIMBS do
			local bone = Utility.Create("Frame", {
				Name = "Bone",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Visible = false,
				Parent = overlay,
			})
			table.insert(self._bones, bone)
			table.insert(self._parts, { instance = bone })
		end

		local right = Utility.Create("Frame", {
			Name = "Panel",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(paneWidth + 10, 0),
			Size = UDim2.new(1, -(paneWidth + 10), 1, 0),
			Parent = frame,
		})
		local scroller = Widgets.Scroller(cleanup, {
			Name = "Options",
			Parent = right,
			Thickness = 2,
		})
		Widgets.List(scroller, 6)
		self.Container = scroller

		if config.Title then
			local header = Utility.Create("Frame", {
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 0,
				Parent = scroller,
			})
			Widgets.List(header, 6, {
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
				Icons.Create(holder, config.Icon, Icons.Options(config, {
					Size = config.IconSize or 14,
					Color = config.IconColor or "Accent",
					Cleanup = cleanup,
				}))
			end
			local _, handle = Widgets.Text(cleanup, {
				Parent = header,
				Text = config.Title,
				Color = config.TitleColor or "Text",
				Gradient = config.TitleGradient,
				Bold = true,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = 2,
			})
			self._title = handle
			self._order = 0
		end

		local spin = 0
		local dragging = false
		local hidden = false
		cleanup:Add(RunService.RenderStepped:Connect(function(delta)
			if self._destroyed or hidden or not self._model then
				return
			end
			if self._spin and not dragging then
				spin += delta * (config.SpinSpeed or 0.5)
			end
			self._model:PivotTo(self._origin * CFrame.Angles(0, spin, 0))
			self:_Draw()
		end))

		local hit = Utility.Create("TextButton", {
			Name = "Rotate",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = stage,
		})
		local lastX
		Drag.Track(hit, cleanup, function(position)
			dragging = true
			if lastX then
				spin -= (position.X - lastX) * 0.012
			end
			lastX = position.X
		end, function()
			dragging = false
			lastX = nil
		end)

		cleanup:Add(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if not self._destroyed then
				self:Refocus()
			end
		end))

		Theme.BindFn(function()
			if not self.Color or config.Color == nil then
				self.Color = Theme.Get("Accent")
			end
			self:_Apply()
		end, cleanup)

		self:SetModel(config.Model or config.Player or Players.LocalPlayer)

		function self:SetHealth(alpha)
			self._healthValue = math.clamp(tonumber(alpha) or 0, 0, 1)
			healthFill.BackgroundColor3 = Color3.fromRGB(
				math.floor(255 * (1 - self._healthValue)),
				math.floor(200 * self._healthValue + 40),
				90
			)
			return self
		end
		self:SetHealth(self._healthValue)

		function self:SetTitle(text)
			if self._title then
				self._title.SetText(text)
			end
			return self
		end

		function self:SetName(text)
			self._espName = text
			name.Text = text
			return self
		end

		function self:SetVisible(visible)
			hidden = visible == false
			frame.Visible = visible == true
			return self
		end

		return self
	end
end
