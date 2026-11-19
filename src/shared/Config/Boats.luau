--!strict
-- Tekne seviyeleri.
-- slots: depolama slotu sayısı (1 tanesi korumalı)
-- speed: kürek/motor hızı
-- oceans: bu tekneyle girilebilen okyanuslar

local Boats = {
	Kayak = { displayName = "Wooden Kayak", price = 0, slots = 3, speed = 12, oceans = { "Warm" } },
	Rowboat = { displayName = "Rowboat", price = 500, slots = 5, speed = 16, oceans = { "Warm" } },
	Sloop = { displayName = "Sloop", price = 5000, slots = 7, speed = 22, oceans = { "Warm", "Deep" } },
	Warship = { displayName = "Warship", price = 50000, slots = 9, speed = 26, oceans = { "Warm", "Deep", "Mystery" } },
}

Boats.ProtectedSlots = 1
Boats.Starter = "Kayak"

return Boats
