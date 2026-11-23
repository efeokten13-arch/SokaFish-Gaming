-- Adalar arası yolculuk animasyonu (~3 sn)
-- Server "SailCinematic" gönderir → oyuncunun teknesinin kopyası yakındaki açık denizde hızla süzülür:
--   pruvadan su fışkırır, arkada köpük izi, suda halkalar ve parıltılar, ekranda hız çizgileri, "ding ding" çan.
-- Ekran beyazken server ışınlar (SeaMap.Sail.PivotAt), sonra beyaz açılır ve oyuncu yeni adadadır.
-- Kopya ve efektler sadece bu oyuncuda (client) oluşur, kimse görmez.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SeaMap = require(Shared.Config:WaitForChild("SeaMap"))
local Audio = require(Shared.Config:WaitForChild("Audio"))
local FishingWater = require(Shared:WaitForChild("FishingWater"))

local S = SeaMap.Sail
local SailCinematic = {}
local playing = false

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function sound(id: string, vol: number, speed: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	task.delay(8, function()
		s:Destroy()
	end)
	return s
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightInfluence = 0.4
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function att(parent: BasePart, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = parent
	return a
end

-- karakterin yakınında düz bir açık deniz hattı bul: (başlangıç, yön)
local function findLane(): (Vector3?, Vector3?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end
	local base = Vector3.new(root.Position.X, 0, root.Position.Z)
	local camLook = Workspace.CurrentCamera.CFrame.LookVector
	local a0 = math.atan2(camLook.X, camLook.Z)
	for _, dist in { 200, 260, 330, 160, 120, 420 } do -- tercihen açıkta (derin, turkuaz su)
		for _, off in { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } do
			local a = a0 + math.rad(off)
			local out = Vector3.new(math.sin(a), 0, math.cos(a))
			local p = base + out * dist
			-- yolculuk yönü: dışarıya dik (sahil boyunca), iki yönü de dene
			for _, side in { 1, -1 } do
				local dir = Vector3.new(-out.Z, 0, out.X) * side
				local ok = true
				for _, k in { -30, 0, 60, 120, 180, 230 } do
					local q = p + dir * k
					if not FishingWater.IsWater(q) or not FishingWater.IsWater(q + out * 40) or not FishingWater.IsWater(q - out * 25) then
						ok = false
						break
					end
				end
				if ok then
					return p, dir
				end
			end
		end
	end
	return nil, nil
end

local function buildBoat(boatId: string?): Model?
	local folder = ReplicatedStorage:FindFirstChild("BoatPreviews")
	if not folder then
		return nil
	end
	local src = (boatId and folder:FindFirstChild(boatId)) or folder:GetChildren()[1]
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	return m
end

-- ekran efektleri: hız çizgileri, yazı, beyaz flaş
local function buildGui(islandName: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SailCinematicGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui

	local lines = {}
	for i = 1, 44 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = if i % 4 == 0 then Color3.fromRGB(200, 240, 255) else Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.1), NumberSequenceKeypoint.new(1, 0.05) })
		g.Parent = f
		f.Parent = gui
		table.insert(lines, { f = f, ang = (i / 44) * math.pi * 2 + math.random() * 0.15, t = math.random() })
	end

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 1, -70)
	title.Size = UDim2.fromOffset(700, 54)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 40
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.25
	title.TextTransparency = 1
	title.TextStrokeColor3 = Color3.fromRGB(10, 60, 100)
	title.Text = "⛵ Sailing to " .. islandName .. "..."
	title.Parent = gui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = gui

	return gui, lines, title, flash
end

local function updateLines(lines, dt: number, strength: number)
	local vs = Workspace.CurrentCamera.ViewportSize
	local cx, cy = vs.X / 2, vs.Y / 2
	local rMax = math.sqrt(cx * cx + cy * cy)
	for _, L in lines do
		L.t += dt * (2.2 + math.random() * 0.6)
		if L.t > 1 then
			L.t -= 1
			L.ang = math.random() * math.pi * 2
			L.len = rMax * (0.25 + math.random() * 0.35)
			L.w = math.random(3, 9)
		end
		L.len = L.len or rMax * 0.4
		L.w = L.w or 3
		-- dış kenardan içeri doğru kayan çizgi
		local r = rMax * (1.05 - L.t * 0.35)
		local x, y = cx + math.cos(L.ang) * r, cy + math.sin(L.ang) * r
		L.f.Position = UDim2.fromOffset(x, y)
		L.f.Size = UDim2.fromOffset(L.len, L.w)
		L.f.Rotation = math.deg(L.ang) + 180
		L.f.BackgroundTransparency = 1 - strength * math.sin(L.t * math.pi) * 0.9
	end
