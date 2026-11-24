--!nonstrict
-- Deniz kızı görevi (client): sağdaki görev kartı + oyuncuya özel parlayan kabuk.
--  * Kart: Marina'nın 3 eşyası (Golden Fish / Glowing Shell / Diamond Necklace) ve durumları
--    (teslim edildi ✅ / elinde, götür / nerede bulunur). Karta dokununca küçülür. Sahnelerde gizlenir.
--  * Üçü de elindeyse (ya da teslim edildiyse) ok Marina'yı gösterir.
--  * Kabuk: server 4 hilal adaya birer görünmez kabuk koyar (Workspace.Atoll.QuestShells); burada sadece bu
--    oyuncunun kabuğu (data.shellSpot) görünür, döner, prompt'u açılır. Toplayınca parıltı patlaması.
-- Server: server/Map/MermaidService. Veri: DataUpdated (mermaidQuest, mqGiven, hasShell, hasNecklace, shellSpot, storage).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))
local Items = require(Shared.Config:WaitForChild("Items"))

local IslandGuide = require(script.Parent.IslandGuide)

local MermaidQuest = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 214, 80)
local GREEN = Color3.fromRGB(120, 230, 150)
local SOFT = Color3.fromRGB(200, 215, 235)

local ROWS = {
	{ id = "fish", icon = "🐟", name = "Golden Fish", hint = "Epic fish → Temple Keeper" },
	{ id = "shell", icon = "🐚", name = "Glowing Shell", hint = "Golden light, crescent isle" },
	{ id = "necklace", icon = "💎", name = "Diamond Necklace", hint = "Open treasure chests" },
}

local gui, card, title, rowLabels, body = nil, nil, nil, {}, nil
local collapsed = false
local last = nil -- önceki veri (değişimleri yakalamak için)
local pointedMarina = false

---------------------------------------------------------------------------------------------
-- Kart
---------------------------------------------------------------------------------------------
local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "MermaidQuestGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("TextButton")
	card.Name = "QuestCard"
	card.AutoButtonColor = false
	card.Text = ""
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, -12, 0.36, 0)
	card.Size = UDim2.fromOffset(236, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(18, 40, 58)
	card.BackgroundTransparency = 0.12
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(90, 200, 230)
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(120, 220, 245)
	title.Text = "🧜 Marina's Treasures"
	title.Parent = card

	body = Instance.new("Frame")
	body.LayoutOrder = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Parent = card
	local bl = Instance.new("UIListLayout")
	bl.Padding = UDim.new(0, 6)
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Parent = body

	for i, r in ROWS do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundTransparency = 1
		row.Parent = body
		local ic = Instance.new("TextLabel")
		ic.Size = UDim2.fromOffset(34, 34)
		ic.BackgroundTransparency = 1
		ic.TextScaled = true
		ic.Font = Enum.Font.GothamBold
		ic.Text = r.icon
		ic.Parent = row
		local nm = Instance.new("TextLabel")
		nm.Position = UDim2.fromOffset(42, 0)
		nm.Size = UDim2.new(1, -42, 0, 20)
		nm.BackgroundTransparency = 1
		nm.Font = Enum.Font.GothamBold
		nm.TextSize = 16
		nm.TextXAlignment = Enum.TextXAlignment.Left
		nm.TextColor3 = Color3.new(1, 1, 1)
		nm.Text = r.name
		nm.Parent = row
		local stl = Instance.new("TextLabel")
		stl.Position = UDim2.fromOffset(42, 20)
		stl.Size = UDim2.new(1, -42, 0, 18)
		stl.BackgroundTransparency = 1
		stl.Font = Enum.Font.GothamMedium
		stl.TextSize = 13
		stl.TextXAlignment = Enum.TextXAlignment.Left
		stl.TextTruncate = Enum.TextTruncate.AtEnd
		stl.Parent = row
		rowLabels[r.id] = { status = stl, row = row, icon = ic }
	end

	card.Activated:Connect(function()
		collapsed = not collapsed
		body.Visible = not collapsed
	end)
	local hint = Instance.new("TextLabel")
	hint.Name = "TapHint"
	hint.LayoutOrder = 2
	hint.Size = UDim2.new(1, 0, 0, 14)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 12
	hint.TextColor3 = Color3.fromRGB(140, 170, 195)
	hint.Text = "tap to open"
	hint.Visible = false
	hint.Parent = card
	body:GetPropertyChangedSignal("Visible"):Connect(function()
		hint.Visible = not body.Visible
	end)
end

local function pop(target)
	local s = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = target
	s.Scale = 1.25
	TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
	task.delay(5, function()
		s:Destroy()
	end)
end

-- her eşyanın durumu: "given" | "have" | "missing"
local function states(data)
	local given = data.mqGiven or {}
	local function st(id, have)
		if table.find(given, id) then
			return "given"
		end
		return have and "have" or "missing"
	end
	return {
		fish = st("fish", table.find(data.storage or {}, Items.Mermaid.QuestFish) ~= nil),
		shell = st("shell", data.hasShell),
		necklace = st("necklace", data.hasNecklace),
	}
end

-- Marina'nın konumunda yerel, görünmez bir işaret (Marina uzaktayken modeli streaming yüzünden client'ta olmayabilir)
local marinaMarker = nil
local function marinaPoint()
	local info = ReplicatedStorage:FindFirstChild("MermaidShells")
	local pos = info and info:GetAttribute("Marina")
	if typeof(pos) ~= "Vector3" then
		return nil
	end
	if not marinaMarker or not marinaMarker.Parent then
		marinaMarker = Instance.new("Part")
		marinaMarker.Name = "MarinaMarker"
		marinaMarker.Anchored = true
		marinaMarker.CanCollide = false
		marinaMarker.CanQuery = false
		marinaMarker.CanTouch = false
		marinaMarker.Transparency = 1
		marinaMarker.Size = Vector3.one
		marinaMarker.Parent = Workspace
	end
	marinaMarker.Position = pos
	return marinaMarker
