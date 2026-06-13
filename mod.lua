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
local hrp = character:WaitForChild("HumanoidRootPart")

-- CLEAR COMPONENT: Wipes out previous menus to stop duplicate rendering
local targetGui = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
for _, oldUi in pairs(targetGui:GetChildren()) do
    if oldUi.Name == "JuggProfileGui" or oldUi.Name == "JuggPremiumGui" or oldUi.Name == "JuggWatermark" then
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
}

local FeatureStates = {
    OrbitAura = false,
    SmoothOrbit = false,
    AutoCollect = false,
    AutoRespawn = false,
    AntiMod = false,
    AntiAFK = false,
    FPSBoost = false,
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

-- Feature Modules
local VOID_POS = Vector3.new(0, -500, 0)
local orbitConnection, smoothOrbitConnection, collectConnection, antiModThread, antiAFKConnection

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
    FeatureStates.AntiMod = enabled
    if enabled then
        print("[Anti-Mod] Active: Monitoring for staff join events...")
        antiModConnection = Players.PlayerAdded:Connect(function(p)
            print("[Anti-Mod] Checking player: " .. p.Name .. " (" .. p.UserId .. ")")
            if table.find(modIds, p.UserId) then
                warn("[Anti-Mod] STAFF DETECTED: " .. p.Name .. ". Triggering auto-leave.")
                TeleportService:Teleport(game.PlaceId)
            end
        end)
    else
        if antiModConnection then 
            antiModConnection:Disconnect() 
            antiModConnection = nil 
            print("[Anti-Mod] Disabled.")
        end
    end
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
-- MAIN MENU GENERATION
--------------------------------------------------
local function InitializeMainMenu()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "JuggProfileGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = targetGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -160)
    MainFrame.BackgroundColor3 = Color3.fromRGB(9, 9, 11)
    MainFrame.BackgroundTransparency = Settings.UITransparency
    MainFrame.BorderSizePixel = 0
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

    local JuggPage = createTab("Jugg")
    local MiscPage = createTab("Misc")
    local SettingsPage = createTab("Settings")

    tabs["Jugg"].Page.Visible = true
    tabs["Jugg"].Btn.BackgroundTransparency = 0
    tabs["Jugg"].Btn.TextColor3 = Color3.fromRGB(255, 255, 255)

    createToggleRow(JuggPage, "Orbit Kill Aura", "OrbitAura", false, toggleOrbitAura)
    createToggleRow(JuggPage, "Smooth Orbit", "SmoothOrbit", false, toggleSmoothOrbit)
    createToggleRow(JuggPage, "Auto Collect Drops", "AutoCollect", false, toggleAutoCollect)
    createToggleRow(JuggPage, "Auto Respawn", "AutoRespawn", false, toggleAutoRespawn)

    createToggleRow(MiscPage, "Anti-Mod", "AntiMod", false, toggleAntiMod)
    createToggleRow(MiscPage, "Anti-AFK", "AntiAFK", false, toggleAntiAFK)
    createToggleRow(MiscPage, "FPS Boost", "FPSBoost", false, toggleFPSBoost)

    createActionButton(SettingsPage, "Save Current Settings Parameters", function()
        saveSettings()
    end)
    createKeybindSelector(SettingsPage, "Menu Keybind", "ToggleKey")

    for key, _ in pairs(RegisteredUIComponents) do
        updateUIToggleVisual(key, false)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Settings.ToggleKey then
                MainFrame.Visible = not MainFrame.Visible
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

    if FeatureStates.OrbitAura then toggleOrbitAura(true) end
    if FeatureStates.SmoothOrbit then toggleSmoothOrbit(true) end
    if FeatureStates.AutoCollect then toggleAutoCollect(true) end
    if FeatureStates.AutoRespawn then toggleAutoRespawn(true) end
    if FeatureStates.AntiMod then toggleAntiMod(true) end
    if FeatureStates.AntiAFK then toggleAntiAFK(true) end
    if FeatureStates.FPSBoost then toggleFPSBoost(true) end
end

--------------------------------------------------
-- INITIALIZATION SEQUENCE 
--------------------------------------------------
task.spawn(function()
    -- Staggers the initialization thread to completely avoid script startup lag
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

    -- Fade Intro In
    TweenService:Create(textLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
    TweenService:Create(subtitleLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(subtitleStroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
    
    -- Display time
    task.wait(3.5)

    -- Slide out sequence
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
    
    -- Sequential handover: Generate dashboard now that intro has closed
    InitializeMainMenu()
end)