--[[
    ╔═══════════════════════════════════════╗
    ║       JUGG RIVALS PREMIUM MENU        ║
    ║         Exact UI Profile Match        ║
    ║         File Binding: jugg.lua        ║
    ╚═══════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

--features
local hrp = character:WaitForChild("HumanoidRootPart")
local trip_hrp
local rs = game:GetService("RunService")
local trip_conn_a, trip_conn_b

-- CLEAR COMPONENT: Wipes out previous menus to stop duplicate rendering
local targetGui = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
for _, oldUi in pairs(targetGui:GetChildren()) do
    if oldUi.Name == "JuggProfileGui" or oldUi.Name == "JuggCrosshairGui" then
        oldUi:Destroy()
    end
end

local RegisteredUIComponents = {}

--------------------------------------------------
-- SAVED CONFIGURATIONS (ISOLATED TO JUGGLUA FOLDER)
--------------------------------------------------
local FOLDER_NAME = "jugglua"
local CONFIG_FILE = FOLDER_NAME .. "/jugg_config.json"

local Settings = {
    UIColor = Color3.fromRGB(147, 51, 234), 
    UITransparency = 0,
    AnimationSpeed = 0.2,
    ToggleKey = Enum.KeyCode.RightShift,
    VoidKey = Enum.KeyCode.V,
    AutoExecute = true,
    ShowWatermark = true, 
    ShowGuiOnLoad = true, 
}

local FeatureStates = {
    OrbitAura = false,
    SmoothOrbit = false,
    AntiTrip = false,
    AutoCollect = false,
    AutoRespawn = false,
    AntiMod = false,
    AntiAFK = false,
    FPSBoost = false,

    -- VOID FEATURES
    VoidEnabled = false,
    VoidDistancePercent = 100,
    HeightOffset = 0,
    MotionMode = "None",
    MotionSpeed = 10,
    OrbitRadius = 25,

    -- VISUAL FEATURES
    Crosshair = false,
    HideGameCrosshair = false,
    CrosshairSize = 4,
    CrosshairTextSize = 12,
    CrosshairOpacity = 100,
    CrosshairText = true,
    CrosshairCustomText = "jugg.lua",
    CrosshairTextStyle = "Rainbow",
    CrosshairShape = "Square",
    CrosshairColor = "#9333EA",
    CrosshairOutline = false,
    CrosshairOutlineThickness = 1,
    CrosshairOutlineColor = "#000000",
    CrosshairGap = 0,
    CrosshairThickness = 2,
}

local function saveSettings()
    if makefolder and isfolder and not isfolder(FOLDER_NAME) then
        pcall(function() makefolder(FOLDER_NAME) end)
    end

    local saveData = {
        Settings = {
            UIColor = {Settings.UIColor.R, Settings.UIColor.G, Settings.UIColor.B},
            UITransparency = Settings.UITransparency,
            AnimationSpeed = Settings.AnimationSpeed,
            ToggleKey = Settings.ToggleKey.Name,
            AutoExecute = Settings.AutoExecute,
            ShowWatermark = Settings.ShowWatermark,
            ShowGuiOnLoad = Settings.ShowGuiOnLoad,
        },
        FeatureStates = FeatureStates
    }
    
    if writefile then
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(saveData)) end)
    end
end

local updateUIToggleVisual

local function loadSettings()
    if not isfile or not isfile(CONFIG_FILE) then return end
    if readfile then
        pcall(function()
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if data then
                if data.Settings then
                    if data.Settings.UIColor then Settings.UIColor = Color3.new(data.Settings.UIColor[1], data.Settings.UIColor[2], data.Settings.UIColor[3]) end
                    if data.Settings.UITransparency ~= nil then Settings.UITransparency = data.Settings.UITransparency end
                    if data.Settings.AnimationSpeed ~= nil then Settings.AnimationSpeed = data.Settings.AnimationSpeed end
                    if data.Settings.ToggleKey then Settings.ToggleKey = Enum.KeyCode[data.Settings.ToggleKey] end
                    if data.Settings.AutoExecute ~= nil then Settings.AutoExecute = data.Settings.AutoExecute end
                    if data.Settings.ShowWatermark ~= nil then Settings.ShowWatermark = data.Settings.ShowWatermark end
                    if data.Settings.ShowGuiOnLoad ~= nil then Settings.ShowGuiOnLoad = data.Settings.ShowGuiOnLoad end
                end
                if data.FeatureStates then
                    for key, value in pairs(data.FeatureStates) do FeatureStates[key] = value end
                end
            end
        end)
    end
end

loadSettings()

--------------------------------------------------
-- ANTI-MOD DETECTION ENGINE
--------------------------------------------------
local staffUserIds = {}
local groupId = game.CreatorId
local notify_sound = nil
local CACHE_FILE = "jugglua/modDetect_" .. groupId .. ".json"

if game.CreatorType ~= Enum.CreatorType.Group then
    return
end

task.spawn(function()
    if not isfile("jugglua/modDetect.mp3") then writefile("jugglua/modDetect.mp3", tostring(game:HttpGetAsync("https://github.com/csgofever/api/raw/refs/heads/main/modDetect.mp3"))) end
    notify_sound = Instance.new("Sound", workspace)
    notify_sound.SoundId = getcustomasset("jugglua/modDetect.mp3")
    notify_sound.Volume = 3
    notify_sound.Looped = true
end)

local function fetchURL(url)
    local ok, res = pcall(game.HttpGet, game, url)
    return ok and HttpService:JSONDecode(res) or nil
end

local function extractStaffRoleIds()
    local data = fetchURL(("https://groups.roblox.com/v1/groups/%d/roles"):format(groupId))
    local ids = {}
    if data and data.roles then
        for _, r in ipairs(data.roles) do
            local n = string.lower(r.name)
            if string.find(n, "mod") or string.find(n, "staff") then table.insert(ids, r.id) end
        end
    end
    return ids
end

local function fetchUsersInRole(roleId)
    local collected = {}
    local url = string.format("https://groups.roproxy.com/v1/groups/%d/roles/%d/users?limit=100", groupId, roleId)
    local data = fetchURL(url)
    if data and data.data then
        for _, u in ipairs(data.data) do collected[u.userId] = true end
    end
    return collected
end

