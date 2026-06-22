local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local WorldToScreen = WorldToScreen

if _G.AmmoESP_Cleanup then
    _G.AmmoESP_Cleanup()
end

_G.AmmoESP_Running = true

local MAX_DISTANCE = 200
local TEXT_SIZE = 16
local TEXT_COLOR = Color3.fromRGB(0, 180, 0)

local ammoItems = {}
local labels = {}

local function GetCharacterPosition()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    return nil
end

local function CreateLabel()
    local label = Drawing.new("Text")
    label.Size = TEXT_SIZE
    label.Font = Drawing.Fonts.UI
    label.Center = true
    label.Outline = true
    label.Color = TEXT_COLOR
    label.Visible = false
    return label
end

local function GetLabel(i)
    if not labels[i] then
        labels[i] = CreateLabel()
    end
    return labels[i]
end

local function ScanForAmmo()
    if not _G.AmmoESP_Running then return end
    
    local items = Workspace:FindFirstChild("Ignore")
    if items then
        items = items:FindFirstChild("Items")
    end
    if not items then return end

    local newAmmo = {}

    for _, child in ipairs(items:GetChildren()) do
        if child:IsA("Model") and child.Name == "Ammo" then
            local part = child:FindFirstChild("Box")
            if part and part:IsA("BasePart") then
                table.insert(newAmmo, {
                    Part = part
                })
            end
        end
    end

    ammoItems = newAmmo

    for i = #ammoItems + 1, #labels do
        if labels[i] then
            labels[i].Visible = false
        end
    end
end

local function UpdateESP()
    if not _G.AmmoESP_Running then return end
    
    local charPos = GetCharacterPosition()
    if not charPos then return end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    for i, data in ipairs(ammoItems) do
        local label = GetLabel(i)
        
        if data.Part and data.Part.Parent then
            local dist = (data.Part.Position - charPos).Magnitude
            if dist <= MAX_DISTANCE then
                local pos, on = WorldToScreen(data.Part.Position)
                if on then
                    label.Position = Vector2.new(pos.X, pos.Y - 20)
                    label.Text = tostring(math.floor(dist)) .. "m"
                    label.Visible = true
                else
                    label.Visible = false
                end
            else
                label.Visible = false
            end
        else
            label.Visible = false
        end
    end
end

task.spawn(function()
    while _G.AmmoESP_Running do
        ScanForAmmo()
        task.wait(0.36)
    end
end)

task.spawn(function()    while _G.AmmoESP_Running do
        UpdateESP()
        task.wait(0.035)
    end
end)

_G.AmmoESP_Cleanup = function()
    _G.AmmoESP_Running = false
    
    for _, label in ipairs(labels) do
        pcall(function()
            label:Remove()
        end)
    end
    
    labels = {}
    ammoItems = {}
end

local headSize = 6

local playerNames = {}
for _, player in ipairs(Players:GetPlayers()) do
    playerNames[player.Name] = true
end

task.spawn(function()
    while _G.AmmoESP_Running do
        local infected = Workspace:FindFirstChild("Entities")
        if infected then
            infected = infected:FindFirstChild("Infected")
        end
        
        if infected then
            for _, zombie in ipairs(infected:GetChildren()) do
                if zombie:IsA("Model") then
                    if playerNames[zombie.Name] then
                        -- skip real players
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

print("twr head expander and ammo esp loaded")
