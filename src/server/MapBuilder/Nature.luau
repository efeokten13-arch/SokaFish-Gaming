--!nonstrict
-- Doğa: harita kenarında tropikal dağ halkası + adalara çalı, kaya, çiçek, eğrelti ve ekstra palmiye.
-- Her şey sabit tohumla üretilir: aynı kod = aynı harita.
local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)
local Decor = require(script.Parent.Decor)

local Nature = {}

-- Dağlar --------------------------------------------------------------------
-- Her dağ: üst üste küçülen toplar. Etek kum, gövde yapraklı çim (orman), tepe kaya.
local function mountain(x, z, height, rng)
	local base = height * 0.7
	-- ince sahil şeridi
	Terrain:FillCylinder(CFrame.new(x, -1, z), 6, base * 0.95, Enum.Material.Sand)
	local y = -30
	while y < height do
		local t = math.max(y, 0) / height
		local r = base * (1 - t) ^ 1.25 + 5
		local mat
		if t > 0.75 then
			mat = Enum.Material.Rock
		elseif rng:NextNumber() < 0.25 then
			mat = Enum.Material.Grass
		else
			mat = Enum.Material.LeafyGrass
		end
		local jx, jz = rng:NextNumber(-0.15, 0.15) * r, rng:NextNumber(-0.15, 0.15) * r
		Terrain:FillBall(Vector3.new(x + jx, y, z + jz), r, mat)
		y += math.max(r * 0.35, 8)
	end
	-- kaya çıkıntıları ve yan sırtlar
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local t = rng:NextNumber(0.15, 0.55)
		local rr = base * (1 - t) ^ 1.25 * 0.85
		Terrain:FillBall(Vector3.new(x + math.cos(a) * rr, height * t, z + math.sin(a) * rr), base * rng:NextNumber(0.1, 0.18), rng:NextNumber() < 0.5 and Enum.Material.Rock or Enum.Material.LeafyGrass)
	end
end

-- Eski dağları sil (yerine su doldurur); yeniden kurmadan önce
function Nature.ClearMountains(cfg)
	for _, m in Nature.MountainList(cfg) do
		local r = m.h * 0.9 + 30
		Terrain:FillCylinder(CFrame.new(m.x, 132, m.z), 336, r, Enum.Material.Air)
		Terrain:FillCylinder(CFrame.new(m.x, -18, m.z), 36, r, Enum.Material.Water)
		task.wait()
	end
end

-- from/to: dağ indeksi aralığı (yavaş olduğu için parça parça çalıştırılabilir)
function Nature.Mountains(cfg, from, to)
	local list = Nature.MountainList(cfg)
	from = from or 1
	to = math.min(to or #list, #list)
	for i = from, to do
		local m = list[i]
		mountain(m.x, m.z, m.h, Random.new(cfg.Seed * 1000 + i))
		task.wait()
	end
	return #list
end

function Nature.MountainList(cfg)
	local rng = Random.new(cfg.Seed + 77)
	local list = {}
	local R = cfg.SeaSize / 2 - 110
	for row = 0, 1 do
		local count = row == 0 and 30 or 26
		for k = 1, count do
			local a = (k + row * 0.5) / count * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
			local r = R + row * 120 + rng:NextNumber(-40, 30)
			local h = row == 0 and rng:NextNumber(70, 150) or rng:NextNumber(140, 240)
			table.insert(list, { x = math.cos(a) * r, z = math.sin(a) * r, h = h })
		end
	end
	return list
end

-- Bitki örtüsü --------------------------------------------------------------

local function okGround(x, z)
	local gy = Util.groundY(x, z)
	if not gy or gy < 4 or gy > 8 then
		return nil
	end
	-- sadece çim üstüne (yol, plaza, kum değil)
	local mats = Terrain:ReadVoxels(Region3.new(Vector3.new(x - 2, 4, z - 2), Vector3.new(x + 2, 8, z + 2)):ExpandToGrid(4), 4)
	local m = mats[1][1][1]
	if m ~= Enum.Material.Grass and m ~= Enum.Material.Air then
		return nil
	end
	return gy
end

local function far(x, z, blocks)
	for _, b in blocks do
		if (Vector2.new(x, z) - Vector2.new(b[1], b[2])).Magnitude < b[3] then
			return false
		end
	end
	return true
end

local function scatter(parent, rng, sample, counts, blocks)
	for kind, n in counts do
		local placed, tries = 0, 0
		while placed < n and tries < n * 12 do
			tries += 1
			local x, z = sample()
			if far(x, z, blocks) then
				local gy = okGround(x, z)
				if gy then
					local pos = Vector3.new(x, gy - 0.2, z)
					if kind == "bush" then
						Decor.bush(parent, pos, rng)
					elseif kind == "rock" then
						Decor.rock(parent, pos, rng)
					elseif kind == "flowers" then
						Decor.flowers(parent, pos, rng)
					elseif kind == "fern" then
						Decor.fern(parent, pos, rng)
					elseif kind == "palm" then
						Decor.palm(parent, Vector3.new(x, gy - 0.3, z), rng)
					end
					placed += 1
				end
			end
		end
	end
end

function Nature.Vegetation(cfg)
	local folder = Util.fresh("Folder", "Nature")
	-- ana ada: yapılardan uzak dur
	local P, H = cfg.Plaza, cfg.FishMarket
	local blocks = {
		{ P.x, P.z, P.radius + 6 },
		{ H.x, H.z, 46 },
		{ cfg.Pier.startX, cfg.Pier.walkZ, 14 },
		{ -135, 70, 16 },
		{ -150, -60, 16 },
	}
	local main = Instance.new("Model")
	main.Name = "MainIsland"
	main.Parent = folder
	local rng = Random.new(cfg.Seed + 901)
	local R = cfg.Main.radius
	scatter(main, rng, function()
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * R * 0.92
		return math.cos(a) * r, math.sin(a) * r
	end, { bush = 70, rock = 30, flowers = 45, fern = 30, palm = 10 }, blocks)
	task.wait()
	-- 12 özel ada
	for i = 1, cfg.Ring.count do
		local f = Layout.frame(cfg, i)
		local isl = Instance.new("Model")
		isl.Name = "Island" .. i
		isl.Parent = folder
		local r2 = Random.new(cfg.Seed * 50 + i)
		local hutP = Layout.arcPoint(cfg, f, 0) + f.back * 6
		local spawnP = Layout.arcPoint(cfg, f, 0.35)
		local tipA, tipB = Layout.arcPoint(cfg, f, -1), Layout.arcPoint(cfg, f, 1)
		local iblocks = {
			{ hutP.X, hutP.Z, 18 },
			{ spawnP.X, spawnP.Z, 6 },
			{ tipA.X, tipA.Z, 10 },
			{ tipB.X, tipB.Z, 12 },
		}
		scatter(isl, r2, function()
			local t = r2:NextNumber(-0.95, 0.95)
			local p = Layout.arcPoint(cfg, f, t)
			local rr = Layout.radiusAt(cfg, t)
			local a = r2:NextNumber(0, math.pi * 2)
			local d = math.sqrt(r2:NextNumber()) * rr * 0.85
			return p.X + math.cos(a) * d, p.Z + math.sin(a) * d
		end, { bush = 9, rock = 5, flowers = 9, fern = 5, palm = 2 }, iblocks)
		task.wait()
	end
	return folder
end

return Nature
