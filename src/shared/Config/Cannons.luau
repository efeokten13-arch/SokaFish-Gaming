--!strict
-- Gemi topları ayarları (client nişan çizgisi ve server mermi aynı sayıları kullanır)
-- Oyuncu güvertede bir topun yanına yürür: R = nişan (fare / A-D sağa-sola, W-S / fare yukarı-aşağı), F = ateş.
return {
	Speed = 150, -- mermi çıkış hızı (stud/sn)
	Arc = 16, -- yukarı doğru ek hız (kavis)
	Gravity = 70, -- mermiye etki eden yerçekimi (Roblox'unkinden düşük = daha uzun menzil)
	MaxYawDeg = 25, -- topların sağa sola dönebildiği açı
	MinPitchDeg = -6, -- namlu en fazla bu kadar aşağı (yakın atış)
	MaxPitchDeg = 22, -- namlu en fazla bu kadar yukarı (uzak atış, ~300 stud)
	Cooldown = 2, -- aynı oyuncunun iki atışı arası saniye
	Lifetime = 5, -- mermi en fazla kaç saniye uçar
	BlastRadius = 6, -- şimdilik sadece görsel (hasar gemi savaşında eklenecek)
	UseRange = 14, -- oyuncu topa bu kadar yakın olmalı (server kontrolü)

	-- Gülle türleri (nişan alırken sağ ortada görünür). locked = henüz açılmadı (ileride: ateşli gülle vb.)
	Ammo = {
		{ id = "Iron", name = "Cannonball", icon = "⚫", note = "∞" },
		{ id = "Fire", name = "Fire Ball", icon = "🔥", note = "Soon", locked = true },
		{ id = "Chain", name = "Chain Shot", icon = "⛓️", note = "Soon", locked = true },
	},
}
