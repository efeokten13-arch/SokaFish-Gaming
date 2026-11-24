--!nonstrict
-- Gemi topları (client): kendi gemindeki bir topun yanına gelince "Aim" ve "Fire" butonları çıkar.
-- Nişan modu (Sea of Thieves tarzı): kamera namlunun hemen arkasına geçer, namlu ekranın altında, namlu boyunca bakılır.
--   Sağa-sola: fare / parmak / A-D (en fazla ±25°). Yukarı-aşağı: fare / parmak / W-S (Config/Cannons Min/MaxPitch).
--   Gülle yolu sarı noktalarla, düşeceği yer halka ile görünür. Sağ ortada gülle envanteri (1-2-3 ile seç).
--   Nişandayken karakter yürümez ve kendi ekranında gizlenir (görüşü kapatmasın).
-- Ateş: server (CannonService) topun gerçekten bu oyuncunun gemisinde ve yanında olduğunu kontrol eder.
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
local DOTS = 30
local landRing -- düşüş noktası halkası
local ammoPanel, ammoRows, reloadBar = nil, {}, nil
local ammoId = Cfg.Ammo[1].id
local lastFire = 0
local shake = 0
local fishingGui -- nişandayken "At" (olta) butonu gizlenir

-- nişan kamerası
local ENTER_TIME = 0.4 -- kameranın topun arkasına geçiş süresi
local EXIT_TIME = 0.3
local AIM_FOV = 66
local MOUSE_SENS = 0.0045 -- rad / piksel
local TOUCH_SENS = 0.007
local KEY_SPEED = 1.1 -- rad / sn (A-D)
local PITCH_KEY_SPEED = 0.45 -- rad / sn (W-S)
local yaw = 0 -- topun şu anki açısı
local pitch = 0 -- namlunun yukarı açısı (radyan)
local camT = 0 -- 0..1 giriş animasyonu
local exitTween: { from: CFrame, t: number, fov: number }? = nil
local savedFov = 70
local hint
local keyLeft, keyRight, keyUp, keyDown = false, false, false, false

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

local function setAim(barrel, yaw, pitch)
	local w = barrel and barrel:FindFirstChild("Hinge")
	local base = w and w:GetAttribute("BaseC0")
	if base then
		w.C0 = base * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, pitch or 0)
	end
end

-- Namlunun dünyadaki CFrame'i (yerel +X = namlu ağzı yönü)
local function barrelCF(barrel)
	local w = barrel.Hinge
	return hull.CFrame * w.C0 * w.C1:Inverse()
end

