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
    CircleSegments = 16,
    CircleRadius = 1.8,
    CircleYOffset = 1.0,
    FadeDistance = 40,
    CacheClearInterval = 1800,
    CircleThickness = 2,
}

local ITEM_META = {
    Medkit = { Color = Color3.fromRGB(180, 0, 0), Label = "medkit" },
    Bandages = { Color = Color3.fromRGB(222, 204, 168), Label = "bandages" },
    AmmoBoxes = { Color = Color3.fromRGB(0, 180, 0), Label = "ammo" },
}

-- Priority order for item detection
local ITEM_PRIORITY = {
    "Bandages",
    "Medkit",
    "AmmoBoxes",
}

local CircleOffsets = {}
for i = 1, CONFIG.CircleSegments do
    local a = (i - 1) * (2 * math.pi / CONFIG.CircleSegments)
    CircleOffsets[i] = Vector3.new(
        math.cos(a) * CONFIG.CircleRadius,
        0,
        math.sin(a) * CONFIG.CircleRadius
    )
end

local CircleOffset = Vector3.new(0, CONFIG.CircleYOffset, 0)
local TargetHeadSize = Vector3.new(CONFIG.HeadSize, CONFIG.HeadSize, CONFIG.HeadSize)

local State = {
    RunId = ((_G.MatchaItemScript_RunId or 0) + 1),
    Items = {},
    Labels = {},
    Circles = {},
    VisibleItems = {},
    RankCache = {},
    LastStaffString = "",
}
_G.MatchaItemScript_RunId = State.RunId

local LocalPlayer = Players.LocalPlayer
local studConv = 1 / 3.5714285714

if _G.MatchaItemScript_Labels then
    for _, label in ipairs(_G.MatchaItemScript_Labels) do
        pcall(function()
            label.Visible = false
            label:Remove()
        end)
    end
end
_G.MatchaItemScript_Labels = {}

if _G.MatchaItemScript_Circles then
    for _, circle in ipairs(_G.MatchaItemScript_Circles) do
        pcall(function()
            circle.Visible = false
            circle:Remove()
        end)
    end
end
_G.MatchaItemScript_Circles = {}

local function getItemType(model)
    for _, itemName in ipairs(ITEM_PRIORITY) do
        if model:FindFirstChild(itemName) then
            return itemName
        end
    end
    return nil
end

local function newLineSegment()
    local ok, l = pcall(function() return Drawing.new("Line") end)
    if not ok or not l then return nil end
    l.Visible = false
    l.From = Vector2.new(0, 0)
    l.To = Vector2.new(0, 0)
    l.Thickness = CONFIG.CircleThickness
    return l
end

