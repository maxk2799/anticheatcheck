--[[
    ANTI-CHEAT TESTER
    Studio-only client testing harness
    Place in:
    StarterPlayer > StarterPlayerScripts
    Categories:
        Combat (aimbot, triggerbot)
        Visuals (ESP, tracers, boxes, x-ray, hitboxes)
        Movement
        Stats
    This does NOT:
        - discover/fire arbitrary game remotes
        - perform OS mouse clicks
        - run outside Roblox Studio
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    return
end
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera
-- Remove old copy if script restarts
local oldGui = PlayerGui:FindFirstChild("AntiCheatTesterGUI")
if oldGui then
    oldGui:Destroy()
end

-- =========================================================
-- SETTINGS

-- =========================================================
local Settings = {
    -- Combat
    AimEnabled = false,
    TriggerbotEnabled = false,
    ESPEnabled = false,
    TargetedESPEnabled = false,
    ESPLabelsEnabled = true,
    InventoryInspectEnabled = false,
    TargetESPUserId = nil,
    WallCheck = true,
    FreecamEnabled = false,
    FreecamSpeed = 75,
    FOV = 200,
    Smoothness = 1,
    AimPart = "Head", -- Head / Chest / Root
    AimMode = "Smooth", -- Smooth / Snap / Soft
    AimKey = "Always", -- Always / Hold RMB
    AimPriority = "Crosshair", -- Crosshair / Distance / Health
    StickyAim = false,
    TeamCheck = false,
    SoftStrength = 35, -- percent of normal pull
    Prediction = 0, -- seconds of velocity lead
    TriggerKey = "Always", -- Always / Hold RMB
    TriggerDelay = 0, -- ms before the first shot
    TriggerCooldown = 0.12,
    PeekPrefire = false,
    PeekLead = 8, -- studs ahead of a hidden player's movement
    PeekCover = 14, -- max studs of cover between the player and the wall face
    -- Visuals
    ESPLines = false,
    ESPBoxes = false,
    XRayEnabled = false,
    HitboxEnabled = false,
    HitboxSize = 10,
    -- Movement
    SpeedEnabled = false,
    WalkSpeed = 100,
    FlyEnabled = false,
    FlySpeed = 90,
    NoclipEnabled = false,
    JumpEnabled = false,
    JumpPower = 100,
    InfiniteJump = false,
    TeleportDistance = 50,
    ClickTeleport = false,
    CFrameSpeedEnabled = false,
    CFrameSpeed = 60,
    DashSpeed = 200,
    SpinEnabled = false,
    SpinSpeed = 3000 -- degrees/sec; 50000 maximum
}
local State = {
    FlyKeys = {},
    FreecamKeys = {},
    FreecamPosition = nil,
    FreecamYaw = 0,
    FreecamPitch = 0,
    FreecamLooking = false,
    HumanoidDefaults = {},
    OriginalCollisions = {},
    LastTrigger = 0,
    TriggerSince = nil,
    PeekHidden = {},
    StickyTarget = nil,
    RightMouseDown = false,
    PlayerLabels = {},
    Highlights = {},
    Drawings = {},
    HitboxOriginals = {},
    XRayParts = {}
}

-- =========================================================
-- CHARACTER HELPERS

-- =========================================================
local function getCharacter()
    return LocalPlayer.Character
end
local function getHumanoid()
    local character = getCharacter()
    if not character then
        return nil
    end
    return character:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local character = getCharacter()
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end
local function isAlive(model)
    if not model then
        return false
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end
local function sameTeam(player)
    return Settings.TeamCheck and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
end

-- =========================================================
-- GUI

-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "AntiCheatTesterGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = PlayerGui
local connections = {}
local running = true
local function connect(signal, callback)
    local connection = signal:Connect(function(...)
        if running then callback(...) end
    end)
    table.insert(connections, connection)
    return connection
end
local Theme = {
    Bg = Color3.fromRGB(8, 12, 18),
    Raised = Color3.fromRGB(22, 28, 38),
    RaisedHover = Color3.fromRGB(36, 46, 60),
    Line = Color3.fromRGB(186, 204, 224),
    Text = Color3.fromRGB(244, 247, 252),
    Muted = Color3.fromRGB(198, 208, 220),
    Accent = Color3.fromRGB(120, 210, 255),
    On = Color3.fromRGB(72, 220, 160),
    Danger = Color3.fromRGB(255, 110, 124),
    Panel = 0.52,
    Surface = 0.58,
    Stroke = 0.28,
}
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end
local function addStroke(parent, color)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Line
    stroke.Thickness = 1
    stroke.Transparency = Theme.Stroke
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end
local function ink(label)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.4
end
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(468, 640)
main.Position = UDim2.new(0, 24, 0.5, -320)
main.BackgroundColor3 = Theme.Bg
main.BackgroundTransparency = Theme.Panel
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
addCorner(main, 14)
local title = Instance.new("Frame")
title.Name = "Header"
title.Size = UDim2.new(1, 0, 0, 56)
title.BackgroundTransparency = 1
title.Active = true
title.Parent = main
local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Position = UDim2.fromOffset(12, 60)
tabBar.Size = UDim2.new(1, -24, 0, 34)
tabBar.BackgroundColor3 = Theme.Bg
tabBar.BackgroundTransparency = Theme.Surface
tabBar.BorderSizePixel = 0
tabBar.Parent = main
addCorner(tabBar, 8)
do
    addStroke(main)
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(1, 0, 0, 3)
    accentBar.BackgroundColor3 = Theme.Accent
    accentBar.BackgroundTransparency = 0.2
    accentBar.BorderSizePixel = 0
    accentBar.Parent = main
    local titleText = Instance.new("TextLabel")
    titleText.BackgroundTransparency = 1
    titleText.Position = UDim2.fromOffset(16, 10)
    titleText.Size = UDim2.new(1, -32, 0, 22)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 16
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.TextColor3 = Theme.Text
    titleText.Text = "Anti-Cheat Tester"
    ink(titleText)
    titleText.Parent = title
    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.fromOffset(16, 32)
    subtitle.Size = UDim2.new(1, -32, 0, 16)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Theme.Muted
    subtitle.Text = "Right Shift hides the panel and overlays"
    ink(subtitle)
    subtitle.Parent = title
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabBar
    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 4)
    tabPad.PaddingRight = UDim.new(0, 4)
    tabPad.Parent = tabBar
end
local tabButtons = {}

-- =========================================================
-- LOG

-- =========================================================
local logBox = Instance.new("TextLabel")
logBox.Size = UDim2.new(1, -24, 0, 86)
logBox.Position = UDim2.new(0, 12, 1, -98)
logBox.BackgroundColor3 = Theme.Bg
logBox.BackgroundTransparency = Theme.Surface
logBox.BorderSizePixel = 0
logBox.Text = "Waiting for a test."
logBox.TextColor3 = Color3.fromRGB(186, 198, 214)
logBox.TextSize = 12
logBox.Font = Enum.Font.Code
logBox.TextWrapped = true
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
ink(logBox)
logBox.Parent = main
addCorner(logBox, 8)
addStroke(logBox)
do
    local logCaption = Instance.new("TextLabel")
    logCaption.BackgroundTransparency = 1
    logCaption.Position = UDim2.new(0, 16, 1, -118)
    logCaption.Size = UDim2.new(1, -32, 0, 16)
    logCaption.Font = Enum.Font.GothamBold
    logCaption.TextSize = 11
    logCaption.TextXAlignment = Enum.TextXAlignment.Left
    logCaption.TextColor3 = Theme.Muted
    logCaption.Text = "ACTIVITY"
    ink(logCaption)
    logCaption.Parent = main
    local logPad = Instance.new("UIPadding")
    logPad.PaddingTop = UDim.new(0, 8)
    logPad.PaddingLeft = UDim.new(0, 10)
    logPad.PaddingRight = UDim.new(0, 10)
    logPad.Parent = logBox
end
local logLines = {}
local function log(message)
    table.insert(logLines, string.format("%6.1f   %s", os.clock(), tostring(message)))
    while #logLines > 5 do
        table.remove(logLines, 1)
    end
    logBox.Text = table.concat(logLines, "\n")
    print("[AntiCheatTester]", message)
end

-- =========================================================
-- PAGE AREA

-- =========================================================
local pageArea = Instance.new("Frame")
pageArea.Size = UDim2.new(1, -24, 1, -230)
pageArea.Position = UDim2.fromOffset(12, 104)
pageArea.BackgroundTransparency = 1
pageArea.Parent = main
local pages = {}
local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Theme.Accent
    page.ScrollBarImageTransparency = 0.35
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = pageArea
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = page
    pages[name] = page
    return page
end
local function showPage(name)
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
    for tabName, tab in pairs(tabButtons) do
        local selected = tabName == name
        tab.BackgroundTransparency = selected and 0.35 or 1
        tab.BackgroundColor3 = Theme.Accent
        tab.TextColor3 = selected and Theme.Text or Theme.Muted
    end
end
local navInfo = {
    ["Combat Tests"] = "Aimbot modes and triggerbot",
    ["Visual Tests"] = "ESP, tracers, boxes, x-ray, hitboxes",
    ["Movement Tests"] = "Speed, fly, noclip, teleports, and spin",
    ["Stats Scanner"] = "Scan and edit local player stats",
}
local dangerButtons = {
    ["STOP SPIN"] = true,
    ["Disable All Tests"] = true,
}
local function makeButton(parent, text)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 13
    button.Text = text
    button.TextColor3 = Theme.Text
    button.LayoutOrder = #parent:GetChildren()
    button.Parent = parent
    local toggleName = string.match(text, "^(.*): ON$") or string.match(text, "^(.*): OFF$")
    local navDetail = navInfo[text]
    if toggleName then
        button.Size = UDim2.new(1, -4, 0, 40)
        button.TextTransparency = 1
        button.BackgroundColor3 = Theme.Raised
        button.BackgroundTransparency = Theme.Surface
        addCorner(button, 8)
        addStroke(button)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(12, 0)
        nameLabel.Size = UDim2.new(1, -78, 1, 0)
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.TextColor3 = Theme.Text
        ink(nameLabel)
        nameLabel.Parent = button
        local pill = Instance.new("Frame")
        pill.AnchorPoint = Vector2.new(1, 0.5)
        pill.Position = UDim2.new(1, -8, 0.5, 0)
        pill.Size = UDim2.fromOffset(48, 22)
        pill.BackgroundTransparency = 0.2
        pill.BorderSizePixel = 0
        pill.Parent = button
        addCorner(pill, 11)
        local pillText = Instance.new("TextLabel")
        pillText.BackgroundTransparency = 1
        pillText.Size = UDim2.fromScale(1, 1)
        pillText.Font = Enum.Font.GothamBold
        pillText.TextSize = 11
        pillText.Parent = pill
        local function refreshToggle()
            local labelText, state = string.match(button.Text, "^(.*): (ON)$")
            if not labelText then
                labelText, state = string.match(button.Text, "^(.*): (OFF)$")
            end
            local on = state == "ON"
            nameLabel.Text = labelText or button.Text
            pillText.Text = on and "ON" or "OFF"
            pillText.TextColor3 = on and Color3.fromRGB(8, 32, 24) or Color3.fromRGB(198, 206, 216)
            pill.BackgroundColor3 = on and Theme.On or Color3.fromRGB(58, 68, 82)
            button.BackgroundColor3 = on and Color3.fromRGB(16, 42, 36) or Theme.Raised
            button.BackgroundTransparency = Theme.Surface
        end
        refreshToggle()
        button:GetPropertyChangedSignal("Text"):Connect(refreshToggle)
    elseif navDetail then
        button.Size = UDim2.new(1, -4, 0, 64)
        button.TextTransparency = 1
        button.BackgroundColor3 = Theme.Raised
        button.BackgroundTransparency = Theme.Surface
        addCorner(button, 10)
        addStroke(button)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, -18)
        bar.Position = UDim2.fromOffset(0, 9)
        bar.BackgroundColor3 = Theme.Accent
        bar.BorderSizePixel = 0
        bar.Parent = button
        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(16, 10)
        nameLabel.Size = UDim2.new(1, -46, 0, 20)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 15
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Theme.Text
        nameLabel.Text = text
        ink(nameLabel)
        nameLabel.Parent = button
        local detail = Instance.new("TextLabel")
        detail.BackgroundTransparency = 1
        detail.Position = UDim2.fromOffset(16, 32)
        detail.Size = UDim2.new(1, -46, 0, 18)
        detail.Font = Enum.Font.Gotham
        detail.TextSize = 12
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextColor3 = Theme.Muted
        detail.Text = navDetail
        ink(detail)
        detail.Parent = button
        local chevron = Instance.new("TextLabel")
        chevron.BackgroundTransparency = 1
        chevron.AnchorPoint = Vector2.new(1, 0.5)
        chevron.Position = UDim2.new(1, -12, 0.5, 0)
        chevron.Size = UDim2.fromOffset(16, 20)
        chevron.Font = Enum.Font.GothamBold
        chevron.TextSize = 16
        chevron.TextColor3 = Theme.Accent
        chevron.Text = ">"
        chevron.Parent = button
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Theme.RaisedHover
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Theme.Raised
        end)
    elseif dangerButtons[text] then
        button.Size = UDim2.new(1, -4, 0, 36)
        button.BackgroundColor3 = Theme.Danger
        button.BackgroundTransparency = 0.35
        button.TextColor3 = Theme.Text
        button.Font = Enum.Font.GothamBold
        button.TextXAlignment = Enum.TextXAlignment.Center
        ink(button)
        addCorner(button, 8)
        addStroke(button, Theme.Danger)
    elseif string.sub(text, 1, 1) == "<" then
        button.Size = UDim2.new(1, -4, 0, 26)
        button.BackgroundTransparency = 1
        button.TextColor3 = Theme.Accent
        button.TextXAlignment = Enum.TextXAlignment.Left
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 2)
        pad.Parent = button
    else
        button.Size = UDim2.new(1, -4, 0, 36)
        button.BackgroundColor3 = Theme.Raised
        button.BackgroundTransparency = Theme.Surface
        button.TextXAlignment = Enum.TextXAlignment.Center
        ink(button)
        addCorner(button, 8)
        addStroke(button)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Theme.RaisedHover
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Theme.Raised
        end)
    end
    return button
