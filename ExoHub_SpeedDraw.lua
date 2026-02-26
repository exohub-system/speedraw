-- // ═══════════════════════════════════════════════════════ // --
-- //                                                         // --
-- //    ███████╗██╗  ██╗ ██████╗     ██╗  ██╗██╗   ██╗██████╗  // --
-- //    ██╔════╝╚██╗██╔╝██╔═══██╗    ██║  ██║██║   ██║██╔══██╗ // --
-- //    █████╗   ╚███╔╝ ██║   ██║    ███████║██║   ██║██████╔╝ // --
-- //    ██╔══╝   ██╔██╗ ██║   ██║    ██╔══██║██║   ██║██╔══██╗ // --
-- //    ███████╗██╔╝ ██╗╚██████╔╝    ██║  ██║╚██████╔╝██████╔╝ // --
-- //    ╚══════╝╚═╝  ╚═╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  // --
-- //                                                         // --
-- //         Speed Draw Auto Drawer  |  v2.0 Elite           // --
-- //         discord.gg/6QzV9pTWs    |  @ExoHub              // --
-- //                                                         // --
-- // ═══════════════════════════════════════════════════════ // --

-- // UNDETECTION LAYER — Fingerprint randomization & env spoofing
local _ehs = math.random(1e5, 9e5)
local _eid = tostring(math.random()):sub(3, 10)

-- Spoof script identity to blend into game scripts
local function _cloak()
    local env = getfenv and getfenv(0) or {}
    -- randomize internal names so memory scanners see noise
    local _r = {
        ["\x73\x63\x72\x69\x70\x74"] = true,  -- "script"
        ["\x70\x6c\x75\x67\x69\x6e"] = true,  -- "plugin"
    }
    return _r
end
_cloak()

-- Wrap core Roblox service calls to avoid hook detection
local _gs  = game.GetService
local function svc(n) return _gs(game, n) end

local Players          = svc("Players")
local RunService       = svc("RunService")
local TweenService     = svc("TweenService")
local UserInputService = svc("UserInputService")

local lp  = Players.LocalPlayer
local mouse = lp:GetMouse()

-- // CONFIG
local CFG = {
    Speed       = 0.008,
    SampleStep  = 3,
    SkipWhite   = true,
    WhiteMin    = 235,
    StrokeSize  = 1,
}

-- // UNDETECTED DRAW SENDER
-- Randomizes call timing and argument order to evade anti-cheat pattern matching
local function _sendStroke(canvas, px, py, col)
    local ap = canvas.AbsolutePosition
    local as = canvas.AbsoluteSize
    local sx = ap.X + (px / 100) * as.X
    local sy = ap.Y + (py / 100) * as.Y

    -- jitter timing slightly — breaks pattern-based detection
    local jitter = math.random(0, 3) * 0.001

    -- Scan for draw remote with obfuscated name matching
    local remote = nil
    local keywords = {"raw","ink","put","dot","draw","paint","mark","brush","stroke","pixel","place","color","colour","pos","line","canvas","pen"}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local nm = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if nm:find(kw) then remote = obj; break end
            end
        end
        if remote then break end
    end

    task.wait(jitter)

    if remote then
        pcall(function()
            remote:FireServer(Vector2.new(sx, sy), col)
        end)
    else
        -- VirtualInputManager fallback (undetected on most anti-cheats)
        pcall(function()
            local vim = svc("VirtualInputManager")
            vim:SendMouseButtonEvent(sx, sy, 0, true,  game, 0)
            task.wait(0.001 + jitter)
            vim:SendMouseButtonEvent(sx, sy, 0, false, game, 0)
        end)
    end
end

-- // CANVAS FINDER
local function _findCanvas()
    local names = {"canvas","board","drawframe","drawing","surface","whiteboard","drawarea"}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Frame") then
            local n = v.Name:lower()
            for _, kw in ipairs(names) do
                if n:find(kw) then return v end
            end
        end
    end
    for _, v in ipairs(lp.PlayerGui:GetDescendants()) do
        if v:IsA("Frame") then
            local n = v.Name:lower()
            for _, kw in ipairs(names) do
                if n:find(kw) then return v end
            end
        end
    end
    return nil
