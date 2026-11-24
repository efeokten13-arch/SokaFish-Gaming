--!nonstrict
-- Deniz kızı Marina'nın 2. ada öğreticisi (Old Finn'inkiyle aynı tarz): kamera ona yaklaşır, sohbet + cevap butonları,
-- sonra adanın önemli yerlerini uzaktan gezdirir (hazine adası, tapınak, dalış yeri, kale kapısı) ve GÖREVİ verir.
-- Server (server/Map/MermaidService) "MermaidStart"(mod, bilgi) gönderir; bitince "mermaid","done" döner. Modlar:
--   "intro"  = ilk geliş: gezinti + görev     "quest" = sadece görev (gezintiyi önceden görmüş eski kayıt)
--   "turnin" = teslim (bilgi: given / remaining / done) -> üçü tamamsa anahtar sahnesi    "after" = anahtar alındı
-- Metinler aşağıdaki SCRIPT tablosunda; sırayı ve yazıları oradan değiştirin. gesture = deniz kızının animasyonu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))
local AtollCfg = require(Shared:WaitForChild("Config"):WaitForChild("Atoll"))

local MermaidIntro = {}

local player = Players.LocalPlayer
local NAME = "Marina"
local running = false

---------------------------------------------------------------------------------------------
-- Kamera çekimleri
---------------------------------------------------------------------------------------------
local function atoll(px, py)
	local O, S, C = AtollCfg.Origin, AtollCfg.Scale, AtollCfg.Center
	return Vector3.new(O.X + (px - C[1]) * S, 0, O.Z + (py - C[2]) * S)
end

local function marinaHead()
	local npcs = Workspace:FindFirstChild("NPCs")
	local m = npcs and npcs:FindFirstChild("Mermaid Marina")
	return m and m:FindFirstChild("Head"), m
end

-- bir noktanın çevresinde yavaşça dönen çekim
local function orbit(center, radius, height, startDeg, speed, lookY)
	return function(t)
		local a = math.rad(startDeg) + t * speed
		local c = Vector3.new(center.X, lookY or 8, center.Z)
		return CFrame.lookAt(c + Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius), c)
	end
end

local SHOTS = {}
SHOTS.marina = function(t)
	local head, m = marinaHead()
	if not head then
		return nil
	end
	local look = m.HumanoidRootPart.CFrame.LookVector
	local front = Vector3.new(look.X, 0, look.Z).Unit
	local side = front:Cross(Vector3.yAxis)
	local eye = head.Position + front * 8 + side * 2.4 + Vector3.new(0, 0.9 + math.sin(t * 0.8) * 0.15, 0)
	return CFrame.lookAt(eye, head.Position + Vector3.new(0, -2.4, 0))
end
SHOTS.overview = function(t)
	local head = marinaHead()
	local c = head and head.Position or Vector3.new(4881, 12, -70)
	return orbit(c, 120, 62, 20, 0.05, c.Y)(t)
end
SHOTS.treasure = orbit(atoll(AtollCfg.TreasureIsland.x, AtollCfg.TreasureIsland.y), 95, 48, 200, 0.06, 8)
SHOTS.temple = orbit(atoll(AtollCfg.MainTemple.temple[1], AtollCfg.MainTemple.temple[2]), 190, 100, 30, 0.04, 20)
SHOTS.ship = orbit(atoll(AtollCfg.BigShip.x, AtollCfg.BigShip.y), 70, 34, 110, 0.06, -4)
SHOTS.gate = orbit(Vector3.new(4562, 0, -881), 170, 75, 60, 0.04, 20)

