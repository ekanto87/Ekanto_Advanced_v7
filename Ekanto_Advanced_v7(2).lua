--[[
    EKANTO v6.0 "AURORA"
    Universal Local Panel — client-side ScreenGui (single LocalScript)

    SECTIONS
      1. Services
      2. Theme / Constants / Key check
      3. Config & Runtime State (+ central Loop, error handler)
      4. Utilities (drag inertia, ripple, arrows, smooth theme tween)
      5. Config IO (versioned, XOR+base64, per-game files)
      6. Physics / Cheat Systems (God, Invis, AntiTrip, Fly, Speed, Aura, ESP+, Noclip, AntiAFK, Env)
      7. Lifecycle, Main Loop, Cleanup
      8. UI Framework (Toast, Tooltip, Sfx, Slider, Toggle, Button)
      9. Main Panel (tabs, waypoints, servers, palette, context menu, HUD + sparkline)
     10. Verification Gate (typewriter boot, keypad, glitch)
     11. Boot
]]

-- ============================================================
-- 1. SERVICES
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

while not Players.LocalPlayer do task.wait() end
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- 2. THEME / CONSTANTS
-- ============================================================
-- The key is never stored as a literal: the input is hashed and compared to a masked constant.
local KEY_LEN, KEY_SALT, KEY_MASK, KEY_HASH = 4, 13, 0x5A5A5A5A, 1580920994
local function checkKey(input)
    if type(input) ~= "string" or #input ~= KEY_LEN then return false end
    local h = 0
    for i = 1, #input do
        h = (h * 257 + string.byte(input, i) + KEY_SALT) % 1000000007
    end
    return bit32.bxor(h, KEY_MASK) == KEY_HASH
end
local KEY_REMEMBER_SECONDS = 3600 -- re-running within this window skips the key prompt
local GUI_NAME = "EkantoCyberPanel"
local CONFIG_FILE = "EkantoConfig.json"
local GAME_CONFIG_FILE = "EkantoConfig_" .. tostring(game.PlaceId) .. ".json"
local CONFIG_VERSION = 2
local INSTAGRAM_URL = "https://instagram.com"

local Theme = {
    Black = Color3.fromRGB(0, 0, 0),
    Dark = Color3.fromRGB(18, 18, 18),
    White = Color3.fromRGB(255, 255, 255),
    Cyan = Color3.fromRGB(0, 240, 255),
    Green = Color3.fromRGB(57, 255, 130),
    Red = Color3.fromRGB(255, 59, 48),
    Track = Color3.fromRGB(45, 45, 45),
    Off = Color3.fromRGB(150, 150, 150),
    HoverGrey = Color3.fromRGB(60, 60, 60),
    Font = Enum.Font.GothamMedium,
    SubText = Color3.fromRGB(228, 228, 228),
}

local THEME_PRESETS = {
    { name = "Neon",   c1 = Color3.fromRGB(0, 240, 255),   c2 = Color3.fromRGB(57, 255, 130),  dark = Color3.fromRGB(0, 70, 35) },
    { name = "Violet", c1 = Color3.fromRGB(180, 110, 255), c2 = Color3.fromRGB(255, 90, 220),  dark = Color3.fromRGB(60, 20, 70) },
    { name = "Ember",  c1 = Color3.fromRGB(255, 170, 40),  c2 = Color3.fromRGB(255, 84, 64),   dark = Color3.fromRGB(80, 35, 10) },
    { name = "Ocean",  c1 = Color3.fromRGB(70, 150, 255),  c2 = Color3.fromRGB(0, 230, 200),   dark = Color3.fromRGB(0, 50, 70) },
    { name = "Sakura", c1 = Color3.fromRGB(255, 130, 180), c2 = Color3.fromRGB(255, 200, 120), dark = Color3.fromRGB(80, 30, 50) },
    { name = "Mono",   c1 = Color3.fromRGB(235, 235, 235), c2 = Color3.fromRGB(150, 200, 255), dark = Color3.fromRGB(50, 50, 62) },
}
Theme.OnDark = THEME_PRESETS[1].dark

-- readable font presets (missing enum items are skipped safely)
local FONT_PRESETS = {}
do
    local function add(name, enumName, sizeOffset)
        local ok, f = pcall(function() return Enum.Font[enumName] end)
        if ok and f then table.insert(FONT_PRESETS, { name = name, font = f, off = sizeOffset }) end
    end
    add("Clean", "GothamSemibold", 0)
    add("Sharp", "SourceSansBold", 2)
    add("Modern", "BuilderSansMedium", 0)
    add("Retro", "Code", 0)
    if #FONT_PRESETS == 0 then table.insert(FONT_PRESETS, { name = "Clean", font = Enum.Font.GothamMedium, off = 0 }) end
end
local function fontPreset(name)
    for _, f in ipairs(FONT_PRESETS) do
        if f.name == name then return f end
    end
    return FONT_PRESETS[1]
end

-- maps ANY preset accent color to the currently active one (nil if not an accent)
local function themeMap(c)
    for _, p in ipairs(THEME_PRESETS) do
        if c == p.c1 then return Theme.Cyan
        elseif c == p.c2 then return Theme.Green
        elseif c == p.dark then return Theme.OnDark end
    end
    return nil
end

local function setThemeColors(name)
    for _, p in ipairs(THEME_PRESETS) do
        if p.name == name then
            Theme.Cyan, Theme.Green, Theme.OnDark = p.c1, p.c2, p.dark
            return true
        end
    end
    return false
end

local HOVER_SCALE = 1 -- no zoom on hover: scaled text renders blurry
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING_INFO = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local ENTRY_START_SCALE = 0.96
local ENTRY_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local PANEL_SIZE = UDim2.fromOffset(560, 430)
local MINI_SIZE = UDim2.fromOffset(52, 52)
local PanelSize = PANEL_SIZE -- live size (user can resize the window)

local SPEED_MIN, SPEED_MAX = 16, 250
local FLY_MIN, FLY_MAX, FLY_SMOOTHING = 10, 300, 14
local DEFAULT_WALKSPEED = 16

local AURA_RADIUS, AURA_PUSH, AURA_LIFT = 20, 300, 120
local AURA_COOLDOWN, AURA_INTERVAL, AURA_SWING_INTERVAL = 0.25, 0.05, 0.12

local TOOLTIP_MAX_W = 240
local TOAST_TEXT_W = 274

local WAYPOINT_SLOTS = 8
local SPARK_SAMPLES = 60 -- 1 sample / second = 60s of FPS history

-- Sound design. Built-in client sounds are used so nothing depends on a catalog upload;
-- swap any "id" for an "rbxassetid://<number>" of your choice. vol is the base volume (0-1),
-- multiplied by the master volume slider in Settings.
local SOUND_IDS = {
    hover = { id = "rbxasset://sounds/clickfast.wav", vol = 0.10, pitch = 1.9 },
    click = { id = "rbxasset://sounds/button.wav",    vol = 0.20, pitch = 1.0 },
    on    = { id = "rbxasset://sounds/switch.wav",    vol = 0.26, pitch = 1.25 },
    off   = { id = "rbxasset://sounds/switch.wav",    vol = 0.26, pitch = 0.78 },
}

-- ============================================================
-- 3. CONFIG & RUNTIME STATE
-- ============================================================
local TOGGLE_KEYS = { "fly", "godMode", "invisible", "esp", "aura", "optimizer", "noFog", "fullBright",
    "noclip", "antiAfk", "espInfo" }
-- physical actions (fly, aura, noclip) are never auto-restored on load
local PASSIVE_RESTORE = { godMode = true, invisible = true, esp = true,
    optimizer = true, noFog = true, fullBright = true, antiAfk = true, espInfo = true }

local DEFAULT_CONFIG = {
    speed = SPEED_MIN, flySpeed = 50,
    fly = false, godMode = false, invisible = false, esp = false,
    aura = false, optimizer = false, noFog = false, fullBright = false,
    noclip = false, antiAfk = false, espInfo = true,
    -- v6 settings
    version = CONFIG_VERSION, volume = 40, perGame = false, waypoints = {},
    -- v5 settings
    theme = "Neon", uiScale = 100, toasts = true, hud = false, hopMax = 8,
    font = "Clean", textBoost = 1,
    panelW = PANEL_SIZE.X.Offset, panelH = PANEL_SIZE.Y.Offset,
    keys = { toggleUI = "RightControl", minimize = "M", fly = "F", noclip = "N", search = "Backquote" },
    profiles = {},
}
local DEFAULT_KEYS = { toggleUI = "RightControl", minimize = "M", fly = "F", noclip = "N", search = "Backquote" }
local PROFILE_TOGGLES = { "godMode", "invisible", "esp", "optimizer", "noFog", "fullBright" }

local function deepCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and deepCopy(v) or v end
    return out
end

local Cfg = deepCopy(DEFAULT_CONFIG)

local function userScale()
    return math.clamp((Cfg.uiScale or 100) / 100, 0.7, 1.4)
end
local function miniDelta()
    return UDim2.fromOffset(
        (MINI_SIZE.X.Offset - PanelSize.X.Offset) / 2 * userScale(),
        (MINI_SIZE.Y.Offset - PanelSize.Y.Offset) / 2 * userScale()
    )
end

local Runtime = { alive = true, mode = "idle", minimized = false }
local MiniState = { frame = nil, bag = nil }

local connections = {}
local animatedGradients = {}
local countups = {}
local ScreenGui

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local UI = { sliders = {}, toggles = {} }

-- ---------- Central loop: ONE Heartbeat connection dispatches every registered handler ----------
-- opts: interval (seconds, throttled), feature (config key auto-disabled on error), keep (never remove on error)
local Loop = { handlers = {}, conn = nil }
local Errors = { active = false, last = {} } -- report/disable are defined once Toast exists

function Loop.register(name, fn, opts)
    opts = opts or {}
    local h = { name = name, fn = fn, interval = opts.interval or 0, feature = opts.feature,
        keep = opts.keep, acc = 0, dead = false }
    table.insert(Loop.handlers, h)
    return h
end

function Loop.remove(h) h.dead = true end

function Loop.dispatch(dt)
    if not Runtime.alive then return end
    local list = Loop.handlers
    for i = #list, 1, -1 do
        if list[i].dead then table.remove(list, i) end
    end
    for i = 1, #list do
        local h = list[i]
        if not h.dead then
            local step, run = dt, true
            if h.interval > 0 then
                h.acc += dt
                if h.acc >= h.interval then step = h.acc; h.acc = 0 else run = false end
            end
            if run then
                local ok, err = pcall(h.fn, step)
                if not ok then
                    if not (h.feature or h.keep) then h.dead = true end
                    Errors.report(h.name, err, h.feature)
                end
            end
        end
    end
end

function Loop.start()
    if Loop.conn then return end
    Loop.conn = track(RunService.Heartbeat:Connect(Loop.dispatch))
end

-- runs fn; on failure shows a red toast and auto-disables `featureKey` (if any)
local function guard(label, featureKey, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Errors.report(label, err, featureKey) end
    return ok
end

-- ============================================================
-- 4. UTILITIES
-- ============================================================
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function create(className, props, parent)
    local inst = Instance.new(className)
    if TEXT_CLASSES[className] then
        inst.Font = Theme.Font
        inst.TextStrokeTransparency = 1
        inst.TextColor3 = Theme.White
    end
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

-- Smooth theme transitions: every accent color (backgrounds, text, strokes, gradient keypoints)
-- is lerped to the new theme over ~0.5s by the central loop.
local function themeRole(c)
    for _, p in ipairs(THEME_PRESETS) do
        if c == p.c1 then return "Cyan"
        elseif c == p.c2 then return "Green"
        elseif c == p.dark then return "OnDark" end
    end
    return nil
end

local ThemeFx = { items = nil, t = 0, dur = 0.5 }

function ThemeFx.collect()
    local items = {}
    local function scan(inst)
        pcall(function()
            if inst:GetAttribute("NoTheme") or (inst.Parent and inst.Parent:GetAttribute("NoTheme")) then return end
            if inst:IsA("GuiObject") then
                local r = themeRole(inst.BackgroundColor3)
                if r then table.insert(items, { inst = inst, prop = "BackgroundColor3", from = inst.BackgroundColor3, role = r }) end
                if TEXT_CLASSES[inst.ClassName] then
                    local tr = themeRole(inst.TextColor3)
                    if tr then table.insert(items, { inst = inst, prop = "TextColor3", from = inst.TextColor3, role = tr }) end
                end
            elseif inst:IsA("UIStroke") then
                local r = themeRole(inst.Color)
                if r then table.insert(items, { inst = inst, prop = "Color", from = inst.Color, role = r }) end
            elseif inst:IsA("UIGradient") then
                local kps, any = {}, false
                for _, kp in ipairs(inst.Color.Keypoints) do
                    local r = themeRole(kp.Value)
                    if r then any = true end
                    table.insert(kps, { time = kp.Time, from = kp.Value, role = r })
                end
                if any then table.insert(items, { inst = inst, kps = kps }) end
            end
        end)
    end
    if ScreenGui then
        for _, d in ipairs(ScreenGui:GetDescendants()) do scan(d) end
    end
    return items
end

function ThemeFx.apply(e)
    for _, it in ipairs(ThemeFx.items) do
        pcall(function()
            if not it.inst.Parent then return end
            if it.kps then
                local out = {}
                for _, k in ipairs(it.kps) do
                    out[#out + 1] = ColorSequenceKeypoint.new(k.time, k.to and k.from:Lerp(k.to, e) or k.from)
                end
                it.inst.Color = ColorSequence.new(out)
            else
                it.inst[it.prop] = it.from:Lerp(it.to, e)
            end
        end)
    end
end

-- snap pass: catches anything a running hover/spring tween dragged back to an old accent
function ThemeFx.settle()
    for _, it in ipairs(ThemeFx.collect()) do
        pcall(function()
            if it.kps then
                local out = {}
                for _, k in ipairs(it.kps) do
                    out[#out + 1] = ColorSequenceKeypoint.new(k.time, k.role and Theme[k.role] or k.from)
                end
                it.inst.Color = ColorSequence.new(out)
            else
                it.inst[it.prop] = Theme[it.role]
            end
        end)
    end
end

function ThemeFx.finish()
    if not ThemeFx.items then return end
    ThemeFx.apply(1)
    ThemeFx.items = nil
end

function ThemeFx.step(dt)
    if not ThemeFx.items then return end
    ThemeFx.t += dt
    local a = math.clamp(ThemeFx.t / ThemeFx.dur, 0, 1)
    ThemeFx.apply(1 - (1 - a) ^ 3) -- ease-out cubic
    if a >= 1 then
        ThemeFx.items = nil
        task.delay(0.35, function()
            if Runtime.alive and not ThemeFx.items then ThemeFx.settle() end
        end)
    end
end

-- chevron arrow built from plain frames (points UP at Rotation 0; no font/asset dependency)
local function buildArrow(parent, color, size)
    size = size or 24
    local k = size / 24
    local root = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1, ZIndex = 46,
    }, parent)
    local function bar(x, y, w, h, rot)
        create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x * k, y * k),
            Size = UDim2.fromOffset(math.max(2, w * k), h * k), Rotation = rot,
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 46,
        }, root)
    end
    bar(12, 12.5, 3, 20, 0)
    bar(8.5, 6.2, 3, 11, 40)
    bar(15.5, 6.2, 3, 11, -40)
    return root
end

local function getCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function neonGradient()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Cyan),
        ColorSequenceKeypoint.new(0.5, Theme.Green),
        ColorSequenceKeypoint.new(1, Theme.Cyan),
    })
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function addFlatStroke(parent, color, thickness)
    return create("UIStroke", {
        Color = color, Thickness = thickness or 1,
        Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function addGradientBorder(parent, thickness)
    local stroke = create("UIStroke", {
        Color = Theme.White, Thickness = thickness or 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
    table.insert(animatedGradients, create("UIGradient", { Color = neonGradient() }, stroke))
    return stroke
end

local function getGuiParent()
    local target = nil
    pcall(function()
        if typeof(gethui) == "function" then target = gethui() end
    end)
    if not target then
        pcall(function()
            local core = game:GetService("CoreGui")
            local test = Instance.new("Folder")
            test.Parent = core
            test:Destroy()
            target = core
        end)
    end
    return target or LocalPlayer:WaitForChild("PlayerGui")
end

local function measureText(text, size, maxWidth)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, Theme.Font, Vector2.new(maxWidth, 10000))
    end)
    if ok and typeof(bounds) == "Vector2" then
        return math.ceil(bounds.X) + 2, math.ceil(bounds.Y) + 2
    end
    local charsPerLine = math.max(1, math.floor(maxWidth / (size * 0.6)))
    return maxWidth, math.max(1, math.ceil(#text / charsPerLine)) * (size + 2)
end

-- Expanding click ring
local function ripple(parent, accent)
    pcall(function()
        local m = UserInputService:GetMouseLocation()
        local rel = m - parent.AbsolutePosition
        local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(rel.X, rel.Y),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = (accent and (themeMap(accent) or accent)) or Theme.Cyan,
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0, Active = false, ZIndex = 30,
        }, parent)
        addCorner(ring, 999)
        TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
        }):Play()
        task.delay(0.5, function() pcall(function() ring:Destroy() end) end)
    end)
end

-- Glide with damping after a drag release
-- keeps a GuiObject reachable: at least `margin` px stay on screen (works with Scale+Offset+AnchorPoint)
local function clampOnScreen(target, margin)
    margin = margin or 70
    pcall(function()
        local parent = target.Parent
        if not (parent and parent:IsA("GuiBase2d")) then return end
        local pv = parent.AbsoluteSize
        local size = target.AbsoluteSize
        local anchor = target.AnchorPoint
        local pos = target.Position
        local left = pos.X.Scale * pv.X + pos.X.Offset - anchor.X * size.X
        local top = pos.Y.Scale * pv.Y + pos.Y.Offset - anchor.Y * size.Y
        local cl = math.clamp(left, margin - size.X, pv.X - margin)
        local ct = math.clamp(top, 0, math.max(0, pv.Y - margin))
        if cl ~= left or ct ~= top then
            target.Position = UDim2.new(pos.X.Scale, pos.X.Offset + (cl - left),
                pos.Y.Scale, pos.Y.Offset + (ct - top))
        end
    end)
end

-- half-pixel positions make ALL text inside look blurry; this rounds the window onto whole pixels
local function snapToPixel(obj)
    pcall(function()
        local ap = obj.AbsolutePosition
        local fx, fy = ap.X % 1, ap.Y % 1
        if fx < 0.02 and fy < 0.02 then return end
        local dx = fx >= 0.5 and (1 - fx) or -fx
        local dy = fy >= 0.5 and (1 - fy) or -fy
        local pos = obj.Position
        obj.Position = UDim2.new(pos.X.Scale, pos.X.Offset + dx, pos.Y.Scale, pos.Y.Offset + dy)
    end)
end

local function glide(target, vel)
    task.spawn(function()
        while vel.Magnitude > 0.6 and target.Parent do
            local pos = target.Position
            target.Position = UDim2.new(pos.X.Scale, pos.X.Offset + vel.X, pos.Y.Scale, pos.Y.Offset + vel.Y)
            clampOnScreen(target)
            vel = vel * 0.86
            RunService.Heartbeat:Wait()
        end
        clampOnScreen(target)
        snapToPixel(target)
    end)
end

-- Drag with optional release inertia
local function makeDraggable(handle, target, onClick, bag, inertia)
    local function hold(conn)
        if bag then table.insert(bag, conn) else track(conn) end
        return conn
    end
    local dragging, moved = false, false
    local dragStart, startPos
    local lastPos, vel = nil, Vector2.zero

    hold(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart = input.Position
            startPos = target.Position
            lastPos = Vector2.new(startPos.X.Offset, startPos.Y.Offset)
            vel = Vector2.zero
            local endedConn
            endedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if endedConn then endedConn:Disconnect() end
                    if not moved and onClick then
                        pcall(onClick)
                    elseif inertia and vel.Magnitude > 2 then
                        glide(target, vel * 1.6)
                    elseif moved then
                        clampOnScreen(target)
                        snapToPixel(target)
                    end
                end
            end)
        end
    end))

    hold(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            pcall(function()
                local delta = input.Position - dragStart
                if delta.Magnitude > 4 then moved = true end
                if moved then
                    local nx = startPos.X.Offset + delta.X
                    local ny = startPos.Y.Offset + delta.Y
                    if lastPos then
                        local newPos = Vector2.new(nx, ny)
                        vel = newPos - lastPos
                        lastPos = newPos
                    end
                    target.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
                end
            end)
        end
    end))
