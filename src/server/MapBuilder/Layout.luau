--!nonstrict
-- Saf matematik: adaların ve ana adanın yeri. Hiçbir şey kurmaz.
local Layout = {}

-- i. özel adanın çerçevesi. u: merkeze bakan yön (hilalin ağzı), back: dışa bakan yön.
function Layout.frame(cfg, i)
	local ring, isl = cfg.Ring, cfg.Island
	local theta = math.rad(ring.startAngle + (i - 1) * 360 / ring.count)
	local out = Vector3.new(math.cos(theta), 0, math.sin(theta))
	local center = out * ring.radius
	local u = -out
	local bay = center + u * isl.bayShift
	return {
		index = i,
		theta = theta,
		center = center,
		u = u,
		back = out,
		bay = bay,
		phi0 = math.atan2(out.Z, out.X),
	}
end

-- Hilal yayı üzerindeki nokta. t: -1 (bir boynuz) ... 0 (sırt) ... 1 (öteki boynuz)
function Layout.arcPoint(cfg, f, t)
	local isl = cfg.Island
	local phi = f.phi0 + t * math.rad(isl.arc)
	return f.bay + Vector3.new(math.cos(phi), 0, math.sin(phi)) * isl.bayRadius, phi
end

function Layout.radiusAt(cfg, t)
	local isl = cfg.Island
	return isl.backRadius - (isl.backRadius - isl.tipRadius) * math.abs(t) ^ 1.5
end

-- Hilalı oluşturan daireler {x, z, yarıçap}
function Layout.discs(cfg, f)
	local out, n = {}, 25
	for k = 0, n - 1 do
		local t = k / (n - 1) * 2 - 1
		local p = Layout.arcPoint(cfg, f, t)
		table.insert(out, { p.X, p.Z, Layout.radiusAt(cfg, t) })
	end
	return out
end

local function inside(poly, x, z)
	local c = false
	local j = #poly
	for i = 1, #poly do
		local xi, zi, xj, zj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
		if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
			c = not c
		end
		j = i
	end
	return c
end

local function edgeDist(poly, x, z)
	local best = math.huge
	local j = #poly
	for i = 1, #poly do
		local ax, az, bx, bz = poly[j][1], poly[j][2], poly[i][1], poly[i][2]
		local dx, dz = bx - ax, bz - az
		local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
		local px, pz = ax + dx * t, az + dz * t
		best = math.min(best, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))
		j = i
	end
	return best
end

Layout.insidePoly = inside
Layout.edgeDist = edgeDist

-- Ana adayı oluşturan daireler.
-- outline varsa: çizginin içini ızgara noktalarıyla doldurur; her daire kıyıya kadar uzanır (yumuşak, doğal kenar).
function Layout.mainDiscs(cfg)
	local poly = cfg.Main.outline
	if poly then
		local rng = Random.new(cfg.Seed + 3)
		local out = {}
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, p in poly do
			minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
			minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
		end
		local step = 18
		for x = minX, maxX, step do
			for z = minZ, maxZ, step do
				local jx, jz = x + rng:NextNumber(-4, 4), z + rng:NextNumber(-4, 4)
				if inside(poly, jx, jz) then
					local d = edgeDist(poly, jx, jz)
					if d > 5 then
						-- kenar dalgası: kıyıya yakın dairelerin boyu hafif oynar
						local r = math.min(d * rng:NextNumber(0.88, 1.0), 46)
						table.insert(out, { jx, jz, r })
					end
				end
			end
		end
		return out
	end
	return Layout.roundDiscs(cfg)
end

-- Eski yuvarlak ana ada
function Layout.roundDiscs(cfg)
	local R = cfg.Main.radius
	local rng = Random.new(cfg.Seed)
	local out = { { 0, 0, R * 0.70 } }
	for i = 0, 15 do
		local a = math.rad(i * 22.5 + rng:NextNumber(-6, 6))
		local d = R * 0.66 * (0.9 + 0.22 * rng:NextNumber())
		local r = R * 0.34 * (0.85 + 0.3 * rng:NextNumber())
		table.insert(out, { math.cos(a) * d, math.sin(a) * d, r })
	end
	return out
end

return Layout
