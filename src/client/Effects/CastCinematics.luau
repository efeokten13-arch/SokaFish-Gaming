--!nonstrict
-- Kademeli atış sahneleri (sadece atan oyuncu görür). Server: FishingService -> Remotes "CastCinematic"
--   (tür, su noktası, fishId, kutsamalı mı). Hangi balıkta hangisi: Config/Fishing.Cinematics.
--   Common / Uncommon: sahne yok · Rare: kısa parlama (client/Fishing/ReelingController)
--   "epic"   (~3.8 sn): yem hızlıca dibe iner, mor parıltı, gelen Epic balık atılıp yemi kapar
--   "golden" (~6.2 sn): drone kamera ağır çekim, yem dibe iner, uzakta altın parıltı, Golden Fish bir anda yutar.
--            Tapınak kutsamalıysa tıklama yok: balık doğrudan çantaya girer
--   "shark"  (~8.6 sn): 1-2 sn hiçbir şey olmaz -> kamera uzaklaşır, uzakta gri gölge geçer -> sessizlik ->
--            köpekbalığı ağzını açarak hızla gelir ve yemi kapar
--   Sahne bitince balık vurur ("BAS!" + çekme). Ortak giriş: drone kamera yemi takip eder, yem suya girer,
--   kamera dalar (mavi renk, derin su uğultusu, kabarcıklar), yem dibe iner.
--   Ekrana dokunmak sahneyi geçer (server zamanlaması değişmez: balık yine zamanında vurur).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Audio = require(Config:WaitForChild("Audio"))
local Items = require(Config:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))

local CastCinematics = {}

-- zaman çizelgesi (sn). Her sahnenin toplamı server bekleme süresinden kısa olmalı
local T_SWING = 0.35 -- olta savrulurken bekle
local MAX_DEPTH = 40 -- dip çok derinse yem bu kadar inince durur
-- golden: uçuş 1.8 (ağır çekim) + parıltı 0.6 + atılış 0.55 + 0.55  ≈ 6.2 sn  (Wait.golden 6.6)
local GOLDEN = { flight = 1.8, sink = 2.3, wait = 0.6, dash = 0.55, after = 0.55 }
-- epic: uçuş 0.9 + dibe iniş 1.1 + parıltı 0.35 + atılış 0.45 + 0.4  ≈ 3.8 sn  (Wait.epic 4.2)
local EPIC = { flight = 0.9, sink = 1.1, wait = 0.35, dash = 0.45, after = 0.4 }
-- shark: uçuş 1.3 + sessizlik 1.6 + uzaklaşma/gölge 1.5 + gerilim 0.5 + hücum 0.55 + 0.5  ≈ 8.6 sn  (Wait.shark 9.2)
local SHARK = { flight = 1.3, sink = 2.3, quiet = 1.6, pull = 1.5, tension = 0.5, rush = 0.55, after = 0.5, fish = "ReefShark" }

local GOLD = Color3.fromRGB(255, 205, 60)
local busy = false

local function play(id, volume, pitch, looped)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.Looped = looped == true
	s.Parent = SoundService
	s:Play()
	if not looped then
		Debris:AddItem(s, 12)
	end
	return s
end

