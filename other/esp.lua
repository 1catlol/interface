--[[
  esp.juice
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

local function Create(className, parent, name, props)
	local obj = Instance.new(className, parent)
	if name then obj.Name = name end
	if props then for k, v in pairs(props) do obj[k] = v end end
	if obj:IsA("TextButton") or obj:IsA("ImageButton") then obj.AutoButtonColor = false end
	return obj
end

local function isSide(side)
	return side == "Left" or side == "Right" or side == "Top" or side == "Bottom"
end

function ESP.new(config)
	config = config or {}
	local self = setmetatable({
		_teamCheck = config.teamCheck or false,
		_visibleCheck = config.visibleCheck or false,
		_maxDistance = config.maxDistance or 2000,
		_isEnemy = config.isEnemy or function(player)
			return player ~= LocalPlayer
		end,
		_isTeam = config.isTeam or function(player)
			return player.Team == LocalPlayer.Team
		end,
		_getCharacter = config.getCharacter or function(player)
			return player.Character
		end,
		_getRoot = config.getRoot or function(char)
			return char:FindFirstChild("HumanoidRootPart")
		end,
		_getHead = config.getHead or function(char)
			return char:FindFirstChild("Head")
		end,
		_getHumanoid = config.getHumanoid or function(char)
			return char:FindFirstChildOfClass("Humanoid")
		end,
		Bars = { Left = {}, Right = {}, Top = {}, Bottom = {} },
		Texts = { Left = {}, Right = {}, Top = {}, Bottom = {} },
		_layout = {
			barThickness = 2,
			barGap = 3,
			textGap = 2,
			sidePadding = 4,
			textOffset = 12,
			barLengthPad = 0,
		},
		_boxes = {},
		_customEntities = {},
		_customBoxes = {},
		_loop = nil,
		_layoutSetup = false,
		_enabled = true,
		_boxEnabled = config.boxEnabled or false,
		_boxColor = config.boxColor or Color3.fromRGB(255, 255, 255),
	}, ESP)

	self._gui = Create("ScreenGui", gethui(), "EspLib", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	self._holder = Create("Folder", self._gui, "EspHolder")

	return self
end

function ESP:RegisterBar(cfg)
	assert(cfg and cfg.id and cfg.side, "RegisterBar needs id + side")
	assert(isSide(cfg.side), "Invalid bar side")
	cfg.priority = cfg.priority or 0
	table.insert(self.Bars[cfg.side], cfg)
	table.sort(self.Bars[cfg.side], function(a, b) return a.priority < b.priority end)
end

function ESP:RegisterText(cfg)
	assert(cfg and cfg.id and cfg.side, "RegisterText needs id + side")
	assert(isSide(cfg.side), "Invalid text side")
	cfg.priority = cfg.priority or 0
	table.insert(self.Texts[cfg.side], cfg)
	table.sort(self.Texts[cfg.side], function(a, b) return a.priority < b.priority end)
end

function ESP:SetBoxEnabled(enabled)
	self._boxEnabled = enabled
end

function ESP:SetBoxColor(color)
	self._boxColor = color
end

function ESP:SetEnabled(enabled)
	self._enabled = enabled
	if not enabled then
		for _, box in pairs(self._boxes) do
			box.cg.Visible = false
		end
		for _, box in pairs(self._customBoxes) do
			box.cg.Visible = false
		end
	end
end

function ESP:AddEntity(id, character, opts)
	opts = opts or {}
	self._customEntities[id] = {
		id = id,
		character = character,
		name = opts.name or tostring(id),
		getCharacter = opts.getCharacter or (character:IsA("Model") and function() return character end or function() return character end),
		getRoot = opts.getRoot or nil,
		getHead = opts.getHead or nil,
		getHumanoid = opts.getHumanoid or nil,
	}
	self._customBoxes[id] = self._customBoxes[id] or self:_createBox(self._customEntities[id])
end

function ESP:RemoveEntity(id)
	if self._customBoxes[id] then
		self._customBoxes[id].cg:Destroy()
		self._customBoxes[id] = nil
	end
	self._customEntities[id] = nil
end

local function worldToScreen(pos)
	local sp, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(sp.X, sp.Y), onScreen, sp.Z
end

function ESP:_solveBox(char)
	local cam = Camera
	if not char then
		return Vector2.zero, Vector2.zero, false, 0
	end

	local hrp = self._getRoot(char)
	local head = self._getHead(char)
	if not hrp and not head then
		return Vector2.zero, Vector2.zero, false, 0
	end

	local headPos = head and head.Position or (hrp.Position + Vector3.new(0, 2, 0))
	local footPos = hrp.Position - Vector3.new(0, 3, 0)

	local hp, hOn = worldToScreen(headPos + Vector3.new(0, 0.5, 0))
	local fp = worldToScreen(footPos)

	local height = math.abs(hp.Y - fp.Y)
	local width = height * 0.45
	local x = hp.X - width / 2
	local y = hp.Y

	local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
	local onScreen = hOn and height > 2

	return Vector2.new(width, height), Vector2.new(x, y), onScreen, dist
end

local function getSidePos(boxPos, boxSize, side, stackIdx, cfg, layout)
	local pad = layout.sidePadding
	local gap = layout.barGap
	local thick = cfg.thickness or layout.barThickness

	if side == "Top" then
		local totalGap = (stackIdx - 1) * gap
		local y = boxPos.Y - pad - thick - totalGap - layout.textOffset
		return Vector2.new(boxPos.X, y), Vector2.new(boxPos.X + boxSize.X, y)
	elseif side == "Bottom" then
		local totalGap = (stackIdx - 1) * gap
		local y = boxPos.Y + boxSize.Y + pad + totalGap
		return Vector2.new(boxPos.X, y), Vector2.new(boxPos.X + boxSize.X, y)
	elseif side == "Left" then
		local totalGap = (stackIdx - 1) * gap
		local x = boxPos.X - pad - thick - totalGap
		return Vector2.new(x, boxPos.Y + boxSize.Y), Vector2.new(x, boxPos.Y)
	elseif side == "Right" then
		local totalGap = (stackIdx - 1) * gap
		local x = boxPos.X + boxSize.X + pad + totalGap
		return Vector2.new(x, boxPos.Y + boxSize.Y), Vector2.new(x, boxPos.Y)
	end
end

local function getTextPos(boxPos, boxSize, side, stackIdx, layout)
	local pad = layout.sidePadding
	local gap = layout.textGap

	if side == "Top" then
		local totalGap = (stackIdx - 1) * gap
		local y = boxPos.Y - layout.textOffset - 14 - 14 * (stackIdx - 1) - totalGap
		return Vector2.new(boxPos.X + boxSize.X / 2, y)
	elseif side == "Bottom" then
		local totalGap = (stackIdx - 1) * gap
		local y = boxPos.Y + boxSize.Y + pad + 14 * (stackIdx - 1) + totalGap
		return Vector2.new(boxPos.X + boxSize.X / 2, y)
	elseif side == "Left" then
		local totalGap = (stackIdx - 1) * gap
		local x = boxPos.X - pad - 50
		return Vector2.new(x, boxPos.Y + 14 * (stackIdx - 1) + totalGap)
	elseif side == "Right" then
		local totalGap = (stackIdx - 1) * gap
		local x = boxPos.X + boxSize.X + pad
		return Vector2.new(x, boxPos.Y + 14 * (stackIdx - 1) + totalGap)
	end
end

function ESP:_createBox(target)
	local cgName = (typeof(target) == "table" and target.name) or (typeof(target) == "Instance" and target.Name) or "Unknown"
	local cg = Create("CanvasGroup", self._holder, cgName, {
		BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), BorderColor3 = Color3.fromRGB(0, 0, 0),
	})

	local boxOutline = Create("Frame", cg, "BoxOutline", {
		BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0, 0, 0, 0),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
	})
	local strokeOuter = Create("UIStroke", boxOutline, nil, {
		Thickness = 3, Color = Color3.fromRGB(0, 0, 0),
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
	local strokeInner = Create("UIStroke", boxOutline, nil, {
		Thickness = 2, Color = Color3.fromRGB(0, 0, 0),
		LineJoinMode = Enum.LineJoinMode.Miter,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
	})
	local strokeMain = Create("UIStroke", boxOutline, nil, {
		Thickness = 1, Color = self._boxColor,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})

	local barElements = {}
	for side, list in pairs(self.Bars) do
		barElements[side] = {}
		for _, cfg in ipairs(list) do
			local bg = Create("Frame", cg, nil, {
				BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0), Visible = false,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
			})
			local fill = Create("Frame", bg, nil, {
				BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(0, 255, 0),
				Size = UDim2.new(0, 0, 0, 0), Visible = false,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
			})
			barElements[side][cfg.id] = { bg = bg, fill = fill, cfg = cfg }
		end
	end

	local textElements = {}
	for side, list in pairs(self.Texts) do
		textElements[side] = {}
		for _, cfg in ipairs(list) do
			local lbl = Create("TextLabel", cg, nil, {
				BorderSizePixel = 0, TextSize = cfg.size or 13,
				BackgroundTransparency = 1,
				FontFace = cfg.font or Font.fromEnum(Enum.Font.SourceSans),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Size = UDim2.new(0, 0, 0, 14), Visible = false,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				Text = "", TextStrokeTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			textElements[side][cfg.id] = { label = lbl, cfg = cfg }
		end
	end

	return {
		cg = cg,
		boxOutline = boxOutline,
		strokeOuter = strokeOuter,
		strokeInner = strokeInner,
		strokeMain = strokeMain,
		bars = barElements,
		texts = textElements,
	}
end

function ESP:_removeBox(player)
	local box = self._boxes[player]
	if box then
		box.cg:Destroy()
		self._boxes[player] = nil
	end
end

function ESP:_update()
	if not self._enabled then
		for _, box in pairs(self._boxes) do box.cg.Visible = false end
		for _, box in pairs(self._customBoxes) do box.cg.Visible = false end
		return
	end

	local function processEntity(entity, box, isCustom)
		local char, getRootFn, getHeadFn, getHumanoidFn

		if isCustom then
			char = (entity.getCharacter and entity.getCharacter(entity)) or entity.character
			if not char then box.cg.Visible = false; return end
			getRootFn = entity.getRoot or self._getRoot
			getHeadFn = entity.getHead or self._getHead
			getHumanoidFn = entity.getHumanoid or self._getHumanoid
		else
			char = self._getCharacter(entity)
			if not char then box.cg.Visible = false; return end
			getRootFn = self._getRoot
			getHeadFn = self._getHead
			getHumanoidFn = self._getHumanoid
		end

		local hrp = getRootFn(char)
		local head = getHeadFn(char)
		local humanoid = getHumanoidFn(char)
		if not hrp then box.cg.Visible = false; return end

		local boxSize, boxPos, onScreen, dist = self:_solveBox(char)

		if self._maxDistance and dist > self._maxDistance then
			onScreen = false
		end

		if not isCustom then
			if self._teamCheck and self._isTeam(entity) then onScreen = false end
			if not self._isEnemy(entity) then onScreen = false end
		end

		if not onScreen then
			box.cg.Visible = false
			return
		end

		box.cg.Visible = true

		box.boxOutline.Size = UDim2.new(0, boxSize.X, 0, boxSize.Y)
		box.boxOutline.Position = UDim2.new(0, boxPos.X, 0, boxPos.Y)
		box.boxOutline.Visible = self._boxEnabled
		box.strokeMain.Color = self._boxColor

		local array = {
			Player = isCustom and entity or entity,
			Character = char,
		}

		for side, list in pairs(self.Bars) do
			local stack = 0
			for _, cfg in ipairs(list) do
				local bar = box.bars[side][cfg.id]
				if bar then
					local show = cfg.visibleFn and cfg.visibleFn(array, humanoid, hrp)
					if show then
						stack = stack + 1
						local from, to = getSidePos(boxPos, boxSize, side, stack, cfg, self._layout)
						local isVertical = side == "Left" or side == "Right"
						local v = 0

						if cfg.valueFn then
							local val = cfg.valueFn(array, humanoid, hrp)
							if type(val) == "table" and #val >= 2 then
								local numerator, denominator = val[1], val[2]
								v = denominator > 0 and math.clamp(numerator / denominator, 0, 1) or 0
							else
								v = math.clamp(tonumber(val) or 0, 0, 1)
							end
						end

						local thick = cfg.thickness or self._layout.barThickness

						if isVertical then
							bar.bg.Size = UDim2.new(0, thick + 2, 0, to.Y - from.Y)
							bar.bg.Position = UDim2.new(0, from.X - 1, 0, from.Y)
							bar.fill.Size = UDim2.new(0, thick, 0, (to.Y - from.Y) * v)
							bar.fill.Position = UDim2.new(0, 0, 1, 0)
						else
							bar.bg.Size = UDim2.new(0, to.X - from.X, 0, thick + 2)
							bar.bg.Position = UDim2.new(0, from.X, 0, from.Y - 1)
							bar.fill.Size = UDim2.new((to.X - from.X) * v, 0, 0, thick)
							bar.fill.Position = UDim2.new(0, 0, 0, 0)
						end

						bar.fill.BackgroundColor3 = (cfg.colorFn and cfg.colorFn(array, humanoid, hrp, v)) or Color3.fromRGB(0, 255, 0)
						bar.bg.Visible = true
						bar.fill.Visible = true
					else
						bar.bg.Visible = false
						bar.fill.Visible = false
					end
				end
			end
		end

		for side, list in pairs(self.Texts) do
			local stack = 0
			for _, cfg in ipairs(list) do
				local t = box.texts[side][cfg.id]
				if t then
					local show = cfg.visibleFn and cfg.visibleFn(array, humanoid, hrp)
					if show then
						stack = stack + 1
						local pos = getTextPos(boxPos, boxSize, side, stack, self._layout)
						t.label.Position = UDim2.new(0, pos.X, 0, pos.Y)
						t.label.Text = (cfg.textFn and cfg.textFn(array, humanoid, hrp, t.label)) or ""
						t.label.TextColor3 = (cfg.colorFn and cfg.colorFn(array, humanoid, hrp)) or Color3.fromRGB(255, 255, 255)
						t.label.Visible = true
					else
						t.label.Visible = false
					end
				end
			end
		end
	end

	for player, box in pairs(self._boxes) do
		if not player.Parent then
			self:_removeBox(player)
			continue
		end
		processEntity(player, box, false)
	end

	for id, entity in pairs(self._customEntities) do
		local box = self._customBoxes[id]
		if not box then continue end
		if not entity.character or not entity.character.Parent then
			self:RemoveEntity(id)
			continue
		end
		processEntity(entity, box, true)
	end
end

function ESP:SetupLayoutDefaults()
	if self._layoutSetup then return end
	self._layoutSetup = true

	self:RegisterBar({
		id = "health",
		side = "Left",
		priority = 1,
		visibleFn = function() return true end,
		valueFn = function(_, humanoid)
			if not humanoid or humanoid.MaxHealth <= 0 then return 0 end
			return humanoid.Health / humanoid.MaxHealth
		end,
		colorFn = function(_, _, _, v)
			return Color3.new(1 - v, v, 0)
		end,
	})

	self:RegisterText({
		id = "name",
		side = "Top",
		priority = 0,
		visibleFn = function() return true end,
		textFn = function(array)
			return array.Player.Name
		end,
		colorFn = function()
			return Color3.new(1, 1, 1)
		end,
	})

	self:RegisterText({
		id = "distance",
		side = "Bottom",
		priority = 0,
		visibleFn = function() return true end,
		textFn = function(array)
			if array.Character and array.Character:FindFirstChild("HumanoidRootPart") then
				local lp = LocalPlayer
				if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
					return math.floor((lp.Character.HumanoidRootPart.Position - array.Character.HumanoidRootPart.Position).Magnitude + 0.5) .. "m"
				end
			end
			return ""
		end,
		colorFn = function()
			return Color3.fromRGB(200, 200, 200)
		end,
	})
end

function ESP:Bind()
	self:SetupLayoutDefaults()

	local function onCharAdded(char, player)
		self._boxes[player] = self._boxes[player] or self:_createBox(player)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if self._isEnemy(player) and player.Character then
			onCharAdded(player.Character, player)
		end
	end

	local function onPlayerAdded(player)
		if not self._isEnemy(player) then return end
		player.CharacterAdded:Connect(function(char)
			onCharAdded(char, player)
		end)
		if player.Character then
			onCharAdded(player.Character, player)
		end
	end

	self._addedConn = Players.PlayerAdded:Connect(onPlayerAdded)
	self._removingConn = Players.PlayerRemoving:Connect(function(player)
		self:_removeBox(player)
	end)

	if self._loop then self._loop:Disconnect() end
	self._loop = RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function ESP:Unbind()
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
	if self._addedConn then
		self._addedConn:Disconnect()
		self._addedConn = nil
	end
	if self._removingConn then
		self._removingConn:Disconnect()
		self._removingConn = nil
	end
	for _, box in pairs(self._boxes) do
		box.cg:Destroy()
	end
	self._boxes = {}
	for _, box in pairs(self._customBoxes) do
		box.cg:Destroy()
	end
	self._customBoxes = {}
	self._customEntities = {}
end

return ESP
