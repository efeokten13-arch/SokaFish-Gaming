--!nonstrict
-- Balık fedası sahnesi (sadece feda eden oyuncu görür; server: Map/AltarService).
--   1. Balık oyuncunun üstünde mor ışıkla belirir
--   2. Kavis çizerek tapınağın ortasındaki sunağa uçar (iz bırakır, kamera takip eder)
--   3. Sunağın üstünde yükselerek döner döner, hızlanır; renk morda altına döner, sunak alevi büyür, yer titrer
--   4. PATLAR: altın flaş, kıvılcımlar, şok halkası, balık parçaları savrulur
--   5. Altın bir ışık küresi oyuncuya uçar, çarpınca etrafında altın halka yükselir
--   6. "GOLDEN BLESSING" yazısı: "Your next fish will be a GOLDEN FISH!" -> kamera geri döner
-- Süreler Config/Items.Altar ile uyumlu (BlessAt = ışığın oyuncuya indiği an, Duration = toplam).
-- Kutsama aktifken ekranda küçük altın rozet durur (oyuncunun "GoldenBlessing" attribute'u).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Audio = require(Config:WaitForChild("Audio"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Fish = require(Config:WaitForChild("Fish"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))

local AltarCinematic = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 170)

-- zaman çizelgesi (sn)
local T_APPEAR = 0.8
local T_FLY = 1.6
local T_SPIN = 2.6
local T_ORB = 1.0 -- patlamadan oyuncuya (BlessAt ≈ 0.8 + 1.6 + 2.6 + 0.2 + 1.0 = 6.2)
local T_HOLD = 1.8

local busy = false

local function play(id, volume, pitch)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 15)
	return s
end

local function neon(name, size, cf, color, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = Workspace.CurrentCamera
	return p
end

local function sparks(parent, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 1), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(3, 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = rate or 0
	e.Parent = parent
	return e
end

local function bezier(a, b, c, t)
	local u = 1 - t
	return a * u * u + b * 2 * u * t + c * t * t
end

local function lockCharacter(on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if on then
		hum:SetAttribute("AltarSpeed", hum.WalkSpeed)
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	else
		hum.WalkSpeed = hum:GetAttribute("AltarSpeed") or 16
		hum.JumpHeight = 7.2
		hum:SetAttribute("AltarSpeed", nil)
	end
end

---------------------------------------------------------------------------------------------
-- Ekran: flaş ve kutsama yazısı
---------------------------------------------------------------------------------------------
local function makeGui()
	local g = Instance.new("ScreenGui")
	g.Name = "AltarGui"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 30
	g.Parent = player:WaitForChild("PlayerGui")
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = GOLD_LIGHT
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = g
	return g, flash
end

local function blessingBanner(g)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromOffset(760, 150)
	holder.BackgroundTransparency = 1
	holder.Parent = g
	local sc = Instance.new("UIScale")
	sc.Scale = 2.4
	sc.Parent = holder
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 92)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "✨ GOLDEN BLESSING ✨"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 1
	title.Parent = holder
	local st = Instance.new("UIStroke")
	st.Thickness = 5
	st.Color = Color3.fromRGB(110, 60, 0)
	st.Parent = title
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 210)),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 150, 20)),
	})
	grad.Rotation = 90
	grad.Parent = title
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 96)
	sub.Size = UDim2.new(1, 0, 0, 36)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBlack
	sub.TextScaled = true
	sub.Text = "Your next fish will be a GOLDEN FISH!"
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.TextStrokeTransparency = 0.3
	sub.TextTransparency = 1
	sub.Parent = holder
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	task.delay(0.3, function()
		TweenService:Create(sub, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end)
	-- yazının üstünde gezen parıltı
	task.spawn(function()
		local shine = Instance.new("UIGradient")
		while holder.Parent do
			grad.Offset = Vector2.new(0, -0.15)
			TweenService:Create(grad, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Offset = Vector2.new(0, 0.15) }):Play()
			task.wait(0.6)
			TweenService:Create(grad, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Offset = Vector2.new(0, -0.15) }):Play()
			task.wait(0.6)
		end
		shine:Destroy()
	end)
	return holder, title, sub