end

-- ============================================================
-- 5. CONFIG IO
-- ============================================================
local PersistHooks = {} -- run right before saving (window pos/size etc.)

-- ---------- Obfuscation: XOR + base64 (pure Luau, no executor crypt API needed) ----------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_DEC = {}
for i = 1, #B64 do B64_DEC[string.byte(B64, i)] = i - 1 end
local CFG_PREFIX = "EK2:"
local XOR_KEY = "ekanto::cfg::v2::k7Qz"

local function xorStr(str)
    local out, kl = table.create(#str), #XOR_KEY
    for i = 1, #str do
        out[i] = string.char(bit32.bxor(string.byte(str, i), string.byte(XOR_KEY, (i - 1) % kl + 1)))
    end
    return table.concat(out)
end

local function b64enc(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2 = bit32.rshift(n, 18) % 64, bit32.rshift(n, 12) % 64
        local c3, c4 = bit32.rshift(n, 6) % 64, n % 64
        out[#out + 1] = string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
            .. (b and string.sub(B64, c3 + 1, c3 + 1) or "=") .. (c and string.sub(B64, c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function b64dec(text)
    text = string.gsub(text, "[^%w%+/=]", "")
    local out = {}
    for i = 1, #text, 4 do
        local a, b, c, d = string.byte(text, i, i + 3)
        local va, vb = B64_DEC[a], B64_DEC[b]
        if not va or not vb then return nil end
        local vc, vd = c and B64_DEC[c], d and B64_DEC[d]
        local n = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
        out[#out + 1] = string.char(bit32.rshift(n, 16) % 256)
        if vc then out[#out + 1] = string.char(bit32.rshift(n, 8) % 256) end
        if vd then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

local function encodeConfig(tbl)
    return CFG_PREFIX .. b64enc(xorStr(HttpService:JSONEncode(tbl)))
end

-- returns table, wasPlain  (plain JSON from v5 is still accepted and gets migrated on next save)
local function decodeConfig(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    if string.sub(raw, 1, #CFG_PREFIX) == CFG_PREFIX then
        local bin = b64dec(string.sub(raw, #CFG_PREFIX + 1))
        if not bin then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(xorStr(bin)) end)
        if ok and type(data) == "table" then return data, false end
        return nil
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(data) == "table" then return data, true end
    return nil
end

local function readCfgFile(path)
    local ok, raw = pcall(function()
        if isfile and not isfile(path) then return nil end
        return readfile(path)
    end)
    if not ok or type(raw) ~= "string" then return nil end
    return decodeConfig(raw)
end

local function saveConfig()
    for _, h in ipairs(PersistHooks) do pcall(h) end
    Cfg.version = CONFIG_VERSION
    local okAny = false
    local blob = encodeConfig(Cfg)
    -- the global file always exists (it carries the per-game flag); the per-game file is extra
    if pcall(function() writefile(CONFIG_FILE, blob) end) then okAny = true end
    if Cfg.perGame then
        if pcall(function() writefile(GAME_CONFIG_FILE, blob) end) then okAny = true end
    end
    return okAny
end

-- migrate an old config table forward to CONFIG_VERSION (in place)
local function migrateConfig(data)
    local v = type(data.version) == "number" and data.version or 1
    if v < 2 then
        -- v1 (Ekanto v5): no sounds / waypoints / extra keys
        if data.volume == nil then data.volume = 40 end
        if data.waypoints == nil then data.waypoints = {} end
        if data.perGame == nil then data.perGame = false end
        if data.espInfo == nil then data.espInfo = true end
        if type(data.keys) == "table" then
            data.keys.noclip = data.keys.noclip or DEFAULT_KEYS.noclip
            data.keys.search = data.keys.search or DEFAULT_KEYS.search
        end
        v = 2
    end
    -- future: if v < 3 then ... v = 3 end
    data.version = v
    return data
end

local function applyConfigData(data)
    migrateConfig(data)
    if type(data.speed) == "number" then
        Cfg.speed = math.clamp(math.floor(data.speed + 0.5), SPEED_MIN, SPEED_MAX)
    end
    if type(data.flySpeed) == "number" then
        Cfg.flySpeed = math.clamp(math.floor(data.flySpeed + 0.5), FLY_MIN, FLY_MAX)
    end
    for _, k in ipairs(TOGGLE_KEYS) do
        if type(data[k]) == "boolean" then Cfg[k] = data[k] end
    end
    if type(data.theme) == "string" then
        for _, pr in ipairs(THEME_PRESETS) do
            if pr.name == data.theme then Cfg.theme = pr.name end
        end
    end
    if type(data.uiScale) == "number" then Cfg.uiScale = math.clamp(math.floor(data.uiScale + 0.5), 70, 140) end
    if type(data.toasts) == "boolean" then Cfg.toasts = data.toasts end
    if type(data.hud) == "boolean" then Cfg.hud = data.hud end
    if type(data.font) == "string" then
        for _, f in ipairs(FONT_PRESETS) do
            if f.name == data.font then Cfg.font = f.name end
        end
    end
    if type(data.textBoost) == "number" then Cfg.textBoost = math.clamp(math.floor(data.textBoost + 0.5), 0, 4) end
    if type(data.verifiedAt) == "number" then Cfg.verifiedAt = data.verifiedAt end
    if type(data.hopMax) == "number" then Cfg.hopMax = math.clamp(math.floor(data.hopMax + 0.5), 1, 30) end
    if type(data.panelW) == "number" then Cfg.panelW = math.clamp(math.floor(data.panelW), 420, 900) end
    if type(data.panelH) == "number" then Cfg.panelH = math.clamp(math.floor(data.panelH), 320, 760) end
    if type(data.posX) == "number" and type(data.posY) == "number" then
        Cfg.posX, Cfg.posY = data.posX, data.posY
    end
    -- v6 fields
    if type(data.volume) == "number" then Cfg.volume = math.clamp(math.floor(data.volume + 0.5), 0, 100) end
    if type(data.perGame) == "boolean" then Cfg.perGame = data.perGame end
    if type(data.keys) == "table" then
        for action in pairs(DEFAULT_KEYS) do
            local name = data.keys[action]
            if type(name) == "string" and name ~= "Unknown" then
                local okk, kc = pcall(function() return Enum.KeyCode[name] end)
                if okk and kc then Cfg.keys[action] = name end
            end
        end
    end
    if type(data.profiles) == "table" then
        for i = 1, 3 do
            local pr = data.profiles[tostring(i)]
            if type(pr) == "table" and type(pr.speed) == "number" and type(pr.flySpeed) == "number" then
                local clean = {
                    speed = math.clamp(math.floor(pr.speed + 0.5), SPEED_MIN, SPEED_MAX),
                    flySpeed = math.clamp(math.floor(pr.flySpeed + 0.5), FLY_MIN, FLY_MAX),
                }
                for _, k in ipairs(PROFILE_TOGGLES) do clean[k] = pr[k] == true end
                Cfg.profiles[tostring(i)] = clean
            end
        end
    end
    if type(data.waypoints) == "table" then
        Cfg.waypoints = {}
        for i = 1, WAYPOINT_SLOTS do
            local w = data.waypoints[tostring(i)]
            if type(w) == "table" and type(w.cf) == "table" and #w.cf == 12 then
                local good = true
                for _, n in ipairs(w.cf) do if type(n) ~= "number" or n ~= n then good = false end end
                if good then
                    Cfg.waypoints[tostring(i)] = { name = tostring(w.name or ("Slot " .. i)):sub(1, 18), cf = w.cf }
                end
            end
        end
    end
end

local function loadConfig()
    local data, wasPlain = readCfgFile(CONFIG_FILE)
    if not data then return false end
    applyConfigData(data)
    -- per-game override: only when enabled; falls back to the global values if the file is absent
    if Cfg.perGame then
        local gdata = readCfgFile(GAME_CONFIG_FILE)
        if gdata then
            local keepVerified, keepPerGame = Cfg.verifiedAt, Cfg.perGame
            applyConfigData(gdata)
            Cfg.verifiedAt, Cfg.perGame = keepVerified or Cfg.verifiedAt, keepPerGame
        end
    end
    if wasPlain then task.defer(function() pcall(saveConfig) end) end -- plain-JSON v5 file -> encoded v6
    return true
end

local saveToken = 0
local function scheduleSave()
    saveToken += 1
    local mine = saveToken
    task.delay(0.6, function()
        if mine == saveToken and Runtime.alive then pcall(saveConfig) end
    end)
end

-- live theme switch: tweens every accent over ~0.5s (see ThemeFx)
local function applyTheme(name)
    local before = { Theme.Cyan, Theme.Green, Theme.OnDark }
    if not setThemeColors(name) then return end
    Cfg.theme = name
    if ScreenGui then
        ThemeFx.finish() -- complete any transition still running
        local items = ThemeFx.collect()
        local roles = { Cyan = Theme.Cyan, Green = Theme.Green, OnDark = Theme.OnDark }
        for _, it in ipairs(items) do
            if it.kps then
                for _, k in ipairs(it.kps) do if k.role then k.to = roles[k.role] end end
            else
                it.to = roles[it.role]
            end
        end
        ThemeFx.items, ThemeFx.t = items, 0
    end
    scheduleSave()
end

-- global text style: font preset + size boost, applied to every label (also ones created later)
local function styleText(inst)
    if not TEXT_CLASSES[inst.ClassName] then return end
    if inst:GetAttribute("NoFont") or inst.Font == Enum.Font.RobotoMono then return end
    local base = inst:GetAttribute("BaseSize")
    if not base then
        base = inst.TextSize
        inst:SetAttribute("BaseSize", base)
    end
    local fp = fontPreset(Cfg.font)
    local boost = inst:GetAttribute("NoBoost") and 0 or (Cfg.textBoost or 0)
    inst.Font = fp.font
    inst.TextSize = base + boost + fp.off
end

local styleToken = 0
local function applyTextStyle(immediate)
    local function run()
        if not ScreenGui then return end
        for _, d in ipairs(ScreenGui:GetDescendants()) do pcall(styleText, d) end
    end
    if immediate then run() return end
    styleToken += 1
    local tok = styleToken
    task.delay(0.12, function()
        if tok == styleToken then run() end
    end)
end

-- ============================================================
-- 6. PHYSICS / CHEAT SYSTEMS
-- ============================================================

-- ---------- 6a. God Mode ----------
local originalCanTouch = setmetatable({}, { __mode = "k" })
local descendantConn = nil
local healthConn = nil

local God = {}

function God.setPart(part, disable)
    pcall(function()
        if disable then
            if originalCanTouch[part] == nil then originalCanTouch[part] = part.CanTouch end
            part.CanTouch = false
        else
            local orig = originalCanTouch[part]
            if orig ~= nil then part.CanTouch = orig; originalCanTouch[part] = nil end
        end
    end)
end

function God.applyToCharacter(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then God.setPart(d, true) end
    end
end

function God.restore()
    for part in pairs(originalCanTouch) do God.setPart(part, false) end
end

function God.step(hum)
    if Cfg.godMode and hum.Health > 0 and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
end

-- ---------- 6b. Invisibility + name tag ----------
local originalVisual = setmetatable({}, { __mode = "k" })
local originalDisplay = setmetatable({}, { __mode = "k" })

local Invis = {}

function Invis.hide(inst)
    pcall(function()
        if inst:IsA("BasePart") then
            if originalVisual[inst] == nil then
                originalVisual[inst] = { t = inst.Transparency, l = inst.LocalTransparencyModifier }
            end
            inst.Transparency = 1
            inst.LocalTransparencyModifier = 1
        elseif inst:IsA("Decal") then
            if originalVisual[inst] == nil then originalVisual[inst] = { t = inst.Transparency } end
            inst.Transparency = 1
        end
    end)
end

function Invis.setNameTag(hum, hidden)
    pcall(function()
        if hidden then
            if originalDisplay[hum] == nil then
                originalDisplay[hum] = hum.DisplayDistanceType
            end
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        else
            local orig = originalDisplay[hum]
            if orig ~= nil then
                hum.DisplayDistanceType = orig
                originalDisplay[hum] = nil
            end
        end
    end)
end

function Invis.applyToCharacter(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do Invis.hide(d) end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then Invis.setNameTag(hum, true) end
end

function Invis.restore()
    for inst, data in pairs(originalVisual) do
        pcall(function()
            if inst:IsA("BasePart") then
                inst.Transparency = data.t
                inst.LocalTransparencyModifier = data.l or 0
            elseif inst:IsA("Decal") then
                inst.Transparency = data.t
            end
        end)
        originalVisual[inst] = nil
    end
    for hum in pairs(originalDisplay) do Invis.setNameTag(hum, false) end
end

function Invis.step(hum)
    if not Cfg.invisible then return end
    for inst in pairs(originalVisual) do
        if inst and inst.Parent and inst:IsA("BasePart") then
            inst.LocalTransparencyModifier = 1
        end
    end
    if hum and hum.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
        Invis.setNameTag(hum, true)
    end
end

local function hookCharacter(char)
    if descendantConn then descendantConn:Disconnect(); descendantConn = nil end
    if healthConn then healthConn:Disconnect(); healthConn = nil end
    if not char then return end
    pcall(function()
        if Cfg.godMode then God.applyToCharacter(char) end
        if Cfg.invisible then Invis.applyToCharacter(char) end
        descendantConn = char.DescendantAdded:Connect(function(d)
            pcall(function()
                if Cfg.godMode and d:IsA("BasePart") then God.setPart(d, true) end
                if Cfg.invisible then Invis.hide(d) end
            end)
        end)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            healthConn = hum.HealthChanged:Connect(function(h)
                pcall(function()
                    if Cfg.godMode and h > 0 and h < hum.MaxHealth then
                        hum.Health = hum.MaxHealth
                    end
                end)
            end)
        end
    end)
end

-- ---------- 6c. Anti-Trip ----------
local AntiTrip = { humanoid = nil, att = nil, align = nil, lastFlatLook = Vector3.new(0, 0, -1) }

local blockedStates = {}
for _, name in ipairs({ "Ragdoll", "FallingDown", "Tripping" }) do
    local ok, item = pcall(function() return Enum.HumanoidStateType[name] end)
    if ok and item then table.insert(blockedStates, item) end
end

local function setBlockedStates(hum, enabled)
    for _, state in ipairs(blockedStates) do
        pcall(function() hum:SetStateEnabled(state, enabled) end)
    end
end

function AntiTrip.destroyAligner()
    if AntiTrip.align then pcall(function() AntiTrip.align:Destroy() end); AntiTrip.align = nil end
    if AntiTrip.att then pcall(function() AntiTrip.att:Destroy() end); AntiTrip.att = nil end
end

function AntiTrip.ensureAligner(hrp)
    if AntiTrip.att and AntiTrip.align
        and AntiTrip.att.Parent == hrp and AntiTrip.align.Parent == hrp then
        return
    end
    AntiTrip.destroyAligner()
    AntiTrip.att = create("Attachment", { Name = "EkantoUprightAtt" }, hrp)
    AntiTrip.align = create("AlignOrientation", {
        Name = "EkantoUpright",
        Mode = Enum.OrientationAlignmentMode.OneAttachment,
        Attachment0 = AntiTrip.att,
        RigidityEnabled = true,
        MaxTorque = math.huge,
        Responsiveness = 200,
        ReactionTorqueEnabled = false,
        CFrame = hrp.CFrame.Rotation,
    }, hrp)
end

function AntiTrip.engage(hum)
    if AntiTrip.humanoid ~= hum then
        if AntiTrip.humanoid then setBlockedStates(AntiTrip.humanoid, true) end
        AntiTrip.humanoid = hum
        setBlockedStates(hum, false)
    end
end

function AntiTrip.release()
    if AntiTrip.humanoid then
        setBlockedStates(AntiTrip.humanoid, true)
        AntiTrip.humanoid = nil
    end
    AntiTrip.destroyAligner()
end

function AntiTrip.reset()
    AntiTrip.humanoid = nil
    AntiTrip.destroyAligner()
end

function AntiTrip.step(hrp, hum, moving, moveDir, dt)
    local current = hum:GetState()
    for _, state in ipairs(blockedStates) do
        if current == state then hum:ChangeState(Enum.HumanoidStateType.GettingUp); break end
    end
    if hum.PlatformStand then hum.PlatformStand = false end

    AntiTrip.ensureAligner(hrp)
    local look = hrp.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.1 then flat = AntiTrip.lastFlatLook else flat = flat.Unit end
    if moving and hum.AutoRotate then
        local dirFlat = Vector3.new(moveDir.X, 0, moveDir.Z)
        if dirFlat.Magnitude > 0.01 then
            dirFlat = dirFlat.Unit
            local mix = flat:Lerp(dirFlat, math.clamp(dt * 14, 0, 1))
            if mix.Magnitude < 0.05 then mix = dirFlat end
            flat = mix.Unit
        end
    end
    AntiTrip.lastFlatLook = flat
    AntiTrip.align.CFrame = CFrame.lookAt(Vector3.zero, flat)
    AntiTrip.align.Enabled = true
    local av = hrp.AssemblyAngularVelocity
    hrp.AssemblyAngularVelocity = moving and Vector3.zero or Vector3.new(0, av.Y, 0)
end

-- ---------- 6d. Fly ----------
local Fly = { att = nil, lv = nil, ao = nil, current = Vector3.zero }

function Fly.destroyInstances()
    for _, k in ipairs({ "lv", "ao", "att" }) do
        local inst = Fly[k]
        if inst then pcall(function() inst:Destroy() end); Fly[k] = nil end
    end
end

function Fly.ensure(hrp)
    if Fly.att and Fly.lv and Fly.ao
        and Fly.att.Parent == hrp and Fly.lv.Parent == hrp and Fly.ao.Parent == hrp then
        return
    end
    Fly.destroyInstances()
    Fly.current = Vector3.zero
    Fly.att = create("Attachment", { Name = "EkantoFlyAtt" }, hrp)
    Fly.lv = create("LinearVelocity", {
        Name = "EkantoFlyVelocity",
        Attachment0 = Fly.att,
        RelativeTo = Enum.ActuatorRelativeTo.World,
        VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
        MaxForce = math.huge,
        VectorVelocity = Vector3.zero,
    }, hrp)
    Fly.ao = create("AlignOrientation", {
        Name = "EkantoFlyOrient",
        Mode = Enum.OrientationAlignmentMode.OneAttachment,
        Attachment0 = Fly.att,
        RigidityEnabled = true,
        MaxTorque = math.huge,
        Responsiveness = 200,
        ReactionTorqueEnabled = false,
        CFrame = hrp.CFrame.Rotation,
    }, hrp)
end

function Fly.enable(hrp, hum)
    Fly.ensure(hrp)
    hum.PlatformStand = true
end

function Fly.step(hrp, hum, dt)
    local cam = workspace.CurrentCamera
    if not cam then return end
    Fly.ensure(hrp)
    hum.PlatformStand = true

    local target = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        local look = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local dir = Vector3.zero
        local up = Vector3.new(0, 1, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then dir += up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir -= up end
        if dir.Magnitude > 0.01 then target = dir.Unit * Cfg.flySpeed end
    end

    local alpha = 1 - math.exp(-FLY_SMOOTHING * dt)
    Fly.current = Fly.current:Lerp(target, alpha)
    if target.Magnitude < 0.01 and Fly.current.Magnitude < 0.5 then
        Fly.current = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    Fly.lv.VectorVelocity = Fly.current

    local camLook = cam.CFrame.LookVector
    local flat = Vector3.new(camLook.X, 0, camLook.Z)
    if flat.Magnitude > 0.05 then Fly.ao.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit) end
    hrp.AssemblyAngularVelocity = Vector3.zero
end

function Fly.disable()
    local carry = Fly.current
    Fly.destroyInstances()
    Fly.current = Vector3.zero
    local _, hum, hrp = getCharacterParts()
    if hum then
        hum.PlatformStand = false
        if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
    end
    if hrp and carry.Magnitude > 0.5 then
        task.spawn(function()
            pcall(function()
                for i = 1, 8 do
                    if not Runtime.alive or Runtime.mode ~= "idle" or not hrp.Parent then return end
                    local horizontal = Vector3.new(carry.X, 0, carry.Z) * (1 - i / 8)
                    local v = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(horizontal.X, math.min(v.Y, 0), horizontal.Z)
                    RunService.Heartbeat:Wait()
                end
            end)
        end)
    end
end

function Fly.reset()
    Fly.destroyInstances()
    Fly.current = Vector3.zero
end

-- ---------- 6e. Speed boost ----------
local Speed = {}

function Speed.step(hrp, hum, dt)
    local moveDir = hum.MoveDirection
    local moving = moveDir.Magnitude > 0
    if moving then
        local dir = moveDir.Unit
        local current = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X * Cfg.speed, current.Y, dir.Z * Cfg.speed)
        if hum.WalkSpeed ~= Cfg.speed then hum.WalkSpeed = Cfg.speed end -- hybrid
    end
    AntiTrip.step(hrp, hum, moving, moveDir, dt)
end

function Speed.exit()
    pcall(function()
        local _, hum = getCharacterParts()
        if hum and hum.WalkSpeed ~= DEFAULT_WALKSPEED then hum.WalkSpeed = DEFAULT_WALKSPEED end
    end)
    AntiTrip.release()
end

-- ---------- 6f. Fling Aura (NPC only) ----------
local Aura = { token = 0, cooldowns = setmetatable({}, { __mode = "k" }), lastSwing = 0 }

local function findHumanoidModel(part)
    local node = part
    while node and node ~= workspace do
        if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return node end
        node = node.Parent
    end
    return nil
end

function Aura.scan()
    if not Cfg.aura then return end
    local char, hum, hrp = getCharacterParts()
    if not (char and hum and hrp) or hum.Health <= 0 then return end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local parts = workspace:GetPartBoundsInRadius(hrp.Position, AURA_RADIUS, params)
    local handled, now = {}, os.clock()
    local anyTarget = false
    for _, part in ipairs(parts) do
        pcall(function()
            local model = findHumanoidModel(part)
            if not model or handled[model] then return end
            handled[model] = true
            if Players:GetPlayerFromCharacter(model) ~= nil then return end
            local targetHum = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")
            if not targetHum or not root or targetHum.Health <= 0 or root.Anchored then return end
            anyTarget = true
            local last = Aura.cooldowns[model]
            if last and now - last < AURA_COOLDOWN then return end
            Aura.cooldowns[model] = now
            local offset = root.Position - hrp.Position
            local flat = Vector3.new(offset.X, 0, offset.Z)
            if flat.Magnitude < 0.1 then
                local look = hrp.CFrame.LookVector
                flat = Vector3.new(look.X, 0, look.Z)
            end
            flat = flat.Unit
            root.AssemblyLinearVelocity = flat * AURA_PUSH + Vector3.new(0, AURA_LIFT, 0)
            root.AssemblyAngularVelocity = Vector3.new(
                math.random(-40, 40), math.random(-40, 40), math.random(-40, 40))
        end)
    end
    if anyTarget and now - Aura.lastSwing >= AURA_SWING_INTERVAL then
        Aura.lastSwing = now
        pcall(function()
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end)
    end
end

function Aura.stop()
    Aura.token += 1
    if Aura.handle then Loop.remove(Aura.handle); Aura.handle = nil end
    table.clear(Aura.cooldowns)
end

function Aura.start()
    Aura.token += 1
    if Aura.handle then Loop.remove(Aura.handle) end
    Aura.handle = Loop.register("Damage Aura", Aura.scan, { interval = AURA_INTERVAL, feature = "aura" })
end

-- ---------- 6g. ESP (highlight + billboard tag + off-screen edge arrows) ----------
local ESP = { folder = nil, arrowLayer = nil, highlights = {}, tags = {}, charConns = {},
    playerAdded = nil, playerRemoving = nil, handle = nil }
local HP_LOW, HP_HIGH = Color3.fromRGB(255, 59, 48), Color3.fromRGB(90, 255, 120)

function ESP.removeTag(player)
    local t = ESP.tags[player]
    if t then
        pcall(function() t.gui:Destroy() end)
        pcall(function() t.arrow:Destroy() end)
        ESP.tags[player] = nil
    end
end

function ESP.removeHighlight(player)
    local h = ESP.highlights[player]
    if h then
        pcall(function() h:Destroy() end)
        ESP.highlights[player] = nil
    end
    ESP.removeTag(player)
end

function ESP.buildTag(player, char)
    local head = char:FindFirstChild("Head") or char:WaitForChild("HumanoidRootPart", 5)
    if not head or not ESP.folder then return end
    local gui = create("BillboardGui", {
        Name = "EkantoTag", Adornee = head, Size = UDim2.fromOffset(120, 42),
        StudsOffset = Vector3.new(0, 2.6, 0), AlwaysOnTop = true,
        MaxDistance = math.huge, -- no range cap: visible from any distance
        LightInfluence = 0, ResetOnSpawn = false, Enabled = Cfg.espInfo ~= false,
    }, ESP.folder)
    local function lbl(y, h, size, text, color)
        local l = create("TextLabel", {
            Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h),
            BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
            TextStrokeTransparency = 0.35, TextStrokeColor3 = Theme.Black,
        }, gui)
        l:SetAttribute("NoTheme", true); l:SetAttribute("NoFont", true); l:SetAttribute("NoBoost", true)
        return l
    end
    lbl(0, 16, 14, player.DisplayName, Theme.White)
    local distL = lbl(16, 14, 12, "", Theme.SubText)
    local bg = create("Frame", {
        Position = UDim2.new(0.1, 0, 0, 34), Size = UDim2.new(0.8, 0, 0, 5),
        BackgroundColor3 = Theme.Black, BackgroundTransparency = 0.25, BorderSizePixel = 0,
    }, gui)
    bg:SetAttribute("NoTheme", true)
    local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = HP_HIGH, BorderSizePixel = 0 }, bg)
    fill:SetAttribute("NoTheme", true)
    local arrow = buildArrow(ESP.arrowLayer, HP_LOW, 22)
    arrow.Visible = false
    ESP.tags[player] = { gui = gui, distL = distL, fill = fill, arrow = arrow, char = char,
        hum = char:FindFirstChildOfClass("Humanoid") }
end

function ESP.update()
    local cam = workspace.CurrentCamera
    if not cam or not ESP.folder then return end
    local _, _, myHrp = getCharacterParts()
    local vp = cam.ViewportSize
    local center = vp / 2
    for player, t in pairs(ESP.tags) do
        local char = t.char
        local root = char and char.Parent and char:FindFirstChild("HumanoidRootPart")
        if not root then
            t.arrow.Visible = false
        else
            local from = myHrp and myHrp.Position or cam.CFrame.Position
            t.distL.Text = math.floor((root.Position - from).Magnitude) .. " studs"
            local hum = t.hum
            local frac = (hum and hum.MaxHealth > 0) and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
            t.fill.Size = UDim2.new(frac, 0, 1, 0)
            t.fill.BackgroundColor3 = HP_LOW:Lerp(HP_HIGH, frac)
            t.gui.Enabled = Cfg.espInfo ~= false
            local v, onScreen = cam:WorldToViewportPoint(root.Position)
            if Cfg.espInfo == false or (onScreen and v.Z > 0) then
                t.arrow.Visible = false
            else
                local rel = cam.CFrame:PointToObjectSpace(root.Position)
                local dir = Vector2.new(rel.X, -rel.Y)
                if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
                dir = dir.Unit
                local mx, my = center.X - 34, center.Y - 34
                local k = math.min(math.abs(dir.X) > 1e-4 and mx / math.abs(dir.X) or math.huge,
                    math.abs(dir.Y) > 1e-4 and my / math.abs(dir.Y) or math.huge)
                local p = center + dir * k
                t.arrow.Position = UDim2.fromOffset(p.X, p.Y)
                t.arrow.Rotation = math.deg(math.atan2(dir.X, -dir.Y))
                t.arrow.Visible = true
            end
        end
    end
end

function ESP.attach(player)
    if player == LocalPlayer or ESP.charConns[player] then return end
    local function onChar(char)
        pcall(function()
            ESP.removeHighlight(player)
            if not ESP.folder then return end
            ESP.highlights[player] = create("Highlight", {
                Name = "EkantoESP",
                Adornee = char,
                FillColor = Theme.Red,
                FillTransparency = 0.65,
                OutlineColor = Theme.White,
                OutlineTransparency = 0,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, ESP.folder)
            task.spawn(function() pcall(ESP.buildTag, player, char) end)
        end)
    end
    if player.Character then onChar(player.Character) end
    ESP.charConns[player] = player.CharacterAdded:Connect(onChar)
end

function ESP.detach(player)
    local c = ESP.charConns[player]
    if c then pcall(function() c:Disconnect() end); ESP.charConns[player] = nil end
    ESP.removeHighlight(player)
end

function ESP.enable()
    if ESP.folder then return end
    ESP.folder = create("Folder", { Name = "EkantoESPFolder" }, ScreenGui)
    ESP.arrowLayer = create("Frame", {
        Name = "EdgeArrows", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Active = false, ZIndex = 45,
    }, ESP.folder)
    for _, p in ipairs(Players:GetPlayers()) do pcall(ESP.attach, p) end
    ESP.playerAdded = Players.PlayerAdded:Connect(function(p) pcall(ESP.attach, p) end)
    ESP.playerRemoving = Players.PlayerRemoving:Connect(function(p) pcall(ESP.detach, p) end)
    ESP.handle = Loop.register("Player ESP", ESP.update, { interval = 0.03, feature = "esp" })
end

function ESP.disable()
    if ESP.handle then Loop.remove(ESP.handle); ESP.handle = nil end
    if ESP.playerAdded then pcall(function() ESP.playerAdded:Disconnect() end); ESP.playerAdded = nil end
    if ESP.playerRemoving then pcall(function() ESP.playerRemoving:Disconnect() end); ESP.playerRemoving = nil end
    for p in pairs(ESP.charConns) do ESP.detach(p) end
    for p in pairs(ESP.highlights) do ESP.removeHighlight(p) end
    for p in pairs(ESP.tags) do ESP.removeTag(p) end
    if ESP.folder then pcall(function() ESP.folder:Destroy() end); ESP.folder = nil end
    ESP.arrowLayer = nil
end

-- ---------- 6g2. Noclip ----------
local Noclip = { orig = setmetatable({}, { __mode = "k" }), parts = {}, char = nil, refreshAt = 0, handle = nil }

function Noclip.step()
    if not Cfg.noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    local now = os.clock()
    if Noclip.char ~= char or now >= Noclip.refreshAt then
        Noclip.char, Noclip.refreshAt = char, now + 0.5
        Noclip.parts = {}
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then table.insert(Noclip.parts, d) end
        end
    end
    for _, p in ipairs(Noclip.parts) do
        if p.Parent and p.CanCollide then
            Noclip.orig[p] = true -- remember it was solid so restore doesn't solidify decorative parts
            p.CanCollide = false
        end
    end
end

function Noclip.restore()
    for p in pairs(Noclip.orig) do
        pcall(function() p.CanCollide = true end)
        Noclip.orig[p] = nil
    end
    Noclip.parts, Noclip.char = {}, nil
end

function Noclip.start()
    if Noclip.handle then Loop.remove(Noclip.handle) end
    Noclip.handle = Loop.register("Noclip", Noclip.step, { feature = "noclip" })
end

function Noclip.stop()
    if Noclip.handle then Loop.remove(Noclip.handle); Noclip.handle = nil end
    Noclip.restore()
end

-- ---------- 6g3. Anti-AFK ----------
local AntiAFK = { conn = nil, handle = nil }

function AntiAFK.pulse()
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new(0, 0)) -- harmless right-click at the corner
    end)
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.05), 0) end -- microscopic nudge
    end)
end

function AntiAFK.start()
    AntiAFK.stop()
    AntiAFK.conn = LocalPlayer.Idled:Connect(AntiAFK.pulse)
    AntiAFK.handle = Loop.register("Anti-AFK", AntiAFK.pulse, { interval = 240, feature = "antiAfk" })
end

function AntiAFK.stop()
    if AntiAFK.conn then pcall(function() AntiAFK.conn:Disconnect() end); AntiAFK.conn = nil end
    if AntiAFK.handle then Loop.remove(AntiAFK.handle); AntiAFK.handle = nil end
end

-- ---------- 6h. Environment ----------
local Optimizer = {
    saved = setmetatable({}, { __mode = "k" }),
    conn = nil, token = 0, lighting = nil, quality = nil,
}

local function optimizeInstance(inst)
    pcall(function()
        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
            or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles")
            or inst:IsA("PostEffect") then
            if Optimizer.saved[inst] == nil then Optimizer.saved[inst] = { enabled = inst.Enabled } end
            inst.Enabled = false
        elseif inst:IsA("Terrain") then
            return
        elseif inst:IsA("BasePart") then
            if LocalPlayer.Character and inst:IsDescendantOf(LocalPlayer.Character) then return end
            if Optimizer.saved[inst] == nil then
                Optimizer.saved[inst] = { mat = inst.Material, refl = inst.Reflectance, shadow = inst.CastShadow }
            end
            inst.Material = Enum.Material.SmoothPlastic
            inst.Reflectance = 0
            inst.CastShadow = false
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if LocalPlayer.Character and inst:IsDescendantOf(LocalPlayer.Character) then return end
            if Optimizer.saved[inst] == nil then Optimizer.saved[inst] = { t = inst.Transparency } end
            inst.Transparency = 1
        end
    end)
end

function Optimizer.enable()
    Optimizer.token += 1
    local myToken = Optimizer.token
    pcall(function()
        Optimizer.lighting = Optimizer.lighting or { shadows = Lighting.GlobalShadows }
        Lighting.GlobalShadows = false
    end)
    pcall(function()
        local rendering = settings().Rendering
        Optimizer.quality = Optimizer.quality or rendering.QualityLevel
        rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    if Optimizer.conn then pcall(function() Optimizer.conn:Disconnect() end) end
    Optimizer.conn = workspace.DescendantAdded:Connect(optimizeInstance)
    task.spawn(function()
        pcall(function()
            for _, d in ipairs(Lighting:GetDescendants()) do optimizeInstance(d) end
            local count = 0
            for _, d in ipairs(workspace:GetDescendants()) do
                if not Runtime.alive or Optimizer.token ~= myToken then return end
                optimizeInstance(d)
                count += 1
                if count % 400 == 0 then task.wait() end
            end
        end)
    end)
end

function Optimizer.disable()
    Optimizer.token += 1
    if Optimizer.conn then pcall(function() Optimizer.conn:Disconnect() end); Optimizer.conn = nil end
    local count = 0
    for inst, data in pairs(Optimizer.saved) do
        pcall(function()
            if data.enabled ~= nil then inst.Enabled = data.enabled
            elseif data.mat ~= nil then
                inst.Material = data.mat
                inst.Reflectance = data.refl
                inst.CastShadow = data.shadow
            elseif data.t ~= nil then inst.Transparency = data.t end
        end)
        Optimizer.saved[inst] = nil
        count += 1
        if count % 600 == 0 then task.wait() end
    end
    pcall(function()
        if Optimizer.lighting then Lighting.GlobalShadows = Optimizer.lighting.shadows; Optimizer.lighting = nil end
    end)
    pcall(function()
        if Optimizer.quality then
            settings().Rendering.QualityLevel = Optimizer.quality
            Optimizer.quality = nil
        end
    end)
end

local Env = { fog = nil, bright = nil }

local function getAtmosphere() return Lighting:FindFirstChildOfClass("Atmosphere") end

local function assertFog()
    pcall(function()
        Lighting.FogStart = 1e8
        Lighting.FogEnd = 1e9
        local atmo = getAtmosphere()
        if atmo then atmo.Density = 0; atmo.Haze = 0 end
    end)
end

local function assertBright()
    pcall(function()
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
    end)
end

function Env.setFog(on)
    pcall(function()
        if on then
            if not Env.fog then
                local atmo = getAtmosphere()
                Env.fog = {
                    fogStart = Lighting.FogStart, fogEnd = Lighting.FogEnd,
                    density = atmo and atmo.Density, haze = atmo and atmo.Haze,
                }
            end
            assertFog()
        elseif Env.fog then
            Lighting.FogStart = Env.fog.fogStart
            Lighting.FogEnd = Env.fog.fogEnd
            local atmo = getAtmosphere()
            if atmo and Env.fog.density ~= nil then
                atmo.Density = Env.fog.density
                atmo.Haze = Env.fog.haze
            end
            Env.fog = nil
        end
    end)
end

function Env.setBright(on)
    pcall(function()
        if on then
            if not Env.bright then
                Env.bright = {
                    ambient = Lighting.Ambient, outdoor = Lighting.OutdoorAmbient,
                    brightness = Lighting.Brightness, clock = Lighting.ClockTime,
                }
            end
            assertBright()
        elseif Env.bright then
            Lighting.Ambient = Env.bright.ambient
            Lighting.OutdoorAmbient = Env.bright.outdoor
            Lighting.Brightness = Env.bright.brightness
            Lighting.ClockTime = Env.bright.clock
            Env.bright = nil
        end
    end)
end

function Env.startLoop()
    Loop.register("Environment", function()
        if Cfg.noFog then assertFog() end
        if Cfg.fullBright then assertBright() end
    end, { interval = 0.5, keep = true })
end

-- ---------- 6i. Feature setters ----------
local Features = {}

function Features.fly(on) Cfg.fly = on end

function Features.godMode(on)
    Cfg.godMode = on
    pcall(function()
        if on then God.applyToCharacter(LocalPlayer.Character) else God.restore() end
    end)
end

function Features.invisible(on)
    Cfg.invisible = on
    pcall(function()
        if on then Invis.applyToCharacter(LocalPlayer.Character) else Invis.restore() end
    end)
end

function Features.esp(on)
    Cfg.esp = on
    if on then ESP.enable() else ESP.disable() end
end

function Features.aura(on)
    Cfg.aura = on
    if on then Aura.start() else Aura.stop() end
end

function Features.optimizer(on)
    Cfg.optimizer = on
    if on then Optimizer.enable() else task.spawn(Optimizer.disable) end
end

function Features.noFog(on)
    Cfg.noFog = on
    Env.setFog(on)
end

function Features.fullBright(on)
    Cfg.fullBright = on
    Env.setBright(on)
end

function Features.noclip(on)
    Cfg.noclip = on
    if on then Noclip.start() else Noclip.stop() end
end

function Features.antiAfk(on)
    Cfg.antiAfk = on
    if on then AntiAFK.start() else AntiAFK.stop() end
end

function Features.espInfo(on) Cfg.espInfo = on end

-- every feature setter runs through the central error handler
for name, fn in pairs(Features) do
    Features[name] = function(on)
        guard(name, name, fn, on)
    end
end

-- ============================================================
-- 7. LIFECYCLE, MAIN LOOP, CLEANUP
-- ============================================================
local function transition(from, to)
    if from == "fly" then Fly.disable()
    elseif from == "boost" then Speed.exit() end
    if to == "fly" then
        local _, hum, hrp = getCharacterParts()
        if hum and hrp then Fly.enable(hrp, hum) end
    elseif to == "boost" then
        local _, hum = getCharacterParts()
        if hum then AntiTrip.engage(hum) end
    end
end

local function movementStep(dt)
    do
        local char, hum, hrp = getCharacterParts()
        if not (char and hum and hrp) then return end
        local alive = hum.Health > 0
        local desired = "idle"
        if Cfg.fly and alive then desired = "fly"
        elseif Cfg.speed > SPEED_MIN and alive and hum.SeatPart == nil then desired = "boost" end
        if desired ~= Runtime.mode then
            local from = Runtime.mode
            Runtime.mode = desired
            transition(from, desired)
        end
        if desired == "fly" then Fly.step(hrp, hum, dt)
        elseif desired == "boost" then Speed.step(hrp, hum, dt) end
    end
end

-- gameplay handlers on the single central Heartbeat (registered once buildMain runs)
local function registerGameplayLoops()
    Loop.register("Movement", function(dt)
        local ok, err = pcall(movementStep, dt)
        if ok then return end
        local mode = Runtime.mode
        if mode == "fly" then
            Errors.report("Fly", err, "fly")
        elseif mode == "boost" then
            Errors.report("WalkSpeed", err)
            pcall(function() UI.sliders.speed.Set(SPEED_MIN) end)
        else
            Errors.report("Movement", err)
        end
    end, { keep = true })
    Loop.register("God Mode", function()
        local _, hum = getCharacterParts()
        if hum then God.step(hum) end
    end, { feature = "godMode" })
    Loop.register("Invisible Mode", function()
        local _, hum = getCharacterParts()
        if hum then Invis.step(hum) end
    end, { feature = "invisible" })
end

local function onCharacterAdded(char)
    table.clear(originalCanTouch)
    table.clear(originalVisual)
    table.clear(originalDisplay)
    table.clear(Noclip.orig); Noclip.char = nil
    Runtime.mode = "idle"
    AntiTrip.reset()
    Fly.reset()
    task.spawn(function()
        pcall(function()
            char:WaitForChild("HumanoidRootPart", 10)
            char:WaitForChild("Humanoid", 10)
            task.wait(0.1)
            hookCharacter(char)
        end)
    end)
end

local function fullCleanup()
    if not Runtime.alive then return end
    local lastMode = Runtime.mode
    Runtime.alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    if MiniState.bag then
        for _, c in ipairs(MiniState.bag) do pcall(function() c:Disconnect() end) end
        MiniState.bag = nil
    end
    for _, c in ipairs({ descendantConn, healthConn }) do
        pcall(function() c:Disconnect() end)
    end
    descendantConn, healthConn = nil, nil
    pcall(Aura.stop)
    pcall(ESP.disable)
    pcall(Noclip.stop)     -- restores CanCollide on every touched part
    pcall(AntiAFK.stop)
    ThemeFx.items = nil
    pcall(function() if Loop.conn then Loop.conn:Disconnect(); Loop.conn = nil end end)
    table.clear(Loop.handlers)
    if lastMode == "fly" then pcall(Fly.disable) else pcall(Fly.destroyInstances) end
    pcall(Speed.exit)
    Runtime.mode = "idle"
    pcall(God.restore)
    pcall(Invis.restore)
    pcall(Env.setFog, false)
    pcall(Env.setBright, false)
    task.spawn(function() pcall(Optimizer.disable) end)
    for _, k in ipairs(TOGGLE_KEYS) do Cfg[k] = false end
end

-- ============================================================
-- 8. UI FRAMEWORK
-- ============================================================
-- ---------- Stagger entrance ----------
local function staggerIn(holder)
    local items = {}
    for _, c in ipairs(holder:GetChildren()) do
        if c:IsA("GuiObject") then table.insert(items, c) end
    end
    table.sort(items, function(a, b) return (a.LayoutOrder or 0) < (b.LayoutOrder or 0) end)
    for i, card in ipairs(items) do
        local s = card:FindFirstChildOfClass("UIScale")
        if not s then s = create("UIScale", { Scale = 1 }, card) end
        s.Scale = 0.94
        task.delay((i - 1) * 0.045, function()
            if card.Parent then
                TweenService:Create(s, SPRING_INFO, { Scale = 1 }):Play()
            end
        end)
    end
end

-- ---------- Toast (with countdown bar) ----------
local NotifLog = { entries = {}, listeners = {} }
local Toast = { layer = nil, counter = 0 }

function Toast.init(gui)
    Toast.layer = create("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(300, 320),
        BackgroundTransparency = 1, Active = false, ZIndex = 90,
    }, gui)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
    }, Toast.layer)
end

function Toast.show(text, accent, duration)
    pcall(function()
        table.insert(NotifLog.entries, 1, { t = os.date("%H:%M:%S"), text = tostring(text) })
        while #NotifLog.entries > 40 do table.remove(NotifLog.entries) end
        for _, fn in ipairs(NotifLog.listeners) do pcall(fn) end
    end)
    if Cfg.toasts == false then return end
    if not Toast.layer or not Runtime.alive then return end
    task.spawn(function()
        pcall(function()
            Toast.counter += 1
            local _, textH = measureText(text, 14, TOAST_TEXT_W)
            duration = duration or 2.5
            local frame = create("Frame", {
                LayoutOrder = Toast.counter,
                Size = UDim2.fromOffset(TOAST_TEXT_W + 16, textH + 14 + 3),
                BackgroundColor3 = Theme.Black,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 91,
            }, Toast.layer)
            addCorner(frame, 6)
            local stroke = create("UIStroke", {
                Color = accent or Theme.Cyan, Thickness = 1, Transparency = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, frame)
            local label = create("TextLabel", {
                Size = UDim2.new(1, -16, 1, -3),
                Position = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text = text, TextTransparency = 1,
                TextSize = 14, TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 92,
            }, frame)
            local bar = create("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new(0, 6, 1, -3),
                Size = UDim2.new(1, -12, 0, 2),
                BackgroundColor3 = accent or Theme.Cyan,
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 92,
            }, frame)
            addCorner(bar, 1)

            local tin = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(frame, tin, { BackgroundTransparency = 0.05 }):Play()
            TweenService:Create(stroke, tin, { Transparency = 0 }):Play()
            TweenService:Create(label, tin, { TextTransparency = 0 }):Play()
            TweenService:Create(bar, tin, { BackgroundTransparency = 0.3 }):Play()
            TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Size = UDim2.new(0, 0, 0, 2) }):Play()

            task.wait(duration)
            if not frame.Parent then return end
            local tout = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            TweenService:Create(frame, tout, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(stroke, tout, { Transparency = 1 }):Play()
            TweenService:Create(label, tout, { TextTransparency = 1 }):Play()
            TweenService:Create(bar, tout, { BackgroundTransparency = 1 }):Play()
            task.wait(0.3)
            frame:Destroy()
        end)
    end)
end

-- ---------- Centralized error handling ----------
function Errors.disable(featureKey)
    if not featureKey or Errors.busy then return end
    Errors.busy = true -- a failing "off" callback must not re-enter this handler forever
    pcall(function()
        local t = UI.toggles[featureKey]
        if t and t.Get() then t.Set(false, true) end
    end)
    pcall(function() Cfg[featureKey] = false end)
    Errors.busy = false
end

function Errors.report(label, err, featureKey)
    local msg = tostring(err):gsub("^.-:%d+:%s*", "")
    local now = os.clock()
    if Errors.last[label] and now - Errors.last[label] < 3 then
        Errors.disable(featureKey)
        return
    end
    Errors.last[label] = now
    Errors.disable(featureKey)
    pcall(Toast.show, "[" .. tostring(label) .. "] error: " .. msg, Theme.Red, 4)
end

-- ---------- Sound design ----------
local Sfx = { folder = nil, sounds = {}, lastHover = 0 }

function Sfx.init(gui)
    Sfx.folder = create("Folder", { Name = "EkantoSfx" }, gui)
    for name, def in pairs(SOUND_IDS) do
        pcall(function()
            Sfx.sounds[name] = create("Sound", {
                Name = name, SoundId = def.id, Volume = 0, PlaybackSpeed = def.pitch or 1,
            }, Sfx.folder)
        end)
    end
end

function Sfx.play(name)
    local snd, def = Sfx.sounds[name], SOUND_IDS[name]
    if not snd or not def then return end
    local master = (Cfg.volume or 40) / 100
    if master <= 0 then return end
    if name == "hover" then
        local now = os.clock()
        if now - Sfx.lastHover < 0.06 then return end
        Sfx.lastHover = now
    end
    pcall(function()
        snd.Volume = def.vol * master
        snd.TimePosition = 0
        snd:Play()
    end)
end

-- ---------- Tooltip (fades in/out) ----------
local Tooltip = { frame = nil, label = nil, size = Vector2.new(0, 0), token = 0 }

function Tooltip.init(gui)
    Tooltip.frame = create("Frame", {
        Name = "Tooltip",
        Visible = false,
        Size = UDim2.fromOffset(120, 30),
        BackgroundColor3 = Theme.Black,
        BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = false, ZIndex = 100,
    }, gui)
    addCorner(Tooltip.frame, 6)
    addFlatStroke(Tooltip.frame, Theme.Off, 1)
    Tooltip.label = create("TextLabel", {
        Position = UDim2.fromOffset(8, 5),
        Size = UDim2.fromOffset(100, 20),
        BackgroundTransparency = 1,
        Text = "", TextTransparency = 1,
        TextSize = 14, TextWrapped = true, TextColor3 = Theme.White,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 101,
    }, Tooltip.frame)
end

function Tooltip.set(text)
    local w, h = measureText(text, 14, TOOLTIP_MAX_W)
    Tooltip.label.Text = text
    Tooltip.label.Size = UDim2.fromOffset(w, h)
    Tooltip.frame.Size = UDim2.fromOffset(w + 16, h + 10)
    Tooltip.size = Vector2.new(w + 16, h + 10)
end

function Tooltip.move()
    pcall(function()
        local m = UserInputService:GetMouseLocation()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local x = math.min(m.X + 14, vp.X - Tooltip.size.X - 8)
        local y = math.min(m.Y + 16, vp.Y - Tooltip.size.Y - 8)
        Tooltip.frame.Position = UDim2.fromOffset(math.max(x, 4), math.max(y, 4))
    end)
end

function Tooltip.show()
    if not Tooltip.frame then return end
    Tooltip.token += 1
    local tok = Tooltip.token
    Tooltip.frame.Visible = true
    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(Tooltip.frame, info, { BackgroundTransparency = 0.05 }):Play()
    TweenService:Create(Tooltip.label, info, { TextTransparency = 0 }):Play()
end

function Tooltip.hide()
    Tooltip.token += 1
    local tok = Tooltip.token
    local f, l = Tooltip.frame, Tooltip.label
    if not f then return end
    local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(f, info, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(l, info, { TextTransparency = 1 }):Play()
    task.delay(0.14, function()
        if tok == Tooltip.token and f.Parent then f.Visible = false end
    end)
end

function Tooltip.attach(obj, text)
    track(obj.MouseEnter:Connect(function()
        Tooltip.set(text)
        Tooltip.show()
        Tooltip.move()
    end))
    track(obj.MouseMoved:Connect(Tooltip.move))
    track(obj.MouseLeave:Connect(Tooltip.hide))
end

-- ---------- Hover FX ----------
local function addHoverFX(obj, stroke, restTransparency)
    local s = create("UIScale", { Scale = 1 }, obj)
    track(obj.MouseEnter:Connect(function()
        Sfx.play("hover")
        TweenService:Create(s, HOVER_INFO, { Scale = HOVER_SCALE }):Play()
        if stroke then TweenService:Create(stroke, HOVER_INFO, { Transparency = 0 }):Play() end
    end))
    track(obj.MouseLeave:Connect(function()
        TweenService:Create(s, HOVER_INFO, { Scale = 1 }):Play()
        if stroke then
            TweenService:Create(stroke, HOVER_INFO, { Transparency = restTransparency or 0.2 }):Play()
        end
    end))
    return s
end

-- ---------- Card ----------
local CardContext = { open = nil, t = 0 } -- right-click menu hook, installed by buildMain
local function createCard(page, name, height, accent)
    page.order += 1
    local card = create("Frame", {
        Name = name .. "Card",
        LayoutOrder = page.order,
        Size = UDim2.new(1, -10, 0, height),
        BackgroundColor3 = Theme.Black,
        BorderSizePixel = 0,
    }, page.frame)
    addCorner(card, 8)
    local stroke = create("UIStroke", {
        Color = accent, Thickness = 1.5, Transparency = 0.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, card)
    track(card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and CardContext.open then
            guard("Context menu", nil, CardContext.open, card)
        end
    end))
    return card, stroke
end

-- ---------- Slider (popup + count-up) ----------
local function createSlider(page, spec)
    local card, cardStroke = createCard(page, spec.name, 78, spec.accent)
    card:SetAttribute("desc", spec.desc or spec.name)
    card:SetAttribute("search", string.lower(spec.name .. " " .. (spec.desc or "") .. " " .. (spec.tip or "")))

    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(0.65, 0, 0, 22),
        BackgroundTransparency = 1, Text = spec.name, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -24, 0, 20),
        BackgroundTransparency = 1, Text = spec.desc, TextSize = 14, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    local valueLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 7),
        Size = UDim2.new(0, 70, 0, 22), BackgroundTransparency = 1,
        Text = tostring(spec.value), TextSize = 17,
        TextColor3 = Theme.Green,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, card)

    local sliderTrack = create("Frame", {
        Name = "Track",
        Position = UDim2.new(0, 14, 0, 62),
        Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = Theme.Track, BorderSizePixel = 0,
    }, card)
    addCorner(sliderTrack, 3)
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.White, BorderSizePixel = 0,
    }, sliderTrack)
    addCorner(fill, 3)
    create("UIGradient", { Color = ColorSequence.new(Theme.Cyan, Theme.Green) }, fill)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, ZIndex = 3,
    }, sliderTrack)
    addCorner(knob, 8)
    addFlatStroke(knob, Theme.Green, 2)

    -- floating value popup above the knob
    local popup = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0, -8),
        Size = UDim2.fromOffset(44, 18),
        BackgroundColor3 = Theme.Black, BackgroundTransparency = 1,
        Text = tostring(spec.value), TextSize = 12, TextColor3 = Theme.Green,
        TextTransparency = 1, Visible = false, ZIndex = 8,
    }, knob)
    addCorner(popup, 4)
    addFlatStroke(popup, Theme.Green, 1)

    local hit = create("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 4,
    }, sliderTrack)

    local value = spec.value
    local displayValue = value
    local knobInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local popInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function render(animate)
        local alpha = (value - spec.min) / (spec.max - spec.min)
        if animate then
            TweenService:Create(fill, knobInfo, { Size = UDim2.new(alpha, 0, 1, 0) }):Play()
            TweenService:Create(knob, knobInfo, { Position = UDim2.new(alpha, 0, 0.5, 0) }):Play()
        else
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        end
        popup.Text = tostring(value)
    end
    render(false)

    -- smooth count-up/down for the numeric label
    countups[spec.key] = function(dt)
        if displayValue ~= value then
            displayValue = displayValue + (value - displayValue) * math.clamp(dt * 18, 0, 1)
            if math.abs(displayValue - value) < 0.6 then displayValue = value end
            valueLabel.Text = tostring(math.floor(displayValue + 0.5))
        end
    end

    local function setFromX(x)
        local w = sliderTrack.AbsoluteSize.X
        if w <= 0 then return end
        local alpha = math.clamp((x - sliderTrack.AbsolutePosition.X) / w, 0, 1)
        value = math.floor(spec.min + (spec.max - spec.min) * alpha + 0.5)
        render(true)
        pcall(spec.onChange, value)
    end

    local sliding = false
    local function setPopup(visible)
        popup.Visible = visible
        TweenService:Create(popup, popInfo, { TextTransparency = visible and 0 or 1,
            BackgroundTransparency = visible and 0 or 1 }):Play()
    end
    track(hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            setPopup(true)
            setFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if sliding then setPopup(false) end
            sliding = false
        end
    end))

    addHoverFX(card, cardStroke)
    Tooltip.attach(card, spec.tip)

    local obj = {}
    function obj.Set(v)
        value = math.clamp(math.floor(v + 0.5), spec.min, spec.max)
        render(false)
        pcall(spec.onChange, value)
    end
    UI.sliders[spec.key] = obj
    return obj
