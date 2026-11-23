--!strict
-- Mağaza (olta + tekne) arayüzünün yazıları ve istatistik çubuğu sınırları.
-- Fiyat / şans / hız gibi asıl değerler Economy.luau ve Boats.luau'da; burada sadece yazı ve ölçek var.
local Shop = {}

Shop.Merchants = {
	Rods = { name = "Rod Merchant", subtitle = "Rod Shop · Main Island" },
	Boats = { name = "Shipwright Nils", subtitle = "Boat Shop · Main Island" },
}

-- Çubukların dolu sayılacağı en yüksek değerler (arayüzde çubuk boyu = değer / max)
Shop.RodMax = { luck = 2.6, length = 7.5 }
Shop.BoatMax = { speed = 450, slots = 9, oceans = 3 }

Shop.RodDesc = {
	BranchRod = { tag = "Better than nothing!", text = "A forked branch with a bit of string. Every legend starts somewhere." },
	BambooRod = { tag = "Light and springy.", text = "Old but reliable. Slightly better luck for a few coins." },
	ApprenticeRod = { tag = "Worn by deckhands.", text = "Dark wood and a brass reel. The pirate apprentices swear by it." },
	IronRod = { tag = "Riveted for rough seas.", text = "Strong enough for the big ones. Fish bite more often." },
	CoralRod = { tag = "Straight from the reef.", text = "A bright coral grip and a glowing reel. Rare fish love it." },
	WreckRod = { tag = "Pulled from a wreck.", text = "Mossy and heavy, but it finds treasure others miss." },
	SharkRod = { tag = "The ultimate rod.", text = "Carved from a shark tooth. The best luck money can buy." },
}

Shop.BoatDesc = {
	Rowboat = { tag = "Your first boat.", text = "Two oars and a lot of hope. Cheap, slow and reliable." },
	Kayak = { tag = "Fast and nimble.", text = "A sturdy yellow canoe. Faster than rowing and holds more fish." },
	Sloop = { tag = "Sails the deep ocean.", text = "A real sailing ship. Opens the Deep Ocean and carries a big catch." },
	Warship = { tag = "Built for battle.", text = "Cannons, a huge hold and the Mystery Sea. Unlocks Mermaid Island." },
}

return Shop
