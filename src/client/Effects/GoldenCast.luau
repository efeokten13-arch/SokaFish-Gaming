--!nonstrict
-- Kutsamalı atış sahnesi (tapınak kutsaması varken atılan ilk olta; sadece atan oyuncu görür).
--   1. "Drone" kamera oltanın ucundan çıkan yemi arkadan takip eder, hafif ağır çekim, olta ipi görünür
--   2. Yem şapırtıyla suya girer, kamera da suyun altına dalar (mavi renk, derin su uğultusu, kabarcıklar)
--   3. Yem ışık huzmeleri arasından yavaşça dibe iner, kuma oturur (kum bulutu)
--   4. Uzakta altın bir parıltı... Golden Fish bir anda fırlar ve yemi yutar (kabarcık patlaması, sarsıntı)
--   5. Beyaz geçişle kamera oyuncuya döner; Golden Fish tıklama / çekme olmadan doğrudan çantaya girer
-- Server: FishingService (Remotes "GoldenCast"), balık Config/Fishing.GoldenCastWait sn sonra doğrudan yakalanır.
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

local GoldenCast = {}

-- zaman çizelgesi (sn, olay geldiği andan). Toplam GoldenCastWait'ten (6.8) kısa olmalı
local T_SWING = 0.35 -- olta savrulurken bekle
local T_FLIGHT = 1.8 -- yemin havadaki uçuşu (ağır çekim)
local T_SINK = 2.3 -- dibe iniş
local T_WAIT = 0.6 -- dipte bekleyiş (uzakta parıltı)
local T_DASH = 0.55 -- Golden Fish'in atılışı
local T_AFTER = 0.55 -- yuttuktan sonra, geri dönüş öncesi
local MAX_DEPTH = 40 -- dip çok derinse yem bu kadar inince durur

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
		hum:SetAttribute("GoldenCastSpeed", hum.WalkSpeed)
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	else
		hum.WalkSpeed = hum:GetAttribute("GoldenCastSpeed") or 16
		hum.JumpHeight = 7.2
		hum:SetAttribute("GoldenCastSpeed", nil)
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

