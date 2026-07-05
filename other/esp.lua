--[[
  esp.juice
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local My_Player = Players.LocalPlayer

local function Draw(class, props)
	local d = Drawing.new(class)
	for k, v in pairs(props) do d[k] = v end
	return d
end

local function makeLine()
	return Draw("Line", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 1, ZIndex = 1 })
end

local FONT = Drawing.Fonts.Plex
local SIZE = 13

local R15_SEGMENTS = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"},
	{"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"},
	{"RightUpperArm", "RightLowerArm"},
	{"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"},
	{"RightUpperLeg", "RightLowerLeg"},
	{"RightLowerLeg", "RightFoot"},
}

local R6_SEGMENTS = {
	{"Head", "Torso"},
	{"Torso", "Left Arm"},
	{"Torso", "Right Arm"},
	{"Torso", "Left Leg"},
	{"Torso", "Right Leg"},
}

local function isR15(character)
	return character:FindFirstChild("UpperTorso") ~= nil
end

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function isFn(v) return type(v) == "function" end
local function isSide(side)
	return side == "Left" or side == "Right" or side == "Top" or side == "Bottom"
end

local settings = {
	visuals = {
		master = true,
		box = true,
		name = true,
		UseDisplay = false,
		healthbar = true,
		ammobar = false,
		weapon = false,
		charge = false,
		team = false,
		state = false,
		exploit = false,
		filter = "Enemies + Team Medic",
		skeleton = false,
		offsetx = 0,
		offsety = 0,
		offsetz = 0,
		tracers = false,
		tracermode = "Solid",
		tracercolor = Color3.new(1, 1, 1),
		lifetime = 2,
	},
}

local Visuals = {
	_loop = nil,
	Bars = { Left = {}, Right = {}, Top = {}, Bottom = {} },
	Texts = { Left = {}, Right = {}, Top = {}, Bottom = {} },
	layout = { barThickness = 2, barGap = 3, textGap = 2, sidePadding = 4, textOffset = 12, barLengthPad = 0 },
	_layoutSetup = false,
}
Visuals.__index = Visuals

local player_array = { CurrentArrays = {} }
player_array.__index = player_array

local function searchWeapon(name)
	return game:GetService("ReplicatedStorage").Weapons:FindFirstChild(name)
end

local function applyToAny(obj, fn)
	if typeof(obj) == "DrawingObject" then
		fn(obj)
	elseif type(obj) == "table" then
		for _, v in pairs(obj) do applyToAny(v, fn) end
	end
end

function player_array:NewPlayerArray(char, player)
	if player == My_Player then return end

	if self.CurrentArrays[player] then
		self:SetStatus(player, 0)
		self.CurrentArrays[player]:RenderDrawings()
		return
	end

	local player_data = {
		Character = char,
		Player = player,
		Drawings = {},
		status = 0,
		_lastMoveTime = tick(),
		_stale = false,
		_teleport = false,
		_lastDelta = 0,
		_lastPosition = Vector3.new(),
		_lastHealthVariable = 0,
		_lastRender = tick(),
		_startTime = tick(),
		_flags = {},
		_deltaSamples = {},
		_lastBigJumpTime = 0,
		_lastBigJumpDelta = 0,
	}
	player_data.__index = player_data
	self.CurrentArrays[player] = player_data

	function player_data:RenderDrawings()
		local function makeLineLocal()
			return Draw("Line", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 1, ZIndex = 1 })
		end

		local drawings = {
			box_o = Draw("Square", { Filled = false, Thickness = 3, Color = Color3.new(0, 0, 0), ZIndex = -2 }),
			box = Draw("Square", { Filled = false, Thickness = 1, Color = Color3.new(1, 1, 1), ZIndex = -1 }),
			skeleton = {},
			bars = { Left = {}, Right = {}, Top = {}, Bottom = {} },
			texts = { Left = {}, Right = {}, Top = {}, Bottom = {} },
		}

		for i = 1, 20 do
			drawings.skeleton[i] = makeLineLocal()
		end

		local function makeBar()
			local t = (Visuals.layout and Visuals.layout.barThickness) or 2
			return {
				outline = Draw("Line", { Thickness = t + 2, Color = Color3.new(0, 0, 0), Transparency = 1, ZIndex = 2 }),
				fill = Draw("Line", { Thickness = t, Color = Color3.new(0, 1, 0), Transparency = 1, ZIndex = 3 }),
			}
		end

		local function makeText(cfg)
			return Draw("Text", {
				Outline = true,
				Center = cfg.center ~= false,
				Size = cfg.size or 13,
				Font = cfg.font or FONT,
				Color = Color3.new(1, 1, 1),
				ZIndex = 3,
				Text = "",
			})
		end

		for side, list in pairs(Visuals.Bars) do
			for _, cfg in ipairs(list) do
				drawings.bars[side][cfg.id] = makeBar()
			end
		end

		for side, list in pairs(Visuals.Texts) do
			for _, cfg in ipairs(list) do
				drawings.texts[side][cfg.id] = makeText(cfg)
			end
		end

		self.Drawings = drawings
		return drawings
	end

	function player_data:RemoveDrawings()
		local function removeAny(obj)
			if typeof(obj) == "DrawingObject" then
				obj.Visible = false
				obj:Remove()
			elseif type(obj) == "table" then
				for _, v in pairs(obj) do removeAny(v) end
			end
		end

		for _, d in pairs(self.Drawings) do
			removeAny(d)
		end
		self.Drawings = {}
	end

	player_data:RenderDrawings()
