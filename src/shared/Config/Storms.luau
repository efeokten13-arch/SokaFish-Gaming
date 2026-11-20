--!strict
-- Yağmur bulutları (ilk deniz): altına olta atınca nadir balık şansı artar.
-- Bulutlar ana adanın etrafında rastgele gezer; deniz kenarlarına çok gitmez.
return {
	Count = 2, -- aynı anda kaç bulut
	Luck = 2.0, -- bulut altında şans çarpanı (sadece Common dışı balıkları etkiler)
	Radius = 55, -- bulutun altındaki şanslı alanın yarıçapı (stud)

	-- Gezinme alanı: ana adanın merkezine uzaklık (stud). Oyuncu adaları ~700'de.
	MinDistance = 280, -- ana adanın üstüne fazla girmesin
	MaxDistance = 900, -- en dışlara gitmesin (deniz kenarı ~1800)
	Center = Vector3.new(0, 0, 0),

	Speed = 9, -- stud/sn (teknelerden yavaş: yetişilebilsin)
	StepMin = 180, -- her yeni hedef en az bu kadar uzakta
	StepMax = 420,
	MinGap = 350, -- iki bulut birbirine bu kadar yaklaşmasın

	Height = 75, -- bulutun sudan yüksekliği
	LightningMin = 6, -- şimşek aralığı (sn)
	LightningMax = 14,
}
