-- ASTRAL.WTF | VOID HIDE ULTIMATE
-- Developed by @s39z_
-- Premium Void Teleport + Anti-Aim + Riot Bypass

local Teleport = loadstring(game:HttpGet("https://raw.githubusercontent.com/WEFGQERQEGWGE/a/refs/heads/main/1.txt"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Variables
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local OriginalCFrame = HumanoidRootPart.CFrame
local TeleportCount = 0
local isReturning = false
local returnStartTime = 0
local returnDuration = 0.5
local lastUpdate = 0
local jitterAngle = 0
local spinAngle = 0

-- Settings
local Settings = {
    VoidEnabled = false,
    VoidDistance = 1000000,
    VoidDistancePercent = 100,
    HeightOffset = 0,
    Mode = "None",
    SpinSpeed = 10,
    OrbitSpeed = 1.5,
    OrbitRadius = 25,
    DesyncSpeed = 50,
    
    RiotEnabled = false,
    RiotDistance = 10,
    RiotHeight = 0,
    RiotUpdateRate = 0.5,
    RiotTarget = nil,
    
    AAEnabled = false,
    AAPitch = "None",
    AAYawRange = 45,
    AAMode = "None",
    AASpeed = 15,
    
    SoundId = "rbxassetid://719384308",
    SoundVolume = 0.5
}

-- Sound Setup
local SoundService = game:GetService("SoundService")
local TeleportSound = Instance.new("Sound", SoundService)
TeleportSound.SoundId = Settings.SoundId
TeleportSound.Volume = Settings.SoundVolume

local SoundIds = {
    Space = "rbxassetid://719384308",
    Pop = "rbxassetid://140323850218372",
    Bonk = "rbxassetid://18794851884",
    Skeet = "rbxassetid://83717596220569",
    Neverlose = "rbxassetid://97643101798871",
    Slip = "rbxassetid://70557734865364"
}

-- Helper Functions
local function isAlive()
    return Character and Character.Parent and HumanoidRootPart and HumanoidRootPart.Parent and Humanoid and Humanoid.Health > 0
end

local function getRoot()
    return isAlive() and HumanoidRootPart or nil
end

-- Character respawn handler
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    OriginalCFrame = HumanoidRootPart.CFrame
    
    if Settings.VoidEnabled then
        task.wait(0.5)
        teleportToVoid()
    end
end)

-- Play teleport sound
local function playTeleportSound()
    pcall(function()
        TeleportSound.PlaybackSpeed = math.random(95, 105) / 100
        TeleportSound:Play()
    end)
end

-- Get void position
local function getVoidPosition()
    local root = getRoot()
    if not root then 
        return Vector3.new(0, Settings.VoidDistance + Settings.HeightOffset, 0)
    end
    
    if Settings.Mode == "Spin" then
        return Vector3.new(0, Settings.VoidDistance + Settings.HeightOffset, 0)
    elseif Settings.Mode == "Orbit" then
        return Vector3.new(0, Settings.VoidDistance + Settings.HeightOffset, 0)
    elseif Settings.Mode == "Random" then
        local x = math.random(-Settings.OrbitRadius, Settings.OrbitRadius)
        local z = math.random(-Settings.OrbitRadius, Settings.OrbitRadius)
        return Vector3.new(x, Settings.VoidDistance + Settings.HeightOffset, z)
    elseif Settings.Mode == "Desync" then
        return Vector3.new(0, Settings.VoidDistance + Settings.HeightOffset, 0)
    else
        return Vector3.new(0, Settings.VoidDistance + Settings.HeightOffset, 0)
    end
end

-- Teleport to void
local function teleportToVoid()
    if not Settings.VoidEnabled then return end
    if not isAlive() then return end
    
    local root = getRoot()
    if not root then return end
    
    if not OriginalCFrame or OriginalCFrame.Position.Magnitude < 1 then
        OriginalCFrame = root.CFrame
    end
    
    local voidPos = getVoidPosition()
    root.CFrame = CFrame.new(voidPos)
    TeleportCount = TeleportCount + 1
    playTeleportSound()
    
    -- Update UI
    if TeleportCounterLabel then
        TeleportCounterLabel:SetText("Teleports: " .. TeleportCount)
    end
    if TotalTeleportsLabel then
        TotalTeleportsLabel:SetText("Total Teleports: " .. TeleportCount)
    end
end

-- Apply motion effects
local function applyMotion(deltaTime)
    if not Settings.VoidEnabled then return end
    if not isAlive() then return end
    
    local root = getRoot()
    if not root then return end
    
    spinAngle = spinAngle + (Settings.SpinSpeed * deltaTime)
    
    if Settings.Mode == "Spin" then
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spinAngle, 0)
        
    elseif Settings.Mode == "Orbit" then
        local angle = spinAngle * Settings.OrbitSpeed
        local x = math.cos(angle) * Settings.OrbitRadius
        local z = math.sin(angle) * Settings.OrbitRadius
        root.CFrame = CFrame.new(Vector3.new(x, Settings.VoidDistance + Settings.HeightOffset, z))
        
    elseif Settings.Mode == "Random" then
        if math.random(1, 100) < Settings.SpinSpeed * deltaTime then
            local randomX = math.random(-Settings.OrbitRadius, Settings.OrbitRadius)
            local randomZ = math.random(-Settings.OrbitRadius, Settings.OrbitRadius)
            root.CFrame = CFrame.new(Vector3.new(randomX, Settings.VoidDistance + Settings.HeightOffset, randomZ))
        end
        
    elseif Settings.Mode == "Desync" then
        local desyncX = math.sin(spinAngle * Settings.DesyncSpeed) * 10
        local desyncZ = math.cos(spinAngle * Settings.DesyncSpeed) * 10
        root.CFrame = CFrame.new(Vector3.new(desyncX, Settings.VoidDistance + Settings.HeightOffset, desyncZ))
        root.CFrame = root.CFrame * CFrame.Angles(math.sin(spinAngle) * 0.5, math.cos(spinAngle) * 0.5, 0)
    end
