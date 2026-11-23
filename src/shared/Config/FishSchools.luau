--!strict
-- Balık sürüleri (ilk deniz): martıların döndüğü, balıkların sudan zıpladığı yerler.
-- Sürünün içine olta atınca nadir balık şansı artar. Bir süre sonra dağılır, başka yerde yenisi çıkar.
-- Server: server/Fish/SchoolService · Görsel: client/Effects/FishSchools
return {
	Count = 4, -- aynı anda kaç sürü
	Luck = 1.6, -- sürünün içinde şans çarpanı (yağmur bulutu 4.0; ikisi üst üste gelirse çarpılır)
	Radius = 45, -- şanslı alanın yarıçapı (stud)

	LifeMin = 90, -- sürü kaç saniye sonra dağılır (rastgele, bu ikisi arası)
	LifeMax = 180,

	-- Nerede çıkar: ana adanın merkezine uzaklık (stud). Oyuncu adaları ~700'de, deniz kenarı ~1800.
	Center = Vector3.new(0, 0, 0),
	MinDistance = 300,
	MaxDistance = 1100,
	MinGap = 250, -- iki sürü birbirine bu kadar yaklaşmasın

	-- Görsel (sadece client)
	Gulls = 6, -- sürünün üstünde dönen martı sayısı
	GullHeight = 26, -- martıların sudan yüksekliği
	GullRadius = 22, -- dönme yarıçapı
	JumpMin = 0.5, -- sudan zıplayan balıklar arası süre (sn)
	JumpMax = 1.4,
	DrawDistance = 700, -- kameraya bundan uzak sürüler çizilmez (performans)
}