local function part(name, size, cf, color, material, shape, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = Workspace.CurrentCamera
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function lockCharacter(on)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if on then
		hum:SetAttribute("CastCineSpeed", hum.WalkSpeed)
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	else
		hum.WalkSpeed = hum:GetAttribute("CastCineSpeed") or 16
		hum.JumpHeight = 7.2
		hum:SetAttribute("CastCineSpeed", nil)
	end
end

-- sunucunun şamandırasını sahne boyunca gizle (kendi yemimiz görünsün)
local function hideBobbers(on)
	local folder = Workspace:FindFirstChild("FishingFX")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not folder or not root then
		return
	end
	for _, b in folder:GetChildren() do
		if b:IsA("BasePart") and (b.Position - root.Position).Magnitude < 80 then
			for _, d in b:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if on then 1 else 0
				end
			end
			b.LocalTransparencyModifier = if on then 1 else 0
		end
	end
end

local function rodTip(): Vector3?
	local char = player.Character
	if not char then
		return nil
	end
	for _, d in char:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "TipAttachment" then
			return d.WorldPosition
		end
	end
	local head = char:FindFirstChild("Head")
	return head and head.Position + Vector3.new(0, 2, 0)
end

local function waterSurface(pos: Vector3): number
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { Workspace.Terrain }
	p.IgnoreWater = false
	local r = Workspace:Raycast(Vector3.new(pos.X, 60, pos.Z), Vector3.new(0, -120, 0), p)
	if r and r.Material == Enum.Material.Water then
		return r.Position.Y
	end
	return 0
end

local function seabed(pos: Vector3, surface: number): number
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { Workspace.Terrain }
	p.IgnoreWater = true
	local r = Workspace:Raycast(Vector3.new(pos.X, surface - 0.5, pos.Z), Vector3.new(0, -MAX_DEPTH - 2, 0), p)
	if r then
		return math.min(r.Position.Y + 0.5, surface - 6)
	end
	return surface - MAX_DEPTH
end

local function noCollide(model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
end

-- Bekle; oyuncu ekrana dokunup sahneyi geçerse true döner
local function step(S, t)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		if S.skip then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return S.skip == true
end

---------------------------------------------------------------------------------------------
-- Ortak giriş: kurulum, uçuş, suya giriş, dibe iniş. Sahne durumunu (S) döndürür.
---------------------------------------------------------------------------------------------
local function intro(target: Vector3, flightTime: number, sinkTime: number)
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local S = { cam = cam, items = {}, conns = {} }
	player:SetAttribute("InCutscene", true)
	lockCharacter(true)
	S.oldType, S.oldFov, S.startCf = cam.CameraType, cam.FieldOfView, cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	local surface = waterSurface(target)
	S.surface = surface
	S.entry = Vector3.new(target.X, surface, target.Z)
	S.bottom = Vector3.new(target.X, seabed(target, surface), target.Z)
	local flat = Vector3.new(S.entry.X - root.Position.X, 0, S.entry.Z - root.Position.Z)
	S.fwd = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	S.side = S.fwd:Cross(Vector3.new(0, 1, 0)).Unit

	-- su altı görünümü (sadece kamera suyun altındayken)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CastCineUnderwater"
	cc.TintColor = Color3.fromRGB(150, 205, 255)
	cc.Saturation = 0.1
	cc.Contrast = 0.05
	cc.Enabled = false
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "CastCineBlur"
	blur.Size = 0
	blur.Parent = Lighting
	S.cc, S.blur = cc, blur
	local underwater = false
	function S.setUnder(on)
		if on == underwater then
			return
		end
		underwater = on
		cc.Enabled = on
		blur.Size = if on then 3 else 0
		if on then
			S.drone = play(Audio.UnderwaterDrone, 0, 0.8, true)
			if S.drone then
				TweenService:Create(S.drone, TweenInfo.new(0.8), { Volume = 0.7 }):Play()
			end
			S.bubbles = play(Audio.UnderwaterBubbles, 0.5, 0.8)
		end
	end
	table.insert(S.conns, RunService.RenderStepped:Connect(function()
		S.setUnder(cam.CFrame.Position.Y < surface - 0.3)
	end))

	-- ekran: sinema şeritleri + geçiş perdesi
	local g = Instance.new("ScreenGui")
	g.Name = "CastCineGui"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 30
	g.Parent = player:WaitForChild("PlayerGui")
	for _, anchorY in { 0, 1 } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, anchorY)
		b.Size = UDim2.fromScale(1, 0.09)
		b.Position = UDim2.fromScale(0, if anchorY == 0 then -0.09 else 1.09)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = g
		TweenService:Create(b, TweenInfo.new(0.4), { Position = UDim2.fromScale(0, anchorY) }):Play()
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = g
	S.gui, S.flash = g, flash
	-- dokun -> geç
	local skipHint = Instance.new("TextLabel")
	skipHint.AnchorPoint = Vector2.new(1, 1)
	skipHint.Position = UDim2.new(1, -16, 1, -12)
	skipHint.Size = UDim2.fromOffset(160, 22)
	skipHint.BackgroundTransparency = 1
	skipHint.Font = Enum.Font.GothamBold
	skipHint.TextSize = 14
	skipHint.TextColor3 = Color3.fromRGB(220, 225, 235)
	skipHint.TextTransparency = 0.3
	skipHint.TextXAlignment = Enum.TextXAlignment.Right
	skipHint.Text = "Tap to skip ⏩"
	skipHint.ZIndex = 6
	skipHint.Parent = g
	local started = os.clock()
	table.insert(S.conns, game:GetService("UserInputService").InputBegan:Connect(function(input)
		if os.clock() - started < 0.6 then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space then
			S.skip = true
		end
	end))

	-- yem: kanca + parlak yem topu + ip
	local lure = part("Lure", Vector3.one * 0.45, CFrame.new(rodTip() or root.Position), Color3.fromRGB(255, 120, 90), Enum.Material.Neon, Enum.PartType.Ball)
	local hook = part("Hook", Vector3.new(0.08, 0.55, 0.08), lure.CFrame * CFrame.new(0, -0.35, 0), GOLD, Enum.Material.Metal)
	local lureAtt = Instance.new("Attachment")
	lureAtt.Parent = lure
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 120)
	glow.Range = 8
	glow.Brightness = 2
	glow.Parent = lure
	local trail = emitter(lureAtt, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(GOLD),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Rate = 25,
		Speed = NumberRange.new(0.2, 0.6),
	})
	local anchorPart = part("LineAnchor", Vector3.one * 0.1, CFrame.new(rodTip() or root.Position), Color3.new(), nil, nil, 1)
	local tipAtt = Instance.new("Attachment")
	tipAtt.Parent = anchorPart
	local line = Instance.new("Beam")
	line.Attachment0 = tipAtt
	line.Attachment1 = lureAtt
	line.Width0, line.Width1 = 0.05, 0.05
	line.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	line.Transparency = NumberSequence.new(0.2)
	line.FaceCamera = true
	line.Parent = anchorPart
	S.lure, S.hook, S.lureAtt, S.glow, S.trail = lure, hook, lureAtt, glow, trail
	table.insert(S.items, lure)
	table.insert(S.items, hook)
	table.insert(S.items, anchorPart)

	-- 1) olta savrulur, drone kamera omzun üstüne gelir
	local fwd, side, entry, bottom = S.fwd, S.side, S.entry, S.bottom
	local behind = CFrame.lookAt(root.Position - fwd * 8 + side * 3 + Vector3.new(0, 6, 0), entry)
	TweenService:Create(cam, TweenInfo.new(T_SWING + 0.2, Enum.EasingStyle.Quad), { CFrame = behind, FieldOfView = S.oldFov - 6 }):Play()
	if step(S, T_SWING) then
		return S
	end

	-- 2) uçuş: kamera yemin arkasından takip eder
	local from = rodTip() or (root.Position + Vector3.new(0, 4, 0))
	local apex = (from + entry) / 2 + Vector3.new(0, 7 + (entry - from).Magnitude * 0.15, 0)
	play(Audio.Whoosh, 0.6, 0.6)
	local t0 = os.clock()
	local camPos = cam.CFrame.Position
	local flyConn = RunService.RenderStepped:Connect(function(dt)
		local u = math.clamp((os.clock() - t0) / flightTime, 0, 1)
		local e = if u < 0.5 then 0.5 * (2 * u) ^ 1.6 else 1 - 0.5 * (2 * (1 - u)) ^ 1.15
		local a = 1 - e
		local pos = from * a * a + apex * 2 * a * e + entry * e * e
		lure.CFrame = CFrame.new(pos)
		hook.CFrame = lure.CFrame * CFrame.new(0, -0.35, 0)
		anchorPart.CFrame = CFrame.new(rodTip() or from)
		local desired = pos - fwd * 6 + side * 1.5 + Vector3.new(0, 2.2, 0)
		camPos = camPos:Lerp(desired, math.clamp(dt * 6, 0, 1))
		cam.CFrame = CFrame.lookAt(camPos, pos + fwd * 1.5)
		cam.FieldOfView = S.oldFov - 6 - u * 8
	end)
	table.insert(S.conns, flyConn)
	local skipped = step(S, flightTime)
	flyConn:Disconnect()
	if skipped then
		return S
	end

	-- 3) suya giriş
	play(Audio.WaterPlunge, 0.9, 0.9)
	local splashPart = part("Splash", Vector3.one * 0.2, CFrame.new(entry), Color3.new(), nil, nil, 1)
	local splash = emitter(splashPart, {
		Color = ColorSequence.new(Color3.fromRGB(235, 248, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -40, 0),
		Rate = 0,
		EmissionDirection = Enum.NormalId.Top,
	})
	splash:Emit(45)
	Debris:AddItem(splashPart, 2)
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	local bubbleFx = emitter(lureAtt, {
		Color = ColorSequence.new(Color3.fromRGB(225, 245, 255)),
		Transparency = NumberSequence.new(0.3, 1),
		Size = NumberSequence.new(0.18, 0.35),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 3, 0),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 18,
	})
	bubbleFx:Emit(25)
	S.bubbleFx = bubbleFx
	-- su altı ışık huzmeleri
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local p0 = entry + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)
		local len = math.max(8, surface - bottom.Y + 4)
		table.insert(S.items, part("SunRay", Vector3.new(0.35 + (i % 3) * 0.25, len, 0.1), CFrame.new(p0 - Vector3.new(0, len / 2, 0)) * CFrame.Angles(math.rad(12), a, math.rad(8)), Color3.fromRGB(210, 240, 255), Enum.Material.Neon, nil, 0.94))
	end

	-- 4) dibe iniş
	t0 = os.clock()
	local sinkConn = RunService.RenderStepped:Connect(function(dt)
		local u = math.clamp((os.clock() - t0) / sinkTime, 0, 1)
		local e = 1 - (1 - u) ^ 2
		local sway = Vector3.new(math.sin(u * 9) * 0.4, 0, math.cos(u * 7) * 0.3)
		local pos = entry:Lerp(bottom, e) + sway * (1 - u)
		lure.CFrame = CFrame.new(pos)
		hook.CFrame = lure.CFrame * CFrame.new(0, -0.35, 0) * CFrame.Angles(0, 0, math.sin(u * 12) * 0.3)
		local desired = pos + side * 5 - fwd * 3 + Vector3.new(0, 2.5 - u * 1.2, 0)
		camPos = camPos:Lerp(desired, math.clamp(dt * 4, 0, 1))
		cam.CFrame = CFrame.lookAt(camPos, pos)
		cam.FieldOfView = S.oldFov - 10
	end)
	table.insert(S.conns, sinkConn)
	skipped = step(S, sinkTime)
	sinkConn:Disconnect()
	if skipped then
		return S
	end
	local puffPart = part("SandPuff", Vector3.one * 0.2, CFrame.new(bottom), Color3.new(), nil, nil, 1)
	local puff = emitter(puffPart, {
		Color = ColorSequence.new(Color3.fromRGB(225, 205, 160)),
		Transparency = NumberSequence.new(0.4, 1),
		Size = NumberSequence.new(0.6, 1.6),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(80, 80),
		Rate = 0,
	})
	puff:Emit(14)
	Debris:AddItem(puffPart, 3)
	bubbleFx.Rate = 4
	return S
