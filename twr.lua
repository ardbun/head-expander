local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    MAX_VISIBLE = 5,
    MAX_DISTANCE = 70,
    UPDATE_INTERVAL = 0.022,
    SCAN_INTERVAL = 0.5,
    TEXT_SIZE = 18,
    HEAD_SIZE = 5,
    
    ITEM_TYPES = {
        Medkit = { Type = "Medkit", Color = Color3.fromRGB(180, 0, 0) },
        Bandages = { Type = "Bandages", Color = Color3.fromRGB(222, 204, 168) },
        AmmoBoxes = { Type = "Ammo", Color = Color3.fromRGB(0, 180, 0) },
    }
}

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
_G.AmmoESP_Labels = {}

local ammoItems = {}
local labels = {}
local visibleDists = {}
local visibleScreenPos = {}
local visibleIndices = {}

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
    label.Size = CONFIG.TEXT_SIZE
    label.Font = Drawing.Fonts.UI
    label.Center = true
    label.Outline = true
    label.Color = color
    label.Visible = false
    table.insert(_G.AmmoESP_Labels, label)
    return label
end

local function GetLabel(index)
    if not labels[index] then
        labels[index] = CreateLabel(Color3.fromRGB(255, 255, 255))
    end
    
    local item = ammoItems[index]
    if item then
        local config = CONFIG.ITEM_TYPES[item.OriginalName]
        if config then
            labels[index].Color = config.Color
        end
    end
    
    return labels[index]
end

local function CleanupExtraLabels(newCount)
    for i = newCount + 1, #labels do
        if labels[i] then
            pcall(function()
                labels[i].Visible = false
                labels[i]:Remove()
            end)
            labels[i] = nil
        end
    end
    while #labels > newCount do
        table.remove(labels)
    end
end

local function ScanForItems()
    if _G.AmmoESP_RunId ~= runId then return end
    
    local itemsContainer = Workspace:FindFirstChild("Ignore")
    if itemsContainer then
        itemsContainer = itemsContainer:FindFirstChild("Items")
    end
    if not itemsContainer then 
        ammoItems = {}
        CleanupExtraLabels(0)
        return 
    end
    
    local newItems = {}
    
    for _, model in ipairs(itemsContainer:GetChildren()) do
        if model:IsA("Model") then
            local matchedPart = nil
            local matchedName = nil
            local config = nil
            
            for _, child in ipairs(model:GetChildren()) do
                if child:IsA("MeshPart") and child.Name ~= "Box" then
                    local childConfig = CONFIG.ITEM_TYPES[child.Name]
                    if childConfig then
                        matchedPart = child
                        matchedName = child.Name
                        config = childConfig
                        break
                    end
                end
            end
            
            if matchedPart and config then
                local boxPart = model:FindFirstChild("Box")
                if boxPart and boxPart:IsA("BasePart") then
                    table.insert(newItems, {
                        Part = boxPart,
                        OriginalName = matchedName,
                    })
                end
            end
        end
    end
    
    ammoItems = newItems
    CleanupExtraLabels(#ammoItems)
end

local function UpdateESP()
    if _G.AmmoESP_RunId ~= runId then return end
    
    local charPos = GetCharacterPosition()
    if not charPos then return end
    
    if not Workspace.CurrentCamera then return end
    
    local visibleCount = 0
    local maxDistSq = CONFIG.MAX_DISTANCE * CONFIG.MAX_DISTANCE
    
    for i, data in ipairs(ammoItems) do
        local part = data.Part
        if part and part.Parent and part:IsA("BasePart") then
            local pos = part.Position
            
            if not pos then
                local label = GetLabel(i)
                label.Visible = false
                continue
            end
            
            local dx = pos.X - charPos.X
            local dy = pos.Y - charPos.Y
            local dz = pos.Z - charPos.Z
            local distSq = dx*dx + dy*dy + dz*dz
            
            if distSq <= maxDistSq then
                local success, screenPos, onScreen = pcall(WorldToScreen, pos)
                if success and onScreen then
                    visibleCount = visibleCount + 1
                    visibleIndices[visibleCount] = i
                    visibleDists[visibleCount] = math.sqrt(distSq)
                    visibleScreenPos[visibleCount] = screenPos
                else
                    local label = GetLabel(i)
                    label.Visible = false
                end
            else
                local label = GetLabel(i)
                label.Visible = false
            end
        else
            local label = GetLabel(i)
            label.Visible = false
        end
    end
    
    local showCount = math.min(visibleCount, CONFIG.MAX_VISIBLE)
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
        end
    end
    
    for idx = 1, showCount do
        local itemIndex = visibleIndices[idx]
        local label = GetLabel(itemIndex)
        local dist = visibleDists[idx]
        local screenPos = visibleScreenPos[idx]
        
        label.Position = Vector2.new(screenPos.X, screenPos.Y - 15)
        label.Text = tostring(math.floor(dist)) .. "m"
        label.Visible = true
    end
    
    for idx = showCount + 1, visibleCount do
        local label = GetLabel(visibleIndices[idx])
        if label then
            label.Visible = false
        end
    end
end

local function ExpandZombieHeads()
    local infectedContainer = Workspace:FindFirstChild("Entities")
    if infectedContainer then
        infectedContainer = infectedContainer:FindFirstChild("Infected")
    end
    if not infectedContainer then return end
    
    local targetSize = CONFIG.HEAD_SIZE
    
    for _, zombie in ipairs(infectedContainer:GetChildren()) do
        if zombie:IsA("Model") then
            local humanoid = zombie:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local head = zombie:FindFirstChild("Head")
                if head and head:IsA("BasePart") then
                    local currentSize = head.Size
                    if math.abs(currentSize.X - targetSize) > 0.01 then
                        pcall(function()
                            head.Size = Vector3.new(targetSize, targetSize, targetSize)
                        end)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        ScanForItems()
        task.wait(CONFIG.SCAN_INTERVAL)
    end
end)

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        UpdateESP()
        task.wait(CONFIG.UPDATE_INTERVAL)
    end
