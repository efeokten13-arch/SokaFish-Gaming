-- Sadece Studio'da çalışır: test için oyuncuya para vermek.
-- Studio'da (Server) command bar'dan:
--   game.ServerStorage.DevGiveMoney:Fire("KullanıcıAdı", 100000)
-- Canlı oyunda hiçbir şey yapmaz.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataService = require(script.Parent.Parent.Data.DataService)

local ev = ServerStorage:FindFirstChild("DevGiveMoney") or Instance.new("BindableEvent")
ev.Name = "DevGiveMoney"
ev.Parent = ServerStorage

ev.Event:Connect(function(name, amount)
	local player = Players:FindFirstChild(name) or Players:GetPlayers()[1]
	local data = player and DataService.Wait(player)
	if data and type(amount) == "number" then
		data.money += amount
		DataService.Push(player)
		DataService.Notify(player, "[Dev] +$" .. amount, Color3.fromRGB(255, 214, 80))
		print("[DevAdmin]", player.Name, "money =", data.money)
	end
end)

-- Öğreticiyi + rehberi tekrar denemek için (sadece Studio):
--   game.ServerStorage.DevResetIntro:Fire()              -> öğretici + rehber baştan (oltası/teknesi varsa o adımlar atlanır)
--   game.ServerStorage.DevResetIntro:Fire(nil, true)     -> tam yeni oyuncu: oltalar ve tekneler geçici olarak saklanır
--   game.ServerStorage.DevRestore:Fire()                 -> saklanan olta ve tekneleri geri ver
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))
local backups = {}
local function bindable(name)
	local e = ServerStorage:FindFirstChild(name) or Instance.new("BindableEvent")
	e.Name = name
	e.Parent = ServerStorage
	return e
