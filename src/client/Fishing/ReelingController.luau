-- Balık tutma (client tarafı): buton, reeling bar, yakalama popup'ı.
-- UI tamamen koddan kurulur, Studio'da çizim gerekmez.
--
-- Kontroller:
--   Mobil: sağ alttaki büyük buton (zıplama butonunun üstünde)
--   PC:    F tuşu veya ekrandaki butona tıklama
--   Gamepad: X
--
-- Akış: "At" -> bekle -> "BAS!" -> hızlı hızlı tıkla: gösterge yeşilde kalsın
--   Çekme çubuğu: altta ve üstte kırmızı, ortada yeşil (arada turuncu).
--   Her tıklama göstergeyi yukarı iter, yerçekimi aşağı çeker, balık da rastgele çekiştirir.
--   Yavaş tıklarsan aşağı düşer, çok hızlı tıklarsan yukarı fırlar. Yeşilde ilerleme dolar;
--   kırmızıda uzun süre (RED_LIMIT sn) kalırsan balık kaçar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HapticService = game:GetService("HapticService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Cfg = require(Config:WaitForChild("Fishing"))
local FishingWater = require(Config.Parent:WaitForChild("FishingWater"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))

local Audio = require(Config:WaitForChild("Audio"))

local ReelingController = {}
ReelingController._debugTap = nil -- (test) Studio'da tıklama simülasyonu

-- Çekme ayarları
local TAP_IMPULSE = 0.42 -- her tıklamanın yukarı itişi
local GRAVITY = 1.25 -- aşağı çekiş (≈3 tık/sn dengede tutar)
local DAMPING = 2.6 -- hız sönümü
local CENTER = 1.8 -- ortaya hafif çekim: ~2.5-3.5 tık/sn yeşilde tutar, yavaşı aşağı, hızlıyı yukarı kaydırır
local FISH_PULL = 0.55 -- balığın çekiştirme gücü (nadirliğin barSpeed'i ile çarpılır)
local RED_ZONE = 0.17 -- alttaki ve üstteki kırmızı bölgelerin boyu
local RED_LIMIT = 1.6 -- kırmızıda bu kadar saniye kalırsa balık kaçar

local MESSAGES = {
	early = "Erken bastın, balık kaçtı",
	late = "Geç kaldın, balık kaçtı",
	escaped = "Balık kaçtı",
	full = "Tekne deposu dolu! Limana dön",
	far = "Spot'a çok uzaksın",
	nofish = "Burada balık yok",
	notwater = "Buraya olta atamazsın, suya dön",
	invalid = "Bir şeyler ters gitti",
}

local COLOR_BTN = Color3.fromRGB(30, 140, 210)
local COLOR_BITE = Color3.fromRGB(235, 80, 60)
local COLOR_IN = Color3.fromRGB(90, 200, 90)
local COLOR_OUT = Color3.fromRGB(220, 90, 70)

-- Durum
local phase = "idle" -- idle | waiting | bite | hooking | reeling | sent | cooldown
local holding = false
local activeInput: InputObject? = nil
local nearSpot: BasePart? = nil
local openWaterPoint: Vector3? = nil -- işaretli spot yoksa önündeki su noktası
local phaseSince = os.clock() -- zaman aşımı kontrolü için

local barSpeed, targetSize = 1, 0.3
local zp, zv, fp, ft, fTimer, progress = 0, 0, 0.5, 0.5, 0, 0.3
local pos, vel, pull, pullTimer, redTime, greenSize = 0.5, 0, 0, 0, 0, 0.36
local reelSound: Sound? = nil

-- UI referansları
local gui, button, status, bar, zone, fishDot, progFill, popup, viewport, popupLabel
local greenFrame, needle, dangerFill, tapHint, bigPopup
local popupConn: RBXScriptConnection? = nil

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "FishingGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Ana buton (mobilde zıplama butonunun üstünde)
	button = Instance.new("TextButton")
	button.Name = "FishButton"
	button.Size = UDim2.fromOffset(110, 110)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -20, 1, -170)
	button.BackgroundColor3 = COLOR_BTN
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Text = "At"
	button.Visible = false
	corner(button, UDim.new(0.5, 0))
	stroke(button, Color3.new(1, 1, 1), 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 30)
	pad.PaddingBottom = UDim.new(0, 30)
	pad.Parent = button
	button.Parent = gui

	-- Durum yazısı (butonun üstünde)
	status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.fromOffset(280, 36)
	status.AnchorPoint = Vector2.new(1, 1)
	status.Position = UDim2.new(1, -20, 1, -290)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.3
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Text = ""
	status.Parent = gui

	-- Çekme çubuğu: büyük, altta/üstte kırmızı, ortada yeşil
	bar = Instance.new("Frame")
	bar.Name = "ReelBar"
	bar.Size = UDim2.fromOffset(74, 380)
	bar.AnchorPoint = Vector2.new(1, 0.5)
	bar.Position = UDim2.new(1, -170, 0.5, -30)
	bar.BackgroundColor3 = Color3.fromRGB(240, 160, 50) -- arada turuncu (güvenli ama ilerlemez)
	bar.Visible = false
	bar.ClipsDescendants = false
	corner(bar, UDim.new(0, 12))
	stroke(bar, Color3.new(1, 1, 1), 3)
	bar.Parent = gui

	local function zoneFrame(name, color, anchorY)
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, RED_ZONE)
		corner(f, UDim.new(0, 12))
		f.Parent = bar
		return f
	end
	zoneFrame("RedTop", Color3.fromRGB(215, 55, 50), 0)
	zoneFrame("RedBottom", Color3.fromRGB(215, 55, 50), 1)
	greenFrame = Instance.new("Frame")
	greenFrame.Name = "Green"
	greenFrame.BackgroundColor3 = Color3.fromRGB(70, 205, 90)
	greenFrame.BorderSizePixel = 0
	greenFrame.AnchorPoint = Vector2.new(0, 0.5)
	greenFrame.Position = UDim2.fromScale(0, 0.5)
	greenFrame.Size = UDim2.fromScale(1, greenSize)
	greenFrame.Parent = bar
	for _, f in bar:GetChildren() do
		if f:IsA("Frame") then
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 0) })
			g.Parent = f
		end
	end

	-- gösterge: çubuğu boydan boya geçen beyaz çizgi + balık rengi top
	needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Size = UDim2.new(1, 22, 0, 8)
	needle.BackgroundColor3 = Color3.new(1, 1, 1)
	needle.ZIndex = 3
	corner(needle, UDim.new(0.5, 0))
	stroke(needle, Color3.fromRGB(20, 20, 30), 2)
	needle.Parent = bar
	fishDot = Instance.new("Frame")
	fishDot.Name = "Fish"
	fishDot.Size = UDim2.fromOffset(30, 30)
	fishDot.AnchorPoint = Vector2.new(0.5, 0.5)
	fishDot.Position = UDim2.fromScale(0, 0.5)
	fishDot.ZIndex = 4
	corner(fishDot, UDim.new(0.5, 0))
	stroke(fishDot, Color3.new(0, 0, 0), 2)
	fishDot.Parent = needle
	local fishIcon = Instance.new("TextLabel")
	fishIcon.Size = UDim2.fromScale(1, 1)
	fishIcon.BackgroundTransparency = 1
	fishIcon.Text = "🐟"
	fishIcon.TextScaled = true
	fishIcon.ZIndex = 5
	fishIcon.Parent = fishDot

	-- ilerleme (sağda, uzun)
	local progBg = Instance.new("Frame")
	progBg.Name = "ProgressBg"
	progBg.Size = UDim2.new(0, 18, 1, 0)
	progBg.Position = UDim2.new(1, 12, 0, 0)
	progBg.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
	progBg.BackgroundTransparency = 0.2
	corner(progBg, UDim.new(0, 9))
	stroke(progBg, Color3.new(1, 1, 1), 2)
	progBg.Parent = bar
	progFill = Instance.new("Frame")
	progFill.Name = "Fill"
	progFill.AnchorPoint = Vector2.new(0, 1)
	progFill.Position = UDim2.fromScale(0, 1)
	progFill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	progFill.BorderSizePixel = 0
	corner(progFill, UDim.new(0, 9))
	progFill.Parent = progBg

	-- kırmızı tehlike sayacı (solda): dolarsa balık kaçar
	local dangerBg = Instance.new("Frame")
	dangerBg.Name = "DangerBg"
	dangerBg.Size = UDim2.new(0, 10, 1, 0)
	dangerBg.AnchorPoint = Vector2.new(1, 0)
	dangerBg.Position = UDim2.new(0, -12, 0, 0)
	dangerBg.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
	dangerBg.BackgroundTransparency = 0.3
	corner(dangerBg, UDim.new(0, 5))
	dangerBg.Parent = bar
	dangerFill = Instance.new("Frame")
	dangerFill.AnchorPoint = Vector2.new(0, 1)
	dangerFill.Position = UDim2.fromScale(0, 1)
	dangerFill.Size = UDim2.fromScale(1, 0)
	dangerFill.BackgroundColor3 = Color3.fromRGB(255, 60, 50)
	dangerFill.BorderSizePixel = 0
	corner(dangerFill, UDim.new(0, 5))
	dangerFill.Parent = dangerBg

	tapHint = Instance.new("TextLabel")
	tapHint.AnchorPoint = Vector2.new(0.5, 1)
	tapHint.Position = UDim2.new(0.5, 0, 0, -10)
	tapHint.Size = UDim2.fromOffset(170, 34)
	tapHint.BackgroundTransparency = 1
	tapHint.Font = Enum.Font.FredokaOne
	tapHint.TextSize = 26
	tapHint.TextColor3 = Color3.new(1, 1, 1)
	tapHint.TextStrokeTransparency = 0.2
	tapHint.Text = "TAP TAP!"
	tapHint.Parent = bar

	zone = greenFrame

	-- Yakalama popup'ı (döner 3D balık)
	popup = Instance.new("Frame")
	popup.Name = "CatchPopup"
	popup.Size = UDim2.fromOffset(260, 200)
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, 0, 0, 70)
	popup.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
	popup.BackgroundTransparency = 0.2
	popup.Visible = false
	corner(popup, UDim.new(0, 12))
	popup.Parent = gui

	viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -16, 0, 140)
	viewport.Position = UDim2.fromOffset(8, 8)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(180, 180, 180)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.Parent = popup

	popupLabel = Instance.new("TextLabel")
	popupLabel.Size = UDim2.new(1, -16, 0, 40)
	popupLabel.Position = UDim2.fromOffset(8, 152)
	popupLabel.BackgroundTransparency = 1
	popupLabel.Font = Enum.Font.GothamBold
	popupLabel.TextScaled = true
	popupLabel.TextStrokeTransparency = 0.4
	popupLabel.Parent = popup

	-- Yeni tür: ekranın ortasında büyük dönen balık, arkası nadirlik renginde
	bigPopup = Instance.new("Frame")
	bigPopup.Name = "NewFishPopup"
	bigPopup.AnchorPoint = Vector2.new(0.5, 0.5)
	bigPopup.Position = UDim2.fromScale(0.5, 0.45)
	bigPopup.Size = UDim2.fromOffset(440, 440)
	bigPopup.BackgroundTransparency = 1
	bigPopup.Visible = false
	bigPopup.ZIndex = 20
	bigPopup.Parent = gui