local function runDetection()
    task.spawn(function()
        local staffNames, friendStaffNames = {}, {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if staffUserIds[plr.UserId] then table.insert(staffNames, plr.Name) end
            
            task.wait(0.035)
            local ok, pages = pcall(function() return Players:GetFriendsAsync(plr.UserId) end)
            if ok and pages then
                for _, friend in ipairs(pages:GetCurrentPage()) do
                    if staffUserIds[friend.Id] then table.insert(friendStaffNames, friend.Username) end
                end
            end
        end
        print("========================================")
        print("Server Mods: " .. (#staffNames > 0 and table.concat(staffNames, ", ") or "None"))
        print("Friend Mods: " .. (#friendStaffNames > 0 and table.concat(friendStaffNames, ", ") or "None"))
        if #staffNames > 0 or #friendStaffNames > 0 then
            if notify_sound then notify_sound:Play() end
            task.wait(2.6)
            TeleportService:Teleport(17625359962)
        end
        print("-- jugg.lua --")
        print("========================================")
    end)

    if not _G.AntiModConnected then
        _G.AntiModConnected = true
        Players.PlayerAdded:Connect(function(plr)
            if not FeatureStates.AntiMod then return end
            local isMod = false
            
            if staffUserIds[plr.UserId] then
                print("[jugg.lua] ALERT: Server Mod late-joined! ->", plr.Name)
                isMod = true
            end
            
            local ok, pages = pcall(function() return Players:GetFriendsAsync(plr.UserId) end)
            if ok and pages then
                for _, friend in ipairs(pages:GetCurrentPage()) do
                    if staffUserIds[friend.Id] then
                        print("[jugg.lua] ALERT: Friend of Mod late-joined! ->", plr.Name)
                        isMod = true
                    end
                end
            end
            
            if isMod then
                if notify_sound then notify_sound:Play() end
                task.wait(2.6)
                TeleportService:Teleport(17625359962)
            end
        end)
    end
end

for _, roleId in ipairs(extractStaffRoleIds()) do
    for uid, _ in pairs(fetchUsersInRole(roleId)) do staffUserIds[uid] = true end
end

--------------------------------------------------
-- AUTO EXECUTE / TELEPORT INTEGRATION
--------------------------------------------------
local function setupAutoExecute()
    pcall(function()
        if not Settings.AutoExecute then return end
        if queue_on_teleport then
            queue_on_teleport([[
                task.wait(3)
                pcall(function()
                    local GitRequests = loadstring(game:HttpGet('https://raw.githubusercontent.com/csgofever/Roblox-GitRequests/refs/heads/main/GitRequests.lua'))()
                    local Repo = GitRequests.Repo("csgofever", "Modules")
                    loadstring(Repo:getFileContent("mod.lua"))()
                end)
            ]])
        end
        pcall(function()
            if not isfolder("jugglua") then makefolder("jugglua") end
        end)
    end)
end

--------------------------------------------------
-- MOTION UTILITIES & IN-GAME UTILS
--------------------------------------------------
local function createTween(instance, properties, duration)
    local tweenInfo = TweenInfo.new(duration or Settings.AnimationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

local function addSafeBorder(parent, color)
    local success, stroke = pcall(function()
        local s = Instance.new("UIStroke")
        s.Color = color or Color3.fromRGB(35, 35, 42)
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end)
    if not success then
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 1, -1)
        line.BackgroundColor3 = color or Color3.fromRGB(35, 35, 42)
        line.BorderSizePixel = 0
        line.Parent = parent
    end
end

local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

--------------------------------------------------
-- REFACTORED CROSSHAIR SYSTEM
--------------------------------------------------
local crosshairGui = nil
local crosshairUpdateLoop = nil
local gapSliderRow = nil
local thicknessSliderRow = nil

local function parseColor(str)
    if not str then return Settings.UIColor or Color3.fromRGB(147, 51, 234) end
    
    -- Hex format: #RRGGBB or RRGGBB
    local hex = str:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        if r and g and b then
            return Color3.fromRGB(r, g, b)
        end
    end
    
    -- RGB format: R, G, B
    local r, g, b = str:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r and g and b then
        return Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
    end
    
    -- Fallback/Default
    return Settings.UIColor or Color3.fromRGB(147, 51, 234)
end

local function updateCrosshairVisuals()
    if gapSliderRow then
        local shape = FeatureStates.CrosshairShape or "Square"
        gapSliderRow.Visible = (shape == "Classic" or shape == "Horizontal Line")
    end
    if thicknessSliderRow then
        local shape = FeatureStates.CrosshairShape or "Square"
        thicknessSliderRow.Visible = (shape == "Classic" or shape == "X" or shape == "Horizontal Line")
    end
    
    if not crosshairGui then return end
    
    local shapeContainer = crosshairGui:FindFirstChild("ShapeContainer")
    local label = crosshairGui:FindFirstChild("TextLabel", true)
    
    if shapeContainer then
        shapeContainer:ClearAllChildren()
        
        local size = FeatureStates.CrosshairSize
        local opacity = 1 - (FeatureStates.CrosshairOpacity / 100)
        local color = parseColor(FeatureStates.CrosshairColor)
        local shape = FeatureStates.CrosshairShape or "Square"
        local gap = FeatureStates.CrosshairGap or 0
        
        local function applyOutline(instance)
            if FeatureStates.CrosshairOutline then
                local stroke = Instance.new("UIStroke")
                stroke.Thickness = FeatureStates.CrosshairOutlineThickness or 1
                stroke.Color = parseColor(FeatureStates.CrosshairOutlineColor)
                if instance:IsA("TextLabel") then
                    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
                else
                    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                end
                stroke.Parent = instance
            end
        end
        
        if shape == "Square" then
            local f = Instance.new("Frame", shapeContainer)
            f.Size = UDim2.new(0, size, 0, size)
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.new(0.5, 0, 0.5, 0)
            f.BackgroundColor3 = color
            f.BorderSizePixel = 0
            f.BackgroundTransparency = opacity
            applyOutline(f)
        elseif shape == "Circle" then
            local f = Instance.new("Frame", shapeContainer)
            f.Size = UDim2.new(0, size, 0, size)
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.new(0.5, 0, 0.5, 0)
            f.BackgroundColor3 = color
            f.BorderSizePixel = 0
            f.BackgroundTransparency = opacity
            addCorner(f, size)
            applyOutline(f)
        elseif shape == "Classic" then
            local thickness = FeatureStates.CrosshairThickness or 2
            local crossSize = size * 3
            if gap == 0 then
                local v = Instance.new("Frame", shapeContainer)
                v.Size = UDim2.new(0, thickness, 0, crossSize)
                v.AnchorPoint = Vector2.new(0.5, 0.5)
                v.Position = UDim2.new(0.5, 0, 0.5, 0)
                v.BackgroundColor3 = color
                v.BorderSizePixel = 0
                v.BackgroundTransparency = opacity
                applyOutline(v)
                
                local h = Instance.new("Frame", shapeContainer)
                h.Size = UDim2.new(0, crossSize, 0, thickness)
                h.AnchorPoint = Vector2.new(0.5, 0.5)
                h.Position = UDim2.new(0.5, 0, 0.5, 0)
                h.BackgroundColor3 = color
                h.BorderSizePixel = 0
                h.BackgroundTransparency = opacity
                applyOutline(h)
            else
                local length = crossSize / 2
                
                local left = Instance.new("Frame", shapeContainer)
                left.Size = UDim2.new(0, length, 0, thickness)
                left.AnchorPoint = Vector2.new(1, 0.5)
                left.Position = UDim2.new(0.5, -gap, 0.5, 0)
                left.BackgroundColor3 = color
                left.BorderSizePixel = 0
                left.BackgroundTransparency = opacity
                applyOutline(left)
                
                local right = Instance.new("Frame", shapeContainer)
                right.Size = UDim2.new(0, length, 0, thickness)
                right.AnchorPoint = Vector2.new(0, 0.5)
                right.Position = UDim2.new(0.5, gap, 0.5, 0)
                right.BackgroundColor3 = color
                right.BorderSizePixel = 0
                right.BackgroundTransparency = opacity
                applyOutline(right)
                
                local top = Instance.new("Frame", shapeContainer)
                top.Size = UDim2.new(0, thickness, 0, length)
                top.AnchorPoint = Vector2.new(0.5, 1)
                top.Position = UDim2.new(0.5, 0, 0.5, -gap)
                top.BackgroundColor3 = color
                top.BorderSizePixel = 0
                top.BackgroundTransparency = opacity
                applyOutline(top)
                
                local bottom = Instance.new("Frame", shapeContainer)
                bottom.Size = UDim2.new(0, thickness, 0, length)
                bottom.AnchorPoint = Vector2.new(0.5, 0)
                bottom.Position = UDim2.new(0.5, 0, 0.5, gap)
                bottom.BackgroundColor3 = color
                bottom.BorderSizePixel = 0
                bottom.BackgroundTransparency = opacity
                applyOutline(bottom)
            end
        elseif shape == "X" then
            local thickness = FeatureStates.CrosshairThickness or 2
            local crossSize = size * 3
            
            local d1 = Instance.new("Frame", shapeContainer)
            d1.Size = UDim2.new(0, crossSize, 0, thickness)
            d1.AnchorPoint = Vector2.new(0.5, 0.5)
            d1.Position = UDim2.new(0.5, 0, 0.5, 0)
            d1.BackgroundColor3 = color
            d1.BorderSizePixel = 0
            d1.BackgroundTransparency = opacity
            d1.Rotation = 45
            applyOutline(d1)
            
            local d2 = Instance.new("Frame", shapeContainer)
            d2.Size = UDim2.new(0, crossSize, 0, thickness)
            d2.AnchorPoint = Vector2.new(0.5, 0.5)
            d2.Position = UDim2.new(0.5, 0, 0.5, 0)
            d2.BackgroundColor3 = color
            d2.BorderSizePixel = 0
            d2.BackgroundTransparency = opacity
            d2.Rotation = -45
            applyOutline(d2)
        elseif shape == "Horizontal Line" then
            local thickness = FeatureStates.CrosshairThickness or 2
            local lineSize = size * 3
            if gap == 0 then
                local h = Instance.new("Frame", shapeContainer)
                h.Size = UDim2.new(0, lineSize, 0, thickness)
                h.AnchorPoint = Vector2.new(0.5, 0.5)
                h.Position = UDim2.new(0.5, 0, 0.5, 0)
                h.BackgroundColor3 = color
                h.BorderSizePixel = 0
                h.BackgroundTransparency = opacity
                applyOutline(h)
            else
                local length = lineSize / 2
                
                local left = Instance.new("Frame", shapeContainer)
                left.Size = UDim2.new(0, length, 0, thickness)
                left.AnchorPoint = Vector2.new(1, 0.5)
                left.Position = UDim2.new(0.5, -gap, 0.5, 0)
                left.BackgroundColor3 = color
                left.BorderSizePixel = 0
                left.BackgroundTransparency = opacity
                applyOutline(left)
                
                local right = Instance.new("Frame", shapeContainer)
                right.Size = UDim2.new(0, length, 0, thickness)
                right.AnchorPoint = Vector2.new(0, 0.5)
                right.Position = UDim2.new(0.5, gap, 0.5, 0)
                right.BackgroundColor3 = color
                right.BorderSizePixel = 0
                right.BackgroundTransparency = opacity
                applyOutline(right)
            end
        elseif shape == "Triangle" then
            local t = Instance.new("TextLabel", shapeContainer)
            t.BackgroundTransparency = 1
            t.Size = UDim2.new(0, size * 3, 0, size * 3)
            t.AnchorPoint = Vector2.new(0.5, 0.5)
            t.Position = UDim2.new(0.5, 0, 0.5, 0)
            t.Text = "▲"
            t.TextColor3 = color
            t.TextTransparency = opacity
            t.TextSize = math.clamp(size * 3, 8, 100)
            t.Font = Enum.Font.GothamBold
            applyOutline(t)
        elseif shape == "Arrow" then
            local t = Instance.new("TextLabel", shapeContainer)
            t.BackgroundTransparency = 1
            t.Size = UDim2.new(0, size * 3, 0, size * 3)
            t.AnchorPoint = Vector2.new(0.5, 0.5)
            t.Position = UDim2.new(0.5, 0, 0.5, 0)
            t.Text = "↑"
            t.TextColor3 = color
            t.TextTransparency = opacity
            t.TextSize = math.clamp(size * 3, 8, 100)
            t.Font = Enum.Font.GothamBold
            applyOutline(t)
        end
    end
    
    if label then
        label.Visible = FeatureStates.CrosshairText
        label.Text = FeatureStates.CrosshairCustomText
        label.TextSize = FeatureStates.CrosshairTextSize
        
        -- Adjust text label offset based on shape size and gap to prevent overlap
        local shapeSize = FeatureStates.CrosshairSize
        local offset = 8
        local shape = FeatureStates.CrosshairShape or "Square"
        local gap = FeatureStates.CrosshairGap or 0
        if shape == "Classic" or shape == "Horizontal Line" then
            if gap == 0 then
                offset = math.max(8, (shapeSize * 1.5) + 4)
            else
                local length = (shapeSize * 3) / 2
                offset = math.max(8, gap + length + 4)
            end
        elseif shape == "X" then
            offset = math.max(8, (shapeSize * 1.5) + 4)
        elseif shape == "Triangle" or shape == "Arrow" then
            offset = math.max(8, (shapeSize * 1.5) + 4)
        else
            offset = math.max(8, (shapeSize / 2) + 6)
        end
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 0.5, offset) 
        
        -- Handle Style Logic
        local gradient = label:FindFirstChild("UIGradient")
        if FeatureStates.CrosshairTextStyle == "Rainbow" then
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            if gradient then gradient.Enabled = true end
        elseif FeatureStates.CrosshairTextStyle == "UI Color" then
            if gradient then gradient.Enabled = false end
            label.TextColor3 = Settings.UIColor or Color3.fromRGB(147, 51, 234)
        elseif FeatureStates.CrosshairTextStyle == "White" then
            if gradient then gradient.Enabled = false end
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

-- UPDATED: Robust Crosshair Hide Logic
local function toggleHideGameCrosshair(enabled)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Recursive search to find the crosshair UI element regardless of name or path
    local function recursiveFind(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("GuiObject") and string.find(string.lower(child.Name), "crosshair") then
                child.Visible = not enabled
            end
            recursiveFind(child)
        end
    end
    recursiveFind(playerGui)
end

local function toggleCrosshair(enabled)
    FeatureStates.Crosshair = enabled
    if enabled then
        if targetGui:FindFirstChild("JuggCrosshairGui") then targetGui.JuggCrosshairGui:Destroy() end
        
        crosshairGui = Instance.new("ScreenGui")
        crosshairGui.Name = "JuggCrosshairGui"
        crosshairGui.ResetOnSpawn = false
        -- CRITICAL: This ignores the top bar/status bar offset
        crosshairGui.IgnoreGuiInset = true 
        crosshairGui.Parent = targetGui
        
        local shapeContainer = Instance.new("Frame", crosshairGui)
        shapeContainer.Name = "ShapeContainer"
        shapeContainer.BackgroundTransparency = 1
        shapeContainer.BorderSizePixel = 0
        shapeContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        shapeContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
        shapeContainer.Size = UDim2.new(0, 0, 0, 0)
        
        local label = Instance.new("TextLabel", crosshairGui)
        label.Name = "TextLabel"
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = FeatureStates.CrosshairTextSize
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.AutomaticSize = Enum.AutomaticSize.XY
        -- Positioned relative to the dot's center
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 0.5, 8) 
        
        local textGradient = Instance.new("UIGradient", label)
        textGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
        })
        
        updateCrosshairVisuals()
        
        crosshairUpdateLoop = RunService.RenderStepped:Connect(function()
            if FeatureStates.CrosshairTextStyle == "Rainbow" and textGradient.Parent and textGradient.Enabled then
                textGradient.Offset = Vector2.new(-((tick() * 1.3) % 1), 0)
            end
        end)
    else
        if crosshairUpdateLoop then crosshairUpdateLoop:Disconnect() end
        if crosshairGui then crosshairGui:Destroy() end
    end
end

-- Other Feature Modules
local VOID_POS = Vector3.new(0, -500, 0)
local orbitConnection, smoothOrbitConnection, collectConnection, antiAFKConnection

local function getClosestEnemy()
    local closest, shortestDist = nil, math.huge
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local enemyHrp = v.Character:FindFirstChild("HumanoidRootPart")
            local enemyHum = v.Character:FindFirstChild("Humanoid")
            if enemyHrp and enemyHum and enemyHum.Health > 0 then
                local dist = (hrp.Position - enemyHrp.Position).Magnitude
                if dist < shortestDist then shortestDist = dist closest = v.Character end
            end
        end
    end
    return closest
end

local function toggleOrbitAura(enabled)
    FeatureStates.OrbitAura = enabled
    if enabled then
        local orbitAngle = 0
        orbitConnection = RunService.Stepped:Connect(function()
            if character and hrp then
                if hrp.Position.Y > -450 then hrp.CFrame = CFrame.new(VOID_POS) end
                local enemy = getClosestEnemy()
                if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                    orbitAngle = orbitAngle + 2
                    local x = math.cos(math.rad(orbitAngle)) * 10
                    local z = math.sin(math.rad(orbitAngle)) * 10
                    Camera.CFrame = CFrame.new(VOID_POS, enemy.HumanoidRootPart.Position + Vector3.new(x, 5, z))
                end
            end
        end)
    else
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
    end
end

local function toggleSmoothOrbit(enabled)
    FeatureStates.SmoothOrbit = enabled
    if enabled then
        local smoothOrbitAngle = 0
        smoothOrbitConnection = RunService.RenderStepped:Connect(function()
            if not hrp then return end
            smoothOrbitAngle = (smoothOrbitAngle + 4) % 360
            local targetPos = VOID_POS + Vector3.new(math.cos(math.rad(smoothOrbitAngle)) * 4, 5, math.sin(math.rad(smoothOrbitAngle)) * 4)
            hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos), 0.15)
            local enemy = getClosestEnemy()
            if enemy and enemy:FindFirstChild("HumanoidRootPart") then Camera.CFrame = CFrame.new(hrp.Position, enemy.HumanoidRootPart.Position) end
        end)
    else
        if smoothOrbitConnection then smoothOrbitConnection:Disconnect() smoothOrbitConnection = nil end
    end
