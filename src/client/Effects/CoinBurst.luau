--!nonstrict
-- Satıştan para gelince: ekranın ortasında altın paralar fışkırır, sonra üstteki para kutucuğuna uçar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local CoinBurst = {}

local player = Players.LocalPlayer
local gui

local GOLD = Color3.fromRGB(255, 205, 60)

-- Üstteki para kutucuğunun ekrandaki yeri
local function targetPos()
	local hud = player.PlayerGui:FindFirstChild("HUD")
	local pill = hud and hud:FindFirstChild("Money", true)
	if pill and pill:IsA("GuiObject") then
		return pill.AbsolutePosition + Vector2.new(22, pill.AbsoluteSize.Y / 2)
	end
	local cam = workspace.CurrentCamera
	return Vector2.new(cam.ViewportSize.X / 2 - 60, 24)
end

local function coin(size)
	local c = Instance.new("Frame")
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Size = UDim2.fromOffset(size, size)
	c.BackgroundColor3 = GOLD
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = c
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(200, 140, 20)
	st.Thickness = 3
	st.Parent = c
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "$"
	t.TextColor3 = Color3.fromRGB(170, 110, 10)
	t.Parent = c
	c.Parent = gui
	return c
end

local function burst(amount)
	local view = workspace.CurrentCamera.ViewportSize
	local center = Vector2.new(view.X / 2, view.Y / 2)
	-- büyük "+$X" yazısı
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(center.X, center.Y - 70)
	label.Size = UDim2.fromOffset(400, 70)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 56
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(110, 70, 0)
	label.Text = "+$" .. tostring(amount)
	label.Parent = gui
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = label
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.3, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.45, function()
			label:Destroy()
		end)
	end)

	local n = math.clamp(math.floor(amount / 10) + 6, 8, 18)
	local target = targetPos()
	for i = 1, n do
		local c = coin(math.random(26, 36))
		c.Position = UDim2.fromOffset(center.X, center.Y)
		-- önce etrafa saçıl
		local a = math.random() * math.pi * 2
		local r = math.random(60, 170)
		local spread = center + Vector2.new(math.cos(a) * r, math.sin(a) * r * 0.7)
		TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(spread.X, spread.Y) }):Play()
		-- sonra sırayla para kutucuğuna uç
		task.delay(0.45 + i * 0.05, function()
			local tw = TweenService:Create(c, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
				Size = UDim2.fromOffset(16, 16),
			})
			tw:Play()
			tw.Completed:Wait()
			c:Destroy()
			-- kutucuk hafifçe zıplasın
			local hud = player.PlayerGui:FindFirstChild("HUD")
			local pill = hud and hud:FindFirstChild("Money", true)
			if pill then
				local s = pill:FindFirstChild("BumpScale") or Instance.new("UIScale")
				s.Name = "BumpScale"
				s.Parent = pill
				s.Scale = 1.12
				TweenService:Create(s, TweenInfo.new(0.15), { Scale = 1 }):Play()
			end
		end)
	end
end

function CoinBurst.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "CoinBurstGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = player:WaitForChild("PlayerGui")
	Remotes.Event("CoinBurst").OnClientEvent:Connect(function(amount)
		if type(amount) == "number" and amount > 0 then
			burst(amount)
		end
	end)
end

return CoinBurst
