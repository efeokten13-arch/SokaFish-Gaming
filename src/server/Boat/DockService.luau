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
local allPoints: { { j: Jetty, c: Vector3 } } = {} -- tüm iskele noktaları (yer yoksa yakındakilere bakılır)

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
	-- Sudaki oyuncu "yüzme" halindeyken Roblox tırmanmaya geçmez; client (Boat/DockClient) bu bilgilerle
	-- oyuncuyu merdivenden yukarı çıkarır.
	m:SetAttribute("Edge", Vector3.new(edge.X, 0, edge.Z))
	m:SetAttribute("Out", out)
	m:SetAttribute("Top", top)
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

-- Teknenin su hizasındaki gövdesinin yarı eni / yarı boyu (direk ve yelkenler sayılmaz).
-- Teknenin kendi ekseninde ölçülür (ileri = pivotun LookVector'ü). Bir kez hesaplanıp teknede saklanır.
local function footprint(boat: Model): (number, number)
	local w, l = boat:GetAttribute("FootW") :: number?, boat:GetAttribute("FootL") :: number?
	if w and l then
		return w, l
	end
	local pivot = boat:GetPivot()
	local maxX, maxZ = 2, 4
	for _, p in boat:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and p.Position.Y < pivot.Position.Y + 5 then
			local h = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local c = pivot:PointToObjectSpace(p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, 0, h.Z * sz)))
					maxX = math.max(maxX, math.abs(c.X))
					maxZ = math.max(maxZ, math.abs(c.Z))
				end
			end
		end
	end
	boat:SetAttribute("FootW", maxX)
	boat:SetAttribute("FootL", maxZ)
	return maxX, maxZ
end

-- Çarpışma kontrolünde sayılmayacaklar: teknenin kendisi, arazi, oyuncular
local function ignoreList(boat: Model): { Instance }
	local list: { Instance } = { boat, Workspace.Terrain }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- Bir iskele noktasının çevresinde tekneye uygun yer: suda (burun ve kıç dahil), hiçbir şeye çarpmıyor
local function tryAt(j: Jetty, at: Vector3, halfW: number, halfL: number, ignore: { Instance }, gaps: { number }): CFrame?
	-- burun açık denize baksın
	local fwd = if FishingWater.IsWater(at + j.axis * (halfL + 15)) then j.axis else -j.axis
	for _, gap in gaps do
		for _, along in { 0, 10, -10, 20, -20 } do
			for _, s in { 1, -1 } do
				local pos = at + j.axis * along + j.side * s * (j.width / 2 + halfW + gap)
				if FishingWater.IsWater(pos) and FishingWater.IsWater(pos + fwd * halfL) and FishingWater.IsWater(pos - fwd * halfL) then
					local cf = CFrame.lookAt(Vector3.new(pos.X, WATER_Y, pos.Z), Vector3.new(pos.X, WATER_Y, pos.Z) + fwd)
					-- sadece su hizası (-1.25 .. 4.75): iskele güvertesinin altında kalır, direkler hesaba girmez
					local box = CFrame.new(pos.X, 1.75, pos.Z) * cf.Rotation
					if not blocked(box, Vector3.new(halfW * 2 + 1, 6, halfL * 2 + 1), ignore) then
						return cf
					end
				end
			end
		end
	end
	return nil
end

-- İskelenin yanında yer bul: önce basılan nokta, sonra yakındaki diğer iskele noktaları (en yakından başlayarak).
-- Dönüş: teknenin yeri ve oyuncunun ineceği iskele noktası
local function berthFor(j: Jetty, at: Vector3, boat: Model): (CFrame?, Jetty, Vector3)
	local halfW, halfL = footprint(boat)
	local ignore = ignoreList(boat)
	local gaps = { 1.5, 5, 10 }
	local cf = tryAt(j, at, halfW, halfL, ignore, gaps)
	if cf then
		return cf, j, at
	end
	local near = {}
	for _, p in allPoints do
		local d = (p.c - at).Magnitude
		if d > 1 and d < 150 then
			table.insert(near, { p = p, d = d })
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	for _, n in near do
		cf = tryAt(n.p.j, n.p.c, halfW, halfL, ignore, gaps)
		if cf then
			return cf, n.p.j, n.p.c
		end
	end
	return nil, j, at