end
local function refreshLabel(label)
    local text = label.Text
    local heading = not string.find(text, "%l") and #text >= 8
    if heading then
        label.Size = UDim2.new(1, -4, 0, 28)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextColor3 = Theme.Accent
    elseif string.find(text, "FOUND", 1, true)
        or string.find(text, "LOCAL READBACK", 1, true)
        or string.find(text, "matched", 1, true)
        or string.find(text, "restored", 1, true) then
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextColor3 = Theme.On
    elseif string.find(text, "not confirmed", 1, true)
        or string.find(text, "could not", 1, true) then
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextColor3 = Theme.Danger
    elseif string.find(text, "Active stat:", 1, true)
        or string.find(text, "Value:", 1, true)
        or string.find(text, "ESP target:", 1, true)
        or string.find(text, "WalkSpeed:", 1, true)
        or string.find(text, "Speed:", 1, true)
        or string.find(text, "Power:", 1, true)
        or string.find(text, "Distance:", 1, true)
        or string.find(text, "Smoothness:", 1, true)
        or string.find(text, "FOV:", 1, true) then
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.TextColor3 = Theme.Text
    else
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextColor3 = Theme.Muted
    end
end
local function makeLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.LayoutOrder = #parent:GetChildren()
    ink(label)
    label.Parent = parent
    refreshLabel(label)
    label:GetPropertyChangedSignal("Text"):Connect(function()
        refreshLabel(label)
    end)
    return label
end
local function styleField(box)
    box.BackgroundColor3 = Theme.Raised
    box.BackgroundTransparency = Theme.Surface
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.TextColor3 = Theme.Text
    box.PlaceholderColor3 = Theme.Muted
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 13
    ink(box)
    addCorner(box, 8)
    addStroke(box)
end
local function makeTextBox(parent, text)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -4, 0, 36)
    box.Text = text
    box.PlaceholderText = "Enter value"
    box.LayoutOrder = #parent:GetChildren()
    box.Parent = parent
    styleField(box)
    return box
end
-- Luau allows 200 locals per function, and this whole script is one chunk.
-- Steppers wire their own buttons so each one costs no top-level locals.
local function stepSetting(key, amount, minimum, maximum)
    return function(direction)
        local value = math.clamp(Settings[key] + direction * amount, minimum, maximum)
        Settings[key] = math.floor(value * 1000 + 0.5) / 1000
    end
end
local function showSetting(prefix, key, suffix)
    return function()
        return prefix .. Settings[key] .. (suffix or "")
    end
end
local function makeStepper(parent, format, step)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, -4, 0, 36)
    row.LayoutOrder = #parent:GetChildren()
    row.Parent = parent
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -84, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Theme.Text
    label.Text = format()
    ink(label)
    label.Parent = row
    local function stepButton(symbol, offset, direction)
        local button = Instance.new("TextButton")
        button.AutoButtonColor = false
        button.Size = UDim2.fromOffset(36, 32)
        button.AnchorPoint = Vector2.new(1, 0.5)
        button.Position = UDim2.new(1, offset, 0.5, 0)
        button.BackgroundColor3 = Theme.Raised
        button.BackgroundTransparency = Theme.Surface
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 16
        button.TextColor3 = Theme.Text
        button.Text = symbol
        ink(button)
        button.Parent = row
        addCorner(button, 8)
        addStroke(button)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Theme.RaisedHover
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Theme.Raised
        end)
        connect(button.MouseButton1Click, function()
            step(direction)
            label.Text = format()
        end)
    end
    stepButton("-", -40, -1)
    stepButton("+", 0, 1)
    return label
end
local function makeInlineField(parent, boxText, buttonText)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, -4, 0, 36)
    row.LayoutOrder = #parent:GetChildren()
    row.Parent = parent
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -118, 1, 0)
    box.Text = boxText
    box.PlaceholderText = "Enter value"
    box.Parent = row
    styleField(box)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.AnchorPoint = Vector2.new(1, 0)
    button.Position = UDim2.new(1, 0, 0, 0)
    button.Size = UDim2.fromOffset(108, 36)
    button.BackgroundColor3 = Theme.Accent
    button.BackgroundTransparency = 0.28
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.TextColor3 = Theme.Text
    button.Text = buttonText
    ink(button)
    button.Parent = row
    addCorner(button, 8)
    addStroke(button, Theme.Accent)
    return box, button
end
local function makeCycle(parent, labelText, options, initial, onChange)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -4, 0, 40)
    button.BackgroundColor3 = Theme.Raised
    button.BackgroundTransparency = Theme.Surface
    button.Text = ""
    button.LayoutOrder = #parent:GetChildren()
    button.Parent = parent
    addCorner(button, 8)
    addStroke(button)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.fromOffset(12, 0)
    nameLabel.Size = UDim2.new(1, -130, 1, 0)
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextColor3 = Theme.Text
    nameLabel.Text = labelText
    ink(nameLabel)
    nameLabel.Parent = button
    local pill = Instance.new("Frame")
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.Position = UDim2.new(1, -8, 0.5, 0)
    pill.Size = UDim2.fromOffset(104, 24)
    pill.BackgroundColor3 = Color3.fromRGB(20, 48, 66)
    pill.BackgroundTransparency = 0.35
    pill.BorderSizePixel = 0
    pill.Parent = button
    addCorner(pill, 12)
    local pillText = Instance.new("TextLabel")
    pillText.BackgroundTransparency = 1
    pillText.Size = UDim2.fromScale(1, 1)
    pillText.Font = Enum.Font.GothamBold
    pillText.TextSize = 11
    pillText.TextColor3 = Theme.Accent
    pillText.Parent = pill
    local index = table.find(options, initial) or 1
    pillText.Text = options[index]
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Theme.RaisedHover
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Theme.Raised
    end)
    connect(button.MouseButton1Click, function()
        index = index % #options + 1
        pillText.Text = options[index]
        onChange(options[index])
    end)
    return button
end
local function addTab(name, label, order)
    local tab = Instance.new("TextButton")
    tab.Name = name
    tab.Size = UDim2.fromOffset(84, 26)
    tab.BackgroundColor3 = Theme.Accent
    tab.BackgroundTransparency = 1
    tab.BorderSizePixel = 0
    tab.AutoButtonColor = false
    tab.Font = Enum.Font.GothamBold
    tab.TextSize = 12
    tab.Text = label
    tab.TextColor3 = Theme.Muted
    ink(tab)
    tab.LayoutOrder = order
    tab.Parent = tabBar
    addCorner(tab, 6)
    tabButtons[name] = tab
    connect(tab.MouseButton1Click, function()
        showPage(name)
    end)
end
addTab("Menu", "Home", 1)
addTab("Combat", "Combat", 2)
addTab("Visuals", "Visuals", 3)
addTab("Movement", "Move", 4)
addTab("Stats", "Stats", 5)

-- =========================================================
-- MAIN MENU

-- =========================================================
local menuPage =
    createPage("Menu")
local combatPresetButton = makeButton(menuPage, "Enemy Combat Preset: ON")
makeLabel(
    menuPage,
    "Auto Aim, highlights, and tracers for enemies."
)
makeLabel(
    menuPage,
    "Pick a category, or use the tabs above."
)
local combatMenuButton =
    makeButton(
        menuPage,
        "Combat Tests"
    )
local movementMenuButton =
    makeButton(
        menuPage,
        "Movement Tests"
    )
-- =========================================================
-- COMBAT PAGE

-- =========================================================
local visualsMenuButton = makeButton(menuPage, "Visual Tests")
local statsMenuButton = makeButton(menuPage, "Stats Scanner")
local disableAllButton = makeButton(menuPage, "Disable All Tests")
local combatPage = createPage("Combat")
local combatBack = makeButton(combatPage, "< Back")
makeLabel(combatPage, "AIMBOT CONTROLS")
local aimButton = makeButton(combatPage, "Auto Aim: OFF")
makeCycle(combatPage, "Target part", {"Head", "Chest", "Root"}, Settings.AimPart, function(value)
    Settings.AimPart = value
end)
makeCycle(combatPage, "Aim mode", {"Smooth", "Snap", "Soft"}, Settings.AimMode, function(value)
    Settings.AimMode = value
end)
makeCycle(combatPage, "Activation", {"Always", "Hold RMB"}, Settings.AimKey, function(value)
    Settings.AimKey = value
    State.StickyTarget = nil
end)
makeCycle(combatPage, "Target priority", {"Crosshair", "Distance", "Health"}, Settings.AimPriority, function(value)
    Settings.AimPriority = value
    State.StickyTarget = nil
end)
local stickyButton = makeButton(combatPage, "Sticky Aim: OFF")
local teamCheckButton = makeButton(combatPage, "Team Check: OFF")
local wallCheckButton = makeButton(combatPage, "Aim Wall Check: ON")
makeStepper(combatPage, showSetting("FOV: ", "FOV"), stepSetting("FOV", 20, 20, 500))
makeStepper(combatPage, showSetting("Smoothness: ", "Smoothness"), stepSetting("Smoothness", 1, 1, 30))
makeStepper(combatPage, showSetting("Soft Aim Strength: ", "SoftStrength", "%"), stepSetting("SoftStrength", 5, 5, 100))
makeStepper(combatPage, showSetting("Prediction: ", "Prediction", "s"), stepSetting("Prediction", 0.05, 0, 0.5))
makeLabel(combatPage, "Soft mode pulls gently toward the target; Snap locks instantly.")
makeLabel(combatPage, "TRIGGERBOT")
local triggerButton = makeButton(combatPage, "Triggerbot (Equipped Tool): OFF")
makeCycle(combatPage, "Activation", {"Always", "Hold RMB"}, Settings.TriggerKey, function(value)
    Settings.TriggerKey = value
    State.TriggerSince = nil
end)
makeStepper(combatPage, showSetting("Reaction Delay: ", "TriggerDelay", " ms"), stepSetting("TriggerDelay", 25, 0, 1000))
makeStepper(combatPage, function()
    return "Fire Interval: " .. math.floor(Settings.TriggerCooldown * 1000 + 0.5) .. " ms"
end, stepSetting("TriggerCooldown", 0.02, 0.01, 2))
makeLabel(combatPage, "Fires the equipped Tool while the crosshair is on a player.")
makeLabel(combatPage, "PEEK PREFIRE")
local peekButton = makeButton(combatPage, "Peek Prefire: OFF")
makeStepper(combatPage, showSetting("Peek Lead: ", "PeekLead"), stepSetting("PeekLead", 1, 2, 30))
makeStepper(combatPage, showSetting("Cover Range: ", "PeekCover"), stepSetting("PeekCover", 2, 4, 40))
makeLabel(combatPage, "Fires at the open side of a wall when a hidden player moves into it.")

