--!nonstrict
-- Balık 3D modellerini Part'lardan kodla üretir (mesh yok). Görünüm Config/Fish.luau içindeki "look" alanından gelir.
-- ReplicatedStorage'da durduğu için hem server (havuz, tutma sahnesi) hem client (UI önizlemeleri) kullanır.
--
-- Kullanım:
--   local model = FishModelBuilder.Build("Cod")        -- normal boy
--   local big   = FishModelBuilder.Build("Cod", 1.3)   -- %30 büyük
-- Model -Z yönüne bakar (kafa -Z'de), +Y yukarı. Body = PrimaryPart (anchored); diğer parçalar ona kaynaklı (Weld).
-- Türler (look.kind): fish, puffer, lionfish, seahorse, ray, jelly, eel, octopus, angler, billfish, shark.
-- İleride mesh modelleri gelirse: Build() içinde look.mesh varsa onu klonlayıp döndürmek yeterli.

local Shared = script.Parent
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))

local FishModelBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(22, 22, 28)
local rad = math.rad

local function darker(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end
local function lighter(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end

---------------------------------------------------------------------------------------------
-- Parça yardımcıları
---------------------------------------------------------------------------------------------
-- ctx = { model, body (PrimaryPart), L, reflect }
local function newPart(ctx, name, size, color, kind, o)
	o = o or {}
	local p
	if kind == "wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if kind == "ball" then
			p.Shape = Enum.PartType.Ball
		elseif kind == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = name
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.Color = color
	p.Material = o.material or ctx.material or Enum.Material.SmoothPlastic
	p.Reflectance = o.reflect or ctx.reflect or 0
	p.Transparency = o.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	if kind == "ell" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	return p
end

-- parçayı gövdeye göre cf konumuna koy ve kaynakla
local function put(ctx, p, cf)
	p.CFrame = ctx.body.CFrame * (ctx.xf or CFrame.identity) * cf
	if p ~= ctx.body then
		local w = Instance.new("WeldConstraint")
		w.Part0 = ctx.body
		w.Part1 = p
		w.Parent = p
	end
	p.Parent = ctx.model
	return p
end

local function E(ctx, name, size, cf, color, o) -- elips
	return put(ctx, newPart(ctx, name, size, color, "ell", o), cf)
end
local function BALL(ctx, name, d, pos, color, o)
	return put(ctx, newPart(ctx, name, Vector3.new(d, d, d), color, "ball", o), CFrame.new(pos))
end
-- iki nokta arası yuvarlak çubuk
local function ROD(ctx, name, a, b, d, color, o)
	local len = (b - a).Magnitude
	local p = newPart(ctx, name, Vector3.new(len, d, d), color, "cyl", o)
	return put(ctx, p, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0))
end
-- iki nokta arası elips segment (yılan balığı, dokunaç gibi zincirler)
local function SEG(ctx, name, a, b, w, h, color, o, up)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b, up or Vector3.yAxis)
	return E(ctx, name, Vector3.new(w, h, len * 1.35), cf, color, o)
end

-- elipsoid yüzeyinde nokta ve dış normal. a,b,c yarı eksenler (x,y,z); merkez center.
-- ang: z ekseni etrafında açı (0 = sağ yan, 90 = sırt), t: -1 (kafa) .. 1 (kuyruk)
local function onSurface(center, a, b, c, ang, t)
	local r = math.sqrt(math.max(1 - t * t, 0))
	local x, y, z = a * r * math.cos(ang), b * r * math.sin(ang), c * t
	local n = Vector3.new(x / (a * a), y / (b * b), z / (c * c))
	return center + Vector3.new(x, y, z), n.Magnitude > 0 and n.Unit or Vector3.xAxis
end

-- yüzeye yapışık yassı leke (benek, şerit parçası)
local function DECAL(ctx, name, center, a, b, c, ang, t, w, h, color, o)
	local p, n = onSurface(center, a, b, c, ang, t)
	local up = math.abs(n.Y) > 0.95 and Vector3.zAxis or Vector3.yAxis
	local cf = CFrame.lookAt(p - n * 0.01, p + n, up)
	return E(ctx, name, Vector3.new(w, h, math.max(ctx.L * 0.012, 0.03)), cf, color, o)
end

---------------------------------------------------------------------------------------------
-- Ortak parçalar: göz, ağız, yüzgeç, kuyruk
---------------------------------------------------------------------------------------------
-- Çizgi film gözü: beyaz + büyük göz bebeği + parlak nokta. pos = göz merkezi, out = dışa yön
local function EYE(ctx, pos, d, out, irisColor, o)
	o = o or {}
	local scl = BALL(ctx, "Eye", d, pos, o.sclera or WHITE, { reflect = 0, material = Enum.Material.SmoothPlastic })
	local iris = BALL(ctx, "Pupil", d * 0.68, pos + out * d * 0.2 + Vector3.new(0, 0, -d * 0.06), irisColor or INK, { reflect = 0.1, material = o.irisNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic })
	BALL(ctx, "EyeShine", d * 0.24, pos + out * d * 0.42 + Vector3.new(0, d * 0.16, -d * 0.16), WHITE, { material = Enum.Material.Neon, reflect = 0 })
	return scl, iris
end

local function EYES(ctx, x, y, z, d, irisColor, o)
	for _, s in { 1, -1 } do
		EYE(ctx, Vector3.new(s * x, y, z), d, Vector3.new(s, 0, 0), irisColor, o)
	end
end

-- yarım gömülü yuvarlak yüzgeç (sırt / karın): ince elips, merkezi gövde kenarında
local function FIN(ctx, name, center, height, length, color, tiltDeg, o)
	local cf = CFrame.new(center) * CFrame.Angles(rad(tiltDeg or 0), 0, 0)
	return E(ctx, name, Vector3.new(ctx.thin, height * 2, length), cf, color, o)
end

-- kuyruk; z0 = kuyruk sapının bittiği yer, tl = kuyruk boyu
local function TAIL(ctx, style, z0, y0, tl, color, edge)
	local th = ctx.thin
	if style == "fan" then
		if edge then
			E(ctx, "TailEdge", Vector3.new(th * 0.6, tl * 1.0, tl * 0.86), CFrame.new(0, y0, z0 + tl * 0.38), edge)
		end
		E(ctx, "Tail", Vector3.new(th, tl * 0.88, tl * 0.76), CFrame.new(0, y0, z0 + tl * 0.34), color, { transparency = 0.03 })
		for i = -2, 2 do
			local a = rad(i * 17)
			local tip = Vector3.new(0, y0 + math.sin(a) * tl * 0.42, z0 + math.cos(a) * tl * 0.7)
			ROD(ctx, "TailRay", Vector3.new(th * 0.6, y0, z0 + tl * 0.05), tip, th * 0.7, darker(color, 0.18))
		end
	elseif style == "lunate" then
		for _, s in { 1, -1 } do
			E(ctx, "TailLobe", Vector3.new(th, tl * 0.2, tl * 0.95), CFrame.new(0, y0 + s * tl * 0.34, z0 + tl * 0.28) * CFrame.Angles(s * rad(58), 0, 0), color)
		end
		E(ctx, "TailBase", Vector3.new(th * 1.4, tl * 0.3, tl * 0.32), CFrame.new(0, y0, z0 + tl * 0.08), color)
	else -- fork
		for _, s in { 1, -1 } do
			E(ctx, "TailLobe", Vector3.new(th, tl * 0.3, tl * 0.82), CFrame.new(0, y0 + s * tl * 0.24, z0 + tl * 0.3) * CFrame.Angles(s * rad(38), 0, 0), color)
			if edge then
				E(ctx, "TailTip", Vector3.new(th * 0.7, tl * 0.18, tl * 0.4), CFrame.new(0, y0 + s * tl * 0.46, z0 + tl * 0.56) * CFrame.Angles(s * rad(38), 0, 0), edge)
			end
		end
		E(ctx, "TailBase", Vector3.new(th * 1.4, tl * 0.34, tl * 0.3), CFrame.new(0, y0, z0 + tl * 0.08), color)
	end
end