end

-- Yanaşacak yer yoksa: iskeleden biraz açıkta boş bir yer (sergideki teknelerin içine değil)
local function openWaterSpot(j: Jetty, at: Vector3, boat: Model): CFrame?
	local halfW, halfL = footprint(boat)
	return tryAt(j, at, halfW, halfL, ignoreList(boat), { 20, 35, 55, 80 })
end

local function stop(boat: Model)
	if boat.PrimaryPart then
		boat.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		boat.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
	end
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
	-- teknesi denizde yoksa önce iskeleden uzakta (boş suda) yarat; sonra yanına yerleştir
	local boat = findBoat(player)
	if not boat then
		local spawnAt = at + j.side * 150
		for _, s in { 1, -1 } do
			local p = at + j.side * s * 150
			if FishingWater.IsWater(p) then
				spawnAt = p
				break
			end
		end
		BoatService.BringTo(player, CFrame.new(spawnAt.X, WATER_Y, spawnAt.Z))
		local t = 0
		while not boat and t < 2 do
			t += task.wait(0.1)
			boat = findBoat(player)
		end
	end
	if boat then
		local seated = boat:FindFirstChildWhichIsA("VehicleSeat", true)
		if seated and seated.Occupant then
			seated.Occupant.Sit = false -- başkası oturuyorsa kaldır (zaten sadece sahibi oturabilir)
		end
		local cf = berthFor(j, at, boat) or openWaterSpot(j, at, boat)
		if cf then
			boat:PivotTo(cf)
		else
			DataService.Notify(player, "Couldn't bring your boat here, try another dock.", RED)
		end
		stop(boat)
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

-- Teknedeyken "⚓ Dock here": tekne iskelenin yanına yanaşır, oyuncu iskeleye iner
local function dock(player: Player, j: Jetty, at: Vector3)
	if busy[player] then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local boat = findBoat(player)
	local seat = hum and hum.SeatPart
	if not hum or not boat or not seat or not seat:IsDescendantOf(boat) then
		return
	end
	local cf, landJ, landAt = berthFor(j, at, boat)
	if not cf then
		DataService.Notify(player, "No room to dock here. Try another dock.", RED)
		return
	end
	busy[player] = true
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	hum.Sit = false
	task.wait(0.1)
	boat:PivotTo(cf)
	stop(boat)
	-- oyuncu, teknenin yanaştığı iskele noktasına iner
	if char and char.Parent then
		local stand = Vector3.new(landAt.X, landJ.top + 3, landAt.Z)
		char:PivotTo(CFrame.lookAt(stand, Vector3.new(cf.Position.X, stand.Y, cf.Position.Z)))
	end
	DataService.Notify(player, "⚓ Docked! Press B on the dock to board again.", Color3.fromRGB(150, 230, 255))
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
		table.insert(allPoints, { j = j, c = c })
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
			-- teknedeyken görünür (client gizler/gösterir: Boat/DockClient); tekne iskeleden uzakta durduğu için mesafe büyük
			local dockPrompt = Instance.new("ProximityPrompt")
			dockPrompt.Name = "DockPrompt"
			dockPrompt.ActionText = "⚓ Dock here"
			dockPrompt.ObjectText = "Dock"
			dockPrompt.KeyboardKeyCode = Enum.KeyCode.E -- teknedeyken Steer düğmesi kapalı, E boşta
			dockPrompt.HoldDuration = 0
			dockPrompt.MaxActivationDistance = 40
			dockPrompt.RequiresLineOfSight = false
			dockPrompt.Parent = anchor
			dockPrompt.Triggered:Connect(function(player)
				dock(player, j, c)
			end)
		end
	end
end

local function build()
	local old = Workspace:FindFirstChild("DockExtras")
	if old then
		old:Destroy()
	end
	table.clear(allPoints)
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
