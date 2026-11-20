--!nonstrict
-- Gemi topları (client): kendi gemindeki bir topun yanına gelince "Aim" ve "Fire" butonları çıkar.
-- Nişan modu (Sea of Thieves tarzı): kamera topun arkasına geçer, namlunun üstünden denize bakılır.
--   Top fareyle / parmakla kaydırarak / A-D tuşlarıyla döner (en fazla ±25°), gülle yolu sarı noktalarla görünür.
--   Nişandayken karakter yürümez ve kendi ekranında gizlenir (görüşü kapatmasın).
-- Ateş etme şimdilik kapalı (gemi savaşı sistemiyle eklenecek).
-- Kısayollar: R = nişan aç/kapa, F = ateş.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cannons"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local UIController = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIController"))

local CannonController = {}

local player = Players.LocalPlayer
local NEAR = 7 -- topa bu kadar yaklaşınca butonlar çıkar
local cannon, hull -- yanındaki top (namlu) ve geminin gövdesi
local aiming = false
local gui, aimBtn, fireBtn
local dots = {}
local DOTS = 18

-- nişan kamerası
local ENTER_TIME = 0.4 -- kameranın topun arkasına geçiş süresi
local EXIT_TIME = 0.3
local AIM_FOV = 58
local MOUSE_SENS = 0.0045 -- rad / piksel
local TOUCH_SENS = 0.007
local KEY_SPEED = 1.1 -- rad / sn (A-D)
local yaw = 0 -- topun şu anki açısı
local camT = 0 -- 0..1 giriş animasyonu
local exitTween: { from: CFrame, t: number, fov: number }? = nil
local savedFov = 70
local hint
local keyLeft, keyRight = false, false

-- Nişandayken karakter yürümesin/zıplamasın (A-D topu çevirir).
-- Varsayılan PlayerModule varsa onun kontrolleri kapatılır; yoksa hız geçici olarak sıfırlanır.
local frozen: { hum: Humanoid, walk: number, jump: number, jumpH: number }? = nil
local function freezeCharacter(on)
	local ps = player:FindFirstChild("PlayerScripts")
	local pmScript = ps and ps:FindFirstChild("PlayerModule")
	if pmScript then
		local ok, pm = pcall(require, pmScript)
		local ctl = ok and pm and pm.GetControls and pm:GetControls()
		if ctl then
			if on then
				ctl:Disable()
			else
				ctl:Enable()
			end
		end
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on and hum then
		frozen = { hum = hum, walk = hum.WalkSpeed, jump = hum.JumpPower, jumpH = hum.JumpHeight }
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	elseif not on and frozen then
		if frozen.hum.Parent then
			frozen.hum.WalkSpeed = frozen.walk
			frozen.hum.JumpPower = frozen.jump
			frozen.hum.JumpHeight = frozen.jumpH
		end
		frozen = nil
	end
end

local function setCharacterHidden(hidden)
	local char = player.Character
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- Kendi gemindeki en yakın top
local function nearestCannon()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local boats = Workspace:FindFirstChild("Boats")
	if not root or not boats then
		return nil
	end
	local best, bestD, bestHull = nil, NEAR, nil
	for _, boat in boats:GetChildren() do
		if boat:GetAttribute("HasCannons") and boat:GetAttribute("OwnerUserId") == player.UserId then
			local folder = boat:FindFirstChild("Cannons")
			for _, b in folder and folder:GetChildren() or {} do
				if b:IsA("BasePart") and b:FindFirstChild("Hinge") then
					local d = (b.Position - root.Position).Magnitude
					if d < bestD then
						best, bestD, bestHull = b, d, boat.PrimaryPart
					end
				end
			end
		end
	end
	return best, bestHull
end

local function setYaw(barrel, yaw)
	local w = barrel and barrel:FindFirstChild("Hinge")
	local base = w and w:GetAttribute("BaseC0")
	if base then
		w.C0 = base * CFrame.Angles(0, yaw, 0)
	end
end

-- Namlunun dünyadaki CFrame'i (yerel +X = namlu ağzı yönü)
local function barrelCF(barrel)
	local w = barrel.Hinge
	return hull.CFrame * w.C0 * w.C1:Inverse()
end

-- Nişan kamerası: namlunun üstünde; namlu ağzı ekranın alt ortasında görünür
local function aimCameraCF(barrel)
	local cf = barrelCF(barrel)
	-- göz namlunun dış yarısının üstünde: gövde içindeki direk/yelken görüşü kapatmasın
	local eye = (cf * CFrame.new(0.5, 1.5, 0)).Position
	local target = (cf * CFrame.new(60, 0.3, 0)).Position
	-- hafif dalga sallantısı
	local t = os.clock()
	eye += Vector3.new(0, math.sin(t * 1.3) * 0.08, 0)
	return CFrame.lookAt(eye, target, Vector3.yAxis)
end

local function hideDots()
	for _, d in dots do
		d.Transparency = 1
	end
end

local function showPath(barrel)
	local w = barrel.Hinge
	local cf = hull.CFrame * w.C0 * w.C1:Inverse()
	local pos = (cf * CFrame.new(barrel.Size.X / 2 + 0.8, 0, 0)).Position
	local vel = cf.RightVector * Cfg.Speed + Vector3.new(0, Cfg.Arc, 0) + hull.AssemblyLinearVelocity
	for i = 1, DOTS do
		local t = i * 0.12
		local p = pos + vel * t - Vector3.new(0, 0.5 * Cfg.Gravity * t * t, 0)
		local d = dots[i]
		if p.Y < 0 then
			d.Transparency = 1
		else
			d.Position = p
			d.Transparency = 0.15
		end
	end
