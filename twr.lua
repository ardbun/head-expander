local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local WorldToScreen = WorldToScreen
local Drawing = Drawing
local tick = tick
local math = math
local ipairs = ipairs
local pairs = pairs

_G.AmmoESP_RunId = (_G.AmmoESP_RunId or 0) + 1
local runId = _G.AmmoESP_RunId

if _G.AmmoESP_RenderConnection then
    pcall(function() _G.AmmoESP_RenderConnection:Disconnect() end)
    _G.AmmoESP_RenderConnection = nil
end

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
local MAX_VISIBLE = 6
local MAX_DISTANCE = 80
local UPDATE_INTERVAL = 0.03
local TEXT_INTERVAL = 0.8

-- Precompute squared distances
local ITEM_CONFIG = {
    Ammo = {
        Color = Color3.fromRGB(0, 180, 0),
        MaxDistance = MAX_DISTANCE,
        MaxDistSq = MAX_DISTANCE * MAX_DISTANCE
    },
    Medkit = {
        Color = Color3.fromRGB(180, 0, 0),
        MaxDistance = MAX_DISTANCE,
        MaxDistSq = MAX_DISTANCE * MAX_DISTANCE
    },
    Bandages = {
        Color = Color3.fromRGB(222, 204, 168),
        MaxDistance = MAX_DISTANCE,
        MaxDistSq = MAX_DISTANCE * MAX_DISTANCE
    }
}

local ammoItems = {}
local labels = {}
local boxes = {}
local lastTextUpdate = {}

-- Reused arrays
local visibleIndices = {}
local visibleDists = {}
local visibleScreenPos = {}
local visibleData = {}
local visibleLabels = {}
local visibleBoxes = {}

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
    local visibleCount = 0
    
    for i, data in ipairs(ammoItems) do
        local config = ITEM_CONFIG[data.Type] or ITEM_CONFIG.Ammo
        local label = GetLabel(i)
        local box = GetBox(i)
        local maxDistSq = config.MaxDistSq
        
        local part = data.Part
        if part and part.Parent and part:IsA("BasePart") then
            local pos = part.Position
            local dx = pos.X - charPos.X
            local dy = pos.Y - charPos.Y
            local dz = pos.Z - charPos.Z
            local distSq = dx*dx + dy*dy + dz*dz
            
            if distSq <= maxDistSq then
                local screenPos, onScreen = WorldToScreen(pos)
                if onScreen then
                    visibleCount = visibleCount + 1
                    visibleIndices[visibleCount] = i
                    visibleDists[visibleCount] = math.sqrt(distSq)
                    visibleScreenPos[visibleCount] = screenPos
                    visibleData[visibleCount] = data
                    visibleLabels[visibleCount] = label
                    visibleBoxes[visibleCount] = box
                else
                    label.Visible = false
                    if box then box.Visible = false end
                end
            else
                label.Visible = false
                if box then box.Visible = false end
            end
        else
            label.Visible = false
            if box then box.Visible = false end
        end
    end
    
    local showCount = math.min(visibleCount, MAX_VISIBLE)
    for i = 1, showCount do
        local bestIdx = i
        local bestDist = visibleDists[i]
        for j = i + 1, visibleCount do
            if visibleDists[j] < bestDist then
                bestDist = visibleDists[j]
                bestIdx = j
            end
        end
        if bestIdx ~= i then
            visibleIndices[i], visibleIndices[bestIdx] = visibleIndices[bestIdx], visibleIndices[i]
            visibleDists[i], visibleDists[bestIdx] = visibleDists[bestIdx], visibleDists[i]
            visibleScreenPos[i], visibleScreenPos[bestIdx] = visibleScreenPos[bestIdx], visibleScreenPos[i]
            visibleData[i], visibleData[bestIdx] = visibleData[bestIdx], visibleData[i]
            visibleLabels[i], visibleLabels[bestIdx] = visibleLabels[bestIdx], visibleLabels[i]
            visibleBoxes[i], visibleBoxes[bestIdx] = visibleBoxes[bestIdx], visibleBoxes[i]
        end
    end
    
    for idx = 1, showCount do
        local i = visibleIndices[idx]
        local data = visibleData[idx]
        local label = visibleLabels[idx]
        local box = visibleBoxes[idx]
        local dist = visibleDists[idx]
        local screenPos = visibleScreenPos[idx]
        
        -- 2D DISTANCE-SCALED BOX (1 WorldToScreen call, no corner projections)
        local scale = math.clamp(700 / dist, 10, 34)
        local halfScale = scale
        
        if box then
            box.Position = Vector2.new(screenPos.X - halfScale, screenPos.Y - halfScale)
            box.Size = Vector2.new(scale * 2, scale * 2)
            box.Visible = true
        end
        
        label.Position = Vector2.new(screenPos.X, screenPos.Y - scale - 10)
        label.Visible = true
        
        if currentTime - (lastTextUpdate[i] or 0) >= TEXT_INTERVAL then
            label.Text = tostring(math.floor(dist)) .. "m"
            lastTextUpdate[i] = currentTime
        end
    end
    
    for idx = showCount + 1, visibleCount do
        if visibleLabels[idx] then
            visibleLabels[idx].Visible = false
            if visibleBoxes[idx] then
                visibleBoxes[idx].Visible = false
            end
        end
    end
