-- Rayfield GUI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============ SERVICES ============
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============ VARIABLES ============
local clueESPEnabled = false
local separationESPEnabled = false
local showInnocent = true
local showSheriff = true
local showMurderer = true
local showDead = false
local gunESPEnabled = false

local autoWalkCollectEnabled = false
local instantCollectEnabled = false
local instantCollectRange = 200  -- default max
local autoWalkRange = 8

local flyEnabled = false
local flySpeed = 50
local walkSpeedEnabled = false
local customWalkSpeed = 16
local killAuraEnabled = false
local killAuraRange = 20
local autoRejoinEnabled = false
local autoServerHopOnKick = false

local clueESPObjects = {}
local separationESPObjects = {}
local gunESPMarkers = {}
local sheriffDeathConnections = {}

-- ============ CONFIG SYSTEM ============
local CONFIG_FOLDER = "ItemAsylum_Configs"
local AUTORUN_FILE = CONFIG_FOLDER .. "/autorun.txt"
if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end

local function GetConfigList()
    local files = listfiles(CONFIG_FOLDER)
    local names = {}
    for _, path in ipairs(files) do
        local name = path:match("([^/\\]+)$")
        if name and name:sub(-5) == ".json" then
            table.insert(names, name:sub(1, -6))
        end
    end
    return names
end

local function SaveConfig(name)
    local data = {
        clueESPEnabled = clueESPEnabled,
        separationESPEnabled = separationESPEnabled,
        showInnocent = showInnocent,
        showSheriff = showSheriff,
        showMurderer = showMurderer,
        showDead = showDead,
        gunESPEnabled = gunESPEnabled,
        autoWalkCollectEnabled = autoWalkCollectEnabled,
        instantCollectEnabled = instantCollectEnabled,
        instantCollectRange = instantCollectRange,
        autoWalkRange = autoWalkRange,
        flyEnabled = flyEnabled,
        flySpeed = flySpeed,
        walkSpeedEnabled = walkSpeedEnabled,
        customWalkSpeed = customWalkSpeed,
        killAuraEnabled = killAuraEnabled,
        killAuraRange = killAuraRange,
        autoRejoinEnabled = autoRejoinEnabled,
        autoServerHopOnKick = autoServerHopOnKick,
    }
    writefile(CONFIG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
end

local function GetAutoRunConfig()
    if isfile(AUTORUN_FILE) then return readfile(AUTORUN_FILE) end
    return nil
end
local function SetAutoRunConfig(name)
    if name and name ~= "" then writefile(AUTORUN_FILE, name) end
end
local function ClearAutoRun()
    if isfile(AUTORUN_FILE) then delfile(AUTORUN_FILE) end
end
local function DeleteConfig(name)
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if isfile(path) then delfile(path) end
end

-- ============ ROLE DETECTION ============
local SHERIFF_GUNS = {
    ["mad sheriff"] = true,
    ["mad handgun"] = true,
}

local function isMurdererTool(toolName)
    return toolName:lower():sub(1, 3) == "mu_"
end

local function isSheriffTool(toolName)
    return SHERIFF_GUNS[toolName:lower()] == true
end

local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Health > 0
end

local function GetRole(player)
    if not IsAlive(player) then return "Dead" end
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then
                if isMurdererTool(obj.Name) then return "Murderer" end
                if isSheriffTool(obj.Name) then return "Sheriff" end
            end
        end
    end
    if backpack then
        for _, obj in ipairs(backpack:GetChildren()) do
            if obj:IsA("Tool") then
                if isMurdererTool(obj.Name) then return "Murderer" end
                if isSheriffTool(obj.Name) then return "Sheriff" end
            end
        end
    end
    return "Innocent"
end

local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 50, 50) end
    if role == "Sheriff"  then return Color3.fromRGB(50, 150, 255) end
    if role == "Dead"     then return Color3.fromRGB(120, 120, 120) end
    return Color3.fromRGB(100, 255, 100)
end

local function GetRoleEmoji(role)
    if role == "Murderer" then return "🔪 Murderer" end
    if role == "Sheriff"  then return "🔫 Sheriff" end
    if role == "Dead"     then return "💀 Dead" end
    return "😇 Innocent"