end)

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        ExpandZombieHeads()
        task.wait(0.5)
    end
end)

if notify then
    pcall(function()
        notify("Item ESP", "Loaded | Run ID: " .. runId, 4)
    end)
end

local GroupId = 2838077
local MinRank = 250

local rankCache = {}
local lastStaffString = ""
local lastNotifyTime = 0
local lastStaffCount = 0

local function GetRankInGroup(UserId, GroupId)
    if rankCache[UserId] then
        return rankCache[UserId].rank, rankCache[UserId].role
    end
    
    local url = "https://groups.roblox.com/v2/users/" .. UserId .. "/groups/roles"
    local success, response = pcall(httpget, url)
    
    if not success or response == "" then 
        return 0, "Unknown" 
    end
    
    local success2, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success2 or not data then 
        return 0, "Unknown" 
    end
    
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
        local players = Players:GetPlayers()
        
        for _, player in ipairs(players) do
            local userId = player.UserId
            if userId then
                local rank, roleName = GetRankInGroup(userId, GroupId)
                if rank >= MinRank then
                    table.insert(staffNames, player.Name .. " (" .. roleName .. ")")
                end
            end
        end
        
        local staffString = table.concat(staffNames, ", ")
        local currentTime = tick()
        local staffCount = #staffNames
        
        local previousStaffCount = lastStaffCount
        lastStaffCount = staffCount
        
        if staffString ~= lastStaffString or currentTime - lastNotifyTime > 30 then
            lastStaffString = staffString
            lastNotifyTime = currentTime
            
            if staffCount > 0 and notify then
                pcall(function()
                    notify("Staff Online (" .. staffCount .. ")", staffString, 10)
                end)
            elseif staffCount == 0 and previousStaffCount > 0 and notify then
                pcall(function()
                    notify("Staff Online", "No staff members online", 10)
                end)
            end
        end
        
        task.wait(30)
    end
end)