end

local function setAiming(on)
	if on == aiming then
		return
	end
	aiming = on
	player:SetAttribute("CannonAiming", on)
	if aimBtn then
		Theme.SetActive(aimBtn, on)
	end
	local cam = Workspace.CurrentCamera
	if on then
		yaw = 0
		camT = 0
		exitTween = nil
		savedFov = cam.FieldOfView
		cam.CameraType = Enum.CameraType.Scriptable
		freezeCharacter(true)
		setCharacterHidden(true)
		if hint then
			hint.Visible = true
		end
	else
		hideDots()
		if cannon then
			setYaw(cannon, 0)
		end
		freezeCharacter(false)
		setCharacterHidden(false)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if hint then
			hint.Visible = false
		end
		-- kamerayı yumuşakça karaktere geri döndür
		exitTween = { from = cam.CFrame, t = 0, fov = cam.FieldOfView }
	end
end

local function fire()
	if not cannon then
		return
	end
	-- Ateş şimdilik kapalı: gemi savaşı sistemiyle birlikte açılacak
	UIController.Notify("Cannons can't fire yet. Coming soon!", Color3.fromRGB(255, 214, 80))
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CannonGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local step = Theme.ButtonSize + Theme.Gap
	aimBtn = Theme.Button(gui, "AimButton", "🎯", "Aim (R)", UDim2.new(1, -18, 1, -24 - step * 2), Vector2.new(1, 1))
	fireBtn = Theme.Button(gui, "FireButton", "💥", "Fire (F)", UDim2.new(1, -18, 1, -24 - step * 3), Vector2.new(1, 1))
	aimBtn.Activated:Connect(function()
		setAiming(not aiming)
	end)
	fireBtn.Activated:Connect(fire)
	hint = Instance.new("TextLabel")
	hint.Name = "AimHint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0, 96) -- üstte, para göstergesinin altında (namluyu kapatmasın)
	hint.Size = UDim2.fromOffset(420, 30)
	hint.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	hint.BackgroundTransparency = 0.35
	hint.Font = Enum.Font.FredokaOne
	hint.TextSize = 18
	hint.TextColor3 = Color3.fromRGB(255, 244, 214)
	hint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "Drag to aim  ·  🎯 to stop"
		else "Move mouse / A-D to aim  ·  R to stop"
	hint.Visible = false
	hint.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = hint
	local folder = Instance.new("Folder")
	folder.Name = "CannonAimDots"
	folder.Parent = Workspace.CurrentCamera
	for i = 1, DOTS do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.new(0.7, 0.7, 0.7)
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Material = Enum.Material.Neon
		d.Color = Color3.fromRGB(255, 196, 64)
		d.Transparency = 1
		d.Parent = folder
		dots[i] = d
	end
end

function CannonController.Init()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			keyLeft = true
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			keyRight = true
		end
		if processed or not cannon then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			setAiming(not aiming)
		elseif input.KeyCode == Enum.KeyCode.F then
			fire()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			keyLeft = false
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			keyRight = false
		end
	end)
	-- fare / parmak ile çevirme
	UserInputService.InputChanged:Connect(function(input, processed)
		if not aiming then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * MOUSE_SENS
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			yaw -= input.Delta.X * TOUCH_SENS
		end
	end)
	local acc = 0
	RunService:BindToRenderStep("CannonAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- en yakın topu 5 kez/saniye ara
		acc += dt
		if acc >= 0.2 then
			acc = 0
			local c, h = nearestCannon()
			if c ~= cannon then
				if aiming then
					setAiming(false)
				end
				cannon, hull = c, h
				gui.Enabled = c ~= nil
			end
		end
		local cam = Workspace.CurrentCamera
		if aiming and cannon and hull and cannon.Parent then
			local maxYaw = math.rad(Cfg.MaxYawDeg)
			if keyLeft then
				yaw += KEY_SPEED * dt
			end
			if keyRight then
				yaw -= KEY_SPEED * dt
			end
			yaw = math.clamp(yaw, -maxYaw, maxYaw)
			setYaw(cannon, yaw)
			showPath(cannon)
			-- kamera: önce yumuşak geçiş, sonra namluyu takip
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			cam.CameraType = Enum.CameraType.Scriptable
			local target = aimCameraCF(cannon)
			if camT < 1 then
				camT = math.min(1, camT + dt / ENTER_TIME)
				local a = 1 - (1 - camT) ^ 3 -- yavaşlayarak otur
				cam.CFrame = cam.CFrame:Lerp(target, a)
				cam.FieldOfView = savedFov + (AIM_FOV - savedFov) * a
			else
				cam.CFrame = target
				cam.FieldOfView = AIM_FOV
			end
		elseif exitTween then
			-- çıkış: kamerayı karakterin arkasına geri kaydır, sonra normal kameraya bırak
			exitTween.t = math.min(1, exitTween.t + dt / EXIT_TIME)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local a = 1 - (1 - exitTween.t) ^ 3
			if root then
				local back = CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
				cam.CFrame = exitTween.from:Lerp(back, a)
			end
			cam.FieldOfView = exitTween.fov + (savedFov - exitTween.fov) * a
			if exitTween.t >= 1 then
				exitTween = nil
				cam.FieldOfView = savedFov
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end)
	-- ölünce / karakter değişince nişan kapansın
	player.CharacterAdded:Connect(function()
		if aiming then
			setAiming(false)
		end
	end)
end

return CannonController
