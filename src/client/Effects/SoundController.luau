--!nonstrict
-- Sesler (client): kasaba müziği, balık sesleri. Yağmur/gök gürültüsü StormClouds içinde.
-- Ayarlar: Config/Audio.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SoundController = {}

local player = Players.LocalPlayer
local music: Sound
local baseVolume = Audio.MusicStartVolume
local stormy = false

local function setMusicVolume(v, time)
	TweenService:Create(music, TweenInfo.new(time or 2), { Volume = v }):Play()
end

local function targetVolume()
	return if stormy then Audio.MusicStormVolume else baseVolume
end

-- Tek seferlik ses (2D)
function SoundController.Play(id: string, volume: number?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(15, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

-- StormClouds çağırır: oyuncu bulutun altına girip çıkınca müzik kısılır/açılır
function SoundController.SetStormy(on: boolean)
	if on == stormy then
		return
	end
	stormy = on
	if music then
		setMusicVolume(targetVolume(), 1.5)
	end
end

function SoundController.IsStormy(): boolean
	return stormy
end

local function startMusic()
	music = Instance.new("Sound")
	music.Name = "TownMusic"
	music.Volume = Audio.MusicStartVolume
	music.Looped = false
	music.Parent = SoundService
	local i = 0
	local function nextTrack()
		i = i % #Audio.Music + 1
		music.SoundId = Audio.Music[i]
		music.TimePosition = 0
		music:Play()
	end
	music.Ended:Connect(nextTrack)
	nextTrack()
	-- ilk girişten bir süre sonra kısılsın
	task.delay(Audio.MusicFadeAfter, function()
		baseVolume = Audio.MusicVolume
		setMusicVolume(targetVolume(), 4)
	end)
end

function SoundController.Init()
	startMusic()
	-- balık vurdu: su sesi
	Remotes.Event("FishBite").OnClientEvent:Connect(function()
		SoundController.Play(Audio.Splash, 0.5, 1.15)
	end)
	-- balık tutuldu: su sesi + kısa müzik; fırtınadaysa gök gürültüsü de
	Remotes.Event("FishCaught").OnClientEvent:Connect(function()
		SoundController.Play(Audio.Splash, 0.7, 0.9)
		task.delay(0.15, function()
			SoundController.Play(Audio.CatchJingle, 0.45)
		end)
		if stormy then
			SoundController.Play(Audio.StormCatch, 0.8, 1.1)
		end
	end)
end

return SoundController
