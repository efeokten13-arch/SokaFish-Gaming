--!strict
-- Haritadaki objeleri bulur. Harita Studio'da (Team Create) kalır, Rojo onu taşımaz.
--
-- Beklenen Workspace yapısı (isimler arkadaşının kurduğuna göre değiştirilebilir):
--   Workspace
--     FishingSpots   (Folder)  -> içinde Part'lar, her birinde Attribute: SpotType = "Near" | "Mid" | "Far", Ocean = "Warm"
--     PrivateIslands (Folder)  -> 8 ada Model'i, her birinde "Pool" ve "Dock" Part'ı
--     MainHall       (Model)   -> içinde "SellCounter" ve "BoatShop"
--     Pier           (Model)   -> içinde "BoatSpawn" Part'ı

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local MapService = {}

local islandOwners: { [Instance]: Player } = {}

function MapService.GetSpots(): { BasePart }
	local folder = Workspace:FindFirstChild("FishingSpots")
	local spots = {}
	if folder then
		for _, p in folder:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(spots, p)
			end
		end
	end
	return spots
end

-- Oyuncu bir spot'un yakınında mı? (client'ın "buradayım" demesine güvenmemek için)
function MapService.IsNearSpot(player: Player, spot: BasePart, maxDistance: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (root.Position - spot.Position).Magnitude <= maxDistance
end

-- Boş adayı oyuncuya ver
function MapService.AssignIsland(player: Player): Instance?
	local folder = Workspace:FindFirstChild("PrivateIslands")
	if not folder then
		return nil
	end
	for _, island in folder:GetChildren() do
		if not islandOwners[island] then
			islandOwners[island] = player
			island:SetAttribute("OwnerUserId", player.UserId)
			return island
		end
	end
	return nil
end

function MapService.GetIsland(player: Player): Instance?
	for island, owner in islandOwners do
		if owner == player then
			return island
		end
	end
	return nil
end

function MapService.Init()
	Players.PlayerAdded:Connect(function(p)
		MapService.AssignIsland(p)
	end)
	Players.PlayerRemoving:Connect(function(p)
		for island, owner in islandOwners do
			if owner == p then
				islandOwners[island] = nil
				island:SetAttribute("OwnerUserId", nil)
			end
		end
	end)
end

return MapService
