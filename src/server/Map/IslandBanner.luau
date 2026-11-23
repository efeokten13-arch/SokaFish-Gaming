--!strict
-- Oyuncu adası tabelası + bayrak. Ada sahiplenilince (MapService.AssignIsland) kurulur, oyuncu çıkınca kalkar.
--   Tabela: iskelenin ucunda, iki yüzlü (denizden ve adadan okunur): oyuncunun avatarı + "<isim>'s Island"
--   Bayrak: spawn noktasının yanında, oyuncuya özel renkte
-- Haritanın kendisine dokunmaz; her şey adanın içindeki "OwnerBanner" modelinde.

local Players = game:GetService("Players")

local IslandBanner = {}

local WOOD = Color3.fromRGB(120, 84, 52)
local BOARD = Color3.fromRGB(40, 90, 120)
local CREAM = Color3.fromRGB(255, 244, 220)

-- Bayrak renkleri: aynı oyuncu hep aynı rengi alır
local FLAG_COLORS = {
	Color3.fromRGB(230, 70, 60),
	Color3.fromRGB(240, 160, 40),
	Color3.fromRGB(245, 215, 70),
	Color3.fromRGB(80, 190, 100),
	Color3.fromRGB(50, 170, 200),
	Color3.fromRGB(70, 110, 230),
	Color3.fromRGB(160, 90, 220),
	Color3.fromRGB(235, 100, 170),
}

local function colorFor(userId: number): Color3
	return FLAG_COLORS[(math.abs(userId) % #FLAG_COLORS) + 1]
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

-- Tabelanın bir yüzü: solda avatar, sağda isim
local function signFace(board: BasePart, face: Enum.NormalId, name: string): ImageLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = board

	local img = Instance.new("ImageLabel")
	img.Name = "Avatar"
	img.AnchorPoint = Vector2.new(0, 0.5)
	img.Position = UDim2.new(0, 10, 0.5, 0)
	img.Size = UDim2.fromScale(0.3, 0.84)
	img.BackgroundColor3 = CREAM
	img.BackgroundTransparency = 0.2
	img.Parent = gui
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = img
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = img

	local t = Instance.new("TextLabel")
	t.Name = "Owner"
	t.AnchorPoint = Vector2.new(1, 0.5)
	t.Position = UDim2.new(1, -10, 0.5, 0)
	t.Size = UDim2.fromScale(0.64, 0.8)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = CREAM
	t.Text = name .. "'s\nIsland"
	t.Parent = gui
	return img
end

local function buildSign(model: Model, dock: BasePart, player: Player): { ImageLabel }
	-- Dock: CFrame.lookAt(uç, uç + u) -> LookVector denize doğru, sağda fener var; tabela sol tarafa
	local cf = dock.CFrame
	local top = dock.Position.Y + dock.Size.Y / 2
	local base = cf.Position - cf.RightVector * 3.9 - cf.LookVector * 2
	local up = Vector3.yAxis
	for _, side in { -1.6, 1.6 } do
		local p = base + cf.RightVector * side
		part(model, "SignPost", Vector3.new(0.5, 7, 0.5), CFrame.new(p.X, top + 3.5, p.Z), WOOD, Enum.Material.Wood)
	end
	local boardCf = CFrame.lookAt(Vector3.new(base.X, top + 5.6, base.Z), Vector3.new(base.X, top + 5.6, base.Z) + cf.LookVector, up)
	local board = part(model, "SignBoard", Vector3.new(5.6, 2.4, 0.3), boardCf, BOARD, Enum.Material.WoodPlanks)
	board.CanCollide = false
	-- tabelanın etrafına ince çerçeve
	local frame = part(model, "SignFrame", Vector3.new(6, 2.8, 0.2), boardCf, WOOD, Enum.Material.Wood)
	frame.CanCollide = false
	return {
		signFace(board, Enum.NormalId.Front, player.DisplayName),
		signFace(board, Enum.NormalId.Back, player.DisplayName),
	}
end

-- Bayrak ölçüleri (stud). Adalar ana adadan ~500 stud uzakta; oradan seçilebilsin diye büyük.
local FLAG_POLE_HEIGHT = 42
local FLAG_SIZE = Vector2.new(15, 9.5)

local function buildFlag(model: Model, spawnPart: BasePart, player: Player)
	local color = colorFor(player.UserId)
	local ground = spawnPart.Position.Y - spawnPart.Size.Y / 2
	local p = spawnPart.Position + Vector3.new(6, 0, 6)
	local height = FLAG_POLE_HEIGHT
	part(model, "FlagPole", Vector3.new(0.9, height, 0.9), CFrame.new(p.X, ground + height / 2, p.Z), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
	local knob = part(model, "FlagKnob", Vector3.new(1.6, 1.6, 1.6), CFrame.new(p.X, ground + height + 0.6, p.Z), Color3.fromRGB(235, 190, 70), Enum.Material.Metal)
	knob.Shape = Enum.PartType.Ball
	knob.CanCollide = false
	local flag = part(model, "Flag", Vector3.new(FLAG_SIZE.X, FLAG_SIZE.Y, 0.2), CFrame.new(p.X + FLAG_SIZE.X / 2 + 0.45, ground + height - FLAG_SIZE.Y / 2 - 0.5, p.Z), color, Enum.Material.Fabric)
	flag.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = flag
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Text = "🐟"
		t.Parent = gui
	end
end

-- Adaya sahip tabelası + bayrak koy (player nil ise kaldır)
function IslandBanner.Set(island: Instance, player: Player?)
	local old = island:FindFirstChild("OwnerBanner")
	if old then
		old:Destroy()
	end
	if not player then
		return
	end

	local model = Instance.new("Model")
	model.Name = "OwnerBanner"
	local avatars: { ImageLabel } = {}
	local dock = island:FindFirstChild("Dock")
	if dock and dock:IsA("BasePart") then
		avatars = buildSign(model, dock, player)
	end
	local spawnPart = island:FindFirstChild("Spawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		buildFlag(model, spawnPart, player)
	end
	model.Parent = island

	-- avatar resmi internetten gelir (bekletir), tabelayı bekletmesin
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and model.Parent then
			for _, img in avatars do
				img.Image = image
			end
		end
	end)
end

return IslandBanner
