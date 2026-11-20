--!nonstrict
-- Gemi topları (client): kendi gemindeki bir topun yanına gelince "Aim" ve "Fire" butonları çıkar.
-- Nişan modunda o top kameranın baktığı yöne döner (en fazla ±25°) ve gülle yolu noktalarla görünür.
-- Ateş etme şimdilik kapalı (gemi savaşı sistemiyle eklenecek).
-- Kısayollar: R = nişan aç/kapa, F = ateş.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cannons"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local UIController = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIController"))

local CannonController = {}

local player = Players.LocalPlayer
local NEAR = 7 -- topa bu kadar yaklaşınca butonlar çıkar
local cannon, hull -- yanındaki top (namlu) ve geminin gövdesi
local aiming = false
local gui, aimBtn, fireBtn
local dots = {}
local DOTS = 18

-- Kendi gemindeki en yakın top
local function nearestCannon()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local boats = Workspace:FindFirstChild("Boats")
	if not root or not boats then
		return nil
	end
	local best, bestD, bestHull = nil, NEAR, nil
	for _, boat in boats:GetChildren() do
		if boat:GetAttribute("HasCannons") and boat:GetAttribute("OwnerUserId") == player.UserId then
			local folder = boat:FindFirstChild("Cannons")
			for _, b in folder and folder:GetChildren() or {} do
				if b:IsA("BasePart") and b:FindFirstChild("Hinge") then
					local d = (b.Position - root.Position).Magnitude
					if d < bestD then
						best, bestD, bestHull = b, d, boat.PrimaryPart
					end
				end
			end
		end
	end
	return best, bestHull
end

local function setYaw(barrel, yaw)
	local w = barrel and barrel:FindFirstChild("Hinge")
	local base = w and w:GetAttribute("BaseC0")
	if base then
		w.C0 = base * CFrame.Angles(0, yaw, 0)
	end
end

-- Kameranın baktığı yöne göre bu topun açısı
local function aimYaw(barrel)
	local cam = Workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return 0
	end
	local base = barrel.Hinge:GetAttribute("BaseC0")
	local d = (hull.CFrame * base).Rotation:VectorToObjectSpace(flat.Unit)
	local yaw = math.atan2(-d.Z, d.X)
	local maxYaw = math.rad(Cfg.MaxYawDeg)
	return math.clamp(yaw, -maxYaw, maxYaw)
end

local function hideDots()
	for _, d in dots do
		d.Transparency = 1
	end
end

local function showPath(barrel)
	local w = barrel.Hinge
	local cf = hull.CFrame * w.C0 * w.C1:Inverse()
	local pos = (cf * CFrame.new(barrel.Size.X / 2 + 0.8, 0, 0)).Position
	local vel = cf.RightVector * Cfg.Speed + Vector3.new(0, Cfg.Arc, 0) + hull.AssemblyLinearVelocity
	for i = 1, DOTS do
		local t = i * 0.12
		local p = pos + vel * t - Vector3.new(0, 0.5 * Cfg.Gravity * t * t, 0)
		local d = dots[i]
		if p.Y < 0 then
			d.Transparency = 1
		else
			d.Position = p
			d.Transparency = 0.15
		end
	end
end

local function setAiming(on)
	aiming = on
	if aimBtn then
		Theme.SetActive(aimBtn, on)
	end
	if not on then
		hideDots()
		if cannon then
			setYaw(cannon, 0)
		end
	end
end

local function fire()
	if not cannon then
		return
	end
	-- Ateş şimdilik kapalı: gemi savaşı sistemiyle birlikte açılacak
	UIController.Notify("Cannons can't fire yet. Coming soon!", Color3.fromRGB(255, 214, 80))
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CannonGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local step = Theme.ButtonSize + Theme.Gap
	aimBtn = Theme.Button(gui, "AimButton", "🎯", "Aim (R)", UDim2.new(1, -18, 1, -24 - step * 2), Vector2.new(1, 1))
	fireBtn = Theme.Button(gui, "FireButton", "💥", "Fire (F)", UDim2.new(1, -18, 1, -24 - step * 3), Vector2.new(1, 1))
	aimBtn.Activated:Connect(function()
		setAiming(not aiming)
	end)
	fireBtn.Activated:Connect(fire)
	local folder = Instance.new("Folder")
	folder.Name = "CannonAimDots"
	folder.Parent = Workspace.CurrentCamera
	for i = 1, DOTS do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.new(0.7, 0.7, 0.7)
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Material = Enum.Material.Neon
		d.Color = Color3.fromRGB(255, 196, 64)
		d.Transparency = 1
		d.Parent = folder
		dots[i] = d
	end
end

function CannonController.Init()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not cannon then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			setAiming(not aiming)
		elseif input.KeyCode == Enum.KeyCode.F then
			fire()
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		-- en yakın topu 5 kez/saniye ara
		acc += dt
		if acc >= 0.2 then
			acc = 0
			local c, h = nearestCannon()
			if c ~= cannon then
				if aiming then
					setAiming(false)
				end
				cannon, hull = c, h
				gui.Enabled = c ~= nil
			end
		end
		if aiming and cannon and hull and cannon.Parent then
			setYaw(cannon, aimYaw(cannon))
			showPath(cannon)
		end
	end)
end

return CannonController
