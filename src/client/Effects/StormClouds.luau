--!nonstrict
-- Yağmur bulutları (client görseli): kabarık koyu bulut, yağmur perdesi, sudaki sıçramalar, şimşek.
-- Konumu ReplicatedStorage.Storms'taki yoldan her karede hesaplanır (server ile aynı formül: StormPath).
-- Oyuncu bulutun altındaysa ekranın üstünde "Storm luck" yazısı çıkar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Storms"))
local StormPath = require(Shared:WaitForChild("StormPath"))
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local StormClouds = {}

local player = Players.LocalPlayer
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local DARK = Color3.fromRGB(62, 68, 82)
local MID = Color3.fromRGB(104, 110, 126)
local LIGHT = Color3.fromRGB(158, 164, 178)

local visuals = {} -- [Configuration] = { model, offset parts... }
local banner
local localRain, localRainEmitter -- bulutun altındayken oyuncunun etrafında yoğun yağmur
local gloom -- bulutun altındayken ekran hafif kararır
local wasUnder = false

local function part(parent, name, size, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Elips "puf" (Part + küre mesh)
local function puff(parent, size, color)
	local p = part(parent, "Puff", size, color)
	p.CastShadow = true
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
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

local function buildCloud(seed)
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "StormCloud"
	local pieces = {} -- { part, localCFrame }

	local K = Cfg.Scale or 1
	-- alt katman: geniş, düz, koyu (yağmurun çıktığı taban)
	for i = 1, 11 do
		local a = (i / 11) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(14, 30) * K
		local s = rng:NextNumber(26, 36) * K
		local p = puff(model, Vector3.new(s, s * 0.45, s), DARK)
		table.insert(pieces, { p, CFrame.new(math.cos(a) * r, rng:NextNumber(-2, 2) * K, math.sin(a) * r) })
	end
	table.insert(pieces, { puff(model, Vector3.new(58, 16, 58) * K, DARK), CFrame.new(0, 0, 0) })
	-- orta katman: kabarık, gri
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(8, 22) * K
		local s = rng:NextNumber(22, 32) * K
		table.insert(pieces, { puff(model, Vector3.new(s, s * 0.8, s), MID), CFrame.new(math.cos(a) * r, rng:NextNumber(7, 12) * K, math.sin(a) * r) })
	end
	-- üst katman: açık renk tepeler
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local r = rng:NextNumber(3, 13) * K
		local s = rng:NextNumber(18, 26) * K
		table.insert(pieces, { puff(model, Vector3.new(s, s * 0.85, s), LIGHT), CFrame.new(math.cos(a) * r, rng:NextNumber(16, 22) * K, math.sin(a) * r) })
	end

	-- yağmur kaynağı (görünmez, bulutun altında)
	local rainSrc = part(model, "RainSource", Vector3.new(Cfg.Radius * 1.6, 1, Cfg.Radius * 1.6), DARK, 1)
	table.insert(pieces, { rainSrc, CFrame.new(0, -6 * K, 0) })
	local fall = Cfg.Height - 6 * K
	emitter(rainSrc, {
		Texture = SMOKE,
		Rate = 1400,
		Lifetime = NumberRange.new(fall / 110, fall / 95),
		Speed = NumberRange.new(95, 110),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(3, 3),
		Size = NumberSequence.new(0.6),
		Squash = NumberSequence.new(2.6),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.fromRGB(225, 235, 250)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 0.2) }),
		LightEmission = 0.35,
	})
	-- yağmur perdesi (gri sis): uzaktan bulutun altında yağmur yağdığı belli olsun
	emitter(rainSrc, {
		Texture = SMOKE,
		Rate = 40,
		Lifetime = NumberRange.new(fall / 40, fall / 32),
		Speed = NumberRange.new(32, 40),
		EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 24), NumberSequenceKeypoint.new(1, 40) }),
		Color = ColorSequence.new(Color3.fromRGB(150, 158, 172)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.62), NumberSequenceKeypoint.new(1, 0.85) }),
		LightEmission = 0,
		RotSpeed = NumberRange.new(-10, 10),
		Rotation = NumberRange.new(0, 360),
	})

	-- sudaki sıçramalar
	local splashSrc = part(model, "SplashSource", Vector3.new(Cfg.Radius * 1.6, 0.2, Cfg.Radius * 1.6), DARK, 1)
	table.insert(pieces, { splashSrc, CFrame.new(0, -Cfg.Height + 0.6, 0) })
	emitter(splashSrc, {
		Texture = SMOKE,
		Rate = 280,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(4, 9),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -40, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
		Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	})

	-- yağmur sesi: suyun hizasında, yaklaştıkça duyulur
	local rain = Instance.new("Sound")
	rain.Name = "Rain"
	rain.SoundId = Audio.Rain
	rain.Looped = true
	rain.Volume = Audio.RainVolume
	rain.RollOffMode = Enum.RollOffMode.InverseTapered
	rain.RollOffMinDistance = Cfg.Radius
	rain.RollOffMaxDistance = Cfg.Radius * 4
	rain.Parent = splashSrc
	rain:Play()

	-- şimşek ışığı
	local core = part(model, "Core", Vector3.new(1, 1, 1), DARK, 1)
	table.insert(pieces, { core, CFrame.new(0, 2, 0) })
	local flash = Instance.new("PointLight")
	flash.Range = 240
	flash.Brightness = 0
	flash.Color = Color3.fromRGB(200, 215, 255)
	flash.Shadows = false
	flash.Parent = core

	-- uzaktan görünen yazı
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 54)
	bb.StudsOffset = Vector3.new(0, 52 * K, 0)
	bb.MaxDistance = 2500
	bb.LightInfluence = 0
	bb.Parent = core
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.6)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "⛈ Rain Storm"
	t.TextColor3 = Color3.fromRGB(235, 240, 255)
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	local t2 = t:Clone()
	t2.Position = UDim2.fromScale(0, 0.6)
	t2.Size = UDim2.fromScale(1, 0.4)
	t2.Text = string.format("Rare fish x%g", Cfg.Luck)
	t2.TextColor3 = Color3.fromRGB(255, 215, 90)
	t2.Parent = bb

	model.Parent = Workspace.CurrentCamera
	return { model = model, pieces = pieces, flash = flash, spin = rng:NextNumber(-0.02, 0.02), angle = 0, lastLightning = nil }
