--!nonstrict
-- 2. ada (Mermaid Island) sahillerine deniz kabukları: 3 çeşit, koddan Part'larla (mesh yok).
--   Scallop (yelpaze, pembe/şeftali), Conch (sarmal salyangoz kabuğu, krem + pembe ağız), Cowrie (parlak yumurta kabuk, benekli)
-- Sadece süs: dokunulmaz, çarpışmaz, raycast'e girmez.
-- Çalıştırma (Edit modunda, command bar / execute_luau):
--   require(game.ServerScriptService.Server.MapBuilder.Shells).Build()   -- sonra save_place
-- Eskileri siler, yeniden kurar: Workspace.Atoll.Shells
local Workspace = game:GetService("Workspace")

local Shells = {}

local ORIGIN = Vector3.new(6000, 0, 0) -- atoll merkezi
local HALF_X, HALF_Z = 2090, 1400
local STEP = 10 -- tarama aralığı (stud)
local BEACH_MIN_Y, BEACH_MAX_Y = 0.2, 4.5 -- kıyı şeridi yüksekliği
local CLUSTERS = 70 -- kaç kabuk kümesi
local rng = Random.new(2311)

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new(if shape == "wedge" then "WedgePart" else "Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end

-- Tarak / yelpaze kabuk: 9 kaburga yelpaze şeklinde açılır, dipte iki küçük "kulak"
local SCALLOP_COLORS = {
	Color3.fromRGB(255, 170, 150), Color3.fromRGB(255, 200, 160), Color3.fromRGB(240, 140, 160), Color3.fromRGB(255, 225, 190),
}
local function scallop(parent, cf, s)
	local m = Instance.new("Model")
	m.Name = "Scallop"
	local col = SCALLOP_COLORS[rng:NextInteger(1, #SCALLOP_COLORS)]
	local ribs = 9
	for i = 1, ribs do
		local a = math.rad(-62 + (i - 1) * (124 / (ribs - 1)))
		local shade = if i % 2 == 0 then col else col:Lerp(Color3.new(1, 1, 1), 0.25)
		local len = 1.15 * s
		local rib = part(m, "Rib", Vector3.new(0.24 * s, 0.14 * s, len), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.06 * s, -len / 2) * CFrame.Angles(math.rad(-6), 0, 0), shade, Enum.Material.SmoothPlastic)
		rib.Reflectance = 0.05
	end
	local hinge = part(m, "Hinge", Vector3.new(0.55 * s, 0.14 * s, 0.22 * s), cf * CFrame.new(0, 0.05 * s, 0.08 * s), col:Lerp(Color3.new(0, 0, 0), 0.15))
	hinge.Name = "Hinge"
	m.Parent = parent
	return m
end

-- Sarmal kabuk (conch): uzun gövde, arkaya doğru incelen sarmal tepe (halkalar), kahve çizgiler, geniş pembe ağız
local function conch(parent, cf, s)
	local m = Instance.new("Model")
	m.Name = "Conch"
	local cream = Color3.fromRGB(246, 230, 205)
	local band = Color3.fromRGB(196, 140, 98)
	-- gövde: yere yatık uzun oval
	local body = part(m, "Body", Vector3.new(0.75 * s, 0.6 * s, 1.25 * s), cf * CFrame.new(0, 0.27 * s, 0), cream, Enum.Material.SmoothPlastic, "ball")
	body.Reflectance = 0.06
	-- çizgiler
	for i = -1, 1 do
		part(m, "Stripe", Vector3.new(0.78 * s, 0.08 * s, 0.1 * s), cf * CFrame.new(0, 0.3 * s, i * 0.32 * s), band, Enum.Material.SmoothPlastic, "ball")
	end
	-- sarmal tepe: arkaya doğru küçülen halkalar (silindirler), hafif yukarı kalkık
	local z = 0.5 * s
	for i, k in { 0.5, 0.38, 0.27, 0.17 } do
		local d = k * s
		part(m, "Whorl", Vector3.new(d * 0.55, d, d), cf * CFrame.new(0, 0.28 * s + i * 0.05 * s, z) * CFrame.Angles(0, math.rad(90), math.rad(-8 * i)),
			if i % 2 == 0 then band else cream, Enum.Material.SmoothPlastic, "cyl")
		z += d * 0.5
	end
	-- uç
	part(m, "Tip", Vector3.new(0.1 * s, 0.1 * s, 0.22 * s), cf * CFrame.new(0, 0.5 * s, z + 0.05 * s), band, Enum.Material.SmoothPlastic, "ball")
	-- ağız: önde yana açılan pembe dudak
	local lip = part(m, "Lip", Vector3.new(0.18 * s, 0.5 * s, 0.85 * s), cf * CFrame.new(0.34 * s, 0.28 * s, -0.2 * s) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(255, 165, 170), Enum.Material.SmoothPlastic, "ball")
	lip.Reflectance = 0.1
	m.Parent = parent
	return m
end

-- Parlak yumurta kabuk (cowrie): basık oval + üstte benekler + altta ince yarık
local COWRIE = { Color3.fromRGB(250, 245, 235), Color3.fromRGB(235, 205, 160), Color3.fromRGB(215, 185, 230) }
local function cowrie(parent, cf, s)
	local m = Instance.new("Model")
	m.Name = "Cowrie"
	local col = COWRIE[rng:NextInteger(1, #COWRIE)]
	local body = part(m, "Shell", Vector3.new(0.6 * s, 0.34 * s, 0.9 * s), cf * CFrame.new(0, 0.15 * s, 0), col, Enum.Material.SmoothPlastic, "ball")
	body.Reflectance = 0.2
	for i = 1, 4 do
		part(m, "Spot", Vector3.new(0.09 * s, 0.05 * s, 0.09 * s), cf * CFrame.new((rng:NextNumber() - 0.5) * 0.3 * s, 0.31 * s, (rng:NextNumber() - 0.5) * 0.55 * s), Color3.fromRGB(140, 95, 60), Enum.Material.SmoothPlastic, "ball")
	end
	part(m, "Slit", Vector3.new(0.05 * s, 0.06 * s, 0.7 * s), cf * CFrame.new(0, 0.02 * s, 0), Color3.fromRGB(90, 60, 40))
	m.Parent = parent
	return m
end

local MAKERS = { scallop, conch, cowrie }

-- Bu noktada kuru kum var mı? (su ile ölç: üstte su varsa ıslak sayılır)
local wetParams = RaycastParams.new()
wetParams.FilterType = Enum.RaycastFilterType.Include
wetParams.FilterDescendantsInstances = { Workspace.Terrain }
wetParams.IgnoreWater = false
local function groundAt(pos: Vector3)
	local r = Workspace:Raycast(Vector3.new(pos.X, 80, pos.Z), Vector3.new(0, -120, 0), wetParams)
	if r and r.Material == Enum.Material.Sand and r.Position.Y > BEACH_MIN_Y and r.Position.Y < BEACH_MAX_Y and r.Normal.Y > 0.8 then
		return { pos = r.Position, normal = r.Normal }
	end
	return nil
end

-- Kıyı noktası mı? Kum, alçak, ve yakınında su var
local function beachPoints()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	local land = RaycastParams.new()
	land.FilterType = Enum.RaycastFilterType.Include
	land.FilterDescendantsInstances = { Workspace.Terrain }
	land.IgnoreWater = true
	local pts = {}
	local n = 0
	for x = -HALF_X, HALF_X, STEP do
		for z = -HALF_Z, HALF_Z, STEP do
			local o = ORIGIN + Vector3.new(x, 0, z)
			local r = Workspace:Raycast(Vector3.new(o.X, 80, o.Z), Vector3.new(0, -120, 0), params)
			if r and r.Material == Enum.Material.Sand and r.Position.Y > BEACH_MIN_Y and r.Position.Y < BEACH_MAX_Y then
				-- 14 stud içinde su var mı?
				local near = false
				for _, d in { Vector3.new(14, 0, 0), Vector3.new(-14, 0, 0), Vector3.new(0, 0, 14), Vector3.new(0, 0, -14) } do
					local w = Workspace:Raycast(Vector3.new(o.X + d.X, 80, o.Z + d.Z), Vector3.new(0, -120, 0), params)
					if w and w.Material == Enum.Material.Water then
						near = true
						break
					end
				end
				if near then
					local g = Workspace:Raycast(Vector3.new(o.X, 80, o.Z), Vector3.new(0, -120, 0), land)
					if g then
						table.insert(pts, { pos = g.Position, normal = g.Normal })
					end
				end
			end
		end
		n += 1
		if n % 20 == 0 then
			task.wait()
		end
	end
	return pts
end

function Shells.Build()
	local atoll = Workspace:FindFirstChild("Atoll")
	if not atoll then
		return "no Atoll"
	end
	local old = atoll:FindFirstChild("Shells")
	if old then
		old:Destroy()
	end
	local pts = beachPoints()
	if #pts == 0 then
		return "no beach points"
	end
	local folder = Instance.new("Folder")
	folder.Name = "Shells"
	local placed = 0
	local used = {}
	local guard = 0
	local counts = { 0, 0, 0 }
	while placed < CLUSTERS and guard < CLUSTERS * 20 do
		guard += 1
		local p = pts[rng:NextInteger(1, #pts)]
		local key = math.floor(p.pos.X / 60) .. ":" .. math.floor(p.pos.Z / 60)
		if not used[key] then
			used[key] = true
			placed += 1
			-- küme: 1-3 kabuk, yakın aralıkla, karışık türler
			local k = rng:NextInteger(1, 3)
			for _ = 1, k do
				-- her kabuk kendi noktasında yeniden ölçülür: kum, kuru ve kıyı bandında olmalı
				local off = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				local spot = groundAt(p.pos + off)
				if spot then
					local up = spot.normal
					local look = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0).LookVector
					local right = look:Cross(up)
					if right.Magnitude < 0.01 then
						right = Vector3.new(1, 0, 0)
					end
					right = right.Unit
					local fwd = up:Cross(right).Unit
					local cf = CFrame.fromMatrix(spot.pos - up * 0.05, right, up, -fwd)
					local t = rng:NextInteger(1, 3)
					counts[t] += 1
					MAKERS[t](folder, cf, rng:NextNumber(1.1, 1.6))
				end
			end
		end
	end
	folder.Parent = atoll
	return string.format("beach points %d, clusters %d, scallop %d conch %d cowrie %d", #pts, placed, counts[1], counts[2], counts[3])
end

return Shells
