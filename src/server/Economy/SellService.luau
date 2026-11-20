--!strict
-- Kıyıdaki balık pazarının SellCounter'ları: tekne deposundaki balıkları sat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Fish = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Fish"))
local DataService = require(script.Parent.Parent.Data.DataService)

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
