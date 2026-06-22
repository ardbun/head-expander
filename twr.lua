local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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
local MAX_VISIBLE = 6
local MAX_DISTANCE = 80

-- Precomputed corner signs
local cornerSigns = {
    {-1,-1,-1}, {1,-1,-1}, {1,1,-1}, {-1,1,-1},
    {-1,-1, 1}, {1,-1, 1}, {1,1, 1}, {-1,1, 1}
}

local ITEM_CONFIG = {
    Ammo = {
        Color = Color3.fromRGB(0, 180, 0),
        MaxDistance = MAX_DISTANCE
    },
    Medkit = {
        Color = Color3.fromRGB(180, 0, 0),
        MaxDistance = MAX_DISTANCE
    },
    Bandages = {
        Color = Color3.fromRGB(222, 204, 168),
        MaxDistance = MAX_DISTANCE
    }
}

local ammoItems = {}
local labels = {}
local boxes = {}
local lastTextUpdate = {}
local lastBoxUpdate = {}

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
        lastBoxUpdate[i] = 0
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
    
    -- Reuse arrays to avoid GC spikes
    local visibleCount = 0
    local visibleIndices = {}
    local visibleDists = {}
    local visibleScreenPos = {}
    local visibleData = {}
    local visibleLabels = {}
    local visibleBoxes = {}
    
    for i, data in ipairs(ammoItems) do
        local config = ITEM_CONFIG[data.Type] or ITEM_CONFIG.Ammo
        local label = GetLabel(i)
        local box = GetBox(i)
        local maxDist = config.MaxDistance
        
        local part = data.Part
        if part and part.Parent and part:IsA("BasePart") then
            local pos = part.Position
            local dist = (pos - charPos).Magnitude
            
            if dist <= maxDist then
                local screenPos, onScreen = WorldToScreen(pos)
                if onScreen then
                    visibleCount = visibleCount + 1
                    visibleIndices[visibleCount] = i
                    visibleDists[visibleCount] = dist
                    visibleScreenPos[visibleCount] = screenPos
                    visibleData[visibleCount] = data
                    visibleLabels[visibleCount] = label
                    visibleBoxes[visibleCount] = box
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
    
    -- Selection sort for closest items (no table allocation)
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
    
    -- Render closest items
    for idx = 1, showCount do
        local i = visibleIndices[idx]
        local data = visibleData[idx]
        local label = visibleLabels[idx]
        local box = visibleBoxes[idx]
        local dist = visibleDists[idx]
        local screenPos = visibleScreenPos[idx]
        
        -- BOX: Update every frame (smooth)
        local size = data.Part.Size
        local halfX = size.X / 2
        local halfY = size.Y / 2
        local halfZ = size.Z / 2
        local cf = data.Part.CFrame
        
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local allOnScreen = true
        
        for _, sign in ipairs(cornerSigns) do
            local corner = cf * Vector3.new(sign[1] * halfX, sign[2] * halfY, sign[3] * halfZ)
            local sc, on = WorldToScreen(corner)
            if not on then
                allOnScreen = false
                break
            end
            if sc.X < minX then minX = sc.X end
            if sc.Y < minY then minY = sc.Y end
            if sc.X > maxX then maxX = sc.X end
            if sc.Y > maxY then maxY = sc.Y end
        end
        
        if allOnScreen then
            box.Position = Vector2.new(minX, minY)
            box.Size = Vector2.new(maxX - minX, maxY - minY)
            box.Visible = true
        else
            box.Visible = false
        end
        
        -- LABEL: Position updates every frame (smooth)
        label.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
        label.Visible = true
        
        -- TEXT: Updates only every 0.8 seconds (much less often)
        if currentTime - lastTextUpdate[i] >= 0.8 then
            label.Text = tostring(math.floor(dist)) .. "m"
            lastTextUpdate[i] = currentTime
        end
    end
    
    -- Hide extra items
    for idx = showCount + 1, visibleCount do
        if visibleLabels[idx] then
            visibleLabels[idx].Visible = false
            visibleBoxes[idx].Visible = false
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
        task.wait(0.015)
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
                        pcall(function()
                            head.Size = Vector3.new(headSize, headSize, headSize)
                        end)
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

notify('Loaded | Run ID: ' .. runId, 4)

-- ===== ADMIN CHECK LOOP (Tied to runId + Cached) =====
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
    local success, response = pcall(game.HttpGet, game, url)
    if not success then return 0, "Unknown" end
    
    local data = HttpService:JSONDecode(response)
    for _, group in pairs(data.data) do
        if group.group.id == GroupId then
            rankCache[UserId] = {
                rank = group.role.rank,
                role = group.role.name
            }
            return group.role.rank, group.role.name
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