-- yan (göğüs) yüzgeçleri
local function PECS(ctx, x, y, z, h, l, color, spread)
	for _, s in { 1, -1 } do
		E(ctx, "SideFin", Vector3.new(ctx.thin * 1.2, h, l), CFrame.new(s * x, y, z) * CFrame.Angles(rad(-15), s * rad(spread or 32), 0) * CFrame.new(0, 0, l * 0.35), color, { transparency = 0.05 })
	end
end

---------------------------------------------------------------------------------------------
-- Desenler (gövde elipsi üzerinde)
---------------------------------------------------------------------------------------------
local function pattern(ctx, look, center, a, b, c, rng)
	local p = look.pattern
	local col = look.accent or darker(look.body, 0.35)
	local L = ctx.L
	if p == "spots" then
		for i = 1, 7 do
			local t = -0.55 + i * 0.15
			for _, s in { 0, 180 } do
				DECAL(ctx, "Spot", center, a, b, c, rad(s == 0 and 38 or 142), t, b * 0.22, b * 0.22, col)
			end
		end
	elseif p == "speckle" then
		for _ = 1, 34 do
			local ang = rad(rng:NextNumber(15, 165))
			DECAL(ctx, "Speckle", center, a, b, c, ang, rng:NextNumber(-0.7, 0.75), b * 0.09, b * 0.09, col)
		end
	elseif p == "bars" then
		for i = 0, 8 do
			local t = -0.45 + i * 0.13
			for _, side in { 1, -1 } do
				local ang = side > 0 and rad(62) or rad(118)
				local bar = DECAL(ctx, "Bar", center, a, b, c, ang, t, b * 0.12, b * 0.62, col)
				bar.CFrame = bar.CFrame * CFrame.Angles(0, 0, side * rad(14 + (i % 2) * 18))
			end
		end
	elseif p == "lines" then
		for _, ang0 in { 20, 42 } do
			for _, side in { 1, -1 } do
				local ang = side > 0 and rad(ang0) or rad(180 - ang0)
				for i = 0, 9 do
					local t = -0.62 + i * 0.13
					DECAL(ctx, "Line", center, a, b, c, ang, t, c * 0.16, b * 0.06, col)
				end
			end
		end
	elseif p == "bands" then
		for _, t in look.bandsAt or { -0.45, 0.05, 0.55 } do
			local r = math.sqrt(math.max(1 - t * t, 0))
			E(ctx, "Band", Vector3.new(a * 2 * r * 1.05, b * 2 * r * 1.05, L * 0.07), CFrame.new(center + Vector3.new(0, 0, c * t)), col)
		end
	elseif p == "patches" then
		for _ = 1, 10 do
			local ang = rad(rng:NextNumber(0, 180))
			local d = b * rng:NextNumber(0.22, 0.42)
			DECAL(ctx, "Patch", center, a, b, c, ang, rng:NextNumber(-0.6, 0.6), d * 1.3, d, col)
		end
	end
end

---------------------------------------------------------------------------------------------
-- 1) Klasik balık (çoğu tür)
---------------------------------------------------------------------------------------------
local SHAPES = {
	Slim = { w = 0.20, h = 0.27 },
	Normal = { w = 0.26, h = 0.36 },
	Deep = { w = 0.26, h = 0.50 },
	Round = { w = 0.56, h = 0.60 },
	Torpedo = { w = 0.30, h = 0.33 },
}

local function has(look, x)
	return look.extras ~= nil and table.find(look.extras, x) ~= nil
end

local function buildFish(ctx, look, rng)
	local L = ctx.L
	local sh = SHAPES[look.shape or "Normal"] or SHAPES.Normal
	local W, H = L * sh.w, L * sh.h
	local body, belly, fin = look.body, look.belly, look.fin
	-- gövde: ana elips + yuvarlak kafa + incelen arka + kuyruk sapı
	local center = Vector3.new(0, 0, L * 0.02)
	local a, b, c = W / 2, H / 2, L * 0.39
	E(ctx, "Head", Vector3.new(W * 0.94, H * 0.88, L * 0.44), CFrame.new(0, H * 0.02, -L * 0.25), body)
	E(ctx, "Rear", Vector3.new(W * 0.56, H * 0.56, L * 0.36), CFrame.new(0, 0, L * 0.29), body)
	E(ctx, "TailStalk", Vector3.new(W * 0.28, H * 0.27, L * 0.2), CFrame.new(0, 0, L * 0.43), body)
	-- karın (açık renk alt yarı)
	E(ctx, "Belly", Vector3.new(W * 1.02, H * 0.64, L * 0.68), CFrame.new(0, -H * 0.19, -L * 0.03), belly)
	E(ctx, "Chin", Vector3.new(W * 0.9, H * 0.5, L * 0.3), CFrame.new(0, -H * 0.2, -L * 0.26), belly)
	-- sırtta biraz koyu ton (derinlik hissi)
	E(ctx, "Back", Vector3.new(W * 0.7, H * 0.4, L * 0.62), CFrame.new(0, H * 0.31, L * 0.0), darker(body, 0.12))
	pattern(ctx, look, center, a * 1.0, b * 1.0, c, rng)
	-- ağız + dudak
	local noseZ = -L * 0.46
	E(ctx, "Mouth", Vector3.new(W * 0.34, H * 0.07, L * 0.05), CFrame.new(0, -H * 0.07, noseZ + L * 0.01), INK)
	E(ctx, "Lip", Vector3.new(W * 0.4, H * 0.06, L * 0.05), CFrame.new(0, -H * 0.02, noseZ + L * 0.005), lighter(body, 0.25))
	if has(look, "Beak") then
		local beak = look.belly:Lerp(WHITE, 0.4)
		E(ctx, "BeakTop", Vector3.new(W * 0.48, H * 0.17, L * 0.12), CFrame.new(0, H * 0.0, noseZ - L * 0.01), beak)
		E(ctx, "BeakBottom", Vector3.new(W * 0.42, H * 0.14, L * 0.1), CFrame.new(0, -H * 0.13, noseZ + L * 0.005), beak)
	end
	if has(look, "Whiskers") then
		ROD(ctx, "Barbel", Vector3.new(0, -H * 0.38, -L * 0.33), Vector3.new(0, -H * 0.6, -L * 0.3), ctx.thin * 0.8, darker(body, 0.2))
	end
	-- solungaç çizgileri
	for _, s in { 1, -1 } do
		local g = E(ctx, "Gill", Vector3.new(ctx.thin * 0.8, H * 0.5, L * 0.025), CFrame.new(s * W * 0.43, -H * 0.02, -L * 0.15) * CFrame.Angles(rad(12), s * rad(8), 0), darker(body, 0.35))
		g.Transparency = 0.1
	end
	-- gözler
	local ed = math.max(H * 0.26, L * 0.07)
	EYES(ctx, W * 0.39, H * 0.11, -L * 0.32, ed, look.eye)
	-- sırt yüzgeci
	local dorsal = look.dorsal or "soft"
	local finCol = fin
	if dorsal == "spiny" then
		FIN(ctx, "DorsalMembrane", Vector3.new(0, H * 0.42, -L * 0.02), H * 0.24, L * 0.44, lighter(fin, 0.15), 0, { transparency = 0.15 })
		for i = 0, 7 do
			local z = -L * 0.2 + i * L * 0.055
			local hgt = H * (0.5 - math.abs(i - 2) * 0.05)
			ROD(ctx, "Spine", Vector3.new(0, H * 0.38, z), Vector3.new(0, H * 0.38 + hgt, z + L * 0.03), ctx.thin * 0.9, darker(fin, 0.1))
		end
		FIN(ctx, "Dorsal2", Vector3.new(0, H * 0.36, L * 0.22), H * 0.22, L * 0.2, fin)
	elseif dorsal == "fancy" then
		local acc = look.accent or lighter(fin, 0.4)
		E(ctx, "DorsalFancy", Vector3.new(ctx.thin, H * 0.75, L * 0.66), CFrame.new(0, H * 0.42, L * 0.14) * CFrame.Angles(rad(-12), 0, 0), fin, { transparency = 0.2 })
		E(ctx, "DorsalFancyEdge", Vector3.new(ctx.thin * 0.6, H * 0.82, L * 0.74), CFrame.new(0, H * 0.44, L * 0.17) * CFrame.Angles(rad(-12), 0, 0), acc, { transparency = 0.45 })
		E(ctx, "AnalFancy", Vector3.new(ctx.thin, H * 0.7, L * 0.42), CFrame.new(0, -H * 0.4, L * 0.24) * CFrame.Angles(rad(15), 0, 0), fin, { transparency = 0.08 })
		for _, s in { 1, -1 } do
			E(ctx, "Ribbon", Vector3.new(ctx.thin * 0.8, H * 0.18, L * 0.55), CFrame.new(s * W * 0.2, -H * 0.42, -L * 0.02) * CFrame.Angles(rad(28), s * rad(10), 0) * CFrame.new(0, 0, L * 0.18), acc, { transparency = 0.1 })
		end
	elseif dorsal == "sail" then
		FIN(ctx, "Sail", Vector3.new(0, H * 0.45, -L * 0.02), H * 0.65, L * 0.6, fin)
	else
		FIN(ctx, "Dorsal", Vector3.new(0, H * 0.4, -L * 0.02), H * 0.27, L * 0.42, fin, -6)
	end
	if dorsal ~= "fancy" then
		FIN(ctx, "AnalFin", Vector3.new(0, -H * 0.36, L * 0.2), H * 0.2, L * 0.22, fin, 8)
	end
	-- karın yüzgeçleri + yan yüzgeçler
	for _, s in { 1, -1 } do
		E(ctx, "PelvicFin", Vector3.new(ctx.thin, H * 0.22, L * 0.13), CFrame.new(s * W * 0.18, -H * 0.42, -L * 0.1) * CFrame.Angles(rad(30), 0, s * rad(15)), fin)
	end
	PECS(ctx, W * 0.46, -H * 0.1, -L * 0.15, H * 0.3, L * 0.2, fin, 34)
	if has(look, "Finlets") then
		for i = 0, 4 do
			local z = L * 0.27 + i * L * 0.04
			for _, y in { 1, -1 } do
				E(ctx, "Finlet", Vector3.new(ctx.thin, H * 0.09, L * 0.035), CFrame.new(0, y * H * (0.2 - i * 0.025), z), look.accent or fin)
			end
		end
		for _, s in { 1, -1 } do
			E(ctx, "Keel", Vector3.new(W * 0.18, H * 0.05, L * 0.12), CFrame.new(s * W * 0.14, 0, L * 0.45), look.accent or fin)
		end
	end
	-- kuyruk
	local tl = L * ((look.tail == "lunate") and 0.34 or 0.34)
	TAIL(ctx, look.tail or "fork", L * 0.5, 0, tl, fin, (look.tail == "fan") and (look.accent or lighter(fin, 0.35)) or nil)