---------------------------------------------------------------------------------------------
-- Sohbet metni. choices: { {yazı, sonraki adım} }; gesture: adım başlarken Marina'nın animasyonu
---------------------------------------------------------------------------------------------
local SCRIPT = {
	start = {
		shot = "marina",
		gesture = "Wave",
		text = "Splash! Welcome to Mermaid Island, little sailor! I'm Marina, guardian of these waters.",
		choices = { { "Wow! A real mermaid!", "sea" }, { "Where am I?", "sea" } },
	},
	sea = {
		shot = "overview",
		text = "This whole sea is shared by every sailor. The fish here are different from the ones back home, so keep your Collection Book handy!",
		choices = { { "Cool!", "chest" } },
	},
	chest = {
		shot = "treasure",
		gesture = "Point",
		text = "Treasure chests are hidden on islands like this one. Hold E next to a chest to open it and win gold, pearls and more!",
		choices = { { "Treasure! Yes!", "temple" } },
	},
	temple = {
		shot = "temple",
		text = "In the middle of the sea stands the Ancient Temple. Brave sailors explore it and the little islands around it.",
		choices = { { "Sounds exciting!", "dive" } },
	},
	dive = {
		shot = "ship",
		gesture = "Point",
		text = "Take a deep breath and dive! A flooded ship and the bones of a giant sea monster rest on the seabed.",
		choices = { { "I'm ready to dive!", "gate" } },
	},
	gate = {
		shot = "gate",
		text = "Far away stands the Castle Gate. It leads to Island 3, but it's sealed... and I'm the one who holds the key!",
		choices = { { "Can I have it?", "quest" } },
	},
	-- görev ("quest" modu buradan başlar)
	quest = {
		shot = "marina",
		gesture = "Wave",
		text = "Bring me three treasures and the Gate Key is yours: a GOLDEN FISH, my GLOWING SHELL and my DIAMOND NECKLACE!",
		choices = { { "Where do I find them?", "where" } },
	},
	where = {
		shot = "temple",
		gesture = "Point",
		text = "Offer an EPIC fish to the Temple Keeper. His blessing brings you a Golden Fish!",
		choices = { { "And your shell?", "shellwhere" } },
	},
	shellwhere = {
		shot = "temple",
		text = "My shell glows with golden light on one of the crescent islands around the Temple.",
		choices = { { "And the necklace?", "necklace" } },
	},
	necklace = {
		shot = "treasure",
		text = "A sneaky pirate hid my necklace in a treasure chest of this sea. Open chests until you find it!",
		choices = { { "I'll find all three!", "bye" } },
	},
	bye = {
		shot = "marina",
		gesture = "Cheer",
		text = "Bring them in any order, one by one or all together. Follow the arrow to a chest. Good luck!",
		choices = { { "Let's go!", nil } },
	},
}