end

local function setState(text: string, btnText: string, color: Color3?)
	phaseSince = os.clock()
	status.Text = text
	button.Text = btnText
	button.BackgroundColor3 = color or COLOR_BTN
end

local function pulse()
	button.Size = UDim2.fromOffset(130, 130)
	TweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(110, 110) }):Play()
	pcall(function()
		if HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large) then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0.6)
			task.delay(0.2, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
			end)
		end
	end)
end

local function finish(message: string)
	if reelSound then
		reelSound:Stop()
		reelSound:Destroy()
		reelSound = nil
	end
	phase = "cooldown"
	holding = false
	bar.Visible = false
	setState(message, "At")
	task.delay(1.5, function()
		if phase == "cooldown" then
			phase = "idle"
			status.Text = ""
		end
	end)
end

local function showPopup(fishId: string)
	local def = Fish[fishId]
	if not def then
		return
	end
	if popupConn then
		popupConn:Disconnect()
		popupConn = nil
	end
	viewport:ClearAllChildren()

	local model = FishModelBuilder.Build(fishId)
	if not model then
		return
	end
	model.Parent = viewport

	local L = def.look.length
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(L * 1.7 + 1, L * 0.3, 0), Vector3.zero)
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	popupLabel.Text = def.displayName .. " (" .. def.rarity .. ")"
	popupLabel.TextColor3 = (Rarities :: any)[def.rarity].color
	popup.Visible = true

	local t0 = os.clock()
	popupConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		model:PivotTo(CFrame.Angles(0, t * 1.2, 0))
		if t > 3 then
			if popupConn then
				popupConn:Disconnect()
				popupConn = nil
			end
			popup.Visible = false
		end
	end)
