local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local CONFIG = {
    MaxVisible = 5,
    MaxDistance = 70,
    UpdateInterval = 0.022,
    ScanInterval = 0.5,
    TextSize = 18,
    HeadSize = 5,
    StaffCheckInterval = 30,
    StaffGroupId = 2838077,
    MinStaffRank = 250,
    ZombieUpdateInterval = 0.5,
    TextYOffset = 15,
}

local ITEM_META = {
    Medkit = { Color = Color3.fromRGB(180, 0, 0) },
    Bandages = { Color = Color3.fromRGB(222, 204, 168) },
    AmmoBoxes = { Color = Color3.fromRGB(0, 180, 0) },
}

local State = {
    RunId = ((_G.MatchaItemScript_RunId or 0) + 1),
    Items = {},
    Labels = {},
    VisibleItems = {},
    RankCache = {},
    LastStaffString = "",
}
_G.MatchaItemScript_RunId = State.RunId

local LocalPlayer = Players.LocalPlayer

if _G.MatchaItemScript_Labels then
    for _, label in ipairs(_G.MatchaItemScript_Labels) do
        pcall(function()
            label.Visible = false
            label:Remove()
        end)
    end
end
_G.MatchaItemScript_Labels = {}

local function getLocalPosition()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    return nil
end

local function createLabel(color)
    local label = Drawing.new("Text")
    label.Size = CONFIG.TextSize
    label.Font = Drawing.Fonts.UI
    label.Center = true
    label.Outline = true
    label.Color = color
    label.Visible = false
    table.insert(_G.MatchaItemScript_Labels, label)
    return label
end

local function getLabel(index)
    if not State.Labels[index] then
        State.Labels[index] = createLabel(Color3.fromRGB(255, 255, 255))
    end
    
    local item = State.Items[index]
    if item then
        local meta = ITEM_META[item.OriginalName]
        if meta then
            State.Labels[index].Color = meta.Color
        end
    end
    
    return State.Labels[index]
end

local function hideLabel(index)
    local label = getLabel(index)
    label.Visible = false
end

local function hideLabels()
    for i = 1, #State.Labels do
        if State.Labels[i] then
            State.Labels[i].Visible = false
        end
    end
end

local function trimLabels(newCount)
    for i = newCount + 1, #State.Labels do
        if State.Labels[i] then
            pcall(function()
                State.Labels[i].Visible = false
                State.Labels[i]:Remove()
            end)
            State.Labels[i] = nil
        end
    end
    while #State.Labels > newCount do
        table.remove(State.Labels)
    end
end

