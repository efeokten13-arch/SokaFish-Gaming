--!strict
-- Gemi topları ayarları (client nişan çizgisi ve server mermi aynı sayıları kullanır)
return {
	Speed = 150, -- mermi çıkış hızı (stud/sn)
	Arc = 16, -- yukarı doğru ek hız (kavis)
	Gravity = 70, -- mermiye etki eden yerçekimi (Roblox'unkinden düşük = daha uzun menzil)
	MaxYawDeg = 25, -- topların sağa sola dönebildiği açı
	Cooldown = 2.5, -- iki atış arası saniye
	Lifetime = 4, -- mermi en fazla kaç saniye uçar
	BlastRadius = 6, -- şimdilik sadece görsel (hasar gemi savaşında eklenecek)
}
