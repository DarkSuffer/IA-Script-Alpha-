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

local HeadExpander = { Enabled = false, Multiplier = 2, RoleOnly = false }
local originalPartSize      = {}
local originalHeadPhysics   = {}
local headEspByHead         = {}
local headExpanderCharConns = {}
local headPollActive        = false

local clueESPEnabled          = false
local separationESPEnabled    = false
local showInnocent            = true
local showSheriff             = true
local showMurderer            = true
local showJester              = true
local showDead                = false
local gunESPEnabled           = false
local instantCollectEnabled   = false
local instantCollectRange     = 3
local autoTeleportClueActive  = false
local flyEnabled              = false
local flySpeed                = 10
local walkSpeedEnabled        = false
local customWalkSpeed         = 16
local noclipEnabled           = false
local killAuraEnabled         = false
local killAuraRange           = 5
local fullbrightEnabled       = false
local noFogEnabled            = false
local autoRejoinEnabled       = false
local autoServerHopOnKick     = false
local kickActionFired         = false
local chamsEnabled            = false
local chamsColor              = Color3.fromRGB(200, 100, 255)

local savedLighting   = {}
local savedAtmosphere = {}
local atmosphereRef   = nil

local Aimbot = {
    Enabled = false, FOV = 40, UseFOVLimit = false, ShowFOV = false,
    FOVColor = Color3.fromRGB(255, 90, 90), Smoothness = 1, TargetPart = "Head",
    TeamCheck = false, HoldMode = true, MaxDistance = 50,
}

local aimbotRenderConn = nil
local FOVCircle        = nil
local drawingLibOk     = pcall(function() return Drawing.new ~= nil end)
local chamsPlayerConns = {}
local noclipConn       = nil

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
local sessionStart   = tick()

-- ============ ROLE DETECTION ============
local SHERIFF_GUNS = { ["mad sheriff"] = true, ["mad handgun"] = true }
local function isMurdererTool(n) return n:lower():sub(1, 3) == "mu_" end
local function isSheriffTool(n)  return SHERIFF_GUNS[n:lower()] == true end
local function isJesterToolName(n) return n:lower():sub(1, 3) == "je_" end

-- Cache: tool -> boolean (is jester weapon). Weak keys: auto-GC when tool destroyed.
local jesterToolCache = setmetatable({}, { __mode = "k" })

local DMG_MULT_KEYS = {
    "DamageMultiplier", "DmgMult", "Multiplier", "dmgMult",
    "damageMultiplier", "DamageMult", "Damage_Multiplier",
}

local function readNumberFromValueObject(obj)
    if not obj then return nil end
    if obj:IsA("NumberValue") or obj:IsA("IntValue") then
        return obj.Value
    end
    return nil
end

local function scanConfigContainerForNegMult(container)
    if not container then return false end
    for _, key in ipairs(DMG_MULT_KEYS) do
        local child = container:FindFirstChild(key)
        local n = readNumberFromValueObject(child)
        if n and n < 0 then return true end
    end
    for _, key in ipairs(DMG_MULT_KEYS) do
        local ok, val = pcall(container.GetAttribute, container, key)
        if ok and type(val) == "number" and val < 0 then return true end
    end
    return false
end

local function IsJesterWeapon(tool)
    if not tool or not tool:IsA("Tool") then return false end

    local cached = jesterToolCache[tool]
    if cached ~= nil then return cached end

    local result = false

    if isJesterToolName(tool.Name) then
        result = true
    else
        for _, key in ipairs(DMG_MULT_KEYS) do
            local ok, val = pcall(tool.GetAttribute, tool, key)
            if ok and type(val) == "number" and val < 0 then
                result = true
                break
            end
        end

        if not result then
            for _, desc in ipairs(tool:GetDescendants()) do
                if desc.Name == "Config" then
                    if desc:IsA("Folder") or desc:IsA("Configuration") or desc:IsA("Model") then
                        if scanConfigContainerForNegMult(desc) then
                            result = true
                            break
                        end
                    elseif desc:IsA("ModuleScript") then
                        local ok, mod = pcall(require, desc)
                        if ok and type(mod) == "table" then
                            for _, key in ipairs(DMG_MULT_KEYS) do
                                local v = mod[key]
                                if type(v) == "number" and v < 0 then
                                    result = true
                                    break
                                end
                            end
                            if result then break end
                        end
                    end
                end
            end
        end

        if not result then
            for _, desc in ipairs(tool:GetDescendants()) do
                if desc:IsA("NumberValue") or desc:IsA("IntValue") then
                    for _, key in ipairs(DMG_MULT_KEYS) do
                        if desc.Name == key and desc.Value < 0 then
                            result = true
                            break
                        end
                    end
                    if result then break end
                end
            end
        end
    end

    jesterToolCache[tool] = result

    pcall(function()
        tool.Destroying:Connect(function()
            jesterToolCache[tool] = nil
        end)
    end)

    return result
end

local function ScanToolsForRole(player)
    local containers = {}
    if player.Character then table.insert(containers, player.Character) end
    local bp = player:FindFirstChild("Backpack")
    if bp then table.insert(containers, bp) end

    -- Pass 1: Jester check has priority (jester can hold ANY weapon, including mu_*)
    -- Negative damage multiplier is the ground truth.
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Tool") and IsJesterWeapon(obj) then
                return "Jester"
            end
        end
    end

    -- Pass 2: standard role detection by tool name
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
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
    if role == "Murderer" then return Color3.fromRGB(255, 50, 50) end
    if role == "Sheriff"  then return Color3.fromRGB(50, 150, 255) end
    if role == "Jester"   then return Color3.fromRGB(255, 100, 220) end
    if role == "Dead"     then return Color3.fromRGB(120, 120, 120) end
    return Color3.fromRGB(100, 255, 100)
end

local function GetRoleEmoji(role)
    if role == "Murderer" then return "Murderer" end
    if role == "Sheriff"  then return "Sheriff" end
    if role == "Jester"   then return "Jester" end
    if role == "Dead"     then return "Dead" end
    return "Innocent"
end

local function ShouldShowRole(role)
    if role == "Innocent" then return showInnocent end
    if role == "Sheriff"  then return showSheriff end
    if role == "Murderer" then return showMurderer end
    if role == "Jester"   then return showJester end
    if role == "Dead"     then return showDead end
    return false
end