end

local function strike(v, center)
	-- gök gürültüsü (uzaktan da duyulur, biraz gecikmeli)
	local core = v.flash.Parent
	local th = Instance.new("Sound")
	th.SoundId = Audio.Thunder[math.random(1, #Audio.Thunder)]
	th.Volume = Audio.ThunderVolume
	th.PlaybackSpeed = 0.9 + math.random() * 0.2
	th.RollOffMode = Enum.RollOffMode.InverseTapered
	th.RollOffMinDistance = Cfg.Radius * 1.5
	th.RollOffMaxDistance = 1600
	th.Parent = core
	task.delay(0.25, function()
		th:Play()
	end)
	task.delay(10, function()
		th:Destroy()
	end)
	-- ışık parlaması
	v.flash.Brightness = 10
	TweenService:Create(v.flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	-- zikzak yıldırım
	local rng = Random.new()
	local K = Cfg.Scale or 1
	local top = center + Vector3.new(rng:NextNumber(-20, 20) * K, Cfg.Height - 6 * K, rng:NextNumber(-20, 20) * K)
	local bottom = center + Vector3.new(rng:NextNumber(-35, 35) * K, 0.5, rng:NextNumber(-35, 35) * K)
	local bolt = Instance.new("Model")
	bolt.Name = "Bolt"
	local prev = top
	local segs = 12
	for i = 1, segs do
		local a = i / segs
		local p = top:Lerp(bottom, a)
		if i < segs then
			p += Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		end
		local len = (p - prev).Magnitude
		local seg = part(bolt, "Seg", Vector3.new(0.9, 0.9, len), Color3.fromRGB(215, 228, 255))
		seg.Material = Enum.Material.Neon
		seg.CastShadow = false
		seg.CFrame = CFrame.lookAt((p + prev) / 2, p)
		prev = p
	end
	bolt.Parent = Workspace.CurrentCamera
	task.delay(0.08, function()
		for _, s in bolt:GetChildren() do
			s.Transparency = 0.6
		end
	end)
	task.delay(0.16, function()
		for _, s in bolt:GetChildren() do
			s.Transparency = 0
		end
	end)
	task.delay(0.26, function()
		bolt:Destroy()
	end)
end

local function makeBanner()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StormGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 96)
	banner.Size = UDim2.fromOffset(400, 36)
	banner.BackgroundColor3 = Color3.fromRGB(40, 48, 70)
	banner.BackgroundTransparency = 0.25
	banner.Font = Enum.Font.FredokaOne
	banner.TextSize = 20
	banner.TextColor3 = Color3.fromRGB(255, 215, 90)
	banner.Text = string.format("⛈ Under the storm: Rare fish x%g!", Cfg.Luck)
	banner.Visible = false
	banner.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = banner
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(255, 215, 90)
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = banner
end

-- Studio'da önizleme için (Edit modunda command bar'dan): StormClouds.Preview(Vector3.new(300, 0, 400))
function StormClouds.Preview(center: Vector3)
	local v = buildCloud(1234)
	v.model.Parent = Workspace
	local base = CFrame.new(center.X, Cfg.Height, center.Z)
	for _, pc in v.pieces do
		pc[1].CFrame = base * pc[2]
	end
	return v.model, function()
		strike(v, center)
	end
end

local function makeLocalRain()
	localRain = Instance.new("Part")
	localRain.Name = "LocalRain"
	localRain.Size = Vector3.new(70, 1, 70)
	localRain.Transparency = 1
	localRain.Anchored = true
	localRain.CanCollide = false
	localRain.CanQuery = false
	localRain.CanTouch = false
	localRain.Parent = Workspace.CurrentCamera
	localRainEmitter = emitter(localRain, {
		Texture = SMOKE,
		Rate = 700,
		Enabled = false,
		Lifetime = NumberRange.new(0.45, 0.55),
		Speed = NumberRange.new(95, 110),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(4, 4),
		Size = NumberSequence.new(0.35),
		Squash = NumberSequence.new(2.8),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.fromRGB(225, 235, 250)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 0.3) }),
		LightEmission = 0.3,
	})
