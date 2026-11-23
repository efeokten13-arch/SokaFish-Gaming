--!nonstrict
-- Ana adayı canlandırma (Kasım 2026, "Fisch / Sea of Thieves" havası):
--   FishMarket  : kuzey kıyısında, iskeleli, balıkçı barakası tarzı satış binası (eski MainHall'ın yerine)
--   Hills       : kuzeybatı ve kuzeydoğuda kayalık tepeler / uçurumlar
--   Ground      : patika kenarı toprak, palmiye altı koyu çim, kıyıda kaya/kalas/yosunlu taş
--   Props       : yön tabelaları, fener direkleri, çitler, iskele girişi süsleri, kamp alanı, çapa, karaya vurmuş sandal
--   BoatHouse   : iskele girişinde yarı açık kayıkhane (Boat Shop)
--   Piers       : iskele kazıklarında yosun + köpük
--   Lighting    : öğleden sonra güneşi, sıcak ufuk sisi
-- Hepsi sabit tohumla üretilir; tekrar çalıştırmak eskisini silip yeniden kurar.
-- Studio command bar: require(game.ServerScriptService.Server.MapBuilder).IslandLife()
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Terrain = Workspace.Terrain
local Util = require(script.Parent.Util)
local Land = require(script.Parent.Land)
local Decor = require(script.Parent.Decor)
local Props = require(script.Parent.Props)

local IslandLife = {}

local DARK = Props.DARK
local CREAM = Color3.fromRGB(255, 244, 214)
local SAND = Enum.Material.Sandstone

local function v3(x, y, z)
	return Vector3.new(x, y, z)
end

local function flat(p: Vector3): Vector2
	return Vector2.new(p.X, p.Z)
end

-- Bir alanın içindeki doğal süsleri (palmiye, çalı, kaya, çiçek, eğrelti) sil: yeni yapılar için yer aç
local function clearDecor(x, z, r)
	local center = Vector2.new(x, z)
	for _, folderName in { "Nature", "MainIslandProps", "IslandLifeProps" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, d in folder:GetDescendants() do
				if d.Parent and (d:IsA("Model") or d:IsA("BasePart")) then
					local name = d.Name
					local natural = name == "Palm" or name == "Bush" or name == "Rock" or name == "Flowers" or name == "Fern" or name == "Crate" or name == "Barrel"
					if natural then
						local p = d:IsA("Model") and d:GetPivot().Position or d.Position
						if p.Y < 40 and (flat(p) - center).Magnitude < r then
							d:Destroy()
						end
					end
				end
			end
		end
	end
end
IslandLife.clearDecor = clearDecor

-- Kumsalda bir nokta bul: x sabit, z0'dan z1'e doğru ilk kum (yükseklik 0.6-3.5)
local function findBeach(x, z0, z1)
	local step = if z1 > z0 then 2 else -2
	for z = z0, z1, step do
		local gy = Util.groundY(x, z)
		if gy and gy > 0.6 and gy < 3.5 then
			return v3(x, gy, z)
		end
	end
	return nil
end

-- Yer seviyesi (yoksa çim seviyesi)
local function ground(cfg, x, z)
	return Util.groundY(x, z) or cfg.GrassY
end

------------------------------------------------------------------------------------------
-- 1) Balık pazarı: kıyıda, ahşap platform üstünde barakası + kuzeye uzanan bağlama iskelesi
------------------------------------------------------------------------------------------
function IslandLife.FishMarket(cfg)
	local F = cfg.FishMarket
	local old = Workspace:FindFirstChild("MainHall")
	if old then
		old:Destroy()
	end
	local m = Util.fresh("Model", "FishMarket")
	local rng = Random.new(cfg.Seed + 700)
	local y = cfg.DeckY -- platform üst yüzü
	local cx, cz = F.x, F.z
	local W, D, H = F.width, F.depth, 10 -- bina: X genişlik, Z derinlik, duvar yüksekliği
	local frontZ, backZ = cz + D / 2, cz - D / 2 -- ön = güney (ada tarafı), arka = kuzey (iskele tarafı)

	-- eski salonun zemini çime dönsün; yeni yol pazara gitsin
	Terrain:ReplaceMaterial(Region3.new(v3(-72, 0, -156), v3(32, 12, -80)):ExpandToGrid(4), 4, Enum.Material.Ground, Enum.Material.Grass)
	local P = cfg.Plaza
	Land.wavyPath(v3(P.x, 0, P.z - P.radius + 4), v3(cx, 0, frontZ + 9), 6, SAND, 12, 4, 1)
	clearDecor(cx, cz, 44)
	-- kıyı kayası iskeleye engel olmasın
	Terrain:FillBall(v3(cx, -2, backZ - 6), 9, Enum.Material.Water)

	-- platform: kara tarafından denize uzanan tahta zemin
	local plat = Util.part(m, "Platform", v3(W + 14, 1, D + 16), CFrame.new(cx, y - 0.5, cz - 1), Props.WOOD, Enum.Material.WoodPlanks)
	for i = 0, 6 do -- kalas çizgileri
		local px = cx - (W + 14) / 2 + 2 + i * (W + 10) / 6
		Props.deco(Util.part(m, "Seam", v3(0.25, 0.05, D + 16), CFrame.new(px, y + 0.02, cz - 1), DARK, Enum.Material.Wood), false)
	end
	local function piling(x, z, top)
		local gy = Util.groundY(x, z)
		if gy and gy > y - 1.5 then
			return
		end
		local p = Util.pole(m, "Piling", x, z, -12, top or (y + 0.6), 1.2, DARK, Enum.Material.Wood)
		p:SetAttribute("Piling", true)
	end
	for x = cx - (W + 14) / 2 + 1, cx + (W + 14) / 2 - 1, 7 do
		for z = cz - 1 - (D + 16) / 2 + 1, cz - 1 + (D + 16) / 2 - 1, 7 do
			piling(x, z)
		end
	end

	-- duvarlar: dikey kalaslar (yıpranmış, renkleri hafif farklı). openings = { {from, to, y0, y1} } yatay konum boşlukları
	local function plankWall(name, a: Vector3, b: Vector3, openings)
		local dir = (b - a)
		local len = dir.Magnitude
		local u = dir.Unit
		local n = math.floor(len / 1.6)
		local step = len / n
		for i = 0, n - 1 do
			local t0 = i * step
			local mid = a + u * (t0 + step / 2)
			local col = Props.oldWood(rng)
			local cut = nil
			for _, o in openings or {} do
				if t0 + step / 2 > o[1] and t0 + step / 2 < o[2] then
					cut = o
				end
			end
			local look = CFrame.lookAt(mid, mid + u)
			local function board(y0, y1)
				if y1 - y0 > 0.1 then
					Util.part(m, name, v3(0.5, y1 - y0, step - 0.08), look * CFrame.new(0, 0, 0) + v3(0, y + (y0 + y1) / 2, 0) - v3(0, look.Position.Y, 0) + v3(0, mid.Y, 0), col, Enum.Material.WoodPlanks)
				end
			end
			if cut then
				board(0, cut[3])
				board(cut[4], H)
			else
				board(0, H)
			end
		end
	end
	local win = 16 -- satış penceresi genişliği
	local wo = { { W / 2 - win / 2, W / 2 + win / 2, 3.4, 7.8 } }
	plankWall("Wall", v3(cx - W / 2, 0, frontZ), v3(cx + W / 2, 0, frontZ), wo)
	plankWall("Wall", v3(cx - W / 2, 0, backZ), v3(cx + W / 2, 0, backZ), wo)
	plankWall("Wall", v3(cx - W / 2, 0, backZ), v3(cx - W / 2, 0, frontZ), { { D / 2 - 2, D / 2 + 2, 0, 7.4 } }) -- yan kapı
	plankWall("Wall", v3(cx + W / 2, 0, backZ), v3(cx + W / 2, 0, frontZ), { { D / 2 - 2.5, D / 2 + 2.5, 3.8, 7.2 } }) -- yan pencere
	-- köşe ve kapı direkleri (kalın, koyu)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Util.part(m, "CornerPost", v3(1.4, H + 0.6, 1.4), CFrame.new(cx + sx * W / 2, y + (H + 0.6) / 2, cz + sz * D / 2), DARK, Enum.Material.Wood)
		end
		for _, z in { frontZ, backZ } do
			Util.part(m, "WindowPost", v3(1, H, 1.2), CFrame.new(cx + sx * (win / 2 + 0.3), y + H / 2, z), DARK, Enum.Material.Wood)
		end
	end
	-- yatay kuşak kirişler
	for _, z in { frontZ, backZ } do
		for _, hy in { 0.4, H - 0.3 } do
			Props.deco(Util.part(m, "Beam", v3(W + 1, 0.6, 1.3), CFrame.new(cx, y + hy, z), DARK, Enum.Material.Wood))
		end
	end
	for _, x in { cx - W / 2, cx + W / 2 } do
		Props.deco(Util.part(m, "Beam", v3(1.3, 0.6, D + 1), CFrame.new(x, y + H - 0.3, cz), DARK, Enum.Material.Wood))
	end
	Util.part(m, "Floor", v3(W - 1, 0.3, D - 1), CFrame.new(cx, y + 0.15, cz), Color3.fromRGB(120, 92, 66), Enum.Material.WoodPlanks)

	-- satış tezgahları (iki yüzde) + açılır kepenkler
	local counters = {}
	for _, s in { 1, -1 } do -- 1 = ön (ada), -1 = arka (iskele)
		local z = cz + s * (D / 2 + 1.1)
		local c = Util.part(m, "SellCounter", v3(win + 1, 0.7, 2.8), CFrame.new(cx, y + 3.75, z), Color3.fromRGB(150, 110, 72), Enum.Material.WoodPlanks)
		table.insert(counters, c)
		for _, bx in { -win / 2 + 1, 0, win / 2 - 1 } do
			Props.deco(Util.part(m, "Bracket", v3(0.5, 1.6, 1.8), CFrame.new(cx + bx, y + 2.6, z - s * 0.3) * CFrame.Angles(s * math.rad(-35), 0, 0), DARK, Enum.Material.Wood))
		end
		-- kepenk: üstten menteşeli, dışa açık (tente gibi)
		local flapCF = CFrame.new(cx, y + 7.9, cz + s * D / 2) * CFrame.Angles(-s * math.rad(62), 0, 0) * CFrame.new(0, 0, s * 2.1)
		Props.deco(Util.part(m, "Shutter", v3(win + 1, 0.35, 4.4), flapCF, Props.oldWood(rng), Enum.Material.WoodPlanks))
		for _, bx in { -win / 2 + 0.6, win / 2 - 0.6 } do
			local top = (CFrame.new(cx + bx, y + 7.9, cz + s * D / 2) * CFrame.Angles(-s * math.rad(62), 0, 0) * CFrame.new(0, 0, s * 4)).Position
			Props.deco(Util.rod(m, "ShutterProp", v3(cx + bx, y + 4.2, cz + s * (D / 2 + 0.4)), top, 0.25, DARK, Enum.Material.Wood))
		end
		-- tezgahta buzlu balıklar
		Props.fishCrate(m, CFrame.new(cx - 4.5, y + 4.1, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), rng)
		Props.fishCrate(m, CFrame.new(cx + 4.8, y + 4.1, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), rng)
	end

	-- çatı: X boyunca mahya, 2 stud saçak, açıkta kirişler, baca
	local over = 2.2
	local rise = 6
	local half = D / 2 + over
	local ang = math.atan2(rise, D / 2)
	local slopeLen = half / math.cos(ang)
	local top = y + H
	local SHINGLE = Color3.fromRGB(92, 104, 108)
	for _, s in { -1, 1 } do
		local midY = top + rise - math.tan(ang) * half / 2 + 0.4
		local roof = Util.part(m, "Roof", v3(W + over * 2, 0.8, slopeLen), CFrame.new(cx, midY, cz + s * half / 2) * CFrame.Angles(s * ang, 0, 0), SHINGLE, Enum.Material.Slate)
		-- kiremit sıraları
		for k = 1, 5 do
			Props.deco(Util.part(m, "ShingleRow", v3(W + over * 2 + 0.1, 0.25, 0.4), roof.CFrame * CFrame.new(0, 0.45, -slopeLen / 2 + k * slopeLen / 6), SHINGLE:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate), false)
		end
		-- saçak altı kirişler
		for x = cx - W / 2, cx + W / 2 + 0.1, W / 6 do
			Props.deco(Util.part(m, "Rafter", v3(0.6, 0.6, slopeLen + 0.3), roof.CFrame * CFrame.new(x - cx, -0.65, 0), DARK, Enum.Material.Wood))
		end
		-- alınlık: üçgen duvarlar
		for _, sx in { -1, 1 } do
			local g = Props.deco(Util.wedge(m, "Gable", v3(0.6, rise, D / 2), CFrame.new(cx + sx * W / 2, top + rise / 2, cz + s * D / 4) * CFrame.Angles(0, s == 1 and math.pi or 0, 0), Props.oldWood(rng), Enum.Material.WoodPlanks))
			g.CanCollide = true
		end
	end
	Util.part(m, "Ridge", v3(W + over * 2 + 0.6, 0.9, 1.4), CFrame.new(cx, top + rise + 0.45, cz), DARK, Enum.Material.Wood)
	Util.part(m, "Ceiling", v3(W, 0.4, D), CFrame.new(cx, top + 0.2, cz), DARK, Enum.Material.Wood)
	-- soba borusu bacası + duman
	local chim = Util.cyl(m, "Chimney", 5, 1.2, CFrame.new(cx + W / 2 - 4, top + rise + 1.2, cz - D / 4) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 70, 74), Enum.Material.Metal)
	Props.deco(Util.cyl(m, "ChimneyCap", 0.4, 2, chim.CFrame * CFrame.new(2.6, 0, 0), Color3.fromRGB(60, 60, 64), Enum.Material.Metal))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 3
	smoke.Lifetime = NumberRange.new(4, 6)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = chim

	-- tabelalar: ön cephede büyük "FISH MARKET", iskele tarafında "SELL FISH"; yanlarında asılı fenerler
	local function hangingSign(z, s, text, w)
		-- tabela saçağın üstünde, iki kısa direkle çatıya oturur; yanlarda duvardan sarkan fenerler
		local board = Util.part(m, "Sign", v3(w, 3, 0.5), CFrame.new(cx, top + 2.3, z - s * 0.6), Color3.fromRGB(46, 78, 96), Enum.Material.WoodPlanks)
		Props.deco(Util.part(m, "SignFrame", v3(w + 0.8, 3.7, 0.35), board.CFrame * CFrame.new(0, 0, -s * 0.35), DARK, Enum.Material.Wood))
		Util.sign(board, s == 1 and Enum.NormalId.Back or Enum.NormalId.Front, text, CREAM).LightInfluence = 0.2
		for _, sx in { -1, 1 } do
			Props.deco(Util.part(m, "SignPost", v3(0.5, 2.6, 0.5), CFrame.new(cx + sx * (w / 2 - 1.5), top + 0.4, z - s * 1), DARK, Enum.Material.Wood))
			Props.lantern(m, CFrame.new(cx + sx * (win / 2 + 2.2), y + 8.1, z + s * 1.9))
			Props.deco(Util.part(m, "LanternArm", v3(0.3, 0.3, 2.2), CFrame.new(cx + sx * (win / 2 + 2.2), y + 9.1, z + s * 1), DARK, Enum.Material.Wood))
		end
		return board
	end
	hangingSign(frontZ, 1, "FISH MARKET", 18)
	hangingSign(backZ, -1, "SELL FISH", 12)

	-- terazi (ön saçaktan asılı), ağlar, can simidi, şamandıralar
	Props.scale(m, CFrame.new(cx - win / 2 - 4.2, y + 9.3, frontZ + 1.4))
	Props.net(m, CFrame.new(cx - W / 2 - 0.45, y + 5, cz) * CFrame.Angles(0, math.pi / 2, 0), D - 4, 5)
	Props.lifeRing(m, CFrame.new(cx + W / 2 + 0.4, y + 5.5, cz + 4) * CFrame.Angles(0, -math.pi / 2, 0))
	for k = 0, 3 do
		Props.buoy(m, CFrame.new(cx + W / 2 + 0.7, y + 8 - k * 0.2, cz - 3 - k * 1.4), k % 2 == 0 and Color3.fromRGB(215, 70, 55) or Color3.fromRGB(240, 236, 228))
	end

	-- binanın etrafında kasalar, fıçılar, halatlar
	Props.crateStack(m, CFrame.new(cx - W / 2 - 4, y, frontZ + 4) * CFrame.Angles(0, 0.2, 0), rng, 3)
	Props.crateStack(m, CFrame.new(cx + W / 2 + 4.5, y, frontZ + 3) * CFrame.Angles(0, -0.3, 0), rng, 2)
	Props.barrel(m, CFrame.new(cx - W / 2 - 3, y, cz - 2), rng)
	Props.barrel(m, CFrame.new(cx - W / 2 - 3.2, y, cz + 1), rng)
	Props.barrel(m, CFrame.new(cx + W / 2 + 3, y, backZ - 3), rng)
	Props.coil(m, CFrame.new(cx + W / 2 + 4, y, cz + 1))
	Props.bucket(m, CFrame.new(cx - win / 2 - 2, y, frontZ + 2.6), true)
	Props.rodStand(m, CFrame.new(cx - W / 2 - 4, y, backZ - 2) * CFrame.Angles(0, math.pi / 2, 0), rng)

	-- satıcı NPC: tezgahın arkasında, adaya bakar
	local tpl = ServerStorage:FindFirstChild("NPCTemplates")
	local npcT = tpl and (tpl:FindFirstChild("FishMerchant") or tpl:FindFirstChild("RodMerchant"))
	if npcT then
		local npc = npcT:Clone()
		npc.Name = "FishMerchant"
		local _, size = npc:GetBoundingBox()
		local root = npc:FindFirstChild("HumanoidRootPart")
		for _, d in npc:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = d == root
				d.CanCollide = false
			end
		end
		npc:PivotTo(CFrame.lookAt(v3(cx + 1.5, y + size.Y / 2, frontZ - 2.4), v3(cx + 1.5, y + size.Y / 2, frontZ + 10)))
		local hum = npc:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		npc.Parent = m
		local head = npc:FindFirstChild("Head") or root
		if head then
			Util.billboard(head, "Fishmonger", 2.4, 180).MaxDistance = 50
		end
	end

	-- içeride ışık
	Util.light(Util.zone(m, "InsideLight", v3(1, 1, 1), CFrame.new(cx, top - 1.5, cz)), 1, 26)

	-- bağlama iskelesi: platformdan kuzeye, ucunda T başı
	local dz0 = cz - 1 - (D + 16) / 2
	local L = F.dockLength
	local dz1 = dz0 - L
	Util.part(m, "Dock", v3(9, 1, L), CFrame.new(cx, y - 0.5, (dz0 + dz1) / 2), Props.WOOD, Enum.Material.WoodPlanks)
	Util.part(m, "DockHead", v3(44, 1, 9), CFrame.new(cx, y - 0.5, dz1 - 4.5), Props.WOOD, Enum.Material.WoodPlanks)
	for z = dz0 - 4, dz1, -9 do
		for _, sx in { -1, 1 } do
			piling(cx + sx * 4, z, y + 1.4)
		end
	end
	for x = cx - 21, cx + 21, 7 do
		for _, dz in { -0.5, -8.5 } do
			piling(x, dz1 + dz, y + 1.4)
		end
	end
	-- babalar, halatlar, fenerler, kasalar
	for z = dz0 - 10, dz1 + 2, -14 do
		for _, sx in { -1, 1 } do
			Props.bollard(m, CFrame.new(cx + sx * 3.6, y, z))
		end
		Props.coil(m, CFrame.new(cx - 2.4, y, z - 3), 0.9)
	end
	for _, sx in { -1, 1 } do
		Props.bollard(m, CFrame.new(cx + sx * 20, y, dz1 - 7.6))
		Props.lanternPost(m, CFrame.new(cx + sx * 20, y, dz1 - 1.2) * CFrame.Angles(0, sx == 1 and math.pi / 2 or -math.pi / 2, 0), 8)
	end
	Props.lanternPost(m, CFrame.new(cx + 3.6, y, dz0 - 2) * CFrame.Angles(0, -math.pi / 2, 0), 8)
	Props.crateStack(m, CFrame.new(cx - 14, y, dz1 - 5) * CFrame.Angles(0, 0.1, 0), rng, 3)
	Props.barrel(m, CFrame.new(cx + 12, y, dz1 - 5), rng)
	Props.net(m, CFrame.new(cx, y + 3.4, dz1 - 8.8), 14, 3.4)
	Props.deco(Util.part(m, "NetBar", v3(15, 0.35, 0.35), CFrame.new(cx, y + 5.2, dz1 - 8.8), DARK, Enum.Material.Wood))
	for _, sx in { -7.3, 7.3 } do
		Util.part(m, "NetPost", v3(0.5, 5.4, 0.5), CFrame.new(cx + sx, y + 2.7, dz1 - 8.8), DARK, Enum.Material.Wood)
	end

	m.PrimaryPart = counters[1]
	return m
