--!nonstrict
-- Deniz kızı Marina (2. ada, kayanın üstünde oturur). NPC Studio'da hazır: "Workspace.NPCs.Mermaid Marina".
--  * 2. adaya ilk gelen oyuncuya sinematik öğretici başlar (client/Tutorial/MermaidIntro): adayı gezdirir, sonra
--    GÖREVİ verir: kapının anahtarı için 3 eşya getir (sıra yok, tek tek ya da hepsi birden teslim edilebilir):
--      Golden Fish (çantada; tapınaktaki fedadan ya da şansla), Glowing Shell (oyuncuya özel, 4 hilal adadan birinde),
--      Diamond Necklace (görev sürerken 2. ada sandıklarından: %50, en geç 3. sandıkta kesin; Treasure/Loot).
--  * Sonra E ile konuşunca: elindeki eşyaları teslim alır; üçü tamamsa anahtarı verir (data.hasGateKey) ve kapıya ok.
--  * Kayıt: mermaidDone (gezinti görüldü), mermaidQuest (0/1/2), mqGiven, hasShell, hasNecklace, shellSpot.
--  * Animasyonlar: oturma (döngü) + el sallama / işaret etme / sevinç (öğretici adımına göre client ister).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Items = require(ReplicatedStorage.Shared:WaitForChild("Config"):WaitForChild("Items"))
local AtollCfg = require(ReplicatedStorage.Shared.Config:WaitForChild("Atoll"))
local DataService = require(script.Parent.Parent.Data.DataService)

local MermaidService = {}

local ANIM = {
	Sit = "rbxassetid://2506281703", -- R15 oturma
	Wave = "rbxassetid://95216477066555", -- kendi el sallaması (deniz kızı için üretilmişti)
	Point = "rbxassetid://507770453", -- işaret et
	Cheer = "rbxassetid://507770677", -- sevinç
}

local root: BasePart? = nil
local head: BasePart? = nil
local tracks: { [string]: AnimationTrack } = {}
local home: CFrame? = nil
local active: { [Player]: boolean } = {} -- öğreticisi şu an oynayanlar

local function bubble(text: string, seconds: number)
	if not head then
		return
	end
	local old = head:FindFirstChild("MarinaBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "MarinaBubble"
	gui.Size = UDim2.fromOffset(300, 74)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 70
	gui.Adornee = head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(235, 248, 250)
	t.TextColor3 = Color3.fromRGB(30, 80, 110)
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 22
	t.TextWrapped = true
	t.Text = text
	t.Parent = gui
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(70, 150, 190)
	st.Thickness = 3
	st.Parent = t
	gui.Parent = head
	task.delay(seconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function gesture(name: string, seconds: number?)
	local tr = tracks[name]
	if not tr then
		return
	end
	tr.Priority = Enum.AnimationPriority.Action
	tr:Play(0.2)
	task.delay(seconds or 2.6, function()
		tr:Stop(0.3)
	end)
end

local function face(pos: Vector3?)
	if not root or not home then
		return
	end
	local target = home
	if pos then
		local look = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		if look.Magnitude > 0.1 then
			target = CFrame.lookAt(root.Position, root.Position + look)
		end
	end
	TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = target.Rotation + root.Position }):Play()
end

-- en yakın hazine sandığı (atolde)
local function nearestChest(): BasePart?
	if not root then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in CollectionService:GetTagged("TreasureChest") do
		if m:IsA("Model") and m:IsDescendantOf(Workspace) then
			local pos = m:GetPivot().Position
			if pos.X > 3000 then
				local d = (pos - root.Position).Magnitude
				if d < bestD then
					best, bestD = m, d
				end
			end
		end
	end
	return best and (best.PrimaryPart or best:FindFirstChildWhichIsA("BasePart", true))
end

local QUEST_ITEMS = { "fish", "shell", "necklace" }

local function given(data: any, item: string): boolean
	return table.find(data.mqGiven or {}, item) ~= nil
end

