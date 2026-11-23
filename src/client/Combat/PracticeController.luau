--!nonstrict
-- Atış eğitimi (client): üstte korsanın kartı (aşama, isabet noktaları, cümle) + HIT! yazısı
-- ve gemi batınca ANİME TARZI final: vuruş donması, siyah-beyaz çerçeve, hız çizgileri, sinematik kamera,
-- zincirleme patlamalar, ana patlama (küre + halkalar + ateş sütunu + yıldız parlaması), "SUNK!" yazısı, sesler.
-- Server zamanlaması: Config/Practice.luau (Finale). Server gemiyi Main anında parçalar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local UserInputService = game:GetService("UserInputService")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Gate = require(script.Parent:WaitForChild("GateCinematics"))
local Cfg = require(ReplicatedStorage.Shared.Config.Practice)
local Audio = require(ReplicatedStorage.Shared.Config.Audio)

local PracticeController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(230, 185, 60)
local NAVY = Color3.fromRGB(22, 26, 38)

local hud, card, textLbl, popup, fxGui
local finaleRunning = false

---------------------------------------------------------------------------------------------
-- Küçük yardımcılar
---------------------------------------------------------------------------------------------
local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function sfx2d(id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 12)
end

local fxFolder
local function sfx3d(pos, id, vol, speed, life)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 80
	s.RollOffMaxDistance = 1800
	s.Parent = p
	p.Parent = fxFolder
	s:Play()
	Debris:AddItem(p, 12)
	if life then
		task.delay(life, function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(0.6), { Volume = 0 }):Play()
			end
		end)
	end
end

local function fxPart(shape, size, cf, color, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Parent = fxFolder
	return p
end

local function blob(pos, color, s0, s1, dur, lightRange)
	local p = fxPart(Enum.PartType.Ball, Vector3.one * s0, CFrame.new(pos), color)
	tween(p, dur, { Size = Vector3.one * s1, Transparency = 1 })
	if lightRange then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = lightRange
		l.Brightness = 6
		l.Parent = p
		tween(l, dur, { Brightness = 0 })
	end
	Debris:AddItem(p, dur + 0.2)
	return p
end

-- su yüzeyinde yayılan şok halkası
local function ring(pos, color, d1, dur, thick)
	local p = fxPart(Enum.PartType.Cylinder, Vector3.new(thick or 1.2, 6, 6), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color)
	tween(p, dur, { Size = Vector3.new(thick or 1.2, d1, d1), Transparency = 1 })
	Debris:AddItem(p, dur + 0.2)
end

-- dikey ateş / ışık sütunu
local function pillar(pos, color, w, h, dur)
	local base = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local p = fxPart(Enum.PartType.Cylinder, Vector3.new(h * 0.4, w, w), base, color)
	tween(p, dur, { Size = Vector3.new(h, w * 0.5, w * 0.5), Transparency = 1, CFrame = CFrame.new(pos + Vector3.new(0, h / 2 + h * 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	Debris:AddItem(p, dur + 0.2)
end

-- ekrana bakan 4 uçlu yıldız parlaması (anime "ışık patlaması")
local function starFlare(pos, dur)
	local anchor = fxPart(Enum.PartType.Block, Vector3.one, CFrame.new(pos), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(1400, 1400)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local function bar(w, h)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(w * 0.15, h * 0.15)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = bb
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation = w > h and 0 or 90
		g.Parent = f
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		tween(f, dur, { Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1 }, Enum.EasingStyle.Cubic)
	end
	bar(1300, 26)
	bar(26, 1100)
	bar(900, 18)
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(60, 60)
	glow.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
	glow.BorderSizePixel = 0
	glow.Parent = bb
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	tween(glow, dur, { Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1 })
	Debris:AddItem(anchor, dur + 0.3)
end

local function sparks(pos, count)
	local p = fxPart(Enum.PartType.Block, Vector3.one, CFrame.new(pos), Color3.new(1, 1, 1))
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(1.2, 2.4)
	e.Speed = NumberRange.new(70, 190)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 110, 40))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.2), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	e:Emit(count)
	Debris:AddItem(p, 4)
end

local function smokePlume(pos, seconds)
	local p = fxPart(Enum.PartType.Block, Vector3.one, CFrame.new(pos), Color3.new(1, 1, 1))
	p.Transparency = 1
	local s = Instance.new("Smoke")
	s.Size = 38
	s.Opacity = 0.85
	s.RiseVelocity = 20
	s.Color = Color3.fromRGB(46, 46, 50)
	s.Parent = p
	local f = Instance.new("Fire")
	f.Size = 26
	f.Heat = 12
	f.Parent = p
	task.delay(seconds * 0.6, function()
		f.Enabled = false
	end)
	task.delay(seconds, function()
		s.Enabled = false
	end)
	Debris:AddItem(p, seconds + 6)
end

local function debrisBurst(pos, n)
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.6 + math.random() * 1.2, 0.5, 2 + math.random() * 3)
		p.Color = Color3.fromRGB(120 + math.random(0, 30), 84, 52)
		p.Material = Enum.Material.WoodPlanks
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.AssemblyLinearVelocity = Vector3.new(math.random(-90, 90), math.random(50, 160), math.random(-90, 90))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
		local tr = Instance.new("Trail")
		local a0, a1 = Instance.new("Attachment", p), Instance.new("Attachment", p)
		a0.Position, a1.Position = Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.6
		tr.LightEmission = 0.8
		tr.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 80, 30))
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Parent = p
		p.Parent = fxFolder
		Debris:AddItem(p, 5)
	end