-- ============ HEAD EXPANDER ============
local function clampMultiplier(n)
    return math.clamp(math.floor(n + 0.5), 1, 15)
end

local function restoreHead(head)
    if originalPartSize[head] then
        pcall(function() head.Size = originalPartSize[head] end)
    end
    if originalHeadPhysics[head] then
        pcall(function()
            head.CanCollide = originalHeadPhysics[head].CanCollide
            head.Massless   = originalHeadPhysics[head].Massless
        end)
    end
    pcall(function()
        local hl = head:FindFirstChild("ItemAsylumHeadESP")
        if hl then hl:Destroy() end
    end)
    headEspByHead[head] = nil
end

local function scaleHead(head, multiplier)
    if not originalPartSize[head] then originalPartSize[head] = head.Size end
    if not originalHeadPhysics[head] then
        originalHeadPhysics[head] = { CanCollide = head.CanCollide, Massless = head.Massless }
    end
    local m = clampMultiplier(multiplier)
    head.Size = originalPartSize[head] * m
    if m > 1 then
        head.CanCollide = false
        head.Massless   = true
    else
        head.CanCollide = originalHeadPhysics[head].CanCollide
        head.Massless   = originalHeadPhysics[head].Massless
    end
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

local function processPlayerHead(player)
    if player == LocalPlayer then return end
    if not player or not player.Parent then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end

    if not HeadExpander.Enabled then
        restoreHead(head)
        return
    end

    if HeadExpander.RoleOnly then
        local role = ScanToolsForRole(player)
        if role ~= "Sheriff" and role ~= "Murderer" and role ~= "Jester" then
            if originalPartSize[head] then
                restoreHead(head)
            end
            return
        end
    end

    scaleHead(head, HeadExpander.Multiplier)
end

local function refreshAllHeads()
    for _, plr in ipairs(Players:GetPlayers()) do
        pcall(function() processPlayerHead(plr) end)
    end
end

local function clearAllHeadEsp()
    for head in pairs(headEspByHead) do
        pcall(function()
            local hl = head:FindFirstChild("ItemAsylumHeadESP")
            if hl then hl:Destroy() end
        end)
    end
    table.clear(headEspByHead)
end

local function restoreAllHeads()
    for part, base in pairs(originalPartSize) do
        pcall(function() if part and part.Parent then part.Size = base end end)
    end
    for head, phys in pairs(originalHeadPhysics) do
        pcall(function()
            if head and head.Parent then
                head.CanCollide = phys.CanCollide
                head.Massless   = phys.Massless
            end
        end)
    end
    clearAllHeadEsp()
    table.clear(originalPartSize)
    table.clear(originalHeadPhysics)
end

local function disconnectHeadExpanderConns(player)
    local conns = headExpanderCharConns[player]
    if not conns then return end
    for _, conn in ipairs(conns) do
        pcall(function() conn:Disconnect() end)
    end
    headExpanderCharConns[player] = nil
end

local function stopHeadExpander()
    headPollActive = false
    for plr in pairs(headExpanderCharConns) do
        disconnectHeadExpanderConns(plr)
    end
end

local function hookPlayerForHeadExpander(player)
    if player == LocalPlayer then return end
    if headExpanderCharConns[player] then return end

    local conns = {}

    local function watchContainer(container)
        if not container then return end
        table.insert(conns, container.ChildAdded:Connect(function(child)
            if not HeadExpander.Enabled then return end
            if child:IsA("Tool") or child:IsA("Model") then
                task.wait(0.05)
                pcall(function() processPlayerHead(player) end)
            end
        end))
        table.insert(conns, container.ChildRemoved:Connect(function(child)
            if not HeadExpander.Enabled then return end
            if child:IsA("Tool") or child:IsA("Model") then
                task.wait(0.05)
                pcall(function() processPlayerHead(player) end)
            end
        end))
    end

    local function onCharAdded(char)
        task.wait(0.3)
        if not HeadExpander.Enabled then return end

        watchContainer(char)
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                watchContainer(child)
            end
        end

        local bp = player:FindFirstChild("Backpack")
        if bp then watchContainer(bp) end

        table.insert(conns, player.ChildAdded:Connect(function(child)
            if child.Name == "Backpack" then
                task.wait(0.1)
                watchContainer(child)
            end
        end))

        for delay = 0, 4 do
            task.spawn(function()
                task.wait(delay * 0.5)
                if HeadExpander.Enabled then
                    pcall(function() processPlayerHead(player) end)
                end
            end)
        end
    end

    if player.Character then
        task.spawn(function() onCharAdded(player.Character) end)
    end

    table.insert(conns, player.CharacterAdded:Connect(function(char)
        onCharAdded(char)
    end))

    headExpanderCharConns[player] = conns
end

local function startHeadExpander()
    stopHeadExpander()
    if not HeadExpander.Enabled then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        hookPlayerForHeadExpander(plr)
    end

    headPollActive = true
    task.spawn(function()
        for i = 1, 10 do
            if not (scriptAlive and headPollActive and HeadExpander.Enabled) then break end
            refreshAllHeads()
            task.wait(0.4)
        end
        while scriptAlive and headPollActive and HeadExpander.Enabled do
            refreshAllHeads()
            task.wait(1)
        end
    end)
end

-- ============ NOCLIP ============
local function startNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if not scriptAlive or not noclipEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

-- ============ CLUE DETECTION ============
local function IsActiveClue(part)
    if not part or not part.Parent then return false end
    if not part:IsA("BasePart") then return false end
    local prompt = part:FindFirstChild("UsePrompt")
    return prompt and prompt:IsA("ProximityPrompt")
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
            local dist = (obj.Position - root.Position).Magnitude
            if dist <= range then
                local prompt = GetCluePrompt(obj)
                if prompt then
                    table.insert(clues, { part = obj, prompt = prompt, dist = dist })
                end
            end
        end
    end
    return clues
end

local function GetAllActiveClues()
    local clues = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if IsActiveClue(obj) then
            local prompt = GetCluePrompt(obj)
            if prompt then table.insert(clues, { part = obj, prompt = prompt }) end
        end
    end
    return clues
end

