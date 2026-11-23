-- Server giriş noktası. Tüm servisleri sırayla başlatır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) -- remote'ları oluştur

local Server = script.Parent

local services = {
	require(Server.Data.DataService),
	require(Server.Map.MapService),
	require(Server.Map.TeleportService),
	require(Server.Map.FishermanService),
	require(Server.Map.MermaidService),
	require(Server.Boat.BoatService),
	require(Server.Boat.DockService),
	require(Server.Economy.SellService),
	require(Server.Economy.PoolService),
	require(Server.Map.BookService),
	require(Server.Fish.FishingService),
	require(Server.SeaMap.SeaMapService),
	require(Server.Combat.CannonService),
	require(Server.Combat.PracticeService),
	require(Server.Treasure.TreasureService),
	require(Server.Shop.RodShopService),
	require(Server.Weather.StormService),
	require(Server.Fish.SchoolService),
	require(Server.Map.LeaderboardService),
}

for _, s in services do
	s.Init()
end

print("[Server] Fishing game hazır")
