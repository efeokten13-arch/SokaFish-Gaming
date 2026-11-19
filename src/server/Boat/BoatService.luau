--!strict
-- Tekne: iskeledeki vitrinden satın alma, denize indirme (spawn), sadece sahibi binebilir.
-- Vitrin: Workspace.Pier.Showroom içindeki modeller (MapBuilder kurar). Her birine "Buy / Sail" düğmesi eklenir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boats = require(Shared:WaitForChild("Config"):WaitForChild("Boats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataService = require(script.Parent.Parent.Data.DataService)
local MapService = require(script.Parent.Parent.Map.MapService)
local BoatModels = require(script.Parent.BoatModels)

local BoatService = {}

local spawned: { [Player]: Model } = {}
local GREEN = Color3.fromRGB(120, 230, 150)
local RED = Color3.fromRGB(255, 140, 120)

function BoatService.GetSlotCount(boatId: string): number
	local boat = (Boats :: any)[boatId]
	return boat and boat.slots or 3
end

local function owns(data: any, id: string): boolean
	return table.find(data.ownedBoats, id) ~= nil
end

-- En iyi tekne (slot sayısı için)
local function bestBoat(data: any): string
	local best, order = data.boat, 0
	for _, id in data.ownedBoats do
		local info = (Boats :: any)[id]
		if info and (info.order or 0) > order then
			best, order = id, info.order
		end
	end
	return best
end

local function folder(): Folder
	local f = Workspace:FindFirstChild("Boats") :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = "Boats"
		f.Parent = Workspace
	end
	return f :: Folder
end

local function guardSeat(model: Model, owner: Player)
	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true) :: VehicleSeat?
	if not seat then
		return
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		local p = hum and Players:GetPlayerFromCharacter(hum.Parent)
		if p and p ~= owner then
			hum.Sit = false
			DataService.Notify(p, "This is " .. owner.DisplayName .. "'s boat", RED)
		end
	end)
end

local function place(player: Player, id: string, cf: CFrame): Model?
	local old = spawned[player]
	if old then
		old:Destroy()
	end
	local model = BoatModels.Build(id, cf, false)
	if not model then
		return nil
	end
	model.Name = player.Name .. "_" .. id
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = folder()
	spawned[player] = model
	guardSeat(model, player)
	return model
end

-- Oyuncu adasına ışınlanınca teknesi adanın iskelesine (Dock) gelir.
-- Teknesi denizde değilse sahip olduğu en iyi tekne oraya çıkarılır.
function BoatService.BringToDock(player: Player, island: Instance)
	local dock = island:FindFirstChild("Dock") :: BasePart?
	local data = DataService.Get(player)
	if not dock or not data or #data.ownedBoats == 0 then
		return
	end
	local look = dock.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z).Unit
	local side = Vector3.new(-flat.Z, 0, flat.X)
	local pos = Vector3.new(dock.Position.X, 0.65, dock.Position.Z) + side * 9 + flat * 2
	local cf = CFrame.lookAt(pos, pos + flat)
	local boat = spawned[player]
	if boat and boat.Parent then
		local seat = boat:FindFirstChildWhichIsA("VehicleSeat", true) :: VehicleSeat?
		if seat and seat.Occupant then
			seat.Occupant.Sit = false
		end
		boat:PivotTo(cf)
		if boat.PrimaryPart then
			boat.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
			boat.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		end
	else
		place(player, bestBoat(data), cf)
	end
end

local function launch(player: Player, id: string, display: Model)
	local base = (display:GetAttribute("Launch") :: CFrame?) or display:GetPivot()
	local rng = Random.new()
	local cf = base + Vector3.new(rng:NextNumber(0, 30), 0, rng:NextNumber(-8, 8))
	local model = place(player, id, cf)
	if not model then
		return
	end
	-- oyuncuyu direkt tekneye oturt
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true) :: VehicleSeat?
	if hum and seat then
		if hum.SeatPart then
			hum.Sit = false
			task.wait(0.1)
		end
		char:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
		task.wait(0.2)
		seat:Sit(hum)
	end
end

local function onPrompt(player: Player, id: string, display: Model)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local info = (Boats :: any)[id]
	if not owns(data, id) then
		if data.money < info.price then
			DataService.Notify(player, "You need $" .. info.price .. " for the " .. info.displayName, RED)
			return
		end
		data.money -= info.price
		table.insert(data.ownedBoats, id)
		data.boat = bestBoat(data)
		DataService.Notify(player, "You bought the " .. info.displayName .. "!", GREEN)
		DataService.Push(player)
		-- anlatım: ilk tekne alındı -> adaya git
		if ((data :: any).tutorial or 0) < 2 then
			(data :: any).tutorial = 2
			local island = MapService.GetIsland(player)
			local sp = island and island:FindFirstChild("Spawn")
			if sp then
				task.delay(1.5, function()
					Remotes.Event("GuideTarget"):FireClient(player, sp, "Your island")
					DataService.Notify(player, "Sail to your island and put your fish in the pool!", GREEN)
				end)
			end
		end
	end
	launch(player, id, display)
end

function BoatService.Init()
	task.spawn(function()
		local pier = Workspace:WaitForChild("Pier", 60)
		local showroom = pier and pier:WaitForChild("Showroom", 10)
		if not showroom then
			warn("[BoatService] Workspace.Pier.Showroom yok (MapBuilder.Structures çalıştırılmadı)")
			return
		end
		for _, display in showroom:GetChildren() do
			local id = display:GetAttribute("BoatId") :: string?
			local info = id and (Boats :: any)[id]
			local hull = display:IsA("Model") and display.PrimaryPart
			if info and hull then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Buy ($" .. info.price .. ") / Sail"
				prompt.ObjectText = info.displayName
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 16
				prompt.RequiresLineOfSight = false
				prompt.Parent = hull
				prompt.Triggered:Connect(function(p)
					onPrompt(p, id :: string, display :: Model)
				end)
			end
		end
	end)
	-- eski sürümden kalan sahipsiz kayığı kaldır
	local f = Workspace:FindFirstChild("Boats")
	local legacy = f and f:FindFirstChild("Kayak")
	if legacy then
		legacy:Destroy()
	end
	Players.PlayerRemoving:Connect(function(p)
		if spawned[p] then
			spawned[p]:Destroy()
			spawned[p] = nil
		end
	end)
end

return BoatService
