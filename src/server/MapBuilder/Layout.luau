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

-- Ana adayı oluşturan daireler (düzensiz kıyı için sabit tohumla)
function Layout.mainDiscs(cfg)
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
