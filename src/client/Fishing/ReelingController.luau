-- Balık tutma (client tarafı): buton, reeling bar, yakalama popup'ı.
-- UI tamamen koddan kurulur, Studio'da çizim gerekmez.
--
-- Kontroller:
--   Mobil: sağ alttaki büyük buton (zıplama butonunun üstünde)
--   PC:    F tuşu veya ekrandaki butona tıklama
--   Gamepad: X
--
-- Akış: "At" -> bekle -> "BAS!" -> basılı tut / bırak (Config/Fishing.ReelControl = "hold"; "tap" = eski hızlı tıklama): gösterge yeşilde kalsın
-- His (juice): ilerledikçe makara sesi incelir, vuruşta kamera yakınlaşır, kırmızıda ekran ve çubuk titrer,
--   yeşilde parıltılar çıkar, şamandırada köpük, Epic/Legendary takılınca suda renkli parıltı + parlayan çerçeve.
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
local HOLD = Cfg.ReelControl ~= "tap"
local shakeAmt = 0
local sparkleTimer = 0
local barBasePos: UDim2? = nil
local barStroke: UIStroke? = nil
local omenLabel: TextLabel? = nil
local hookedRarity = "Common"
local hookedAt = 0 -- takılma anı (ilk anlarda düşüş yumuşak, oyuncu tepki verebilsin)
local fx = {} -- şamandıradaki köpük / nadirlik parıltısı (client'ta, sadece bu oyuncu görür)

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
	Instance.new("UIScale").Parent = button
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
	barStroke = bar:FindFirstChildOfClass("UIStroke")
	bar.Parent = gui
	barBasePos = bar.Position
	-- nadirlik habercisi: Epic / Legendary takılınca çubuğun üstünde
	omenLabel = Instance.new("TextLabel")
	omenLabel.AnchorPoint = Vector2.new(0.5, 1)
	omenLabel.Position = UDim2.new(0.5, 0, 0, -46)
	omenLabel.Size = UDim2.fromOffset(260, 30)
	omenLabel.BackgroundTransparency = 1
	omenLabel.Font = Enum.Font.Bangers
	omenLabel.TextSize = 30
	omenLabel.TextStrokeTransparency = 0.1
	omenLabel.Visible = false
	omenLabel.Parent = bar

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
	tapHint.Text = if HOLD then "HOLD!" else "TAP TAP!"
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

---------------------------------------------------------------------------------------------
-- His (juice) yardımcıları
---------------------------------------------------------------------------------------------
local function squash(scale)
	local sc = button:FindFirstChildOfClass("UIScale")
	if sc then
		TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = scale }):Play()
	end
end

local function myBobber(): BasePart?
	local folder = Workspace:FindFirstChild("FishingFX")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not root then
		return nil
	end
	local best, bd = nil, 60
	for _, b in folder:GetChildren() do
		if b.Name == "Bobber" and b:IsA("BasePart") then
			local d = (b.Position - root.Position).Magnitude
			if d < bd then
				best, bd = b, d
			end
		end
	end
	return best
end

local function clearFx()
	for _, x in fx do
		if x and x.Parent then
			x:Destroy()
		end
	end
	fx = {}
end

