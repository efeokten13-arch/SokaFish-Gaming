--!nonstrict
-- Sandık / enkaz açılışı, Clash of Clans tarzı (sadece açan oyuncu görür):
--   1. "Open" -> kamera sandığa yaklaşır, karakter gizlenir. Üstte 4 boş yıldız, altta "TAP!" yazısı.
--   2. Her dokunuşta sandık zıplayıp kendi etrafında bir tur döner; dönerken kapak biraz aralanır ve içinden
--      sıradaki renk sızar: 1. yeşil, 2. mavi, 3. mor, 4. sarı. Her dokunuşta bir yıldız o renkte yanar.
--   3. Renk sandığın en nadir ödülüne ulaşınca (ör. en iyisi mor ise 3. dokunuşta) sandık kendiliğinden açılır:
--      client server'a "LootRevealDone" der, server kapağı herkes için açar.
--   4. Ödül kartları teker teker çıkar, dokununca altın / inci sayacına veya çantaya uçar.
--   Dokunulmazsa TAP_IDLE sn sonra kendiliğinden devam eder (takılı kalmasın).
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

local VIEW = {
	chest = { dist = 10, height = 5, hop = 2.6 },
	wreck = { dist = 15, height = 7, hop = 1.4 },
}
local TAP_TIME = 0.62 -- bir zıplama + tur süresi
local TAP_IDLE = 6 -- dokunulmazsa kendiliğinden devam
local CRACK = math.rad(-24) -- kapak aralanma açısı
local CARD_GAP = 0.38 -- kartlar arası
local HOLD = 2.2 -- son karttan sonra bekleme (dokununca hemen kapanır)

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

local function lidOf(model)
	local lid = model:FindFirstChild("Lid")
	local closed = model:GetAttribute("LidClosed")
	if lid and lid:IsA("BasePart") and typeof(closed) == "CFrame" then
		return lid, closed
	end
	return nil, nil
end

local function makeStars(g)
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromScale(0.5, 0.17)
	row.Size = UDim2.fromOffset(4 * 74, 70)
	row.BackgroundTransparency = 1
	row.ZIndex = 10
	row.Parent = g
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.Padding = UDim.new(0, 6)
	lay.Parent = row
	local stars = {}
	for i = 1, 4 do
		local st = Instance.new("TextLabel")
		st.Size = UDim2.fromOffset(66, 66)
		st.BackgroundTransparency = 1
		st.Text = "★"
		st.Font = Enum.Font.GothamBlack
		st.TextScaled = true
		st.TextColor3 = Color3.fromRGB(60, 66, 80)
		st.TextTransparency = 0.15
		st.ZIndex = 10
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(20, 22, 30)
		stroke.Parent = st
		local sc = Instance.new("UIScale")
		sc.Parent = st
		st.LayoutOrder = i
		st.Parent = row
		stars[i] = { label = st, scale = sc }
	end
	return row, stars
end

local function makeTapHint(g)
	local t = Instance.new("TextLabel")
	t.Name = "TapHint"
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.8)
	t.Size = UDim2.fromOffset(260, 56)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "👆 TAP!"
	t.TextColor3 = Color3.new(1, 1, 1)
	t.ZIndex = 10
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(20, 22, 30)
	st.Parent = t
	local sc = Instance.new("UIScale")
	sc.Parent = t
	t.Parent = g
	local alive = true
	task.spawn(function()
		while alive and t.Parent do
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1.15 }):Play()
			task.wait(0.35)
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
			task.wait(0.35)
		end
	end)
	return t, function()
		alive = false
	end
end

