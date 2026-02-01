-- PerplexityESP v2.0 - Complete Roblox ESP Library with Minimap & Advanced Features (2026 Edition)
-- Brand new features: Minimap Radar, Off-Screen Arrows, Item ESP, Dropped Tools, and more!
-- Educational project - Copy-paste ready for all exploits with Drawing API.

local PerplexityESP = {}
PerplexityESP.__index = PerplexityESP

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- Internal Storage
local ESPObjects = {}
local ItemESPObjects = {}
local Settings = {
    Enabled = true,
    TeamCheck = true,
    DistanceCheck = false,
    MaxDistance = 5000,
    RainbowSpeed = 1,
    PerformanceMode = false,
    MinimapEnabled = true,
    ArrowsEnabled = true,
    ItemESP = true
}

-- Colors
local Colors = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Team = Color3.fromRGB(0, 255, 0),
    Item = Color3.fromRGB(255, 255, 0),
    Tool = Color3.fromRGB(0, 255, 255),
    Wallbang = Color3.fromRGB(255, 255, 0),
    Rainbow = Color3.fromRGB(255, 255, 255),
    HealthGreen = Color3.fromRGB(0, 255, 0),
    HealthRed = Color3.fromRGB(255, 0, 0),
    Black = Color3.fromRGB(0, 0, 0),
    MinimapPlayer = Color3.fromRGB(255, 0, 0),
    MinimapLocal = Color3.fromRGB(0, 255, 0)
}

-- Minimap Settings
local Minimap = {
    Size = 200,
    Position = Vector2.new(20, 20),
    CenterDotSize = 8,
    PlayerDotSize = 4,
    FOV = 500
}

-- Off-Screen Arrows Settings
local Arrows = {
    Size = 30,
    DistanceFromEdge = 50,
    MaxDistance = 1000
}

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

local function GetBoundingBox(part)
    local cframe, size = part.CFrame, part.Size
    local corners = {
        cframe.Position - size/2,
        cframe.Position + Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
        cframe.Position + Vector3.new(-size.X/2, -size.Y/2, size.Z/2),
        cframe.Position + size/2
    }
    
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, corner in pairs(corners) do
        local screenPos, onScreen = WorldToScreen(corner)
        if onScreen then
            minX, maxX = math.min(minX, screenPos.X), math.max(maxX, screenPos.X)
            minY, maxY = math.min(minY, screenPos.Y), math.max(maxY, screenPos.Y)
        end
    end
    return {Left = minX, Right = maxX, Top = minY, Bottom = maxY}
end

local function RainbowColor(time)
    return Color3.fromHSV((tick() * Settings.RainbowSpeed) % 1, 1, 1)
end

local function DistanceFromCamera(pos)
    return (Camera.CFrame.Position - pos.Position).Magnitude
end

-- Off-Screen Arrow Calculation
local function GetOffScreenArrowPos(worldPos)
    local screenPos, onScreen = WorldToScreen(worldPos)
    if onScreen then return nil end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local angle = math.atan2(worldPos.Position.Y - Camera.CFrame.Position.Y, worldPos.Position.X - Camera.CFrame.Position.X)
    local distance = Arrows.MaxDistance
    
    local arrowPos = screenCenter + Vector2.new(
        math.cos(angle) * (Arrows.DistanceFromEdge + Arrows.Size/2),
        math.sin(angle) * (Arrows.DistanceFromEdge + Arrows.Size/2)
    )
    
    return arrowPos
end

-- Minimap World to Radar Position
local function WorldToRadar(worldPos)
    local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") 
    local center = localPos and localPos.Position or Vector3.new()
    
    local relativePos = worldPos - center
    local radarPos = Vector2.new(relativePos.X, relativePos.Z)
    
    local angle = Camera.CFrame:ToObjectSpace(CFrame.new(center)):Position
    local rotated = Vector2.new(
        radarPos.X * math.cos(-angle.Y) - radarPos.Y * math.sin(-angle.Y),
        radarPos.X * math.sin(-angle.Y) + radarPos.Y * math.cos(-angle.Y)
    )
    
    local scale = Minimap.Size / 2 / Minimap.FOV
    return Minimap.Position + Vector2.new(Minimap.Size/2, Minimap.Size/2) + rotated * scale
end

-- ESP Object Class (Enhanced)
local ESPObject = {}
ESPObject.__index = ESPObject

