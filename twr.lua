local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local WorldToScreen = WorldToScreen

_G.AmmoESP_RunId = (_G.AmmoESP_RunId or 0) + 1
local runId = _G.AmmoESP_RunId

if _G.AmmoESP_Labels then
    for _, label in ipairs(_G.AmmoESP_Labels) do
        pcall(function()
            label.Visible = false
            label:Remove()
        end)
    end
end
if _G.AmmoESP_Boxes then
    for _, box in ipairs(_G.AmmoESP_Boxes) do
        pcall(function()
            box.Visible = false
            box:Remove()
        end)
    end
end

_G.AmmoESP_Labels = {}
_G.AmmoESP_Boxes = {}

local TEXT_SIZE = 16
local BOX_THICKNESS = 2

local ITEM_CONFIG = {
    Ammo = {
        Color = Color3.fromRGB(0, 180, 0),
        MaxDistance = 170
    },
    Medkit = {
        Color = Color3.fromRGB(180, 0, 0),
        MaxDistance = 130
    },
    Bandages = {
        Color = Color3.fromRGB(222, 204, 168),
        MaxDistance = 130
    }
}

local ammoItems = {}
local labels = {}
local boxes = {}
local lastTextUpdate = {}

local function GetCharacterPosition()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    return nil
end

local function CreateLabel(color)
    local label = Drawing.new("Text")
    label.Size = TEXT_SIZE
    label.Font = Drawing.Fonts.UI
    label.Center = true
    label.Outline = true
    label.Color = color
    label.Visible = false
    
    table.insert(_G.AmmoESP_Labels, label)
    return label
end

local function CreateBox(color)
    local box = Drawing.new("Square")
    box.Thickness = BOX_THICKNESS
    box.Filled = false
    box.Color = color
    box.Visible = false
    
    table.insert(_G.AmmoESP_Boxes, box)
    return box
end

local function GetLabel(i)
    if not labels[i] then
        local config = ITEM_CONFIG[ammoItems[i] and ammoItems[i].Type or "Ammo"]
        labels[i] = CreateLabel(config.Color)
        boxes[i] = CreateBox(config.Color)
        lastTextUpdate[i] = 0
    end
    return labels[i]
end

local function GetBox(i)
    if not boxes[i] then
        local config = ITEM_CONFIG[ammoItems[i] and ammoItems[i].Type or "Ammo"]
        boxes[i] = CreateBox(config.Color)
    end
    return boxes[i]
end

local function GetMeshName(itemName)
    local meshMap = {
        Ammo = "AmmoBoxes",
        Medkit = "Medkit",
        Bandages = "Bandages"
    }
    return meshMap[itemName]
end

local function ScanForItems()
    if _G.AmmoESP_RunId ~= runId then return end
    
    local items = Workspace:FindFirstChild("Ignore")
    if items then
        items = items:FindFirstChild("Items")
    end
    if not items then return end

    local newItems = {}
    local validTypes = { Ammo = true, Medkit = true, Bandages = true }

    for _, child in ipairs(items:GetChildren()) do
        if child:IsA("Model") and validTypes[child.Name] then
            local meshName = GetMeshName(child.Name)
            if meshName and child:FindFirstChild(meshName) then
                local part = child:FindFirstChild("Box")
                if part and part:IsA("BasePart") then
                    table.insert(newItems, {
                        Part = part,
                        Model = child,
                        Type = child.Name
                    })
                end
            end
        end
    end

    ammoItems = newItems

    for i = #ammoItems + 1, #labels do
        if labels[i] then
            labels[i].Visible = false
        end
        if boxes[i] then
            boxes[i].Visible = false
        end
    end
end

local function UpdateESP()
    if _G.AmmoESP_RunId ~= runId then return end
    
    local charPos = GetCharacterPosition()
    if not charPos then return end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    local currentTime = tick()
    
    for i, data in ipairs(ammoItems) do
        local config = ITEM_CONFIG[data.Type] or ITEM_CONFIG.Ammo
        local label = GetLabel(i)
        local box = GetBox(i)
        local maxDist = config.MaxDistance
        
        label.Color = config.Color
        box.Color = config.Color
        
        if data.Part and data.Part.Parent then
            local dist = (data.Part.Position - charPos).Magnitude
            
            if dist <= maxDist then
                local pos, on = WorldToScreen(data.Part.Position)
                
                if on then
                    local size = data.Part.Size
                    local halfSize = size / 2
                    local cf = data.Part.CFrame
                    
                    local corners = {
                        cf * Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
                        cf * Vector3.new( halfSize.X, -halfSize.Y, -halfSize.Z),
                        cf * Vector3.new( halfSize.X,  halfSize.Y, -halfSize.Z),
                        cf * Vector3.new(-halfSize.X,  halfSize.Y, -halfSize.Z),
                        cf * Vector3.new(-halfSize.X, -halfSize.Y,  halfSize.Z),
                        cf * Vector3.new( halfSize.X, -halfSize.Y,  halfSize.Z),
                        cf * Vector3.new( halfSize.X,  halfSize.Y,  halfSize.Z),
                        cf * Vector3.new(-halfSize.X,  halfSize.Y,  halfSize.Z)
                    }
                    
                    local screenCorners = {}
                    local allOnScreen = true
                    for j, corner in ipairs(corners) do
                        local screenPos, onScreen = WorldToScreen(corner)
                        if not onScreen then
                            allOnScreen = false
                            break
                        end
                        screenCorners[j] = screenPos
                    end
                    
                    if allOnScreen then
                        local minX, minY = math.huge, math.huge
                        local maxX, maxY = -math.huge, -math.huge
                        for _, sc in ipairs(screenCorners) do
                            if sc.X < minX then minX = sc.X end
                            if sc.Y < minY then minY = sc.Y end
                            if sc.X > maxX then maxX = sc.X end
                            if sc.Y > maxY then maxY = sc.Y end
                        end
                        
                        box.Position = Vector2.new(minX, minY)
                        box.Size = Vector2.new(maxX - minX, maxY - minY)
                        box.Visible = true
                    else
                        box.Visible = false
                    end
                    
                    label.Position = Vector2.new(pos.X, pos.Y - 30)
                    label.Visible = true
                    
                    if currentTime - lastTextUpdate[i] >= 0.2 then
                        label.Text = tostring(math.floor(dist)) .. "m"
                        lastTextUpdate[i] = currentTime
                    end
                else
                    label.Visible = false
                    box.Visible = false
                end
            else
                label.Visible = false
                box.Visible = false
            end
        else
            label.Visible = false
            box.Visible = false
        end
    end
end

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        ScanForItems()
        task.wait(0.36)
    end
end)

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        UpdateESP()
        task.wait(0.02)
    end
end)

local headSize = 6

local playerNames = {}
for _, player in ipairs(Players:GetPlayers()) do
    playerNames[player.Name] = true
end

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        local infected = Workspace:FindFirstChild("Entities")
        if infected then
            infected = infected:FindFirstChild("Infected")
        end
        
        if infected then
            for _, zombie in ipairs(infected:GetChildren()) do
                if zombie:IsA("Model") then
                    if playerNames[zombie.Name] then
                    else
                        local head = zombie:FindFirstChild("Head")
                        if head and head:IsA("BasePart") then
                            pcall(function()
                                head.Size = Vector3.new(headSize, headSize, headSize)
                            end)
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

print("Loaded | Run ID:", runId)
