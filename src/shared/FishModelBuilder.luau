--!strict
-- Balık 3D modellerini Part'lardan kodla üretir. Görünüm Config/Fish.luau içindeki "look" alanından gelir.
-- ReplicatedStorage'da durduğu için hem server (havuz, tekne) hem client (UI önizleme) kullanabilir.
--
-- Kullanım:
--   local FishModelBuilder = require(ReplicatedStorage.Shared.FishModelBuilder)
--   local model = FishModelBuilder.Build("Cod")            -- normal boy
--   local big   = FishModelBuilder.Build("Cod", 1.3)       -- %30 büyük varyant
--   model:PivotTo(CFrame.new(0, 10, 0))
--   model.Parent = workspace
--
-- Balık -Z yönüne bakar (Roblox'un LookVector'ü). Body = PrimaryPart.
-- Varsayılan olarak Body anchored. Hareket ettirmek için: model.PrimaryPart.Anchored = false

local Shared = script.Parent
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))

-- Gövde oranları (boyun katı olarak): w = genişlik, h = yükseklik
local SHAPES = {
	Slim = { w = 0.24, h = 0.30, tail = 0.30, fin = 0.25 },
	Normal = { w = 0.28, h = 0.38, tail = 0.32, fin = 0.30 },
	Round = { w = 0.80, h = 0.80, tail = 0.26, fin = 0.22 },
	Long = { w = 0.15, h = 0.22, tail = 0.24, fin = 0.20 },
}

local FishModelBuilder = {}

