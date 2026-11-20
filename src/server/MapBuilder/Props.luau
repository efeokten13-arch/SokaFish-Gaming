--!nonstrict
-- Hikaye anlatan küçük süsler (balıkçı / korsan): fener direği, yön tabelası, çit, halat, baba (bollard),
-- can simidi, kürek, çapa, buzlu balık kasası, kova, olta kutusu, asılı fener, ağ, terazi, kamp ateşi, çadır.
-- Hepsi "cf" (yer + yön) alır; çarpışma sadece büyük parçalarda açık.
local Util = require(script.Parent.Util)

local Props = {}

Props.WOOD = Color3.fromRGB(139, 94, 60)
Props.DARK = Color3.fromRGB(84, 58, 38)
Props.OLD = { -- yıpranmış tahta tonları
	Color3.fromRGB(138, 104, 72),
	Color3.fromRGB(122, 92, 64),
	Color3.fromRGB(150, 116, 82),
	Color3.fromRGB(112, 86, 62),
	Color3.fromRGB(130, 108, 86),
}
local ROPE = Color3.fromRGB(196, 172, 122)
local IRON = Color3.fromRGB(58, 58, 62)
local BRASS = Color3.fromRGB(196, 150, 60)
local ICE = Color3.fromRGB(214, 238, 250)

local function deco(p, shadow)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow ~= false
	return p
