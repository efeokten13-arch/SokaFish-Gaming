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
--   theme         elle çizilen portrenin stili

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
	theme: string?,
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

-- theme: elle çizilen portrenin stili ("tropical", "coral", "swamp", "ice", "volcano")
SeaMap.Islands = {
	{ id = "Warm", name = "Warm Waters", x = 0.16, y = 0.34, level = 0, image = "", theme = "tropical", seed = 1, travel = "Main",
		description = "The peaceful starting seas. Rich with common fish, gentle waves, and busy docks." },
	{ id = "Coral", name = "Ancient Coral Atoll", x = 0.35, y = 0.66, level = 1, image = "", theme = "coral", seed = 2, travel = "Dest",
		description = "Bright reefs around forgotten ruins. Colorful and rare fish." },
	{ id = "Swamp", name = "Shrouded Swamp", x = 0.53, y = 0.34, level = 2, image = "", theme = "swamp", seed = 3,
		description = "Murky water under twisted trees. Strange fish hide in the fog." },
	{ id = "Frost", name = "Frostbite Fjord", x = 0.71, y = 0.66, level = 3, image = "", theme = "ice", seed = 4,
		description = "Freezing water between icy cliffs. Only sturdy boats survive." },
	{ id = "Ashen", name = "Ashen Caldera", x = 0.88, y = 0.34, level = 4, image = "", theme = "volcano", seed = 5,
		description = "A burning volcano. Legendary fish swim in the hot sea." },
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