local function run(kind: string, model: Instance, rewards, top: string)
	local center = centerOf(model)
	if not center or type(rewards) ~= "table" or not model:IsA("Model") then
		return
	end
	local V = VIEW[kind] or VIEW.chest
	local topRank = Items.TierRank(top)
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	player:SetAttribute("InCutscene", true)
	lockCharacter(true)
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	local startCf = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	-- kamera oyuncu tarafından, 35° yandan, biraz yukarıdan (kapağın aralığı görünsün)
	local away = if root then (root.Position - center) else (startCf.Position - center)
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	away = (CFrame.Angles(0, math.rad(35), 0) * CFrame.new(away)).Position
	local camCf = CFrame.lookAt(center + away * V.dist + Vector3.new(0, V.height, 0), center + Vector3.new(0, 1.2, 0))

	local basePivot = model:GetPivot()
	local lid, lidClosed = lidOf(model)
	local hinge = lidClosed and (lidClosed * CFrame.new(0, -0.55, 1.55))
	local function placeLid(pivot, angle)
		if lid and hinge then
			local world = hinge * CFrame.Angles(angle, 0, 0) * hinge:Inverse() * lidClosed
			lid.CFrame = pivot * (basePivot:Inverse() * world)
		end
	end

	local fx = makeFx(center, Items.TierColors.Green, false)
	-- içerideki ışık: kapak aralanınca görünen renkli neon blok + ışık
	local inner = Instance.new("Part")
	inner.Name = "InnerGlow"
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanQuery = false
	inner.CanTouch = false
	inner.CastShadow = false
	inner.Material = Enum.Material.Neon
	inner.Transparency = 1
	local _, size = model:GetBoundingBox()
	inner.Size = Vector3.new(size.X * 0.8, 0.4, size.Z * 0.7)
	inner.Parent = fx.folder
	local g, flash, vig = makeGui()
	local starRow, stars = makeStars(g)
	local hint, stopHint = makeTapHint(g)

	-- yakınlaşma
	TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = camCf, FieldOfView = oldFov - 10 }):Play()
	play(Audio.Whoosh, 0.6, 1.1)
	task.wait(0.5)

	-- sandık dururken hafifçe nefes alır (dokunuş beklerken)
	local level = 0
	local animating = false
	local tapped = false
	local idleT = 0
	local currentColor = nil
	local idleConn = RunService.RenderStepped:Connect(function(dt)
		if animating or not model.Parent then
			return
		end
		idleT += dt
		local wob = math.sin(idleT * 6) * 0.03 * (1 + level * 0.5)
		local pv = basePivot * CFrame.Angles(0, 0, wob)
		model:PivotTo(pv)
		placeLid(pv, 0)
		fx.light.Brightness = if currentColor then 1.5 + math.sin(idleT * 5) * 0.6 else 0
	end)
	local tapConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
			tapped = true
		end
	end)

	-- bir dokunuş: zıpla, tur at, kapak aralanır, yeni renk sızar
	local function doTap(newLevel)
		animating = true
		local tier = Items.TierOrder[newLevel]
		local color = Items.TierColors[tier]
		local t0 = os.clock()
		local revealed = false
		play(Audio.Whoosh, 0.5, 1.2 + newLevel * 0.08)
		play(Audio.ChestShake, 0.35, 1.3)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local u = math.clamp((os.clock() - t0) / TAP_TIME, 0, 1)
			local hop = 4 * u * (1 - u) * V.hop
			local e = u * u * (3 - 2 * u)
			local pv = basePivot * CFrame.new(0, hop, 0) * CFrame.Angles(0, e * math.pi * 2, 0)
			if model.Parent then
				model:PivotTo(pv)
			end
			local open = math.sin(math.pi * u)
			placeLid(pv, CRACK * open * (1 + newLevel * 0.15))
			-- içerideki renkli ışık kapak aralığından sızar
			if u >= 0.3 and not revealed then
				revealed = true
				currentColor = color
				inner.Color = color
				fx.light.Color = color
				fx.sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
				for _, b in fx.beams do
					b.part.Color = color
				end
				local s = stars[newLevel]
				s.label.TextColor3 = color
				s.label.TextTransparency = 0
				s.scale.Scale = 1.8
				TweenService:Create(s.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				play(Audio.RewardPop, 0.7, 0.8 + newLevel * 0.18)
				vig.Color = color
			end
			inner.CFrame = pv * CFrame.new(0, size.Y * 0.18, 0)
			inner.Transparency = if revealed then 1 - open * 0.9 else 1
			fx.center = pv.Position + Vector3.new(0, size.Y * 0.4, 0)
			updateBeams(fx, if revealed then open * (0.25 + newLevel * 0.08) else 0, u * math.pi * 2)
			fx.light.Brightness = if revealed then 2 + open * 5 else 0
			vig.Transparency = if revealed then 1 - open * 0.35 else 1
			if u >= 1 then
				conn:Disconnect()
			end
		end)
		task.wait(TAP_TIME)
		if conn.Connected then
			conn:Disconnect()
		end
		-- yere iniş: küçük sarsıntı + parıltı
		play(Audio.ShipHit, 0.18, 1.6)
		fx.sparks:Emit(8 + newLevel * 6)
		inner.Transparency = 1
		updateBeams(fx, 0, 0)
		vig.Transparency = 1
		local bump = cam.CFrame
		cam.CFrame = bump * CFrame.new(0, -0.15, 0)
		TweenService:Create(cam, TweenInfo.new(0.15), { CFrame = bump }):Play()
		animating = false
	end

	-- dokunuşlar: en nadir ödülün rengine ulaşınca durur
	while level < topRank do
		tapped = false
		local waitStart = os.clock()
		while not tapped and os.clock() - waitStart < TAP_IDLE do
			task.wait()
		end
		level += 1
		doTap(level)
	end
	stopHint()
	hint:Destroy()
	idleConn:Disconnect()

	-- AÇILIŞ: kısa titreme, sonra kapak açılır (server herkes için açar), ışık patlaması
	local color = Items.TierColors[top] or Items.TierColors.Green
	local big = top == "Purple" or top == "Yellow"
	local shakeStart = os.clock()
	while os.clock() - shakeStart < 0.35 do
		local k = 0.06
		local pv = basePivot * CFrame.Angles((math.random() - 0.5) * k, 0, (math.random() - 0.5) * k)
		if model.Parent then
			model:PivotTo(pv)
		end
		placeLid(pv, 0)
		RunService.RenderStepped:Wait()
	end
	if model.Parent then
		model:PivotTo(basePivot)
	end
	placeLid(basePivot, 0)
	Remotes.Event("LootRevealDone"):FireServer(model)
	play(Audio.ChestOpen, 0.85, 1)
	play(if big then Audio.ChestFanfareBig else Audio.ChestFanfare, 0.55)
	flash.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.6)
	flash.BackgroundTransparency = 0.35
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	fx.center = center + Vector3.new(0, size.Y * 0.3, 0)
	fx.sparks:Emit(if big then 80 else 40)
	fx.sparks.Rate = if big then 14 else 6
	inner.CFrame = basePivot * CFrame.new(0, size.Y * 0.18, 0)
	inner.Transparency = 0.1
	local openAt = os.clock()
	local raysConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - openAt
		updateBeams(fx, math.max(0.35, 0.9 - t * 0.3), t * 0.8)
		fx.light.Brightness = 6
	end)
	TweenService:Create(starRow, TweenInfo.new(0.3), { Position = UDim2.fromScale(0.5, 0.08) }):Play()

	-- kartlar
	task.wait(0.45)
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
	local collect = Instance.new("TextLabel")
	collect.AnchorPoint = Vector2.new(0.5, 0)
	collect.Position = UDim2.new(0.5, 0, 0.5, 130)
	collect.Size = UDim2.fromOffset(300, 24)
	collect.BackgroundTransparency = 1
	collect.Font = Enum.Font.GothamBold
	collect.TextSize = 16
	collect.TextColor3 = Color3.new(1, 1, 1)
	collect.TextStrokeTransparency = 0.4
	collect.Text = "Tap to collect"
	collect.ZIndex = 9
	collect.Parent = g
	tapped = false
	local waitStart = os.clock()
	while not tapped and os.clock() - waitStart < HOLD do
		task.wait()
	end
	tapConn:Disconnect()
	collect:Destroy()

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
	TweenService:Create(starRow, TweenInfo.new(0.3), { Position = UDim2.fromScale(0.5, -0.2) }):Play()
	raysConn:Disconnect()
	local back = TweenService:Create(cam, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = startCf, FieldOfView = oldFov })
	back:Play()
	TweenService:Create(fx.light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	TweenService:Create(inner, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	for _, b in fx.beams do
		TweenService:Create(b.part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end
	fx.sparks.Rate = 0
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
				Remotes.Event("LootRevealDone"):FireServer(job[2]) -- server kapağı açsın, veriyi göndersin
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