end

---------------------------------------------------------------------------------------------
-- 2) Balon balığı
---------------------------------------------------------------------------------------------
local function buildPuffer(ctx, look, rng)
	local L = ctx.L
	local W, H = L * 0.78, L * 0.74
	local center = Vector3.new(0, 0, L * 0.02)
	E(ctx, "Belly", Vector3.new(W * 0.96, H * 0.7, L * 0.8), CFrame.new(0, -H * 0.17, 0), look.belly)
	local a, b, c = W / 2, H / 2, L * 0.44
	-- sırttaki benekler
	for _ = 1, 22 do
		DECAL(ctx, "Spot", center, a, b, c, rad(rng:NextNumber(25, 155)), rng:NextNumber(-0.6, 0.7), b * 0.12, b * 0.12, look.accent or darker(look.body, 0.4))
	end
	-- dikenler
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, 59 do
		local y = 1 - (i / 59) * 2
		local r = math.sqrt(1 - y * y)
		local th = golden * i
		local dir = Vector3.new(math.cos(th) * r, y, math.sin(th) * r)
		if dir.Z < 0.7 and dir.Z > -0.75 then
			local base = center + Vector3.new(dir.X * a * 0.96, dir.Y * b * 0.96, dir.Z * c * 0.96)
			local n = Vector3.new(dir.X / a, dir.Y / b, dir.Z / c).Unit
			ROD(ctx, "Spike", base, base + n * L * 0.11, L * 0.022, lighter(look.fin, 0.3))
			BALL(ctx, "SpikeTip", L * 0.018, base + n * L * 0.11, lighter(look.fin, 0.55))
		end
	end
	-- dudaklar ("o" ağız)
	E(ctx, "Lips", Vector3.new(W * 0.2, H * 0.15, L * 0.07), CFrame.new(0, -H * 0.05, -c * 0.98), lighter(look.body, 0.3))
	E(ctx, "Mouth", Vector3.new(W * 0.1, H * 0.07, L * 0.04), CFrame.new(0, -H * 0.05, -c * 1.02), INK)
	EYES(ctx, a * 0.62, b * 0.35, -c * 0.62, L * 0.2, look.eye)
	PECS(ctx, a * 0.92, -b * 0.05, -c * 0.15, H * 0.22, L * 0.16, look.fin, 40)
	FIN(ctx, "Dorsal", Vector3.new(0, b * 0.75, c * 0.55), H * 0.14, L * 0.14, look.fin)
	E(ctx, "TailStalk", Vector3.new(W * 0.22, H * 0.22, L * 0.2), CFrame.new(0, 0, c * 0.98), look.body)
	TAIL(ctx, "fan", c * 1.05, 0, L * 0.3, look.fin, look.accent)
end

---------------------------------------------------------------------------------------------
-- 3) Aslan balığı: çizgili gövde, uzun dikenler, yelpaze yüzgeçler
---------------------------------------------------------------------------------------------
local function buildLionfish(ctx, look, rng)
	local L = ctx.L
	local stripe = look.accent or WHITE
	look = table.clone(look)
	look.shape, look.pattern, look.tail, look.dorsal = "Normal", "bands", "fan", "soft"
	look.bandsAt = { -0.62, -0.38, -0.14, 0.1, 0.34, 0.58 }
	buildFish(ctx, look, rng)
	local H, W = L * 0.36, L * 0.26
	-- uzun çizgili sırt dikenleri
	for i = 0, 11 do
		local z = -L * 0.2 + i * L * 0.045
		local hgt = L * (0.42 - math.abs(i - 3) * 0.025)
		local base = Vector3.new(0, H * 0.4, z)
		local dir = Vector3.new(0, 1, 0.35 + i * 0.03).Unit
		local n = 4
		for k = 0, n - 1 do
			local a0 = base + dir * hgt * (k / n)
			local a1 = base + dir * hgt * ((k + 1) / n)
			ROD(ctx, "Spine", a0, a1, L * 0.018, k % 2 == 0 and look.fin or stripe)
		end
		E(ctx, "SpineWeb", Vector3.new(ctx.thin * 0.6, hgt * 0.5, L * 0.05), CFrame.lookAt(base + dir * hgt * 0.25, base + dir * hgt) * CFrame.Angles(rad(90), 0, 0), lighter(look.fin, 0.3), { transparency = 0.35 })
	end
	-- dev yelpaze göğüs yüzgeçleri (tüy gibi şeritli ışınlar)
	for _, s in { 1, -1 } do
		for r = 0, 8 do
			local a = rad(-60 + r * 16)
			local base = Vector3.new(s * W * 0.45, -H * 0.05, -L * 0.12)
			local dir = Vector3.new(s * 0.75, math.sin(a) * 0.65, 0.55 + r * 0.05).Unit
			local len = L * (0.42 + (r % 3) * 0.05)
			local tip = base + dir * len
			E(ctx, "Feather", Vector3.new(L * 0.05, ctx.thin * 1.2, len), CFrame.lookAt((base + tip) / 2, tip), look.fin, { transparency = 0.05 })
			for k = 1, 3 do
				local p = base + dir * len * (k / 4)
				E(ctx, "FeatherBand", Vector3.new(L * 0.055, ctx.thin * 1.4, len * 0.08), CFrame.lookAt(p, tip), stripe)
			end
		end
	end
	-- gözlerin üstünde küçük dokunaçlar
	for _, s in { 1, -1 } do
		ROD(ctx, "Tentacle", Vector3.new(s * W * 0.3, H * 0.3, -L * 0.33), Vector3.new(s * W * 0.4, H * 0.62, -L * 0.36), L * 0.02, stripe)
	end
