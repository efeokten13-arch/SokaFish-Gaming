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