end

-- ---------- Toggle (spring + glow pulse + ripple) ----------
local function createToggle(page, spec)
    local card, cardStroke = createCard(page, spec.name, 58, spec.accent)
    card:SetAttribute("search", string.lower(spec.name .. " " .. (spec.desc or "") .. " " .. (spec.tip or "")))
    card:SetAttribute("desc", spec.name .. " - " .. (spec.desc or ""))
    if spec.rebind then card:SetAttribute("rebind", spec.rebind) end

    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -90, 0, 22),
        BackgroundTransparency = 1, Text = spec.name, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 31), Size = UDim2.new(1, -90, 0, 20),
        BackgroundTransparency = 1, Text = spec.desc, TextSize = 14, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)

    local switch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 48, 0, 24), BackgroundColor3 = Theme.Track,
        Text = "", AutoButtonColor = false, ZIndex = 5,
    }, card)
    addCorner(switch, 12)
    local swStroke = addFlatStroke(switch, Theme.Off, 1.5)
    local sKnob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0, ZIndex = 6,
    }, switch)
    addCorner(sKnob, 8)

    local on = false
    local pulseToken = 0

    local function render()
        if on then
            TweenService:Create(sKnob, SPRING_INFO, { Position = UDim2.new(1, -20, 0.5, 0), BackgroundColor3 = Theme.Green }):Play()
            TweenService:Create(switch, SPRING_INFO, { BackgroundColor3 = Theme.OnDark }):Play()
            TweenService:Create(swStroke, SPRING_INFO, { Color = Theme.Green }):Play()
            -- glow pulse loop while on
            pulseToken += 1
            local tok = pulseToken
            task.spawn(function()
                while on and card.Parent and tok == pulseToken do
                    TweenService:Create(swStroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 2.5 }):Play()
                    task.wait(0.7)
                    if not (on and tok == pulseToken) then break end
                    TweenService:Create(swStroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 1.5 }):Play()
                    task.wait(0.7)
                end
            end)
        else
            pulseToken += 1
            TweenService:Create(sKnob, SPRING_INFO, { Position = UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = Theme.Off }):Play()
            TweenService:Create(switch, SPRING_INFO, { BackgroundColor3 = Theme.Track }):Play()
            TweenService:Create(swStroke, SPRING_INFO, { Color = Theme.Off, Thickness = 1.5 }):Play()
        end
    end

    local obj = {}
    obj.card = card
    function obj.Set(v, silent)
        local changed = (v and true or false) ~= on
        on = v and true or false
        render()
        if not silent and changed then Sfx.play(on and "on" or "off") end
        guard(spec.name, nil, spec.callback, on, silent)
    end
    function obj.Toggle() obj.Set(not on, false) end
    function obj.Get() return on end

    track(switch.MouseButton1Click:Connect(function()
        ripple(card, spec.accent)
        obj.Toggle()
    end))
    addHoverFX(card, cardStroke)
    Tooltip.attach(card, spec.tip)

    UI.toggles[spec.key] = obj
    return obj