end

------------------------------------------------------------------------------------------
-- 2) Tepeler ve uçurumlar
------------------------------------------------------------------------------------------
-- { x, z, yükseklik, taban yarıçapı, kıyıya bakan yön (açı, derece) }
local HILLS = {
	{ -152, -112, 30, 34, 225 },
	{ -116, -146, 22, 26, 250 },
	{ -170, -88, 18, 22, 190 },
	{ -84, -160, 13, 20, 265 },
	{ 118, -142, 24, 30, 300 },
	{ 146, -118, 15, 18, 330 },
}
IslandLife.HILLS = HILLS

local function hill(cfg, h, rng)
	local x, z, height, base, faceDeg = h[1], h[2], h[3], h[4], h[5]
	local g = cfg.GrassY
	local face = Vector3.new(math.cos(math.rad(faceDeg)), 0, math.sin(math.rad(faceDeg)))
	-- gövde: üst üste küçülen toplar; tepe merkezi kıyıya doğru kayar (kıyı tarafı dik = uçurum)
	local R0 = base + 4
	local n = 7
	for k = 0, n do
		local f = k / n
		local r = R0 * (1 - 0.75 * f)
		local topY = g + height * (0.5 + 0.5 * f)
		local shift = face * (f * base * 0.3)
		local jx, jz = rng:NextNumber(-0.1, 0.1) * r, rng:NextNumber(-0.1, 0.1) * r
		Terrain:FillBall(v3(x + jx, topY - r, z + jz) + shift, r, f > 0.55 and Enum.Material.LeafyGrass or Enum.Material.Grass)
	end
	-- kıyı tarafı: kaya uçurum yüzleri
	for k = 0, 4 do
		local a = math.rad(faceDeg) + (k - 2) * 0.32
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local rr = base * rng:NextNumber(0.28, 0.4)
		local hh = g + height * rng:NextNumber(0.25, 0.65)
		Terrain:FillBall(v3(x, 0, z) + d * base * 0.62 + v3(0, hh - rr * 0.4, 0), rr, Enum.Material.Rock)
	end
	-- tepe kayası
	Terrain:FillBall(v3(x, g + height - base * 0.12, z) + face * base * 0.3, base * 0.15, Enum.Material.Rock)
	-- kaya etek bandı (zemin hizasında)
	Land.paintDisc(x, z, base * 0.95, Enum.Material.Rock, Enum.Material.Grass)
	Land.paintDisc(x, z, base * 0.95, Enum.Material.Rock, Enum.Material.LeafyGrass)
