--!strict
-- Plazada lider tablosu (bu sunucudaki oyuncular). Çeşmeye bakan ahşap pano:
--   sol sütun: en zengin (para) · sağ sütun: en iyi balık (en nadir, eşitse en pahalı)
-- Her birkaç saniyede bir yenilenir. Haritaya dokunmaz; Workspace.PlazaLeaderboard modelini kendisi kurar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Map = require(Config:WaitForChild("Map"))
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))

local DataService = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("DataService"))

local LeaderboardService = {}

local ROWS = 5
local REFRESH = 5 -- sn
-- Plazanın kuzeybatı köşegeni (yollar ve saksılar arasındaki boşluk), merkeze bu kadar uzak
local ANGLE = math.rad(225)
local DISTANCE = 34

local WOOD = Color3.fromRGB(110, 76, 46)
local BOARD = Color3.fromRGB(28, 48, 66)
local CREAM = Color3.fromRGB(255, 244, 220)
local GOLD = Color3.fromRGB(255, 205, 80)
local MUTED = Color3.fromRGB(150, 170, 190)

type Row = { rank: TextLabel, name: TextLabel, value: TextLabel }
local moneyRows: { { Row } } = {} -- her yüz için ayrı satırlar (ön yüz yeterli ama ileride arka da kullanılabilir)
local fishRows: { { Row } } = {}

-- 1250 -> "1,250"
local function formatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, color: Color3, font: Enum.Font, align: Enum.TextXAlignment): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.Font = font
	t.TextScaled = true
	t.TextXAlignment = align
	t.Parent = parent
	return t
end

-- Bir sütun: başlık + ROWS satır
local function column(parent: Instance, title: string, x: number): { Row }
	local col = Instance.new("Frame")
	col.BackgroundTransparency = 1
	col.Position = UDim2.fromScale(x, 0.2)
	col.Size = UDim2.fromScale(0.46, 0.76)
	col.Parent = parent

	local head = label(col, title, GOLD, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
	head.Size = UDim2.fromScale(1, 0.15)

	local rows: { Row } = {}
	for i = 1, ROWS do
		local y = 0.18 + (i - 1) * 0.165
		local bg = Instance.new("Frame")
		bg.Position = UDim2.fromScale(0, y)
		bg.Size = UDim2.fromScale(1, 0.145)
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.BackgroundTransparency = if i % 2 == 1 then 0.92 else 0.96
		bg.Parent = col
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.25, 0)
		c.Parent = bg

		local rank = label(bg, "#" .. i, if i == 1 then GOLD else MUTED, Enum.Font.FredokaOne, Enum.TextXAlignment.Left)
		rank.Position = UDim2.fromScale(0.03, 0.1)
		rank.Size = UDim2.fromScale(0.12, 0.8)
		local name = label(bg, "-", CREAM, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		name.Position = UDim2.fromScale(0.16, 0.12)
		name.Size = UDim2.fromScale(0.44, 0.76)
		local value = label(bg, "", CREAM, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
		value.Position = UDim2.fromScale(0.6, 0.12)
		value.Size = UDim2.fromScale(0.37, 0.76)
		table.insert(rows, { rank = rank, name = name, value = value })
	end
	return rows
end

local function build()
	local old = Workspace:FindFirstChild("PlazaLeaderboard")
	if old then
		old:Destroy()
	end
	local P = Map.Plaza
	local g = Map.GrassY
	local center = Vector3.new(P.x, g, P.z)
	local pos = center + Vector3.new(math.cos(ANGLE) * DISTANCE, 0, math.sin(ANGLE) * DISTANCE)
	-- pano çeşmeye baksın (ön yüz = LookVector)
	local face = CFrame.lookAt(pos, Vector3.new(center.X, g, center.Z))

	local model = Instance.new("Model")
	model.Name = "PlazaLeaderboard"
	local W, H, LIFT = 16, 9, 3 -- pano genişliği, yüksekliği, yerden yüksekliği
	for _, side in { -1, 1 } do
		part(model, "Post", Vector3.new(0.9, LIFT + H + 1, 0.9), face * CFrame.new(side * (W / 2 + 0.2), (LIFT + H + 1) / 2, 0.3), WOOD, Enum.Material.Wood)
	end
	part(model, "Frame", Vector3.new(W + 0.8, H + 0.8, 0.4), face * CFrame.new(0, LIFT + H / 2, 0.15), WOOD, Enum.Material.Wood)
	part(model, "Roof", Vector3.new(W + 2.4, 0.5, 2.2), face * CFrame.new(0, LIFT + H + 0.9, 0.2), Color3.fromRGB(176, 84, 60), Enum.Material.Slate)
	local board = part(model, "Board", Vector3.new(W, H, 0.3), face * CFrame.new(0, LIFT + H / 2, 0), BOARD, Enum.Material.WoodPlanks)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = board

	local title = label(gui, "🏆 TOP FISHERS", GOLD, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
	title.Position = UDim2.fromScale(0.05, 0.03)
	title.Size = UDim2.fromScale(0.9, 0.14)

	moneyRows = { column(gui, "💰 Richest", 0.03) }
	fishRows = { column(gui, "🐟 Best Catch", 0.51) }

	model.PrimaryPart = board
	model.Parent = Workspace
end

-- Oyuncunun en iyi balığı: en yüksek nadirlik, eşitse en yüksek satış fiyatı
local function bestFish(caught: { [string]: number }?): (string?, number)
	local bestId, bestScore = nil, -1
	for id, count in caught or {} do
		local def = (Fish :: any)[id]
		if def and count > 0 then
			local tier = table.find(Rarities.Order, def.rarity) or 0
			local score = tier * 1e7 + def.sell
			if score > bestScore then
				bestId, bestScore = id, score
			end
		end
	end
	return bestId, bestScore
end

local function fill(rows: { Row }, entries: { { name: string, text: string, color: Color3? } })
	for i, row in rows do
		local e = entries[i]
		row.name.Text = if e then e.name else "-"
		row.value.Text = if e then e.text else ""
		row.value.TextColor3 = if e and e.color then e.color else CREAM
	end
end

local function refresh()
	local rich, fish = {}, {}
	for _, p in Players:GetPlayers() do
		local data = DataService.Get(p) :: any
		if data then
			table.insert(rich, { player = p, money = data.money or 0 })
			local id, score = bestFish(data.caught)
			if id then
				table.insert(fish, { player = p, id = id, score = score })
			end
		end
	end
	table.sort(rich, function(a, b)
		return a.money > b.money
	end)
	table.sort(fish, function(a, b)
		return a.score > b.score
	end)

	local richEntries, fishEntries = {}, {}
	for i = 1, math.min(ROWS, #rich) do
		table.insert(richEntries, { name = rich[i].player.DisplayName, text = "$" .. formatNumber(rich[i].money) })
	end
	for i = 1, math.min(ROWS, #fish) do
		local def = (Fish :: any)[fish[i].id]
		local r = (Rarities :: any)[def.rarity]
		table.insert(fishEntries, { name = fish[i].player.DisplayName, text = def.displayName, color = r and r.color })
	end
	for _, rows in moneyRows do
		fill(rows, richEntries)
	end
	for _, rows in fishRows do
		fill(rows, fishEntries)
	end
end

function LeaderboardService.Init()
	build()
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
