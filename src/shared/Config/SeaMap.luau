--!strict
-- Korsan haritası (ada seçimi) ayarları. Yeni ada eklemek = listeye yeni satır.
--
-- Her ada:
--   id            benzersiz ad (boşluksuz)
--   name          haritada görünen ad
--   x, y          haritadaki yeri, 0-1 arası (x: 0 sol, 1 sağ; y: 0 üst, 1 alt)
--   level         açılması için gereken tekne seviyesi (0 = baştan açık)
--   image         kendi ada görselin: "rbxassetid://123..." (boş "" ise ada elle çizilir)
--   description   seçince altta görünen kısa yazı
--   travel        nereye ışınlanılır:
--                   "Main"  -> ana ada (spawn)
--                   "Dest"  -> Workspace.SeaMapDestinations içindeki, id ile aynı isimli Part
--                   nil     -> henüz yapılmadı ("coming soon" mesajı)
--   seed          elle çizilen adanın şekli (farklı sayı = farklı şekil)

export type SeaIsland = {
	id: string,
	name: string,
	x: number,
	y: number,
	level: number,
	image: string,
	description: string,
	travel: string?,
	seed: number,
}

local SeaMap = {}

-- Tekne seviyeleri: oyuncunun sahip olduğu en yüksek seviyeli tekne sayılır
SeaMap.BoatLevels = {
	Rowboat = 1,
	Kayak = 2, -- Yellow Canoe
	Sloop = 3,
	Warship = 4,
}

-- Kilitli adaya tıklayınca çıkan yazı (%d = gereken seviye)
SeaMap.LockedMessage = "You need a Level %d boat to unlock this island!"
SeaMap.ComingSoonMessage = "This island hasn't been charted yet. Coming soon!"

-- Parşömen için kendi görselini kullanmak istersen buraya yaz ("" = kodla çizilir)
SeaMap.ParchmentImage = ""

SeaMap.Islands = {
	{ id = "Harbor", name = "Harbor Isle", x = 0.50, y = 0.88, level = 0, image = "", seed = 1, travel = "Main",
		description = "The home harbor. Fish Market, boat shop and the Old Fisherman." },
	{ id = "Driftwood", name = "Driftwood Cay", x = 0.73, y = 0.77, level = 1, image = "", seed = 2,
		description = "Calm shallows full of common fish." },
	{ id = "Gull", name = "Gull Rock", x = 0.28, y = 0.68, level = 1, image = "", seed = 3,
		description = "Seabirds circle over the reefs." },
	{ id = "Coral", name = "Coral Crown", x = 0.70, y = 0.59, level = 2, image = "", seed = 4,
		description = "Bright reefs and rare fish." },
	{ id = "Mist", name = "Mistwood", x = 0.30, y = 0.50, level = 2, image = "", seed = 5,
		description = "Fog hides what swims below." },
	{ id = "Smuggler", name = "Smuggler's Cove", x = 0.72, y = 0.41, level = 2, image = "", seed = 6,
		description = "Old crates and older secrets." },
	{ id = "Serpent", name = "Serpent Spine", x = 0.33, y = 0.32, level = 3, image = "", seed = 7,
		description = "Deep water. Big fish. Bigger danger." },
	{ id = "Bones", name = "Bone Shoals", x = 0.66, y = 0.24, level = 3, image = "", seed = 8,
		description = "Shipwrecks litter the sand." },
	{ id = "Storm", name = "Stormbreak", x = 0.38, y = 0.16, level = 4, image = "", seed = 9,
		description = "Only warships survive these waves." },
	{ id = "Treasure", name = "Skull Treasure Isle", x = 0.60, y = 0.08, level = 4, image = "", seed = 10,
		description = "Where the legends end... and the treasure begins." },
}

-- Oyuncunun tekne seviyesi (sahip olunan teknelerden en yükseği)
function SeaMap.BoatLevel(ownedBoats: { string }?): number
	local best = 0
	for _, id in ownedBoats or {} do
		best = math.max(best, SeaMap.BoatLevels[id] or 0)
	end
	return best
end

function SeaMap.Get(id: string): SeaIsland?
	for _, isl in SeaMap.Islands do
		if isl.id == id then
			return isl :: any
		end
	end
	return nil
end

return SeaMap
