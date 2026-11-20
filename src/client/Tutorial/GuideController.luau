--!nonstrict
-- Rehber (client): ekranın üstünde görev yazısı, balık tutma adımında ipuçları,
-- havuz adımında adanın tepeden sinematiği. Server: GuideService ("GuideStep").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local GuideController = {}

local player = Players.LocalPlayer
local gui, card, title, tip
local step = nil

local GOLD = Color3.fromRGB(255, 214, 80)

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "GuideGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("Frame")
	card.Name = "Quest"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -24) -- altta ortada (üstteki yön okuyla çakışmasın)
	card.Size = UDim2.fromOffset(460, 44)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(20, 28, 42)
	card.BackgroundTransparency = 0.15
	card.Visible = false
	card.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = card
	local st = Instance.new("UIStroke")
	st.Color = GOLD
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = card

	title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 21
	title.TextWrapped = true
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.TextColor3 = GOLD
	title.Parent = card

	tip = Instance.new("TextLabel")
	tip.Size = UDim2.new(1, 0, 0, 22)
	tip.BackgroundTransparency = 1
	tip.Font = Enum.Font.GothamMedium
	tip.TextSize = 17
	tip.TextWrapped = true
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.TextColor3 = Color3.fromRGB(235, 240, 250)
	tip.Visible = false
	tip.Parent = card
end

local function pop()
	local s = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = card
	s.Scale = 1.15
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function setTip(text)
	tip.Text = text or ""
	tip.Visible = text ~= nil
	if text then
		pop()
	end
end

-- Havuz adımı: adanın tepesinden alçalarak dönen kamera, sonra karaktere dönüş
local function poolCinematic(pool)
	if not pool or not pool:IsA("BasePart") or player:GetAttribute("InCutscene") then
		return
	end
	player:SetAttribute("InCutscene", true)
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local c = pool.Position
	local t0 = os.clock()
	local DUR = 5.5
	local from = cam.CFrame
	local conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / DUR, 0, 1)
		local e = t * t * (3 - 2 * t)
		local a = 0.5 + e * 1.4
		local h = 230 - e * 150
		local r = 20 + e * 70
		local target = CFrame.lookAt(c + Vector3.new(math.cos(a) * r, h, math.sin(a) * r), c)
		local blend = math.clamp((os.clock() - t0) / 0.8, 0, 1)
		cam.CFrame = from:Lerp(target, blend)
	end)
	task.wait(DUR)
	conn:Disconnect()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local back = CFrame.lookAt(root.Position - root.CFrame.LookVector * 14 + Vector3.new(0, 6, 0), root.Position)
		local tw = TweenService:Create(cam, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = back })
		tw:Play()
		tw.Completed:Wait()
	end
	cam.CameraType = Enum.CameraType.Custom
	player:SetAttribute("InCutscene", false)
end

local TIPS = {
	rod = "Walk into the Rod Shop and grab the Branch Rod.",
	boat = "The little Rowboat costs only $1. Hold E (or tap) to buy it!",
	fish = "Tap the big fishing button (or press F) to throw your line into the water.",
	pool = "Find the Fish Pool on your island's dock and put your fish in. They earn coins every minute!",
}

function GuideController.Init()
	build()
	Remotes.Event("GuideStep").OnClientEvent:Connect(function(id, text, pool)
		step = id
		if id == "done" or not text then
			card.Visible = false
			return
		end
		card.Visible = true
		title.Text = "🎯 " .. text
		setTip(TIPS[id])
		pop()
		if id == "pool" then
			task.spawn(poolCinematic, pool)
		end
	end)
	-- balık tutma adımında canlı ipuçları
	Remotes.Event("FishBite").OnClientEvent:Connect(function()
		if step == "fish" then
			setTip("🐟 A fish bit! Press the button NOW!")
		end
	end)
	Remotes.Event("FishHooked").OnClientEvent:Connect(function()
		if step == "fish" then
			setTip("Hold the button to move the green bar up, let go to drop it. Keep the fish inside the green bar!")
		end
	end)
	Remotes.Event("FishingEnded").OnClientEvent:Connect(function(reason)
		if step ~= "fish" then
			return
		end
		if reason == "early" then
			setTip("Too early! Wait until the fish bites, then press.")
		elseif reason == "late" then
			setTip("Too slow! Press quickly when the fish bites. Try again!")
		elseif reason == "escaped" then
			setTip("It got away! Keep the fish inside the green bar. Try again!")
		elseif reason == "notwater" or reason == "far" then
			setTip("Face the water and try again!")
		end
	end)
end

return GuideController
