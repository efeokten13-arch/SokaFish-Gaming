--!strict
-- Korsan haritasından yolculuk isteği: kilidi server kontrol eder, sonra oyuncuyu ışınlar.
-- Kendi RemoteEvent'ini kullanır (ReplicatedStorage.SeaMapRemotes.Travel); diğer sistemlere dokunmaz.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local SeaMap = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SeaMap"))
local DataService = require(script.Parent.Parent.Data.DataService)
local BoatService = require(script.Parent.Parent.Boat.BoatService)

local SeaMapService = {}

local COOLDOWN = 5
local last: { [Player]: number } = {}
local RED = Color3.fromRGB(255, 140, 120)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local function destination(isl: any): CFrame?
	if isl.travel == "Main" then
		local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
		return sp and (sp.CFrame + Vector3.new(0, 4, 0))
	elseif isl.travel == "Dest" then
		local folder = Workspace:FindFirstChild("SeaMapDestinations")
		local part = folder and folder:FindFirstChild(isl.id)
		if part and part:IsA("BasePart") then
			return part.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

-- Teknenin geleceği yer: Main -> iskele BoatSpawn; Dest -> SeaMapDestinations.<id>_Boat
local function boatDestination(isl: any): CFrame?
	local part
	if isl.travel == "Main" then
		local pier = Workspace:FindFirstChild("Pier")
		part = pier and pier:FindFirstChild("BoatSpawn")
	elseif isl.travel == "Dest" then
		local folder = Workspace:FindFirstChild("SeaMapDestinations")
		part = folder and folder:FindFirstChild(isl.id .. "_Boat")
	end
	if part and part:IsA("BasePart") then
		return CFrame.new(part.Position.X, 0.65, part.Position.Z) * part.CFrame.Rotation
	end
	return nil
end

local function travel(player: Player, id: any)
	if typeof(id) ~= "string" then
		return
	end
	local isl = SeaMap.Get(id)
	local data = DataService.Get(player)
	if not isl or not data then
		return
	end
	if SeaMap.BoatLevel((data :: any).ownedBoats) < isl.level then
		DataService.Notify(player, (isl :: any).lockedMessage or string.format(SeaMap.LockedMessage, isl.level), RED)
		return
	end
	local now = os.clock()
	if last[player] and now - last[player] < COOLDOWN then
		return
	end
	local cf = destination(isl)
	if not cf then
		DataService.Notify(player, SeaMap.ComingSoonMessage, RED)
		return
	end
	last[player] = now
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return
	end
	if hum.SeatPart then
		hum.Sit = false
		task.wait(0.1)
	end
	-- yolculuk animasyonu: client denizde süzülen tekneyi gösterir, ekran beyazken ışınlanır
	Remotes.Event("SailCinematic"):FireClient(player, (data :: any).boat, isl.name)
	local t0 = os.clock()
	-- hedef bölgeyi oyuncu için önceden yükle (StreamingEnabled)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	task.wait(math.max(0, SeaMap.Sail.PivotAt - (os.clock() - t0)))
	if not char.Parent or hum.Health <= 0 then
		return
	end
	if hum.SeatPart then
		hum.Sit = false
		task.wait(0.1)
	end
	char:PivotTo(cf)
	local bcf = boatDestination(isl)
	if bcf then
		BoatService.BringTo(player, bcf)
	end
	DataService.Notify(player, "Arrived at " .. isl.name, Color3.fromRGB(255, 214, 80))
end

function SeaMapService.Init()
	local folder = ReplicatedStorage:FindFirstChild("SeaMapRemotes") or Instance.new("Folder")
	folder.Name = "SeaMapRemotes"
	folder.Parent = ReplicatedStorage
	local ev = folder:FindFirstChild("Travel") or Instance.new("RemoteEvent")
	ev.Name = "Travel"
	ev.Parent = folder
	;(ev :: RemoteEvent).OnServerEvent:Connect(travel)
	Players.PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

return SeaMapService
