--!strict
-- İskele kolaylıkları (haritaya dokunmaz; oyun açılınca Workspace.DockExtras içine kurulur):
--   1) "⛵ Board boat" noktaları: iskelede B'ye (mobilde dokun) basınca teknen iskelenin yanına gelir ve dümene oturursun.
--   2) Merdivenler: iskelelerin iki yanında, suya düşen oyuncu tırmanıp güverteye çıkar.
-- İskele = suyun üstündeki dar, yatay ahşap güverte (Pier, FishMarket, oyuncu adaları, Atoll altında). Yeni iskele eklenirse
-- otomatik tanınır. Merdiven / binme noktası sadece yanında su olan yerlere konur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishingWater = require(Shared:WaitForChild("FishingWater"))

local Server = script.Parent.Parent
local DataService = require(Server.Data.DataService)
local BoatService = require(Server.Boat.BoatService)

local DockService = {}

-- İskelelerin arandığı yerler
local ROOTS = { "Pier", "FishMarket", "PrivateIslands", "Atoll" }
local BOARD_SPACING = 30 -- binme noktaları arası (stud)
local LADDER_SPACING = 45 -- merdiven çiftleri arası (stud)
local LADDER_HEIGHT = 12 -- güvertenin 10 stud altından 2 stud üstüne
local WATER_Y = 0.65 -- tekne merkezinin yüksekliği (BoatService ile aynı)

local WOOD = Color3.fromRGB(92, 64, 40)
local RED = Color3.fromRGB(255, 120, 110)

type Jetty = { part: BasePart, axis: Vector3, side: Vector3, length: number, width: number, top: number }

local extras: Folder
local busy: { [Player]: boolean } = {}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- Dar, yatay, ahşap ve su seviyesine yakın parça = iskele güvertesi
local function asJetty(p: BasePart): Jetty?
	if p.Material ~= Enum.Material.WoodPlanks or p.Size.Y > 1.3 then
		return nil
	end
	local top = p.Position.Y + p.Size.Y / 2
	if top < 4 or top > 9 then
		return nil
	end
	local long, narrow = math.max(p.Size.X, p.Size.Z), math.min(p.Size.X, p.Size.Z)
	if long < 14 or narrow > 12 or math.abs(p.CFrame.UpVector.Y) < 0.98 then
		return nil
	end
	local axis = flat(if p.Size.X > p.Size.Z then p.CFrame.RightVector else p.CFrame.LookVector)
	return {
		part = p,
		axis = axis,
		side = Vector3.new(-axis.Z, 0, axis.X),
		length = long,
		width = narrow,
		top = top,
	}
end

local function findJetties(): { Jetty }
	local list = {}
	for _, name in ROOTS do
		local root = Workspace:FindFirstChild(name)
		for _, d in root and root:GetDescendants() or {} do
			if d:IsA("BasePart") then
				local j = asJetty(d)
				if j then
					table.insert(list, j)
				end
			end
		end
	end
	return list
end

-- İskele boyunca noktalar (güverte ortası, deniz seviyesinde): her 6 stud'da bir aday denenir,
-- ok(nokta) olanlardan birbirine en az `spacing` uzak olanlar seçilir. Denizdeki uçtan başlar
-- (karadan denize uzanan iskelelerde ilk nokta açık uçta olsun).
local function pointsAlong(j: Jetty, spacing: number, ok: (Vector3) -> boolean): { Vector3 }
	local c = Vector3.new(j.part.Position.X, 0, j.part.Position.Z)
	local half = j.length / 2 - 2
	local a, b = c - j.axis * half, c + j.axis * half
	if not FishingWater.IsWater(b + j.axis * 4) and FishingWater.IsWater(a - j.axis * 4) then
		a, b = b, a
	end
	-- b = açık uç
	local dir = (a - b).Unit
	local pts: { Vector3 } = {}
	local d = 0
	while d <= half * 2 do
		local p = b + dir * d
		local far = true
		for _, q in pts do
			if (q - p).Magnitude < spacing then
				far = false
				break
			end
		end
		if far and ok(p) then
			table.insert(pts, p)
		end
		d += 6
	end
	return pts
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Wood
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Merdiven: görünen ahşap korkuluk + basamaklar, tırmanmayı sağlayan görünmez TrussPart
local function ladder(parent: Instance, edge: Vector3, out: Vector3, axis: Vector3, top: number)
	local m = Instance.new("Model")
	m.Name = "Ladder"
	local bottom = top + 2 - LADDER_HEIGHT
	local cy = (top + 2 + bottom) / 2
	local base = edge + out * 1

	local truss = Instance.new("TrussPart")
	truss.Name = "Climb"
	truss.Size = Vector3.new(2, LADDER_HEIGHT, 2)
	truss.CFrame = CFrame.lookAt(Vector3.new(base.X, cy, base.Z), Vector3.new(base.X, cy, base.Z) + out)
	truss.Anchored = true
	truss.Transparency = 1
	truss.Parent = m

	local railPos = edge + out * 0.7
	for _, s in { -0.85, 0.85 } do
		local p = railPos + axis * s
		part(m, "Rail", Vector3.new(0.3, LADDER_HEIGHT, 0.3), CFrame.new(p.X, cy, p.Z), WOOD)
	end
	local y = top - 0.6
	while y > -1.5 do
		part(m, "Rung", Vector3.new(1.9, 0.22, 0.22), CFrame.fromMatrix(Vector3.new(railPos.X, y, railPos.Z), axis, Vector3.yAxis), WOOD)
		y -= 1.4
	end
	m.Parent = parent
end