end

function IslandLife.Hills(cfg)
	local rng = Random.new(cfg.Seed + 711)
	for _, h in HILLS do
		clearDecor(h[1], h[2], h[4] + 4)
	end
	for _, h in HILLS do
		hill(cfg, h, rng)
		task.wait()
	end
	-- tepelere bitki: zemine oturt (yamaçta)
	local folder = Util.fresh("Folder", "HillPlants", Workspace:FindFirstChild("Nature") or Workspace)
	for _, h in HILLS do
		for _ = 1, math.floor(h[4] / 2) do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * h[4] * 0.85
			local x, z = h[1] + math.cos(a) * r, h[2] + math.sin(a) * r
			local gy = Util.groundY(x, z)
			if gy and gy > cfg.GrassY + 1 then
				local roll = rng:NextNumber()
				if roll < 0.18 then
					Decor.palm(folder, v3(x, gy - 0.5, z), rng)
				elseif roll < 0.5 then
					Decor.bush(folder, v3(x, gy, z), rng)
				elseif roll < 0.7 then
					Decor.fern(folder, v3(x, gy, z), rng)
				elseif roll < 0.85 then
					Decor.flowers(folder, v3(x, gy, z), rng)
				else
					Decor.rock(folder, v3(x, gy - 0.4, z), rng)
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- 3) Zemin dokuları + kıyı detayları
------------------------------------------------------------------------------------------
function IslandLife.Ground(cfg)
	local P = cfg.Plaza
	local GROUND = Enum.Material.Ground
	-- patika kenarları toprak (sadece çimi boyar, patikanın kendisi kalır)
	Land.path(v3(P.x + P.radius - 4, 0, P.z), v3(cfg.Pier.startX + 2, 0, cfg.Pier.walkZ), 8.5, GROUND)
	Land.wavyPath(v3(P.x, 0, P.z - P.radius + 4), v3(cfg.FishMarket.x, 0, cfg.FishMarket.z + cfg.FishMarket.depth / 2 + 9), 8.5, GROUND, 12, 4, 1)
	for i, h in { { -135, 70 }, { -150, -60 } } do
		local a = v3(P.x, 0, P.z)
		local b = v3(h[1], 0, h[2] + 10)
		Land.wavyPath(a + (b - a).Unit * (P.radius - 4), b, 7, GROUND, 20 + i, 6, 1.5)
	end
	Land.wavyPath(v3(P.x, 0, P.z + P.radius - 4), v3(P.x, 0, 200), 7.5, GROUND, 31, 6, 1.5)
	Land.wavyPath(v3(P.x - P.radius + 4, 0, P.z), v3(-200, 0, P.z), 7.5, GROUND, 41, 6, 1.5)
	task.wait()
	-- patikanın / plazanın üstünde kalan doğal süsleri kaldır (yol açık kalsın)
	local pathMats = { [Enum.Material.Sandstone] = true, [Enum.Material.Cobblestone] = true, [Enum.Material.Slate] = true, [Enum.Material.Sand] = false }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	for _, folderName in { "Nature", "MainIslandProps" } do
		local folder = Workspace:FindFirstChild(folderName)
		for _, d in folder and folder:GetDescendants() or {} do
			if d.Parent and d:IsA("Model") and (d.Name == "Palm" or d.Name == "Bush" or d.Name == "Fern" or d.Name == "Flowers") then
				local trunk = d:FindFirstChild("Trunk")
				local p = trunk and trunk.Position or d:GetPivot().Position
				if flat(p).Magnitude < 260 then
					local r = Workspace:Raycast(v3(p.X, 40, p.Z), v3(0, -80, 0), params)
					if r and pathMats[r.Material] then
						d:Destroy()
					end
				end
			end
		end
	end
	-- palmiye altları koyu yapraklı çim + diplerine eğrelti/çalı/çiçek
	local rng = Random.new(cfg.Seed + 733)
	local extra = Util.fresh("Folder", "TrunkPlants", Workspace:FindFirstChild("Nature") or Workspace)
	local n = 0
	for _, folderName in { "Nature", "MainIslandProps" } do
		local folder = Workspace:FindFirstChild(folderName)
		for _, d in folder and folder:GetDescendants() or {} do
			if d:IsA("Model") and d.Name == "Palm" then
				local p = d:GetPivot().Position
				local trunk = d:FindFirstChild("Trunk")
				local base = trunk and trunk.Position or p
				if flat(base).Magnitude < 260 and base.Y < 14 then
					Land.paintDisc(base.X, base.Z, 7, Enum.Material.LeafyGrass)
					for _ = 1, rng:NextInteger(1, 3) do
						local a = rng:NextNumber(0, math.pi * 2)
						local q = v3(base.X + math.cos(a) * rng:NextNumber(2, 4), 0, base.Z + math.sin(a) * rng:NextNumber(2, 4))
						local gy = Util.groundY(q.X, q.Z)
						if gy and gy > cfg.GrassY - 1 then
							local r = rng:NextNumber()
							local pos = v3(q.X, gy, q.Z)
							if r < 0.45 then
								Decor.fern(extra, pos, rng)
							elseif r < 0.75 then
								Decor.bush(extra, pos, rng)
							else
								Decor.flowers(extra, pos, rng)
							end
						end
					end
					n += 1
					if n % 15 == 0 then
						task.wait()
					end
				end
			end
		end
	end
	-- kıyı: yarı gömülü kayalar, yosunlu taşlar, eski kalaslar (iskeleler hariç)
	local shore = Util.fresh("Folder", "Shoreline", Workspace:FindFirstChild("Nature") or Workspace)
	local poly = cfg.Main.outline
	local F = cfg.FishMarket
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		local seg = Vector2.new(b[1] - a[1], b[2] - a[2])
		local count = math.floor(seg.Magnitude / 14)
		for k = 0, count do
			local t = (k + rng:NextNumber(0, 0.8)) / math.max(count, 1)
			local x, z = a[1] + seg.X * t, a[2] + seg.Y * t
			-- kumsalda bir yer ara (çizgiye dik, birkaç stud içeri/dışarı)
			local nrm = Vector2.new(-seg.Y, seg.X).Unit
			local found
			for _, off in { -6, -3, 0, 3, 6, -9 } do
				local px, pz = x + nrm.X * off, z + nrm.Y * off
				local gy = Util.groundY(px, pz)
				if gy and gy > 0.3 and gy < 4.2 then
					found = v3(px, gy, pz)
					break
				end
			end
			local nearPier = x > cfg.Pier.startX - 10 and z > cfg.Pier.zTop - 15 and z < cfg.Pier.zBottom + 10
			local nearMarket = (Vector2.new(x, z) - Vector2.new(F.x, F.z)).Magnitude < 40
			if found and not nearPier and not nearMarket then
				local r = rng:NextNumber()
				local cf = CFrame.new(found - v3(0, 0.5, 0))
				if r < 0.4 then
					Decor.rock(shore, found - v3(0, 0.8, 0), rng)
				elseif r < 0.7 then
					Props.mossStone(shore, cf, rng)
				elseif r < 0.9 then
					Props.plank(shore, cf + v3(0, 0.6, 0), rng)
				else
					Props.buoy(shore, cf + v3(0, 0.9, 0), Color3.fromRGB(200, 90, 60))
				end
			end
		end
		if i % 6 == 0 then
			task.wait()
		end
	end