end

function player_array:Remove(player)
	if self.CurrentArrays[player] then
		self:SetStatus(player, 1)
		return
	end
end

function player_array:GetStatus(player)
	return self.CurrentArrays[player] and self.CurrentArrays[player].status == 0 or false
end

function player_array:SetStatus(player, status)
	if not self.CurrentArrays[player] then return end
	self.CurrentArrays[player].status = status or 1
	return self.CurrentArrays[player].status
end

function player_array:Get(player)
	if self.CurrentArrays[player] then return self.CurrentArrays[player] end
end

function player_array:GetArrays()
	return self.CurrentArrays
end

function Visuals:RegisterBar(cfg)
	assert(cfg and cfg.id and cfg.side, "RegisterBar needs id + side")
	assert(isSide(cfg.side), "Invalid bar side")
	cfg.priority = cfg.priority or 0
	table.insert(self.Bars[cfg.side], cfg)
	table.sort(self.Bars[cfg.side], function(a, b) return a.priority < b.priority end)
end

function Visuals:RegisterText(cfg)
	assert(cfg and cfg.id and cfg.side, "RegisterText needs id + side")
	assert(isSide(cfg.side), "Invalid text side")
	cfg.priority = cfg.priority or 0
	table.insert(self.Texts[cfg.side], cfg)
	table.sort(self.Texts[cfg.side], function(a, b) return a.priority < b.priority end)
end

function Visuals:GetPingSeconds()
	local lp = Players.LocalPlayer
	if lp and lp.GetNetworkPing then
		local ok, v = pcall(function() return lp:GetNetworkPing() end)
		if ok and type(v) == "number" then
			return v
		end
	end
	return 0.05
end

function Visuals:GetScreenPos(world_position)
	local viewport_size = Camera.ViewportSize
	local local_position = Camera.CFrame:pointToObjectSpace(world_position)

	local aspect_ratio = viewport_size.x / viewport_size.y
	local half_height = -local_position.z * math.tan(math.rad(Camera.FieldOfView / 2))
	local half_width = aspect_ratio * half_height

	local far_plane_corner = Vector3.new(-half_width, half_height, local_position.z)
	local relative_position = local_position - far_plane_corner

	local screen_x = relative_position.x / (half_width * 2)
	local screen_y = -relative_position.y / (half_height * 2)

	local is_on_screen = -local_position.z > 0
		and screen_x >= 0
		and screen_x <= 1
		and screen_y >= 0
		and screen_y <= 1

	return Vector2.new(screen_x * viewport_size.x, screen_y * viewport_size.y), is_on_screen
end