end

---------------------------------------------------------------------------------------------
-- 4) Denizatı (dik durur, burnu -Z'ye bakar)
---------------------------------------------------------------------------------------------
local function buildSeahorse(ctx, look, rng)
	local L = ctx.L
	local body, belly, fin, acc = look.body, look.belly, look.fin, look.accent or lighter(look.body, 0.4)
	-- gövde ekseni: boyun -> göğüs -> karın -> kuyruk spirali (YZ düzleminde, kuyruk +Z'ye kıvrılır)
	local pts, rads = {}, {}
	local trunk = {
		{ 0.30, 0.04, 0.085 }, { 0.22, 0.0, 0.11 }, { 0.13, -0.035, 0.135 }, { 0.04, -0.05, 0.15 },
		{ -0.05, -0.045, 0.145 }, { -0.13, -0.02, 0.12 }, { -0.2, 0.02, 0.095 },
	}
	for _, t in trunk do
		table.insert(pts, Vector3.new(0, t[1] * L, t[2] * L))
		table.insert(rads, t[3] * L)
	end
	-- kuyruk spirali
	local cx, cy = 0.11 * L, -0.31 * L
	for i = 0, 13 do
		local k = i / 13
		local ang = math.pi + k * math.pi * 2.1
		local r = (0.12 - k * 0.07) * L
		table.insert(pts, Vector3.new(0, cy + math.sin(ang) * -r + r * 0, cx + math.cos(ang) * r))
		table.insert(rads, (0.085 - k * 0.065) * L)
	end
	-- spiralin başını gövde sonuna bağla
	pts[8] = pts[7]:Lerp(pts[9], 0.5)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local r = (rads[i] + rads[i + 1]) / 2
		local seg = SEG(ctx, "Body", a, b, r * 1.7, r * 1.9, body, nil, Vector3.xAxis)
		-- halka sırtları
		if i % 1 == 0 then
			E(ctx, "Ridge", Vector3.new(r * 1.85, r * 1.85, L * 0.018), CFrame.lookAt(a, b), darker(body, 0.15))
		end
		if i <= 7 then
			-- karın tarafı açık renk
			local mid = (a + b) / 2 + Vector3.new(0, 0, -r * 0.45)
			E(ctx, "Belly", Vector3.new(r * 1.3, (b - a).Magnitude * 1.3, r * 1.0), CFrame.new(mid), belly)
			-- sırt dikenleri
			BALL(ctx, "Knob", r * 0.35, (a + b) / 2 + Vector3.new(0, 0, r * 0.9), acc)
		end
	end
	-- benekler
	for _ = 1, 10 do
		local i = rng:NextInteger(1, 6)
		local p = pts[i]:Lerp(pts[i + 1], rng:NextNumber())
		local side = rng:NextNumber() < 0.5 and -1 or 1
		E(ctx, "Spot", Vector3.new(L * 0.012, L * 0.03, L * 0.03), CFrame.new(p + Vector3.new(side * rads[i] * 0.85, 0, 0)), acc)
	end
	-- kafa: boyundan öne eğik, uzun burun
	local headC = Vector3.new(0, 0.39 * L, -0.02 * L)
	E(ctx, "Head", Vector3.new(L * 0.19, L * 0.18, L * 0.24), CFrame.new(headC) * CFrame.Angles(rad(-20), 0, 0), body)
	E(ctx, "Cheek", Vector3.new(L * 0.13, L * 0.09, L * 0.12), CFrame.new(headC + Vector3.new(0, -L * 0.035, -L * 0.03)), belly)
	local snoutA = headC + Vector3.new(0, -L * 0.03, -L * 0.07)
	local snoutB = headC + Vector3.new(0, -L * 0.07, -L * 0.25)
	ROD(ctx, "Snout", snoutA, snoutB, L * 0.07, body)
	E(ctx, "SnoutTip", Vector3.new(L * 0.07, L * 0.06, L * 0.04), CFrame.lookAt(snoutB, snoutB + (snoutB - snoutA)), darker(body, 0.15))
	-- taç (coronet) + başın arkasında küçük dikenler
	for i = 0, 4 do
		local base = headC + Vector3.new(0, L * 0.06, L * 0.02 + i * L * 0.012)
		local a = rad(-30 + i * 18)
		ROD(ctx, "Crown", base, base + Vector3.new((i % 2 == 0 and 1 or -1) * L * 0.015, math.cos(a) * L * 0.07, math.sin(a) * L * 0.05), L * 0.02, acc)
	end
	EYES(ctx, L * 0.085, headC.Y + L * 0.015, headC.Z - L * 0.03, L * 0.085, look.eye)
	-- sırt yüzgeci (sırtta, yelpaze) + küçük göğüs yüzgeçleri
	local dc = Vector3.new(0, -0.02 * L, 0.11 * L)
	E(ctx, "DorsalFin", Vector3.new(ctx.thin, L * 0.16, L * 0.1), CFrame.new(dc), fin, { transparency = 0.1 })
	for r = -2, 2 do
		local tip = dc + Vector3.new(0, r * L * 0.03, L * 0.05)
		ROD(ctx, "FinRay", dc - Vector3.new(0, 0, L * 0.02), tip, ctx.thin * 0.6, darker(fin, 0.15))
	end
	for _, s in { 1, -1 } do
		E(ctx, "SideFin", Vector3.new(ctx.thin, L * 0.07, L * 0.05), CFrame.new(s * L * 0.07, 0.3 * L, 0.04 * L) * CFrame.Angles(0, s * rad(30), 0), fin, { transparency = 0.1 })
	end
end

---------------------------------------------------------------------------------------------
-- 5) Vatoz: yassı elmas gövde, sırtında deniz yıldızı deseni, uzun kuyruk
---------------------------------------------------------------------------------------------
local function buildRay(ctx, look, rng)
	local L = ctx.L
	-- yandan bakınca sırttaki yıldız görünsün: hafif yana yatık ve burnu yukarı (süzülür gibi)
	ctx.xf = CFrame.Angles(rad(-12), 0, rad(48))
	local body, acc = look.body, look.accent or lighter(look.body, 0.4)
	local T = L * 0.09
	E(ctx, "Disc", Vector3.new(L * 0.62, T * 1.3, L * 0.58), CFrame.new(0, 0, 0), body)
	for _, s in { 1, -1 } do
		E(ctx, "Wing", Vector3.new(L * 0.62, T * 0.7, L * 0.32), CFrame.new(s * L * 0.27, -T * 0.05, L * 0.02) * CFrame.Angles(0, s * rad(-22), s * rad(-4)), body)
		E(ctx, "WingTip", Vector3.new(L * 0.26, T * 0.5, L * 0.12), CFrame.new(s * L * 0.53, T * 0.05, L * 0.13) * CFrame.Angles(0, s * rad(-35), s * rad(-8)), darker(body, 0.08))
		E(ctx, "WingBelly", Vector3.new(L * 0.56, T * 0.5, L * 0.28), CFrame.new(s * L * 0.25, -T * 0.3, L * 0.02) * CFrame.Angles(0, s * rad(-22), 0), look.belly)
	end
	E(ctx, "Belly", Vector3.new(L * 0.56, T * 0.8, L * 0.52), CFrame.new(0, -T * 0.35, 0), look.belly)
	-- baş lobu
	E(ctx, "HeadLobe", Vector3.new(L * 0.26, T * 1.1, L * 0.16), CFrame.new(0, T * 0.05, -L * 0.3), body)
	-- sırtta beş kollu deniz yıldızı
	local top = T * 0.62
	for k = 0, 4 do
		local ang = rad(90 + k * 72)
		local dir = Vector3.new(math.cos(ang), 0, -math.sin(ang))
		for j = 0, 4 do
			local d = L * (0.03 + j * 0.045)
			local sz = L * (0.075 - j * 0.011)
			E(ctx, "Star", Vector3.new(sz, T * 0.25, sz), CFrame.new(dir * d + Vector3.new(0, top - j * T * 0.05, 0.02 * L)), acc)
		end
	end
	E(ctx, "StarCore", Vector3.new(L * 0.1, T * 0.3, L * 0.1), CFrame.new(0, top + T * 0.03, 0.02 * L), lighter(acc, 0.2))
	-- benekler
	for _ = 1, 26 do
		local x = rng:NextNumber(-0.55, 0.55) * L
		local z = rng:NextNumber(-0.22, 0.25) * L
		if math.abs(x) > L * 0.2 or math.abs(z) > L * 0.2 then
			E(ctx, "Speck", Vector3.new(L * 0.025, T * 0.2, L * 0.025), CFrame.new(x, T * 0.35 - math.abs(x) / L * T * 0.4, z), lighter(acc, 0.3))
		end
	end
	-- gözler (sırtta) + nefes delikleri
	for _, s in { 1, -1 } do
		EYE(ctx, Vector3.new(s * L * 0.07, T * 0.6, -L * 0.2), L * 0.06, Vector3.new(s * 0.4, 1, -0.3).Unit, look.eye)
		E(ctx, "Spiracle", Vector3.new(L * 0.03, T * 0.2, L * 0.04), CFrame.new(s * L * 0.07, T * 0.6, -L * 0.13), darker(body, 0.4))
	end
	-- uzun kuyruk + küçük kuyruk yüzgeci
	local prev = Vector3.new(0, 0, L * 0.26)
	for i = 1, 10 do
		local p = Vector3.new(math.sin(i * 0.4) * L * 0.03, -T * 0.05 * i * 0.2, L * (0.26 + i * 0.06))
		ROD(ctx, "Tail", prev, p, L * (0.035 - i * 0.0028), i % 2 == 0 and darker(body, 0.1) or body)
		prev = p
	end
	E(ctx, "TailFin", Vector3.new(ctx.thin, L * 0.05, L * 0.08), CFrame.new(0, T * 0.2, L * 0.4), look.fin)
end

---------------------------------------------------------------------------------------------
-- 6) Kristal denizanası: cam kubbe, parlayan iç, fırfırlı kenar, dokunaçlar
---------------------------------------------------------------------------------------------
local function buildJelly(ctx, look, rng)
	local L = ctx.L
	local domeH = L * 0.42
	local R = L * 0.3
	local glass = { material = Enum.Material.Glass, transparency = 0.35, reflect = 0.1 }
	E(ctx, "Dome", Vector3.new(R * 2, domeH * 2, R * 2), CFrame.new(0, 0, 0), look.body, glass)
	E(ctx, "DomeInner", Vector3.new(R * 1.55, domeH * 1.5, R * 1.55), CFrame.new(0, domeH * 0.1, 0), look.belly, { material = Enum.Material.Neon, transparency = 0.55 })
	E(ctx, "Core", Vector3.new(R * 0.7, domeH * 0.6, R * 0.7), CFrame.new(0, domeH * 0.15, 0), look.accent or WHITE, { material = Enum.Material.Neon, transparency = 0.25 })
	-- alt yarıyı kapatan düz alt yüz (kubbe görünümü)
	E(ctx, "Bell", Vector3.new(R * 2.04, domeH * 0.5, R * 2.04), CFrame.new(0, -domeH * 0.25, 0), look.fin, { material = Enum.Material.Glass, transparency = 0.25 })
	-- dört nal deseni (üstte)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		E(ctx, "Gonad", Vector3.new(R * 0.3, domeH * 0.12, R * 0.14), CFrame.new(math.cos(a) * R * 0.38, domeH * 0.62, math.sin(a) * R * 0.38) * CFrame.Angles(0, -a, 0), look.accent or WHITE, { material = Enum.Material.Neon, transparency = 0.15 })
	end
	-- fırfırlı kenar
	for k = 0, 19 do
		local a = k / 20 * math.pi * 2
		BALL(ctx, "Frill", R * 0.24, Vector3.new(math.cos(a) * R * 0.98, -domeH * 0.38, math.sin(a) * R * 0.98), k % 2 == 0 and look.fin or lighter(look.fin, 0.3), { material = Enum.Material.Glass, transparency = 0.2 })
	end
	-- uzun ince dokunaçlar
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.2
		local prev = Vector3.new(math.cos(a) * R * 0.85, -domeH * 0.45, math.sin(a) * R * 0.85)
		local phase = rng:NextNumber(0, 6)
		for i = 1, 9 do
			local p = Vector3.new(math.cos(a) * R * (0.85 - i * 0.03) + math.sin(i * 0.8 + phase) * L * 0.035, -domeH * 0.45 - i * L * 0.075, math.sin(a) * R * (0.85 - i * 0.03) + math.cos(i * 0.8 + phase) * L * 0.03)
			ROD(ctx, "Tentacle", prev, p, L * (0.022 - i * 0.0018), i % 3 == 0 and look.accent or look.fin, { material = Enum.Material.Neon, transparency = 0.3 })
			prev = p
		end
	end
	-- ortada fırfırlı ağız kolları
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local prev = Vector3.new(math.cos(a) * R * 0.15, -domeH * 0.4, math.sin(a) * R * 0.15)
		for i = 1, 6 do
			local p = Vector3.new(math.cos(a) * R * 0.2 + math.sin(i * 1.1 + k) * L * 0.05, -domeH * 0.4 - i * L * 0.075, math.sin(a) * R * 0.2 + math.cos(i * 1.1 + k) * L * 0.04)
			SEG(ctx, "OralArm", prev, p, L * (0.08 - i * 0.007), L * 0.05, look.belly, { material = Enum.Material.Glass, transparency = 0.3 })
			prev = p
		end
	end