end

-- Anti-Aim System
local function applyAntiAim(deltaTime)
    if not Settings.AAEnabled then return end
    if not isAlive() then return end
    
    local root = getRoot()
    if not root then return end
    
    local pitch = 0
    local yaw = 0
    
    -- Pitch calculation
    if Settings.AAPitch == "Flip" then
        pitch = math.rad(180)
    elseif Settings.AAPitch == "Up" then
        pitch = math.rad(-90)
    elseif Settings.AAPitch == "Down" then
        pitch = math.rad(90)
    end
    
    -- Yaw calculation based on mode
    if Settings.AAMode == "Jitter" then
        jitterAngle = (jitterAngle + Settings.AASpeed * deltaTime * 10) % (Settings.AAYawRange * 2)
        yaw = math.rad(jitterAngle - Settings.AAYawRange)
        
    elseif Settings.AAMode == "Sway" then
        yaw = math.sin(spinAngle * (Settings.AASpeed / 5)) * math.rad(Settings.AAYawRange)
        
    elseif Settings.AAMode == "Inverter" then
        yaw = (math.floor(spinAngle * 2) % 2 == 0) and 0 or math.rad(180)
        
    elseif Settings.AAMode == "Spin" then
        yaw = spinAngle
    end
    
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(pitch, yaw, 0)
end

-- Riot Bypass - Find nearest player
local function findNearestPlayer()
    local closest = nil
    local closestDist = math.huge
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local root = plr.Character.HumanoidRootPart
                local dist = (HumanoidRootPart.Position - root.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = plr
                end
            end
        end
    end
    
    return closest
end

local function updateRiotTarget()
    if not Settings.RiotEnabled then return end
    
    local target = findNearestPlayer()
    if target then
        Settings.RiotTarget = target
        if RiotTargetLabel then
            RiotTargetLabel:SetText("Target: " .. target.Name)
        end
    else
        Settings.RiotTarget = nil
        if RiotTargetLabel then
            RiotTargetLabel:SetText("Target: None")
        end
    end
end

local function applyRiotBypass(deltaTime)
    if not Settings.RiotEnabled then return end
    if not isAlive() then return end
    
    if not Settings.RiotTarget or not Settings.RiotTarget.Character then
        updateRiotTarget()
        return
    end
    
    local targetRoot = Settings.RiotTarget.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    
    -- Get position behind target
    local targetPos = targetRoot.Position
    local targetLook = targetRoot.CFrame.LookVector
    local behindPos = targetPos - targetLook * Settings.RiotDistance
    behindPos = behindPos + Vector3.new(0, Settings.RiotHeight, 0)
    
    -- Smooth movement
    local tweenInfo = TweenInfo.new(Settings.RiotUpdateRate, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = CFrame.new(behindPos)})
    tween:Play()