end

local function gethrp()
    pcall(function()
        local pl = game:GetService("Players").LocalPlayer
        trip_hrp = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
    end)
end

local function det()
    pcall(function()
        if not trip_hrp then return end
        for _, s in ipairs(workspace:GetChildren()) do
            if s.Name == "SubspaceTripmineHitbox" then
                local hb = s:FindFirstChild("Hitbox")
                if hb and trip_hrp and trip_hrp:IsA("BasePart") then
                    firetouchinterest(trip_hrp, hb, 1)
                    firetouchinterest(trip_hrp, hb, 0)
                end
            end
        end
    end)
end

local function startAntiSubspace()
    if not trip_conn_a then
        trip_conn_a = game:GetService("RunService").Heartbeat:Connect(gethrp)
        trip_conn_b = game:GetService("RunService").Heartbeat:Connect(det)
    end
end

local function stopAntiSubspace()
    if trip_conn_a then trip_conn_a:Disconnect(); trip_conn_a = nil end
    if trip_conn_b then trip_conn_b:Disconnect(); trip_conn_b = nil end
end

local function toggleAntiTrip(enabled)
    FeatureStates.AntiTrip = enabled
    if enabled then startAntiSubspace() else stopAntiSubspace() end
end

local function toggleAutoCollect(enabled)
    FeatureStates.AutoCollect = enabled
    if enabled then
        collectConnection = RunService.RenderStepped:Connect(function()
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end
            for _, obj in pairs(workspace:GetChildren()) do
                if obj.Name == "_drop" and obj:IsA("BasePart") then
                    firetouchinterest(character.HumanoidRootPart, obj, 0)
                    firetouchinterest(character.HumanoidRootPart, obj, 1)
                end
            end
        end)
    else
        if collectConnection then collectConnection:Disconnect() collectConnection = nil end
    end