end

-- ---------- Button ----------
local function createButton(page, text, accent, tip, callback)
    local card, cardStroke = createCard(page, text, 44, accent)
    card:SetAttribute("search", string.lower(text .. " " .. (tip or "")))
    card:SetAttribute("desc", text .. (tip and (" - " .. tip) or ""))
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = text, TextSize = 16, AutoButtonColor = false, ZIndex = 5,
    }, card)
    track(btn.MouseEnter:Connect(function()
        TweenService:Create(card, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
    end))
    track(btn.MouseLeave:Connect(function()
        TweenService:Create(card, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
    end))
    track(btn.MouseButton1Click:Connect(function()
        ripple(card, accent)
        Sfx.play("click")
        guard(text, nil, callback)
    end))
    track(btn.MouseButton2Click:Connect(function()
        if CardContext.open then guard("Context menu", nil, CardContext.open, card) end
    end))
    addHoverFX(card, cardStroke)
    if tip then Tooltip.attach(card, tip) end
    return card
end

-- ---------- Info card ----------
local function createInfo(page, text, accent)
    local _, h = measureText(text, 14, 380)
    local card = createCard(page, "Info" .. tostring(page.order + 1), h + 32, accent or Theme.Off)
    create("TextLabel", {
        Position = UDim2.fromOffset(12, 9),
        Size = UDim2.new(1, -24, 1, -18),
        BackgroundTransparency = 1, Text = text, TextSize = 14, TextColor3 = Theme.SubText,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, card)
    return card
end

-- ============================================================
-- 9. MAIN PANEL
-- ============================================================
local Main
local mainShown = true

local function featureCallback(label, fn)
    return function(on, silent)
        fn(on)
        scheduleSave()
        if not silent then
            Toast.show(label .. (on and " enabled" or " disabled"), on and Theme.Green or Theme.Off)
        end
    end
end

local function applyConfigToUI()
    UI.sliders.speed.Set(Cfg.speed)
    UI.sliders.flySpeed.Set(Cfg.flySpeed)
    for _, k in ipairs(TOGGLE_KEYS) do
        UI.toggles[k].Set(Cfg[k] and PASSIVE_RESTORE[k] == true, true)
    end
end

local function buildMain()
    PanelSize = UDim2.fromOffset(Cfg.panelW or PANEL_SIZE.X.Offset, Cfg.panelH or PANEL_SIZE.Y.Offset)
    Main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = PanelSize,
        BackgroundColor3 = Theme.Black,
        BorderSizePixel = 0,
        Active = true,
    }, ScreenGui)
    addCorner(Main, 10)
    addGradientBorder(Main, 1.5)

    local scale = create("UIScale", { Scale = ENTRY_START_SCALE * userScale() }, Main)
    TweenService:Create(scale, ENTRY_INFO, { Scale = userScale() }):Play()
    task.delay(ENTRY_INFO.Time + 0.2, function()
        if Main and Main.Parent then snapToPixel(Main) end
    end)

    local body = create("Frame", {
        Name = "Body",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
    }, Main)

    -- ---------- Header ----------
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1, Active = true, ZIndex = 3,
    }, body)
    create("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.new(1, -110, 0, 28),
        BackgroundTransparency = 1, Text = "EKANTO",
        TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    }, header)
    create("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 108, 0.5, 2),
        Size = UDim2.fromOffset(40, 14),
        BackgroundTransparency = 1, Text = "v6.0",
        TextSize = 11, TextColor3 = Theme.Off, ZIndex = 4,
    }, header)

    local function makeHeaderButton(name, text, xOffset, hoverColor)
        local btn = create("TextButton", {
            Name = name, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.new(0, 28, 0, 28),
            BackgroundColor3 = Theme.Black, Text = text, TextSize = 18,
            AutoButtonColor = false, ZIndex = 6,
        }, header)
        addCorner(btn, 4)
        addFlatStroke(btn, Theme.Off, 1)
        local s = create("UIScale", { Scale = 1 }, btn)
        track(btn.MouseEnter:Connect(function()
            TweenService:Create(btn, HOVER_INFO, { BackgroundColor3 = hoverColor }):Play()
            TweenService:Create(s, HOVER_INFO, { Scale = HOVER_SCALE }):Play()
        end))
        track(btn.MouseLeave:Connect(function()
            TweenService:Create(btn, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
            TweenService:Create(s, HOVER_INFO, { Scale = 1 }):Play()
        end))
        return btn
    end

    local closeBtn = makeHeaderButton("Close", "X", -12, Theme.Red)
    local minBtn = makeHeaderButton("Minimize", "-", -46, Theme.HoverGrey)

    track(closeBtn.MouseButton1Click:Connect(function()
        ripple(Main, Theme.Red)
        pcall(saveConfig)
        pcall(function() ScreenGui:Destroy() end)
    end))
    track(minBtn.MouseButton1Click:Connect(function()
        ripple(Main, Theme.Cyan)
    end))

    local divider = create("Frame", {
        Position = UDim2.new(0, 14, 0, 48),
        Size = UDim2.new(1, -28, 0, 2),
        BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 3,
    }, body)
    table.insert(animatedGradients, create("UIGradient", { Color = neonGradient() }, divider))

    makeDraggable(header, Main, nil, nil, true) -- inertia on the window

    -- ---------- Tabs with sliding underline ----------
    local tabBar = create("Frame", {
        Position = UDim2.new(0, 12, 0, 56),
        Size = UDim2.new(1, -24, 0, 28),
        BackgroundTransparency = 1, ZIndex = 3,
    }, body)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabBar)

    local TAB_COUNT, TAB_PAD = 5, 6
    local tabW = UDim2.new(1 / TAB_COUNT, -(TAB_PAD * (TAB_COUNT - 1)) / TAB_COUNT, 1, 0)
    -- indicator lives in its own holder so the UIListLayout above doesn't treat it as a tab slot
    local indicatorHolder = create("Frame", {
        Position = tabBar.Position, Size = tabBar.Size,
        BackgroundTransparency = 1, ZIndex = 3,
    }, body)
    local indicator = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 4),
        Size = UDim2.new(tabW.X.Scale, tabW.X.Offset, 0, 2),
        BackgroundColor3 = Theme.Green, BorderSizePixel = 0, ZIndex = 4,
    }, indicatorHolder)

    local tabs = {}
    local tabNames = {}
    local currentTab = "Movement"
    local tabOrder = 0

    local function selectTab(name)
        currentTab = name
        for n, t in pairs(tabs) do
            local active = (n == name)
            t.page.frame.Visible = active
            t.button.TextColor3 = active and Theme.Green or Theme.White
            t.stroke.Color = active and Theme.Green or Theme.Off
        end
        local idx = tabs[name].index - 1
        TweenService:Create(indicator, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Position = UDim2.new(idx / TAB_COUNT, idx * TAB_PAD / TAB_COUNT, 1, 4) }):Play()
        staggerIn(tabs[name].page.frame)
    end

    local function createTab(name)
        tabOrder += 1
        local button = create("TextButton", {
            LayoutOrder = tabOrder,
            Size = tabW,
            BackgroundColor3 = Theme.Black, BorderSizePixel = 0,
            Text = name, TextSize = 14, AutoButtonColor = false, ZIndex = 4,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, tabBar)
        button:SetAttribute("NoBoost", true)
        addCorner(button, 4)
        local stroke = addFlatStroke(button, Theme.Off, 1)
        local s = create("UIScale", { Scale = 1 }, button)
        track(button.MouseEnter:Connect(function()
            TweenService:Create(s, HOVER_INFO, { Scale = HOVER_SCALE }):Play()
            TweenService:Create(button, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
        end))
        track(button.MouseLeave:Connect(function()
            TweenService:Create(s, HOVER_INFO, { Scale = 1 }):Play()
            TweenService:Create(button, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
        end))

        local frame = create("ScrollingFrame", {
            Position = UDim2.new(0, 12, 0, 92),
            Size = UDim2.new(1, -24, 1, -102),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Off,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ZIndex = 3,
        }, body)
        create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2) }, frame)
        local layout = create("UIListLayout", {
            Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        }, frame)
        track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            pcall(function()
                frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
            end)
        end))

        local page = { frame = frame, order = 0 }
        tabs[name] = { button = button, stroke = stroke, page = page, index = tabOrder }
        table.insert(tabNames, name)
        track(button.MouseButton1Click:Connect(function()
            ripple(button, Theme.Cyan)
            Sfx.play("click")
            selectTab(name)
        end))
        return page
    end

    local movePage = createTab("Movement")
    local combatPage = createTab("Combat")
    local perfPage = createTab("Performance")
    local toolsPage = createTab("Tools")
    local settingsPage = createTab("Settings")

    -- ---------- Movement ----------
    createSlider(movePage, {
        key = "speed", name = "WalkSpeed Changer",
        desc = "Speed boost + anti-trip • 16 - 250",
        tip = "Pushes your root part along your move direction, sets WalkSpeed alongside, blocks Ragdoll/FallingDown/Tripping and locks the upright axis.",
        min = SPEED_MIN, max = SPEED_MAX, value = Cfg.speed, accent = Theme.Cyan,
        onChange = function(v) Cfg.speed = v; scheduleSave() end,
    })
    createToggle(movePage, {
        key = "fly", name = "Fly Hack Mode",
        desc = "F • WASD + Space/E up + Shift/Q down",
        tip = "Camera-aligned flight via LinearVelocity + AlignOrientation. F toggles. Releasing all keys hovers in place.",
        accent = Theme.Cyan, rebind = "fly",
        callback = featureCallback("Fly Hack Mode", Features.fly),
    })
    createToggle(movePage, {
        key = "noclip", name = "Noclip",
        desc = "N • walk through walls",
        tip = "Loops CanCollide off on every character part while enabled. Turning it off restores exactly the parts it changed.",
        accent = Theme.Green, rebind = "noclip",
        callback = featureCallback("Noclip", Features.noclip),
    })
    createSlider(movePage, {
        key = "flySpeed", name = "Fly Speed Control",
        desc = "Live flight speed • 10 - 300",
        tip = "Changes flight speed in real time, even mid-flight.",
        min = FLY_MIN, max = FLY_MAX, value = Cfg.flySpeed, accent = Theme.Green,
        onChange = function(v) Cfg.flySpeed = v; scheduleSave() end,
    })

    -- ---------- Combat ----------
    createToggle(combatPage, {
        key = "esp", name = "Universal Player ESP",
        desc = "Highlights other players through walls",
        tip = "Flat red highlight with white outline on every other player, always visible through walls. Local only.",
        accent = Theme.Cyan,
        callback = featureCallback("Player ESP", Features.esp),
    })
    createToggle(combatPage, {
        key = "espInfo", name = "ESP Info Tags + Arrows",
        desc = "Name • distance • health bar • edge arrows",
        tip = "Needs Player ESP on. Shows a tag above each player from any range plus an arrow at the screen edge pointing to players who are off-screen.",
        accent = Theme.Green,
        callback = featureCallback("ESP Info", Features.espInfo),
    })
    createToggle(combatPage, {
        key = "aura", name = "Auto-Hit / M1 Damage Aura",
        desc = "Swings tool + flings NPCs within 20 studs",
        tip = "Scans every 0.05s: swings your equipped tool and flings NPCs/dummies in range. Real players are always skipped.",
        accent = Theme.Green,
        callback = featureCallback("Damage Aura", Features.aura),
    })
    createToggle(combatPage, {
        key = "godMode", name = "100% God Mode",
        desc = "Health locked to max • CanTouch off",
        tip = "Locks health to max on every frame and health change, and turns CanTouch off on your limbs. Client-side only. Restored exactly when off.",
        accent = Theme.Cyan,
        callback = featureCallback("God Mode", Features.godMode),
    })
    createToggle(combatPage, {
        key = "invisible", name = "Invisible Mode",
        desc = "Hides character + name tag (local only)",
        tip = "Sets every part/decal of your character fully transparent locally and hides the name tag. Other players still see you. Originals restored exactly when off.",
        accent = Theme.Green,
        callback = featureCallback("Invisible Mode", Features.invisible),
    })

    -- ---------- Performance ----------
    createToggle(perfPage, {
        key = "optimizer", name = "Graphics & Animation Optimizer",
        desc = "Less effects, flat materials, low quality",
        tip = "Disables particles/trails/beams/post effects, flattens materials, hides decals, lowers render quality. Restored when off.",
        accent = Theme.Green,
        callback = featureCallback("FPS Optimizer", Features.optimizer),
    })
    createToggle(perfPage, {
        key = "noFog", name = "Remove Fog",
        desc = "Pushes fog out to infinity",
        tip = "FogStart/FogEnd huge, Atmosphere density and haze zeroed. Originals restored when off.",
        accent = Theme.Cyan,
        callback = featureCallback("Remove Fog", Features.noFog),
    })
    createToggle(perfPage, {
        key = "fullBright", name = "Full Bright Mode",
        desc = "Pure white ambient light",
        tip = "Forces Ambient/OutdoorAmbient to white and raises brightness. Original lighting restored when off.",
        accent = Theme.Green,
        callback = featureCallback("Full Bright", Features.fullBright),
    })

    -- ============================================================
    -- EXTRAS (v5): themes, search, profiles, keybinds, HUD, resize
    -- ============================================================
    local function createSection(page, text)
        page.order += 1
        return create("TextLabel", {
            Name = "Section" .. page.order, LayoutOrder = page.order,
            Size = UDim2.new(1, -10, 0, 22), BackgroundTransparency = 1,
            Text = "  " .. string.upper(text), TextSize = 13, TextColor3 = Theme.Cyan,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, page.frame)
    end

    local function cardLabels(card, title, desc, rightPad)
        create("TextLabel", {
            Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -(rightPad or 24), 0, 22),
            BackgroundTransparency = 1, Text = title, TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
        return create("TextLabel", {
            Position = UDim2.new(0, 12, 0, 31), Size = UDim2.new(1, -(rightPad or 24), 0, 20),
            BackgroundTransparency = 1, Text = desc, TextSize = 14, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
    end

    -- ---------- UI scale (debounced so dragging the slider doesn't fight itself) ----------
    local scaleToken = 0
    local function applyUiScale()
        scaleToken += 1
        local tok = scaleToken
        task.delay(0.35, function()
            if tok ~= scaleToken or not (Main and Main.Parent) then return end
            TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Scale = userScale() }):Play()
        end)
    end

    -- ---------- Keybind rebinding ----------
    local RESERVED = { W = true, A = true, S = true, D = true, E = true, Q = true,
        Space = true, LeftShift = true, Return = true, Tab = true }
    local NON_TYPING = { RightControl = true, LeftControl = true, RightShift = true, Insert = true,
        Home = true, End = true, Delete = true, PageUp = true, PageDown = true }
    local Rebind = { action = nil, token = 0, refreshers = {} }

    function Rebind.codeOf(action)
        local ok, kc = pcall(function() return Enum.KeyCode[Cfg.keys[action]] end)
        if ok and kc then return kc end
        return Enum.KeyCode[DEFAULT_KEYS[action]]
    end
    function Rebind.safeWhileTyping(code)
        return NON_TYPING[code.Name] == true or string.match(code.Name, "^F%d+$") ~= nil
    end
    function Rebind.refresh()
        for _, fn in ipairs(Rebind.refreshers) do pcall(fn) end
    end
    function Rebind.cancel()
        Rebind.action = nil
        Rebind.token += 1
        Rebind.refresh()
    end
    function Rebind.begin(action)
        Rebind.action = action
        Rebind.token += 1
        local tok = Rebind.token
        Rebind.refresh()
        task.delay(6, function()
            if Rebind.action == action and Rebind.token == tok then Rebind.cancel() end
        end)
    end
    function Rebind.capture(code)
        local action = Rebind.action
        if code == Enum.KeyCode.Escape then
            Rebind.cancel()
            Toast.show("Rebind cancelled", Theme.Off, 1.5)
            return
        end
        if code == Enum.KeyCode.Unknown then return end
        if RESERVED[code.Name] then
            Toast.show(code.Name .. " is reserved (flight / typing)", Theme.Red, 2.5)
            return
        end
        for other, name in pairs(Cfg.keys) do
            if other ~= action and name == code.Name then
                Toast.show(code.Name .. " is already used by another action", Theme.Red, 2.5)
                return
            end
        end
        Cfg.keys[action] = code.Name
        Rebind.action = nil
        Rebind.token += 1
        Rebind.refresh()
        scheduleSave()
        Toast.show("Key set to " .. code.Name, Theme.Green, 2)
    end

    local function createKeybindRow(page, spec)
        local card, cardStroke = createCard(page, "Key" .. spec.id, 58, Theme.Cyan)
        card:SetAttribute("search", string.lower("keybind hotkey key " .. spec.name .. " " .. spec.desc))
        cardLabels(card, spec.name, spec.desc, 170)
        local btn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(130, 30), BackgroundColor3 = Theme.Black,
            Text = "", TextSize = 14, AutoButtonColor = false, ZIndex = 5,
        }, card)
        addCorner(btn, 4)
        local bStroke = addFlatStroke(btn, Theme.Off, 1)
        local function refresh()
            if Rebind.action == spec.id then
                btn.Text = "Press a key..."
                btn.TextColor3 = Theme.Green
                bStroke.Color = Theme.Green
            else
                btn.Text = Cfg.keys[spec.id] or DEFAULT_KEYS[spec.id]
                btn.TextColor3 = Theme.White
                bStroke.Color = Theme.Off
            end
        end
        table.insert(Rebind.refreshers, refresh)
        refresh()
        track(btn.MouseButton1Click:Connect(function()
            ripple(card, Theme.Cyan)
            if Rebind.action == spec.id then Rebind.cancel() else Rebind.begin(spec.id) end
        end))
        addHoverFX(card, cardStroke)
        Tooltip.attach(card, "Click, then press the new key. Esc cancels. W A S D E Q Space and Shift are reserved for flight.")
    end

    -- ---------- Profiles ----------
    local function profileSummary(pr)
        if not pr then return "Empty slot" end
        local n = 0
        for _, k in ipairs(PROFILE_TOGGLES) do if pr[k] then n += 1 end end
        return "Speed " .. tostring(pr.speed) .. " • Fly " .. tostring(pr.flySpeed)
            .. " • " .. n .. (n == 1 and " toggle" or " toggles") .. " on"
    end

    local ProfileApi = { descs = {} }
    function ProfileApi.save(i)
        local key = tostring(i)
        local snap = { speed = Cfg.speed, flySpeed = Cfg.flySpeed }
        for _, k in ipairs(PROFILE_TOGGLES) do
            snap[k] = UI.toggles[k] and UI.toggles[k].Get() == true
        end
        Cfg.profiles[key] = snap
        if ProfileApi.descs[key] then ProfileApi.descs[key].Text = profileSummary(snap) end
        scheduleSave()
        Toast.show("Profile " .. i .. " saved", Theme.Green)
    end
    function ProfileApi.load(i)
        local pr = Cfg.profiles[tostring(i)]
        if not pr then
            Toast.show("Profile " .. i .. " is empty", Theme.Red)
            return false
        end
        pcall(function() UI.sliders.speed.Set(pr.speed) end)
        pcall(function() UI.sliders.flySpeed.Set(pr.flySpeed) end)
        for _, k in ipairs(PROFILE_TOGGLES) do
            pcall(function() UI.toggles[k].Set(pr[k] == true, true) end)
        end
        Toast.show("Profile " .. i .. " loaded", Theme.Green)
        return true
    end

    local function createProfileCard(page, i)
        local key = tostring(i)
        local card, cardStroke = createCard(page, "Profile" .. i, 58, Theme.Cyan)
        card:SetAttribute("search", string.lower("profile preset slot " .. i .. " save load"))
        local desc = cardLabels(card, "Profile " .. i, profileSummary(Cfg.profiles[key]), 170)

        local function miniBtn(text, xOff, color)
            local b = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0),
                Size = UDim2.fromOffset(66, 28), BackgroundColor3 = Theme.Black,
                Text = text, TextSize = 14, AutoButtonColor = false, ZIndex = 5,
            }, card)
            addCorner(b, 4)
            addFlatStroke(b, color, 1)
            track(b.MouseEnter:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
            end))
            track(b.MouseLeave:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
            end))
            return b
        end
        local saveB = miniBtn("Save", -82, Theme.Cyan)
        local loadB = miniBtn("Load", -10, Theme.Green)

        ProfileApi.descs[key] = desc
        track(saveB.MouseButton1Click:Connect(function()
            ripple(card, Theme.Cyan)
            Sfx.play("click")
            ProfileApi.save(i)
        end))
        track(loadB.MouseButton1Click:Connect(function()
            ripple(card, Theme.Green)
            Sfx.play("click")
            ProfileApi.load(i)
        end))
        addHoverFX(card, cardStroke)
    end

    -- ---------- Stats HUD ----------
    local HUD = { frame = nil }
    local HUD_NAMES = { fly = "Fly", godMode = "God", invisible = "Invis", esp = "ESP",
        aura = "Aura", optimizer = "Opt", noFog = "NoFog", fullBright = "Bright",
        noclip = "Clip", antiAfk = "AFK" }

    local function getPing()
        local ok, v = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(v) == "number" then return math.floor(v + 0.5) end
        local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() * 2000 end)
        if ok2 and type(p) == "number" then return math.floor(p + 0.5) end
        return 0
    end

    do
        local f = create("Frame", {
            Name = "StatsHUD", Position = UDim2.new(0, 12, 0, 12),
            Size = UDim2.fromOffset(172, 112), BackgroundColor3 = Theme.Black,
            BackgroundTransparency = 0.15, BorderSizePixel = 0, Active = true,
            Visible = false, ZIndex = 60,
        }, ScreenGui)
        addCorner(f, 6)
        addFlatStroke(f, Theme.Cyan, 1)
        local dot = create("Frame", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -7, 0, 7),
            Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.Green,
            BorderSizePixel = 0, ZIndex = 61,
        }, f)
        addCorner(dot, 3)
        local lbl = create("TextLabel", {
            Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -20, 0, 48),
            BackgroundTransparency = 1, Text = "", TextSize = 12, Font = Enum.Font.RobotoMono,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 61,
        }, f)
        local onLbl = create("TextLabel", {
            Position = UDim2.fromOffset(8, 56), Size = UDim2.new(1, -16, 0, 16),
            BackgroundTransparency = 1, Text = "", TextSize = 12, Font = Enum.Font.RobotoMono,
            TextColor3 = Theme.Green, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61,
        }, f)
        makeDraggable(f, f, nil, nil, true)
        HUD.frame = f

        -- rolling 60s FPS sparkline: 60 thin bars, newest on the right
        local spark = create("Frame", {
            Position = UDim2.fromOffset(8, 76), Size = UDim2.new(1, -16, 0, 28),
            BackgroundColor3 = Theme.Dark, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 61,
        }, f)
        addCorner(spark, 3)
        local bars = {}
        for i = 1, SPARK_SAMPLES do
            bars[i] = create("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new((i - 1) / SPARK_SAMPLES, 0, 1, 0),
                Size = UDim2.new(1 / SPARK_SAMPLES, 0, 0, 0),
                BackgroundColor3 = Theme.Green, BorderSizePixel = 0, ZIndex = 62,
            }, spark)
        end
        local hist = {}
        local function drawSpark()
            local top = 60
            for _, v in ipairs(hist) do if v > top then top = v end end
            local off = SPARK_SAMPLES - #hist
            for i = 1, SPARK_SAMPLES do
                local v = hist[i - off]
                local b = bars[i]
                if v then
                    b.Size = UDim2.new(1 / SPARK_SAMPLES, 0, math.clamp(v / top, 0.04, 1), 0)
                    b.BackgroundColor3 = v >= 50 and Theme.Green
                        or (v >= 30 and Color3.fromRGB(255, 200, 0) or Theme.Red)
                else
                    b.Size = UDim2.new(1 / SPARK_SAMPLES, 0, 0, 0)
                end
            end
        end

        local acc, frames, startT, histAcc, fpsNow = 0, 0, os.clock(), 0, 60
        Loop.register("Stats HUD", function(dt)
            acc += dt
            frames += 1
            histAcc += dt
            if acc >= 0.25 then
                local fps = frames / acc
                acc, frames = 0, 0
                fpsNow = fps
                if f.Visible then
                    local _, _, hrp = getCharacterParts()
                    local posText = "-"
                    if hrp then
                        local ps = hrp.Position
                        posText = math.floor(ps.X) .. " " .. math.floor(ps.Y) .. " " .. math.floor(ps.Z)
                    end
                    local up = math.floor(os.clock() - startT)
                    local timeText = up >= 3600
                        and string.format("%d:%02d:%02d", math.floor(up / 3600), math.floor((up % 3600) / 60), up % 60)
                        or string.format("%02d:%02d", math.floor(up / 60), up % 60)
                    local active = {}
                    for _, k in ipairs(TOGGLE_KEYS) do
                        local t = UI.toggles[k]
                        if t and t.Get() then table.insert(active, HUD_NAMES[k] or k) end
                    end
                    lbl.Text = string.format("FPS %d  %dms\nPOS %s\nPLR %d/%s  %s",
                        math.floor(fps + 0.5), getPing(), posText,
                        #Players:GetPlayers(), tostring(Players.MaxPlayers), timeText)
                    onLbl.Text = "ON " .. (#active > 0 and table.concat(active, " ") or "-")
                    dot.BackgroundColor3 = fps >= 50 and Theme.Green
                        or (fps >= 30 and Color3.fromRGB(255, 200, 0) or Theme.Red)
                end
            end
            if histAcc >= 1 then
                histAcc -= 1
                table.insert(hist, math.floor(fpsNow + 0.5))
                if #hist > SPARK_SAMPLES then table.remove(hist, 1) end
                if f.Visible then drawSpark() end
            end
        end, { feature = "hud" })
    end

    -- ======================= TOOLS TAB =======================
    createSection(toolsPage, "Monitoring")
    createToggle(toolsPage, {
        key = "hud", name = "Stats HUD", desc = "FPS • ping • position • active toggles",
        tip = "Small draggable overlay with live FPS, ping, your position, session time and which toggles are on.",
        accent = Theme.Cyan,
        callback = function(on)
            Cfg.hud = on and true or false
            if HUD.frame then HUD.frame.Visible = Cfg.hud end
            scheduleSave()
        end,
    })

    createSection(toolsPage, "Utility")
    createToggle(toolsPage, {
        key = "antiAfk", name = "Anti-AFK",
        desc = "Dodges the 20-minute idle kick",
        tip = "Every ~4 minutes sends a harmless right-click and a microscopic camera nudge, and answers the idle event.",
        accent = Theme.Green,
        callback = featureCallback("Anti-AFK", Features.antiAfk),
    })

    createSection(toolsPage, "Profiles")
    for i = 1, 3 do createProfileCard(toolsPage, i) end


    -- ---------- Waypoints ----------
    createSection(toolsPage, "Waypoints")
    local Waypoints = { refreshers = {} }
    function Waypoints.go(i)
        local w = Cfg.waypoints[tostring(i)]
        if not w then
            Toast.show("Waypoint " .. tostring(i) .. " is empty", Theme.Red)
            return false
        end
        local _, _, hrp = getCharacterParts()
        if not hrp then return false end
        hrp.CFrame = CFrame.new(table.unpack(w.cf)) + Vector3.new(0, 3, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        Toast.show("Teleported to " .. w.name, Theme.Green, 1.8)
        return true
    end
    function Waypoints.set(i)
        local _, _, hrp = getCharacterParts()
        if not hrp then return false end
        local key = tostring(i)
        local old = Cfg.waypoints[key]
        Cfg.waypoints[key] = { name = old and old.name or ("Slot " .. i), cf = { hrp.CFrame:GetComponents() } }
        scheduleSave()
        for _, fn in ipairs(Waypoints.refreshers) do pcall(fn) end
        Toast.show("Saved " .. Cfg.waypoints[key].name, Theme.Green, 1.8)
        return true
    end
    function Waypoints.delete(i)
        Cfg.waypoints[tostring(i)] = nil
        scheduleSave()
        for _, fn in ipairs(Waypoints.refreshers) do pcall(fn) end
        Toast.show("Cleared slot " .. i, Theme.Off, 1.5)
    end

    for i = 1, WAYPOINT_SLOTS do
        local card, cardStroke = createCard(toolsPage, "Waypoint" .. i, 58, Theme.Cyan)
        card:SetAttribute("search", "waypoint teleport position slot save " .. i)
        card:SetAttribute("desc", "Waypoint slot " .. i)
        local title = create("TextBox", {
            Position = UDim2.new(0, 12, 0, 7), Size = UDim2.new(1, -176, 0, 22),
            BackgroundTransparency = 1, Text = "", TextSize = 16, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            PlaceholderText = "Slot " .. i, PlaceholderColor3 = Theme.Off,
        }, card)
        local desc = create("TextLabel", {
            Position = UDim2.new(0, 12, 0, 31), Size = UDim2.new(1, -176, 0, 20),
            BackgroundTransparency = 1, Text = "", TextSize = 14, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
        local function refresh()
            local w = Cfg.waypoints[tostring(i)]
            if w then
                title.Text = w.name
                desc.Text = string.format("%d, %d, %d", math.floor(w.cf[1]), math.floor(w.cf[2]), math.floor(w.cf[3]))
            else
                title.Text = ""
                desc.Text = "Empty • press Set to store your position"
            end
        end
        table.insert(Waypoints.refreshers, refresh)
        refresh()
        track(title.FocusLost:Connect(function()
            local w = Cfg.waypoints[tostring(i)]
            if not w then title.Text = "" return end
            local txt = string.gsub(title.Text, "^%s+", "")
            txt = string.sub(txt, 1, 18)
            if txt == "" then txt = "Slot " .. i end
            w.name = txt
            title.Text = txt
            scheduleSave()
        end))
        local function wpBtn(text, xOff, color, fn)
            local b = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0),
                Size = UDim2.fromOffset(46, 28), BackgroundColor3 = Theme.Black,
                Text = text, TextSize = 14, AutoButtonColor = false, ZIndex = 5,
            }, card)
            b:SetAttribute("NoBoost", true)
            addCorner(b, 4)
            addFlatStroke(b, color, 1)
            track(b.MouseEnter:Connect(function()
                Sfx.play("hover")
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
            end))
            track(b.MouseLeave:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
            end))
            track(b.MouseButton1Click:Connect(function()
                ripple(card, color)
                Sfx.play("click")
                guard("Waypoint " .. text, nil, fn)
            end))
        end
        wpBtn("Del", -10, Theme.Red, function() Waypoints.delete(i) end)
        wpBtn("Go", -62, Theme.Green, function() Waypoints.go(i) end)
        wpBtn("Set", -114, Theme.Cyan, function() Waypoints.set(i) end)
        addHoverFX(card, cardStroke)
        Tooltip.attach(card, "Set stores your current position. Go teleports you there. Click the name to rename it. Del clears the slot.")
    end

    -- ---------- Server finder ----------
    createSection(toolsPage, "Servers")
    local TeleportService = game:GetService("TeleportService")
    local Hop = { busy = false, bad = {}, list = nil, idx = 0, pending = nil, tries = 0 }

    local function httpGet(url)
        local body
        local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
            or (fluxus and fluxus.request)
        if reqFn then
            local ok, res = pcall(reqFn, { Url = url, Method = "GET" })
            if ok and type(res) == "table" and type(res.Body) == "string" then body = res.Body end
        end
        if not body then
            local ok, res = pcall(function() return game:HttpGet(url) end)
            if ok and type(res) == "string" then body = res end
        end
        return body
    end

    function Hop.fetch()
        local servers, cursor = {}, nil
        for _ = 1, 5 do
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100", game.PlaceId)
            if cursor then url = url .. "&cursor=" .. cursor end
            local body = httpGet(url)
            if not body then return servers, (#servers == 0) and "no http" or nil end
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
                return servers, (#servers == 0) and "rate limited or blocked" or nil
            end
            for _, sv in ipairs(data.data) do table.insert(servers, sv) end
            cursor = data.nextPageCursor
            if not cursor then break end
            task.wait(0.6)
        end
        return servers, nil
    end

    local function tryNext()
        if not Hop.list then Hop.busy = false return end
        Hop.idx += 1
        Hop.tries += 1
        local sv = Hop.list[Hop.idx]
        if not sv or Hop.tries > 4 then
            Hop.busy, Hop.pending, Hop.list = false, nil, nil
            Toast.show("Couldn't join a server (full or blocked). Try again.", Theme.Red, 3.5)
            return
        end
        Hop.pending = sv.id
        pcall(saveConfig)
        Toast.show("Joining server with " .. tostring(sv.playing) .. " player(s)...", Theme.Green, 3)
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LocalPlayer)
        end)
        if not ok then
            Hop.bad[sv.id] = true
            tryNext()
        end
    end

    track(TeleportService.TeleportInitFailed:Connect(function(player)
        if player == LocalPlayer and Hop.pending then
            Hop.bad[Hop.pending] = true
            Hop.pending = nil
            task.delay(0.5, tryNext)
        end
    end))

    local function startHop(mode)
        if Hop.busy then return end
        if game.PrivateServerId ~= "" then
            Toast.show("This is a private server. Public server list doesn't apply.", Theme.Red, 3.5)
            return
        end
        Hop.busy, Hop.tries = true, 0
        Toast.show("Searching servers...", Theme.Cyan, 2)
        task.spawn(function()
            local servers, err = Hop.fetch()
            local pool = {}
            for _, sv in ipairs(servers) do
                if type(sv.id) == "string" and sv.id ~= game.JobId and not Hop.bad[sv.id]
                    and type(sv.playing) == "number" and type(sv.maxPlayers) == "number"
                    and sv.playing >= 1 and sv.playing < sv.maxPlayers then
                    table.insert(pool, sv)
                end
            end
            if #pool == 0 then
                Hop.busy = false
                Toast.show(err and ("Server search failed: " .. err) or "No other open servers found.", Theme.Red, 3.5)
                return
            end
            table.sort(pool, function(a, b) return a.playing < b.playing end)
            local list = {}
            if mode == "low" then
                local limit = Cfg.hopMax or 8
                for _, sv in ipairs(pool) do
                    if sv.playing <= limit then table.insert(list, sv) end
                end
                if #list == 0 then
                    Hop.busy = false
                    Toast.show("No server with " .. limit .. " or fewer players. Lowest is "
                        .. pool[1].playing .. " - raise the limit.", Theme.Red, 4.5)
                    return
                end
                -- shuffle the few lowest so repeated clicks don't all hit the same server
                for i = math.min(#list, 5), 2, -1 do
                    local j = math.random(1, i)
                    list[i], list[j] = list[j], list[i]
                end
            else
                list = pool
                for i = #list, 2, -1 do
                    local j = math.random(1, i)
                    list[i], list[j] = list[j], list[i]
                end
            end
            Hop.list, Hop.idx = list, 0
            tryNext()
        end)
    end

    local serverCard = createCard(toolsPage, "ServerInfo", 58, Theme.Off)
    serverCard:SetAttribute("search", "server players count current low population hop join")
    local serverDesc = cardLabels(serverCard, "Current Server", "...")
    local function refreshServerInfo()
        local n = #Players:GetPlayers()
        local mx = Players.MaxPlayers
        serverDesc.Text = n .. " / " .. tostring(mx) .. " players"
    end
    refreshServerInfo()
    task.spawn(function()
        while Runtime.alive and serverCard.Parent do
            task.wait(4)
            pcall(refreshServerInfo)
        end
    end)

    createSlider(toolsPage, {
        key = "hopMax", name = "Low-Pop Limit", desc = "Max players allowed in the server • 1 - 30",
        tip = "Join Low-Pop Server only picks servers with this many players or fewer.",
        min = 1, max = 30, value = Cfg.hopMax or 8, accent = Theme.Cyan,
        onChange = function(v) Cfg.hopMax = v; scheduleSave() end,
    })
    createButton(toolsPage, "Join Low-Pop Server", Theme.Green,
        "Looks up this game's public servers and teleports you to one with few players. Needs an executor with HTTP support. The script has to be re-run in the new server.",
        function() startHop("low") end)
    createButton(toolsPage, "Join Random Server", Theme.Cyan,
        "Teleports you to a random other public server that isn't full.",
        function() startHop("random") end)

    createSection(toolsPage, "Server Tools")
    local function joinServer(id)
        Hop.pending = id
        pcall(saveConfig)
        Toast.show("Joining server...", Theme.Green, 2.5)
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
        end)
        if not ok then Toast.show("Teleport failed", Theme.Red, 3) end
    end
    local function rejoin()
        pcall(saveConfig)
        Toast.show("Rejoining...", Theme.Cyan, 2.5)
        local ok = false
        if game.PrivateServerId == "" and game.JobId ~= "" then
            ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
        end
        if not ok then
            ok = pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
        if not ok then Toast.show("Rejoin failed", Theme.Red, 3) end
    end
    local function copyJobId()
        local ok = pcall(function() setclipboard(game.JobId) end)
        Toast.show(ok and "JobId copied" or "Clipboard unavailable here", ok and Theme.Green or Theme.Red)
    end
    createButton(toolsPage, "Rejoin Current Server", Theme.Cyan,
        "Teleports you back into this exact server (or a fresh one if it is private).", rejoin)
    createButton(toolsPage, "Copy JobId", Theme.Green,
        "Copies this server's JobId to the clipboard (needs setclipboard).", copyJobId)

    -- ---------- Join by JobId ----------
    local jobIdCard, jobIdStroke = createCard(toolsPage, "JoinByJobId", 92, Theme.Cyan)
    jobIdCard:SetAttribute("search", "join by jobid job id server paste teleport")
    jobIdCard:SetAttribute("desc", "Join by JobId - paste a JobId from this game, then press Join")
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 22),
        BackgroundTransparency = 1, Text = "Join by JobId", TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, jobIdCard)
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(1, -24, 0, 18),
        BackgroundTransparency = 1, Text = "Paste a JobId from this game, then press Join",
        TextSize = 13, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, jobIdCard)
    local jobIdBox = create("TextBox", {
        Position = UDim2.new(0, 12, 0, 52), Size = UDim2.new(1, -82, 0, 30),
        BackgroundColor3 = Theme.Dark, Text = "", ClearTextOnFocus = false,
        PlaceholderText = "XXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, jobIdCard)
    addCorner(jobIdBox, 4)
    addFlatStroke(jobIdBox, Theme.Off, 1)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, jobIdBox)
    local function jidBtn(text, xOff, color)
        local b = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 52),
            Size = UDim2.fromOffset(56, 30), BackgroundColor3 = Theme.Black,
            Text = text, TextSize = 14, AutoButtonColor = false, ZIndex = 5,
        }, jobIdCard)
        b:SetAttribute("NoBoost", true)
        addCorner(b, 4)
        addFlatStroke(b, color, 1)
        track(b.MouseEnter:Connect(function()
            Sfx.play("hover")
            TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
        end))
        track(b.MouseLeave:Connect(function()
            TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
        end))
        return b
    end
    local joinIdBtn = jidBtn("Join", -6, Theme.Green)
    track(joinIdBtn.MouseButton1Click:Connect(function()
        ripple(jobIdCard, Theme.Green)
        Sfx.play("click")
        local id = string.gsub(jobIdBox.Text, "^%s*(.-)%s*$", "%1")
        if id == "" then
            Toast.show("Enter a JobId first", Theme.Red, 2)
            return
        end
        joinServer(id)
    end))
    addHoverFX(jobIdCard, jobIdStroke)

    -- clickable server browser (reuses Hop.fetch)
    local ServerBrowser = { busy = false }
    local sbCard = createCard(toolsPage, "ServerBrowser", 240, Theme.Cyan)
    sbCard:SetAttribute("search", "server browser list join players count rejoin")
    sbCard:SetAttribute("desc", "Server Browser - click a server to join it")
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -110, 0, 22),
        BackgroundTransparency = 1, Text = "Server Browser", TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sbCard)
    local sbRefresh = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4),
        Size = UDim2.fromOffset(84, 26), BackgroundColor3 = Theme.Black,
        Text = "Refresh", TextSize = 14, AutoButtonColor = false, ZIndex = 5,
    }, sbCard)
    sbRefresh:SetAttribute("NoBoost", true)
    addCorner(sbRefresh, 4)
    addFlatStroke(sbRefresh, Theme.Green, 1)
    local sbList = create("ScrollingFrame", {
        Position = UDim2.new(0, 10, 0, 36), Size = UDim2.new(1, -20, 1, -46),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Off, CanvasSize = UDim2.new(), ZIndex = 4,
    }, sbCard)
    local sbLayout = create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sbList)
    track(sbLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sbList.CanvasSize = UDim2.new(0, 0, 0, sbLayout.AbsoluteContentSize.Y + 4)
    end))
    local sbNote = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "Press Refresh to list public servers.",
        TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, sbList)
    local function clearRows()
        for _, c in ipairs(sbList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end
    function ServerBrowser.refresh()
        if ServerBrowser.busy then return end
        if game.PrivateServerId ~= "" then
            sbNote.Text = "Private server: public list doesn't apply."
            return
        end
        ServerBrowser.busy = true
        sbNote.Visible = true
        sbNote.Text = "Searching servers..."
        clearRows()
        task.spawn(function()
            local servers, err = Hop.fetch()
            ServerBrowser.busy = false
            if not (sbCard.Parent and Runtime.alive) then return end
            local rows = {}
            for _, sv in ipairs(servers) do
                if type(sv.id) == "string" and type(sv.playing) == "number" and type(sv.maxPlayers) == "number" then
                    table.insert(rows, sv)
                end
            end
            table.sort(rows, function(a, b) return a.playing < b.playing end)
            if #rows == 0 then
                sbNote.Text = err and ("Failed: " .. err) or "No servers found."
                return
            end
            sbNote.Visible = false
            for n = 1, math.min(#rows, 60) do
                local sv = rows[n]
                local here = sv.id == game.JobId
                local ping = type(sv.ping) == "number" and (sv.ping .. "ms") or "--"
                local row = create("TextButton", {
                    LayoutOrder = n, Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = Theme.Dark,
                    Text = string.format("%s%d / %d players   %s   %s", here and "* " or "", sv.playing,
                        sv.maxPlayers, ping, string.sub(sv.id, 1, 6)),
                    TextSize = 13, AutoButtonColor = false, ZIndex = 5,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = here and Theme.Green or Theme.White,
                }, sbList)
                row:SetAttribute("NoBoost", true)
                create("UIPadding", { PaddingLeft = UDim.new(0, 8) }, row)
                addCorner(row, 4)
                track(row.MouseEnter:Connect(function()
                    Sfx.play("hover")
                    TweenService:Create(row, HOVER_INFO, { BackgroundColor3 = Theme.HoverGrey }):Play()
                end))
                track(row.MouseLeave:Connect(function()
                    TweenService:Create(row, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
                end))
                track(row.MouseButton1Click:Connect(function()
                    Sfx.play("click")
                    if here then Toast.show("You are already in this server", Theme.Off, 2) return end
                    joinServer(sv.id)
                end))
            end
        end)
    end
    track(sbRefresh.MouseButton1Click:Connect(function()
        ripple(sbCard, Theme.Green)
        Sfx.play("click")
        guard("Server browser", nil, ServerBrowser.refresh)
    end))

    createSection(toolsPage, "Activity")
    local histCard = createCard(toolsPage, "History", 80, Theme.Off)
    histCard:SetAttribute("search", "notification history log activity toasts")
    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 20),
        BackgroundTransparency = 1, Text = "Notification History", TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, histCard)
    local histBody = create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -24, 1, -38),
        BackgroundTransparency = 1, Text = "", TextSize = 13, TextColor3 = Theme.SubText,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, histCard)
    local function refreshHistory()
        if not histCard.Parent then return end
        local lines = {}
        for i = 1, math.min(8, #NotifLog.entries) do
            local e = NotifLog.entries[i]
            lines[#lines + 1] = e.t .. "  " .. e.text
        end
        local txt = #lines > 0 and table.concat(lines, "\n") or "Nothing yet. Toggle something and it shows up here."
        histBody.Text = txt
        local w = 380
        local abs = histCard.AbsoluteSize.X
        if abs > 60 then w = math.floor(abs / math.max(scale.Scale, 0.1)) - 28 end
        local _, h = measureText(txt, 13, math.max(w, 160))
        histCard.Size = UDim2.new(1, -10, 0, math.max(60, h + 44))
    end
    table.insert(NotifLog.listeners, refreshHistory)
    refreshHistory()
    createButton(toolsPage, "Clear Notification History", Theme.Off, "Wipes the log above.", function()
        table.clear(NotifLog.entries)
        refreshHistory()
    end)

    -- ======================= SETTINGS TAB =======================
    createSection(settingsPage, "Appearance")
    local themeCard = createCard(settingsPage, "Theme", 100, Theme.Cyan)
    themeCard:SetAttribute("search", "theme accent color colour appearance")
    cardLabels(themeCard, "Accent Theme", "Pick a color scheme • applies instantly")
    local swatchRow = create("Frame", {
        Position = UDim2.new(0, 12, 0, 62), Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
    }, themeCard)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
    }, swatchRow)
    local swatches = {}
    local function refreshSwatches()
        for name, st in pairs(swatches) do
            local sel = (name == Cfg.theme)
            st.Color = sel and Theme.White or Theme.Off
            st.Thickness = sel and 3 or 2
        end
    end
    for i, pr in ipairs(THEME_PRESETS) do
        local b = create("TextButton", {
            LayoutOrder = i, Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Theme.White,
            Text = "", AutoButtonColor = false, ZIndex = 5,
        }, swatchRow)
        b:SetAttribute("NoTheme", true) -- keep swatch colors fixed while the rest recolors
        addCorner(b, 15)
        create("UIGradient", { Color = ColorSequence.new(pr.c1, pr.c2), Rotation = 45 }, b)
        swatches[pr.name] = create("UIStroke", {
            Color = Theme.Off, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, b)
        Tooltip.attach(b, pr.name .. " theme")
        track(b.MouseButton1Click:Connect(function()
            applyTheme(pr.name)
            refreshSwatches()
            Toast.show(pr.name .. " theme applied", Theme.Cyan, 1.8)
        end))
    end
    refreshSwatches()

    createSlider(settingsPage, {
        key = "uiScale", name = "UI Scale", desc = "Panel size in percent • 70 - 140",
        tip = "Scales the whole panel. Applies a moment after you stop dragging. Touch devices start larger.",
        min = 70, max = 140, value = Cfg.uiScale, accent = Theme.Cyan,
        onChange = function(v) Cfg.uiScale = v; applyUiScale(); scheduleSave() end,
    })
    local fontCard = createCard(settingsPage, "FontStyle", 100, Theme.Cyan)
    fontCard:SetAttribute("search", "font text style readable bold sharp clean modern retro")
    cardLabels(fontCard, "Text Style", "Pick whichever font is easiest to read")
    local fontRow = create("Frame", {
        Position = UDim2.new(0, 12, 0, 62), Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
    }, fontCard)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, fontRow)
    local fontStrokes = {}
    local function refreshFontButtons()
        for name, st in pairs(fontStrokes) do
            st.Color = (name == Cfg.font) and Theme.Green or Theme.Off
        end
    end
    local nFonts = #FONT_PRESETS
    for i, fp in ipairs(FONT_PRESETS) do
        local b = create("TextButton", {
            LayoutOrder = i, Size = UDim2.new(1 / nFonts, -8 * (nFonts - 1) / nFonts, 1, 0),
            BackgroundColor3 = Theme.Black, Text = fp.name, TextSize = 15, Font = fp.font,
            AutoButtonColor = false, ZIndex = 5,
        }, fontRow)
        b:SetAttribute("NoFont", true)
        b:SetAttribute("NoBoost", true)
        addCorner(b, 4)
        fontStrokes[fp.name] = addFlatStroke(b, Theme.Off, 1.5)
        track(b.MouseButton1Click:Connect(function()
            Cfg.font = fp.name
            Theme.Font = fp.font
            applyTextStyle(true)
            refreshFontButtons()
            scheduleSave()
        end))
    end
    refreshFontButtons()

    createSlider(settingsPage, {
        key = "textBoost", name = "Text Size", desc = "Extra pixels added to all text • 0 - 4",
        tip = "Makes every label bigger. Raise it if anything is hard to read.",
        min = 0, max = 4, value = Cfg.textBoost, accent = Theme.Cyan,
        onChange = function(v) Cfg.textBoost = v; applyTextStyle(); scheduleSave() end,
    })
    createToggle(settingsPage, {
        key = "toasts", name = "Notifications", desc = "Pop-up toasts • history always logs",
        tip = "Turns the corner pop-ups on or off. The Notification History in Tools keeps logging either way.",
        accent = Theme.Green,
        callback = function(on) Cfg.toasts = on and true or false; scheduleSave() end,
    })

    createSection(settingsPage, "Sound")
    createSlider(settingsPage, {
        key = "volume", name = "Master Volume", desc = "Hover, click and toggle sounds • 0 - 100",
        tip = "Controls every UI sound. Set to 0 to mute.",
        min = 0, max = 100, value = Cfg.volume, accent = Theme.Green,
        onChange = function(v) Cfg.volume = v; scheduleSave() end,
    })

    createSection(settingsPage, "Keybinds")
    for _, spec in ipairs({
        { id = "toggleUI", name = "Show / Hide Panel", desc = "Toggles the whole window" },
        { id = "minimize", name = "Minimize Panel", desc = "Collapse to the floating E button" },
        { id = "fly", name = "Toggle Fly", desc = "Quick on / off for Fly Hack Mode" },
        { id = "noclip", name = "Toggle Noclip", desc = "Quick on / off for Noclip" },
        { id = "search", name = "Focus Command Bar", desc = "Jumps to the search / command box" },
    }) do
        createKeybindRow(settingsPage, spec)
    end

    createSection(settingsPage, "Data")
    createToggle(settingsPage, {
        key = "perGame", name = "Per-game settings",
        desc = "Separate config for each game (PlaceId)",
        tip = "Saves to EkantoConfig_" .. tostring(game.PlaceId) .. ".json and loads it here next time. If that file doesn't exist yet, your global config is used.",
        accent = Theme.Cyan,
        callback = function(on, silent)
            Cfg.perGame = on and true or false
            scheduleSave()
            if not silent then
                Toast.show(on and "Per-game config on for this place" or "Per-game config off (global file only)", Theme.Cyan)
            end
        end,
    })
    local resetArmed = false
    local function doReset()
        for _, k in ipairs(TOGGLE_KEYS) do pcall(function() UI.toggles[k].Set(false, true) end) end
        pcall(function() UI.sliders.speed.Set(SPEED_MIN) end)
        pcall(function() UI.sliders.flySpeed.Set(DEFAULT_CONFIG.flySpeed) end)
        pcall(function() UI.sliders.uiScale.Set(100) end)
        pcall(function() UI.sliders.hopMax.Set(8) end)
        pcall(function() UI.sliders.volume.Set(40) end)
        Cfg.font = "Clean"
        Theme.Font = fontPreset("Clean").font
        pcall(function() UI.sliders.textBoost.Set(1) end)
        refreshFontButtons()
        applyTextStyle(true)
        pcall(function() UI.toggles.hud.Set(false, true) end)
        pcall(function() UI.toggles.toasts.Set(true, true) end)
        for action, name in pairs(DEFAULT_KEYS) do Cfg.keys[action] = name end
        Rebind.action = nil
        Rebind.refresh()
        applyTheme("Neon")
        refreshSwatches()
        Cfg.panelW, Cfg.panelH = PANEL_SIZE.X.Offset, PANEL_SIZE.Y.Offset
        Cfg.posX, Cfg.posY = 0, 0
        PanelSize = PANEL_SIZE
        if not Runtime.minimized then
            TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Size = PANEL_SIZE, Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
        end
        scheduleSave()
        Toast.show("Everything reset to default", Theme.Green)
    end
    createButton(settingsPage, "Reset Everything to Default", Theme.Red,
        "Turns every feature off and restores theme, scale, keybinds and window size. Saved profiles are kept. Click twice to confirm.",
        function()
            if not resetArmed then
                resetArmed = true
                Toast.show("Click again within 3s to confirm reset", Theme.Red, 3)
                task.delay(3, function() resetArmed = false end)
                return
            end
            resetArmed = false
            doReset()
        end)
    createButton(settingsPage, "Lock Now (ask key next run)", Theme.Off,
        "Forgets the saved key verification, so the next run asks for the key again.",
        function()
            Cfg.verifiedAt = nil
            pcall(saveConfig)
            Toast.show("Locked. Key required on next run.", Theme.Cyan)
        end)
    createButton(settingsPage, "Copy Settings JSON", Theme.Green,
        "Copies your current settings to the clipboard (if your executor supports it).",
        function()
            pcall(saveConfig)
            local ok = pcall(function() setclipboard(HttpService:JSONEncode(Cfg)) end)
            Toast.show(ok and "Settings copied to clipboard" or "Clipboard unavailable here",
                ok and Theme.Green or Theme.Red)
        end)
    createInfo(settingsPage,
        "Tips: drag the header to move the panel, drag the bottom-right corner to resize it, and use the search box at the top to filter features across every tab. Everything saves automatically.",
        Theme.Off)

    -- ======================= SEARCH =======================
    local searchBox = create("TextBox", {
        Name = "Search", AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 158, 0.5, 0), Size = UDim2.new(1, -242, 0, 26),
        BackgroundColor3 = Theme.Dark, Text = "", PlaceholderText = "Search / command...",
        PlaceholderColor3 = Color3.fromRGB(130, 130, 130), ClearTextOnFocus = false,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, header)
    addCorner(searchBox, 4)
    addFlatStroke(searchBox, Theme.Off, 1)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 24) }, searchBox)
    local clearBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 20, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Text = "×",
        TextSize = 16, TextColor3 = Theme.Off, Visible = false, AutoButtonColor = false, ZIndex = 8,
    }, searchBox)

    local function applySearch(q)
        q = string.lower(q or "")
        for _, name in ipairs(tabNames) do
            local t = tabs[name]
            local hits = 0
            for _, c in ipairs(t.page.frame:GetChildren()) do
                if c:IsA("GuiObject") then
                    if q == "" then
                        c.Visible = true
                    else
                        local hay = c:GetAttribute("search")
                        local m = hay ~= nil and string.find(hay, q, 1, true) ~= nil
                        c.Visible = m
                        if m then hits += 1 end
                    end
                end
            end
            t.hits = hits
        end
        if q ~= "" and (tabs[currentTab].hits or 0) == 0 then
            for _, name in ipairs(tabNames) do
                if (tabs[name].hits or 0) > 0 then
                    selectTab(name)
                    break
                end
            end
        end
    end
    track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = searchBox.Text ~= ""
        applySearch(searchBox.Text)
    end))
    track(clearBtn.MouseButton1Click:Connect(function() searchBox.Text = "" end))

    -- ======================= RESIZE GRIP =======================
    do
        local grip = create("TextButton", {
            Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 46,
        }, body)
        for _, ln in ipairs({ { 3, 6 }, { 7, 12 }, { 11, 18 } }) do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(18 - ln[1], 18 - ln[1]),
                Size = UDim2.fromOffset(ln[2], 2), Rotation = -45,
                BackgroundColor3 = Theme.Off, BorderSizePixel = 0, ZIndex = 47,
            }, grip)
        end
        local MIN_W, MIN_H, MAX_W, MAX_H = 420, 320, 900, 760
        local resizing, rStart, rSize, rPos = false, nil, nil, nil
        track(grip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                rStart = input.Position
                rSize = Vector2.new(Main.Size.X.Offset, Main.Size.Y.Offset)
                rPos = Main.Position
            end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if not resizing then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local s = math.max(scale.Scale, 0.1)
            local w = math.clamp(rSize.X + (input.Position.X - rStart.X) / s, MIN_W, MAX_W)
            local h = math.clamp(rSize.Y + (input.Position.Y - rStart.Y) / s, MIN_H, MAX_H)
            Main.Size = UDim2.fromOffset(w, h)
            -- keep the top-left corner pinned (panel is center-anchored)
            Main.Position = UDim2.new(rPos.X.Scale, rPos.X.Offset + (w - rSize.X) * s / 2,
                rPos.Y.Scale, rPos.Y.Offset + (h - rSize.Y) * s / 2)
            PanelSize = Main.Size
            Cfg.panelW, Cfg.panelH = math.floor(w), math.floor(h)
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                resizing = false
                snapToPixel(Main)
                refreshHistory()
                scheduleSave()
            end
        end))
        track(grip.MouseEnter:Connect(function() Tooltip.set("Drag to resize"); Tooltip.show(); Tooltip.move() end))
        track(grip.MouseMoved:Connect(Tooltip.move))
        track(grip.MouseLeave:Connect(Tooltip.hide))
    end

    -- ======================= PERSISTENCE =======================
    table.insert(PersistHooks, function()
        if Main and Main.Parent and not Runtime.minimized then
            Cfg.panelW, Cfg.panelH = math.floor(Main.Size.X.Offset), math.floor(Main.Size.Y.Offset)
            Cfg.posX, Cfg.posY = math.floor(Main.Position.X.Offset), math.floor(Main.Position.Y.Offset)
        end
    end)
    task.spawn(function()
        while Runtime.alive do
            task.wait(20)
            if Runtime.alive then pcall(saveConfig) end
        end
    end)
    pcall(function()
        if type(Cfg.posX) == "number" and type(Cfg.posY) == "number" then
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            Main.Position = UDim2.new(0.5, math.clamp(Cfg.posX, -vp.X / 2 + 60, vp.X / 2 - 60),
                0.5, math.clamp(Cfg.posY, -vp.Y / 2 + 40, vp.Y / 2 - 40))
        end
    end)

    -- every label created from now on (toasts, tooltips...) gets the chosen font / size too
    track(ScreenGui.DescendantAdded:Connect(function(d) pcall(styleText, d) end))
    applyTextStyle(true)

    -- initial state of the extra toggles
    UI.toggles.hud.Set(Cfg.hud == true, true)
    UI.toggles.toasts.Set(Cfg.toasts ~= false, true)
    UI.toggles.perGame.Set(Cfg.perGame == true, true)

    applyConfigToUI()
    selectTab("Movement")

    -- ---------- Minimize ----------
    local MINI_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local minToken = 0
    local setMinimized

    local function fadeMini(m, visible, duration)
        pcall(function()
            local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(m, info, {
                BackgroundTransparency = visible and 0 or 1,
                TextTransparency = visible and 0 or 1 }):Play()
            local stroke = m:FindFirstChildOfClass("UIStroke")
            if stroke then
                TweenService:Create(stroke, info, { Transparency = visible and 0 or 1 }):Play()
            end
        end)
    end

    local function createMini(pos)
        local m = create("TextButton", {
            Name = "EkantoMini",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = pos, Size = MINI_SIZE,
            BackgroundColor3 = Theme.Black, BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "E", TextSize = 28, TextTransparency = 1,
            AutoButtonColor = false, ZIndex = 50,
        }, ScreenGui)
        addCorner(m, 8)
        local stroke = addFlatStroke(m, Theme.Cyan, 2)
        stroke.Transparency = 1
        MiniState.frame = m
        MiniState.bag = {}
        makeDraggable(m, m, function() setMinimized(false) end, MiniState.bag, true)
        fadeMini(m, true, 0.2)
        return m
    end

    local function closeMini()
        local m, bag = MiniState.frame, MiniState.bag
        MiniState.frame, MiniState.bag = nil, nil
        if not m then return end
        fadeMini(m, false, 0.15)
        task.delay(0.2, function()
            if bag then
                for _, c in ipairs(bag) do pcall(function() c:Disconnect() end) end
            end
            pcall(function() m:Destroy() end)
        end)
    end

    setMinimized = function(state)
        if Runtime.minimized == state then return end
        Runtime.minimized = state
        minToken += 1
        local myToken = minToken
        Tooltip.hide()
        if state then
            body.Visible = false
            local pos = Main.Position + miniDelta()
            TweenService:Create(Main, MINI_TWEEN, { Size = MINI_SIZE, Position = pos }):Play()
            task.delay(0.3, function()
                if myToken ~= minToken or not Runtime.minimized or not Main.Parent then return end
                Main.Visible = false
                local m = createMini(pos)
                if not mainShown then m.Visible = false end
            end)
        else
            local pos = Main.Position
            if MiniState.frame then pos = MiniState.frame.Position end
            closeMini()
            Main.Position = pos
            Main.Size = MINI_SIZE
            Main.Visible = mainShown
            TweenService:Create(Main, MINI_TWEEN, { Size = PanelSize, Position = pos - miniDelta() }):Play()
            task.delay(0.28, function()
                if myToken == minToken and not Runtime.minimized and body.Parent then
                    body.Visible = true
                end
            end)
        end
    end
    track(minBtn.MouseButton1Click:Connect(function() pcall(setMinimized, true) end))

    -- ---------- Window toggle ----------
    local toggleToken = 0
    local function setWindowVisible(visible)
        mainShown = visible
        toggleToken += 1
        local myToken = toggleToken
        Tooltip.hide()
        if Runtime.minimized then
            if MiniState.frame then MiniState.frame.Visible = visible end
            return
        end
        if visible then
            Main.Visible = true
            scale.Scale = ENTRY_START_SCALE * userScale()
            TweenService:Create(scale, ENTRY_INFO, { Scale = userScale() }):Play()
        else
            local tw = TweenService:Create(scale,
                TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Scale = ENTRY_START_SCALE * userScale() })
            tw.Completed:Connect(function()
                if myToken == toggleToken and not mainShown and Main and Main.Parent then
                    Main.Visible = false
                end
            end)
            tw:Play()
        end
    end

    track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local code = input.KeyCode
        -- rebinding mode swallows the next key
        if Rebind.action then
            Rebind.capture(code)
            return
        end
        local typing = UserInputService:GetFocusedTextBox() ~= nil
        if typing and not Rebind.safeWhileTyping(code) then return end
        if code == Rebind.codeOf("toggleUI") then
            pcall(function()
                if Main and Main.Parent then setWindowVisible(not mainShown) end
            end)
            return
        end
        if gameProcessed or typing then return end
        if code == Rebind.codeOf("minimize") then
            if mainShown then pcall(setMinimized, not Runtime.minimized) end
        elseif code == Rebind.codeOf("fly") then
            pcall(function() UI.toggles.fly.Toggle() end)
        elseif code == Rebind.codeOf("noclip") then
            pcall(function() UI.toggles.noclip.Toggle() end)
        elseif code == Rebind.codeOf("search") then
            if mainShown and not Runtime.minimized then
                task.defer(function()
                    searchBox:CaptureFocus()
                    RunService.Heartbeat:Wait()
                    searchBox.Text = "" -- drop the hotkey character that slipped in
                end)
            end
        end
    end))

    -- ======================= COMMAND PALETTE =======================
    local TOGGLE_ALIASES = {
        fly = "fly", god = "godMode", godmode = "godMode", invis = "invisible", invisible = "invisible",
        esp = "esp", aura = "aura", noclip = "noclip", clip = "noclip", afk = "antiAfk", antiafk = "antiAfk",
        fog = "noFog", nofog = "noFog", bright = "fullBright", fullbright = "fullBright",
        opt = "optimizer", optimizer = "optimizer", fps = "optimizer", hud = "hud", info = "espInfo",
    }
    local function runToggle(key, arg)
        local t = UI.toggles[key]
        if not t then return end
        if arg == "on" then t.Set(true, false)
        elseif arg == "off" then t.Set(false, false)
        else t.Toggle() end
    end
    -- returns a function that runs the command, or nil when the text isn't a command
    local function resolveCommand(text)
        local words = {}
        for w in string.gmatch(string.lower(text or ""), "%S+") do table.insert(words, w) end
        local cmd, a1 = words[1], words[2]
        if not cmd then return nil end
        if TOGGLE_ALIASES[cmd] then
            return function() runToggle(TOGGLE_ALIASES[cmd], a1) end
        end
        if cmd == "theme" and a1 then
            for _, pr in ipairs(THEME_PRESETS) do
                if string.lower(pr.name) == a1 then
                    return function()
                        applyTheme(pr.name); refreshSwatches()
                        Toast.show(pr.name .. " theme applied", Theme.Cyan, 1.8)
                    end
                end
            end
            return nil
        elseif cmd == "hop" or cmd == "lowpop" then
            return function() startHop(a1 == "random" and "random" or "low") end
        elseif cmd == "rejoin" or cmd == "rj" then
            return rejoin
        elseif cmd == "jobid" then
            return copyJobId
        elseif cmd == "servers" then
            return function() selectTab("Tools"); ServerBrowser.refresh() end
        elseif (cmd == "speed" or cmd == "flyspeed") and tonumber(a1) then
            return function() UI.sliders[cmd == "speed" and "speed" or "flySpeed"].Set(tonumber(a1)) end
        elseif (cmd == "tp" or cmd == "wp") and tonumber(a1) then
            return function() Waypoints.go(math.floor(tonumber(a1))) end
        elseif cmd == "setwp" and tonumber(a1) then
            return function() Waypoints.set(math.floor(tonumber(a1))) end
        elseif cmd == "profile" and tonumber(a1) then
            return function() ProfileApi.load(math.floor(tonumber(a1))) end
        elseif cmd == "min" or cmd == "minimize" then
            return function() setMinimized(true) end
        elseif cmd == "hide" then
            return function() setWindowVisible(false) end
        elseif cmd == "help" then
            return function()
                Toast.show("Commands: fly god invis esp aura noclip afk fog bright fps hud • theme <name> • hop [random] • rejoin • jobid • servers • speed N • tp N • setwp N • profile N", Theme.Cyan, 6)
            end
        end
        return nil
    end
    track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchBox.TextColor3 = resolveCommand(searchBox.Text) and Theme.Green or Theme.White
    end))
    track(searchBox.FocusLost:Connect(function(enterPressed)
        if not enterPressed then return end
        local fn = resolveCommand(searchBox.Text)
        if fn then
            Sfx.play("click")
            guard("Command", nil, fn)
            searchBox.Text = ""
        end
    end))

    -- ======================= CONTEXT MENU (right-click a card) =======================
    local ctx = { gui = nil }
    local function closeContext()
        if ctx.gui then pcall(function() ctx.gui:Destroy() end); ctx.gui = nil end
    end
    CardContext.open = function(card)
        local now = os.clock()
        if now - CardContext.t < 0.12 then return end
        CardContext.t = now
        closeContext()
        local items = {}
        local rebindAction = card:GetAttribute("rebind")
        if rebindAction then
            table.insert(items, { "Rebind key", function()
                selectTab("Settings")
                Rebind.begin(rebindAction)
                Toast.show("Press a new key for " .. rebindAction .. " (Esc cancels)", Theme.Cyan, 3)
            end })
        end
        for i = 1, 3 do
            table.insert(items, { "Save to profile " .. i, function() ProfileApi.save(i) end })
        end
        table.insert(items, { "Copy description", function()
            local ok = pcall(function() setclipboard(card:GetAttribute("desc") or card.Name) end)
            Toast.show(ok and "Description copied" or "Clipboard unavailable here", ok and Theme.Green or Theme.Red, 1.8)
        end })

        local root = create("TextButton", {
            Name = "ContextMenu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 96,
        }, ScreenGui)
        ctx.gui = root
        track(root.MouseButton1Click:Connect(closeContext))
        track(root.MouseButton2Click:Connect(closeContext))
        local w, h = 176, #items * 28 + 8
        local m = UserInputService:GetMouseLocation()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local menu = create("Frame", {
            Position = UDim2.fromOffset(math.clamp(m.X, 4, vp.X - w - 4), math.clamp(m.Y, 4, vp.Y - h - 4)),
            Size = UDim2.fromOffset(w, h), BackgroundColor3 = Theme.Black, BorderSizePixel = 0, ZIndex = 97,
        }, root)
        addCorner(menu, 6)
        addFlatStroke(menu, Theme.Cyan, 1)
        for i, it in ipairs(items) do
            local b = create("TextButton", {
                Position = UDim2.fromOffset(4, 4 + (i - 1) * 28), Size = UDim2.new(1, -8, 0, 26),
                BackgroundColor3 = Theme.Black, Text = it[1], TextSize = 14, AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 98,
            }, menu)
            b:SetAttribute("NoBoost", true)
            create("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
            addCorner(b, 4)
            track(b.MouseEnter:Connect(function()
                Sfx.play("hover")
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.HoverGrey }):Play()
            end))
            track(b.MouseLeave:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
            end))
            track(b.MouseButton1Click:Connect(function()
                Sfx.play("click")
                closeContext()
                guard(it[1], nil, it[2])
            end))
        end
    end

    -- ---------- Runtime ----------
    registerGameplayLoops()
    track(LocalPlayer.CharacterAdded:Connect(onCharacterAdded))
    task.spawn(function()
        pcall(function() hookCharacter(LocalPlayer.Character) end)
    end)

    Env.startLoop()
    staggerIn(tabs.Movement.page.frame)
    Toast.show("EKANTO v6.0 loaded. " .. Cfg.keys.toggleUI .. " hides, " .. Cfg.keys.minimize
        .. " minimizes, " .. Cfg.keys.fly .. " flies.", Theme.Green, 4)
