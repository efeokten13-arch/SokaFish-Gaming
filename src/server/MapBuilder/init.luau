--!nonstrict
-- MapBuilder: haritayı Config/Map.luau'daki ölçülerden kurar.
-- Studio'da (Edit modu) command bar'dan, aşamaları tek tek çalıştırın:
--   local B = require(game.ServerScriptService.Server.MapBuilder)
--   B.Sea() ; B.Land() ; B.Structures() ; B.Islands() ; B.Kayak() ; B.Decor() ; B.Environment()
-- Hepsi için: B.All()   (Önce boş bir place'te deneyin; her aşama eskisini silip yeniden kurar.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = {}

local function cfg()
	-- Clone: Map.luau'yu değiştirince eski önbellek kullanılmasın
	return require(ReplicatedStorage.Shared.Config.Map:Clone())
end

function Builder.Cfg()
	return cfg()
end

function Builder.Sea()
	require(script.Land).sea(cfg())
end

function Builder.Land()
	local c = cfg()
	local Land = require(script.Land)
	Land.islands(c)
	Land.rocks(c)
end

-- 2. ada: Ancient Coral Atoll (ana denizden uzakta, ortak balık bölgesi)
function Builder.Atoll(stage)
	require(script.Atoll).Build(stage)
end

-- Ana adayı yeni kıyı çizgisine göre baştan kur (arazi + yapılar + bitkiler)
function Builder.RebuildMainIsland()
	local c = cfg()
	require(script.Land).rebuildMain(c)
	Builder.Structures()
	Builder.Environment()
	require(script.Nature).Vegetation(c)
end

-- Ana ada: plaza, Fish Market, tekne dükkanı, iskele, kulübeler
function Builder.Structures()
	local c = cfg()
	local S = require(script.Structures)
	S.Plaza(c)
	S.Hall(c)
	S.Pier(c)
	S.Props(c)
	S.Fisherman(c)
	Builder.RodShop()
end

-- Ana adadaki olta dükkânı (eski kulübelerden birinin yerine)
function Builder.RodShop()
	return require(script.RodShop).Build(cfg())
end

-- Var olan adalara Spawn (ışınlanma noktası + sahip yazısı) ekle
function Builder.AddIslandSpawns()
	require(script.Islands).AddSpawns(cfg())
end

-- Adalardaki kulübelere koleksiyon kitabı ekle (adaları yeniden kurmadan)
function Builder.IslandBooks()
	require(script.Islands).AddBooks(cfg())
end

-- Adalara toprak patikalar ekle (adaları yeniden kurmadan)
function Builder.IslandPaths()
	require(script.Islands).AddPaths(cfg())
end

-- Işık, atmosfer, su ve arazi renkleri ("stylized realism": canlı ama doğal)
function Builder.Environment()
	local Lighting = game:GetService("Lighting")
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(96, 100, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 134, 148)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.2
	Lighting.ExposureCompensation = 0.1
	Lighting.FogEnd = 100000
	-- fazla Sky nesnelerini temizle (birden fazlası çakışıyor)
	local seen = false
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") then
			if seen then
				c:Destroy()
			end
			seen = true
		end
	end
	local function effect(class, name)
		local e = Lighting:FindFirstChild(name) or Instance.new(class)
		e.Name = name
		e.Parent = Lighting
		return e
	end
	-- hafif atmosfer: uzak adalar görünür kalsın, ufuk yumuşasın
	local atm = effect("Atmosphere", "Atmosphere")
	atm.Density = 0.22
	atm.Offset = 0.12
	atm.Color = Color3.fromRGB(199, 220, 236)
	atm.Decay = Color3.fromRGB(106, 140, 170)
	atm.Glare = 0.25
	atm.Haze = 0.6
	local cc = effect("ColorCorrectionEffect", "ColorCorrection")
	cc.Brightness = 0.02
	cc.Contrast = 0.1
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(255, 252, 245)
	local bloom = effect("BloomEffect", "Bloom")
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.6
	local rays = effect("SunRaysEffect", "SunRays")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	-- bulanıklık efektini kapat (görüntü net kalsın)
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false
	end

	-- Streaming: kenardaki dağlar uzaktan görünsün diye geniş yükleme mesafesi
	-- (düşük bellekli cihazlarda Roblox bunu kendiliğinden azaltır)
	workspace.StreamingTargetRadius = 2800 -- atolde dağların görünmesi için
	workspace.StreamingMinRadius = 128

	local T = workspace.Terrain
	T.Decoration = true
	T.WaterColor = Color3.fromRGB(20, 118, 158)
	T.WaterTransparency = 0.6
	T.WaterReflectance = 0.35
	T.WaterWaveSize = 0.18
	T.WaterWaveSpeed = 10
	local colors = {
		[Enum.Material.Grass] = Color3.fromRGB(96, 156, 64),
		[Enum.Material.LeafyGrass] = Color3.fromRGB(70, 126, 48),
		[Enum.Material.Sand] = Color3.fromRGB(232, 210, 156),
		[Enum.Material.Rock] = Color3.fromRGB(116, 112, 106),
		[Enum.Material.Ground] = Color3.fromRGB(146, 112, 78),
		[Enum.Material.Cobblestone] = Color3.fromRGB(164, 158, 148),
		[Enum.Material.Slate] = Color3.fromRGB(128, 128, 134),
		[Enum.Material.Sandstone] = Color3.fromRGB(206, 178, 132),
		[Enum.Material.Basalt] = Color3.fromRGB(78, 76, 74),
	}
	for mat, col in colors do
		T:SetMaterialColor(mat, col)
	end
end

-- Harita kenarındaki tropikal dağlar (yavaş: parça parça da çalıştırılabilir, ör. B.Mountains(1, 20))
function Builder.ClearMountains()
	require(script.Nature).ClearMountains(cfg())
end

function Builder.Mountains(from, to)
	return require(script.Nature).Mountains(cfg(), from, to)
end

-- Adalara çalı, kaya, çiçek, eğrelti ve ekstra palmiye
function Builder.Vegetation()
	require(script.Nature).Vegetation(cfg())
end

-- Old Fisherman NPC (ada dağıtıcı)
function Builder.Fisherman()
	require(script.Structures).Fisherman(cfg())
end

-- 12 özel ada + balık noktaları
function Builder.Islands()
	local c = cfg()
	local I = require(script.Islands)
	I.Build(c)
	I.Spots(c)
end

return Builder