end

local function ShouldShowRole(role)
    if role == "Innocent" then return showInnocent end
    if role == "Sheriff"  then return showSheriff end
    if role == "Murderer" then return showMurderer end
    if role == "Dead"     then return showDead end
    return false
end

local function GetRoleDebug(player)
    local lines = {
        "=== ROLE DEBUG: " .. player.Name ..
        " | Alive: " .. tostring(IsAlive(player)) ..
        " | Detected: " .. GetRole(player) .. " ==="
    }
    local char = player.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then table.insert(lines, "[Equipped] " .. obj.Name) end
        end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, obj in ipairs(backpack:GetChildren()) do
            if obj:IsA("Tool") then table.insert(lines, "[Backpack] " .. obj.Name) end
        end
    end
    print(table.concat(lines, "\n"))
end
_G.GetRoleDebug = GetRoleDebug

-- ============ CLUE DETECTION ============
local function IsActiveClue(part)
    if not part or not part.Parent then return false end
    if not part:IsA("BasePart") then return false end
    return part:FindFirstChildOfClass("Highlight") ~= nil
        and part:FindFirstChild("UsePrompt") ~= nil
end

local function GetCluePrompt(part)
    if not part then return nil end
    local prompt = part:FindFirstChild("UsePrompt")
    if prompt and prompt:IsA("ProximityPrompt") then return prompt end
    return nil
end

local function GetAllActiveClues()
    local clues = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if IsActiveClue(obj) then
            local prompt = GetCluePrompt(obj)
            if prompt then
                table.insert(clues, {part = obj, prompt = prompt})
            end
        end
    end
    return clues
end

local function GetActiveCluesInRange(range)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end
    local clues = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if IsActiveClue(obj) then
            local ok, dist = pcall(function()
                return (obj.Position - root.Position).Magnitude
            end)
            if ok and dist <= range then
                local prompt = GetCluePrompt(obj)
                if prompt then
                    table.insert(clues, {part = obj, prompt = prompt, dist = dist})
                end
            end
        end
    end
    return clues
end

-- ============ CLUE ESP ============
local function CreateClueESP(clue)
    if clueESPObjects[clue] then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ClueESP"
    billboard.Adornee = clue
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = clue

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.6, 0)
    label.BackgroundTransparency = 1
    label.Text = "📁 CLUE"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Parent = frame

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0m"
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextSize = 11
    distLabel.Font = Enum.Font.Gotham
    distLabel.Parent = frame

    clueESPObjects[clue] = {billboard = billboard, distanceLabel = distLabel}
end

local function RemoveClueESP(clue)
    if clueESPObjects[clue] then
        pcall(function() clueESPObjects[clue].billboard:Destroy() end)
        clueESPObjects[clue] = nil
    end
end

local function UpdateClueESP()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    for clue, espData in pairs(clueESPObjects) do
        if not clue.Parent or not IsActiveClue(clue) then
            RemoveClueESP(clue)
        elseif root then
            local ok, dist = pcall(function()
                return (clue.Position - root.Position).Magnitude
            end)
            if ok then espData.distanceLabel.Text = string.format("%.0fm", dist) end
        end
    end
end