-- =========================================================
-- VISUALS PAGE

-- =========================================================
local visualsPage = createPage("Visuals")
local visualsBack = makeButton(visualsPage, "< Back")
makeLabel(visualsPage, "ESP OVERLAYS")
local espButton = makeButton(visualsPage, "Player Highlights: OFF")
local espLinesButton = makeButton(visualsPage, "Tracer Lines: OFF")
local espBoxesButton = makeButton(visualsPage, "2D Boxes: OFF")
local espLabelsButton = makeButton(visualsPage, "Username / HP Labels: ON")
local xrayButton = makeButton(visualsPage, "X-Ray Walls: OFF")
makeLabel(visualsPage, "HITBOX EXPANDER")
local hitboxButton = makeButton(visualsPage, "Hitbox Expander: OFF")
makeStepper(visualsPage, showSetting("Hitbox Size: ", "HitboxSize"), stepSetting("HitboxSize", 2, 2, 60))
makeLabel(visualsPage, "Enlarges other players' root parts on this client only.")

-- =========================================================
-- MOVEMENT PAGE

-- =========================================================
local movementPage =
    createPage("Movement")
local movementBack =
    makeButton(
        movementPage,
        "< Back"
    )
local freecamButton =
    makeButton(
        movementPage,
        "Freecam: OFF"
    )
makeStepper(movementPage, showSetting("Freecam Speed: ", "FreecamSpeed"), stepSetting("FreecamSpeed", 10, 5, 1000))
makeLabel(
    movementPage,
    "MOVEMENT TESTS"
)
local speedButton =
    makeButton(
        movementPage,
        "Speed Alterer: OFF"
    )
local speedBox, applySpeed =
    makeInlineField(movementPage, tostring(Settings.WalkSpeed), "Apply")
local speedLabel = makeStepper(movementPage, showSetting("WalkSpeed: ", "WalkSpeed"), function(direction)
    stepSetting("WalkSpeed", 10, 0, 1000)(direction)
    speedBox.Text = tostring(Settings.WalkSpeed)
end)
local flyButton =
    makeButton(
        movementPage,
        "Fly: OFF"
    )
makeStepper(movementPage, showSetting("Fly Speed: ", "FlySpeed"), stepSetting("FlySpeed", 10, 10, 500))
local noclipButton =
    makeButton(
        movementPage,
        "Noclip: OFF"
    )
local highJumpButton =
    makeButton(
        movementPage,
        "High Jump: OFF"
    )
makeStepper(movementPage, showSetting("Jump Power: ", "JumpPower"), stepSetting("JumpPower", 10, 0, 500))
local infiniteJumpButton =
    makeButton(
        movementPage,
        "Infinite Jump: OFF"
    )
makeStepper(movementPage, showSetting("Teleport Distance: ", "TeleportDistance"),
    stepSetting("TeleportDistance", 50, 10, 10000))
local teleportButton =
    makeButton(
        movementPage,
        "Teleport Forward"
    )
local teleportTargetButton = makeButton(movementPage, "Teleport to ESP Target")
local clickTeleportButton = makeButton(movementPage, "Ctrl+Click Teleport: OFF")
makeLabel(movementPage, "CFRAME MOVEMENT")
local cframeSpeedButton = makeButton(movementPage, "CFrame Speed: OFF")
makeStepper(movementPage, showSetting("CFrame Speed: ", "CFrameSpeed"), stepSetting("CFrameSpeed", 10, 10, 1000))
makeLabel(movementPage, "Moves the root by CFrame each frame instead of WalkSpeed.")
makeStepper(movementPage, showSetting("Dash Velocity: ", "DashSpeed"), stepSetting("DashSpeed", 50, 50, 2000))
local dashButton = makeButton(movementPage, "Dash Forward")

-- =========================================================
-- FOV DISPLAY

-- =========================================================
local fovCircle =
    Instance.new("Frame")
fovCircle.AnchorPoint =
    Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Visible = false
fovCircle.Parent = gui
local circleCorner =
    Instance.new("UICorner")
circleCorner.CornerRadius =
    UDim.new(1, 0)
circleCorner.Parent =
    fovCircle
local circleStroke =
    Instance.new("UIStroke")
circleStroke.Thickness = 1.5
circleStroke.Color = Color3.fromRGB(92, 196, 255)
circleStroke.Transparency = 0.15
circleStroke.Parent =
    fovCircle

-- =========================================================
-- TARGETING

-- =========================================================
local function getAimPart(model)
    if not model then
        return nil
    end
    if Settings.AimPart == "Chest" then
        return model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
            or model:FindFirstChild("HumanoidRootPart")
    elseif Settings.AimPart == "Root" then
        return model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Head")
    end
    return model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
end
local function predictedPosition(part)
    if Settings.Prediction <= 0 then
        return part.Position
    end
    return part.Position + part.AssemblyLinearVelocity * Settings.Prediction
end
local function aimKeyHeld()
    return Settings.AimKey == "Always" or State.RightMouseDown
end
local function targetVisible(part, model)
    if not Settings.WallCheck then
        return true
    end
    local character =
        getCharacter()
    local parameters =
        RaycastParams.new()
    parameters.FilterType =
        Enum.RaycastFilterType.Exclude
    parameters.FilterDescendantsInstances =
        character and {character} or {}
    parameters.IgnoreWater = true
    local origin =
        Camera.CFrame.Position
    local result =
        workspace:Raycast(
            origin,
            part.Position - origin,
            parameters
        )
    if not result then
        return true
    end
    return result.Instance:
        IsDescendantOf(model)
end
-- Pixel distance from the crosshair, or nil when the part is off screen / outside the FOV circle.
local function crosshairDistance(part, center, limit)
    local point, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen or point.Z <= 0 then
        return nil
    end
    local distance = (Vector2.new(point.X, point.Y) - center).Magnitude
    if distance > limit then
        return nil
    end
    return distance
end
local function candidateScore(part, center)
    local pixels = crosshairDistance(part, center, Settings.FOV)
    if not pixels then
        return nil
    end
    if Settings.AimPriority == "Distance" then
        return (part.Position - Camera.CFrame.Position).Magnitude
    elseif Settings.AimPriority == "Health" then
        local humanoid = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.Health or math.huge
    end
    return pixels
end
local function acquireTarget()
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil, nil
    end
    local center = Camera.ViewportSize / 2
    if Settings.StickyAim and State.StickyTarget then
        local model = State.StickyTarget
        local player = Players:GetPlayerFromCharacter(model)
        local part = getAimPart(model)
        if player and player.Parent and isAlive(model) and part and not sameTeam(player)
            and crosshairDistance(part, center, Settings.FOV * 1.5)
            and targetVisible(part, model) then
            return model, part
        end
        State.StickyTarget = nil
    end
    local bestModel, bestPart, bestScore = nil, nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not sameTeam(player) then
            local character = player.Character
            if character and isAlive(character) then
                local part = getAimPart(character)
                if part then
                    local score = candidateScore(part, center)
                    if score and score < bestScore and targetVisible(part, character) then
                        bestScore, bestModel, bestPart = score, character, part
                    end
                end
            end
        end
    end
    if Settings.StickyAim then
        State.StickyTarget = bestModel
    end
    return bestModel, bestPart
end
local function updateAim(dt)
    if not Settings.AimEnabled or Settings.FreecamEnabled then
        return
    end
    if not aimKeyHeld() then
        State.StickyTarget = nil
        return
    end
    local model, part = acquireTarget()
    if not model or not part then
        return
    end
    local desired = CFrame.lookAt(Camera.CFrame.Position, predictedPosition(part))
    if Settings.AimMode == "Snap" then
        Camera.CFrame = desired
        return
    end
    local speed = math.clamp(20 / Settings.Smoothness, 0.5, 30)
    local alpha = math.clamp(dt * speed, 0, 1)
    if Settings.AimMode == "Soft" then
        alpha = alpha * (Settings.SoftStrength / 100)
    end
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end

-- =========================================================
-- ESP

-- =========================================================
local function clearESP()
    for _, highlight in pairs(
        State.Highlights
    ) do
        if highlight then
            highlight:Destroy()
        end
    end
    table.clear(State.Highlights)
    for _, entry in pairs(State.PlayerLabels) do entry.Gui:Destroy() end
    table.clear(State.PlayerLabels)
end
-- Targeted ESP works independently of normal ESP. With both enabled,
-- the selected player is gold and everyone else is blue.
makeLabel(visualsPage, "TARGETED ESP (GOLD)")
makeLabel(visualsPage, "Enter exact username or UserId (not display name)")
local targetESPBox = makeTextBox(visualsPage, "")
targetESPBox.PlaceholderText = "Username or UserId"
local targetESPLabel = makeLabel(visualsPage, "ESP target: none")
local selectESPButton = makeButton(visualsPage, "Select ESP Player")
local nextESPButton = makeButton(visualsPage, "Next ESP Player")
local targetedESPButton = makeButton(visualsPage, "Targeted ESP: OFF")
local clearESPButton = makeButton(visualsPage, "Clear ESP Target")
makeLabel(visualsPage, "INVENTORY")
local inventoryButton = makeButton(visualsPage, "Look-at Inventory: OFF")
makeLabel(visualsPage, "Aim the screen center at a player; visible Tools only.")

-- 2D tracers and boxes are redrawn every frame from screen projections.
local drawLayer = Instance.new("Frame")
drawLayer.Name = "Drawings"
drawLayer.Size = UDim2.fromScale(1, 1)
drawLayer.BackgroundTransparency = 1
drawLayer.ZIndex = 0
drawLayer.Parent = gui
local function getDrawing(player)
    local entry = State.Drawings[player]
    if entry then
        return entry
    end
    local line = Instance.new("Frame")
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BorderSizePixel = 0
    line.Visible = false
    line.Parent = drawLayer
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = drawLayer
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Parent = box
    entry = {Line = line, Box = box, Stroke = stroke}
    State.Drawings[player] = entry
    return entry
end
local function destroyDrawing(player, entry)
    entry.Line:Destroy()
    entry.Box:Destroy()
    State.Drawings[player] = nil
end
local function clearDrawings()
    for player, entry in pairs(State.Drawings) do
        destroyDrawing(player, entry)
    end
end
local boxCorners = {}
for _, x in ipairs({-1, 1}) do
    for _, y in ipairs({-1, 1}) do
        for _, z in ipairs({-1, 1}) do
            table.insert(boxCorners, Vector3.new(x, y, z))
        end
    end
