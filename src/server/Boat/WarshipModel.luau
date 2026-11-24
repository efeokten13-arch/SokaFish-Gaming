--!nonstrict
-- Warship görüntüsü (Ege'nin resmi, 24 Kas): tek direkli, tek kare yelkenli korsan gemisi; ahşap gövde, beyaz çerçeveler,
-- yüksek pruva, KIÇ KULESİ (dümenin altı kapalı, tahta kaplı; üst kısmı geriye taşar), turuncu dümen, her yanda 1 top.
-- Eski hali yapay zeka mesh'iydi (ServerStorage.BoatTemplates.Warship): yelkenleri görüşü kapatıyordu.
-- Fizik (görünmez): gövde kökü, güverte zeminleri, çukurun yan duvarları, rampalar. Görüntü parçaları çarpışmasız.
-- Koordinatlar gövde merkezine göre; tekne -Z'ye (pruva) bakar. h = su seviyesinden yükseklik (y = W + h).
local WarshipModel = {}

local W = -0.65 -- gövde merkezinden su seviyesine

-- Renkler (Ege: renkler önemli değil, şekil resimdeki gibi)
local HULL = Color3.fromRGB(150, 92, 54)
local DECK = Color3.fromRGB(178, 122, 76)
local DARK = Color3.fromRGB(88, 56, 34)
local WHITE = Color3.fromRGB(242, 238, 228)
local IRON = Color3.fromRGB(50, 50, 56)
local SAIL = Color3.fromRGB(242, 234, 214)
local ROPE = Color3.fromRGB(74, 56, 38)
local WHEEL = Color3.fromRGB(214, 118, 46)
local GLASS = Color3.fromRGB(46, 62, 78)

-- Ölçüler (Ege'nin resminden: uzun ve ALÇAK gövde, pruva en yüksek kısım, dümen platformu orta küpeştenin biraz üstünde,
-- orta küpeşte alçak: iki top da güvertede görünür)
local HW = 6.3 -- gövde yarı genişliği
local BOTTOM = -1.4 -- gövdenin alt kenarı
local BOW_TIP = -14.5 -- pruva ucu
local BOW_NARROW = -8.5 -- pruva bu z'den öne doğru daralır
local BOW_START = -3.4 -- pruva güvertesinin arka kenarı
local CASTLE_FROM = 3.6 -- kıç bölümünün kapalı yan duvarı direğin arkasından başlar (Ege'nin çizimi)
local CABIN_Z = 9 -- dümen platformunun ön kenarı
local STERN = 15.6 -- alt gövdenin bittiği yer
local CASTLE_END = 18.4 -- platformun üst kısmı geriye taşar
local OVERHANG_H = 2.7 -- taşan kısmın alt kenarı (çizimdeki iki dikdörtgenin sınırı)
local DECK_WELL, DECK_BOW, DECK_STERN = 1.6, 5.9, 5.4
local WELL_TOP = 3.3 -- orta küpeşte (alçak)
local BOW_TOP = 7.1 -- pruva küpeştesi
local STERN_TOP = 5.9 -- kıç yan duvarının üstü (üstünde korkuluk)
local MAST_Z = 3.2
local PORT_Z0, PORT_Z1, PORT_H0 = -0.1, 2.1, 2.3 -- top oyuğu (küpeştede üstü açık çentik)

WarshipModel.CannonZ = 1
WarshipModel.SideX = 7.0
WarshipModel.DeckWell = DECK_WELL

-- gövdenin z'deki yarı genişliği: pruvada yuvarlak daralır
local function hw(z: number): number
	if z >= BOW_NARROW then
		return HW
	end
	local t = math.clamp((z - BOW_TIP) / (BOW_NARROW - BOW_TIP), 0, 1)
	return 0.7 + (HW - 0.7) * (1 - (1 - t) ^ 2)
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
	-- a'dan b'ye uzanan çubuk (halat, cıvadıra): blok ya da silindir
	local function beam(name, a, b, dia, color, mat, cyl)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		if cyl then
			return vis(name, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, math.pi / 2, 0), color, mat, "cyl")
		end
		return vis(name, Vector3.new(dia, dia, len), cf, color, mat)
	end
	local function trim(size, cf)
		return vis("Trim", size, cf, WHITE, Enum.Material.SmoothPlastic)
	end
	local function face(pos, normal)
		return CFrame.lookAt(pos, pos + normal)
	end
	-- beyaz çerçeveli, 4 bölmeli pencere (resimdeki gibi)
	local function window(pos, normal, w, h)
		vis("WinFrame", Vector3.new(w + 0.45, h + 0.45, 0.12), face(pos + normal * 0.06, normal), WHITE, Enum.Material.SmoothPlastic)
		vis("WinGlass", Vector3.new(w, h, 0.14), face(pos + normal * 0.09, normal), GLASS, Enum.Material.Glass)
		vis("WinBar", Vector3.new(0.14, h, 0.16), face(pos + normal * 0.1, normal), WHITE, Enum.Material.SmoothPlastic)
		vis("WinBar", Vector3.new(w, 0.14, 0.16), face(pos + normal * 0.1, normal), WHITE, Enum.Material.SmoothPlastic)
	end

	---------------------------------------------------------------------------------------------
	-- FİZİK (görünmez)
	---------------------------------------------------------------------------------------------
	local hull = newPart(m, "Hull", Vector3.new(8, 3.2, 12), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	hull.Transparency = 1
	hull.CanCollide = false
	local function floor(name, size, top, z)
		ghost(name, size, at(0, top - size.Y / 2, z))
	end
	floor("DeckWell", Vector3.new(2 * HW - 0.6, 3, CABIN_Z - BOW_START), DECK_WELL, (CABIN_Z + BOW_START) / 2)
	floor("DeckBow", Vector3.new(2 * HW - 1, 3, BOW_START - BOW_NARROW), DECK_BOW, (BOW_START + BOW_NARROW) / 2)
	floor("DeckBow", Vector3.new(2 * hw(-11.5) - 1, 3, 3), DECK_BOW, -10)
	floor("DeckStern", Vector3.new(2 * HW - 1, 3, CASTLE_END - CABIN_Z), DECK_STERN, (CABIN_Z + CASTLE_END) / 2)
	for _, side in { -1, 1 } do
		ghost("WellWall", Vector3.new(0.6, 7, CABIN_Z - BOW_START), at(side * (HW - 0.2), DECK_WELL + 3.5, (CABIN_Z + BOW_START) / 2))
		ghost("SternRail", Vector3.new(0.6, 1.8, CASTLE_END - CABIN_Z), at(side * (HW - 0.4), DECK_STERN + 0.9, (CABIN_Z + CASTLE_END) / 2))
		ghost("BowRail", Vector3.new(0.6, 1.6, BOW_START - BOW_NARROW), at(side * (HW - 0.4), DECK_BOW + 0.8, (BOW_START + BOW_NARROW) / 2))
	end
	ghost("SternRail", Vector3.new(2 * HW, 1.8, 0.6), at(0, DECK_STERN + 0.9, CASTLE_END - 0.4))
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
	local BOW_RAMP_X, STERN_RAMP_X = 2.0, -2.6
	ramp("RampBow", BOW_RAMP_X, 0.4, BOW_START, DECK_WELL, DECK_BOW)
	ramp("RampStern", STERN_RAMP_X, 4.6, CABIN_Z, DECK_WELL, DECK_STERN)

	---------------------------------------------------------------------------------------------
	-- GÖVDE: tahta bordalar, beyaz üst çerçeve, su hattında koyu şerit
	---------------------------------------------------------------------------------------------
	local function wall(side, z0, z1, hb, ht, cap)
		local x0, x1 = side * (hw(z0) - 0.3), side * (hw(z1) - 0.3)
		local mid = (hb + ht) / 2
		local a, b = Vector3.new(x0, W + mid, z0), Vector3.new(x1, W + mid, z1)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		vis("HullSide", Vector3.new(0.6, ht - hb, len + 0.14), cf, HULL)
		if cap then
			trim(Vector3.new(0.9, 0.3, len + 0.16), cf * CFrame.new(0, (ht - hb) / 2 + 0.1, 0))
		end
		if hb < 0.4 then
			vis("IronBand", Vector3.new(0.7, 0.5, len + 0.16), cf * CFrame.new(0, 0.15 - mid, 0), IRON, Enum.Material.Metal)
		end
	end

	for _, side in { -1, 1 } do
		-- PRUVA: geminin en yüksek kısmı; önde daralır, alt kenarı ve üstü öne doğru kalkar
		local z = BOW_TIP + 0.5
		while z < BOW_START - 0.01 do
			local z1 = math.min(z + (z < BOW_NARROW and 1 or 2.5), BOW_START)
			local zm = (z + z1) / 2
			local k = math.clamp((BOW_NARROW - zm) / (BOW_NARROW - BOW_TIP), 0, 1) -- 0 düz kısım, 1 uç
			wall(side, z, z1, BOTTOM + 3.2 * k ^ 2, BOW_TOP + 1.4 * k ^ 1.5, true)
			z = z1
		end
		-- ORTA: alçak küpeşte, topun olduğu yerde üstü açık çentik
		wall(side, BOW_START, CASTLE_FROM, BOTTOM, PORT_H0, false)
		wall(side, BOW_START, PORT_Z0, PORT_H0, WELL_TOP, true)
		wall(side, PORT_Z1, CASTLE_FROM, PORT_H0, WELL_TOP, true)
		-- çentiğin beyaz çerçevesi (U)
		local px = side * (HW + 0.03)
		trim(Vector3.new(0.18, 0.24, PORT_Z1 - PORT_Z0 + 0.24), at(px, PORT_H0 - 0.05, (PORT_Z0 + PORT_Z1) / 2))
		for _, zz in { PORT_Z0 - 0.05, PORT_Z1 + 0.05 } do
			trim(Vector3.new(0.18, WELL_TOP - PORT_H0 + 0.3, 0.24), at(px, (PORT_H0 + WELL_TOP) / 2 + 0.05, zz))
		end
		-- KIÇ (Ege'nin çizimi): direğin arkasından itibaren platform yüksekliğine kadar kapalı tahta duvar
		wall(side, CASTLE_FROM, STERN, BOTTOM, STERN_TOP, true)
		-- üst kısım geriye taşar
		wall(side, STERN, CASTLE_END, OVERHANG_H, STERN_TOP, true)
		-- beyaz çerçeve çizgileri: iki dikdörtgenin sınırı + dikey çizgiler (çizimdeki gibi)
		trim(Vector3.new(0.18, 0.26, CASTLE_END - CASTLE_FROM), at(side * (HW + 0.03), OVERHANG_H, (CASTLE_FROM + CASTLE_END) / 2))
		for _, zz in { CASTLE_FROM + 0.1, CABIN_Z } do
			trim(Vector3.new(0.18, STERN_TOP - OVERHANG_H, 0.26), at(side * (HW + 0.03), (OVERHANG_H + STERN_TOP) / 2, zz))
		end
		trim(Vector3.new(0.18, STERN_TOP - OVERHANG_H + 0.2, 0.26), at(side * (HW + 0.03), (OVERHANG_H + STERN_TOP) / 2, CASTLE_END - 0.12))
		trim(Vector3.new(0.18, OVERHANG_H - BOTTOM, 0.26), at(side * (HW + 0.03), (OVERHANG_H + BOTTOM) / 2 + 0.3, STERN - 0.12))
		-- pruvadaki beyaz çerçeveli panel + pencere (resimdeki gibi)
		local pz0, pz1 = BOW_NARROW + 0.6, BOW_START - 0.4
		trim(Vector3.new(0.18, 0.24, pz1 - pz0), at(side * (HW + 0.03), WELL_TOP, (pz0 + pz1) / 2))
		trim(Vector3.new(0.18, BOW_TOP - WELL_TOP, 0.24), at(side * (HW + 0.03), (WELL_TOP + BOW_TOP) / 2, pz0))
		trim(Vector3.new(0.18, BOW_TOP - BOTTOM - 0.6, 0.24), at(side * (HW + 0.03), (BOW_TOP + BOTTOM + 0.6) / 2, BOW_START + 0.05))
		window(P(side * HW, 5.2, (pz0 + pz1) / 2 - 0.4), Vector3.new(side, 0, 0), 1.3, 1.3)
	end
	-- pruva ucu
	vis("Stem", Vector3.new(1.0, (BOW_TOP + 1.6) - (BOTTOM + 3), 1.0), at(0, (BOW_TOP + 1.6 + BOTTOM + 3) / 2, BOW_TIP + 0.3), HULL)
	trim(Vector3.new(1.2, 0.3, 1.2), at(0, BOW_TOP + 1.55, BOW_TIP + 0.3))
	-- kıç aynası (alt) + taşan kısmın altı + üst kıç aynası
	vis("Transom", Vector3.new(2 * HW, OVERHANG_H - BOTTOM, 0.6), at(0, (OVERHANG_H + BOTTOM) / 2, STERN - 0.3), HULL)
	vis("IronBand", Vector3.new(2 * HW + 0.1, 0.5, 0.7), at(0, 0.15, STERN - 0.3), IRON, Enum.Material.Metal)
	vis("OverhangFloor", Vector3.new(2 * HW, 0.4, CASTLE_END - STERN), at(0, OVERHANG_H + 0.2, (STERN + CASTLE_END) / 2), DARK)
	vis("Transom", Vector3.new(2 * HW, STERN_TOP - OVERHANG_H, 0.6), at(0, (OVERHANG_H + STERN_TOP) / 2, CASTLE_END - 0.3), HULL)
	trim(Vector3.new(2 * HW + 0.2, 0.3, 0.9), at(0, STERN_TOP + 0.1, CASTLE_END - 0.3))
	trim(Vector3.new(2 * HW + 0.2, 0.26, 0.18), at(0, OVERHANG_H, CASTLE_END + 0.03))
	for _, x in { -2.8, 2.8 } do
		window(P(x, 4.3, CASTLE_END), Vector3.new(0, 0, 1), 1.4, 1.3)
	end
	vis("Bottom", Vector3.new(2 * HW - 0.4, 0.4, STERN - BOW_NARROW), at(0, BOTTOM + 0.2, (STERN + BOW_NARROW) / 2), DARK)

	---------------------------------------------------------------------------------------------
	-- GÜVERTELER, BÖLMELER, MERDİVENLER, KORKULUKLAR
	---------------------------------------------------------------------------------------------
	vis("Deck", Vector3.new(2 * HW - 0.6, 0.4, CABIN_Z - BOW_START), at(0, DECK_WELL - 0.2, (CABIN_Z + BOW_START) / 2), DECK)
	vis("Deck", Vector3.new(2 * HW - 0.6, 0.4, CASTLE_END - CABIN_Z - 0.3), at(0, DECK_STERN - 0.2, (CABIN_Z + CASTLE_END - 0.3) / 2), DECK)
	do
		local z = BOW_TIP + 0.9
		while z < BOW_START - 0.01 do
			local z1 = math.min(z + 1, BOW_START)
			vis("Deck", Vector3.new(math.max(2 * hw((z + z1) / 2) - 0.9, 0.5), 0.4, z1 - z + 0.05), at(0, DECK_BOW - 0.2, (z + z1) / 2), DECK)
			z = z1
		end
	end
	-- pruva bölmesinin çukura bakan duvarı + dümen platformunun ön duvarı
	vis("Bulkhead", Vector3.new(2 * HW - 0.6, DECK_BOW - DECK_WELL, 0.5), at(0, (DECK_BOW + DECK_WELL) / 2, BOW_START + 0.25), HULL)
	trim(Vector3.new(2 * HW - 0.6, 0.3, 0.7), at(0, DECK_BOW + 0.05, BOW_START + 0.25))
	vis("Bulkhead", Vector3.new(2 * HW - 0.6, DECK_STERN - DECK_WELL, 0.5), at(0, (DECK_STERN + DECK_WELL) / 2, CABIN_Z - 0.25), HULL)
	trim(Vector3.new(2 * HW - 0.6, 0.3, 0.7), at(0, DECK_STERN + 0.05, CABIN_Z - 0.25))
	-- kamara kapısı
	local dn = Vector3.new(0, 0, -1)
	vis("DoorFrame", Vector3.new(2.0, 3.0, 0.12), face(P(2.4, DECK_WELL + 1.5, CABIN_Z - 0.56), dn), WHITE, Enum.Material.SmoothPlastic)
	vis("Door", Vector3.new(1.6, 2.75, 0.16), face(P(2.4, DECK_WELL + 1.4, CABIN_Z - 0.6), dn), DARK, Enum.Material.WoodPlanks)

	local RAIL_H = 1.25
	local function railRun(a: Vector3, b: Vector3)
		local n = math.max(2, math.floor((b - a).Magnitude / 1.4))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			vis("Baluster", Vector3.new(0.22, RAIL_H, 0.22), CFrame.new(p + Vector3.new(0, RAIL_H / 2, 0)), DARK, Enum.Material.Wood)
		end
		beam("Rail", a + Vector3.new(0, RAIL_H, 0), b + Vector3.new(0, RAIL_H, 0), 0.28, WHITE, Enum.Material.SmoothPlastic)
	end
	local rh = STERN_TOP + 0.25
	for _, side in { -1, 1 } do
		railRun(P(side * (HW - 0.3), rh, CABIN_Z - 0.2), P(side * (HW - 0.3), rh, CASTLE_END - 0.3))
	end
	railRun(P(-(HW - 0.3), rh, CASTLE_END - 0.3), P(HW - 0.3, rh, CASTLE_END - 0.3))
	railRun(P(STERN_RAMP_X + 1.5, DECK_STERN + 0.05, CABIN_Z - 0.2), P(HW - 0.3, DECK_STERN + 0.05, CABIN_Z - 0.2))
	railRun(P(-(HW - 0.3), DECK_BOW + 0.05, BOW_START + 0.2), P(BOW_RAMP_X - 1.5, DECK_BOW + 0.05, BOW_START + 0.2))

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
	-- DİREK + TEK BÜYÜK YELKEN (resimdeki gibi: üstteki serenden sarkar, açılı durur, yandan geniş görünür)
	---------------------------------------------------------------------------------------------
	local MAST_TOP = 27
	vis("Mast", Vector3.new(MAST_TOP - DECK_WELL, 1.1, 1.1), at(0, (MAST_TOP + DECK_WELL) / 2, MAST_Z) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood, "cyl")
	vis("MastCap", Vector3.new(1.4, 1.4, 1.4), at(0, MAST_TOP + 0.3, MAST_Z), DARK, Enum.Material.Wood, "ball")
	vis("MastRing", Vector3.new(0.35, 1.6, 1.6), at(0, DECK_WELL + 0.3, MAST_Z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, "cyl")
	local YARD_H, SAIL_LOW = MAST_TOP - 1.2, 11.5
	local SAIL_W = 12
	-- yelken düzlemi direğin önünde, gemiye ~50° açılı (yandan bakınca geniş görünür)
	local sailCf = at(0, 0, MAST_Z) * CFrame.Angles(0, math.rad(-50), 0)
	local function sailPart(name, size, rel, color, mat, shape)
		local p = vis(name, size, CFrame.new(), color, mat, shape)
		parts[#parts][2] = sailCf * rel
		return p
	end
	sailPart("Yard", Vector3.new(SAIL_W + 1.6, 0.5, 0.5), CFrame.new(0, W + YARD_H, -0.7), DARK, Enum.Material.Wood, "cyl")
	local strips = 6
	local sw = SAIL_W / strips
	for i = 1, strips do
		local u = (i - 0.5) / strips * 2 - 1 -- -1..1
		local bulge = (1 - u * u) * 1.3
		local top = YARD_H - 0.2
		local low = SAIL_LOW + (1 - u * u) * -0.6 -- alt kenar hafif sarkık
		sailPart("Sail", Vector3.new(sw + 0.1, top - low, 0.16), CFrame.new(u * SAIL_W / 2, W + (top + low) / 2, -0.9 - bulge) * CFrame.Angles(0, -u * 0.38, 0), SAIL, Enum.Material.Fabric)
	end
	-- birkaç ince halat (resimdeki kadar)
	local spritA, spritB = P(0, BOW_TOP + 1, BOW_TIP + 2.2), P(0, BOW_TOP + 4.2, BOW_TIP - 6)
	beam("Bowsprit", spritA, spritB, 0.7, DARK, Enum.Material.Wood, true)
	local mtop = P(0, MAST_TOP - 0.3, MAST_Z)
	beam("Rope", mtop, spritB, 0.1, ROPE, Enum.Material.Fabric)
	beam("Rope", mtop, P(0, STERN_TOP + 1.5, CASTLE_END - 0.4), 0.1, ROPE, Enum.Material.Fabric)
	local corner = (sailCf * CFrame.new(-SAIL_W / 2, W + SAIL_LOW, -0.9)).Position
	beam("Rope", corner, P(HW - 0.5, STERN_TOP + 1.4, CABIN_Z + 2), 0.1, ROPE, Enum.Material.Fabric)

	---------------------------------------------------------------------------------------------
	-- DÜMEN (büyük, turuncu, platformun ön kısmında) + KOLTUK + SÜS
	---------------------------------------------------------------------------------------------
	local deckStern = W + DECK_STERN
	local WZ = CABIN_Z + 1.6
	add(newPart(m, "WheelPost", Vector3.new(0.8, 2.6, 0.8), DARK, Enum.Material.Wood), CFrame.new(0, deckStern + 1.3, WZ + 0.35))
	local wheel = newPart(m, "Wheel", Vector3.new(0.4, 3.4, 3.4), WHEEL, Enum.Material.Wood, "cyl")
	add(wheel, CFrame.new(0, deckStern + 3.1, WZ) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new())
	for k = 0, 3 do
		local spoke = newPart(m, "Spoke", Vector3.new(0.22, 4.6, 0.26), WHEEL, Enum.Material.Wood)
		add(spoke, CFrame.new(0, deckStern + 3.1, WZ) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(k * math.pi / 4, 0, 0), nil, "Wheel")
	end
	add(seat(m, Vector3.new(2.4, 0.5, 2), DARK), CFrame.new(0, deckStern + 0.25, WZ + 2.3))
	vis("Hatch", Vector3.new(2.4, 0.9, 2.2), at(-1.2, DECK_BOW + 0.45, -9.5), Color3.fromRGB(120, 78, 46), Enum.Material.WoodPlanks)
	vis("Barrel", Vector3.new(1.4, 1.1, 1.1), at(-4.4, DECK_WELL + 0.7, 7.2) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(130, 84, 48), Enum.Material.Wood, "cyl")

	return hull, parts
end

return WarshipModel
