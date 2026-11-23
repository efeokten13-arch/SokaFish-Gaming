--!strict
-- Oyun sesleri. Hepsi Roblox Creator Store'daki ücretsiz/lisanslı sesler (APM, Pro Sound Effects vb.).
-- Değiştirmek için sadece numarayı değiştirin.
return {
	-- Arka plan müziği: sırayla çalar, sonra başa döner
	Music = {
		"rbxassetid://1839578771", -- Charming View Ukulele (APM)
		"rbxassetid://1845913205", -- Walking On The Beach - Hawaii ukulele (APM)
	},
	MusicStartVolume = 0, -- (eskisi 0.5) şimdilik kapalı -- oyuna ilk girince
	MusicVolume = 0, -- (eskisi 0.16) şimdilik kapalı -- birkaç saniye sonra kısılır
	MusicFadeAfter = 20, -- kaç sn sonra kısılsın
	MusicStormVolume = 0, -- (eskisi 0.06) şimdilik kapalı -- fırtınanın altındayken (yağmur duyulsun)

	Rain = "rbxassetid://5911952995", -- yağmur döngüsü
	RainVolume = 0.7,
	Thunder = { "rbxassetid://139319051979882", "rbxassetid://130457325001606" },
	ThunderVolume = 0.9,

	Splash = "rbxassetid://9125703162", -- balık vurunca / tutunca su sesi
	Reel = "rbxassetid://9114454025", -- olta makarası (çekerken döngü)
	NewFish = "rbxassetid://1839881844", -- yeni tür ilk kez tutulunca kısa fanfar
	CatchJingle = "rbxassetid://1848281810", -- balık tutunca kısa müzik
	HoHo = "rbxassetid://140460517641927", -- yaşlı balıkçının "Ho ho!" kahkahası (öğretici)
	Click = "rbxassetid://9125703162", -- öğreticide cevap butonu (küçük su sesi)
	StormCatch = "rbxassetid://130457325001606", -- fırtınada tutunca gök gürültüsü
	Purchase = "rbxassetid://91609406292294", -- olta / tekne alınca para eksilme sesi (retro kasa "ka-ching")

	-- Atış eğitimi (Gunnery Range). Hepsi Creator Store'dan ücretsiz sesler; numarayı değiştirerek başkasıyla değiştirebilirsin.
	Cannon = "rbxassetid://72411732778781", -- top atışı
	ShipHit = "rbxassetid://9120187684", -- gülle tahtaya çarpınca (ahşap parçalanma)
	ShipBlastSmall = "rbxassetid://17520934057", -- zincirleme küçük patlamalar
	ShipBlastBig = "rbxassetid://106108995063585", -- ana patlama (anime / Dragon Ball tarzı)
	ShipBlastLayer = "rbxassetid://83045267644362", -- ana patlamanın altına binen ağır "boom"
	ShipBlastFar = "rbxassetid://71210968604540", -- uzaktan gelen yankı

	-- Eğitim körfezi ortam sesleri (Pro Sound Effects, ücretsiz)
	BayWaterfall = "rbxassetid://9116496316", -- şelale döngüsü (3B, şelalenin dibinde)
	BayCave = "rbxassetid://9112775175", -- mağara ağzındaki ürkütücü uğultu (3B)
	BayAmbience = "rbxassetid://9112828911", -- liman: tahta gıcırtısı, su şıpırtısı (körfezdeyken 2B)

	-- Kale kapısı görevi
	QuestMusic = "rbxassetid://9043602056", -- aksiyon müziği: "Ghost Ship" (APM), kapı açılınca başlar, gemi batınca durur
	QuestMusicVolume = 0.5,
	VictorySting = "rbxassetid://83315768373322", -- "Island 3 unlocked" zafer müziği (APM)
	GateCreak = "rbxassetid://9120839599", -- ahşap kapı gıcırtısı (yavaş çalınır = dev kapı)
	ChainRattle = "rbxassetid://9116791182", -- vinç zinciri şıngırtısı
}
