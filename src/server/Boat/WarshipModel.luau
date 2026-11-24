--!nonstrict
-- Warship görüntüsü (Ege'nin resmi, 24 Kas): tek direkli, tek kare yelkenli, KAVİSLİ ahşap korsan gemisi.
-- Ege: "apartman bloğu gibi olmasın, yumuşak geçişler, zarif yapı". Bu yüzden gövde düz duvarlarla değil KESİTLERDEN kurulur:
--   * plan: ortada en geniş, pruvaya doğru sivrilerek, kıça doğru hafifçe daralır (w(z))
--   * karina: kesit yuvarlak (dipte dar, üstte dik) (sectionX)
--   * küpeşte çizgisi kavisli: ortada alçak, pruvaya ve kıça doğru yumuşakça yükselir (rail(z))
--   * alt kenar pruvada kavisle kalkar (baş bodoslama), kıçta yükselir: üst kısım geriye taşar (Ege'nin çizimi) (keel(z))
-- Fizik (görünmez): güverte zeminleri, kenar duvarları, rampalar. Görüntü parçaları çarpışmasız.
-- Koordinatlar gövde merkezine göre; tekne -Z'ye (pruva) bakar. h = su seviyesinden yükseklik (y = W + h).
local WarshipModel = {}

local W = -0.65 -- gövde merkezinden su seviyesine

-- Renkler (Ege: renkler önemli değil, şekil resimdeki gibi)
local HULL = Color3.fromRGB(150, 92, 54)
local HULL_DARK = Color3.fromRGB(120, 72, 42)
local DECK = Color3.fromRGB(178, 122, 76)
local DARK = Color3.fromRGB(88, 56, 34)
local WHITE = Color3.fromRGB(242, 238, 228)
local IRON = Color3.fromRGB(50, 50, 56)
local SAIL = Color3.fromRGB(242, 234, 214)
local ROPE = Color3.fromRGB(74, 56, 38)
local WHEEL = Color3.fromRGB(214, 118, 46)
local GLASS = Color3.fromRGB(46, 62, 78)

-- Ana ölçüler
local HW = 6.3 -- en geniş yarı genişlik (küpeşte hizasında)
local BOW_TIP = -15 -- pruva ucu
local STERN_END = 17.6 -- kıç ucu
local BOW_START = -5.2 -- pruva güvertesinin arka kenarı
local CABIN_Z = 9 -- dümen platformunun ön kenarı
local DECK_WELL, DECK_BOW, DECK_STERN = 1.6, 5.9, 5.4
local MAST_Z = 3.2
local PORT_Z0, PORT_Z1, PORT_H0 = -0.1, 2.1, 2.3 -- top oyuğu (küpeştede üstü açık çentik)
local WALE_H = 2.3 -- gövde boyunca beyaz çizgi (Ege'nin çizimindeki sınır)

WarshipModel.CannonZ = 1
WarshipModel.SideX = 7.0
WarshipModel.DeckWell = DECK_WELL

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- plan: küpeşte hizasında yarı genişlik
local function w(z: number): number
	if z < 0 then
		local t = math.clamp(-z / -BOW_TIP, 0, 1)
		return math.max(HW * (1 - t ^ 1.9) ^ 0.7, 0.3) -- sivri pruva
	elseif z > 6 then
		local t = math.clamp((z - 6) / (STERN_END - 6), 0, 1)
		return HW * (1 - 0.2 * t * t)
	end
	return HW
end

-- küpeşte yüksekliği: ortada 3.3, pruvaya doğru ~6.9'a (uçta ~8.8) ve kıça doğru 6'ya (uçta 6.7) yumuşakça kalkar
local function rail(z: number): number
	local h = 3.3
	if z < -1.2 then
		h += 3.6 * smooth((-1.2 - z) / 4.6)
		local t = math.clamp((-5.8 - z) / (-5.8 - BOW_TIP), 0, 1)
		h += 1.9 * t ^ 1.7
	elseif z > 3.8 then
		h += 2.7 * smooth((z - 3.8) / 5.2)
		local t = math.clamp((z - 9) / (STERN_END - 9), 0, 1)
		h += 0.7 * t ^ 1.5
	end
	return h
end

-- gövdenin alt kenarı: ortada -1.6; pruvada kavisle kalkar, kıçta yükselir (üst kısım geriye taşar)
local function keel(z: number): number
	if z < -7 then
		local t = math.clamp((-7 - z) / (-7 - BOW_TIP), 0, 1)
		return -1.6 + 6.6 * t ^ 2.2
	elseif z > 11.5 then
		local t = math.clamp((z - 11.5) / (STERN_END - 11.5), 0, 1)
		return -1.6 + 3.9 * t ^ 1.6
	end
	return -1.6
end

-- kesit: s = 0 (dip) .. 1 (küpeşte) -> (x, h). Dipte dar, yuvarlak karina, üstte neredeyse dik
local function sectionPoint(z: number, s: number): (number, number)
	local f = 0.22 + 0.78 * math.sin(s * math.pi / 2) ^ 0.55
	local hb, hr = keel(z), rail(z)
	return w(z) * f, hb + (hr - hb) * s
end

-- verilen yükseklikte gövde dış yüzeyinin x'i (yoksa nil)
local function hullXAt(z: number, h: number): number?
	local hb, hr = keel(z), rail(z)
	if h < hb or h > hr then
		return nil
	end
	local x = sectionPoint(z, (h - hb) / (hr - hb))
	return x
end

WarshipModel.HullXAt = hullXAt

-- gövde boyunca z kesitleri: uçlarda sık (kavis düzgün olsun), ortada seyrek
local function stations(): { number }
	local zs = {}
	local z = BOW_TIP
	while z < STERN_END - 0.01 do
		table.insert(zs, z)
		local step = if z < -6 then 0.9 elseif z < -0.4 then 1.0 elseif z > 12 then 0.9 elseif z > 3.4 then 1.0 else 1.1
		-- top oyuğunun kenarlarına denk getir
		for _, edge in { PORT_Z0, PORT_Z1 } do
			if z < edge - 0.05 and z + step > edge + 0.05 then
				step = edge - z
			end
		end
		z += step
	end
	table.insert(zs, STERN_END)
	return zs
end

function WarshipModel.Build(m: Model, newPart, seat)
	local parts = {}
	local function add(p, cf, hinge, attach)
		table.insert(parts, { p, cf, hinge, attach })
		return p
	end
	local function vis(name, size, cf, color, mat, shape)
		local p = newPart(m, name, size, color, mat or Enum.Material.WoodPlanks, shape)
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		return add(p, cf)
	end
	local function ghost(name, size, cf)
		local p = newPart(m, name, size, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		p.Transparency = 1
		return add(p, cf)
	end
	local function at(x, h, z)
		return CFrame.new(x, W + h, z)
	end
	local function P(x, h, z)
		return Vector3.new(x, W + h, z)
	end
	local function beam(name, a, b, dia, color, mat, cyl)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		if cyl then
			return vis(name, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, math.pi / 2, 0), color, mat, "cyl")
		end
		return vis(name, Vector3.new(dia, dia, len), cf, color, mat)
	end
	-- dört köşeli yüzey parçası (gövde tahtası): a,b ön kenar (alt, üst), c,d arka kenar (alt, üst)
	local function quad(name, a, b, c, d, thick, color, mat)
		local center = (a + b + c + d) / 4
		local u = ((c + d) - (a + b)) / 2 -- boyuna
		local v = ((b + d) - (a + c)) / 2 -- yukarı
		if u.Magnitude < 0.01 or v.Magnitude < 0.01 then
			return nil
		end
		local zA = u.Unit
		local yA = (v - zA * v:Dot(zA))
		if yA.Magnitude < 0.001 then
			return nil
		end
		yA = yA.Unit
		local xA = yA:Cross(zA)
		return vis(name, Vector3.new(thick, v.Magnitude + 0.12, u.Magnitude + 0.12), CFrame.fromMatrix(center, xA, yA, zA), color, mat)
	end
	local function face(pos, normal)
		return CFrame.lookAt(pos, pos + normal)
	end
	local function window(pos, normal, ww, hh)
		vis("WinFrame", Vector3.new(ww + 0.45, hh + 0.45, 0.12), face(pos + normal * 0.08, normal), WHITE, Enum.Material.SmoothPlastic)
		vis("WinGlass", Vector3.new(ww, hh, 0.14), face(pos + normal * 0.11, normal), GLASS, Enum.Material.Glass)
		vis("WinBar", Vector3.new(0.14, hh, 0.16), face(pos + normal * 0.12, normal), WHITE, Enum.Material.SmoothPlastic)
		vis("WinBar", Vector3.new(ww, 0.14, 0.16), face(pos + normal * 0.12, normal), WHITE, Enum.Material.SmoothPlastic)
	end

	local zs = stations()

	---------------------------------------------------------------------------------------------
	-- FİZİK (görünmez): güverteler gövdenin planını izler (dışarıda yürünmesin)
	---------------------------------------------------------------------------------------------
	local hull = newPart(m, "Hull", Vector3.new(8, 3.2, 12), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	hull.Transparency = 1
	hull.CanCollide = false
	local function floorRun(name, top, z0, z1, step, edgeH)
		local z = z0
		while z < z1 - 0.01 do
			local za = math.min(z + step, z1)
			local half = math.min(w(z), w(za)) - 0.55
			if half > 0.4 then
				ghost(name, Vector3.new(2 * half, 3, za - z + 0.05), at(0, top - 1.5, (z + za) / 2))
				if edgeH then
					for _, side in { -1, 1 } do
						ghost(name .. "Edge", Vector3.new(0.5, edgeH, za - z + 0.05), at(side * (half + 0.2), top + edgeH / 2, (z + za) / 2))
					end
				end
			end
			z = za
		end
	end
	floorRun("DeckWell", DECK_WELL, BOW_START, CABIN_Z, 12.4, nil)
	floorRun("DeckBow", DECK_BOW, BOW_TIP + 1.2, BOW_START, 1.5, 1.5)
	floorRun("DeckStern", DECK_STERN, CABIN_Z, STERN_END - 0.4, 1.5, 1.8)
	for _, side in { -1, 1 } do
		ghost("WellWall", Vector3.new(0.6, 7, CABIN_Z - BOW_START), at(side * (HW - 0.2), DECK_WELL + 3.5, (CABIN_Z + BOW_START) / 2))
	end
	ghost("SternRail", Vector3.new(2 * w(STERN_END), 1.8, 0.6), at(0, DECK_STERN + 0.9, STERN_END - 0.6))
	local function ramp(name, x, z0, z1, y0, y1)
		local len, rise = math.abs(z1 - z0), y1 - y0
		local wdg = Instance.new("WedgePart")
		wdg.Name = name
		wdg.Size = Vector3.new(2.4, rise, len)
		wdg.Transparency = 1
		wdg.Parent = m
		local cf = CFrame.new(x, W + y0 + rise / 2, (z0 + z1) / 2)
		if z1 < z0 then
			cf = cf * CFrame.Angles(0, math.pi, 0)
		end
		add(wdg, cf)
	end
	local BOW_RAMP_X, STERN_RAMP_X = 2.0, 2.6
	ramp("RampBow", BOW_RAMP_X, 0.4, BOW_START, DECK_WELL, DECK_BOW)
	ramp("RampStern", STERN_RAMP_X, 4.6, CABIN_Z, DECK_WELL, DECK_STERN)

	---------------------------------------------------------------------------------------------
	-- GÖVDE: kesitler arası kavisli tahta şeritler
	---------------------------------------------------------------------------------------------
	local BANDS = { 0, 0.2, 0.42, 0.66, 1 }
	local function pt(side, z, s)
		local x, h = sectionPoint(z, s)
		return P(side * x, h, z)
	end
	for i = 1, #zs - 1 do
		local z0, z1 = zs[i], zs[i + 1]
		local zm = (z0 + z1) / 2
		local inPort = zm > PORT_Z0 and zm < PORT_Z1
		for _, side in { -1, 1 } do
			for b = 1, #BANDS - 1 do
				local s0, s1 = BANDS[b], BANDS[b + 1]
				local a, bb, c, d = pt(side, z0, s0), pt(side, z0, s1), pt(side, z1, s0), pt(side, z1, s1)
				if inPort and b == #BANDS - 1 then
					-- top oyuğu: üst şeridin üstü PORT_H0'da kesilir
					local function clampH(p0, p1)
						local t = math.clamp((W + PORT_H0 - p0.Y) / math.max(p1.Y - p0.Y, 0.01), 0, 1)
						return p0:Lerp(p1, t)
					end
					bb, d = clampH(a, bb), clampH(c, d)
				end
				quad("Plank", a, bb, c, d, 0.5, (b % 2 == 0) and HULL or HULL_DARK)
			end
			-- küpeşte üstündeki beyaz kapak (oyuk hariç)
			if not inPort then
				local a, c = pt(side, z0, 1), pt(side, z1, 1)
				local len = (c - a).Magnitude
				vis("RailCap", Vector3.new(0.75, 0.28, len + 0.14), CFrame.lookAt((a + c) / 2, c) * CFrame.new(-side * 0.08, 0.1, 0), WHITE, Enum.Material.SmoothPlastic)
			end
			-- beyaz çizgi ve su hattındaki koyu şerit: o yükseklikte gövdenin dış yüzeyinde
			for _, line in { { WALE_H, WHITE, Enum.Material.SmoothPlastic, 0.26 }, { 0.2, IRON, Enum.Material.Metal, 0.5 } } do
				local x0, x1 = hullXAt(z0, line[1]), hullXAt(z1, line[1])
				if x0 and x1 and not (inPort and line[1] > PORT_H0 - 0.1) then
					local a, c = P(side * (x0 + 0.06), line[1], z0), P(side * (x1 + 0.06), line[1], z1)
					vis("Line", Vector3.new(0.18, line[4], (c - a).Magnitude + 0.14), CFrame.lookAt((a + c) / 2, c), line[2], line[3])
				end
			end
		end
		-- dip: iki yanın alt kenarı arası
		local a, b = pt(-1, z0, 0), pt(1, z0, 0)
		local c, d = pt(-1, z1, 0), pt(1, z1, 0)
		local center = (a + b + c + d) / 4
		vis("Keel", Vector3.new((b - a).Magnitude + 0.3, 0.45, (c - a).Magnitude + 0.12), CFrame.lookAt(center, center + (c - a)), HULL_DARK)
	end
	-- top oyuğunun beyaz çerçevesi (U)
	for _, side in { -1, 1 } do
		local x = (hullXAt(1, PORT_H0) or HW) + 0.07
		vis("PortTrim", Vector3.new(0.18, 0.24, PORT_Z1 - PORT_Z0 + 0.24), at(side * x, PORT_H0 - 0.05, (PORT_Z0 + PORT_Z1) / 2), WHITE, Enum.Material.SmoothPlastic)
		for _, zz in { PORT_Z0 - 0.05, PORT_Z1 + 0.05 } do
			vis("PortTrim", Vector3.new(0.18, rail(zz) - PORT_H0 + 0.3, 0.24), at(side * x, (PORT_H0 + rail(zz)) / 2 + 0.05, zz), WHITE, Enum.Material.SmoothPlastic)
		end
	end
	-- kavisli baş bodoslama (pruvanın alt kenarından uca kıvrılan koyu kiriş) + uçta beyaz başlık
	do
		local prev = nil
		local z = -7
		while z >= BOW_TIP - 0.01 do
			local p = P(0, keel(z) - 0.1, z - 0.15)
			if prev then
				beam("Stem", prev, p, 0.7, DARK, Enum.Material.Wood)
			end
			prev = p
			z -= 1
		end
		beam("Stem", prev, P(0, rail(BOW_TIP) + 0.4, BOW_TIP - 0.25), 0.7, DARK, Enum.Material.Wood)
		vis("StemCap", Vector3.new(0.9, 0.3, 0.9), at(0, rail(BOW_TIP) + 0.45, BOW_TIP - 0.2), WHITE, Enum.Material.SmoothPlastic)
	end
	-- kıç aynası: kıç ucunda iki yanın kesitleri arası yatay şeritler + 2 pencere
	do
		local z = STERN_END
		for b = 1, #BANDS - 1 do
			local x0, h0 = sectionPoint(z, BANDS[b])
			local x1, h1 = sectionPoint(z, BANDS[b + 1])
			vis("Transom", Vector3.new(2 * math.max(x0, x1) + 0.3, h1 - h0 + 0.1, 0.5), at(0, (h0 + h1) / 2, z - 0.2), (b % 2 == 0) and HULL or HULL_DARK)
		end
		local xr = sectionPoint(z, 1)
		vis("RailCap", Vector3.new(2 * xr + 0.5, 0.28, 0.75), at(0, rail(z) + 0.1, z - 0.2), WHITE, Enum.Material.SmoothPlastic)
		for _, x in { -2.2, 2.2 } do
			window(P(x, rail(z) - 1.6, z), Vector3.new(0, 0, 1), 1.2, 1.1)
		end
	end
	-- pruva yanında beyaz çerçeveli pencere (resimdeki gibi)
	for _, side in { -1, 1 } do
		local z, h = -7.6, 5.3
		local x = hullXAt(z, h) or w(z)
		local n = Vector3.new(side * 1, 0, -0.35).Unit
		window(P(side * x, h, z), n, 1.2, 1.2)
	end

	---------------------------------------------------------------------------------------------
	-- GÜVERTELER (planı izleyen şeritler), BÖLMELER, MERDİVENLER, KORKULUK
	---------------------------------------------------------------------------------------------
	local function deckRun(top, z0, z1, step)
		local z = z0
		while z < z1 - 0.01 do
			local za = math.min(z + step, z1)
			local hz = (top < 3) and math.min(hullXAt(z, top) or 0, hullXAt(za, top) or 0) or math.min(w(z), w(za))
			if hz > 0.5 then
				vis("Deck", Vector3.new(2 * hz - 0.4, 0.35, za - z + 0.06), at(0, top - 0.17, (z + za) / 2), DECK)
			end
			z = za
		end
	end
	deckRun(DECK_WELL, BOW_START, CABIN_Z, 1.2)
	deckRun(DECK_BOW, BOW_TIP + 0.8, BOW_START, 0.9)
	deckRun(DECK_STERN, CABIN_Z, STERN_END - 0.2, 1.0)
	-- pruva ve dümen platformunun çukura bakan duvarları
	vis("Bulkhead", Vector3.new(2 * HW - 0.8, DECK_BOW - DECK_WELL, 0.45), at(0, (DECK_BOW + DECK_WELL) / 2, BOW_START + 0.22), HULL)
	vis("Trim", Vector3.new(2 * HW - 0.8, 0.26, 0.6), at(0, DECK_BOW + 0.05, BOW_START + 0.22), WHITE, Enum.Material.SmoothPlastic)
	vis("Bulkhead", Vector3.new(2 * HW - 0.8, DECK_STERN - DECK_WELL, 0.45), at(0, (DECK_STERN + DECK_WELL) / 2, CABIN_Z - 0.22), HULL)
	vis("Trim", Vector3.new(2 * HW - 0.8, 0.26, 0.6), at(0, DECK_STERN + 0.05, CABIN_Z - 0.22), WHITE, Enum.Material.SmoothPlastic)
	local dn = Vector3.new(0, 0, -1)
	vis("DoorFrame", Vector3.new(1.9, 3.0, 0.12), face(P(-2.4, DECK_WELL + 1.5, CABIN_Z - 0.5), dn), WHITE, Enum.Material.SmoothPlastic)
	vis("Door", Vector3.new(1.5, 2.75, 0.16), face(P(-2.4, DECK_WELL + 1.4, CABIN_Z - 0.54), dn), DARK, Enum.Material.WoodPlanks)
	local up = Vector3.new(0, 0, 1)
	vis("DoorFrame", Vector3.new(1.9, 3.0, 0.12), face(P(-2.4, DECK_WELL + 1.5, BOW_START + 0.5), up), WHITE, Enum.Material.SmoothPlastic)
	vis("Door", Vector3.new(1.5, 2.75, 0.16), face(P(-2.4, DECK_WELL + 1.4, BOW_START + 0.54), up), DARK, Enum.Material.WoodPlanks)

	-- dümen platformu korkuluğu: gövdenin planını izleyen dikmeler + beyaz kavisli tutamak
	local RAIL_H = 1.2
	local function railPoints(side, z0, z1, step)
		local pts = {}
		local z = z0
		while z <= z1 + 0.01 do
			table.insert(pts, P(side * (w(z) - 0.35), rail(z) + 0.2, z))
			z += step
		end
		return pts
	end
	local function railLine(pts)
		for i, p in pts do
			vis("Baluster", Vector3.new(0.2, RAIL_H, 0.2), CFrame.new(p + Vector3.new(0, RAIL_H / 2, 0)), DARK, Enum.Material.Wood)
			if i > 1 then
				beam("Rail", pts[i - 1] + Vector3.new(0, RAIL_H, 0), p + Vector3.new(0, RAIL_H, 0), 0.26, WHITE, Enum.Material.SmoothPlastic)
			end
		end
	end
	for _, side in { -1, 1 } do
		railLine(railPoints(side, CABIN_Z - 0.2, STERN_END - 0.4, 1.4))
	end
	do
		local zb = STERN_END - 0.4
		local xb = w(zb) - 0.35
		railLine({ P(-xb, rail(zb) + 0.2, zb), P(-xb / 2, rail(zb) + 0.2, zb), P(0, rail(zb) + 0.2, zb), P(xb / 2, rail(zb) + 0.2, zb), P(xb, rail(zb) + 0.2, zb) })
	end
	-- platformun ön kenarı (merdiven boşluğu hariç)
	railLine({ P(-(HW - 0.4), DECK_STERN, CABIN_Z - 0.15), P(-2.6, DECK_STERN, CABIN_Z - 0.15), P(-0.6, DECK_STERN, CABIN_Z - 0.15), P(STERN_RAMP_X - 1.4, DECK_STERN, CABIN_Z - 0.15) })
	-- pruva güvertesinin arka kenarı (merdiven boşluğu hariç)
	railLine({ P(-(HW - 0.4), DECK_BOW, BOW_START + 0.15), P(-3, DECK_BOW, BOW_START + 0.15), P(BOW_RAMP_X - 1.4, DECK_BOW, BOW_START + 0.15) })

	local function stairs(x, z0, z1, h0, h1)
		local n = 7
		local len = z1 - z0
		for i = 1, n do
			local zz = z0 + (i - 0.5) * len / n
			local hh = h0 + i * (h1 - h0) / n
			vis("Step", Vector3.new(2.3, 0.26, math.abs(len) / n + 0.08), at(x, hh - 0.13, zz), DECK)
		end
		for _, dx in { -1.25, 1.25 } do
			beam("Stringer", P(x + dx, h0, z0), P(x + dx, h1, z1), 0.3, DARK, Enum.Material.Wood)
		end
	end
	stairs(STERN_RAMP_X, 4.6, CABIN_Z, DECK_WELL, DECK_STERN)
	stairs(BOW_RAMP_X, 0.4, BOW_START, DECK_WELL, DECK_BOW)

	---------------------------------------------------------------------------------------------
	-- DİREK + TEK BÜYÜK YELKEN + İNCE HALATLAR
	---------------------------------------------------------------------------------------------
	local MAST_TOP = 27
	vis("Mast", Vector3.new(MAST_TOP - DECK_WELL, 1.1, 1.1), at(0, (MAST_TOP + DECK_WELL) / 2, MAST_Z) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood, "cyl")
	vis("MastCap", Vector3.new(1.4, 1.4, 1.4), at(0, MAST_TOP + 0.3, MAST_Z), DARK, Enum.Material.Wood, "ball")
	vis("MastRing", Vector3.new(0.35, 1.6, 1.6), at(0, DECK_WELL + 0.3, MAST_Z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, "cyl")
	local YARD_H, SAIL_LOW = MAST_TOP - 1.2, 11.5
	local SAIL_W = 14
	local sailCf = at(0, 0, MAST_Z) * CFrame.Angles(0, math.rad(40), 0)
	local function sailPart(name, size, rel, color, mat, shape)
		local p = vis(name, size, CFrame.new(), color, mat, shape)
		parts[#parts][2] = sailCf * rel
		return p
	end
	sailPart("Yard", Vector3.new(SAIL_W + 1.6, 0.5, 0.5), CFrame.new(0, W + YARD_H, -0.7), DARK, Enum.Material.Wood, "cyl")
	local strips = 8
	local sw = SAIL_W / strips
	for i = 1, strips do
		local u = (i - 0.5) / strips * 2 - 1
		local bulge = (1 - u * u) * 1.4
		local top = YARD_H - 0.2
		local low = SAIL_LOW - (1 - u * u) * 0.8 -- alt kenar ortada sarkık (yumuşak kavis)
		sailPart("Sail", Vector3.new(sw + 0.1, top - low, 0.16), CFrame.new(u * SAIL_W / 2, W + (top + low) / 2, -0.9 - bulge) * CFrame.Angles(0, -u * 0.36, 0), SAIL, Enum.Material.Fabric)
	end
	local tipZ = BOW_TIP - 0.2
	local spritA, spritB = P(0, rail(tipZ) - 0.2, tipZ + 2.6), P(0, rail(tipZ) + 3.6, tipZ - 6)
	beam("Bowsprit", spritA, spritB, 0.7, DARK, Enum.Material.Wood, true)
	-- halat yok (Ege 24 Kas: ipleri sil)

	---------------------------------------------------------------------------------------------
	-- DÜMEN + KOLTUK + SÜS
	---------------------------------------------------------------------------------------------
	local deckStern = W + DECK_STERN
	local WZ = CABIN_Z + 1.6
	-- dümen parçaları çarpışmasız: karakter üstüne tırmanmasın (Ege 24 Kas)
	local post = newPart(m, "WheelPost", Vector3.new(0.8, 2.6, 0.8), DARK, Enum.Material.Wood)
	post.CanCollide = false
	add(post, CFrame.new(0, deckStern + 1.3, WZ + 0.35))
	local wheel = newPart(m, "Wheel", Vector3.new(0.4, 3.4, 3.4), WHEEL, Enum.Material.Wood, "cyl")
	wheel.CanCollide = false
	add(wheel, CFrame.new(0, deckStern + 3.1, WZ) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new())
	for k = 0, 3 do
		local spoke = newPart(m, "Spoke", Vector3.new(0.22, 4.6, 0.26), WHEEL, Enum.Material.Wood)
		spoke.CanCollide = false
		add(spoke, CFrame.new(0, deckStern + 3.1, WZ) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(k * math.pi / 4, 0, 0), nil, "Wheel")
	end
	add(seat(m, Vector3.new(2.4, 0.5, 2), DARK), CFrame.new(0, deckStern + 0.25, WZ + 2.3))
	vis("Hatch", Vector3.new(2.2, 0.8, 2), at(-1.2, DECK_BOW + 0.4, -8.5), Color3.fromRGB(120, 78, 46), Enum.Material.WoodPlanks)
	vis("Barrel", Vector3.new(1.4, 1.1, 1.1), at(-4.2, DECK_WELL + 0.7, 6.2) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(130, 84, 48), Enum.Material.Wood, "cyl")

	return hull, parts
end

return WarshipModel
