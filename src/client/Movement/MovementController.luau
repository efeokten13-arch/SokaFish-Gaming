--!nonstrict
-- Koşma (Shift / SPRINT), hızlı yüzme, dalma (C / DIVE) ve sol taraftaki ışınlanma butonları.
-- Animasyonlar Roblox'un kendi Animate script'inden gelir: hız arttıkça koşu ve yüzme animasyonu da hızlanır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Movement"))

local MovementController = {}

local player = Players.LocalPlayer
local sprintToggle = false -- buton ile açılıp kapanır
local shiftHeld = false
local diveHeld = false
local sprintButton, diveButton

local function sprinting()
	return sprintToggle or shiftHeld
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isSwimming(hum)
	local s = hum:GetState()
	return s == Enum.HumanoidStateType.Swimming
end

local function applySpeed()
	local hum = getHumanoid()
	if not hum or hum.SeatPart then
		return
	end
	local sw = isSwimming(hum)
	local target
	if sw then
		target = sprinting() and Cfg.SwimSprintSpeed or Cfg.SwimSpeed
	else
		target = sprinting() and Cfg.SprintSpeed or Cfg.WalkSpeed
	end
	if hum.WalkSpeed ~= target then
		hum.WalkSpeed = target
	end
	local fov = (sprinting() and hum.MoveDirection.Magnitude > 0.1) and Cfg.SprintFov or Cfg.NormalFov
	local cam = Workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - fov) > 0.5 then
		cam.FieldOfView += (fov - cam.FieldOfView) * 0.15
	end
end

-- Dalma: suda yüzerken butona basılı tutunca aşağı iner
local function applyDive()
	local hum = getHumanoid()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and diveHeld and isSwimming(hum) then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, -Cfg.DiveSpeed, v.Z)
	end
end

local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MovementGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Sol sütun: (Harita, Envanter) üstte, ışınlanma altta
	local island = Theme.Button(gui, "IslandButton", "🏝️", "My Island", Theme.LeftColumn(1))
	local main = Theme.Button(gui, "MainButton", "🏠", "Main", Theme.LeftColumn(2))
	island.Activated:Connect(function()
		Remotes.Event("TeleportRequest"):FireServer("Island")
	end)
	main.Activated:Connect(function()
		Remotes.Event("TeleportRequest"):FireServer("Main")
	end)

	-- Sağ alt: sprint ve dive
	local step = Theme.ButtonSize + Theme.Gap
	sprintButton = Theme.Button(gui, "SprintButton", "⚡", "Sprint", UDim2.new(1, -18, 1, -24 - step), Vector2.new(1, 1))
	diveButton = Theme.Button(gui, "DiveButton", "🤿", "Dive", UDim2.new(1, -18, 1, -24), Vector2.new(1, 1))
	sprintButton.Activated:Connect(function()
		sprintToggle = not sprintToggle
	end)
	-- Dive: basılı tutulduğu sürece iner (mouse ve dokunmatik)
	diveButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			diveHeld = true
		end
	end)
	diveButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			diveHeld = false
		end
	end)
end

function MovementController.Init()
	buildUI()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			shiftHeld = true
		elseif input.KeyCode == Enum.KeyCode.C then
			diveHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			shiftHeld = false
		elseif input.KeyCode == Enum.KeyCode.C then
			diveHeld = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		applySpeed()
		applyDive()
		if sprintButton then
			Theme.SetActive(sprintButton, sprinting())
			Theme.SetActive(diveButton, diveHeld)
		end
	end)
end

return MovementController
