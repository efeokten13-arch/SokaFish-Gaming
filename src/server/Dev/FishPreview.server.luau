-- Sadece Studio'da çalışır: tüm balıkları spawn'ın yanında yan yana döndürerek gösterir.
-- Canlı oyunda hiçbir şey yapmaz. İşi bitince bu dosyayı silebilirsiniz.

local RunService = game:GetService("RunService")
local ENABLED = false -- giriş yerinde balık modellerini göstermek için true yapın
if not ENABLED or not RunService:IsStudio() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared:WaitForChild("Config"):WaitForChild("Fish"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))

-- Spawn noktasını bul, yoksa haritanın ortası
local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local origin = if spawn then spawn.Position + Vector3.new(0, 6, -14) else Vector3.new(0, 15, 0)

-- Nadirliğe göre sırala
local ids = {}
for id in Fish do
	table.insert(ids, id)
end
table.sort(ids, function(a, b)
	return table.find(Rarities.Order, Fish[a].rarity) < table.find(Rarities.Order, Fish[b].rarity)
end)

local folder = Instance.new("Folder")
folder.Name = "FishPreview"
folder.Parent = Workspace

local models = {}
local x = -(#ids - 1) * 3.5
for _, id in ids do
	local m = FishModelBuilder.Build(id)
	if m then
		m.Parent = folder
		table.insert(models, { model = m, pos = origin + Vector3.new(x, 0, 0) })

		-- İsim etiketi
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffset = Vector3.new(0, 2.5, 0)
		gui.AlwaysOnTop = true
		gui.Parent = m.PrimaryPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = Fish[id].displayName .. "\n" .. Fish[id].rarity
		label.TextColor3 = Rarities[Fish[id].rarity].color
		label.TextStrokeTransparency = 0.3
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = gui
	end
	x += 7
end

-- Yavaşça döndür
local angle = 0
RunService.Heartbeat:Connect(function(dt)
	angle += dt * 0.8
	for _, entry in models do
		entry.model:PivotTo(CFrame.new(entry.pos) * CFrame.Angles(0, angle, 0))
	end
end)

print("[Dev] FishPreview: " .. #models .. " balık spawn'ın yanında")