end

---------------------------------------------------------------------------------------------
-- 7) Yılan balığı: kıvrımlı uzun gövde, şerit yüzgeç, açık ağız, burun tüpleri
---------------------------------------------------------------------------------------------
local function buildEel(ctx, look, rng)
	local L = ctx.L
	local N = 24
	local pts = {}
	for i = 0, N do
		local t = i / N
		table.insert(pts, Vector3.new(math.sin(t * math.pi * 1.2) * L * 0.02, math.sin(t * math.pi * 2.2) * L * 0.08 * (0.35 + t), -L * 0.5 + t * L))
	end
	for i = 1, N do
		local t = (i - 1) / N
		local r = L * (t < 0.12 and (0.045 + t * 0.15) or (0.063 * (1 - (t - 0.12) * 0.95)))
		r = math.max(r, L * 0.008)
		local a, b = pts[i], pts[i + 1]
		SEG(ctx, "Body", a, b, r * 1.7, r * 2.1, look.body)
		-- açık renk karın şeridi + koyu kenar çizgisi
		local dir = (b - a).Unit
		local side = dir:Cross(Vector3.yAxis).Unit
		E(ctx, "BellyStripe", Vector3.new(r * 1.2, r * 0.6, (b - a).Magnitude * 1.3), CFrame.lookAt((a + b) / 2 - Vector3.new(0, r * 0.75, 0), (a + b) / 2 - Vector3.new(0, r * 0.75, 0) + dir), look.belly)
		-- şerit sırt ve karın yüzgeci
		if t > 0.08 then
			local h = r * 1.1
			E(ctx, "RibbonFin", Vector3.new(ctx.thin * 0.8, h * 2, (b - a).Magnitude * 1.4), CFrame.lookAt((a + b) / 2 + Vector3.new(0, r * 0.95, 0), (a + b) / 2 + Vector3.new(0, r * 0.95, 0) + dir), look.fin, { transparency = 0.05 })
			E(ctx, "RibbonFinLow", Vector3.new(ctx.thin * 0.8, h * 1.3, (b - a).Magnitude * 1.4), CFrame.lookAt((a + b) / 2 - Vector3.new(0, r * 0.95, 0), (a + b) / 2 - Vector3.new(0, r * 0.95, 0) + dir), look.fin, { transparency = 0.05 })
		end
		if i % 3 == 0 and look.accent then
			for _, s in { 1, -1 } do
				E(ctx, "Dot", Vector3.new(r * 0.5, r * 0.5, r * 0.5), CFrame.new((a + b) / 2 + side * s * r * 0.8 + Vector3.new(0, r * 0.3, 0)), look.accent)
			end
		end
	end
	-- kafa: üst ve alt çene ayrı (ağız açık), sarı ağız kenarı
	local head = pts[1]
	local dir = (pts[1] - pts[3]).Unit
	local hc = head + dir * L * 0.03
	E(ctx, "UpperJaw", Vector3.new(L * 0.08, L * 0.05, L * 0.16), CFrame.lookAt(hc + Vector3.new(0, L * 0.018, 0), hc + Vector3.new(0, L * 0.018, 0) + dir) * CFrame.Angles(rad(8), 0, 0), look.body)
	E(ctx, "LowerJaw", Vector3.new(L * 0.07, L * 0.035, L * 0.15), CFrame.lookAt(hc - Vector3.new(0, L * 0.022, 0), hc - Vector3.new(0, L * 0.022, 0) + dir) * CFrame.Angles(rad(-14), 0, 0), look.belly)
	E(ctx, "MouthInside", Vector3.new(L * 0.06, L * 0.03, L * 0.1), CFrame.lookAt(hc, hc + dir), INK)
	-- burun tüpleri (yelpaze uçlu)
	for _, s in { 1, -1 } do
		local nb = hc + dir * L * 0.07 + Vector3.new(s * L * 0.015, L * 0.04, 0)
		local nt = nb + dir * L * 0.03 + Vector3.new(s * L * 0.01, L * 0.035, 0)
		ROD(ctx, "NoseTube", nb, nt, L * 0.012, look.fin)
		E(ctx, "NoseFlare", Vector3.new(L * 0.035, L * 0.01, L * 0.035), CFrame.new(nt), look.fin)
	end
	EYES(ctx, L * 0.04, hc.Y + L * 0.035, hc.Z + L * 0.005, L * 0.042, look.eye)
	-- çene ucunda küçük sakal
	ROD(ctx, "ChinBarbel", hc - Vector3.new(0, L * 0.04, 0) + dir * L * 0.05, hc - Vector3.new(0, L * 0.07, 0) + dir * L * 0.06, L * 0.008, look.fin)
