--!strict
-- Tekne seviyeleri.
-- slots: depolama slotu sayısı (1 tanesi korumalı)
-- speed: kürek/motor hızı
-- oceans: bu tekneyle girilebilen okyanuslar

local Boats = {
	Rowboat = { displayName = "Rowboat", price = 1, slots = 3, speed = 12, oceans = { "Warm" }, order = 1 },
	Kayak = { displayName = "Yellow Canoe", price = 100, slots = 5, speed = 18, oceans = { "Warm" }, order = 2 },
	Sloop = { displayName = "Sloop", price = 2500, slots = 7, speed = 22, oceans = { "Warm", "Deep" }, order = 3 },
	Warship = { displayName = "Warship", price = 50000, slots = 9, speed = 26, oceans = { "Warm", "Deep", "Mystery" } },
}

Boats.ProtectedSlots = 1
Boats.Starter = "Rowboat" -- slot sayısı için varsayılan; tekne artık iskeleden satın alınır
-- İskelede sergilenen ve satılan tekneler (sırayla slip 1, 2, 3)
Boats.ShopOrder = { "Rowboat", "Kayak", "Sloop" }

return Boats
