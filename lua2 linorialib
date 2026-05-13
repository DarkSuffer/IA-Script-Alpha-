--[[
  Item Asylum — LinoriaLib UI
  Executor: loadstring, game:HttpGet, fireproximityprompt
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Item Asylum",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local MainTab     = Window:AddTab("Main")
local MurderTab   = Window:AddTab("Murder Party")
local MovementTab = Window:AddTab("Movement")
local ServerTab   = Window:AddTab("Server")
local SettingsTab = Window:AddTab("Settings")

-- ============ HEAD EXPANDER ============
local HeadExpander = { Enabled = false, Multiplier = 2 }
local originalPartSize    = {}
local originalHeadPhysics = {}
local headExpanderHeartbeatConn = nil
local headEspByHead = {}

-- ============ STATE ============
local clueESPEnabled        = false
local separationESPEnabled  = false
local showInnocent          = true
local showSheriff           = true
local showMurderer          = true
local showDead              = false
local gunESPEnabled         = false
local instantCollectEnabled = false
local instantCollectRange   = 3
local flyEnabled            = false
local flySpeed              = 10
local walkSpeedEnabled      = false
local customWalkSpeed       = 16
local killAuraEnabled       = false
local killAuraRange         = 5
local fullbrightEnabled     = false
local noFogEnabled          = false
local autoRejoinEnabled     = false
local autoServerHopOnKick   = false
local kickActionFired       = false
local chamsEnabled          = false
local chamsColor            = Color3.fromRGB(200, 100, 255)

local savedLighting   = {}
local savedAtmosphere = {}
local atmosphereRef   = nil

local Aimbot = {
    Enabled     = false,
    FOV         = 40,
    UseFOVLimit = false,
    ShowFOV     = false,
    FOVColor    = Color3.fromRGB(255, 90, 90),
    Smoothness  = 1,
    TargetPart  = "Head",
    TeamCheck   = false,
    HoldMode    = true,
    MaxDistance = 50,
}

local aimbotRenderConn = nil
local FOVCircle        = nil
local drawingLibOk     = pcall(function() return Drawing.new ~= nil end)
local chamsPlayerConns = {}

local clueESPObjects          = {}
local separationESPObjects    = {}
local gunESPMarkers           = {}
local sheriffDeathConnections = {}

local espFolder = Instance.new("Folder")
espFolder.Name   = "IAHub_SepESP"
espFolder.Parent = Workspace

local LINORIA_FOLDER = "ItemAsylum"
local scriptAlive    = true
local walkSpeedConn  = nil

-- ============ HEAD EXPANDER HELPERS ============
local function clampMultiplier(n)
    return math.clamp(math.floor(n + 0.5), 1, 15)
end

local function applyScaledPart(part, featureOn, multiplier)
    if not part or not part:IsA("BasePart") then return end
    if not originalPartSize[part] then originalPartSize[part] = part.Size end
    local m = featureOn and clampMultiplier(multiplier or HeadExpander.Multiplier) or 1
    part.Size = originalPartSize[part] * m
end

local function setExpandedHeadCollision(head, noCollide)
    if not head or not head:IsA("BasePart") then return end
    if not originalHeadPhysics[head] then
        originalHeadPhysics[head] = { CanCollide = head.CanCollide, Massless = head.Massless }
    end
    local o = originalHeadPhysics[head]
    if noCollide then
        head.CanCollide = false
        head.Massless   = true
    else
        pcall(function()
            head.CanCollide = o.CanCollide
            head.Massless   = o.Massless
        end)
    end
end

local function isUnderLocalCharacter(inst)
    local char = LocalPlayer.Character
    return char ~= nil and inst ~= nil and inst:IsDescendantOf(char)
end

local function removeHeadEsp(head)
    if not head then return end
    headEspByHead[head] = nil
    pcall(function()
        local hl = head:FindFirstChild("ItemAsylumHeadESP")
        if hl then hl:Destroy() end
    end)
end

local function clearAllHeadEsp()
    local batch = {}
    for head in pairs(headEspByHead) do batch[#batch + 1] = head end
    table.clear(headEspByHead)
    for _, head in ipairs(batch) do
        pcall(function()
            if head and head.Parent then
                local hl = head:FindFirstChild("ItemAsylumHeadESP")
                if hl then hl:Destroy() end
            end
        end)
    end
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst.Name == "Head" and inst:IsA("BasePart") then
            local hl = inst:FindFirstChild("ItemAsylumHeadESP")
            if hl then hl:Destroy() end
        end
    end
end

local function ensureHeadEsp(head)
    if not head or not head.Parent or not HeadExpander.Enabled then return end
    local hl = head:FindFirstChild("ItemAsylumHeadESP")
    if not hl then
        hl        = Instance.new("Highlight")
        hl.Name   = "ItemAsylumHeadESP"
        hl.Parent = head
    end
    hl.FillColor           = Color3.fromRGB(120, 210, 255)
    hl.FillTransparency    = 0.9
    hl.OutlineColor        = Color3.fromRGB(200, 235, 255)
    hl.OutlineTransparency = 0.5
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    headEspByHead[head]    = hl
end

local function sweepHeadEspStale()
    for head in pairs(headEspByHead) do
        if not head.Parent or not HeadExpander.Enabled or isUnderLocalCharacter(head) then
            removeHeadEsp(head)
        end
    end
end

local function stopHeadExpander()
    if headExpanderHeartbeatConn then
        headExpanderHeartbeatConn:Disconnect()
        headExpanderHeartbeatConn = nil
    end
end

local function refreshAllHeads()
    local processed = {}
    local function processHead(head)
        if not head or not head:IsA("BasePart") or processed[head] then return end
        if isUnderLocalCharacter(head) then return end
        processed[head] = true
        applyScaledPart(head, HeadExpander.Enabled, HeadExpander.Multiplier)
        local noCollide = HeadExpander.Enabled and clampMultiplier(HeadExpander.Multiplier) > 1
        setExpandedHeadCollision(head, noCollide)
        if HeadExpander.Enabled then ensureHeadEsp(head) else removeHeadEsp(head) end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if head and head:IsA("BasePart") then processHead(head) end
    end
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst.Name == "Head" and inst:IsA("BasePart") then processHead(inst) end
    end
    sweepHeadEspStale()
end

local function startHeadExpander()
    stopHeadExpander()
    if not HeadExpander.Enabled then return end
    refreshAllHeads()
    headExpanderHeartbeatConn = RunService.Heartbeat:Connect(function()
        if scriptAlive and HeadExpander.Enabled then refreshAllHeads() end
    end)
end

-- ============ ROLE DETECTION ============
local SHERIFF_GUNS = { ["mad sheriff"] = true, ["mad handgun"] = true }

local function isMurdererTool(toolName) return toolName:lower():sub(1, 3) == "mu_" end
local function isSheriffTool(toolName)  return SHERIFF_GUNS[toolName:lower()] == true end

local function ScanToolsForRole(player)
    local containers = {}
    if player.Character then table.insert(containers, player.Character) end
    local bp = player:FindFirstChild("Backpack")
    if bp then table.insert(containers, bp) end
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Tool") then
                if isMurdererTool(obj.Name) then return "Murderer" end
                if isSheriffTool(obj.Name)  then return "Sheriff"  end
            end
        end
    end
    return "Innocent"
end

local function IsAlive(player)
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function GetRole(player)
    if not IsAlive(player) then return "Dead" end
    return ScanToolsForRole(player)
end

local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 50,  50)  end
    if role == "Sheriff"  then return Color3.fromRGB(50,  150, 255) end
    if role == "Dead"     then return Color3.fromRGB(120, 120, 120) end
    return Color3.fromRGB(100, 255, 100)
end

local function GetRoleEmoji(role)
    if role == "Murderer" then return "Murderer" end
    if role == "Sheriff"  then return "Sheriff"  end
    if role == "Dead"     then return "Dead"     end
    return "Innocent"
end

local function ShouldShowRole(role)
    if role == "Innocent" then return showInnocent end
    if role == "Sheriff"  then return showSheriff  end
    if role == "Murderer" then return showMurderer end
    if role == "Dead"     then return showDead     end
    return false
end

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

local function GetActiveCluesInRange(range)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end
    local clues = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if IsActiveClue(obj) then
            local ok, dist = pcall(function()
                return (obj.Position - root.Position).Magnitude
            end)
            if ok and dist <= range then
                local prompt = GetCluePrompt(obj)
                if prompt then
                    table.insert(clues, { part = obj, prompt = prompt, dist = dist })
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
    billboard.Name        = "ClueESP"
    billboard.Adornee     = clue
    billboard.Size        = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent      = clue

    local frame = Instance.new("Frame", billboard)
    frame.Size                   = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3       = Color3.fromRGB(85, 255, 127)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel        = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", frame)
    label.Size               = UDim2.new(1, 0, 0.6, 0)
    label.BackgroundTransparency = 1
    label.Text               = "CLUE"
    label.TextColor3         = Color3.new(1, 1, 1)
    label.TextSize           = 14
    label.Font               = Enum.Font.GothamBold

    local distLabel = Instance.new("TextLabel", frame)
    distLabel.Size               = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position           = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text               = "0m"
    distLabel.TextColor3         = Color3.fromRGB(200, 200, 200)
    distLabel.TextSize           = 11
    distLabel.Font               = Enum.Font.Gotham

    clueESPObjects[clue] = { billboard = billboard, distanceLabel = distLabel }
end

local function RemoveClueESP(clue)
    if clueESPObjects[clue] then
        pcall(function() clueESPObjects[clue].billboard:Destroy() end)
        clueESPObjects[clue] = nil
    end
end

local function UpdateClueESP()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
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
local function HardClearAllSepESP()
    for _, child in ipairs(espFolder:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
    for _, data in pairs(separationESPObjects) do
        if data.charConn then
            pcall(function() data.charConn:Disconnect() end)
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name == "SeparationESP" then
            pcall(function() obj:Destroy() end)
        end
    end
    table.clear(separationESPObjects)
end

local function BuildSepBillboard(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local data = separationESPObjects[player]
    if not data then return end

    if data.billboard then
        pcall(function() data.billboard:Destroy() end)
        data.billboard = nil
    end

    local role    = GetRole(player)
    local color   = GetRoleColor(role)
    local visible = ShouldShowRole(role)

    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "SeparationESP"
    billboard.Adornee     = root
    billboard.Size        = UDim2.new(0, 140, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled     = visible
    billboard.Parent      = espFolder

    local frame = Instance.new("Frame", billboard)
    frame.Size                   = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3       = color
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel        = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local bar = Instance.new("Frame", frame)
    bar.Size             = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel  = 0

    local nameLabel = Instance.new("TextLabel", frame)
    nameLabel.Size               = UDim2.new(1, -8, 0.5, 0)
    nameLabel.Position           = UDim2.new(0, 6, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text               = player.Name
    nameLabel.TextColor3         = Color3.new(1, 1, 1)
    nameLabel.TextSize           = 12
    nameLabel.Font               = Enum.Font.GothamBold
    nameLabel.TextXAlignment     = Enum.TextXAlignment.Left
    nameLabel.TextTruncate       = Enum.TextTruncate.AtEnd

    local roleLabel = Instance.new("TextLabel", frame)
    roleLabel.Size               = UDim2.new(1, -8, 0.5, 0)
    roleLabel.Position           = UDim2.new(0, 6, 0.5, 0)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text               = GetRoleEmoji(role)
    roleLabel.TextColor3         = Color3.new(1, 1, 1)
    roleLabel.TextSize           = 11
    roleLabel.Font               = Enum.Font.Gotham
    roleLabel.TextXAlignment     = Enum.TextXAlignment.Left

    data.billboard = billboard
    data.roleLabel = roleLabel
    data.frame     = frame
end

local function CreateSeparationESP(player)
    if separationESPObjects[player] then return end
    local data = { billboard = nil, charConn = nil, roleLabel = nil, frame = nil }
    separationESPObjects[player] = data
    BuildSepBillboard(player)
    data.charConn = player.CharacterAdded:Connect(function()
        task.wait(0.8)
        if separationESPEnabled and separationESPObjects[player] then
            BuildSepBillboard(player)
        end
    end)
end

local function RemoveSeparationESP(player)
    local data = separationESPObjects[player]
    if not data then return end
    if data.billboard then pcall(function() data.billboard:Destroy() end) end
    if data.charConn  then pcall(function() data.charConn:Disconnect() end) end
    separationESPObjects[player] = nil
end

-- ============ GUN ESP ============
local function DestroyGunMarker(markerData)
    if not markerData then return end
    pcall(function() markerData.marker:Destroy() end)
    for i, data in ipairs(gunESPMarkers) do
        if data == markerData then table.remove(gunESPMarkers, i) break end
    end
end

local function CreateGunMarker(position, sheriffName)
    local marker = Instance.new("Part")
    marker.Name        = "GunDropMarker"
    marker.Anchored    = true
    marker.CanCollide  = false
    marker.Transparency = 1
    marker.Size        = Vector3.new(1, 1, 1)
    marker.Position    = position
    marker.Parent      = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "GunESP"
    billboard.Adornee     = marker
    billboard.Size        = UDim2.new(0, 150, 0, 55)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent      = marker

    local frame = Instance.new("Frame", billboard)
    frame.Size                   = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3       = Color3.fromRGB(255, 215, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel        = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size               = UDim2.new(1, 0, 0.55, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text               = "GUN DROPPED"
    titleLabel.TextColor3         = Color3.new(1, 1, 1)
    titleLabel.TextSize           = 12
    titleLabel.Font               = Enum.Font.GothamBold

    local infoLabel = Instance.new("TextLabel", frame)
    infoLabel.Size               = UDim2.new(1, 0, 0.45, 0)
    infoLabel.Position           = UDim2.new(0, 0, 0.55, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text               = "Sheriff: " .. sheriffName
    infoLabel.TextColor3         = Color3.fromRGB(255, 230, 100)
    infoLabel.TextSize           = 10
    infoLabel.Font               = Enum.Font.Gotham

    local markerData = { marker = marker, billboard = billboard }
    table.insert(gunESPMarkers, markerData)

    task.spawn(function()
        task.wait(0.5)
        local foundGun = nil
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Tool") and isSheriffTool(obj.Name) then
                local handle = obj:FindFirstChild("Handle")
                if handle and (handle.Position - position).Magnitude < 30 then
                    foundGun = obj break
                end
            end
        end
        if foundGun then
            local conn
            conn = foundGun.AncestryChanged:Connect(function(_, newParent)
                if newParent ~= Workspace then
                    conn:Disconnect()
                    task.wait(0.3)
                    if foundGun.Parent ~= Workspace then DestroyGunMarker(markerData) end
                end
            end)
            foundGun.Destroying:Connect(function() DestroyGunMarker(markerData) end)
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
            if ScanToolsForRole(player) == "Sheriff" then
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

-- ============ FLY ============
local function HandleFly()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    for _, v in pairs(root:GetChildren()) do
        if v.Name == "FlyVelocity" or v.Name == "FlyGyro" or v.Name == "FlyAttachment"
            or v:IsA("LinearVelocity") or v:IsA("AlignOrientation") then
            v:Destroy()
        end
    end
    local att = Instance.new("Attachment", root) att.Name = "FlyAttachment"
    local lv  = Instance.new("LinearVelocity", root)
    lv.Name           = "FlyVelocity"
    lv.Attachment0    = att
    lv.MaxForce       = math.huge
    lv.VectorVelocity = Vector3.zero
    lv.RelativeTo     = Enum.ActuatorRelativeTo.World
    local ao = Instance.new("AlignOrientation", root)
    ao.Name           = "FlyGyro"
    ao.Attachment0    = att
    ao.Mode           = Enum.OrientationAlignmentMode.OneAttachment
    ao.MaxTorque      = math.huge
    ao.Responsiveness = 200
    task.spawn(function()
        while flyEnabled and scriptAlive and root and root.Parent do
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.new(0, 1, 0)  end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.new(0, 1, 0)  end
            lv.VectorVelocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
            ao.CFrame = cam.CFrame
            RunService.Heartbeat:Wait()
        end
        pcall(function() lv:Destroy()  end)
        pcall(function() ao:Destroy()  end)
        pcall(function() att:Destroy() end)
    end)
end

-- ============ LIGHTING ============
local function EnableFullbright()
    if not next(savedLighting) then
        savedLighting = {
            Brightness     = Lighting.Brightness,
            ClockTime      = Lighting.ClockTime,
            FogEnd         = Lighting.FogEnd,
            FogStart       = Lighting.FogStart,
            GlobalShadows  = Lighting.GlobalShadows,
            Ambient        = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
    end
    Lighting.Brightness     = 1
    Lighting.ClockTime      = 12
    Lighting.FogEnd         = 100000
    Lighting.FogStart       = 100000
    Lighting.GlobalShadows  = false
    Lighting.Ambient        = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
end

local function DisableFullbright()
    if next(savedLighting) then
        for prop, value in pairs(savedLighting) do Lighting[prop] = value end
        savedLighting = {}
    end
end

local function EnableNoFog()
    atmosphereRef = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphereRef then
        savedAtmosphere = {
            Density = atmosphereRef.Density,
            Offset  = atmosphereRef.Offset,
            Haze    = atmosphereRef.Haze,
            Glare   = atmosphereRef.Glare,
        }
        atmosphereRef.Density = 0
        atmosphereRef.Offset  = 0
        atmosphereRef.Haze    = 0
        atmosphereRef.Glare   = 0
    end
    Lighting.FogEnd   = 100000
    Lighting.FogStart = 100000
end

local function DisableNoFog()
    if not fullbrightEnabled and next(savedLighting) then
        Lighting.FogEnd   = savedLighting.FogEnd
        Lighting.FogStart = savedLighting.FogStart
    end
    if atmosphereRef and atmosphereRef.Parent and next(savedAtmosphere) then
        for prop, value in pairs(savedAtmosphere) do atmosphereRef[prop] = value end
        savedAtmosphere = {}
    end
    atmosphereRef = nil
end

-- ============ REJOIN / SERVERHOP ============
local function Rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

local function ServerHop()
    pcall(function()
        local placeId = game.PlaceId
        local servers = HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100")
        )
        for _, server in ipairs(servers.data or {}) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(placeId, server.id, LocalPlayer)
                return
            end
        end
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

-- ============ CHAMS ============
local function removeChamsForCharacter(character)
    if not character then return end
    local h = character:FindFirstChild("ItemAsylumChams")
    if h then pcall(function() h:Destroy() end) end
end

local function applyChamsHighlightStyle(hl)
    if not hl then return end
    local c = chamsColor
    hl.FillColor           = c
    hl.OutlineColor        = Color3.new(math.min(c.R*1.2,1), math.min(c.G*1.2,1), math.min(c.B*1.2,1))
    hl.FillTransparency    = 0.5
    hl.OutlineTransparency = 0.25
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
end

local function ensureChamsOnCharacter(character)
    if not character or not character:IsA("Model") then return end
    if Players:GetPlayerFromCharacter(character) == LocalPlayer then
        removeChamsForCharacter(character) return
    end
    if not chamsEnabled then removeChamsForCharacter(character) return end
    local hl = character:FindFirstChild("ItemAsylumChams")
    if not hl then
        hl        = Instance.new("Highlight")
        hl.Name   = "ItemAsylumChams"
        hl.Parent = character
    end
    applyChamsHighlightStyle(hl)
end

local function refreshAllChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if not char then continue end
        if plr == LocalPlayer then removeChamsForCharacter(char)
        elseif chamsEnabled   then ensureChamsOnCharacter(char)
        else                       removeChamsForCharacter(char) end
    end
end

local function refreshChamsColorsOnly()
    if not chamsEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hl = plr.Character:FindFirstChild("ItemAsylumChams")
            if hl then applyChamsHighlightStyle(hl) end
        end
    end
end

local function setupChamsForPlayer(player)
    if player == LocalPlayer or chamsPlayerConns[player] then return end
    chamsPlayerConns[player] = player.CharacterAdded:Connect(function(char)
        task.defer(function()
            task.wait(0.35)
            if scriptAlive and chamsEnabled then ensureChamsOnCharacter(char) end
        end)
    end)
    if player.Character then ensureChamsOnCharacter(player.Character) end
end

local function teardownChamsHooks()
    for plr, conn in pairs(chamsPlayerConns) do
        if conn then pcall(function() conn:Disconnect() end) end
        chamsPlayerConns[plr] = nil
    end
end

-- ============ AIMBOT ============
local function getCamera() return Workspace.CurrentCamera end

local function getAimbotBodyPart(character, partName)
    if not character then return nil end
    local p = character:FindFirstChild(partName)
    if p and p:IsA("BasePart") then return p end
    local alt = {
        Head             = { "Head" },
        HumanoidRootPart = { "HumanoidRootPart", "UpperTorso", "Torso" },
        UpperTorso       = { "UpperTorso", "Torso", "LowerTorso" },
        LowerTorso       = { "LowerTorso", "UpperTorso", "Torso" },
    }
    local list = alt[partName]
    if list then
        for _, n in ipairs(list) do
            local c = character:FindFirstChild(n)
            if c and c:IsA("BasePart") then return c end
        end
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function isAimbotTeammate(player)
    if not Aimbot.TeamCheck then return false end
    if not LocalPlayer.Team or not player.Team then return false end
    return LocalPlayer.Team == player.Team
end

local function findBestAimbotTarget()
    local cam    = getCamera()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not cam or not myRoot then return nil end
    local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
    local bestPart, bestScreenDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if isAimbotTeammate(plr) then continue end
        local part = getAimbotBodyPart(char, Aimbot.TargetPart)
        if not part then continue end
        if (part.Position - myRoot.Position).Magnitude > Aimbot.MaxDistance then continue end
        local vp, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen or vp.Z <= 0 then continue end
        local sd = (Vector2.new(vp.X, vp.Y) - center).Magnitude
        if Aimbot.UseFOVLimit and sd > Aimbot.FOV then continue end
        if sd < bestScreenDist then bestScreenDist = sd; bestPart = part end
    end
    return bestPart
end

local function aimbotApplyCamera(targetPart)
    local cam = getCamera()
    if not cam or not targetPart then return end
    local targetCF = CFrame.lookAt(cam.CFrame.Position, targetPart.Position)
    if Aimbot.Smoothness <= 1 then
        cam.CFrame = targetCF
    else
        cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(1 / Aimbot.Smoothness, 0.04, 0.92))
    end
end

local function aimbotEnsureFOVCircle()
    if not Aimbot.ShowFOV or not drawingLibOk or FOVCircle then return end
    local ok, circle = pcall(function() return Drawing.new("Circle") end)
    if not ok or not circle then return end
    FOVCircle               = circle
    FOVCircle.Thickness     = 2
    FOVCircle.NumSides      = 64
    FOVCircle.Filled        = false
    FOVCircle.ZIndex        = 2
    FOVCircle.Transparency  = 0.65
end

local function aimbotUpdateFOVDrawing()
    if not FOVCircle then return end
    local cam = getCamera()
    if not cam then FOVCircle.Visible = false return end
    FOVCircle.Position = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
    FOVCircle.Radius   = Aimbot.FOV
    FOVCircle.Color    = Aimbot.FOVColor
    FOVCircle.Visible  = scriptAlive and Aimbot.ShowFOV
end

local function aimbotDestroyFOVCircle()
    if FOVCircle then pcall(function() FOVCircle:Remove() end); FOVCircle = nil end
end

local function aimbotStopRender()
    if aimbotRenderConn then aimbotRenderConn:Disconnect(); aimbotRenderConn = nil end
    aimbotDestroyFOVCircle()
end

local function aimbotStartRender()
    aimbotStopRender()
    aimbotRenderConn = RunService.RenderStepped:Connect(function()
        if not scriptAlive then return end

        if Aimbot.ShowFOV and drawingLibOk then
            aimbotEnsureFOVCircle()
            aimbotUpdateFOVDrawing()
        elseif FOVCircle then
            FOVCircle.Visible = false
        end

        if not Aimbot.Enabled then return end

        local keybindActive = false
        pcall(function()
            keybindActive = Options.AimbotKeybind:GetState()
        end)

        if Aimbot.HoldMode and not keybindActive then return end

        local target = findBestAimbotTarget()
        if target then aimbotApplyCamera(target) end
    end)
end

local function safeToggleSet(flag, value)
    if Toggles[flag] then
        pcall(function()
            if Toggles[flag].SetValue then Toggles[flag]:SetValue(value)
            elseif Toggles[flag].Set  then Toggles[flag]:Set(value) end
        end)
    end
end

-- ============================================================
-- GUI
-- ============================================================

-- ============ MAIN TAB ============
local HeadBox   = MainTab:AddLeftGroupbox("Head Expander (Others Only)")
local CombatBox = MainTab:AddRightGroupbox("Kill Aura")
local AimbotBox = MainTab:AddRightGroupbox("Aimbot (FOV)")

HeadBox:AddToggle("HeadExpanderEnabled", {
    Text    = "Scale others' heads + transparent ESP",
    Default = false,
    Callback = function(v)
        HeadExpander.Enabled = v
        if v then startHeadExpander() else stopHeadExpander(); refreshAllHeads() end
    end,
})
HeadBox:AddSlider("HeadExpanderMultiplier", {
    Text     = "Head scale (max 15x)",
    Default  = 2,
    Min      = 1,
    Max      = 15,
    Rounding = 0,
    Callback = function(v)
        HeadExpander.Multiplier = clampMultiplier(v)
        if HeadExpander.Enabled then refreshAllHeads() end
    end,
})

CombatBox:AddToggle("KillAuraEnabled", {
    Text    = "Kill Aura",
    Default = false,
    Callback = function(v) killAuraEnabled = v end,
})
CombatBox:AddSlider("KillAuraRange", {
    Text     = "Range (studs)",
    Default  = 5,
    Min      = 5,
    Max      = 50,
    Rounding = 0,
    Callback = function(v) killAuraRange = v end,
})

AimbotBox:AddToggle("AimbotEnabled", {
    Text    = "Enable Aimbot",
    Default = false,
    Callback = function(v) Aimbot.Enabled = v end,
})
AimbotBox:AddLabel("Aimbot hold key (click to change)"):AddKeyPicker("AimbotKeybind", {
    Default        = "MB2",
    SyncToggleState = false,
    Mode           = "Hold",
    Text           = "Aimbot Key",
    NoUI           = false,
    Callback       = function(_) end,
})
AimbotBox:AddToggle("AimbotHoldMode", {
    Text    = "Require hold to aim (off = always on)",
    Default = true,
    Callback = function(v) Aimbot.HoldMode = v end,
})
AimbotBox:AddToggle("AimbotFOVLimit", {
    Text    = "Limit targets to FOV circle",
    Default = false,
    Callback = function(v) Aimbot.UseFOVLimit = v end,
})
AimbotBox:AddToggle("AimbotShowFOV", {
    Text    = "Show FOV circle",
    Default = false,
    Callback = function(v)
        Aimbot.ShowFOV = v
        if not v then aimbotDestroyFOVCircle() end
    end,
})
AimbotBox:AddLabel("FOV circle color"):AddColorPicker("AimbotFOVColorPick", {
    Title    = "FOV color",
    Default  = Color3.fromRGB(255, 90, 90),
    Callback = function(c) Aimbot.FOVColor = c end,
})
AimbotBox:AddSlider("AimbotFOV", {
    Text     = "FOV radius (px)",
    Default  = 40,
    Min      = 40,
    Max      = 400,
    Rounding = 0,
    Callback = function(v) Aimbot.FOV = v end,
})
AimbotBox:AddSlider("AimbotSmoothness", {
    Text     = "Smoothness (1 = snap)",
    Default  = 1,
    Min      = 1,
    Max      = 20,
    Rounding = 0,
    Callback = function(v) Aimbot.Smoothness = v end,
})
AimbotBox:AddSlider("AimbotMaxDistance", {
    Text     = "Max lock distance (studs)",
    Default  = 50,
    Min      = 50,
    Max      = 2000,
    Rounding = 0,
    Callback = function(v) Aimbot.MaxDistance = v end,
})
AimbotBox:AddDropdown("AimbotTargetPart", {
    Values   = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Default  = 1,
    Multi    = false,
    Text     = "Target part",
    Callback = function(v) Aimbot.TargetPart = v end,
})
AimbotBox:AddToggle("AimbotTeamCheck", {
    Text    = "Team check (skip teammates)",
    Default = false,
    Callback = function(v) Aimbot.TeamCheck = v end,
})

-- ============ MURDER PARTY TAB ============
local SepBox     = MurderTab:AddLeftGroupbox("Separation ESP")
local GunESPBox  = MurderTab:AddRightGroupbox("Gun ESP")
local ClueBox    = MurderTab:AddLeftGroupbox("Clue ESP")
local ChamsBox   = MurderTab:AddRightGroupbox("Chams ESP")
local CollectBox = MurderTab:AddLeftGroupbox("Collect Clues")
local VisualBox  = MurderTab:AddRightGroupbox("Visuals")

SepBox:AddToggle("SeparationESPEnabled", {
    Text    = "Separation ESP",
    Default = false,
    Callback = function(v)
        separationESPEnabled = v
        if v then
            HardClearAllSepESP()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then CreateSeparationESP(player) end
            end
        else
            HardClearAllSepESP()
        end
    end,
})
SepBox:AddToggle("ShowInnocent", {
    Text    = "Show Innocent",
    Default = true,
    Callback = function(v) showInnocent = v end,
})
SepBox:AddToggle("ShowSheriff", {
    Text    = "Show Sheriff",
    Default = true,
    Callback = function(v) showSheriff = v end,
})
SepBox:AddToggle("ShowMurderer", {
    Text    = "Show Murderer",
    Default = true,
    Callback = function(v) showMurderer = v end,
})
SepBox:AddToggle("ShowDead", {
    Text    = "Show Dead",
    Default = false,
    Callback = function(v) showDead = v end,
})

GunESPBox:AddToggle("GunESPEnabled", {
    Text    = "Gun Drop ESP",
    Default = false,
    Callback = function(v)
        gunESPEnabled = v
        if v then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then WatchSheriffDeath(player) end
            end
        else
            ClearAllGunMarkers()
            for player in pairs(sheriffDeathConnections) do StopWatchingSheriffDeath(player) end
        end
    end,
})
GunESPBox:AddButton("Clear Gun Markers", function()
    ClearAllGunMarkers()
    Library:Notify("All gun markers cleared.", 2)
end)
GunESPBox:AddLabel("Pins drop location when Sheriff dies.")

ClueBox:AddToggle("ClueESPEnabled", {
    Text    = "Clue ESP",
    Default = false,
    Callback = function(v)
        clueESPEnabled = v
        if not v then for clue in pairs(clueESPObjects) do RemoveClueESP(clue) end end
    end,
})

ChamsBox:AddToggle("ChamsESPEnabled", {
    Text    = "Chams ESP (other players)",
    Default = false,
    Callback = function(v) chamsEnabled = v; refreshAllChams() end,
})
ChamsBox:AddLabel("Chams color"):AddColorPicker("ChamsColorPick", {
    Title    = "Chams fill",
    Default  = Color3.fromRGB(200, 100, 255),
    Callback = function(c) chamsColor = c; refreshChamsColorsOnly() end,
})

CollectBox:AddToggle("InstantCollect", {
    Text    = "Instant Collect (nearby)",
    Default = false,
    Callback = function(v) instantCollectEnabled = v end,
})
CollectBox:AddSlider("InstantCollectRange", {
    Text     = "Collect range (studs)",
    Default  = 3,
    Min      = 3,
    Max      = 80,
    Rounding = 0,
    Callback = function(v) instantCollectRange = v end,
})

VisualBox:AddToggle("FullbrightEnabled", {
    Text    = "Fullbright",
    Default = false,
    Callback = function(v)
        fullbrightEnabled = v
        if v then EnableFullbright()
        else DisableFullbright(); if noFogEnabled then EnableNoFog() end end
    end,
})
VisualBox:AddLabel("Minimal brightness — enough to see, not blinding.")
VisualBox:AddToggle("NoFogEnabled", {
    Text    = "No Fog",
    Default = false,
    Callback = function(v)
        noFogEnabled = v
        if v then EnableNoFog() else DisableNoFog() end
    end,
})
VisualBox:AddLabel("Removes Atmosphere and Lighting fog.")

-- ============ MOVEMENT TAB ============
local FlyBox  = MovementTab:AddLeftGroupbox("Fly")
local WalkBox = MovementTab:AddRightGroupbox("Walk Speed")

FlyBox:AddToggle("FlyEnabled", {
    Text    = "Fly (WASD + E/Q)",
    Default = false,
    Callback = function(v) flyEnabled = v; if v then HandleFly() end end,
})
FlyBox:AddSlider("FlySpeed", {
    Text     = "Fly speed",
    Default  = 10,
    Min      = 10,
    Max      = 200,
    Rounding = 0,
    Callback = function(v) flySpeed = v end,
})

WalkBox:AddToggle("WalkSpeedEnabled", {
    Text    = "Custom Walk Speed",
    Default = false,
    Callback = function(v)
        walkSpeedEnabled = v
        if not v then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end,
})
WalkBox:AddSlider("WalkSpeedValue", {
    Text     = "Speed",
    Default  = 16,
    Min      = 16,
    Max      = 200,
    Rounding = 0,
    Callback = function(v) customWalkSpeed = v end,
})

-- ============ SERVER TAB ============
local MgmtBox     = ServerTab:AddLeftGroupbox("Management")
local AutoKickBox = ServerTab:AddRightGroupbox("Auto on Kick")

MgmtBox:AddButton("Rejoin", function()
    Library:Notify("Rejoining...", 2)
    task.wait(1); Rejoin()
end)
MgmtBox:AddButton("Server Hop", function()
    Library:Notify("Hopping server...", 2)
    task.wait(1); ServerHop()
end)

AutoKickBox:AddToggle("AutoRejoinEnabled", {
    Text    = "Auto Rejoin on Kick",
    Default = false,
    Callback = function(v) autoRejoinEnabled = v end,
})
AutoKickBox:AddToggle("AutoServerHopEnabled", {
    Text    = "Auto Server Hop on Kick",
    Default = false,
    Callback = function(v) autoServerHopOnKick = v end,
})
AutoKickBox:AddLabel("Detects disconnect / kick screen.")

-- ============ SETTINGS TAB ============
local MenuBox    = SettingsTab:AddLeftGroupbox("Menu")
local CreditsBox = SettingsTab:AddRightGroupbox("Credits")

MenuBox:AddLabel("Toggle menu"):AddKeyPicker("MenuKeybind", {
    Default  = "RightShift",
    NoUI     = true,
    Text     = "Menu key",
    Mode     = "Toggle",
    Callback = function() end,
})
Library.ToggleKeybind = Options.MenuKeybind

CreditsBox:AddLabel("Script by presleyyyyyyy (@jo2527)")

local function fullUnloadCleanup()
    scriptAlive           = false
    clueESPEnabled        = false
    separationESPEnabled  = false
    gunESPEnabled         = false
    instantCollectEnabled = false
    flyEnabled            = false
    walkSpeedEnabled      = false
    killAuraEnabled       = false
    fullbrightEnabled     = false
    noFogEnabled          = false
    Aimbot.Enabled        = false
    HeadExpander.Enabled  = false
    chamsEnabled          = false

    DisableFullbright()
    DisableNoFog()
    teardownChamsHooks()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then removeChamsForCharacter(plr.Character) end
    end
    for clue in pairs(clueESPObjects) do RemoveClueESP(clue) end
    HardClearAllSepESP()
    ClearAllGunMarkers()
    for player in pairs(sheriffDeathConnections) do StopWatchingSheriffDeath(player) end
    stopHeadExpander()
    clearAllHeadEsp()
    for part, base in pairs(originalPartSize) do
        pcall(function() if part.Parent then part.Size = base end end)
    end
    for head, phys in pairs(originalHeadPhysics) do
        pcall(function()
            if head.Parent then
                head.CanCollide = phys.CanCollide
                head.Massless   = phys.Massless
            end
        end)
    end
    originalPartSize    = {}
    originalHeadPhysics = {}
    if walkSpeedConn then walkSpeedConn:Disconnect(); walkSpeedConn = nil end
    aimbotStopRender()
    pcall(function() espFolder:Destroy() end)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end

MenuBox:AddButton("Unload Script", function()
    fullUnloadCleanup()
    Library:Unload()
end)

-- ============ SAVE / THEME ============
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder(LINORIA_FOLDER)
ThemeManager:SetFolder(LINORIA_FOLDER)
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
SaveManager:LoadAutoloadConfig()

aimbotStartRender()

-- ============ PLAYER CONNECTIONS ============
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then setupChamsForPlayer(player) end
    task.spawn(function()
        task.wait(2)
        if not scriptAlive then return end
        if separationESPEnabled and player ~= LocalPlayer then CreateSeparationESP(player) end
        if gunESPEnabled        and player ~= LocalPlayer then WatchSheriffDeath(player)   end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveSeparationESP(player)
    StopWatchingSheriffDeath(player)
    if player.Character then removeChamsForCharacter(player.Character) end
    if chamsPlayerConns[player] then
        pcall(function() chamsPlayerConns[player]:Disconnect() end)
        chamsPlayerConns[player] = nil
    end
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then setupChamsForPlayer(plr) end
end

-- ============ KICK DETECTOR ============
task.spawn(function()
    while scriptAlive do
        task.wait(0.6)
        if kickActionFired then continue end
        pcall(function()
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if v.Name == "ErrorPrompt" or v.Name == "DisconnectedScreen" then
                    kickActionFired = true
                    task.wait(1.2)
                    if autoServerHopOnKick then ServerHop()
                    elseif autoRejoinEnabled then Rejoin() end
                end
            end
        end)
    end
end)

-- ============ MAIN LOOPS ============

-- Clue ESP
task.spawn(function()
    while scriptAlive do
        if clueESPEnabled then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and IsActiveClue(obj) then CreateClueESP(obj) end
            end
            UpdateClueESP()
        end
        task.wait(0.5)
    end
end)

Workspace.DescendantAdded:Connect(function(desc)
    task.wait(0.15)
    if scriptAlive and clueESPEnabled and desc:IsA("BasePart") and IsActiveClue(desc) then
        CreateClueESP(desc)
    end
end)

-- Lighting enforcement
task.spawn(function()
    while scriptAlive do
        task.wait(1)
        if fullbrightEnabled then
            Lighting.Brightness     = 1
            Lighting.ClockTime      = 12
            Lighting.GlobalShadows  = false
            Lighting.Ambient        = Color3.fromRGB(180, 180, 180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        end
        if noFogEnabled then
            Lighting.FogEnd   = 100000
            Lighting.FogStart = 100000
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0; atm.Offset = 0; atm.Haze = 0; atm.Glare = 0 end
        end
    end
end)

-- Instant Collect
task.spawn(function()
    while scriptAlive do
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

-- Separation ESP refresh
task.spawn(function()
    while scriptAlive do
        task.wait(1.5)
        if separationESPEnabled then
            for player, data in pairs(separationESPObjects) do
                if not player or not player.Parent then continue end
                if not data.billboard or not data.billboard.Parent then
                    BuildSepBillboard(player)
                    continue
                end
                local role    = GetRole(player)
                local color   = GetRoleColor(role)
                local visible = ShouldShowRole(role)
                data.billboard.Enabled = visible
                if data.roleLabel and data.roleLabel.Parent then
                    data.roleLabel.Text = GetRoleEmoji(role)
                end
                if data.frame and data.frame.Parent then
                    data.frame.BackgroundColor3 = color
                end
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and data.billboard.Adornee ~= root then
                    data.billboard.Adornee = root
                end
            end
        end
    end
end)

-- Walk speed
walkSpeedConn = RunService.Heartbeat:Connect(function()
    if scriptAlive and walkSpeedEnabled then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = customWalkSpeed end
    end
end)

-- Kill Aura
task.spawn(function()
    while scriptAlive do
        if killAuraEnabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local tr = player.Character:FindFirstChild("HumanoidRootPart")
                        local th = player.Character:FindFirstChildOfClass("Humanoid")
                        if tr and th and th.Health > 0
                            and (tr.Position - root.Position).Magnitude <= killAuraRange then
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

-- Character respawn
LocalPlayer.CharacterAdded:Connect(function()
    if scriptAlive and flyEnabled then task.wait(1); HandleFly() end
end)

Library:Notify("Item Asylum loaded.", 3)