---------------------------------------------------------------------------------------------
local function run(target: Vector3)
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	player:SetAttribute("InCutscene", true)
	lockCharacter(true)
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	local startCf = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	local surface = waterSurface(target)
	local entry = Vector3.new(target.X, surface, target.Z)
	local bottom = Vector3.new(target.X, seabed(target, surface), target.Z)
	local flat = Vector3.new(entry.X - root.Position.X, 0, entry.Z - root.Position.Z)
	local fwd = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	local side = fwd:Cross(Vector3.new(0, 1, 0)).Unit

	-- su altı görünümü (sadece kamera suyun altındayken)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GoldenCastUnderwater"
	cc.TintColor = Color3.fromRGB(150, 205, 255)
	cc.Saturation = 0.1
	cc.Contrast = 0.05
	cc.Enabled = false
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "GoldenCastBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local drone, bubbles
	local underwater = false
	local function setUnder(on)
		if on == underwater then
			return
		end
		underwater = on
		cc.Enabled = on
		blur.Size = if on then 3 else 0
		if on then
			drone = play(Audio.UnderwaterDrone, 0, 0.8, true)
			if drone then
				TweenService:Create(drone, TweenInfo.new(0.8), { Volume = 0.7 }):Play()
			end
			bubbles = play(Audio.UnderwaterBubbles, 0.5, 0.8)
		end
	end
	local camConn = RunService.RenderStepped:Connect(function()
		setUnder(cam.CFrame.Position.Y < surface - 0.3)
	end)

	-- ekran: sinema şeritleri + beyaz geçiş
	local g = Instance.new("ScreenGui")
	g.Name = "GoldenCastGui"
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

	-- yem: altın kanca + parlak yem topu + ip
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

	-- 1) olta savrulur, drone kamera omzun üstüne gelir
	local behind = CFrame.lookAt(root.Position - fwd * 8 + side * 3 + Vector3.new(0, 6, 0), entry)
	TweenService:Create(cam, TweenInfo.new(T_SWING + 0.2, Enum.EasingStyle.Quad), { CFrame = behind, FieldOfView = oldFov - 6 }):Play()
	task.wait(T_SWING)

	-- 2) uçuş: ağır çekim, kamera yemin arkasından takip eder
	local from = rodTip() or (root.Position + Vector3.new(0, 4, 0))
	local apex = (from + entry) / 2 + Vector3.new(0, 7 + (entry - from).Magnitude * 0.15, 0)
	play(Audio.Whoosh, 0.6, 0.6)
	local t0 = os.clock()
	local camPos = cam.CFrame.Position
	local flyConn = RunService.RenderStepped:Connect(function(dt)
		local u = math.clamp((os.clock() - t0) / T_FLIGHT, 0, 1)
		-- ağır çekim hissi: ortada yavaş, sonda hızlanan
		local e = if u < 0.5 then 0.5 * (2 * u) ^ 1.6 else 1 - 0.5 * (2 * (1 - u)) ^ 1.15
		local a = 1 - e
		local pos = from * a * a + apex * 2 * a * e + entry * e * e
		lure.CFrame = CFrame.new(pos)
		hook.CFrame = lure.CFrame * CFrame.new(0, -0.35, 0)
		anchorPart.CFrame = CFrame.new(rodTip() or from)
		-- drone: yemin arkasında, biraz yukarıda, hafif gecikmeli
		local desired = pos - fwd * 6 + side * 1.5 + Vector3.new(0, 2.2, 0)
		camPos = camPos:Lerp(desired, math.clamp(dt * 6, 0, 1))
		cam.CFrame = CFrame.lookAt(camPos, pos + fwd * 1.5)
		cam.FieldOfView = oldFov - 6 - u * 8
	end)
	task.wait(T_FLIGHT)
	flyConn:Disconnect()

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
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	-- kabarcıklar
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
	-- su altı ışık huzmeleri (güneş ışığı)
	local rays = {}
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local p0 = entry + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)
		local len = math.max(8, surface - bottom.Y + 4)
		local ray = part("SunRay", Vector3.new(0.35 + (i % 3) * 0.25, len, 0.1), CFrame.new(p0 - Vector3.new(0, len / 2, 0)) * CFrame.Angles(math.rad(12), a, math.rad(8)), Color3.fromRGB(210, 240, 255), Enum.Material.Neon, nil, 0.94)
		table.insert(rays, ray)
	end

	-- 4) dibe iniş: kamera yemin yanından, biraz yukarıdan
	t0 = os.clock()
	local sinkConn = RunService.RenderStepped:Connect(function(dt)
		local u = math.clamp((os.clock() - t0) / T_SINK, 0, 1)
		local e = 1 - (1 - u) ^ 2
		local sway = Vector3.new(math.sin(u * 9) * 0.4, 0, math.cos(u * 7) * 0.3)
		local pos = entry:Lerp(bottom, e) + sway * (1 - u)
		lure.CFrame = CFrame.new(pos)
		hook.CFrame = lure.CFrame * CFrame.new(0, -0.35, 0) * CFrame.Angles(0, 0, math.sin(u * 12) * 0.3)
		local desired = pos + side * 5 - fwd * 3 + Vector3.new(0, 2.5 - u * 1.2, 0)
		camPos = camPos:Lerp(desired, math.clamp(dt * 4, 0, 1))
		cam.CFrame = CFrame.lookAt(camPos, pos)
		cam.FieldOfView = oldFov - 10
	end)
	task.wait(T_SINK)
	sinkConn:Disconnect()
	-- kuma otururken küçük kum bulutu
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

	-- 5) bekleyiş: uzakta altın parıltı belirir
	local dashFrom = bottom + side * -22 + fwd * 6 + Vector3.new(0, 1.2, 0)
	local glint = part("Glint", Vector3.one * 0.8, CFrame.new(dashFrom), GOLD, Enum.Material.Neon, Enum.PartType.Ball, 0.2)
	local glintLight = Instance.new("PointLight")
	glintLight.Color = GOLD
	glintLight.Range = 14
	glintLight.Brightness = 3
	glintLight.Parent = glint
	TweenService:Create(glint, TweenInfo.new(T_WAIT, Enum.EasingStyle.Sine), { Size = Vector3.one * 1.6 }):Play()
	local camWait = CFrame.lookAt(bottom + side * 6 - fwd * 4 + Vector3.new(0, 1.6, 0), bottom:Lerp(dashFrom, 0.3))
	TweenService:Create(cam, TweenInfo.new(T_WAIT, Enum.EasingStyle.Sine), { CFrame = camWait }):Play()
	task.wait(T_WAIT)

	-- 6) Golden Fish atılır ve yemi yutar
	glint:Destroy()
	local fish = FishModelBuilder.Build(Items.Altar.RewardFish)
	for _, p in fish:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	fish.Name = "GoldenCastFish"
	fish.Parent = Workspace.CurrentCamera
	local fishLight = Instance.new("PointLight")
	fishLight.Color = GOLD
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
	ftrail.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 250, 200))
	ftrail.Transparency = NumberSequence.new(0.2, 1)
	ftrail.Lifetime = 0.35
	ftrail.LightEmission = 1
	ftrail.Parent = fish.PrimaryPart
	local _, fsize = fish:GetBoundingBox()
	local mouthOff = fsize.Z * 0.42 -- model -Z'ye bakar: ağız önde
	play(Audio.Whoosh, 0.9, 1.4)
	t0 = os.clock()
	local dashConn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / T_DASH, 0, 1)
		local e = u ^ 2.2 -- yavaş başlar, bir anda fırlar
		local target = lure.Position
		local head = dashFrom:Lerp(target, e)
		local dir = (target - dashFrom).Unit
		fish:PivotTo(CFrame.lookAt(head - dir * mouthOff, head - dir * mouthOff + dir) * CFrame.Angles(0, 0, math.sin(u * 30) * 0.15))
		cam.CFrame = camWait:Lerp(CFrame.lookAt(bottom + side * 5 - fwd * 3 + Vector3.new(0, 1.4, 0), head), e)
	end)
	task.wait(T_DASH)
	dashConn:Disconnect()
	-- YUTMA
	play(Audio.BubbleBurst, 1, 0.9)
	play(Audio.Splash, 0.5, 0.7)
	lure.Transparency = 1
	hook.Transparency = 1
	glow.Enabled = false
	trail.Enabled = false
	bubbleFx:Emit(40)
	local gulpPart = part("Gulp", Vector3.one * 0.2, CFrame.new(lure.Position), Color3.new(), nil, nil, 1)
	local gulp = emitter(gulpPart, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
	})
	gulp:Emit(60)
	Debris:AddItem(gulpPart, 2)
	-- balık yemle birlikte dönüp kaçar, ip gerilir; kamera sarsılır
	local eatPos = fish:GetPivot()
	lureAtt.Parent = fish.PrimaryPart
	lureAtt.Position = Vector3.new(0, 0, -mouthOff)
	t0 = os.clock()
	local camEat = cam.CFrame
	local escConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local turn = math.clamp(t / 0.3, 0, 1)
		local cf = eatPos * CFrame.Angles(0, math.rad(150) * turn, 0)
		fish:PivotTo(cf * CFrame.new(0, 0, -t * 10 * turn) * CFrame.Angles(0, 0, math.sin(t * 25) * 0.2))
		local k = math.max(0, 0.35 - t) * 1.4
		cam.CFrame = camEat * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		cam.FieldOfView = oldFov - 10 - math.max(0, 0.2 - t) * 25
	end)
	task.wait(T_AFTER - 0.2)
	-- beyaz geçiş ve geri dönüş
	TweenService:Create(flash, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
	task.wait(0.22)
	escConn:Disconnect()
	camConn:Disconnect()
	setUnder(false)
	if drone then
		drone:Destroy()
	end
	if bubbles then
		bubbles:Destroy()
	end
	cc:Destroy()
	blur:Destroy()
	fish:Destroy()
	lure:Destroy()
	hook:Destroy()
	anchorPart:Destroy()
	for _, r in rays do
		r:Destroy()
	end
	cam.CFrame = startCf
	cam.FieldOfView = oldFov
	cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
	hideBobbers(false)
	lockCharacter(false)
	player:SetAttribute("InCutscene", false)
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.delay(0.4, function()
		g:Destroy()
	end)
end

function GoldenCast.Init()
	Remotes.Event("GoldenCast").OnClientEvent:Connect(function(target)
		if busy or typeof(target) ~= "Vector3" then
			return
		end
		busy = true
		-- sunucunun şamandırası biraz sonra çıkar: sahne boyunca gizle
		task.delay(0.3, hideBobbers, true)
		task.delay(1.0, hideBobbers, true)
		local ok, err = pcall(run, target)
		if not ok then
			warn("[GoldenCast]", err)
			local cam = Workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Custom
			lockCharacter(false)
			hideBobbers(false)
			player:SetAttribute("InCutscene", false)
			for _, n in { "GoldenCastUnderwater", "GoldenCastBlur" } do
				local e = Lighting:FindFirstChild(n)
				if e then
					e:Destroy()
				end
			end
			local gg = player.PlayerGui:FindFirstChild("GoldenCastGui")
			if gg then
				gg:Destroy()
			end
		end
		busy = false
	end)
end

return GoldenCast
