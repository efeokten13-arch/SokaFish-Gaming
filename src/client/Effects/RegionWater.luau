--!nonstrict
-- Bölgeye göre su rengi: oyuncu atoldeyken (X > RegionMinX) suyun rengi atol rengine geçer.
-- Sadece bu oyuncunun ekranında değişir; ana adanın suyu ve diğer oyuncular etkilenmez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Atoll = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Atoll"))

local RegionWater = {}

local player = Players.LocalPlayer
local home -- ana denizin ayarları (oyun açılışındaki değerler)
local inAtoll = false

local function apply(settings)
	local T = Workspace.Terrain
	TweenService:Create(T, TweenInfo.new(1.2), {
		WaterColor = settings.color,
		WaterTransparency = settings.transparency,
		WaterReflectance = settings.reflectance,
	}):Play()
	T.WaterWaveSize = settings.waveSize
	T.WaterWaveSpeed = settings.waveSpeed
end

function RegionWater.Init()
	local T = Workspace.Terrain
	home = {
		color = T.WaterColor,
		transparency = T.WaterTransparency,
		reflectance = T.WaterReflectance,
		waveSize = T.WaterWaveSize,
		waveSpeed = T.WaterWaveSpeed,
	}
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local cam = Workspace.CurrentCamera
		local x = cam and cam.CFrame.Position.X or 0
		local now = x > Atoll.RegionMinX
		if now ~= inAtoll then
			inAtoll = now
			apply(now and Atoll.Water or home)
		end
	end)
end

return RegionWater