function ESPObject.new(target)
    local self = setmetatable({}, ESPObject)
    self.Target = target
    self.Character = target.Character or target.CharacterAdded:Wait()
    self.RootPart = self.Character:WaitForChild("HumanoidRootPart")
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.Drawings = {}
    self.Arrow = nil
    self.MinimapDot = nil
    self.Enabled = true
    self:AddDrawings()
    return self
end

function ESPObject:AddDrawings()
    local drawings = self.Drawings
    
    -- Main ESP Drawings (Box, Health, Name, etc.)
    drawings.Box = CreateDrawing("Square", {Filled = false, Thickness = 2, Visible = false})
    drawings.BoxFill = CreateDrawing("Square", {Filled = true, Thickness = 1, Transparency = 0.5, Visible = false})
    drawings.HealthBG = CreateDrawing("Square", {Filled = true, Thickness = 1, Transparency = 0.8, Visible = false})
    drawings.HealthBar = CreateDrawing("Square", {Filled = true, Thickness = 1, Transparency = 1, Visible = false})
    drawings.Name = CreateDrawing("Text", {Size = 14, Center = true, Outline = true, Font = 2, Visible = false})
    drawings.Distance = CreateDrawing("Text", {Size = 12, Center = true, Outline = true, Font = 2, Visible = false})
    drawings.Tracer = CreateDrawing("Line", {Thickness = 2, Transparency = 1, Visible = false})
    
    -- Off-Screen Arrow
    if Settings.ArrowsEnabled then
        self.Arrow = CreateDrawing("Triangle", {
            Filled = true,
            Thickness = 2,
            Color = Colors.Enemy,
            Transparency = 0.8,
            Visible = false
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
            Visible = false
        })
    end
    
    -- Chams
    if self.Target ~= LocalPlayer then
        self.Highlight = Instance.new("Highlight")
        self.Highlight.Parent = self.Character
        self.Highlight.FillColor = Colors.Enemy
        self.Highlight.OutlineColor = Colors.Enemy
        self.Highlight.FillTransparency = 0.5
        self.Highlight.OutlineTransparency = 0
    end
end

function ESPObject:Update()
    if not self.Enabled or not self.RootPart or not self.RootPart.Parent then
        self:Destroy()
        return
    end
    
    local rootPos3D = self.RootPart.Position
    local rootPos, onScreen = WorldToScreen(rootPos3D)
    local humanoid = self.Humanoid
    local health = humanoid.Health / humanoid.MaxHealth
    
    -- Distance Check
    local dist = DistanceFromCamera(self.RootPart)
    if Settings.DistanceCheck and dist > Settings.MaxDistance then
        self:SetVisible(false)
        return
    end
    
    local color = Settings.TeamCheck and self.Target.Team == LocalPlayer.Team and Colors.Team or Colors.Enemy
    if Settings.RainbowEnabled then color = RainbowColor() end
    
    if onScreen then
        -- Main ESP (Box, Health, Text)
        local box = GetBoundingBox(self.RootPart)
        local width, height = box.Right - box.Left, box.Bottom - box.Top
        
        self.Drawings.Box.PointA = Vector2.new(box.Left, box.Top)
        self.Drawings.Box.PointB = Vector2.new(box.Right, box.Bottom)
        self.Drawings.Box.Color = color
        self.Drawings.Box.Visible = true
        
        self.Drawings.BoxFill.PointA = Vector2.new(box.Left, box.Top)
        self.Drawings.BoxFill.PointB = Vector2.new(box.Right, box.Bottom)
        self.Drawings.BoxFill.Color = color
        self.Drawings.BoxFill.Transparency = 0.3
        self.Drawings.BoxFill.Visible = true
        
        -- Health Bar
        local barWidth, barHeight = 4, height
        self.Drawings.HealthBG.PointA = Vector2.new(box.Left - 8, box.Top)
        self.Drawings.HealthBG.PointB = Vector2.new(box.Left - 4, box.Bottom)
        self.Drawings.HealthBG.Color = Colors.Black
        self.Drawings.HealthBG.Visible = true
        
        self.Drawings.HealthBar.PointA = Vector2.new(box.Left - 8, box.Bottom - (barHeight * health))
        self.Drawings.HealthBar.PointB = Vector2.new(box.Left - 4, box.Bottom)
        self.Drawings.HealthBar.Color = Color3.new(
            Colors.HealthGreen.R * (1-health) + Colors.HealthRed.R * health,
            Colors.HealthGreen.G * (1-health) + Colors.HealthRed.G * health,
            Colors.HealthGreen.B * (1-health) + Colors.HealthRed.B * health
        )
        self.Drawings.HealthBar.Visible = true
        
        self.Drawings.Name.Text = self.Target.Name
        self.Drawings.Name.Position = Vector2.new(rootPos.X, box.Top - 20)
        self.Drawings.Name.Color = color
        self.Drawings.Name.Visible = true
        
        self.Drawings.Distance.Text = math.floor(dist) .. "m"
        self.Drawings.Distance.Position = Vector2.new(rootPos.X, box.Bottom + 5)
        self.Drawings.Distance.Color = Colors.Wallbang
        self.Drawings.Distance.Visible = true
        
        self.Drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        self.Drawings.Tracer.To = WorldToScreen(rootPos3D - Vector3.new(0, 3, 0))
        self.Drawings.Tracer.Color = color
        self.Drawings.Tracer.Visible = true
        
        -- Hide Arrow when on screen
        if self.Arrow then self.Arrow.Visible = false end
        
    else
        -- Off-Screen Arrow
        if self.Arrow then
            local arrowPos = GetOffScreenArrowPos(self.RootPart)
            if arrowPos then
                -- Draw arrow pointing to player
                local angle = math.atan2(rootPos3D.Y - Camera.CFrame.Position.Y, rootPos3D.X - Camera.CFrame.Position.X)
                self.Arrow.PointA = arrowPos
                self.Arrow.PointB = arrowPos + Vector2.new(math.cos(angle) * Arrows.Size, math.sin(angle) * Arrows.Size)
                self.Arrow.PointC = arrowPos + Vector2.new(math.cos(angle + math.rad(135)) * Arrows.Size/2, math.sin(angle + math.rad(135)) * Arrows.Size/2)
                self.Arrow.Color = color
                self.Arrow.Visible = true
            end
        end
        
        -- Hide main ESP when off-screen
        self:SetMainVisible(false)
    end
    
    -- Minimap Dot (Always visible)
    if self.MinimapDot and Settings.MinimapEnabled then
        local radarPos = WorldToRadar(self.RootPart)
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