end

---------------------------------------------------------------------------------------------
-- 8) İnci ahtapot: büyük kafa, kocaman gözler, kıvrık kollar, vantuzlar, inci
---------------------------------------------------------------------------------------------
local function buildOctopus(ctx, look, rng)
	local L = ctx.L
	local body, belly, acc = look.body, look.belly, look.accent or lighter(look.body, 0.4)
	E(ctx, "Mantle", Vector3.new(L * 0.46, L * 0.5, L * 0.5), CFrame.new(0, L * 0.24, L * 0.1) * CFrame.Angles(rad(-22), 0, 0), body)
	E(ctx, "Face", Vector3.new(L * 0.44, L * 0.3, L * 0.38), CFrame.new(0, L * 0.04, -L * 0.02), body)
	E(ctx, "Under", Vector3.new(L * 0.36, L * 0.14, L * 0.3), CFrame.new(0, -L * 0.07, -L * 0.02), belly)
	-- kafadaki benekler
	for _ = 1, 14 do
		local a = rng:NextNumber(0.2, math.pi - 0.2)
		local t = rng:NextNumber(-0.5, 0.6)
		DECAL(ctx, "Spot", Vector3.new(0, L * 0.26, L * 0.12), L * 0.23, L * 0.25, L * 0.25, a, t, L * 0.04, L * 0.04, acc)
	end
	-- kocaman sevimli gözler + yanaklar
	for _, s in { 1, -1 } do
		E(ctx, "EyeLid", Vector3.new(L * 0.14, L * 0.15, L * 0.1), CFrame.new(s * L * 0.13, L * 0.11, -L * 0.15), darker(body, 0.08))
		EYE(ctx, Vector3.new(s * L * 0.13, L * 0.1, -L * 0.19), L * 0.12, Vector3.new(s * 0.3, 0, -1).Unit, look.eye)
		E(ctx, "Blush", Vector3.new(L * 0.07, L * 0.035, L * 0.03), CFrame.new(s * L * 0.17, L * 0.01, -L * 0.17), Color3.fromRGB(255, 120, 150), { transparency = 0.3 })
	end
	E(ctx, "Siphon", Vector3.new(L * 0.05, L * 0.05, L * 0.08), CFrame.new(L * 0.17, -L * 0.02, -L * 0.08) * CFrame.Angles(0, rad(40), 0), darker(body, 0.1))
	-- 8 kol: dışa ve aşağı, uçları kıvrılır
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local prev = Vector3.new(0, -L * 0.06, 0) + dir * L * 0.1
		local curl = (k % 2 == 0) and 1 or -1
		for i = 1, 11 do
			local t = i / 11
			local side = dir:Cross(Vector3.yAxis) * curl
			local out = dir * (L * 0.1 + t * L * 0.42) + side * (t ^ 3) * L * 0.12
			local y = -L * 0.06 - math.sin(t * math.pi * 0.8) * L * 0.14 + (t ^ 4) * L * 0.18
			local p = Vector3.new(out.X, y, out.Z)
			local r = L * (0.085 * (1 - t * 0.8))
			SEG(ctx, "Arm", prev, p, r * 1.9, r * 1.7, body)
			if i % 2 == 0 then
				BALL(ctx, "Sucker", r * 0.9, (prev + p) / 2 - Vector3.new(0, r * 0.7, 0), belly)
			end
			prev = p
		end
	end
	-- inci: öndeki iki kolun arasında
	if has(look, "Pearl") then
		local pearl = BALL(ctx, "Pearl", L * 0.12, Vector3.new(0, -L * 0.1, -L * 0.3), Color3.fromRGB(250, 246, 238), { reflect = 0.45 })
		BALL(ctx, "PearlShine", L * 0.035, Vector3.new(L * 0.025, -L * 0.07, -L * 0.35), WHITE, { material = Enum.Material.Neon })
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 240, 230)
		l.Brightness = 0.8
		l.Range = L * 1.5
		l.Parent = pearl
	end
end