end

-- ============================================================
-- 10. VERIFICATION GATE (key verified via hashed checkKey)
-- ============================================================
local function buildGate()
    local KeyFrame = create("Frame", {
        Name = "KeyFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(400, 440),
        BackgroundColor3 = Theme.Black,
        BorderSizePixel = 0,
    }, ScreenGui)
    addCorner(KeyFrame, 10)
    addGradientBorder(KeyFrame, 1.5)
    local basePos = KeyFrame.Position
    local gateToken = 0

    create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1, Text = "EKANTO // SECURE SHELL",
        TextSize = 18,
    }, KeyFrame)

    -- scanline sweep
    local scanline = create("Frame", {
        Position = UDim2.new(0, 10, 0, -2),
        Size = UDim2.new(1, -20, 0, 2),
        BackgroundColor3 = Theme.Cyan, BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
    }, KeyFrame)
    addCorner(scanline, 1)

    -- boot log
    local bootHolder = create("Frame", {
        Position = UDim2.new(0, 24, 0, 42),
        Size = UDim2.new(1, -48, 0, 60),
        BackgroundTransparency = 1,
    }, KeyFrame)
    local bootLines = {
        "> EKANTO SECURE SHELL v6.0",
        "> LOADING KERNEL MODULES ... OK",
        "> AUTH REQUIRED // AWAITING KEY",
    }

    -- noise footer
    local noiseLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 24, 1, -8),
        Size = UDim2.new(1, -48, 0, 14),
        BackgroundTransparency = 1, Text = "",
        TextSize = 11, TextColor3 = Color3.fromRGB(90, 90, 90),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, KeyFrame)

    -- input box (manual capture — no TextBox)
    local inputBox = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 116),
        Size = UDim2.new(1, -48, 0, 44),
        BackgroundColor3 = Theme.Black, BorderSizePixel = 0, Visible = false,
    }, KeyFrame)
    addCorner(inputBox, 4)
    local inputStroke = addFlatStroke(inputBox, Theme.White, 1)
    local inputLabel = create("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Text = "",
        TextSize = 20, TextColor3 = Theme.Green,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, inputBox)
    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(44, 16), BackgroundTransparency = 1,
        Text = "KEY", TextSize = 11, TextColor3 = Color3.fromRGB(90, 90, 90),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, inputBox)

    local hintLabel = create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 166), Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = "keyboard or tap the keypad below",
        TextSize = 11, TextColor3 = Color3.fromRGB(110, 110, 110),
        Visible = false,
    }, KeyFrame)
    local statusLabel = create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 184), Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1, Text = "",
        TextSize = 14, TextColor3 = Theme.Cyan,
    }, KeyFrame)
    local verifyBtn = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 366),
        Size = UDim2.new(1, -48, 0, 36),
        BackgroundColor3 = Theme.Black, Text = "VERIFY",
        TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0, Visible = false,
    }, KeyFrame)
    addCorner(verifyBtn, 4)
    addFlatStroke(verifyBtn, Theme.White, 1)
    local vScale = create("UIScale", { Scale = 1 }, verifyBtn)
    track(verifyBtn.MouseEnter:Connect(function()
        TweenService:Create(verifyBtn, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
        TweenService:Create(vScale, HOVER_INFO, { Scale = HOVER_SCALE }):Play()
    end))
    track(verifyBtn.MouseLeave:Connect(function()
        TweenService:Create(verifyBtn, HOVER_INFO, { BackgroundColor3 = Theme.Black }):Play()
        TweenService:Create(vScale, HOVER_INFO, { Scale = 1 }):Play()
    end))

    local buffer = ""
    local MAX_LEN = 12
    local inputReady = false
    local busy = false
    local attempts = 0

    local function renderInput(cursorOn)
        inputLabel.Text = string.rep("*", #buffer) .. (cursorOn and "_" or " ")
    end
    renderInput(true)

    -- shared edit helpers (used by keyboard AND on-screen keypad)
    local function pushChar(c)
        if not inputReady or busy then return end
        if #buffer < MAX_LEN then
            buffer = buffer .. c
            renderInput(true)
        end
    end
    local function backspace()
        if not inputReady or busy then return end
        buffer = string.sub(buffer, 1, -2)
        renderInput(true)
    end
    local function clearAll()
        if not inputReady or busy then return end
        buffer = ""
        renderInput(true)
    end

    -- on-screen keypad (works on mobile / touch / when keyboard events are swallowed)
    local keypad = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 206),
        Size = UDim2.new(1, -48, 0, 154),
        BackgroundTransparency = 1, Visible = false,
    }, KeyFrame)
    create("UIGridLayout", {
        CellSize = UDim2.new(1/3, -4, 0, 34),
        CellPadding = UDim2.fromOffset(6, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, keypad)
    local padKeys = { "1","2","3","4","5","6","7","8","9","CLR","0","DEL" }
    for i, label in ipairs(padKeys) do
        local b = create("TextButton", {
            LayoutOrder = i, Text = label, TextSize = 16,
            BackgroundColor3 = Theme.Dark, AutoButtonColor = false, BorderSizePixel = 0,
            TextColor3 = (label == "CLR" or label == "DEL") and Theme.Cyan or Theme.White,
        }, keypad)
        addCorner(b, 4)
        addFlatStroke(b, Theme.HoverGrey, 1)
        track(b.MouseEnter:Connect(function()
            TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.HoverGrey }):Play()
        end))
        track(b.MouseLeave:Connect(function()
            TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Dark }):Play()
        end))
        track(b.MouseButton1Click:Connect(function()
            if label == "CLR" then clearAll()
            elseif label == "DEL" then backspace()
            else pushChar(label) end
        end))
    end

    -- scanline loop
    task.spawn(function()
        local tok = gateToken
        while KeyFrame and KeyFrame.Parent and gateToken == tok do
            scanline.Position = UDim2.new(0, 10, 0, -2)
            local tw = TweenService:Create(scanline,
                TweenInfo.new(2.2, Enum.EasingStyle.Linear),
                { Position = UDim2.new(0, 10, 1, 0) })
            tw:Play()
            tw.Completed:Wait()
        end
    end)

    -- noise loop
    task.spawn(function()
        local tok = gateToken
        while KeyFrame and KeyFrame.Parent and gateToken == tok do
            local hex = ""
            for _ = 1, 8 do
                local r = math.random(1, 16); hex = hex .. string.sub("0123456789ABCDEF", r, r)
            end
            noiseLabel.Text = "0x" .. hex .. "  //  MEM " .. math.random(34, 62) .. "%  //  NET OK"
            task.wait(0.12)
        end
    end)

    -- cursor blink
    task.spawn(function()
        local tok = gateToken
        local on = true
        while KeyFrame and KeyFrame.Parent and gateToken == tok do
            if inputReady and not busy then renderInput(on) end
            on = not on
            task.wait(0.4)
        end
    end)

    -- boot typewriter
    task.spawn(function()
        task.wait(0.4)
        for i, line in ipairs(bootLines) do
            if not (KeyFrame and KeyFrame.Parent) then return end
            local lbl = create("TextLabel", {
                Position = UDim2.new(0, 0, 0, (i - 1) * 20),
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1, Text = "",
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = (i == #bootLines) and Theme.Cyan or Color3.fromRGB(170, 170, 170),
            }, bootHolder)
            for j = 1, #line do
                if not lbl.Parent then return end
                lbl.Text = string.sub(line, 1, j)
                task.wait(0.018)
            end
            task.wait(0.15)
        end
        if KeyFrame and KeyFrame.Parent then
            inputReady = true
            inputBox.Visible = true
            hintLabel.Visible = true
            verifyBtn.Visible = true
            keypad.Visible = true
            statusLabel.Text = "AWAITING KEY..."
        end
    end)

    local function scramble(label, finalText, duration)
        local chars = "ABCDEF0123456789#$%&@!?"
        local steps = math.max(1, math.floor(duration / 0.03))
        for i = 1, steps do
            if not (label and label.Parent) then return end
            local n = math.floor(#finalText * (i / steps))
            local s = string.sub(finalText, 1, n)
            for _ = n + 1, #finalText do
                s = s .. string.sub(chars, math.random(1, #chars), math.random(1, #chars))
            end
            label.Text = s
            task.wait(0.03)
        end
        if label and label.Parent then label.Text = finalText end
    end

    local function fadeOutAndDestroy(root, duration)
        gateToken += 1
        local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local function fade(inst)
            pcall(function()
                if inst:IsA("GuiObject") then
                    TweenService:Create(inst, info, { BackgroundTransparency = 1 }):Play()
                end
                if TEXT_CLASSES[inst.ClassName] then
                    TweenService:Create(inst, info, { TextTransparency = 1 }):Play()
                end
                if inst:IsA("UIStroke") then
                    TweenService:Create(inst, info, { Transparency = 1 }):Play()
                end
            end)
        end
        fade(root)
        for _, d in ipairs(root:GetDescendants()) do fade(d) end
        task.wait(duration + 0.05)
        pcall(function() root:Destroy() end)
    end

    local function attemptVerify()
        if busy or not Runtime.alive then return end
        busy = true
        if checkKey(buffer) then
            statusLabel.TextColor3 = Theme.Green
            task.spawn(function()
                pcall(scramble, statusLabel, "ACCESS GRANTED // WELCOME, OPERATOR", 0.7)
                TweenService:Create(inputStroke, TweenInfo.new(0.3), { Color = Theme.Green }):Play()
                Cfg.verifiedAt = os.time()
                pcall(saveConfig)
                task.wait(1.0)
                pcall(function() fadeOutAndDestroy(KeyFrame, 0.5) end)
                pcall(buildMain)
            end)
        else
            attempts += 1
            statusLabel.TextColor3 = Theme.Red
            statusLabel.Text = "ACCESS DENIED // INVALID KEY [" .. attempts .. "]"
            TweenService:Create(inputStroke, TweenInfo.new(0.1), { Color = Theme.Red }):Play()
            task.spawn(function()
                pcall(function()
                    for i = 1, 12 do
                        if not (KeyFrame and KeyFrame.Parent) then break end
                        local amp = math.max(1, math.floor(7 - i * 0.5))
                        KeyFrame.Position = UDim2.new(basePos.X.Scale, math.random(-amp, amp),
                            basePos.Y.Scale, math.random(-amp, amp))
                        task.wait(0.03)
                    end
                    if KeyFrame and KeyFrame.Parent then KeyFrame.Position = basePos end
                    TweenService:Create(inputStroke, TweenInfo.new(0.4), { Color = Theme.White }):Play()
                end)
                buffer = ""
                pcall(renderInput, true)
                task.wait(0.3)
                busy = false
            end)
        end
    end

    track(verifyBtn.MouseButton1Click:Connect(attemptVerify))

    -- manual keyboard capture (dots, no TextBox)
    track(UserInputService.InputBegan:Connect(function(input)
        if not (KeyFrame and KeyFrame.Parent) or not inputReady or busy then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local kc, v = input.KeyCode, input.KeyCode.Value
        if kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter then
            task.spawn(attemptVerify)
        elseif kc == Enum.KeyCode.BackSpace then
            backspace()
        elseif kc == Enum.KeyCode.Escape then
            clearAll()
        else
            local c = nil
            if v >= Enum.KeyCode.Zero.Value and v <= Enum.KeyCode.Nine.Value then
                c = tostring(v - Enum.KeyCode.Zero.Value)
            else
                pcall(function()
                    if v >= Enum.KeyCode.KeypadZero.Value and v <= Enum.KeyCode.KeypadNine.Value then
                        c = tostring(v - Enum.KeyCode.KeypadZero.Value)
                    end
                end)
            end
            if not c and v >= Enum.KeyCode.A.Value and v <= Enum.KeyCode.Z.Value then
                c = string.char(65 + (v - Enum.KeyCode.A.Value))
            end
            if c then pushChar(c) end
        end
    end))

    local kScale = create("UIScale", { Scale = ENTRY_START_SCALE }, KeyFrame)
    TweenService:Create(kScale, ENTRY_INFO, { Scale = 1 }):Play()
end

-- ============================================================
-- 11. BOOT
-- ============================================================
pcall(function()
    local old = getGuiParent():FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

do
    local okLoad, hadFile = pcall(loadConfig)
    if not (okLoad and hadFile) and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        Cfg.textBoost = 2 -- first run on a touch device: start with bigger text
    end
    pcall(setThemeColors, Cfg.theme)
    Theme.Font = fontPreset(Cfg.font).font
end

ScreenGui = create("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
})
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
end)
ScreenGui.Parent = getGuiParent()

track(ScreenGui.Destroying:Connect(fullCleanup))
Toast.init(ScreenGui)
Tooltip.init(ScreenGui)
Sfx.init(ScreenGui)

-- visuals on the ONE central Heartbeat: gradient rotation, count-ups, proximity border, theme tween
do
    local t = 0
    Loop.register("Visuals", function(dt)
        t += dt
        local speedMul = 1
        if Main and Main.Visible then
            pcall(function()
                local m = UserInputService:GetMouseLocation()
                local center = Main.AbsolutePosition + Main.AbsoluteSize * 0.5
                local d = (m - center).Magnitude
                speedMul = 1 + math.clamp(1 - d / 600, 0, 1) * 2.5
            end)
        end
        local gradT = t * 90 * speedMul
        for i = #animatedGradients, 1, -1 do
            local g = animatedGradients[i]
            if g and g.Parent then
                g.Rotation = gradT % 360
            else
                table.remove(animatedGradients, i)
            end
        end
        for _, step in pairs(countups) do
            pcall(step, dt)
        end
    end, { keep = true })
    Loop.register("Theme tween", ThemeFx.step, { keep = true })
    Loop.start()
end

do
    local age = type(Cfg.verifiedAt) == "number" and (os.time() - Cfg.verifiedAt) or math.huge
    if age >= 0 and age < KEY_REMEMBER_SECONDS then
        -- key was entered less than an hour ago: go straight to the panel
        if not pcall(buildMain) then buildGate() end
    else
        buildGate()
    end
end
