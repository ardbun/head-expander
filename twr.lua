local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

_G.HeadExpander_RunId = (_G.HeadExpander_RunId or 0) + 1
local runId = _G.HeadExpander_RunId

-- ===== HEAD EXPANDER =====
local headSize = 5

task.spawn(function()
    while _G.HeadExpander_RunId == runId do
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

-- ===== NOTIFICATION =====
if _G.notify then
    _G.notify("Head Expander", "Loaded | Run ID: " .. runId, 4)
elseif notify then
    notify("Head Expander", "Loaded | Run ID: " .. runId, 4)
else
    print("Head Expander Loaded | Run ID: " .. runId)
end

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
    while _G.HeadExpander_RunId == runId do
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
