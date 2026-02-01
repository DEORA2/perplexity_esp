-- PerplexityESP v2.0 ULTRA CLEAN - Player ESP ONLY (ZERO Item ESP)
-- Minimap + Arrows + Boxes + Health - 100% bulletproof

local PerplexityESP = {}
PerplexityESP.__index = PerplexityESP

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Storage (NO ItemESPObjects)
local ESPObjects = {}
local Settings = {
    Enabled = true,
    TeamCheck = true,
    DistanceCheck = false,
    MaxDistance = 5000,
    RainbowSpeed = 1,
    RainbowEnabled = false,
    MinimapEnabled = true,
    ArrowsEnabled = true
}

-- Colors
local Colors = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Team = Color3.fromRGB(0, 255, 0),
    Wallbang = Color3.fromRGB(255, 255, 0),
    HealthGreen = Color3.fromRGB(0, 255, 0),
    HealthRed = Color3.fromRGB(255, 0, 0),
    Black = Color3.fromRGB(0, 0, 0),
    MinimapLocal = Color3.fromRGB(0, 255, 0)
}

local Minimap = {Size = 200, Position = Vector2.new(20, 20), CenterDotSize = 8, PlayerDotSize = 4}
local Arrows = {Size = 30, DistanceFromEdge = 50}

local function CreateDrawing(type, props)
    local obj = Drawing.new(type)
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

local function WorldToScreen(pos)
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen
end

local function DistanceFromCamera(part)
    return (Camera.CFrame.Position - part.Position).Magnitude
end

local function RainbowColor()
    return Color3.fromHSV((tick() * Settings.RainbowSpeed) % 1, 1, 1)
end

-- ESP Object (Player ONLY)
local ESPObject = {}
ESPObject.__index = ESPObject

function ESPObject.new(target)
    local self = setmetatable({}, ESPObject)
    self.Target = target
    self.Drawings = {}
    self:AddDrawings()
    return self
end

function ESPObject:AddDrawings()
    local d = self.Drawings
    d.Box = CreateDrawing("Square", {Filled = false, Thickness = 2, Color = Colors.Enemy, Visible = false})
    d.Fill = CreateDrawing("Square", {Filled = true, Transparency = 0.5, Visible = false})
    d.HealthBG = CreateDrawing("Square", {Filled = true, Transparency = 0.8, Color = Colors.Black, Visible = false})
    d.Health = CreateDrawing("Square", {Filled = true, Thickness = 3, Visible = false})
    d.Name = CreateDrawing("Text", {Size = 14, Center = true, Outline = true, Font = 2, Visible = false})
    d.Dist = CreateDrawing("Text", {Size = 12, Center = true, Outline = true, Font = 2, Visible = false})
    d.Tracer = CreateDrawing("Line", {Thickness = 2, Transparency = 1, Visible = false})
    
    -- FIXED Arrow (Square only)
    self.Arrow = CreateDrawing("Square", {
        Filled = true, Thickness = 2, Color = Colors.Enemy, 
        Transparency = 0.8, Visible = false, Rotation = 45
    })
    
    self.Dot = CreateDrawing("Circle", {
        Radius = Minimap.PlayerDotSize, Filled = true, 
        Color = Colors.Enemy, Visible = false
    })
end

