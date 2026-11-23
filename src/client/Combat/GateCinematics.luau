--!nonstrict
-- Kale kapısı görevi (client):
--   * Kapı kanatları: server'da hep kapalı. Anahtarı olan oyuncu için burada YEREL olarak açılır (başkaları kapalı görür).
--   * Giriş sinematiği: korsana zoom, çarkı çevirir, kapı açılır, korsan "düşmanı durdurmalıyız" der. Aksiyon müziği başlar.
--   * Parlayan halka: gemiyi getirip ateş edeceği yer (FireSpot).
--   * Bitiş: müzik durur, "ISLAND 3 UNLOCKED" sinematiği (kafatası mağarasının parmaklığı kalkar).
-- PracticeController durum mesajlarına göre buradaki fonksiyonları çağırır. Ayarlar: Config/Practice.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Cfg = require(ReplicatedStorage.Shared.Config.Practice)
local Audio = require(ReplicatedStorage.Shared.Config.Audio)

local G = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(240, 196, 70)

local frame: CFrame? = nil
local doors = {} -- { model, closed: CFrame, side }
local bar, barClosed
local doorsOpen = false
local doorAnim = 0 -- 0 kapalı .. 1 açık
local questActive = false -- görev sürüyor (kapı açık kalsın)
local cineRunning = false
local music: Sound? = nil
local marker: Model? = nil
local portcullis = {} -- { part, closed CFrame }
local cageUp = false
local gui, subPanel, subName, subText, title, subTitle, bars

---------------------------------------------------------------------------------------------
-- Yardımcılar
---------------------------------------------------------------------------------------------
local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function sfx(id, vol, speed, parentPart, life)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = speed or 1
	if parentPart then
		s.RollOffMinDistance = 60
		s.RollOffMaxDistance = 900
	end
	s.Parent = parentPart or SoundService
	s:Play()
	if life then
		task.delay(life, function()
			tween(s, 0.5, { Volume = 0 })
		end)
	end
	Debris:AddItem(s, (life or 14) + 1)
	return s
end

local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function T(s, u, y)
	return ((frame :: CFrame) * CFrame.new(u, y or 0, -s)).Position
end

local function findTraining()
	local atoll = Workspace:FindFirstChild("Atoll")
	return atoll and atoll:FindFirstChild("Training")
end

local function setControls(on)
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if pm then
		local ok, mod = pcall(require, pm)
		local ctl = ok and mod and mod.GetControls and mod:GetControls()
		if ctl then
			if on then
				ctl:Enable()
			else
				ctl:Disable()
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Kapı kanatları (yerel)
---------------------------------------------------------------------------------------------
local function grabDoors()
	if #doors > 0 and doors[1].model.Parent then
		return true
	end
	doors = {}
	local atoll = Workspace:FindFirstChild("Atoll")
	local gd = atoll and atoll:FindFirstChild("GateDoors", true)
	if not gd then
		return false
	end
	for _, d in gd:GetChildren() do
		if d:IsA("Model") and d.PrimaryPart and d:GetAttribute("Side") then
			table.insert(doors, { model = d, closed = d.PrimaryPart.CFrame, side = d:GetAttribute("Side") })
		end
	end
	bar = gd:FindFirstChild("Bar")
	barClosed = bar and bar:GetPivot()
	return #doors > 0
end

local function applyDoors(a)
	doorAnim = a
	for _, d in doors do
		if d.model.Parent then
			d.model:PivotTo(d.closed * CFrame.Angles(0, d.side * math.rad(86) * a, 0))
		end
	end
	if bar and bar.Parent and barClosed then
		-- sürgü önce yukarı kalkar (ilk %35), sonra kanatlar dönmeye devam eder
		bar:PivotTo(barClosed + Vector3.new(0, 44 * math.clamp(a / 0.35, 0, 1), 0))
	end
end

local function setCollide(open)
	for _, d in doors do
		for _, p in d.model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Hinge" then
				if p:GetAttribute("OrigCollide") == nil then
					p:SetAttribute("OrigCollide", p.CanCollide)
				end
				p.CanCollide = (not open) and p:GetAttribute("OrigCollide")
			end
		end
	end
	if bar then
		for _, p in bar:GetDescendants() do
			if p:IsA("BasePart") then
				if p:GetAttribute("OrigCollide") == nil then
					p:SetAttribute("OrigCollide", p.CanCollide)
				end
				p.CanCollide = (not open) and p:GetAttribute("OrigCollide")
			end
		end
	end
end

