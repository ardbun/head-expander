local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local CONFIG = {
    MaxVisible = 5,
    MaxDistance = 70,
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
    Medkit = { Color = Color3.fromRGB(180, 0, 0) },
    Bandages = { Color = Color3.fromRGB(222, 204, 168) },
    AmmoBoxes = { Color = Color3.fromRGB(0, 180, 0) },
}

local WHITE = Color3.new(1, 1, 1)
local MaxDistanceSq = CONFIG.MaxDistance * CONFIG.MaxDistance

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
local FadeMul = (1 / 3.5714285714) / CONFIG.FadeDistance

local State = {
    RunId = ((_G.MatchaItemScript_RunId or 0) + 1),
    Items = {},
    Labels = {},
    LabelCache = {},
    Circles = {},
    CircleColors = {},
    VisibleItems = {},
    RankCache = {},
    LastStaffString = "",
    ZombieHeads = {},
    ZombieHealth = {},
    SeenZombies = {},
    ShownThisFrame = {},
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
    local modelName = string.lower(model.Name)

    if modelName == "bandages" then
        return "Bandages"
    elseif modelName == "medkit" then
        return "Medkit"
    elseif modelName == "ammo" then
        return "AmmoBoxes"
    end

    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("MeshPart") then
            local n = string.lower(child.Name)

            if n == "medkit" then
                return "Medkit"
            elseif n == "bandages" then
                return "Bandages"
            elseif n == "ammoboxes" then
                return "AmmoBoxes"
            end
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
    label.Font = Drawing.Fonts.SystemBold
    label.Center = true
    label.Outline = true
    label.Color = color
    label.Visible = false
    table.insert(_G.MatchaItemScript_Labels, label)
    return label
end

local function getLabel(index)
    local item = State.Items[index]
    local color = item.Meta.Color
    
    local label = State.Labels[index]
    if not label then
        label = createLabel(color)
        State.Labels[index] = label
    elseif label.Color ~= color then
        label.Color = color
    end
    
    return label
end

local function ensureCircleSegments(index)
    if not State.Circles[index] then
        State.Circles[index] = createCircleSegments(CONFIG.CircleSegments)
        State.CircleColors[index] = {}
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
        table.remove(State.LabelCache)
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
            State.CircleColors[i] = nil
        end
    end
    while #State.Circles > newCount do
        table.remove(State.Circles)
        table.remove(State.CircleColors)
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
        hideLabels()
        hideCircles()
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
                        Meta = ITEM_META[matchedName],
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
    
    if not Workspace.CurrentCamera then
        hideLabels()
        hideCircles()
        return
    end
    
    local charPos = getLocalPosition()
    if not charPos then
        hideLabels()
        hideCircles()
        return
    end
    
    table.clear(State.ShownThisFrame)
    table.clear(State.VisibleItems)
    local visibleCount = 0
    
    for i, data in ipairs(State.Items) do
        local part = data.Part
        if part and part.Parent then
            local pos = part.Position
            
            if pos then
                local dx = pos.X - charPos.X
                local dy = pos.Y - charPos.Y
                local dz = pos.Z - charPos.Z
                local distSq = dx*dx + dy*dy + dz*dz
                
                if distSq <= MaxDistanceSq then
                    local screenPos, onScreen = WorldToScreen(pos)
                    
                    if onScreen then
                        visibleCount = visibleCount + 1
                        State.VisibleItems[visibleCount] = {
                            Index = i,
                            DistanceSq = distSq,
                            ScreenPos = screenPos,
                            WorldPos = pos,
                        }
                    end
                end
            end
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
        local distanceSq = item.DistanceSq
        local distance = math.sqrt(distanceSq)
        local label = getLabel(item.Index)
        local circle = ensureCircleSegments(item.Index)
        local color = State.Items[item.Index].Meta.Color
        local colorCache = State.CircleColors[item.Index]
        
        label.Position = Vector2.new(item.ScreenPos.X, item.ScreenPos.Y - CONFIG.TextYOffset)
        
        local meters = math.floor(distance)
        if State.LabelCache[item.Index] ~= meters then
            State.LabelCache[item.Index] = meters
            label.Text = meters .. "m"
        end
        label.Visible = true
        
        State.ShownThisFrame[item.Index] = true
        
        local alpha = 1 - distance * FadeMul
        if alpha <= 0 then
            for _, seg in ipairs(circle) do
                seg.Visible = false
            end
        else
            if alpha > 1 then alpha = 1 end
            
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
                    
                    if colorCache[j] ~= color then
                        colorCache[j] = color
                        seg.Color = color
                    end
                    
                    seg.Transparency = alpha
                    seg.Visible = true
                else
                    if seg then seg.Visible = false end
                end
            end
        end
    end
    
    for i = 1, #State.Items do
        if not State.ShownThisFrame[i] then
            hideLabel(i)
            hideCircle(i)
        end
    end
end

local function updateZombieHeads()
    local infectedContainer = Workspace:FindFirstChild("Entities")
    if infectedContainer then
        infectedContainer = infectedContainer:FindFirstChild("Infected")
    end
    if not infectedContainer then
        table.clear(State.ZombieHeads)
        table.clear(State.ZombieHealth)
        return
    end
    
    local seen = State.SeenZombies
    table.clear(seen)
    
    for _, zombie in ipairs(infectedContainer:GetChildren()) do
        if zombie:IsA("Model") then
            local addr = zombie.Address or tostring(zombie)
            seen[addr] = true
            
            if not State.ZombieHeads[addr] then
                local humanoid = zombie:FindFirstChild("Humanoid")
                local head = zombie:FindFirstChild("Head")
                if humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") then
                    State.ZombieHeads[addr] = head
                    State.ZombieHealth[addr] = humanoid
                end
            end
        end
    end
    
    for addr in pairs(State.ZombieHeads) do
        if not seen[addr] then
            State.ZombieHeads[addr] = nil
            State.ZombieHealth[addr] = nil
        end
    end
    
    for addr, head in pairs(State.ZombieHeads) do
        if head and head.Parent and head.Size ~= TargetHeadSize then
            local health = State.ZombieHealth[addr]
            if health and health.Health > 0 then
                pcall(function()
                    head.Size = TargetHeadSize
                end)
            else
                State.ZombieHeads[addr] = nil
                State.ZombieHealth[addr] = nil
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

-- RenderStepped for ESP drawing
RunService.RenderStepped:Connect(function()
    if _G.MatchaItemScript_RunId == State.RunId then
        updateItemEsp()
    end
end)

task.spawn(function()
    while _G.MatchaItemScript_RunId == State.RunId do
        task.wait(CONFIG.CacheClearInterval)
        table.clear(State.RankCache)
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