-- ============ CLUE ESP ============
local function CreateClueESP(clue)
    if clueESPObjects[clue] then return end

    local bb = Instance.new("BillboardGui")
    bb.Name        = "ClueESP"
    bb.Adornee     = clue
    bb.Size        = UDim2.new(0, 110, 0, 60)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent      = clue

    local fr = Instance.new("Frame", bb)
    fr.Size                   = UDim2.new(1, 0, 1, 0)
    fr.BackgroundColor3       = Color3.fromRGB(85, 255, 127)
    fr.BackgroundTransparency = 0.6
    fr.BorderSizePixel        = 0
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 6)

    local lb = Instance.new("TextLabel", fr)
    lb.Size                  = UDim2.new(1, 0, 0.55, 0)
    lb.Position              = UDim2.new(0, 0, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text                  = "CLUE"
    lb.TextColor3            = Color3.new(1, 1, 1)
    lb.TextSize              = 14
    lb.Font                  = Enum.Font.GothamBold
    lb.TextStrokeTransparency = 0.5

    local dl = Instance.new("TextLabel", fr)
    dl.Size                  = UDim2.new(1, 0, 0.45, 0)
    dl.Position              = UDim2.new(0, 0, 0.55, 0)
    dl.BackgroundTransparency = 1
    dl.Text                  = "..."
    dl.TextColor3            = Color3.fromRGB(255, 255, 200)
    dl.TextSize              = 13
    dl.Font                  = Enum.Font.GothamSemibold
    dl.TextStrokeTransparency = 0.4

    clueESPObjects[clue] = { billboard = bb, distanceLabel = dl }
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
    if not root then return end

    for clue, data in pairs(clueESPObjects) do
        if not clue or not clue.Parent or not IsActiveClue(clue) then
            RemoveClueESP(clue)
        else
            if data.distanceLabel and data.distanceLabel.Parent then
                local dist = (clue.Position - root.Position).Magnitude
                data.distanceLabel.Text = string.format("%dm", math.floor(dist))
            end
        end
    end
end

local function SweepClueESP()
    if not clueESPEnabled then return end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and IsActiveClue(o) then
            CreateClueESP(o)
        end
    end
end

-- ============ SEPARATION ESP ============
local function HardClearAllSepESP()
    for _, child in ipairs(espFolder:GetChildren()) do pcall(function() child:Destroy() end) end
    for _, data in pairs(separationESPObjects) do
        if data.charConn then pcall(function() data.charConn:Disconnect() end) end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name == "SeparationESP" then
            pcall(function() obj:Destroy() end)
        end
    end
    table.clear(separationESPObjects)
end

local function BuildSepBillboard(player)
    local char = player.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local data = separationESPObjects[player]; if not data then return end
    if data.billboard then pcall(function() data.billboard:Destroy() end); data.billboard = nil end
    local role = GetRole(player); local color = GetRoleColor(role); local visible = ShouldShowRole(role)
    local bb = Instance.new("BillboardGui"); bb.Name = "SeparationESP"; bb.Adornee = root
    bb.Size = UDim2.new(0,140,0,40); bb.StudsOffset = Vector3.new(0,3.5,0)
    bb.AlwaysOnTop = true; bb.Enabled = visible; bb.Parent = espFolder
    local fr = Instance.new("Frame", bb); fr.Size = UDim2.new(1,0,1,0)
    fr.BackgroundColor3 = color; fr.BackgroundTransparency = 0.5; fr.BorderSizePixel = 0
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0,6)
    local bar = Instance.new("Frame", fr); bar.Size = UDim2.new(0,3,1,0)
    bar.BackgroundColor3 = color; bar.BorderSizePixel = 0
    local nl = Instance.new("TextLabel", fr); nl.Size = UDim2.new(1,-8,0.5,0)
    nl.Position = UDim2.new(0,6,0,0); nl.BackgroundTransparency = 1; nl.Text = player.Name
    nl.TextColor3 = Color3.new(1,1,1); nl.TextSize = 12; nl.Font = Enum.Font.GothamBold
    nl.TextXAlignment = Enum.TextXAlignment.Left; nl.TextTruncate = Enum.TextTruncate.AtEnd
    local rl = Instance.new("TextLabel", fr); rl.Size = UDim2.new(1,-8,0.5,0)
    rl.Position = UDim2.new(0,6,0.5,0); rl.BackgroundTransparency = 1; rl.Text = GetRoleEmoji(role)
    rl.TextColor3 = Color3.new(1,1,1); rl.TextSize = 11; rl.Font = Enum.Font.Gotham
    rl.TextXAlignment = Enum.TextXAlignment.Left
    data.billboard = bb; data.roleLabel = rl; data.frame = fr
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
    local data = separationESPObjects[player]; if not data then return end
    if data.billboard then pcall(function() data.billboard:Destroy() end) end
    if data.charConn  then pcall(function() data.charConn:Disconnect() end) end
    separationESPObjects[player] = nil
end

-- ============ GUN ESP ============
local function DestroyGunMarker(md)
    if not md then return end
    pcall(function() md.marker:Destroy() end)
    for i, d in ipairs(gunESPMarkers) do
        if d == md then table.remove(gunESPMarkers, i) break end
    end
end

local function CreateGunMarker(position, sheriffName)
    local marker = Instance.new("Part"); marker.Name = "GunDropMarker"
    marker.Anchored = true; marker.CanCollide = false; marker.Transparency = 1
    marker.Size = Vector3.new(1,1,1); marker.Position = position; marker.Parent = Workspace
    local bb = Instance.new("BillboardGui"); bb.Name = "GunESP"; bb.Adornee = marker
    bb.Size = UDim2.new(0,150,0,55); bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true; bb.Parent = marker
    local fr = Instance.new("Frame", bb); fr.Size = UDim2.new(1,0,1,0)
    fr.BackgroundColor3 = Color3.fromRGB(255,215,0); fr.BackgroundTransparency = 0.5; fr.BorderSizePixel = 0
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0,6)
    local t = Instance.new("TextLabel", fr); t.Size = UDim2.new(1,0,0.55,0)
    t.BackgroundTransparency = 1; t.Text = "GUN DROPPED"
    t.TextColor3 = Color3.new(1,1,1); t.TextSize = 12; t.Font = Enum.Font.GothamBold
    local inf = Instance.new("TextLabel", fr); inf.Size = UDim2.new(1,0,0.45,0)
    inf.Position = UDim2.new(0,0,0.55,0); inf.BackgroundTransparency = 1
    inf.Text = "Sheriff: "..sheriffName; inf.TextColor3 = Color3.fromRGB(255,230,100)
    inf.TextSize = 10; inf.Font = Enum.Font.Gotham
    local md = { marker = marker, billboard = bb }
    table.insert(gunESPMarkers, md)
    task.spawn(function()
        task.wait(0.5)
        local fg = nil
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Tool") and isSheriffTool(obj.Name) then
                local h = obj:FindFirstChild("Handle")
                if h and (h.Position - position).Magnitude < 30 then fg = obj break end
            end
        end
        if fg then
            local cn; cn = fg.AncestryChanged:Connect(function(_, np)
                if np ~= Workspace then cn:Disconnect(); task.wait(0.3)
                    if fg.Parent ~= Workspace then DestroyGunMarker(md) end end end)
            fg.Destroying:Connect(function() DestroyGunMarker(md) end)
        else task.wait(30); DestroyGunMarker(md) end
    end)