end

-- Yeni tür ilk kez tutuldu: ortada büyük dönen balık, nadirlik renginde ışık, nadirse parıltılar
local SHINE = {
	Common = { a = Color3.fromRGB(150, 150, 150), b = Color3.fromRGB(60, 60, 66), sparks = 0 },
	Uncommon = { a = Color3.fromRGB(110, 230, 120), b = Color3.fromRGB(30, 90, 40), sparks = 6 },
	Rare = { a = Color3.fromRGB(90, 170, 255), b = Color3.fromRGB(20, 50, 120), sparks = 12 },
	Epic = { a = Color3.fromRGB(200, 110, 255), b = Color3.fromRGB(70, 20, 110), sparks = 22 },
	Legendary = { a = Color3.fromRGB(255, 215, 70), b = Color3.fromRGB(150, 90, 0), sparks = 40 },
}

local function showNewFish(fishId: string)
	local def = Fish[fishId]
	if not def then
		return
	end
	local sh = SHINE[def.rarity] or SHINE.Common
	bigPopup:ClearAllChildren()
	bigPopup.Visible = true

	-- arkası: nadirlik renginde parlayan daire + dönen ışınlar
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = sh.a
	glow.ZIndex = 20
	corner(glow, UDim.new(0.5, 0))
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(sh.a, sh.b)
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
	grad.Rotation = 90
	grad.Parent = glow
	glow.Parent = bigPopup
	local rays = Instance.new("Frame")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.25, 1.25)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 20
	rays.Parent = bigPopup
	for k = 0, 7 do
		local r = Instance.new("Frame")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.new(0, 34, 1, 0)
		r.Rotation = k * 22.5
		r.BackgroundColor3 = sh.a
		r.BackgroundTransparency = 0.7
		r.BorderSizePixel = 0
		r.ZIndex = 20
		r.Parent = rays
	end

	local vp = Instance.new("ViewportFrame")
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.48)
	vp.Size = UDim2.fromScale(0.85, 0.6)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.ZIndex = 22
	vp.Parent = bigPopup
	local model = FishModelBuilder.Build(fishId)
	if model then
		model.Parent = vp
		local cf = model:GetBoundingBox()
		model:TranslateBy(-cf.Position)
	end
	local L = def.look.length
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(L * 1.5 + 1, L * 0.25, 0), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam

	local function text(t, y, size, color)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.new(1.2, 0, 0, size + 10)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		l.Text = t
		l.ZIndex = 25
		l.Parent = bigPopup
		return l
	end
	text("★ NEW FISH! ★", 0.08, 40, Color3.new(1, 1, 1))
	text(def.displayName, 0.84, 46, Color3.new(1, 1, 1))
	text(def.rarity, 0.95, 30, (Rarities :: any)[def.rarity].color)

	-- giriş zıplaması
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = bigPopup
	TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	-- ses
	local snd = Instance.new("Sound")
	snd.SoundId = Audio.NewFish
	snd.Volume = if def.rarity == "Legendary" or def.rarity == "Epic" then 0.9 else 0.6
	snd.Parent = game:GetService("SoundService")
	snd:Play()
	snd.Ended:Once(function()
		snd:Destroy()
	end)

	-- parıltılar (Legendary: altın yağmuru)
	local sparks = {}
	for i = 1, sh.sparks do
		local st = Instance.new("TextLabel")
		st.AnchorPoint = Vector2.new(0.5, 0.5)
		st.Position = UDim2.fromScale(0.5, 0.5)
		st.Size = UDim2.fromOffset(math.random(18, 34), math.random(18, 34))
		st.BackgroundTransparency = 1
		st.Text = "★"
		st.TextScaled = true
		st.TextColor3 = sh.a:Lerp(Color3.new(1, 1, 1), math.random() * 0.5)
		st.ZIndex = 26
		st.Parent = bigPopup
		local a = math.random() * math.pi * 2
		table.insert(sparks, { ui = st, dx = math.cos(a), dy = math.sin(a), spd = 0.25 + math.random() * 0.45, delay = math.random() * 1.5, spin = math.random(-200, 200) })
	end

	local t0 = os.clock()
	local DUR = if def.rarity == "Legendary" then 4.5 else 3.5
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if model then
			model:PivotTo(CFrame.Angles(0, t * 1.6, math.sin(t * 2) * 0.12))
		end
		rays.Rotation = t * 25
		glow.BackgroundTransparency = 0.1 + math.sin(t * 5) * 0.08
		for _, sp in sparks do
			local life = (t - sp.delay) % 1.6
			local d = life * sp.spd
			sp.ui.Position = UDim2.fromScale(0.5 + sp.dx * d, 0.5 + sp.dy * d)
			sp.ui.Rotation += sp.spin * dt
			sp.ui.TextTransparency = math.clamp(life / 1.6, 0, 1)
		end
		if t > DUR then
			conn:Disconnect()
			local out = TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			out:Play()
			out.Completed:Wait()
			bigPopup.Visible = false
			bigPopup:ClearAllChildren()
		end
	end)