end

---------------------------------------------------------------------------------------------
-- Ekran: HUD kartı
---------------------------------------------------------------------------------------------
local pips = {}
local function refreshPips(n)
	for k, pip in pips do
		pip.BackgroundColor3 = k <= n and Color3.fromRGB(255, 120, 50) or Color3.fromRGB(60, 64, 78)
	end
end

local function buildHud()
	hud = Instance.new("ScreenGui")
	hud.Name = "PracticeGui"
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 30
	hud.Enabled = false
	hud.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 178)
	card.Size = UDim2.fromOffset(480, 118)
	card.BackgroundColor3 = NAVY
	card.BackgroundTransparency = 0.1
	card.Parent = hud
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke")
	st.Color = GOLD
	st.Thickness = 3
	st.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -28, 0, 20)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD
	title.Text = "PIRATE TUTOR  -  SINK THE ENEMY SHIP"
	title.Parent = card

	textLbl = Instance.new("TextLabel")
	textLbl.BackgroundTransparency = 1
	textLbl.Position = UDim2.fromOffset(14, 30)
	textLbl.Size = UDim2.new(1, -28, 0, 50)
	textLbl.Font = Enum.Font.GothamMedium
	textLbl.TextSize = 17
	textLbl.TextWrapped = true
	textLbl.TextXAlignment = Enum.TextXAlignment.Left
	textLbl.TextYAlignment = Enum.TextYAlignment.Top
	textLbl.TextColor3 = Color3.new(1, 1, 1)
	textLbl.Text = ""
	textLbl.Parent = card

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.new(0, 14, 1, -32)
	lbl.Size = UDim2.fromOffset(60, 22)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
	lbl.Text = "HITS"
	lbl.Parent = card
	for k = 1, Cfg.Hits do
		local d = Instance.new("Frame")
		d.Size = UDim2.fromOffset(16, 16)
		d.Position = UDim2.new(0, 62 + (k - 1) * 24, 1, -29)
		d.BackgroundColor3 = Color3.fromRGB(60, 64, 78)
		d.BorderSizePixel = 0
		d.Parent = card
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		pips[k] = d
	end

	popup = Instance.new("TextLabel")
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.58)
	popup.Size = UDim2.fromOffset(320, 90)
	popup.BackgroundTransparency = 1
	popup.Font = Enum.Font.Bangers
	popup.TextSize = 72
	popup.Text = "HIT!"
	popup.TextColor3 = Color3.fromRGB(255, 170, 50)
	popup.TextTransparency = 1
	popup.TextStrokeTransparency = 1
	popup.Parent = hud
	local ps = Instance.new("UIStroke")
	ps.Color = Color3.fromRGB(120, 20, 10)
	ps.Thickness = 5
	ps.Transparency = 1
	ps.Name = "Stroke"
	ps.Parent = popup
end

local function showHit()
	popup.Position = UDim2.fromScale(0.5, 0.6)
	popup.Rotation = math.random(-8, 8)
	popup.TextTransparency = 0
	popup.Stroke.Transparency = 0
	popup.TextSize = 40
	tween(popup, 0.18, { TextSize = 84 }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		tween(popup, 0.4, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.52) })
		tween(popup.Stroke, 0.4, { Transparency = 1 })
	end)