-- şamandıranın etrafında köpük + (Epic/Legendary) renkli parıltı
local function bobberFx(rarity: string)
	clearFx()
	local b = myBobber()
	if not b then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "ReelFx"
	att.Position = Vector3.new(0, -0.3, 0)
	att.Parent = b
	table.insert(fx, att)
	local foam = Instance.new("ParticleEmitter")
	foam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	foam.Color = ColorSequence.new(Color3.fromRGB(245, 252, 255))
	foam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) })
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) })
	foam.Lifetime = NumberRange.new(0.8, 1.4)
	foam.Rate = 60
	foam.Speed = NumberRange.new(3, 6)
	foam.SpreadAngle = Vector2.new(80, 80)
	foam.Acceleration = Vector3.new(0, -8, 0)
	foam.RotSpeed = NumberRange.new(-60, 60)
	foam.Parent = att
	table.insert(fx, foam)
	-- su yüzeyinde yayılan beyaz halka köpük
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxasset://textures/particles/smoke_main.dds"
	ring.Color = ColorSequence.new(Color3.new(1, 1, 1))
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Speed = NumberRange.new(0.01)
	ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) })
	ring.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	ring.Lifetime = NumberRange.new(1, 1.4)
	ring.Rate = 6
	ring.Parent = att
	table.insert(fx, ring)
	-- sıçrayan damlacıklar
	local drops = Instance.new("ParticleEmitter")
	drops.Color = ColorSequence.new(Color3.fromRGB(210, 235, 255))
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	drops.Lifetime = NumberRange.new(0.4, 0.7)
	drops.Rate = 35
	drops.Speed = NumberRange.new(6, 10)
	drops.SpreadAngle = Vector2.new(40, 40)
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Acceleration = Vector3.new(0, -35, 0)
	drops.Parent = att
	table.insert(fx, drops)
	local rar = (Rarities :: any)[rarity]
	if rar and (rarity == "Epic" or rarity == "Legendary") then
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glow.Color = ColorSequence.new(rar.color)
		glow.LightEmission = 1
		glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		glow.Lifetime = NumberRange.new(0.8, 1.6)
		glow.Rate = rarity == "Legendary" and 40 or 22
		glow.Speed = NumberRange.new(3, 7)
		glow.SpreadAngle = Vector2.new(50, 50)
		glow.Parent = att
		table.insert(fx, glow)
		local light = Instance.new("PointLight")
		light.Color = rar.color
		light.Range = 18
		light.Brightness = 3
		light.Parent = b
		table.insert(fx, light)
	end
end

-- yeşildeyken iğnenin yanından yeşil yıldızcıklar uçar
local function sparkle()
	local s = Instance.new("Frame")
	local sz = math.random(7, 12)
	s.Size = UDim2.fromOffset(sz, sz)
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.BackgroundColor3 = if math.random() < 0.3 then Color3.new(1, 1, 0.8) else Color3.fromRGB(120, 255, 130)
	s.BorderSizePixel = 0
	s.Rotation = 45
	s.ZIndex = 6
	local side = math.random() < 0.5 and -1 or 1
	s.Position = UDim2.new(0.5 + side * 0.6, 0, needle.Position.Y.Scale, 0)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(30, 120, 40)
	st.Thickness = 1
	st.Parent = s
	s.Parent = bar
	local tw = TweenService:Create(s, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5 + side * (0.95 + math.random() * 0.6), 0, needle.Position.Y.Scale - 0.04 - math.random() * 0.07, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(2, 2),
		Rotation = 45 + math.random(-120, 120),
	})
	tw:Play()
	task.delay(0.6, function()
		s:Destroy()
	end)
end

local function restoreCamera()
	player:SetAttribute("ReelZoom", nil)
	shakeAmt = 0
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
	clearFx()
	restoreCamera()
	squash(1)
	if omenLabel then
		omenLabel.Visible = false
	end
	if barBasePos then
		bar.Position = barBasePos
	end
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
	-- modeli kutusunun ortasına al (denizanası, denizatı gibi dik şekiller de kadraja sığsın)
	local bcf, bsize = model:GetBoundingBox()
	model:TranslateBy(-bcf.Position)
	local basePivot = model:GetPivot()

	local L = math.max(bsize.X, bsize.Y, bsize.Z)
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
		model:PivotTo(CFrame.Angles(0, t * 1.2, 0) * basePivot)
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
	local bigL, bigBase
	local model = FishModelBuilder.Build(fishId)
	if model then
		model.Parent = vp
		local cf, bsize = model:GetBoundingBox()
		model:TranslateBy(-cf.Position)
		bigL = math.max(bsize.X, bsize.Y, bsize.Z)
		bigBase = model:GetPivot()
	end
	local L = bigL or def.look.length
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
			model:PivotTo(CFrame.Angles(0, t * 1.6, math.sin(t * 2) * 0.12) * bigBase)
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
local chooseCastTarget: () -> any
local faceTowards: (Vector3) -> ()

local function press()
	holding = true
	if phase == "idle" then
		local target: any = chooseCastTarget()
		if not target then
			return
		end
		faceTowards(if typeof(target) == "Vector3" then target else target.Position)
		phase = "waiting"
		setState("Bekleniyor...", "Bekle")
		Remotes.Event("CastRequest"):FireServer(target)
	elseif phase == "waiting" then
		-- erken bastı: server "early" diyecek
		Remotes.Event("HookRequest"):FireServer()
	elseif phase == "reeling" then
		if HOLD then
			squash(0.88)
		else
			tap()
		end
	elseif phase == "bite" then
		phase = "hooking"
		setState("Takılıyor...", "...")
		Remotes.Event("HookRequest"):FireServer()
	end
