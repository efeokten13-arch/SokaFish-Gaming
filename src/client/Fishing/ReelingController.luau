-- Balık tutma (client tarafı): buton, reeling bar, yakalama popup'ı.
-- UI tamamen koddan kurulur, Studio'da çizim gerekmez.
--
-- Kontroller:
--   Mobil: sağ alttaki büyük buton (zıplama butonunun üstünde)
--   PC:    F tuşu veya ekrandaki butona tıklama
--   Gamepad: X
--
-- Akış: "At" -> bekle -> "BAS!" -> basılı tut / bırak ile yeşil alanı balığın üstünde tut

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

local ReelingController = {}

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

-- UI referansları
local gui, button, status, bar, zone, fishDot, progFill, popup, viewport, popupLabel
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

	-- Reeling bar
	bar = Instance.new("Frame")
	bar.Name = "ReelBar"
	bar.Size = UDim2.fromOffset(46, 240)
	bar.AnchorPoint = Vector2.new(1, 0.5)
	bar.Position = UDim2.new(1, -160, 0.5, -40)
	bar.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
	bar.BackgroundTransparency = 0.25
	bar.Visible = false
	corner(bar, UDim.new(0, 8))
	stroke(bar, Color3.new(1, 1, 1), 2)
	bar.Parent = gui

	zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.BackgroundColor3 = COLOR_IN
	zone.BackgroundTransparency = 0.2
	zone.BorderSizePixel = 0
	corner(zone, UDim.new(0, 6))
	zone.Parent = bar

	fishDot = Instance.new("Frame")
	fishDot.Name = "Fish"
	fishDot.Size = UDim2.fromOffset(22, 22)
	fishDot.AnchorPoint = Vector2.new(0.5, 0.5)
	fishDot.ZIndex = 2
	corner(fishDot, UDim.new(0.5, 0))
	stroke(fishDot, Color3.new(0, 0, 0), 2)
	fishDot.Parent = bar

	local progBg = Instance.new("Frame")
	progBg.Name = "ProgressBg"
	progBg.Size = UDim2.new(0, 10, 1, 0)
	progBg.Position = UDim2.new(1, 8, 0, 0)
	progBg.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
	progBg.BackgroundTransparency = 0.25
	corner(progBg, UDim.new(0, 5))
	progBg.Parent = bar

	progFill = Instance.new("Frame")
	progFill.Name = "Fill"
	progFill.AnchorPoint = Vector2.new(0, 1)
	progFill.Position = UDim2.fromScale(0, 1)
	progFill.BackgroundColor3 = COLOR_IN
	progFill.BorderSizePixel = 0
	corner(progFill, UDim.new(0, 5))
	progFill.Parent = progBg

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

-- Input --------------------------------------------------------------------

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

local function updateReel(dt: number)
	zv += (if holding then Cfg.ZoneAccelUp else -Cfg.ZoneAccelDown) * dt
	zp += zv * dt
	local maxZ = 1 - targetSize
	if zp < 0 then
		zp, zv = 0, 0
	elseif zp > maxZ then
		zp, zv = maxZ, 0
	end

	fTimer -= dt
	if fTimer <= 0 then
		ft = math.random()
		fTimer = (0.5 + math.random() * 1.2) / barSpeed
	end
	fp += (ft - fp) * math.min(1, dt * barSpeed * 1.6)

	local inside = fp >= zp and fp <= zp + targetSize
	progress += (if inside then Cfg.ProgressGain else -Cfg.ProgressLoss) * dt

	zone.Size = UDim2.new(1, -8, targetSize, 0)
	zone.Position = UDim2.new(0, 4, 1 - zp - targetSize, 0)
	zone.BackgroundColor3 = if inside then COLOR_IN else COLOR_OUT
	fishDot.Position = UDim2.fromScale(0.5, 1 - math.clamp(fp, 0.04, 0.96))
	progFill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))

	if progress >= 1 then
		phase = "sent"
		setState("Yakalanıyor...", "...")
		Remotes.Event("ReelResult"):FireServer(true)
	elseif progress <= 0 then
		phase = "sent"
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
		zp, zv, fp, ft, fTimer = 0, 0, 0.5, 0.5, 0
		progress = Cfg.StartProgress
		fishDot.BackgroundColor3 = (Rarities :: any)[info.rarity].color
		bar.Visible = true
		phase = "reeling"
		setState("Basılı tut!", "Çek")
	end)

	Remotes.Event("FishingEnded").OnClientEvent:Connect(function(reason)
		finish(MESSAGES[reason] or "Balık kaçtı")
	end)

	Remotes.Event("FishCaught").OnClientEvent:Connect(function(fishId)
		local def = Fish[fishId]
		finish((def and def.displayName or fishId) .. " yakalandı!")
		showPopup(fishId)
	end)
end

function ReelingController.Init()
	buildUI()
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
