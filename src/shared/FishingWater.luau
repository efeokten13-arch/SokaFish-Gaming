--!strict
-- Açık denizde balık tutma: bir noktanın su olup olmadığı ve hangi okyanus / bölge olduğu.
-- Hem client (butonu göstermek için) hem server (doğrulamak için) kullanır.
local Workspace = game:GetService("Workspace")

local Config = script.Parent:WaitForChild("Config")
local Cfg = require(Config:WaitForChild("Fishing"))
local Atoll = require(Config:WaitForChild("Atoll"))

local FishingWater = {}

-- Noktanın tam üstünden aşağı bakınca ilk çarpılan arazi su mu? (kara, kum, kaya değil)
function FishingWater.IsWater(pos: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	local hit = Workspace:Raycast(Vector3.new(pos.X, 60, pos.Z), Vector3.new(0, -120, 0), params)
	return hit ~= nil and hit.Material == Enum.Material.Water and hit.Position.Y > -2
end

-- Okyanus ve bölge (Near / Mid / Far): merkeze uzaklığa göre
function FishingWater.Classify(pos: Vector3): (string, string)
	local ocean, center = "Warm", Vector3.zero
	if pos.X > Atoll.RegionMinX then
		ocean, center = "Coral", Atoll.Origin
	end
	local zones = (Cfg.OpenWater :: any)[ocean]
	local d = Vector2.new(pos.X - center.X, pos.Z - center.Z).Magnitude
	local spotType = if d < zones.near then "Near" elseif d < zones.mid then "Mid" else "Far"
	return ocean, spotType
end

return FishingWater
