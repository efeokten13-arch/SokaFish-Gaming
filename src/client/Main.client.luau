-- Client giriş noktası.

local Client = script.Parent

require(Client.Fishing.ReelingController).Init()
require(Client.UI.UIController).Init()

print("[Client] Hazır")
