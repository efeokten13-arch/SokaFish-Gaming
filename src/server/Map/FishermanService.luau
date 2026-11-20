--!strict
-- Old Fisherman: oyuncu ona konuşunca boş bir ada alır ve ok adasını gösterir.
-- NPC haritada (MapBuilder.Fisherman) kurulur; burada sadece konuşma mantığı var.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local MapService = require(script.Parent.MapService)
local DataService = require(script.Parent.Parent.Data.DataService)
local GuideService = require(script.Parent.Parent.Guide.GuideService)
local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))

local FishermanService = {}

local npc: Model? = nil
local sayToken = 0

local function say(text: string)
	local head = npc and npc:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("Speech")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not gui or not label then
		return
	end
	sayToken += 1
	local mine = sayToken
	label.Text = text;
	(gui :: BillboardGui).Enabled = true
	task.delay(5, function()
		if sayToken == mine then
			(gui :: BillboardGui).Enabled = false
		end
	end)
end

local function notify(player: Player, text: string, color: Color3?)
	Remotes.Event("Notify"):FireClient(player, text, color or Color3.fromRGB(120, 200, 255))
end

local function islandNumber(island: Instance): number
	return (island:GetAttribute("Index") :: number?) or 0
end

local function boatShopTarget(): BasePart?
	local pier = Workspace:FindFirstChild("Pier")
	local showroom = pier and pier:FindFirstChild("Showroom")
	local first = showroom and showroom:FindFirstChild("Rowboat") :: Model?
	return first and first.PrimaryPart
end

-- Anlatım: her satır balıkçının balonunda ve oyuncunun ekranında görünür
local function tutorial(player: Player, island: Instance)
	local n = islandNumber(island)
	local lines = {
		"Ahoy " .. player.DisplayName .. "! Island " .. n .. " is yours now.",
		"First, buy a boat at the harbor pier. The rowboat costs only $1!",
		"Then sail to your island. Follow the arrow, it will show you the way.",
		"Put the fish you catch into your island's net pool. It holds " .. Economy.PoolCapacity .. " fish and earns money every minute.",
		"Sell the rest at the Fish Market and buy bigger boats with your money. Good luck!",
	}
	local data = DataService.Get(player)
	local hasBoat = data and #(data :: any).ownedBoats > 0
	local shop = boatShopTarget()
	if not hasBoat and shop then
		Remotes.Event("GuideTarget"):FireClient(player, shop, "Boat shop")
	else
		local sp = island:FindFirstChild("Spawn")
		if sp then
			Remotes.Event("GuideTarget"):FireClient(player, sp, "Your island")
		end
	end
	for _, line in lines do
		if not player.Parent then
			return
		end
		say(line)
		notify(player, line, Color3.fromRGB(255, 244, 214))
		task.wait(4.5)
	end
end

local function onTalk(player: Player)
	local data = DataService.Get(player)
	if data and not (data :: any).introDone then
		Remotes.Event("IntroStart"):FireClient(player)
		return
	end
	local island = MapService.GetIsland(player)
	if island then
		local hasBoat = data and #(data :: any).ownedBoats > 0
		if hasBoat then
			say("Your island is number " .. islandNumber(island) .. ", " .. player.DisplayName .. ". Follow the arrow!")
			local sp = island:FindFirstChild("Spawn")
			if sp then
				Remotes.Event("GuideTarget"):FireClient(player, sp, "Your island")
			end
		else
			task.spawn(tutorial, player, island)
		end
		return
	end
	island = MapService.AssignIsland(player)
	if not island then
		say("Sorry, every island is taken. Come back later!")
		notify(player, "No free islands right now", Color3.fromRGB(255, 140, 120))
		return
	end
	if data and ((data :: any).tutorial or 0) < 1 then
		(data :: any).tutorial = 1
	end
	notify(player, "Island " .. islandNumber(island) .. " is yours!", Color3.fromRGB(120, 230, 150))
	task.spawn(tutorial, player, island)
end

-- Oyuna girişte: öğreticiyi görmemişse sinematik sohbet başlar; görmüşse adası verilir
local function onJoin(player: Player)
	local data = DataService.Wait(player)
	if not data then
		return
	end
	if not (data :: any).introDone then
		task.wait(1.2)
		if player.Parent then
			Remotes.Event("IntroStart"):FireClient(player)
		end
		return
	end
	local island = MapService.AssignIsland(player)
	if island then
		notify(player, "Welcome back! Island " .. islandNumber(island) .. " is yours", Color3.fromRGB(120, 230, 150))
	end
	GuideService.Resume(player)
end

-- Öğreticiden gelen istekler
local function onIntroAction(player: Player, action: any): any
	local data = DataService.Get(player) :: any
	if not data then
		return nil
	end
	if action == "claim" then
		local island = MapService.GetIsland(player) or MapService.AssignIsland(player)
		if not island then
			return nil
		end
		if (data.tutorial or 0) < 1 then
			data.tutorial = 1
		end
		return islandNumber(island)
	elseif action == "done" then
		if data.introDone then
			return true
		end
		data.introDone = true
		if not MapService.GetIsland(player) then
			MapService.AssignIsland(player)
		end
		-- rehber: önce Rod Shop, sonra tekne, balık tutma, havuz
		GuideService.Start(player)
		return true
	end
	return nil
end

function FishermanService.Init()
	Remotes.Function("IntroAction").OnServerInvoke = onIntroAction
	task.spawn(function()
		local found = Workspace:WaitForChild("OldFisherman", 60) :: Model?
		if not found then
			warn("[Fisherman] Workspace.OldFisherman bulunamadı (MapBuilder.Fisherman çalıştırılmadı)")
			return
		end
		npc = found
		local prompt = found:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(onTalk)
		end
		for _, p in Players:GetPlayers() do
			task.spawn(onJoin, p)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Once(function()
			onJoin(p)
		end)
	end)
end

return FishermanService