end
bindable("DevResetIntro").Event:Connect(function(name, fresh)
	local player = (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
	local data = player and DataService.Wait(player)
	if not data then
		return
	end
	local d = data :: any
	if fresh and not backups[player.UserId] then
		backups[player.UserId] = { rods = table.clone(d.ownedRods), boats = table.clone(d.ownedBoats), rod = d.rod }
		d.ownedRods = {}
		d.ownedBoats = {}
	end
	d.introDone = false
	d.guide = 0
	DataService.Push(player)
	task.wait(0.5)
	Remotes.Event("IntroStart"):FireClient(player)
	print("[DevAdmin]", player.Name, "öğretici sıfırlandı", fresh and "(yeni oyuncu)" or "")
end)
bindable("DevRestore").Event:Connect(function(name)
	local player = (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
	local data = player and DataService.Get(player)
	local b = player and backups[player.UserId]
	if not data or not b then
		return
	end
	local d = data :: any
	for _, r in b.rods do
		if not table.find(d.ownedRods, r) then
			table.insert(d.ownedRods, r)
		end
	end
	for _, bt in b.boats do
		if not table.find(d.ownedBoats, bt) then
			table.insert(d.ownedBoats, bt)
		end
	end
	d.rod = b.rod
	d.guide = 5
	d.introDone = true
	backups[player.UserId] = nil
	DataService.Push(player)
	print("[DevAdmin]", player.Name, "olta ve tekneler geri verildi")
end)
-- oyundan çıkarken unutulursa saklananları geri koymayı dene
Players.PlayerRemoving:Connect(function(p)
	if backups[p.UserId] then
		ServerStorage.DevRestore:Fire(p.Name)
	end
end)

-- Rehber adımını elle tetikle (test): game.ServerStorage.DevGuideEvent:Fire("catch")  ("rod" / "boat" / "catch" / "pool")
local GuideService = require(script.Parent.Parent.Guide.GuideService)
bindable("DevGuideEvent").Event:Connect(function(event, name)
	local player = (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
	if player then
		if event == "catch" then
			local d = DataService.Get(player) :: any
			if d and #d.storage == 0 then
				table.insert(d.storage, "Cod")
				DataService.Push(player)
			end
		end
		GuideService.Event(player, event)
	end
end)

-- Çantaya test balığı koy (sadece Studio):
--   game.ServerStorage.DevGiveFish:Fire(nil, { "Cod", "Tuna", "GoldenFish" })   -> çanta = bu liste
--   game.ServerStorage.DevGiveFish:Fire(nil, nil, "market")                      -> ayrıca balık pazarına ışınla
bindable("DevGiveFish").Event:Connect(function(name, list, where)
	local player = (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
	local d = player and DataService.Wait(player)
	if not d then
		return
	end
	if type(list) == "table" then
		d.storage = table.clone(list)
	end
	DataService.Push(player)
	if where == "market" then
		local market = workspace:FindFirstChild("FishMarket")
		for _, x in market and market:GetDescendants() or {} do
			if x.Name == "SellCounter" and x:IsA("BasePart") and player.Character then
				player.Character:PivotTo(CFrame.new(x.Position + Vector3.new(0, 3, 8)))
				break
			end
		end
	end
	print("[DevAdmin] storage =", table.concat(d.storage, ", "))
end)

-- Deniz kızı görevi testi:
--   game.ServerStorage.DevMermaid:Fire()            -> görevi sıfırla (Marina'nın gezisi + görev baştan; anahtar silinir) ve Marina'nın yanına ışınla
--   game.ServerStorage.DevMermaid:Fire(nil, "start") -> konuşmayı atla, görevi direkt başlat
--   game.ServerStorage.DevMermaid:Fire(nil, "items") -> 3 eşyayı da ver (çantaya Golden Fish + kabuk + kolye; görev sürüyor olmalı)
--   game.ServerStorage.DevMermaid:Fire(nil, "shell") -> sadece kendi parlayan kabuğunun yanına ışınla
--   game.ServerStorage.DevMermaid:Fire(nil, "talk")  -> Marina ile konuş (E'ye basmış gibi)
local MermaidService = require(script.Parent.Parent.Map.MermaidService)
bindable("DevMermaid").Event:Connect(function(name, what)
	local player = (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
	local d = player and DataService.Wait(player) :: any
	if not d then
		return
	end
	local char = player.Character
	if what == nil or what == "reset" then
		d.mermaidDone, d.mermaidQuest, d.mqGiven, d.hasShell, d.hasNecklace, d.shellSpot, d.necklaceTries = nil, 0, {}, nil, nil, nil, 0
		d.hasGateKey = false
		player:SetAttribute("HasGateKey", false)
		local npcs = workspace:FindFirstChild("NPCs")
		local m = npcs and npcs:FindFirstChild("Mermaid Marina")
		if m and char then
			local root = m:FindFirstChild("HumanoidRootPart")
			char:PivotTo(CFrame.lookAt(root.Position + root.CFrame.LookVector * 9 + Vector3.new(0, 2, 0), root.Position))
		end
	elseif what == "start" then
		d.mermaidDone, d.mermaidQuest, d.mqGiven, d.hasShell, d.hasNecklace, d.necklaceTries = true, 1, {}, nil, nil, 0
		d.shellSpot = d.shellSpot or math.random(1, 4)
		d.hasGateKey = false
		player:SetAttribute("HasGateKey", false)
	elseif what == "items" then
		if not table.find(d.storage, "GoldenFish") then
			table.insert(d.storage, "GoldenFish")
		end
		d.hasShell, d.hasNecklace = true, true
	elseif what == "shell" then
		local f = workspace:FindFirstChild("Atoll") and workspace.Atoll:FindFirstChild("QuestShells")
		local s = f and d.shellSpot and f:FindFirstChild("GlowingShell" .. d.shellSpot)
		if s and char then
			char:PivotTo(CFrame.new(s:GetPivot().Position + Vector3.new(6, 3, 0)))
		end
	elseif what == "talk" then
		MermaidService.Talk(player)
	end
	DataService.Push(player)
	print("[DevAdmin] mermaid:", what or "reset", "quest=", d.mermaidQuest, "spot=", d.shellSpot, "given=", table.concat(d.mqGiven or {}, ","), "key=", d.hasGateKey)
end)
