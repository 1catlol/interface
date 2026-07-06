local Services = {
	Players = game:GetService("Players"),
	User_Input = game:GetService("UserInputService"),
	Run_Service = game:GetService("RunService"),
	Tween_Service = game:GetService("TweenService"),
	CoreGui = game:GetService("CoreGui"),
}

local HttpService = game:GetService("HttpService")
local Local_Player = Services.Players.LocalPlayer
local PlayerGui = Local_Player and Local_Player:WaitForChild("PlayerGui")

local FONT = nil

local CustomFont = { } do
	function CustomFont:New(Name, Weight, Style, FontData)
		if not isfile(FontData.Id) then 
			writefile(FontData.Id, game:HttpGet(FontData.Url))
		end

		local fontConfig = {
			name = Name,
			faces = {
				{
					name = Name,
					weight = Weight,
					style = Style,
					assetId = getcustomasset(FontData.Id)
				}
			}
		}

		writefile(`{Name}.font`, HttpService:JSONEncode(fontConfig))
		return Font.new(getcustomasset(`{Name}.font`))
	end

	FONT = CustomFont:New("ProggyClean", 400, "Regular", {
		Id = "ProggyClean",
		Url = "https://github.com/chrissimpkins/codeface/raw/refs/heads/master/fonts/proggy-clean/ProggyClean.ttf"
	})
end

local COLOR_BG = Color3.fromRGB(28, 28, 28)
local COLOR_INNER = Color3.fromRGB(13, 13, 13)
local COLOR_SECTION = Color3.fromRGB(27, 27, 27)
local COLOR_SECTION_INNER = Color3.fromRGB(18, 18, 18)
local COLOR_DARK = Color3.fromRGB(8, 8, 8)
local COLOR_ELEMENT = Color3.fromRGB(10, 10, 10)
local COLOR_ACCENT = Color3.fromRGB(4, 134, 255)
local COLOR_TEXT = Color3.fromRGB(137, 137, 137)
local COLOR_BLACK = Color3.fromRGB(0, 0, 0)
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local COLOR_SCROLLBAR = Color3.fromRGB(26, 26, 26)

local GRADIENT_COLOR = ColorSequence.new{
	ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.509, Color3.fromRGB(237, 237, 237)),
	ColorSequenceKeypoint.new(1.000, Color3.fromRGB(142, 142, 142))
}

local GRADIENT_FRAME = ColorSequence.new{
	ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.785, Color3.fromRGB(237, 237, 237)),
	ColorSequenceKeypoint.new(0.938, Color3.fromRGB(142, 142, 142)),
	ColorSequenceKeypoint.new(1.000, Color3.fromRGB(142, 142, 142))
}

local GRADIENT_ELEMENT = ColorSequence.new{
	ColorSequenceKeypoint.new(0.000, Color3.fromRGB(163, 163, 163)),
	ColorSequenceKeypoint.new(0.509, Color3.fromRGB(198, 198, 198)),
	ColorSequenceKeypoint.new(1.000, Color3.fromRGB(208, 208, 208))
}

local function applyStroke(inst)
	local stroke = Instance.new("UIStroke")
	stroke.Parent = inst
	return stroke
end

local function applyGradient(inst, colorSeq, rotation)
	local grad = Instance.new("UIGradient")
	grad.Color = colorSeq or GRADIENT_COLOR
	grad.Rotation = rotation or 90
	grad.Parent = inst
	return grad
end

local function rgbToHsv(color)
	local r, g, b = color.R, color.G, color.B
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local delta = max - min
	local h = 0
	if delta > 0 then
		if max == r then h = ((g - b) / delta) % 6
		elseif max == g then h = (b - r) / delta + 2
		else h = (r - g) / delta + 4 end
		h = h / 6
		if h < 0 then h = h + 1 end
	end
	local s = max > 0 and (delta / max) or 0
	local v = max
	return h, s, v
end

local KEY_DISPLAY = {
	MouseButton1 = "MB1",
	MouseButton2 = "MB2",
	MouseButton3 = "MB3",
}
local function keyDisplayName(keyName)
	return KEY_DISPLAY[keyName] or keyName
end

local function makeDrag(inst, target, lockState)
	local dragStart, startPos, dragging

	inst.InputBegan:Connect(function(input)
		if lockState and lockState.locked then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart = input.Position
			startPos = target.Position
			dragging = true
		end
	end)

	inst.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	Services.User_Input.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

local function Create(className, properties)
	local inst = Instance.new(className)
	for prop, value in pairs(properties) do
		inst[prop] = value
	end
	return inst
end

local Library = {}
Library.flags = {}
Library.__index = Library

local TWEEN_INFO_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_SMOOTH = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_BOUNCE = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_SPRING = TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

local function tween(inst, props, info)
	local ti = info or TWEEN_INFO_FAST
	return Services.Tween_Service:Create(inst, ti, props)
end