end

-- Input --------------------------------------------------------------------

local tap: () -> () -- aşağıda tanımlanıyor (önceden bildirildi)

local function press()
	holding = true
	if phase == "idle" then
		local target: any = nearSpot or openWaterPoint
		if not target then
			return
		end
		phase = "waiting"
		setState("Bekleniyor...", "Bekle")
		Remotes.Event("CastRequest"):FireServer(target)
	elseif phase == "waiting" then
		-- erken bastı: server "early" diyecek
		Remotes.Event("HookRequest"):FireServer()
	elseif phase == "reeling" then
		tap()
	elseif phase == "bite" then
		phase = "hooking"
		setState("Takılıyor...", "...")
		Remotes.Event("HookRequest"):FireServer()
	end
end

local function release()
	holding = false
end

local function isOurKey(input: InputObject): boolean
	return input.KeyCode == Cfg.KeyboardKey or input.KeyCode == Cfg.GamepadKey
end

local function bindInput()
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeInput = input
			press()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if isOurKey(input) and button.Visible then
			press()
		elseif phase == "reeling" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space) then
			tap() -- ekranın herhangi bir yerine tıklamak da sayılır
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeInput = nil
			release()
		elseif isOurKey(input) then
			release()
		end
	end)
end

-- Spot bulma ----------------------------------------------------------------

