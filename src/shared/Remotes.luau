--!strict
-- Tüm RemoteEvent / RemoteFunction'lar burada tanımlanır.
-- Server bunları oluşturur, client bekler. İsimler tek yerde olduğu için yazım hatası olmaz.
--
-- Kural: Client sadece İSTEK gönderir. Hangi balığın çıktığına, para miktarına vs. server karar verir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- Balık tutma döngüsü
	"CastRequest", -- client -> server: olta at (spot Part'ı)
	"FishBite", -- server -> client: balık vurdu, oyuncu basmalı
	"HookRequest", -- client -> server: oyuncu bastı
	"FishHooked", -- server -> client: takıldı, reeling bar'ı başlat (nadirlik, barSpeed, targetSize)
	"ReelResult", -- client -> server: reeling bitti (true = başarılı)
	"FishCaught", -- server -> client: balık depoya eklendi (fishId)
	"FishingEnded", -- server -> client: döngü bitti, sebep ("early", "late", "escaped", "full", "far", ...)

	-- Ekonomi
	"SellRequest", -- client -> server: slot'taki balığı sat
	"PoolRequest", -- client -> server: slot'taki balığı havuza koy
	"DataUpdated", -- server -> client: para / depo / havuz değişti (DataService.Payload formatında)

	-- Hareket
	"TeleportRequest", -- client -> server: "Island" (kendi adama) | "Main" (ana adaya)
	"GuideTarget", -- server -> client: ok'u bu Part'a çevir (part, etiket). part = nil ise ok kapanır

	-- Arayüz
	"OpenCollection", -- server -> client: koleksiyon kitabını aç (kulübedeki kitaba basınca)
	"Notify", -- server -> client: kısa bildirim (metin, renk)

	-- Giriş öğreticisi (yaşlı balıkçı ile sinematik sohbet)
	"IntroStart", -- server -> client: öğreticiyi başlat
	"PoolTake", -- client -> server: havuzdaki i. balığı tekneye (envantere) al
	"CoinBurst", -- server -> client: satıştan para geldi (miktar) -> ekranda para animasyonu
	"GuideStep", -- server -> client: rehber adımı (id, görev yazısı, havuz parçası)
}

local FUNCTIONS = {
	"GetPlayerData", -- client -> server: güncel veriyi iste
	"IntroAction", -- client -> server: "claim" (ada al, ada numarası döner) | "done" (öğretici bitti)
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
