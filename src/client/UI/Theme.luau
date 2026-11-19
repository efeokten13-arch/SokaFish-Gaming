--!nonstrict
-- Ortak arayüz stili: koyu yarı saydam "cam" butonlar, ince çerçeve, küçük ikon ve etiket.
-- Tüm HUD butonları buradan stil alır; renkleri/boyutları tek yerden değiştirin.
local Theme = {}

Theme.Panel = Color3.fromRGB(18, 24, 34)
Theme.PanelTransparency = 0.25
Theme.Stroke = Color3.fromRGB(255, 255, 255)
Theme.StrokeTransparency = 0.7
Theme.Active = Color3.fromRGB(255, 196, 64)
Theme.Text = Color3.fromRGB(240, 244, 250)
Theme.ButtonSize = 54
Theme.Gap = 16 -- etiket için butonlar arası boşluk

-- Var olan bir TextButton'u yuvarlak cam butona çevirir (işlevine dokunmaz)
function Theme.StyleRound(b, labelText)
	b.Size = UDim2.fromOffset(Theme.ButtonSize, Theme.ButtonSize)
	b.BackgroundColor3 = Theme.Panel
	b.BackgroundTransparency = Theme.PanelTransparency
	b.AutoButtonColor = true
	for _, c in b:GetChildren() do
		if c:IsA("UIStroke") or c:IsA("UIPadding") or c:IsA("UICorner") then
			c:Destroy()
		end
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	local st = Instance.new("UIStroke")
	st.Name = "ThemeStroke"
	st.Color = Theme.Stroke
	st.Transparency = Theme.StrokeTransparency
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		pad[side] = UDim.new(0, 13)
	end
	pad.Parent = b
	if labelText then
		local old = b:FindFirstChild("ThemeLabel")
		if old then
			old:Destroy()
		end
		local t = Instance.new("TextLabel")
		t.Name = "ThemeLabel"
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.Size = UDim2.new(1, 40, 0, 14)
		t.Position = UDim2.new(0.5, 0, 1, 14)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 11
		t.TextColor3 = Theme.Text
		t.TextStrokeTransparency = 0.5
		t.Text = labelText
		t.Parent = b
	end
	return b
end

-- Yeni yuvarlak buton
function Theme.Button(parent, name, icon, labelText, position, anchor)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = icon
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Theme.Text
	b.Position = position
	b.AnchorPoint = anchor or Vector2.new(0, 0.5)
	Theme.StyleRound(b, labelText)
	b.Parent = parent
	return b
end

-- Açık/kapalı durumu (ör. Sprint açıkken altın çerçeve)
function Theme.SetActive(b, on)
	local st = b:FindFirstChild("ThemeStroke")
	if st then
		st.Color = on and Theme.Active or Theme.Stroke
		st.Transparency = on and 0 or Theme.StrokeTransparency
		st.Thickness = on and 2.5 or 1.5
	end
	b.BackgroundTransparency = on and 0.1 or Theme.PanelTransparency
end

-- Sol sütundaki sıra: dikey merkezden uzaklık (index: -2,-1,1,2 ...)
function Theme.LeftColumn(index)
	local step = Theme.ButtonSize + Theme.Gap
	return UDim2.new(0, 14, 0.5, (index - (index > 0 and 0.5 or -0.5)) * step)
end

return Theme