---------------------------------------------------------------------------------------------
-- 9) Fener balığı: koyu yuvarlak gövde, dişli dev ağız, parlayan yem, biyolüminesan benekler
---------------------------------------------------------------------------------------------
local function buildAngler(ctx, look, rng)
	local L = ctx.L
	local body, acc = look.body, look.accent or Color3.fromRGB(80, 240, 255)
	E(ctx, "Rear", Vector3.new(L * 0.38, L * 0.42, L * 0.45), CFrame.new(0, 0, L * 0.22), body)
	E(ctx, "Belly", Vector3.new(L * 0.5, L * 0.32, L * 0.62), CFrame.new(0, -L * 0.13, 0), look.belly)
	-- dev alt çene (öne çıkık) + ağız içi
	E(ctx, "LowerJaw", Vector3.new(L * 0.5, L * 0.2, L * 0.36), CFrame.new(0, -L * 0.15, -L * 0.24) * CFrame.Angles(rad(-12), 0, 0), darker(body, 0.1))
	E(ctx, "MouthInside", Vector3.new(L * 0.4, L * 0.16, L * 0.2), CFrame.new(0, -L * 0.06, -L * 0.33), Color3.fromRGB(10, 6, 14))
	-- dişler: üstte ve altta, içe eğik sivri
	for i = -4, 4 do
		local x = i * L * 0.045
		local ang = (i / 4) * 0.9
		local zEdge = -L * 0.38 + math.abs(i) * L * 0.012
		ROD(ctx, "Tooth", Vector3.new(x, L * 0.03, zEdge), Vector3.new(x * 0.95, -L * (0.04 + (i % 2) * 0.03), zEdge - L * 0.01), L * 0.018, Color3.fromRGB(245, 245, 235))
		ROD(ctx, "Tooth", Vector3.new(x * 1.05, -L * 0.14, zEdge - L * 0.03), Vector3.new(x, -L * (0.06 - (i % 2) * 0.02), zEdge - L * 0.02), L * 0.018, Color3.fromRGB(245, 245, 235))
		local _ = ang
	end
	-- parlayan gözler
	for _, s in { 1, -1 } do
		local pos = Vector3.new(s * L * 0.18, L * 0.12, -L * 0.18)
		BALL(ctx, "Eye", L * 0.1, pos, Color3.fromRGB(20, 30, 40))
		BALL(ctx, "EyeGlow", L * 0.065, pos + Vector3.new(s * L * 0.025, 0, -L * 0.015), look.eye or acc, { material = Enum.Material.Neon })
		BALL(ctx, "EyeShine", L * 0.022, pos + Vector3.new(s * L * 0.045, L * 0.02, -L * 0.03), WHITE, { material = Enum.Material.Neon })
	end
	-- yem (illicium): kafadan öne kıvrılan sap + parlayan top
	local prev = Vector3.new(0, L * 0.3, -L * 0.1)
	local lure
	for i = 1, 7 do
		local t = i / 7
		local p = Vector3.new(0, L * (0.3 + math.sin(t * math.pi * 0.85) * 0.22), -L * (0.1 + t * 0.34))
		ROD(ctx, "LureStalk", prev, p, L * 0.02, darker(body, 0.1))
		prev = p
	end
	lure = BALL(ctx, "Lure", L * 0.09, prev + Vector3.new(0, -L * 0.03, -L * 0.02), acc, { material = Enum.Material.Neon })
	BALL(ctx, "LureHalo", L * 0.16, lure.Position - ctx.body.Position, acc, { material = Enum.Material.Neon, transparency = 0.75 })
	local l = Instance.new("PointLight")
	l.Color = acc
	l.Brightness = 3
	l.Range = L * 3
	l.Parent = lure
	-- biyolüminesan benekler + kafadaki mercan büyümeleri
	for _ = 1, 22 do
		local ang = rad(rng:NextNumber(0, 360))
		DECAL(ctx, "GlowDot", Vector3.new(0, L * 0.02, 0), L * 0.27, L * 0.29, L * 0.33, ang, rng:NextNumber(-0.4, 0.8), L * 0.022, L * 0.022, acc, { material = Enum.Material.Neon })
	end
	for k = 0, 4 do
		local base = Vector3.new((k - 2) * L * 0.06, L * 0.26 - math.abs(k - 2) * L * 0.025, L * 0.05 + (k % 2) * L * 0.05)
		local tip = base + Vector3.new((k - 2) * L * 0.02, L * 0.1, L * 0.03)
		ROD(ctx, "Coral", base, tip, L * 0.025, look.fin)
		BALL(ctx, "CoralTip", L * 0.04, tip, lighter(look.fin, 0.3))
		ROD(ctx, "Coral", (base + tip) / 2, (base + tip) / 2 + Vector3.new(L * 0.04, L * 0.04, 0), L * 0.018, look.fin)
	end
	-- küçük yüzgeçler + kuyruk
	PECS(ctx, L * 0.26, -L * 0.05, L * 0.05, L * 0.16, L * 0.12, look.fin, 45)
	FIN(ctx, "Dorsal", Vector3.new(0, L * 0.18, L * 0.3), L * 0.1, L * 0.18, look.fin)
	E(ctx, "TailStalk", Vector3.new(L * 0.14, L * 0.15, L * 0.16), CFrame.new(0, 0, L * 0.43), body)
	TAIL(ctx, "fan", L * 0.48, 0, L * 0.26, look.fin, acc)
end

---------------------------------------------------------------------------------------------
-- 10) Kılıç balığı / marlin: uzun torpido gövde, kılıç burun, orak sırt (veya yelken), hilal kuyruk
---------------------------------------------------------------------------------------------
local function buildBillfish(ctx, look, rng)
	local L = ctx.L
	local W, H = L * 0.15, L * 0.22
	local body, fin, acc = look.body, look.fin, look.accent
	E(ctx, "Head", Vector3.new(W * 0.9, H * 0.82, L * 0.3), CFrame.new(0, H * 0.02, -L * 0.26), body)
	E(ctx, "Rear", Vector3.new(W * 0.6, H * 0.6, L * 0.4), CFrame.new(0, 0, L * 0.25), body)
	E(ctx, "TailStalk", Vector3.new(W * 0.26, H * 0.22, L * 0.18), CFrame.new(0, 0, L * 0.44), body)
	E(ctx, "Belly", Vector3.new(W * 1.02, H * 0.6, L * 0.72), CFrame.new(0, -H * 0.2, -L * 0.04), look.belly)
	E(ctx, "Back", Vector3.new(W * 0.66, H * 0.4, L * 0.7), CFrame.new(0, H * 0.3, 0), darker(body, 0.15))
	-- dikey çizgiler (marlin / mercan kılıç)
	if acc then
		for i = 0, 9 do
			local t = -0.5 + i * 0.11
			for _, side in { 1, -1 } do
				DECAL(ctx, "Stripe", Vector3.new(0, 0, L * 0.02), W / 2, H / 2, L * 0.39, side > 0 and rad(45) or rad(135), t, L * 0.018, H * 0.5, acc, { transparency = 0.05 })
			end
		end
	end
	-- kılıç burun (iki parça, incelen)
	local nose = Vector3.new(0, H * 0.06, -L * 0.42)
	local mid = nose + Vector3.new(0, H * 0.02, -L * 0.22)
	local tip = mid + Vector3.new(0, H * 0.02, -L * 0.2)
	ROD(ctx, "Bill", nose, mid, H * 0.16, darker(fin, 0.05))
	ROD(ctx, "BillTip", mid - Vector3.new(0, 0, -L * 0.01), tip, H * 0.08, darker(fin, 0.05))
	E(ctx, "Mouth", Vector3.new(W * 0.5, H * 0.05, L * 0.1), CFrame.new(0, -H * 0.06, -L * 0.38), INK)
	EYES(ctx, W * 0.4, H * 0.1, -L * 0.31, H * 0.3, look.eye)
	-- sırt
	if look.dorsal == "sail" then
		E(ctx, "Sail", Vector3.new(ctx.thin, H * 2.6, L * 0.58), CFrame.new(0, H * 0.45, -L * 0.04), fin, { transparency = 0.05 })
		for i = 0, 8 do
			local z = -L * 0.28 + i * L * 0.065
			ROD(ctx, "SailRay", Vector3.new(0, H * 0.4, z), Vector3.new(0, H * (1.55 - math.abs(i - 3) * 0.12), z + L * 0.03), ctx.thin * 0.7, darker(fin, 0.2))
		end
		for _ = 1, 12 do
			E(ctx, "SailSpot", Vector3.new(ctx.thin * 1.3, H * 0.14, H * 0.14), CFrame.new(0, H * rng:NextNumber(0.6, 1.3), L * rng:NextNumber(-0.25, 0.2)), acc or lighter(fin, 0.4))
		end
	else
		E(ctx, "Dorsal", Vector3.new(ctx.thin, H * 1.5, L * 0.14), CFrame.new(0, H * 0.75, -L * 0.18) * CFrame.Angles(rad(-28), 0, 0), fin)
		FIN(ctx, "Dorsal2", Vector3.new(0, H * 0.3, L * 0.34), H * 0.15, L * 0.06, fin)
	end
	-- uzun orak göğüs yüzgeçleri, karın yüzgeci, hilal kuyruk, omurga çıkıntısı
	for _, s in { 1, -1 } do
		E(ctx, "SideFin", Vector3.new(ctx.thin, H * 0.25, L * 0.24), CFrame.new(s * W * 0.45, -H * 0.2, -L * 0.18) * CFrame.Angles(rad(28), s * rad(28), 0) * CFrame.new(0, 0, L * 0.1), fin)
		E(ctx, "Keel", Vector3.new(W * 0.25, H * 0.08, L * 0.1), CFrame.new(s * W * 0.13, 0, L * 0.45), darker(body, 0.2))
	end
	FIN(ctx, "AnalFin", Vector3.new(0, -H * 0.38, L * 0.25), H * 0.35, L * 0.1, fin, 25)
	TAIL(ctx, "lunate", L * 0.5, 0, L * 0.3, fin)
end

