-- PerplexityESP v2.0 CLEAN - Player ESP Only (Item ESP REMOVED)
-- Minimap Radar + Off-Screen Arrows + Full Player ESP
-- 100% Clean - No Item ESP bloat

local PerplexityESP = {}
PerplexityESP.__index = PerplexityESP

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Internal Storage (ItemESPObjects REMOVED)
local ESPObjects = {}
local Settings = {
    Enabled = true,
    TeamCheck = true,
    DistanceCheck = false,
    MaxDistance = 5000,
    RainbowSpeed = 1,
    PerformanceMode = false,
    MinimapEnabled = true,
    ArrowsEnabled = true,
    RainbowEnabled = false  -- Added missing setting
}

-- Colors (Item colors REMOVED)
local Colors = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Team = Color3.fromRGB(0, 255, 0),
    Wallbang = Color3.fromRGB(255, 255, 0),
    HealthGreen = Color3.fromRGB(0, 255, 0),
    HealthRed = Color3.fromRGB(255, 0, 0),
    Black = Color3.fromRGB(0, 0, 0),
    MinimapPlayer = Color3.fromRGB(255, 0, 0),
    MinimapLocal = Color3.fromRGB(0, 255, 0)
}

-- Settings
local Minimap = {Size = 200, Position = Vector2.new(20, 20), CenterDotSize = 8, PlayerDotSize = 4, FOV = 500}
local Arrows = {Size = 30, DistanceFromEdge = 50}

-- Drawing Utilities
local function CreateDrawing(type, properties)
    local obj = Drawing.new(type)
    for prop, value in pairs(properties or {}) do
        obj[prop] = value
    end
    return obj
end

local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function DistanceFromCamera(pos)
    return (Camera.CFrame.Position - pos.Position).Magnitude
end

local function RainbowColor()
    return Color3.fromHSV((tick() * Settings.RainbowSpeed) % 1, 1, 1)
end

-- FIXED: Simplified WorldToRadar
local function WorldToRadar(worldPos)
    local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localPos then return Minimap.Position end
    
    local center = localPos.Position
    local relativePos = worldPos - center
    local radarPos = Vector2.new(relativePos.X, relativePos.Z)
    local scale = Minimap.Size / 2 / Minimap.FOV
    return Minimap.Position + Vector2.new(Minimap.Size/2, Minimap.Size/2) + radarPos * scale
end

-- FIXED: Arrow helper (Square-based)
local function GetOffScreenArrowPos(rootPart)
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local angle = math.atan2(rootPart.Position.Y - Camera.CFrame.Position.Y, rootPart.Position.X - Camera.CFrame.Position.X)
    return screenCenter + Vector2.new(math.cos(angle), math.sin(angle)) * (Arrows.DistanceFromEdge + Arrows.Size/2)
end

-- ESP Object Class (ALL ERRORS FIXED)
local ESPObject = {}
ESPObject.__index = ESPObject

function ESPObject.new(target)
    local self = setmetatable({}, ESPObject)
    self.Target = target
    self.Character = target.Character
    self.Enabled = true
    self.Drawings = {}
    self:AddDrawings()
    return self
end

function ESPObject:AddDrawings()
    local drawings = self.Drawings
    
    drawings.Box = CreateDrawing("Square", {Filled = false, Thickness = 2, Visible = false, Color = Colors.Enemy})
    drawings.BoxFill = CreateDrawing("Square", {Filled = true, Thickness = 1, Transparency = 0.5, Visible = false})
    drawings.HealthBG = CreateDrawing("Square", {Filled = true, Thickness = 1, Transparency = 0.8, Visible = false})
    drawings.HealthBar = CreateDrawing("Square", {Filled = true, Thickness = 3, Visible = false})
    drawings.Name = CreateDrawing("Text", {Size = 14, Center = true, Outline = true, Font = 2, Visible = false})
    drawings.Distance = CreateDrawing("Text", {Size = 12, Center = true, Outline = true, Font = 2, Visible = false})
    drawings.Tracer = CreateDrawing("Line", {Thickness = 2, Transparency = 1, Visible = false})
    
    -- FIXED: Arrow uses Square NOT Triangle
    if Settings.ArrowsEnabled then
        self.Arrow = CreateDrawing("Square", {
            Filled = true,
            Thickness = 2,
            Color = Colors.Enemy,
            Transparency = 0.8,
            Visible = false,
            Rotation = 45
        })
    end
    
    -- Minimap Dot
    if Settings.MinimapEnabled then
        self.MinimapDot = CreateDrawing("Circle", {
            Radius = Minimap.PlayerDotSize,
            Filled = true,
            Thickness = 1,
            Color = Colors.Enemy,
            Transparency = 1,
            Visible = true
        })
    end
    
    -- Chams
    pcall(function()
        if self.Target ~= LocalPlayer and self.Character then
            self.Highlight = Instance.new("Highlight")
            self.Highlight.Parent = self.Character
            self.Highlight.FillColor = Colors.Enemy
            self.Highlight.OutlineColor = Colors.Enemy
            self.Highlight.FillTransparency = 0.5
            self.Highlight.OutlineTransparency = 0
        end
    end)
