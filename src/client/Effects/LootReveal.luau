--!nonstrict
-- Sandık / enkaz açılış sahnesi, anime tarzı (sadece açan oyuncu görür):
--   A. Sinema şeritleri + hız çizgileri, kamera kırbaç gibi sandığa yaklaşır
--   B. Sandık havalanır, titrer, giderek hızlanarak döner; altında büyü çemberi, üstünde renkli alev aurası
--      ve ışık huzmeleri (renk = en nadir ödül), gerilim sesi yükselir
--   C. ÇARPMA: sandık yere çakılır, "impact frame" flaşı (beyaz-siyah-renk), gökyüzüne ışık sütunu,
--      yerde şok dalgası, ağır kamera sarsıntısı, kapak açılır (server, herkes görür)
--   D. Dev "EPIC!!" / "LEGENDARY!!!" yazısı çarpar, ödül kartları teker teker fırlar ve sayaçlara uçar
-- Renkler ve ödüller: Config/Items. Server: Treasure/TreasureService (sandık), Treasure/WreckService (enkaz).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Audio = require(Config:WaitForChild("Audio"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local LootReveal = {}

-- süreler (sn). zoom + shake = çarpma anı. Sandık kapağını server bu anda açar (TreasureService LID_DELAY = 2.15)
local TIMING = {
	chest = { zoom = 0.45, shake = 1.65, dist = 11, height = 4.5 },
	wreck = { zoom = 0.4, shake = 1.0, dist = 16, height = 7 },
}
local CARD_GAP = 0.38 -- kartlar arası
local HOLD = 1.6 -- son karttan sonra bekleme (dokununca hemen kapanır)

local busy = false
local queue = {}

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
	Debris:AddItem(s, 12)
	return s
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 14)
	c.Parent = p
end

---------------------------------------------------------------------------------------------
-- 3B efektler (yerel): dönen ışık huzmeleri, ışık, parıltı
---------------------------------------------------------------------------------------------
local function makeFx(center: Vector3, color: Color3, big: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "LootRevealFx"
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Transparency = 1
	core.Size = Vector3.new(0.5, 0.5, 0.5)
	core.CFrame = CFrame.new(center)
	core.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 0
	light.Shadows = false
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, 6, 0)
	sparks.Rate = 0
	sparks.Parent = core

	-- ışık huzmeleri: sandıktan yukarı / yana açılan ince neon dilimler
	local beams = {}
	local n = big and 10 or 7
	for i = 1, n do
		local b = Instance.new("Part")
		b.Name = "Ray"
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = color
		b.Transparency = 1
		b.Size = Vector3.new(0.35, 0.05, 0.05)
		b.Parent = folder
		table.insert(beams, { part = b, a = (i / n) * math.pi * 2, tilt = math.rad(25 + (i % 3) * 14), w = 0.25 + (i % 2) * 0.25 })
	end
	folder.Parent = Workspace.CurrentCamera -- sadece bu oyuncu görür
	return { folder = folder, core = core, light = light, sparks = sparks, beams = beams, center = center }
end

-- power 0..1: huzme boyu / parlaklık; spin: dönüş açısı
local function updateBeams(fx, power, spin)
	for _, b in fx.beams do
		local len = 1 + power * 11
		local a = b.a + spin
		local dir = CFrame.Angles(0, a, 0) * CFrame.Angles(b.tilt - math.pi / 2, 0, 0)
		b.part.Size = Vector3.new(b.w + power * 0.5, len, b.w + power * 0.5)
		b.part.CFrame = CFrame.new(fx.center) * dir * CFrame.new(0, len / 2 + 0.6, 0)
		b.part.Transparency = 1 - math.clamp(power, 0, 1) * 0.65
	end
	fx.light.Brightness = power * 6
end

---------------------------------------------------------------------------------------------
-- Ekran: parlama + ödül kartları
---------------------------------------------------------------------------------------------
local function makeGui()
	local g = Instance.new("ScreenGui")
	g.Name = "LootRevealGui"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 30
	g.Parent = player:WaitForChild("PlayerGui")
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = g
	-- kenarlarda renkli ışıltı (vinyet)
	local vig = Instance.new("Frame")
	vig.Name = "Vignette"
	vig.Size = UDim2.fromScale(1, 1)
	vig.BackgroundTransparency = 1
	vig.Parent = g
	local vs = Instance.new("UIStroke")
	vs.Thickness = 40
	vs.Transparency = 1
	vs.Parent = vig
	return g, flash, vs
end

local function makeCard(parent, reward, index, count)
	local def = Items.Defs[reward.id]
	local color = Items.TierColors[reward.tier] or Color3.new(1, 1, 1)
	local card = Instance.new("Frame")
	card.Name = "Card" .. index
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.fromOffset(150, 196)
	card.Position = UDim2.fromScale(0.5, 0.62)
	card.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	card.ZIndex = 5
	corner(card)
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = 4
	st.Parent = card
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = card
	-- arkadaki renkli hale
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.new(1, 34, 1, 34)
	halo.BackgroundColor3 = color
	halo.BackgroundTransparency = 0.72
	halo.ZIndex = 4
	corner(halo, UDim.new(0, 26))
	halo.Parent = card
	-- üst yarı renkli degrade
	local top = Instance.new("Frame")
	top.Size = UDim2.new(1, 0, 0.55, 0)
	top.BackgroundColor3 = color
	top.ZIndex = 5
	corner(top)
	local tg = Instance.new("UIGradient")
	tg.Rotation = 90
	tg.Transparency = NumberSequence.new(0.35, 1)
	tg.Parent = top
	top.Parent = card
	-- sarı / mor kartlarda dönen parıltı
	if reward.tier == "Yellow" or reward.tier == "Purple" then
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new(Color3.new(1, 1, 1))
		shine.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		shine.Rotation = 25
		local sf = Instance.new("Frame")
		sf.Size = UDim2.fromScale(1, 1)
		sf.BackgroundColor3 = Color3.new(1, 1, 1)
		sf.BackgroundTransparency = 0.55
		sf.ZIndex = 8
		corner(sf)
		shine.Parent = sf
		sf.Parent = card
		task.spawn(function()
			while sf.Parent do
				shine.Offset = Vector2.new(-1, 0)
				local t = TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
				t:Play()
				t.Completed:Wait()
				task.wait(0.5)
			end
		end)
	end
	local function label(txt, y, h, font, col, size)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, -12, 0, h)
		l.BackgroundTransparency = 1
		l.Text = txt
		l.Font = font
		l.TextColor3 = col
		l.TextScaled = true
		l.ZIndex = 7
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.Parent = l
		l.Parent = card
		return l
	end
	label(def and def.icon or "?", 14, 70, Enum.Font.GothamBold, Color3.new(1, 1, 1), 64)
	local amountText = "+" .. tostring(reward.amount)
	if reward.id == "Gold" then
		amountText = "+$" .. tostring(reward.amount)
	end
	local amt = label(amountText, 96, 34, Enum.Font.FredokaOne, Color3.new(1, 1, 1), 32)
	amt.TextStrokeTransparency = 0.3
	label(def and def.name or reward.id, 132, 22, Enum.Font.GothamBold, Color3.fromRGB(220, 228, 240), 18)
	local tierLbl = label(string.upper(Items.TierNames[reward.tier] or ""), 160, 20, Enum.Font.GothamBlack, color, 15)
	tierLbl.TextStrokeTransparency = 0.6
	card.Parent = parent
	-- hedef konum: yan yana dizilim
	local spread = 192
	local x = (index - (count + 1) / 2) * spread
	return card, sc, UDim2.new(0.5, x, 0.5, 10)