end
Props.deco = deco

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Props.oldWood(rng)
	return Props.OLD[rng:NextInteger(1, #Props.OLD)]
end

-- Fener direği: ahşap direk + kol + asılı fener (ışıklı)
function Props.lanternPost(parent, cf, height)
	height = height or 9
	local m = model(parent, "LanternPost")
	Util.part(m, "Post", Vector3.new(0.8, height, 0.8), cf * CFrame.new(0, height / 2, 0), Props.DARK, Enum.Material.Wood)
	Util.part(m, "Base", Vector3.new(1.4, 0.8, 1.4), cf * CFrame.new(0, 0.4, 0), Color3.fromRGB(120, 116, 110), Enum.Material.Cobblestone)
	deco(Util.part(m, "Arm", Vector3.new(0.4, 0.4, 2.4), cf * CFrame.new(0, height - 0.5, -1), Props.DARK, Enum.Material.Wood))
	deco(Util.part(m, "Brace", Vector3.new(0.3, 0.3, 1.6), cf * CFrame.new(0, height - 1.2, -0.55) * CFrame.Angles(math.rad(45), 0, 0), Props.DARK, Enum.Material.Wood))
	Props.lantern(m, cf * CFrame.new(0, height - 1.6, -2))
	return m
end

-- Asılı fener: halka + metal çerçeve + ışıklı cam
function Props.lantern(parent, cf, scale)
	local k = scale or 1
	local m = model(parent, "Lantern")
	deco(Util.part(m, "Cap", Vector3.new(1.1, 0.25, 1.1) * k, cf * CFrame.new(0, 0.75 * k, 0), IRON, Enum.Material.Metal))
	deco(Util.part(m, "Bottom", Vector3.new(1.1, 0.2, 1.1) * k, cf * CFrame.new(0, -0.7 * k, 0), IRON, Enum.Material.Metal))
	local glass = deco(Util.part(m, "Glass", Vector3.new(0.8, 1.2, 0.8) * k, cf, Color3.fromRGB(255, 214, 130), Enum.Material.Neon), false)
	glass.Transparency = 0.15
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco(Util.part(m, "Bar", Vector3.new(0.12, 1.4, 0.12) * k, cf * CFrame.new(0.48 * sx * k, 0, 0.48 * sz * k), IRON, Enum.Material.Metal), false)
		end
	end
	deco(Util.part(m, "Ring", Vector3.new(0.12, 0.5, 0.12) * k, cf * CFrame.new(0, 1.05 * k, 0), IRON, Enum.Material.Metal), false)
	Util.light(glass, 1.1, 20, Color3.fromRGB(255, 200, 130))
	return m
end

-- Yön tabelası: direk + oklar. arrows = { {text, yön (dünya Vector3)}, ... }
function Props.signpost(parent, pos, arrows)
	local m = model(parent, "Signpost")
	Util.part(m, "Post", Vector3.new(0.8, 9, 0.8), CFrame.new(pos + Vector3.new(0, 4.5, 0)), Props.DARK, Enum.Material.Wood)
	deco(Util.part(m, "Top", Vector3.new(1.2, 0.5, 1.2), CFrame.new(pos + Vector3.new(0, 9.2, 0)), Props.DARK, Enum.Material.Wood))
	for i, a in arrows do
		local dir = Vector3.new(a[2].X, 0, a[2].Z).Unit
		local y = 8.2 - (i - 1) * 1.6
		local c = CFrame.lookAt(pos + Vector3.new(0, y, 0), pos + Vector3.new(0, y, 0) + dir) * CFrame.Angles(0, math.pi / 2, 0)
		-- tahta uzunlamasına yöne doğru (yerel +X = gösterdiği yön)
		local board = deco(Util.part(m, "Arrow", Vector3.new(7, 1.3, 0.3), c * CFrame.new(3.2, 0, 0), Props.OLD[(i % #Props.OLD) + 1], Enum.Material.WoodPlanks))
		local tip = deco(Util.wedge(m, "ArrowTip", Vector3.new(0.3, 1.3, 1.1), c * CFrame.new(7.25, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), board.Color, Enum.Material.WoodPlanks))
		tip.Size = Vector3.new(0.3, 1.3, 1.1)
		Util.sign(board, Enum.NormalId.Front, a[1], Color3.fromRGB(255, 244, 214)).PixelsPerStud = 30
		Util.sign(board, Enum.NormalId.Back, a[1], Color3.fromRGB(255, 244, 214)).PixelsPerStud = 30
	end
	return m
end

-- Rustik çit: p0'dan p1'e direkler + iki kat kalas
function Props.fence(parent, p0, p1, rng)
	local m = model(parent, "Fence")
	local len = (p1 - p0).Magnitude
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local p = p0:Lerp(p1, i / n)
		local h = 3.2 + rng:NextNumber(-0.3, 0.3)
		Util.part(m, "FencePost", Vector3.new(0.6, h, 0.6), CFrame.new(p + Vector3.new(0, h / 2 - 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), rng:NextNumber(-0.05, 0.05)), Props.DARK, Enum.Material.Wood)
	end
	for _, y in { 1.2, 2.4 } do
		local a, b = p0 + Vector3.new(0, y, 0), p1 + Vector3.new(0, y, 0)
		local rail = Util.beam(m, "Rail", a, b, 0.25, 0.45, Props.oldWood(rng), Enum.Material.WoodPlanks)
		rail.CFrame *= CFrame.Angles(0, 0, rng:NextNumber(-0.04, 0.04))
	end
	return m
end

-- Sarılı halat: üst üste halkalar
function Props.coil(parent, cf, r)
	r = r or 1.2
	local m = model(parent, "RopeCoil")
	for k = 0, 2 do
		local rr = r * (1 - k * 0.12)
		deco(Util.cyl(m, "Coil", 0.32, rr * 2, cf * CFrame.new(0, 0.16 + k * 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), ROPE:Lerp(Color3.new(0, 0, 0), k * 0.06), Enum.Material.Fabric))
	end
	deco(Util.cyl(m, "Hole", 0.95, r * 0.8, cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 56, 40), Enum.Material.Fabric), false)
	return m
end

-- Gemi bağlama babası (bollard)
function Props.bollard(parent, cf)
	local m = model(parent, "Bollard")
	Util.cyl(m, "Body", 1.6, 1.2, cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
	deco(Util.cyl(m, "Cap", 0.35, 1.6, cf * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal))
	deco(Util.cyl(m, "RopeLoop", 0.3, 1.5, cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2), ROPE, Enum.Material.Fabric))
	return m
end

-- Can simidi: beyaz/kırmızı dilimli halka (duvara asmak için cf'nin -Z'si duvardan dışarı)
function Props.lifeRing(parent, cf, r)
	r = r or 1.4
	local m = model(parent, "LifeRing")
	local n = 12
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		local col = (math.floor(i / 3) % 2 == 0) and Color3.fromRGB(240, 240, 235) or Color3.fromRGB(210, 60, 50)
		deco(Util.part(m, "Seg", Vector3.new(0.75, 0.8, 0.75), p * CFrame.Angles(0, 0, a), col, Enum.Material.SmoothPlastic))
	end
	deco(Util.rod(m, "Rope", (cf * CFrame.new(0, r + 0.5, 0)).Position, (cf * CFrame.new(0, r + 1.4, 0.2)).Position, 0.15, ROPE, Enum.Material.Fabric))
	return m
end

-- Kürek: sap + pala (cf'nin -Z'si pala yönü)
function Props.oar(parent, cf, len)
	len = len or 7
	local m = model(parent, "Oar")
	deco(Util.part(m, "Shaft", Vector3.new(0.25, 0.25, len), cf, Props.WOOD, Enum.Material.Wood))
	deco(Util.part(m, "Blade", Vector3.new(0.9, 0.12, 2.2), cf * CFrame.new(0, 0, -len / 2 - 0.6), Props.WOOD, Enum.Material.Wood))
	deco(Util.part(m, "Grip", Vector3.new(0.35, 0.35, 0.8), cf * CFrame.new(0, 0, len / 2 - 0.3), Props.DARK, Enum.Material.Wood))
	return m
end

-- Dümen tekerleği (cf'nin -Z'si duvardan dışarı)
function Props.shipWheel(parent, cf, r)
	r = r or 2
	local m = model(parent, "ShipWheel")
	local rim = 12
	for i = 0, rim - 1 do
		local a = i / rim * math.pi * 2
		deco(Util.part(m, "Rim", Vector3.new(r * 0.56, 0.35, 0.35), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0), Props.WOOD, Enum.Material.Wood))
	end
	for i = 0, 3 do
		local a = i / 8 * math.pi * 2
		deco(Util.part(m, "Spoke", Vector3.new(0.25, r * 2 + 1.6, 0.25), cf * CFrame.Angles(0, 0, a), Props.DARK, Enum.Material.Wood))
	end
	deco(Util.cyl(m, "Hub", 0.6, 0.9, cf * CFrame.Angles(0, math.pi / 2, 0), BRASS, Enum.Material.Metal))
	return m
end

-- Büyük çapa: yere yatık (cf yerde, -Z = halka/zincir tarafı)
function Props.anchor(parent, cf, rng)
	local m = model(parent, "Anchor")
	Util.part(m, "Shank", Vector3.new(1, 1, 9), cf * CFrame.new(0, 0.5, 0), IRON, Enum.Material.Metal)
	Util.part(m, "Stock", Vector3.new(6.5, 0.7, 0.7), cf * CFrame.new(0, 1.1, -4) * CFrame.Angles(0, 0, math.rad(8)), Props.DARK, Enum.Material.Wood)
	deco(Util.cyl(m, "Ring", 0.4, 2, cf * CFrame.new(0, 0.5, -5.3) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal))
	deco(Util.ball(m, "Crown", Vector3.new(1.6, 1.2, 1.6), cf * CFrame.new(0, 0.5, 4.5), IRON, Enum.Material.Metal))
	for _, s in { -1, 1 } do
		local arm = Util.part(m, "Arm", Vector3.new(1, 0.9, 4.2), cf * CFrame.new(s * 1.5, 0.45, 3.4) * CFrame.Angles(0, s * math.rad(-55), 0), IRON, Enum.Material.Metal)
		deco(Util.wedge(m, "Fluke", Vector3.new(0.4, 1.8, 1.8), arm.CFrame * CFrame.new(0, 0, -2.4) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal))
	end
	-- zincir halkaları: halkadan kıvrılarak uzar
	local p = (cf * CFrame.new(0, 0.3, -5.8)).Position
	local yaw = 0
	for i = 1, 12 do
		yaw += rng:NextNumber(-0.35, 0.35)
		local d = (cf * CFrame.Angles(0, yaw, 0)).LookVector
		p += d * 0.85
		deco(Util.part(m, "Link", Vector3.new(0.3, 0.7, 1), CFrame.lookAt(p, p + d) * CFrame.Angles(0, 0, (i % 2) * math.pi / 2), IRON, Enum.Material.Metal))
	end
	return m
end

-- Buzlu balık kasası (+ üstte iki üç balık)
function Props.fishCrate(parent, cf, rng)
	local m = model(parent, "FishCrate")
	Util.part(m, "Crate", Vector3.new(3, 1.4, 2.2), cf * CFrame.new(0, 0.7, 0), Props.oldWood(rng), Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		deco(Util.part(m, "Slat", Vector3.new(0.2, 1.5, 2.3), cf * CFrame.new(sx * 1.45, 0.75, 0), Props.DARK, Enum.Material.Wood))
	end
	deco(Util.part(m, "Ice", Vector3.new(2.7, 0.35, 1.9), cf * CFrame.new(0, 1.3, 0), ICE, Enum.Material.Ice))
	local cols = { Color3.fromRGB(150, 170, 190), Color3.fromRGB(220, 130, 80), Color3.fromRGB(110, 150, 120), Color3.fromRGB(200, 200, 210) }
	for k = 1, rng:NextInteger(2, 3) do
		local f = deco(Util.ball(m, "Fish", Vector3.new(1.8, 0.45, 0.6), cf * CFrame.new(rng:NextNumber(-0.7, 0.7), 1.55, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), cols[rng:NextInteger(1, #cols)], Enum.Material.SmoothPlastic))
		deco(Util.wedge(m, "Tail", Vector3.new(0.1, 0.5, 0.5), f.CFrame * CFrame.new(-1, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), f.Color, Enum.Material.SmoothPlastic))
	end
	return m
end

-- Kasa yığını (2-3 kat)
function Props.crateStack(parent, cf, rng, count)
	for k = 0, (count or 3) - 1 do
		local off = CFrame.new((k % 2) * 3.1 - 1.5, math.floor(k / 2) * 1.45, rng:NextNumber(-0.2, 0.2)) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
		Props.fishCrate(parent, cf * off, rng)
	end
end

-- Meşe fıçı (çemberli)
function Props.barrel(parent, cf, rng)
	local m = model(parent, "Barrel")
	local col = Props.oldWood(rng)
	Util.cyl(m, "Body", 3.2, 2.4, cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Wood)
	deco(Util.cyl(m, "Belly", 1.6, 2.6, cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Wood))
	for _, y in { 0.45, 2.75 } do
		deco(Util.cyl(m, "Hoop", 0.25, 2.5, cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal))
	end
	return m
end

-- Kova
function Props.bucket(parent, cf, filled)
	local m = model(parent, "Bucket")
	deco(Util.cyl(m, "Body", 1.3, 1.2, cf * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 124, 128), Enum.Material.Metal))
	deco(Util.cyl(m, "Inside", 0.1, 1, cf * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.pi / 2), filled and Color3.fromRGB(60, 120, 170) or Color3.fromRGB(50, 50, 52), filled and Enum.Material.Glass or Enum.Material.Metal), false)
	deco(Util.part(m, "Handle", Vector3.new(1.2, 0.1, 0.1), cf * CFrame.new(0, 1.7, 0), IRON, Enum.Material.Metal), false)
	return m
end

-- Olta kutusu (tackle box)
function Props.tackleBox(parent, cf, color)
	local m = model(parent, "TackleBox")
	deco(Util.part(m, "Box", Vector3.new(1.8, 0.8, 1), cf * CFrame.new(0, 0.4, 0), color or Color3.fromRGB(60, 120, 80), Enum.Material.SmoothPlastic))
	deco(Util.part(m, "Lid", Vector3.new(1.85, 0.15, 1.05), cf * CFrame.new(0, 0.85, 0), (color or Color3.fromRGB(60, 120, 80)):Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.SmoothPlastic))
	deco(Util.part(m, "Handle", Vector3.new(0.8, 0.2, 0.15), cf * CFrame.new(0, 1.05, 0), IRON, Enum.Material.Metal))
	deco(Util.part(m, "Latch", Vector3.new(0.3, 0.25, 0.1), cf * CFrame.new(0, 0.7, -0.52), BRASS, Enum.Material.Metal))
	return m
end

-- Olta standı: 3-4 olta yaslanmış
function Props.rodStand(parent, cf, rng)
	local m = model(parent, "RodStand")
	Util.part(m, "Base", Vector3.new(3.4, 0.5, 1.2), cf * CFrame.new(0, 0.25, 0), Props.DARK, Enum.Material.Wood)
	deco(Util.part(m, "Back", Vector3.new(3.4, 0.4, 0.4), cf * CFrame.new(0, 3.4, 0.4), Props.DARK, Enum.Material.Wood))
	for _, sx in { -1.6, 1.6 } do
		deco(Util.part(m, "Side", Vector3.new(0.3, 3.6, 0.3), cf * CFrame.new(sx, 1.8, 0.4), Props.DARK, Enum.Material.Wood))
	end
	for k = 0, 3 do
		local x = -1.2 + k * 0.8
		local len = rng:NextNumber(6, 8)
		local rc = cf * CFrame.new(x, 0.5, -0.1) * CFrame.Angles(math.rad(-12), 0, rng:NextNumber(-0.08, 0.08))
		deco(Util.part(m, "Rod", Vector3.new(0.15, len, 0.15), rc * CFrame.new(0, len / 2, 0), Props.oldWood(rng), Enum.Material.Wood))
		deco(Util.cyl(m, "Reel", 0.25, 0.5, rc * CFrame.new(0.2, 1.4, 0), IRON, Enum.Material.Metal))
	end
	return m
end

-- Duvarda / direkler arasında asılı ağ (dikdörtgen kafes). cf: ağın ortası, X genişlik, Y yükseklik
function Props.net(parent, cf, w, h)
	local m = model(parent, "Net")
	local col = Color3.fromRGB(210, 196, 156)
	local nx, ny = math.floor(w / 1.1), math.floor(h / 1.1)
	for i = 0, nx do
		local x = -w / 2 + i * w / nx
		local sag = math.sin(i / nx * math.pi) * 0.4
		deco(Util.part(m, "Strand", Vector3.new(0.08, h, 0.08), cf * CFrame.new(x, -sag, 0), col, Enum.Material.Fabric), false)
	end
	for j = 0, ny do
		local y = -h / 2 + j * h / ny
		deco(Util.part(m, "Strand", Vector3.new(w, 0.08, 0.08), cf * CFrame.new(0, y, 0), col, Enum.Material.Fabric), false)
	end
	-- mantar şamandıralar
	for i = 0, nx, 2 do
		deco(Util.ball(m, "Float", Vector3.new(0.45, 0.45, 0.45), cf * CFrame.new(-w / 2 + i * w / nx, h / 2, 0.05), Color3.fromRGB(230, 120, 50), Enum.Material.SmoothPlastic))
	end
	return m
end

-- Asma terazi (pirinç): zincir + kol + iki kefe
function Props.scale(parent, cf)
	local m = model(parent, "Scale")
	deco(Util.part(m, "Chain", Vector3.new(0.12, 1.6, 0.12), cf * CFrame.new(0, -0.8, 0), IRON, Enum.Material.Metal))
	deco(Util.cyl(m, "Dial", 0.25, 1.1, cf * CFrame.new(0, -1.9, 0) * CFrame.Angles(0, math.pi / 2, 0), BRASS, Enum.Material.Metal))
	deco(Util.part(m, "Beam", Vector3.new(2.6, 0.14, 0.14), cf * CFrame.new(0, -2.6, 0), BRASS, Enum.Material.Metal))
	for _, sx in { -1.2, 1.2 } do
		deco(Util.part(m, "PanChain", Vector3.new(0.06, 1, 0.06), cf * CFrame.new(sx, -3.1, 0), IRON, Enum.Material.Metal))
		deco(Util.cyl(m, "Pan", 0.15, 1.3, cf * CFrame.new(sx, -3.65, 0) * CFrame.Angles(0, 0, math.pi / 2), BRASS, Enum.Material.Metal))
	end
	return m
end

-- Şamandıra (asılı veya yerde)
function Props.buoy(parent, cf, col)
	return deco(Util.ball(parent, "Buoy", Vector3.new(1.1, 1.3, 1.1), cf, col or Color3.fromRGB(215, 70, 55), Enum.Material.SmoothPlastic))
end

-- Sönmüş kamp ateşi: taş halka, yanık odunlar, kül
function Props.campfire(parent, cf, rng)
	local m = model(parent, "Campfire")
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		deco(Util.part(m, "Stone", Vector3.new(1.2, 0.8, 1), cf * CFrame.new(math.cos(a) * 2.4, 0.3, math.sin(a) * 2.4) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, 0), Color3.fromRGB(110, 106, 100), Enum.Material.Slate))
	end
	deco(Util.cyl(m, "Ash", 0.2, 3.6, cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 58, 56), Enum.Material.Slate), false)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		deco(Util.part(m, "CharredLog", Vector3.new(0.5, 0.5, 2.6), cf * CFrame.new(math.cos(a) * 0.5, 0.6, math.sin(a) * 0.5) * CFrame.Angles(0, a, math.rad(25)) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(40, 32, 26), Enum.Material.Wood))
	end
	-- ince duman
	local smokePart = Util.zone(m, "SmokeSource", Vector3.new(1, 1, 1), cf * CFrame.new(0, 0.8, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 2
	e.Lifetime = NumberRange.new(4, 6)
	e.Speed = NumberRange.new(1.5, 2.5)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190))
	e.Parent = smokePart
	return m
end

-- Kütük oturak (yatık)
function Props.logSeat(parent, cf, len)
	return Util.cyl(parent, "LogSeat", len or 4.5, 1.4, cf * CFrame.new(0, 0.6, 0), Color3.fromRGB(110, 78, 50), Enum.Material.Wood)
end

-- Eski korsan çadırı: A-çerçeve, yamalı kumaş
function Props.tent(parent, cf, rng)
	local m = model(parent, "Tent")
	local w, h, d = 7, 5, 8
	local ang = math.atan2(h, w / 2)
	local slope = math.sqrt((w / 2) ^ 2 + h ^ 2)
	local cloth = Color3.fromRGB(196, 178, 140)
	for _, s in { -1, 1 } do
		Util.part(m, "Cloth", Vector3.new(slope, 0.2, d), cf * CFrame.new(s * w / 4, h / 2, 0) * CFrame.Angles(0, 0, s * -ang), cloth, Enum.Material.Fabric)
		-- yamalar
		for _ = 1, 2 do
			deco(Util.part(m, "Patch", Vector3.new(1.3, 0.22, 1.2), cf * CFrame.new(s * w / 4, h / 2, rng:NextNumber(-2.5, 2.5)) * CFrame.Angles(0, 0, s * -ang) * CFrame.new(rng:NextNumber(-1, 1), 0.02, 0), Color3.fromRGB(150, 110, 80), Enum.Material.Fabric))
		end
	end
	for _, z in { -d / 2, d / 2 } do
		for _, s in { -1, 1 } do
			deco(Util.part(m, "Pole", Vector3.new(0.3, slope + 0.6, 0.3), cf * CFrame.new(s * w / 4, h / 2, z) * CFrame.Angles(0, 0, s * -ang + math.pi / 2), Props.DARK, Enum.Material.Wood))
		end
	end
	deco(Util.part(m, "Ridge", Vector3.new(0.35, 0.35, d + 1.2), cf * CFrame.new(0, h + 0.1, 0), Props.DARK, Enum.Material.Wood))
	-- yırtık bayrak
	deco(Util.part(m, "Flagpole", Vector3.new(0.2, 4, 0.2), cf * CFrame.new(0, h + 2, d / 2 + 0.3), Props.DARK, Enum.Material.Wood))
	deco(Util.part(m, "Flag", Vector3.new(1.8, 1.1, 0.05), cf * CFrame.new(0.9, h + 3.4, d / 2 + 0.3), Color3.fromRGB(30, 30, 34), Enum.Material.Fabric))
	return m
end

-- Kıyıya vurmuş kalas
function Props.plank(parent, cf, rng)
	return deco(Util.part(parent, "DriftPlank", Vector3.new(rng:NextNumber(3, 6), 0.3, 0.9), cf * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), Props.oldWood(rng):Lerp(Color3.fromRGB(170, 160, 140), 0.3), Enum.Material.WoodPlanks))
end

-- Yosunlu taş: kaya + üstünde yeşil yosun
function Props.mossStone(parent, cf, rng)
	local s = rng:NextNumber(1.6, 3.4)
	local rock = Util.part(parent, "MossStone", Vector3.new(s * 1.3, s * 0.7, s), cf * CFrame.new(0, s * 0.1, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), 0), Color3.fromRGB(118, 116, 110), Enum.Material.Rock)
	deco(Util.part(parent, "Moss", Vector3.new(s * 1.0, 0.25, s * 0.75), rock.CFrame * CFrame.new(0, s * 0.33, 0), Color3.fromRGB(78, 120, 52), Enum.Material.Grass))
	return rock
end

return Props