function Library.new(title)
	local self = setmetatable({}, Library)
	self.title = title or "cheat.ai"
	self.tabs = {}
	self.activeTab = nil
	self._popupHovered = {}
	self._onUnloadCallback = nil
	self._openContextPopups = {}
	self._syncList = {}
	self._configFolder = "retake_config"

	local screenGui = Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = gethui() or game.CoreGui,
	})
	self.screenGui = screenGui

	local main = Create("CanvasGroup", {
		BackgroundColor3 = COLOR_WHITE,
		Size = UDim2.new(0, 498, 0, 418),
		Position = UDim2.new(0.5, -249, 0.4, -209),
		BorderColor3 = COLOR_BLACK,
		Name = "Main",
		GroupTransparency = 0,
		Parent = screenGui,
	})
	self.main = main

	tween(main, {GroupTransparency = 0}, TWEEN_INFO_BOUNCE):Play()

	local mainframe = Create("Frame", {
		BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(0, 499, 0, 420),
		BorderColor3 = COLOR_BLACK,
		Name = "mainframe",
		Parent = main,
	})
	self.mainframe = mainframe
	applyGradient(mainframe, GRADIENT_FRAME, -90)

	local topbar = Create("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(0, 499, 0, 20),
		BorderColor3 = COLOR_BLACK,
		Name = "topbar",
		Parent = mainframe,
	})
	self.topbar = topbar
	applyGradient(topbar)
	self._dragLock = {locked = false}
	makeDrag(topbar, main, self._dragLock)

	local titleLabel = Create("TextLabel", {
		TextStrokeTransparency = 0,
		BorderSizePixel = 0,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = COLOR_WHITE,
		FontFace = FONT,
		TextColor3 = COLOR_TEXT,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 80, 0, 20),
		BorderColor3 = COLOR_BLACK,
		Text = self.title,
		Position = UDim2.new(0, 6, 0, -1),
		Parent = topbar,
	})
	applyStroke(titleLabel)

	local tabFrame = Create("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = COLOR_WHITE,
		Size = UDim2.new(1, -(titleLabel.TextBounds.X + 40), 0, 25),
		Position = UDim2.new(0, titleLabel.TextBounds.X + 40, 0, 0),
		BorderColor3 = COLOR_BLACK,
		BackgroundTransparency = 1,
		Parent = topbar,
	})
	self.tabFrame = tabFrame

	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		Parent = tabFrame,
	})

	local inner = Create("Frame", {
		BackgroundColor3 = COLOR_INNER,
		Size = UDim2.new(0, 485, 0, 393),
		Position = UDim2.new(0.0136, 0, 0.04505, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "inner",
		Parent = mainframe,
	})
	self.inner = inner

	local tabHolder = Create("Folder", {
		Name = "tabholder",
		Parent = inner,
	})
	self.tabHolder = tabHolder

	local warningFrame = Create("CanvasGroup", {
		Visible = false,
		ZIndex = 500,
		BorderSizePixel = 0,
		BackgroundColor3 = COLOR_BLACK,
		Size = UDim2.new(0, 498, 0, 419),
		Position = UDim2.new(0, 0, 0, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "WARNINGFRAME",
		BackgroundTransparency = 0.3,
		Parent = mainframe,
	})
	self.warningFrame = warningFrame

	local warningBox = Create("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(0, 273, 0, 100),
		Position = UDim2.new(0.22691, 0, 0.36516, 0),
		BorderColor3 = COLOR_BLACK,
		Parent = warningFrame,
	})
	self.warningBox = warningBox

	local warningText = Create("TextLabel", {
		TextWrapped = true,
		TextStrokeTransparency = 0,
		BorderSizePixel = 0,
		TextSize = 12,
		BackgroundColor3 = COLOR_WHITE,
		FontFace = FONT,
		TextColor3 = COLOR_TEXT,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 258, 0, 75),
		BorderColor3 = COLOR_BLACK,
		Text = "",
		Position = UDim2.new(0.03166, 0, 0.00316, 0),
		Parent = warningBox,
	})
	self.warningText = warningText
	applyStroke(warningText)

	local warningOkay = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = COLOR_ACCENT,
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 126, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = "Okay", Name = "ImageButton", Position = UDim2.new(0, 7, 0, 76),
		Parent = warningBox,
	})
	applyGradient(warningOkay, GRADIENT_ELEMENT)
	applyStroke(warningOkay)
	self.warningOkay = warningOkay

	local warningNo = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = Color3.fromRGB(155, 155, 155),
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 128, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = "No", Name = "ImageButton", Position = UDim2.new(0, 139, 0, 76),
		Parent = warningBox,
	})
	applyGradient(warningNo, GRADIENT_ELEMENT)
	applyStroke(warningNo)
	self.warningNo = warningNo

	self.warningCallback = nil
	warningOkay.MouseButton1Click:Connect(function()
		self.warningFrame.Visible = false
		if self.warningCallback then
			self.warningCallback(true)
		end
	end)
	warningNo.MouseButton1Click:Connect(function()
		self.warningFrame.Visible = false
		if self.warningCallback then
			self.warningCallback(false)
		end
	end)

	local notifyHolder = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 220, 1, -20),
		Position = UDim2.new(0.008, 0, 0.03, 0),
		ZIndex = 999,
		Parent = screenGui,
	})
	self.notifyHolder = notifyHolder

	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = notifyHolder,
	})

	self._notifyActive = false

	local keybindPanel = Create("CanvasGroup", {
		BackgroundColor3 = COLOR_BG,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 104, 0, 25),
		Position = UDim2.new(0.0106, 0, 0.38891, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "bindlist",
		Visible = false,
		ZIndex = 998,
		Parent = screenGui,
	})
	self.keybindPanel = keybindPanel

	local kbPanelBar = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(1, 0, 0, 20), BorderColor3 = COLOR_BLACK,
		Name = "namebar", Parent = keybindPanel,
	})
	applyGradient(kbPanelBar)

	Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = COLOR_TEXT, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), BorderColor3 = COLOR_BLACK,
		Text = "Binds", Parent = kbPanelBar,
	})
	local bindsLabel = kbPanelBar:FindFirstChildOfClass("TextLabel")
	if bindsLabel then applyStroke(bindsLabel) end

	local holder = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_WHITE,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 104, 0, 4),
		Position = UDim2.new(0, 0, 0, 20),
		BorderColor3 = COLOR_BLACK,
		Name = "holder",
		BackgroundTransparency = 1,
		Parent = keybindPanel,
	})

	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})

	self._keybindLabels = {}
	self._keybindFrames = {}
	self._keybindNames = {}
	self._keybindMode = "all"
	self._keybindUpdateConn = Services.Run_Service.RenderStepped:Connect(function()
		if not self.keybindPanel.Visible then return end
		for flag, frame in pairs(self._keybindFrames) do
			local data = Library.flags[flag]
			local label = self._keybindLabels[flag]
			local name = self._keybindNames[flag] or "keybind"
			if data and label then
				local keyText = data.key and ("[" .. keyDisplayName(data.key) .. "]") or "[N/A]"
				label.Text = keyText .. " " .. name
				local targetColor = data.active and COLOR_ACCENT or COLOR_TEXT
				if label.TextColor3 ~= targetColor then
					tween(label, {TextColor3 = targetColor}, TWEEN_INFO_FAST):Play()
				end
				if self._keybindMode == "active" then
					frame.Visible = data.active
				else
					frame.Visible = true
				end
			end
		end
	end)

	self:_createColorPickerPopup(screenGui)
	self:_createKeyMenuPopup(screenGui)

	self._isMobile = Services.User_Input.TouchEnabled

	if self._isMobile then
		local mobileToggle = Create("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = COLOR_ACCENT,
			BorderSizePixel = 0,
			Text = "UI",
			TextSize = 11,
			TextColor3 = COLOR_WHITE,
			FontFace = FONT,
			Size = UDim2.new(0, 38, 0, 24),
			Position = UDim2.new(1, -46, 1, -32),
			ZIndex = 999,
			Parent = screenGui,
		})
		applyStroke(mobileToggle)

		local mobileLock = Create("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = COLOR_ELEMENT,
			BorderSizePixel = 0,
			Text = "LK",
			TextSize = 11,
			TextColor3 = COLOR_TEXT,
			FontFace = FONT,
			Size = UDim2.new(0, 38, 0, 24),
			Position = UDim2.new(1, -46, 1, -62),
			ZIndex = 999,
			Parent = screenGui,
		})
		applyStroke(mobileLock)

		mobileToggle.Activated:Connect(function()
			self:Toggle()
		end)

		mobileLock.Activated:Connect(function()
			self._dragLock.locked = not self._dragLock.locked
			mobileLock.BackgroundColor3 = self._dragLock.locked and COLOR_ACCENT or COLOR_ELEMENT
		end)

		self._mobileToggle = mobileToggle
		self._mobileLock = mobileLock
	end

	self._menuKeybind = Enum.KeyCode.Insert
	self._menuKeyConn = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self._menuKeybind then
			self:Toggle()
		end
	end)

	self._rightClickConn = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.main.Visible then
				local mousePos = Services.User_Input:GetMouseLocation()
				local absPos = self.main.AbsolutePosition
				local absSize = self.main.AbsoluteSize
				if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
					return
				end
			end

		end
	end)

	self._outsideClickConn = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if self.colorPickerPopup and self.colorPickerPopup.Visible and not self._popupHovered[self.colorPickerPopup] then
				tween(self.colorPickerPopup, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
				task.delay(0.15, function() self.colorPickerPopup.Visible = false end)
			end

			if self.keyMenuPopup and self.keyMenuPopup.Visible and not self._popupHovered[self.keyMenuPopup] then
				tween(self.keyMenuPopup, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
				task.delay(0.15, function() self.keyMenuPopup.Visible = false end)
			end

			for _, ctxData in ipairs(self._openContextPopups or {}) do
				if ctxData.open.value and ctxData.popup.Visible and not self._popupHovered[ctxData.popup] then
					ctxData.open.value = false
					tween(ctxData.popup, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
					task.delay(0.15, function() ctxData.popup.Visible = false end)
				end
			end
		end
	end)
	
	return self
end

function Library:_createColorPickerPopup(parent)
	local cp = Create("CanvasGroup", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		Size = UDim2.new(0, 159, 0, 177),
		Position = UDim2.new(0.57749, 0, 0.07584, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "Colorpicker",
		Visible = false,
		GroupTransparency = 1,
		Parent = parent,
	})
	self.colorPickerPopup = cp
	cp.MouseEnter:Connect(function() self._popupHovered[cp] = true end)
	cp.MouseLeave:Connect(function() self._popupHovered[cp] = false end)

	local namebar = Create("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(35, 35, 35),
		Size = UDim2.new(0, 159, 0, 20),
		BorderColor3 = COLOR_BLACK,
		Name = "namebar",
		Parent = cp,
	})
	applyGradient(namebar)

	local nameLabel = Create("TextLabel", {
		TextStrokeTransparency = 0,
		BorderSizePixel = 0,
		TextSize = 12,
		BackgroundColor3 = COLOR_WHITE,
		FontFace = FONT,
		TextColor3 = COLOR_TEXT,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 124, 0, 20),
		BorderColor3 = COLOR_BLACK,
		Text = "Color menu",
		Position = UDim2.new(0.10858, 0, 0, 0),
		Parent = namebar,
	})
	applyStroke(nameLabel)

	self._colorHue = 0.6
	self._colorSat = 1
	self._colorVal = 1

	local pickerFrame = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, 124, 0, 124),
		Position = UDim2.new(0.04023, 0, 0.13872, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "picker",
		Parent = cp,
	})

	local svGradient = Instance.new("UIGradient")
	svGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(self._colorHue, 1, 1))
	}
	svGradient.Rotation = 0
	svGradient.Parent = pickerFrame

	local svOverlay = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 1, 0),
		BorderSizePixel = 0,
		Parent = pickerFrame,
	})

	local svOverlayGrad = Instance.new("UIGradient")
	svOverlayGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, COLOR_BLACK)
	}
	svOverlayGrad.Rotation = 90
	svOverlayGrad.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	}
	svOverlayGrad.Parent = svOverlay

	local svBtn = Create("ImageButton", {
		AutoButtonColor = false, ImageTransparency = 1, BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 5,
		Parent = pickerFrame,
	})

	local svCursor = Create("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = COLOR_WHITE,
		Size = UDim2.new(0, 6, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(self._colorSat, 0, 1 - self._colorVal, 0),
		ZIndex = 6,
		Parent = pickerFrame,
	})
	applyStroke(svCursor)

	local hueFrame = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, 16, 0, 124),
		Position = UDim2.new(0.854, 0, 0.13872, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "hue",
		Parent = cp,
	})

	local hueGradient = Instance.new("UIGradient")
	hueGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
		ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
	}
	hueGradient.Rotation = 270
	hueGradient.Parent = hueFrame

	local hueBtn = Create("ImageButton", {
		AutoButtonColor = false, ImageTransparency = 1, BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 5,
		Parent = hueFrame,
	})

	local hueCursor = Create("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = COLOR_WHITE,
		Size = UDim2.new(0, 18, 0, 3),
		Position = UDim2.new(0, 0, 1 - self._colorHue, 0),
		ZIndex = 6,
		Parent = hueFrame,
	})
	applyStroke(hueCursor)

	local function updateColor()
		local c = Color3.fromHSV(self._colorHue, self._colorSat, self._colorVal)
		self.colorPickerRGB = c
		svGradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(self._colorHue, 1, 1))
		}
		svCursor.Position = UDim2.new(self._colorSat, 0, 1 - self._colorVal, 0)
		hueCursor.Position = UDim2.new(0, 0, 1 - self._colorHue, 0)
	end

	local svDragging = false
	self._updateColorPicker = updateColor
	svBtn.MouseButton1Down:Connect(function()
		svDragging = true
	end)
	Services.User_Input.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			svDragging = false
		end
	end)
	svBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			svDragging = true
		end
	end)
	Services.User_Input.InputChanged:Connect(function(input)
		if not svDragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local pos = input.Position
			local absPos = pickerFrame.AbsolutePosition
			local absSize = pickerFrame.AbsoluteSize
			self._colorSat = math.clamp((pos.X - absPos.X) / absSize.X, 0, 1)
			self._colorVal = math.clamp(1 - (pos.Y - absPos.Y) / absSize.Y, 0, 1)
			updateColor()
		end
	end)

	local hueDragging = false
	hueBtn.MouseButton1Down:Connect(function()
		hueDragging = true
	end)
	Services.User_Input.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			hueDragging = false
		end
	end)
	hueBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			hueDragging = true
		end
	end)
	Services.User_Input.InputChanged:Connect(function(input)
		if not hueDragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local pos = input.Position
			local absPos = hueFrame.AbsolutePosition
			local absSize = hueFrame.AbsoluteSize
			self._colorHue = math.clamp(1 - (pos.Y - absPos.Y) / absSize.Y, 0, 1)
			updateColor()
		end
	end)

	local applyBtn = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12,
		TextColor3 = Color3.fromRGB(155, 155, 155),
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 70, 0, 13), BorderColor3 = COLOR_BLACK,
		Text = "Apply", Name = "applycolor",
		Position = UDim2.new(0, 7, 0, 157), Parent = cp,
	})
	applyGradient(applyBtn, GRADIENT_ELEMENT)
	applyStroke(applyBtn)

	local cancelBtn = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12,
		TextColor3 = Color3.fromRGB(155, 155, 155),
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 70, 0, 13), BorderColor3 = COLOR_BLACK,
		Text = "Cancel", Name = "cancelcolor",
		Position = UDim2.new(0, 82, 0, 157), Parent = cp,
	})
	applyGradient(cancelBtn, GRADIENT_ELEMENT)
	applyStroke(cancelBtn)

	self.colorPickerTarget = nil
	self.colorPickerRGB = Color3.fromRGB(59, 180, 255)

	updateColor()

	applyBtn.MouseButton1Click:Connect(function()
		if self.colorPickerTarget then
			local c = self.colorPickerRGB
			tween(self.colorPickerTarget, {BackgroundColor3 = c}, TWEEN_INFO_FAST):Play()
			if self.colorPickerCallback then
				self.colorPickerCallback(c)
			end
			if self.colorPickerFlag then
				Library.flags[self.colorPickerFlag] = c
			end
		end
		tween(cp, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			cp.Visible = false
		end)
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		tween(cp, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			cp.Visible = false
		end)
	end)