end

local function setText(t)
	textLbl.Text = t
	textLbl.MaxVisibleGraphemes = 0
	local n = utf8.len(t) or #t
	task.spawn(function()
		for i = 1, n do
			if textLbl.Text ~= t then
				return
			end
			textLbl.MaxVisibleGraphemes = i
			task.wait(0.012)
		end
		textLbl.MaxVisibleGraphemes = -1
	end)
end

local function showCard()
	if hud.Enabled then
		return
	end
	hud.Enabled = true
	card.Position = UDim2.new(0.5, 0, 0, -160)
	tween(card, 0.5, { Position = UDim2.new(0.5, 0, 0, 178) }, Enum.EasingStyle.Back)
end

local function hideCard(delay)
	task.delay(delay or 0, function()
		tween(card, 0.4, { Position = UDim2.new(0.5, 0, 0, -160) }).Completed:Once(function()
			hud.Enabled = false
		end)
	end)
end

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function onState(d)
	if not hud then
		return
	end
	if d.kind == "intro" then
		refreshPips(0)
		Gate.PlayIntro()
	elseif d.kind == "sail" then
		Gate.SetQuestActive(true)
		Gate.MusicStart()
		Gate.ShowMarker(true)
		refreshPips(0)
		showCard()
		setText(d.text)
	elseif d.kind == "fire" then
		Gate.ShowMarker(false)
		showCard()
		setText(touchOnly and d.textTouch or d.text)
	elseif d.kind == "hit" then
		Gate.ShowMarker(false)
		refreshPips(d.hits)
		if not d.last then
			showHit()
			if d.text then
				setText(d.text)
			end
		end
	elseif d.kind == "stop" then
		Gate.ShowMarker(false)
		Gate.MusicStop(1.5)
		Gate.SetQuestActive(false)
		hideCard()
	elseif d.kind == "done" then
		Gate.SetQuestActive(false)
		refreshPips(Cfg.Hits)
		hud.Enabled = false
		Gate.PlayUnlock()
	end
end

---------------------------------------------------------------------------------------------
-- Anime finali
---------------------------------------------------------------------------------------------
local function buildFx()
	fxFolder = Workspace:FindFirstChild("PracticeFx") or Instance.new("Folder")
	fxFolder.Name = "PracticeFx"
	fxFolder.Parent = Workspace
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "PracticeFxGui"
	fxGui.ResetOnSpawn = false
	fxGui.IgnoreGuiInset = true
	fxGui.DisplayOrder = 80
	fxGui.Parent = player:WaitForChild("PlayerGui")
end

local function flashScreen(color, a0, dur)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = a0
	f.BorderSizePixel = 0
	f.ZIndex = 50
	f.Parent = fxGui
	tween(f, dur, { BackgroundTransparency = 1 }).Completed:Once(function()
		f:Destroy()
	end)
end

local function speedLines(dur, count)
	local size = fxGui.AbsoluteSize
	local diag = math.sqrt(size.X ^ 2 + size.Y ^ 2)
	for _ = 1, count do
		local th = math.random() * math.pi * 2
		local r0, r1 = diag * (0.62 + math.random() * 0.1), diag * (0.26 + math.random() * 0.12)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = UDim2.fromOffset(math.random(2, 7), math.random(160, 420))
		line.Rotation = math.deg(th) - 90
		line.Position = UDim2.new(0.5, math.cos(th) * r0, 0.5, math.sin(th) * r0)
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 0.05
		line.BorderSizePixel = 0
		line.ZIndex = 40
		line.Parent = fxGui
		tween(line, dur, { Position = UDim2.new(0.5, math.cos(th) * r1, 0.5, math.sin(th) * r1), BackgroundTransparency = 1 }, Enum.EasingStyle.Cubic).Completed:Once(function()
			line:Destroy()
		end)
	end
end

