--!strict
-- Yağmur bulutları (server): bulutların rotasını seçer, bir noktanın bulut altında olup olmadığını söyler.
-- Görsel (bulut, yağmur, şimşek) client'ta: client/Effects/StormClouds
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Storms"))
local StormPath = require(Shared:WaitForChild("StormPath"))

local StormService = {}

local rng = Random.new()
local folder: Folder
local storms: { Configuration } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Gezinme alanında rastgele nokta
local function randomPoint(): Vector3
	local a = rng:NextNumber(0, math.pi * 2)
	-- alana eşit yayılsın diye karekök
	local r = math.sqrt(rng:NextNumber(Cfg.MinDistance ^ 2, Cfg.MaxDistance ^ 2))
	return Cfg.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function okPoint(p: Vector3, self: Configuration): boolean
	local d = (Vector3.new(p.X, 0, p.Z) - Cfg.Center).Magnitude
	if d < Cfg.MinDistance or d > Cfg.MaxDistance then
		return false
	end
	for _, other in storms do
		if other ~= self then
			local o = StormPath.Position(other)
			local ot = Vector3.new(other:GetAttribute("ToX") :: number, 0, other:GetAttribute("ToZ") :: number)
			if (o - p).Magnitude < Cfg.MinGap or (ot - p).Magnitude < Cfg.MinGap then
				return false
			end
		end
	end
	return true
end

local function newLeg(storm: Configuration)
	local from = StormPath.Position(storm)
	if from == Vector3.zero then
		from = randomPoint()
	end
	local target = nil
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local step = rng:NextNumber(Cfg.StepMin, Cfg.StepMax)
		local p = from + Vector3.new(math.cos(a) * step, 0, math.sin(a) * step)
		if okPoint(p, storm) then
			target = p
			break
		end
	end
	if not target then
		target = randomPoint()
	end
	local dist = (target - from).Magnitude
	storm:SetAttribute("FromX", from.X)
	storm:SetAttribute("FromZ", from.Z)
	storm:SetAttribute("ToX", target.X)
	storm:SetAttribute("ToZ", target.Z)
	storm:SetAttribute("T0", now())
	storm:SetAttribute("Dur", dist / Cfg.Speed * 1.3) -- yumuşak başla/dur için biraz uzun
end

-- Bu nokta bir bulutun altında mı?
function StormService.IsUnderStorm(pos: Vector3): boolean
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, s in storms do
		if (StormPath.Position(s) - flat).Magnitude <= Cfg.Radius then
			return true
		end
	end
	return false
end

function StormService.Init()
	folder = ReplicatedStorage:FindFirstChild("Storms") :: Folder
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Storms"
	folder:SetAttribute("Height", Cfg.Height)
	folder:SetAttribute("Radius", Cfg.Radius)
	folder.Parent = ReplicatedStorage
	for i = 1, Cfg.Count do
		local s = Instance.new("Configuration")
		s.Name = "Storm" .. i
		local start
		for _ = 1, 40 do
			start = randomPoint()
			if okPoint(start, s) then
				break
			end
		end
		s:SetAttribute("FromX", start.X)
		s:SetAttribute("FromZ", start.Z)
		s:SetAttribute("ToX", start.X)
		s:SetAttribute("ToZ", start.Z)
		s:SetAttribute("T0", now())
		s:SetAttribute("Dur", 0.1)
		s.Parent = folder
		table.insert(storms, s)
	end
	task.spawn(function()
		while true do
			for _, s in storms do
				local t0 = s:GetAttribute("T0") :: number
				local dur = s:GetAttribute("Dur") :: number
				if now() >= t0 + dur then
					newLeg(s)
				end
			end
			task.wait(1)
		end
	end)
	-- şimşek zamanları: tüm oyuncular aynı anda görsün
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(Cfg.LightningMin, Cfg.LightningMax))
			local s = storms[rng:NextInteger(1, #storms)]
			s:SetAttribute("Lightning", rng:NextInteger(1, 1e6))
		end
	end)
end

return StormService