end
local function updateDrawings()
    if not main.Visible then
        for _, entry in pairs(State.Drawings) do
            entry.Line.Visible = false
            entry.Box.Visible = false
        end
        return
    end
    if not Settings.ESPLines and not Settings.ESPBoxes then
        if next(State.Drawings) then
            clearDrawings()
        end
        return
    end
    local viewport = Camera.ViewportSize
    local origin = Vector2.new(viewport.X / 2, viewport.Y)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local entry = getDrawing(player)
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local shown = false
            if root and isAlive(character) and not sameTeam(player) then
                local point, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen and point.Z > 0 then
                    shown = true
                    local targeted = Settings.TargetedESPEnabled and player.UserId == Settings.TargetESPUserId
                    local color = targeted and Color3.fromRGB(255, 190, 35) or Color3.fromRGB(92, 196, 255)
                    if Settings.ESPLines then
                        local to = Vector2.new(point.X, point.Y)
                        local delta = to - origin
                        local middle = (origin + to) / 2
                        entry.Line.Visible = true
                        entry.Line.BackgroundColor3 = color
                        entry.Line.Position = UDim2.fromOffset(middle.X, middle.Y)
                        entry.Line.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
                        entry.Line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                    else
                        entry.Line.Visible = false
                    end
                    if Settings.ESPBoxes then
                        local boundsCFrame, boundsSize = character:GetBoundingBox()
                        local half = boundsSize / 2
                        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                        for _, corner in ipairs(boxCorners) do
                            local projected = Camera:WorldToViewportPoint(boundsCFrame:PointToWorldSpace(corner * half))
                            minX = math.min(minX, projected.X)
                            minY = math.min(minY, projected.Y)
                            maxX = math.max(maxX, projected.X)
                            maxY = math.max(maxY, projected.Y)
                        end
                        entry.Box.Visible = true
                        entry.Stroke.Color = color
                        entry.Box.Position = UDim2.fromOffset(minX, minY)
                        entry.Box.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
                    else
                        entry.Box.Visible = false
                    end
                end
            end
            if not shown then
                entry.Line.Visible = false
                entry.Box.Visible = false
            end
        end
    end
    for player, entry in pairs(State.Drawings) do
        if not player.Parent then
            destroyDrawing(player, entry)
        end
    end
end

-- Hitbox expander resizes other players' root parts on this client only.
local function restoreHitboxes()
    for root, original in pairs(State.HitboxOriginals) do
        if root.Parent then
            root.Size = original.Size
            root.Transparency = original.Transparency
            root.CanCollide = original.CanCollide
        end
    end
    table.clear(State.HitboxOriginals)
end
local function applyHitboxes()
    if not Settings.HitboxEnabled then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if player ~= LocalPlayer and root and not sameTeam(player) then
            if not State.HitboxOriginals[root] then
                State.HitboxOriginals[root] = {Size = root.Size, Transparency = root.Transparency,
                    CanCollide = root.CanCollide}
            end
            root.Size = Vector3.one * Settings.HitboxSize
            root.Transparency = 0.6
            root.CanCollide = false
        end
    end
end
local function setHitboxes(enabled)
    Settings.HitboxEnabled = enabled
    if enabled then
        applyHitboxes()
    else
        restoreHitboxes()
    end
end

-- X-ray uses LocalTransparencyModifier, which never replicates and resets cleanly.
local function setXRay(enabled)
    Settings.XRayEnabled = enabled
    for part in pairs(State.XRayParts) do
        if part.Parent then
            part.LocalTransparencyModifier = 0
        end
    end
    table.clear(State.XRayParts)
    if not enabled then
        return
    end
    local characters = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(characters, player.Character)
        end
    end
    local count = 0
    for _, part in ipairs(workspace:GetDescendants()) do
        if count >= 20000 then
            log("X-ray stopped at 20000 parts.")
            break
        end
        if part:IsA("BasePart") and not part:IsA("Terrain") and part.Transparency < 0.5 then
            local inCharacter = false
            for _, character in ipairs(characters) do
                if part:IsDescendantOf(character) then
                    inCharacter = true
                    break
                end
            end
            if not inCharacter then
                part.LocalTransparencyModifier = 0.65
                State.XRayParts[part] = true
                count += 1
            end
        end
    end
    log("X-ray applied to " .. count .. " parts.")
end

-- Shared screen-pixel sizes for every player, with distance scaling.
-- Name text is smaller than HP; long names truncate instead of shrinking.
local function healthText(humanoid)
    return "HP: " .. math.ceil(math.max(0, humanoid.Health))
        .. " / " .. math.ceil(humanoid.MaxHealth)
end

local function updatePlayerLabel(player, entry)
    entry.Health.Text = healthText(entry.Humanoid)
    local camera = workspace.CurrentCamera
    local distance = camera and (entry.Head.Position - camera.CFrame.Position).Magnitude or 0
    local scale = math.clamp(80 / math.max(80, distance), 0.55, 1)
    entry.Gui.Size = UDim2.fromOffset(math.floor(240 * scale), math.floor(61 * scale))
    entry.Name.TextSize = math.floor(13 * scale)
    entry.Health.TextSize = math.max(14, math.floor(25 * scale))
end

local function createPlayerLabel(player, targeted)
    local character = player.Character
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not head or not head:IsA("BasePart") or not humanoid then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AntiCheatPlayerInfo"
    billboard.Adornee = head
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 10000
    billboard.Enabled = main.Visible
    billboard.Parent = gui
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Username"
    nameLabel.Size = UDim2.fromScale(1, 0.35)
    nameLabel.Position = UDim2.fromScale(0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextScaled = false
    nameLabel.TextWrapped = false
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextColor3 = targeted and Color3.fromRGB(255, 215, 75) or Color3.fromRGB(225, 240, 255)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Text = "@" .. player.Name
    nameLabel.Parent = billboard
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "Health"
    hpLabel.Position = UDim2.fromScale(0, 0.35)
    hpLabel.Size = UDim2.fromScale(1, 0.65)
    hpLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
    hpLabel.BackgroundTransparency = 0.25
    hpLabel.BorderSizePixel = 0
    hpLabel.Font = Enum.Font.GothamBold
    addCorner(hpLabel, 6)
    hpLabel.TextScaled = false
    hpLabel.TextWrapped = false
    hpLabel.TextColor3 = targeted and Color3.fromRGB(255, 215, 75) or Color3.fromRGB(225, 240, 255)
    hpLabel.TextStrokeTransparency = 0.3
    hpLabel.Parent = billboard
    local entry = {Gui=billboard, Name=nameLabel, Health=hpLabel, Humanoid=humanoid, Head=head}
    State.PlayerLabels[player] = entry
    updatePlayerLabel(player, entry)
end

local function refreshESP()
    clearESP()
    if not Settings.ESPEnabled and not Settings.TargetedESPEnabled then return end
    local selectedPresent = false
    for _, player in ipairs(Players:GetPlayers()) do
        local selected = player ~= LocalPlayer and player.UserId == Settings.TargetESPUserId
        if selected then
            selectedPresent = true
            targetESPLabel.Text = "ESP target: @" .. player.Name
        end
        local targeted = selected and Settings.TargetedESPEnabled
        if player ~= LocalPlayer and not sameTeam(player) and (Settings.ESPEnabled or targeted)
            and player.Character and isAlive(player.Character) then
            local highlight = Instance.new("Highlight")
            highlight.Name = targeted and "AntiCheatTargetESP" or "AntiCheatESP"
            highlight.Adornee = player.Character
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = targeted and Color3.fromRGB(255, 190, 35)
                or Color3.fromRGB(65, 165, 255)
            highlight.OutlineColor = targeted and Color3.fromRGB(255, 245, 160)
                or Color3.fromRGB(190, 225, 255)
            highlight.FillTransparency = targeted and 0.35 or 0.7
            highlight.OutlineTransparency = 0
            highlight.Parent = player.Character
            highlight.Enabled = main.Visible
            State.Highlights[player] = highlight
            if Settings.ESPLabelsEnabled then createPlayerLabel(player, targeted) end
        end
    end
    if Settings.TargetESPUserId and not selectedPresent then
        targetESPLabel.Text = "ESP target: offline (" .. Settings.TargetESPUserId .. ")"
    end
end

local function selectESPPlayer(player)
    Settings.TargetESPUserId = player.UserId
    targetESPBox.Text = player.Name
    targetESPLabel.Text = "ESP target: @" .. player.Name
    refreshESP()
    log("ESP target selected: @" .. player.Name)
end

connect(selectESPButton.MouseButton1Click, function()
    local query = targetESPBox.Text:match("^%s*(.-)%s*$"):gsub("^@", "")
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and (player.Name:lower() == query:lower()
            or tostring(player.UserId) == query) then
            selectESPPlayer(player)
            return
        end
    end
    log("No matching player. Enter an exact username or UserId.")
end)
connect(nextESPButton.MouseButton1Click, function()
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then table.insert(candidates, player) end
    end
    table.sort(candidates, function(a, b) return a.Name:lower() < b.Name:lower() end)
    if #candidates == 0 then log("No other players in this Studio session."); return end
    local nextIndex = 1
    for index, player in ipairs(candidates) do
        if player.UserId == Settings.TargetESPUserId then nextIndex = index % #candidates + 1; break end
    end
    selectESPPlayer(candidates[nextIndex])
end)
connect(targetedESPButton.MouseButton1Click, function()
    if not Settings.TargetedESPEnabled and not Settings.TargetESPUserId then
        log("Select an ESP player first."); return
    end
    Settings.TargetedESPEnabled = not Settings.TargetedESPEnabled
    targetedESPButton.Text = "Targeted ESP: " .. (Settings.TargetedESPEnabled and "ON" or "OFF")
    refreshESP()
end)
connect(espLabelsButton.MouseButton1Click, function()
    Settings.ESPLabelsEnabled = not Settings.ESPLabelsEnabled
    espLabelsButton.Text = "Username / HP Labels: " .. (Settings.ESPLabelsEnabled and "ON" or "OFF")
    refreshESP()
end)
connect(clearESPButton.MouseButton1Click, function()
    Settings.TargetESPUserId = nil
    Settings.TargetedESPEnabled = false
    targetESPBox.Text = ""
    targetESPLabel.Text = "ESP target: none"
    targetedESPButton.Text = "Targeted ESP: OFF"
    refreshESP()
end)

-- =========================================================
-- TRIGGERBOT SIMULATION

-- =========================================================
local triggerEvent =
    Instance.new("BindableEvent")
triggerEvent.Name =
    "AntiCheatTriggerTest"
triggerEvent.Parent = gui
local function getCrosshairTarget()
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil
    end
    local center =
        Camera.ViewportSize / 2
    local ray =
        Camera:ViewportPointToRay(
            center.X,
            center.Y
        )
    local parameters =
        RaycastParams.new()
    parameters.FilterType =
        Enum.RaycastFilterType.Exclude
    local character =
        getCharacter()
    parameters.FilterDescendantsInstances =
        character and {character} or {}
    local result =
        workspace:Raycast(
            ray.Origin,
            ray.Direction * 10000,
            parameters
        )
    if not result then
        return nil
    end
    local model = result.Instance
    while model and model ~= workspace do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then break end
        model = model.Parent
    end
    if
        model
        and model ~= character
        and isAlive(model)
    then
        return model
    end
    return nil
end
-- Client-only inventory inspection. Other players' Backpacks may not replicate.
-- No claim is made about hidden, saved, or server-only inventories.
local inventoryPanel = Instance.new("ScrollingFrame")
inventoryPanel.Name = "AntiCheatInventoryPanel"
inventoryPanel.AnchorPoint = Vector2.new(1, 0.5)
inventoryPanel.Position = UDim2.new(1, -20, 0.5, 0)
inventoryPanel.Size = UDim2.fromOffset(300, 260)
inventoryPanel.BackgroundColor3 = Theme.Bg
inventoryPanel.BackgroundTransparency = Theme.Panel
inventoryPanel.BorderSizePixel = 0
inventoryPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryPanel.CanvasSize = UDim2.new()
inventoryPanel.ScrollBarThickness = 4
inventoryPanel.ScrollBarImageColor3 = Theme.Accent
inventoryPanel.ScrollBarImageTransparency = 0.35
inventoryPanel.Visible = false
inventoryPanel.Parent = gui
addCorner(inventoryPanel, 12)
addStroke(inventoryPanel)
local inventoryText = Instance.new("TextLabel")
inventoryText.Position = UDim2.fromOffset(14, 12)
inventoryText.Size = UDim2.new(1, -28, 0, 0)
inventoryText.AutomaticSize = Enum.AutomaticSize.Y
inventoryText.BackgroundTransparency = 1
inventoryText.TextColor3 = Theme.Text
ink(inventoryText)
inventoryText.Font = Enum.Font.GothamMedium
inventoryText.TextSize = 13
inventoryText.TextWrapped = true
inventoryText.TextXAlignment = Enum.TextXAlignment.Left
inventoryText.TextYAlignment = Enum.TextYAlignment.Top
inventoryText.Parent = inventoryPanel

local function visibleTools(container)
    local names = {}
    if container then
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then table.insert(names, item.Name) end
        end
    end
    table.sort(names)
    return #names > 0 and table.concat(names, "\n") or "(no visible tools)"
end

local function updateInventoryInspection()
    inventoryPanel.Visible = Settings.InventoryInspectEnabled and main.Visible
    if not Settings.InventoryInspectEnabled then return end
    local character = getCrosshairTarget()
    local player = character and Players:GetPlayerFromCharacter(character)
    if not player or player == LocalPlayer then
        inventoryText.Text = "LOOK-AT INVENTORY\nAim the center of your screen at a player."
        return
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    inventoryText.Text = "@" .. player.Name .. "\nCLIENT-VISIBLE INVENTORY\n\nEquipped Tools:\n"
        .. visibleTools(character) .. "\n\nBackpack Tools:\n"
        .. (backpack and visibleTools(backpack) or "Unavailable on this client")
        .. "\n\nHidden/server inventory is not accessible here."
end

connect(inventoryButton.MouseButton1Click, function()
    Settings.InventoryInspectEnabled = not Settings.InventoryInspectEnabled
    inventoryButton.Text = "Look-at Inventory: " .. (Settings.InventoryInspectEnabled and "ON" or "OFF")
    updateInventoryInspection()
end)
local playerInfoTimer = 0
connect(RunService.Heartbeat, function(dt)
    playerInfoTimer += dt
    if playerInfoTimer < 0.1 then return end
    playerInfoTimer = 0
    for player, entry in pairs(State.PlayerLabels) do
        if entry.Humanoid.Parent and entry.Head.Parent and player.Parent then
            updatePlayerLabel(player, entry)
        else
            entry.Gui:Destroy()
            State.PlayerLabels[player] = nil
        end
    end
    updateInventoryInspection()
end)

-- Activate the equipped Tool through its normal Activated handler.
-- The weapon must implement firing through Tool.Activated. Its server still
-- controls ammunition, fire rate, hit validation, and damage.
local activeTriggerTool = nil
local lastToolMessage = -math.huge
local function releaseTriggerTool()
    if activeTriggerTool then
        pcall(function() activeTriggerTool:Deactivate() end)
        activeTriggerTool = nil
    end
end
local function tryActivateTool(target)
    local character = getCharacter()
    local humanoid = getHumanoid()
    if not character or not humanoid or humanoid.Health <= 0 then
        releaseTriggerTool()
        return false
    end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or not tool.Enabled or (tool.RequiresHandle and not tool:FindFirstChild("Handle")) then
        releaseTriggerTool()
        if os.clock() - lastToolMessage > 3 then
            lastToolMessage = os.clock()
            log("Triggerbot: equip an enabled weapon Tool with its required Handle.")
        end
        return false
    end
    if activeTriggerTool and activeTriggerTool ~= tool then
        releaseTriggerTool()
    end
    local now = os.clock()
    if now - State.LastTrigger < Settings.TriggerCooldown then
        return false
    end
    State.LastTrigger = now
    releaseTriggerTool()
    local ok, err = pcall(function()
        tool:Activate()
    end)
    if ok then
        activeTriggerTool = tool
        triggerEvent:Fire(target)
    elseif now - lastToolMessage > 3 then
        lastToolMessage = now
        log("Tool activation failed: " .. tostring(err))
    end
    -- Studio guns often listen for a real click instead of Tool.Activated.
    local virtualInput = game:GetService("VirtualInputManager")
    local center = Camera and Camera.ViewportSize / 2
    if virtualInput and center then
        pcall(function()
            virtualInput:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        end)
        task.delay(0.05, function()
            pcall(function()
                virtualInput:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
            end)
        end)
    end
    return ok
end
-- True when a ray from the camera reaches the point, or hits the given character first.
local function cameraSees(position, model)
    Camera = workspace.CurrentCamera
    if not Camera then
        return false
    end
    local origin = Camera.CFrame.Position
    local delta = position - origin
    if delta.Magnitude < 0.05 then
        return true
    end
    local parameters = RaycastParams.new()
    parameters.FilterType = Enum.RaycastFilterType.Exclude
    parameters.FilterDescendantsInstances = getCharacter() and {getCharacter()} or {}
    parameters.IgnoreWater = true
    local result = workspace:Raycast(origin, delta, parameters)
    if not result then
        return true
    end
    if model and result.Instance:IsDescendantOf(model) then
        return true
    end
    return (result.Position - origin).Magnitude >= delta.Magnitude - 0.75
end
local function findPeekPoint()
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil
    end
    local center = Camera.ViewportSize / 2
    local bestPoint, bestPixels = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not sameTeam(player) then
            local character = player.Character
            local part = character and isAlive(character) and getAimPart(character)
            if part then
                local hidden = not cameraSees(part.Position, character)
                local wasHidden = State.PeekHidden[player] == true
                State.PeekHidden[player] = hidden
                local aimAt = nil
                if not hidden and wasHidden then
                    aimAt = part.Position
                elseif hidden then
                    for _, limbName in ipairs({"Head", "UpperTorso", "Torso", "RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm"}) do
                        local limb = character:FindFirstChild(limbName)
                        if limb and limb:IsA("BasePart") and cameraSees(limb.Position, character) then
                            aimAt = limb.Position
                            break
                        end
                    end
                    if not aimAt then
                        local velocity = part.AssemblyLinearVelocity
                        local flat = Vector3.new(velocity.X, 0, velocity.Z)
                        if flat.Magnitude < 4 then
                            local look = part.CFrame.LookVector
                            flat = Vector3.new(look.X, 0, look.Z)
                        end
                        if flat.Magnitude > 0.1 then
                            local ahead = part.Position + flat.Unit * Settings.PeekLead
                            local parameters = RaycastParams.new()
                            parameters.FilterType = Enum.RaycastFilterType.Exclude
                            parameters.FilterDescendantsInstances = getCharacter() and {getCharacter()} or {}
                            parameters.IgnoreWater = true
                            local coverHit = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, parameters)
                            local coverLeft = coverHit and (part.Position - coverHit.Position).Magnitude or math.huge
                            if coverLeft <= Settings.PeekCover and cameraSees(ahead, character) then
                                aimAt = ahead
                            end
                        end
                    end
                end
                if aimAt then
                    local projected, onScreen = Camera:WorldToViewportPoint(aimAt)
                    if onScreen and projected.Z > 0 then
                        local pixels = (Vector2.new(projected.X, projected.Y) - center).Magnitude
                        if pixels <= math.max(Settings.FOV, 360) and pixels < bestPixels then
                            bestPixels = pixels
                            bestPoint = aimAt
                        end
                    end
                end
            end
        end
    end
    return bestPoint