function Visuals:SolveBox(target)
	local cam = Camera
	local vp = cam.ViewportSize

	local function invalid()
		return Vector2.zero, Vector2.zero, false, 0
	end

	local char
	if typeof(target) == "Instance" then
		if target:IsA("Model") then
			char = target
		elseif target:IsA("BasePart") then
			char = target:FindFirstAncestorOfClass("Model")
		end
	end
	if not char then return invalid() end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")

	local leftFoot = char:FindFirstChild("LeftFoot")
		or char:FindFirstChild("Left Leg")
		or char:FindFirstChild("LeftLowerLeg")
		or char:FindFirstChild("LeftUpperLeg")

	if not head and hrp then head = hrp end
	if not leftFoot and hrp then leftFoot = hrp end
	if not head or not leftFoot then return invalid() end

	local headPos = head.Position + Vector3.new(0, 1, 0)
	local footPos = leftFoot.Position - Vector3.new(0, 0.0, 0)
	if leftFoot == hrp then
		footPos = hrp.Position - Vector3.new(0, 3.0, 0)
	end

	local head2, headOn = self:GetScreenPos(headPos)
	local foot2, footOn = self:GetScreenPos(footPos)

	local onScreen = (headOn or footOn)
	if not onScreen then return invalid() end

	local height = math.abs(head2.Y - foot2.Y)
	height = math.clamp(height, 18, vp.Y)

	local halfW_fromBones = math.abs(head2.X - foot2.X)
	local width = math.max(halfW_fromBones * 2, height * 0.45)
	width = math.clamp(width, 8, vp.X)

	local centerWorld = (hrp and hrp.Position) or ((headPos + footPos) * 0.5)
	local center2 = self:GetScreenPos(centerWorld)

	local pad = 2
	local boxSize = Vector2.new(math.floor(width + pad * 2), math.floor(height + pad * 2))
	local boxPos = Vector2.new(
		math.floor(center2.X - boxSize.X * 0.5),
		math.floor(math.min(head2.Y, foot2.Y) - pad)
	)

	boxPos = Vector2.new(
		math.clamp(boxPos.X, 0, vp.X),
		math.clamp(boxPos.Y, 0, vp.Y)
	)

	local distance = (centerWorld - cam.CFrame.Position).Magnitude
	return boxSize, boxPos, onScreen, distance
end

function Visuals:UpdateSkeleton(character, drawings, vis)
	local lines = drawings.skeleton
	if not lines then return end

	local segments = isR15(character) and R15_SEGMENTS or R6_SEGMENTS
	local idx = 1

	for i = 1, #segments do
		local a = character:FindFirstChild(segments[i][1])
		local b = character:FindFirstChild(segments[i][2])
		local line = lines[idx]
		idx = idx + 1
		if not line then break end

		if vis and settings.visuals.skeleton and a and b then
			local a2, aOn = self:GetScreenPos(a.Position)
			local b2, bOn = self:GetScreenPos(b.Position)
			line.From = a2
			line.To = b2
			line.Visible = (aOn or bOn)
		else
			line.Visible = false
		end
	end

	for j = idx, #lines do
		lines[j].Visible = false
	end
end

function Visuals:GetSideBarLine(boxPos, boxSize, side, index)
	local L = self.layout
	local pad = L.sidePadding or 4
	local gap = L.barGap or 3
	local t = L.barThickness or 2

	if side == "Left" then
		local x = boxPos.X - pad - (index - 1) * (t + gap)
		return Vector2.new(x, boxPos.Y + boxSize.Y + 1), Vector2.new(x, boxPos.Y - 1), "Vertical"
	elseif side == "Right" then
		local x = boxPos.X + boxSize.X + pad + (index - 1) * (t + gap)
		return Vector2.new(x, boxPos.Y + boxSize.Y + 1), Vector2.new(x, boxPos.Y - 1), "Vertical"
	elseif side == "Top" then
		local y = boxPos.Y - pad - (index - 1) * (t + gap)
		return Vector2.new(boxPos.X - 1, y), Vector2.new(boxPos.X + boxSize.X + 1, y), "Horizontal"
	elseif side == "Bottom" then
		local y = boxPos.Y + boxSize.Y + pad + (index - 1) * (t + gap)
		return Vector2.new(boxPos.X - 1, y), Vector2.new(boxPos.X + boxSize.X + 1, y), "Horizontal"
	end
end

function Visuals:GetSideTextPos(boxPos, boxSize, side, index, textDrawing)
	local L = self.layout
	local pad = L.sidePadding or 4
	local gap = L.textGap or 2

	local bounds = (textDrawing and textDrawing.TextBounds) or Vector2.new(0, 13)
	local w, h = bounds.X, bounds.Y

	local stackY = (index - 1) * (h + gap)

	if side == "Top" then
		return Vector2.new(boxPos.X + boxSize.X * 0.5, boxPos.Y - pad - stackY - h)
	elseif side == "Bottom" then
		return Vector2.new(boxPos.X + boxSize.X * 0.5, boxPos.Y + boxSize.Y + pad + stackY)
	elseif side == "Left" then
		local x = boxPos.X - pad - w * 0.5
		local y = boxPos.Y + stackY
		return Vector2.new(x, y)
	elseif side == "Right" then
		local x = boxPos.X + boxSize.X + pad + w * 0.5
		local y = boxPos.Y + stackY
		return Vector2.new(x, y)
	end
end

