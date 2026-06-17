--Rivals Only!!
--원작자(.antilua.)의 허락 없이 2차 창작물을 제작하거나 배포하는 것을 금지합니다.
--The creation or distribution of derivative works without the permission of the original author (.antilua.) is prohibited.
--Original Script는 loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Ukrubojvo/Modules/main/StaffDetector.lua"))() 입니다!

xpcall(function()
    if (game.GameId ~= 6035872082) then return end
    if shared.StaffDetectorLoading then return end
    shared.StaffDetectorLoading = true
    repeat task.wait() until game:IsLoaded()
    local cloneref = cloneref or function(obj)
        return obj
    end

    if autoload == nil then autoload=true end
    if autoleave == nil then autoleave=true end

    local players = cloneref(game:GetService("Players"))
    local coregui = gethui() or cloneref(game:GetService("CoreGui"))
    local TS = game:GetService("TweenService")
    local TI = TweenInfo.new
    local http = game:GetService("HttpService")
    local lp = players.LocalPlayer
    local groupId = game.CreatorId
    local notify_sound = nil
    local CACHE_FILE = "AntiLua/staffcache_" .. groupId .. ".json"

    if game.CreatorType ~= Enum.CreatorType.Group then
        return
    end

    task.spawn(function()
        if not isfile("AntiLua/staffdetect.mp3") then writefile("AntiLua/staffdetect.mp3", tostring(game:HttpGetAsync("https://github.com/csgofever/api/raw/refs/heads/main/modDetect.mp3"))) end
        notify_sound = Instance.new("Sound", workspace)
        notify_sound.SoundId = getcustomasset("jugglua/staffdetect.mp3")
        notify_sound.Volume = 5
        notify_sound.Looped = true
    end)

    pcall(function()
        if not autoload then return end
        if autoleave then
            queue_on_teleport([[
                pcall(function()
                    autoload = true;
                    autoleave = true;
                    local GitRequests = loadstring(game:HttpGet('https://raw.githubusercontent.com/csgofever/Roblox-GitRequests/refs/heads/main/GitRequests.lua'))()
                    local Repo = GitRequests.Repo("csgofever", "Modules")
                    loadstring(Repo:getFileContent("StaffDetector.lua"))()
                end)
            ]])
        else
            queue_on_teleport([[
                pcall(function()
                    autoload = true;
                    autoleave = false;
                    local GitRequests = loadstring(game:HttpGet('https://raw.githubusercontent.com/csgofever/Roblox-GitRequests/refs/heads/main/GitRequests.lua'))()
                    local Repo = GitRequests.Repo("csgofever", "Modules")
                    loadstring(Repo:getFileContent("StaffDetector.lua"))()
                end)
            ]])
        end
    end)

    local function fetchURL(url)
        local ok, res = pcall(game.HttpGet, game, url)
        if ok then
            local data = http:JSONDecode(res)
            return data
        end
        return nil
    end

    local function loadCachedStaffIds()
        local cached = {}
        pcall(function()
            if isfile(CACHE_FILE) then
                local data = http:JSONDecode(readfile(CACHE_FILE))
                if type(data) == "table" then
                    for _, uid in ipairs(data) do
                        cached[uid] = true
                    end
                end
            end
        end)
        return cached
    end

    local function saveCachedStaffIds(ids)
        pcall(function()
            local list = {}
            for uid, _ in pairs(ids) do
                table.insert(list, uid)
            end
            writefile(CACHE_FILE, http:JSONEncode(list))
        end)
    end

    local function extractStaffRoleIds(groupId)
        local url = ("https://groups.roblox.com/v1/groups/%d/roles"):format(groupId)
        local data = fetchURL(url)
        local roleIds = {}

        if data and data.roles then
            for _, r in ipairs(data.roles) do
                local name = string.lower(r.name)
                if string.find(name, "mod") or string.find(name, "staff") or string.find(name, "contributor") 
                or string.find(name, "script") or string.find(name, "build") then
                    table.insert(roleIds, r.id)
                end
            end
        end

        return roleIds
    end

    local function fetchUsersInRole(groupId, roleId)
        local cursor = ""
        local collected = {}

        while true do
            local url = string.format("https://groups.roproxy.com/v1/groups/%d/roles/%d/users?limit=100&cursor=%s", groupId, roleId, cursor)

            local success, response = pcall(function()
                return game:HttpGet(url)
            end)

            if not success or not response then break end
            local json = http:JSONDecode(response)

            if json.data and type(json.data) == "table" then
                for _, user in ipairs(json.data) do
                    if user.userId then
                        collected[user.userId] = true
                    end
                end
            end

            if not json.nextPageCursor or json.nextPageCursor == "" then break end
            cursor = json.nextPageCursor
        end

        return collected
    end


    local staffRoleIds = extractStaffRoleIds(groupId)
    local staffUserIds = loadCachedStaffIds()

    --[[
    local function GetUserRoleInGroup(userId, groupId)
        local url = string.format("https://groups.roproxy.com/v2/users/%d/groups/roles", userId)
        local success, response = pcall(game.HttpGet, game, url)
        if success then
            local data = http:JSONDecode(response)
            if data and data.data then
                for _, info in ipairs(data.data) do
                    if info.group and info.group.id == groupId then
                        return info.role and info.role.name or nil
                    end
                end
            end
        end
        return nil
    end
    ]]

    local function GetRole(plr, groupId)
        if plr and typeof(plr) == "Instance" then
            local method = plr.GetRoleInGroup
            if typeof(method) == "function" then
                return method(plr, groupId)
            end
        end
        return nil
    end

    local function isStaffRoleName(role)
        if role and typeof(role) == "string" then
            local r = string.lower(role)
            if string.find(r, "mod") or string.find(r, "staff") or string.find(r, "contributor") or string.find(r, "script") or string.find(r, "build") then
                return true
            end
        end
        return false
    end

    local function shortenName(name)
        if #name > 6 then
            return string.sub(name, 1, 6) .. "..."
        end
        return name
    end

    local function getStaffInfo()
        local total = #players:GetPlayers()
        local staffNames = {}
        for _, plr in ipairs(players:GetPlayers()) do
            local role = GetRole(plr, game.CreatorId)
            if isStaffRoleName(role) then
                table.insert(staffNames, shortenName(plr.Name))
            end
        end
        return staffNames, total
    end

    local function getFriendStaffInfo()
        local list = {}
        for _, plr in ipairs(players:GetPlayers()) do
            local ok, pages = pcall(function()
                return players:GetFriendsAsync(plr.UserId)
            end)
            if ok and pages then
                while true do
                    local page = pages:GetCurrentPage()
                    for _, friend in ipairs(page) do
                        if staffUserIds[friend.Id] then
                            table.insert(list, shortenName(friend.Username))
                        end
                    end
                    if pages.IsFinished then break end
                    pages:AdvanceToNextPageAsync()
                end
            end
            -- ADDED: Wait half a second before checking the next player to prevent rate limits
            task.wait(0.5)
        end
        return list
    end

    local function createLeaveUI(MessageText, OnYes, OnNo)
        local old = coregui:FindFirstChild("ModAlertLeaveUI")
        if old then return end

        local Gui = Instance.new("ScreenGui")
        Gui.Name = "ModAlertLeaveUI"
        Gui.ResetOnSpawn = false
        Gui.IgnoreGuiInset = true
        Gui.DisplayOrder = 2147483647
        Gui.Parent = coregui

        local Backdrop = Instance.new("Frame")
        Backdrop.Size = UDim2.new(1, 0, 1, 0)
        Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Backdrop.BackgroundTransparency = 1
        Backdrop.BorderSizePixel = 0
        Backdrop.Parent = Gui

        local Container = Instance.new("CanvasGroup")
        Container.Size = UDim2.new(0, 380, 0, 0)
        Container.AutomaticSize = Enum.AutomaticSize.Y
        Container.Position = UDim2.new(0.5, 0, 0.5, 0)
        Container.AnchorPoint = Vector2.new(0.5, 0.5)
        Container.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
        Container.BorderSizePixel = 0
        Container.GroupTransparency = 1
        Container.Parent = Gui

        Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 12)

        local Border = Instance.new("UIStroke")
        Border.Color = Color3.fromRGB(45, 45, 50)
        Border.Thickness = 1
        Border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        Border.Parent = Container

        local Padding = Instance.new("UIPadding")
        Padding.PaddingTop = UDim.new(0, 24)
        Padding.PaddingBottom = UDim.new(0, 20)
        Padding.PaddingLeft = UDim.new(0, 24)
        Padding.PaddingRight = UDim.new(0, 24)
        Padding.Parent = Container

        local Layout = Instance.new("UIListLayout")
        Layout.FillDirection = Enum.FillDirection.Vertical
        Layout.SortOrder = Enum.SortOrder.LayoutOrder
        Layout.Padding = UDim.new(0, 14)
        Layout.Parent = Container

        local Header = Instance.new("Frame")
        Header.Size = UDim2.new(1, 0, 0, 32)
        Header.BackgroundTransparency = 1
        Header.LayoutOrder = 1
        Header.Parent = Container

        local HeaderLayout = Instance.new("UIListLayout")
        HeaderLayout.FillDirection = Enum.FillDirection.Horizontal
        HeaderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        HeaderLayout.Padding = UDim.new(0, 10)
        HeaderLayout.Parent = Header

        local IconFrame = Instance.new("Frame")
        IconFrame.Size = UDim2.new(0, 32, 0, 32)
        IconFrame.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        IconFrame.BorderSizePixel = 0
        IconFrame.Parent = Header

        Instance.new("UICorner", IconFrame).CornerRadius = UDim.new(0, 8)

        local IconImage = Instance.new("ImageLabel")
        IconImage.Size = UDim2.new(0.6, 0, 0.6, 0)
        IconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
        IconImage.AnchorPoint = Vector2.new(0.5, 0.5)
        IconImage.BackgroundTransparency = 1
        IconImage.Image = "rbxassetid://18797417802"
        IconImage.ImageColor3 = Color3.new(1, 1, 1)
        IconImage.Parent = IconFrame

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -42, 1, 0)
        Title.BackgroundTransparency = 1
        Title.Text = "Moderator Detected"
        Title.TextColor3 = Color3.fromRGB(240, 240, 240)
        Title.TextSize = 17
        Title.Font = Enum.Font.GothamBold
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Header

        local Divider = Instance.new("Frame")
        Divider.Size = UDim2.new(1, 0, 0, 1)
        Divider.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        Divider.BorderSizePixel = 0
        Divider.LayoutOrder = 2
        Divider.Parent = Container

        local Message = Instance.new("TextLabel")
        Message.Size = UDim2.new(1, 0, 0, 0)
        Message.AutomaticSize = Enum.AutomaticSize.Y
        Message.BackgroundTransparency = 1
        Message.Text = MessageText
        Message.RichText = true
        Message.TextColor3 = Color3.fromRGB(160, 160, 170)
        Message.TextSize = 14
        Message.Font = Enum.Font.Gotham
        Message.TextWrapped = true
        Message.TextXAlignment = Enum.TextXAlignment.Left
        Message.TextYAlignment = Enum.TextYAlignment.Top
        Message.LayoutOrder = 3
        Message.Parent = Container

        local ButtonsFrame = Instance.new("Frame")
        ButtonsFrame.Size = UDim2.new(1, 0, 0, 42)
        ButtonsFrame.BackgroundTransparency = 1
        ButtonsFrame.LayoutOrder = 4
        ButtonsFrame.Parent = Container

        local ButtonLayout = Instance.new("UIListLayout")
        ButtonLayout.FillDirection = Enum.FillDirection.Horizontal
        ButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        ButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        ButtonLayout.Padding = UDim.new(0, 10)
        ButtonLayout.Parent = ButtonsFrame

        local function CreateButton(Text, BgColor, TextColor)
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(0, 130, 0, 38)
            Btn.BackgroundColor3 = BgColor
            Btn.BorderSizePixel = 0
            Btn.Text = Text
            Btn.TextColor3 = TextColor
            Btn.TextSize = 14
            Btn.Font = Enum.Font.GothamSemibold
            Btn.Modal = true
            Btn.AutoButtonColor = false
            Btn.Parent = ButtonsFrame

            Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

            Btn.MouseEnter:Connect(function()
                TS:Create(Btn, TI(0.15), {
                    BackgroundColor3 = Color3.fromRGB(
                        math.min(BgColor.R * 255 + 12, 255),
                        math.min(BgColor.G * 255 + 12, 255),
                        math.min(BgColor.B * 255 + 12, 255)
                    )
                }):Play()
            end)

            Btn.MouseLeave:Connect(function()
                TS:Create(Btn, TI(0.15), { BackgroundColor3 = BgColor }):Play()
            end)

            return Btn
        end

        local NoBtn  = CreateButton("Stay Here",    Color3.fromRGB(38, 38, 42),  Color3.fromRGB(180, 180, 190))
        local YesBtn = CreateButton("Leave Server", Color3.fromRGB(185, 50, 50), Color3.fromRGB(255, 255, 255))

        local NoBorder = Instance.new("UIStroke")
        NoBorder.Color = Color3.fromRGB(55, 55, 62)
        NoBorder.Thickness = 1
        NoBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        NoBorder.Parent = NoBtn

        local function FadeOut(callback)
            TS:Create(Backdrop, TI(0.25), { BackgroundTransparency = 1 }):Play()
            TS:Create(Container, TI(0.25), { GroupTransparency = 1 }):Play()
            task.wait(0.25)
            if callback then callback() end
            Gui:Destroy()
        end

        YesBtn.MouseButton1Click:Connect(function() FadeOut(OnYes) end)
        NoBtn.MouseButton1Click:Connect(function()
            if notify_sound then notify_sound:Stop() end
            FadeOut(OnNo)
        end)

        TS:Create(Backdrop, TI(0.3), { BackgroundTransparency = 0.55 }):Play()
        TS:Create(Container, TI(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            GroupTransparency = 0
        }):Play()

        return Gui
    end

    local function showNotification(name, statusText, statusColor, staffNames, friendStaffNames, totalCount, duration)
        local old = coregui:FindFirstChild("ModAlertNotification")
        if old then old:Destroy() end

        local screengui = Instance.new("ScreenGui")
        screengui.Name = name
        screengui.ResetOnSpawn = false
        screengui.DisplayOrder = 2147483647
        screengui.IgnoreGuiInset = true
        screengui.Parent = coregui

        local canvas = Instance.new("CanvasGroup")
        canvas.AnchorPoint = Vector2.new(1, 1)
        canvas.Position = UDim2.new(1, -20, 1, -20)
        canvas.Size = UDim2.new(0, 280, 0, 0)
        canvas.AutomaticSize = Enum.AutomaticSize.Y
        canvas.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        canvas.BorderSizePixel = 0
        canvas.BackgroundTransparency = 0.15
        canvas.Parent = screengui

        local uicorner = Instance.new("UICorner")
        uicorner.CornerRadius = UDim.new(0, 10)
        uicorner.Parent = canvas

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(90, 90, 90)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = canvas

        local listLayout = Instance.new("UIListLayout")
        listLayout.FillDirection = Enum.FillDirection.Vertical
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = canvas

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 10)
        padding.PaddingBottom = UDim.new(0, 12)
        padding.PaddingLeft = UDim.new(0, 15)
        padding.PaddingRight = UDim.new(0, 15)
        padding.Parent = canvas

        local title = Instance.new("TextLabel")
        title.Text = "Moderator Detector"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = Color3.fromRGB(236, 236, 236)
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, 0, 0, 24)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.LayoutOrder = 1
        title.Parent = canvas

        local staffDisplay = #staffNames > 0 and table.concat(staffNames, ", ") or "None"
        local friendDisplay = #friendStaffNames > 0 and table.concat(friendStaffNames, ", ") or "None"

        local desc = Instance.new("TextLabel")
        desc.Text = statusText .. "\n<font color=\"rgb(150,150,150)\" size=\"13\">Server Moderators: " .. staffDisplay .. "</font>" .. "\n<font color=\"rgb(150,150,150)\" size=\"13\">Friend Moderators: " .. friendDisplay .. "</font>"
        desc.RichText = true
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 14
        desc.TextColor3 = statusColor
        desc.BackgroundTransparency = 1
        desc.Size = UDim2.new(1, 0, 0, 0)
        desc.AutomaticSize = Enum.AutomaticSize.Y 
        desc.TextWrapped = true
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextYAlignment = Enum.TextYAlignment.Top
        desc.LayoutOrder = 2
        desc.Parent = canvas

        task.delay(duration, function()
            pcall(function()
                if screengui then
                    screengui:Destroy()
                end
            end)
        end)
    end

    local function runDetection()
        local staffNames, totalCount = getStaffInfo()
        local friendStaffNames = getFriendStaffInfo()

        local hasServerStaff = #staffNames > 0
        local hasFriendStaff = #friendStaffNames > 0
        local hasDetected = (hasServerStaff or hasFriendStaff)

        local statusText = ""
        if hasServerStaff then statusText = "Moderators detected!" end
        if hasFriendStaff then statusText = statusText .. (hasServerStaff and "\n" or "") .. "Staff friends detected!" end
        if statusText == "" then statusText = "No staff detected." end

        local statusColor = hasDetected and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
        local duration = hasDetected and 60 or 10

        if hasDetected then
            if autoleave then
                -- Automatically teleports you to a new server/lobby instead of just kicking
                game:GetService("TeleportService"):Teleport(17625359962)
                return true
            end
        end

        showNotification("ModAlertNotification", statusText, statusColor, staffNames, friendStaffNames, totalCount, duration)
        return hasDetected
    end

    runDetection()

    task.spawn(function()
        for _, roleId in ipairs(staffRoleIds) do
            local users = fetchUsersInRole(groupId, roleId)
            for uid, _ in pairs(users) do
                staffUserIds[uid] = true
            end
        end
        saveCachedStaffIds(staffUserIds)
        if not coregui:FindFirstChild("ModAlertLeaveUI") then
            runDetection()
        end
    end)

    local isScanning = false

    players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Wait()
        
        -- If a scan is already happening, don't start a duplicate one
        if isScanning then return end
        isScanning = true
        
        -- ADDED: Wait a couple seconds to ensure the player fully loads in
        task.wait(2) 
        
        if not coregui:FindFirstChild("ModAlertLeaveUI") then
            runDetection()
        end
        
        -- Open it back up for the next scan
        isScanning = false 
    end)
end, function() end)