end
local function updatePeekPrefire()
    if not Settings.PeekPrefire or Settings.FreecamEnabled or UserInputService:GetFocusedTextBox() then
        return
    end
    local peekPoint = findPeekPoint()
    if not peekPoint then
        return
    end
    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, peekPoint)
    tryActivateTool(peekPoint)
end
local function updateTriggerbot()
    if not Settings.TriggerbotEnabled or Settings.FreecamEnabled
        or UserInputService:GetFocusedTextBox() then
        releaseTriggerTool(); State.TriggerSince = nil; return
    end
    if Settings.TriggerKey ~= "Always" and not State.RightMouseDown then
        releaseTriggerTool(); State.TriggerSince = nil; return
    end
    local character = getCharacter()
    local humanoid = getHumanoid()
    if not character or not humanoid or humanoid.Health <= 0 then releaseTriggerTool(); return end
    local target = getCrosshairTarget()
    if not target then
        local center = Camera.ViewportSize / 2
        local closestPixels = 48
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not sameTeam(player) and player.Character and isAlive(player.Character) then
                local part = getAimPart(player.Character)
                if part then
                    local projected, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen and projected.Z > 0 then
                        local pixels = (Vector2.new(projected.X, projected.Y) - center).Magnitude
                        if pixels < closestPixels and cameraSees(part.Position, player.Character) then
                            closestPixels = pixels
                            target = player.Character
                        end
                    end
                end
            end
        end
    end
    local targetPlayer = target and Players:GetPlayerFromCharacter(target)
    if not target or (targetPlayer and sameTeam(targetPlayer)) then
        releaseTriggerTool(); State.TriggerSince = nil; return
    end
    -- Reaction delay: the crosshair must rest on a target before the first shot.
    State.TriggerSince = State.TriggerSince or os.clock()
    if os.clock() - State.TriggerSince < Settings.TriggerDelay / 1000 then return end
    tryActivateTool(target)
end

-- =========================================================
-- MOVEMENT TESTS

-- =========================================================
local function applyWalkSpeed()
    local humanoid =
        getHumanoid()
    if not humanoid then
        return
    end
    if Settings.SpeedEnabled then
        if not State.HumanoidDefaults[humanoid] then
            State.HumanoidDefaults[humanoid] = {WalkSpeed = humanoid.WalkSpeed,
                JumpPower = humanoid.JumpPower, UseJumpPower = humanoid.UseJumpPower}
        end
        humanoid.WalkSpeed =
            Settings.WalkSpeed
    end
end
local function applyJumpPower()
    local humanoid =
        getHumanoid()
    if not humanoid then
        return
    end
    if Settings.JumpEnabled then
        if not State.HumanoidDefaults[humanoid] then
            State.HumanoidDefaults[humanoid] = {WalkSpeed = humanoid.WalkSpeed,
                JumpPower = humanoid.JumpPower, UseJumpPower = humanoid.UseJumpPower}
        end
        humanoid.UseJumpPower = true
        humanoid.JumpPower =
            Settings.JumpPower
    else
        local original = State.HumanoidDefaults[humanoid]
        if original then humanoid.JumpPower = original.JumpPower; humanoid.UseJumpPower = original.UseJumpPower end
    end
end
local function setNoclip(enabled)
    Settings.NoclipEnabled =
        enabled
    if not enabled then
        for part, original
            in pairs(
                State.OriginalCollisions
            )
        do
            if part and part.Parent then
                part.CanCollide =
                    original
            end
        end
        table.clear(
            State.OriginalCollisions
        )
    end
end
local function updateNoclip()
    if not Settings.NoclipEnabled then
        return
    end
    local character =
        getCharacter()
    if not character then
        return
    end
    for _, object in ipairs(
        character:GetDescendants()
    ) do
        if object:IsA("BasePart") then
            if
                State.OriginalCollisions[
                    object
                ] == nil
            then
                State.OriginalCollisions[
                    object
                ] =
                    object.CanCollide
            end
            object.CanCollide =
                false
        end
    end
end
local function updateFly(dt)
    if not Settings.FlyEnabled or Settings.FreecamEnabled then
        return
    end
    local root =
        getRoot()
    if not root then
        return
    end
    local movement =
        Vector3.zero
    if State.FlyKeys.W then
        movement +=
            Camera.CFrame.LookVector
    end
    if State.FlyKeys.S then
        movement -=
            Camera.CFrame.LookVector
    end
    if State.FlyKeys.A then
        movement -=
            Camera.CFrame.RightVector
    end
    if State.FlyKeys.D then
        movement +=
            Camera.CFrame.RightVector
    end
    if State.FlyKeys.Space then
        movement +=
            Vector3.yAxis
    end
    if State.FlyKeys.Ctrl then
        movement -=
            Vector3.yAxis
    end
    if movement.Magnitude > 0 then
        root.CFrame +=
            movement.Unit
            * Settings.FlySpeed
            * dt
    end
    root.AssemblyLinearVelocity =
        Vector3.zero
