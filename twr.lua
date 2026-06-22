local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local WorldToScreen = WorldToScreen
local Drawing = Drawing
local tick = tick
local math = math
local ipairs = ipairs

local iskeypressed = iskeypressed

local HEAD_EXPANDER_ENABLED = true
local lastCapsState = false

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

local TEXT_SIZE = 18
local MAX_VISIBLE = 8
local MAX_DISTANCE = 80
local UPDATE_INTERVAL = 0.022

-- Map model names to colors
local TYPE_CONFIG = {
    Ammo = {
        Color = Color3.fromRGB(0, 180, 0)
    },
    Medkit = {
        Color = Color3.fromRGB(180, 0, 0)
    },
    Bandages = {
        Color = Color3.fromRGB(222, 204, 168)
    }
}

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
    label.Size = TEXT_SIZE
    label.Font = Drawing.Fonts.UI
    label.Center = true
    label.Outline = true
    label.Color = color
    label.Visible = false
    table.insert(_G.AmmoESP_Labels, label)
    return label
end

local function GetLabel(i)
    if not labels[i] then
        local config = TYPE_CONFIG[ammoItems[i] and ammoItems[i].Type]
        local color = config and config.Color or Color3.fromRGB(255, 255, 255)
        labels[i] = CreateLabel(color)
    end
    return labels[i]
end

local function ScanForItems()
    if _G.AmmoESP_RunId ~= runId then return end
    
    local items = Workspace:FindFirstChild("Ignore")
    if items then
        items = items:FindFirstChild("Items")
    end
    if not items then return end

    local newItems = {}

    for _, child in ipairs(items:GetChildren()) do
        if child:IsA("Model") then
            -- Check by model name
            local typeName = child.Name
            if TYPE_CONFIG[typeName] then
                local part = child:FindFirstChild("Box")
                if part and part:IsA("BasePart") then
                    table.insert(newItems, {
                        Part = part,
                        Type = typeName
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
    end
end

local function UpdateESP()
    if _G.AmmoESP_RunId ~= runId then return end
    
    local charPos = GetCharacterPosition()
    if not charPos then return end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    local visibleCount = 0
    
    for i, data in ipairs(ammoItems) do
        local label = GetLabel(i)
        local maxDistSq = MAX_DISTANCE * MAX_DISTANCE
        
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
        end
    end
    
    for idx = 1, showCount do
        local label = GetLabel(visibleIndices[idx])
        local dist = visibleDists[idx]
        local screenPos = visibleScreenPos[idx]
        
        label.Position = Vector2.new(screenPos.X, screenPos.Y - 10)
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

task.spawn(function()
    while _G.AmmoESP_RunId == runId do
        local capsDown = iskeypressed(0x14) -- Caps Lock

        if capsDown and not lastCapsState then
            HEAD_EXPANDER_ENABLED = not HEAD_EXPANDER_ENABLED

            print("Head Expander:", HEAD_EXPANDER_ENABLED and "ON" or "OFF")

            pcall(function()
                if _G.notify then
                    _G.notify(
                        "Head Expander",
                        HEAD_EXPANDER_ENABLED and "Enabled" or "Disabled",
                        3
                    )
                end
            end)
        end

        lastCapsState = capsDown
        task.wait(0.05)
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
            if HEAD_EXPANDER_ENABLED then
    for _, zombie in ipairs(infected:GetChildren()) do
        local head = zombie:FindFirstChild("Head")

        if head
            and head:IsA("BasePart")
            and head.Size.X ~= headSize
        then
            pcall(function()
                head.Size = Vector3.new(headSize, headSize, headSize)
            end)
        end
    end
end
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