end

function StormClouds.Init()
	makeBanner()
	makeLocalRain()
	gloom = Instance.new("ColorCorrectionEffect")
	gloom.Name = "StormGloom"
	gloom.Parent = Workspace.CurrentCamera
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Storms", 30)
		if not folder then
			return
		end
		local function add(s)
			if visuals[s] or not s:IsA("Configuration") then
				return
			end
			local v = buildCloud(#s.Name * 7919 + (tonumber(s.Name:match("%d+")) or 1) * 101)
			visuals[s] = v
			s:GetAttributeChangedSignal("Lightning"):Connect(function()
				strike(v, StormPath.Position(s))
			end)
		end
		for _, s in folder:GetChildren() do
			add(s)
		end
		folder.ChildAdded:Connect(add)
		folder.ChildRemoved:Connect(function(s)
			if visuals[s] then
				visuals[s].model:Destroy()
				visuals[s] = nil
			end
		end)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local under = false
		for s, v in visuals do
			local c = StormPath.Position(s)
			v.angle += v.spin * dt
			local base = CFrame.new(c.X, Cfg.Height, c.Z) * CFrame.Angles(0, v.angle, 0)
			for _, pc in v.pieces do
				pc[1].CFrame = base * pc[2]
			end
			if root and (Vector3.new(root.Position.X, 0, root.Position.Z) - c).Magnitude <= Cfg.Radius then
				under = true
			end
		end
		if banner then
			banner.Visible = under
		end
		SoundController.SetStormy(under)
		if under ~= wasUnder and gloom then
			wasUnder = under
			TweenService:Create(gloom, TweenInfo.new(1.5), {
				Brightness = if under then -0.08 else 0,
				Contrast = if under then 0.05 else 0,
				Saturation = if under then -0.35 else 0,
				TintColor = if under then Color3.fromRGB(205, 215, 235) else Color3.new(1, 1, 1),
			}):Play()
		end
		if localRain then
			localRainEmitter.Enabled = under
			if under then
				local camPos = Workspace.CurrentCamera.CFrame.Position
				localRain.CFrame = CFrame.new(camPos.X, camPos.Y + 45, camPos.Z)
			end
		end
	end)
end

return StormClouds
