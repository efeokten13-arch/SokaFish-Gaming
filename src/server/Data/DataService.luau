--!strict
-- Oyuncu verisi: yükle, kaydet, eriş.
-- Basit DataStore sürümü. İleride ProfileStore'a geçmek önerilir (session lock, veri kaybını önler).
-- NOT: Studio'da test için Game Settings -> Security -> "Enable Studio Access to API Services" açık olmalı.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Boats = require(Config:WaitForChild("Boats"))

local store = DataStoreService:GetDataStore("PlayerData_v1")

export type PlayerData = {
	money: number,
	boat: string,
	rod: string,
	bait: string,
	storage: { string }, -- teknedeki balık id'leri
	pool: { string }, -- havuzdaki balık id'leri
	lastOnline: number,
}

local function defaultData(): PlayerData
	return {
		money = Economy.StartingMoney,
		boat = Boats.Starter,
		rod = "BasicRod",
		bait = "BasicBait",
		storage = {},
		pool = {},
		lastOnline = os.time(),
	}
end

local DataService = {}
local cache: { [Player]: PlayerData } = {}

function DataService.Get(player: Player): PlayerData?
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
		warn("Veri yüklenemedi:", player.Name, result)
	end
	cache[player] = data
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
	Players.PlayerRemoving:Connect(function(p)
		save(p)
		cache[p] = nil
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			save(p)
		end
	end)
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