-- Kapıyı aç/kapat. seconds = 0 ise anında
function G.SetDoors(open, seconds)
	if not grabDoors() then
		return
	end
	doorsOpen = open
	setCollide(open)
	local from, to = doorAnim, open and 1 or 0
	if not seconds or seconds <= 0 then
		applyDoors(to)
		return
	end
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < seconds do
			if doorsOpen ~= open then
				return
			end
			applyDoors(from + (to - from) * ease((os.clock() - t0) / seconds))
			RunService.RenderStepped:Wait()
		end
		applyDoors(to)
	end)
end

---------------------------------------------------------------------------------------------
-- Kafatası mağarasının parmaklığı (3. ada açıldıysa yerelde kalkık)
---------------------------------------------------------------------------------------------
local function grabCage()
	if #portcullis > 0 and portcullis[1].part.Parent then
		return true
	end
	portcullis = {}
	local t = findTraining()
	local cave = t and t:FindFirstChild("Ambience") and t.Ambience:FindFirstChild("SkullCave")
	if not cave then
		return false
	end
	for _, p in cave:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "PortcullisBar" or p.Name == "PortcullisBeam" or p.Name == "Spike") then
			table.insert(portcullis, { part = p, closed = p.CFrame, collide = p.CanCollide })
		end
	end
	return #portcullis > 0
end

