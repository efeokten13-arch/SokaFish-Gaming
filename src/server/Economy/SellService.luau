--!strict
-- Kıyıdaki balık pazarının SellCounter'ları: tekne deposundaki balıkları sat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Fish = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Fish"))
local DataService = require(script.Parent.Parent.Data.DataService)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local SellService = {}

function SellService.SellSlot(data: any, slotIndex: number): number
	local fishId = data.storage[slotIndex]
	if not fishId then
		return 0
	end
	local price = Fish[fishId] and Fish[fishId].sell or 0
	table.remove(data.storage, slotIndex)
	data.money += price
	return price
end

local function sellAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if #data.storage == 0 then
		DataService.Notify(player, "You have no fish to sell", Color3.fromRGB(255, 140, 120))
		return
	end
	local n, total = #data.storage, 0
	while #data.storage > 0 do
		total += SellService.SellSlot(data, 1)
	end
	DataService.Notify(player, "Sold " .. n .. " fish for $" .. total, Color3.fromRGB(255, 214, 80))
	Remotes.Event("CoinBurst"):FireClient(player, total)
	DataService.Push(player)
end

-- Oyuncu balık pazarının (bir SellCounter'ın) yakınında mı?
local SELL_RANGE = 45
function SellService.NearMarket(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local market = Workspace:FindFirstChild("FishMarket")
	if not root or not market then
		return false
	end
	for _, d in market:GetDescendants() do
		if d.Name == "SellCounter" and d:IsA("BasePart") and (d.Position - root.Position).Magnitude < SELL_RANGE then
			return true
		end
	end
	return false
end

-- Çantadan seçili balıkları sat (client: SellFish(slotList) ; slotList nil = hepsi)
local function sellSelected(player: Player, slots: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not SellService.NearMarket(player) then
		DataService.Notify(player, "Go to the Fish Market to sell your fish!", Color3.fromRGB(255, 140, 120))
		return
	end
	if slots == nil then
		sellAll(player)
		return
	end
	if type(slots) ~= "table" then
		return
	end
	local pick = {}
	for _, v in slots do
		if type(v) == "number" and v == v then
			local i = math.floor(v)
			if data.storage[i] and not table.find(pick, i) then
				table.insert(pick, i)
			end
		end
	end
	if #pick == 0 then
		return
	end
	table.sort(pick, function(a, b)
		return a > b
	end)
	local total = 0
	for _, i in pick do
		total += SellService.SellSlot(data, i)
	end
	DataService.Notify(player, "Sold " .. #pick .. " fish for $" .. total, Color3.fromRGB(255, 214, 80))
	Remotes.Event("CoinBurst"):FireClient(player, total)
	DataService.Push(player)
end

local function hook(counter: Instance)
	if not counter:IsA("BasePart") or counter.Name ~= "SellCounter" or counter:FindFirstChild("SellPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell all fish"
	prompt.ObjectText = "Fish Market"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(sellAll)
end

-- Kıyıdaki balık pazarı (Workspace.FishMarket): ada tarafında ve iskele tarafında birer SellCounter
function SellService.Init()
	Remotes.Event("SellFish").OnServerEvent:Connect(sellSelected)
	task.spawn(function()
		local market = Workspace:WaitForChild("FishMarket", 60)
		if not market then
			warn("[SellService] Workspace.FishMarket yok (MapBuilder.IslandLife ile kurulmalı)")
			return
		end
		for _, d in market:GetDescendants() do
			hook(d)
		end
		market.DescendantAdded:Connect(hook)
	end)
end

return SellService
