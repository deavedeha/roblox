if game.PlaceId ~= 142823291 then
    return
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TRACKER_PREFIX = "RoleDetector_"
local tracked = {}
local highlights = {}
local murdererEspEnabled = false
local sheriffEspEnabled = false
local chamsEnabled = false
local running = true
local lastPositions = {Murderer = nil, Sheriff = nil}
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local menuKey = Enum.KeyCode.Insert
local waitingForMenuKey = false

for _, object in ipairs(PlayerGui:GetChildren()) do
    if object:IsA("BillboardGui") and object.Name:sub(1, #TRACKER_PREFIX) == TRACKER_PREFIX then
        object:Destroy()
    end
end

local function getRoleTool(player)
    local containers = {
        player.Character,
        player:FindFirstChildOfClass("Backpack")
    }

    for _, container in ipairs(containers) do
        if container then
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") then
                    if object.Name == "Knife" then
                        return "Murderer", Color3.fromRGB(255, 60, 60)
                    elseif object.Name == "Revolver" or object.Name == "Gun" then
                        return "Sheriff", Color3.fromRGB(70, 140, 255)
                    end
                end
            end
        end
    end

    return nil
end

local function clearHighlight(player)
    local highlight = highlights[player]
    if highlight then
        highlight:Destroy()
        highlights[player] = nil
    end
end

local function updateChams(player, role, color)
    local character = player.Character
    if not chamsEnabled then
        clearHighlight(player)
        return
    end
    if not character then
        clearHighlight(player)
        return
    end
    if not role then
        return
    end

    local highlight = highlights[player]
    if not highlight or highlight.Parent ~= character then
        clearHighlight(player)
        highlight = Instance.new("Highlight")
        highlight.Name = "RoleChams"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = character
        highlights[player] = highlight
    end

    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
end

local function updateTracker(player, role, color)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")

    if role and root then
        lastPositions[role] = root.CFrame
    end

    updateChams(player, role, color)

    local roleEspEnabled = role == "Murderer" and murdererEspEnabled or role == "Sheriff" and sheriffEspEnabled
    local visible = roleEspEnabled and role and head
    local tracker = tracked[player]

    if not visible then
        if tracker then
            tracker:Destroy()
            tracked[player] = nil
        end
        return
    end

    if not tracker or tracker.Parent == nil then
        tracker = Instance.new("BillboardGui")
        tracker.Name = TRACKER_PREFIX .. player.UserId
        tracker.Size = UDim2.fromOffset(120, 28)
        tracker.StudsOffset = Vector3.new(0, 3, 0)
        tracker.AlwaysOnTop = true
        tracker.Adornee = head
        tracker.Parent = PlayerGui
        tracked[player] = tracker

        local label = Instance.new("TextLabel")
        label.Name = "Role"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextStrokeTransparency = 0.25
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Parent = tracker
    end

    tracker.Adornee = head
    local label = tracker:FindFirstChild("Role")
    if label then
        label.Text = role
        label.TextColor3 = color
    end
end
local function teleportToRole(role)
    local savedCFrame = lastPositions[role]
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if savedCFrame and root then
        root.CFrame = savedCFrame
    end
end

local function MurdererTP()
    teleportToRole("Murderer")
end

local function SheriffTP()
    teleportToRole("Sheriff")
end

if type(getgenv) == "function" then
    local env = getgenv()
    env.MurdererTP = MurdererTP
    env.SheriffTP = SheriffTP
end
local oldMenu = PlayerGui:FindFirstChild("RoleTPMenu")
if oldMenu then
    oldMenu:Destroy()
end

local purgeRoots = {workspace, PlayerGui}
local purgeOk, purgeCoreGui = pcall(function() return game:GetService("CoreGui") end)
if purgeOk and purgeCoreGui then table.insert(purgeRoots, purgeCoreGui) end
for _, purgeRoot in ipairs(purgeRoots) do
    for _, object in ipairs(purgeRoot:GetDescendants()) do
        if object.Name == "RoleChams" or (object:IsA("BillboardGui") and object.Name:sub(1, #TRACKER_PREFIX) == TRACKER_PREFIX) then
            object:Destroy()
        end
    end
end

local cleanupDone = false
local function cleanupAll()
    if cleanupDone then return end
    cleanupDone = true
    running = false
    murdererEspEnabled = false
    sheriffEspEnabled = false
    chamsEnabled = false

    local function purge(root)
        pcall(function()
            for _, object in ipairs(root:GetDescendants()) do
                if object.Name == "RoleChams" or (object:IsA("BillboardGui") and object.Name:sub(1, #TRACKER_PREFIX) == TRACKER_PREFIX) then
                    object:Destroy()
                end
            end
        end)
    end

    purge(workspace)
    purge(PlayerGui)
    pcall(function() purge(game:GetService("CoreGui")) end)

    for player in pairs(tracked) do
        tracked[player] = nil
    end
    for player in pairs(highlights) do
        highlights[player] = nil
    end
end
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "RoleTPMenu"
menuGui.ResetOnSpawn = false
menuGui.Parent = PlayerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "ForumStyleMenu"
mainFrame.Size = UDim2.fromOffset(430, 225)
mainFrame.Position = UDim2.new(1, -740, 0, 5)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = menuGui
corner(mainFrame, 12)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Transparency = 0.82
mainStroke.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
corner(titleBar, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.fromOffset(16, 0)
title.BackgroundTransparency = 1
title.Text = "Murder Mystery 2  | Forum X"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamMedium
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local function titleButton(offset, color, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28)
    b.Position = UDim2.new(1, offset, 0, 10)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.45
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 18
    b.Parent = titleBar
    corner(b, 6)
    return b
end

local minButton = titleButton(-78, Color3.fromRGB(255, 255, 255), "-")
local closeButton = titleButton(-42, Color3.fromRGB(255, 70, 70), "×")

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -20, 1, -58)
body.Position = UDim2.fromOffset(10, 52)
body.BackgroundTransparency = 1
body.Parent = mainFrame

local function makeToggle(row, initial, callback, onColor)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(44, 24)
    button.Position = UDim2.new(1, -56, 0.5, -12)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.78
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.ClipsDescendants = true
    button.Active = true
    button.ZIndex = 10
    button.Parent = row
    corner(button, 1000)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BackgroundTransparency = 0.5
    fill.BorderSizePixel = 0
    fill.Parent = button
    fill.ZIndex = 11
    corner(fill, 1000)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = button
    knob.ZIndex = 12
    corner(knob, 1000)

    local state = initial
    local function refresh()
        local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        fill.BackgroundColor3 = state and onColor or Color3.fromRGB(255, 255, 255)
        TweenService:Create(fill, info, {Size = state and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0), BackgroundTransparency = state and 0.25 or 0.5}):Play()
        TweenService:Create(knob, info, {Position = state and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3)}):Play()
        TweenService:Create(button, info, {BackgroundTransparency = state and 0.6 or 0.78}):Play()
    end
    refresh()
    button.Activated:Connect(function()
        state = not state
        refresh()
        callback(state)
    end)
    return button
end

local tpPanel = Instance.new("Frame")
tpPanel.Size = UDim2.new(1, 0, 0, 44)
tpPanel.Position = UDim2.fromOffset(0, 0)
tpPanel.BackgroundTransparency = 1
tpPanel.Parent = body

local function makeTPButton(text, x, color, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.5, -5, 1, 0)
    button.Position = UDim2.new(x, x == 0 and 0 or 5, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.78
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(220, 220, 235)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.AutoButtonColor = false
    button.Active = true
    button.ZIndex = 10
    button.Parent = tpPanel
    corner(button, 8)
    button.Activated:Connect(callback)
    return button
end

makeTPButton("Murderer TP", 0, Color3.fromRGB(255, 255, 255), MurdererTP)
makeTPButton("Sheriff TP", 0.5, Color3.fromRGB(255, 255, 255), SheriffTP)

local function makePairRow(y, leftText, leftState, leftCallback, rightText, rightState, rightCallback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.Position = UDim2.fromOffset(0, y)
    row.BackgroundTransparency = 1
    row.Parent = body

    local function makeHalf(x, text, state, callback)
        local half = Instance.new("Frame")
        half.Size = UDim2.new(0.5, -3, 1, 0)
        half.Position = UDim2.new(x, x == 0 and 0 or 6, 0, 0)
        half.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        half.BackgroundTransparency = 0.93
        half.BorderSizePixel = 0
        half.Parent = row
        corner(half, 8)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Transparency = 0.9
        stroke.Parent = half
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -70, 1, 0)
        label.Position = UDim2.fromOffset(10, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 220, 235)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = half
        makeToggle(half, state, callback, Color3.fromRGB(255, 255, 255))
    end

    makeHalf(0, leftText, leftState, leftCallback)
    makeHalf(0.5, rightText, rightState, rightCallback)
end

makePairRow(50, "Murderer ESP", false, function(state)
    murdererEspEnabled = state
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then local role, color = getRoleTool(player); updateTracker(player, role, color) end
    end
end, "Sheriff ESP", false, function(state)
    sheriffEspEnabled = state
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then local role, color = getRoleTool(player); updateTracker(player, role, color) end
    end
end)

local keybindRow = Instance.new("Frame")
keybindRow.Size = UDim2.new(0.5, -3, 0, 44)
keybindRow.Position = UDim2.fromOffset(0, 100)
keybindRow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
keybindRow.BackgroundTransparency = 0.93
keybindRow.BorderSizePixel = 0
keybindRow.Parent = body
corner(keybindRow, 8)

local keybindLabel = Instance.new("TextLabel")
keybindLabel.Size = UDim2.new(1, -86, 1, 0)
keybindLabel.Position = UDim2.fromOffset(10, 0)
keybindLabel.BackgroundTransparency = 1
keybindLabel.Text = "Menu Keybind"
keybindLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
keybindLabel.Font = Enum.Font.Gotham
keybindLabel.TextSize = 11
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindLabel.Parent = keybindRow

local keybindButton = Instance.new("TextButton")
keybindButton.Size = UDim2.fromOffset(70, 28)
keybindButton.Position = UDim2.new(1, -78, 0.5, -14)
keybindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
keybindButton.BackgroundTransparency = 0.78
keybindButton.BorderSizePixel = 0
keybindButton.Text = menuKey.Name
keybindButton.TextColor3 = Color3.fromRGB(220, 220, 235)
keybindButton.Font = Enum.Font.GothamBold
keybindButton.TextSize = 12
keybindButton.AutoButtonColor = false
keybindButton.Parent = keybindRow
corner(keybindButton, 7)

keybindButton.Activated:Connect(function()
    waitingForMenuKey = true
    keybindButton.Text = "Press key"
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if waitingForMenuKey and input.UserInputType == Enum.UserInputType.Keyboard then
        waitingForMenuKey = false
        menuKey = input.KeyCode
        keybindButton.Text = menuKey.Name
        return
    end

    if not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == menuKey then
        menuGui.Enabled = not menuGui.Enabled
    end
end)

local chamsRow = Instance.new("Frame")
chamsRow.Size = UDim2.new(0.5, -3, 0, 44)
chamsRow.Position = UDim2.new(0.5, 3, 0, 100)
chamsRow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
chamsRow.BackgroundTransparency = 0.93
chamsRow.BorderSizePixel = 0
chamsRow.Parent = body
corner(chamsRow, 8)

local chamsLabel = Instance.new("TextLabel")
chamsLabel.Size = UDim2.new(1, -72, 1, 0)
chamsLabel.Position = UDim2.fromOffset(10, 0)
chamsLabel.BackgroundTransparency = 1
chamsLabel.Text = "Chams"
chamsLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
chamsLabel.Font = Enum.Font.Gotham
chamsLabel.TextSize = 12
chamsLabel.TextXAlignment = Enum.TextXAlignment.Left
chamsLabel.Parent = chamsRow

makeToggle(chamsRow, false, function(state)
    chamsEnabled = state
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local role, color = getRoleTool(player)
            updateChams(player, role, color)
        end
    end
end, Color3.fromRGB(255, 255, 255))
local dragStart
local startPosition
local dragging = false
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = mainFrame.Position
    end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

local minimized = false
minButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    mainFrame.Size = minimized and UDim2.fromOffset(430, 48) or UDim2.fromOffset(430, 225)
end)
local function closeMenuNow()
    cleanupAll()
    menuGui.Enabled = false
    menuGui:Destroy()
end
closeButton.MouseButton1Click:Connect(closeMenuNow)
closeButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then closeMenuNow() end
end)
closeButton.Activated:Connect(closeMenuNow)
menuGui.Destroying:Connect(cleanupAll)
menuGui.AncestryChanged:Connect(function(_, parent)
    if not parent then cleanupAll() end
end)
while running and task.wait(0.1) do
    local currentPlayers = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            currentPlayers[player] = true
            local role, color = getRoleTool(player)
            updateTracker(player, role, color)
        end
    end

    for player, tracker in pairs(tracked) do
        if not currentPlayers[player] then
            tracker:Destroy()
            tracked[player] = nil
            clearHighlight(player)
        end
    end
end