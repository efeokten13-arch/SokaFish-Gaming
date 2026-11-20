--!strict
-- Olta 3D modelini Part'lardan kodla üretir. Renkler Config/Economy.luau -> Rods[...].look
-- Olta -Z yönünde uzanır. Handle = PrimaryPart (tutma noktası).
-- Uçta "TipAttachment" var: misina (Beam) buraya bağlanır.
--
-- Kullanım: local rod = RodModelBuilder.Build("IronRod")
-- Önce ReplicatedStorage.Assets.Rods.<id> 3D modeli aranır (Handle + Mesh + TipAttachment).
-- Bulunamazsa aşağıdaki basit Part oltası çizilir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))

local RodModelBuilder = {}

local function newPart(model: Model, name: string, size: Vector3, color: Color3, reflect: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Reflectance = reflect
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function template(rodId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Rods")
	local t = folder and folder:FindFirstChild(rodId)
	if t and t:IsA("Model") and t.PrimaryPart then
		return t
	end
	return nil
end

-- 3D modelin kendi boyu (Handle'dan uca)
local function templateLength(m: Model): number
	local att = m:FindFirstChild("TipAttachment", true) :: Attachment?
	return if att then math.abs(att.Position.Z) / 0.88 else 8
end

-- length verilirse olta o boya ölçeklenir (elde / vitrinde farklı boy için)
function RodModelBuilder.Build(rodId: string, length: number?): Model
	local rods = Economy.Rods :: any
	local def = rods[rodId] or rods[Economy.StarterRod]
	local t = template(rodId) or template(Economy.StarterRod)
	if t then
		local model = t:Clone()
		model.Name = "Rod"
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			end
		end
		local want = length or def.length
		if want then
			model:ScaleTo(model:GetScale() * want / templateLength(t))
		end
		return model
	end
	local look = def.look
	local reflect = look.reflect or 0

	local model = Instance.new("Model")
	model.Name = "Rod"

	local handle = newPart(model, "Handle", Vector3.new(0.22, 0.22, 1.1), look.handle, 0)
	handle.CFrame = CFrame.new()
	model.PrimaryPart = handle

	local function add(name: string, size: Vector3, color: Color3, offset: CFrame, shape: Enum.PartType?): Part
		local p = newPart(model, name, size, color, reflect)
		if shape then
			p.Shape = shape
		end
		p.CFrame = offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
		return p
	end

	add("Reel", Vector3.new(0.32, 0.32, 0.32), look.reel, CFrame.new(0, -0.22, -0.2), Enum.PartType.Ball)
	add("Shaft", Vector3.new(0.12, 0.12, 3), look.shaft, CFrame.new(0, 0, -0.55 - 1.5))
	local tip = add("Tip", Vector3.new(0.07, 0.07, 2.5), look.shaft, CFrame.new(0, 0, -3.55 - 1.25))

	local att = Instance.new("Attachment")
	att.Name = "TipAttachment"
	att.Position = Vector3.new(0, 0, -1.25)
	att.Parent = tip

	return model
end

return RodModelBuilder