-- oyuncunun elinde teslim edilebilecek bir şey var mı
local function hasSomething(data: any): boolean
	if data.mermaidQuest ~= 1 then
		return false
	end
	return (not given(data, "fish") and table.find(data.storage, Items.Mermaid.QuestFish) ~= nil)
		or (not given(data, "shell") and data.hasShell == true)
		or (not given(data, "necklace") and data.hasNecklace == true)
end

-- Elindekileri teslim al. { given = {yeni teslim}, remaining = {kalanlar}, done = anahtar verildi mi }
local function handIn(player: Player, data: any)
	data.mqGiven = data.mqGiven or {}
	local now = {}
	if not given(data, "fish") then
		local i = table.find(data.storage, Items.Mermaid.QuestFish)
		if i then
			table.remove(data.storage, i)
			table.insert(now, "fish")
		end
	end
	if not given(data, "shell") and data.hasShell then
		data.hasShell = false
		table.insert(now, "shell")
	end
	if not given(data, "necklace") and data.hasNecklace then
		data.hasNecklace = false
		table.insert(now, "necklace")
	end
	for _, it in now do
		table.insert(data.mqGiven, it)
	end
	local remaining = {}
	for _, it in QUEST_ITEMS do
		if not given(data, it) then
			table.insert(remaining, it)
		end
	end
	local done = #remaining == 0
	if done then
		data.mermaidQuest = 2
		data.hasGateKey = true
		player:SetAttribute("HasGateKey", true)
	end
	DataService.Push(player)
	return { given = now, remaining = remaining, done = done }
end

local function startTutorial(player: Player)
	if active[player] then
		return
	end
	local data = DataService.Get(player) :: any
	if not data then
		return
	end
	active[player] = true
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	face(hrp and (hrp :: BasePart).Position)
	local quest = data.mermaidQuest or 0
	if not data.mermaidDone then
		Remotes.Event("MermaidStart"):FireClient(player, "intro") -- ada gezisi + görev
	elseif quest == 0 then
		Remotes.Event("MermaidStart"):FireClient(player, "quest") -- gezisi eski kayıtta görülmüş: sadece görev
	elseif quest == 1 then
		Remotes.Event("MermaidStart"):FireClient(player, "turnin", handIn(player, data))
	else
		Remotes.Event("MermaidStart"):FireClient(player, "after")
	end
	-- güvenlik: client hiç dönmezse kilit kalmasın
	task.delay(240, function()
		active[player] = nil
	end)
end

MermaidService.Talk = startTutorial -- dev komutu (DevMermaid "talk")

-- Kale kapısı (anahtarı alınca ok buraya)
local gateMarker: BasePart? = nil
local function gateTarget(): BasePart
	if gateMarker and gateMarker.Parent then
		return gateMarker
	end
	-- streaming açık: uzaktaki parça client'a gelmez ve ok boş kalır. Persistent model hep yüklü kalır.
	local holder = Instance.new("Model")
	holder.Name = "GateMarker"
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local p = Instance.new("Part")
	p.Name = "Marker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = Vector3.new(4562, 6, -881)
	p.Parent = holder
	holder.PrimaryPart = p
	holder.Parent = Workspace
	gateMarker = p
	return p
end

local function arrow(player: Player, part: BasePart?, label: string?, seconds: number)
	Remotes.Event("GuideTarget"):FireClient(player, part, label)
	if part then
		task.delay(seconds, function()
			if player.Parent then
				Remotes.Event("GuideTarget"):FireClient(player, nil)
			end
		end)
	end
end