end

function ESPObject:Update()
    if not self.Enabled or not self.Character then return end
    local rootPart = self.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = self.Character:FindFirstChild("Humanoid")
    if not rootPart then return end
    
    local rootPos3D = rootPart.Position
    local rootPos, onScreen = WorldToScreen(rootPos3D)
    local dist = DistanceFromCamera(rootPart)
    
    if Settings.DistanceCheck and dist > Settings.MaxDistance then
        self:SetVisible(false)
        return
    end
    
    local color = Settings.TeamCheck and self.Target.Team == LocalPlayer.Team and Colors.Team or Colors.Enemy
    if Settings.RainbowEnabled then color = RainbowColor() end
    
    if onScreen then
        local size = Vector2.new(2000/dist, 3000/dist)
        
        self.Drawings.Box.PointA = rootPos - size/2
        self.Drawings.Box.PointB = rootPos + size/2
        self.Drawings.Box.Color = color
        self.Drawings.Box.Visible = true
        
        self.Drawings.BoxFill.PointA = rootPos - size/2
        self.Drawings.BoxFill.PointB = rootPos + size/2
        self.Drawings.BoxFill.Color = color
        self.Drawings.BoxFill.Transparency = 0.3
        self.Drawings.BoxFill.Visible = true
        
        -- Health Bar
        local health = humanoid and humanoid.Health / humanoid.MaxHealth or 1
        self.Drawings.HealthBG.PointA = rootPos - Vector2.new(12, size.Y/2)
        self.Drawings.HealthBG.PointB = rootPos - Vector2.new(8, -size.Y/2)
        self.Drawings.HealthBG.Visible = true
        
        self.Drawings.HealthBar.PointA = rootPos - Vector2.new(12, size.Y/2 * (2-health))
        self.Drawings.HealthBar.PointB = rootPos - Vector2.new(8, -size.Y/2)
        self.Drawings.HealthBar.Color = Color3.new(
            Colors.HealthGreen.R * (1-health) + Colors.HealthRed.R * health,
            Colors.HealthGreen.G * (1-health) + Colors.HealthRed.G * health,
            Colors.HealthGreen.B * (1-health) + Colors.HealthRed.B * health
        )
        self.Drawings.HealthBar.Visible = true
        
        self.Drawings.Name.Text = self.Target.Name
        self.Drawings.Name.Position = rootPos + Vector2.new(0, -size.Y/2 - 20)
        self.Drawings.Name.Color = color
        self.Drawings.Name.Visible = true
        
        self.Drawings.Distance.Text = math.floor(dist) .. "m"
        self.Drawings.Distance.Position = rootPos + Vector2.new(0, size.Y/2 + 5)
        self.Drawings.Distance.Color = Colors.Wallbang
        self.Drawings.Distance.Visible = true
        
        self.Drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        self.Drawings.Tracer.To = rootPos - Vector2.new(0, 20)
        self.Drawings.Tracer.Color = color
        self.Drawings.Tracer.Visible = true
        
        if self.Arrow then self.Arrow.Visible = false end
        
    else
        -- FIXED Off-Screen Arrows (Square rotation)
        if self.Arrow and rootPart then
            local arrowPos = GetOffScreenArrowPos(rootPart)
            self.Arrow.Position = arrowPos
            local angle = math.atan2(rootPos3D.Y - Camera.CFrame.Position.Y, rootPos3D.X - Camera.CFrame.Position.X)
            self.Arrow.Rotation = math.deg(angle) + 45
            self.Arrow.Color = color
            self.Arrow.Visible = true
        end
    end
    
    -- Minimap Dot
    if self.MinimapDot and Settings.MinimapEnabled and rootPart then
        local radarPos = WorldToRadar(rootPart.Position)
        self.MinimapDot.Position = radarPos
        self.MinimapDot.Color = color
        self.MinimapDot.Visible = true
    end
    
    -- Update Chams
    if self.Highlight then
        self.Highlight.FillColor = color
        self.Highlight.OutlineColor = color
    end