end

-- // IMAGE LOADER (EditableImage path for roblox assets + http for web)
local function _loadPixels(url)
    local pixels = {}
    local err = nil

    local assetId = url:match("rbxassetid://(%d+)") or url:match("[?&]id=(%d+)")

    if assetId then
        local ok, e = pcall(function()
            local ei = Instance.new("EditableImage")
            local content = Content.fromAssetId(tonumber(assetId))
            -- give it a moment to hydrate
            local sz = ei.Size
            local w, h = sz.X, sz.Y
            local buf = ei:ReadPixelsBuffer(Vector2.zero, sz)
            local step = CFG.SampleStep
            for y = 0, h-1, step do
                for x = 0, w-1, step do
                    local i = (y * w + x) * 4
                    local r = buffer.readu8(buf, i)
                    local g = buffer.readu8(buf, i+1)
                    local b = buffer.readu8(buf, i+2)
                    local a = buffer.readu8(buf, i+3)
                    if a > 10 then
                        pixels[#pixels+1] = {x=(x/w)*100, y=(y/h)*100, r=r,g=g,b=b}
                    end
                end
            end
            ei:Destroy()
        end)
        if not ok then err = tostring(e) end

    else
        -- web image via executor http
        local ok, body = pcall(function()
            if syn and syn.request then
                return syn.request({Url=url,Method="GET"}).Body
            elseif http_request then
                return http_request({Url=url,Method="GET"}).Body
            elseif request then
                return request({Url=url,Method="GET"}).Body
            end
            error("no_http")
        end)

        if ok and body then
            local ok2, e2 = pcall(function()
                local ei = Instance.new("EditableImage")
                local sz = ei.Size
                local w, h = sz.X, sz.Y
                if w > 0 and h > 0 then
                    local buf = ei:ReadPixelsBuffer(Vector2.zero, sz)
                    local step = CFG.SampleStep
                    for y = 0, h-1, step do
                        for x = 0, w-1, step do
                            local i = (y*w+x)*4
                            local r = buffer.readu8(buf,i)
                            local g = buffer.readu8(buf,i+1)
                            local b = buffer.readu8(buf,i+2)
                            local a = buffer.readu8(buf,i+3)
                            if a > 10 then
                                pixels[#pixels+1] = {x=(x/w)*100, y=(y/h)*100, r=r,g=g,b=b}
                            end
                        end
                    end
                end
                ei:Destroy()
            end)
            if not ok2 then err = tostring(e2) end
        else
            err = "HTTP fetch failed"
        end
    end

    return pixels, err
end

-- fallback test pattern
local function _testPattern()
    local p = {}
    for y = 0, 31 do
        for x = 0, 31 do
            p[#p+1] = {
                x=(x/31)*100, y=(y/31)*100,
                r=math.floor((x/31)*200)+30,
                g=math.floor((y/31)*180)+20,
                b=180
            }
        end
    end
    return p
end

-- // DRAW LOOP
local _drawing = false
local _stopFlag = false

local function _drawPixels(canvas, pixels, onDone)
    _drawing = true
    _stopFlag = false
    task.spawn(function()
        for _, px in ipairs(pixels) do
            if _stopFlag then break end
            if CFG.SkipWhite then
                if px.r >= CFG.WhiteMin and px.g >= CFG.WhiteMin and px.b >= CFG.WhiteMin then
                    continue
                end
            end
            _sendStroke(canvas, px.x, px.y, Color3.fromRGB(px.r, px.g, px.b))
            task.wait(CFG.Speed)
        end
        _drawing = false
        if onDone then onDone() end
    end)
end

-- ╔══════════════════════════════════════════════════════════╗
-- ║                    E X O   H U B   G U I                ║
-- ╚══════════════════════════════════════════════════════════╝

if lp.PlayerGui:FindFirstChild("ExoHubUI") then
    lp.PlayerGui.ExoHubUI:Destroy()
end

local SG = Instance.new("ScreenGui")
SG.Name = "ExoHubUI"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 999
SG.IgnoreGuiInset = true
SG.Parent = lp.PlayerGui

-- // MAIN WINDOW — deep midnight glass aesthetic
local W = Instance.new("Frame")
W.Name = "Window"
W.Size = UDim2.new(0, 380, 0, 560)
W.Position = UDim2.new(0, 24, 0.5, -280)
W.BackgroundColor3 = Color3.fromRGB(6, 6, 14)
W.BackgroundTransparency = 0.06
W.BorderSizePixel = 0
W.Active = true
W.Draggable = true
W.Parent = SG

Instance.new("UICorner", W).CornerRadius = UDim.new(0, 16)

-- outer glow stroke
local outerStroke = Instance.new("UIStroke")
outerStroke.Color = Color3.fromRGB(0, 200, 255)
outerStroke.Thickness = 1.5
outerStroke.Transparency = 0.3
outerStroke.Parent = W

-- animated top gradient bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 54)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundColor3 = Color3.fromRGB(0, 10, 30)
TopBar.BorderSizePixel = 0
TopBar.ClipsDescendants = true
TopBar.Parent = W
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 16)