end

------------------------------------------------------------------------------------------
-- 4) Süsler: yön tabelaları, fenerler, çitler, iskele girişi, kamp alanı, çapa, karaya vurmuş sandal
------------------------------------------------------------------------------------------
function IslandLife.Props(cfg)
	local f = Util.fresh("Folder", "IslandLifeProps")
	local rng = Random.new(cfg.Seed + 750)
	local P = cfg.Plaza
	local g = cfg.GrassY
	local F = cfg.FishMarket
	local pier = v3(cfg.Pier.startX, g, cfg.Pier.walkZ)
	local market = v3(F.x, g, F.z)
	local rod = v3(-135, g, 70)
	local hut = v3(-150, g, -60)
	local center = v3(P.x, g, P.z)
	local function dir(to, from)
		return (to - from) * v3(1, 0, 1)
	end

	-- yön tabelaları: plazanın çıkışlarında
	local s1 = center + v3(P.radius + 3, 0, -12)
	Props.signpost(f, s1, { { "Fish Market", dir(market, s1) }, { "Boat Shop", dir(pier, s1) }, { "Rod Shop", dir(rod, s1) } })
	local s2 = center + v3(-P.radius - 3, 0, -12)
	Props.signpost(f, s2, { { "Rod Shop", dir(rod, s2) }, { "Fish Market", dir(market, s2) }, { "Beach", v3(0, 0, 1) } })
	local s3 = v3(F.x + 12, g, F.z + F.depth / 2 + 30)
	Props.signpost(f, s3, { { "Plaza", dir(center, s3) }, { "Fish Market", dir(market, s3) } })

	-- fener direkleri: patikalar boyunca (yolun bir yanında)
	local function along(p0, p1, step, side)
		local d = (p1 - p0)
		local len = d.Magnitude
		local u = d.Unit
		local sideV = v3(-u.Z, 0, u.X) * side
		for t = step * 0.6, len - 4, step do
			local p = p0 + u * t + sideV * 10.5
			local gy = Util.groundY(p.X, p.Z)
			if gy and gy > g - 1 and gy < g + 2 then
				clearDecor(p.X, p.Z, 3)
				Props.lanternPost(f, CFrame.lookAt(v3(p.X, gy, p.Z), v3(p.X, gy, p.Z) - sideV), 8.5)
			end
		end
	end
	along(center + v3(0, 0, -P.radius), v3(F.x, g, F.z + F.depth / 2 + 10), 34, 1)
	along(center + v3(0, 0, P.radius), v3(P.x, g, 185), 36, -1)
	along(center + v3(-P.radius, 0, 0), v3(-185, g, P.z), 36, 1)
	along(center + v3(P.radius, 0, 0), v3(cfg.Pier.startX - 4, g, cfg.Pier.walkZ), 30, 1)

	-- çitler: güney patikası boyunca iki yanda kısa parçalar + kamp alanı
	for _, sx in { -1, 1 } do
		for z0 = P.z + P.radius + 22, 150, 34 do
			local a = v3(P.x + sx * 14, g, z0)
			local b = v3(P.x + sx * 14, g, z0 + 14)
			clearDecor(a.X, z0 + 7, 8)
			Props.fence(f, a, b, rng)
		end
	end

	-- iskele girişi: kasalar, ağ askısı, fıçılar, halatlar, çapa, olta standı
	local px, pz = cfg.Pier.startX, cfg.Pier.walkZ
	clearDecor(px - 10, pz, 14)
	Props.crateStack(f, CFrame.new(px - 8, g, pz + 9) * CFrame.Angles(0, 0.3, 0), rng, 3)
	Props.barrel(f, CFrame.new(px - 12, g, pz + 9.5), rng)
	Props.barrel(f, CFrame.new(px - 13.5, g, pz + 7), rng)
	Props.coil(f, CFrame.new(px - 5, g, pz + 7.5))
	Props.rodStand(f, CFrame.new(px - 16, g, pz + 9) * CFrame.Angles(0, math.pi, 0), rng)
	Decor.netRack(f, v3(px - 26, g, pz + 12), v3(px - 18, g, pz + 12), 7)

	-- plaza kenarı: kasalar, fıçı, ağ askısı, olta standı (yolların arasına)
	for k, ang in { 45, 121, 239, 315 } do
		local a = math.rad(ang)
		local p = center + v3(math.cos(a), 0, math.sin(a)) * (P.radius + 6)
		clearDecor(p.X, p.Z, 6)
		local cf = CFrame.lookAt(p, center)
		if k % 2 == 0 then
			Props.crateStack(f, cf, rng, 2)
			Props.barrel(f, cf * CFrame.new(3.8, 0, 0.5), rng)
		else
			Props.rodStand(f, cf, rng)
			Props.bucket(f, cf * CFrame.new(3, 0, 0), true)
		end
	end

	-- kamp alanı (güneybatı çayır)
	local camp = v3(-96, g, 136)
	local cgy = Util.groundY(camp.X, camp.Z) or g
	camp = v3(camp.X, cgy, camp.Z)
	clearDecor(camp.X, camp.Z, 18)
	Land.paintDisc(camp.X, camp.Z, 10, Enum.Material.Ground)
	local campCF = CFrame.new(camp)
	Props.campfire(f, campCF, rng)
	for i = 0, 2 do
		local a = math.rad(30 + i * 110)
		local p = camp + v3(math.cos(a), 0, math.sin(a)) * 5.5
		Props.logSeat(f, CFrame.lookAt(p, camp) * CFrame.Angles(0, 0, 0))
	end
	Props.tent(f, CFrame.lookAt(camp + v3(-9, 0, -6), camp) * CFrame.Angles(0, math.pi / 2, 0), rng)
	Props.barrel(f, CFrame.new(camp + v3(6, 0, -7)), rng)
	Props.lanternPost(f, CFrame.new(camp + v3(8, 0, 3)), 6)
	local fc = camp + v3(0, 0, 9)
	Props.fence(f, fc + v3(-9, 0, 0), fc + v3(9, 0, 0), rng)

	-- güney kumsalı: zincirli büyük çapa
	local an = findBeach(36, 150, 215)
	if an then
		clearDecor(an.X, an.Z, 8)
		Land.paintDisc(an.X, an.Z, 11, Enum.Material.Sand)
		Land.paintDisc(an.X, an.Z, 11, Enum.Material.Sand, Enum.Material.LeafyGrass)
		Props.anchor(f, CFrame.new(an.X, an.Y - 0.35, an.Z) * CFrame.Angles(0, math.rad(30), 0) * CFrame.Angles(0, 0, math.rad(6)), rng)
	end

	-- güneybatı kumsalı: karaya vurmuş eski sandal (yan yatık, yarı kuma gömülü)
	local tpl = ServerStorage:FindFirstChild("BoatTemplates")
	local rowT = tpl and tpl:FindFirstChild("Rowboat")
	if rowT then
		local b = rowT:Clone()
		b.Name = "BeachedRowboat"
		for _, d in b:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = true
			end
		end
		local bp = findBeach(-70, 160, 215) or v3(-70, 2, 182)
		local bgy = bp.Y
		clearDecor(bp.X, bp.Z, 12)
		Land.paintDisc(bp.X, bp.Z, 13, Enum.Material.Sand)
		Land.paintDisc(bp.X, bp.Z, 13, Enum.Material.Sand, Enum.Material.LeafyGrass)
		b:PivotTo(CFrame.new(bp.X, bgy + 0.4, bp.Z) * CFrame.Angles(0, math.rad(-35), 0) * CFrame.Angles(0, 0, math.rad(24)))
		b.Parent = f
		Props.oar(f, CFrame.new(bp.X + 5, bgy + 0.25, bp.Z + 2) * CFrame.Angles(0, math.rad(70), 0) * CFrame.Angles(0, 0, math.rad(8)), 7)
	end
	return f