local function createCircleSegments(segCount)
    local segs = {}
    for i = 1, segCount do
        local l = newLineSegment()
        if l then segs[#segs + 1] = l end
    end
    return segs
end

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
        local color = Color3.fromRGB(255, 255, 255)
        local item = State.Items[index]
        if item then
            local meta = ITEM_META[item.OriginalName]
            if meta then
                color = meta.Color
            end
        end
        State.Labels[index] = createLabel(color)
    end
    return State.Labels[index]
end

local function ensureCircleSegments(index)
    if not State.Circles[index] then
        State.Circles[index] = createCircleSegments(CONFIG.CircleSegments)
        for _, seg in ipairs(State.Circles[index]) do
            table.insert(_G.MatchaItemScript_Circles, seg)
        end
    end
    return State.Circles[index]
end

local function hideCircle(index)
    local circle = State.Circles[index]
    if not circle then return end
    for _, seg in ipairs(circle) do
        seg.Visible = false
    end
end

local function hideLabel(index)
    local label = State.Labels[index]
    if label then label.Visible = false end
end

local function hideLabels()
    for i = 1, #State.Labels do
        if State.Labels[i] then
            State.Labels[i].Visible = false
        end
    end
end

local function hideCircles()
    for _, circle in ipairs(State.Circles) do
        if circle then
            for _, seg in ipairs(circle) do
                if seg then seg.Visible = false end
            end
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

local function trimCircles(newCount)
    for i = newCount + 1, #State.Circles do
        if State.Circles[i] then
            pcall(function()
                for _, seg in ipairs(State.Circles[i]) do
                    if seg then
                        seg.Visible = false
                        seg:Remove()
                    end
                end
            end)
            State.Circles[i] = nil
        end
    end
    while #State.Circles > newCount do
        table.remove(State.Circles)
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
        trimCircles(0)
        return 
    end
    
    local newItems = {}
    
    for _, model in ipairs(itemsContainer:GetChildren()) do
        if model:IsA("Model") then
            local matchedName = getItemType(model)
            
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
    trimCircles(#State.Items)
end

local function updateItemEsp()
    if _G.MatchaItemScript_RunId ~= State.RunId then return end
    
    local charPos = getLocalPosition()
    if not charPos then
        hideLabels()
        hideCircles()
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
                    local screenPos, onScreen = WorldToScreen(pos)
                    
                    if onScreen then
                        visibleCount = visibleCount + 1
                        State.VisibleItems[visibleCount] = {
                            Index = i,
                            DistanceSq = distSq,
                            ScreenPos = screenPos,
                            WorldPos = pos
                        }
                    else
                        hideLabel(i)
                        hideCircle(i)
                    end
                else
                    hideLabel(i)
                    hideCircle(i)
                end
            else
                hideLabel(i)
                hideCircle(i)
            end
        else
            hideLabel(i)
            hideCircle(i)
        end
    end
    
    local showCount = math.min(visibleCount, CONFIG.MaxVisible)
    for i = 1, showCount do
        local bestIdx = i
        local bestDist = State.VisibleItems[i].DistanceSq
        for j = i + 1, visibleCount do
            if State.VisibleItems[j].DistanceSq < bestDist then
                bestDist = State.VisibleItems[j].DistanceSq
                bestIdx = j
            end
        end
        if bestIdx ~= i then
            State.VisibleItems[i], State.VisibleItems[bestIdx] = State.VisibleItems[bestIdx], State.VisibleItems[i]
        end
    end
    
    for idx = 1, showCount do
        local item = State.VisibleItems[idx]
        local distance = math.sqrt(item.DistanceSq)
        local label = getLabel(item.Index)
        local circle = ensureCircleSegments(item.Index)
        local meta = ITEM_META[State.Items[item.Index].OriginalName]
        local color = meta and meta.Color or Color3.fromRGB(255, 255, 255)
        
        label.Position = Vector2.new(item.ScreenPos.X, item.ScreenPos.Y - CONFIG.TextYOffset)
        label.Text = tostring(math.floor(distance)) .. "m"
        label.Visible = true
        
        local meters = distance * studConv
        local alpha = math.clamp(1 - (meters / CONFIG.FadeDistance), 0, 1)
        
        if alpha > 0 then
            local segCount = #circle
            local centerWorld = item.WorldPos - CircleOffset
            
            for j = 1, segCount do
                local off1 = CircleOffsets[j]
                local off2 = CircleOffsets[(j % segCount) + 1]
                local w1 = centerWorld + off1
                local w2 = centerWorld + off2
                local sp1, on1 = WorldToScreen(w1)
                local sp2, on2 = WorldToScreen(w2)
                local seg = circle[j]
                
                if on1 and on2 and seg then
                    seg.From = sp1
                    seg.To = sp2
                    seg.Color = color
                    seg.Transparency = alpha
                    seg.Visible = true
                else
                    if seg then seg.Visible = false end
                end
            end
        else
            for _, seg in ipairs(circle) do
                seg.Visible = false
            end
        end
    end
    
    for idx = showCount + 1, visibleCount do
        hideCircle(State.VisibleItems[idx].Index)
        hideLabel(State.VisibleItems[idx].Index)
    end
end

local function updateZombieHeads()
    local infectedContainer = Workspace:FindFirstChild("Entities")
    if infectedContainer then
        infectedContainer = infectedContainer:FindFirstChild("Infected")
    end
    if not infectedContainer then return end
    
    for _, zombie in ipairs(infectedContainer:GetChildren()) do
        if zombie:IsA("Model") then
            local humanoid = zombie:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local head = zombie:FindFirstChild("Head")
                if head and head:IsA("BasePart") and head.Size ~= TargetHeadSize then
                    pcall(function()
                        head.Size = TargetHeadSize
                    end)
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
        task.wait(CONFIG.CacheClearInterval)
        State.RankCache = {}
    end
end)

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