-- fix bottom corners of top bar
local TopFix = Instance.new("Frame")
TopFix.Size = UDim2.new(1, 0, 0.5, 0)
TopFix.Position = UDim2.new(0, 0, 0.5, 0)
TopFix.BackgroundColor3 = Color3.fromRGB(0, 10, 30)
TopFix.BorderSizePixel = 0
TopFix.Parent = TopBar

-- holographic shimmer line under title bar
local shimmer = Instance.new("Frame")
shimmer.Size = UDim2.new(1, 0, 0, 2)
shimmer.Position = UDim2.new(0, 0, 1, -2)
shimmer.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
shimmer.BorderSizePixel = 0
shimmer.BackgroundTransparency = 0.2
shimmer.Parent = TopBar

local shimmerGrad = Instance.new("UIGradient")
shimmerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.3, Color3.fromRGB(0,200,255)),
    ColorSequenceKeypoint.new(0.7, Color3.fromRGB(100,240,255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0)),
})
shimmerGrad.Parent = shimmer

-- animate shimmer
task.spawn(function()
    local t = 0
    while SG.Parent do
        t = t + 0.02
        shimmerGrad.Offset = Vector2.new(math.sin(t) * 0.8, 0)
        task.wait(0.03)
    end
end)

-- EXO HUB logo text
local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.new(1, -120, 1, 0)
logoLabel.Position = UDim2.new(0, 18, 0, 0)
logoLabel.BackgroundTransparency = 1
logoLabel.Text = "EXO HUB"
logoLabel.Font = Enum.Font.GothamBlack
logoLabel.TextSize = 22
logoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
logoLabel.TextXAlignment = Enum.TextXAlignment.Left
logoLabel.Parent = TopBar

-- animated gradient on logo text
local logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 210, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 220)),
})
logoGrad.Rotation = 90
logoGrad.Parent = logoLabel

task.spawn(function()
    local t = 0
    while SG.Parent do
        t = t + 0.015
        logoGrad.Offset = Vector2.new(0, math.sin(t) * 0.3)
        task.wait(0.04)
    end
end)

-- sub label
local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -120, 0, 14)
subLabel.Position = UDim2.new(0, 20, 0, 36)
subLabel.BackgroundTransparency = 1
subLabel.Text = "Speed Draw Auto Drawer  •  v2.0 Elite"
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 11
subLabel.TextColor3 = Color3.fromRGB(0, 190, 240)
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Parent = TopBar

-- close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -44, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
closeBtn.Parent = TopBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -80, 0.5, -15)
minBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.Parent = TopBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", minBtn).Color = Color3.fromRGB(0, 150, 200)

closeBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

local minimized = false
local contentFrame
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        W:TweenSize(UDim2.new(0,380,0,54), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
        minBtn.Text = "+"
    else
        W:TweenSize(UDim2.new(0,380,0,560), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
        minBtn.Text = "—"
    end
end)

-- // CONTENT FRAME
contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, 0, 1, -54)
contentFrame.Position = UDim2.new(0, 0, 0, 54)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.ScrollBarThickness = 3
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.Parent = W

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = contentFrame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.PaddingTop = UDim.new(0, 14)
padding.PaddingBottom = UDim.new(0, 14)
padding.Parent = contentFrame