end

-- bir şey değişince kart açılır, 12 sn sonra kendiliğinden küçülür (ekranı kaplamasın)
local openToken = 0
local function openForAWhile()
	collapsed = false
	body.Visible = true
	openToken += 1
	local my = openToken
	task.delay(12, function()
		if my == openToken then
			collapsed = true
			body.Visible = false
		end
	end)
end

local function refreshCard(data)
	local active = data.mermaidQuest == 1
	gui.Enabled = active and not player:GetAttribute("InCutscene")
	if not active then
		return
	end
	local now = states(data)
	local old = last and last.mermaidQuest == 1 and states(last) or nil
	local ready = true
	for _, r in ROWS do
		local l = rowLabels[r.id]
		local s = now[r.id]
		if s == "given" then
			l.status.Text = "✅ Given to Marina"
			l.status.TextColor3 = GREEN
			l.row.BackgroundTransparency = 1
		elseif s == "have" then
			l.status.Text = "✨ Got it! Bring it to Marina"
			l.status.TextColor3 = GOLD
		else
			l.status.Text = r.hint
			l.status.TextColor3 = SOFT
			ready = false
		end
		if old and old[r.id] ~= s then
			pop(l.icon)
			openForAWhile()
		end
	end
	if not (last and last.mermaidQuest == 1) then
		openForAWhile() -- görev yeni başladı / oyuna girildi
	end
	local anyHave = now.fish == "have" or now.shell == "have" or now.necklace == "have"
	if ready and anyHave then
		title.Text = "✨ Bring them to Marina!"
		title.TextColor3 = GOLD
		if not pointedMarina then
			pointedMarina = true
			local p = marinaPoint()
			if p then
				IslandGuide.Point(p, "Marina")
			end
		end
	else
		title.Text = "🧜 Marina's Treasures"
		title.TextColor3 = Color3.fromRGB(120, 220, 245)
		pointedMarina = false
	end
end

---------------------------------------------------------------------------------------------
-- Parlayan kabuk (sadece bu oyuncu görür; client çizer, server sadece görünmez dokunma noktası koyar)
---------------------------------------------------------------------------------------------
local SHELL_PINK = Color3.fromRGB(255, 196, 222)
local SHELL_GOLD = Color3.fromRGB(255, 220, 130)

local shownSpot, shellModel, spinConn = nil, nil, nil

local function sp(model, name, shape, size, cf, color, mat, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Transparency = transp or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- deniz salyangozu: şişkin pembe gövde + sarmal tepe + altın çizgiler + parlak ağız, içinde ışık, üstünde ışık sütunu
local function buildShellModel(pos)
	local m = Instance.new("Model")
	m.Name = "MyGlowingShell"
	local base = CFrame.new(pos + Vector3.new(0, 1.4, 0))
	local body = sp(m, "Body", Enum.PartType.Ball, Vector3.new(2.6, 2.2, 3.2), base, SHELL_PINK, Enum.Material.SmoothPlastic)
	body.Reflectance = 0.25
	for i, t in { { 1.9, 0.7, -0.9 }, { 1.4, 1.2, -1.4 }, { 1.0, 1.6, -1.8 }, { 0.6, 1.95, -2.1 } } do
		local r = sp(m, "Spire" .. i, Enum.PartType.Ball, Vector3.new(t[1], t[1] * 0.85, t[1]), base * CFrame.new(0, t[2] * 0.55, t[3]), i % 2 == 0 and SHELL_GOLD or SHELL_PINK, Enum.Material.SmoothPlastic)
		r.Reflectance = 0.3
	end
	for i = -1, 1 do
		local d = 2.3 - math.abs(i) * 0.4
		sp(m, "Ridge", Enum.PartType.Cylinder, Vector3.new(0.18, d, d), base * CFrame.new(0, 0.05, i * 0.75) * CFrame.Angles(0, math.rad(90), 0), SHELL_GOLD, Enum.Material.Neon, 0.2)
	end
	sp(m, "Lip", Enum.PartType.Ball, Vector3.new(1.5, 1.4, 1.2), base * CFrame.new(0, -0.1, 1.5), Color3.fromRGB(255, 120, 170), Enum.Material.Neon, 0.1)
	local core = sp(m, "Core", Enum.PartType.Ball, Vector3.new(3.2, 2.8, 3.8), base, SHELL_GOLD, Enum.Material.ForceField, 0.45)
	local light = Instance.new("PointLight")
	light.Color = SHELL_GOLD
	light.Range = 16
	light.Brightness = 2.5
	light.Parent = core
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.Color = ColorSequence.new(SHELL_GOLD, SHELL_PINK)
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	em.Lifetime = NumberRange.new(0.8, 1.4)
	em.Speed = NumberRange.new(1.5, 3)
	em.SpreadAngle = Vector2.new(180, 180)
	em.LightEmission = 1
	em.Rate = 14
	em.Parent = core
	m.PrimaryPart = body
	-- ışık sütunu ayrı (dönmesin): kabuğun 6 stud üstünden yukarı
	local pillar = sp(m, "Pillar", Enum.PartType.Cylinder, Vector3.new(160, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 88, 0)) * CFrame.Angles(0, 0, math.rad(90)), SHELL_GOLD, Enum.Material.Neon, 0.72)
	pillar.Parent = nil
	m.Parent = Workspace
	pillar.Parent = m
	return m, pillar