-- Nişan kamerası (Ege'nin Sea of Thieves resmi, 24 Kas): kamera namlunun hemen ARKASINDA ve biraz üstünde, namluyla
-- birlikte sağa-sola VE yukarı-aşağı döner; kalın namlu ekranın alt ortasını doldurur, ağzı hedefe bakar.
local EYE_BACK = 1.7 -- namlunun arka ucundan geriye
local EYE_UP = 1.05 -- namlu ekseninin üstüne
local function aimCameraCF(barrel)
	local cf = barrelCF(barrel)
	local half = barrel.Size.X / 2
	local eye = (cf * CFrame.new(-half - EYE_BACK, EYE_UP, 0)).Position
	local target = (cf * CFrame.new(60, EYE_UP - 1.4, 0)).Position
	-- hafif dalga sallantısı
	local t = os.clock()
	eye += Vector3.new(0, math.sin(t * 1.3) * 0.06, 0)
	if shake > 0.01 then
		eye += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
	end
	return CFrame.lookAt(eye, target, Vector3.yAxis)
end

local function hideDots()
	for _, d in dots do
		d.Transparency = 1
	end
	if landRing then
		landRing.Transparency = 1
	end
end

local pathParams = RaycastParams.new()
pathParams.FilterType = Enum.RaycastFilterType.Exclude
pathParams.IgnoreWater = true
local function showPath(barrel)
	local w = barrel.Hinge
	local cf = hull.CFrame * w.C0 * w.C1:Inverse()
	local pos = (cf * CFrame.new(barrel.Size.X / 2 + 0.8, 0, 0)).Position
	local vel = cf.RightVector * Cfg.Speed + Vector3.new(0, Cfg.Arc, 0) + hull.AssemblyLinearVelocity
	pathParams.FilterDescendantsInstances = { hull.Parent, player.Character, Workspace.CurrentCamera }
	local landed, prev = nil, pos
	for i = 1, DOTS do
		local t = i * 0.12
		local p = pos + vel * t - Vector3.new(0, 0.5 * Cfg.Gravity * t * t, 0)
		local d = dots[i]
		if not landed then
			local hit = Workspace:Raycast(prev, p - prev, pathParams)
			if hit then
				landed = hit.Position
			elseif p.Y <= 0 then
				local k = prev.Y / math.max(prev.Y - p.Y, 0.001)
				landed = prev:Lerp(p, k)
			end
		end
		if landed then
			d.Transparency = 1
		else
			d.Position = p
			d.Transparency = 0.15
		end
		prev = p
	end
	if landRing then
		if landed then
			landRing.CFrame = CFrame.new(landed + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			landRing.Transparency = 0.25
		else
			landRing.Transparency = 1
		end
	end
end

-- Gülle envanteri (sağ orta) ------------------------------------------------------------------------------
local function refreshAmmo()
	for _, r in ammoRows do
		local sel = r.id == ammoId
		r.stroke.Color = sel and Color3.fromRGB(255, 205, 80) or Color3.fromRGB(80, 84, 100)
		r.stroke.Thickness = sel and 3 or 1.5
		r.frame.BackgroundTransparency = sel and 0.05 or 0.3
	end
end

local function selectAmmo(i)
	local a = Cfg.Ammo[i]
	if not a then
		return
	end
	if a.locked then
		UIController.Notify(a.name .. " is coming soon!", Color3.fromRGB(255, 214, 80))
		return
	end
	ammoId = a.id
	refreshAmmo()
end

local function buildAmmo(parent)
	ammoPanel = Instance.new("Frame")
	ammoPanel.Name = "AmmoPanel"
	ammoPanel.AnchorPoint = Vector2.new(1, 0.5)
	ammoPanel.Position = UDim2.new(1, -18, 0.42, 0)
	ammoPanel.Size = UDim2.fromOffset(168, 40 + #Cfg.Ammo * 52 + 20)
	ammoPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	ammoPanel.BackgroundTransparency = 0.25
	ammoPanel.Visible = false
	ammoPanel.Parent = parent
	Instance.new("UICorner", ammoPanel).CornerRadius = UDim.new(0, 12)
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromOffset(12, 6)
	head.Size = UDim2.new(1, -24, 0, 26)
	head.Font = Enum.Font.FredokaOne
	head.TextSize = 18
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextColor3 = Color3.fromRGB(255, 205, 80)
	head.Text = "AMMO"
	head.Parent = ammoPanel
	for i, a in Cfg.Ammo do
		local row = Instance.new("TextButton")
		row.AutoButtonColor = true
		row.Text = ""
		row.Position = UDim2.fromOffset(8, 36 + (i - 1) * 52)
		row.Size = UDim2.new(1, -16, 0, 46)
		row.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
		row.Parent = ammoPanel
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = row
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromOffset(6, 4)
		icon.Size = UDim2.fromOffset(36, 38)
		icon.TextScaled = true
		icon.Text = a.icon
		icon.TextTransparency = a.locked and 0.55 or 0
		icon.Parent = row
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(46, 4)
		name.Size = UDim2.new(1, -52, 0, 20)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 13
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = a.locked and Color3.fromRGB(140, 140, 150) or Color3.new(1, 1, 1)
		name.Text = i .. "  " .. a.name
		name.Parent = row
		local note = Instance.new("TextLabel")
		note.BackgroundTransparency = 1
		note.Position = UDim2.fromOffset(46, 24)
		note.Size = UDim2.new(1, -52, 0, 18)
		note.Font = Enum.Font.GothamMedium
		note.TextSize = 13
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.TextColor3 = a.locked and Color3.fromRGB(150, 150, 160) or Color3.fromRGB(255, 205, 80)
		note.Text = a.locked and ("🔒 " .. a.note) or a.note
		note.Parent = row
		row.Activated:Connect(function()
			selectAmmo(i)
		end)
		table.insert(ammoRows, { id = a.id, frame = row, stroke = st })
	end
	-- dolum çubuğu
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 10, 1, -14)
	back.Size = UDim2.new(1, -20, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(50, 54, 66)
	back.BorderSizePixel = 0
	back.Parent = ammoPanel
	Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
	reloadBar = Instance.new("Frame")
	reloadBar.Size = UDim2.fromScale(1, 1)
	reloadBar.BackgroundColor3 = Color3.fromRGB(255, 160, 60)
	reloadBar.BorderSizePixel = 0
	reloadBar.Parent = back
	Instance.new("UICorner", reloadBar).CornerRadius = UDim.new(1, 0)
	refreshAmmo()
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
	if ammoPanel then
		ammoPanel.Visible = on
	end
	fishingGui = fishingGui or player.PlayerGui:FindFirstChild("FishingGui")
	if fishingGui then
		fishingGui.Enabled = not on
	end
	if on then
		yaw = 0
		pitch = 0
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
			setAim(cannon, 0, 0)
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

local fireRemote
local function fire()
	if not cannon then
		return
	end
	if not aiming then
		-- nişansız ateş: önce nişan moduna geç (yanlışlıkla boşa atış olmasın)
		setAiming(true)
		return
	end
	if os.clock() - lastFire < Cfg.Cooldown then
		return
	end
	lastFire = os.clock()
	shake = 0.6
	fireRemote = fireRemote or ReplicatedStorage:FindFirstChild("CombatRemotes") and ReplicatedStorage.CombatRemotes:FindFirstChild("FireCannons")
	if fireRemote then
		fireRemote:FireServer(cannon, yaw, pitch, ammoId)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CannonGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local step = Theme.ButtonSize + Theme.Gap
	-- "At" (olta) butonunun ve Sprint/Dive sütununun solunda: üst üste binmesin
	aimBtn = Theme.Button(gui, "AimButton", "🎯", "Aim (R)", UDim2.new(1, -150, 1, -24), Vector2.new(1, 1))
	fireBtn = Theme.Button(gui, "FireButton", "💥", "Fire (F)", UDim2.new(1, -150, 1, -24 - step), Vector2.new(1, 1))
	buildAmmo(gui)
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
		then "Drag to aim  ·  💥 fire  ·  🎯 stop"
		else "Mouse / A-D / W-S to aim  ·  F fire  ·  R stop"
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
	landRing = Instance.new("Part")
	landRing.Name = "LandRing"
	landRing.Shape = Enum.PartType.Cylinder
	landRing.Size = Vector3.new(0.3, 7, 7)
	landRing.Anchored, landRing.CanCollide, landRing.CanQuery, landRing.CanTouch, landRing.CastShadow = true, false, false, false, false
	landRing.Material = Enum.Material.Neon
	landRing.Color = Color3.fromRGB(255, 90, 60)
	landRing.Transparency = 1
	landRing.Parent = folder
end

function CannonController.Init()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			keyLeft = true
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			keyRight = true
		elseif input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
			keyUp = true
		elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
			keyDown = true
		end
		if aiming and not processed then
			if input.KeyCode == Enum.KeyCode.One then
				selectAmmo(1)
			elseif input.KeyCode == Enum.KeyCode.Two then
				selectAmmo(2)
			elseif input.KeyCode == Enum.KeyCode.Three then
				selectAmmo(3)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				fire()
			end
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
		elseif input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
			keyUp = false
		elseif input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
			keyDown = false
		end
	end)
	-- fare / parmak ile çevirme
	UserInputService.InputChanged:Connect(function(input, processed)
		if not aiming then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * MOUSE_SENS
			pitch -= input.Delta.Y * MOUSE_SENS * 0.7
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			yaw -= input.Delta.X * TOUCH_SENS
			pitch -= input.Delta.Y * TOUCH_SENS * 0.7
		end
	end)
	local acc = 0
	RunService:BindToRenderStep("CannonAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- sinematik sahne sürerken (ör. eğitim finali) nişan modu kapalı kalır, kamerayı sahne yönetir
		if player:GetAttribute("InCutscene") then
			if aiming then
				setAiming(false)
				exitTween = nil
			end
			return
		end
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
			if keyUp then
				pitch += PITCH_KEY_SPEED * dt
			end
			if keyDown then
				pitch -= PITCH_KEY_SPEED * dt
			end
			pitch = math.clamp(pitch, math.rad(Cfg.MinPitchDeg), math.rad(Cfg.MaxPitchDeg))
			shake *= 0.86
			if reloadBar then
				reloadBar.Size = UDim2.fromScale(math.clamp((os.clock() - lastFire) / Cfg.Cooldown, 0, 1), 1)
			end
			setAim(cannon, yaw, pitch)
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