end

---------------------------------------------------------------------------------------------
local function run(fishId: string, altar: BasePart, keeper: Model?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not altar or not altar.Parent then
		return
	end
	local cam = Workspace.CurrentCamera
	player:SetAttribute("InCutscene", true)
	lockCharacter(true)
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	local startCf = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	local epicColor = (Rarities[(Fish[fishId] or {}).rarity or "Epic"] or Rarities.Epic).color
	local hover = altar.Position + Vector3.new(0, 9, 0)
	local toPlayer = Vector3.new(root.Position.X - altar.Position.X, 0, root.Position.Z - altar.Position.Z)
	toPlayer = if toPlayer.Magnitude > 0.1 then toPlayer.Unit else Vector3.new(-1, 0, 0)
	local side = toPlayer:Cross(Vector3.new(0, 1, 0)).Unit
	local g, flash = makeGui()
	local fxParts = {}

	-- 1) balık belirir
	local fish = FishModelBuilder.Build(fishId)
	if not fish then
		fish = Instance.new("Model")
		local b = neon("Body", Vector3.new(1, 1, 2), CFrame.new(), epicColor)
		b.Parent = fish
		fish.PrimaryPart = b
	end
	for _, p in fish:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	local startPos = root.Position + Vector3.new(0, 5, 0) - toPlayer * 2
	fish:PivotTo(CFrame.lookAt(startPos, startPos - toPlayer))
	fish.Parent = Workspace.CurrentCamera
	local body = fish.PrimaryPart
	local glowAtt = Instance.new("Attachment")
	glowAtt.Parent = body
	local fishLight = Instance.new("PointLight")
	fishLight.Color = epicColor
	fishLight.Range = 16
	fishLight.Brightness = 3
	fishLight.Parent = glowAtt
	local fishSparks = sparks(glowAtt, epicColor, 18, 0.7)
	-- iz
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(epicColor, GOLD)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Enabled = false
	trail.Parent = body

	local camA = CFrame.lookAt(root.Position + side * 16 + toPlayer * 6 + Vector3.new(0, 7, 0), startPos)
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = camA, FieldOfView = oldFov - 8 }):Play()
	play(Audio.RewardPop, 0.7, 0.8)
	local t0 = os.clock()
	local appearConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local bob = math.sin(t * 6) * 0.25
		fish:PivotTo(CFrame.lookAt(startPos + Vector3.new(0, bob + t * 0.8, 0), startPos + Vector3.new(0, bob + t * 0.8, 0) - toPlayer) * CFrame.Angles(0, 0, math.sin(t * 9) * 0.2))
	end)
	task.wait(T_APPEAR)
	appearConn:Disconnect()

	-- 2) sunağa uçuş
	local from = fish:GetPivot().Position
	local mid = (from + hover) / 2 + Vector3.new(0, 22, 0)
	trail.Enabled = true
	play(Audio.Whoosh, 0.8, 0.8)
	local camB = CFrame.lookAt(altar.Position + toPlayer * 30 + side * 14 + Vector3.new(0, 14, 0), hover)
	t0 = os.clock()
	local flyConn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / T_FLY, 0, 1)
		local e = u * u * (3 - 2 * u)
		local pos = bezier(from, mid, hover, e)
		local ahead = bezier(from, mid, hover, math.min(1, e + 0.03))
		local dir = ahead - pos
		local look = if dir.Magnitude > 0.01 then CFrame.lookAt(pos, pos + dir) else CFrame.new(pos)
		fish:PivotTo(look * CFrame.Angles(0, 0, math.sin(u * 20) * 0.3))
		-- kamera balığı takip eder, sonra sunağı çerçeveler
		local follow = CFrame.lookAt(pos - dir.Unit * 14 + side * 8 + Vector3.new(0, 5, 0), pos)
		cam.CFrame = follow:Lerp(camB, math.clamp((u - 0.55) / 0.45, 0, 1))
	end)
	task.wait(T_FLY)
	flyConn:Disconnect()

	-- 3) dönüş: yükselerek, hızlanarak
	local flame = altar.Parent and altar.Parent:FindFirstChild("AltarFlame")
	local flameSize = flame and flame.Size
	local riser = play(Audio.ChestRiser, 0.7, 0.85)
	local rumble = play(Audio.ChestShake, 0.4, 0.6)
	-- sunak etrafında dönen ışık halkası
	local ring = {}
	for i = 1, 16 do
		table.insert(ring, neon("Orbit", Vector3.new(0.6, 0.6, 0.6), CFrame.new(hover), epicColor, 0.2, Enum.PartType.Ball))
	end
	local rays = {}
	for i = 1, 8 do
		table.insert(rays, neon("Ray", Vector3.new(0.3, 1, 0.3), CFrame.new(hover), epicColor, 1))
	end
	local spinA = 0
	t0 = os.clock()
	local spinConn = RunService.RenderStepped:Connect(function(dt)
		local u = math.clamp((os.clock() - t0) / T_SPIN, 0, 1)
		local speed = 2 + u * u * 38
		spinA += dt * speed
		local col = epicColor:Lerp(GOLD, u)
		local pos = hover + Vector3.new(0, u * 4, 0)
		local shake = u * u * 0.25
		fish:PivotTo(CFrame.new(pos + Vector3.new((math.random() - 0.5) * shake, 0, (math.random() - 0.5) * shake)) * CFrame.Angles(0, spinA, 0) * CFrame.Angles(0, 0, math.rad(90 * u)))
		fishLight.Color = col
		fishLight.Brightness = 3 + u * 8
		fishSparks.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
		fishSparks.Rate = 18 + u * 80
		for i, r in ring do
			local a = (i / #ring) * math.pi * 2 + spinA * 0.35
			local rad = 6 - u * 3.5
			r.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * rad, math.sin(a * 2 + spinA) * 0.8, math.sin(a) * rad))
			r.Color = col
			r.Size = Vector3.one * (0.5 + u * 0.5)
		end
		for i, r in ipairs(rays) do
			local a = (i / #rays) * math.pi * 2 + spinA * 0.2
			local len = 2 + u * 16
			r.Size = Vector3.new(0.3 + u * 0.6, len, 0.3 + u * 0.6)
			r.CFrame = CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(60), 0, 0) * CFrame.new(0, len / 2, 0)
			r.Color = col
			r.Transparency = 1 - u * 0.6
		end
		if flame and flameSize then
			flame.Size = flameSize * (1 + u * 1.5)
		end
		-- kamera yavaşça yaklaşır, titrer
		local k = u * u * 0.3
		cam.CFrame = camB:Lerp(CFrame.lookAt(pos + toPlayer * 20 + side * 9 + Vector3.new(0, 7, 0), pos), u * 0.7)
			* CFrame.Angles((math.random() - 0.5) * k * 0.1, (math.random() - 0.5) * k * 0.1, (math.random() - 0.5) * k * 0.2)
		cam.FieldOfView = oldFov - 8 - u * 10
	end)
	task.wait(T_SPIN)
	spinConn:Disconnect()
	if riser then
		riser:Stop()
	end
	if rumble then
		rumble:Stop()
	end

	-- 4) PATLAMA
	local boomPos = fish:GetPivot().Position
	play(Audio.ShipBlastBig, 0.45, 1.15)
	play(Audio.ChestFanfareBig, 0.5)
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	local core = neon("Boom", Vector3.one * 2, CFrame.new(boomPos), GOLD_LIGHT, 0, Enum.PartType.Ball)
	TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.one * 16, Transparency = 1 }):Play()
	local shock = neon("Shock", Vector3.new(0.4, 2, 2), CFrame.new(boomPos) * CFrame.Angles(0, 0, math.rad(90)), GOLD, 0.1, Enum.PartType.Cylinder)
	TweenService:Create(shock, TweenInfo.new(0.7, Enum.EasingStyle.Quart), { Size = Vector3.new(0.05, 60, 60), Transparency = 1 }):Play()
	local burstAtt = Instance.new("Attachment")
	burstAtt.Parent = core
	local burst = sparks(burstAtt, GOLD, 0, 1.4)
	burst.Speed = NumberRange.new(15, 35)
	burst.Lifetime = NumberRange.new(0.8, 1.6)
	burst.Drag = 3
	burst:Emit(160)
	table.insert(fxParts, core)
	table.insert(fxParts, shock)
	for _, r in ring do
		TweenService:Create(r, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end
	for _, r in rays do
		TweenService:Create(r, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end
	-- balık parçaları altına dönüp savrulur (kameranın içindeki parçalar fizik almaz: tween ile)
	for _, p in fish:GetDescendants() do
		if p:IsA("JointInstance") or p:IsA("WeldConstraint") then
			p:Destroy()
		end
	end
	for _, p in fish:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Material = Enum.Material.Neon
			p.Color = GOLD
			local dir = (p.Position - boomPos)
			dir = if dir.Magnitude > 0.05 then dir.Unit else Vector3.new(math.random() - 0.5, 1, math.random() - 0.5).Unit
			local to = p.Position + dir * math.random(8, 18) + Vector3.new(0, math.random(2, 8), 0)
			TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(to) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
				Transparency = 1,
			}):Play()
		end
	end
	Debris:AddItem(fish, 1.5)
	if flame and flameSize then
		TweenService:Create(flame, TweenInfo.new(1), { Size = flameSize }):Play()
	end
	local boomAt = os.clock()
	local camC = cam.CFrame
	local shakeConn = RunService.RenderStepped:Connect(function()
		local k = math.max(0, 0.5 - (os.clock() - boomAt)) * 2.5
		cam.CFrame = camC * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
	task.wait(0.2)

	-- 5) altın küre oyuncuya iner
	local orb = neon("Orb", Vector3.one * 2.2, CFrame.new(boomPos), GOLD, 0, Enum.PartType.Ball)
	local orbLight = Instance.new("PointLight")
	orbLight.Color = GOLD
	orbLight.Range = 20
	orbLight.Brightness = 5
	orbLight.Parent = orb
	local oa0 = Instance.new("Attachment")
	oa0.Position = Vector3.new(0, 0.8, 0)
	oa0.Parent = orb
	local oa1 = Instance.new("Attachment")
	oa1.Position = Vector3.new(0, -0.8, 0)
	oa1.Parent = orb
	local otrail = Instance.new("Trail")
	otrail.Attachment0, otrail.Attachment1 = oa0, oa1
	otrail.Color = ColorSequence.new(GOLD_LIGHT, GOLD)
	otrail.Transparency = NumberSequence.new(0, 1)
	otrail.Lifetime = 0.45
	otrail.LightEmission = 1
	otrail.Parent = orb
	sparks(oa0, GOLD, 30, 0.8)
	table.insert(fxParts, orb)
	shakeConn:Disconnect()
	local target = root.Position + Vector3.new(0, 1.5, 0)
	local omid = (boomPos + target) / 2 + Vector3.new(0, 18, 0)
	local camD = CFrame.lookAt(root.Position + side * 13 + toPlayer * 9 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
	play(Audio.Whoosh, 0.8, 1.3)
	t0 = os.clock()
	local orbConn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / T_ORB, 0, 1)
		local e = u * u
		local pos = bezier(boomPos, omid, target, e)
		orb.CFrame = CFrame.new(pos)
		cam.CFrame = camC:Lerp(camD, u * u * (3 - 2 * u))
		cam.FieldOfView = oldFov - 18 + u * 8
	end)
	task.wait(T_ORB)
	orbConn:Disconnect()
	orb.Transparency = 1
	orbLight.Enabled = false

	-- 6) oyuncu kutsanır: altın halka yükselir, yazı çıkar
	play(Audio.VictorySting, 0.45)
	flash.BackgroundTransparency = 0.4
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	for i = 1, 3 do
		task.delay((i - 1) * 0.18, function()
			local r = neon("BlessRing", Vector3.new(0.3, 3, 3), CFrame.new(root.Position + Vector3.new(0, -2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), GOLD, 0.1, Enum.PartType.Cylinder)
			TweenService:Create(r, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
				Size = Vector3.new(0.1, 9, 9),
				CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Transparency = 1,
			}):Play()
			Debris:AddItem(r, 1.3)
		end)
	end
	local pillar = neon("BlessPillar", Vector3.new(30, 4, 4), CFrame.new(root.Position + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), GOLD_LIGHT, 0.4, Enum.PartType.Cylinder)
	TweenService:Create(pillar, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = Vector3.new(30, 0.1, 0.1), Transparency = 1 }):Play()
	table.insert(fxParts, pillar)
	local banner = blessingBanner(g)
	-- kamera oyuncunun etrafında yavaşça döner
	t0 = os.clock()
	local orbitConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local a = t * 0.25
		local off = (CFrame.Angles(0, a, 0) * CFrame.new(side * 13 + toPlayer * 9)).Position
		cam.CFrame = CFrame.lookAt(root.Position + off + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
	end)
	task.wait(T_HOLD)
	orbitConn:Disconnect()
	TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.fromScale(0.5, -0.3) }):Play()

	-- geri dönüş
	local back = TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = startCf, FieldOfView = oldFov })
	back:Play()
	back.Completed:Wait()
	cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
	cam.FieldOfView = oldFov
	lockCharacter(false)
	player:SetAttribute("InCutscene", false)
	g:Destroy()
	for _, p in ring do
		p:Destroy()
	end
	for _, p in rays do
		p:Destroy()
	end
	for _, p in fxParts do
		p:Destroy()
	end