end

---------------------------------------------------------------------------------------------
local function centerOf(model: Instance): (Vector3?, number)
	if not model or not model.Parent then
		return nil, 0
	end
	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		return cf.Position, cf.Position.Y - size.Y / 2
	elseif model:IsA("BasePart") then
		return model.Position, model.Position.Y - model.Size.Y / 2
	end
	return nil, 0
end

local function lockCharacter(on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	-- sahne boyunca kendi karakterin görünmez (sadece senin ekranında): sandık tam görünsün.
	-- Kamera modülü her karede saydamlığı yeniden yazdığı için her karede uygulanır.
	local function apply(v)
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = v
			end
		end
	end
	if on then
		RunService:BindToRenderStep("LootRevealHide", Enum.RenderPriority.Camera.Value + 5, function()
			apply(1)
		end)
	else
		pcall(function()
			RunService:UnbindFromRenderStep("LootRevealHide")
		end)
		apply(0)
	end
	if on then
		hum:SetAttribute("RevealSpeed", hum.WalkSpeed)
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	else
		hum.WalkSpeed = hum:GetAttribute("RevealSpeed") or 16
		hum.JumpHeight = 7.2
		hum:SetAttribute("RevealSpeed", nil)
	end
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

-- Anime hız çizgileri: ekran kenarlarından merkeze doğru titreşen ince beyaz çizgiler
local function makeSpeedLines(g)
	local holder = Instance.new("Frame")
	holder.Name = "SpeedLines"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 2
	holder.Parent = g
	local lines = {}
	for i = 1, 46 do
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.BackgroundColor3 = Color3.new(1, 1, 1)
		l.BorderSizePixel = 0
		l.BackgroundTransparency = 1
		l.ZIndex = 2
		l.Parent = holder
		table.insert(lines, l)
	end
	local power = 0
	local acc = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.045 then
			return
		end
		acc = 0
		local vs = Workspace.CurrentCamera.ViewportSize
		local diag = vs.Magnitude * 0.5
		for _, l in lines do
			if power <= 0.01 or math.random() > 0.35 + power * 0.6 then
				l.BackgroundTransparency = 1
			else
				local a = math.random() * math.pi * 2
				local inner = diag * (0.42 + (1 - power) * 0.35 + math.random() * 0.15)
				local len = diag * 1.2 - inner
				l.Size = UDim2.fromOffset(len, 1 + math.random() * (2 + power * 4))
				l.Position = UDim2.new(0.5, math.cos(a) * inner, 0.5, math.sin(a) * inner)
				l.Rotation = math.deg(a)
				l.BackgroundTransparency = 0.15 + math.random() * 0.4
			end
		end
	end)
	return {
		set = function(v)
			power = v
		end,
		stop = function()
			conn:Disconnect()
			holder:Destroy()
		end,
	}