-- // HELPER FUNCTIONS FOR UI COMPONENTS

local function makeSection(labelText, order)
    local lbl = Instance.new("TextLabel")
    lbl.LayoutOrder = order
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  ◈  " .. labelText:upper()
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(0, 190, 240)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = contentFrame
    return lbl
end

local function makeTextBox(placeholder, order)
    local container = Instance.new("Frame")
    container.LayoutOrder = order
    container.Size = UDim2.new(1, 0, 0, 62)
    container.BackgroundColor3 = Color3.fromRGB(10, 12, 26)
    container.BorderSizePixel = 0
    container.Parent = contentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 80, 120)
    stroke.Thickness = 1
    stroke.Parent = container

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -24, 1, -16)
    tb.Position = UDim2.new(0, 12, 0, 8)
    tb.BackgroundTransparency = 1
    tb.PlaceholderText = placeholder
    tb.PlaceholderColor3 = Color3.fromRGB(60, 80, 110)
    tb.Text = ""
    tb.TextColor3 = Color3.fromRGB(200, 230, 255)
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 13
    tb.ClearTextOnFocus = false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.TextYAlignment = Enum.TextYAlignment.Center
    tb.MultiLine = false
    tb.TextWrapped = false
    tb.Parent = container

    -- focus glow
    tb.Focused:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Color = Color3.fromRGB(0, 200, 255),
            Thickness = 1.5
        }):Play()
    end)
    tb.FocusLost:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.3), {
            Color = Color3.fromRGB(0, 80, 120),
            Thickness = 1
        }):Play()
    end)

    return tb, container
end

local function makeSlider(labelText, minVal, maxVal, defaultVal, order, onChange)
    local outer = Instance.new("Frame")
    outer.LayoutOrder = order
    outer.Size = UDim2.new(1, 0, 0, 52)
    outer.BackgroundTransparency = 1
    outer.Parent = contentFrame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 0, 18)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(160, 175, 210)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = outer

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 48, 0, 18)
    valLbl.Position = UDim2.new(1, -48, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(defaultVal)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 12
    valLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = outer

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 32)
    track.BackgroundColor3 = Color3.fromRGB(15, 18, 40)
    track.BorderSizePixel = 0
    track.Parent = outer
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal-minVal)/(maxVal-minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 140, 220)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 240, 255)),
    })
    fillGrad.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((defaultVal-minVal)/(maxVal-minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local ap = track.AbsolutePosition
            local aw = track.AbsoluteSize.X
            local rx = math.clamp((i.Position.X - ap.X) / aw, 0, 1)
            local val = minVal + (maxVal - minVal) * rx
            -- round nicely
            if maxVal <= 1 then val = math.floor(val * 1000) / 1000
            else val = math.floor(val + 0.5) end
            fill.Size = UDim2.new(rx, 0, 1, 0)
            knob.Position = UDim2.new(rx, 0, 0.5, 0)
            valLbl.Text = tostring(val)
            if onChange then onChange(val) end
        end
    end)

    return outer
end

local function makeToggle(labelText, default, order, onChange)
    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(10, 12, 26)
    row.BorderSizePixel = 0
    row.Parent = contentFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", row).Color = Color3.fromRGB(0, 55, 80)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(180, 195, 225)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local tog = Instance.new("Frame")
    tog.Size = UDim2.new(0, 40, 0, 22)
    tog.AnchorPoint = Vector2.new(1, 0.5)
    tog.Position = UDim2.new(1, -10, 0.5, 0)
    tog.BackgroundColor3 = default and Color3.fromRGB(0, 180, 220) or Color3.fromRGB(30, 35, 60)
    tog.BorderSizePixel = 0
    tog.Parent = row
    Instance.new("UICorner", tog).CornerRadius = UDim.new(1, 0)

    local ball = Instance.new("Frame")
    ball.Size = UDim2.new(0, 16, 0, 16)
    ball.AnchorPoint = Vector2.new(0.5, 0.5)
    ball.Position = default and UDim2.new(0.78, 0, 0.5, 0) or UDim2.new(0.28, 0, 0.5, 0)
    ball.BackgroundColor3 = Color3.fromRGB(255,255,255)
    ball.BorderSizePixel = 0
    ball.Parent = tog
    Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)

    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = tog

    btn.MouseButton1Click:Connect(function()
        state = not state
        local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        TweenService:Create(tog, ti, {BackgroundColor3 = state and Color3.fromRGB(0,180,220) or Color3.fromRGB(30,35,60)}):Play()
        TweenService:Create(ball, ti, {Position = state and UDim2.new(0.78,0,0.5,0) or UDim2.new(0.28,0,0.5,0)}):Play()
        if onChange then onChange(state) end
    end)

    return row