end

local function play(boatId: string?, islandName: string?)
	if playing then
		return
	end
	playing = true
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local startPos = root and root.Position or Vector3.zero
	player:SetAttribute("InCutscene", true)

	-- diğer arayüzleri gizle (butonlar, para vs.), sonunda geri aç
	local hiddenGuis = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	local gui, lines, title, flash = buildGui(islandName or "the island")
	-- fırtına bulutlarını (client modelleri) animasyon boyunca sakla
	local hiddenClouds = {}
	for _, root in { Workspace.CurrentCamera, Workspace } do
		for _, m in root:GetChildren() do
			if m.Name == "StormCloud" or m.Name == "LocalRain" then
				table.insert(hiddenClouds, { m, m.Parent })
				m.Parent = nil
			end
		end
	end
	-- canlı turkuaz renk (sadece animasyon boyunca)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SailMood"
	cc.Saturation = 0.2
	cc.Contrast = 0.12
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(225, 250, 255)
	cc.Parent = game:GetService("Lighting")
	-- su: koyu turkuaz, daha az şeffaf, daha dalgalı (sonda eski haline döner)
	local terrain = Workspace.Terrain
	local water0 = { terrain.WaterColor, terrain.WaterTransparency, terrain.WaterWaveSize, terrain.WaterWaveSpeed }
	terrain.WaterColor = Color3.fromRGB(8, 140, 185)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.35
	terrain.WaterWaveSpeed = 18
	local scene = Instance.new("Folder")
	scene.Name = "SailCinematic"

	-- çan: ding ding
	sound(S.Bell, 0.8)
	local spray = sound(S.Spray, 0.55, 1.1)
	sound(Audio.Splash, 0.6, 0.8)

	local lane0, dir = findLane()
	local boat = buildBoat(boatId)
	local conn: RBXScriptConnection? = nil
	if lane0 and dir and boat then
		local _, size = boat:GetBoundingBox()
		local L = math.max(size.Z, 10)
		local W = math.max(size.X, 6)
		local startCF = CFrame.lookAt(lane0 + Vector3.new(0, 0.65, 0), lane0 + Vector3.new(0, 0.65, 0) + dir)
		boat:PivotTo(startCF)
		boat.Parent = scene

		-- efektler için görünmez "taşıyıcı" parça (tekneyle birlikte gider)
		local rig = Instance.new("Part")
		rig.Name = "FxRig"
		rig.Anchored = true
		rig.CanCollide = false
		rig.CanQuery = false
		rig.Transparency = 1
		rig.Size = Vector3.new(1, 1, 1)
		rig.CFrame = startCF
		rig.Parent = scene

		-- pruvada iki yana fışkıran su
		for _, side in { -1, 1 } do
			local a = att(rig, Vector3.new(side * W * 0.3, 0.4, -L * 0.45))
			a.Orientation = Vector3.new(0, side * -55, 0)
			emitter(a, {
				EmissionDirection = Enum.NormalId.Top,
				Rate = 140,
				Lifetime = NumberRange.new(0.6, 1.0),
				Speed = NumberRange.new(14, 24),
				SpreadAngle = Vector2.new(25, 35),
				Acceleration = Vector3.new(0, -45, 0),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
				RotSpeed = NumberRange.new(-90, 90),
			})
			emitter(a, { -- damlacıklar
				Texture = SPARK,
				Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)),
				EmissionDirection = Enum.NormalId.Top,
				Rate = 90,
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(18, 30),
				SpreadAngle = Vector2.new(30, 40),
				Acceleration = Vector3.new(0, -60, 0),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			})
		end
		-- arkada köpük izi (dünyada kalır, tekne uzaklaşır → iz oluşur)
		for _, side in { -1, 0, 1 } do
			local a = att(rig, Vector3.new(side * W * 0.35, 0.1, L * 0.45))
			emitter(a, {
				LockedToPart = false,
				EmissionDirection = Enum.NormalId.Top,
				Rate = if side == 0 then 55 else 35,
				Lifetime = NumberRange.new(0.9, 1.3),
				Speed = NumberRange.new(0.5, 1.5),
				SpreadAngle = Vector2.new(40, 40),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) }),
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			})
		end
		-- yanlarda suya yayılan halkalar
		for _, side in { -1, 1 } do
			local a = att(rig, Vector3.new(side * W * 0.9, 0.05, 0))
			emitter(a, {
				LockedToPart = false,
				EmissionDirection = Enum.NormalId.Top,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				Speed = NumberRange.new(0.01),
				Rate = 5,
				Lifetime = NumberRange.new(1, 1.3),
				Color = ColorSequence.new(Color3.fromRGB(200, 245, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			})
		end
		-- tekne etrafında parıltılar
		local sp = att(rig, Vector3.new(0, size.Y * 0.4, 0))
		emitter(sp, {
			Texture = SPARK,
			LightEmission = 1,
			LightInfluence = 0,
			Rate = 45,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(4, 10),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(Color3.fromRGB(220, 250, 255)),
		})
		scene.Parent = Workspace

		cam.CameraType = Enum.CameraType.Scriptable
		local t = 0
		local fov0 = cam.FieldOfView
		conn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			local k = math.clamp(t / S.SailTime, 0, 1)
			local travelled = S.Distance * (k * 0.55 + k * k * 0.45) -- giderek hızlanır
			local bob = math.sin(t * 7) * 0.35
			local roll = math.sin(t * 4.3) * math.rad(3)
			local pitch = math.sin(t * 6) * math.rad(1.5) - math.rad(2)
			local cf = startCF * CFrame.new(0, bob, -travelled) * CFrame.Angles(pitch, 0, roll)
			boat:PivotTo(cf)
			rig.CFrame = startCF * CFrame.new(0, 0, -travelled)
			-- kamera: arkadan-yukarıdan, hafif sallantılı, yavaşça geride kalıyor
			local back = 30 + k * 14
			local camPos = (startCF * CFrame.new(math.sin(t * 2) * 1.5, 13 + k * 3, -travelled + back)).Position
			local target = (startCF * CFrame.new(0, 3, -travelled - 20)).Position
			cam.CFrame = CFrame.lookAt(camPos, target) * CFrame.Angles(0, 0, math.sin(t * 3) * math.rad(1))
			cam.FieldOfView = fov0 + 14 * math.min(1, t * 2)
			updateLines(lines, dt, 1)
		end)
	end

	-- açılış flaşı
	TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	if not conn then
		-- tekne/deniz bulunamadı: sadece hız çizgileri
		conn = RunService.RenderStepped:Connect(function(dt)
			updateLines(lines, dt, 1)
		end)
	end

	-- ışınlanmadan hemen önce ekran beyazlaşır
	task.wait(S.PivotAt - 0.35)
	TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	task.wait(0.3)

	-- ışınlanmayı bekle (karakter uzağa taşındı mı?)
	local t0 = os.clock()
	while os.clock() - t0 < 2 do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and (r.Position - startPos).Magnitude > 60 then
			break
		end
		task.wait(0.05)
	end
	if conn then
		conn:Disconnect()
	end
	scene:Destroy()
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	for _, L in lines do
		L.f:Destroy()
	end
	cc:Destroy()
	for _, h in hiddenClouds do
		pcall(function() -- bu arada fırtına bitip bulut silinmiş olabilir
			if h[1].Parent == nil then
				h[1].Parent = h[2]
			end
		end)
	end
	terrain.WaterColor, terrain.WaterTransparency, terrain.WaterWaveSize, terrain.WaterWaveSpeed = water0[1], water0[2], water0[3], water0[4]
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	title.Text = "⚓ " .. (islandName or "")
	sound(Audio.Splash, 0.5, 1.2)
	TweenService:Create(spray, TweenInfo.new(0.6), { Volume = 0 }):Play()
	task.wait(0.15)
	TweenService:Create(flash, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	player:SetAttribute("InCutscene", nil)
	task.wait(1.2)
	TweenService:Create(title, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.wait(0.6)
	gui:Destroy()
	playing = false
end

function SailCinematic.Init()
	Remotes.Event("SailCinematic").OnClientEvent:Connect(function(boatId, islandName)
		task.spawn(play, boatId, islandName)
	end)
end

return SailCinematic