end

function Library:_createKeyMenuPopup(parent)
	local km = Create("CanvasGroup", {
		BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(0, 70, 0, 58),
		Position = UDim2.new(0.71126, 0, 0.22893, 0),
		BorderColor3 = COLOR_BLACK,
		Name = "keymenu",
		Visible = false,
		GroupTransparency = 1,
		Parent = parent,
	})
	self.keyMenuPopup = km
	km.MouseEnter:Connect(function() self._popupHovered[km] = true end)
	km.MouseLeave:Connect(function() self._popupHovered[km] = false end)

	local holdBtn = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = Color3.fromRGB(155, 155, 155),
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 64, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = "Hold", Position = UDim2.new(0.04, 0, 0.04, 0), Parent = km,
	})
	applyGradient(holdBtn, GRADIENT_ELEMENT)
	applyStroke(holdBtn)

	local toggleBtn = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = COLOR_ACCENT,
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 64, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = "Toggle", Position = UDim2.new(0.04, 0, 0.34, 0), Parent = km,
	})
	applyGradient(toggleBtn, GRADIENT_ELEMENT)
	applyStroke(toggleBtn)

	local alwaysBtn = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = Color3.fromRGB(155, 155, 155),
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 64, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = "Always", Position = UDim2.new(0.04, 0, 0.64, 0), Parent = km,
	})
	applyGradient(alwaysBtn, GRADIENT_ELEMENT)
	applyStroke(alwaysBtn)

	self._keyDetectConn = nil

	local function startListening()
		if self._keyDetectTarget then
			self._keyDetectTarget.Text = "[...]"
		end
		if self._keyDetectConn then
			self._keyDetectConn:Disconnect()
		end
		self._keyDetectConn = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
			local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3
			if gameProcessed and not isMouse then return end
			local keyName = nil
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Backspace then
					if self._keyDetectTarget then
						self._keyDetectTarget.Text = "[N/A]"
					end
					Library.flags[self._keyDetectFlag] = {key = nil, mode = self._keyDetectMode, active = false}
					if self._keyDetectCallback then
						self._keyDetectCallback(nil, self._keyDetectMode)
					end
				else
					keyName = input.KeyCode.Name
				end
			elseif isMouse then
				keyName = input.UserInputType.Name
			end
			if keyName then
				if self._keyDetectTarget then
					self._keyDetectTarget.Text = "[" .. keyDisplayName(keyName) .. "]"
				end
				Library.flags[self._keyDetectFlag] = {key = keyName, mode = self._keyDetectMode, active = false}
				if self._keyDetectCallback then
					self._keyDetectCallback(keyName, self._keyDetectMode)
				end
			end
			if self._keyDetectConn then
				self._keyDetectConn:Disconnect()
				self._keyDetectConn = nil
			end
		end)
	end

	holdBtn.MouseButton1Click:Connect(function()
		self._keyDetectMode = "Hold"
		tween(holdBtn, {TextColor3 = COLOR_ACCENT}, TWEEN_INFO_FAST):Play()
		tween(toggleBtn, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
		tween(alwaysBtn, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
		startListening()
		tween(km, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			km.Visible = false
		end)
	end)
	toggleBtn.MouseButton1Click:Connect(function()
		self._keyDetectMode = "Toggle"
		tween(holdBtn, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
		tween(toggleBtn, {TextColor3 = COLOR_ACCENT}, TWEEN_INFO_FAST):Play()
		tween(alwaysBtn, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
		startListening()
		tween(km, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			km.Visible = false
		end)
	end)
	alwaysBtn.MouseButton1Click:Connect(function()
		self._keyDetectMode = "Always"
		tween(holdBtn, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
		tween(toggleBtn, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
		tween(alwaysBtn, {TextColor3 = COLOR_ACCENT}, TWEEN_INFO_FAST):Play()
		startListening()
		tween(km, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			km.Visible = false
		end)
	end)
end

function Library:CreateTab(name)
	local tabBtn = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = COLOR_ACCENT,
		BackgroundColor3 = COLOR_ELEMENT, FontFace = FONT,
		Size = UDim2.new(0, 71, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = name, Parent = self.tabFrame,
	})
	applyGradient(tabBtn, GRADIENT_COLOR)
	applyStroke(tabBtn)

	local tabIndicator = Create("Frame", {
		ZIndex = 2, BorderSizePixel = 0,
		BackgroundColor3 = COLOR_WHITE,
		Size = UDim2.new(0, 71, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BorderColor3 = COLOR_BLACK, Parent = tabBtn,
	})

	local tabCanvas = Create("CanvasGroup", {
		BackgroundColor3 = COLOR_INNER,
		Size = UDim2.new(0, 486, 0, 393),
		Position = UDim2.new(0, 0, -0, 0),
		BorderColor3 = COLOR_BLACK, Name = name,
		GroupTransparency = (#self.tabs == 0) and 0 or 1,
		Parent = self.tabHolder,
		Visible = (#self.tabs == 0),
	})
	applyStroke(tabCanvas)

	local leftSection = Create("ScrollingFrame", {
		Active = true, CanvasSize = UDim2.new(0, 0, 0, 0),
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		Name = "left_section", BackgroundColor3 = COLOR_DARK,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 233, 0, 379),
		ScrollBarImageColor3 = COLOR_SCROLLBAR,
		Position = UDim2.new(0.01443, 0, 0.01828, 0),
		BorderColor3 = COLOR_BLACK, ScrollBarThickness = 3,
		Parent = tabCanvas,
	})

	local leftElements = Instance.new("Folder")
	leftElements.Name = "Elements"
	leftElements.Parent = leftSection

	Create("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = leftElements,
	})

	local rightSection = Create("ScrollingFrame", {
		Active = true, CanvasSize = UDim2.new(0, 0, 0, 0),
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		Name = "right_section", BackgroundColor3 = COLOR_DARK,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 233, 0, 379),
		ScrollBarImageColor3 = COLOR_SCROLLBAR,
		Position = UDim2.new(0.50722, 0, 0.01828, 0),
		BorderColor3 = COLOR_BLACK, ScrollBarThickness = 3,
		Parent = tabCanvas,
	})

	Create("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rightSection,
	})

	local tabData = {
		button = tabBtn,
		indicator = tabIndicator,
		canvas = tabCanvas,
		leftSection = leftSection,
		leftElements = leftElements,
		rightSection = rightSection,
		rightElements = rightSection,
		name = name,
	}

	tabBtn.MouseButton1Click:Connect(function()
		self:_switchTab(tabData)
	end)

	table.insert(self.tabs, tabData)
	if #self.tabs == 1 then
		self.activeTab = tabData
		tabBtn.TextColor3 = COLOR_ACCENT
		tabBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		tabIndicator.BackgroundColor3 = COLOR_WHITE
	end

	return tabData
end

function Library:_switchTab(tabData)
	for _, tab in ipairs(self.tabs) do
		if tab == tabData then
			tab.canvas.Visible = true
			tab.canvas.GroupTransparency = 1
			tween(tab.canvas, {GroupTransparency = 0}, TWEEN_INFO_SMOOTH):Play()
			tween(tab.button, {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}, TWEEN_INFO_FAST):Play()
			tween(tab.button, {TextColor3 = COLOR_ACCENT}, TWEEN_INFO_FAST):Play()
			tab.indicator.BackgroundColor3 = COLOR_WHITE
		else
			tween(tab.canvas, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
			task.delay(0.12, function()
				if self.activeTab ~= tab then
					tab.canvas.Visible = false
				end
			end)
			tween(tab.button, {BackgroundColor3 = Color3.fromRGB(12, 12, 12)}, TWEEN_INFO_FAST):Play()
			tween(tab.button, {TextColor3 = Color3.fromRGB(155, 155, 155)}, TWEEN_INFO_FAST):Play()
			tab.indicator.BackgroundColor3 = COLOR_BLACK
		end
	end
	self.activeTab = tabData
end

function Library:CreateSection(tab, name, side)
	side = side or "left"
	local parentElements = side == "left" and tab.leftElements or tab.rightElements

	local section = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_SECTION,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, -0.07866, 50),
		BorderColor3 = Color3.fromRGB(35, 35, 35),
		Name = "section", Parent = parentElements,
	})
	applyGradient(section)

	Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_BLACK,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, -1),
		BorderColor3 = COLOR_BLACK, Name = "topline", Parent = section,
	})

	local sectionTopbar = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_SECTION,
		Size = UDim2.new(0, 233, 0, 20), BorderColor3 = COLOR_BLACK,
		Name = "topbar", Parent = section,
	})
	applyGradient(sectionTopbar)

	Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = COLOR_TEXT, BackgroundTransparency = 1,
		Size = UDim2.new(0, 193, 0, 20), BorderColor3 = COLOR_BLACK,
		Text = name, Position = UDim2.new(0.03004, 0, 0, 0),
		Parent = sectionTopbar,
	})
	local sectionHeaderLabel = sectionTopbar:FindFirstChildOfClass("TextLabel")
	if sectionHeaderLabel then applyStroke(sectionHeaderLabel) end

	Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_BLACK,
		Size = UDim2.new(0, 233, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BorderColor3 = COLOR_BLACK, Parent = sectionTopbar,
	})

	local sectionInner = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_SECTION_INNER,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 20),
		BorderColor3 = COLOR_BLACK, Name = "inner", Parent = section,
	})

	local elementsFolder = Create("Folder", {Parent = sectionInner})

	Create("UIListLayout", {
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = elementsFolder,
	})

	Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_BLACK,
		Size = UDim2.new(0, 233, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BorderColor3 = COLOR_BLACK, Name = "bottomline", Parent = sectionInner,
	})

	local sectionData = {
		frame = section,
		inner = sectionInner,
		elements = elementsFolder,
		name = name,
	}

	return sectionData