end

-- Yem yutulunca: yem kaybolur, kabarcık + parıltı patlaması
local function swallow(S, sparkleColor)
	play(Audio.BubbleBurst, 1, 0.9)
	play(Audio.Splash, 0.5, 0.7)
	S.lure.Transparency = 1
	S.hook.Transparency = 1
	S.glow.Enabled = false
	S.trail.Enabled = false
	S.bubbleFx:Emit(40)
	local gulpPart = part("Gulp", Vector3.one * 0.2, CFrame.new(S.lure.Position), Color3.new(), nil, nil, 1)
	local gulp = emitter(gulpPart, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(sparkleColor, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
	})
	gulp:Emit(60)
	Debris:AddItem(gulpPart, 2)
end

-- Geçiş perdesi kapanınca her şeyi temizle, kamerayı geri ver, perdeyi aç
local function outro(S, curtainColor)
	S.flash.BackgroundColor3 = curtainColor
	TweenService:Create(S.flash, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
	task.wait(0.22)
	for _, c in S.conns do
		c:Disconnect()
	end
	S.setUnder(false)
	if S.drone then
		S.drone:Destroy()
	end
	if S.bubbles then
		S.bubbles:Destroy()
	end
	S.cc:Destroy()
	S.blur:Destroy()
	for _, it in S.items do
		it:Destroy()
	end
	local cam = S.cam
	cam.CFrame = S.startCf
	cam.FieldOfView = S.oldFov
	cam.CameraType = if S.oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else S.oldType
	hideBobbers(false)
	lockCharacter(false)
	player:SetAttribute("InCutscene", false)
	TweenService:Create(S.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	local g = S.gui
	task.delay(0.4, function()
		g:Destroy()
	end)
end

---------------------------------------------------------------------------------------------
-- Golden / Epic: uzakta parıltı, balık bir anda atılır ve yemi yutar
---------------------------------------------------------------------------------------------
local function runDash(kind: string, target: Vector3, fishId: string)
	local cfg = if kind == "golden" then GOLDEN else EPIC
	local def = Fish[fishId]
	local color = if kind == "golden" then GOLD else ((def and Rarities[def.rarity] or Rarities.Epic).color)
	local S = intro(target, cfg.flight, cfg.sink)
	if not S then
		return
	end
	if S.skip then
		return outro(S, Color3.new(0, 0, 0))
	end
	local cam, bottom, side, fwd, lure = S.cam, S.bottom, S.side, S.fwd, S.lure
	local dashFrom = bottom + side * -22 + fwd * 6 + Vector3.new(0, 1.2, 0)
	local glint = part("Glint", Vector3.one * 0.8, CFrame.new(dashFrom), color, Enum.Material.Neon, Enum.PartType.Ball, 0.2)
	table.insert(S.items, glint)
	local glintLight = Instance.new("PointLight")
	glintLight.Color = color
	glintLight.Range = 14
	glintLight.Brightness = 3
	glintLight.Parent = glint
	TweenService:Create(glint, TweenInfo.new(cfg.wait, Enum.EasingStyle.Sine), { Size = Vector3.one * 1.6 }):Play()
	local camWait = CFrame.lookAt(bottom + side * 6 - fwd * 4 + Vector3.new(0, 1.6, 0), bottom:Lerp(dashFrom, 0.3))
	TweenService:Create(cam, TweenInfo.new(cfg.wait, Enum.EasingStyle.Sine), { CFrame = camWait }):Play()
	if step(S, cfg.wait) then
		return outro(S, Color3.new(0, 0, 0))
	end
	glint.Transparency = 1
	glintLight.Enabled = false

	local fish = FishModelBuilder.Build(fishId) or FishModelBuilder.Build(Items.Altar.RewardFish)
	noCollide(fish)
	fish.Name = "CastCineFish"
	fish.Parent = Workspace.CurrentCamera
	table.insert(S.items, fish)
	local fishLight = Instance.new("PointLight")
	fishLight.Color = color
	fishLight.Range = 18
	fishLight.Brightness = 4
	fishLight.Parent = fish.PrimaryPart
	local fa0 = Instance.new("Attachment")
	fa0.Position = Vector3.new(0, 0.5, 0.5)
	fa0.Parent = fish.PrimaryPart
	local fa1 = Instance.new("Attachment")
	fa1.Position = Vector3.new(0, -0.5, 0.5)
	fa1.Parent = fish.PrimaryPart
	local ftrail = Instance.new("Trail")
	ftrail.Attachment0, ftrail.Attachment1 = fa0, fa1
	ftrail.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.6))
	ftrail.Transparency = NumberSequence.new(0.2, 1)
	ftrail.Lifetime = 0.35
	ftrail.LightEmission = 1
	ftrail.Parent = fish.PrimaryPart
	local _, fsize = fish:GetBoundingBox()
	local mouthOff = fsize.Z * 0.42
	play(Audio.Whoosh, 0.9, 1.4)
	local t0 = os.clock()
	local dashConn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / cfg.dash, 0, 1)
		local e = u ^ 2.2
		local head = dashFrom:Lerp(lure.Position, e)
		local dir = (lure.Position - dashFrom).Unit
		fish:PivotTo(CFrame.lookAt(head - dir * mouthOff, head - dir * mouthOff + dir) * CFrame.Angles(0, 0, math.sin(u * 30) * 0.15))
		cam.CFrame = camWait:Lerp(CFrame.lookAt(bottom + side * (5 + mouthOff * 0.3) - fwd * 3 + Vector3.new(0, 1.4, 0), head), e)
	end)
	table.insert(S.conns, dashConn)
	if step(S, cfg.dash) then
		return outro(S, Color3.new(0, 0, 0))
	end
	dashConn:Disconnect()
	swallow(S, color)
	local eatPos = fish:GetPivot()
	S.lureAtt.Parent = fish.PrimaryPart
	S.lureAtt.Position = Vector3.new(0, 0, -mouthOff)
	t0 = os.clock()
	local camEat = cam.CFrame
	local escConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local turn = math.clamp(t / 0.3, 0, 1)
		local cf = eatPos * CFrame.Angles(0, math.rad(150) * turn, 0)
		fish:PivotTo(cf * CFrame.new(0, 0, -t * 10 * turn) * CFrame.Angles(0, 0, math.sin(t * 25) * 0.2))
		local k = math.max(0, 0.35 - t) * 1.4
		cam.CFrame = camEat * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		cam.FieldOfView = S.oldFov - 10 - math.max(0, 0.2 - t) * 25
	end)
	table.insert(S.conns, escConn)
	step(S, cfg.after - 0.2)
	outro(S, if kind == "golden" then Color3.new(1, 1, 1) else color:Lerp(Color3.new(1, 1, 1), 0.7))