-- teslim / anahtar konuşmaları (server'dan gelen bilgiye göre kurulur)
local ITEM_NAME = { fish = "Golden Fish 🐟", shell = "Glowing Shell 🐚", necklace = "Diamond Necklace 💎" }
local ITEM_TIP = {
	fish = "Golden Fish: offer an EPIC fish to the Temple Keeper, then cast. Keep it in your backpack!",
	shell = "Glowing Shell: look for the golden light on a crescent island near the Temple.",
	necklace = "Diamond Necklace: it's hidden in a treasure chest of this sea. Keep opening chests!",
}

local function joinNames(list)
	local names = {}
	for _, it in list do
		table.insert(names, ITEM_NAME[it] or it)
	end
	if #names <= 1 then
		return names[1] or ""
	end
	return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

local function turninScript(info)
	local nodes = {}
	local given, remaining = info.given or {}, info.remaining or {}
	-- ipucu zinciri: kalan her eşya için bir cümle
	local firstTip = nil
	for i = #remaining, 1, -1 do
		local it = remaining[i]
		nodes["tip_" .. it] = {
			shot = "marina",
			text = ITEM_TIP[it],
			choices = { { i < #remaining and "Next tip" or "On my way!", firstTip } },
		}
		firstTip = "tip_" .. it
	end
	nodes.need = {
		shot = "marina",
		gesture = #given == 0 and "Point" or nil,
		text = (#given == 0 and "Hmm, you don't have any of my treasures yet. " or "") .. "I still need my " .. joinNames(remaining) .. ".",
		choices = { { "On my way!", nil }, { "Any tips?", firstTip } },
	}
	if info.done then
		nodes.thanks = {
			shot = "marina",
			gesture = "Cheer",
			text = "My " .. joinNames(given) .. "! That's all three treasures! You did it, sailor!",
			choices = { { "Yay!", "key" } },
		}
		nodes.key = {
			shot = "marina",
			gesture = "Wave",
			fx = "key",
			text = "As promised, here is the GATE KEY. Keep it safe!",
			choices = { { "Thank you, Marina!", "go" } },
		}
		nodes.go = {
			shot = "gate",
			text = "Sail to the Castle Gate and it will open for you. Adventure awaits on Island 3!",
			choices = { { "Aye aye!", nil } },
		}
		return nodes, "thanks"
	end
	if #given > 0 then
		nodes.thanks = {
			shot = "marina",
			gesture = "Cheer",
			text = "Oh! My " .. joinNames(given) .. "! Thank you, sailor!",
			choices = { { "You're welcome!", "need" } },
		}
		return nodes, "thanks"
	end
	return nodes, "need"
end

local AFTER = {
	go = {
		shot = "marina",
		gesture = "Wave",
		text = "You have the Gate Key, sailor! Sail to the Castle Gate and it will open for you.",
		choices = { { "Aye aye!", nil } },
	},
}

---------------------------------------------------------------------------------------------
-- Arayüz
---------------------------------------------------------------------------------------------
local gui, panel, textLabel, choiceRow, bars = nil, nil, nil, nil, {}

local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "MermaidIntroGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	for i, y in { 0, 1 } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, y)
		b.Position = UDim2.fromScale(0, y)
		b.Size = UDim2.new(1, 0, 0, 0)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = gui
		bars[i] = b
	end

	panel = Instance.new("Frame")
	panel.Name = "Dialog"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.new(0.9, 0, 0, 170)
	panel.BackgroundColor3 = Color3.fromRGB(236, 250, 252)
	panel.BackgroundTransparency = 0.04
	panel.Parent = gui
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(760, 220)
	size.Parent = panel
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(70, 150, 190)
	st.Thickness = 4
	st.Parent = panel

	local nameTag = Instance.new("TextLabel")
	nameTag.AnchorPoint = Vector2.new(0, 0.5)
	nameTag.Position = UDim2.new(0, 22, 0, 0)
	nameTag.Size = UDim2.fromOffset(150, 38)
	nameTag.BackgroundColor3 = Color3.fromRGB(40, 130, 170)
	nameTag.Font = Enum.Font.FredokaOne
	nameTag.TextSize = 22
	nameTag.TextColor3 = Color3.new(1, 1, 1)
	nameTag.Text = "🧜 " .. NAME
	nameTag.Parent = panel
	Instance.new("UICorner", nameTag).CornerRadius = UDim.new(0, 12)

	textLabel = Instance.new("TextLabel")
	textLabel.Position = UDim2.new(0, 24, 0, 26)
	textLabel.Size = UDim2.new(1, -48, 1, -92) -- cevap butonlarının üstündeki tüm alan
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextSize = 24
	textLabel.TextScaled = true -- uzun cümle dar ekranda küçülür, kesilmez
	textLabel.TextWrapped = true
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 24
	tsc.MinTextSize = 14
	tsc.Parent = textLabel
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextColor3 = Color3.fromRGB(30, 70, 95)
	textLabel.Parent = panel

	choiceRow = Instance.new("Frame")
	choiceRow.Name = "Choices"
	choiceRow.AnchorPoint = Vector2.new(1, 1)
	choiceRow.Position = UDim2.new(1, -18, 1, -16)
	choiceRow.Size = UDim2.new(1, -36, 0, 48)
	choiceRow.BackgroundTransparency = 1
	choiceRow.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, 12)
	list.Parent = choiceRow
end

local function setBars(on)
	for _, b in bars do
		TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, on and 0.09 or 0, 0) }):Play()
	end
end

local function sound(id, volume, pitch)
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
end

local function typeText(text)
	local skip = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space then
			skip = true
		end
	end)
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	for i = 1, utf8.len(text) or #text do
		if skip then
			break
		end
		textLabel.MaxVisibleGraphemes = i
		task.wait(0.028)
	end
	textLabel.MaxVisibleGraphemes = -1
	conn:Disconnect()