local function buildLadders(j: Jetty, folder: Folder)
	-- her yan (sağ / sol) ayrı: yanı su olan noktalara merdiven
	for _, s in { 1, -1 } do
		local out = j.side * s
		local function waterSide(c: Vector3): boolean
			return FishingWater.IsWater(c + out * (j.width / 2 + 3))
		end
		for _, c in pointsAlong(j, LADDER_SPACING, waterSide) do
			ladder(folder, c + out * (j.width / 2), out, j.axis, j.top)
		end
	end
end

-- Oyuncunun denizdeki teknesi (BoatService Workspace.Boats içine koyar)
local function findBoat(player: Player): Model?
	local boats = Workspace:FindFirstChild("Boats")
	for _, b in boats and boats:GetChildren() or {} do
		if b:IsA("Model") and b:GetAttribute("OwnerUserId") == player.UserId then
			return b
		end
	end
	return nil
end

-- Bu konumda tekne başka bir şeye çarpıyor mu? (iskele, sergideki tekneler, kayalar)
local function blocked(cf: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, hit in Workspace:GetPartBoundsInBox(cf, size, params) do
		if hit.CanCollide and not hit:IsA("Terrain") then
			return true
		end
	end
	return false
end

-- İskelenin yanında tekne için boş ve sulu bir yer bul
local function berthFor(j: Jetty, at: Vector3, boat: Model, player: Player): CFrame?
	local size = boat:GetExtentsSize()
	local halfW, halfL = math.min(size.X, size.Z) / 2, math.max(size.X, size.Z) / 2
	-- burun açık denize baksın
	local fwd = if FishingWater.IsWater(at + j.axis * (halfL + 15)) then j.axis else -j.axis
	local ignore: { Instance } = { boat, Workspace.Terrain }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, extra in { 1.5, 6, 12 } do
		for _, s in { 1, -1 } do
			local pos = at + j.side * s * (j.width / 2 + halfW + extra)
			local cf = CFrame.lookAt(Vector3.new(pos.X, WATER_Y, pos.Z), Vector3.new(pos.X, WATER_Y, pos.Z) + fwd)
			local box = CFrame.new(pos.X, WATER_Y + size.Y / 2, pos.Z) * cf.Rotation
			if FishingWater.IsWater(pos) and not blocked(box, Vector3.new(halfW * 2, size.Y, halfL * 2), ignore) then
				return cf
			end
		end
	end
	return nil
end

local function board(player: Player, j: Jetty, at: Vector3)
	if busy[player] then
		return
	end
	local data = DataService.Get(player) :: any
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not hum or hum.SeatPart then
		return
	end
	if #(data.ownedBoats or {}) == 0 then
		DataService.Notify(player, "You don't have a boat yet! Buy one from Shipwright Nils.", RED)
		return
	end
	busy[player] = true
	-- teknesi yoksa yarat / varsa getir (önce iskeleden uzağa; sonra yanına tam yerleştir)
	local away = at + j.side * (j.width / 2 + 40)
	BoatService.BringTo(player, CFrame.new(away.X, WATER_Y, away.Z))
	local boat = findBoat(player)
	local t = 0
	while not boat and t < 2 do
		t += task.wait(0.1)
		boat = findBoat(player)
	end
	if boat then
		local cf = berthFor(j, at, boat, player)
		if cf then
			boat:PivotTo(cf)
		else
			DataService.Notify(player, "No room here, your boat is waiting a bit further out.", RED)
		end
		if boat.PrimaryPart then
			boat.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
			boat.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		end
		local seat = boat:FindFirstChildWhichIsA("VehicleSeat", true)
		if seat and not seat.Occupant and char and char.Parent then
			char:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
			task.wait(0.2)
			seat:Sit(hum)
		end
	end
	task.wait(1)
	busy[player] = nil
end

local function buildBoardPoints(j: Jetty, folder: Folder)
	-- iki yanından biri su olmalı
	local reach = j.width / 2 + 6
	local function nearWater(c: Vector3): boolean
		return FishingWater.IsWater(c + j.side * reach) or FishingWater.IsWater(c - j.side * reach)
	end
	for _, c in pointsAlong(j, BOARD_SPACING, nearWater) do
		do
			local anchor = part(folder, "BoardPoint", Vector3.new(1, 1, 1), CFrame.new(c.X, j.top + 2.5, c.Z), WOOD)
			anchor.Transparency = 1
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BoardPrompt"
			prompt.ActionText = "⛵ Board boat"
			prompt.ObjectText = "Dock"
			prompt.KeyboardKeyCode = Enum.KeyCode.B -- E başka düğmelerde (Steer, Browse) kullanılıyor
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = anchor
			prompt.Triggered:Connect(function(player)
				board(player, j, c)
			end)
		end
	end
end

local function build()
	local old = Workspace:FindFirstChild("DockExtras")
	if old then
		old:Destroy()
	end
	extras = Instance.new("Folder")
	extras.Name = "DockExtras"
	local ladders = Instance.new("Folder")
	ladders.Name = "Ladders"
	ladders.Parent = extras
	local points = Instance.new("Folder")
	points.Name = "BoardPoints"
	points.Parent = extras

	local jetties = findJetties()
	for i, j in jetties do
		buildLadders(j, ladders)
		buildBoardPoints(j, points)
		if i % 10 == 0 then
			task.wait() -- su kontrolü raycast yapar; sunucuyu bir anda yormasın
		end
	end
	extras.Parent = Workspace
	print(string.format("[DockService] %d iskele: %d merdiven, %d binme noktası", #jetties, #ladders:GetChildren(), #points:GetChildren()))
end

function DockService.Init()
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
	task.spawn(function()
		-- harita yüklensin
		Workspace:WaitForChild("Pier", 60)
		Workspace:WaitForChild("PrivateIslands", 30)
		build()
	end)
end

return DockService
