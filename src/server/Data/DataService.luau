--!strict
-- Oyuncu verisi: yükle, kaydet, eriş, client'a gönder.
-- Basit DataStore sürümü. İleride ProfileStore'a geçmek önerilir (session lock, veri kaybını önler).
-- NOT: Studio'da kayıt için Game Settings -> Security -> "Enable Studio Access to API Services" açık olmalı.
--      Kapalıysa oyun varsayılan veriyle çalışır, sadece kaydedilmez.
--
-- Client'a giden veri formatı (HUD ve envanter bunu kullanır):
--   {
--     money = 1250,
--     storage = { "Cod", "SeaBass" },   -- teknedeki balık id'leri
--     slots = 3,                        -- teknenin slot sayısı
--     protectedSlots = 1,
--     pool = { "Cod" },                 -- havuzdaki balık id'leri
--     poolCapacity = 6,
--     boat = "Kayak", rod = "BranchRod", ownedRods = { "BranchRod" }, bait = "BasicBait",
--   }
-- Veri değiştiren her server kodu sonunda DataService.Push(player) çağırmalı.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Boats = require(Config:WaitForChild("Boats"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local store = DataStoreService:GetDataStore("PlayerData_v1")

export type PlayerData = {
	money: number,
	boat: string,
	rod: string,
	bait: string,
	storage: { string },
	pool: { string },
	ownedBoats: { string },
	ownedRods: { string },
	caught: { [string]: number }, -- koleksiyon kitabı: tür -> tutulan sayı
	tutorial: number, -- 0 = başlamadı, 1 = ada alındı, 2 = tekne alındı
	starterGrant: boolean?, -- eski kayıtlara bir kez başlangıç parası vermek için
	lastOnline: number,
}

local function defaultData(): PlayerData
	return {
		money = Economy.StartingMoney,
		boat = Boats.Starter,
		rod = Economy.StarterRod,
		bait = "BasicBait",
		storage = {},
		pool = {},
		ownedBoats = {},
		ownedRods = { Economy.StarterRod },
		caught = {},
		tutorial = 0,
		lastOnline = os.time(),
	}
end

local DataService = {}
local cache: { [Player]: PlayerData } = {}

function DataService.Get(player: Player): PlayerData?
	return cache[player]
end

-- Client'a gönderilecek kopya
function DataService.Payload(player: Player): any
	local data = cache[player]
	if not data then
		return nil
	end
	local boat = (Boats :: any)[data.boat]
	return {
		money = data.money,
		storage = table.clone(data.storage),
		slots = if boat then boat.slots else 3,
		protectedSlots = Boats.ProtectedSlots,
		pool = table.clone(data.pool),
		poolCapacity = Economy.PoolCapacity,
		boat = data.boat,
		ownedBoats = table.clone(data.ownedBoats),
		caught = table.clone(data.caught),
		ownedRods = table.clone(data.ownedRods),
		rod = data.rod,
		bait = data.bait,
	}
end

-- Güncel veriyi oyuncunun client'ına gönder
function DataService.Push(player: Player)
	local payload = DataService.Payload(player)
	if payload then
		Remotes.Event("DataUpdated"):FireClient(player, payload)
	end
end

-- Oyuncuya kısa bildirim gönder (HUD gösterir)
function DataService.Notify(player: Player, text: string, color: Color3?)
	Remotes.Event("Notify"):FireClient(player, text, color)
end

-- Veri yüklenene kadar bekler (en fazla 10 sn)
function DataService.Wait(player: Player): PlayerData?
	local t = 0
	while not cache[player] and t < 10 and player.Parent do
		t += task.wait(0.1)
	end
	return cache[player]
end

local function load(player: Player)
	local ok, result = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	local data = defaultData()
	if ok and type(result) == "table" then
		for k, v in result do
			(data :: any)[k] = v
		end
	elseif not ok then
		warn("Veri yüklenemedi (Studio'da API erişimi kapalı olabilir):", player.Name, result)
	end
	-- tekneler satılık olmadan önce kaydolmuş oyuncu: ilk kayığı alabilsin diye bir kez başlangıç parası
	if not data.starterGrant then
		data.money = math.max(data.money, Economy.StartingMoney)
		data.starterGrant = true
	end
	-- olta listesi değişti: eski kayıttaki olmayan oltalar başlangıç oltasına döner
	if type(data.ownedRods) ~= "table" then
		data.ownedRods = {}
	end
	local valid = {}
	for _, id in data.ownedRods do
		if (Economy.Rods :: any)[id] and not table.find(valid, id) then
			table.insert(valid, id)
		end
	end
	if not table.find(valid, Economy.StarterRod) then
		table.insert(valid, 1, Economy.StarterRod)
	end
	data.ownedRods = valid
	if not table.find(valid, data.rod) then
		data.rod = Economy.StarterRod
	end
	cache[player] = data
	DataService.Push(player)
end

local function save(player: Player)
	local data = cache[player]
	if not data then
		return
	end
	data.lastOnline = os.time()
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("Veri kaydedilemedi:", player.Name, err)
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	-- Server başlamadan önce girmiş oyuncular (Studio'da sık olur)
	for _, p in Players:GetPlayers() do
		if not cache[p] then
			task.spawn(load, p)
		end
	end

	Players.PlayerRemoving:Connect(function(p)
		save(p)
		cache[p] = nil
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			save(p)
		end
	end)

	-- Client "verimi ver" derse: yüklenene kadar en fazla 10 sn bekle
	Remotes.Function("GetPlayerData").OnServerInvoke = function(player: Player)
		local t = 0
		while not cache[player] and t < 10 do
			t += task.wait(0.1)
		end
		return DataService.Payload(player)
	end

	task.spawn(function()
		while true do
			task.wait(Economy.AutosaveSeconds)
			for _, p in Players:GetPlayers() do
				save(p)
			end
		end
	end)
end

return DataService