-- ============ SEPARATION ESP ============
local function CreateSeparationESP(player)
    if separationESPObjects[player] then return end

    local espData = {}
    separationESPObjects[player] = espData

    local function build()
        if not player or not player.Parent then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if espData.billboard then
            pcall(function() espData.billboard:Destroy() end)
            espData.billboard = nil
        end

        local role = GetRole(player)
        local color = GetRoleColor(role)
        local roleText = GetRoleEmoji(role)
        local visible = ShouldShowRole(role)

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "SeparationESP"
        billboard.Adornee = root
        billboard.Size = UDim2.new(0, 140, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = visible
        billboard.Parent = root

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = color
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, 0)
        bar.BackgroundColor3 = color
        bar.BorderSizePixel = 0
        bar.Parent = frame

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -8, 0.5, 0)
        nameLabel.Position = UDim2.new(0, 6, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = player.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 12
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = frame

        local roleLabel = Instance.new("TextLabel")
        roleLabel.Size = UDim2.new(1, -8, 0.5, 0)
        roleLabel.Position = UDim2.new(0, 6, 0.5, 0)
        roleLabel.BackgroundTransparency = 1
        roleLabel.Text = roleText
        roleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        roleLabel.TextSize = 11
        roleLabel.Font = Enum.Font.Gotham
        roleLabel.TextXAlignment = Enum.TextXAlignment.Left
        roleLabel.Parent = frame

        espData.billboard = billboard
        espData.roleLabel = roleLabel
        espData.frame = frame
    end

    build()
    player.CharacterAdded:Connect(function()
        task.wait(1)
        build()
    end)
end

local function RemoveSeparationESP(player)
    if separationESPObjects[player] then
        pcall(function()
            if separationESPObjects[player].billboard then
                separationESPObjects[player].billboard:Destroy()
            end
        end)
        separationESPObjects[player] = nil
    end
end

-- ============ GUN ESP ============
local function DestroyGunMarker(markerData)
    if not markerData then return end
    pcall(function() markerData.marker:Destroy() end)
    for i, data in ipairs(gunESPMarkers) do
        if data == markerData then
            table.remove(gunESPMarkers, i)
            break
        end
    end
end

local function CreateGunMarker(position, sheriffName)
    local marker = Instance.new("Part")
    marker.Name = "GunDropMarker"
    marker.Anchored = true
    marker.CanCollide = false
    marker.Transparency = 1
    marker.Size = Vector3.new(1, 1, 1)
    marker.Position = position
    marker.Parent = workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GunESP"
    billboard.Adornee = marker
    billboard.Size = UDim2.new(0, 150, 0, 55)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = marker

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔫 GUN DROPPED HERE"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 12
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0.45, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.55, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Sheriff: " .. sheriffName
    infoLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
    infoLabel.TextSize = 10
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Parent = frame

    local markerData = {marker = marker, billboard = billboard}
    table.insert(gunESPMarkers, markerData)

    task.spawn(function()
        task.wait(0.5)
        local foundGun = nil
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Tool") and isSheriffTool(obj.Name) then
                local handle = obj:FindFirstChild("Handle")
                if handle then
                    local dist = (handle.Position - position).Magnitude
                    if dist < 30 then foundGun = obj break end
                end
            end
        end
        if foundGun then
            local conn
            conn = foundGun.AncestryChanged:Connect(function(_, newParent)
                if newParent ~= workspace then
                    conn:Disconnect()
                    task.wait(0.3)
                    if foundGun.Parent ~= workspace then
                        DestroyGunMarker(markerData)
                    end
                end
            end)
            foundGun.Destroying:Connect(function()
                DestroyGunMarker(markerData)
            end)
        else
            task.wait(30)
            DestroyGunMarker(markerData)
        end
    end)
end

local function ClearAllGunMarkers()
    for _, data in ipairs(gunESPMarkers) do
        pcall(function() data.marker:Destroy() end)
    end
    gunESPMarkers = {}
end

local function WatchSheriffDeath(player)
    if sheriffDeathConnections[player] then return end

    local function onCharAdded(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if not gunESPEnabled then return end
            local wasSheriff = false
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Tool") and isSheriffTool(obj.Name) then
                    wasSheriff = true break
                end
            end
            if not wasSheriff then
                local bp = player:FindFirstChild("Backpack")
                if bp then
                    for _, obj in ipairs(bp:GetChildren()) do
                        if obj:IsA("Tool") and isSheriffTool(obj.Name) then
                            wasSheriff = true break
                        end
                    end
                end
            end
            if wasSheriff then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then CreateGunMarker(root.Position, player.Name) end
            end
        end)
    end

    if player.Character then task.spawn(function() onCharAdded(player.Character) end) end
    sheriffDeathConnections[player] = player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        onCharAdded(char)
    end)
end

local function StopWatchingSheriffDeath(player)
    if sheriffDeathConnections[player] then
        sheriffDeathConnections[player]:Disconnect()
        sheriffDeathConnections[player] = nil
    end
end

