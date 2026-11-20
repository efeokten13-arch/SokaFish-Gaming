-- Client giriş noktası.

local Client = script.Parent

require(Client.Fishing.ReelingController).Init()
require(Client.Fishing.ReelHands).Init()
require(Client.UI.UIController).Init()
require(Client.Movement.MovementController).Init()
require(Client.Map.IslandGuide).Init()
require(Client.UI.CollectionBook).Init()
require(Client.UI.SeaMap).Init()
require(Client.Effects.BoatWake).Init()
require(Client.Effects.RegionWater).Init()
require(Client.Combat.CannonController).Init()
require(Client.UI.RodShopPrompts).Init()
require(Client.Effects.SoundController).Init()
require(Client.Effects.StormClouds).Init()
require(Client.Tutorial.IntroController).Init()
require(Client.Tutorial.GuideController).Init()
require(Client.UI.PoolScreen).Init()
require(Client.Effects.CoinBurst).Init()

print("[Client] Hazır")