local function sunkText()
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.4)
	holder.Size = UDim2.fromScale(0.62, 0.3)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 60
	holder.Rotation = -6
	holder.Parent = fxGui

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.58)
	bar.Size = UDim2.fromScale(0, 0.3)
	bar.BackgroundColor3 = Color3.fromRGB(190, 24, 24)
	bar.BorderSizePixel = 0
	bar.ZIndex = 59
	bar.Parent = holder
	local bs = Instance.new("UIStroke")
	bs.Color = Color3.new(1, 1, 1)
	bs.Thickness = 4
	bs.Parent = bar
	tween(bar, 0.25, { Size = UDim2.fromScale(1.15, 0.3) }, Enum.EasingStyle.Cubic)

	local function label(text, y, h, font, color, strokeColor, strokeT, z)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(1, h)
		l.BackgroundTransparency = 1
		l.Font = font
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.ZIndex = z
		l.Parent = holder
		local s = Instance.new("UIStroke")
		s.Color = strokeColor
		s.Thickness = strokeT
		s.Parent = l
		return l
	end
	local shadow = label("SUNK!", 0.4, 0.8, Enum.Font.Bangers, Color3.fromRGB(40, 0, 0), Color3.fromRGB(40, 0, 0), 10, 60)
	shadow.Position = UDim2.fromScale(0.51, 0.43)
	local big = label("SUNK!", 0.4, 0.8, Enum.Font.Bangers, Color3.new(1, 1, 1), Color3.fromRGB(150, 20, 10), 8, 61)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 230), Color3.fromRGB(255, 190, 50))
	grad.Rotation = 90
	grad.Parent = big
	local sub = label("ENEMY SHIP DESTROYED", 0.72, 0.2, Enum.Font.GothamBlack, Color3.new(1, 1, 1), Color3.fromRGB(60, 0, 0), 3, 61)

	-- vuruş: büyükten gelir, sarsılır
	holder.Size = UDim2.fromScale(1.5, 0.8)
	tween(holder, 0.22, { Size = UDim2.fromScale(0.62, 0.3), Rotation = -6 }, Enum.EasingStyle.Back)
	task.spawn(function()
		for i = 1, 10 do
			holder.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.02, 0.4 + (math.random() - 0.5) * 0.02)
			task.wait(0.03)
		end
		holder.Position = UDim2.fromScale(0.5, 0.4)
	end)
	task.delay(3.4, function()
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.6, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, 0.6, { Transparency = 1 })
			elseif d:IsA("Frame") then
				tween(d, 0.6, { BackgroundTransparency = 1 })
			end
		end
		task.delay(0.7, function()
			holder:Destroy()
		end)
	end)
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

