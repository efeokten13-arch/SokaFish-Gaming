--!nonstrict
-- Eğitim körfezine (Gunnery Range) girince ortam değişir: hafif sis, serin/gizemli renk, liman sesi.
-- Körfezden çıkınca her şey yavaşça eski haline döner. Ayarlar aşağıdaki MOOD tablosunda.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audio = require(ReplicatedStorage.Shared.Config.Audio)

local M = {}

local MOOD = {
	Atmosphere = {
		Density = 0.42,
		Offset = 0.15,
		Color = Color3.fromRGB(178, 192, 196),
		Decay = Color3.fromRGB(86, 106, 112),
		Glare = 0,
		Haze = 2.4,
	},
	CC = { Brightness = -0.03, Contrast = 0.12, Saturation = -0.14, TintColor = Color3.fromRGB(222, 236, 238) },
	Exposure = -0.15,
	AmbienceVolume = 0.35,
	FadeIn = 3,
	FadeOut = 2.5,
}
local NEUTRAL_CC = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }

-- körfez sınırları (TrainFrame'e göre): s = kapıdan içeri, u = yana
local S_MIN, S_MAX, U_MAX, Y_MAX = -5, 440, 290, 280

local function tween(inst, t, props)
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine), props)
	tw:Play()
	return tw
end

function M.Init()
	task.spawn(function()
		-- akış (streaming) yüzünden parça geç gelebilir: uyarı basmadan bekle
		local framePart
		repeat
			local atoll = Workspace:FindFirstChild("Atoll")
			local training = atoll and atoll:FindFirstChild("Training")
			framePart = training and training:FindFirstChild("TrainFrame")
			if not framePart then
				task.wait(1)
			end
		until framePart
		local frame = framePart.CFrame -- sabit; akış (streaming) parçayı kaldırsa da kullanılır

		local inside = false
		local saved
		local cc
		local sound = Instance.new("Sound")
		sound.Name = "BayAmbience"
		sound.SoundId = Audio.BayAmbience
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService

		local function enter()
			local atm = Lighting:FindFirstChildOfClass("Atmosphere")
			saved = { Exposure = Lighting.ExposureCompensation }
			if atm then
				saved.Atmosphere = {}
				for k in MOOD.Atmosphere do
					saved.Atmosphere[k] = atm[k]
				end
				tween(atm, MOOD.FadeIn, MOOD.Atmosphere)
			end
			if cc then
				cc:Destroy()
			end
			cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "BayMood"
			for k, v in NEUTRAL_CC do
				cc[k] = v
			end
			cc.Parent = Lighting
			tween(cc, MOOD.FadeIn, MOOD.CC)
			tween(Lighting, MOOD.FadeIn, { ExposureCompensation = saved.Exposure + MOOD.Exposure })
			if not sound.IsPlaying then
				sound:Play()
			end
			tween(sound, MOOD.FadeIn, { Volume = MOOD.AmbienceVolume })
		end

		local function leave()
			local atm = Lighting:FindFirstChildOfClass("Atmosphere")
			if atm and saved and saved.Atmosphere then
				tween(atm, MOOD.FadeOut, saved.Atmosphere)
			end
			if saved then
				tween(Lighting, MOOD.FadeOut, { ExposureCompensation = saved.Exposure })
			end
			if cc then
				local old = cc
				cc = nil
				tween(old, MOOD.FadeOut, NEUTRAL_CC).Completed:Once(function()
					old:Destroy()
				end)
			end
			tween(sound, MOOD.FadeOut, { Volume = 0 }).Completed:Once(function()
				if not inside then
					sound:Stop()
				end
			end)
		end

		while true do
			local cam = Workspace.CurrentCamera
			if cam then
				local p = cam.CFrame.Position
				local lp = frame:PointToObjectSpace(p)
				local s, u = -lp.Z, lp.X
				local now = s > S_MIN and s < S_MAX and math.abs(u) < U_MAX and p.Y < Y_MAX
				if now ~= inside then
					inside = now
					if now then
						enter()
					else
						leave()
					end
				end
			end
			task.wait(0.4)
		end
	end)
end

return M
