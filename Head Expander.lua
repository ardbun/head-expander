local headSize = Vector3.new(10, 10, 10)
local resized = {}

local function resizeHead(zombie)
    if not zombie or not zombie:IsA("Model") then return end
    local head = zombie:FindFirstChild("Head")
    if head and not resized[zombie] then
        head.Size = headSize
        resized[zombie] = true
    end
end

local function setupFolder(folder)
    for _, zombie in pairs(folder:GetChildren()) do
        resizeHead(zombie)
    end

    folder.ChildAdded:Connect(function(zombie)
        task.wait() -- wait a frame for the model to fully load
        resizeHead(zombie)
    end)

    folder.ChildRemoved:Connect(function(zombie)
        resized[zombie] = nil
    end)
end

local entities = game.Workspace:WaitForChild("Entities")
local infectedFolder = entities:WaitForChild("Infected")
setupFolder(infectedFolder)