end

local function ClearAllGunMarkers()
    for _, d in ipairs(gunESPMarkers) do pcall(function() d.marker:Destroy() end) end
    gunESPMarkers = {}
end

local function WatchSheriffDeath(player)
    if sheriffDeathConnections[player] then return end
    local function oc(char)
        local hum = char:WaitForChild("Humanoid", 5); if not hum then return end
        hum.Died:Connect(function()
            if not gunESPEnabled then return end
            if ScanToolsForRole(player) == "Sheriff" then
                local r = char:FindFirstChild("HumanoidRootPart")
                if r then CreateGunMarker(r.Position, player.Name) end
            end
        end)
    end
    if player.Character then task.spawn(function() oc(player.Character) end) end
    sheriffDeathConnections[player] = player.CharacterAdded:Connect(function(c)
        task.wait(0.5); oc(c)
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
            or v:IsA("LinearVelocity") or v:IsA("AlignOrientation") then v:Destroy() end
    end
    local att = Instance.new("Attachment", root); att.Name = "FlyAttachment"
    local lv = Instance.new("LinearVelocity", root); lv.Name = "FlyVelocity"
    lv.Attachment0 = att; lv.MaxForce = math.huge; lv.VectorVelocity = Vector3.zero
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    local ao = Instance.new("AlignOrientation", root); ao.Name = "FlyGyro"
    ao.Attachment0 = att; ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.MaxTorque = math.huge; ao.Responsiveness = 200
    task.spawn(function()
        while flyEnabled and scriptAlive and root and root.Parent do
            local cam = Workspace.CurrentCamera; local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.new(0,1,0) end
            lv.VectorVelocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
            ao.CFrame = cam.CFrame; RunService.Heartbeat:Wait()
        end
        pcall(function() lv:Destroy() end)
        pcall(function() ao:Destroy() end)
        pcall(function() att:Destroy() end)
    end)
end

-- ============ LIGHTING ============
local function EnableFullbright()
    if not next(savedLighting) then
        savedLighting = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
    end
    Lighting.Brightness = 1; Lighting.ClockTime = 12; Lighting.FogEnd = 100000; Lighting.FogStart = 100000
    Lighting.GlobalShadows = false; Lighting.Ambient = Color3.fromRGB(180,180,180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
end
local function DisableFullbright()
    if next(savedLighting) then
        for p, v in pairs(savedLighting) do Lighting[p] = v end; savedLighting = {}
    end
end
local function EnableNoFog()
    atmosphereRef = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphereRef then
        savedAtmosphere = { Density = atmosphereRef.Density, Offset = atmosphereRef.Offset,
            Haze = atmosphereRef.Haze, Glare = atmosphereRef.Glare }
        atmosphereRef.Density = 0; atmosphereRef.Offset = 0
        atmosphereRef.Haze = 0; atmosphereRef.Glare = 0
    end
    Lighting.FogEnd = 100000; Lighting.FogStart = 100000
end
local function DisableNoFog()
    if not fullbrightEnabled and next(savedLighting) then
        Lighting.FogEnd = savedLighting.FogEnd; Lighting.FogStart = savedLighting.FogStart
    end
    if atmosphereRef and atmosphereRef.Parent and next(savedAtmosphere) then
        for p, v in pairs(savedAtmosphere) do atmosphereRef[p] = v end; savedAtmosphere = {}
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
        local pid = game.PlaceId
        local s = HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/"..pid.."/servers/Public?sortOrder=Asc&limit=100"))
        for _, sv in ipairs(s.data or {}) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                TeleportService:TeleportToPlaceInstance(pid, sv.id, LocalPlayer) return
            end
        end
        TeleportService:Teleport(pid, LocalPlayer)
    end)
end

-- ============ CHAMS ============
local function removeChamsForCharacter(c)
    if not c then return end
    local h = c:FindFirstChild("ItemAsylumChams"); if h then pcall(function() h:Destroy() end) end
end
local function applyChamsHighlightStyle(hl)
    if not hl then return end; local c = chamsColor
    hl.FillColor = c
    hl.OutlineColor = Color3.new(math.min(c.R*1.2,1), math.min(c.G*1.2,1), math.min(c.B*1.2,1))
    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0.25
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end
local function ensureChamsOnCharacter(character)
    if not character or not character:IsA("Model") then return end
    if Players:GetPlayerFromCharacter(character) == LocalPlayer then
        removeChamsForCharacter(character) return end
    if not chamsEnabled then removeChamsForCharacter(character) return end
    local hl = character:FindFirstChild("ItemAsylumChams")
    if not hl then hl = Instance.new("Highlight"); hl.Name = "ItemAsylumChams"; hl.Parent = character end
    applyChamsHighlightStyle(hl)
end
local function refreshAllChams()
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character; if not c then continue end
        if p == LocalPlayer then removeChamsForCharacter(c)
        elseif chamsEnabled then ensureChamsOnCharacter(c)
        else removeChamsForCharacter(c) end
    end
end
local function refreshChamsColorsOnly()
    if not chamsEnabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hl = p.Character:FindFirstChild("ItemAsylumChams")
            if hl then applyChamsHighlightStyle(hl) end
        end
    end
end
local function setupChamsForPlayer(player)
    if player == LocalPlayer or chamsPlayerConns[player] then return end
    chamsPlayerConns[player] = player.CharacterAdded:Connect(function(c)
        task.defer(function() task.wait(0.35)
            if scriptAlive and chamsEnabled then ensureChamsOnCharacter(c) end end) end)
    if player.Character then ensureChamsOnCharacter(player.Character) end
end
local function teardownChamsHooks()
    for p, cn in pairs(chamsPlayerConns) do
        if cn then pcall(function() cn:Disconnect() end) end
        chamsPlayerConns[p] = nil
    end
end

-- ============ AIMBOT ============
local function getCamera() return Workspace.CurrentCamera end
local function getAimbotBodyPart(character, partName)
    if not character then return nil end
    local p = character:FindFirstChild(partName)
    if p and p:IsA("BasePart") then return p end
    local alt = { Head = {"Head"}, HumanoidRootPart = {"HumanoidRootPart","UpperTorso","Torso"},
        UpperTorso = {"UpperTorso","Torso","LowerTorso"}, LowerTorso = {"LowerTorso","UpperTorso","Torso"} }
    local list = alt[partName]; if list then
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
    local cam = getCamera(); local mc = LocalPlayer.Character
    local mr = mc and mc:FindFirstChild("HumanoidRootPart")
    if not cam or not mr then return nil end
    local center = Vector2.new(cam.ViewportSize.X*0.5, cam.ViewportSize.Y*0.5)
    local bp, bsd = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local c = plr.Character; if not c then continue end
        local h = c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then continue end
        if isAimbotTeammate(plr) then continue end
        local part = getAimbotBodyPart(c, Aimbot.TargetPart); if not part then continue end
        if (part.Position - mr.Position).Magnitude > Aimbot.MaxDistance then continue end
        local vp, os = cam:WorldToViewportPoint(part.Position)
        if not os or vp.Z <= 0 then continue end
        local sd = (Vector2.new(vp.X,vp.Y) - center).Magnitude
        if Aimbot.UseFOVLimit and sd > Aimbot.FOV then continue end
        if sd < bsd then bsd = sd; bp = part end
    end
    return bp
end
local function aimbotApplyCamera(tp)
    local cam = getCamera(); if not cam or not tp then return end
    local tcf = CFrame.lookAt(cam.CFrame.Position, tp.Position)
    if Aimbot.Smoothness <= 1 then cam.CFrame = tcf
    else cam.CFrame = cam.CFrame:Lerp(tcf, math.clamp(1/Aimbot.Smoothness, 0.04, 0.92)) end
end
local function aimbotEnsureFOVCircle()
    if not Aimbot.ShowFOV or not drawingLibOk or FOVCircle then return end
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if not ok or not c then return end
    FOVCircle = c; FOVCircle.Thickness = 2; FOVCircle.NumSides = 64
    FOVCircle.Filled = false; FOVCircle.ZIndex = 2; FOVCircle.Transparency = 0.65
end
local function aimbotUpdateFOVDrawing()
    if not FOVCircle then return end; local cam = getCamera()
    if not cam then FOVCircle.Visible = false return end
    FOVCircle.Position = Vector2.new(cam.ViewportSize.X*0.5, cam.ViewportSize.Y*0.5)
    FOVCircle.Radius = Aimbot.FOV; FOVCircle.Color = Aimbot.FOVColor
    FOVCircle.Visible = scriptAlive and Aimbot.ShowFOV
end
local function aimbotDestroyFOVCircle()
    if FOVCircle then pcall(function() FOVCircle:Remove() end); FOVCircle = nil end end
local function aimbotStopRender()
    if aimbotRenderConn then aimbotRenderConn:Disconnect(); aimbotRenderConn = nil end
    aimbotDestroyFOVCircle()
end
local function aimbotStartRender()
    aimbotStopRender()
    aimbotRenderConn = RunService.RenderStepped:Connect(function()
        if not scriptAlive then return end
        if Aimbot.ShowFOV and drawingLibOk then aimbotEnsureFOVCircle(); aimbotUpdateFOVDrawing()
        elseif FOVCircle then FOVCircle.Visible = false end
        if not Aimbot.Enabled then return end
        local ka = false; pcall(function() ka = Options.AimbotKeybind:GetState() end)
        if Aimbot.HoldMode and not ka then return end
        local t = findBestAimbotTarget(); if t then aimbotApplyCamera(t) end
    end)
end

-- ============ AUTO TELEPORT COLLECT ============
local function RunAutoTeleportCollect()
    if autoTeleportClueActive then return end
    if not instantCollectEnabled then
        Library:Notify("Enable Instant Collect first.", 3)
        pcall(function() Toggles.AutoTeleportCollect:SetValue(false) end)
        return
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        Library:Notify("No character.", 2)
        pcall(function() Toggles.AutoTeleportCollect:SetValue(false) end)
        return
    end

    autoTeleportClueActive = true

    task.spawn(function()
        local homeCFrame = root.CFrame

        while scriptAlive and autoTeleportClueActive do
            char = LocalPlayer.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then
                task.wait(1)
                continue
            end

            if not instantCollectEnabled then
                autoTeleportClueActive = false
                pcall(function() Toggles.AutoTeleportCollect:SetValue(false) end)
                Library:Notify("Instant Collect disabled. Stopping.", 3)
                break
            end

            local clues = GetAllActiveClues()

            if #clues == 0 then
                task.wait(1)
                continue
            end

            Library:Notify("Auto collect: " .. #clues .. " clues.", 3)
            homeCFrame = root.CFrame

            for _, cd in ipairs(clues) do
                if not scriptAlive or not autoTeleportClueActive then break end

                local clue   = cd.part
                local prompt = cd.prompt

                if not clue or not clue.Parent or not IsActiveClue(clue) then continue end
                if not prompt or not prompt.Parent then continue end

                char = LocalPlayer.Character
                root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then break end

                root.CFrame = CFrame.new(clue.Position + Vector3.new(0, 4, 0))

                local deadline = tick() + 4
                while tick() < deadline do
                    if not scriptAlive or not autoTeleportClueActive then break end
                    if not clue.Parent or not IsActiveClue(clue) then break end
                    task.wait(0.05)
                end

                task.wait(0.15)
            end

            char = LocalPlayer.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            if root and root.Parent then
                root.CFrame = homeCFrame
            end

            task.wait(0.5)
        end

        autoTeleportClueActive = false
        pcall(function() Toggles.AutoTeleportCollect:SetValue(false) end)
        Library:Notify("Auto collect stopped.", 3)
    end)
end

-- ============ GUI ============

local HeadBox   = MainTab:AddLeftGroupbox("Head Expander (Others Only)")
local CombatBox = MainTab:AddRightGroupbox("Kill Aura")
local AimbotBox = MainTab:AddRightGroupbox("Aimbot (FOV)")

HeadBox:AddToggle("HeadExpanderEnabled", { Text = "Enable Head Expander", Default = false,
    Callback = function(v) HeadExpander.Enabled = v
        if v then startHeadExpander() else stopHeadExpander(); restoreAllHeads() end end })
HeadBox:AddSlider("HeadExpanderMultiplier", {
    Text = "Head scale (max 15x)", Default = 2, Min = 1, Max = 15, Rounding = 0,
    Callback = function(v) HeadExpander.Multiplier = clampMultiplier(v)
        if HeadExpander.Enabled then refreshAllHeads() end end })
HeadBox:AddToggle("HeadExpanderRoleOnly", {
    Text = "Only expand Sheriff / Murderer / Jester", Default = false,
    Callback = function(v) HeadExpander.RoleOnly = v
        if HeadExpander.Enabled then refreshAllHeads() end end })

CombatBox:AddToggle("KillAuraEnabled", { Text = "Kill Aura", Default = false,
    Callback = function(v) killAuraEnabled = v end })
CombatBox:AddSlider("KillAuraRange", {
    Text = "Range (studs)", Default = 5, Min = 5, Max = 50, Rounding = 0,
    Callback = function(v) killAuraRange = v end })

AimbotBox:AddToggle("AimbotEnabled", { Text = "Enable Aimbot", Default = false,
    Callback = function(v) Aimbot.Enabled = v end })
AimbotBox:AddLabel("Aimbot hold key"):AddKeyPicker("AimbotKeybind", {
    Default = "MB2", SyncToggleState = false, Mode = "Hold",
    Text = "Aimbot Key", NoUI = false, Callback = function(_) end })
AimbotBox:AddToggle("AimbotHoldMode", { Text = "Require hold (off = always on)", Default = true,
    Callback = function(v) Aimbot.HoldMode = v end })
AimbotBox:AddToggle("AimbotFOVLimit", { Text = "Limit to FOV circle", Default = false,
    Callback = function(v) Aimbot.UseFOVLimit = v end })
AimbotBox:AddToggle("AimbotShowFOV", { Text = "Show FOV circle", Default = false,
    Callback = function(v) Aimbot.ShowFOV = v; if not v then aimbotDestroyFOVCircle() end end })
AimbotBox:AddLabel("FOV color"):AddColorPicker("AimbotFOVColorPick", {
    Title = "FOV color", Default = Color3.fromRGB(255,90,90),
    Callback = function(c) Aimbot.FOVColor = c end })
AimbotBox:AddSlider("AimbotFOV", { Text = "FOV radius (px)", Default = 40, Min = 40, Max = 400, Rounding = 0,
    Callback = function(v) Aimbot.FOV = v end })
AimbotBox:AddSlider("AimbotSmoothness", { Text = "Smoothness (1=snap)", Default = 1, Min = 1, Max = 20, Rounding = 0,
    Callback = function(v) Aimbot.Smoothness = v end })
AimbotBox:AddSlider("AimbotMaxDistance", { Text = "Max distance (studs)", Default = 50, Min = 50, Max = 2000, Rounding = 0,
    Callback = function(v) Aimbot.MaxDistance = v end })
AimbotBox:AddDropdown("AimbotTargetPart", {
    Values = {"Head","HumanoidRootPart","UpperTorso","LowerTorso"},
    Default = 1, Multi = false, Text = "Target part",
    Callback = function(v) Aimbot.TargetPart = v end })
AimbotBox:AddToggle("AimbotTeamCheck", { Text = "Team check", Default = false,
    Callback = function(v) Aimbot.TeamCheck = v end })

local SepBox     = MurderTab:AddLeftGroupbox("Separation ESP")
local GunESPBox  = MurderTab:AddRightGroupbox("Gun ESP")
local ClueBox    = MurderTab:AddLeftGroupbox("Clue ESP")
local ChamsBox   = MurderTab:AddRightGroupbox("Chams ESP")
local CollectBox = MurderTab:AddLeftGroupbox("Collect Clues")
local VisualBox  = MurderTab:AddRightGroupbox("Visuals")

SepBox:AddToggle("SeparationESPEnabled", { Text = "Separation ESP", Default = false,
    Callback = function(v) separationESPEnabled = v
        if v then HardClearAllSepESP()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then CreateSeparationESP(p) end end
        else HardClearAllSepESP() end end })
SepBox:AddToggle("ShowInnocent", { Text = "Show Innocent", Default = true,
    Callback = function(v) showInnocent = v end })
SepBox:AddToggle("ShowSheriff", { Text = "Show Sheriff", Default = true,
    Callback = function(v) showSheriff = v end })
SepBox:AddToggle("ShowMurderer", { Text = "Show Murderer", Default = true,
    Callback = function(v) showMurderer = v end })
SepBox:AddToggle("ShowJester", { Text = "Show Jester", Default = true,
    Callback = function(v) showJester = v end })
SepBox:AddToggle("ShowDead", { Text = "Show Dead", Default = false,
    Callback = function(v) showDead = v end })

GunESPBox:AddToggle("GunESPEnabled", { Text = "Gun Drop ESP", Default = false,
    Callback = function(v) gunESPEnabled = v
        if v then for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then WatchSheriffDeath(p) end end
        else ClearAllGunMarkers()
            for p in pairs(sheriffDeathConnections) do StopWatchingSheriffDeath(p) end end end })
GunESPBox:AddButton("Clear Gun Markers", function()
    ClearAllGunMarkers(); Library:Notify("Cleared.", 2) end)
GunESPBox:AddLabel("Pins drop when Sheriff dies.")

ClueBox:AddToggle("ClueESPEnabled", { Text = "Clue ESP", Default = false,
    Callback = function(v) clueESPEnabled = v
        if v then SweepClueESP()
        else for c in pairs(clueESPObjects) do RemoveClueESP(c) end end end })
ClueBox:AddButton("Refresh Clue ESP", function()
    if clueESPEnabled then SweepClueESP(); Library:Notify("Refreshed.", 2) end end)
ClueBox:AddButton("Teleport to Nearest Clue", function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then Library:Notify("No character.", 2) return end
    local nearest, nd = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if IsActiveClue(obj) then
            local d = (obj.Position - root.Position).Magnitude
            if d < nd then nd = d; nearest = obj end
        end
    end
    if nearest then root.CFrame = CFrame.new(nearest.Position + Vector3.new(0,4,0))
        Library:Notify("Teleported.", 2)
    else Library:Notify("No active clues.", 2) end end)

ChamsBox:AddToggle("ChamsESPEnabled", { Text = "Chams ESP", Default = false,
    Callback = function(v) chamsEnabled = v; refreshAllChams() end })
ChamsBox:AddLabel("Chams color"):AddColorPicker("ChamsColorPick", {
    Title = "Chams fill", Default = Color3.fromRGB(200,100,255),
    Callback = function(c) chamsColor = c; refreshChamsColorsOnly() end })

CollectBox:AddToggle("InstantCollect", { Text = "Instant Collect (nearby)", Default = false,
    Callback = function(v) instantCollectEnabled = v end })
CollectBox:AddSlider("InstantCollectRange", { Text = "Collect range", Default = 3, Min = 3, Max = 80, Rounding = 0,
    Callback = function(v) instantCollectRange = v end })
CollectBox:AddLabel("Requires Instant Collect.")
CollectBox:AddToggle("AutoTeleportCollect", {
    Text    = "Auto Teleport & Collect All",
    Default = false,
    Callback = function(v)
        if v then
            RunAutoTeleportCollect()
        else
            if autoTeleportClueActive then
                autoTeleportClueActive = false
                Library:Notify("Auto collect stopped.", 2)
            end
        end
    end
})

VisualBox:AddToggle("FullbrightEnabled", { Text = "Fullbright", Default = false,
    Callback = function(v) fullbrightEnabled = v
        if v then EnableFullbright()
        else DisableFullbright(); if noFogEnabled then EnableNoFog() end end end })
VisualBox:AddLabel("Minimal brightness.")
VisualBox:AddToggle("NoFogEnabled", { Text = "No Fog", Default = false,
    Callback = function(v) noFogEnabled = v; if v then EnableNoFog() else DisableNoFog() end end })
VisualBox:AddLabel("Removes Atmosphere + Lighting fog.")

local FlyBox    = MovementTab:AddLeftGroupbox("Fly")
local WalkBox   = MovementTab:AddRightGroupbox("Walk Speed")
local NoclipBox = MovementTab:AddLeftGroupbox("Noclip")

FlyBox:AddToggle("FlyEnabled", { Text = "Fly (WASD + E/Q)", Default = false,
    Callback = function(v) flyEnabled = v; if v then HandleFly() end end })
FlyBox:AddSlider("FlySpeed", { Text = "Fly speed", Default = 10, Min = 10, Max = 200, Rounding = 0,
    Callback = function(v) flySpeed = v end })
FlyBox:AddLabel("Fly toggle key"):AddKeyPicker("FlyKeybind", {
    Default = "None", SyncToggleState = false, Mode = "Toggle", Text = "Fly Key", NoUI = false,
    Callback = function()
        flyEnabled = not flyEnabled
        pcall(function() Toggles.FlyEnabled:SetValue(flyEnabled) end)
        if flyEnabled then HandleFly() end
    end })

WalkBox:AddToggle("WalkSpeedEnabled", { Text = "Custom Walk Speed", Default = false,
    Callback = function(v) walkSpeedEnabled = v
        if not v then
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 16 end end end })
WalkBox:AddSlider("WalkSpeedValue", { Text = "Speed", Default = 16, Min = 16, Max = 200, Rounding = 0,
    Callback = function(v) customWalkSpeed = v end })
WalkBox:AddLabel("Speed toggle key"):AddKeyPicker("WalkSpeedKeybind", {
    Default = "None", SyncToggleState = false, Mode = "Toggle", Text = "Speed Key", NoUI = false,
    Callback = function()
        walkSpeedEnabled = not walkSpeedEnabled
        pcall(function() Toggles.WalkSpeedEnabled:SetValue(walkSpeedEnabled) end)
        if not walkSpeedEnabled then
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 16 end
        end
    end })

NoclipBox:AddToggle("NoclipEnabled", { Text = "Noclip (phase through walls)", Default = false,
    Callback = function(v)
        noclipEnabled = v
        if v then startNoclip() else stopNoclip() end
    end })
NoclipBox:AddLabel("Noclip toggle key"):AddKeyPicker("NoclipKeybind", {
    Default = "None", SyncToggleState = false, Mode = "Toggle", Text = "Noclip Key", NoUI = false,
    Callback = function()
        noclipEnabled = not noclipEnabled
        pcall(function() Toggles.NoclipEnabled:SetValue(noclipEnabled) end)
        if noclipEnabled then startNoclip() else stopNoclip() end
    end })

local MgmtBox     = ServerTab:AddLeftGroupbox("Management")
local AutoKickBox = ServerTab:AddRightGroupbox("Auto on Kick")
MgmtBox:AddButton("Rejoin", function() Library:Notify("Rejoining...", 2); task.wait(1); Rejoin() end)
MgmtBox:AddButton("Server Hop", function() Library:Notify("Hopping...", 2); task.wait(1); ServerHop() end)
AutoKickBox:AddToggle("AutoRejoinEnabled", { Text = "Auto Rejoin on Kick", Default = false,
    Callback = function(v) autoRejoinEnabled = v end })
AutoKickBox:AddToggle("AutoServerHopEnabled", { Text = "Auto Server Hop on Kick", Default = false,
    Callback = function(v) autoServerHopOnKick = v end })
AutoKickBox:AddLabel("Detects disconnect / kick screen.")

local MenuBox       = SettingsTab:AddLeftGroupbox("Menu")
local CreditsBox    = SettingsTab:AddRightGroupbox("Credits")
local ServerInfoBox = SettingsTab:AddRightGroupbox("Server Info")

MenuBox:AddLabel("Toggle menu"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift", NoUI = true, Text = "Menu key", Mode = "Toggle",
    Callback = function() end })
Library.ToggleKeybind = Options.MenuKeybind

CreditsBox:AddLabel("Script by presleyyyyyyy (@jo2527)")

local jobIdShort = tostring(game.JobId):sub(1, 8) .. "..."
local serverInfoPlayerLabel = ServerInfoBox:AddLabel("Players: "..#Players:GetPlayers().."/"..Players.MaxPlayers)
local serverInfoJobIdLabel  = ServerInfoBox:AddLabel("JobId: "..jobIdShort)
local serverInfoUptimeLabel = ServerInfoBox:AddLabel("Session: 0m 0s")

task.spawn(function()
    while scriptAlive do
        task.wait(1)
        local elapsed = math.floor(tick() - sessionStart)
        local mins = math.floor(elapsed / 60)
        local secs = elapsed % 60
        pcall(function()
            serverInfoPlayerLabel:SetText("Players: "..#Players:GetPlayers().."/"..Players.MaxPlayers)
            serverInfoUptimeLabel:SetText("Session: "..mins.."m "..secs.."s")
        end)
    end
end)

local function fullUnloadCleanup()
    scriptAlive = false; autoTeleportClueActive = false; headPollActive = false
    clueESPEnabled = false; separationESPEnabled = false; gunESPEnabled = false
    instantCollectEnabled = false; flyEnabled = false; walkSpeedEnabled = false
    noclipEnabled = false; killAuraEnabled = false; fullbrightEnabled = false
    noFogEnabled = false; Aimbot.Enabled = false; HeadExpander.Enabled = false; chamsEnabled = false
    DisableFullbright(); DisableNoFog(); teardownChamsHooks(); stopNoclip()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then removeChamsForCharacter(p.Character) end end
    for c in pairs(clueESPObjects) do RemoveClueESP(c) end
    HardClearAllSepESP(); ClearAllGunMarkers()
    for p in pairs(sheriffDeathConnections) do StopWatchingSheriffDeath(p) end
    stopHeadExpander(); restoreAllHeads()
    if walkSpeedConn then walkSpeedConn:Disconnect(); walkSpeedConn = nil end
    aimbotStopRender(); pcall(function() espFolder:Destroy() end)
    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = 16 end
end

MenuBox:AddButton("Unload Script", function() fullUnloadCleanup(); Library:Unload() end)

ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings(); SaveManager:SetFolder(LINORIA_FOLDER)
ThemeManager:SetFolder(LINORIA_FOLDER); SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab); SaveManager:LoadAutoloadConfig()
aimbotStartRender()

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        setupChamsForPlayer(player)
        if HeadExpander.Enabled then hookPlayerForHeadExpander(player) end
    end
    task.spawn(function()
        task.wait(2); if not scriptAlive then return end
        if separationESPEnabled and player ~= LocalPlayer then CreateSeparationESP(player) end
        if gunESPEnabled and player ~= LocalPlayer then WatchSheriffDeath(player) end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveSeparationESP(player); StopWatchingSheriffDeath(player)
    if player.Character then removeChamsForCharacter(player.Character) end
    if chamsPlayerConns[player] then
        pcall(function() chamsPlayerConns[player]:Disconnect() end)
        chamsPlayerConns[player] = nil
    end
    disconnectHeadExpanderConns(player)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then setupChamsForPlayer(plr) end
end

task.spawn(function()
    while scriptAlive do
        task.wait(0.6); if kickActionFired then continue end
        pcall(function()
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if v.Name == "ErrorPrompt" or v.Name == "DisconnectedScreen" then
                    kickActionFired = true; task.wait(1.2)
                    if autoServerHopOnKick then ServerHop()
                    elseif autoRejoinEnabled then Rejoin() end
                end
            end
        end)
    end
end)

task.spawn(function()
    while scriptAlive do
        if clueESPEnabled then
            SweepClueESP()
            UpdateClueESP()
        end
        task.wait(0.25)
    end
end)

Workspace.DescendantAdded:Connect(function(d)
    if not scriptAlive or not clueESPEnabled then return end
    if d:IsA("BasePart") then
        task.wait(0.1)
        if IsActiveClue(d) then CreateClueESP(d) end
    end
    if d:IsA("ProximityPrompt") and d.Name == "UsePrompt" then
        task.wait(0.05)
        local parent = d.Parent
        if parent and parent:IsA("BasePart") and IsActiveClue(parent) then
            CreateClueESP(parent)
        end
    end
end)

task.spawn(function()
    while scriptAlive do
        task.wait(1)
        if fullbrightEnabled then
            Lighting.Brightness = 1; Lighting.ClockTime = 12; Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(180,180,180); Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
        end
        if noFogEnabled then
            Lighting.FogEnd = 100000; Lighting.FogStart = 100000
            local a = Lighting:FindFirstChildOfClass("Atmosphere")
            if a then a.Density = 0; a.Offset = 0; a.Haze = 0; a.Glare = 0 end
        end
    end
end)

task.spawn(function()
    while scriptAlive do
        if instantCollectEnabled then
            local nc = GetActiveCluesInRange(instantCollectRange)
            for _, cd in ipairs(nc) do
                if cd.part and cd.part.Parent and cd.prompt then
                    pcall(function() fireproximityprompt(cd.prompt) end)
                    task.wait(0.1)
                end
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while scriptAlive do
        task.wait(1.5)
        if separationESPEnabled then
            for player, data in pairs(separationESPObjects) do
                if not player or not player.Parent then continue end
                if not data.billboard or not data.billboard.Parent then
                    BuildSepBillboard(player) continue end
                local role = GetRole(player); local color = GetRoleColor(role)
                local visible = ShouldShowRole(role)
                data.billboard.Enabled = visible
                if data.roleLabel and data.roleLabel.Parent then
                    data.roleLabel.Text = GetRoleEmoji(role) end
                if data.frame and data.frame.Parent then
                    data.frame.BackgroundColor3 = color end
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and data.billboard.Adornee ~= root then
                    data.billboard.Adornee = root end
            end
        end
    end
end)

walkSpeedConn = RunService.Heartbeat:Connect(function()
    if scriptAlive and walkSpeedEnabled then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = customWalkSpeed end
    end
end)

task.spawn(function()
    while scriptAlive do
        if killAuraEnabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local tr = p.Character:FindFirstChild("HumanoidRootPart")
                        local th = p.Character:FindFirstChildOfClass("Humanoid")
                        if tr and th and th.Health > 0
                            and (tr.Position - root.Position).Magnitude <= killAuraRange then
                            pcall(function()
                                local t = char:FindFirstChildOfClass("Tool")
                                if t then t:Activate() end
                            end)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if scriptAlive and flyEnabled then task.wait(1); HandleFly() end
end)

Library:Notify("Item Asylum loaded.", 3)