end

function ESPObject:SetVisible(visible)
    for _, drawing in pairs(self.Drawings) do
        drawing.Visible = visible
    end
    if self.Arrow then self.Arrow.Visible = visible end
    if self.MinimapDot then self.MinimapDot.Visible = visible end
end

function ESPObject:Destroy()
    for _, drawing in pairs(self.Drawings) do
        pcall(function() drawing:Remove() end)
    end
    pcall(function() if self.Arrow then self.Arrow:Remove() end end)
    pcall(function() if self.MinimapDot then self.MinimapDot:Remove() end end)
    pcall(function() if self.Highlight then self.Highlight:Destroy() end end)
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

-- Library Methods (Item ESP methods REMOVED)
function PerplexityESP:CreateESP()
    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= LocalPlayer and not ESPObjects[target] then
            ESPObjects[target] = ESPObject.new(target)
            target.CharacterAdded:Connect(function()
                if ESPObjects[target] then ESPObjects[target]:Destroy() end
                task.wait(1)
                ESPObjects[target] = ESPObject.new(target)
            end)
        end
    end
end

function PerplexityESP:Toggle()
    Settings.Enabled = not Settings.Enabled
    for _, esp in pairs(ESPObjects) do esp.Enabled = Settings.Enabled end
end

function PerplexityESP:SetTeamCheck(state) Settings.TeamCheck = state end
function PerplexityESP:SetRainbow(state) Settings.RainbowEnabled = state end
function PerplexityESP:ToggleMinimap() 
    Settings.MinimapEnabled = not Settings.MinimapEnabled
    MinimapBG.Visible = Settings.MinimapEnabled
    LocalDot.Visible = Settings.MinimapEnabled
end
function PerplexityESP:ToggleArrows() Settings.ArrowsEnabled = not Settings.ArrowsEnabled end
function PerplexityESP:PerformanceMode(state) Settings.PerformanceMode = state end
function PerplexityESP:SetDistanceCheck(state, dist) 
    Settings.DistanceCheck = state
    if dist then Settings.MaxDistance = dist end
end

-- Main Loop (Item ESP loop REMOVED)
local HeartbeatConnection
function PerplexityESP:Start()
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not Settings.Enabled then return end
        
        for target, esp in pairs(ESPObjects) do
            if target.Parent then 
                esp:Update()
            else 
                esp:Destroy() 
                ESPObjects[target] = nil 
            end
        end
        
        -- Update Local Player Dot
        if Settings.MinimapEnabled and LocalPlayer.Character then
            local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if localRoot then
                LocalDot.Position = Minimap.Position + Vector2.new(Minimap.Size/2, Minimap.Size/2)
                LocalDot.Visible = true
            end
        end
    end)
end

function PerplexityESP:Stop()
    if HeartbeatConnection then HeartbeatConnection:Disconnect() end
    for _, esp in pairs(ESPObjects) do esp:Destroy() end
    ESPObjects = {}
end

-- Initialize
PerplexityESP:CreateESP()
PerplexityESP:Start()

_G.PerplexityESP = PerplexityESP
print("✅ PerplexityESP v2.0 CLEAN loaded! (Item ESP removed)")
print("Controls: :Toggle(), :ToggleMinimap(), :ToggleArrows(), :SetRainbow(true)")

return PerplexityESP
