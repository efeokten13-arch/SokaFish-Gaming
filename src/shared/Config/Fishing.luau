--!strict
-- Balık tutma mekaniği ayarları. Zorluğu buradan oynayın.

local Fishing = {
	CastRange = 25, -- spot'a en fazla kaç stud uzaktan olta atılabilir

	-- Bekleme ve vurma
	WaitMin = 1.2, -- olta atıldıktan sonra en az bekleme (sn)
	WaitMax = 3.0, -- en fazla bekleme (sn)
	BiteWindow = 0.9, -- "BAS!" çıktıktan sonra basmak için süre (sn)
	LatencyGrace = 0.35, -- internet gecikmesi için tolerans (sn)

	-- Çekme (reeling bar)
	StartProgress = 0.3, -- bar bu kadar dolu başlar (0-1)
	ProgressGain = 0.32, -- balık alanın içindeyken saniyede dolma
	ProgressLoss = 0.22, -- balık dışarıdayken saniyede boşalma
	ZoneAccelUp = 2.6, -- basılı tutunca yeşil alanın yukarı ivmesi
	ZoneAccelDown = 2.4, -- bırakınca aşağı ivme
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