-- Client'tan: ("mermaid", "Wave"|"Point"|"Cheer") jest | ("mermaid", "done") bitti
function MermaidService.Action(player: Player, what: any): any
	if what == "Wave" or what == "Point" or what == "Cheer" then
		gesture(what, 2.8)
		return true
	elseif what == "done" then
		local data = DataService.Get(player) :: any
		active[player] = nil
		face(nil)
		gesture("Cheer", 2.5)
		if not data then
			return true
		end
		data.mermaidDone = true
		if (data.mermaidQuest or 0) == 0 then
			-- görev başlar: kabuk bu oyuncu için rastgele bir hilal adada
			data.mermaidQuest = 1
			data.mqGiven = {}
			data.necklaceTries = 0
			data.shellSpot = math.random(1, #AtollCfg.Crescents)
			DataService.Push(player)
		end
		if data.mermaidQuest == 2 then
			arrow(player, gateTarget(), "Castle Gate", 240)
		elseif not given(data, "necklace") and not data.hasNecklace then
			local chest = nearestChest()
			if chest then
				arrow(player, chest, "Treasure chest", 90)
			end
		end
		return true
	end
	return nil
end

local function setup(model: Model)
	root = model:WaitForChild("HumanoidRootPart") :: BasePart
	head = model:WaitForChild("Head") :: BasePart
	home = root.CFrame
	-- client'ın oku için (Marina uzaktayken streaming yüzünden modeli client'ta olmayabilir)
	local info = ReplicatedStorage:FindFirstChild("MermaidShells") or Instance.new("Folder")
	info.Name = "MermaidShells"
	info:SetAttribute("Marina", root.Position + root.CFrame.LookVector * 3.2)
	info.Parent = ReplicatedStorage
	local hum = model:WaitForChild("Humanoid") :: Humanoid
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local old = model:FindFirstChild("NPCAnimator") -- eski "sürekli el sallar" betiği
	if old then
		old:Destroy()
	end
	for _, t in animator:GetPlayingAnimationTracks() do
		t:Stop(0)
	end
	for name, id in ANIM do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, tr = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and tr then
			tracks[name] = tr
		end
	end
	if tracks.Sit then
		tracks.Sit.Looped = true
		tracks.Sit.Priority = Enum.AnimationPriority.Idle
		tracks.Sit:Play()
	end

	-- konuşma düğmesi: yüzünün önünde görünmez nokta
	local pt = Instance.new("Part")
	pt.Name = "TalkPoint"
	pt.Size = Vector3.new(2, 4, 2)
	pt.Transparency = 1
	pt.Anchored = true
	pt.CanCollide = false
	pt.CanTouch = false
	pt.CanQuery = false
	pt.CFrame = CFrame.new(root.Position + root.CFrame.LookVector * 3.2)
	pt.Parent = model
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "TalkPrompt"
	pr.ObjectText = "Marina the Mermaid"
	pr.ActionText = "Talk"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.Parent = pt
	pr.Triggered:Connect(startTutorial)

	-- yaklaşan oyuncu: öğreticiyi görmediyse sinematik başlar; gördüyse sadece selam (3 dk'da bir)
	local seen: { [Player]: number } = {}
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local data = DataService.Get(p) :: any
			if hrp and data and data.introDone and not active[p] and (hrp.Position - root.Position).Magnitude < 45 then
				if not data.mermaidDone then
					if os.clock() - (seen[p] or -999) > 30 then
						seen[p] = os.clock()
						startTutorial(p)
					end
				elseif (hrp.Position - root.Position).Magnitude < 30 and os.clock() - (seen[p] or -999) > (hasSomething(data) and 40 or 180) then
					seen[p] = os.clock()
					face(hrp.Position)
					local msg = if hasSomething(data)
						then "Ooh, " .. p.DisplayName .. "! Did you bring me something? Talk to me (E)"
						elseif data.mermaidQuest == 1 then "Still searching, " .. p.DisplayName .. "? Talk to me (E)"
						else "Hello, " .. p.DisplayName .. "! Come talk to me (E)"
					bubble(msg, 5)
					gesture("Wave", 3)
					task.delay(5, function()
						face(nil)
					end)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		seen[p] = nil
		active[p] = nil
	end)
end


