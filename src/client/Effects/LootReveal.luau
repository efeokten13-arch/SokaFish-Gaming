--!nonstrict
-- Sandık / enkaz açılış sahnesi (sadece açan oyuncu görür):
--   1. Kamera sandığa yakınlaşır (zoom)
--   2. Sandık sallanır, en nadir ödülün renginde ışık huzmeleri ve parıltılar büyür, gerilim sesi yükselir
--   3. Patlama: ekran o renkte parlar, kapak açılır (server, herkes görür), müzik çalar
--   4. Ödül kartları teker teker fırlar (her biri kendi renginde), sonra üstteki altın / inci sayacına uçar
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

-- süreler (sn). Sandık kapağı server'da 2.45 sn'de açılır (TreasureService LID_DELAY): zoom + shake bundan kısa kalmalı
local TIMING = {
	chest = { zoom = 0.55, shake = 1.75, dist = 9, height = 4.2 },
	wreck = { zoom = 0.45, shake = 0.9, dist = 15, height = 7 },
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
local function centerOf(model: Instance): Vector3?
	if not model or not model.Parent then
		return nil
	end
	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y * 0.15, 0)
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

local function lockCharacter(on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
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

local function run(kind: string, model: Instance, rewards, top: string)
	local center = centerOf(model)
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

	-- kamera oyuncunun tarafından, sandığa önden bakar
	local away = if root then (root.Position - center) else (startCf.Position - center)
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	local function camAt(dist)
		return CFrame.lookAt(center + away * dist + Vector3.new(0, T.height * dist / T.dist, 0), center + Vector3.new(0, 0.4, 0))
	end

	local fx = makeFx(center, color, big)
	local g, flash, vig = makeGui()
	vig.Color = color

	-- sandığın orijinal konumu (yerel sallanma için)
	local isModel = model:IsA("Model")
	local basePivot = if isModel then model:GetPivot() else nil

	-- 1) yakınlaşma + 2) sallanma ve şarj
	local shakeSound = play(Audio.ChestShake, 0.7, if kind == "wreck" then 0.8 else 1.05)
	local riser = play(Audio.ChestRiser, 0.55, 1.15)
	local t0 = os.clock()
	local spin = 0
	local total = T.zoom + T.shake
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		local z = math.clamp(t / T.zoom, 0, 1)
		local ez = 1 - (1 - z) ^ 3
		-- uzaktan (2x) yakına zoom; FOV de daralır
		local camCf = startCf:Lerp(camAt(T.dist * (2 - ez)), math.clamp(t / 0.35, 0, 1))
		if z >= 1 then
			camCf = camAt(T.dist)
		end
		local charge = math.clamp((t - T.zoom * 0.5) / T.shake, 0, 1)
		cam.FieldOfView = oldFov - ez * 14 - charge * 6
		-- kamera titremesi şarjla artar
		local k = charge * charge * 0.18
		cam.CFrame = camCf * CFrame.Angles((math.random() - 0.5) * k * 0.3, (math.random() - 0.5) * k * 0.3, (math.random() - 0.5) * k)
		-- sandık sallanır: önce yavaş tıkırtı, sonra sıklaşan sarsıntı
		if isModel and basePivot and model.Parent then
			local amp = 0.04 + charge * 0.22
			local freq = 12 + charge * 30
			local wob = math.sin(t * freq) * amp
			local hop = math.max(0, math.sin(t * freq * 0.5)) * charge * 0.25
			model:PivotTo(basePivot * CFrame.new(0, hop, 0) * CFrame.Angles(wob * 0.35, 0, wob))
		end
		spin += dt * (0.6 + charge * 3)
		updateBeams(fx, charge * 0.75, spin)
		fx.sparks.Rate = charge * 40
		vig.Transparency = 1 - charge * 0.55
		if t >= total then
			conn:Disconnect()
		end
	end)
	task.wait(total)
	if conn.Connected then
		conn:Disconnect()
	end
	if isModel and basePivot and model.Parent then
		model:PivotTo(basePivot) -- kapağı server açacak: önce yerine koy
	end
	if shakeSound then
		shakeSound:Stop()
	end
	if riser then
		riser:Stop()
	end

	-- 3) patlama
	play(Audio.ChestOpen, 0.8, 1)
	play(if big then Audio.ChestFanfareBig else Audio.ChestFanfare, 0.55)
	flash.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55)
	flash.BackgroundTransparency = 0.15
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	fx.sparks:Emit(if big then 90 else 50)
	fx.sparks.Rate = if big then 18 else 8
	local burstStart = os.clock()
	local camBase = camAt(T.dist)
	local conn2 = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - burstStart
		spin += dt * 1.2
		local p = 1 - math.clamp(t / 0.5, 0, 1) * 0.25 -- huzmeler patlar sonra biraz söner
		updateBeams(fx, p, spin)
		local k = math.max(0, 0.25 - t) * 1.2
		cam.CFrame = camBase * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		cam.FieldOfView = oldFov - 20 + math.clamp(t / 0.4, 0, 1) * 6
	end)

	-- 4) kartlar
	task.wait(0.35)
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

	-- dokununca veya süre dolunca topla
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

	-- kartlar üstteki sayaçlara uçar (altın / inci üst ortada), malzemeler çantaya (sol)
	for _, c in cards do
		local toTop = c.reward.id == "Gold" or c.reward.id == "Pearl"
		local dest = if toTop then UDim2.new(0.5, if c.reward.id == "Gold" then -110 else 20, 0, 24) else UDim2.new(0, 40, 0.5, -35)
		TweenService:Create(c.card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = dest }):Play()
		TweenService:Create(c.sc, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.15 }):Play()
		task.wait(0.07)
	end
	-- kamera karaktere döner
	conn2:Disconnect()
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
	g:Destroy()
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