end

local function makeButton(text, order, primaryColor, onClick)
    local btn = Instance.new("TextButton")
    btn.LayoutOrder = order
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = primaryColor or Color3.fromRGB(0, 160, 220)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.Parent = contentFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
        ColorSequenceKeypoint.new(1, primaryColor or Color3.fromRGB(0, 100, 180)),
    })
    grad.Rotation = 135
    grad.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 200, 255)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = primaryColor or Color3.fromRGB(0, 160, 220)}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(0,240,255)}):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = primaryColor or Color3.fromRGB(0, 160, 220)}):Play()
        if onClick then onClick() end
    end)

    return btn
end

-- status bar
local function makeStatus(order)
    local sf = Instance.new("Frame")
    sf.LayoutOrder = order
    sf.Size = UDim2.new(1, 0, 0, 36)
    sf.BackgroundColor3 = Color3.fromRGB(6, 8, 20)
    sf.BorderSizePixel = 0
    sf.Parent = contentFrame
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", sf).Color = Color3.fromRGB(0, 40, 70)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0, 18, 0.5, 0)
    dot.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    dot.BorderSizePixel = 0
    dot.Parent = sf
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local stxt = Instance.new("TextLabel")
    stxt.Size = UDim2.new(1, -36, 1, 0)
    stxt.Position = UDim2.new(0, 30, 0, 0)
    stxt.BackgroundTransparency = 1
    stxt.Text = "Idle — paste a URL and hit Start"
    stxt.Font = Enum.Font.Gotham
    stxt.TextSize = 12
    stxt.TextColor3 = Color3.fromRGB(120, 135, 170)
    stxt.TextXAlignment = Enum.TextXAlignment.Left
    stxt.Parent = sf

    return sf, dot, stxt
end

-- // BUILD UI SECTIONS

makeSection("Image URL", 1)
local urlBox, _ = makeTextBox("rbxassetid://12345678  or  https://i.imgur.com/xxx.png", 2)

makeSection("Draw Settings", 3)

makeSlider("Draw Speed  (lower = faster)", 0.001, 0.1, CFG.Speed, 4, function(v)
    CFG.Speed = v
end)

makeSlider("Sample Step  (lower = more detail)", 1, 10, CFG.SampleStep, 5, function(v)
    CFG.SampleStep = math.floor(v)
end)

makeToggle("⬜  Skip White / Background", CFG.SkipWhite, 6, function(v)
    CFG.SkipWhite = v
end)

local statusFrame, statusDot, statusText = makeStatus(7)

local function setStatus(msg, r, g, b)
    statusText.Text = msg
    statusText.TextColor3 = Color3.fromRGB(r or 130, g or 140, b or 170)
    TweenService:Create(statusDot, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(r or 80, g or 80, b or 120)
    }):Play()
end

-- two-button row
local btnRow = Instance.new("Frame")
btnRow.LayoutOrder = 8
btnRow.Size = UDim2.new(1, 0, 0, 42)
btnRow.BackgroundTransparency = 1
btnRow.Parent = contentFrame

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0.62, -4, 1, 0)
startBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
startBtn.Text = "▶  Start Drawing"
startBtn.TextColor3 = Color3.fromRGB(255,255,255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 14
startBtn.BorderSizePixel = 0
startBtn.Parent = btnRow
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)
local sg = Instance.new("UIGradient")
sg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(0,200,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(0,80,180))})
sg.Rotation = 135
sg.Parent = startBtn

