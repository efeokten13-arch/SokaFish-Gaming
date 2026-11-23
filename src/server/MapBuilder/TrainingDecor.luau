--!nonstrict
-- Eğitim körfezi (Gunnery Range) atmosferi. Atoll.Training'in sonunda çağrılır.
-- Kurulanlar (Workspace.Atoll.Training.Ambience):
--   arka kayalık duvar (açık kanalı kapatır) + kafatası oymalı, demir parmaklıklı gizemli mağara + şelale,
--   körfezin üstüne gerilmiş halatlar (flamalar, korsan bayrakları, fenerler, ağlar), kayalıklarda sarmaşık + yosun,
--   kıyı fenerleri, kale duvarında sancaklar, yarı batık hayalet gemi, kayıklar, yüzen fıçılar, sis ve ateş böcekleri.
-- Koordinatlar: s = kapıdan körfezin içine doğru, u = yana (sağ +). Bütün süsler gülleleri/gemileri engellemez.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = Workspace.Terrain
local Util = require(script.Parent.Util)

local D = {}

local ROCK, SLATE, BASALT, LEAFY, WATER, AIR =
	Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.LeafyGrass, Enum.Material.Water, Enum.Material.Air
local DARK = Color3.fromRGB(70, 48, 32)
local HULL = Color3.fromRGB(74, 52, 36)
local ROPE = Color3.fromRGB(150, 128, 92)
local NETC = Color3.fromRGB(112, 96, 70)
local IRON = Color3.fromRGB(52, 46, 42)
local BONE = Color3.fromRGB(222, 212, 188)
local WARM = Color3.fromRGB(255, 168, 80)
local GHOST = Color3.fromRGB(110, 255, 170)
local VINES = { Color3.fromRGB(58, 92, 46), Color3.fromRGB(76, 112, 52), Color3.fromRGB(44, 76, 42), Color3.fromRGB(90, 118, 60) }
local BUNTING = { Color3.fromRGB(26, 26, 30), Color3.fromRGB(150, 32, 32), Color3.fromRGB(220, 204, 168), Color3.fromRGB(58, 88, 92) }
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Terrain }
terrainOnly.IgnoreWater = true

-- süs parçası: çarpışmaz, ışın (gülle) geçer, gölge yapmaz
local function deco(p, shadow)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow == true
	return p
end
local function seq(t)
	local k = {}
	for _, v in t do
		table.insert(k, NumberSequenceKeypoint.new(v[1], v[2]))
	end
	return NumberSequence.new(k)
end
local function loopSound(parent, id, vol, minD, maxD)
	local s = Instance.new("Sound")
	s.Name = "Ambience"
	s.SoundId = id
	s.Volume = vol
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = minD
	s.RollOffMaxDistance = maxD
	s.Parent = parent
	s.Playing = true
	return s
end