end

---------------------------------------------------------------------------------------------
-- Kutsama rozeti (üst ortadaki altın / inci göstergelerinin altında)
---------------------------------------------------------------------------------------------
local function buildBadge()
	local g = Instance.new("ScreenGui")
	g.Name = "BlessingBadge"
	g.ResetOnSpawn = false
	g.DisplayOrder = 5
	g.Parent = player:WaitForChild("PlayerGui")
	local b = Instance.new("TextLabel")
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = UDim2.new(0.5, 0, 0, 46)
	b.Size = UDim2.fromOffset(250, 26)
	b.BackgroundColor3 = Color3.fromRGB(60, 40, 5)
	b.BackgroundTransparency = 0.15
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 14
	b.TextColor3 = GOLD
	b.Text = "✨ Next fish: GOLDEN FISH"
	b.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.Color = GOLD
	st.Thickness = 1.5
	st.Parent = b
	b.Parent = g
	local function refresh()
		b.Visible = player:GetAttribute("GoldenBlessing") == true and player:GetAttribute("InCutscene") ~= true
	end
	player:GetAttributeChangedSignal("GoldenBlessing"):Connect(refresh)
	player:GetAttributeChangedSignal("InCutscene"):Connect(refresh)
	refresh()
	-- hafif nabız
	task.spawn(function()
		while g.Parent do
			if b.Visible then
				TweenService:Create(st, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0.7 }):Play()
				task.wait(0.8)
				TweenService:Create(st, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
			end
			task.wait(0.8)
		end
	end)
end

function AltarCinematic.Init()
	buildBadge()
	Remotes.Event("AltarSacrifice").OnClientEvent:Connect(function(fishId, altar, keeper)
		if busy then
			return
		end
		busy = true
		local ok, err = pcall(run, fishId, altar, keeper)
		if not ok then
			warn("[AltarCinematic]", err)
			local cam = Workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Custom
			lockCharacter(false)
			player:SetAttribute("InCutscene", false)
			local gg = player.PlayerGui:FindFirstChild("AltarGui")
			if gg then
				gg:Destroy()
			end
		end
		busy = false
	end)
end

return AltarCinematic