local function playFinale(info)
	if finaleRunning then
		return
	end
	finaleRunning = true
	local F = Cfg.Finale
	local cf = info.cf
	local trainee = info.trainee
	local center = cf.Position + Vector3.new(0, 5, 0)
	local water = Vector3.new(center.X, 0.8, center.Z)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local cam = Workspace.CurrentCamera

	-- görüntü efektleri
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PracticeCC"
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "PracticeBloom"
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 30, 1.1
	bloom.Parent = Lighting
	local function neutral(t)
		tween(cc, t, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	end
	local function impactFrame()
		-- anime "vuruş karesi": siyah-beyaz, aşırı kontrast, sonra kırmızıya akar
		cc.Saturation, cc.Contrast, cc.Brightness, cc.TintColor = -1, 1.8, 0.3, Color3.new(1, 1, 1)
		flashScreen(Color3.new(1, 1, 1), 0.15, 0.5)
		task.delay(0.08, function()
			cc.Saturation, cc.Contrast, cc.Brightness, cc.TintColor = 0.6, 0.5, 0.1, Color3.fromRGB(255, 140, 110)
			neutral(0.9)
		end)
	end

	local started = os.clock()
	local savedGuis = {}
	local savedFov = cam.FieldOfView
	local cam0 = cam.CFrame
	local shake = 0
	local bars

	if trainee then
		player:SetAttribute("InCutscene", true)
		setControls(false)
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and g ~= fxGui and g ~= hud then
				savedGuis[#savedGuis + 1] = g
				g.Enabled = false
			end
		end
		hud.Enabled = false
		bars = { Instance.new("Frame"), Instance.new("Frame") }
		for i, b in bars do
			b.BackgroundColor3 = Color3.new(0, 0, 0)
			b.BorderSizePixel = 0
			b.AnchorPoint = Vector2.new(0, i - 1)
			b.Position = UDim2.fromScale(0, i - 1)
			b.Size = UDim2.fromScale(1, 0)
			b.ZIndex = 30
			b.Parent = fxGui
			tween(b, 0.5, { Size = UDim2.fromScale(1, 0.11) })
		end
		-- kamera yönetmeni
		local dir0 = Vector3.new(cam0.Position.X - center.X, 0, cam0.Position.Z - center.Z)
		dir0 = dir0.Magnitude > 1 and dir0.Unit or look:Cross(Vector3.yAxis).Unit
		local base = math.atan2(dir0.X, dir0.Z)
		local function ease3(x)
			x = math.clamp(x, 0, 1)
			return 1 - (1 - x) ^ 3
		end
		RunService:BindToRenderStep("PracticeFinaleCam", Enum.RenderPriority.Camera.Value + 5, function()
			local e = os.clock() - started
			cam.CameraType = Enum.CameraType.Scriptable
			local pos, tgt, fov, roll
			if e < 0.5 then
				pos, tgt, fov, roll = cam0.Position, center, savedFov - (savedFov - 46) * ease3(e / 0.15), 0
			elseif e < F.Main then
				local k = (e - 0.5) / (F.Main - 0.5)
				local a = base + 0.25
				local dist = 72 - 18 * k
				pos = center + Vector3.new(math.sin(a) * dist, 3.5 + 2 * k, math.cos(a) * dist)
				tgt = center + Vector3.new(0, 4, 0)
				fov, roll = 62 - 6 * k, math.rad(5)
			elseif e < F.Main + 2.4 then
				local k = ease3((e - F.Main) / 2.4)
				local a = base + 0.25 - 0.5 * k
				local dist = 54 + 90 * k
				pos = center + Vector3.new(math.sin(a) * dist, 4 + 38 * k, math.cos(a) * dist)
				tgt = center + Vector3.new(0, 12 + 6 * k, 0)
				fov, roll = 58 + 38 * math.sin(math.min(1, (e - F.Main) / 1.2) * math.pi * 0.5) - 14 * k, math.rad(5) * (1 - k)
			else
				local k = math.clamp((e - F.Main - 2.4) / (F.Total - F.Main - 2.4), 0, 1)
				local a = base - 0.25 + 1.1 * k
				local dist = 144 + 14 * k
				pos = center + Vector3.new(math.sin(a) * dist, 42 + 14 * k, math.cos(a) * dist)
				tgt = center + Vector3.new(0, 6, 0)
				fov, roll = 74, 0
			end
			shake = shake * 0.93
			local off = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, (math.random() - 0.5) * shake)
			cam.CFrame = CFrame.lookAt(pos + off, tgt) * CFrame.Angles(0, 0, roll + (math.random() - 0.5) * shake * 0.01)
			cam.FieldOfView = fov
		end)
	end

	-- t = 0: son gülle isabet etti
	task.spawn(function()
		blob(center, Color3.fromRGB(255, 220, 140), 6, 26, 0.35, 60)
		sfx3d(center, Audio.ShipBlastSmall, 0.6, 1.1, 2)
		if trainee then
			shake = 3
		end
		impactFrame()
		bloom.Intensity = 0.4
		tween(bloom, 0.6, { Intensity = 1.2 })
	end)

	-- zincirleme küçük patlamalar
	task.delay(F.Chain, function()
		for i = 1, 4 do
			task.delay((i - 1) * 0.22, function()
				local p = center + look * ((i - 2.5) * 9) + Vector3.new(math.random(-3, 3), math.random(0, 6), math.random(-3, 3))
				blob(p, i % 2 == 0 and Color3.fromRGB(255, 190, 70) or Color3.fromRGB(255, 120, 40), 4, 22 + i * 3, 0.55, 40)
				sparks(p, 24)
				sfx3d(p, Audio.ShipBlastSmall, 0.45, 0.85 + i * 0.1, 1.8)
				if trainee then
					shake = 2 + i * 0.6
				end
			end)
		end
	end)

	-- ANA PATLAMA
	task.delay(F.Main, function()
		if trainee then
			Gate.MusicStop(2.5) -- düşman battı: aksiyon müziği susar
		end
		impactFrame()
		flashScreen(Color3.new(1, 1, 1), 0, 0.9)
		if trainee then
			shake = 9
			speedLines(0.7, 36)
			task.delay(0.12, function()
				speedLines(0.6, 24)
			end)
			sunkText()
		end
		blob(center, Color3.new(1, 1, 1), 8, 70, 0.45, 160)
		blob(center, Color3.fromRGB(255, 210, 90), 14, 125, 1.0, 200)
		blob(center, Color3.fromRGB(255, 110, 40), 20, 175, 1.7, 0)
		blob(center + Vector3.new(0, 8, 0), Color3.fromRGB(120, 24, 16), 30, 150, 2.2, 0)
		ring(water, Color3.new(1, 1, 1), 420, 1.3, 1.4)
		ring(water, Color3.fromRGB(255, 160, 70), 320, 1.6, 2)
		ring(water, Color3.fromRGB(110, 210, 255), 250, 1.0, 1)
		pillar(water, Color3.fromRGB(255, 190, 80), 26, 260, 1.4)
		pillar(water, Color3.new(1, 1, 1), 10, 340, 0.9)
		starFlare(center + Vector3.new(0, 10, 0), 1.3)
		sparks(center, 160)
		debrisBurst(center, 34)
		smokePlume(center, 8)
		tween(bloom, 0.2, { Intensity = 2.4 })
		task.delay(0.3, function()
			tween(bloom, 2.4, { Intensity = 0.5 })
		end)
		if trainee then
			sfx2d(Audio.ShipBlastBig, 0.75, 1)
			sfx2d(Audio.ShipBlastLayer, 0.7, 0.9)
		else
			sfx3d(center, Audio.ShipBlastBig, 1, 1)
			sfx3d(center, Audio.ShipBlastLayer, 0.9, 0.9)
		end
		task.delay(0.45, function()
			sfx3d(center, Audio.ShipBlastFar, 0.8, 0.8)
			if trainee then
				sfx2d(Audio.ShipBlastFar, 0.45, 0.75)
			end
		end)
		-- ikinci dalga: yankı patlaması
		task.delay(0.7, function()
			blob(center + Vector3.new(0, 14, 0), Color3.fromRGB(255, 200, 120), 20, 110, 0.9, 120)
			sparks(center + Vector3.new(0, 14, 0), 80)
			sfx3d(center, Audio.ShipBlastSmall, 0.7, 0.6, 3)
			if trainee then
				shake = 5
			end
		end)
	end)

	-- bitiş
	task.delay(F.Total, function()
		pcall(function()
			RunService:UnbindFromRenderStep("PracticeFinaleCam")
		end)
		if trainee then
			for _, b in bars do
				tween(b, 0.5, { Size = UDim2.fromScale(1, 0) })
			end
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = savedFov
			for _, g in savedGuis do
				if g.Parent then
					g.Enabled = true
				end
			end
			setControls(true)
			player:SetAttribute("InCutscene", false)
			task.delay(0.6, function()
				for _, b in bars do
					b:Destroy()
				end
			end)
		end
		tween(bloom, 1, { Intensity = 0 })
		neutral(0.6)
		task.delay(1.2, function()
			cc:Destroy()
			bloom:Destroy()
			finaleRunning = false
		end)
	end)
end

function PracticeController.Init()
	Gate.Init()
	buildHud()
	buildFx()
	Remotes.Event("PracticeState").OnClientEvent:Connect(onState)
	Remotes.Event("PracticeFinale").OnClientEvent:Connect(function(info)
		local ok, err = pcall(playFinale, info)
		if not ok then
			warn("[Practice] finale hatası:", err)
			finaleRunning = false
		end
	end)
	-- Studio'da ses numaralarını doğrula (yüklenemeyen sesi Output'ta gösterir)
	if RunService:IsStudio() then
		task.spawn(function()
			for _, key in { "Cannon", "ShipHit", "ShipBlastSmall", "ShipBlastBig", "ShipBlastLayer", "ShipBlastFar", "QuestMusic", "VictorySting", "GateCreak", "ChainRattle", "BayWaterfall", "BayCave", "BayAmbience" } do
				local s = Instance.new("Sound")
				s.SoundId = Audio[key]
				s.Parent = SoundService
				pcall(function()
					ContentProvider:PreloadAsync({ s })
				end)
				local t0 = os.clock()
				while not s.IsLoaded and os.clock() - t0 < 6 do
					task.wait(0.1)
				end
				print(string.format("[Practice] ses %s loaded=%s uzunluk=%.2fs", key, tostring(s.IsLoaded), s.TimeLength))
				s:Destroy()
			end
		end)
	end
end

return PracticeController