end

local function release()
	holding = false
	if phase == "reeling" then
		local sc = button:FindFirstChildOfClass("UIScale")
		if sc then
			sc.Scale = 1.08
			TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
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
			-- ekranın herhangi bir yerine basmak da sayılır
			if HOLD then
				activeInput = input
				holding = true
				squash(0.88)
			else
				tap()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeInput = nil
			release()
		elseif isOurKey(input) or input.KeyCode == Enum.KeyCode.Space then
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
	for _, d in { base, base - 4, base + 4, base - 8, base + 8, base + 12 } do
		local p = root.Position + dir * d
		if FishingWater.IsWater(p) then
			return Vector3.new(p.X, 0, p.Z)
		end
	end
	return nil
end

-- Kameranın baktığı yatay yön
local function lookDir(): Vector3?
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cam or not root then
		return nil
	end
	local l = cam.CFrame.LookVector
	local d = Vector3.new(l.X, 0, l.Z)
	if d.Magnitude < 0.01 then
		d = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	return d.Unit
end

-- Olta nereye: baktığın yöndeki işaretli spot (±35°) > baktığın yöndeki açık su > (yoksa) yakındaki spot
chooseCastTarget = function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local dir = lookDir()
	if not root or not dir then
		return nearSpot or openWaterPoint
	end
	local folder = Workspace:FindFirstChild("FishingSpots")
	if folder then
		local best, bestScore = nil, -math.huge
		for _, p in folder:GetDescendants() do
			if p:IsA("BasePart") then
				local off = Vector3.new(p.Position.X - root.Position.X, 0, p.Position.Z - root.Position.Z)
				local dist = off.Magnitude
				if dist <= Cfg.CastRange and dist > 1 then
					local dot = off.Unit:Dot(dir)
					if dot >= 0.82 and dot - dist * 0.004 > bestScore then
						best, bestScore = p, dot - dist * 0.004
					end
				end
			end
		end
		if best then
			return best
		end
	end
	return findOpenWater() or nearSpot
end