function Visuals:RenderLayout(array, boxPos, boxSize, vis, humanoid, hrp)
	local drawings = array.Drawings
	if not drawings then return end

	for side, list in pairs(self.Bars) do
		local stack = 0
		for _, cfg in ipairs(list) do
			local bar = drawings.bars[side][cfg.id]
			if bar then
				local show = vis and (cfg.visibleFn and cfg.visibleFn(array, humanoid, hrp))
				if show then
					stack = stack + 1
					local from, to, orient = self:GetSideBarLine(boxPos, boxSize, side, stack)

					local v = 0
					if cfg.valueFn then
						local a, b = cfg.valueFn(array, humanoid, hrp)
						if b ~= nil then
							v = b > 0 and (a / b) or 0
						else
							v = a or 0
						end
					end

					v = math.clamp(v, 0, 1)

					local thick = cfg.thickness or self.layout.barThickness
					bar.fill.Thickness = 1
					bar.outline.Thickness = 3

					bar.outline.From = from
					bar.outline.To = to

					bar.fill.Color = (cfg.colorFn and cfg.colorFn(array, humanoid, hrp, v)) or Color3.new(0, 1, 0)

					if orient == "Vertical" then
						from = from - Vector2.new(0, 1)
						to = to + Vector2.new(0, 1)

						local full = (from - to).Magnitude
						bar.fill.From = from
						bar.fill.To = Vector2.new(from.X, from.Y - full * v)
					else
						from = from + Vector2.new(1, 0)
						to = to - Vector2.new(1, 0)

						local full = (to - from).Magnitude
						bar.fill.From = from
						bar.fill.To = Vector2.new(from.X + full * v, from.Y)
					end

					bar.outline.Visible = true
					bar.fill.Visible = true
				else
					bar.outline.Visible = false
					bar.fill.Visible = false
				end
			end
		end
	end

	for side, list in pairs(self.Texts) do
		local stack = 0
		for _, cfg in ipairs(list) do
			local t = drawings.texts[side][cfg.id]
			if t then
				local show = vis and cfg.visibleFn and cfg.visibleFn(array, humanoid, hrp)
				if show then
					stack = stack + 1
					t.Visible = true
					t.Position = self:GetSideTextPos(boxPos, boxSize, side, stack, t)
					t.Text = cfg.textFn and cfg.textFn(array, humanoid, hrp, t) or ""
					t.Color = (cfg.colorFn and cfg.colorFn(array, humanoid, hrp)) or Color3.new(1, 1, 1)
				else
					t.Visible = false
				end
			end
		end
	end
end

function Visuals:UpdatePlayerVisuals()
	for playerKey, array in pairs(player_array:GetArrays()) do
		if not player_array:GetStatus(playerKey) then
			if array.Drawings then
				applyToAny(array.Drawings, function(d) d.Visible = false end)
			end
			continue
		end

		local char = array.Player and array.Player.Character
		if not char then
			if array.Drawings then
				applyToAny(array.Drawings, function(d) d.Visible = false end)
			end
			continue
		end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not humanoid then
			if array.Drawings then
				applyToAny(array.Drawings, function(d) d.Visible = false end)
			end
			continue
		end

		array.Character = char
		local drawings = array.Drawings

		local boxSize, boxPos, onScreen, distance = self:SolveBox(char)
		local classdata = array.Character:FindFirstChild("IsAPlayer") and array.Character.IsAPlayer.Value or ""
		local filter = settings.visuals.filter
		local sameTeam = playerKey.Team == My_Player.Team
		local isMedic = classdata == "Doctor"
		local can_render = true
		if filter == "Only Enemies" and sameTeam then
			can_render = false
		elseif filter == "Only Team" and not sameTeam then
			can_render = false
		elseif filter == "Enemies + Team Medic" and sameTeam and not isMedic then
			can_render = false
		end

		local vis = onScreen and can_render and settings.visuals.master

		if drawings.box then
			drawings.box.Visible = vis and settings.visuals.box
			drawings.box.Position = boxPos
			drawings.box.Size = boxSize
		end
		if drawings.box_o then
			drawings.box_o.Visible = vis and settings.visuals.box
			drawings.box_o.Position = boxPos
			drawings.box_o.Size = boxSize
		end

		self:UpdateSkeleton(char, drawings, vis)
		self:RenderLayout(array, boxPos, boxSize, vis, humanoid, hrp)
	end
end

function Visuals:ClearLayout()
	for side, _ in pairs(self.Bars) do
		self.Bars[side] = {}
		self.Texts[side] = {}
	end
	self._layoutSetup = false
end