end

local function setupRespawn(char)
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if not FeatureStates.AutoRespawn then return end
        task.wait()
        pcall(function()
            local rem = ReplicatedStorage:FindFirstChild("Remotes")
            if rem then
                local target = rem:FindFirstChild("RespawnNow") or rem:FindFirstChild("Respawn")
                if target then target:FireServer() end
            end
        end)
    end)
end

local function toggleAutoRespawn(enabled)
    FeatureStates.AutoRespawn = enabled
    if enabled and character then setupRespawn(character) end
end

local function toggleAntiMod(enabled)
    if enabled then runDetection() end
end

local function toggleAntiAFK(enabled)
    FeatureStates.AntiAFK = enabled
    if enabled then
        local vu = game:GetService("VirtualUser")
        antiAFKConnection = LocalPlayer.Idled:Connect(function() vu:Button2Down(Vector2.new(0,0), Camera.CFrame) task.wait(0.5) vu:Button2Up(Vector2.new(0,0), Camera.CFrame) end)
    else
        if antiAFKConnection then antiAFKConnection:Disconnect() antiAFKConnection = nil end
    end
end

local function toggleFPSBoost(enabled)
    FeatureStates.FPSBoost = enabled
    if enabled then
        Lighting.GlobalShadows = false
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("Part") or v:IsA("MeshPart") then v.Material = Enum.Material.Plastic elseif v:IsA("Decal") then v.Transparency = 1 end
        end
    end
end

--------------------------------------------------
-- VOID TELEPORT SYSTEM
--------------------------------------------------
local OriginalCFrame
local isReturning = false
local returnStartTime = 0
local returnDuration = 0.5
local TeleportCount = 0
local spinAngle = 0
local voidConnection

local function getVoidPosition()
    local yOffset = (FeatureStates.VoidDistancePercent * 25000) + FeatureStates.HeightOffset
    if FeatureStates.MotionMode == "Random" then
        local x = math.random(-FeatureStates.OrbitRadius, FeatureStates.OrbitRadius)
        local z = math.random(-FeatureStates.OrbitRadius, FeatureStates.OrbitRadius)
        return Vector3.new(x, yOffset, z)
    end
    return Vector3.new(0, yOffset, 0)
end

local function applyVoidMotion(deltaTime)
    if not FeatureStates.VoidEnabled then return end
    if not hrp then return end

    spinAngle = spinAngle + (FeatureStates.MotionSpeed * deltaTime)
    local yOffset = (FeatureStates.VoidDistancePercent * 25000) + FeatureStates.HeightOffset

    if FeatureStates.MotionMode == "Spin" then
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, spinAngle, 0)
    elseif FeatureStates.MotionMode == "Orbit" then
        local angle = spinAngle * 1.5
        local x = math.cos(angle) * FeatureStates.OrbitRadius
        local z = math.sin(angle) * FeatureStates.OrbitRadius
        hrp.CFrame = CFrame.new(Vector3.new(x, yOffset, z))
    elseif FeatureStates.MotionMode == "Desync" then
        local desyncX = math.sin(spinAngle * 50) * 10
        local desyncZ = math.cos(spinAngle * 50) * 10
        hrp.CFrame = CFrame.new(Vector3.new(desyncX, yOffset, desyncZ)) * CFrame.Angles(math.sin(spinAngle) * 0.5, math.cos(spinAngle) * 0.5, 0)
    end
end

local function toggleVoidHide(enabled)
    FeatureStates.VoidEnabled = enabled
    if enabled then
        if hrp then OriginalCFrame = hrp.CFrame end
        TeleportCount = TeleportCount + 1
        
        if not voidConnection then
            voidConnection = RunService.Heartbeat:Connect(function(dt)
                if not hrp then return end
                if FeatureStates.MotionMode == "None" then
                    hrp.CFrame = CFrame.new(getVoidPosition())
                else
                    applyVoidMotion(dt)
                end
            end)
        end
    else
        isReturning = true
        returnStartTime = tick()
        if voidConnection then voidConnection:Disconnect(); voidConnection = nil end

        task.spawn(function()
            while isReturning and OriginalCFrame and hrp do
                local elapsed = tick() - returnStartTime
                if elapsed < returnDuration then
                    local alpha = elapsed / returnDuration
                    local newPos = OriginalCFrame.Position:Lerp(hrp.Position, alpha)
                    hrp.CFrame = CFrame.new(newPos)
                else
                    hrp.CFrame = OriginalCFrame
                    isReturning = false
                end
                RunService.Heartbeat:Wait()
            end
        end)
    end
