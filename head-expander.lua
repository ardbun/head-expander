local headSize = 6

local playerNames = {}
for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
    playerNames[player.Name] = true
end

task.spawn(function()
    while true do
        local infected = workspace:FindFirstChild("Entities")
            and workspace.Entities:FindFirstChild("Infected")
        
        if infected then
            for _, zombie in ipairs(infected:GetChildren()) do
                if zombie:IsA("Model") then
                    if playerNames[zombie.Name] then
                        continue
                    end
                    
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