end

------------------------------------------------------------------------------------------
-- 5) Kayıkhane (Boat Shop): iskele girişinde yarı açık, duvarda dümen/can simidi/kürek
------------------------------------------------------------------------------------------
function IslandLife.BoatHouse(cfg)
	local m = Util.fresh("Model", "BoatHouse")
	local rng = Random.new(cfg.Seed + 760)
	local g = cfg.GrassY
	local cx, cz = cfg.Pier.startX - 22, cfg.Pier.walkZ - 21 -- yolun kuzeyinde, açık yüzü yola (güneye) bakar
	local W, D, H = 30, 20, 11
	clearDecor(cx, cz, 24)
	Land.paintRect(cx, cz, W + 8, D + 8, Enum.Material.Ground)
	local y = g + 1
	Util.part(m, "Foundation", v3(W + 2, 1, D + 2), CFrame.new(cx, g + 0.5, cz), Color3.fromRGB(130, 126, 120), Enum.Material.Cobblestone)
	Util.part(m, "Floor", v3(W, 0.3, D), CFrame.new(cx, y + 0.15, cz), Color3.fromRGB(128, 96, 66), Enum.Material.WoodPlanks)
	-- arka ve yan duvarlar (kalas), ön açık
	local back = cz - D / 2
	for i = 0, math.floor(W / 1.6) - 1 do
		local x = cx - W / 2 + 0.8 + i * 1.6
		Util.part(m, "Wall", v3(1.55, H, 0.5), CFrame.new(x, y + H / 2, back), Props.oldWood(rng), Enum.Material.WoodPlanks)
	end
	for _, sx in { -1, 1 } do
		for i = 0, math.floor(D / 1.6) - 1 do
			local z = back + 0.8 + i * 1.6
			local h = (i > math.floor(D / 1.6) - 3) and 3.2 or H -- ön köşe yarı açık (alçak duvar)
			Util.part(m, "Wall", v3(0.5, h, 1.55), CFrame.new(cx + sx * W / 2, y + h / 2, z), Props.oldWood(rng), Enum.Material.WoodPlanks)
		end
		Util.part(m, "Post", v3(1.3, H + 0.5, 1.3), CFrame.new(cx + sx * W / 2, y + (H + 0.5) / 2, cz + D / 2), DARK, Enum.Material.Wood)
		Util.part(m, "Post", v3(1.3, H + 0.5, 1.3), CFrame.new(cx + sx * W / 2, y + (H + 0.5) / 2, back), DARK, Enum.Material.Wood)
	end
	Util.part(m, "FrontBeam", v3(W + 1.5, 1, 1.3), CFrame.new(cx, y + H, cz + D / 2), DARK, Enum.Material.Wood)
	-- çatı: tek eğim, öne 2 stud saçak + kirişler
	local rise = 5
	local len = math.sqrt((D + 4) ^ 2 + rise ^ 2)
	local ang = math.atan2(rise, D + 4)
	-- arka yüksek, ön alçak
	local roof = Util.part(m, "Roof", v3(W + 4, 0.7, len), CFrame.new(cx, y + H + rise / 2 + 0.4, cz) * CFrame.Angles(ang, 0, 0), Color3.fromRGB(96, 74, 54), Enum.Material.WoodPlanks)
	for x = cx - W / 2, cx + W / 2 + 0.1, W / 5 do
		Props.deco(Util.part(m, "Rafter", v3(0.6, 0.6, len), roof.CFrame * CFrame.new(x - cx, -0.6, 0), DARK, Enum.Material.Wood))
	end
	-- arka duvarda: dümen, can simitleri, çapraz kürekler
	Props.shipWheel(m, CFrame.new(cx, y + 5.2, back + 0.5) * CFrame.Angles(0, math.pi, 0), 2.2)
	for _, sx in { -10, 10 } do
		Props.lifeRing(m, CFrame.new(cx + sx, y + 5.5, back + 0.6) * CFrame.Angles(0, math.pi, 0), 1.3)
	end
	for _, sx in { -1, 1 } do
		local base = CFrame.new(cx + sx * 3.6, y + 6, back + 0.5)
		Props.oar(m, base * CFrame.Angles(0, 0, sx * math.rad(35)) * CFrame.Angles(math.rad(90), 0, 0), 7)
	end
	-- yan duvarlarda kürek + halat
	Props.oar(m, CFrame.new(cx - W / 2 + 0.5, y + 5, cz) * CFrame.Angles(math.rad(90), 0, math.rad(80)), 7)
	Props.coil(m, CFrame.new(cx + W / 2 - 2.5, y + 0.3, cz - 2), 1)
	local kx = cx - 8
	-- tezgahlarda yapımı süren kayık iskeleti (kaburgalar)
	for _, sz in { -2.5, 2.5 } do
		Util.part(m, "Trestle", v3(5, 2, 0.6), CFrame.new(kx, y + 1, cz + sz), DARK, Enum.Material.Wood)
	end
	Props.deco(Util.part(m, "Keel", v3(0.6, 0.6, 11), CFrame.new(kx, y + 2.3, cz), Props.WOOD, Enum.Material.Wood))
	for k = -2, 2 do
		for _, sx in { -1, 1 } do
			Props.deco(Util.part(m, "Rib", v3(0.4, 2.6, 0.4), CFrame.new(kx + sx * 1.4, y + 3.3, cz + k * 2.2) * CFrame.Angles(0, 0, sx * math.rad(30 - math.abs(k) * 4)), Props.WOOD, Enum.Material.Wood))
		end
	end
	Props.tackleBox(m, CFrame.new(cx - W / 2 + 2.5, y + 0.3, back + 2), Color3.fromRGB(170, 60, 50))
	Props.bucket(m, CFrame.new(cx + W / 2 - 3, y + 0.3, back + 2))
	Props.barrel(m, CFrame.new(cx + W / 2 - 2.6, y + 0.3, cz + 2.5), rng)
	-- tersane ustası NPC: sağ tarafta tezgâhın arkasında, açık yüze (yola) bakar
	local counterX, counterZ = cx + 6, cz - 1
	Util.part(m, "Counter", v3(9, 3.4, 2.6), CFrame.new(counterX, y + 1.7, counterZ + 0.0), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks)
	Util.part(m, "CounterTop", v3(9.6, 0.4, 3.2), CFrame.new(counterX, y + 3.6, counterZ), DARK, Enum.Material.Wood)
	Props.tackleBox(m, CFrame.new(counterX - 2.6, y + 3.8, counterZ), Color3.fromRGB(60, 100, 140))
	local tpl = ServerStorage:FindFirstChild("NPCTemplates")
	local npcT = tpl and tpl:FindFirstChild("BoatMerchant")
	if npcT then
		local npc = npcT:Clone()
		npc.Name = "BoatMerchant"
		local root = npc:FindFirstChild("HumanoidRootPart")
		for _, d in npc:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = d == root
				d.CanCollide = false
			elseif d:IsA("BillboardGui") and d.Parent and d.Parent.Name == "Head" then
				d:Destroy()
			end
		end
		local _, size = npc:GetBoundingBox()
		local at = v3(counterX, y + size.Y / 2 + 0.2, counterZ - 3.2)
		npc:PivotTo(CFrame.lookAt(at, at + v3(0, 0, 10)))
		local hum = npc:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		npc.Parent = m
		local head = npc:FindFirstChild("Head") or root
		if head then
			Util.billboard(head, "Shipwright Nils", 2.4, 200).MaxDistance = 40
		end
	end
	-- düğme tezgâhın önündeki görünmez noktada (NPC gövdesindeki düğme güvenilir görünmüyor)
	local promptHost = Util.part(m, "CounterPoint", v3(8, 3, 1), CFrame.new(counterX, y + 3, counterZ + 2))
	promptHost.Transparency = 1
	promptHost.CanCollide = false
	promptHost.CanTouch = false
	local sp = Instance.new("ProximityPrompt")
	sp.Name = "ShopPrompt"
	sp.ObjectText = "Shipwright Nils"
	sp.ActionText = "Browse Boats"
	sp.HoldDuration = 0
	sp.MaxActivationDistance = 14
	sp.RequiresLineOfSight = false
	sp.KeyboardKeyCode = Enum.KeyCode.E
	sp:SetAttribute("Kind", "Boats")
	sp.Parent = promptHost
	-- tabela
	local sign = Util.part(m, "Sign", v3(18, 2.8, 0.5), CFrame.new(cx, y + H + 1.9, cz + D / 2 + 0.6), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Props.deco(Util.part(m, "SignFrame", v3(18.8, 3.5, 0.3), sign.CFrame * CFrame.new(0, 0, -0.3), DARK, Enum.Material.Wood))
	Util.sign(sign, Enum.NormalId.Back, "BOAT SHOP", CREAM).LightInfluence = 0.2
	for _, sx in { -1, 1 } do
		Props.lantern(m, CFrame.new(cx + sx * 11.5, y + H - 1.3, cz + D / 2 + 0.8))
	end
	Util.light(Util.zone(m, "InsideLight", v3(1, 1, 1), CFrame.new(cx, y + H - 1, cz)), 0.8, 20)
	return m
end

------------------------------------------------------------------------------------------
-- 6) İskele kazıklarında yosun bandı + suda köpük halkası
------------------------------------------------------------------------------------------
function IslandLife.PilingFoam(cfg)
	local f = Util.fresh("Folder", "PilingFoam")
	local MOSS = Color3.fromRGB(70, 104, 56)
	local n = 0
	for _, root in { Workspace:FindFirstChild("Pier"), Workspace:FindFirstChild("FishMarket") } do
		for _, d in root and root:GetDescendants() or {} do
			if d:IsA("BasePart") and d.Name == "Piling" then
				local p = d.Position
				local dia = math.min(d.Size.Y, d.Size.Z)
				local bottom = p.Y - d.Size.X / 2
				if bottom < 0 then
					Props.deco(Util.pole(f, "Moss", p.X, p.Z, -0.8, 1.1, dia + 0.12, MOSS, Enum.Material.Grass), false)
					local foam = Props.deco(Util.cyl(f, "Foam", 0.12, dia + 2.2, CFrame.new(p.X, 0.12, p.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 248, 255), Enum.Material.SmoothPlastic), false)
					foam.Transparency = 0.45
					n += 1
				end
			end
		end
	end
	return n
end

------------------------------------------------------------------------------------------
-- 7) Işık: öğleden sonra güneşi (daha belirgin gölgeler), sıcak ufuk sisi, kıyıda daha şeffaf su
------------------------------------------------------------------------------------------
function IslandLife.Lighting()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 32
	Lighting.ShadowSoftness = 0.08
	Lighting.Brightness = 3.2
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Parent = Lighting
	atm.Density = 0.26
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(236, 222, 200)
	atm.Decay = Color3.fromRGB(150, 140, 128)
	atm.Glare = 0.35
	atm.Haze = 1.1
	Workspace.Terrain.WaterTransparency = 0.72
end

-- Hepsi (sırayla, aralarda bekleyerek)
function IslandLife.All(cfg)
	IslandLife.FishMarket(cfg)
	task.wait()
	IslandLife.Hills(cfg)
	task.wait()
	IslandLife.Ground(cfg)
	task.wait()
	IslandLife.BoatHouse(cfg)
	task.wait()
	IslandLife.Props(cfg)
	task.wait()
	IslandLife.PilingFoam(cfg)
	IslandLife.Lighting()
end

return IslandLife