-- ============ FLY SYSTEM ============
local function HandleFly()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")

    for _, v in pairs(root:GetChildren()) do
        if v.Name == "FlyVelocity" or v.Name == "FlyGyro" then v:Destroy() end
        if v:IsA("LinearVelocity") or v:IsA("AlignOrientation") then v:Destroy() end
        if v:IsA("Attachment") and v.Name == "FlyAttachment" then v:Destroy() end
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = "FlyAttachment"
    attachment.Parent = root

    local lv = Instance.new("LinearVelocity")
    lv.Name = "FlyVelocity"
    lv.Attachment0 = attachment
    lv.MaxForce = math.huge
    lv.VectorVelocity = Vector3.new(0, 0, 0)
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = root

    local ao = Instance.new("AlignOrientation")
    ao.Name = "FlyGyro"
    ao.Attachment0 = attachment
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.MaxTorque = math.huge
    ao.Responsiveness = 200
    ao.Parent = root

    task.spawn(function()
        while flyEnabled and root and root.Parent do
            local cam = workspace.CurrentCamera
            local dir = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0, 1, 0) end
            lv.VectorVelocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
            ao.CFrame = cam.CFrame
            RunService.Heartbeat:Wait()
        end
        pcall(function() lv:Destroy() end)
        pcall(function() ao:Destroy() end)
        pcall(function() attachment:Destroy() end)
    end)
end

-- ============ REJOIN / SERVERHOP ============
local function Rejoin()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end

