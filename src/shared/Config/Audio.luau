--!strict
-- Oyun sesleri. Hepsi Roblox Creator Store'daki ücretsiz/lisanslı sesler (APM, Pro Sound Effects vb.).
-- Değiştirmek için sadece numarayı değiştirin.
return {
	-- Arka plan müziği: sırayla çalar, sonra başa döner
	Music = {
		"rbxassetid://1839578771", -- Charming View Ukulele (APM)
		"rbxassetid://1845913205", -- Walking On The Beach - Hawaii ukulele (APM)
	},
	MusicStartVolume = 0.5, -- oyuna ilk girince
	MusicVolume = 0.16, -- birkaç saniye sonra kısılır
	MusicFadeAfter = 20, -- kaç sn sonra kısılsın
	MusicStormVolume = 0.06, -- fırtınanın altındayken (yağmur duyulsun)

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
}
