--!strict
-- Haritadaki objeleri bulur. Harita Studio'da (Team Create) kalır, Rojo onu taşımaz.
--
-- Beklenen Workspace yapısı (isimler arkadaşının kurduğuna göre değiştirilebilir):
--   Workspace
--     FishingSpots   (Folder)  -> içinde Part'lar, her birinde Attribute: SpotType = "Near" | "Mid" | "Far", Ocean = "Warm"
--     PrivateIslands (Folder)  -> 8 ada Model'i, her birinde "Pool" ve "Dock" Part'ı
--     FishMarket     (Model)   -> içinde "SellCounter" (ada ve iskele tarafında)
--     Pier           (Model)   -> "BoatShop" (kulübe), "Showroom" (satılık tekneler)
--     Pier           (Model)   -> içinde "BoatSpawn" Part'ı

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local IslandBanner = require(script.Parent:WaitForChild("IslandBanner"))

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

function MapService.GetIsland(player: Player): Instance?
	for island, owner in islandOwners do
		if owner == player then
			return island
		end
	end
	return nil
end

-- Adanın üstündeki "Spawn" parçasındaki yazıyı güncelle (sahip adı veya FREE ISLAND)
local function setOwnerLabel(island: Instance, ownerName: string?)
	local spawnPart = island:FindFirstChild("Spawn")
	local gui = spawnPart and spawnPart:FindFirstChild("OwnerLabel")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = ownerName and (ownerName .. "'s Island") or "FREE ISLAND"
	end
end

-- Boş adayı oyuncuya ver (zaten adası varsa aynısını döndürür)
function MapService.AssignIsland(player: Player): Instance?
	local existing = MapService.GetIsland(player)
	if existing then
		return existing
	end
	local folder = Workspace:FindFirstChild("PrivateIslands")
	if not folder then
		return nil
	end
	-- numara sırasıyla (Island1, Island2, ...) ilk boş adayı ver
	local list = folder:GetChildren()
	table.sort(list, function(a, b)
		return ((a:GetAttribute("Index") :: number?) or 0) < ((b:GetAttribute("Index") :: number?) or 0)
	end)
	for _, island in list do
		if not islandOwners[island] then
			islandOwners[island] = player
			island:SetAttribute("OwnerUserId", player.UserId)
			setOwnerLabel(island, player.DisplayName)
			IslandBanner.Set(island, player) -- iskelede isim tabelası + bayrak
			return island
		end
	end
	return nil
end

function MapService.Init()
	-- Ada artık otomatik verilmez: oyuncu Old Fisherman ile konuşunca alır (FishermanService)
	Players.PlayerRemoving:Connect(function(p)
		for island, owner in islandOwners do
			if owner == p then
				islandOwners[island] = nil
				island:SetAttribute("OwnerUserId", nil)
				setOwnerLabel(island, nil)
				IslandBanner.Set(island, nil)
			end
		end
	end)
end

return MapService