local function scanItems()
    if _G.MatchaItemScript_RunId ~= State.RunId then return end
    
    local itemsContainer = Workspace:FindFirstChild("Ignore")
    if itemsContainer then
        itemsContainer = itemsContainer:FindFirstChild("Items")
    end
    if not itemsContainer then 
        State.Items = {}
        trimLabels(0)
        return 
    end
    
    local newItems = {}
    
    for _, model in ipairs(itemsContainer:GetChildren()) do
        if model:IsA("Model") then
            local matchedName = nil
            
            for _, child in ipairs(model:GetChildren()) do
                if child:IsA("MeshPart") and child.Name ~= "Box" then
                    if ITEM_META[child.Name] then
                        matchedName = child.Name
                        break
                    end
                end
            end
            
            if matchedName then
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
    
    State.Items = newItems
    trimLabels(#State.Items)
end

local function updateItemEsp()
    if _G.MatchaItemScript_RunId ~= State.RunId then return end
    
    local charPos = getLocalPosition()
    if not charPos or not Workspace.CurrentCamera then
        hideLabels()
        return
    end
    
    State.VisibleItems = {}
    
    local visibleCount = 0
    local maxDistSq = CONFIG.MaxDistance * CONFIG.MaxDistance
    
    for i, data in ipairs(State.Items) do
        local part = data.Part
        if part and part.Parent and part:IsA("BasePart") then
            local pos = part.Position
            
            if pos then
                local dx = pos.X - charPos.X
                local dy = pos.Y - charPos.Y
                local dz = pos.Z - charPos.Z
                local distSq = dx*dx + dy*dy + dz*dz
                
                if distSq <= maxDistSq then
                    local success, screenPos, onScreen = pcall(WorldToScreen, pos)
                    
                    if success and onScreen then
                        visibleCount = visibleCount + 1
                        State.VisibleItems[visibleCount] = {
                            Index = i,
                            Distance = math.sqrt(distSq),
                            ScreenPos = screenPos
                        }
                    else
                        hideLabel(i)
                    end
                else
                    hideLabel(i)
                end
            else
                hideLabel(i)
            end
        else
            hideLabel(i)
        end
    end
    
    local showCount = math.min(visibleCount, CONFIG.MaxVisible)
    for i = 1, showCount do
        local bestIdx = i
        local bestDist = State.VisibleItems[i].Distance
        for j = i + 1, visibleCount do
            if State.VisibleItems[j].Distance < bestDist then
                bestDist = State.VisibleItems[j].Distance
                bestIdx = j
            end
        end
        if bestIdx ~= i then
            State.VisibleItems[i], State.VisibleItems[bestIdx] = State.VisibleItems[bestIdx], State.VisibleItems[i]
        end
    end
    
    for idx = 1, showCount do
        local item = State.VisibleItems[idx]
        local label = getLabel(item.Index)
        
        label.Position = Vector2.new(item.ScreenPos.X, item.ScreenPos.Y - CONFIG.TextYOffset)
        label.Text = tostring(math.floor(item.Distance)) .. "m"
        label.Visible = true
    end
    
    for idx = showCount + 1, visibleCount do
        hideLabel(State.VisibleItems[idx].Index)
    end
end

local function updateZombieHeads()
    local infectedContainer = Workspace:FindFirstChild("Entities")
    if infectedContainer then
        infectedContainer = infectedContainer:FindFirstChild("Infected")
    end
    if not infectedContainer then return end
    
    local targetSize = CONFIG.HeadSize
    
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

local function getGroupRank(userId)
    if State.RankCache[userId] then
        return State.RankCache[userId].rank, State.RankCache[userId].role
    end
    
    local url = "https://groups.roblox.com/v2/users/" .. userId .. "/groups/roles"
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
            if group.group and group.group.id == CONFIG.StaffGroupId then
                State.RankCache[userId] = {
                    rank = group.role.rank,
                    role = group.role.name
                }
                return group.role.rank, group.role.name
            end
        end
    end
    
    State.RankCache[userId] = { rank = 0, role = "Unknown" }
    return 0, "Unknown"
end

local function updateStaffCheck()
    if _G.MatchaItemScript_RunId ~= State.RunId then return end
    
    local staffNames = {}
    local players = Players:GetPlayers()
    
    for _, player in ipairs(players) do
        local userId = player.UserId
        if userId then
            local rank, roleName = getGroupRank(userId)
            if rank >= CONFIG.MinStaffRank then
                table.insert(staffNames, player.Name .. " (" .. roleName .. ")")
            end
        end
    end
    
    local staffString = table.concat(staffNames, ", ")
    local previousStaffString = State.LastStaffString
    
    if staffString ~= previousStaffString then
        State.LastStaffString = staffString
        
        if staffString ~= "" and notify then
            pcall(function()
                notify("Staff Online (" .. #staffNames .. ")", staffString, 10)
            end)
        elseif staffString == "" and previousStaffString ~= "" and notify then
            pcall(function()
                notify("Staff Online", "No staff members online", 10)
            end)
        end
    end
end

task.spawn(function()
    while _G.MatchaItemScript_RunId == State.RunId do
        scanItems()
        task.wait(CONFIG.ScanInterval)
    end
end)

task.spawn(function()
    while _G.MatchaItemScript_RunId == State.RunId do
        updateItemEsp()
        task.wait(CONFIG.UpdateInterval)
    end
end)

task.spawn(function()
    while _G.MatchaItemScript_RunId == State.RunId do
        updateZombieHeads()
        task.wait(CONFIG.ZombieUpdateInterval)
    end
end)

task.spawn(function()
    while _G.MatchaItemScript_RunId == State.RunId do
        updateStaffCheck()
        task.wait(CONFIG.StaffCheckInterval)
    end
end)

if notify then
    pcall(function()
        notify("Item ESP", "Loaded | Run ID: " .. State.RunId, 4)
    end)
end
