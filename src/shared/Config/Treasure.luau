--!strict
-- Hazine sandıkları: ödüller ve yenilenme süresi (her oyuncu için ayrı)
return {
	Tiers = {
		Small = { min = 60, max = 160 }, -- ana atoldeki X işaretleri
		Medium = { min = 150, max = 400 }, -- uydu adalar
		Large = { min = 350, max = 900 }, -- 4 köşe adası
	},
	RespawnMinutes = 15, -- aynı oyuncu aynı sandığı bu kadar dakika sonra tekrar açabilir
}