function ESPObject:SetMainVisible(visible)
    for _, drawing in pairs(self.Drawings) do
        drawing.Visible = visible
    end
end

function ESPObject:SetVisible(visible)
    self:SetMainVisible(visible)
    if self.Arrow then self.Arrow.Visible = visible end
    if self.MinimapDot then self.MinimapDot.Visible = visible end
end

function ESPObject:Destroy()
    for _, drawing in pairs(self.Drawings) do
        if drawing.Remove then drawing:Remove() end
    end
    if self.Arrow and self.Arrow.Remove then self.Arrow:Remove() end
    if self.MinimapDot and self.MinimapDot.Remove then self.MinimapDot:Remove() end
    if self.Highlight then self.Highlight:Destroy() end
end

-- Item ESP Class
local ItemESPObject = {}
ItemESPObject.__index = ItemESPObject

function ItemESPObject.new(item)
    local self = setmetatable({}, ItemESPObject)
    self.Item = item
    self.Drawings = {}
    self:AddDrawings()
    return self
end

function ItemESPObject:AddDrawings()
    self.Drawings.Box = CreateDrawing("Square", {Filled = false, Thickness = 2, Color = Colors.Item, Visible = false})
    self.Drawings.Name = CreateDrawing("Text", {Size = 14, Center = true, Outline = true, Font = 2, Color = Colors.Item, Visible = false})
end

function ItemESPObject:Update()
    if not self.Item.Parent then
        self:Destroy()
        return
    end
    
    local pos, onScreen = WorldToScreen(self.Item.Position)
    local dist = DistanceFromCamera(self.Item)
    
    if Settings.DistanceCheck and dist > Settings.MaxDistance then
        self:SetVisible(false)
        return
    end
    
    if onScreen then
        local size = 30 / dist * 1000
        self.Drawings.Box.PointA = Vector2.new(pos.X - size/2, pos.Y - size/2)
        self.Drawings.Box.PointB = Vector2.new(pos.X + size/2, pos.Y + size/2)
        self.Drawings.Box.Visible = true
        
        self.Drawings.Name.Text = self.Item.Name
        self.Drawings.Name.Position = Vector2.new(pos.X, pos.Y - size/2 - 20)
        self.Drawings.Name.Visible = true
    else
        self:SetVisible(false)
    end
end

function ItemESPObject:SetVisible(visible)
    self.Drawings.Box.Visible = visible
    self.Drawings.Name.Visible = visible
end