end

-- Main update loop
RunService.Heartbeat:Connect(function(deltaTime)
    if not isAlive() then return end
    
    -- Return to original position when disabling void
    if isReturning then
        local elapsed = tick() - returnStartTime
        if elapsed < returnDuration then
            local alpha = elapsed / returnDuration
            local newPos = OriginalCFrame.Position:Lerp(HumanoidRootPart.Position, alpha)
            HumanoidRootPart.CFrame = CFrame.new(newPos)
        else
            HumanoidRootPart.CFrame = OriginalCFrame
            isReturning = false
        end
        return
    end
    
    -- Void Teleport
    if Settings.VoidEnabled then
        teleportToVoid()
        applyMotion(deltaTime)
    end
    
    -- Anti-Aim
    if Settings.AAEnabled then
        applyAntiAim(deltaTime)
    end
    
    -- Riot Bypass
    if Settings.RiotEnabled then
        if tick() - lastUpdate > Settings.RiotUpdateRate then
            updateRiotTarget()
            lastUpdate = tick()
        end
        applyRiotBypass(deltaTime)
    end
end)

-- Create UI Window
local Window = Teleport:CreateWindow({
    Title = "ASTRAL.WTF | VOID HIDE",
    Center = true,
    Footer = "Developed by @s39z_ | Premium Script",
    ToggleKeybind = Enum.KeyCode.RightShift,
    Size = UDim2.fromOffset(650, 550),
    AutoShow = true
})

-- ==================== VOID TAB ====================
local VoidTab = Window:AddTab("Void")
local VoidGroup = VoidTab:AddLeftGroupbox("Void Teleport")

-- Enable Void Toggle with Keybind
local VoidToggle = VoidGroup:AddCheckbox("EnableVoid", {
    Text = "Enable Void Hide",
    Default = false,
    Callback = function(value)
        Settings.VoidEnabled = value
        if value then
            OriginalCFrame = HumanoidRootPart.CFrame
            teleportToVoid()
            Teleport:Notify("Void Hide: ACTIVE", 2)
        else
            isReturning = true
            returnStartTime = tick()
            Teleport:Notify("Void Hide: DEACTIVATED", 2)
        end
    end
})

-- Void Keybind (Click to change)
local VoidKeybind = VoidToggle:AddKeyPicker("VoidBind", {
    Text = "Toggle Void Mode",
    Default = "V",
    SyncToggleState = true,
    Mode = "Toggle"
})

-- Void Distance Slider
local VoidDistSlider = VoidGroup:AddSlider("VoidDist", {
    Text = "Void Distance",
    Default = 100,
    Max = 100,
    Min = 1,
    Suffix = "%",
    Rounding = 0,
    Callback = function(value)
        Settings.VoidDistancePercent = value
        Settings.VoidDistance = value * 25000
    end
})

-- Height Offset Slider
local HeightOffsetSlider = VoidGroup:AddSlider("HeightOffset", {
    Text = "Height Offset",
    Default = 0,
    Max = 1000,
    Min = -1000,
    Suffix = " studs",
    Rounding = 0,
    Callback = function(value)
        Settings.HeightOffset = value
    end
})

-- Teleport Counter
local TeleportCounterLabel = VoidGroup:AddLabel("Teleports: 0")

-- Motion Settings Group
local MotionGroup = VoidTab:AddRightGroupbox("Motion Effects")

-- Motion Mode Dropdown
local MotionModeDropdown = MotionGroup:AddDropdown("MotionMode", {
    Text = "Movement Pattern",
    Values = {"Spin", "Orbit", "Random", "Desync", "None"},
    Default = "None",
    Callback = function(value)
        Settings.Mode = value
    end
})

-- Movement Speed Slider
local MotionSpeedSlider = MotionGroup:AddSlider("BaseSpeed", {
    Text = "Movement Speed",
    Default = 10,
    Max = 100,
    Min = 0,
    Rounding = 1,
    Callback = function(value)
        Settings.SpinSpeed = value
    end
})