local function newPart(model: Model, name: string, size: Vector3, color: Color3, reflect: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = reflect
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = model
	return p
end

-- Sphere SpecialMesh, Part boyutuna göre esner -> elips gövde
local function makeEllipsoid(p: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

local function attach(body: Part, p: Part, offset: CFrame)
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
end

local function hasExtra(look: any, name: string): boolean
	return look.extras ~= nil and table.find(look.extras, name) ~= nil
end

function FishModelBuilder.Build(fishId: string, sizeMul: number?): Model?
	local def = Fish[fishId]
	if not def then
		warn("FishModelBuilder: bilinmeyen balık", fishId)
		return nil
	end
	local look = def.look
	local shape = (SHAPES :: any)[look.shape] or SHAPES.Normal
	local mul = sizeMul or 1
	local reflect = look.reflect or 0

	local L = look.length * mul
	local W = L * shape.w
	local H = L * shape.h
	local thin = math.max(L * 0.025, 0.05)

	local model = Instance.new("Model")
	model.Name = fishId

	-- Gövde + karın (iki tonlu görünüm)
	local body = newPart(model, "Body", Vector3.new(W, H, L), look.body, reflect)
	body.CFrame = CFrame.new()
	body.Anchored = true
	makeEllipsoid(body)
	model.PrimaryPart = body

	-- Karın gövdeden alt ve yanlardan biraz taşar, böylece alt yarı açık renk görünür
	local belly = newPart(model, "Belly", Vector3.new(W * 1.03, H * 0.7, L * 0.9), look.belly, reflect)
	makeEllipsoid(belly)
	attach(body, belly, CFrame.new(0, -H * 0.17, -L * 0.02))

	-- Kuyruk sapı
	local stalk = newPart(model, "TailStalk", Vector3.new(W * 0.35, H * 0.32, L * 0.22), look.body, reflect)
	makeEllipsoid(stalk)
	attach(body, stalk, CFrame.new(0, 0, L * 0.47))

	-- Kuyruk: V şeklinde iki kanat
	local tl = L * shape.tail
	for _, s in { 1, -1 } do
		local blade = newPart(model, "TailBlade", Vector3.new(thin, tl * 0.28, tl), look.fin, reflect)
		attach(body, blade, CFrame.new(0, s * tl * 0.22, L * 0.5 + tl * 0.3) * CFrame.Angles(-s * math.rad(35), 0, 0))
	end

	-- Sırt yüzgeci (Sail varsa büyük yelken)
	local fl = L * shape.fin
	if hasExtra(look, "Sail") then
		local sail = newPart(model, "Sail", Vector3.new(thin, H * 1.3, L * 0.5), look.fin, reflect)
		attach(body, sail, CFrame.new(0, H * 0.75, -L * 0.05))
	else
		local dorsal = newPart(model, "DorsalFin", Vector3.new(thin, fl * 0.5, fl), look.fin, reflect)
		attach(body, dorsal, CFrame.new(0, H * 0.45, L * 0.05))
	end

	-- Yan yüzgeçler
	for _, s in { 1, -1 } do
		local pec = newPart(model, "SideFin", Vector3.new(fl * 0.45, thin, fl * 0.3), look.fin, reflect)
		attach(
			body,
			pec,
			CFrame.new(s * (W * 0.5 + fl * 0.12), -H * 0.15, -L * 0.1)
				* CFrame.Angles(0, s * math.rad(25), -s * math.rad(20))
		)
	end

	-- Gözler (beyaz + siyah göz bebeği)
	local e = math.max(H * 0.17, 0.12)
	for _, s in { 1, -1 } do
		local white = newPart(model, "Eye", Vector3.new(e, e, e), Color3.new(1, 1, 1), 0)
		white.Shape = Enum.PartType.Ball
		attach(body, white, CFrame.new(s * W * 0.38, H * 0.12, -L * 0.3))

		local pupil = newPart(model, "Pupil", Vector3.new(e * 0.6, e * 0.6, e * 0.6), Color3.new(0.05, 0.05, 0.05), 0)
		pupil.Shape = Enum.PartType.Ball
		attach(body, pupil, CFrame.new(s * (W * 0.38 + e * 0.25), H * 0.12, -L * 0.3 - e * 0.1))
	end

	-- Kılıç burun
	if hasExtra(look, "Bill") then
		local billLen = L * 0.35
		local d = math.max(H * 0.12, 0.08)
		local bill = newPart(model, "Bill", Vector3.new(billLen, d, d), look.fin, reflect)
		bill.Shape = Enum.PartType.Cylinder
		-- Cylinder X ekseninde uzanır; Y etrafında 90° çevirince -Z'ye bakar
		attach(body, bill, CFrame.new(0, H * 0.05, -L * 0.5 - billLen * 0.45) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- Dikenler (balon balığı): fibonacci küresiyle eşit dağıtılmış
	if hasExtra(look, "Spikes") then
		local count = 26
		local spikeLen = L * 0.14
		local golden = math.pi * (3 - math.sqrt(5))
		for i = 0, count - 1 do
			local y = 1 - (i / (count - 1)) * 2
			local r = math.sqrt(1 - y * y)
			local theta = golden * i
			local dir = Vector3.new(math.cos(theta) * r, y, math.sin(theta) * r)
			-- kuyruk tarafına diken koyma
			if dir.Z < 0.75 then
				local point = Vector3.new(dir.X * W * 0.5, dir.Y * H * 0.5, dir.Z * L * 0.5)
				local spike = newPart(model, "Spike", Vector3.new(thin, thin, spikeLen), look.fin, reflect)
				local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
				attach(body, spike, CFrame.lookAt(point, point + dir, up) * CFrame.new(0, 0, -spikeLen * 0.3))
			end
		end
	end

	-- Nadirlik efekti: Epic ve Legendary parlar
	local rarity = (Rarities :: any)[def.rarity]
	if rarity and (def.rarity == "Epic" or def.rarity == "Legendary") then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Brightness = 1
		light.Range = L * 2
		light.Parent = body

		if def.rarity == "Legendary" then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Color = ColorSequence.new(rarity.color)
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new(L * 0.04)
			sparkle.Lifetime = NumberRange.new(0.8, 1.4)
			sparkle.Rate = 6
			sparkle.Speed = NumberRange.new(0.3, 0.8)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = body
		end
	end

	model:SetAttribute("FishId", fishId)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Size", mul)
	return model
end

-- Rastgele boy varyantı (0.8x - 1.3x). Büyük balık daha nadir.
function FishModelBuilder.RollSize(rng: Random?): number
	local r = rng or Random.new()
	local t = r:NextNumber() ^ 2 -- küçük değerler daha sık
	return math.floor((0.8 + t * 0.5) * 100 + 0.5) / 100
end

return FishModelBuilder