local function ServerHop()
    pcall(function()
        local placeId = game.PlaceId
        local ok, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
            ))
        end)
        if ok and servers and servers.data then
            for _, server in ipairs(servers.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
                    return
                end
            end
        end
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

-- ============ KICK DETECTOR ============
local kickActionFired = false
task.spawn(function()
    local CoreGui = game:GetService("CoreGui")
    while true do
        task.wait(0.5)
        pcall(function()
            if kickActionFired then return end
            for _, child in ipairs(CoreGui:GetChildren()) do
                if child.Name == "ErrorPrompt" or child.Name == "DisconnectedScreen" then
                    kickActionFired = true
                    task.wait(1.5)
                    if autoServerHopOnKick then ServerHop()
                    elseif autoRejoinEnabled then Rejoin() end
                    return
                end
            end
        end)
    end
end)

-- ============ LOAD CONFIG ============
local SyncUI
local function LoadConfig(name)
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or not data then return false end

    clueESPEnabled        = data.clueESPEnabled        or false
    separationESPEnabled  = data.separationESPEnabled  or false
    showInnocent          = (data.showInnocent ~= nil) and data.showInnocent or true
    showSheriff           = (data.showSheriff ~= nil) and data.showSheriff or true
    showMurderer          = (data.showMurderer ~= nil) and data.showMurderer or true
    showDead              = (data.showDead ~= nil) and data.showDead or false
    gunESPEnabled         = data.gunESPEnabled         or false
    autoWalkCollectEnabled = data.autoWalkCollectEnabled or false
    instantCollectEnabled = data.instantCollectEnabled or false
    instantCollectRange   = data.instantCollectRange   or 200
    autoWalkRange         = data.autoWalkRange         or 8
    flyEnabled            = data.flyEnabled            or false
    flySpeed              = data.flySpeed              or 50
    walkSpeedEnabled      = data.walkSpeedEnabled      or false
    customWalkSpeed       = data.customWalkSpeed       or 16
    killAuraEnabled       = data.killAuraEnabled       or false
    killAuraRange         = data.killAuraRange         or 20
    autoRejoinEnabled     = data.autoRejoinEnabled     or false
    autoServerHopOnKick   = data.autoServerHopOnKick   or false

    if flyEnabled then task.spawn(HandleFly) end
    if SyncUI then SyncUI() end
    return true
end

-- ============ RAYFIELD WINDOW ============
local Window = Rayfield:CreateWindow({
    Name = "🎭 Item Asylum Hub",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by @jo2527 presleyyyyyyy",
    ConfigurationSaving = { Enabled = false }
})

-- ============ TAB 1: MURDER PARTY ============
local MurderTab = Window:CreateTab("Murder Party", 4483362458)

MurderTab:CreateSection("Separation ESP")
MurderTab:CreateLabel("Toggle which roles are visible.")

local separationESPToggle = MurderTab:CreateToggle({
    Name = "👥 Enable Separation ESP",
    CurrentValue = false,
    Callback = function(v)
        separationESPEnabled = v
        if v then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then CreateSeparationESP(player) end
            end
        else
            for player, _ in pairs(separationESPObjects) do
                RemoveSeparationESP(player)
            end
        end
        Rayfield:Notify({Title = "Separation ESP", Content = v and "Enabled" or "Disabled", Duration = 2})
    end
})

local showInnocentToggle = MurderTab:CreateToggle({
    Name = "😇 Show Innocents", CurrentValue = true,
    Callback = function(v) showInnocent = v end
})
local showSheriffToggle = MurderTab:CreateToggle({
    Name = "🔫 Show Sheriff", CurrentValue = true,
    Callback = function(v) showSheriff = v end
})
local showMurdererToggle = MurderTab:CreateToggle({
    Name = "🔪 Show Murderer", CurrentValue = true,
    Callback = function(v) showMurderer = v end
})
local showDeadToggle = MurderTab:CreateToggle({
    Name = "💀 Show Dead", CurrentValue = false,
    Callback = function(v) showDead = v end
})

MurderTab:CreateSection("Gun ESP")
MurderTab:CreateLabel("🔫 Pins location when Sheriff dies. Auto-removes on pickup.")

local gunESPToggle = MurderTab:CreateToggle({
    Name = "🔫 Gun Drop ESP",
    CurrentValue = false,
    Callback = function(v)
        gunESPEnabled = v
        if v then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then WatchSheriffDeath(player) end
            end
        else
            ClearAllGunMarkers()
            for player, _ in pairs(sheriffDeathConnections) do
                StopWatchingSheriffDeath(player)
            end
        end
        Rayfield:Notify({Title = "Gun ESP", Content = v and "ON" or "Disabled", Duration = 2})
    end
})

MurderTab:CreateButton({
    Name = "🗑️ Clear Gun Markers",
    Callback = function()
        ClearAllGunMarkers()
        Rayfield:Notify({Title = "Cleared", Content = "All gun markers removed.", Duration = 2})
    end
})

MurderTab:CreateSection("Clue ESP")

local clueESPToggle = MurderTab:CreateToggle({
    Name = "📁 Clue ESP",
    CurrentValue = false,
    Callback = function(v)
        clueESPEnabled = v
        if not v then
            for clue, _ in pairs(clueESPObjects) do RemoveClueESP(clue) end
        end
        Rayfield:Notify({Title = "Clue ESP", Content = v and "Enabled" or "Disabled", Duration = 2})
    end
})

MurderTab:CreateButton({
    Name = "🔍 Debug All Players (Console)",
    Callback = function()
        for _, player in ipairs(Players:GetPlayers()) do GetRoleDebug(player) end
        Rayfield:Notify({Title = "Dumped", Content = "Check console.", Duration = 3})
    end
})

MurderTab:CreateSection("Collect Clues")
MurderTab:CreateLabel("Only one mode active at a time.")

MurderTab:CreateLabel("🚶 Auto Walk: walks to each clue and collects it.")
local autoWalkCollectToggle = MurderTab:CreateToggle({
    Name = "🚶 Auto Walk & Collect",
    CurrentValue = false,
    Callback = function(v)
        if v and instantCollectEnabled then
            instantCollectEnabled = false
            instantCollectToggle:Set(false)
        end
        autoWalkCollectEnabled = v
        Rayfield:Notify({Title = "Auto Walk Collect", Content = v and "ON" or "OFF", Duration = 2})
    end
})

local autoWalkRangeSlider = MurderTab:CreateSlider({
    Name = "📏 Fire Range (how close to fire prompt)",
    Range = {3, 20}, Increment = 1, Suffix = " studs", CurrentValue = 8,
    Callback = function(v) autoWalkRange = v end
})

MurderTab:CreateLabel("⚡ Instant Collect: fires prompt on clues near you as you walk.")
local instantCollectToggle = MurderTab:CreateToggle({
    Name = "⚡ Instant Collect (Near)",
    CurrentValue = false,
    Callback = function(v)
        if v and autoWalkCollectEnabled then
            autoWalkCollectEnabled = false
            autoWalkCollectToggle:Set(false)
        end
        instantCollectEnabled = v
        Rayfield:Notify({Title = "Instant Collect", Content = v and "ON" or "OFF", Duration = 2})
    end
})

local instantCollectRangeSlider = MurderTab:CreateSlider({
    Name = "📏 Instant Collect Range",
    Range = {3, 200}, Increment = 1, Suffix = " studs", CurrentValue = 200,
    Callback = function(v) instantCollectRange = v end
})

-- ============ TAB 2: MOVEMENT ============
local MovementTab = Window:CreateTab("Movement", 4483362458)
MovementTab:CreateSection("Fly")

local flyToggle = MovementTab:CreateToggle({
    Name = "✈️ Fly (WASD + E/Q)", CurrentValue = false,
    Callback = function(v) flyEnabled = v if v then HandleFly() end end
})
local flySpeedSlider = MovementTab:CreateSlider({
    Name = "⚡ Fly Speed", Range = {10, 200}, Increment = 10, Suffix = " spd", CurrentValue = 50,
    Callback = function(v) flySpeed = v end
})

MovementTab:CreateSection("Walk Speed")
local walkSpeedToggle = MovementTab:CreateToggle({
    Name = "🏃 Custom Walk Speed", CurrentValue = false,
    Callback = function(v)
        walkSpeedEnabled = v
        if not v then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})
local walkSpeedSlider = MovementTab:CreateSlider({
    Name = "⚡ Speed", Range = {16, 200}, Increment = 4, Suffix = " spd", CurrentValue = 16,
    Callback = function(v) customWalkSpeed = v end
})

-- ============ TAB 3: COMBAT ============
local CombatTab = Window:CreateTab("Combat", 4483362458)
CombatTab:CreateSection("Kill Aura")

local killAuraToggle = CombatTab:CreateToggle({
    Name = "⚔️ Kill Aura", CurrentValue = false,
    Callback = function(v) killAuraEnabled = v end
})
local killAuraRangeSlider = CombatTab:CreateSlider({
    Name = "📏 Range", Range = {5, 50}, Increment = 5, Suffix = " studs", CurrentValue = 20,
    Callback = function(v) killAuraRange = v end
})
CombatTab:CreateLabel("⚠️ May be detectable")

-- ============ TAB 4: SERVER ============
local ServerTab = Window:CreateTab("Server", 4483362458)
ServerTab:CreateSection("Management")

ServerTab:CreateButton({ Name = "🔄 Rejoin", Callback = function() task.wait(1) Rejoin() end })
ServerTab:CreateButton({ Name = "🌐 Server Hop", Callback = function() task.wait(1) ServerHop() end })

ServerTab:CreateSection("Auto on Kick")

local autoRejoinLabel = ServerTab:CreateLabel("🔁 Auto Rejoin: OFF")
local autoRejoinToggle = ServerTab:CreateToggle({
    Name = "🔁 Auto Rejoin", CurrentValue = false,
    Callback = function(v)
        autoRejoinEnabled = v
        autoRejoinLabel:Set("🔁 Auto Rejoin: " .. (v and "ON" or "OFF"))
    end
})
local autoHopLabel = ServerTab:CreateLabel("🌐 Auto Hop: OFF")
local autoHopToggle = ServerTab:CreateToggle({
    Name = "🌐 Auto ServerHop", CurrentValue = false,
    Callback = function(v)
        autoServerHopOnKick = v
        autoHopLabel:Set("🌐 Auto Hop: " .. (v and "ON" or "OFF"))
    end
})

-- ============ TAB 5: CONFIG ============
local ConfigTab = Window:CreateTab("Config", 4483362458)

ConfigTab:CreateSection("Save")
local saveNameInput = ""
ConfigTab:CreateInput({
    Name = "📝 Name", PlaceholderText = "config name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) saveNameInput = t end
})
ConfigTab:CreateButton({ Name = "💾 Save", Callback = function()
    if saveNameInput == "" then return end
    SaveConfig(saveNameInput)
    Rayfield:Notify({Title = "Saved!", Content = "'" .. saveNameInput .. "'", Duration = 2})
    loadDropdown:Refresh(GetConfigList())
    autoRunDropdown:Refresh(GetConfigList())
    deleteDropdown:Refresh(GetConfigList())
end })

ConfigTab:CreateSection("Load")
local selectedLoadConfig = ""
local loadDropdown = ConfigTab:CreateDropdown({
    Name = "📂 Config", Options = GetConfigList(),
    Callback = function(v) selectedLoadConfig = v end
})
ConfigTab:CreateButton({ Name = "📥 Load", Callback = function()
    if selectedLoadConfig ~= "" then
        if LoadConfig(selectedLoadConfig) then
            Rayfield:Notify({Title = "Loaded!", Content = "'" .. selectedLoadConfig .. "'", Duration = 2})
        end
    end
end })

ConfigTab:CreateSection("AutoRun")
local currentAutoRun = GetAutoRunConfig() or "None"
local autoRunLabel = ConfigTab:CreateLabel("🔁 AutoRun: " .. currentAutoRun)
local selectedAutoRunConfig = ""
local autoRunDropdown = ConfigTab:CreateDropdown({
    Name = "🔁 Config", Options = GetConfigList(),
    Callback = function(v) selectedAutoRunConfig = v end
})
ConfigTab:CreateButton({ Name = "✅ Set", Callback = function()
    if selectedAutoRunConfig ~= "" then
        SetAutoRunConfig(selectedAutoRunConfig)
        autoRunLabel:Set("🔁 AutoRun: " .. selectedAutoRunConfig)
        Rayfield:Notify({Title = "AutoRun Set!", Duration = 2})
    end
end })
ConfigTab:CreateButton({ Name = "❌ Clear", Callback = function()
    ClearAutoRun()
    autoRunLabel:Set("🔁 AutoRun: None")
end })

ConfigTab:CreateSection("Delete")
local selectedDeleteConfig = ""
local deleteDropdown = ConfigTab:CreateDropdown({
    Name = "🗑️ Config", Options = GetConfigList(),
    Callback = function(v) selectedDeleteConfig = v end
})
ConfigTab:CreateButton({ Name = "🗑️ Delete", Callback = function()
    if selectedDeleteConfig ~= "" then
        DeleteConfig(selectedDeleteConfig)
        loadDropdown:Refresh(GetConfigList())
        autoRunDropdown:Refresh(GetConfigList())
        deleteDropdown:Refresh(GetConfigList())
        Rayfield:Notify({Title = "Deleted!", Duration = 2})
    end
end })

-- ============ SyncUI ============
SyncUI = function()
    separationESPToggle:Set(separationESPEnabled)
    showInnocentToggle:Set(showInnocent)
    showSheriffToggle:Set(showSheriff)
    showMurdererToggle:Set(showMurderer)
    showDeadToggle:Set(showDead)
    gunESPToggle:Set(gunESPEnabled)
    clueESPToggle:Set(clueESPEnabled)
    autoWalkCollectToggle:Set(autoWalkCollectEnabled)
    autoWalkRangeSlider:Set(autoWalkRange)
    instantCollectToggle:Set(instantCollectEnabled)
    instantCollectRangeSlider:Set(instantCollectRange)
    flyToggle:Set(flyEnabled)
    flySpeedSlider:Set(flySpeed)
    walkSpeedToggle:Set(walkSpeedEnabled)
    walkSpeedSlider:Set(customWalkSpeed)
    killAuraToggle:Set(killAuraEnabled)
    killAuraRangeSlider:Set(killAuraRange)
    autoRejoinToggle:Set(autoRejoinEnabled)
    autoHopToggle:Set(autoServerHopOnKick)
    autoRejoinLabel:Set("🔁 Auto Rejoin: " .. (autoRejoinEnabled and "ON" or "OFF"))
    autoHopLabel:Set("🌐 Auto Hop: " .. (autoServerHopOnKick and "ON" or "OFF"))
end

-- ============ LOOPS & EVENTS ============

-- Clue ESP scan
task.spawn(function()
    while true do
        if clueESPEnabled then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and IsActiveClue(obj) then CreateClueESP(obj) end
            end
            UpdateClueESP()
        end
        task.wait(0.5)
    end
end)

workspace.DescendantAdded:Connect(function(desc)
    task.wait(0.15)
    if clueESPEnabled and desc:IsA("BasePart") and IsActiveClue(desc) then
        CreateClueESP(desc)
    end
end)

-- Auto Walk & Collect loop
task.spawn(function()
    while true do
        if autoWalkCollectEnabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if root and hum then
                local clues = GetAllActiveClues()

                for _, clueData in ipairs(clues) do
                    if not autoWalkCollectEnabled then break end
                    if not clueData.part or not clueData.part.Parent then continue end
                    if not clueData.prompt or not clueData.prompt.Parent then continue end

                    local dist = (clueData.part.Position - root.Position).Magnitude

                    if dist <= autoWalkRange then
                        pcall(function() fireproximityprompt(clueData.prompt) end)
                        task.wait(0.3)
                    else
                        hum:MoveTo(clueData.part.Position)
                        local timeout = tick() + 5
                        while autoWalkCollectEnabled and tick() < timeout do
                            if not clueData.part.Parent or not IsActiveClue(clueData.part) then break end
                            local currentDist = (clueData.part.Position - root.Position).Magnitude
                            if currentDist <= autoWalkRange then
                                pcall(function() fireproximityprompt(clueData.prompt) end)
                                task.wait(0.3)
                                break
                            end
                            task.wait(0.1)
                        end
                    end
                end
            end

            task.wait(0.5)
        else
            task.wait(0.5)
        end
    end
end)

-- Instant Collect loop
task.spawn(function()
    while true do
        if instantCollectEnabled then
            local nearClues = GetActiveCluesInRange(instantCollectRange)
            for _, clueData in ipairs(nearClues) do
                if clueData.part and clueData.part.Parent and clueData.prompt then
                    pcall(function() fireproximityprompt(clueData.prompt) end)
                    task.wait(0.1)
                end
            end
        end
        task.wait(0.2)
    end
end)

-- Separation ESP role refresh
task.spawn(function()
    while true do
        task.wait(2)
        if separationESPEnabled then
            for player, espData in pairs(separationESPObjects) do
                if player and player.Parent then
                    local role = GetRole(player)
                    local color = GetRoleColor(role)
                    local roleText = GetRoleEmoji(role)
                    local visible = ShouldShowRole(role)
                    if espData.billboard then espData.billboard.Enabled = visible end
                    if espData.roleLabel and espData.roleLabel.Parent then
                        espData.roleLabel.Text = roleText
                    end
                    if espData.frame and espData.frame.Parent then
                        espData.frame.BackgroundColor3 = color
                    end
                end
            end
        end
    end
end)

-- Walk speed
RunService.Heartbeat:Connect(function()
    if walkSpeedEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = customWalkSpeed end
    end
end)

-- Kill aura
task.spawn(function()
    while true do
        if killAuraEnabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local tr = player.Character:FindFirstChild("HumanoidRootPart")
                        local th = player.Character:FindFirstChildOfClass("Humanoid")
                        if tr and th and th.Health > 0 and
                            (tr.Position - root.Position).Magnitude <= killAuraRange then
                            pcall(function()
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool then tool:Activate() end
                            end)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Player events
Players.PlayerAdded:Connect(function(player)
    task.wait(2)
    if separationESPEnabled and player ~= LocalPlayer then CreateSeparationESP(player) end
    if gunESPEnabled and player ~= LocalPlayer then WatchSheriffDeath(player) end
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveSeparationESP(player)
    StopWatchingSheriffDeath(player)
end)

-- Character respawn
LocalPlayer.CharacterAdded:Connect(function()
    if flyEnabled then task.wait(1) HandleFly() end
end)

-- AutoRun
task.spawn(function()
    task.wait(2)
    local name = GetAutoRunConfig()
    if name and name ~= "" then
        if LoadConfig(name) then
            Rayfield:Notify({Title = "AutoRun", Content = "'" .. name .. "' loaded.", Duration = 3})
        end
    end
end)

Rayfield:Notify({Title = "✅ Loaded!", Content = "Item Asylum Hub ready.", Duration = 3})