function ESPObject:Update()
    local char = self.Target.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root then return end
    
    local pos3d = root.Position
    local pos2d, onScreen = WorldToScreen(pos3d)
    local dist = DistanceFromCamera(root)
    
    if Settings.DistanceCheck and dist > Settings.MaxDistance then return end
    
    local color = Settings.TeamCheck and self.Target.Team == LocalPlayer.Team 
        and Colors.Team or Colors.Enemy
    if Settings.RainbowEnabled then color = RainbowColor() end
    
    local size = Vector2.new(2000/dist, 3000/dist)
    
    if onScreen then
        -- Main ESP
        self.Drawings.Box.PointA = pos2d - size/2
        self.Drawings.Box.PointB = pos2d + size/2
        self.Drawings.Box.Color = color
        self.Drawings.Box.Visible = true
        
        self.Drawings.Fill.PointA = pos2d - size/2
        self.Drawings.Fill.PointB = pos2d + size/2
        self.Drawings.Fill.Color = color
        self.Drawings.Fill.Visible = true
        
        -- Health
        local health = hum and hum.Health / hum.MaxHealth or 1
        self.Drawings.HealthBG.PointA = pos2d - Vector2.new(12, size.Y/2)
        self.Drawings.HealthBG.PointB = pos2d - Vector2.new(8, -size.Y/2)
        self.Drawings.HealthBG.Visible = true
        
        self.Drawings.Health.PointA = pos2d - Vector2.new(12, size.Y/2 * (2-health))
        self.Drawings.Health.PointB = pos2d - Vector2.new(8, -size.Y/2)
        self.Drawings.Health.Color = Color3.new(
            Colors.HealthGreen.R * (1-health) + Colors.HealthRed.R * health,
            Colors.HealthGreen.G * (1-health) + Colors.HealthRed.G * health,
            Colors.HealthGreen.B * (1-health) + Colors.HealthRed.B * health
        )
        self.Drawings.Health.Visible = true
        
        self.Drawings.Name.Text = self.Target.Name
        self.Drawings.Name.Position = pos2d + Vector2.new(0, -size.Y/2 - 20)
        self.Drawings.Name.Color = color
        self.Drawings.Name.Visible = true
        
        self.Drawings.Dist.Text = math.floor(dist) .. "m"
        self.Drawings.Dist.Position = pos2d + Vector2.new(0, size.Y/2 + 5)
        self.Drawings.Dist.Color = Colors.Wallbang
        self.Drawings.Dist.Visible = true
        
        self.Drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2 + 100)
        self.Drawings.Tracer.To = pos2d
        self.Drawings.Tracer.Color = color
        self.Drawings.Tracer.Visible = true
        
        self.Arrow.Visible = false
        
    else
        -- Off-screen arrow
        local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        local angle = math.atan2(pos3d.Y - Camera.CFrame.Position.Y, pos3d.X - Camera.CFrame.Position.X)
        local arrowPos = screenCenter + Vector2.new(math.cos(angle), math.sin(angle)) * (Arrows.DistanceFromEdge + Arrows.Size/2)
        
        self.Arrow.Position = arrowPos
        self.Arrow.Rotation = math.deg(angle) + 45
        self.Arrow.Color = color
        self.Arrow.Visible = true
    end
    
    -- Minimap
    if Settings.MinimapEnabled then
        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if localRoot then
            local relPos = (pos3d - localRoot.Position)
            local radarPos = Minimap.Position + Vector2.new(Minimap.Size/2, Minimap.Size/2) + Vector2.new(relPos.X, relPos.Z) * 0.2
            self.Dot.Position = radarPos
            self.Dot.Color = color
            self.Dot.Visible = true
        end
    end
end

function ESPObject:Destroy()
    for _, d in pairs(self.Drawings) do pcall(function() d:Remove() end) end
    pcall(function() self.Arrow:Remove() end)
    pcall(function() self.Dot:Remove() end)
end

-- Global Minimap
local MinimapBG = CreateDrawing("Square", {
    Filled = true, Color = Colors.Black, Transparency = 0.3, Visible = true
})
MinimapBG.PointA = Vector2.new(Minimap.Position.X, Minimap.Position.Y)
MinimapBG.PointB = Vector2.new(Minimap.Position.X + Minimap.Size, Minimap.Position.Y + Minimap.Size)

local LocalDot = CreateDrawing("Circle", {
    Radius = Minimap.CenterDotSize, Filled = true, Color = Colors.MinimapLocal, Visible = true
})

-- API
function PerplexityESP:CreateESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not ESPObjects[p] then
            ESPObjects[p] = ESPObject.new(p)
            p.CharacterAdded:Connect(function()
                if ESPObjects[p] then ESPObjects[p]:Destroy() end
                task.wait(1)
                ESPObjects[p] = ESPObject.new(p)
            end)
        end
    end
end

function PerplexityESP:Toggle() Settings.Enabled = not Settings.Enabled end
function PerplexityESP:SetTeamCheck(b) Settings.TeamCheck = b end
function PerplexityESP:SetRainbow(b) Settings.RainbowEnabled = b end
function PerplexityESP:ToggleMinimap() 
    Settings.MinimapEnabled = not Settings.MinimapEnabled
    MinimapBG.Visible = Settings.MinimapEnabled
    LocalDot.Visible = Settings.MinimapEnabled
end
function PerplexityESP:ToggleArrows() Settings.ArrowsEnabled = not Settings.ArrowsEnabled end
function PerplexityESP:SetDistanceCheck(b, d) 
    Settings.DistanceCheck = b
    if d then Settings.MaxDistance = d end
end

local Conn
function PerplexityESP:Start()
    Conn = RunService.Heartbeat:Connect(function()
        if not Settings.Enabled then return end
        for p, esp in pairs(ESPObjects) do
            if p.Parent then esp:Update()
            else esp:Destroy() ESPObjects[p] = nil end
        end
        if Settings.MinimapEnabled then
            local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if localRoot then LocalDot.Position = Minimap.Position + Vector2.new(Minimap.Size/2, Minimap.Size/2) end
        end
    end)
end

function PerplexityESP:Stop()
    if Conn then Conn:Disconnect() end
    for _, esp in pairs(ESPObjects) do esp:Destroy() end
    ESPObjects = {}
end

PerplexityESP:CreateESP()
PerplexityESP:Start()
_G.PerplexityESP = PerplexityESP
print("✅ PerplexityESP ULTRA CLEAN loaded! (No Item ESP)")
return PerplexityESP