-- karakter oltayı atarken o yöne döner (teknede oturuyorsa dönmez)
faceTowards = function(point: Vector3)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.SeatPart then
		return
	end
	local d = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	if d.Magnitude < 0.5 then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + d)
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
	if HOLD then
		-- basılı tut: yükselir, bırak: düşer (balık da çekiştirir)
		local grace = math.clamp((os.clock() - hookedAt) / 1.2, 0.1, 1)
		local acc = if holding then Cfg.ZoneAccelUp else -Cfg.ZoneAccelDown * grace
		vel += (acc + pull * grace) * dt
	else
		vel += (pull - GRAVITY - CENTER * (pos - 0.5)) * dt
	end
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
	if HOLD then
		tapHint.Text = if pos <= RED_ZONE then "HOLD! ⬆" elseif pos >= 1 - RED_ZONE then "LET GO! ⬇" elseif inGreen then "Nice! 👍" else (if holding then "Easy..." else "HOLD!")
	else
		tapHint.Text = if pos <= RED_ZONE then "FASTER! ⬆" elseif pos >= 1 - RED_ZONE then "SLOWER! ⬇" elseif inGreen then "Nice! 👍" else "TAP TAP!"
	end
	tapHint.TextColor3 = if inRed then Color3.fromRGB(255, 110, 100) else Color3.new(1, 1, 1)
	-- makara sesi: ilerledikçe incelir ("az kaldı!"), hızlı hareket ekstra tiz
	if reelSound then
		reelSound.PlaybackSpeed = 0.78 + math.clamp(progress, 0, 1) * 0.55 + math.clamp(math.abs(vel), 0, 1.2) * 0.15
		reelSound.Volume = 0.45 + math.clamp(progress, 0, 1) * 0.35
	end
	-- kırmızıda: çubuk sallanır + kamera hafif titrer
	if inRed then
		shakeAmt = math.min(shakeAmt + dt * 2, 0.22)
		if barBasePos then
			bar.Position = barBasePos + UDim2.fromOffset(math.random(-4, 4), math.random(-3, 3))
		end
	else
		shakeAmt = math.max(shakeAmt - dt * 1.5, 0)
		if barBasePos then
			bar.Position = barBasePos
		end
	end
	-- yeşilde: parıltılar
	if inGreen then
		sparkleTimer -= dt
		if sparkleTimer <= 0 then
			sparkleTimer = 0.09
			sparkle()
		end
	end
	-- nadir balıkta çerçeve nabız gibi parlar
	if barStroke and (hookedRarity == "Epic" or hookedRarity == "Legendary") then
		local rc = (Rarities :: any)[hookedRarity].color
		local k = 0.5 + 0.5 * math.sin(os.clock() * 7)
		barStroke.Color = Color3.new(1, 1, 1):Lerp(rc, k)
		barStroke.Thickness = 3 + k * 3
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
		shakeAmt = 0.3
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
		hookedRarity = info.rarity
		hookedAt = os.clock()
		if barStroke then
			barStroke.Color = Color3.new(1, 1, 1)
			barStroke.Thickness = 3
		end
		startReelSound()
		setState(if HOLD then "" else "Hızlı tıkla!", if HOLD then "Tut" else "Tıkla") -- (hold) ipucu çubuğun üstünde
		-- kamera biraz yakınlaşır (balıkla boğuşma)
		player:SetAttribute("ReelZoom", true) -- FOV'u MovementController yumuşakça düşürür
		bobberFx(info.rarity)
		-- Epic / Legendary habercisi
		if omenLabel then
			if info.rarity == "Legendary" or info.rarity == "Epic" then
				local rc = (Rarities :: any)[info.rarity].color
				omenLabel.Text = if info.rarity == "Legendary" then "✨ SOMETHING LEGENDARY! ✨" else "⚡ Something EPIC! ⚡"
				omenLabel.TextColor3 = rc
				omenLabel.Visible = true
				omenLabel.TextSize = 12
				TweenService:Create(omenLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back), { TextSize = 30 }):Play()
				if info.rarity == "Legendary" then
					local th = Instance.new("Sound")
					th.SoundId = Audio.Thunder[1]
					th.Volume = 0.35
					th.Parent = game:GetService("SoundService")
					th:Play()
					game:GetService("Debris"):AddItem(th, 8)
				end
			else
				omenLabel.Visible = false
			end
		end
	end)

	Remotes.Event("FishingEnded").OnClientEvent:Connect(function(reason)
		player:SetAttribute("LastFishEnd", tostring(reason))
		finish(MESSAGES[reason] or "Balık kaçtı")
	end)

	Remotes.Event("FishCaught").OnClientEvent:Connect(function(fishId, isNew)
		local def = Fish[fishId]
		finish((def and def.displayName or fishId) .. " yakalandı!")
		-- nadirliğe göre zafer sesi (yeni türlerde zaten fanfar çalıyor)
		if def and not isNew and (def.rarity == "Epic" or def.rarity == "Legendary") then
			local v = Instance.new("Sound")
			v.SoundId = if def.rarity == "Legendary" then Audio.VictorySting else Audio.NewFish
			v.Volume = 0.6
			v.Parent = game:GetService("SoundService")
			v:Play()
			task.delay(if def.rarity == "Legendary" then 5 else 4, function()
				TweenService:Create(v, TweenInfo.new(1), { Volume = 0 }):Play()
				game:GetService("Debris"):AddItem(v, 1.2)
			end)
		end
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
		player:GetAttributeChangedSignal("DebugHold"):Connect(function()
			holding = player:GetAttribute("DebugHold") == true
		end)
	end
	bindInput()
	bindRemotes()
	-- kamera titremesi (kamera güncellemesinden sonra küçük kaydırma)
	RunService:BindToRenderStep("ReelShake", Enum.RenderPriority.Camera.Value + 2, function()
		if shakeAmt > 0.005 and not player:GetAttribute("InCutscene") then
			local cam = Workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * shakeAmt, (math.random() - 0.5) * shakeAmt, 0)
			if phase ~= "reeling" then
				shakeAmt *= 0.85
			end
		end
	end)

	local scanTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		scanTimer -= dt
		if scanTimer <= 0 then
			scanTimer = 0.2
			nearSpot = findNearestSpot()
			openWaterPoint = findOpenWater()
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