function ItemESPObject:Destroy()
    for _, drawing in pairs(self.Drawings) do
        if drawing.Remove then drawing:Remove() end
    end
end

-- Minimap Background & Local Player Dot
local MinimapBG = CreateDrawing("Square", {
    Filled = true,
    Color = Colors.Black,
    Transparency = 0.3,
    Visible = Settings.MinimapEnabled
})
MinimapBG.PointA = Vector2.new(Minimap.Position.X, Minimap.Position.Y)
MinimapBG.PointB = Vector2.new(Minimap.Position.X + Minimap.Size, Minimap.Position.Y + Minimap.Size)

local LocalDot = CreateDrawing("Circle", {
    Radius = Minimap.CenterDotSize,
    Filled = true,
    Color = Colors.MinimapLocal,
    Visible = Settings.MinimapEnabled
})

-- Library Methods
function PerplexityESP:CreateESP(targets)
    targets = targets or Players:GetPlayers()
    for _, target in ipairs(targets) do
        if target ~= LocalPlayer and not ESPObjects[target] then
            ESPObjects[target] = ESPObject.new(target)
            target.CharacterAdded:Connect(function()
                if ESPObjects[target] then ESPObjects[target]:Destroy() end
                ESPObjects[target] = ESPObject.new(target)
            end)
        end
    end
end

function PerplexityESP:ScanForItems()
    if not Settings.ItemESP then return end
    
    -- Clear old items
    for item, esp in pairs(ItemESPObjects) do
        esp:Destroy()
    end
    ItemESPObjects = {}
    
    -- Scan workspace for items/tools
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("Tool") or obj:IsA("Part") and obj.Name:lower():find("gun") or obj.Name:lower():find("weapon")) 
            and obj.Parent ~= LocalPlayer.Character then
            ItemESPObjects[obj] = ItemESPObject.new(obj)
            obj.AncestryChanged:Connect(function()
                if not obj.Parent then
                    if ItemESPObjects[obj] then
                        ItemESPObjects[obj]:Destroy()
                        ItemESPObjects[obj] = nil
                    end
                end
            end)
        end
    end
end

function PerplexityESP:Toggle()
    Settings.Enabled = not Settings.Enabled
    for _, esp in pairs(ESPObjects) do esp.Enabled = Settings.Enabled end
end

function PerplexityESP:ToggleMinimap()
    Settings.MinimapEnabled = not Settings.MinimapEnabled
    MinimapBG.Visible = Settings.MinimapEnabled
    LocalDot.Visible = Settings.MinimapEnabled
end

function PerplexityESP:ToggleArrows()
    Settings.ArrowsEnabled = not Settings.ArrowsEnabled
end

function PerplexityESP:ToggleItemESP()
    Settings.ItemESP = not Settings.ItemESP
end

-- Main Update Loop
local HeartbeatConnection
function PerplexityESP:Start()
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not Settings.Enabled then return end
        
        -- Update Player ESP
        for target, esp in pairs(ESPObjects) do
            if target.Parent then
                esp:Update()
            else
                esp:Destroy()
                ESPObjects[target] = nil
            end
        end
        
        -- Update Item ESP
        for item, esp in pairs(ItemESPObjects) do
            if item.Parent then
                esp:Update()
            else
                esp:Destroy()
                ItemESPObjects[item] = nil
            end
        end
        
        -- Update Minimap Local Player
        if Settings.MinimapEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalDot.Position = Minimap.Position + Vector2.new(Minimap.Size/2, Minimap.Size/2)
            LocalDot.Visible = true
        end
        
        -- Auto-scan items every 5 seconds
        if tick() % 5 < 0.1 then
            self:ScanForItems()
        end
    end)
end

function PerplexityESP:Stop()
    if HeartbeatConnection then HeartbeatConnection:Disconnect() end
    for _, esp in pairs(ESPObjects) do esp:Destroy() end
    for _, esp in pairs(ItemESPObjects) do esp:Destroy() end
    ESPObjects, ItemESPObjects = {}, {}
    MinimapBG:Remove()
    LocalDot:Remove()
end

-- Initialize
PerplexityESP:CreateESP()
PerplexityESP:ScanForItems()
PerplexityESP:Start()

-- Controls
_G.PerplexityESP = PerplexityESP
print("PerplexityESP v2.0 loaded! New features: Minimap Radar + Off-Screen Arrows + Item ESP!")
print("Controls: :Toggle(), :ToggleMinimap(), :ToggleArrows(), :ToggleItemESP()")

return PerplexityESP