---------------------------------------------------------------------------------------------
-- 11) Köpek balığı (çekiç başlı)
---------------------------------------------------------------------------------------------
local function buildShark(ctx, look, rng)
	local L = ctx.L
	local W, H = L * 0.2, L * 0.22
	local body, fin = look.body, look.fin
	E(ctx, "Head", Vector3.new(W * 0.85, H * 0.78, L * 0.3), CFrame.new(0, 0, -L * 0.28), body)
	E(ctx, "Rear", Vector3.new(W * 0.55, H * 0.55, L * 0.42), CFrame.new(0, 0, L * 0.25), body)
	E(ctx, "TailStalk", Vector3.new(W * 0.24, H * 0.24, L * 0.2), CFrame.new(0, H * 0.03, L * 0.44), body)
	E(ctx, "Belly", Vector3.new(W * 1.02, H * 0.5, L * 0.74), CFrame.new(0, -H * 0.24, -L * 0.04), look.belly)
	E(ctx, "Back", Vector3.new(W * 0.7, H * 0.42, L * 0.7), CFrame.new(0, H * 0.28, 0), darker(body, 0.12))
	-- çekiç kafa
	if has(look, "Hammer") then
		E(ctx, "Hammer", Vector3.new(L * 0.4, H * 0.32, L * 0.12), CFrame.new(0, H * 0.02, -L * 0.42), body)
		E(ctx, "HammerUnder", Vector3.new(L * 0.38, H * 0.2, L * 0.1), CFrame.new(0, -H * 0.06, -L * 0.42), look.belly)
		for _, s in { 1, -1 } do
			EYE(ctx, Vector3.new(s * L * 0.2, H * 0.02, -L * 0.42), H * 0.22, Vector3.new(s, 0, 0), look.eye)
		end
	else
		EYES(ctx, W * 0.35, H * 0.12, -L * 0.33, H * 0.2, look.eye)
	end
	E(ctx, "Mouth", Vector3.new(W * 0.55, H * 0.06, L * 0.06), CFrame.new(0, -H * 0.3, -L * 0.33) * CFrame.Angles(rad(-15), 0, 0), INK)
	-- solungaç yarıkları
	for _, s in { 1, -1 } do
		for i = 0, 4 do
			E(ctx, "GillSlit", Vector3.new(ctx.thin, H * 0.4, L * 0.012), CFrame.new(s * W * 0.43, -H * 0.02, -L * 0.2 + i * L * 0.028) * CFrame.Angles(rad(10), 0, 0), darker(body, 0.4))
		end
	end
	-- yüzgeçler: büyük sırt (arkaya yatık), göğüs (yatay), küçük ikinci sırt, asimetrik kuyruk
	E(ctx, "Dorsal", Vector3.new(ctx.thin * 1.4, H * 1.7, L * 0.16), CFrame.new(0, H * 0.55, -L * 0.05) * CFrame.Angles(rad(-30), 0, 0), fin)
	FIN(ctx, "Dorsal2", Vector3.new(0, H * 0.25, L * 0.3), H * 0.2, L * 0.06, fin)
	for _, s in { 1, -1 } do
		E(ctx, "SideFin", Vector3.new(L * 0.24, ctx.thin * 1.4, L * 0.1), CFrame.new(s * W * 0.55, -H * 0.3, -L * 0.12) * CFrame.Angles(0, s * rad(-30), s * rad(-18)) * CFrame.new(s * L * 0.08, 0, 0), fin)
		E(ctx, "PelvicFin", Vector3.new(L * 0.08, ctx.thin, L * 0.05), CFrame.new(s * W * 0.25, -H * 0.38, L * 0.2) * CFrame.Angles(0, s * rad(-30), 0), fin)
	end
	E(ctx, "TailUpper", Vector3.new(ctx.thin * 1.4, L * 0.08, L * 0.36), CFrame.new(0, H * 0.45, L * 0.6) * CFrame.Angles(rad(48), 0, 0), fin)
	E(ctx, "TailLower", Vector3.new(ctx.thin * 1.4, L * 0.06, L * 0.18), CFrame.new(0, -H * 0.22, L * 0.55) * CFrame.Angles(rad(-45), 0, 0), fin)
end

local BUILDERS = {
	fish = buildFish,
	puffer = buildPuffer,
	lionfish = buildLionfish,
	seahorse = buildSeahorse,
	ray = buildRay,
	jelly = buildJelly,
	eel = buildEel,
	octopus = buildOctopus,
	angler = buildAngler,
	billfish = buildBillfish,
	shark = buildShark,
}

---------------------------------------------------------------------------------------------
-- Ana fonksiyon
---------------------------------------------------------------------------------------------
function FishModelBuilder.Build(fishId: string, sizeMul: number?): Model?
	local def = Fish[fishId]
	if not def then
		warn("FishModelBuilder: bilinmeyen balık", fishId)
		return nil
	end
	local look = def.look
	local mul = sizeMul or 1
	local L = look.length * mul
	local model = Instance.new("Model")
	model.Name = fishId
	-- Body: görünmez merkez parça (PrimaryPart). Bütün parçalar buna kaynaklı.
	local core = Instance.new("Part")
	core.Name = "Body"
	core.Size = Vector3.new(L * 0.2, L * 0.2, L) -- Size.Z = boy (eski kod buna göre konum hesaplar)
	core.Transparency = 1
	core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = false, false, false, false
	core.Anchored = true
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core
	local ctx = { model = model, body = core, L = L, reflect = look.reflect or 0, thin = math.max(L * 0.022, 0.04), material = look.metal and Enum.Material.Metal or nil }
	-- ana gövde elipsi (klasik balıkta görünür gövde; diğer türlerde kendi şekillerini çizerler)
	local kind = look.kind or "fish"
	if kind == "fish" or kind == "lionfish" then
		local sh = SHAPES[look.shape or "Normal"] or SHAPES.Normal
		if kind == "lionfish" then
			sh = SHAPES.Normal
		end
		E(ctx, "MainBody", Vector3.new(L * sh.w, L * sh.h, L * 0.78), CFrame.new(0, 0, L * 0.02), look.body)
	elseif kind == "puffer" then
		E(ctx, "MainBody", Vector3.new(L * 0.78, L * 0.74, L * 0.88), CFrame.new(0, 0, L * 0.02), look.body)
	elseif kind == "angler" then
		E(ctx, "MainBody", Vector3.new(L * 0.54, L * 0.58, L * 0.66), CFrame.new(0, L * 0.02, 0), look.body)
	elseif kind == "billfish" then
		E(ctx, "MainBody", Vector3.new(L * 0.15, L * 0.22, L * 0.78), CFrame.new(0, 0, L * 0.02), look.body)
	elseif kind == "shark" then
		E(ctx, "MainBody", Vector3.new(L * 0.2, L * 0.22, L * 0.8), CFrame.new(0, 0, 0), look.body)
	end
	local rng = Random.new(#fishId * 131 + string.byte(fishId, 1))
	local fn = BUILDERS[kind] or buildFish
	local ok, err = pcall(fn, ctx, look, rng)
	if not ok then
		warn("FishModelBuilder hata", fishId, err)
	end

	-- Nadirlik: Epic ve Legendary (ve glow = true) parlar; Legendary pırıltı saçar
	local rarity = Rarities[def.rarity]
	if rarity and (look.glow or def.rarity == "Epic" or def.rarity == "Legendary") then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Brightness = def.rarity == "Legendary" and 1.6 or 1
		light.Range = L * 2
		light.Parent = core
	end
	if rarity and def.rarity == "Legendary" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(rarity.color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, L * 0.06), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.8, 1.5)
		sparkle.Rate = 10
		sparkle.Speed = NumberRange.new(0.3, 0.9)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = core
	end

	model:SetAttribute("FishId", fishId)
	model:SetAttribute("Rarity", def.rarity)
	model:SetAttribute("Size", mul)
	return model
end

-- Rastgele boy varyantı (0.8x - 1.3x). Büyük balık daha nadir.
function FishModelBuilder.RollSize(rng: Random?): number
	local r = rng or Random.new()
	local t = r:NextNumber() ^ 2
	return math.floor((0.8 + t * 0.5) * 100 + 0.5) / 100
end

return FishModelBuilder
