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
	-- Kademeli atış sahneleri (client/Effects/CastCinematics): Common / Uncommon sahne yok, Rare kısa parlama
	-- (client/Fishing/ReelingController), Epic kısa ortak sahne, Legendary'ler kendi özel sahnesi.
	-- Sahne bitince balık vurur ("BAS!" + çekme). Tapınak kutsamalı Golden Fish'te tıklama yok, doğrudan yakalanır.
	Cinematics = {
		ByFish = { ReefShark = "shark", GoldenFish = "golden" }, -- özel sahnesi olan balıklar
		ByRarity = { Epic = "epic", Legendary = "epic" }, -- özel sahnesi yoksa nadirliğe göre
		Wait = { epic = 4.2, golden = 6.6, shark = 9.2 }, -- sahne süresi + pay (sn): bu kadar sonra vurur
	},
	CineMaxWait = 9.2, -- en uzun bekleme (client zaman aşımı için)
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