end

---------------------------------------------------------------------------------------------
-- Reef Shark: sessizlik -> uzaklaşma + gri gölge -> ağzı açık hücum
---------------------------------------------------------------------------------------------
-- Köpekbalığının alt çenesi (alt burun, ağız içi, alt dişler) menteşe etrafında dönsün diye ayrılır
local function rigJaw(shark)
	local body = shark.PrimaryPart
	local head = shark:FindFirstChild("Head")
	local L = body.Size.Z
	local H = if head then head.Size.Y / 0.78 else L * 0.25
	local W = if head then head.Size.X / 0.85 else L * 0.2
	local jaw = {}
	for _, p in shark:GetDescendants() do
		if p:IsA("BasePart") and p ~= body then
			local rel = body.CFrame:ToObjectSpace(p.CFrame)
			local lower = p.Name == "SnoutUnder" or p.Name == "Mouth"
				or (p.Name == "Tooth" and rel.Position.Y < -H * 0.205)
			if lower then
				for _, j in p:GetChildren() do
					if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
						j:Destroy()
					end
				end
				for _, j in body:GetChildren() do
					if (j:IsA("WeldConstraint") or j:IsA("JointInstance")) and (j.Part1 == p or j.Part0 == p) then
						j:Destroy()
					end
				end
				p.Anchored = true
				table.insert(jaw, { part = p, rel = rel })
			end
		end
	end
	-- ağız açılınca görünen koyu boğaz
	local maw = Instance.new("Part")
	maw.Name = "Maw"
	maw.Shape = Enum.PartType.Ball
	maw.Size = Vector3.new(W * 0.62, H * 0.42, L * 0.16)
	maw.Color = Color3.fromRGB(70, 15, 25)
	maw.Material = Enum.Material.SmoothPlastic
	maw.Anchored = true
	maw.CanCollide, maw.CanQuery, maw.CanTouch = false, false, false
	maw.CFrame = body.CFrame * CFrame.new(0, -H * 0.2, -L * 0.36)
	maw.Parent = shark
	local mawRel = body.CFrame:ToObjectSpace(maw.CFrame)
	local hinge = CFrame.new(0, -H * 0.12, -L * 0.24)
	-- open: 0 kapalı .. 1 tam açık
	return function(open)
		local bcf = body.CFrame
		local rot = hinge * CFrame.Angles(math.rad(-38) * open, 0, 0) * hinge:Inverse()
		for _, j in jaw do
			j.part.CFrame = bcf * rot * j.rel
		end
		maw.CFrame = bcf * mawRel * CFrame.new(0, -H * 0.12 * open, 0)
		maw.Transparency = if open > 0.05 then 0 else 1
	end
