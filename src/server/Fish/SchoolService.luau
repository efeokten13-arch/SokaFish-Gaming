--!strict
-- Balık sürüleri (server): sürülerin yerini seçer, süresi dolunca başka yere taşır,
-- bir noktanın sürünün içinde olup olmadığını söyler (FishingService şans için kullanır).
-- Görsel (martılar, zıplayan balıklar) client'ta: client/Effects/FishSchools
--
-- Her sürü ReplicatedStorage.FishSchools içinde bir Configuration; özellikleri:
--   X, Z: merkez · Expires: dağılacağı an (GetServerTimeNow) · Seed: her yer değişiminde yenilenir (client bunu dinler)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("FishSchools"))
local FishingWater = require(Shared:WaitForChild("FishingWater"))

local SchoolService = {}

local rng = Random.new()
local folder: Folder? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function centerOf(school: Instance): Vector3?
	local x, z = school:GetAttribute("X") :: number?, school:GetAttribute("Z") :: number?
	if x and z then
		return Vector3.new(x, 0, z)
	end
	return nil
end

local function farFromOthers(p: Vector3, self: Instance): boolean
	if not folder then
		return true
	end
	for _, other in folder:GetChildren() do
		local o = if other ~= self then centerOf(other) else nil
		if o and (o - p).Magnitude < Cfg.MinGap then
			return false
		end
	end
	return true
end

-- Sürüyü açık denizde yeni bir yere koy
local function place(school: Configuration)
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		-- alana eşit yayılsın diye karekök
		local r = math.sqrt(rng:NextNumber(Cfg.MinDistance ^ 2, Cfg.MaxDistance ^ 2))
		local p = Cfg.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if farFromOthers(p, school) and FishingWater.IsWater(p) then
			school:SetAttribute("X", p.X)
			school:SetAttribute("Z", p.Z)
			school:SetAttribute("Expires", now() + rng:NextNumber(Cfg.LifeMin, Cfg.LifeMax))
			school:SetAttribute("Seed", rng:NextInteger(1, 1e6)) -- en son: client buna göre yeniden çizer
			return
		end
	end
	-- uygun yer bulunamadı: biraz sonra tekrar dene
	school:SetAttribute("Expires", now() + 10)
end

-- Bu nokta bir balık sürüsünün içinde mi?
function SchoolService.IsInSchool(pos: Vector3): boolean
	if not folder then
		return false
	end
	for _, s in folder:GetChildren() do
		local c = centerOf(s)
		if c and Vector2.new(pos.X - c.X, pos.Z - c.Z).Magnitude <= Cfg.Radius then
			return true
		end
	end
	return false
end

function SchoolService.Init()
	local old = ReplicatedStorage:FindFirstChild("FishSchools")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "FishSchools"
	f:SetAttribute("Radius", Cfg.Radius)
	f.Parent = ReplicatedStorage
	folder = f

	local schools: { Configuration } = {}
	for i = 1, Cfg.Count do
		local s = Instance.new("Configuration")
		s.Name = "School" .. i
		s.Parent = f
		place(s)
		table.insert(schools, s)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			for _, s in schools do
				local expires = s:GetAttribute("Expires") :: number?
				if not expires or now() >= expires then
					place(s)
				end
			end
		end
	end)
end

return SchoolService
