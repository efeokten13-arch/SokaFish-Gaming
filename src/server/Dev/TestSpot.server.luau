-- Sadece Studio'da: Workspace'te "FishingSpots" klasörü yoksa spawn'ın yanına bir test spot'u koyar.
-- Böylece harita hazır olmadan da balık tutma test edilebilir. Gerçek spot'lar eklenince otomatik devre dışı kalır.
--
-- Gerçek spot nasıl eklenir:
--   Workspace içinde "FishingSpots" adında bir Folder aç, içine Part'lar koy.
--   Her Part'a Attribute ekle: SpotType = "Near" | "Mid" | "Far"   (opsiyonel: Ocean = "Warm")

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Workspace = game:GetService("Workspace")
if Workspace:FindFirstChild("FishingSpots") then
	return
end

local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local pos = if spawn then spawn.Position + Vector3.new(12, 0, 0) else Vector3.new(0, 5, 0)

local folder = Instance.new("Folder")
folder.Name = "FishingSpots"
folder.Parent = Workspace

local spot = Instance.new("Part")
spot.Name = "TestSpot"
spot.Shape = Enum.PartType.Cylinder
spot.Size = Vector3.new(0.4, 10, 10)
spot.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
spot.Anchored = true
spot.CanCollide = false
spot.Color = Color3.fromRGB(60, 170, 255)
spot.Transparency = 0.5
spot.Material = Enum.Material.Neon
spot:SetAttribute("SpotType", "Mid")
spot:SetAttribute("Ocean", "Warm")
spot.Parent = folder

print("[Dev] TestSpot: spawn'ın yanına test spot'u kondu (mavi daire)")
