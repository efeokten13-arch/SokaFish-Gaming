--!strict
-- Sol taraftaki ışınlanma butonları: "Island" = kendi adan, "Main" = ana ada (plaza).
-- Client sadece istek gönderir, nereye gidileceğine server karar verir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Movement = require(Shared:WaitForChild("Config"):WaitForChild("Movement"))
local DataService = require(script.Parent.Parent.Data.DataService)
local MapService = require(script.Parent.MapService)
local BoatService = require(script.Parent.Parent.Boat.BoatService)

local TeleportService = {}

local lastUse: { [Player]: number } = {}

local function notify(player: Player, text: string)
	Remotes.Event("Notify"):FireClient(player, text, Color3.fromRGB(255, 140, 120))
end

local function destination(player: Player, kind: string): CFrame?
	if kind == "Island" then
		local island = MapService.GetIsland(player)
		local spawnPart = island and island:FindFirstChild("Spawn") :: BasePart?
		if spawnPart then
			return spawnPart.CFrame + Vector3.new(0, 4, 0)
		end
		notify(player, "Talk to the Old Fisherman to claim an island")
		local npc = Workspace:FindFirstChild("OldFisherman")
		local torso = npc and npc:FindFirstChild("Torso")
		if torso then
			Remotes.Event("GuideTarget"):FireClient(player, torso, "Old Finn")
		end
		return nil
	elseif kind == "Market" then
		-- balık pazarının ada tarafındaki tezgahının önü, pazara bakarak
		local market = Workspace:FindFirstChild("FishMarket")
		local plat = market and market:FindFirstChild("Platform") :: BasePart?
		if plat then
			local front = plat.Position + Vector3.new(0, 4, plat.Size.Z / 2 - 2)
			return CFrame.lookAt(front, plat.Position + Vector3.new(0, 4, 0))
		end
	elseif kind == "Main" then
		local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
		if sp then
			return sp.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

local function teleport(player: Player, kind: any)
	if typeof(kind) ~= "string" then
		return
	end
	-- öğretici bitmeden ışınlanma yok
	local d = DataService.Get(player) :: any
	if d and not d.introDone then
		return
	end
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < Movement.TeleportCooldown then
		notify(player, "Teleport is cooling down")
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return
	end
	local cf = destination(player, kind)
	if not cf then
		return
	end
	lastUse[player] = now
	-- kayıktaysa önce kayıktan indir
	if hum.SeatPart then
		hum.Sit = false
		task.wait(0.1)
	end
	char:PivotTo(cf)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	-- adaya gidince tekne de adanın iskelesine gelir
	if kind == "Island" then
		local island = MapService.GetIsland(player)
		if island then
			BoatService.BringToDock(player, island)
		end
	end
end

function TeleportService.Init()
	Remotes.Event("TeleportRequest").OnServerEvent:Connect(teleport)
	Players.PlayerRemoving:Connect(function(p)
		lastUse[p] = nil
	end)
end

return TeleportService
