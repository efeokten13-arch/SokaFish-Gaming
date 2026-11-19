-- Client giriş noktası.

local Client = script.Parent

require(Client.Fishing.ReelingController).Init()
require(Client.UI.UIController).Init()
require(Client.Movement.MovementController).Init()
require(Client.Map.IslandGuide).Init()
require(Client.UI.CollectionBook).Init()
require(Client.UI.SeaMap).Init()
require(Client.Effects.BoatWake).Init()

print("[Client] Hazır")