local function setCage(up, seconds)
	if not grabCage() then
		return
	end
	cageUp = up
	for _, c in portcullis do
		local goal = up and (c.closed + Vector3.new(0, 38, 0)) or c.closed
		c.part.CanCollide = (not up) and c.collide
		if seconds and seconds > 0 then
			tween(c.part, seconds, { CFrame = goal }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		else
			c.part.CFrame = goal
		end
	end
end

---------------------------------------------------------------------------------------------
-- Müzik
---------------------------------------------------------------------------------------------
function G.MusicStart()
	if music and music.Parent then
		return
	end
	music = Instance.new("Sound")
	music.Name = "QuestMusic"
	music.SoundId = Audio.QuestMusic
	music.Looped = true
	music.Volume = 0
	music.Parent = SoundService
	music:Play()
	tween(music, 1.5, { Volume = Audio.QuestMusicVolume })
end

function G.MusicStop(seconds)
	local m = music
	music = nil
	if m then
		tween(m, seconds or 2, { Volume = 0 })
		task.delay((seconds or 2) + 0.1, function()
			m:Destroy()
		end)
	end
end

---------------------------------------------------------------------------------------------
-- Halka işareti (ateş noktası)
---------------------------------------------------------------------------------------------
function G.ShowMarker(on)
	if marker then
		marker:Destroy()
		marker = nil
	end
	if not on or not frame then
		return
	end
	local fs = Cfg.FireSpot
	local center = T(fs.s, fs.u, 0.4)
	marker = Instance.new("Model")
	marker.Name = "FireSpotMarker"
	local n = 28
	local r = fs.r * 0.8
	for i = 1, n do
		local a0, a1 = (i - 1) / n * math.pi * 2, i / n * math.pi * 2
		local p0 = center + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r)
		local p1 = center + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
		local seg = Instance.new("Part")
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material = Enum.Material.Neon
		seg.Color = GOLD
		seg.Size = Vector3.new(1.6, 0.4, (p1 - p0).Magnitude + 0.2)
		seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		seg.Parent = marker
	end
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = GOLD
	beam.Transparency = 0.75
	beam.Size = Vector3.new(90, r * 2, r * 2)
	beam.CFrame = CFrame.new(center + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = marker
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 26, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = beam
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.Text = "FIRE FROM HERE"
	t.TextColor3 = GOLD
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	bb.Parent = beam
	marker.Parent = Workspace.CurrentCamera
	task.spawn(function()
		local m = marker
		while m and m.Parent do
			local k = 0.55 + 0.25 * math.sin(os.clock() * 3)
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p ~= beam then
					p.Transparency = 1 - k
				end
			end
			task.wait(0.05)
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Sinematik arayüzü: siyah şeritler + altyazı paneli + büyük başlık
---------------------------------------------------------------------------------------------
local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "GateCineGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	bars = {}
	for i, y in { 0, 1 } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, y)
		b.Position = UDim2.fromScale(0, y)
		b.Size = UDim2.fromScale(1, 0)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = gui
		bars[i] = b
	end
	subPanel = Instance.new("Frame")
	subPanel.AnchorPoint = Vector2.new(0.5, 1)
	subPanel.Position = UDim2.new(0.5, 0, 1, -24)
	subPanel.Size = UDim2.new(0.7, 0, 0, 92)
	subPanel.BackgroundColor3 = Color3.fromRGB(22, 18, 16)
	subPanel.BackgroundTransparency = 0.15
	subPanel.Visible = false
	subPanel.ZIndex = 5
	subPanel.Parent = gui
	Instance.new("UICorner", subPanel).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(214, 170, 70)
	st.Thickness = 3
	st.Parent = subPanel
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(760, 120)
	sc.Parent = subPanel
	subName = Instance.new("TextLabel")
	subName.BackgroundTransparency = 1
	subName.Position = UDim2.fromOffset(18, 8)
	subName.Size = UDim2.new(1, -36, 0, 22)
	subName.Font = Enum.Font.GothamBlack
	subName.TextSize = 16
	subName.TextXAlignment = Enum.TextXAlignment.Left
	subName.TextColor3 = GOLD
	subName.Text = "PIRATE TUTOR"
	subName.ZIndex = 6
	subName.Parent = subPanel
	subText = Instance.new("TextLabel")
	subText.BackgroundTransparency = 1
	subText.Position = UDim2.fromOffset(18, 32)
	subText.Size = UDim2.new(1, -36, 1, -40)
	subText.Font = Enum.Font.GothamMedium
	subText.TextSize = 20
	subText.TextWrapped = true
	subText.TextXAlignment = Enum.TextXAlignment.Left
	subText.TextYAlignment = Enum.TextYAlignment.Top
	subText.TextColor3 = Color3.new(1, 1, 1)
	subText.ZIndex = 6
	subText.Parent = subPanel
	title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.4)
	title.Size = UDim2.fromScale(0.9, 0.16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Bangers
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.TextTransparency = 1
	title.ZIndex = 8
	title.Parent = gui
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.fromRGB(90, 30, 10)
	ts.Thickness = 5
	ts.Transparency = 1
	ts.Name = "Stroke"
	ts.Parent = title
	subTitle = Instance.new("TextLabel")
	subTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subTitle.Position = UDim2.fromScale(0.5, 0.52)
	subTitle.Size = UDim2.fromScale(0.8, 0.06)
	subTitle.BackgroundTransparency = 1
	subTitle.Font = Enum.Font.FredokaOne
	subTitle.TextScaled = true
	subTitle.TextColor3 = Color3.new(1, 1, 1)
	subTitle.TextStrokeTransparency = 0.3
	subTitle.TextTransparency = 1
	subTitle.ZIndex = 8
	subTitle.Parent = gui
end

local function say(name, text)
	subPanel.Visible = true
	subName.Text = name
	subText.Text = text
	subText.MaxVisibleGraphemes = 0
	local n = utf8.len(text) or #text
	task.spawn(function()
		for i = 1, n do
			if subText.Text ~= text then
				return
			end
			subText.MaxVisibleGraphemes = i
			task.wait(0.018)
		end
	end)
end

-- Sinematik başlat / bitir: kontroller, diğer arayüzler, siyah şeritler
local hiddenGuis = {}
local savedFov = 70
local function cineBegin()
	cineRunning = true
	player:SetAttribute("InCutscene", true)
	setControls(false)
	hiddenGuis = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g ~= gui and g.Name ~= "PracticeFxGui" then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	gui.Enabled = true
	for _, b in bars do
		tween(b, 0.5, { Size = UDim2.fromScale(1, 0.1) })
	end
	local cam = Workspace.CurrentCamera
	savedFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
end

local function cineEnd()
	pcall(function()
		RunService:UnbindFromRenderStep("GateCineCam")
	end)
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = savedFov
	subPanel.Visible = false
	for _, b in bars do
		tween(b, 0.4, { Size = UDim2.fromScale(1, 0) })
	end
	task.delay(0.45, function()
		if not cineRunning then
			gui.Enabled = false
		end
	end)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	hiddenGuis = {}
	setControls(true)
	player:SetAttribute("InCutscene", false)
	cineRunning = false
end

-- Kamera yönetmeni: shots = { { t0, t1, fn(k) -> (pos, target, fov) } }, k = 0..1 o planın ilerlemesi
local function runShots(shots, total, onDone)
	local cam = Workspace.CurrentCamera
	local start = os.clock()
	local prevEnd = cam.CFrame
	local shake = 0
	RunService:BindToRenderStep("GateCineCam", Enum.RenderPriority.Camera.Value + 6, function()
		local e = os.clock() - start
		cam.CameraType = Enum.CameraType.Scriptable
		for _, sh in shots do
			if e >= sh[1] and e < sh[2] then
				local k = (e - sh[1]) / (sh[2] - sh[1])
				local pos, tgt, fov, blendFrom, sk = sh[3](k)
				local cf = CFrame.lookAt(pos, tgt)
				if blendFrom then
					cf = prevEnd:Lerp(cf, ease(k / blendFrom))
				end
				shake = math.max(shake * 0.92, sk or 0)
				local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
				cam.CFrame = cf + off
				cam.FieldOfView = fov
				return
			end
		end
	end)
	task.delay(total, function()
		pcall(function()
			RunService:UnbindFromRenderStep("GateCineCam")
		end)
		if onDone then
			onDone()
		end
	end)
	return function(cf)
		prevEnd = cf
	end
end

---------------------------------------------------------------------------------------------
-- 1) Giriş sinematiği
---------------------------------------------------------------------------------------------
function G.PlayIntro()
	if cineRunning or not frame then
		return
	end
	questActive = true
	grabDoors()
	local I = Cfg.Intro
	local npcs = Workspace:FindFirstChild("NPCs")
	local pirate = npcs and npcs:FindFirstChild("Pirate Tutor")
	local head = pirate and pirate:FindFirstChild("Head")
	local headPos = head and head.Position or T(37, -97, 15)
	local face = pirate and pirate:GetPivot().LookVector or (T(10, -40) - T(37, -97)).Unit
	face = Vector3.new(face.X, 0, face.Z).Unit
	local right = face:Cross(Vector3.yAxis)
	local gateC = T(0, 0, 26)
	local outside = -(frame :: CFrame).LookVector
	local winch = Workspace:FindFirstChild("Atoll") and Workspace.Atoll:FindFirstChild("GateWinch", true)
	local capParts = {}
	if winch then
		for _, p in winch:GetChildren() do
			if p.Name:match("^Capstan") then
				table.insert(capParts, { part = p, cf = p.CFrame })
			end
		end
	end
	local capAxis = T(33, -108, 11)

	cineBegin()
	G.MusicStart()
	local cam = Workspace.CurrentCamera
	local cam0 = cam.CFrame
	local t1 = I.ToPirate
	local t2 = t1 + I.Winch
	local t3 = t2 + I.Doors
	local t4 = t3 + I.Talk
	local shots = {
		-- A) oyuncudan korsana uçuş + zoom
		{ 0, t1, function(k)
			local close = headPos + face * 9 + right * 3 + Vector3.new(0, 1.2, 0)
			local p = cam0.Position:Lerp(close, ease(k)) + Vector3.new(0, math.sin(k * math.pi) * 40, 0)
			local tgt = (cam0.Position + cam0.LookVector * 50):Lerp(headPos, ease(math.min(1, k * 1.6)))
			return p, tgt, 70 - 32 * ease(k)
		end },
		-- B) çark: yandan orta plan
		{ t1, t2, function(k)
			local p = capAxis + face * 14 + right * -10 + Vector3.new(0, 7, 0) + right * 3 * k
			return p, capAxis + Vector3.new(0, 3, 0), 52
		end },
		-- C) kapı: dışarıdan, gemi tarafından; kanatlar açılır
		{ t2, t3, function(k)
			local p = gateC + outside * (150 - 30 * k) + Vector3.new(0, 30 - 8 * k, 0)
			return p, gateC + Vector3.new(0, -4, 0), 62, nil, k < 0.12 and 1.4 or 0
		end },
		-- D) korsan konuşur
		{ t3, I.Total, function(k)
			local p = headPos + face * 8 - right * 3.5 + Vector3.new(0, 0.8, 0) + face * -1.5 * k
			return p, headPos + Vector3.new(0, -0.3, 0), 42
		end },
	}
	runShots(shots, I.Total, cineEnd)
	say("PIRATE TUTOR", Cfg.IntroText1)
	task.delay(t1, function()
		subPanel.Visible = false
		sfx(Audio.ChainRattle, 0.8, 1, nil, Cfg.Intro.Winch + 1)
		-- çark döner
		local t0 = os.clock()
		while os.clock() - t0 < I.Winch + 0.4 do
			local a = (os.clock() - t0) * 3
			for _, c in capParts do
				c.part.CFrame = CFrame.new(capAxis) * CFrame.Angles(0, a, 0) * (CFrame.new(capAxis):Inverse() * c.cf)
			end
			RunService.RenderStepped:Wait()
		end
	end)
	task.delay(t2, function()
		sfx(Audio.GateCreak, 1.2, 0.45)
		task.delay(0.6, function()
			sfx(Audio.GateCreak, 1, 0.38)
		end)
		G.SetDoors(true, I.Doors - 0.4)
	end)
	task.delay(t3, function()
		say("PIRATE TUTOR", Cfg.IntroText2)
	end)
	task.delay(t4 + 0.5, function()
		for _, c in capParts do
			if c.part.Parent then
				c.part.CFrame = c.cf
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
-- 2) "ISLAND 3 UNLOCKED" sinematiği (gemi battıktan sonra)
---------------------------------------------------------------------------------------------
function G.PlayUnlock()
	if cineRunning or not frame then
		return
	end
	G.MusicStop(1)
	local U = Cfg.Unlock
	cineBegin()
	local caveFront = T(318, -30, 30)
	local caveMouth = T(345, -30, 26)
	local cam = Workspace.CurrentCamera
	local cam0 = cam.CFrame
	local shots = {
		{ 0, U.Total, function(k)
			local far = T(170, -10, 70)
			local near = T(290, -28, 32)
			local p
			if k < 0.35 then
				p = cam0.Position:Lerp(far, ease(k / 0.35))
			else
				p = far:Lerp(near, ease((k - 0.35) / 0.65))
			end
			local tgt = caveFront:Lerp(caveMouth, ease(k))
			return p, tgt, 60 - 14 * ease(k), nil, (k > 0.3 and k < 0.36) and 1.2 or 0
		end },
	}
	runShots(shots, U.Total, cineEnd)
	sfx(Audio.VictorySting, 0.8, 1)
	task.delay(U.Total * 0.32, function()
		sfx(Audio.ChainRattle, 0.9, 0.8, nil, 3)
		setCage(true, 3)
		-- kafatasının gözleri parlar
		local t = findTraining()
		local cave = t and t:FindFirstChild("Ambience") and t.Ambience:FindFirstChild("SkullCave")
		for _, e in cave and cave:GetChildren() or {} do
			if e.Name == "EyeGlow" then
				local l = e:FindFirstChildOfClass("PointLight")
				if l then
					tween(l, 1.5, { Brightness = 6, Range = 50 })
					task.delay(U.Total, function()
						tween(l, 2, { Brightness = 2, Range = 30 })
					end)
				end
			end
		end
	end)
	task.delay(U.Total * 0.45, function()
		title.Text = Cfg.UnlockTitle
		title.TextTransparency = 0
		title.Stroke.Transparency = 0
		title.Size = UDim2.fromScale(0.3, 0.06)
		tween(title, 0.5, { Size = UDim2.fromScale(0.9, 0.16) }, Enum.EasingStyle.Back)
		subTitle.Text = Cfg.UnlockText
		task.delay(0.5, function()
			tween(subTitle, 0.5, { TextTransparency = 0 })
		end)
	end)
	task.delay(U.Total - 0.6, function()
		tween(title, 0.5, { TextTransparency = 1 })
		tween(title.Stroke, 0.5, { Transparency = 1 })
		tween(subTitle, 0.5, { TextTransparency = 1 })
	end)