-- Parlayan kabuklar ---------------------------------------------------------------------------------------------
-- Her hilal adada bir GÖRÜNMEZ dokunma noktası ("Pick up" prompt'u). Kabuğun kendisini client çizer, sadece o oyuncunun
-- kabuğunu (shellSpot) ve sadece onun prompt'unu gösterir (client/Map/MermaidQuest). Oyunda streaming açık olduğu için
-- görüntü server parçalarına bağlı değil: konumlar ReplicatedStorage.MermaidShells attribute'larında (Pos1..Pos4).
-- Server kimin kabuğu olduğunu ayrıca kontrol eder.
local SHELL_GOLD = Color3.fromRGB(255, 220, 130)

local function landAt(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	if hit and hit.Material ~= Enum.Material.Water and hit.Position.Y > 0.6 and hit.Position.Y < 12 then
		return hit.Position
	end
	return nil
end

local function shellSpotPos(arc: { { number } }): Vector3?
	local O, S, C = AtollCfg.Origin, AtollCfg.Scale, AtollCfg.Center
	local mid = math.ceil(#arc / 2)
	local order = { mid, mid + 1, mid - 1, mid + 2, mid - 2, 1, #arc }
	for _, k in order do
		local pt = arc[k]
		if pt then
			local x, z = O.X + (pt[1] - C[1]) * S, O.Z + (pt[2] - C[2]) * S
			for _, off in { Vector2.zero, Vector2.new(8, 0), Vector2.new(-8, 0), Vector2.new(0, 8), Vector2.new(0, -8), Vector2.new(14, 14), Vector2.new(-14, -14) } do
				local pos = landAt(x + off.X, z + off.Y)
				if pos then
					return pos
				end
			end
		end
	end
	return nil
end

local function buildShell(index: number, pos: Vector3, parent: Instance)
	local hit = Instance.new("Part")
	hit.Name = "GlowingShell" .. index
	hit:SetAttribute("Spot", index)
	hit.Size = Vector3.new(4, 4, 4)
	hit.Position = pos + Vector3.new(0, 1.4, 0)
	hit.Anchored = true
	hit.CanCollide = false
	hit.CanTouch = false
	hit.CanQuery = false
	hit.Transparency = 1
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "ShellPrompt"
	pr.ActionText = "Pick up"
	pr.ObjectText = "Glowing Shell"
	pr.HoldDuration = 0.6
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.Enabled = true -- server'da açık olmalı (kapalı prompt'u server yok sayar); client başkalarınınkini kapatır
	pr.Parent = hit
	pr.Triggered:Connect(function(player)
		local data = DataService.Get(player) :: any
		if not data or data.mermaidQuest ~= 1 or data.shellSpot ~= index or data.hasShell or given(data, "shell") then
			return
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp or (hrp.Position - hit.Position).Magnitude > 20 then
			return
		end
		data.hasShell = true
		DataService.Push(player)
		DataService.Notify(player, "🐚 You found the Glowing Shell! Bring it to Marina.", SHELL_GOLD)
	end)
	hit.Parent = parent
end

local function buildShells()
	local atoll = Workspace:WaitForChild("Atoll", 60)
	if not atoll then
		return
	end
	local old = atoll:FindFirstChild("QuestShells")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "QuestShells"
	local info = ReplicatedStorage:FindFirstChild("MermaidShells") or Instance.new("Folder")
	info.Name = "MermaidShells"
	info.Parent = ReplicatedStorage
	for i, arc in AtollCfg.Crescents do
		local pos = shellSpotPos(arc)
		if pos then
			buildShell(i, pos, folder)
			info:SetAttribute("Pos" .. i, pos)
		else
			warn("[Mermaid] hilal ada " .. i .. " için kabuk yeri bulunamadı")
		end
	end
	folder.Parent = atoll
end

function MermaidService.Init()
	task.spawn(buildShells)
	gateTarget() -- baştan kur: ok gönderildiği anda client'ta hazır olsun
	Players.PlayerAdded:Connect(function(p)
		local data = DataService.Wait(p) :: any
		if data and data.hasGateKey then
			p:SetAttribute("HasGateKey", true)
		end
	end)
	task.spawn(function()
		local folder = Workspace:WaitForChild("NPCs", 60)
		local m = folder and folder:WaitForChild("Mermaid Marina", 30)
		if m then
			setup(m)
		else
			warn("[Mermaid] Workspace.NPCs['Mermaid Marina'] bulunamadı")
		end
	end)
end

return MermaidService