end

function Library:CreateSlider(section, config)
	local name = config.name or "Slider"
	local default = config.default or 50
	local minVal = config.min or 0
	local maxVal = config.max or 100
	local step = config.step or 1
	local flag = config.flag or name:lower():gsub("%s+", "_")
	local callback = config.callback or function() end

	Library.flags[flag] = default

	local sliderFrame = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_WHITE,
		Size = UDim2.new(0, 233, 0, 37), BorderColor3 = COLOR_BLACK,
		Name = "Slider", BackgroundTransparency = 1, Parent = section.elements,
	})

	local sliderBar = Create("ImageButton", {
		AutoButtonColor = false, ImageTransparency = 1,
		BackgroundColor3 = COLOR_ELEMENT, ImageColor3 = Color3.fromRGB(22, 22, 22),
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Size = UDim2.new(0, 219, 0, 13), BorderColor3 = COLOR_BLACK,
		Position = UDim2.new(0, 7, 0, 18), Parent = sliderFrame,
	})
	applyGradient(sliderBar, GRADIENT_ELEMENT)

	local fill = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_ACCENT,
		Size = UDim2.new(0, 0, 0, 13), BorderColor3 = COLOR_BLACK,
		Parent = sliderBar,
	})
	applyGradient(fill, GRADIENT_ELEMENT)

	local nameLabel = Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = COLOR_TEXT, BackgroundTransparency = 1,
		Size = UDim2.new(0, 60, 0, 13), BorderColor3 = COLOR_BLACK,
		Text = name, Name = "name",
		Position = UDim2.new(0.02587, 0, 0.11566, -1), Parent = sliderFrame,
	})
	applyStroke(nameLabel)

	local valueLabel = Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = COLOR_TEXT, BackgroundTransparency = 1,
		Size = UDim2.new(0, 60, 0, 13), BorderColor3 = COLOR_BLACK,
		Text = tostring(default) .. " / " .. tostring(maxVal), Name = "value",
		Position = UDim2.new(0.36922, 0, 0.5, 0), Parent = sliderFrame,
	})
	applyStroke(valueLabel)

	local function updateSlider(frac)
		local val = minVal + (maxVal - minVal) * frac
		if step > 0 then
			val = math.floor(val / step + 0.5) * step
		end
		val = math.clamp(val, minVal, maxVal)
		tween(fill, {Size = UDim2.new(frac, 0, 0, 13)}, TWEEN_INFO_FAST):Play()
		local displayVal = step == 1 and math.floor(val) or val
		displayVal = string.format("%." .. (step < 1 and 2 or 0) .. "f", displayVal)
		valueLabel.Text = displayVal .. " / " .. tostring(maxVal)
		Library.flags[flag] = val
		callback(val)
	end

	local fracDefault = (default - minVal) / (maxVal - minVal)
	updateSlider(fracDefault)

	local dragging = false

	sliderBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)

	Services.User_Input.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	Services.User_Input.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local pos = input.Position
			local absPos = sliderBar.AbsolutePosition
			local absSize = sliderBar.AbsoluteSize
			local frac = math.clamp((pos.X - absPos.X) / absSize.X, 0, 1)
			updateSlider(frac)
		end
	end)

	sliderBar.MouseButton1Down:Connect(function()
		local pos = Services.User_Input:GetMouseLocation()
		local absPos = sliderBar.AbsolutePosition
		local absSize = sliderBar.AbsoluteSize
		local frac = math.clamp((pos.X - absPos.X) / absSize.X, 0, 1)
		updateSlider(frac)
	end)

	table.insert(self._syncList, {
		flag = flag,
		apply = function(val)
			if val == nil then val = Library.flags[flag] end
			if val == nil then return end
			fill.BackgroundColor3 = COLOR_ACCENT
			local frac = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
			fill.Size = UDim2.new(frac, 0, 0, 13)
			local displayVal = step == 1 and math.floor(val) or val
			displayVal = string.format("%." .. (step < 1 and 2 or 0) .. "f", displayVal)
			valueLabel.Text = displayVal .. " / " .. tostring(maxVal)
		end,
	})

	return {frame = sliderFrame, fill = fill, nameLabel = nameLabel, valueLabel = valueLabel}
end