end

local BANNERS = { Green = "NICE!", Blue = "RARE!", Purple = "EPIC!!", Yellow = "LEGENDARY!!!" }

local function slamBanner(g, top, color)
	local txt = Instance.new("TextLabel")
	txt.Name = "Banner"
	txt.AnchorPoint = Vector2.new(0.5, 0.5)
	txt.Position = UDim2.fromScale(0.5, 0.3)
	txt.Size = UDim2.fromOffset(900, 130)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.FredokaOne
	txt.TextScaled = true
	txt.Text = BANNERS[top] or "TREASURE!"
	txt.TextColor3 = color
	txt.Rotation = -7
	txt.ZIndex = 12
	local st = Instance.new("UIStroke")
	st.Thickness = 7
	st.Color = Color3.fromRGB(15, 10, 25)
	st.Parent = txt
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	grad.Rotation = 90
	grad.Parent = txt
	local sc = Instance.new("UIScale")
	sc.Scale = 3.2
	sc.Parent = txt
	txt.TextTransparency = 1
	txt.Parent = g
	TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(txt, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
	-- yazı hafifçe titreşir
	task.spawn(function()
		local t0 = os.clock()
		while txt.Parent and os.clock() - t0 < 1.2 do
			txt.Position = UDim2.new(0.5, (math.random() - 0.5) * 6, 0.3, (math.random() - 0.5) * 6)
			task.wait(0.03)
		end
		if txt.Parent then
			txt.Position = UDim2.fromScale(0.5, 0.3)
		end
	end)
	return txt
end

local function run(kind: string, model: Instance, rewards, top: string)
	local center, groundY = centerOf(model)
	if not center or type(rewards) ~= "table" then
		return
	end
	local T = TIMING[kind] or TIMING.chest
	local color = Items.TierColors[top] or Items.TierColors.Green
	local big = top == "Purple" or top == "Yellow"
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	player:SetAttribute("InCutscene", true)
	lockCharacter(true)
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	local startCf = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	local away = if root then (root.Position - center) else (startCf.Position - center)
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	-- kamera oyuncunun omzunun üstünden değil, 40° yandan bakar (karakter sandığı kapatmasın)
	away = (CFrame.Angles(0, math.rad(40), 0) * CFrame.new(away)).Position
	local function camAt(dist, lift)
		local focus = center + Vector3.new(0, lift or 0, 0)
		return CFrame.lookAt(center + away * dist + Vector3.new(0, T.height * dist / T.dist, 0), focus)
	end

	local fx = makeFx(center, color, big)
	local g, flash, vig = makeGui()
	vig.Color = color
	local lines = makeSpeedLines(g)

	-- sinema şeritleri
	local bars = {}
	for i, anchorY in { 0, 1 } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, anchorY)
		b.Size = UDim2.fromScale(1, 0.11)
		b.Position = UDim2.fromScale(0, if anchorY == 0 then -0.11 else 1.11)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.ZIndex = 20
		b.Parent = g
		TweenService:Create(b, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, anchorY) }):Play()
		bars[i] = b
	end

	-- büyü çemberi: sandığın altında dönen neon halka (iki kat)
	local circle = {}
	local R1, R2 = (if kind == "wreck" then 6 else 4.2), (if kind == "wreck" then 4 else 2.8)
	for i = 1, 24 do
		table.insert(circle, { part = neon("Rune", Vector3.new(1.1, 0.12, 0.35), CFrame.new(), color, 1), r = R1, a = i / 24 * math.pi * 2, dir = 1 })
	end
	for i = 1, 12 do
		table.insert(circle, { part = neon("Rune", Vector3.new(0.5, 0.12, 0.5), CFrame.new(), Color3.new(1, 1, 1), 1), r = R2, a = i / 12 * math.pi * 2, dir = -1.6 })
	end
	local floorY = groundY + 0.15

	-- aura: sandıktan yukarı akan renkli alevler
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = "rbxasset://textures/particles/fire_main.dds"
	aura.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	aura.Lifetime = NumberRange.new(0.5, 0.9)
	aura.Speed = NumberRange.new(5, 9)
	aura.SpreadAngle = Vector2.new(25, 25)
	aura.EmissionDirection = Enum.NormalId.Top
	aura.Rate = 0
	aura.Parent = fx.core

	local isModel = model:IsA("Model")
	local basePivot = if isModel then model:GetPivot() else nil
	local liftMax = if kind == "wreck" then 1.6 else 3.2

	-- A) kırbaç zoom
	play(Audio.Whoosh, 0.8, 1)
	local riser = play(Audio.ChestRiser, 0.6, 1.1)
	local shakeSound = play(Audio.ChestShake, 0.55, 1.2)
	local t0 = os.clock()
	local total = T.zoom + T.shake
	local spin = 0
	local chestSpin = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		local z = math.clamp(t / T.zoom, 0, 1)
		local ez = 1 - (1 - z) ^ 4
		local charge = math.clamp((t - T.zoom) / T.shake, 0, 1)
		local lift = liftMax * (1 - (1 - charge) ^ 2)
		-- kamera: hızlı yaklaşma, sonra yavaş itme
		local dist = T.dist * (2.6 - ez * 1.6) * (1 - charge * 0.18)
		local camCf = startCf:Lerp(camAt(dist, lift * 0.6), math.clamp(t / (T.zoom * 0.8), 0, 1))
		if z >= 1 then
			camCf = camAt(dist, lift * 0.6)
		end
		local k = charge * charge * 0.35
		cam.CFrame = camCf * CFrame.Angles((math.random() - 0.5) * k * 0.25, (math.random() - 0.5) * k * 0.25, (math.random() - 0.5) * k * 0.6)
		cam.FieldOfView = oldFov + 12 - ez * 30 - charge * 6
		lines.set(if t < T.zoom then 1 - z * 0.6 else 0.25 + charge * 0.75)
		-- sandık havalanır, titrer ve giderek hızlanarak döner
		if isModel and basePivot and model.Parent then
			chestSpin += dt * (1 + charge * charge * 22)
			local amp = 0.03 + charge * 0.12
			local wob = math.sin(t * (20 + charge * 40)) * amp
			model:PivotTo(basePivot * CFrame.new(0, lift, 0) * CFrame.Angles(wob, chestSpin, wob * 0.7))
		end
		-- büyü çemberi döner ve belirir
		spin += dt * (0.8 + charge * 5)
		for _, c in circle do
			local a = c.a + spin * c.dir
			local r = c.r * (0.6 + charge * 0.4)
			c.part.CFrame = CFrame.new(center.X + math.cos(a) * r, floorY, center.Z + math.sin(a) * r) * CFrame.Angles(0, -a, 0)
			c.part.Transparency = 1 - math.clamp(charge * 1.4, 0, 0.85)
		end
		fx.core.CFrame = CFrame.new(center + Vector3.new(0, lift, 0))
		fx.center = center + Vector3.new(0, lift, 0)
		updateBeams(fx, charge * 0.55, spin)
		aura.Rate = charge * 70
		fx.sparks.Rate = charge * 45
		vig.Transparency = 1 - charge * 0.6
		if t >= total then
			conn:Disconnect()
		end
	end)
	task.wait(total)
	if conn.Connected then
		conn:Disconnect()
	end
	if riser then
		riser:Stop()
	end
	if shakeSound then
		shakeSound:Stop()
	end

	-- B) ÇARPMA: sandık yere çakılır (kapağı hemen ardından server açar)
	if isModel and basePivot and model.Parent then
		model:PivotTo(basePivot)
	end
	fx.center = center
	fx.core.CFrame = CFrame.new(center)
	aura.Rate = 0
	play(Audio.ShipBlastBig, if big then 0.55 else 0.35, 1.1)
	play(Audio.ChestOpen, 0.9, 1)
	play(if big then Audio.ChestFanfareBig else Audio.ChestFanfare, 0.55)
	-- anime "impact frame": beyaz, siyah, renk
	task.spawn(function()
		flash.BackgroundTransparency = 0
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		task.wait(0.05)
		flash.BackgroundColor3 = Color3.new(0, 0, 0)
		task.wait(0.05)
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = 0.1
		task.wait(0.04)
		TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	end)
	-- ışık sütunu (gökyüzüne)
	local pillar = neon("Pillar", Vector3.new(400, 0.5, 0.5), CFrame.new(center.X, groundY + 200, center.Z) * CFrame.Angles(0, 0, math.rad(90)), color, 0.15, Enum.PartType.Cylinder)
	local pw = if big then 9 else 6
	TweenService:Create(pillar, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = Vector3.new(400, pw, pw) }):Play()
	task.delay(0.25, function()
		TweenService:Create(pillar, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(400, 0.2, 0.2), Transparency = 1 }):Play()
	end)
	local pillarCore = neon("PillarCore", Vector3.new(400, pw * 0.4, pw * 0.4), pillar.CFrame, Color3.new(1, 1, 1), 0.1, Enum.PartType.Cylinder)
	TweenService:Create(pillarCore, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(400, 0.1, 0.1), Transparency = 1 }):Play()
	-- şok dalgası (yerde genişleyen halka)
	for i, sizeTo in { 46, 30 } do
		local ring = neon("Shockwave", Vector3.new(0.3, 2, 2), CFrame.new(center.X, floorY + 0.1 * i, center.Z) * CFrame.Angles(0, 0, math.rad(90)), if i == 1 then color else Color3.new(1, 1, 1), 0.1, Enum.PartType.Cylinder)
		TweenService:Create(ring, TweenInfo.new(0.55 + i * 0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, sizeTo, sizeTo), Transparency = 1 }):Play()
		Debris:AddItem(ring, 1)
	end
	fx.sparks:Emit(if big then 130 else 70)
	fx.sparks.Rate = if big then 20 else 10
	for _, c in circle do
		TweenService:Create(c.part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end
	lines.set(1)
	local impactAt = os.clock()
	local camBase = camAt(T.dist * 0.8, 0.5)
	local conn2 = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - impactAt
		spin += dt * 1.5
		updateBeams(fx, math.max(0.55, 1 - t * 0.4), spin)
		local k = math.max(0, 0.45 - t) * 2.4
		cam.CFrame = camBase * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.05)
		cam.FieldOfView = oldFov - 26 + math.clamp(t / 0.6, 0, 1) * 12
	end)

	-- C) büyük nadirlik yazısı
	task.wait(0.25)
	local banner = slamBanner(g, top, color)
	task.wait(0.75)
	lines.set(0.3)

	-- D) kartlar
	local cards = {}
	for i, r in rewards do
		local card, sc, target = makeCard(g, r, i, #rewards)
		local isTop = i == #rewards
		play(Audio.RewardPop, 0.6, 0.9 + i * 0.12)
		TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target }):Play()
		TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if isTop and big then 1.12 else 1 }):Play()
		card.Rotation = (math.random() - 0.5) * 30
		TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
		table.insert(cards, { card = card, sc = sc, reward = r })
		task.wait(CARD_GAP)
	end
	lines.set(0)
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.5, 130)
	hint.Size = UDim2.fromOffset(300, 24)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 16
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.4
	hint.Text = "Tap to collect"
	hint.ZIndex = 9
	hint.Parent = g

	local done = false
	local tapConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
			done = true
		end
	end)
	local waitStart = os.clock()
	while not done and os.clock() - waitStart < HOLD do
		task.wait()
	end
	tapConn:Disconnect()
	hint:Destroy()
	TweenService:Create(banner, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()

	-- kartlar üstteki sayaçlara (altın / inci) veya dümendeki çantaya (malzemeler) uçar
	for _, c in cards do
		local dest
		if c.reward.id == "Gold" then
			dest = UDim2.new(0.5, -70, 0, 24)
		elseif c.reward.id == "Pearl" then
			dest = UDim2.new(0.5, 70, 0, 24)
		else
			dest = UDim2.new(0.5, 60, 1, -110)
		end
		TweenService:Create(c.card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = dest }):Play()
		TweenService:Create(c.sc, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.15 }):Play()
		task.wait(0.07)
	end
	conn2:Disconnect()
	for _, b in bars do
		TweenService:Create(b, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end
	local back = TweenService:Create(cam, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = startCf, FieldOfView = oldFov })
	back:Play()
	TweenService:Create(fx.light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	for _, b in fx.beams do
		TweenService:Create(b.part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end
	fx.sparks.Rate = 0
	TweenService:Create(vig, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	back.Completed:Wait()
	cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
	cam.FieldOfView = oldFov
	lockCharacter(false)
	player:SetAttribute("InCutscene", false)
	lines.stop()
	g:Destroy()
	for _, c in circle do
		c.part:Destroy()
	end
	pillar:Destroy()
	pillarCore:Destroy()
	task.delay(1.2, function()
		fx.folder:Destroy()
	end)
end

function LootReveal.Init()
	Remotes.Event("LootReveal").OnClientEvent:Connect(function(kind, model, rewards, top)
		table.insert(queue, { kind, model, rewards, top })
		if busy then
			return
		end
		busy = true
		while #queue > 0 do
			local job = table.remove(queue, 1)
			local ok, err = pcall(run, job[1], job[2], job[3], job[4])
			if not ok then
				warn("[LootReveal]", err)
				-- bir şey ters giderse oyuncu takılı kalmasın
				local cam = Workspace.CurrentCamera
				cam.CameraType = Enum.CameraType.Custom
				lockCharacter(false)
				player:SetAttribute("InCutscene", false)
				local gg = player.PlayerGui:FindFirstChild("LootRevealGui")
				if gg then
					gg:Destroy()
				end
			end
		end
		busy = false
	end)
end

return LootReveal