-- Orbit Radius Slider
local OrbitRadiusSlider = MotionGroup:AddSlider("Radius", {
    Text = "Effect Radius",
    Default = 25,
    Max = 200,
    Min = 1,
    Rounding = 0,
    Callback = function(value)
        Settings.OrbitRadius = value
    end
})

-- ==================== RIOT BYPASS TAB ====================
local RiotTab = Window:AddTab("Riot Bypass")
local RiotGroup = RiotTab:AddLeftGroupbox("Riot Bypass Settings")

-- Enable Riot Toggle
local RiotToggle = RiotGroup:AddCheckbox("EnableRiot", {
    Text = "Enable Riot Bypass",
    Default = false,
    Callback = function(value)
        Settings.RiotEnabled = value
        if value then
            updateRiotTarget()
            Teleport:Notify("Riot Bypass: ACTIVE", 2)
        else
            Teleport:Notify("Riot Bypass: DEACTIVATED", 2)
        end
    end
})

-- Riot Keybind (Click to change)
local RiotKeybind = RiotToggle:AddKeyPicker("RiotBind", {
    Text = "Toggle Riot Bypass",
    Default = "B",
    SyncToggleState = true,
    Mode = "Toggle"
})

-- Distance Behind Slider
local RiotDistSlider = RiotGroup:AddSlider("RiotDist", {
    Text = "Distance Behind",
    Default = 10,
    Max = 50,
    Min = 0,
    Suffix = " studs",
    Rounding = 1,
    Callback = function(value)
        Settings.RiotDistance = value
    end
})

-- Height Offset Slider
local RiotHeightSlider = RiotGroup:AddSlider("RiotHeight", {
    Text = "Height Offset",
    Default = 0,
    Max = 20,
    Min = -20,
    Suffix = " studs",
    Rounding = 1,
    Callback = function(value)
        Settings.RiotHeight = value
    end
})

-- Update Rate Slider
local RiotUpdateSlider = RiotGroup:AddSlider("RiotUpdateRate", {
    Text = "Target Update Rate",
    Default = 0.5,
    Max = 5,
    Min = 0.1,
    Suffix = "s",
    Rounding = 1,
    Callback = function(value)
        Settings.RiotUpdateRate = value
    end
})

-- Target Display
local RiotTargetLabel = RiotGroup:AddLabel("Target: None")

-- ==================== ANTI-AIM TAB ====================
local AntiAimTab = Window:AddTab("Anti Aim")
local AAGroup = AntiAimTab:AddLeftGroupbox("Anti-Aim Settings")

-- Enable Anti-Aim Toggle
local AAToggle = AAGroup:AddCheckbox("EnableAA", {
    Text = "Enable Anti-Aim",
    Default = false,
    Callback = function(value)
        Settings.AAEnabled = value
        Teleport:Notify("Anti-Aim: " .. (value and "ACTIVE" or "DEACTIVATED"), 2)
    end
})

-- Pitch Dropdown
local AAPitchDropdown = AAGroup:AddDropdown("AAPitch", {
    Text = "Pitch Angle",
    Values = {"Flip", "Up", "Down", "None"},
    Default = "None",
    Callback = function(value)
        Settings.AAPitch = value
    end
})

-- Yaw Range Slider
local AAYawSlider = AAGroup:AddSlider("JitterRange", {
    Text = "Rotate Amount",
    Default = 45,
    Max = 360,
    Min = 0,
    Suffix = "°",
    Rounding = 1,
    Callback = function(value)
        Settings.AAYawRange = value
    end
})

-- Anti-Aim Mode Dropdown
local AAModeDropdown = AAGroup:AddDropdown("AAMode", {
    Text = "Anti-Aim Type",
    Values = {"Jitter", "Sway", "Inverter", "Spin", "None"},
    Default = "None",
    Callback = function(value)
        Settings.AAMode = value
    end
})

-- Anti-Aim Speed Slider
local AASpeedSlider = AAGroup:AddSlider("AASpeed", {
    Text = "Anti-Aim Speed",
    Default = 15,
    Max = 30,
    Min = 1,
    Suffix = " Hz",
    Rounding = 0,
    Callback = function(value)
        Settings.AASpeed = value
    end
})