end
-- Rapid spin uses a local AngularVelocity constraint on your own character.
-- Collision groups, noclip, mass, and network ownership determine fling behavior.
makeLabel(movementPage, "RAPID SPIN / PHYSICS TEST")
local spinButton = makeButton(movementPage, "Rapid Spin: OFF")
local spinSpeedLabel = makeLabel(movementPage, "Spin speed: " .. Settings.SpinSpeed .. " deg/sec")
local spinSpeedBox, applySpinButton = makeInlineField(movementPage, tostring(Settings.SpinSpeed), "Apply")
local stopSpinButton = makeButton(movementPage, "STOP SPIN")
makeLabel(movementPage, "F8 stops spin. Noclip prevents collision-based flinging.")
local spinState = nil
local function stopSpin()
    Settings.SpinEnabled = false
    if spinState then
        spinState.Constraint:Destroy()
        spinState.Attachment:Destroy()
        if spinState.Root.Parent then
            spinState.Root.AssemblyAngularVelocity = Vector3.zero
            spinState.Root.AssemblyLinearVelocity = Vector3.zero
        end
        if spinState.Humanoid.Parent then spinState.Humanoid.AutoRotate = spinState.AutoRotate end
        spinState = nil
    end
    spinButton.Text = "Rapid Spin: OFF"
end
local function startSpin()
    stopSpin()
    local root, humanoid = getRoot(), getHumanoid()
    if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
        log("Spin needs a living character with an unanchored root."); return
    end
    local attachment = Instance.new("Attachment")
    attachment.Name = "AntiCheatSpinAttachment"
    attachment.Parent = root
    local constraint = Instance.new("AngularVelocity")
    constraint.Name = "AntiCheatSpinVelocity"
    constraint.Attachment0 = attachment
    constraint.RelativeTo = Enum.ActuatorRelativeTo.World
    constraint.MaxTorque = 1000000000
    constraint.AngularVelocity = Vector3.new(0, math.rad(Settings.SpinSpeed), 0)
    spinState = {Root=root, Humanoid=humanoid, AutoRotate=humanoid.AutoRotate,
        Constraint=constraint, Attachment=attachment}
    humanoid.AutoRotate = false
    constraint.Parent = root
    Settings.SpinEnabled = true
    spinButton.Text = "Rapid Spin: ON"
    log("Rapid spin started. F8 or STOP SPIN stops it.")
end
connect(spinButton.MouseButton1Click, function()
    if Settings.SpinEnabled then stopSpin() else startSpin() end
end)
connect(stopSpinButton.MouseButton1Click, stopSpin)
connect(applySpinButton.MouseButton1Click, function()
    local value = tonumber(spinSpeedBox.Text)
    if not value or value ~= value or math.abs(value) == math.huge then
        spinSpeedBox.Text = tostring(Settings.SpinSpeed); log("Invalid spin speed."); return
    end
    Settings.SpinSpeed = math.clamp(value, 0, 50000)
    spinSpeedBox.Text = tostring(Settings.SpinSpeed)
    spinSpeedLabel.Text = "Spin speed: " .. Settings.SpinSpeed .. " deg/sec"
    if spinState then spinState.Constraint.AngularVelocity = Vector3.new(0, math.rad(Settings.SpinSpeed), 0) end
end)
connect(UserInputService.InputBegan, function(input)
    if input.KeyCode == Enum.KeyCode.F8 then stopSpin() end
end)
connect(LocalPlayer.CharacterRemoving, function() stopSpin(); releaseTriggerTool() end)
connect(RunService.Heartbeat, function()
    if spinState and (not spinState.Root:IsDescendantOf(workspace)
        or spinState.Humanoid.Health <= 0) then stopSpin() end
end)

local function teleportForward()
    local root =
        getRoot()
    if not root then
        log("Teleport failed")
        return
    end
    root.CFrame =
        root.CFrame
        + root.CFrame.LookVector
        * Settings.TeleportDistance
    log(
        "Teleported "
            .. Settings.TeleportDistance
            .. " studs"
    )
end
local function teleportToTarget()
    local root = getRoot()
    local player = Settings.TargetESPUserId and Players:GetPlayerByUserId(Settings.TargetESPUserId)
    local targetRoot = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root or not targetRoot then
        log("Select an ESP target on the Visuals tab first.")
        return
    end
    root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
    log("Teleported to @" .. player.Name)
end
local function clickTeleport()
    local root = getRoot()
    Camera = workspace.CurrentCamera
    if not root or not Camera then
        return
    end
    local mouse = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)
    local parameters = RaycastParams.new()
    parameters.FilterType = Enum.RaycastFilterType.Exclude
    parameters.FilterDescendantsInstances = {root.Parent}
    local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, parameters)
    if not result then
        log("Click teleport: nothing under the cursor.")
        return
    end
    root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3.5, 0)) * root.CFrame.Rotation
    log(string.format("Click teleported %.0f studs", (result.Position - ray.Origin).Magnitude))
end
local function dashForward()
    local root = getRoot()
    if not root then
        log("Dash failed")
        return
    end
    local look = Camera and Camera.CFrame.LookVector or root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then
        flat = root.CFrame.LookVector
    end
    root.AssemblyLinearVelocity = flat.Unit * Settings.DashSpeed + Vector3.new(0, 20, 0)
    log("Dash at " .. Settings.DashSpeed .. " studs/sec")
end
local function updateCFrameSpeed(dt)
    if not Settings.CFrameSpeedEnabled or Settings.FlyEnabled or Settings.FreecamEnabled then
        return
    end
    local root, humanoid = getRoot(), getHumanoid()
    if not root or not humanoid or humanoid.Health <= 0 then
        return
    end
    local direction = humanoid.MoveDirection
    if direction.Magnitude > 0 then
        root.CFrame += direction.Unit * Settings.CFrameSpeed * dt
    end
end

-- =========================================================
-- MENU EVENTS

-- =========================================================

-- =========================================================
-- FREECAM: WASD, Space/Ctrl; hold right mouse to look. F exits.
-- Mouse stays available for the menu and speed controls.

-- =========================================================
makeLabel(movementPage, "Freecam: WASD + Space/Ctrl; hold RMB to look; F exits.")
local freecamAction = "AntiCheatTesterFreecamMovement"
local freecamRender = "AntiCheatTesterFreecamCamera"
local savedCamera = nil
local savedMouse = nil

local function releaseFreecamMouse()
    State.FreecamLooking = false
    if savedMouse then
        UserInputService.MouseBehavior = savedMouse.Behavior
        UserInputService.MouseIconEnabled = savedMouse.Icon
    end
end

local function disableFreecam()
    Settings.FreecamEnabled = false
    RunService:UnbindFromRenderStep(freecamRender)
    ContextActionService:UnbindAction(freecamAction)
    releaseFreecamMouse()
    table.clear(State.FreecamKeys)
    table.clear(State.FlyKeys)
    if savedCamera and savedCamera.Camera.Parent then
        local camera = savedCamera.Camera
        camera.CameraType = savedCamera.Type
        local subject = savedCamera.Subject
        camera.CameraSubject = (subject and subject.Parent and subject) or getHumanoid()
        camera.CFrame = savedCamera.CFrame
        camera.Focus = savedCamera.Focus
    end
    savedCamera = nil
    savedMouse = nil
    freecamButton.Text = "Freecam: OFF"
end

local function updateFreecam(dt)
    if not running or not Settings.FreecamEnabled then return end
    local camera = workspace.CurrentCamera
    if not camera or not savedCamera or camera ~= savedCamera.Camera then
        disableFreecam()
        return
    end
    if State.FreecamLooking and not UserInputService:GetFocusedTextBox() then
        local delta = UserInputService:GetMouseDelta()
        State.FreecamYaw -= delta.X * 0.0025
        State.FreecamPitch = math.clamp(State.FreecamPitch - delta.Y * 0.0025,
            math.rad(-89), math.rad(89))
    end
    local rotation = CFrame.fromOrientation(State.FreecamPitch, State.FreecamYaw, 0)
    local keys = State.FreecamKeys
    local move = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        if keys.W then move += rotation.LookVector end
        if keys.S then move -= rotation.LookVector end
        if keys.A then move -= rotation.RightVector end
        if keys.D then move += rotation.RightVector end
        if keys.Space then move += Vector3.yAxis end
        if keys.Ctrl then move -= Vector3.yAxis end
    end
    if move.Magnitude > 0 then
        State.FreecamPosition += move.Unit * Settings.FreecamSpeed * math.min(dt, 0.1)
    end
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(State.FreecamPosition) * rotation
    camera.Focus = camera.CFrame * CFrame.new(0, 0, -20)
end