end

local function removeShell(burst)
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	local m = shellModel
	shellModel, shownSpot = nil, nil
	if not m then
		return
	end
	if not burst then
		m:Destroy()
		return
	end
	-- toplandı: parıltı patlaması, sonra kaybolur
	sound(Audio.RewardPop, 0.7, 1.2)
	local core = m:FindFirstChild("Core")
	local em = core and core:FindFirstChildOfClass("ParticleEmitter")
	if em then
		em:Emit(40)
		em.Rate = 0
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.5, function()
		m:Destroy()
	end)
end

local function showShell(spot)
	if shownSpot == spot and shellModel and shellModel.Parent then
		return
	end
	local info = ReplicatedStorage:FindFirstChild("MermaidShells")
	local pos = info and info:GetAttribute("Pos" .. tostring(spot))
	if typeof(pos) ~= "Vector3" then
		return
	end
	removeShell(false)
	local m, pillar = buildShellModel(pos)
	shellModel, shownSpot = m, spot
	local parts = {}
	local base = m:GetPivot()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= pillar then
			parts[d] = base:ToObjectSpace(d.CFrame)
		end
	end
	spinConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local cf = base * CFrame.new(0, math.sin(t * 2) * 0.35, 0) * CFrame.Angles(0, t * 0.8, 0)
		for part, rel in parts do
			part.CFrame = cf * rel
		end
	end)
end

-- başkalarının kabuklarında "Pick up" görünmesin (kendi kabuğu sadece arıyorsa)
local mySpot = nil
local function syncPrompt(pr)
	local hit = pr.Parent
	pr.Enabled = mySpot ~= nil and hit and hit:GetAttribute("Spot") == mySpot
end
local function syncPrompts()
	local atoll = Workspace:FindFirstChild("Atoll")
	local folder = atoll and atoll:FindFirstChild("QuestShells")
	for _, d in folder and folder:GetDescendants() or {} do
		if d:IsA("ProximityPrompt") then
			syncPrompt(d)
		end
	end
end

local function refreshShell(data)
	local need = data.mermaidQuest == 1 and not data.hasShell and not table.find(data.mqGiven or {}, "shell") and data.shellSpot
	mySpot = need and data.shellSpot or nil
	syncPrompts()
	if need then
		showShell(data.shellSpot)
	elseif shellModel then
		removeShell(data.hasShell == true and last ~= nil and not last.hasShell)
	end
end

---------------------------------------------------------------------------------------------
local function apply(data)
	if type(data) ~= "table" then
		return
	end
	refreshCard(data)
	refreshShell(data)
	last = data
end

function MermaidQuest.Init()
	build()
	Remotes.Event("DataUpdated").OnClientEvent:Connect(apply)
	player:GetAttributeChangedSignal("InCutscene"):Connect(function()
		if last then
			gui.Enabled = last.mermaidQuest == 1 and not player:GetAttribute("InCutscene")
		end
	end)
	-- kabuk konumları ve dokunma noktaları server'da sonradan kurulur / streaming ile gelip gider: gelince tekrar ayarla
	task.spawn(function()
		local info = ReplicatedStorage:WaitForChild("MermaidShells", 60)
		if info then
			info.AttributeChanged:Connect(function()
				if last then
					refreshShell(last)
				end
			end)
			if last then
				refreshShell(last)
			end
		end
	end)
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and d.Name == "ShellPrompt" then
			syncPrompt(d)
		end
	end)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok and data and not last then
			apply(data)
		end
	end)
end

return MermaidQuest