end

--------------------------------------------------
-- MAIN MENU GENERATION
--------------------------------------------------
local function InitializeMainMenu()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "JuggProfileGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 2136372536
    ScreenGui.Parent = targetGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -160)
    MainFrame.BackgroundColor3 = Color3.fromRGB(9, 9, 11)
    MainFrame.BackgroundTransparency = Settings.UITransparency
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = Settings.ShowGuiOnLoad
    MainFrame.Parent = ScreenGui
    addCorner(MainFrame, 8)
    addSafeBorder(MainFrame, Color3.fromRGB(28, 28, 35))

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 130, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(7, 7, 9)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    addCorner(Sidebar, 8)

    local SidebarDivider = Instance.new("Frame")
    SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
    SidebarDivider.Position = UDim2.new(1, -1, 0, 0)
    SidebarDivider.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    SidebarDivider.BorderSizePixel = 0
    SidebarDivider.Parent = Sidebar

    local DragHandle = Instance.new("Frame")
    DragHandle.Name = "DragHandle"
    DragHandle.Size = UDim2.new(1, 0, 0, 45)
    DragHandle.BackgroundTransparency = 1
    DragHandle.Parent = Sidebar

    local LogoLabel = Instance.new("TextLabel")
    LogoLabel.Size = UDim2.new(1, 0, 1, 0)
    LogoLabel.Position = UDim2.new(0, 14, 0, 0)
    LogoLabel.BackgroundTransparency = 1
    LogoLabel.Text = "jugg.lua"
    LogoLabel.TextColor3 = Settings.UIColor
    LogoLabel.Font = Enum.Font.GothamBold
    LogoLabel.TextSize = 14
    LogoLabel.TextXAlignment = Enum.TextXAlignment.Left
    LogoLabel.Parent = DragHandle

    makeDraggable(MainFrame, MainFrame)
    makeDraggable(MainFrame, DragHandle)

    local NavigationList = Instance.new("Frame")
    NavigationList.Size = UDim2.new(1, -16, 1, -60)
    NavigationList.Position = UDim2.new(0, 8, 0, 50)
    NavigationList.BackgroundTransparency = 1
    NavigationList.Parent = Sidebar

    local NavLayout = Instance.new("UIListLayout")
    NavLayout.Padding = UDim.new(0, 5)
    NavLayout.Parent = NavigationList

    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, -145, 1, -20)
    ContentArea.Position = UDim2.new(0, 140, 0, 10)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = MainFrame

    updateUIToggleVisual = function(configKey, isSettingTable)
        local component = RegisteredUIComponents[configKey]
        if not component then return end
        
        local isActive = isSettingTable and Settings[configKey] or FeatureStates[configKey]
        local pin = component:FindFirstChild("Pin", true)
        local track = component:FindFirstChild("Track", true)
        
        if pin and track then
            if isActive then
                createTween(pin, {Position = UDim2.new(1, -15, 0.5, -5)}, 0.12)
                createTween(track, {BackgroundColor3 = Settings.UIColor}, 0.12)
            else
                createTween(pin, {Position = UDim2.new(0, 3, 0.5, -5)}, 0.12)
                createTween(track, {BackgroundColor3 = Color3.fromRGB(34, 34, 38)}, 0.12)
            end
        end
    end

    local tabs = {}
    local function createTab(name)
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(1, 0, 0, 32)
        TabButton.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        TabButton.BackgroundTransparency = 1
        TabButton.Text = name
        TabButton.TextColor3 = Color3.fromRGB(130, 130, 135)
        TabButton.Font = Enum.Font.GothamMedium
        TabButton.TextSize = 12
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.Parent = NavigationList
        addCorner(TabButton, 5)
        
        local Pad = Instance.new("UIPadding")
        Pad.PaddingLeft = UDim.new(0, 12)
        Pad.Parent = TabButton

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.Visible = false
        TabPage.ScrollBarThickness = 0
        TabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
        TabPage.Parent = ContentArea
        
        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Padding = UDim.new(0, 6)
        PageLayout.Parent = TabPage
        
        TabButton.MouseButton1Click:Connect(function()
            for _, t in pairs(tabs) do
                t.Page.Visible = false
                createTween(t.Btn, {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(130, 130, 135)}, 0.12)
            end
            TabPage.Visible = true
            createTween(TabButton, {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.12)
        end)
        
        tabs[name] = {Btn = TabButton, Page = TabPage}
        return TabPage
    end

    local function createToggleRow(parent, label, configKey, isSettingTable, callback)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.BorderSizePixel = 0
        Row.Parent = parent
        addCorner(Row, 5)
        addSafeBorder(Row, Color3.fromRGB(22, 22, 26))

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -60, 1, 0)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row
        
        local ClickZone = Instance.new("TextButton")
        ClickZone.Size = UDim2.new(0, 32, 0, 16)
        ClickZone.Position = UDim2.new(1, -44, 0.5, -8)
        ClickZone.BackgroundTransparency = 1
        ClickZone.Text = ""
        ClickZone.Parent = Row
        
        local Track = Instance.new("Frame")
        Track.Name = "Track"
        Track.Size = UDim2.new(1, 0, 1, 0)
        Track.BackgroundColor3 = Color3.fromRGB(34, 34, 38)
        Track.BorderSizePixel = 0
        Track.Parent = ClickZone
        addCorner(Track, 8)
        
        local Pin = Instance.new("Frame")
        Pin.Name = "Pin"
        Pin.Size = UDim2.new(0, 10, 0, 10)
        Pin.Position = UDim2.new(0, 3, 0.5, -5)
        Pin.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Pin.BorderSizePixel = 0
        Pin.Parent = ClickZone
        addCorner(Pin, 5)
        
        RegisteredUIComponents[configKey] = Row
        
        ClickZone.MouseButton1Click:Connect(function()
            local cur = isSettingTable and Settings[configKey] or FeatureStates[configKey]
            local newVal = not cur
            if isSettingTable then Settings[configKey] = newVal else FeatureStates[configKey] = newVal end
            updateUIToggleVisual(configKey, isSettingTable)
            callback(newVal)
        end)
    end

    local function createSliderRow(parent, label, configKey, min, max, default, suffix, callback)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 50)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.BorderSizePixel = 0
        Row.Parent = parent
        
        local corner1 = Instance.new("UICorner")
        corner1.CornerRadius = UDim.new(0, 5)
        corner1.Parent = Row
        
        local stroke1 = Instance.new("UIStroke")
        stroke1.Color = Color3.fromRGB(22, 22, 26)
        stroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke1.Parent = Row

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -60, 0, 25)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row

        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0, 50, 0, 25)
        ValueLabel.Position = UDim2.new(1, -62, 0, 0)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(default) .. (suffix or "")
        ValueLabel.TextColor3 = Settings.UIColor
        ValueLabel.Font = Enum.Font.GothamBold
        ValueLabel.TextSize = 11
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        ValueLabel.Parent = Row

        local SliderBg = Instance.new("TextButton")
        SliderBg.Size = UDim2.new(1, -24, 0, 4)
        SliderBg.Position = UDim2.new(0, 12, 0, 32)
        SliderBg.BackgroundColor3 = Color3.fromRGB(34, 34, 38)
        SliderBg.Text = ""
        SliderBg.AutoButtonColor = false
        SliderBg.Parent = Row
        
        local corner2 = Instance.new("UICorner")
        corner2.CornerRadius = UDim.new(0, 4)
        corner2.Parent = SliderBg

        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0)
        SliderFill.BackgroundColor3 = Settings.UIColor
        SliderFill.Parent = SliderBg
        
        local corner3 = Instance.new("UICorner")
        corner3.CornerRadius = UDim.new(0, 4)
        corner3.Parent = SliderFill

        local dragging = false
        local function update(input)
            local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
            SliderFill.Size = UDim2.new(pos, 0, 1, 0)
            local val = math.floor(min + ((max - min) * pos))
            FeatureStates[configKey] = val
            ValueLabel.Text = tostring(val) .. (suffix or "")
            if callback then callback(val) end
        end

        SliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then 
                dragging = true 
                update(input) 
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
        end)
        return Row
    end

    local function createCycleRow(parent, label, configKey, options, default, callback)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.Parent = parent
        addCorner(Row, 5)
        addSafeBorder(Row, Color3.fromRGB(22, 22, 26))

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -110, 1, 0)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row

        local ActionBtn = Instance.new("TextButton")
        ActionBtn.Size = UDim2.new(0, 90, 0, 24)
        ActionBtn.Position = UDim2.new(1, -102, 0.5, -12)
        ActionBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        ActionBtn.Text = default
        ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ActionBtn.Font = Enum.Font.GothamBold
        ActionBtn.TextSize = 10
        ActionBtn.Parent = Row
        addCorner(ActionBtn, 4)
        addSafeBorder(ActionBtn, Settings.UIColor)

        local currentIndex = table.find(options, default) or 1
        ActionBtn.MouseButton1Click:Connect(function()
            currentIndex = (currentIndex % #options) + 1
            ActionBtn.Text = options[currentIndex]
            FeatureStates[configKey] = options[currentIndex]
            callback(options[currentIndex])
        end)
    end

    local function createInputRow(parent, label, configKey, default, callback)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.Parent = parent
        addCorner(Row, 5)
        addSafeBorder(Row, Color3.fromRGB(22, 22, 26))

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -130, 1, 0)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row

        local TextBox = Instance.new("TextBox")
        TextBox.Size = UDim2.new(0, 110, 0, 24)
        TextBox.Position = UDim2.new(1, -122, 0.5, -12)
        TextBox.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        TextBox.Text = default
        TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextBox.Font = Enum.Font.Gotham
        TextBox.TextSize = 11
        TextBox.ClearTextOnFocus = false
        TextBox.Parent = Row
        addCorner(TextBox, 4)
        addSafeBorder(TextBox, Color3.fromRGB(35, 35, 45))

        TextBox.FocusLost:Connect(function()
            local text = TextBox.Text
            FeatureStates[configKey] = text
            if callback then callback(text) end
        end)
    end

    local function createColorPickerRow(parent, label, configKey, callback)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.ClipsDescendants = true
        Row.Parent = parent
        addCorner(Row, 5)
        addSafeBorder(Row, Color3.fromRGB(22, 22, 26))

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -60, 0, 40)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row

        local ColorPreviewBtn = Instance.new("TextButton")
        ColorPreviewBtn.Size = UDim2.new(0, 20, 0, 20)
        ColorPreviewBtn.Position = UDim2.new(1, -32, 0, 10)
        ColorPreviewBtn.Text = ""
        ColorPreviewBtn.Parent = Row
        addCorner(ColorPreviewBtn, 4)
        addSafeBorder(ColorPreviewBtn, Color3.fromRGB(45, 45, 55))

        local ExpandedPanel = Instance.new("Frame")
        ExpandedPanel.Size = UDim2.new(1, 0, 0, 125)
        ExpandedPanel.Position = UDim2.new(0, 0, 0, 40)
        ExpandedPanel.BackgroundTransparency = 1
        ExpandedPanel.BorderSizePixel = 0
        ExpandedPanel.ClipsDescendants = true
        ExpandedPanel.Parent = Row

        local PreviewBox = Instance.new("Frame", ExpandedPanel)
        PreviewBox.Size = UDim2.new(0, 40, 0, 100)
        PreviewBox.Position = UDim2.new(0, 12, 0, 10)
        PreviewBox.BorderSizePixel = 0
        addCorner(PreviewBox, 4)
        addSafeBorder(PreviewBox, Color3.fromRGB(35, 35, 45))

        local SVFrame = Instance.new("TextButton", ExpandedPanel)
        SVFrame.Size = UDim2.new(1, -210, 0, 100)
        SVFrame.Position = UDim2.new(0, 64, 0, 10)
        SVFrame.BorderSizePixel = 0
        SVFrame.Text = ""
        SVFrame.AutoButtonColor = false
        addCorner(SVFrame, 4)

        local WhiteGradientFrame = Instance.new("Frame", SVFrame)
        WhiteGradientFrame.Size = UDim2.new(1, 0, 1, 0)
        WhiteGradientFrame.BackgroundTransparency = 0
        WhiteGradientFrame.BorderSizePixel = 0
        addCorner(WhiteGradientFrame, 4)
        local wg = Instance.new("UIGradient", WhiteGradientFrame)
        wg.Color = ColorSequence.new(Color3.new(1, 1, 1))
        wg.Transparency = NumberSequence.new(0, 1)

        local BlackGradientFrame = Instance.new("Frame", SVFrame)
        BlackGradientFrame.Size = UDim2.new(1, 0, 1, 0)
        BlackGradientFrame.BackgroundTransparency = 0
        BlackGradientFrame.BorderSizePixel = 0
        addCorner(BlackGradientFrame, 4)
        local bg = Instance.new("UIGradient", BlackGradientFrame)
        bg.Color = ColorSequence.new(Color3.new(0, 0, 0))
        bg.Transparency = NumberSequence.new(1, 0)
        bg.Rotation = 90

        local SVCursor = Instance.new("Frame", SVFrame)
        SVCursor.Size = UDim2.new(0, 8, 0, 8)
        SVCursor.BackgroundTransparency = 1
        SVCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        local svStroke = Instance.new("UIStroke", SVCursor)
        svStroke.Color = Color3.new(1, 1, 1)
        svStroke.Thickness = 1.5
        addCorner(SVCursor, 4)

        local HueSlider = Instance.new("TextButton", ExpandedPanel)
        HueSlider.Size = UDim2.new(0, 12, 0, 100)
        HueSlider.Position = UDim2.new(1, -132, 0, 10)
        HueSlider.BorderSizePixel = 0
        HueSlider.Text = ""
        HueSlider.AutoButtonColor = false
        addCorner(HueSlider, 4)

        local hg = Instance.new("UIGradient", HueSlider)
        hg.Rotation = 90
        hg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
        })

        local HueCursor = Instance.new("Frame", HueSlider)
        HueCursor.Size = UDim2.new(1, 4, 0, 4)
        HueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        HueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
        addCorner(HueCursor, 2)
        addSafeBorder(HueCursor, Color3.new(0, 0, 0))

        local ColorCodeLabel = Instance.new("TextLabel", ExpandedPanel)
        ColorCodeLabel.Size = UDim2.new(0, 100, 0, 20)
        ColorCodeLabel.Position = UDim2.new(1, -112, 0, 90)
        ColorCodeLabel.BackgroundTransparency = 1
        ColorCodeLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
        ColorCodeLabel.Font = Enum.Font.GothamMedium
        ColorCodeLabel.TextSize = 10
        ColorCodeLabel.TextXAlignment = Enum.TextXAlignment.Center

        local isExpanded = false
        ColorPreviewBtn.MouseButton1Click:Connect(function()
            isExpanded = not isExpanded
            createTween(Row, {Size = isExpanded and UDim2.new(1, -5, 0, 165) or UDim2.new(1, -5, 0, 40)}, 0.15)
        end)

        -- Initialize currentColor
        local currentColor = parseColor(FeatureStates[configKey])
        local h, s, v = Color3.toHSV(currentColor)

        local function updateDisplay()
            local selectedColor = Color3.fromHSV(h, s, v)
            PreviewBox.BackgroundColor3 = selectedColor
            ColorPreviewBtn.BackgroundColor3 = selectedColor
            ColorCodeLabel.Text = "#" .. selectedColor:ToHex():upper()
            SVFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            SVCursor.Position = UDim2.new(s, 0, 1 - v, 0)
            HueCursor.Position = UDim2.new(0.5, 0, h, 0)
        end
        updateDisplay()

        local isDraggingSV = false
        local function updateSV(input)
            local relativeX = math.clamp((input.Position.X - SVFrame.AbsolutePosition.X) / SVFrame.AbsoluteSize.X, 0, 1)
            local relativeY = math.clamp((input.Position.Y - SVFrame.AbsolutePosition.Y) / SVFrame.AbsoluteSize.Y, 0, 1)
            s = relativeX
            v = 1 - relativeY
            updateDisplay()
            local selectedColor = Color3.fromHSV(h, s, v)
            FeatureStates[configKey] = "#" .. selectedColor:ToHex():upper()
            if callback then callback(FeatureStates[configKey]) end
        end

        local isDraggingHue = false
        local function updateHue(input)
            local relativeY = math.clamp((input.Position.Y - HueSlider.AbsolutePosition.Y) / HueSlider.AbsoluteSize.Y, 0, 1)
            h = relativeY
            updateDisplay()
            local selectedColor = Color3.fromHSV(h, s, v)
            FeatureStates[configKey] = "#" .. selectedColor:ToHex():upper()
            if callback then callback(FeatureStates[configKey]) end
        end

        SVFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDraggingSV = true
                updateSV(input)
            end
        end)

        HueSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDraggingHue = true
                updateHue(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDraggingSV = false
                isDraggingHue = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if isDraggingSV then
                    updateSV(input)
                elseif isDraggingHue then
                    updateHue(input)
                end
            end
        end)
    end

    local function createActionButton(parent, label, callback)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.BorderSizePixel = 0
        Row.Parent = parent
        addCorner(Row, 5)
        addSafeBorder(Row, Color3.fromRGB(22, 22, 26))

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -110, 1, 0)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row

        local ActionBtn = Instance.new("TextButton")
        ActionBtn.Size = UDim2.new(0, 90, 0, 24)
        ActionBtn.Position = UDim2.new(1, -102, 0.5, -12)
        ActionBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        ActionBtn.Text = "Save Config"
        ActionBtn.TextColor3 = Settings.UIColor
        ActionBtn.Font = Enum.Font.GothamBold
        ActionBtn.TextSize = 10
        ActionBtn.Parent = Row
        addCorner(ActionBtn, 4)
        addSafeBorder(ActionBtn, Color3.fromRGB(35, 35, 45))

        ActionBtn.MouseButton1Click:Connect(function()
            createTween(ActionBtn, {BackgroundColor3 = Settings.UIColor}, 0.08)
            ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            callback()
            task.wait(0.1)
            createTween(ActionBtn, {BackgroundColor3 = Color3.fromRGB(24, 24, 30)}, 0.12)
            ActionBtn.TextColor3 = Settings.UIColor
        end)
    end

    local function createKeybindSelector(parent, label, configKey)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
        Row.Parent = parent
        addCorner(Row, 5)
        addSafeBorder(Row, Color3.fromRGB(22, 22, 26))

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -100, 1, 0)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = label
        TextLabel.TextColor3 = Color3.fromRGB(210, 210, 215)
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextSize = 11
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.Parent = Row
        
        local BindBtn = Instance.new("TextButton")
        BindBtn.Size = UDim2.new(0, 80, 0, 22)
        BindBtn.Position = UDim2.new(1, -92, 0.5, -11)
        BindBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        BindBtn.Text = Settings[configKey].Name
        BindBtn.TextColor3 = Settings.UIColor
        BindBtn.Font = Enum.Font.GothamBold
        BindBtn.TextSize = 10
        BindBtn.Parent = Row
        addCorner(BindBtn, 4)
        addSafeBorder(BindBtn, Color3.fromRGB(35, 35, 45))
        
        local listening = false
        BindBtn.MouseButton1Click:Connect(function()
            listening = true
            BindBtn.Text = "..."
        end)
        
        UserInputService.InputBegan:Connect(function(input)
            if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    BindBtn.Text = Settings[configKey].Name
                    listening = false
                else
                    Settings[configKey] = input.KeyCode
                    BindBtn.Text = input.KeyCode.Name
                    listening = false
                end
            end
        end)
    end

    local OrbitPage = createTab("Orbit")
    local VoidPage = createTab("Void")
    local VisualsPage = createTab("Visuals")
    local MiscPage = createTab("Misc")
    local SettingsPage = createTab("Settings")

    tabs["Orbit"].Page.Visible = true
    tabs["Orbit"].Btn.BackgroundTransparency = 0
    tabs["Orbit"].Btn.TextColor3 = Color3.fromRGB(255, 255, 255)

    createToggleRow(OrbitPage, "Orbit Kill Aura", "OrbitAura", false, toggleOrbitAura)
    createToggleRow(OrbitPage, "Smooth Orbit", "SmoothOrbit", false, toggleSmoothOrbit)
    
    createToggleRow(VoidPage, "Enable Void Hide", "VoidEnabled", false, toggleVoidHide)
    createKeybindSelector(VoidPage, "Void Toggle Keybind", "VoidKey")
    
    createSliderRow(VoidPage, "Void Distance", "VoidDistancePercent", 1, 100, FeatureStates.VoidDistancePercent, "%", function(v) end)
    createSliderRow(VoidPage, "Height Offset", "HeightOffset", -1000, 1000, FeatureStates.HeightOffset, "st", function(v) end)
    
    createCycleRow(VoidPage, "Movement Pattern", "MotionMode", {"None", "Spin", "Orbit", "Random", "Desync"}, FeatureStates.MotionMode, function(v) end)
    createSliderRow(VoidPage, "Movement Speed", "MotionSpeed", 0, 100, FeatureStates.MotionSpeed, "", function(v) end)
    createSliderRow(VoidPage, "Effect Radius", "OrbitRadius", 1, 200, FeatureStates.OrbitRadius, "", function(v) end)
    
    -- Visuals Section Integration
    createToggleRow(VisualsPage, "Hide Game Crosshair", "HideGameCrosshair", false, toggleHideGameCrosshair)
    createToggleRow(VisualsPage, "Custom Crosshair", "Crosshair", false, toggleCrosshair)
    createCycleRow(VisualsPage, "Crosshair Shape", "CrosshairShape", {"Square", "Circle", "Classic", "X", "Triangle", "Arrow", "Horizontal Line"}, FeatureStates.CrosshairShape, updateCrosshairVisuals)
    createSliderRow(VisualsPage, "Crosshair Size", "CrosshairSize", 2, 20, FeatureStates.CrosshairSize, "px", updateCrosshairVisuals)
    gapSliderRow = createSliderRow(VisualsPage, "Crosshair Gap", "CrosshairGap", 0, 30, FeatureStates.CrosshairGap, "px", updateCrosshairVisuals)
    thicknessSliderRow = createSliderRow(VisualsPage, "Crosshair Thickness", "CrosshairThickness", 1, 10, FeatureStates.CrosshairThickness, "px", updateCrosshairVisuals)
    createSliderRow(VisualsPage, "Crosshair Opacity", "CrosshairOpacity", 0, 100, FeatureStates.CrosshairOpacity, "%", updateCrosshairVisuals)
    createColorPickerRow(VisualsPage, "Crosshair Color", "CrosshairColor", updateCrosshairVisuals)
    createToggleRow(VisualsPage, "Crosshair Outline", "CrosshairOutline", false, updateCrosshairVisuals)
    createSliderRow(VisualsPage, "Outline Thickness", "CrosshairOutlineThickness", 1, 5, FeatureStates.CrosshairOutlineThickness, "px", updateCrosshairVisuals)
    createColorPickerRow(VisualsPage, "Outline Color", "CrosshairOutlineColor", updateCrosshairVisuals)

    createToggleRow(VisualsPage, "Show Crosshair Text", "CrosshairText", false, updateCrosshairVisuals)
    createInputRow(VisualsPage, "Custom Text", "CrosshairCustomText", FeatureStates.CrosshairCustomText, updateCrosshairVisuals)
    createSliderRow(VisualsPage, "Text Size", "CrosshairTextSize", 8, 24, 12, "pt", updateCrosshairVisuals)
    createCycleRow(VisualsPage, "Text Style", "CrosshairTextStyle", {"Rainbow", "UI Color", "White"}, FeatureStates.CrosshairTextStyle, updateCrosshairVisuals)
    
    updateCrosshairVisuals()

    createToggleRow(MiscPage, "Anti Subspace Tripmine", "AntiTrip", false, toggleAntiTrip)
    createToggleRow(MiscPage, "Auto Collect Drops", "AutoCollect", false, toggleAutoCollect)
    createToggleRow(MiscPage, "Auto Respawn", "AutoRespawn", false, toggleAutoRespawn)

    createToggleRow(MiscPage, "Anti-Mod", "AntiMod", false, toggleAntiMod)
    createToggleRow(MiscPage, "Anti-AFK", "AntiAFK", false, toggleAntiAFK)
    createToggleRow(MiscPage, "FPS Boost", "FPSBoost", false, toggleFPSBoost)

    createToggleRow(SettingsPage, "Auto Execute", "AutoExecute", true, function(state) end)
    createToggleRow(SettingsPage, "Show Intro Watermark", "ShowWatermark", true, function(state) end)
    createToggleRow(SettingsPage, "Show GUI on Startup", "ShowGuiOnLoad", true, function(state) end)

    createKeybindSelector(SettingsPage, "Menu Keybind", "ToggleKey")

    createActionButton(SettingsPage, "Save Current Settings Parameters", function()
        saveSettings()
    end)

    for key, _ in pairs(RegisteredUIComponents) do
        local isSetting = (key == "AutoExecute" or key == "ShowWatermark" or key == "ShowGuiOnLoad")
        updateUIToggleVisual(key, isSetting)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Settings.ToggleKey then
                MainFrame.Visible = not MainFrame.Visible
            elseif input.KeyCode == Settings.VoidKey then
                local newState = not FeatureStates.VoidEnabled
                toggleVoidHide(newState)
                updateUIToggleVisual("VoidEnabled", false)
            end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        character = char 
        hrp = char:WaitForChild("HumanoidRootPart")
        if FeatureStates.OrbitAura then toggleOrbitAura(false) task.wait(0.1) toggleOrbitAura(true) end
        if FeatureStates.SmoothOrbit then toggleSmoothOrbit(false) task.wait(0.1) toggleSmoothOrbit(true) end
        if FeatureStates.AutoRespawn then setupRespawn(char) end
    end)