-- ==================== SOUNDS TAB ====================
local SoundTab = Window:AddTab("Sounds")
local SoundGroup = SoundTab:AddLeftGroupbox("Sound Effects")

-- Sound Selector Dropdown
local SoundSelectDropdown = SoundGroup:AddDropdown("SoundSelect", {
    Text = "Select Sound",
    Values = {"Space", "Pop", "Bonk", "Skeet", "Neverlose", "Slip"},
    Default = "Space",
    Callback = function(value)
        Settings.SoundId = SoundIds[value]
        TeleportSound.SoundId = Settings.SoundId
    end
})

-- Sound Volume Slider
local SoundVolumeSlider = SoundGroup:AddSlider("SoundVolume", {
    Text = "Sound Volume",
    Default = 50,
    Max = 100,
    Min = 0,
    Suffix = "%",
    Rounding = 0,
    Callback = function(value)
        Settings.SoundVolume = value / 100
        TeleportSound.Volume = Settings.SoundVolume
    end
})

-- ==================== STATISTICS TAB ====================
local StatsTab = Window:AddTab("Statistics")
local StatsGroup = StatsTab:AddLeftGroupbox("Stats & Info")

-- Statistics Display
local TotalTeleportsLabel = StatsGroup:AddLabel("Total Teleports: 0")
local VoidStatusLabel = StatsGroup:AddLabel("Void Status: OFF")
local RiotStatusLabel = StatsGroup:AddLabel("Riot Status: OFF")
local AAStatusLabel = StatsGroup:AddLabel("Anti-Aim Status: OFF")
local DevCreditLabel = StatsGroup:AddLabel("Developer: @s39z_")
local VersionLabel = StatsGroup:AddLabel("Version: 2.0 | ASTRAL.WTF")

-- Update stats periodically
RunService.Heartbeat:Connect(function()
    TotalTeleportsLabel:SetText("Total Teleports: " .. TeleportCount)
    VoidStatusLabel:SetText("Void Status: " .. (Settings.VoidEnabled and "ACTIVE" or "OFF"))
    RiotStatusLabel:SetText("Riot Status: " .. (Settings.RiotEnabled and "ACTIVE" or "OFF"))
    AAStatusLabel:SetText("Anti-Aim Status: " .. (Settings.AAEnabled and "ACTIVE" or "OFF"))
end)

-- ==================== KEYBIND HANDLER ====================
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Void Toggle
    if VoidKeybind:IsPressed() then
        local newState = not Settings.VoidEnabled
        Settings.VoidEnabled = newState
        VoidToggle:SetValue(newState)
        if newState then
            OriginalCFrame = HumanoidRootPart.CFrame
            teleportToVoid()
            Teleport:Notify("Void Hide: ACTIVE", 2)
        else
            isReturning = true
            returnStartTime = tick()
            Teleport:Notify("Void Hide: DEACTIVATED", 2)
        end
    end
    
    -- Riot Toggle
    if RiotKeybind:IsPressed() then
        local newState = not Settings.RiotEnabled
        Settings.RiotEnabled = newState
        RiotToggle:SetValue(newState)
        if newState then
            updateRiotTarget()
            Teleport:Notify("Riot Bypass: ACTIVE", 2)
        else
            Teleport:Notify("Riot Bypass: DEACTIVATED", 2)
        end
    end
end)

-- Initial Notifications
Teleport:Notify("ASTRAL.WTF | Void Hide Ultimate Loaded!", 3)
Teleport:Notify("Press RightShift for menu | Click keybinds to change keys", 4)

print("================================================")
print("ASTRAL.WTF | VOID HIDE ULTIMATE")
print("Developed by @s39z_")
print("================================================")
print("FEATURES:")
print("  • Void Teleport - Teleports you to the void")
print("  • Motion Effects - Spin, Orbit, Random, Desync")
print("  • Riot Bypass - Hide behind players")
print("  • Anti-Aim - Break hitboxes with jitter/sway")
print("  • Custom Sound Effects")
print("================================================")
print("CONTROLS:")
print("  • RightShift - Open/Close Menu")
print("  • V - Toggle Void Hide (Click button to change)")
print("  • B - Toggle Riot Bypass (Click button to change)")
print("================================================")