local function findNearestSpot(): BasePart?
	local folder = Workspace:FindFirstChild("FishingSpots")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not folder or not root then
		return nil
	end
	local best, bestDist = nil, Cfg.CastRange
	for _, p in folder:GetDescendants() do
		if p:IsA("BasePart") then
			local d = (p.Position - root.Position).Magnitude
			if d <= bestDist then
				best, bestDist = p, d
			end
		end
	end
	return best
end

-- Açık deniz: kameranın baktığı yönde, karakterin önündeki nokta su mu?
local function findOpenWater(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = Workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	local look = cam.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.01 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local base = Cfg.OpenWaterCastDistance
	for _, d in { base, base - 5, base + 5 } do
		local p = root.Position + dir * d
		if FishingWater.IsWater(p) then
			return Vector3.new(p.X, 0, p.Z)
		end
	end
	return nil
end

-- Reeling döngüsü -----------------------------------------------------------

local function stopReelSound()
	if reelSound then
		reelSound:Stop()
		reelSound:Destroy()
		reelSound = nil
	end
end

local function startReelSound()
	stopReelSound()
	local snd = Instance.new("Sound")
	snd.SoundId = Audio.Reel
	snd.Looped = true
	snd.Volume = 0.6
	snd.Parent = game:GetService("SoundService")
	snd:Play()
	reelSound = snd
end

-- Her tıklama göstergeyi yukarı iter
tap = function()
	vel += TAP_IMPULSE
	player:SetAttribute("ReelTaps", (player:GetAttribute("ReelTaps") or 0) + 1) -- test sayacı
	-- küçük zıplama
	needle.Size = UDim2.new(1, 30, 0, 12)
	TweenService:Create(needle, TweenInfo.new(0.12), { Size = UDim2.new(1, 22, 0, 8) }):Play()
end

ReelingController._debugTap = tap

local function updateReel(dt: number)
	-- balık çekiştirmesi
	pullTimer -= dt
	if pullTimer <= 0 then
		pull = (math.random() * 2 - 1) * FISH_PULL * barSpeed
		pullTimer = (0.5 + math.random() * 1.0) / math.max(barSpeed, 0.5)
	end
	vel += (pull - GRAVITY - CENTER * (pos - 0.5)) * dt
	vel *= math.exp(-DAMPING * dt)
	pos += vel * dt
	if pos < 0 then
		pos, vel = 0, 0
	elseif pos > 1 then
		pos, vel = 1, 0
	end

	local half = greenSize / 2
	local inGreen = pos >= 0.5 - half and pos <= 0.5 + half
	local inRed = pos <= RED_ZONE or pos >= 1 - RED_ZONE
	if inGreen then
		progress += Cfg.ProgressGain * dt
		redTime = math.max(0, redTime - dt * 2)
	elseif inRed then
		progress -= Cfg.ProgressLoss * 0.5 * dt
		redTime += dt
	else
		redTime = math.max(0, redTime - dt)
	end

	-- görüntü
	needle.Position = UDim2.fromScale(0.5, 1 - pos)
	needle.BackgroundColor3 = if inRed then Color3.fromRGB(255, 90, 80) elseif inGreen then Color3.new(1, 1, 1) else Color3.fromRGB(255, 235, 180)
	progFill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))
	dangerFill.Size = UDim2.fromScale(1, math.clamp(redTime / RED_LIMIT, 0, 1))
	tapHint.Text = if pos <= RED_ZONE then "FASTER! ⬆" elseif pos >= 1 - RED_ZONE then "SLOWER! ⬇" elseif inGreen then "Nice! 👍" else "TAP TAP!"
	tapHint.TextColor3 = if inRed then Color3.fromRGB(255, 110, 100) else Color3.new(1, 1, 1)
	if reelSound then
		reelSound.PlaybackSpeed = 0.85 + math.clamp(math.abs(vel), 0, 1.2) * 0.5
	end

	player:SetAttribute("ReelPos", math.floor(pos * 100) / 100) -- test
	if progress >= 1 then
		phase = "sent"
		stopReelSound()
		setState("Yakalanıyor...", "...")
		Remotes.Event("ReelResult"):FireServer(true)
	elseif redTime >= RED_LIMIT or progress <= 0 then
		phase = "sent"
		stopReelSound()
		Remotes.Event("ReelResult"):FireServer(false)
	end
