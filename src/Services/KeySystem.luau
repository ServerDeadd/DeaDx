return function(import)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local MarketplaceService = game:GetService("MarketplaceService")
	local Workspace = game:GetService("Workspace")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Hash = import("Core/Hash")
	local Integrity = import("Core/Integrity")
	local Capabilities = import("Core/Capabilities")
	local Icons = import("Icons/Icon")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")
	local Drag = import("Services/Drag")

	local KeySystem = {}
	KeySystem.__index = KeySystem

	local vault = setmetatable({}, { __mode = "k" })
	local accept

	local function seal(self)
		local slot = vault[self]
		if not slot then
			return false
		end
		slot.proof = Hash.Hmac(slot.session, "unlocked|" .. tostring(self.Hwid))
		return true
	end

	local function sealed(self)
		local slot = vault[self]
		if not slot or not slot.proof then
			return false
		end
		return Hash.Equal(slot.proof, Hash.Hmac(slot.session, "unlocked|" .. tostring(self.Hwid)))
	end

	local function clock(seconds)
		seconds = math.max(math.ceil(seconds), 0)
		return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
	end

	local function list(value)
		if value == nil then
			return nil
		end
		if type(value) ~= "table" then
			return { value }
		end
		return value
	end

	local function lines(body)
		local out = {}
		for line in string.gmatch(tostring(body), "[^\r\n]+") do
			line = string.gsub(line, "^%s*(.-)%s*$", "%1")
			if line ~= "" and string.sub(line, 1, 1) ~= "#" then
				table.insert(out, line)
			end
		end
		return out
	end

	local function viewportScale()
		local camera = Workspace.CurrentCamera
		if not camera or camera.ViewportSize.Y <= 0 then
			return 1
		end
		return math.clamp(camera.ViewportSize.Y / 900, 0.78, 1.3)
	end

	local function assetId(text)
		return tonumber(string.match(tostring(text), "(%d+)") or "") or 0
	end

	local function wearing(player, id)
		id = tonumber(id) or 0
		if id == 0 then
			return false
		end
		local character = player.Character
		if character then
			for _, item in character:GetDescendants() do
				if item:IsA("Shirt") and assetId(item.ShirtTemplate) == id then
					return true
				elseif item:IsA("Pants") and assetId(item.PantsTemplate) == id then
					return true
				elseif item:IsA("ShirtGraphic") and assetId(item.Graphic) == id then
					return true
				elseif item:IsA("Accessory") then
					if item:GetAttribute("AssetId") == id then
						return true
					end
					local handle = item:FindFirstChild("Handle")
					local mesh = handle and (handle:FindFirstChildWhichIsA("SpecialMesh") or handle)
					if mesh then
						local texture = mesh:IsA("SpecialMesh") and mesh.TextureId or (mesh:IsA("MeshPart") and mesh.TextureID or "")
						local meshId = mesh:IsA("SpecialMesh") and mesh.MeshId or (mesh:IsA("MeshPart") and mesh.MeshId or "")
						if assetId(texture) == id or assetId(meshId) == id then
							return true
						end
					end
				end
			end
		end
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok and description then
			for _, field in { "Shirt", "Pants", "GraphicTShirt", "HatAccessory", "FaceAccessory", "BackAccessory", "FrontAccessory", "NeckAccessory", "ShouldersAccessory", "WaistAccessory" } do
				local value = description[field]
				if value ~= nil then
					for part in string.gmatch(tostring(value), "%d+") do
						if tonumber(part) == id then
							return true
						end
					end
				end
			end
		end
		return false
	end

	function KeySystem.new(config)
		config = config or {}
		Utility.Check(type(config) == "table", "KeySystem", "?", "Config must be a table.")
		local self = setmetatable({}, KeySystem)
		self.Cleanup = Cleanup.new()
		self.Validated = Signal.new()
		self.Rejected = Signal.new()
		self.Config = config
		self.Salt = config.Salt or "DeaDx"
		self.File = config.File or "DeaDx/key.dat"
		self.Attempts = config.Attempts or 5
		self.Lockout = config.Lockout or 30
		self.Require = config.Require == "all" and "all" or "any"
		self._left = self.Attempts
		self._done = false
		vault[self] = { session = Hash.Nonce(24) }
		self._rows = {}
		local cleanup = self.Cleanup
		cleanup:Add(self.Validated)
		cleanup:Add(self.Rejected)

		self.Player = Players.LocalPlayer
		self.Hwid = Capabilities.Hwid()
		self.HwidShort = string.sub(Hash.Sha256(self.Hwid), 1, 18)

		self.Plus = config.Plus
		if self.Plus then
			Utility.Check(type(self.Plus) == "table", "KeySystem", "Plus", "Plus must be a table.")
			Utility.Check(
				type(self.Plus.Endpoint) == "string" and self.Plus.Endpoint ~= "",
				"KeySystem",
				"Plus",
				"Plus needs an Endpoint."
			)
		end
		self.Luarmor = config.Luarmor
		if self.Luarmor then
			if type(self.Luarmor) == "string" then
				self.Luarmor = { ScriptId = self.Luarmor }
			end
			Utility.Check(
				type(self.Luarmor) == "table" and type(self.Luarmor.ScriptId) == "string",
				"KeySystem",
				"Luarmor",
				"Luarmor needs a ScriptId."
			)
		end
		self.Checks = self:_BuildChecks()
		self.UsesKey = (
			config.Key
			or config.Keys
			or config.Hashes
			or config.Url
			or config.Endpoint
			or config.Validate
			or config.Plus
			or config.Luarmor
		) ~= nil

		if config.Integrity ~= false then
			local clean, failures = Integrity.Scan()
			self._tampered = not clean
			self._tamperList = failures
		end

		local gui = cleanup:Add(Utility.NewScreenGui("DeaDx_Key", config.DisplayOrder or 2400))
		gui.IgnoreGuiInset = true
		self.Gui = gui

		local backdrop = Utility.Create("Frame", {
			Name = "Backdrop",
			BackgroundColor3 = Color3.fromRGB(6, 6, 8),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Active = true,
			Parent = gui,
		})
		Animation:Play(backdrop, { BackgroundTransparency = config.Dim or 0.2 }, { Duration = 0.2 })
		self._backdrop = backdrop

		local stage = Utility.Create("Frame", {
			Name = "Stage",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(config.Width or 400, 120),
			Parent = backdrop,
		})
		self.Stage = stage
		local scale = Instance.new("UIScale")
		scale.Scale = viewportScale() * 0.96
		scale.Parent = stage
		self._scale = scale

		local card = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Key",
			Parent = stage,
			Fill = "Background",
			Transparency = 0.04,
			Stroke = "Border",
			StrokeTransparency = 0.3,
			Radius = 24,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = 1,
		})
		self.Card = card
		Widgets.Padding(card, 24, 24)
		Widgets.List(card, 14)

		local head = Utility.Create("Frame", {
			Name = "Head",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = 1,
			Parent = card,
		})
		local badge = Widgets.Surface(cleanup, {
			Parent = head,
			Fill = config.IconBackground or "SecondaryBackground",
			Stroke = "Border",
			StrokeTransparency = 0.35,
			Radius = 14,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
		})
		Icons.Create(badge, config.Icon or "key-round", {
			Size = 22,
			Color = config.IconColor or "Accent",
			Position = UDim2.fromOffset(11, 11),
			Cleanup = cleanup,
		})
		Widgets.Text(cleanup, {
			Parent = head,
			Text = config.Title or "Key system",
			Color = config.TitleColor or "Text",
			Gradient = config.TitleGradient,
			Heavy = true,
			TextSize = 21,
			Position = UDim2.fromOffset(56, 3),
			Size = UDim2.new(1, -56, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Widgets.Text(cleanup, {
			Parent = head,
			Text = config.Subtitle or (self.UsesKey and "Enter your key to continue" or "Access requirements"),
			Color = "MutedText",
			TextSize = 12,
			Position = UDim2.fromOffset(56, 25),
			Size = UDim2.new(1, -56, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		if config.Note then
			local note = Widgets.Surface(cleanup, {
				Parent = card,
				Fill = "SecondaryBackground",
				Transparency = 0.3,
				Stroke = "Border",
				StrokeTransparency = 0.55,
				Radius = 13,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 2,
			})
			Widgets.Padding(note, 13, 11)
			Widgets.Text(cleanup, {
				Parent = note,
				Text = config.Note,
				Color = config.NoteColor or "MutedText",
				TextSize = 12,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
			})
		end

		if #self.Checks > 0 then
			local panel = Utility.Create("Frame", {
				Name = "Checks",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 3,
				Parent = card,
			})
			Widgets.List(panel, 6)
			for index, check in self.Checks do
				self._rows[index] = self:_Row(panel, check, index)
			end
		end

		if self.UsesKey then
			local holder, box, stroke, field = Widgets.Field(cleanup, {
				Name = "Input",
				Parent = card,
				Radius = 14,
				Placeholder = config.Placeholder or "paste your key here",
				Size = UDim2.new(1, 0, 0, 42),
				TextSize = 14,
				Inset = 14,
				Trail = 14,
				LayoutOrder = 4,
			})
			self._box, self._field, self._stroke = box, field, stroke
			self._holder = holder
			cleanup:Add(box.FocusLost:Connect(function(enter)
				if enter then
					self:Submit(box.Text)
				end
			end))
		end

		local buttons = Utility.Create("Frame", {
			Name = "Buttons",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 5,
			Parent = card,
		})
		Widgets.List(buttons, 9, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		self._buttons = buttons

		local links = config.Links or (config.Link and { { Title = "Get key", Url = config.Link } } or nil)
		local count = (links and links[1] and 1 or 0) + 1
		local width = 1 / count

		if links and links[1] then
			self:_Action(links[1].Title or "Get key", links[1].Icon or "link", false, 1, width, function()
				if Capabilities.SetClipboard(links[1].Url or "") then
					self:SetStatus("Link copied.", "Success")
				else
					self:SetStatus(links[1].Url or "", "Info")
				end
			end)
		end

		self._submit = self:_Action(
			config.SubmitText or (self.UsesKey and "Verify" or "Check access"),
			"check",
			true,
			2,
			width,
			function()
				if self.UsesKey and self._box then
					self:Submit(self._box.Text)
				else
					self:Recheck(true)
				end
			end
		)

		local status = Utility.Create("Frame", {
			Name = "Status",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 6,
			Parent = card,
		})
		local _, statusText = Widgets.Text(cleanup, {
			Parent = status,
			Text = "",
			Color = "MutedText",
			TextSize = 12,
			Size = UDim2.new(1, -52, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		self._status = statusText
		if self.UsesKey then
			local _, attempts = Widgets.Text(cleanup, {
				Parent = status,
				Text = string.format("%d/%d", self._left, self.Attempts),
				Color = "MutedText",
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(50, 16),
				Markup = false,
			})
			self._attempts = attempts
		end

		if config.ShowHwid ~= false then
			local row = Widgets.Surface(cleanup, {
				Class = "TextButton",
				Parent = card,
				Fill = "SecondaryBackground",
				Transparency = 0.4,
				Radius = 11,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 7,
			})
			Icons.Create(row, "fingerprint", {
				Size = 13,
				Color = "MutedText",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 11, 0.5, 0),
				Cleanup = cleanup,
			})
			Widgets.Text(cleanup, {
				Parent = row,
				Text = "HWID " .. self.HwidShort,
				Color = "MutedText",
				TextSize = 11,
				Position = UDim2.fromOffset(30, 0),
				Size = UDim2.new(1, -62, 1, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Markup = false,
			})
			local copyIcon = Icons.Create(row, "copy", {
				Size = 13,
				Color = "MutedText",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -11, 0.5, 0),
				Cleanup = cleanup,
			})
			Widgets.Interactive(cleanup, row, row, { Base = "SecondaryBackground", Alpha = { 0.4, 0.24, 0.14 } })
			cleanup:Add(row.Activated:Connect(function()
				if Capabilities.SetClipboard(self.Hwid) then
					copyIcon:Set("check")
					self:SetStatus("HWID copied.", "Success")
					task.delay(1.2, function()
						if not self._done then
							copyIcon:Set("copy")
						end
					end)
				end
			end))
		end

		if config.Draggable ~= false then
			card.Active = true
			Drag.Attach(card, stage, cleanup, { Margin = 60, Ignore = { self._holder, buttons } })
		end

		Animation:Play(card, { GroupTransparency = 0 }, { Duration = 0.2 })
		Animation:Play(scale, { Scale = viewportScale() }, { Duration = 0.28, Style = Enum.EasingStyle.Back })

		if self._tampered then
			self:SetStatus("Tampered environment: " .. (self._tamperList[1] or "hook"), "Error")
			Utility.SafeCall("KeySystem OnTamper", config.OnTamper, self._tamperList)
			if config.BlockOnTamper then
				self._blocked = true
			end
		end

		if config.Integrity ~= false and config.Guard ~= false then
			local watched = {
				{ Name = "KeySystem.IsValid", Fn = KeySystem.IsValid, Lua = true },
				{ Name = "KeySystem.Submit", Fn = KeySystem.Submit, Lua = true },
				{ Name = "KeySystem.Wait", Fn = KeySystem.Wait, Lua = true },
				{ Name = "KeySystem.accept", Fn = accept, Lua = true },
				{ Name = "Hash.Hmac", Fn = Hash.Hmac, Lua = true },
				{ Name = "Hash.Equal", Fn = Hash.Equal, Lua = true },
			}
			self._guard = Integrity.Guard(config.GuardInterval or 6, function(failures)
				self._tampered = true
				Utility.SafeCall("KeySystem OnTamper", config.OnTamper, failures)
			end, watched)
			cleanup:Add(function()
				self._guard.Stop()
			end)
		end

		task.defer(function()
			if config.Remember ~= false and self:_LoadSaved() then
				accept(self, "Saved key accepted.", true)
				return
			end
			if #self.Checks > 0 then
				self:Recheck(false)
			end
		end)
		return self
	end

	function KeySystem:_Action(text, iconName, primary, order, width, callback)
		local cleanup = self.Cleanup
		local config = self.Config
		local button = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Parent = self._buttons,
			Fill = primary and (config.Accent or "Accent") or "SecondaryBackground",
			Stroke = (not primary) and "Border" or nil,
			StrokeTransparency = 0.35,
			Radius = 13,
			Size = UDim2.new(width or 0.5, -5, 1, 0),
			LayoutOrder = order,
		})
		local icon = Icons.Create(button, iconName, {
			Size = 15,
			Color = primary and "AccentText" or "MutedText",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Cleanup = cleanup,
		})
		Widgets.Text(cleanup, {
			Parent = button,
			Text = text,
			Color = primary and "AccentText" or "Text",
			Bold = true,
			TextSize = 13,
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -44, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Widgets.Interactive(cleanup, button, button, {
			Base = primary and (config.Accent or "Accent") or "SecondaryBackground",
			Hover = primary and (config.Accent or "Accent") or "Hover",
			Pressed = primary and (config.Accent or "Accent") or "Pressed",
			Alpha = primary and { 0, 0.12, 0.25 } or nil,
		})
		cleanup:Add(button.Activated:Connect(callback))
		return button, icon
	end

	function KeySystem:_BuildChecks()
		local config = self.Config
		local player = Players.LocalPlayer
		local checks = {}

		local function add(kind, label, icon, run)
			table.insert(checks, { Kind = kind, Label = label, Icon = icon, Run = run, State = "pending" })
		end

		if config.Group then
			local groups = list(config.Group)
			for _, id in groups do
				local rank = config.GroupRank or 0
				add("group", config.GroupText or ("Join the group " .. tostring(id)), "users", function()
					local ok, member = pcall(function()
						return player:IsInGroup(id)
					end)
					if not ok or not member then
						return false, "you are not in the group"
					end
					if rank > 0 then
						local okRank, value = pcall(function()
							return player:GetRankInGroup(id)
						end)
						if not okRank or value < rank then
							return false, "rank too low"
						end
					end
					return true
				end)
			end
		end

		for _, id in list(config.Gamepass) or {} do
			add("gamepass", config.GamepassText or ("Buy the gamepass " .. tostring(id)), "shopping-cart", function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
				end)
				if ok and owns then
					return true
				end
				return false, "gamepass not found"
			end)
		end

		for _, id in list(config.Asset) or {} do
			add("asset", config.AssetText or ("Own the item " .. tostring(id)), "shirt", function()
				local ok, owns = pcall(function()
					return MarketplaceService:PlayerOwnsAsset(player, id)
				end)
				if ok and owns then
					return true
				end
				return false, "item not found"
			end)
		end

		for _, id in list(config.Wearing) or {} do
			add("wearing", config.WearingText or ("Wear the item " .. tostring(id)), "shirt", function()
				if wearing(player, id) then
					return true
				end
				return false, "item not equipped"
			end)
		end

		if config.Whitelist then
			add("whitelist", config.WhitelistText or "Be on the whitelist", "user-check", function()
				for _, entry in config.Whitelist do
					if type(entry) == "number" and entry == player.UserId then
						return true
					end
					if type(entry) == "string" then
						local lowered = string.lower(entry)
						if lowered == string.lower(player.Name) or lowered == string.lower(player.DisplayName) then
							return true
						end
					end
				end
				if type(config.WhitelistUrl) == "string" then
					local ok, body = Capabilities.HttpGet(config.WhitelistUrl)
					if ok then
						for _, entry in lines(body) do
							if entry == tostring(player.UserId) or string.lower(entry) == string.lower(player.Name) then
								return true
							end
						end
					end
				end
				return false, "name not listed"
			end)
		end

		if config.Premium then
			add("premium", "Have Roblox Premium", "crown", function()
				if player.MembershipType == Enum.MembershipType.Premium then
					return true
				end
				return false, "no premium"
			end)
		end

		if config.Checks then
			for _, entry in config.Checks do
				if type(entry) == "table" and type(entry.Run) == "function" then
					add(entry.Kind or "custom", entry.Label or "Requirement", entry.Icon or "circle-check", entry.Run)
				end
			end
		end

		return checks
	end

	function KeySystem:_Row(parent, check, index)
		local cleanup = self.Cleanup
		local row = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Parent = parent,
			Fill = "SecondaryBackground",
			Transparency = 0.42,
			Stroke = "Border",
			StrokeTransparency = 0.6,
			Radius = 12,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = index,
		})
		local icon = Icons.Create(row, check.Icon or "circle-check", {
			Size = 15,
			Color = "MutedText",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Cleanup = cleanup,
		})
		local _, label = Widgets.Text(cleanup, {
			Parent = row,
			Text = check.Label,
			Color = "Text",
			TextSize = 12,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -62, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local mark = Icons.Create(row, "loader", {
			Size = 14,
			Color = "MutedText",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Cleanup = cleanup,
		})
		Widgets.Interactive(cleanup, row, row, { Base = "SecondaryBackground", Alpha = { 0.42, 0.26, 0.16 } })
		cleanup:Add(row.Activated:Connect(function()
			self:Recheck(true)
		end))
		return { Frame = row, Icon = icon, Label = label, Mark = mark, Check = check }
	end

	function KeySystem:_Paint(index, state, reason)
		local row = self._rows[index]
		if not row then
			return
		end
		local check = row.Check
		check.State = state
		check.Reason = reason
		if state == "ok" then
			row.Mark:Set("circle-check")
			row.Mark:SetColor("Success")
			row.Icon:SetColor("Success")
			Widgets.Pulse(row.Mark.Instance, 0.6, 0.3)
		elseif state == "fail" then
			row.Mark:Set("circle-x")
			row.Mark:SetColor("Error")
			row.Icon:SetColor("MutedText")
		else
			row.Mark:Set("loader")
			row.Mark:SetColor("MutedText")
		end
		if reason and state == "fail" then
			row.Label.SetText(check.Label .. "  <fade:0.35>(" .. reason .. ")</fade>")
		else
			row.Label.SetText(check.Label)
		end
	end

	function KeySystem:Recheck(manual)
		if self._done or self._checking then
			return self
		end
		self._checking = true
		if manual then
			self:SetStatus("Checking requirements...")
		end
		task.spawn(function()
			local passed, total = 0, #self.Checks
			for index, check in self.Checks do
				self:_Paint(index, "pending")
				local ok, reason = check.Run()
				if ok == true then
					passed += 1
					self:_Paint(index, "ok")
				else
					self:_Paint(index, "fail", reason)
				end
			end
			self._checking = false
			if self._done then
				return
			end
			self._passed = passed
			local granted = total > 0 and (self.Require == "all" and passed == total or (self.Require == "any" and passed > 0))
			if granted and not self.UsesKey then
				accept(self, "Access granted.")
				return
			end
			if granted and self.Require == "any" then
				accept(self, "Access granted by whitelist.")
				return
			end
			if manual then
				if total > 0 and passed == 0 then
					self:SetStatus("No requirement met.", "Error")
					self:_Shake()
				elseif self.UsesKey then
					self:SetStatus("Requirements missing. Use a key.", "Error")
				end
			end
		end)
		return self
	end

	function KeySystem:SetStatus(text, kind)
		if not self._status then
			return self
		end
		self._status.SetText(text or "")
		self._status.SetColor(kind == "Success" and "Success" or (kind == "Error" and "Error" or "MutedText"))
		return self
	end

	function KeySystem:_Shake()
		local stage = self.Stage
		local base = stage.Position
		task.spawn(function()
			for _, offset in { 11, -9, 6, -4, 0 } do
				if not stage.Parent then
					return
				end
				Animation:Play(stage, {
					Position = UDim2.new(base.X.Scale, base.X.Offset + offset, base.Y.Scale, base.Y.Offset),
				}, { Duration = 0.045 })
				task.wait(0.05)
			end
			if stage.Parent then
				stage.Position = base
			end
		end)
		if self._stroke then
			Widgets.Glow(self._stroke, "Error", 0.6)
		end
	end

	function KeySystem:_Token()
		return Hash.Salted(self.Hwid .. "|" .. tostring(self.Config.Product or "DeaDx"), self.Salt)
	end

	function KeySystem:_SaveKey(key)
		if self.Config.Remember == false or not Capabilities.FileSystem then
			return false
		end
		local payload = {
			t = self:_Token(),
			k = Hash.Salted(key, self.Salt),
			e = self.Config.ExpiresIn and (os.time() + self.Config.ExpiresIn) or 0,
		}
		if self.Plus or self.Luarmor then
			payload.p = Hash.Encode(key, self:_Token())
		end
		local ok, body = pcall(HttpService.JSONEncode, HttpService, payload)
		if not ok then
			return false
		end
		Capabilities.EnsureFolder(string.match(self.File, "^(.*)/[^/]+$") or "DeaDx")
		return (pcall(Capabilities.FS.Write, self.File, Hash.Encode(body, self.Hwid)))
	end

	function KeySystem:_LoadSaved()
		if not Capabilities.FileSystem or not Capabilities.FS.IsFile(self.File) then
			return false
		end
		local ok, raw = pcall(Capabilities.FS.Read, self.File)
		if not ok or type(raw) ~= "string" then
			return false
		end
		local decoded = Hash.Decode(raw, self.Hwid)
		if not decoded then
			return false
		end
		local parsed, payload = pcall(HttpService.JSONDecode, HttpService, decoded)
		if not parsed or type(payload) ~= "table" then
			return false
		end
		if not Hash.Equal(tostring(payload.t), self:_Token()) then
			return false
		end
		if type(payload.e) == "number" and payload.e > 0 and os.time() > payload.e then
			pcall(Capabilities.FS.Delete, self.File)
			return false
		end
		if self.Luarmor then
			local stored = type(payload.p) == "string" and Hash.Decode(payload.p, self:_Token()) or nil
			if not stored then
				return false
			end
			local Luarmor = import("Services/Luarmor")
			local status = Luarmor.Check(self.Luarmor, stored)
			if status.code ~= "KEY_VALID" then
				self._savedReason = status.message
				return false
			end
			self.Status = status
			self.Info = Luarmor.Info(status)
			Luarmor.SetKey(stored)
			if self.Luarmor.Load then
				task.defer(function()
					Luarmor.Load(self.Luarmor, stored)
				end)
			end
			return true
		end

		if self.Plus then
			local stored = type(payload.p) == "string" and Hash.Decode(payload.p, self:_Token()) or nil
			if not stored then
				return false
			end
			local body, reason = import("Services/KeyPlus").Request(self.Plus, stored)
			if not body then
				self._plusReason = reason
				return false
			end
			self._payload = body
			return true
		end
		return self:_Match(nil, payload.k)
	end

	function KeySystem:Forget()
		if Capabilities.FileSystem and Capabilities.FS.Delete and Capabilities.FS.IsFile(self.File) then
			pcall(Capabilities.FS.Delete, self.File)
		end
		return self
	end

	function KeySystem:_Remote()
		local config = self.Config
		if self._remote ~= nil then
			return self._remote
		end
		if type(config.Url) ~= "string" then
			self._remote = false
			return false
		end
		local ok, body = Capabilities.HttpGet(config.Url)
		self._remote = ok and lines(body) or false
		return self._remote
	end

	function KeySystem:_Match(key, hashed)
		local config = self.Config
		local digest = hashed or Hash.Salted(key, self.Salt)

		if type(config.Validate) == "function" and key ~= nil then
			local ok, result = pcall(config.Validate, key, self.Hwid)
			if ok and result == true then
				return true
			end
		end

		for _, entry in config.Hashes or {} do
			if Hash.Equal(string.lower(tostring(entry)), digest) then
				return true
			end
		end

		if key ~= nil then
			local plain = config.Keys or (config.Key and { config.Key } or nil)
			for _, entry in plain or {} do
				if Hash.Equal(Hash.Salted(tostring(entry), self.Salt), digest) then
					return true
				end
			end
		end

		local remote = self:_Remote()
		if type(remote) == "table" then
			for _, entry in remote do
				entry = string.lower(entry)
				if Hash.Equal(entry, digest) then
					return true
				end
				if key ~= nil and Hash.Equal(Hash.Salted(entry, self.Salt), digest) then
					return true
				end
			end
		end

		return false
	end

	function KeySystem:_Endpoint(key)
		local config = self.Config
		if type(config.Endpoint) ~= "string" then
			return nil
		end
		local url = config.Endpoint
		local replacements = {
			key = HttpService:UrlEncode(key),
			hwid = HttpService:UrlEncode(self.Hwid),
			user = HttpService:UrlEncode(self.Player and self.Player.Name or ""),
			userid = tostring(self.Player and self.Player.UserId or 0),
			place = tostring(game.PlaceId),
		}
		url = string.gsub(url, "{(%w+)}", function(name)
			return replacements[string.lower(name)] or ""
		end)
		if string.find(url, "%%s") then
			local count = select(2, string.gsub(url, "%%s", ""))
			url = count >= 2 and string.format(url, replacements.key, replacements.hwid)
				or string.format(url, replacements.key)
		end
		local ok, body = Capabilities.HttpGet(url)
		if not ok or type(body) ~= "string" then
			return false, "no response from the server"
		end
		local expect = config.Expect
		if type(expect) == "string" then
			return string.find(body, expect, 1, true) ~= nil
		end
		local parsed, data = pcall(HttpService.JSONDecode, HttpService, body)
		if parsed and type(data) == "table" then
			if data.valid == true or data.success == true or data.status == "ok" then
				return true
			end
			return false, data.message or data.error
		end
		local trimmed = string.lower((string.gsub(body, "%s", "")))
		return trimmed == "true" or trimmed == "1" or trimmed == "ok"
	end

	function KeySystem:IsLocked()
		return self._lockUntil ~= nil and os.clock() < self._lockUntil
	end

	function KeySystem:_Lock()
		self._lockUntil = os.clock() + self.Lockout
		self._left = self.Attempts
		if self._box then
			self._box.TextEditable = false
		end
		task.spawn(function()
			while self:IsLocked() and not self._done do
				self:SetStatus("Locked for " .. clock(self._lockUntil - os.clock()), "Error")
				task.wait(0.2)
			end
			if not self._done then
				self._lockUntil = nil
				if self._box then
					self._box.TextEditable = true
				end
				if self._attempts then
					self._attempts.SetText(string.format("%d/%d", self._left, self.Attempts))
				end
				self:SetStatus("You can try again.")
			end
		end)
	end

	function accept(self, message, silent)
		if self._done then
			return
		end
		if self._blocked then
			self:SetStatus("Blocked: tampered environment.", "Error")
			return
		end
		self._done = true
		seal(self)
		self:SetStatus(message or "Key accepted.", "Success")
		if self._stroke then
			Widgets.Glow(self._stroke, "Success", 0.6)
		end
		self.Validated:Fire(self._payload, self.Info)
		Utility.SafeCall("KeySystem OnSuccess", self.Config.OnSuccess, self._payload, self.Info)
		if self._payload then
			Utility.SafeCall("KeySystem OnUnlock", self.Config.OnUnlock, self._payload)
		end
		task.delay(silent and 0.05 or 0.3, function()
			Animation:Play(self._scale, { Scale = self._scale.Scale * 1.03 }, { Duration = 0.2 })
			Animation:Play(self.Card, { GroupTransparency = 1 }, { Duration = 0.2 })
			Animation:Play(self._backdrop, { BackgroundTransparency = 1 }, {
				Duration = 0.2,
				OnComplete = function()
					self.Cleanup:Clean()
				end,
			})
			task.delay(0.6, function()
				self.Cleanup:Clean()
			end)
		end)
	end

	function KeySystem:Submit(key)
		if self._done or self._checking then
			return self
		end
		if self:IsLocked() then
			self:_Shake()
			return self
		end
		key = string.gsub(tostring(key or ""), "^%s*(.-)%s*$", "%1")
		if key == "" then
			self:SetStatus("Type a key.", "Error")
			self:_Shake()
			return self
		end

		self._checking = true
		self:SetStatus("Checking...")
		task.spawn(function()
			if self.Luarmor then
				local Luarmor = import("Services/Luarmor")
				local status = Luarmor.Check(self.Luarmor, key)
				self._checking = false
				if self._done then
					return
				end
				self.Status = status
				self.Info = Luarmor.Info(status)

				if status.code == "KEY_VALID" then
					Luarmor.SetKey(key)
					self._payload = nil
					self:_SaveKey(key)
					local note = self.Info and (" - " .. Luarmor.Remaining(self.Info)) or ""
					accept(self, "Key accepted" .. note .. ".")
					if self.Luarmor.Load then
						task.defer(function()
							local ok, reason = Luarmor.Load(self.Luarmor, key)
							if not ok then
								Utility.Warn("luarmor load_script failed: " .. tostring(reason))
							end
						end)
					end
					return
				end

				self:_Shake()
				self.Rejected:Fire(key, status.code)
				Utility.SafeCall("KeySystem OnFail", self.Config.OnFail, key, status.code, status.message)
				if Luarmor.IsOwnerFault(status.code) then
					Utility.Warn("luarmor: " .. tostring(status.message))
				end
				if Luarmor.IsFatal(status.code) then
					self:SetStatus(tostring(status.message), "Error")
					return
				end
				self._left -= 1
				if self._attempts then
					self._attempts.SetText(string.format("%d/%d", math.max(self._left, 0), self.Attempts))
				end
				if self._left <= 0 then
					self:_Lock()
				else
					self:SetStatus(tostring(status.message) .. " (" .. self._left .. ")", "Error")
				end
				return
			end

			if self.Plus then
				local body, reason = import("Services/KeyPlus").Request(self.Plus, key)
				self._checking = false
				if self._done then
					return
				end
				if body then
					self._payload = body
					self:_SaveKey(key)
					accept(self, "Unlocked by the server.")
					return
				end
				self._left -= 1
				if self._attempts then
					self._attempts.SetText(string.format("%d/%d", math.max(self._left, 0), self.Attempts))
				end
				self:_Shake()
				self.Rejected:Fire(key)
				Utility.SafeCall("KeySystem OnFail", self.Config.OnFail, key, reason)
				if self._left <= 0 then
					self:_Lock()
				else
					self:SetStatus(tostring(reason or "Invalid key") .. " (" .. self._left .. ")", "Error")
				end
				return
			end

			local ok = self:_Match(key)
			if not ok then
				local remote, reason = self:_Endpoint(key)
				if remote == true then
					ok = true
				elseif remote == false and reason then
					self:SetStatus(tostring(reason), "Error")
				end
			end
			if ok and self.Require == "all" and #self.Checks > 0 then
				local passed = 0
				for index, check in self.Checks do
					local good = check.Run()
					self:_Paint(index, good and "ok" or "fail")
					if good then
						passed += 1
					end
				end
				if passed < #self.Checks then
					ok = false
					self:SetStatus("Key is fine, requirements missing.", "Error")
				end
			end
			self._checking = false
			if self._done then
				return
			end
			if ok then
				self:_SaveKey(key)
				accept(self)
				return
			end
			self._left -= 1
			if self._attempts then
				self._attempts.SetText(string.format("%d/%d", math.max(self._left, 0), self.Attempts))
			end
			self:_Shake()
			self.Rejected:Fire(key)
			Utility.SafeCall("KeySystem OnFail", self.Config.OnFail, key)
			if self._left <= 0 then
				self:_Lock()
			else
				self:SetStatus("Invalid key. " .. self._left .. " tries left.", "Error")
			end
		end)
		return self
	end

	function KeySystem:IsValid()
		return sealed(self)
	end

	function KeySystem:GetPayload()
		return self._payload
	end

	function KeySystem:GetInfo()
		return self.Info
	end

	function KeySystem:GetStatus()
		return self.Status
	end

	function KeySystem:LoadScript()
		if not self.Luarmor then
			return false, "not a luarmor key system"
		end
		return import("Services/Luarmor").Load(self.Luarmor)
	end

	function KeySystem:PurgeCache()
		if not self.Luarmor then
			return false
		end
		return import("Services/Luarmor").PurgeCache(self.Luarmor)
	end

	function KeySystem:RunPayload()
		if type(self._payload) ~= "string" then
			return nil, "sem payload"
		end
		local compiled, err = loadstring(self._payload, "=DeaDx/KeyPlus")
		if not compiled then
			return nil, tostring(err)
		end
		local ok, result = pcall(compiled)
		if not ok then
			return nil, tostring(result)
		end
		return result or true
	end

	function KeySystem:Wait(timeout)
		local deadline = os.clock() + (tonumber(timeout) or 300)
		while not self._done and os.clock() < deadline do
			task.wait(0.04)
		end
		return sealed(self)
	end

	function KeySystem:Destroy()
		self._done = true
		self.Cleanup:Clean()
	end

	return KeySystem
end