end

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        ScanForItems()
        task.wait(0.5)
    end
end)

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        UpdateESP()
        task.wait(UPDATE_INTERVAL)
    end
end)

local headSize = 5

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        local infected = Workspace:FindFirstChild("Entities")
        if infected then
            infected = infected:FindFirstChild("Infected")
        end
        
        if infected then
            for _, zombie in ipairs(infected:GetChildren()) do
                if zombie:IsA("Model") then
                    local head = zombie:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then
                        if head.Size.X ~= headSize then
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

pcall(function()
    if _G.notify then
        _G.notify("Ammo ESP", "Loaded | Run ID: " .. runId, 4)
    elseif notify then
        notify("Ammo ESP", "Loaded | Run ID: " .. runId, 4)
    else
        print("Ammo ESP Loaded | Run ID: " .. runId)
    end
end)

-- ===== ADMIN CHECK LOOP =====
local HttpService = game:GetService("HttpService")
local GroupId = 2838077
local MinRank = 250

local lastStaffString = ""
local rankCache = {}

local function GetRankInGroup(UserId, GroupId)
    if rankCache[UserId] then
        return rankCache[UserId].rank, rankCache[UserId].role
    end
    
    local url = "https://groups.roblox.com/v2/users/" .. UserId .. "/groups/roles"
    local success, response = pcall(function()
        if httpget then
            return httpget(url)
        else
            return game:HttpGet(url)
        end
    end)
    if not success or not response or response == "" then return 0, "Unknown" end
    
    local success2, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if not success2 or not data then return 0, "Unknown" end
    
    if data.data then
        for _, group in pairs(data.data) do
            if group.group and group.group.id == GroupId then
                rankCache[UserId] = {
                    rank = group.role.rank,
                    role = group.role.name
                }
                return group.role.rank, group.role.name
            end
        end
    end
    rankCache[UserId] = { rank = 0, role = "Unknown" }
    return 0, "Unknown"
end

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        local staffNames = {}
        local staffString = ""
        
        for _, player in ipairs(Players:GetPlayers()) do
            local userId = player.UserId
            if userId then
                local rank, roleName = GetRankInGroup(userId, GroupId)
                if rank >= MinRank then
                    table.insert(staffNames, player.Name .. " (" .. roleName .. ")")
                end
            end
        end
        
        staffString = table.concat(staffNames, ", ")
        
        if staffString ~= lastStaffString and #staffNames > 0 then
            lastStaffString = staffString
            
            pcall(function()
                if _G.notify then
                    _G.notify("Staff Online (" .. #staffNames .. ")", staffString, 10)
                elseif notify then
                    notify("Staff Online (" .. #staffNames .. ")", staffString, 10)
                else
                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "Staff Online (" .. #staffNames .. ")",
                        Text = staffString,
                        Duration = 10
                    })
                end
            end)
        end
        
        task.wait(5)
    end
end)