function Library:CreateDropdown(section, config)
	local name = config.name or "Dropdown"
	local default = config.default or ""
	local options = config.options or {}
	local multi = config.multi or false
	local flag = config.flag or name:lower():gsub("%s+", "_")
	local callback = config.callback or function() end

	if multi then
		if type(default) == "string" then default = {default} end
		if type(default) ~= "table" then default = {} end
		Library.flags[flag] = default
	else
		Library.flags[flag] = default
	end

	local dropdownFrame = Instance.new("Frame")
	dropdownFrame.BorderSizePixel = 0
	dropdownFrame.BackgroundColor3 = COLOR_WHITE
	dropdownFrame.AutomaticSize = Enum.AutomaticSize.Y
	dropdownFrame.Size = UDim2.new(0, 233, 0, 24)
	dropdownFrame.BorderColor3 = COLOR_BLACK
	dropdownFrame.Name = "Dropdown"
	dropdownFrame.BackgroundTransparency = 1
	dropdownFrame.Parent = section.elements

	local ddButton = Instance.new("ImageButton")
	ddButton.AutoButtonColor = false
	ddButton.ImageTransparency = 1
	ddButton.BackgroundColor3 = COLOR_ELEMENT
	ddButton.ImageColor3 = Color3.fromRGB(22, 22, 22)
	ddButton.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	ddButton.Size = UDim2.new(0, 219, 0, 13)
	ddButton.BorderColor3 = COLOR_BLACK
	ddButton.Position = UDim2.new(0, 7, 0, 5)
	ddButton.Parent = dropdownFrame
	applyGradient(ddButton, GRADIENT_ELEMENT)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.TextStrokeTransparency = 0
	nameLabel.BorderSizePixel = 0
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.BackgroundColor3 = COLOR_WHITE
	nameLabel.FontFace = FONT
	nameLabel.TextColor3 = COLOR_TEXT
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(0, 130, 0, 13)
	nameLabel.BorderColor3 = COLOR_BLACK
	nameLabel.Text = multi and (name .. " (+" .. #default .. ")") or name
	nameLabel.Name = "name"
	nameLabel.Position = UDim2.new(0, 7, 0, 5)
	nameLabel.Parent = dropdownFrame
	applyStroke(nameLabel)

	local plusLabel = Instance.new("TextLabel")
	plusLabel.LineHeight = 0
	plusLabel.TextStrokeTransparency = 0
	plusLabel.BorderSizePixel = 0
	plusLabel.TextSize = 12
	plusLabel.TextYAlignment = Enum.TextYAlignment.Top
	plusLabel.BackgroundColor3 = COLOR_WHITE
	plusLabel.FontFace = FONT
	plusLabel.TextColor3 = COLOR_TEXT
	plusLabel.BackgroundTransparency = 1
	plusLabel.Size = UDim2.new(0, 14, 0, 13)
	plusLabel.BorderColor3 = COLOR_BLACK
	plusLabel.Text = "+"
	plusLabel.Name = "plus"
	plusLabel.Position = UDim2.new(0, 212, 0, 5)
	plusLabel.Parent = dropdownFrame
	applyStroke(plusLabel)

	local listFrame = Instance.new("Frame")
	listFrame.Visible = false
	listFrame.BorderSizePixel = 0
	listFrame.BackgroundColor3 = COLOR_BLACK
	listFrame.AutomaticSize = Enum.AutomaticSize.Y
	listFrame.Size = UDim2.new(0, 220, 0, 20)
	listFrame.Position = UDim2.new(0, 7, 0, 20)
	listFrame.BorderColor3 = COLOR_BLACK
	listFrame.Name = "list"
	listFrame.BackgroundTransparency = 1
	listFrame.ClipsDescendants = true
	listFrame.Parent = dropdownFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 3)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listFrame

	local selectedOption = default
	local optionButtons = {}
	local selectedSet = {}

	if multi then
		for _, v in ipairs(default) do
			selectedSet[v] = true
		end
	else
		selectedSet[default] = true
	end

	local function selectOption(opt)
		if multi then
			selectedSet[opt] = not selectedSet[opt]
			local selectedList = {}
			for _, o in ipairs(options) do
				if selectedSet[o] then table.insert(selectedList, o) end
			end
			selectedOption = selectedList
			Library.flags[flag] = selectedList
			for _, btn in ipairs(optionButtons) do
				btn.TextColor3 = selectedSet[btn.Text] and COLOR_ACCENT or Color3.fromRGB(155, 155, 155)
			end
			local displayText = #selectedList > 0 and table.concat(selectedList, ", ") or name
			if #displayText > 30 then displayText = displayText:sub(1, 27) .. "..." end
			nameLabel.Text = displayText
			callback(selectedList)
		else
			selectedOption = opt
			selectedSet = {[opt] = true}
			Library.flags[flag] = opt
			callback(opt)
			for _, btn in ipairs(optionButtons) do
				btn.TextColor3 = btn.Text == opt and COLOR_ACCENT or Color3.fromRGB(155, 155, 155)
			end
			listFrame.Visible = false
		end
	end

	for _, opt in ipairs(options) do
		local optBtn = Instance.new("TextButton")
		optBtn.AutoButtonColor = false
		optBtn.TextSize = 12
		local isSelected = multi and selectedSet[opt] or (opt == default)
		optBtn.TextColor3 = isSelected and COLOR_ACCENT or Color3.fromRGB(155, 155, 155)
		optBtn.BackgroundColor3 = COLOR_ELEMENT
		optBtn.FontFace = FONT
		optBtn.Size = UDim2.new(0, 219, 0, 13)
		optBtn.BorderColor3 = COLOR_BLACK
		optBtn.Text = opt
		optBtn.Name = "ImageButton"
		optBtn.Parent = listFrame
		applyGradient(optBtn, GRADIENT_ELEMENT)
		applyStroke(optBtn)
		optBtn.MouseButton1Click:Connect(function()
			selectOption(opt)
		end)
		table.insert(optionButtons, optBtn)
	end

	ddButton.MouseButton1Click:Connect(function()
		listFrame.Visible = not listFrame.Visible
	end)

	if not multi and default ~= "" then
		selectOption(default)
	elseif multi and #default > 0 then
		for _, v in ipairs(default) do
			selectOption(v)
		end
	end

	table.insert(self._syncList, {
		flag = flag,
		multi = multi,
		apply = function(val)
			if val == nil then val = Library.flags[flag] end
			if val == nil then return end
			if multi then
				selectedSet = {}
				if type(val) == "table" then
					for _, v in ipairs(val) do selectedSet[v] = true end
				end
				for _, btn in ipairs(optionButtons) do
					btn.TextColor3 = selectedSet[btn.Text] and COLOR_ACCENT or Color3.fromRGB(155, 155, 155)
				end
				local displayText = #val > 0 and table.concat(val, ", ") or name
				if #displayText > 30 then displayText = displayText:sub(1, 27) .. "..." end
				nameLabel.Text = displayText
			else
				for _, btn in ipairs(optionButtons) do
					btn.TextColor3 = btn.Text == val and COLOR_ACCENT or Color3.fromRGB(155, 155, 155)
				end
			end
		end,
	})

	local function refreshOptions(newOptions)
		for _, btn in ipairs(optionButtons) do
			btn:Destroy()
		end
		table.clear(optionButtons)
		options = newOptions or {}
		selectedSet = {}
		if multi then
			for _, v in ipairs(selectedOption) do
				selectedSet[v] = true
			end
		else
			selectedSet[selectedOption] = true
		end
		for _, opt in ipairs(options) do
			local optBtn = Instance.new("TextButton")
			optBtn.AutoButtonColor = false
			optBtn.TextSize = 12
			local isSelected = selectedSet[opt]
			optBtn.TextColor3 = isSelected and COLOR_ACCENT or Color3.fromRGB(155, 155, 155)
			optBtn.BackgroundColor3 = COLOR_ELEMENT
			optBtn.FontFace = FONT
			optBtn.Size = UDim2.new(0, 219, 0, 13)
			optBtn.BorderColor3 = COLOR_BLACK
			optBtn.Text = opt
			optBtn.Name = "ImageButton"
			optBtn.Parent = listFrame
			applyGradient(optBtn, GRADIENT_ELEMENT)
			applyStroke(optBtn)
			optBtn.MouseButton1Click:Connect(function()
				selectOption(opt)
			end)
			table.insert(optionButtons, optBtn)
		end
	end

	local dropdownData = {frame = dropdownFrame, options = optionButtons, listFrame = listFrame, RefreshOptions = refreshOptions}
	return dropdownData
end