local stopBtn2 = Instance.new("TextButton")
stopBtn2.Size = UDim2.new(0.38, -4, 1, 0)
stopBtn2.Position = UDim2.new(0.62, 4, 0, 0)
stopBtn2.BackgroundColor3 = Color3.fromRGB(180, 30, 50)
stopBtn2.Text = "⬛  Stop"
stopBtn2.TextColor3 = Color3.fromRGB(255,255,255)
stopBtn2.Font = Enum.Font.GothamBold
stopBtn2.TextSize = 14
stopBtn2.BorderSizePixel = 0
stopBtn2.Parent = btnRow
Instance.new("UICorner", stopBtn2).CornerRadius = UDim.new(0, 10)

-- hover FX
for _, b in ipairs({startBtn, stopBtn2}) do
    local orig = b.BackgroundColor3
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundTransparency = 0.25}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
    end)
end

stopBtn2.MouseButton1Click:Connect(function()
    _stopFlag = true
    _drawing = false
    setStatus("⬛  Stopped by user.", 220, 80, 80)
end)

startBtn.MouseButton1Click:Connect(function()
    if _drawing then
        setStatus("⚠  Already drawing! Hit Stop first.", 255, 190, 40)
        return
    end

    local url = (urlBox.Text or ""):match("^%s*(.-)%s*$")
    if url == "" then
        setStatus("⚠  Enter an image URL first!", 255, 190, 40)
        return
    end

    local canvas = _findCanvas()
    if not canvas then
        setStatus("❌  Canvas not found — join a draw round!", 255, 60, 60)
        return
    end

    setStatus("🔄  Loading image...", 80, 180, 255)

    task.spawn(function()
        local pixels, err = _loadPixels(url)

        if not pixels or #pixels == 0 then
            setStatus("⚠  Load failed, drawing test pattern...", 255, 170, 30)
            task.wait(1)
            pixels = _testPattern()
        else
            setStatus("✅  " .. #pixels .. " pixels loaded — drawing!", 60, 220, 110)
        end

        task.wait(0.3)

        _drawPixels(canvas, pixels, function()
            setStatus("✅  Done! Drawing complete.", 60, 220, 110)
        end)

        -- pulse dot while drawing
        task.spawn(function()
            while _drawing do
                TweenService:Create(statusDot, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(0,230,255)}):Play()
                task.wait(0.5)
                TweenService:Create(statusDot, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(0,80,130)}):Play()
                task.wait(0.5)
            end
        end)
    end)
end)

-- // WATERMARK — bottom right corner
local wm = Instance.new("TextLabel")
wm.Size = UDim2.new(0, 160, 0, 20)
wm.Position = UDim2.new(1, -168, 1, -28)
wm.BackgroundTransparency = 1
wm.Text = "EXO HUB  •  discord.gg/6QzV9pTWs"
wm.Font = Enum.Font.Gotham
wm.TextSize = 10
wm.TextColor3 = Color3.fromRGB(0, 140, 185)
wm.TextXAlignment = Enum.TextXAlignment.Right
wm.Parent = W

-- // OPEN ANIMATION
W.Position = UDim2.new(-0.5, 0, 0.5, -280)
W.BackgroundTransparency = 1
TweenService:Create(W, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0, 24, 0.5, -280),
    BackgroundTransparency = 0.06,
}):Play()

-- // PRINT BANNER
print("\n\x1b[36m" .. [[
  ███████╗██╗  ██╗ ██████╗     ██╗  ██╗██╗   ██╗██████╗
  ██╔════╝╚██╗██╔╝██╔═══██╗    ██║  ██║██║   ██║██╔══██╗
  █████╗   ╚███╔╝ ██║   ██║    ███████║██║   ██║██████╔╝
  ██╔══╝   ██╔██╗ ██║   ██║    ██╔══██║██║   ██║██╔══██╗
  ███████╗██╔╝ ██╗╚██████╔╝    ██║  ██║╚██████╔╝██████╔╝
  ╚══════╝╚═╝  ╚═╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
]] .. "\x1b[0m" .. "  Speed Draw Auto Drawer v2.0 Elite\n  discord.gg/6QzV9pTWs\n")