end

-- Server olayları -----------------------------------------------------------

local function bindRemotes()
	Remotes.Event("FishBite").OnClientEvent:Connect(function()
		if phase ~= "waiting" then
			return
		end
		phase = "bite"
		setState("Vurdu!", "BAS!", COLOR_BITE)
		pulse()
	end)

	Remotes.Event("FishHooked").OnClientEvent:Connect(function(info)
		barSpeed = info.barSpeed
		targetSize = info.targetSize
		pos, vel, pull, pullTimer, redTime = 0.5, 0, 0, 0, 0
		-- yeşil alan nadirliğe göre: Common geniş, Legendary dar
		greenSize = math.clamp(0.16 + targetSize * 0.75, 0.2, 0.42)
		greenFrame.Size = UDim2.fromScale(1, greenSize)
		progress = Cfg.StartProgress
		fishDot.BackgroundColor3 = (Rarities :: any)[info.rarity].color
		bar.Visible = true
		phase = "reeling"
		startReelSound()
		setState("Hızlı tıkla!", "Tıkla")
	end)

	Remotes.Event("FishingEnded").OnClientEvent:Connect(function(reason)
		player:SetAttribute("LastFishEnd", tostring(reason))
		finish(MESSAGES[reason] or "Balık kaçtı")
	end)

	Remotes.Event("FishCaught").OnClientEvent:Connect(function(fishId, isNew)
		local def = Fish[fishId]
		finish((def and def.displayName or fishId) .. " yakalandı!")
		if isNew then
			showNewFish(fishId)
		else
			showPopup(fishId)
		end
	end)
end

function ReelingController.Init()
	buildUI()
	-- (sadece Studio) test: oyuncunun "DebugTap" özelliği değişince bir tıklama say
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("DebugTap"):Connect(function()
			if phase == "reeling" then
				tap()
			end
		end)
	end
	bindInput()
	bindRemotes()

	local scanTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		scanTimer -= dt
		if scanTimer <= 0 then
			scanTimer = 0.2
			nearSpot = findNearestSpot()
			openWaterPoint = if nearSpot then nil else findOpenWater()
			button.Visible = nearSpot ~= nil or openWaterPoint ~= nil or phase ~= "idle"
		end
		if phase == "reeling" then
			updateReel(dt)
		end

		-- Server cevap vermezse takılı kalma
		local waited = os.clock() - phaseSince
		if (phase == "waiting" and waited > Cfg.WaitMax + Cfg.BiteWindow + 3)
			or ((phase == "hooking" or phase == "sent") and waited > 4)
		then
			finish("Bağlantı sorunu, tekrar dene")
		end
	end)
end

return ReelingController