end

---------------------------------------------------------------------------------------------
-- Görev durumu (PracticeController'dan)
---------------------------------------------------------------------------------------------
function G.SetQuestActive(on)
	questActive = on
	if on then
		G.SetDoors(true, doorsOpen and 0 or 2.5)
	end
end

function G.Init()
	buildGui()
	task.spawn(function()
		local fp
		repeat
			local t = findTraining()
			fp = t and t:FindFirstChild("TrainFrame")
			if not fp then
				task.wait(1)
			end
		until fp
		frame = fp.CFrame
		-- kapıyı/parmaklığı mesafeye göre yerelde aç-kapa
		while true do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and not cineRunning then
				local gp = T(0, 0, 0)
				local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(gp.X, 0, gp.Z)).Magnitude
				local wantOpen = player:GetAttribute("HasGateKey") == true
					and (questActive or player:GetAttribute("PracticeDone") == true)
					and d < Cfg.GateOpenDistance
				if wantOpen ~= doorsOpen then
					G.SetDoors(wantOpen, wantOpen and 2.5 or 0)
				end
				local wantCage = player:GetAttribute("Island3Unlocked") == true and d < 900
				if wantCage ~= cageUp then
					setCage(wantCage, 0)
				end
			end
			task.wait(0.5)
		end
	end)
end

return G
