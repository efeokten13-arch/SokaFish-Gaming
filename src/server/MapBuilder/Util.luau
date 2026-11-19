--!nonstrict
-- Küçük yardımcılar: parça üretme, yazı, zemin yüksekliği.
local Workspace = game:GetService("Workspace")

local Util = {}

function Util.fresh(className, name, parent)
	parent = parent or Workspace
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function setup(p, name, size, cf, color, material)
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.fromRGB(163, 162, 165)
	p.Material = material or Enum.Material.Plastic
end

function Util.part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	setup(p, name, size, cf, color, material)
	p.Parent = parent
	return p
end

function Util.wedge(parent, name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	setup(p, name, size, cf, color, material)
	p.Parent = parent
	return p
end

-- Elips: blok parça + küre mesh (Ball şekli tek boyuta zorlar)
function Util.ball(parent, name, size, cf, color, material)
	local p = Util.part(parent, name, size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- Silindir: ekseni yerel X
function Util.cyl(parent, name, length, diameter, cf, color, material)
	return Util.part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

-- Dikey direk (y0 -> y1)
function Util.pole(parent, name, x, z, y0, y1, diameter, color, material)
	return Util.cyl(
		parent, name, y1 - y0, diameter,
		CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		color, material
	)
end

-- İki nokta arasında düz kalas (genişlik X, kalınlık Y)
function Util.beam(parent, name, p0, p1, width, thick, color, material)
	local len = (p1 - p0).Magnitude
	return Util.part(parent, name, Vector3.new(width, thick, len), CFrame.lookAt((p0 + p1) / 2, p1), color, material)
end

-- İki nokta arasında yuvarlak halat / boru
function Util.rod(parent, name, p0, p1, diameter, color, material)
	local len = (p1 - p0).Magnitude
	return Util.cyl(
		parent, name, len, diameter,
		CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0),
		color, material
	)
end

-- Görünmez bölge (havuz, slot gibi)
function Util.zone(parent, name, size, cf)
	local p = Util.part(parent, name, size, cf)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

function Util.noCollide(p)
	p.CanCollide = false
	return p
end

-- Parçanın bir yüzüne yazı koy
function Util.sign(part, face, text, textColor)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = textColor or Color3.fromRGB(255, 244, 214)
	t.Parent = g
	return g
end

function Util.billboard(part, text, offsetY, widthPx)
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromOffset(widthPx or 180, 36)
	b.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	b.MaxDistance = 140
	b.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.TextStrokeTransparency = 0.3
	t.Parent = b
	return b
end

-- Sadece arazinin yüksekliği (su yok sayılır)
function Util.groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local r = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return r and r.Position.Y
end

function Util.light(part, brightness, range, color)
	local l = Instance.new("PointLight")
	l.Brightness = brightness or 1
	l.Range = range or 20
	l.Color = color or Color3.fromRGB(255, 214, 150)
	l.Parent = part
	return l
end

return Util
