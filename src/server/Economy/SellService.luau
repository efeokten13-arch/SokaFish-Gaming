--!strict
-- Balık pazarı: tezgahların önündeki SELL FISH plakasına basınca client çantayı açar; satış buradan (SellFish).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Fish = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Fish"))
local DataService = require(script.Parent.Parent.Data.DataService)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local SellService = {}

function SellService.SellSlot(data: any, slotIndex: number): number
	local fishId = data.storage[slotIndex]
	if not fishId then
		return 0
	end
	local price = Fish[fishId] and Fish[fishId].sell or 0
	table.remove(data.storage, slotIndex)
	data.money += price
	return price
end

local function sellAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if #data.storage == 0 then
		DataService.Notify(player, "You have no fish to sell", Color3.fromRGB(255, 140, 120))
		return
	end
	local n, total = #data.storage, 0
	while #data.storage > 0 do
		total += SellService.SellSlot(data, 1)
	end
	DataService.Notify(player, "Sold " .. n .. " fish for $" .. total, Color3.fromRGB(255, 214, 80))
	Remotes.Event("CoinBurst"):FireClient(player, total)
	DataService.Push(player)
end

-- Oyuncu balık pazarının (bir SellCounter'ın) yakınında mı?
local SELL_RANGE = 45
function SellService.NearMarket(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local market = Workspace:FindFirstChild("FishMarket")
	if not root or not market then
		return false
	end
	for _, d in market:GetDescendants() do
		if d.Name == "SellCounter" and d:IsA("BasePart") and (d.Position - root.Position).Magnitude < SELL_RANGE then
			return true
		end
	end
	return false
end

-- Çantadan seçili balıkları sat (client: SellFish(slotList) ; slotList nil = hepsi)
local function sellSelected(player: Player, slots: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not SellService.NearMarket(player) then
		DataService.Notify(player, "Go to the Fish Market to sell your fish!", Color3.fromRGB(255, 140, 120))
		return
	end
	if slots == nil then
		sellAll(player)
		return
	end
	if type(slots) ~= "table" then
		return
	end
	local pick = {}
	for _, v in slots do
		if type(v) == "number" and v == v then
			local i = math.floor(v)
			if data.storage[i] and not table.find(pick, i) then
				table.insert(pick, i)
			end
		end
	end
	if #pick == 0 then
		return
	end
	table.sort(pick, function(a, b)
		return a > b
	end)
	local total = 0
	for _, i in pick do
		total += SellService.SellSlot(data, i)
	end
	DataService.Notify(player, "Sold " .. #pick .. " fish for $" .. total, Color3.fromRGB(255, 214, 80))
	Remotes.Event("CoinBurst"):FireClient(player, total)
	DataService.Push(player)
end

-- Tezgahın önündeki zemine parlayan "SELL FISH" plakası. Oyuncu üstüne basınca client çantayı açar (Inventory.luau).
-- (Eskiden "Sell all fish" basılı tutma düğmesi vardı; yanlışlıkla her şeyi sattığı için kaldırıldı.)
local function hook(counter: Instance)
	if not counter:IsA("BasePart") or counter.Name ~= "SellCounter" or counter:GetAttribute("HasPad") then
		return
	end
	counter:SetAttribute("HasPad", true)
	local old = counter:FindFirstChild("SellPrompt")
	if old then
		old:Destroy()
	end
	local market = counter:FindFirstAncestor("FishMarket") or counter.Parent
	local platform = market and market:FindFirstChild("Platform") :: BasePart?
	-- plaka tezgahın platform kenarına bakan tarafında
	local center = if platform then platform.Position else counter.Position
	local dirZ = if counter.Position.Z > center.Z then 1 else -1
	local topY = if platform then platform.Position.Y + platform.Size.Y / 2 else counter.Position.Y - 4
	local pos = Vector3.new(counter.Position.X, topY + 0.06, counter.Position.Z + dirZ * 4.2)
	local function slab(name: string, size: Vector3, y: number, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, if dirZ > 0 then 0 else math.pi, 0)
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = market
		return p
	end
	local rim = slab("SellPadRim", Vector3.new(12, 0.12, 4.6), 0, Color3.fromRGB(255, 196, 60), Enum.Material.Neon)
	local pad = slab("SellPad", Vector3.new(3.8, 0.14, 11.2), 0.02, Color3.fromRGB(60, 40, 24), Enum.Material.WoodPlanks)
	-- yazı üst yüzde parçanın Z ekseni boyunca akar: uzun kenarı dünyada X'e çevir, okuyan oyuncu dışarıdan baksın
	pad.CFrame = CFrame.new(pad.Position) * CFrame.Angles(0, if dirZ > 0 then -math.pi / 2 else math.pi / 2, 0)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Parent = pad
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "💰 SELL FISH"
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 220, 110)
	t.Parent = g
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 90)
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = rim
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 215, 100))
	sp.LightEmission = 1
	sp.Size = NumberSequence.new(0.35, 0)
	sp.Lifetime = NumberRange.new(0.8, 1.4)
	sp.Rate = 4
	sp.Speed = NumberRange.new(1, 2)
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Parent = rim
end

-- Kıyıdaki balık pazarı (Workspace.FishMarket): ada tarafında ve iskele tarafında birer SellCounter
function SellService.Init()
	Remotes.Event("SellFish").OnServerEvent:Connect(sellSelected)
	task.spawn(function()
		local market = Workspace:WaitForChild("FishMarket", 60)
		if not market then
			warn("[SellService] Workspace.FishMarket yok (MapBuilder.IslandLife ile kurulmalı)")
			return
		end
		for _, d in market:GetDescendants() do
			hook(d)
		end
		market.DescendantAdded:Connect(hook)
	end)
end

return SellService
