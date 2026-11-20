--!strict
-- Tekne seviyeleri.
-- slots: depolama slotu sayısı (1 tanesi korumalı)
-- speed: en yüksek hız (stud/sn). Karakter yürüyüşü 16.
-- turnIdle (isteğe bağlı): dururken dönüş hızı (varsayılan 0.18; hareket halinde tam hız)
-- oceans: bu tekneyle girilebilen okyanuslar

local Boats = {
	Rowboat = { displayName = "Rowboat", price = 1, slots = 3, speed = 215, oceans = { "Warm" }, order = 1 },
	Kayak = { displayName = "Yellow Canoe", price = 100, slots = 5, speed = 312, oceans = { "Warm" }, order = 2 },
	Sloop = { displayName = "Sloop", price = 2500, slots = 7, speed = 371, oceans = { "Warm", "Deep" }, order = 3 },
	Warship = { displayName = "Warship", price = 50000, slots = 9, speed = 429, oceans = { "Warm", "Deep", "Mystery" }, order = 4 },
}

Boats.ProtectedSlots = 1
Boats.Starter = "Rowboat" -- slot sayısı için varsayılan; tekne artık iskeleden satın alınır
-- İskelede sergilenen ve satılan tekneler (sırayla slip 1, 2, 3)
Boats.ShopOrder = { "Rowboat", "Kayak", "Sloop", "Warship" }

return Boats