end

local function askChoices(choices)
	for _, c in choiceRow:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local picked = nil
	local ev = Instance.new("BindableEvent")
	for i, ch in choices do
		local b = Instance.new("TextButton")
		b.Name = "Choice" .. i
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 46)
		b.BackgroundColor3 = i == 1 and Color3.fromRGB(70, 170, 120) or Color3.fromRGB(40, 130, 170)
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 22
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = ch[1]
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
		pad.Parent = b
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
		local s = Instance.new("UIStroke")
		s.Color = Color3.new(1, 1, 1)
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = b
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		b.Parent = choiceRow
		b.Activated:Connect(function()
			if picked == nil then
				picked = ch
				ev:Fire()
			end
		end)
	end
	ev.Event:Wait()
	ev:Destroy()
	sound(Audio.Click, 0.5)
	for _, c in choiceRow:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	return picked[2]
end

---------------------------------------------------------------------------------------------
-- Kamera sürücü + dondurma
---------------------------------------------------------------------------------------------
local camConn
local shotName, shotStart = nil, 0
local fromCF, blendStart, BLEND = nil, 0, 1.8

local function setShot(name)
	fromCF = Workspace.CurrentCamera.CFrame
	blendStart = os.clock()
	shotName = name
	shotStart = os.clock()
end

local function startCamera()
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	camConn = RunService.RenderStepped:Connect(function()
		local fn = shotName and SHOTS[shotName]
		local target = fn and fn(os.clock() - shotStart)
		if not target then
			return
		end
		local a = math.clamp((os.clock() - blendStart) / BLEND, 0, 1)
		a = a * a * (3 - 2 * a)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = fromCF and fromCF:Lerp(target, a) or target
	end)
end

local function stopCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local back = CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
		local tw = TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = back })
		tw:Play()
		tw.Completed:Wait()
	end
	cam.CameraType = Enum.CameraType.Custom
end

local hidden, frozen = {}, nil
local function freeze(on)
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if pm then
		local ok, mod = pcall(require, pm)
		local ctl = ok and mod and mod.GetControls and mod:GetControls()
		if ctl then
			if on then
				ctl:Disable()
			else
				ctl:Enable()
			end
		end
	end
	player:SetAttribute("InCutscene", on)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on and hum then
		frozen = { hum = hum, walk = hum.WalkSpeed, jump = hum.JumpPower, jh = hum.JumpHeight }
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	elseif not on and frozen then
		if frozen.hum.Parent then
			frozen.hum.WalkSpeed, frozen.hum.JumpPower, frozen.hum.JumpHeight = frozen.walk, frozen.jump, frozen.jh
		end
		frozen = nil
	end
	if player.Character then
		for _, d in player.Character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = on and 1 or 0
			end
		end
	end
	local pg = player:FindFirstChild("PlayerGui")
	if on then
		hidden = {}
		for _, g in pg and pg:GetChildren() or {} do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
	else
		for _, g in hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
		hidden = {}
	end
end

