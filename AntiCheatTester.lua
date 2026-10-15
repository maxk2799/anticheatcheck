--[[
    ANTI-CHEAT TESTER
    Studio-only client testing harness
    Place in:
    StarterPlayer > StarterPlayerScripts
    Categories:
        Combat
        Movement
        Stats
    This does NOT:
        - discover/fire arbitrary game remotes
        - perform OS mouse clicks
        - run outside Roblox Studio
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
    SpinEnabled = false,
    SpinSpeed = 3000, -- degrees/sec; 50000 maximum
    TriggerCooldown = 0.12
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
    PlayerLabels = {},
    Highlights = {}
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
    Bg = Color3.fromRGB(10, 13, 18),
    Raised = Color3.fromRGB(24, 30, 40),
    RaisedHover = Color3.fromRGB(32, 40, 52),
    Line = Color3.fromRGB(52, 64, 80),
    Text = Color3.fromRGB(236, 241, 247),
    Muted = Color3.fromRGB(148, 160, 176),
    Accent = Color3.fromRGB(92, 196, 255),
    On = Color3.fromRGB(52, 211, 153),
    Danger = Color3.fromRGB(255, 107, 122),
}
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(468, 640)
main.Position = UDim2.new(0, 24, 0.5, -320)
main.BackgroundColor3 = Theme.Bg
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
addCorner(main, 14)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Theme.Line
mainStroke.Thickness = 1
mainStroke.Parent = main
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = Theme.Accent
accentBar.BorderSizePixel = 0
accentBar.Parent = main
local title = Instance.new("Frame")
title.Name = "Header"
title.Size = UDim2.new(1, 0, 0, 56)
title.BackgroundTransparency = 1
title.Active = true
title.Parent = main
local titleText = Instance.new("TextLabel")
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.fromOffset(16, 10)
titleText.Size = UDim2.new(1, -32, 0, 22)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 16
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextColor3 = Theme.Text
titleText.Text = "Anti-Cheat Tester"
titleText.Parent = title
local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(16, 32)
subtitle.Size = UDim2.new(1, -32, 0, 16)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Theme.Muted
subtitle.Text = "Right Shift hides this panel"
subtitle.Parent = title
local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Position = UDim2.fromOffset(12, 60)
tabBar.Size = UDim2.new(1, -24, 0, 34)
tabBar.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
tabBar.BorderSizePixel = 0
tabBar.Parent = main
addCorner(tabBar, 8)
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
local tabButtons = {}

-- =========================================================
-- LOG

-- =========================================================
local logCaption = Instance.new("TextLabel")
logCaption.BackgroundTransparency = 1
logCaption.Position = UDim2.new(0, 16, 1, -118)
logCaption.Size = UDim2.new(1, -32, 0, 16)
logCaption.Font = Enum.Font.GothamBold
logCaption.TextSize = 11
logCaption.TextXAlignment = Enum.TextXAlignment.Left
logCaption.TextColor3 = Theme.Muted
logCaption.Text = "ACTIVITY"
logCaption.Parent = main
local logBox = Instance.new("TextLabel")
logBox.Size = UDim2.new(1, -24, 0, 86)
logBox.Position = UDim2.new(0, 12, 1, -98)
logBox.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
logBox.BorderSizePixel = 0
logBox.Text = "Waiting for a test."
logBox.TextColor3 = Color3.fromRGB(186, 198, 214)
logBox.TextSize = 12
logBox.Font = Enum.Font.Code
logBox.TextWrapped = true
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.Parent = main
addCorner(logBox, 8)
local logPad = Instance.new("UIPadding")
logPad.PaddingTop = UDim.new(0, 8)
logPad.PaddingLeft = UDim.new(0, 10)
logPad.PaddingRight = UDim.new(0, 10)
logPad.Parent = logBox
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
        tab.BackgroundTransparency = selected and 0 or 1
        tab.BackgroundColor3 = Theme.Accent
        tab.TextColor3 = selected and Color3.fromRGB(10, 16, 22) or Theme.Muted
    end
end
local navInfo = {
    ["Combat Tests"] = "Aim, triggerbot, ESP, and inventory",
    ["Movement Tests"] = "Speed, fly, noclip, jump, and spin",
    ["Stats Scanner"] = "Scan and edit local player stats",
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
    local toggleName, toggleState = string.match(text, "^(.*): (ON)$")
    if not toggleName then
        toggleName, toggleState = string.match(text, "^(.*): (OFF)$")
    end
    local navDetail = navInfo[text]
    if toggleName then
        button.Size = UDim2.new(1, -4, 0, 40)
        button.TextTransparency = 1
        button.BackgroundColor3 = Theme.Raised
        addCorner(button, 8)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.fromOffset(12, 0)
        nameLabel.Size = UDim2.new(1, -78, 1, 0)
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.TextColor3 = Theme.Text
        nameLabel.Parent = button
        local pill = Instance.new("Frame")
        pill.AnchorPoint = Vector2.new(1, 0.5)
        pill.Position = UDim2.new(1, -8, 0.5, 0)
        pill.Size = UDim2.fromOffset(48, 22)
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
        end
        refreshToggle()
        button:GetPropertyChangedSignal("Text"):Connect(refreshToggle)
    elseif navDetail then
        button.Size = UDim2.new(1, -4, 0, 64)
        button.TextTransparency = 1
        button.BackgroundColor3 = Theme.Raised
        addCorner(button, 10)
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
    elseif text == "STOP SPIN" then
        button.Size = UDim2.new(1, -4, 0, 36)
        button.BackgroundColor3 = Theme.Danger
        button.TextColor3 = Color3.fromRGB(32, 8, 12)
        button.Font = Enum.Font.GothamBold
        button.TextXAlignment = Enum.TextXAlignment.Center
        addCorner(button, 8)
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
        button.TextXAlignment = Enum.TextXAlignment.Center
        addCorner(button, 8)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.Line
        stroke.Thickness = 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = button
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
    label.Parent = parent
    refreshLabel(label)
    label:GetPropertyChangedSignal("Text"):Connect(function()
        refreshLabel(label)
    end)
    return label
end
local function styleField(box)
    box.BackgroundColor3 = Theme.Raised
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.TextColor3 = Theme.Text
    box.PlaceholderColor3 = Theme.Muted
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 13
    addCorner(box, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Line
    stroke.Thickness = 1
    stroke.Parent = box
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
local function makeStepper(parent, labelText)
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
    label.Text = labelText
    label.Parent = row
    local function stepButton(symbol, offset)
        local button = Instance.new("TextButton")
        button.AutoButtonColor = false
        button.Size = UDim2.fromOffset(36, 32)
        button.AnchorPoint = Vector2.new(1, 0.5)
        button.Position = UDim2.new(1, offset, 0.5, 0)
        button.BackgroundColor3 = Theme.Raised
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 16
        button.TextColor3 = Theme.Text
        button.Text = symbol
        button.Parent = row
        addCorner(button, 8)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Theme.RaisedHover
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Theme.Raised
        end)
        return button
    end
    return label, stepButton("-", -40), stepButton("+", 0)
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
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.TextColor3 = Color3.fromRGB(10, 18, 26)
    button.Text = buttonText
    button.Parent = row
    addCorner(button, 8)
    return box, button
end
local function addTab(name, label, order)
    local tab = Instance.new("TextButton")
    tab.Name = name
    tab.Size = UDim2.fromOffset(104, 26)
    tab.BackgroundColor3 = Theme.Accent
    tab.BackgroundTransparency = 1
    tab.BorderSizePixel = 0
    tab.AutoButtonColor = false
    tab.Font = Enum.Font.GothamBold
    tab.TextSize = 12
    tab.Text = label
    tab.TextColor3 = Theme.Muted
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
addTab("Movement", "Move", 3)
addTab("Stats", "Stats", 4)

-- =========================================================
-- MAIN MENU

-- =========================================================
local menuPage =
    createPage("Menu")
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
local statsMenuButton = makeButton(menuPage, "Stats Scanner")
local combatPage =
    createPage("Combat")
local combatBack =
    makeButton(
        combatPage,
        "< Back"
    )
makeLabel(
    combatPage,
    "COMBAT TESTS"
)
local aimButton =
    makeButton(
        combatPage,
        "Auto Aim: OFF"
    )
local triggerButton =
    makeButton(
        combatPage,
        "Triggerbot (Equipped Tool): OFF"
    )
local espButton =
    makeButton(
        combatPage,
        "Walls / ESP: OFF"
    )
local wallCheckButton =
    makeButton(
        combatPage,
        "Aim Wall Check: ON"
    )
local fovLabel, fovMinus, fovPlus = makeStepper(combatPage, "FOV: " .. Settings.FOV)
local smoothLabel, smoothMinus, smoothPlus = makeStepper(combatPage, "Smoothness: " .. Settings.Smoothness)

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
local freecamSpeedLabel, freecamSpeedMinus, freecamSpeedPlus =
    makeStepper(movementPage, "Freecam Speed: " .. Settings.FreecamSpeed)
makeLabel(
    movementPage,
    "MOVEMENT TESTS"
)
local speedButton =
    makeButton(
        movementPage,
        "Speed Alterer: OFF"
    )
local speedLabel, speedMinus, speedPlus =
    makeStepper(movementPage, "WalkSpeed: " .. Settings.WalkSpeed)
local speedBox, applySpeed =
    makeInlineField(movementPage, tostring(Settings.WalkSpeed), "Apply")
local flyButton =
    makeButton(
        movementPage,
        "Fly: OFF"
    )
local flySpeedLabel, flyMinus, flyPlus =
    makeStepper(movementPage, "Fly Speed: " .. Settings.FlySpeed)
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
local jumpLabel, jumpMinus, jumpPlus =
    makeStepper(movementPage, "Jump Power: " .. Settings.JumpPower)
local infiniteJumpButton =
    makeButton(
        movementPage,
        "Infinite Jump: OFF"
    )
local teleportLabel, teleportMinus, teleportPlus =
    makeStepper(movementPage, "Teleport Distance: " .. Settings.TeleportDistance)
local teleportButton =
    makeButton(
        movementPage,
        "Teleport Forward"
    )

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
    return model:FindFirstChild("Head")
        or model:FindFirstChild(
            "HumanoidRootPart"
        )
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
local function acquireTarget()
    Camera = workspace.CurrentCamera
    if not Camera then
        return nil, nil
    end
    local center =
        Camera.ViewportSize / 2
    local bestModel = nil
    local bestPart = nil
    local closest =
        Settings.FOV
    for _, player in ipairs(
        Players:GetPlayers()
    ) do
        if player ~= LocalPlayer then
            local character =
                player.Character
            if
                character
                and isAlive(character)
            then
                local part =
                    getAimPart(character)
                if part then
                    local point,
                        onScreen =
                        Camera:
                            WorldToViewportPoint(
                                part.Position
                            )
                    if
                        onScreen
                        and point.Z > 0
                    then
                        local distance =
                            (
                                Vector2.new(
                                    point.X,
                                    point.Y
                                )
                                - center
                            ).Magnitude
                        if
                            distance
                                <= closest
                            and targetVisible(
                                part,
                                character
                            )
                        then
                            closest =
                                distance
                            bestModel =
                                character
                            bestPart =
                                part
                        end
                    end
                end
            end
        end
    end
    return bestModel, bestPart
end
local function updateAim(dt)
    if not Settings.AimEnabled or Settings.FreecamEnabled then
        return
    end
    local model, part =
        acquireTarget()
    if not model or not part then
        return
    end
    local desired =
        CFrame.lookAt(
            Camera.CFrame.Position,
            part.Position
        )
    local speed =
        math.clamp(
            20 / Settings.Smoothness,
            0.5,
            30
        )
    local alpha =
        math.clamp(
            dt * speed,
            0,
            1
        )
    Camera.CFrame =
        Camera.CFrame:Lerp(
            desired,
            alpha
        )
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
makeLabel(combatPage, "TARGETED ESP (gold highlight)")
makeLabel(combatPage, "Enter exact username or UserId (not display name)")
local targetESPBox = makeTextBox(combatPage, "")
targetESPBox.PlaceholderText = "Username or UserId"
local targetESPLabel = makeLabel(combatPage, "ESP target: none")
local selectESPButton = makeButton(combatPage, "Select ESP Player")
local nextESPButton = makeButton(combatPage, "Next ESP Player")
local targetedESPButton = makeButton(combatPage, "Targeted ESP: OFF")
local clearESPButton = makeButton(combatPage, "Clear ESP Target")

local espLabelsButton = makeButton(combatPage, "Username / HP Labels: ON")
local inventoryButton = makeButton(combatPage, "Look-at Inventory: OFF")
makeLabel(combatPage, "Inventory: aim screen center at a player; visible Tools only.")

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
        if player ~= LocalPlayer and (Settings.ESPEnabled or targeted)
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
inventoryPanel.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
inventoryPanel.BackgroundTransparency = 0.04
inventoryPanel.BorderSizePixel = 0
inventoryPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryPanel.CanvasSize = UDim2.new()
inventoryPanel.ScrollBarThickness = 4
inventoryPanel.ScrollBarImageColor3 = Theme.Accent
inventoryPanel.Visible = false
inventoryPanel.Parent = gui
addCorner(inventoryPanel, 12)
local inventoryStroke = Instance.new("UIStroke")
inventoryStroke.Color = Theme.Line
inventoryStroke.Thickness = 1
inventoryStroke.Parent = inventoryPanel
local inventoryText = Instance.new("TextLabel")
inventoryText.Position = UDim2.fromOffset(14, 12)
inventoryText.Size = UDim2.new(1, -28, 0, 0)
inventoryText.AutomaticSize = Enum.AutomaticSize.Y
inventoryText.BackgroundTransparency = 1
inventoryText.TextColor3 = Theme.Text
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
    inventoryPanel.Visible = Settings.InventoryInspectEnabled
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
local function updateTriggerbot()
    if not Settings.TriggerbotEnabled or Settings.FreecamEnabled
        or UserInputService:GetFocusedTextBox() then releaseTriggerTool(); return end
    local character = getCharacter()
    local humanoid = getHumanoid()
    if not character or not humanoid or humanoid.Health <= 0 then releaseTriggerTool(); return end
    local target = getCrosshairTarget()
    if not target then releaseTriggerTool(); return end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or not tool.Enabled or (tool.RequiresHandle and not tool:FindFirstChild("Handle")) then
        releaseTriggerTool()
        if os.clock() - lastToolMessage > 3 then
            lastToolMessage = os.clock()
            log("Triggerbot: equip an enabled weapon Tool with its required Handle.")
        end
        return
    end
    if activeTriggerTool and activeTriggerTool ~= tool then releaseTriggerTool() end
    local now = os.clock()
    if now - State.LastTrigger < Settings.TriggerCooldown then return end
    State.LastTrigger = now
    releaseTriggerTool()
    local ok, err = pcall(function() tool:Activate() end)
    if ok then
        activeTriggerTool = tool
        triggerEvent:Fire(target) -- optional local telemetry; activation above fires the Tool
    elseif now - lastToolMessage > 3 then
        lastToolMessage = now
        log("Tool activation failed: " .. tostring(err))
    end
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
connect(freecamSpeedMinus.MouseButton1Click, function()
    Settings.FreecamSpeed = math.max(5, Settings.FreecamSpeed - 10)
    freecamSpeedLabel.Text = "Freecam Speed: " .. Settings.FreecamSpeed
end)
connect(freecamSpeedPlus.MouseButton1Click, function()
    Settings.FreecamSpeed = math.min(1000, Settings.FreecamSpeed + 10)
    freecamSpeedLabel.Text = "Freecam Speed: " .. Settings.FreecamSpeed
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

-- =========================================================
-- COMBAT BUTTONS

-- =========================================================
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
connect(espButton.MouseButton1Click, function()
        Settings.ESPEnabled =
            not Settings.ESPEnabled
        espButton.Text =
            "Walls / ESP: "
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
connect(fovMinus.MouseButton1Click, function()
        Settings.FOV =
            math.max(
                20,
                Settings.FOV - 20
            )
        fovLabel.Text =
            "FOV: "
            .. Settings.FOV
    end)
connect(fovPlus.MouseButton1Click, function()
        Settings.FOV =
            math.min(
                500,
                Settings.FOV + 20
            )
        fovLabel.Text =
            "FOV: "
            .. Settings.FOV
    end)
connect(smoothMinus.MouseButton1Click, function()
        Settings.Smoothness =
            math.max(
                1,
                Settings.Smoothness - 1
            )
        smoothLabel.Text =
            "Smoothness: "
            .. Settings.Smoothness
    end)
connect(smoothPlus.MouseButton1Click, function()
        Settings.Smoothness =
            math.min(
                30,
                Settings.Smoothness + 1
            )
        smoothLabel.Text =
            "Smoothness: "
            .. Settings.Smoothness
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
connect(speedMinus.MouseButton1Click, function()
        Settings.WalkSpeed =
            math.max(
                0,
                Settings.WalkSpeed - 10
            )
        speedBox.Text =
            tostring(
                Settings.WalkSpeed
            )
        speedLabel.Text =
            "WalkSpeed: "
            .. Settings.WalkSpeed
        applyWalkSpeed()
    end)
connect(speedPlus.MouseButton1Click, function()
        Settings.WalkSpeed =
            math.min(
                1000,
                Settings.WalkSpeed + 10
            )
        speedBox.Text =
            tostring(
                Settings.WalkSpeed
            )
        speedLabel.Text =
            "WalkSpeed: "
            .. Settings.WalkSpeed
        applyWalkSpeed()
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
connect(flyMinus.MouseButton1Click, function()
        Settings.FlySpeed =
            math.max(
                10,
                Settings.FlySpeed - 10
            )
        flySpeedLabel.Text =
            "Fly Speed: "
            .. Settings.FlySpeed
    end)
connect(flyPlus.MouseButton1Click, function()
        Settings.FlySpeed =
            math.min(
                500,
                Settings.FlySpeed + 10
            )
        flySpeedLabel.Text =
            "Fly Speed: "
            .. Settings.FlySpeed
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
connect(jumpMinus.MouseButton1Click, function()
        Settings.JumpPower =
            math.max(
                0,
                Settings.JumpPower - 10
            )
        jumpLabel.Text =
            "Jump Power: "
            .. Settings.JumpPower
        applyJumpPower()
    end)
connect(jumpPlus.MouseButton1Click, function()
        Settings.JumpPower =
            math.min(
                500,
                Settings.JumpPower + 10
            )
        jumpLabel.Text =
            "Jump Power: "
            .. Settings.JumpPower
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
connect(teleportMinus.MouseButton1Click, function()
        Settings.TeleportDistance =
            math.max(
                10,
                Settings.TeleportDistance
                    - 50
            )
        teleportLabel.Text =
            "Teleport Distance: "
            .. Settings.TeleportDistance
    end)
connect(teleportPlus.MouseButton1Click, function()
        Settings.TeleportDistance =
            math.min(
                10000,
                Settings.TeleportDistance
                    + 50
            )
        teleportLabel.Text =
            "Teleport Distance: "
            .. Settings.TeleportDistance
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
            main.Visible =
                not main.Visible
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
            Settings.AimEnabled
        updateAim(dt)
        updateTriggerbot()
        applyWalkSpeed()
        updateFly(dt)
        applyJumpPower()
        espTimer += dt
        if
            (Settings.ESPEnabled or Settings.TargetedESPEnabled)
            and espTimer >= 1
        then
            espTimer = 0
            refreshESP()
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
log("Panel ready.")
log("Use the tabs to switch tests.")
log("Right Shift hides and shows the panel.")

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
-- Destroying/replacing the GUI also stops the old loops and restores state.
local function cleanup()
    if not running then return end
    running = false
    stopSpin()
    releaseTriggerTool()
    disableFreecam()
    setNoclip(false)
    clearESP()
    restoreStatEdits()
    for humanoid, original in pairs(State.HumanoidDefaults) do
        if humanoid.Parent then
            humanoid.WalkSpeed = original.WalkSpeed
            humanoid.JumpPower = original.JumpPower
            humanoid.UseJumpPower = original.UseJumpPower
        end
    end
    for _, connection in ipairs(connections) do connection:Disconnect() end
end
connect(gui.Destroying, cleanup)
connect(script.Destroying, function()
    cleanup()
    if gui.Parent then gui:Destroy() end
end)