local function enableFreecam()
    local camera = workspace.CurrentCamera
    if not camera then log("Freecam: no camera available"); return end
    savedCamera = {Camera = camera, Type = camera.CameraType, Subject = camera.CameraSubject,
        CFrame = camera.CFrame, Focus = camera.Focus}
    savedMouse = {Behavior = UserInputService.MouseBehavior, Icon = UserInputService.MouseIconEnabled}
    Settings.AimEnabled = false
    aimButton.Text = "Auto Aim: OFF"
    State.FreecamPosition = camera.CFrame.Position
    State.FreecamPitch, State.FreecamYaw = camera.CFrame:ToOrientation()
    table.clear(State.FreecamKeys)
    table.clear(State.FlyKeys)
    Settings.FreecamEnabled = true
    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    ContextActionService:BindActionAtPriority(freecamAction, function(_, inputState, input)
        local names = {[Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A",
            [Enum.KeyCode.S] = "S", [Enum.KeyCode.D] = "D",
            [Enum.KeyCode.Space] = "Space", [Enum.KeyCode.LeftControl] = "Ctrl"}
        local key = names[input.KeyCode]
        if key then
            State.FreecamKeys[key] = inputState == Enum.UserInputState.Begin
                and not UserInputService:GetFocusedTextBox()
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value + 100,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Space, Enum.KeyCode.LeftControl)
    RunService:BindToRenderStep(freecamRender, Enum.RenderPriority.Camera.Value + 1, updateFreecam)
    freecamButton.Text = "Freecam: ON"
    log("Freecam enabled; Auto Aim disabled.")
end

connect(freecamButton.MouseButton1Click, function()
    if Settings.FreecamEnabled then disableFreecam() else enableFreecam() end
end)

-- =========================================================
-- =========================================================
-- STATS TESTER: expanded guessed names in the local player's client-visible data.
-- A numeric ValueBase or attribute is a match; missing data is not a match.
-- The first available candidate becomes the live stat. Rescan if it disappears.
-- Local value/attribute writes are optional Studio tests. No remotes are fired.
-- Successful client readback does not imply a server-authorized currency/XP change.
-- Edit this list to use the exact stat names in your own Studio project.
-- =========================================================
local statCandidates = {
    "Cash", "Money", "Coins", "Currency", "Balance",
    "Wallet", "Funds", "Credits", "Gold", "Dollars",
    "CashBalance", "MoneyBalance", "CoinBalance", "CurrencyBalance", "TotalCash",
    "TotalMoney", "TotalCoins", "PlayerCash", "PlayerMoney", "PlayerCoins",
    "CashAmount", "MoneyAmount", "CoinAmount", "CurrentCash", "CurrentMoney",
    "CurrentCoins", "AvailableCash", "AvailableMoney", "Bank", "BankBalance",
    "BankCash", "BankMoney", "CashValue", "MoneyValue", "CoinValue",
    "CurrencyValue", "CashOwned", "MoneyOwned", "CoinsOwned", "SoftCurrency",
    "HardCurrency", "PremiumCurrency", "Gems", "Diamonds", "Tokens",
    "Tickets", "Bucks", "Beli", "Yen", "Rupees",
    "Silver", "Copper", "Shillings", "Doubloons", "GoldCoins",
    "CoinsCollected", "EarnedCash", "EarnedMoney", "LifetimeCash", "LifetimeMoney",
    "Level", "Levels", "Experience", "XP", "Exp",
    "Points", "Score"
}
local statsPage = createPage("Stats")
local statsBack = makeButton(statsPage, "< Back")
makeLabel(statsPage, "LOCAL PLAYER STATS (Studio client tests)")
makeLabel(statsPage, "Checks 67 names; the first numeric match is used.")
local statsAutoButton = makeButton(statsPage, "Auto Stat Scan: OFF")
local scanStatsButton = makeButton(statsPage, "Scan Stats Now")
local activeStatLabel = makeLabel(statsPage, "Active stat: none")
local statValueLabel = makeLabel(statsPage, "Value: unavailable")
makeLabel(statsPage, "Requested local test value (0-1000000000):")
local statEditBox, guessEditButton = makeInlineField(statsPage, "1000", "Apply Value")
local restoreStatsButton = makeButton(statsPage, "Restore Local Edits")
local editFeedback = makeLabel(statsPage, "Local edit: no test run")
local statOriginals = {}
local statFeedbackLabels = {}
for index, name in ipairs(statCandidates) do
    statFeedbackLabels[index] = makeLabel(statsPage, name .. ": not checked")
end
makeLabel(statsPage, "Checks leaderstats, Stats, player attributes, and direct values.")
local statsAutoEnabled = false
local activeStat = nil
local function numericStatValue(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function readStat(binding)
    if not binding or not binding.Owner.Parent then return nil end
    local value
    if binding.Attribute then value = binding.Owner:GetAttribute(binding.Name)
    elseif binding.Owner:IsA("ValueBase") then value = binding.Owner.Value end
    return numericStatValue(value) and value or nil
end
local function findStat(name)
    local containers = {LocalPlayer}
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local stats = LocalPlayer:FindFirstChild("Stats")
    if leaderstats then table.insert(containers, 1, leaderstats) end
    if stats then table.insert(containers, stats) end
    for _, container in ipairs(containers) do
        for _, child in ipairs(container:GetChildren()) do
            if child.Name:lower() == name:lower() and child:IsA("ValueBase")
                and numericStatValue(child.Value) then
                return {Owner=child, Name=child.Name, Source=container.Name .. "." .. child.Name}
            end
        end
        for attribute, value in pairs(container:GetAttributes()) do
            if attribute:lower() == name:lower() and numericStatValue(value) then
                return {Owner=container, Name=attribute, Attribute=true,
                    Source=container.Name .. " attribute " .. attribute}
            end
        end
    end
    return nil
end
local function scanStats()
    local first = nil
    for index, name in ipairs(statCandidates) do
        local match = findStat(name)
        local value = readStat(match)
        statFeedbackLabels[index].Text = name .. ": "
            .. (value ~= nil and ("FOUND = " .. tostring(value)) or "not available")
        if not first and value ~= nil then first = match end
    end
    activeStat = first
    activeStatLabel.Text = first and ("Active stat: " .. first.Source) or "Active stat: no numeric match"
    local value = readStat(first)
    statValueLabel.Text = value ~= nil and ("Value: " .. tostring(value)) or "Value: unavailable"
end
local function writeStat(binding, value)
    if binding.Attribute then binding.Owner:SetAttribute(binding.Name, value)
    else binding.Owner.Value = value end
end
local function restoreStatEdits()
    local remaining = {}
    for _, original in ipairs(statOriginals) do
        if original.Binding.Owner.Parent then
            local ok = pcall(writeStat, original.Binding, original.Value)
            if not ok then table.insert(remaining, original) end
        end
    end
    statOriginals = remaining
    return #remaining == 0
end
connect(restoreStatsButton.MouseButton1Click, function()
    local ok = restoreStatEdits()
    scanStats()
    editFeedback.Text = ok and "Local edits restored." or "Some edits could not be restored."
end)
connect(guessEditButton.MouseButton1Click, function()
    local requested = tonumber(statEditBox.Text)
    if not numericStatValue(requested) or requested < 0 or requested > 1000000000 then
        editFeedback.Text = "Enter a finite value from 0 to 1000000000."
        return
    end
    requested = math.floor(requested)
    statEditBox.Text = tostring(requested)
    for index, name in ipairs(statCandidates) do
        local binding = findStat(name)
        local before = readStat(binding)
        if before ~= nil then
            local alreadySaved = false
            for _, original in ipairs(statOriginals) do
                if original.Binding.Owner == binding.Owner and original.Binding.Name == binding.Name
                    and original.Binding.Attribute == binding.Attribute then alreadySaved = true; break end
            end
            local ok = pcall(writeStat, binding, requested)
            local after = readStat(binding)
            if ok and after == requested then
                if not alreadySaved then table.insert(statOriginals, {Binding=binding, Value=before}) end
                activeStat = binding
                activeStatLabel.Text = "Active stat: " .. binding.Source
                statValueLabel.Text = "Value: " .. tostring(after)
                statFeedbackLabels[index].Text = name .. ": LOCAL READBACK = " .. tostring(after)
                editFeedback.Text = "Local readback matched: " .. name .. " (server not verified)"
                log("Local stat test matched " .. name .. "; server acceptance is unverified.")
                return
            end
            -- Restore before advancing after an unsuccessful write/readback.
            local restored = pcall(writeStat, binding, before)
            if not restored and not alreadySaved then
                table.insert(statOriginals, {Binding=binding, Value=before})
            end
            statFeedbackLabels[index].Text = name .. ": local write not confirmed"
        else
            statFeedbackLabels[index].Text = name .. ": no numeric match"
        end
    end
    editFeedback.Text = "No existing writable numeric stat matched the 67 guesses."
end)

connect(statsMenuButton.MouseButton1Click, function() showPage("Stats") end)
connect(statsBack.MouseButton1Click, function() showPage("Menu") end)
connect(scanStatsButton.MouseButton1Click, scanStats)
connect(statsAutoButton.MouseButton1Click, function()
    statsAutoEnabled = not statsAutoEnabled
    statsAutoButton.Text = "Auto Stat Scan: " .. (statsAutoEnabled and "ON" or "OFF")
    if statsAutoEnabled then scanStats() end
end)
local statTimer = 0
connect(RunService.Heartbeat, function(dt)
    statTimer += dt
    if statTimer < 0.5 then return end
    statTimer = 0
    if statsAutoEnabled then scanStats()
    elseif activeStat then
        local value = readStat(activeStat)
        if value == nil then scanStats()
        else statValueLabel.Text = "Value: " .. tostring(value) end
    end
end)

connect(combatMenuButton.MouseButton1Click, function()
        showPage("Combat")
    end)
connect(movementMenuButton.MouseButton1Click, function()
        showPage("Movement")
    end)
connect(combatBack.MouseButton1Click, function()
        showPage("Menu")
    end)
connect(movementBack.MouseButton1Click, function()
        showPage("Menu")
    end)
connect(visualsMenuButton.MouseButton1Click, function() showPage("Visuals") end)
connect(visualsBack.MouseButton1Click, function() showPage("Menu") end)

-- =========================================================
-- COMBAT BUTTONS

-- =========================================================
local function toggleText(name, enabled)
    return name .. ": " .. (enabled and "ON" or "OFF")
end
connect(stickyButton.MouseButton1Click, function()
    Settings.StickyAim = not Settings.StickyAim
    State.StickyTarget = nil
    stickyButton.Text = toggleText("Sticky Aim", Settings.StickyAim)
end)
connect(teamCheckButton.MouseButton1Click, function()
    Settings.TeamCheck = not Settings.TeamCheck
    State.StickyTarget = nil
    teamCheckButton.Text = toggleText("Team Check", Settings.TeamCheck)
    if Settings.HitboxEnabled then restoreHitboxes(); applyHitboxes() end
end)
-- =========================================================
-- VISUAL BUTTONS

-- =========================================================
connect(espLinesButton.MouseButton1Click, function()
    Settings.ESPLines = not Settings.ESPLines
    espLinesButton.Text = toggleText("Tracer Lines", Settings.ESPLines)
end)
connect(espBoxesButton.MouseButton1Click, function()
    Settings.ESPBoxes = not Settings.ESPBoxes
    espBoxesButton.Text = toggleText("2D Boxes", Settings.ESPBoxes)
end)
connect(xrayButton.MouseButton1Click, function()
    setXRay(not Settings.XRayEnabled)
    xrayButton.Text = toggleText("X-Ray Walls", Settings.XRayEnabled)
end)
connect(hitboxButton.MouseButton1Click, function()
    setHitboxes(not Settings.HitboxEnabled)
    hitboxButton.Text = toggleText("Hitbox Expander", Settings.HitboxEnabled)
end)
-- =========================================================
-- TELEPORT / CFRAME BUTTONS

-- =========================================================
connect(teleportTargetButton.MouseButton1Click, teleportToTarget)
connect(clickTeleportButton.MouseButton1Click, function()
    Settings.ClickTeleport = not Settings.ClickTeleport
    clickTeleportButton.Text = toggleText("Ctrl+Click Teleport", Settings.ClickTeleport)
end)
connect(cframeSpeedButton.MouseButton1Click, function()
    Settings.CFrameSpeedEnabled = not Settings.CFrameSpeedEnabled
    cframeSpeedButton.Text = toggleText("CFrame Speed", Settings.CFrameSpeedEnabled)
end)
connect(dashButton.MouseButton1Click, dashForward)
connect(UserInputService.InputBegan, function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.RightMouseDown = true
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and Settings.ClickTeleport
        and not processed and not Settings.FreecamEnabled
        and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        clickTeleport()
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.RightMouseDown = false
    end
end)
local function setCombatPreset(enabled)
    if enabled and Settings.FreecamEnabled then
        log("Exit Freecam before enabling Auto Aim.")
        combatPresetButton.Text = "Enemy Combat Preset: OFF"
        return
    end
    Settings.AimEnabled = enabled
    Settings.ESPEnabled = enabled
    Settings.ESPLines = enabled
    Settings.TeamCheck = enabled
    State.StickyTarget = nil
    aimButton.Text = "Auto Aim: " .. (enabled and "ON" or "OFF")
    espButton.Text = "Player Highlights: " .. (enabled and "ON" or "OFF")
    espLinesButton.Text = "Tracer Lines: " .. (enabled and "ON" or "OFF")
    teamCheckButton.Text = "Team Check: " .. (enabled and "ON" or "OFF")
    combatPresetButton.Text = "Enemy Combat Preset: " .. (enabled and "ON" or "OFF")
    refreshESP()
    log(enabled and "Enemy combat preset on." or "Enemy combat preset off.")
end
connect(combatPresetButton.MouseButton1Click, function()
    setCombatPreset(not Settings.AimEnabled or not Settings.ESPEnabled or not Settings.ESPLines)
end)
connect(aimButton.MouseButton1Click, function()
        if Settings.FreecamEnabled then log("Exit Freecam before enabling Auto Aim."); return end
        Settings.AimEnabled =
            not Settings.AimEnabled
        aimButton.Text =
            "Auto Aim: "
            .. (
                Settings.AimEnabled
                    and "ON"
                    or "OFF"
            )
        log(
            "Auto Aim "
                .. (
                    Settings.AimEnabled
                        and "enabled"
                        or "disabled"
                )
        )
    end)
connect(triggerButton.MouseButton1Click, function()
        Settings.TriggerbotEnabled =
            not Settings.TriggerbotEnabled
        if not Settings.TriggerbotEnabled then releaseTriggerTool() end
        triggerButton.Text =
            "Triggerbot (Equipped Tool): "
            .. (
                Settings.TriggerbotEnabled
                    and "ON"
                    or "OFF"
            )
    end)
connect(peekButton.MouseButton1Click, function()
    Settings.PeekPrefire = not Settings.PeekPrefire
    peekButton.Text = toggleText("Peek Prefire", Settings.PeekPrefire)
end)
connect(espButton.MouseButton1Click, function()
        Settings.ESPEnabled =
            not Settings.ESPEnabled
        espButton.Text =
            "Player Highlights: "
            .. (
                Settings.ESPEnabled
                    and "ON"
                    or "OFF"
            )
        refreshESP()
    end)
connect(wallCheckButton.MouseButton1Click, function()
        Settings.WallCheck =
            not Settings.WallCheck
        wallCheckButton.Text =
            "Aim Wall Check: "
            .. (
                Settings.WallCheck
                    and "ON"
                    or "OFF"
            )
    end)
-- =========================================================
-- SPEED ALTERER

-- =========================================================
connect(speedButton.MouseButton1Click, function()
        Settings.SpeedEnabled =
            not Settings.SpeedEnabled
        speedButton.Text =
            "Speed Alterer: "
            .. (
                Settings.SpeedEnabled
                    and "ON"
                    or "OFF"
            )
        local humanoid =
            getHumanoid()
        if humanoid then
            if Settings.SpeedEnabled then
                applyWalkSpeed()
            else
                local original = State.HumanoidDefaults[humanoid]
                humanoid.WalkSpeed = original and original.WalkSpeed or humanoid.WalkSpeed
            end
        end
        log(
            "Speed alterer "
                .. (
                    Settings.SpeedEnabled
                        and "enabled"
                        or "disabled"
                )
        )
    end)
connect(applySpeed.MouseButton1Click, function()
        local requested =
            tonumber(speedBox.Text)
        if not requested or requested ~= requested or math.abs(requested) == math.huge then
            speedBox.Text =
                tostring(
                    Settings.WalkSpeed
                )
            log(
                "Invalid WalkSpeed"
            )
            return
        end
        requested =
            math.clamp(
                requested,
                0,
                1000
            )
        Settings.WalkSpeed =
            requested
        speedBox.Text =
            tostring(requested)
        speedLabel.Text =
            "WalkSpeed: "
            .. tostring(requested)
        applyWalkSpeed()
        log(
            "WalkSpeed set to "
                .. requested
        )
    end)
-- =========================================================
-- OTHER MOVEMENT BUTTONS

-- =========================================================
connect(flyButton.MouseButton1Click, function()
        Settings.FlyEnabled =
            not Settings.FlyEnabled
        flyButton.Text =
            "Fly: "
            .. (
                Settings.FlyEnabled
                    and "ON"
                    or "OFF"
            )
    end)
connect(noclipButton.MouseButton1Click, function()
        setNoclip(
            not Settings.NoclipEnabled
        )
        noclipButton.Text =
            "Noclip: "
            .. (
                Settings.NoclipEnabled
                    and "ON"
                    or "OFF"
            )
    end)
connect(highJumpButton.MouseButton1Click, function()
        Settings.JumpEnabled =
            not Settings.JumpEnabled
        highJumpButton.Text =
            "High Jump: "
            .. (
                Settings.JumpEnabled
                    and "ON"
                    or "OFF"
            )
        applyJumpPower()
    end)
connect(infiniteJumpButton.MouseButton1Click, function()
        Settings.InfiniteJump =
            not Settings.InfiniteJump
        infiniteJumpButton.Text =
            "Infinite Jump: "
            .. (
                Settings.InfiniteJump
                    and "ON"
                    or "OFF"
            )
    end)
connect(teleportButton.MouseButton1Click, teleportForward)

-- =========================================================
-- INPUT

-- =========================================================
local keyMap = {
    [Enum.KeyCode.W] = "W",
    [Enum.KeyCode.A] = "A",
    [Enum.KeyCode.S] = "S",
    [Enum.KeyCode.D] = "D",
    [Enum.KeyCode.Space] =
        "Space",
    [Enum.KeyCode.LeftControl] =
        "Ctrl"
}
connect(UserInputService.InputBegan, function(input, processed)
        if
            input.KeyCode
            == Enum.KeyCode.RightShift
        then
            main.Visible = not main.Visible
            drawLayer.Visible = main.Visible
            if not main.Visible then
                inventoryPanel.Visible = false
                fovCircle.Visible = false
                for _, highlight in pairs(State.Highlights) do
                    highlight.Enabled = false
                end
                for _, entry in pairs(State.PlayerLabels) do
                    entry.Gui.Enabled = false
                end
                for _, drawing in pairs(State.Drawings) do
                    drawing.Line.Visible = false
                    drawing.Box.Visible = false
                end
            else
                for _, highlight in pairs(State.Highlights) do
                    highlight.Enabled = true
                end
                for _, entry in pairs(State.PlayerLabels) do
                    entry.Gui.Enabled = true
                end
            end
            return
        end
        if Settings.FreecamEnabled and input.KeyCode == Enum.KeyCode.F
            and not UserInputService:GetFocusedTextBox() then disableFreecam(); return end
        if processed or UserInputService:GetFocusedTextBox() then
            return
        end
        local key =
            keyMap[
                input.KeyCode
            ]
        if key then
            if not Settings.FreecamEnabled then State.FlyKeys[key] = true end
        end
    end)
connect(UserInputService.InputEnded, function(input)
        local key =
            keyMap[
                input.KeyCode
            ]
        if key then
            State.FlyKeys[key] = false
            State.FreecamKeys[key] = false
        end
    end)
-- Infinite jump
connect(UserInputService.JumpRequest, function()
        if not Settings.InfiniteJump or Settings.FreecamEnabled or UserInputService:GetFocusedTextBox() then
            return
        end
        local humanoid =
            getHumanoid()
        if humanoid then
            humanoid:
                ChangeState(
                    Enum.HumanoidStateType
                        .Jumping
                )
        end
    end)

-- =========================================================
-- DRAG WINDOW

-- =========================================================
local dragging = false
local dragStart = nil
local originalPosition = nil
connect(title.InputBegan, function(input)
        if
            input.UserInputType
            == Enum.UserInputType
                .MouseButton1
        then
            dragging = true
            dragStart =
                input.Position
            originalPosition =
                main.Position
        end
    end)
connect(UserInputService.InputEnded, function(input)
        if
            input.UserInputType
            == Enum.UserInputType
                .MouseButton1
        then
            dragging = false
        end
    end)
connect(UserInputService.InputChanged, function(input)
        if
            not dragging
            or input.UserInputType
                ~= Enum.UserInputType
                    .MouseMovement
        then
            return
        end
        local difference =
            input.Position
            - dragStart
        main.Position =
            UDim2.new(
                originalPosition.X.Scale,
                originalPosition.X.Offset
                    + difference.X,
                originalPosition.Y.Scale,
                originalPosition.Y.Offset
                    + difference.Y
            )
    end)

-- =========================================================
-- UPDATE LOOP

-- =========================================================
local espTimer = 0
connect(RunService.RenderStepped, function(dt)
        Camera =
            workspace.CurrentCamera
        if not Camera then
            return
        end
        local center =
            Camera.ViewportSize / 2
        fovCircle.Position =
            UDim2.fromOffset(
                center.X,
                center.Y
            )
        fovCircle.Size =
            UDim2.fromOffset(
                Settings.FOV * 2,
                Settings.FOV * 2
            )
        fovCircle.Visible =
            main.Visible and Settings.AimEnabled
        updateAim(dt)
        updateTriggerbot()
        updatePeekPrefire()
        updateDrawings()
        applyWalkSpeed()
        updateFly(dt)
        updateCFrameSpeed(dt)
        applyJumpPower()
        espTimer += dt
        if espTimer >= 1 then
            espTimer = 0
            if Settings.ESPEnabled or Settings.TargetedESPEnabled then
                refreshESP()
            end
            applyHitboxes()
        end
    end)

-- =========================================================
-- RESPAWN

-- =========================================================
connect(LocalPlayer.CharacterAdded, function()
        task.wait(0.5)
        if not running then return end
        table.clear(State.HumanoidDefaults)
        table.clear(
            State.OriginalCollisions
        )
        applyWalkSpeed()
        applyJumpPower()
        if Settings.ESPEnabled or Settings.TargetedESPEnabled then
            refreshESP()
        end
    end)

-- =========================================================
-- START

-- =========================================================
showPage("Menu")
setCombatPreset(true)
log("Panel ready.")
log("Enemy combat preset is on. Right Shift hides overlays; tests keep running.")

-- Focus loss clears held inputs; the menu remains clickable during Freecam.
connect(UserInputService.InputBegan, function(input, processed)
    if Settings.FreecamEnabled and not processed and not UserInputService:GetFocusedTextBox()
        and input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.FreecamLooking = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and Settings.FreecamEnabled then
        releaseFreecamMouse()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end)
connect(UserInputService.WindowFocusReleased, function()
    table.clear(State.FreecamKeys)
    table.clear(State.FlyKeys)
    if Settings.FreecamEnabled then
        releaseFreecamMouse()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end)
connect(UserInputService.TextBoxFocused, function()
    table.clear(State.FreecamKeys)
    table.clear(State.FlyKeys)
end)
connect(RunService.Stepped, updateNoclip)
local function restoreHumanoids()
    for humanoid, original in pairs(State.HumanoidDefaults) do
        if humanoid.Parent then
            humanoid.WalkSpeed = original.WalkSpeed
            humanoid.JumpPower = original.JumpPower
            humanoid.UseJumpPower = original.UseJumpPower
        end
    end
end
local function disableAll()
    Settings.AimEnabled = false
    Settings.TriggerbotEnabled = false
    Settings.PeekPrefire = false
    Settings.ESPEnabled = false
    Settings.TargetedESPEnabled = false
    Settings.ESPLines = false
    Settings.ESPBoxes = false
    Settings.TeamCheck = false
    Settings.InventoryInspectEnabled = false
    Settings.SpeedEnabled = false
    Settings.FlyEnabled = false
    Settings.JumpEnabled = false
    Settings.InfiniteJump = false
    Settings.ClickTeleport = false
    Settings.CFrameSpeedEnabled = false
    State.StickyTarget = nil
    stopSpin()
    releaseTriggerTool()
    disableFreecam()
    setNoclip(false)
    setXRay(false)
    setHitboxes(false)
    clearESP()
    clearDrawings()
    restoreHumanoids()
    updateInventoryInspection()
    aimButton.Text = "Auto Aim: OFF"
    triggerButton.Text = "Triggerbot (Equipped Tool): OFF"
    peekButton.Text = "Peek Prefire: OFF"
    espButton.Text = "Player Highlights: OFF"
    targetedESPButton.Text = "Targeted ESP: OFF"
    espLinesButton.Text = "Tracer Lines: OFF"
    teamCheckButton.Text = "Team Check: OFF"
    combatPresetButton.Text = "Enemy Combat Preset: OFF"
    espBoxesButton.Text = "2D Boxes: OFF"
    xrayButton.Text = "X-Ray Walls: OFF"
    hitboxButton.Text = "Hitbox Expander: OFF"
    inventoryButton.Text = "Look-at Inventory: OFF"
    speedButton.Text = "Speed Alterer: OFF"
    flyButton.Text = "Fly: OFF"
    noclipButton.Text = "Noclip: OFF"
    highJumpButton.Text = "High Jump: OFF"
    infiniteJumpButton.Text = "Infinite Jump: OFF"
    clickTeleportButton.Text = "Ctrl+Click Teleport: OFF"
    cframeSpeedButton.Text = "CFrame Speed: OFF"
    log("All tests disabled.")
end
connect(disableAllButton.MouseButton1Click, disableAll)
-- Destroying/replacing the GUI also stops the old loops and restores state.
local function cleanup()
    if not running then return end
    running = false
    stopSpin()
    releaseTriggerTool()
    disableFreecam()
    setNoclip(false)
    setXRay(false)
    restoreHitboxes()
    clearESP()
    clearDrawings()
    restoreStatEdits()
    restoreHumanoids()
    for _, connection in ipairs(connections) do connection:Disconnect() end
end
connect(gui.Destroying, cleanup)
connect(script.Destroying, function()
    cleanup()
    if gui.Parent then gui:Destroy() end
end)