---------------------------------------------------------------------------------------------
-- Akış
---------------------------------------------------------------------------------------------
-- Anahtar sahnesi: ekranın ortasında dönen ışınlar + büyük anahtar, sonra yukarı uçup kaybolur
local function keyReward()
	local g = Instance.new("Frame")
	g.Name = "KeyReward"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.4)
	g.Size = UDim2.fromOffset(320, 320)
	g.BackgroundTransparency = 1
	g.ZIndex = 20
	g.Parent = gui
	-- ışınlar: ortadan geçen ince çubuklar (her biri kendi etrafında döner)
	local rays = {}
	for i = 1, 8 do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.45)
		b.Size = UDim2.fromOffset(30, 420)
		b.BackgroundColor3 = Color3.fromRGB(255, 214, 90)
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.Rotation = i * 22.5
		b.ZIndex = 20
		local gr = Instance.new("UIGradient")
		gr.Rotation = 90
		gr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gr.Parent = b
		b.Parent = g
		table.insert(rays, b)
	end
	local icon = Instance.new("TextLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.45)
	icon.Size = UDim2.fromOffset(170, 170)
	icon.BackgroundTransparency = 1
	icon.Text = "🔑"
	icon.TextColor3 = Color3.fromRGB(255, 200, 60) -- Roblox bu emojiyi tek renk çiziyor: altın yap
	icon.TextStrokeColor3 = Color3.fromRGB(120, 70, 10)
	icon.TextStrokeTransparency = 0.2
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.ZIndex = 22
	icon.Parent = g
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.8)
	title.Size = UDim2.fromOffset(320, 50)
	title.BackgroundTransparency = 1
	title.Text = "GATE KEY"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 44
	title.TextColor3 = Color3.fromRGB(255, 214, 80)
	title.TextStrokeTransparency = 0.2
	title.ZIndex = 22
	title.Parent = g
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = g
	sound(Audio.ChestFanfareBig or Audio.ChestFanfare, 0.6)
	TweenService:Create(sc, TweenInfo.new(0.55, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	for _, b in rays do
		TweenService:Create(b, TweenInfo.new(0.5), { BackgroundTransparency = 0.35 }):Play()
	end
	local spin = RunService.RenderStepped:Connect(function(dt)
		for _, b in rays do
			b.Rotation += dt * 35
		end
		icon.Rotation = math.sin(os.clock() * 3) * 10
	end)
	return function()
		TweenService:Create(g, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, -0.2) }):Play()
		TweenService:Create(sc, TweenInfo.new(0.5), { Scale = 0.3 }):Play()
		task.delay(0.55, function()
			spin:Disconnect()
			g:Destroy()
		end)
	end
end

local function run(mode, info)
	-- yolculuk animasyonu (SailCinematic) bitene kadar bekle, sonra başla
	local t0 = os.clock()
	while player:GetAttribute("InCutscene") and os.clock() - t0 < 6 do
		task.wait(0.1)
	end
	if running or player:GetAttribute("InCutscene") then
		return
	end
	mode = mode or "intro"
	local nodes, step = SCRIPT, "start"
	if mode == "quest" then
		step = "quest"
	elseif mode == "turnin" then
		nodes, step = turninScript(info or {})
	elseif mode == "after" then
		nodes, step = AFTER, "go"
	end
	running = true
	gui.Enabled = true
	panel.Visible = false
	freeze(true)
	startCamera()
	setBars(true)
	if mode == "intro" then
		setShot("overview")
		BLEND = 1.2
		task.wait(1.4)
	else
		BLEND = 1.0
		setShot("marina")
		task.wait(1.0)
	end
	BLEND = 1.8

	local closeKey = nil
	while step do
		local node = nodes[step]
		if not node then
			break
		end
		if node.shot ~= shotName then
			setShot(node.shot)
			if node.shot ~= "marina" then
				panel.Visible = false
				task.wait(1.3) -- uzaktaki yere uçuş
			end
		end
		if node.gesture then
			task.spawn(function()
				pcall(function()
					Remotes.Function("IntroAction"):InvokeServer("mermaid", node.gesture)
				end)
			end)
		end
		if node.fx == "key" and closeKey == nil then
			closeKey = keyReward()
		end
		panel.Visible = true
		sound(Audio.Splash, 0.35, 1.3 + math.random() * 0.2)
		typeText(node.text)
		step = askChoices(node.choices)
		if closeKey then
			closeKey()
			closeKey = false -- anahtar sahnesi bir kez
		end
	end

	panel.Visible = false
	setBars(false)
	pcall(function()
		Remotes.Function("IntroAction"):InvokeServer("mermaid", "done")
	end)
	stopCamera()
	freeze(false)
	gui.Enabled = false
	running = false
end

function MermaidIntro.Init()
	buildUI()
	Remotes.Event("MermaidStart").OnClientEvent:Connect(function(mode, info)
		task.spawn(run, mode, info)
	end)
end

return MermaidIntro