function D.Build(f, frame, ctx)
	local Audio = require(ReplicatedStorage.Shared.Config.Audio:Clone())
	local rng = Random.new(4242)
	local root = Util.fresh("Folder", "Ambience", f)
	local sDir, uDir = frame.LookVector, frame.RightVector
	local function F(s, u, y)
		return frame * CFrame.new(u, y or 0, -s)
	end
	local function T(s, u, y)
		return F(s, u, y).Position
	end
	local function sub(name)
		local m = Instance.new("Folder")
		m.Name = name
		return m
	end

	-- ---------------------------------------------------------------- 1) Arka duvar: kanalı kapatan yüksek kayalık
	local WALL_S = 338
	for u = -290, 250, 17 do
		local top = 155 + 45 * math.sin(u / 55) + rng:NextNumber(0, 35)
		local y = -44
		while y < top do
			local r = 42 * (1 - 0.4 * math.max(y, 0) / top) + rng:NextNumber(-4, 4)
			local mat = y < 30 and BASALT or (y < 90 and ROCK or SLATE)
			Terrain:FillBall(T(WALL_S + r * 0.9 + rng:NextNumber(-3, 5), u + rng:NextNumber(-5, 5), y), r, mat)
			y += 26
		end
		Terrain:FillBall(T(WALL_S + 40, u, top), 26 + rng:NextNumber(0, 10), SLATE)
		if u % 51 == 0 then
			task.wait()
		end
	end
	-- duvarın arkası tamamen dolu (kanal görünmesin)
	Terrain:FillBlock(F(WALL_S + 95, -20, 40), Vector3.new(560, 170, 90), ROCK)
	task.wait()

	-- ---------------------------------------------------------------- 2) Gizemli mağara: kafatası oyması, demir parmaklık, yeşil ışıklı gözler
	do
		local m = sub("SkullCave")
		local cu, w, h = -30, 46, 30
		local cs = WALL_S - 4
		Terrain:FillBlock(F(cs + 22, cu, h / 2 + 1), Vector3.new(w, h, 56), AIR)
		Terrain:FillCylinder(F(cs + 22, cu, h) * CFrame.Angles(math.pi / 2, 0, 0), 56, w / 2, AIR)
		Terrain:FillBlock(F(cs + 22, cu, -7), Vector3.new(w + 4, 14, 56), WATER)
		-- mağaranın dibi: zifiri karanlık perde
		local back = Util.part(m, "Darkness", Vector3.new(w + 10, h + w / 2 + 12, 2), F(cs + 46, cu, (h + w / 2) / 2), Color3.fromRGB(6, 6, 8), Enum.Material.SmoothPlastic)
		deco(back)
		-- paslı parmaklık (gemiler giremez)
		for x = -w / 2 + 3, w / 2 - 3, 4 do
			local topY = h + math.sqrt(math.max((w / 2) ^ 2 - x * x, 0)) - 2
			local bar = Util.part(m, "PortcullisBar", Vector3.new(1, topY + 10, 1), F(cs + 6, cu + x, (topY - 10) / 2), IRON, Enum.Material.CorrodedMetal)
			bar.CanQuery = false
			Util.part(m, "Spike", Vector3.new(1.4, 2.4, 1.4), F(cs + 6, cu + x, -9) * CFrame.Angles(0, math.pi / 4, 0), IRON, Enum.Material.CorrodedMetal).CanQuery = false
		end
		for _, y in { 4, 16, 28, 40 } do
			local half = y <= h and w / 2 or math.sqrt(math.max((w / 2) ^ 2 - (y - h) ^ 2, 0))
			if half > 4 then
				local bar = Util.part(m, "PortcullisBeam", Vector3.new(half * 2 - 2, 1.4, 1.4), F(cs + 6, cu, y), IRON, Enum.Material.CorrodedMetal)
				bar.CanQuery = false
			end
		end
		-- kafatası: kemerin üstünde, körfeze bakar
		local K = F(cs - 3, cu, h + w / 2 + 20) * CFrame.Angles(0, math.pi, 0)
		for _, sgn in { -1, 1 } do
			local bone = Util.cyl(m, "CrossBone", 54, 5, K * CFrame.new(0, -6, 6) * CFrame.Angles(0, 0, sgn * 0.62), BONE, Enum.Material.Slate)
			for _, e in { -27, 27 } do
				Util.ball(m, "BoneKnob", Vector3.new(8, 8, 8), bone.CFrame * CFrame.new(e, 0, 2.6), BONE, Enum.Material.Slate)
				Util.ball(m, "BoneKnob", Vector3.new(8, 8, 8), bone.CFrame * CFrame.new(e, 0, -2.6), BONE, Enum.Material.Slate)
			end
		end
		Util.ball(m, "Skull", Vector3.new(30, 27, 24), K, BONE, Enum.Material.Slate)
		Util.part(m, "Jaw", Vector3.new(19, 8, 15), K * CFrame.new(0, -14, -3), BONE, Enum.Material.Slate)
		for i = -2.5, 2.5 do
			Util.part(m, "Tooth", Vector3.new(2.2, 3.4, 1.2), K * CFrame.new(i * 3, -10.5, -10.6), Color3.fromRGB(240, 232, 210), Enum.Material.SmoothPlastic)
		end
		Util.ball(m, "Nose", Vector3.new(4, 5.5, 3), K * CFrame.new(0, -4, -11), Color3.fromRGB(20, 18, 18), Enum.Material.SmoothPlastic)
		for _, sx in { -7, 7 } do
			Util.ball(m, "EyeSocket", Vector3.new(8.5, 9, 4), K * CFrame.new(sx, 3, -10), Color3.fromRGB(14, 12, 12), Enum.Material.SmoothPlastic)
			local eye = Util.ball(m, "EyeGlow", Vector3.new(2.6, 2.6, 2.6), K * CFrame.new(sx, 3, -11.6), GHOST, Enum.Material.Neon)
			Util.light(eye, 2, 30, GHOST)
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "PortcullisBar" and d.Name ~= "PortcullisBeam" and d.Name ~= "Spike" then
				deco(d)
			end
		end
		-- iki yanında kaya çıkıntısı + meşale
		for _, sg in { -1, 1 } do
			local su = cu + sg * (w / 2 + 9)
			Terrain:FillBall(T(cs - 4, su, -6), 10, BASALT)
			ctx.torch(m, T(cs - 7, su, 3))
		end
		-- mağaradan dışarı süzülen sis + uğultu
		local mist = deco(Util.part(m, "CaveMist", Vector3.new(w - 6, 10, 4), F(cs + 12, cu, 6) * CFrame.Angles(0, math.pi, 0)))
		mist.Transparency = 1
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SMOKE
		pe.EmissionDirection = Enum.NormalId.Front
		pe.Color = ColorSequence.new(Color3.fromRGB(150, 170, 165))
		pe.Size = seq({ { 0, 8 }, { 1, 26 } })
		pe.Transparency = seq({ { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } })
		pe.Lifetime = NumberRange.new(8, 12)
		pe.Rate = 2.5
		pe.Speed = NumberRange.new(2, 5)
		pe.SpreadAngle = Vector2.new(25, 10)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-8, 8)
		pe.Parent = mist
		loopSound(back, Audio.BayCave, 0.7, 30, 320)
		m.Parent = root
	end
	task.wait()

	-- ---------------------------------------------------------------- 3) Şelale (sağ tarafta, duvardan suya)
	do
		local m = sub("Waterfall")
		local wu = 92
		local hitTop = Workspace:Raycast(T(WALL_S - 60, wu, 150), sDir * 160, terrainOnly)
		local hitBot = Workspace:Raycast(T(WALL_S - 60, wu, 6), sDir * 160, terrainOnly)
		local pTop = (hitTop and hitTop.Position or T(WALL_S, wu, 150)) - sDir * 2
		local pBot = (hitBot and hitBot.Position or T(WALL_S, wu, 0)) - sDir * 12
		pBot = Vector3.new(pBot.X, 0, pBot.Z)
		-- tepedeki taşma ağzı
		Terrain:FillBall(pTop + sDir * 6 + Vector3.new(0, 4, 0), 12, BASALT)
		for i, wd in { 26, 18, 10 } do
			local sheet = Util.beam(m, "Fall", pTop - sDir * (i - 1) * 0.6, pBot - sDir * (i - 1) * 0.6, wd, 1.6, Color3.fromRGB(196 + i * 12, 232, 244), Enum.Material.Glass)
			sheet.Transparency = 0.25 + i * 0.12
			deco(sheet)
		end
		for k = -2, 2 do
			local streak = Util.beam(m, "Streak", pTop + uDir * k * 4.5 - sDir * 1.4, pBot + uDir * k * 4.5 - sDir * 1.4, 1, 0.3, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
			streak.Transparency = 0.55
			deco(streak)
		end
		local lip = deco(Util.part(m, "Lip", Vector3.new(24, 1, 3), CFrame.lookAt(pTop - sDir * 3, pTop - sDir * 3 - sDir) * CFrame.new(0, 0, 0)))
		lip.Transparency = 1
		local drops = Instance.new("ParticleEmitter")
		drops.Texture = SMOKE
		drops.EmissionDirection = Enum.NormalId.Bottom
		drops.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
		drops.Size = seq({ { 0, 4 }, { 1, 10 } })
		drops.Transparency = seq({ { 0, 0.55 }, { 1, 1 } })
		drops.Lifetime = NumberRange.new(1.9, 2.2)
		drops.Rate = 30
		drops.Speed = NumberRange.new(20, 28)
		drops.Acceleration = Vector3.new(0, -32, 0)
		drops.SpreadAngle = Vector2.new(6, 6)
		drops.Parent = lip
		local foamCF = CFrame.new(pBot + Vector3.new(0, 0.4, 0))
		local foam = deco(Util.cyl(m, "Foam", 0.6, 36, foamCF * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(236, 248, 252), Enum.Material.SmoothPlastic))
		foam.Transparency = 0.35
		local mist = deco(Util.part(m, "SplashMist", Vector3.new(26, 1, 26), foamCF))
		mist.Transparency = 1
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SMOKE
		pe.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
		pe.Size = seq({ { 0, 10 }, { 1, 32 } })
		pe.Transparency = seq({ { 0, 0.5 }, { 1, 1 } })
		pe.Lifetime = NumberRange.new(3, 5)
		pe.Rate = 14
		pe.Speed = NumberRange.new(5, 12)
		pe.SpreadAngle = Vector2.new(70, 70)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-15, 15)
		pe.Parent = mist
		loopSound(mist, Audio.BayWaterfall, 0.9, 40, 420)
		for i = 1, 5 do
			Terrain:FillBall(pBot + uDir * rng:NextNumber(-22, 22) + sDir * rng:NextNumber(2, 10) + Vector3.new(0, -3, 0), rng:NextNumber(4, 7), BASALT)
		end
		m.Parent = root
	end
	task.wait()

	-- ---------------------------------------------------------------- 4) Sarmaşık yardımcısı
	local vines = sub("Vines")
	local function vine(start, len, outward, parent)
		parent = parent or vines
		local p = start
		local d = 0
		local side = outward and outward:Cross(Vector3.yAxis) or Vector3.zero
		local thick = rng:NextNumber(0.32, 0.55)
		local col = VINES[rng:NextInteger(1, #VINES)]
		local n = 0
		while d < len do
			local step = math.min(5, len - d)
			local q = p + Vector3.new(0, -step, 0) + (outward or Vector3.zero) * rng:NextNumber(-0.2, 0.5) + side * rng:NextNumber(-0.6, 0.6)
			deco(Util.rod(parent, "Vine", p, q, thick, col, Enum.Material.Grass))
			n += 1
			if n % 2 == 0 then
				local leaf = Util.ball(parent, "Leaf", Vector3.new(1.5, 0.9, 1.2) * rng:NextNumber(0.7, 1.2), CFrame.new(q) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.3), rng:NextNumber(-0.5, 0.5)), VINES[rng:NextInteger(1, #VINES)], Enum.Material.Grass)
				deco(leaf)
			end
			p = q
			d += step
			thick *= 0.93
		end
	end

	-- ---------------------------------------------------------------- 5) Kayalıklara yosun + sarkan sarmaşıklar
	do
		local okMat = {
			[ROCK] = true, [SLATE] = true, [BASALT] = true, [Enum.Material.Ground] = true, [Enum.Material.Grass] = true,
			[LEAFY] = true, [Enum.Material.Mud] = true, [Enum.Material.Limestone] = true, [Enum.Material.Cobblestone] = true,
		}
		local function tryAt(origin, dir)
			local hit = Workspace:Raycast(origin, dir, terrainOnly)
			if not hit or not okMat[hit.Material] or math.abs(hit.Normal.Y) > 0.8 or hit.Position.Y < 8 then
				return
			end
			-- platformların ve kapının hemen üstüne sarkmasın
			local lp = frame:PointToObjectSpace(hit.Position)
			local s, u = -lp.Z, lp.X
			if s < 12 or (s > 168 and s < 242 and math.abs(u) > 110 and hit.Position.Y < 40) then
				return
			end
			local out = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			out = out.Magnitude > 0.05 and out.Unit or -dir.Unit
			if rng:NextNumber() < 0.7 then
				Terrain:FillBall(hit.Position - hit.Normal * 2.5, rng:NextNumber(5, 10), LEAFY)
			end
			local strands = rng:NextInteger(1, 2)
			for _ = 1, strands do
				local st = hit.Position + out * 1.6 + out:Cross(Vector3.yAxis) * rng:NextNumber(-4, 4) + Vector3.new(0, rng:NextNumber(-2, 2), 0)
				vine(st, math.min(rng:NextNumber(12, 42), st.Y - 3), out)
			end
		end
		local count = 0
		for s = 25, 330, 11 do
			local uc = s > 290 and -25 or 0
			for _, side in { -1, 1 } do
				for _ = 1, 3 do
					local y = rng:NextNumber(14, 125)
					local dir = (uDir * side + sDir * rng:NextNumber(-0.45, 0.45)).Unit * 420
					tryAt(T(s, uc, y), dir)
					count += 1
				end
			end
			if count % 30 == 0 then
				task.wait()
			end
		end
		-- arka duvarın yüzü
		for _ = 1, 40 do
			tryAt(T(WALL_S - 70, rng:NextNumber(-230, 200), rng:NextNumber(12, 140)), (sDir + uDir * rng:NextNumber(-0.3, 0.3)).Unit * 200)
		end
		vines.Parent = root
	end
	task.wait()

	-- ---------------------------------------------------------------- 6) Körfezin üstüne gerilmiş halatlar: flamalar, bayraklar, fenerler, ağlar
	do
		local m = sub("RopeLines")
		local function lantern(parent, top, chain)
			local bottom = top - Vector3.new(0, chain, 0)
			deco(Util.rod(parent, "LanternChain", top, bottom, 0.25, IRON, Enum.Material.Metal))
			deco(Util.part(parent, "LanternCap", Vector3.new(2.2, 0.6, 2.2), CFrame.new(bottom - Vector3.new(0, 0.3, 0)), IRON, Enum.Material.Metal))
			local glass = deco(Util.part(parent, "LanternGlass", Vector3.new(1.7, 2.2, 1.7), CFrame.new(bottom - Vector3.new(0, 1.7, 0)), Color3.fromRGB(255, 196, 110), Enum.Material.Neon))
			glass.Transparency = 0.15
			deco(Util.part(parent, "LanternBase", Vector3.new(2.2, 0.5, 2.2), CFrame.new(bottom - Vector3.new(0, 3, 0)), IRON, Enum.Material.Metal))
			Util.light(glass, 2.2, 36, WARM)
		end
		local function skullFlag(parent, cf, size)
			local fl = deco(Util.part(parent, "PirateFlag", size, cf, Color3.fromRGB(22, 22, 26), Enum.Material.Fabric))
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local g = Instance.new("SurfaceGui")
				g.Face = face
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 30
				g.LightInfluence = 1
				g.Parent = fl
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Text = "☠"
				t.TextScaled = true
				t.TextColor3 = Color3.fromRGB(236, 230, 214)
				t.Parent = g
			end
			return fl
		end
		local function net(parent, pts)
			-- pts: halat üzerindeki noktalar; her birinden aşağı sarkan ip + yatay bağlar
			local cols = {}
			for i, p in pts do
				local depth = 10 + math.sin(i / #pts * math.pi) * 6
				local col = {}
				for k = 0, 4 do
					table.insert(col, p - Vector3.new(0, depth * k / 4, 0) + Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)) * k)
				end
				cols[i] = col
				for k = 1, 4 do
					deco(Util.rod(parent, "Net", col[k], col[k + 1], 0.22, NETC, Enum.Material.Fabric))
				end
			end
			for i = 1, #cols - 1 do
				for k = 2, 5 do
					deco(Util.rod(parent, "Net", cols[i][k], cols[i + 1][k], 0.22, NETC, Enum.Material.Fabric))
				end
			end
		end
		local lines = {
			{ s = 70, y = 78, sag = 0.06, net = false, lanterns = { 0.5 } },
			{ s = 150, y = 88, sag = 0.07, net = true, lanterns = { 0.3, 0.7 } },
			{ s = 238, y = 96, sag = 0.06, net = true, lanterns = { 0.5 } },
			{ s = 312, y = 84, sag = 0.08, net = false, lanterns = { 0.35, 0.65 } },
		}
		for li, L in lines do
			local uc = L.s > 290 and -25 or 0
			local a = Workspace:Raycast(T(L.s, uc, L.y), -uDir * 460, terrainOnly)
			local b = Workspace:Raycast(T(L.s, uc, L.y), uDir * 460, terrainOnly)
			if a and b then
				local pa, pb = a.Position + a.Normal * 0.5, b.Position + b.Normal * 0.5
				local len = (pb - pa).Magnitude
				local sag = len * L.sag
				local function at(t, extra)
					return pa:Lerp(pb, t) - Vector3.new(0, (sag + (extra or 0)) * 4 * t * (1 - t), 0)
				end
				local N = math.clamp(math.floor(len / 8), 10, 40)
				for i = 0, N - 1 do
					deco(Util.rod(m, "Rope", at(i / N), at((i + 1) / N), 0.7, ROPE, Enum.Material.Fabric))
				end
				-- ikinci, daha sarkık ince halat (fotoğraftaki gibi çift hat)
				if li % 2 == 0 then
					local pa2, pb2 = pa - Vector3.new(0, 5, 0), pb - Vector3.new(0, 5, 0)
					for i = 0, N - 1 do
						local t0, t1 = i / N, (i + 1) / N
						local q0 = pa2:Lerp(pb2, t0) - Vector3.new(0, sag * 1.5 * 4 * t0 * (1 - t0), 0)
						local q1 = pa2:Lerp(pb2, t1) - Vector3.new(0, sag * 1.5 * 4 * t1 * (1 - t1), 0)
						deco(Util.rod(m, "Rope", q0, q1, 0.45, ROPE, Enum.Material.Fabric))
					end
				end
				-- uçlarda kayaya çakılı demir halka
				for _, h in { a, b } do
					deco(Util.cyl(m, "Anchor", 4, 1.6, CFrame.lookAt(h.Position, h.Position + h.Normal) * CFrame.Angles(0, math.pi / 2, 0), IRON, Enum.Material.CorrodedMetal))
				end
				local dir = (pb - pa).Unit
				local flat = Vector3.new(dir.X, 0, dir.Z).Unit
				-- flamalar
				local nb = math.floor(len / 7)
				for i = 1, nb - 1 do
					local t = i / nb
					local p = at(t)
					local cf = CFrame.fromMatrix(p - Vector3.new(0, 2.3, 0), flat, Vector3.yAxis) * CFrame.Angles(0, 0, math.rad(45 + rng:NextNumber(-8, 8)))
					local pen = deco(Util.part(m, "Pennant", Vector3.new(2.9, 2.9, 0.12), cf, BUNTING[(i % #BUNTING) + 1], Enum.Material.Fabric))
					pen.Transparency = 0.05
				end
				-- büyük korsan bayrakları
				for _, t in { 0.22, 0.78 } do
					local p = at(t)
					skullFlag(m, CFrame.fromMatrix(p - Vector3.new(0, 4.6, 0), flat, Vector3.yAxis) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4))), Vector3.new(10, 8, 0.2))
				end
				for _, t in L.lanterns do
					lantern(m, at(t), 4)
				end
				-- halattan sarkan sarmaşıklar
				for t = 0.08, 0.92, 0.07 do
					if rng:NextNumber() < 0.45 then
						vine(at(t + rng:NextNumber(-0.02, 0.02)), rng:NextNumber(4, 14), nil, m)
					end
				end
				if L.net then
					local pts = {}
					local t0 = li == 2 and 0.1 or 0.62
					for k = 0, 6 do
						table.insert(pts, at(t0 + k * 0.035))
					end
					net(m, pts)
				end
			end
		end
		m.Parent = root
	end
	task.wait()

	-- ---------------------------------------------------------------- 7) Kıyı boyunca suya çakılı fener direkleri
	do
		local m = sub("ShoreLanterns")
		for s = 30, 320, 26 do
			local uc = s > 290 and -25 or 0
			for _, side in { -1, 1 } do
				local hit = Workspace:Raycast(T(s, uc, 2), uDir * side * 420, terrainOnly)
				if hit then
					local lp = frame:PointToObjectSpace(hit.Position)
					local hs, hu = -lp.Z, lp.X
					local nearDeck = hs > 160 and hs < 250 and math.abs(hu) > 100
					local nearFall = hs > 300 and hu > 40
					if not nearDeck and not nearFall then
						local p = hit.Position - uDir * side * 6
						local post = Util.pole(m, "Post", p.X, p.Z, -10, 9, 1.3, DARK, Enum.Material.Wood)
						deco(post, true)
						deco(Util.cyl(m, "Arm", 3.4, 0.5, CFrame.new(p.X, 8.4, p.Z) * CFrame.new(-uDir * side * 1.6) * CFrame.lookAt(Vector3.zero, uDir) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.Wood))
						local hook = Vector3.new(p.X, 8.4, p.Z) - uDir * side * 3
						local bottom = hook - Vector3.new(0, 1.2, 0)
						deco(Util.rod(m, "LanternChain", hook, bottom, 0.2, IRON, Enum.Material.Metal))
						local glass = deco(Util.part(m, "LanternGlass", Vector3.new(1.5, 2, 1.5), CFrame.new(bottom - Vector3.new(0, 1.2, 0)), Color3.fromRGB(255, 196, 110), Enum.Material.Neon))
						deco(Util.part(m, "LanternCap", Vector3.new(2, 0.5, 2), CFrame.new(bottom - Vector3.new(0, 0.1, 0)), IRON, Enum.Material.Metal))
						Util.light(glass, 1.8, 28, WARM)
					end
				end
			end
		end
		m.Parent = root
	end
	task.wait()

	-- ---------------------------------------------------------------- 8) Kale duvarının iç yüzünde korsan sancakları
	do
		local m = sub("WallBanners")
		local pr = RaycastParams.new()
		pr.FilterType = Enum.RaycastFilterType.Exclude
		pr.FilterDescendantsInstances = { f }
		pr.IgnoreWater = true
		for _, u in { -150, -105, 105, 150 } do
			local hit = Workspace:Raycast(T(40, u, 36), -sDir * 70, pr)
			if hit and not hit.Instance:IsA("Terrain") then
				local pos = hit.Position + hit.Normal * 0.4
				local cf = CFrame.lookAt(pos, pos + hit.Normal)
				local b = deco(Util.part(m, "Banner", Vector3.new(11, 26, 0.3), cf, Color3.fromRGB(24, 24, 28), Enum.Material.Fabric))
				deco(Util.part(m, "BannerStripe", Vector3.new(11, 2.2, 0.34), cf * CFrame.new(0, -11, 0), Color3.fromRGB(140, 28, 28), Enum.Material.Fabric))
				deco(Util.cyl(m, "BannerRod", 13, 0.7, cf * CFrame.new(0, 13.2, -0.2), IRON, Enum.Material.Metal))
				local g = Instance.new("SurfaceGui")
				g.Face = Enum.NormalId.Front
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				g.PixelsPerStud = 25
				g.LightInfluence = 1
				g.Parent = b
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 0.5)
				t.Position = UDim2.fromScale(0, 0.15)
				t.BackgroundTransparency = 1
				t.Text = "☠"
				t.TextScaled = true
				t.TextColor3 = Color3.fromRGB(236, 230, 214)
				t.Parent = g
			end
		end
		m.Parent = root
	end

	-- ---------------------------------------------------------------- 9) Yarı batık hayalet gemi (arka sol köşe)
	do
		local m = Instance.new("Model")
		m.Name = "GhostWreck"
		local K = F(300, -112, -4) * CFrame.Angles(0, 0.85, 0) * CFrame.Angles(math.rad(-9), 0, math.rad(17))
		Util.ball(m, "Hull", Vector3.new(22, 15, 74), K, HULL, Enum.Material.WoodPlanks)
		Util.ball(m, "HullInner", Vector3.new(18, 10, 66), K * CFrame.new(0, 4.4, 0), Color3.fromRGB(40, 28, 20), Enum.Material.WoodPlanks)
		Util.part(m, "Deck", Vector3.new(17, 0.8, 50), K * CFrame.new(0, 5.6, 2), Color3.fromRGB(92, 66, 44), Enum.Material.WoodPlanks)
		Util.part(m, "SternCastle", Vector3.new(18, 10, 14), K * CFrame.new(0, 10, 28), HULL, Enum.Material.WoodPlanks)
		Util.part(m, "SternRoof", Vector3.new(19, 1, 15), K * CFrame.new(0, 15.4, 28), DARK, Enum.Material.Wood)
		for _, sx in { -9.6, 9.6 } do
			for z = -22, 20, 6 do
				if rng:NextNumber() < 0.7 then
					Util.part(m, "Rail", Vector3.new(0.8, 3, 0.8), K * CFrame.new(sx, 7.6, z), DARK, Enum.Material.Wood)
				end
			end
		end
		Util.ball(m, "Breach", Vector3.new(1, 7, 9), K * CFrame.new(-10.8, 1, -8), Color3.fromRGB(10, 8, 6), Enum.Material.SmoothPlastic)
		Util.cyl(m, "Bowsprit", 22, 1.6, K * CFrame.new(0, 8, -40) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(20)), DARK, Enum.Material.Wood)
		local mast = Util.cyl(m, "MainMast", 48, 2.2, K * CFrame.new(0, 29, 4) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood)
		Util.cyl(m, "Yard", 24, 1, mast.CFrame * CFrame.new(16, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.Wood)
		Util.cyl(m, "CrowsNest", 2.5, 6, mast.CFrame * CFrame.new(21, 0, 0), DARK, Enum.Material.Wood)
		Util.cyl(m, "BrokenMast", 15, 1.8, K * CFrame.new(0, 12, -20) * CFrame.Angles(0, 0, math.pi / 2 + 0.35), DARK, Enum.Material.Wood)
		local sails = {
			{ Vector3.new(20, 14, 0.2), K * CFrame.new(0, 37, 4.6) * CFrame.Angles(math.rad(6), 0, math.rad(4)) },
			{ Vector3.new(9, 8, 0.2), K * CFrame.new(5, 26, 4.8) * CFrame.Angles(0, 0, math.rad(-18)) },
			{ Vector3.new(6, 10, 0.2), K * CFrame.new(-6, 25, 4.7) * CFrame.Angles(0, 0, math.rad(12)) },
		}
		for _, sp in sails do
			local sl = Util.part(m, "TornSail", sp[1], sp[2], Color3.fromRGB(176, 166, 138), Enum.Material.Fabric)
			sl.Transparency = 0.18
			deco(sl)
		end
		local top = (mast.CFrame * CFrame.new(23, 0, 0)).Position
		for _, d in { { -10, -20 }, { 10, -20 }, { -10, 22 }, { 10, 22 } } do
			deco(Util.rod(m, "Rigging", top, (K * CFrame.new(d[1], 6, d[2])).Position, 0.3, ROPE, Enum.Material.Fabric))
		end
		local fl = deco(Util.part(m, "TornFlag", Vector3.new(0.2, 4.5, 7), CFrame.new(top + Vector3.new(0, 1, 0)) * CFrame.new(0, 0, 3.6), Color3.fromRGB(22, 22, 26), Enum.Material.Fabric))
		fl.Transparency = 0.1
		local lamp = deco(Util.ball(m, "GhostLamp", Vector3.new(2.4, 2.4, 2.4), K * CFrame.new(0, 17.5, 33), GHOST, Enum.Material.Neon))
		Util.light(lamp, 1.6, 44, GHOST)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
				if d.Name ~= "Hull" and d.Name ~= "Deck" and d.Name ~= "SternCastle" then
					deco(d)
				end
			end
		end
		m.Parent = root
	end
	task.wait()

	-- ---------------------------------------------------------------- 10) Kayıklar + yüzen fıçılar
	do
		local m = sub("Flotsam")
		for _, spec in { { 252, -132, 0.4 }, { 162, 130, -0.6 }, { 95, -128, 1.2 } } do
			local K = F(spec[1], spec[2], 0.2) * CFrame.Angles(0, spec[3], 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6)))
			deco(Util.ball(m, "RowboatHull", Vector3.new(5.6, 2.8, 14), K, Color3.fromRGB(116, 80, 52), Enum.Material.WoodPlanks), true)
			deco(Util.ball(m, "RowboatInside", Vector3.new(4.6, 1.6, 12.4), K * CFrame.new(0, 0.85, 0), Color3.fromRGB(64, 44, 30), Enum.Material.WoodPlanks))
			for _, z in { -2.6, 2.4 } do
				deco(Util.part(m, "Seat", Vector3.new(4.6, 0.4, 1.3), K * CFrame.new(0, 1.2, z), DARK, Enum.Material.Wood))
			end
			for _, sx in { -1, 1 } do
				deco(Util.rod(m, "Oar", (K * CFrame.new(sx * 1.8, 1.6, 0)).Position, (K * CFrame.new(sx * 6.5, -0.2, 3)).Position, 0.4, DARK, Enum.Material.Wood))
			end
		end
		for _ = 1, 9 do
			local s = rng:NextNumber(40, 300)
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local hit = Workspace:Raycast(T(s, s > 290 and -25 or 0, 2), uDir * side * 420, terrainOnly)
			if hit then
				local p = hit.Position - uDir * side * rng:NextNumber(10, 20)
				local lp = frame:PointToObjectSpace(p)
				if not (-lp.Z > 160 and -lp.Z < 250 and math.abs(lp.X) > 100) then
					local cf = CFrame.new(p.X, 0.3, p.Z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4) + math.pi / 2, rng:NextNumber(0, 6), 0)
					deco(Util.cyl(m, "FloatingBarrel", 4, 3, cf, Color3.fromRGB(110, 76, 48), Enum.Material.Wood))
					for _, k in { -1.2, 1.2 } do
						deco(Util.cyl(m, "Hoop", 0.35, 3.15, cf * CFrame.new(k, 0, 0), IRON, Enum.Material.Metal))
					end
				end
			end
		end
		m.Parent = root
	end

	-- ---------------------------------------------------------------- 11) Su üstünde sis + ateş böcekleri
	do
		local m = sub("Fog")
		local spots = {
			{ 60, -80 }, { 60, 60 }, { 140, -100 }, { 140, 10 }, { 140, 110 },
			{ 225, -60 }, { 225, 50 }, { 290, -90 }, { 300, 20 }, { 318, 80 },
		}
		for _, sp in spots do
			local p = deco(Util.part(m, "FogBank", Vector3.new(70, 1, 70), F(sp[1], sp[2], 3)))
			p.Transparency = 1
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = SMOKE
			pe.Color = ColorSequence.new(Color3.fromRGB(206, 216, 218))
			pe.Size = seq({ { 0, 18 }, { 0.5, 34 }, { 1, 44 } })
			pe.Transparency = seq({ { 0, 1 }, { 0.25, 0.8 }, { 0.75, 0.84 }, { 1, 1 } })
			pe.Lifetime = NumberRange.new(14, 20)
			pe.Rate = 0.9
			pe.Speed = NumberRange.new(0.6, 2)
			pe.SpreadAngle = Vector2.new(85, 85)
			pe.Drag = 0.3
			pe.Rotation = NumberRange.new(0, 360)
			pe.RotSpeed = NumberRange.new(-5, 5)
			pe.Parent = p
		end
		for _, sp in { { 205, -185, Vector3.new(80, 22, 70) }, { 205, 185, Vector3.new(80, 22, 70) }, { 320, -30, Vector3.new(130, 30, 30) }, { 90, 0, Vector3.new(160, 30, 60) } } do
			local p = deco(Util.part(m, "Fireflies", sp[3], F(sp[1], sp[2], 14)))
			p.Transparency = 1
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = SPARK
			pe.Shape = Enum.ParticleEmitterShape.Box
			pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			pe.Color = ColorSequence.new(Color3.fromRGB(255, 226, 120))
			pe.LightEmission = 1
			pe.Brightness = 3
			pe.Size = seq({ { 0, 0.45 }, { 1, 0.45 } })
			pe.Transparency = seq({ { 0, 1 }, { 0.2, 0 }, { 0.8, 0.1 }, { 1, 1 } })
			pe.Lifetime = NumberRange.new(4, 7)
			pe.Rate = 7
			pe.Speed = NumberRange.new(0.4, 1.4)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Parent = p
		end
		m.Parent = root
	end
end

return D
