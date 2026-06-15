-- Execute on Teleport Wrapper
local scriptURL = "https://raw.githubusercontent.com/csgofever/Modules/refs/heads/main/meow.lua"
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Clean up previous UI instances to prevent them from stacking when you teleport
local oldGui = player:WaitForChild("PlayerGui"):FindFirstChild("TeleportGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportGui"
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 150)
frame.Position = UDim2.new(0.5, -125, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 30)
frameCorner.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 50)
label.Position = UDim2.new(0, 0, 0, 0)
label.Text = "meowwCL community lua"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Font = Enum.Font.Arcade
label.TextSize = 15
label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
label.BackgroundTransparency = 1
label.Parent = frame

local button = Instance.new("TextButton")
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 30)
buttonCorner.Parent = button
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(0.5, -100, 0.5, -25)
button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
button.TextColor3 = Color3.fromRGB(0, 0, 0)
button.Text = "ON"
button.Parent = frame
button.Font = Enum.Font.Arcade
button.TextSize = 20

local dragDetector = Instance.new("UIDragDetector")
dragDetector.Parent = frame

local running = false

button.MouseButton1Click:Connect(function()
	running = not running

	if running then
		button.Text = "OFF"

		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local hrp = character:WaitForChild("HumanoidRootPart")

			while running and character and hrp do
				hrp.CFrame = hrp.CFrame + Vector3.new(249548593482502345, 32495872349574, 2394857239485792384)
				task.wait(0.1)
			end
		end)
	else
		button.Text = "ON"
	end
end)

-- 1. Establish fallback support for different executors' teleport queues
local teleportQueue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)

if teleportQueue then
    pcall(function()
        -- Queue the HTTP Get request for the next server
        teleportQueue(string.format([[
            pcall(function()
                loadstring(game:HttpGet("%s"))()
            end)
        ]], scriptURL))
    end)
end

-- 2. Run the code normally for the current server
pcall(function()
    loadstring(game:HttpGet(scriptURL))()
end)