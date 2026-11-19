-- Server giriş noktası. Tüm servisleri sırayla başlatır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")) -- remote'ları oluştur

local Server = script.Parent

local services = {
	require(Server.Data.DataService),
	require(Server.Map.MapService),
	require(Server.Boat.BoatService),
	require(Server.Economy.SellService),
	require(Server.Economy.PoolService),
}

for _, s in services do
	s.Init()
end

print("[Server] Fishing game hazır")