end

--------------------------------------------------
-- INITIALIZATION THREAD EXECUTOR (INSTANT RUN)
--------------------------------------------------
local function initializeCoreThreads()
    if Settings.AutoExecute then setupAutoExecute() end
    if FeatureStates.OrbitAura then toggleOrbitAura(true) end
    if FeatureStates.SmoothOrbit then toggleSmoothOrbit(true) end
    if FeatureStates.AntiTrip then toggleAntiTrip(true) end       
    if FeatureStates.AutoCollect then toggleAutoCollect(true) end 
    if FeatureStates.AutoRespawn then toggleAutoRespawn(true) end
    if FeatureStates.AntiMod then toggleAntiMod(true) end
    if FeatureStates.AntiAFK then toggleAntiAFK(true) end
    if FeatureStates.FPSBoost then toggleFPSBoost(true) end
    
    -- Silent initialization of Visual threads
    if FeatureStates.Crosshair then toggleCrosshair(true) end
end

--------------------------------------------------
-- INITIALIZATION SEQUENCE 
--------------------------------------------------
initializeCoreThreads() 

task.spawn(function()
    if Settings.ShowWatermark then
        task.wait(5)

        local overlayGui = gethui() or game:GetService("CoreGui")
        local watermarkGui = Instance.new("ScreenGui")
        watermarkGui.Name = "JuggWatermark"
        watermarkGui.DisplayOrder = 2147483647
        watermarkGui.Parent = overlayGui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 750, 0, 260) 
        container.Position = UDim2.new(0.5, 0, 0.5, -25)
        container.AnchorPoint = Vector2.new(0.5, 0.5)
        container.BackgroundTransparency = 1
        container.Parent = watermarkGui

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 0, 190) 
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "<i>jugg</i>"
        textLabel.RichText = true
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.ArialBold
        textLabel.TextTransparency = 1
        textLabel.Parent = container

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(15, 15, 20)
        stroke.Thickness = 14
        stroke.Transparency = 1
        stroke.Parent = textLabel

        local subtitleLabel = Instance.new("TextLabel")
        subtitleLabel.Size = UDim2.new(1, 0, 0, 35)
        subtitleLabel.Position = UDim2.new(0, 0, 0, 195) 
        subtitleLabel.BackgroundTransparency = 1
        subtitleLabel.Text = "<i>the best lua</i>"
        subtitleLabel.RichText = true 
        subtitleLabel.TextColor3 = Color3.fromRGB(140, 20, 255)
        subtitleLabel.TextSize = 24
        subtitleLabel.Font = Enum.Font.GothamBold
        subtitleLabel.TextTransparency = 1
        subtitleLabel.Parent = container

        local subtitleStroke = Instance.new("UIStroke")
        subtitleStroke.Color = Color3.fromRGB(10, 10, 10)
        subtitleStroke.Thickness = 3
        subtitleStroke.Transparency = 1
        subtitleStroke.Parent = subtitleLabel

        local uiGradient = Instance.new("UIGradient")
        uiGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 50)),
            ColorSequenceKeypoint.new(0.2,  Color3.fromRGB(255, 140, 0)),
            ColorSequenceKeypoint.new(0.4,  Color3.fromRGB(0, 255, 100)),
            ColorSequenceKeypoint.new(0.6,  Color3.fromRGB(0, 220, 255)),
            ColorSequenceKeypoint.new(0.8,  Color3.fromRGB(150, 0, 255)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 50))
        })
        uiGradient.Parent = textLabel

        local waveSpeed = 1.3
        local animationLoop = RunService.RenderStepped:Connect(function()
            local offset = (tick() * waveSpeed) % 1
            uiGradient.Offset = Vector2.new(-offset, 0)
        end)

        TweenService:Create(textLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
        TweenService:Create(subtitleLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        TweenService:Create(subtitleStroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
        
        task.wait(3.5)

        local slideTime = 0.55
        local slideTweenInfo = TweenInfo.new(slideTime, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        
        TweenService:Create(container, slideTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 180)}):Play()
        TweenService:Create(textLabel, TweenInfo.new(slideTime - 0.1), {TextTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(slideTime - 0.1), {Transparency = 1}):Play()
        TweenService:Create(subtitleLabel, TweenInfo.new(slideTime - 0.1), {TextTransparency = 1}):Play()
        TweenService:Create(subtitleStroke, TweenInfo.new(slideTime - 0.1), {Transparency = 1}):Play()
        
        task.wait(slideTime)
        animationLoop:Disconnect()
        watermarkGui:Destroy()
    end
    
    InitializeMainMenu()
end)