function Library:CreateToggle(section, config)
	local lib = self
	local name = config.name or "Toggle"
	local default = config.default or false
	local flag = config.flag or name:lower():gsub("%s+", "_")
	local callback = config.callback or function() end

	Library.flags[flag] = default

	local toggleFrame = Instance.new("Frame")
	toggleFrame.BorderSizePixel = 0
	toggleFrame.BackgroundColor3 = COLOR_WHITE
	toggleFrame.Size = UDim2.new(0, 233, 0, 23)
	toggleFrame.BorderColor3 = COLOR_BLACK
	toggleFrame.Name = "Toggle"
	toggleFrame.BackgroundTransparency = 1
	toggleFrame.Parent = section.elements

	local checkbox = Instance.new("ImageButton")
	checkbox.AutoButtonColor = false
	checkbox.ImageTransparency = 1
	checkbox.BackgroundColor3 = default and COLOR_ACCENT or Color3.fromRGB(60, 60, 60)
	checkbox.ImageColor3 = default and COLOR_ACCENT or Color3.fromRGB(60, 60, 60)
	checkbox.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	checkbox.Size = UDim2.new(0, 13, 0, 13)
	checkbox.BorderColor3 = COLOR_BLACK
	checkbox.Position = UDim2.new(0, 7, 0, 5)
	checkbox.Parent = toggleFrame
	applyGradient(checkbox, GRADIENT_ELEMENT)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.TextStrokeTransparency = 0
	nameLabel.BorderSizePixel = 0
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.BackgroundColor3 = COLOR_WHITE
	nameLabel.FontFace = FONT
	nameLabel.TextColor3 = COLOR_TEXT
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(0, 193, 0, 15)
	nameLabel.BorderColor3 = COLOR_BLACK
	nameLabel.Text = name
	nameLabel.Position = UDim2.new(0.116, 0, 0.2, 0)
	nameLabel.Parent = toggleFrame
	applyStroke(nameLabel)

	local toggled = default

	local toggleData = {
		frame = toggleFrame,
		checkbox = checkbox,
		nameLabel = nameLabel,
		toggled = toggled,
		flag = flag,
		extras = {},
	}

	local function setToggle(val)
		toggled = val
		toggleData.toggled = val
		Library.flags[flag] = val
		local targetColor = val and COLOR_ACCENT or Color3.fromRGB(60, 60, 60)
		tween(checkbox, {BackgroundColor3 = targetColor, ImageColor3 = targetColor}, TWEEN_INFO_FAST):Play()
		callback(val)
	end

	checkbox.MouseButton1Click:Connect(function()
		setToggle(not toggled)
	end)

	local function getOrCreateExtrasFrame()
		for _, child in ipairs(toggleFrame:GetChildren()) do
			if child:IsA("Frame") and child.BackgroundTransparency == 1 and child:FindFirstChildOfClass("TextButton") then
				return child
			end
		end
		local ef = Create("Frame", {
			BorderSizePixel = 0, BackgroundColor3 = COLOR_WHITE,
			Size = UDim2.new(0, 128, 0, 13),
			Position = UDim2.new(0.42489, 0, 0.21739, 0),
			BorderColor3 = COLOR_BLACK, BackgroundTransparency = 1,
			Parent = toggleFrame,
		})
		Create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 5),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			Parent = ef,
		})
		return ef
	end

	function toggleData:CreateColorPicker(config)
		local cpConfig = config or {}
		local cpDefault = cpConfig.default or Color3.fromRGB(59, 180, 255)
		local cpFlag = cpConfig.flag or flag .. "_color"
		local cpCallback = cpConfig.callback or function() end

		Library.flags[cpFlag] = cpDefault

		local extrasFrame = getOrCreateExtrasFrame()

		local cpButton = Instance.new("TextButton")
		cpButton.AutoButtonColor = false
		cpButton.TextStrokeTransparency = 0
		cpButton.TextSize = 14
		cpButton.TextColor3 = cpDefault
		cpButton.BackgroundColor3 = cpDefault
		cpButton.FontFace = FONT
		cpButton.Size = UDim2.new(0, 25, 0, 13)
		cpButton.BorderColor3 = COLOR_BLACK
		cpButton.Text = ""
		cpButton.Name = "ColorPicker"
		cpButton.Parent = extrasFrame
		applyStroke(cpButton)

		cpButton.MouseButton1Click:Connect(function()
			lib.colorPickerTarget = cpButton
			lib.colorPickerCallback = function(c)
				tween(cpButton, {BackgroundColor3 = c, TextColor3 = c}, TWEEN_INFO_FAST):Play()
				Library.flags[cpFlag] = c
				cpCallback(c)
			end
			lib.colorPickerFlag = cpFlag
			lib.colorPickerRGB = Library.flags[cpFlag] or cpDefault
			local h, s, v = rgbToHsv(lib.colorPickerRGB)
			lib._colorHue, lib._colorSat, lib._colorVal = h, s, v
			if lib._updateColorPicker then lib._updateColorPicker() end
			local btnAbs = cpButton.AbsolutePosition
			lib.colorPickerPopup.Position = UDim2.new(0, btnAbs.X - 164, 0, btnAbs.Y - 82)
			lib.colorPickerPopup.Visible = true
			lib.colorPickerPopup.GroupTransparency = 1
			tween(lib.colorPickerPopup, {GroupTransparency = 0}, TWEEN_INFO_BOUNCE):Play()
		end)

		toggleFrame.Size = UDim2.new(0, 233, 0, 23)

		table.insert(toggleData.extras, {type = "colorpicker", frame = extrasFrame, button = cpButton, flag = cpFlag})

		table.insert(lib._syncList, {
            flag = cpFlag,
            apply = function(val)
                tween(cpButton, {BackgroundColor3 = Library.flags[cpFlag]}, TWEEN_INFO_FAST):Play()
            end,
        })
		return toggleData
	end

	function toggleData:CreateKeybind(config)
		local kbConfig = config or {}
		local kbDefault = kbConfig.default or "E"
		local kbDefaultMode = kbConfig.mode or "Toggle"
		local kbFlag = kbConfig.flag or flag .. "_keybind"
		local kbCallback = kbConfig.callback or function() end

		Library.flags[kbFlag] = {key = kbDefault, mode = kbDefaultMode, active = false}

		local keyState = {held = false, toggled = false}
		local keyTrackBegan = nil
		local keyTrackEnded = nil

		local function rebindTracker(keyName)
			if keyTrackBegan then keyTrackBegan:Disconnect() end
			if keyTrackEnded then keyTrackEnded:Disconnect() end
			if not keyName then
				keyState.held = false
				keyState.toggled = false
				Library.flags[kbFlag].active = false
				return
			end
			local targetKeyCode = nil
			local targetMouseType = nil
			local ok
			ok, targetMouseType = pcall(function() return Enum.UserInputType[keyName] end)
			if not ok then targetMouseType = nil end
			if not targetMouseType then
				ok, targetKeyCode = pcall(function() return Enum.KeyCode[keyName] end)
				if not ok then targetKeyCode = nil end
			end
			if not targetKeyCode and not targetMouseType then return end
			keyTrackBegan = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then return end
				local matched = (targetKeyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == targetKeyCode)
					or (targetMouseType and input.UserInputType == targetMouseType)
				if matched then
					keyState.held = true
					local flagData = Library.flags[kbFlag]
					if flagData then
						if flagData.mode == "Toggle" then
							keyState.toggled = not keyState.toggled
							flagData.active = keyState.toggled
						elseif flagData.mode == "Hold" then
							flagData.active = true
						else
							flagData.active = true
						end
					end
				end
			end)
			keyTrackEnded = Services.User_Input.InputEnded:Connect(function(input)
				local matched = (targetKeyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == targetKeyCode)
					or (targetMouseType and input.UserInputType == targetMouseType)
				if matched then
					keyState.held = false
					local flagData = Library.flags[kbFlag]
					if flagData and flagData.mode == "Hold" then
						flagData.active = false
					end
				end
			end)
		end

		function toggleData:IsActive()
			local flagData = Library.flags[kbFlag]
			if not flagData or not flagData.key then return false end
			if flagData.mode == "Hold" then return keyState.held end
			if flagData.mode == "Toggle" then return keyState.toggled end
			if flagData.mode == "Always" then return true end
			return false
		end

		rebindTracker(kbDefault)

		local function onKeyChanged(keyName, mode)
			rebindTracker(keyName)
			toggleData._keyMode = mode
		end

		local extrasFrame = getOrCreateExtrasFrame()

		local kbButton = Instance.new("TextButton")
		kbButton.AutoButtonColor = false
		kbButton.TextStrokeTransparency = 0
		kbButton.TextSize = 12
		kbButton.TextColor3 = COLOR_WHITE
		kbButton.BackgroundColor3 = COLOR_ELEMENT
		kbButton.FontFace = FONT
		kbButton.Size = UDim2.new(0, 26, 0, 13)
		kbButton.BorderColor3 = COLOR_BLACK
		kbButton.Text = "[" .. keyDisplayName(kbDefault) .. "]"
		kbButton.Name = "KeyPicker"
		kbButton.Parent = extrasFrame
		applyStroke(kbButton)
		Instance.new("UIPadding", kbButton).PaddingTop = UDim.new(0, -1)

		kbButton.MouseButton1Click:Connect(function()
			if lib._isMobile then return end
			kbButton.Text = "[...]"
			lib._keyDetectTarget = kbButton
			lib._keyDetectCallback = function(key, mode)
				Library.flags[kbFlag] = {key = key, mode = mode}
				onKeyChanged(key, mode)
				kbCallback(key, mode)
			end
			lib._keyDetectFlag = kbFlag
			lib._keyDetectMode = kbDefaultMode
			if lib._keyDetectConn then
				lib._keyDetectConn:Disconnect()
			end
			lib._keyDetectConn = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
				local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2
					or input.UserInputType == Enum.UserInputType.MouseButton3
				if gameProcessed and not isMouse then return end
				local keyName = nil
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Backspace then
						kbButton.Text = "[N/A]"
						Library.flags[kbFlag] = {key = nil, mode = kbDefaultMode, active = false}
						onKeyChanged(nil, kbDefaultMode)
						kbCallback(nil, kbDefaultMode)
					else
						keyName = input.KeyCode.Name
					end
				elseif isMouse then
					keyName = input.UserInputType.Name
				end
				if keyName then
					kbButton.Text = "[" .. keyDisplayName(keyName) .. "]"
					Library.flags[kbFlag] = {key = keyName, mode = kbDefaultMode, active = false}
					onKeyChanged(keyName, kbDefaultMode)
					kbCallback(keyName, kbDefaultMode)
				end
				if lib._keyDetectConn then
					lib._keyDetectConn:Disconnect()
					lib._keyDetectConn = nil
				end
			end)
		end)

		kbButton.MouseButton2Click:Connect(function()
			if lib._isMobile then return end
			lib._keyDetectTarget = kbButton
			lib._keyDetectCallback = function(key, mode)
				Library.flags[kbFlag] = {key = key, mode = mode, active = false}
				onKeyChanged(key, mode)
				kbCallback(key, mode)
			end
			lib._keyDetectFlag = kbFlag
			lib._keyDetectMode = kbDefaultMode
			local btnAbs = kbButton.AbsolutePosition
			lib.keyMenuPopup.Position = UDim2.new(0, btnAbs.X - 35, 0, btnAbs.Y + 15)
			lib.keyMenuPopup.Visible = true
			lib.keyMenuPopup.GroupTransparency = 1
			tween(lib.keyMenuPopup, {GroupTransparency = 0}, TWEEN_INFO_FAST):Play()
		end)

		toggleFrame.Size = UDim2.new(0, 233, 0, 23)

		table.insert(lib._syncList, {
            flag = kbFlag,
            apply = function(val)
                local displayText = keyDisplayName(Library.flags[kbFlag].key)
                kbButton.Text = displayText
            end,
        })
		return toggleData
	end

	function toggleData:AddContextMenu()
		local extrasFrame = getOrCreateExtrasFrame()

		local ctxButton = Instance.new("ImageButton")
		ctxButton.AutoButtonColor = false
		ctxButton.ScaleType = Enum.ScaleType.Fit
		ctxButton.BackgroundColor3 = COLOR_ELEMENT
		ctxButton.Image = "rbxassetid://6793572208"
		ctxButton.Size = UDim2.new(0, 15, 0, 13)
		ctxButton.BorderColor3 = COLOR_BLACK
		ctxButton.Name = "Context"
		ctxButton.Parent = extrasFrame

		local ctxPopup = Instance.new("CanvasGroup")
		ctxPopup.BackgroundColor3 = COLOR_BG
		ctxPopup.AutomaticSize = Enum.AutomaticSize.Y
		ctxPopup.Size = UDim2.new(0, 233, 0, 10)
		ctxPopup.BorderColor3 = COLOR_BLACK
		ctxPopup.Name = "ToggleContext"
		ctxPopup.Visible = false
		ctxPopup.GroupTransparency = 1
		ctxPopup.Parent = lib.screenGui
		ctxPopup.MouseEnter:Connect(function() lib._popupHovered[ctxPopup] = true end)
		ctxPopup.MouseLeave:Connect(function() lib._popupHovered[ctxPopup] = false end)
		Instance.new("UIPadding", ctxPopup).PaddingBottom = UDim.new(0, 5)

		lib._popupHovered[ctxPopup] = false

		local ctxElements = Instance.new("Folder")
		ctxElements.Name = "Elements"
		ctxElements.Parent = ctxPopup

		local ctxLayout = Instance.new("UIListLayout")
		ctxLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
		ctxLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ctxLayout.Parent = ctxElements

		local ctxOpen = {value = false}

		ctxButton.Activated:Connect(function()
			ctxOpen.value = not ctxOpen.value
			if ctxOpen.value then
				local btnAbs = ctxButton.AbsolutePosition
				ctxPopup.Position = UDim2.new(0, btnAbs.X - 220, 0, btnAbs.Y + 15)
				ctxPopup.Visible = true
				ctxPopup.GroupTransparency = 1
				tween(ctxPopup, {GroupTransparency = 0}, TWEEN_INFO_FAST):Play()
			else
				tween(ctxPopup, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
				task.delay(0.15, function()
					ctxPopup.Visible = false
				end)
			end
		end)

		local ctxSection = {
			frame = ctxPopup,
			inner = ctxPopup,
			elements = ctxElements,
			name = "context",
			Close = function()
				ctxOpen.value = false
				tween(ctxPopup, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
				task.delay(0.15, function()
					ctxPopup.Visible = false
				end)
			end,
		}

		table.insert(lib._openContextPopups, {popup = ctxPopup, open = ctxOpen})
		toggleData._ctxSection = ctxSection
		return ctxSection
	end

	table.insert(lib._syncList, {
		flag = flag,
		apply = function(val)
			if val == nil then val = Library.flags[flag] end
			if val == nil then return end
			local targetColor = val and COLOR_ACCENT or Color3.fromRGB(60, 60, 60)
			checkbox.BackgroundColor3 = targetColor
			checkbox.ImageColor3 = targetColor
			toggled = val
			toggleData.toggled = val
		end,
	})

	return toggleData
end

function Library:CreateTextBox(section, config)
	local name = config.name or "TextBox"
	local default = config.default or ""
	local placeholder = config.placeholder or "Config name...."
	local flag = config.flag or name:lower():gsub("%s+", "_")
	local callback = config.callback or function() end

	Library.flags[flag] = default

	local textboxFrame = Instance.new("Frame")
	textboxFrame.BorderSizePixel = 0
	textboxFrame.BackgroundColor3 = COLOR_WHITE
	textboxFrame.Size = UDim2.new(0, 233, 0, 24)
	textboxFrame.BorderColor3 = COLOR_BLACK
	textboxFrame.Name = "textbox"
	textboxFrame.BackgroundTransparency = 1
	textboxFrame.Parent = section.elements

	local tb = Instance.new("TextBox")
	tb.Name = "ImageButton"
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.TextSize = 12
	tb.TextColor3 = COLOR_WHITE
	tb.BackgroundColor3 = COLOR_ELEMENT
	tb.FontFace = FONT
	tb.PlaceholderText = placeholder
	tb.Size = UDim2.new(0, 219, 0, 14)
	tb.Position = UDim2.new(0, 8, 0, 5)
	tb.BorderColor3 = COLOR_BLACK
	tb.Text = default
	tb.Parent = textboxFrame
	applyGradient(tb, GRADIENT_ELEMENT)
	applyStroke(tb)

	tb.FocusLost:Connect(function(enterPressed)
		Library.flags[flag] = tb.Text
		callback(tb.Text, enterPressed)
	end)

	return {frame = textboxFrame, textbox = tb}
end

function Library:CreateButton(section, config)
	local name = config.name or "Button"
	local callback = config.callback or function() end

	local buttonFrame = Instance.new("Frame")
	buttonFrame.BorderSizePixel = 0
	buttonFrame.BackgroundColor3 = COLOR_WHITE
	buttonFrame.Size = UDim2.new(0, 233, 0, 24)
	buttonFrame.BorderColor3 = COLOR_BLACK
	buttonFrame.Name = "Button"
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = section.elements

	local btn = Instance.new("TextButton")
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(155, 155, 155)
	btn.BackgroundColor3 = COLOR_ELEMENT
	btn.FontFace = FONT
	btn.Size = UDim2.new(0, 219, 0, 13)
	btn.BorderColor3 = COLOR_BLACK
	btn.Text = name
	btn.Name = "ImageButton"
	btn.Position = UDim2.new(0, 8, 0, 5)
	btn.Parent = buttonFrame
	applyGradient(btn, GRADIENT_ELEMENT)
	applyStroke(btn)

	btn.MouseButton1Click:Connect(function()
		tween(btn, {BackgroundColor3 = COLOR_ACCENT}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			tween(btn, {BackgroundColor3 = COLOR_ELEMENT}, TWEEN_INFO_FAST):Play()
		end)
		callback()
	end)
	btn.AutoButtonColor = false

	return {frame = buttonFrame, button = btn}
end

function Library:CreateLabel(section, text)
	local labelFrame = Instance.new("Frame")
	labelFrame.BorderSizePixel = 0
	labelFrame.BackgroundColor3 = COLOR_WHITE
	labelFrame.AutomaticSize = Enum.AutomaticSize.Y
	labelFrame.Size = UDim2.new(0, 233, 0, 15)
	labelFrame.BorderColor3 = COLOR_BLACK
	labelFrame.Name = "Label"
	labelFrame.BackgroundTransparency = 1
	labelFrame.Parent = section.elements

	local lbl = Instance.new("TextLabel")
	lbl.TextWrapped = true
	lbl.TextStrokeTransparency = 0
	lbl.BorderSizePixel = 0
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BackgroundColor3 = COLOR_WHITE
	lbl.FontFace = FONT
	lbl.TextColor3 = COLOR_TEXT
	lbl.BackgroundTransparency = 1
	lbl.RichText = true
	lbl.Size = UDim2.new(0.94139, 0, 0.49524, 0)
	lbl.BorderColor3 = COLOR_BLACK
	lbl.Text = text
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.Position = UDim2.new(0.03286, 0, 0.01429, 0)
	lbl.Parent = labelFrame
	applyStroke(lbl)

	return {frame = labelFrame, label = lbl}
end

function Library:CreateWarning(title, text, callback)
	self.warningText.Text = text or ""
	self.warningCallback = callback
	self.warningFrame.Visible = true
	self.warningFrame.GroupTransparency = 1
	local boxStartPos = self.warningBox.Position
	self.warningBox.Position = UDim2.new(boxStartPos.X.Scale, boxStartPos.X.Offset, boxStartPos.Y.Scale, boxStartPos.Y.Offset + 10)
	tween(self.warningFrame, {GroupTransparency = 0}, TWEEN_INFO_FAST):Play()
	tween(self.warningBox, {Position = boxStartPos}, TWEEN_INFO_BOUNCE):Play()
end

function Library:SetVisible(visible)
	if visible then
		self._toggleId = (self._toggleId or 0) + 1
		self.main.Visible = true
		self.main.GroupTransparency = 1
		tween(self.main, {GroupTransparency = 0}, TWEEN_INFO_BOUNCE):Play()
		if not self._cursorUnlockConn then
			self._cursorUnlockConn = Services.Run_Service.RenderStepped:Connect(function()
				Services.User_Input.MouseBehavior = Enum.MouseBehavior.Default
				Services.User_Input.MouseIconEnabled = true
			end)
		end
	else
		self._toggleId = (self._toggleId or 0) + 1
		local captureId = self._toggleId
		tween(self.main, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
		task.delay(0.15, function()
			if self._toggleId == captureId then
				self.main.Visible = false
			end
		end)
		self.colorPickerPopup.Visible = false
		self.keyMenuPopup.Visible = false
		self.warningFrame.Visible = false
		-- stop forcing the cursor free and hand control back to the game (re-lock for FPS)
		if self._cursorUnlockConn then
			self._cursorUnlockConn:Disconnect()
			self._cursorUnlockConn = nil
		end
		Services.User_Input.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

function Library:Destroy()
	if self._rightClickConn then
		self._rightClickConn:Disconnect()
		self._rightClickConn = nil
	end
	if self._menuKeyConn then
		self._menuKeyConn:Disconnect()
		self._menuKeyConn = nil
	end
	if self._keyDetectConn then
		self._keyDetectConn:Disconnect()
		self._keyDetectConn = nil
	end
	if self._outsideClickConn then
		self._outsideClickConn:Disconnect()
		self._outsideClickConn = nil
	end
	if self._keybindUpdateConn then
		self._keybindUpdateConn:Disconnect()
		self._keybindUpdateConn = nil
	end
	if self._cursorUnlockConn then
		self._cursorUnlockConn:Disconnect()
		self._cursorUnlockConn = nil
	end
	pcall(function()
		self.screenGui:Destroy()
	end)
end

function Library:Unload()
	self:Destroy()
	if self._onUnloadCallback then
		self._onUnloadCallback()
	end
end

function Library:OnUnload(callback)
	self._onUnloadCallback = callback
end

function Library:Toggle()
	if self.main.Visible then
		self:SetVisible(false)
	else
		self:SetVisible(true)
	end
end

function Library:SetMenuKeybind(key)
	self._menuKeybind = key
	if self._menuKeyConn then
		self._menuKeyConn:Disconnect()
	end
	self._menuKeyConn = Services.User_Input.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key then
			self:Toggle()
		end
	end)
end

function Library:SaveConfig(name)
	local function isColor3(v)
		local ok = pcall(function() return v.R, v.G, v.B end)
		return ok and type(v.R) == "number"
	end
	local function serialize(v)
		if isColor3(v) then
			return {__color3 = {v.R, v.G, v.B}}
		elseif type(v) == "table" then
			local t = {}
			for kk, vv in pairs(v) do
				t[kk] = serialize(vv)
			end
			return t
		end
		return v
	end
	local filtered = {}
	for k, v in pairs(Library.flags) do
		if type(k) == "string" then
			filtered[k] = serialize(v)
		end
	end
	local json = HttpService:JSONEncode(filtered)
	makefolder(self._configFolder)
	writefile(self._configFolder .. "/" .. name .. ".json", json)
	writefile(self._configFolder .. "/_last.txt", name)
end

function Library:LoadConfig(name)
	local function deserialize(v)
		if type(v) == "table" and v.__color3 then
			return Color3.new(v.__color3[1], v.__color3[2], v.__color3[3])
		elseif type(v) == "table" then
			local t = {}
			for kk, vv in pairs(v) do
				t[kk] = deserialize(vv)
			end
			return t
		end
		return v
	end
	local path = self._configFolder .. "/" .. name .. ".json"
	if not isfile(path) then return false end
	local json = readfile(path)
	local data = HttpService:JSONDecode(json)
	if type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		Library.flags[k] = deserialize(v)
	end
	writefile(self._configFolder .. "/_last.txt", name)
	self:RefreshAll()
	return true
end

function Library:LoadLastConfig()
	local path = self._configFolder .. "/_last.txt"
	if not isfile(path) then return false end
	local name = readfile(path)
	if name and name ~= "" then
		return self:LoadConfig(name)
	end
	return false
end

function Library:GetConfigs()
	local configs = {}
	if not isfolder(self._configFolder) then return configs end
	for _, file in ipairs(listfiles(self._configFolder)) do
		local name = file:match("([^/\\]+)%.json$")
		if name then table.insert(configs, name) end
	end
	return configs
end

function Library:DeleteConfig(name)
	local path = self._configFolder .. "/" .. name .. ".json"
	if isfile(path) then delfile(path) end
end

function Library:RefreshAll()
	for _, sync in ipairs(self._syncList) do
		sync.apply()
	end
end

function Library:Notify(text, isWarning)
	local barColor = typeof(isWarning) == "boolean" and Color3.fromRGB(255, 200, 0) or COLOR_ACCENT
	local duration = 3

	local displayText = text or ""

	local notifyFrame = Create("CanvasGroup", {
		BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(0, 0, 0, 22),
		BorderColor3 = COLOR_BLACK,
		Name = "Notification",
		GroupTransparency = 1,
		ZIndex = 999,
		Parent = self.notifyHolder,
	})

	local notifyText = Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = isWarning and barColor or COLOR_TEXT,
		BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		BorderColor3 = COLOR_BLACK,
		Text = displayText,
		Position = UDim2.new(0, 6, 0, 0),
		Parent = notifyFrame,
	})
	applyStroke(notifyText)
	local textWidth = notifyText.TextBounds.X
	notifyText.AutomaticSize = Enum.AutomaticSize.None

	local frameWidth = math.clamp(math.ceil(textWidth) + 52, 120, 400)
	notifyFrame.Size = UDim2.new(0, frameWidth, 0, 22)
	notifyText.Size = UDim2.new(0, frameWidth - 36, 1, 0)

	local timerLabel = Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = barColor, BackgroundTransparency = 1,
		Size = UDim2.new(0, 28, 1, 0), BorderColor3 = COLOR_BLACK,
		Text = duration .. "s",
		Position = UDim2.new(1, -32, 0, 0), Parent = notifyFrame,
	})

	local timerBar = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = barColor,
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BorderColor3 = COLOR_BLACK, Parent = notifyFrame,
	})
	applyStroke(timerBar)

	notifyFrame.Position = UDim2.new(0, -frameWidth - 20, notifyFrame.Position.Y.Scale, notifyFrame.Position.Y.Offset)
	tween(notifyFrame, {Position = UDim2.new(0, 4, notifyFrame.Position.Y.Scale, notifyFrame.Position.Y.Offset), GroupTransparency = 0}, TWEEN_INFO_SMOOTH):Play()
	tween(timerBar, {Size = UDim2.new(0, 0, 0, 2)}, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)):Play()

	if isWarning then
		local flashTween = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for i = 1, 6 do
			task.delay((i - 1) * 0.5, function()
				local target = i % 2 == 1 and barColor or Color3.fromRGB(80, 60, 0)
				tween(timerBar, {BackgroundColor3 = target}, flashTween):Play()
			end)
		end
	else
		local flashTween = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for i = 1, 6 do
			task.delay((i - 1) * 0.5, function()
				local target = i % 2 == 1 and barColor or Color3.fromRGB(2, 60, 110)
				tween(timerBar, {BackgroundColor3 = target}, flashTween):Play()
			end)
		end
	end

	for i = duration - 1, 0, -1 do
		task.delay(duration - i, function()
			if notifyFrame and notifyFrame.Parent then
				timerLabel.Text = i .. "s"
			end
		end)
	end

	task.delay(duration, function()
		local outTween = tween(notifyFrame, {Position = UDim2.new(0, -frameWidth - 20, notifyFrame.Position.Y.Scale, notifyFrame.Position.Y.Offset), GroupTransparency = 1}, TWEEN_INFO_SMOOTH)
		outTween:Play()
		outTween.Completed:Connect(function()
			notifyFrame:Destroy()
		end)
	end)
