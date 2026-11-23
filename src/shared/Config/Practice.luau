--!strict
-- Kale kapısı + atış görevi (kapının arkasındaki "Gunnery Range" körfezi). Hem server hem client okur.
-- Akış: anahtarı olan oyuncu gemisiyle kapıya gelir -> sinematik (kapı açılır, aksiyon müziği, kuledeki korsan düşmanı gösterir)
--   -> parlayan halkaya yelken aç -> güverteden bir topa yürü, R nişan / F ateş -> Hits isabette düşman gemisi batar
--   (anime patlama) -> müzik durur -> "ISLAND 3 UNLOCKED" sinematiği.
-- Konum ölçüsü: kapıdan (s = 0) körfezin içine doğru s stud, kapıya bakınca sağa doğru u stud ("TrainFrame" parçasına göre).
return {
	Hits = 3, -- düşman gemisi kaç isabette batar (sonuncusu anime finali)

	-- Korsanın cümleleri (kısa)
	IntroText1 = "Ahoy, captain! The Mermaid's key opened the gate. Up here, on the lookout tower!",
	IntroText2 = "See that ship over there? That's the ENEMY! Sink her before she escapes!",
	SailText = "Sail to the glowing ring!",
	FireText = "Walk to a cannon on the RIGHT side of your deck. R = aim, mouse = move, F = FIRE!",
	FireTextTouch = "Walk to a cannon on the RIGHT side of your deck. Tap Aim, drag to move, then Fire!",
	HitText = "Good hit! Again!",
	LastHitText = "One more... sink her!",
	DoneText = "Boom! Ye sank her! Ye're a proper gunner, captain!",
	UnlockTitle = "ISLAND 3 UNLOCKED!",
	UnlockText = "The way to the Pirate Seas is open, captain!",
	BusyText = "is fighting the enemy ship right now. Wait for your turn!",
	NoKeyText = "The gate is sealed. The Mermaid has the key!",

	-- Yerler (s, u)
	Berth = { s = 205, u = 94 }, -- düşman gemisi iskelede bağlı durur
	FireSpot = { s = 200, u = 8, r = 30 }, -- oyuncunun gemiyi getireceği halka (r = kabul yarıçapı)
	GateTrigger = 240, -- anahtarlı oyuncu kapının bu kadar yakınına (dışarıdan) gelince sinematik başlar
	GateOpenDistance = 520, -- anahtarlı oyuncuya (görev sürerken ya da bittiyse) kapı bu mesafede açık durur (körfezin içi dahil)
	PlayerStart = { s = -150, u = 0 }, -- dev komutu teknenizi buraya (kapının dışına) getirir
	IdleTimeout = 240, -- bu kadar sn isabet yoksa görev sıfırlanır (tekrar gelince baştan)

	-- Sinematik süreleri (sn)
	Intro = {
		Doors = 3.6, -- kapı kanatları açılır (dışarıdan, gemi tarafından)
		ToPirate = 3.0, -- kamera kapıdan geçip gözetleme kulesindeki korsana uçar (1. cümle)
		Point = 4.4, -- korsan düşman gemisini gösterir, kamera omzunun üstünden gemiye kayar (2. cümle)
		Total = 11.6, -- kamera oyuncuya döner (server bundan sonra "sail" gönderir)
	},
	Unlock = { Total = 8 },

	-- Final sahnesi zaman çizelgesi (sn, son isabetten sonra). Server ve client aynı sayıları kullanır.
	Finale = {
		Chain = 0.9, -- zincirleme küçük patlamalar başlar
		Main = 1.9, -- ana patlama + gemi parçalanır
		WreckLife = 7.5, -- enkaz ne kadar sonra silinir
		Total = 10.5, -- kamera oyuncuya döner, ardından "Island 3" sinematiği
		Rebuild = 22, -- yeni düşman gemisi kurulur
	},
	FarDistance = 900, -- patlamayı bu mesafeden uzaktaki oyuncular görmez
}
