--!nonstrict
-- Ekranın üstünde hedefi gösteren dönen ok + dünyada ışık sütunu.
-- Server "GuideTarget" gönderir (Old Fisherman veya kendi adan).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local IslandGuide = {}

local player = Players.LocalPlayer
local HIDE_DISTANCE = 22 -- bu kadar yaklaşınca ok kapanır
local target: BasePart? = nil
local arrowFrame, arrowLabel, distLabel, beacon, conn

local function clear()
	target = nil
	if arrowFrame then
		arrowFrame.Visible = false
	end
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function makeBeacon(part, color)
	if beacon then
		beacon:Destroy()
	end
	beacon = Instance.new("Part")
	beacon.Name = "GuideBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Material = Enum.Material.Neon
	beacon.Color = color
	beacon.Transparency = 0.55
	beacon.Size = Vector3.new(260, 5, 5)
	beacon.CFrame = CFrame.new(part.Position + Vector3.new(0, 130, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beacon.Parent = Workspace
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IslandGuideGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "Guide"
	arrowFrame.AnchorPoint = Vector2.new(0.5, 0)
	arrowFrame.Position = UDim2.new(0.5, 0, 0, 120)
	arrowFrame.Size = UDim2.fromOffset(220, 110)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.Visible = false
	arrowFrame.Parent = gui

	arrowLabel = Instance.new("TextLabel")
	arrowLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowLabel.Position = UDim2.new(0.5, 0, 0, 40)
	arrowLabel.Size = UDim2.fromOffset(70, 70)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = "▲"
	arrowLabel.TextScaled = true
	arrowLabel.Font = Enum.Font.GothamBold
	arrowLabel.TextColor3 = Color3.fromRGB(255, 214, 80)
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.TextStrokeColor3 = Color3.fromRGB(30, 30, 30)
	arrowLabel.Parent = arrowFrame

	distLabel = Instance.new("TextLabel")
	distLabel.AnchorPoint = Vector2.new(0.5, 0)
	distLabel.Position = UDim2.new(0.5, 0, 0, 80)
	distLabel.Size = UDim2.fromOffset(220, 26)
	distLabel.BackgroundTransparency = 1
	distLabel.Font = Enum.Font.GothamBold
	distLabel.TextSize = 18
	distLabel.TextColor3 = Color3.new(1, 1, 1)
	distLabel.TextStrokeTransparency = 0.3
	distLabel.Parent = arrowFrame
end

local label = ""

-- Oku bir parçaya çevir (part = nil: ok kapanır). Server "GuideTarget" ile, client modülleri doğrudan çağırır.
function IslandGuide.Point(part, text)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		clear()
		return
	end
	target = part
	label = text or ""
	makeBeacon(part, (text == "Old Fisherman" or text == "Old Finn" or text == "Marina") and Color3.fromRGB(255, 214, 80) or Color3.fromRGB(80, 230, 150))
	if arrowFrame then
		arrowFrame.Visible = true
	end
end

function IslandGuide.Init()
	buildUI()

	Remotes.Event("GuideTarget").OnClientEvent:Connect(IslandGuide.Point)

	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not target or not target.Parent or not cam or not root then
			if target and not target.Parent then
				clear()
			end
			return
		end
		local dist = (target.Position - root.Position).Magnitude
		if dist < HIDE_DISTANCE then
			clear()
			return
		end
		local localPos = cam.CFrame:PointToObjectSpace(target.Position)
		arrowLabel.Rotation = math.deg(math.atan2(localPos.X, -localPos.Z))
		distLabel.Text = label .. " · " .. math.floor(dist) .. " studs"
	end)
end

return IslandGuide