function Visuals:SetupLayoutDefaults()
	if self._layoutSetup then return end
	self._layoutSetup = true

	self:RegisterBar({
		id = "health",
		side = "Left",
		priority = 1,
		visibleFn = function() return settings.visuals.healthbar end,
		valueFn = function(_, humanoid)
			if not humanoid or humanoid.MaxHealth <= 0 then return 0 end
			return humanoid.Health / humanoid.MaxHealth
		end,
		colorFn = function(_, _, _, v)
			return Color3.new(1 - v, v, 0)
		end,
	})

	self:RegisterBar({
		id = "ammobar",
		side = "Bottom",
		priority = -2,
		visibleFn = function(array)
			if not array.Character then return false end
			local weaponname = tostring(array.Character:GetAttribute("EquippedWeapon"))
			local weapondata = searchWeapon(weaponname)
			if not weapondata or not array.Character:GetAttribute("AmmoInclip") then return false end
			return settings.visuals.ammobar
		end,
		valueFn = function(array, humanoid)
			if not array.Character then return 0 end
			local weaponname = tostring(array.Character:GetAttribute("EquippedWeapon"))
			local weapondata = searchWeapon(weaponname)
			if weapondata and array.Character:GetAttribute("AmmoInclip") and array.Character:GetAttribute("AmmoLeft") then
				local maxammo = weapondata.StoredAmmo.Value ~= 0 and weapondata.StoredAmmo.Value or weapondata.Ammo.Value
				local ammoinclip = array.Character:GetAttribute("AmmoInclip")
				local ammoleft = array.Character:GetAttribute("AmmoLeft")
				return ammoinclip + ammoleft, maxammo
			end
			return 100, 100
		end,
		colorFn = function(_, _, _, v)
			return Color3.fromRGB(100, 100, 255)
		end,
	})

	self:RegisterBar({
		id = "charge",
		side = "Top",
		priority = -2,
		visibleFn = function(array)
			return array.Character:FindFirstChild("IsAPlayer")
				and array.Character.IsAPlayer.Value == "Doctor"
				and settings.visuals.charge
		end,
		valueFn = function(array, humanoid)
			if not array.Character:GetAttribute("SuperC") then return 0 end
			return array.Character:GetAttribute("SuperC"), 100
		end,
		colorFn = function(_, _, _, v)
			return Color3.fromRGB(255, 0, 0)
		end,
	})

	self:RegisterText({
		id = "name",
		side = "Top",
		priority = 0,
		visibleFn = function() return settings.visuals.name end,
		textFn = function(array)
			return settings.visuals.UseDisplay and array.Player.DisplayName or array.Player.Name
		end,
		colorFn = function(array)
			if array.Player.Team == My_Player.Team then
				return Color3.new(0, 1, 0)
			end
			return Color3.new(1, 1, 1)
		end,
	})

	self:RegisterText({
		id = "weapon",
		side = "Bottom",
		priority = -1,
		visibleFn = function(array)
			if not array.Character then return false end
			local weaponname = tostring(array.Character:GetAttribute("EquippedWeapon"))
			local weapondata = searchWeapon(weaponname)
			if not weapondata then return false end
			return settings.visuals.weapon
		end,
		textFn = function(array)
			local weaponname = tostring(array.Character:GetAttribute("EquippedWeapon"))
			if array.Character and array.Character:GetAttribute("AmmoInclip") and array.Character:GetAttribute("AmmoLeft") then
				local ammoinclip = tostring(array.Character:GetAttribute("AmmoInclip"))
				local ammoleft = tostring(array.Character:GetAttribute("AmmoLeft"))
				return weaponname .. " " .. ammoinclip .. "/" .. ammoleft
			end
			return weaponname or ""
		end,
	})
end

function Visuals:Bind()
	self:SetupLayoutDefaults()

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			player_array:NewPlayerArray(char, player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			player_array:NewPlayerArray(player.Character, player)
		end
		player.CharacterAdded:Connect(function(char)
			player_array:NewPlayerArray(char, player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local arr = player_array.CurrentArrays[player]
		if arr then
			arr:RemoveDrawings()
			player_array.CurrentArrays[player] = nil
		end
	end)

	if self._loop then self._loop:Disconnect() end
	self._loop = RunService.RenderStepped:Connect(function()
		self:UpdatePlayerVisuals()
	end)
end

function Visuals:Unbind()
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
	for _, arr in pairs(player_array:GetArrays()) do
		if arr.RemoveDrawings then arr:RemoveDrawings() end
	end
	player_array.CurrentArrays = {}
end

return {
	Visuals = Visuals,
	Settings = settings,
	PlayerArray = player_array,
	Bind = function() return Visuals:Bind() end,
	Unbind = function() return Visuals:Unbind() end,
	ClearLayout = function() return Visuals:ClearLayout() end,
}