end

function Library:CreateMultiTab(tab, name)
	if not tab._multiTabs then
		tab._multiTabs = {}
		tab._multiActive = nil

		local multiCanvas = Create("CanvasGroup", {
			BackgroundColor3 = COLOR_INNER,
			Size = UDim2.new(0, 486, 0, 393),
			Position = UDim2.new(-0.0004, 0, -0, 0),
			BorderColor3 = COLOR_BLACK,
			Name = "multitab",
			Parent = tab.canvas,
		})
		applyStroke(multiCanvas)
		tab._multiCanvas = multiCanvas

		local tabButtons = Create("Frame", {
			BorderSizePixel = 0, BackgroundColor3 = COLOR_WHITE,
			Size = UDim2.new(0, 471, 0, 17),
			Position = UDim2.new(0.014, 1, 0, 7),
			BorderColor3 = COLOR_BLACK, BackgroundTransparency = 1,
			Name = "tabbuttons", Parent = multiCanvas,
		})
		Create("UIListLayout", {
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			Parent = tabButtons,
		})
		tab._tabButtons = tabButtons

		local tabsFolder = Create("Folder", {
			Name = "tabs", Parent = multiCanvas,
		})
		tab._tabsFolder = tabsFolder
	end

	local mtButton = Create("TextButton", {
		AutoButtonColor = false, TextSize = 12, TextColor3 = Color3.fromRGB(137, 137, 137),
		BackgroundColor3 = Color3.fromRGB(12, 12, 12), FontFace = FONT,
		Size = UDim2.new(0, 71, 0, 18), BorderColor3 = COLOR_BLACK,
		Text = name, Parent = tab._tabButtons,
	})
	applyGradient(mtButton, GRADIENT_COLOR)
	applyStroke(mtButton)

	local isFirst = (#tab._multiTabs == 0)
	local mtCanvas = Create("CanvasGroup", {
		BackgroundColor3 = COLOR_INNER,
		Size = UDim2.new(0, 486, 0, 361),
		Position = UDim2.new(0, 0, 0.08142, 0),
		BorderColor3 = COLOR_BLACK,
		GroupTransparency = isFirst and 0 or 1,
		Name = name,
		Visible = isFirst,
		Parent = tab._tabsFolder,
	})
	applyStroke(mtCanvas)

	local leftSection = Create("ScrollingFrame", {
		Active = true, CanvasSize = UDim2.new(0, 0, 0, 0),
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		Name = "left_section", BackgroundColor3 = COLOR_DARK,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 233, 0, 347),
		ScrollBarImageColor3 = COLOR_SCROLLBAR,
		Position = UDim2.new(0.01443, 0, 0.01863, 0),
		BorderColor3 = COLOR_BLACK, ScrollBarThickness = 3,
		Parent = mtCanvas,
	})

	local leftElements = Create("Folder", {Name = "Elements", Parent = leftSection})
	Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = leftElements})

	local rightSection = Create("ScrollingFrame", {
		Active = true, CanvasSize = UDim2.new(0, 0, 0, 0),
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		Name = "right_section", BackgroundColor3 = COLOR_DARK,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, 233, 0, 347),
		ScrollBarImageColor3 = COLOR_SCROLLBAR,
		Position = UDim2.new(0.50722, 0, 0.01863, 0),
		BorderColor3 = COLOR_BLACK, ScrollBarThickness = 3,
		Parent = mtCanvas,
	})
	Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightSection})

	local mtData = {
		button = mtButton,
		canvas = mtCanvas,
		leftSection = leftSection,
		leftElements = leftElements,
		rightSection = rightSection,
		rightElements = rightSection,
		name = name,
	}

	mtButton.MouseButton1Click:Connect(function()
		for _, mt in ipairs(tab._multiTabs) do
			if mt == mtData then
				mt.canvas.Visible = true
				mt.canvas.GroupTransparency = 1
				tween(mt.canvas, {GroupTransparency = 0}, TWEEN_INFO_SMOOTH):Play()
				mt.button.TextColor3 = COLOR_ACCENT
				mt.button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			else
				tween(mt.canvas, {GroupTransparency = 1}, TWEEN_INFO_FAST):Play()
				task.delay(0.12, function()
					if tab._multiActive ~= mt then
						mt.canvas.Visible = false
					end
				end)
				mt.button.TextColor3 = Color3.fromRGB(137, 137, 137)
				mt.button.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
			end
		end
		tab._multiActive = mtData
	end)

	table.insert(tab._multiTabs, mtData)
	if #tab._multiTabs == 1 then
		tab._multiActive = mtData
		mtButton.TextColor3 = COLOR_ACCENT
		mtButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	end

	return mtData
end

function Library:ShowKeybinds(visible, mode)
	self.keybindPanel.Visible = visible
	self._keybindMode = mode or "all"
end

function Library:RegisterKeybindLabel(flag, displayName)
	local holder = self.keybindPanel:FindFirstChild("holder")
	if not holder then return end

	local frame = Create("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = COLOR_BG,
		Size = UDim2.new(1, 0, 0, 20), BorderColor3 = COLOR_BLACK,
		Name = "inactive", Parent = holder,
	})
	applyGradient(frame)

	local label = Create("TextLabel", {
		TextStrokeTransparency = 0, BorderSizePixel = 0, TextSize = 12,
		BackgroundColor3 = COLOR_WHITE, FontFace = FONT,
		TextColor3 = COLOR_TEXT, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), BorderColor3 = COLOR_BLACK,
		Text = "[N/A] " .. (displayName or "keybind"), Parent = frame,
	})
	applyStroke(label)

	self._keybindNames[flag] = displayName or "keybind"
	self._keybindLabels[flag] = label
	self._keybindFrames[flag] = frame
	return label
end

return Library