end

local function runShark(target: Vector3)
	local S = intro(target, SHARK.flight, SHARK.sink)
	if not S then
		return
	end
	local BLACK = Color3.new(0, 0, 0)
	if S.skip then
		return outro(S, BLACK)
	end
	local cam, bottom, side, fwd, lure = S.cam, S.bottom, S.side, S.fwd, S.lure
	local lurePos = lure.Position

	-- 1) sessizlik: yem dipte kıpırdar, kamera yavaşça süzülür
	local quietFrom = cam.CFrame
	local quietTo = CFrame.lookAt(lurePos + side * 4.5 - fwd * 2.5 + Vector3.new(0, 1.6, 0), lurePos)
	TweenService:Create(cam, TweenInfo.new(SHARK.quiet, Enum.EasingStyle.Sine), { CFrame = quietTo }):Play()
	-- kararma: su biraz koyulaşır (tehlike hissi)
	TweenService:Create(S.cc, TweenInfo.new(SHARK.quiet + SHARK.pull, Enum.EasingStyle.Sine), {
		TintColor = Color3.fromRGB(110, 150, 190),
		Brightness = -0.12,
		Saturation = -0.15,
	}):Play()
	if step(S, SHARK.quiet) then
		return outro(S, BLACK)
	end

	-- 2) kamera yemden uzaklaşır; uzakta gri bir gölge geçer
	local camFar = CFrame.lookAt(lurePos + side * 13 - fwd * 9 + Vector3.new(0, 4, 0), lurePos + fwd * 6)
	TweenService:Create(cam, TweenInfo.new(SHARK.pull, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = camFar, FieldOfView = S.oldFov }):Play()
	local ghost = FishModelBuilder.Build(SHARK.fish)
	noCollide(ghost)
	for _, p in ghost:GetDescendants() do
		if p:IsA("BasePart") and p ~= ghost.PrimaryPart then
			p.Color = Color3.fromRGB(55, 62, 72)
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0
			p.Transparency = 0.45
		end
		if p:IsA("PointLight") or p:IsA("SurfaceLight") or p:IsA("ParticleEmitter") then
			p.Enabled = false
		end
	end
	ghost.Parent = Workspace.CurrentCamera
	table.insert(S.items, ghost)
	-- yemin arkasında, uzakta, soldan sağa
	local behindLure = lurePos + fwd * 34 + Vector3.new(0, 3.5, 0)
	local gA = behindLure - side * 40
	local gB = behindLure + side * 40
	local low = play(Audio.UnderwaterDrone, 0.0, 0.45)
	if low then
		TweenService:Create(low, TweenInfo.new(0.6), { Volume = 0.9 }):Play()
		table.insert(S.items, low)
	end
	play(Audio.Whoosh, 0.35, 0.45)
	local t0 = os.clock()
	local ghostConn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / (SHARK.pull + 0.2), 0, 1)
		local pos = gA:Lerp(gB, u)
		ghost:PivotTo(CFrame.lookAt(pos, pos + side) * CFrame.Angles(0, 0, math.sin(u * 14) * 0.08))
	end)
	table.insert(S.conns, ghostConn)
	if step(S, SHARK.pull) then
		return outro(S, BLACK)
	end
	ghostConn:Disconnect()
	ghost:Destroy()

	-- 3) gerilim: sessizlik, kamera hafif titrer
	if S.drone then
		TweenService:Create(S.drone, TweenInfo.new(0.3), { Volume = 0.15 }):Play()
	end
	t0 = os.clock()
	local tenseConn = RunService.RenderStepped:Connect(function()
		local k = 0.04
		cam.CFrame = camFar * CFrame.Angles((math.random() - 0.5) * k * 0.1, (math.random() - 0.5) * k * 0.1, 0)
	end)
	table.insert(S.conns, tenseConn)
	if step(S, SHARK.tension) then
		return outro(S, BLACK)
	end
	tenseConn:Disconnect()

	-- 4) HÜCUM: köpekbalığı karanlıktan ağzını açarak hızla gelir
	local shark = FishModelBuilder.Build(SHARK.fish)
	noCollide(shark)
	for _, p in shark:GetDescendants() do
		if p:IsA("PointLight") then
			p.Enabled = false
		end
	end
	shark.Parent = Workspace.CurrentCamera
	table.insert(S.items, shark)
	local setJaw = rigJaw(shark)
	local _, ssize = shark:GetBoundingBox()
	local mouthOff = ssize.Z * 0.42
	local rushFrom = lurePos + fwd * 38 + side * -6 + Vector3.new(0, 3, 0)
	local dir = (lurePos - rushFrom).Unit
	-- kamera yemin yanında, köpekbalığı neredeyse üstüne gelir
	local camRush = CFrame.lookAt(lurePos - fwd * 5 + side * 3.5 + Vector3.new(0, 1.2, 0), lurePos + fwd * 4)
	cam.CFrame = camRush
	cam.FieldOfView = S.oldFov - 4
	play(Audio.Whoosh, 1, 0.7)
	if S.drone then
		TweenService:Create(S.drone, TweenInfo.new(0.2), { Volume = 0.9 }):Play()
	end
	t0 = os.clock()
	local rushConn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / SHARK.rush, 0, 1)
		local e = u ^ 2.4
		local head = rushFrom:Lerp(lurePos, e)
		shark:PivotTo(CFrame.lookAt(head - dir * mouthOff, head - dir * mouthOff + dir) * CFrame.Angles(0, 0, math.sin(u * 22) * 0.1))
		setJaw(math.clamp((u - 0.2) / 0.6, 0, 1))
		cam.CFrame = camRush * CFrame.Angles(0, 0, (math.random() - 0.5) * u * 0.02)
		cam.FieldOfView = S.oldFov - 4 + u * 8
	end)
	table.insert(S.conns, rushConn)
	if step(S, SHARK.rush) then
		return outro(S, BLACK)
	end
	rushConn:Disconnect()
	-- ÇAT: çene kapanır, yem gider
	setJaw(0)
	swallow(S, Color3.fromRGB(220, 235, 255))
	play(Audio.ShipHit, 0.8, 0.8)
	S.flash.BackgroundColor3 = Color3.fromRGB(120, 0, 10)
	S.flash.BackgroundTransparency = 0.45
	TweenService:Create(S.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	local bitePos = shark:GetPivot()
	t0 = os.clock()
	local camBite = cam.CFrame
	local afterConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		-- yemle birlikte silkelenip döner
		shark:PivotTo(bitePos * CFrame.Angles(0, math.sin(t * 30) * 0.25 * math.max(0, 1 - t * 2), 0) * CFrame.new(0, 0, -t * 4))
		local k = math.max(0, 0.4 - t) * 2.2
		cam.CFrame = camBite * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
	table.insert(S.conns, afterConn)
	step(S, SHARK.after - 0.2)
	outro(S, BLACK)
end

---------------------------------------------------------------------------------------------
local function guard(fn, target)
	if busy or typeof(target) ~= "Vector3" then
		return
	end
	busy = true
	-- sunucunun şamandırası biraz sonra çıkar: sahne boyunca gizle
	task.delay(0.3, hideBobbers, true)
	task.delay(1.0, hideBobbers, true)
	local ok, err = pcall(fn, target)
	if not ok then
		warn("[CastCinematics]", err)
		local cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		lockCharacter(false)
		hideBobbers(false)
		player:SetAttribute("InCutscene", false)
		for _, n in { "CastCineUnderwater", "CastCineBlur" } do
			local e = Lighting:FindFirstChild(n)
			if e then
				e:Destroy()
			end
		end
		local gg = player.PlayerGui:FindFirstChild("CastCineGui")
		if gg then
			gg:Destroy()
		end
	end
	busy = false
end

function CastCinematics.Init()
	Remotes.Event("CastCinematic").OnClientEvent:Connect(function(kind, target, fishId)
		if kind == "shark" then
			guard(runShark, target)
		elseif kind == "golden" or kind == "epic" then
			guard(function(t)
				runDash(kind, t, if typeof(fishId) == "string" then fishId else Items.Altar.RewardFish)
			end, target)
		end
	end)
end

return CastCinematics
