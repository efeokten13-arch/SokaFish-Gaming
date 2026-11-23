--!strict
-- Balık tutma mekaniği ayarları. Zorluğu buradan oynayın.

local Fishing = {
	CastRange = 25, -- spot'a en fazla kaç stud uzaktan olta atılabilir

	-- Açık deniz: işaretli spot olmasa da suya olta atılabilir.
	-- Bölge, okyanusun merkezine uzaklıkla belirlenir (stud): near'dan yakın = Near, mid'den yakın = Mid, ötesi = Far
	OpenWaterCastDistance = 16, -- karakterin önünde oltanın düştüğü mesafe
	OpenWater = {
		Warm = { near = 600, mid = 1150 },
		Coral = { near = 750, mid = 1250 },
	},
	HotspotLuck = 1.25, -- işaretli (renkli) spotlarda şans bonusu

	-- Bekleme ve vurma
	WaitMin = 1.2, -- olta atıldıktan sonra en az bekleme (sn)
	WaitMax = 3.0, -- en fazla bekleme (sn)
	GoldenCastWait = 6.6, -- tapınak kutsamalı atış: su altı sahnesi (client/Effects/GoldenCast) bitince Golden Fish doğrudan yakalanır (tıklama yok)
	BiteWindow = 0.9, -- "BAS!" çıktıktan sonra basmak için süre (sn)
	LatencyGrace = 0.35, -- internet gecikmesi için tolerans (sn)

	-- Çekme (reeling bar)
	StartProgress = 0.3, -- bar bu kadar dolu başlar (0-1)
	ProgressGain = 0.32, -- balık alanın içindeyken saniyede dolma
	ProgressLoss = 0.22, -- balık dışarıdayken saniyede boşalma
	-- Kontrol: "hold" = basılı tut (yükselir) / bırak (düşer)  ·  "tap" = eski hızlı tıklama
	ReelControl = "hold",
	ZoneAccelUp = 2.6, -- (hold) basılı tutunca göstergenin yukarı ivmesi
	ZoneAccelDown = 1.9, -- (hold) bırakınca aşağı ivme
	MaxReelTime = 45, -- bundan uzun süren çekme geçersiz sayılır (sn)

	-- Olta görseli
	RodRestPitch = 35, -- olta elde dururken ucunun yukarı açısı (derece). Olta yamuk duruyorsa bunu oynayın
	RodHideDelay = 6, -- balık tutulmayınca kaç saniye sonra olta elden kalkar

	-- Tuşlar (mobilde ekrandaki büyük buton kullanılır)
	-- Not: Space kullanmıyoruz çünkü teknede Space = koltuktan zıplama
	KeyboardKey = Enum.KeyCode.F,
	GamepadKey = Enum.KeyCode.ButtonX,
}

return Fishing
