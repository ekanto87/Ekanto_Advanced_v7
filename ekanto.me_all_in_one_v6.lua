--[[
    EKANTO V2.3 "AURORA"  —  PREMIUM UI BUILD + MOVEMENT HARDENING
    + ADVANCED COMBAT (team check, fov circle, hitbox, prediction)
    + FREECAM / AUTOCLICK / PLAYER LIST / WORLD CONTROLS
    + GATE PREMIUM ANIMATED BACKDROP
    + fly: E/Q/Shift vertical removed (Space = up only)
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
local KEY_LEN, KEY_SALT, KEY_MASK, KEY_HASH = 4, 13, 0x5A5A5A5A, 1580920994
local function checkKey(input)
    if type(input) ~= "string" or #input ~= KEY_LEN then return false end
    local h = 0
    for i = 1, #input do
        h = (h * 257 + string.byte(input, i) + KEY_SALT) % 1000000007
    end
    return bit32.bxor(h, KEY_MASK) == KEY_HASH
end
local KEY_REMEMBER_SECONDS = 3600
local GUI_NAME = "EkantoCyberPanel"
local CONFIG_FILE = "EkantoConfig.json"
local GAME_CONFIG_FILE = "EkantoConfig_" .. tostring(game.PlaceId) .. ".json"
local CONFIG_VERSION = 6
local INSTAGRAM_URL = "https://instagram.com"

local Theme = {
    Bg        = Color3.fromRGB(15, 16, 22),
    Bg2       = Color3.fromRGB(23, 24, 33),
    Surface   = Color3.fromRGB(33, 35, 46),
    Surface2  = Color3.fromRGB(45, 47, 62),
    Hairline  = Color3.fromRGB(68, 71, 92),
    Text      = Color3.fromRGB(246, 248, 253),
    TextDim   = Color3.fromRGB(178, 182, 200),
    TextFaint = Color3.fromRGB(126, 130, 150),
    Accent    = Color3.fromRGB(140, 110, 255),
    Accent2   = Color3.fromRGB(0, 216, 255),
    OnAccent  = Color3.fromRGB(20, 16, 44),
    Green     = Color3.fromRGB(80, 230, 150),
    Red       = Color3.fromRGB(255, 84, 108),
    Amber     = Color3.fromRGB(255, 190, 80),
    Black     = Color3.fromRGB(13, 14, 18),
    Dark      = Color3.fromRGB(26, 27, 36),
    White     = Color3.fromRGB(246, 248, 253),
    Cyan      = Color3.fromRGB(140, 110, 255),
    Track     = Color3.fromRGB(54, 57, 74),
    Off       = Color3.fromRGB(134, 138, 158),
    HoverGrey = Color3.fromRGB(50, 52, 66),
    SubText   = Color3.fromRGB(190, 194, 210),
    Font = Enum.Font.GothamMedium,
}

local THEME_PRESETS = {
    { name = "Aurora",  c1 = Color3.fromRGB(140, 110, 255), c2 = Color3.fromRGB(0, 216, 255),  dark = Color3.fromRGB(40, 28, 78) },
    { name = "Sunset",  c1 = Color3.fromRGB(255, 120, 90),  c2 = Color3.fromRGB(255, 84, 168), dark = Color3.fromRGB(74, 28, 34) },
    { name = "Emerald", c1 = Color3.fromRGB(58, 224, 150),  c2 = Color3.fromRGB(0, 200, 196),  dark = Color3.fromRGB(16, 62, 48) },
    { name = "Royal",   c1 = Color3.fromRGB(122, 116, 255), c2 = Color3.fromRGB(224, 92, 255), dark = Color3.fromRGB(38, 26, 84) },
    { name = "Gold",    c1 = Color3.fromRGB(255, 190, 74),  c2 = Color3.fromRGB(255, 140, 66), dark = Color3.fromRGB(74, 50, 14) },
    { name = "Mono",    c1 = Color3.fromRGB(230, 232, 242), c2 = Color3.fromRGB(150, 162, 205), dark = Color3.fromRGB(46, 48, 60) },
}
Theme.OnDark = THEME_PRESETS[1].dark

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

local function themeMap(c)
    for _, p in ipairs(THEME_PRESETS) do
        if c == p.c1 then return Theme.Accent
        elseif c == p.c2 then return Theme.Accent2
        elseif c == p.dark then return Theme.OnAccent end
    end
    return nil
end

local function setThemeColors(name)
    for _, p in ipairs(THEME_PRESETS) do
        if p.name == name then
            Theme.Accent, Theme.Accent2, Theme.OnAccent = p.c1, p.c2, p.dark
            Theme.Cyan, Theme.Green, Theme.OnDark = p.c1, p.c2, p.dark
            return true
        end
    end
    return false
end

local HOVER_SCALE = 1
local HOVER_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local ENTRY_START_SCALE = 0.97
local ENTRY_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local PANEL_SIZE = UDim2.fromOffset(760, 470)
local MINI_SIZE = UDim2.fromOffset(54, 54)
local PanelSize = PANEL_SIZE

local SIDEBAR_W = 150
local PANEL_RADIUS = 16

local SPEED_MIN, SPEED_MAX = 16, 500
local SPEED_BRAKE_DEFAULT = 22
local SWEEP_SUBSTEPS = 14

local FLY_MIN, FLY_MAX, FLY_SMOOTHING = 10, 300, 14
local DEFAULT_WALKSPEED = 16

local MICRO_MIN, MICRO_MAX = 5, 50
local SLEEP_PERIOD = 14

local AURA_RADIUS_DEFAULT = 20
local AURA_PUSH, AURA_LIFT = 300, 120
local AURA_COOLDOWN, AURA_INTERVAL, AURA_SWING_INTERVAL = 0.25, 0.05, 0.12

local TOOLTIP_MAX_W = 250
local TOAST_TEXT_W = 280

local WAYPOINT_SLOTS = 8
local SPARK_SAMPLES = 60

local FREECAM_MIN, FREECAM_MAX = 10, 400

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
    "noclip", "antiAfk", "espInfo", "espUsername", "espBox", "aimLock", "aimHead", "aimNpc", "aimFire",
    "aimPredict", "netSleep", "speedLegacy", "smartHop", "auraPlayers", "fallRescue",
    "teamCheck", "fovCircle", "hitbox", "autoClick", "freecam", "autoJump", "antiFling" }
local PASSIVE_RESTORE = { godMode = true, invisible = true, esp = true,
    optimizer = true, noFog = true, fullBright = true, antiAfk = true, espInfo = true,
    espUsername = true, espBox = true, aimLock = true, aimHead = true, aimNpc = true, aimFire = true,
    netSleep = true, smartHop = true, auraPlayers = true, fallRescue = true,
    teamCheck = true, fovCircle = true, antiFling = true }

local DEFAULT_CONFIG = {
    speed = SPEED_MIN, flySpeed = 50,
    fly = false, godMode = false, invisible = false, esp = false,
    aura = false, optimizer = false, noFog = false, fullBright = false,
    noclip = false, antiAfk = false, espInfo = true,
    espUsername = false, espBox = false, espDistance = 0,
    aimLock = false, aimFov = 25, aimSmooth = 8, aimHead = true, aimNpc = false, aimFire = false,
    aimRange = 150, aimPredict = false,
    teamCheck = false, fovCircle = true,
    hitbox = false, hitboxScale = 2,
    autoClick = false, autoClickCps = 10,
    freecam = false, freecamSpeed = 60,
    autoJump = false, jumpPower = 0,
    antiFling = true,
    timeOfDay = 0, camFov = 0, gravity = 0,
    auraRadius = AURA_RADIUS_DEFAULT,
    microStep = 20, netSleep = true, speedLegacy = false, smartHop = true,
    auraPlayers = false,
    flySpoof = 100,
    speedBrake = SPEED_BRAKE_DEFAULT,
    fallRescue = true,
    version = CONFIG_VERSION, volume = 40, perGame = false, waypoints = {}, recentGames = {},
    theme = "Aurora", uiScale = 100, toasts = true, hud = false, hopMax = 8,
    font = "Clean", textBoost = 1,
    renderLevel = 0, fpsCap = 0, animCap = 0, viewDist = 0,
    liteUI = false, perfGuard = false, guardFps = 30,
    panelW = PANEL_SIZE.X.Offset, panelH = PANEL_SIZE.Y.Offset,
    keys = { toggleUI = "RightControl", minimize = "M", fly = "F", noclip = "N", search = "Backquote",
        aimLock = "LeftAlt", freecam = "V" },
    profiles = {},
}
local DEFAULT_KEYS = { toggleUI = "RightControl", minimize = "M", fly = "F", noclip = "N", search = "Backquote",
    aimLock = "LeftAlt", freecam = "V" }
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

local NotifLog = { entries = {}, listeners = {} }
local Toast = { layer = nil, counter = 0 }

local Loop = { handlers = {}, conn = nil }
local Errors = { active = false, last = {} }

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
        inst.TextColor3 = Theme.Text
    end
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Theme.Hairline, Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function addGradient(parent, c1, c2, rotation)
    return create("UIGradient", {
        Color = ColorSequence.new(c1 or Theme.Accent, c2 or Theme.Accent2),
        Rotation = rotation or 90,
    }, parent)
end

local function neonGradient()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.5, Theme.Accent2),
        ColorSequenceKeypoint.new(1, Theme.Accent),
    })
end

local function addGradientBorder(parent, thickness)
    local stroke = create("UIStroke", {
        Color = Theme.White, Thickness = thickness or 1.2,
        Transparency = 0.15,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
    table.insert(animatedGradients, create("UIGradient", { Color = neonGradient() }, stroke))
    return stroke
end

local function addPanelShadow(main)
    local parts = {}
    for _, s in ipairs({
        { grow = 3,  off = 6,  t = 0.86 },
        { grow = 8,  off = 12, t = 0.92 },
        { grow = 16, off = 20, t = 0.96 },
    }) do
        local f = create("Frame", {
            ZIndex = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, s.off),
            Size = UDim2.new(1, s.grow * 2, 1, s.grow * 2),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = s.t, BorderSizePixel = 0,
        }, main)
        addCorner(f, PANEL_RADIUS + s.grow)
        table.insert(parts, { f = f, base = s.t })
    end
    local glow = create("Frame", {
        ZIndex = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 2),
        Size = UDim2.new(1, 26, 1, 26),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
    }, main)
    addCorner(glow, PANEL_RADIUS + 13)
    table.insert(parts, { f = glow, base = 0.93 })
    return parts
end

local function themeRole(c)
    for _, p in ipairs(THEME_PRESETS) do
        if c == p.c1 then return "Accent"
        elseif c == p.c2 then return "Accent2"
        elseif c == p.dark then return "OnAccent" end
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
    ThemeFx.apply(1 - (1 - a) ^ 3)
    if a >= 1 then
        ThemeFx.items = nil
        task.delay(0.35, function()
            if Runtime.alive and not ThemeFx.items then ThemeFx.settle() end
        end)
    end
end

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

local function ripple(parent, accent)
    pcall(function()
        local m = UserInputService:GetMouseLocation()
        local rel = m - parent.AbsolutePosition
        local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(rel.X, rel.Y),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = (accent and (themeMap(accent) or accent)) or Theme.Accent,
            BackgroundTransparency = 0.72,
            BorderSizePixel = 0, Active = false, ZIndex = 30,
        }, parent)
        addCorner(ring, 999)
        TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
        }):Play()
        task.delay(0.55, function() pcall(function() ring:Destroy() end) end)
    end)
end

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

-- ---------- team check helper ----------
local function isFriendly(char)
    if not Cfg.teamCheck then return false end
    if not char then return false end
    local plr = Players:GetPlayerFromCharacter(char)
    if not plr then return false end
    local me, them = LocalPlayer.Team, plr.Team
    if not me or not them then return false end
    return me == them
end

-- ============================================================
-- 5. CONFIG IO
-- ============================================================
local PersistHooks = {}

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
    if pcall(function() writefile(CONFIG_FILE, blob) end) then okAny = true end
    if Cfg.perGame then
        if pcall(function() writefile(GAME_CONFIG_FILE, blob) end) then okAny = true end
    end
    return okAny
end

local function migrateConfig(data)
    local v = type(data.version) == "number" and data.version or 1
    if v < 2 then
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
    if v < 3 then
        if data.auraPlayers == nil then data.auraPlayers = false end
        v = 3
    end
    if v < 4 then
        data.flySpoof = 100
        v = 4
    end
    if v < 5 then
        data.speedBrake = SPEED_BRAKE_DEFAULT
        data.fallRescue = true
        if type(data.speed) == "number" then
            data.speed = math.clamp(data.speed, SPEED_MIN, SPEED_MAX)
        end
        v = 5
    end
    if v < 6 then
        data.teamCheck = data.teamCheck == true
        data.fovCircle = data.fovCircle ~= false
        data.hitbox = data.hitbox == true
        data.hitboxScale = 2
        data.autoClick = false
        data.autoClickCps = 10
        data.aimPredict = false
        data.freecam = false
        data.freecamSpeed = 60
        data.autoJump = false
        data.jumpPower = 0
        data.antiFling = true
        data.espBox = false
        data.espDistance = 0
        data.timeOfDay = 0
        data.camFov = 0
        data.gravity = 0
        data.auraRadius = AURA_RADIUS_DEFAULT
        if type(data.keys) == "table" then data.keys.freecam = data.keys.freecam or DEFAULT_KEYS.freecam end
        v = 6
    end
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
    if type(data.freecamSpeed) == "number" then
        Cfg.freecamSpeed = math.clamp(math.floor(data.freecamSpeed + 0.5), FREECAM_MIN, FREECAM_MAX)
    end
    if type(data.speedBrake) == "number" then
        Cfg.speedBrake = math.clamp(math.floor(data.speedBrake + 0.5), 5, 60)
    end
    for _, k in ipairs(TOGGLE_KEYS) do
        if type(data[k]) == "boolean" then Cfg[k] = data[k] end
    end
    if type(data.auraRadius) == "number" then Cfg.auraRadius = math.clamp(math.floor(data.auraRadius + 0.5), 5, 60) end
    if type(data.hitboxScale) == "number" then Cfg.hitboxScale = math.clamp(data.hitboxScale, 1, 6) end
    if type(data.autoClickCps) == "number" then Cfg.autoClickCps = math.clamp(math.floor(data.autoClickCps + 0.5), 1, 60) end
    if type(data.espDistance) == "number" then Cfg.espDistance = math.clamp(math.floor(data.espDistance + 0.5), 0, 2000) end
    if type(data.jumpPower) == "number" then Cfg.jumpPower = math.clamp(math.floor(data.jumpPower + 0.5), 0, 500) end
    if type(data.timeOfDay) == "number" then Cfg.timeOfDay = math.clamp(data.timeOfDay, 0, 24) end
    if type(data.camFov) == "number" then Cfg.camFov = math.clamp(math.floor(data.camFov + 0.5), 0, 130) end
    if type(data.gravity) == "number" then Cfg.gravity = math.clamp(math.floor(data.gravity + 0.5), 0, 400) end
    if type(data.theme) == "string" then
        for _, pr in ipairs(THEME_PRESETS) do
            if pr.name == data.theme then Cfg.theme = pr.name end
        end
        if data.theme == "Neon" then Cfg.theme = "Aurora" end
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
    if type(data.renderLevel) == "number" then Cfg.renderLevel = math.clamp(math.floor(data.renderLevel + 0.5), 0, 10) end
    if type(data.fpsCap) == "number" then Cfg.fpsCap = math.clamp(math.floor(data.fpsCap + 0.5), 0, 240) end
    if type(data.animCap) == "number" then Cfg.animCap = math.clamp(math.floor(data.animCap + 0.5), 0, 500) end
    if type(data.viewDist) == "number" then Cfg.viewDist = math.clamp(math.floor(data.viewDist + 0.5), 0, 5000) end
    if type(data.liteUI) == "boolean" then Cfg.liteUI = data.liteUI end
    if type(data.perfGuard) == "boolean" then Cfg.perfGuard = data.perfGuard end
    if type(data.guardFps) == "number" then Cfg.guardFps = math.clamp(math.floor(data.guardFps + 0.5), 15, 60) end
    if type(data.aimFov) == "number" then Cfg.aimFov = math.clamp(math.floor(data.aimFov + 0.5), 5, 90) end
    if type(data.aimSmooth) == "number" then Cfg.aimSmooth = math.clamp(math.floor(data.aimSmooth + 0.5), 0, 30) end
    if type(data.aimRange) == "number" then Cfg.aimRange = math.clamp(math.floor(data.aimRange + 0.5), 10, 500) end
    if type(data.microStep) == "number" then Cfg.microStep = math.clamp(math.floor(data.microStep + 0.5), MICRO_MIN, MICRO_MAX) end
    if type(data.flySpoof) == "number" then Cfg.flySpoof = math.clamp(math.floor(data.flySpoof + 0.5), 0, 100) end
    if type(data.recentGames) == "table" then
        local clean = {}
        for _, e in ipairs(data.recentGames) do
            if type(e) == "table" and type(e.id) == "number" and type(e.name) == "string" then
                table.insert(clean, { id = e.id, name = string.sub(e.name, 1, 60), t = type(e.t) == "number" and e.t or 0 })
                if #clean >= 25 then break end
            end
        end
        Cfg.recentGames = clean
    end
    if type(data.hopMax) == "number" then Cfg.hopMax = math.clamp(math.floor(data.hopMax + 0.5), 1, 30) end
    if type(data.panelW) == "number" then Cfg.panelW = math.clamp(math.floor(data.panelW), 680, 1000) end
    if type(data.panelH) == "number" then Cfg.panelH = math.clamp(math.floor(data.panelH), 380, 800) end
    if type(data.posX) == "number" and type(data.posY) == "number" then
        Cfg.posX, Cfg.posY = data.posX, data.posY
    end
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
    if Cfg.perGame then
        local gdata = readCfgFile(GAME_CONFIG_FILE)
        if gdata then
            local keepVerified, keepPerGame, keepRecent = Cfg.verifiedAt, Cfg.perGame, Cfg.recentGames
            applyConfigData(gdata)
            Cfg.verifiedAt, Cfg.perGame = keepVerified or Cfg.verifiedAt, keepPerGame
            Cfg.recentGames = keepRecent
        end
    end
    if wasPlain then task.defer(function() pcall(saveConfig) end) end
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

local function applyTheme(name)
    if not setThemeColors(name) then return end
    Cfg.theme = name
    if ScreenGui then
        ThemeFx.finish()
        local items = ThemeFx.collect()
        local roles = { Accent = Theme.Accent, Accent2 = Theme.Accent2, OnAccent = Theme.OnAccent }
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
local God = {}

function God.revive(hum)
    pcall(function()
        if hum.Health <= 0 then
            hum.Health = hum.MaxHealth
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

function God.step(hum)
    if not Cfg.godMode or not hum then return end
    if hum.Health <= 0 then
        God.revive(hum)
    elseif hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
end

function God.restore() end

-- ---------- 6b. Smart Invisibility ----------
local originalVisual = setmetatable({}, { __mode = "k" })
local originalDisplay = setmetatable({}, { __mode = "k" })

local Invis = {}

function Invis.hide(inst)
    pcall(function()
        if inst:IsA("BasePart") then
            if originalVisual[inst] == nil then
                originalVisual[inst] = { t = inst.Transparency, l = inst.LocalTransparencyModifier, q = inst.CanQuery }
            end
            inst.Transparency = 1
            inst.LocalTransparencyModifier = 1
            inst.CanQuery = false
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
    if hum then
        Invis.setNameTag(hum, true)
        if hum.Health > 0 and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
    end
end

function Invis.restore()
    for inst, data in pairs(originalVisual) do
        pcall(function()
            if inst:IsA("BasePart") then
                inst.Transparency = data.t
                inst.LocalTransparencyModifier = data.l or 0
                inst.CanQuery = data.q ~= false
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
            if inst.LocalTransparencyModifier ~= 1 then inst.LocalTransparencyModifier = 1 end
            if inst.Transparency ~= 1 then inst.Transparency = 1 end
            if inst.CanQuery ~= false then inst.CanQuery = false end
        end
    end
    if hum then
        if hum.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
            Invis.setNameTag(hum, true)
        end
        if hum.Health <= 0 then
            God.revive(hum)
        elseif hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end
end

local descendantConn = nil
local healthConn = nil

local function hookCharacter(char)
    if descendantConn then descendantConn:Disconnect(); descendantConn = nil end
    if healthConn then healthConn:Disconnect(); healthConn = nil end
    if not char then return end
    pcall(function()
        if Cfg.invisible then Invis.applyToCharacter(char) end
        if Cfg.godMode then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then hum.Health = hum.MaxHealth end
        end
        descendantConn = char.DescendantAdded:Connect(function(d)
            pcall(function()
                if Cfg.invisible then Invis.hide(d) end
            end)
        end)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            healthConn = hum.HealthChanged:Connect(function(h)
                pcall(function()
                    if (Cfg.godMode or Cfg.invisible) and h > 0 and h < hum.MaxHealth then
                        hum.Health = hum.MaxHealth
                    elseif (Cfg.godMode or Cfg.invisible) and h <= 0 then
                        God.revive(hum)
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
        RigidityEnabled = false,
        MaxTorque = 90000,
        Responsiveness = 150,
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
end

-- ---------- 6d. Fly ----------
local Fly = { vel = Vector3.zero, phase = 0 }

function Fly.ensure(hrp) end
function Fly.destroyInstances() end

function Fly.reset()
    Fly.vel = Vector3.zero
    Fly.phase = 0
end

function Fly.enable(hrp, hum)
    Fly.reset()
    hum.PlatformStand = true
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
end

function Fly.step(hrp, hum, dt)
    local cam = workspace.CurrentCamera
    if not cam then return end
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
        -- vertical: ONLY Space (E/Q/Shift removed)
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += up end
        if dir.Magnitude > 0.01 then target = dir.Unit * Cfg.flySpeed end
    end

    local alpha = 1 - math.exp(-FLY_SMOOTHING * dt)
    Fly.vel = Fly.vel:Lerp(target, alpha)
    if target.Magnitude < 0.01 and Fly.vel.Magnitude < 0.4 then Fly.vel = Vector3.zero end

    Fly.phase += dt

    local blend = math.clamp((Cfg.flySpoof or 100) / 100, 0, 1)
    local gravityComp = Vector3.new(0, workspace.Gravity * dt, 0)

    local jitter = Vector3.new(
        math.sin(Fly.phase * 6.1) * 0.10,
        math.sin(Fly.phase * 4.7 + 1.3) * 0.10,
        math.cos(Fly.phase * 5.5) * 0.10)

    hrp.AssemblyLinearVelocity = Fly.vel * blend + gravityComp + jitter

    local move = Fly.vel * (1 - blend) * dt

    local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
    local pos = hrp.Position + move
    if flatLook.Magnitude > 0.01 then
        hrp.CFrame = CFrame.lookAt(pos, pos + flatLook.Unit)
    elseif move.Magnitude > 0 then
        local rot = (hrp.CFrame - hrp.Position).Rotation
        hrp.CFrame = CFrame.new(pos) * rot
    end
end

function Fly.disable()
    local carry = Fly.vel
    Fly.reset()
    local _, hum, hrp = getCharacterParts()
    if hum then
        hum.PlatformStand = false
        if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Freefall) end
    end
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        if carry.Magnitude > 0.5 then
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
end

-- ---------- 6d2. Freecam ----------
local Freecam = { active = false, yaw = 0, pitch = 0, pos = Vector3.zero, savedType = nil, savedWalk = nil }
local FREECAM_BIND = "EkantoFreecam"

function Freecam.enable()
    local cam = workspace.CurrentCamera
    if not cam or Freecam.active then return end
    Freecam.active = true
    Freecam.pos = cam.CFrame.Position
    local rx, ry = cam.CFrame:ToEulerAnglesYXZ()
    Freecam.pitch, Freecam.yaw = rx, ry
    Freecam.savedType = cam.CameraType
    cam.CameraType = Enum.CameraType.Scriptable
    local _, hum = getCharacterParts()
    if hum then
        Freecam.savedWalk = hum.WalkSpeed
        hum.WalkSpeed = 0
    end
    pcall(function() RunService:UnbindFromRenderStep(FREECAM_BIND) end)
    RunService:BindToRenderStep(FREECAM_BIND, Enum.RenderPriority.Camera.Value - 1, function(dt)
        pcall(Freecam.step, dt)
    end)
end

function Freecam.step(dt)
    if not Freecam.active then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)

    local delta = UserInputService:GetMouseDelta()
    local sens = 0.0026
    Freecam.yaw -= delta.X * sens
    Freecam.pitch = math.clamp(Freecam.pitch - delta.Y * sens, math.rad(-89), math.rad(89))
    local rot = CFrame.fromEulerAnglesYXZ(Freecam.pitch, Freecam.yaw, 0)

    local move = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        local fwd, right, up = rot.LookVector, rot.RightVector, Vector3.new(0, 1, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= fwd end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= up end
    end
    if move.Magnitude > 0.01 then move = move.Unit * (Cfg.freecamSpeed or 60) * dt end
    Freecam.pos += move
    cam.CFrame = CFrame.new(Freecam.pos) * rot

    local _, hum = getCharacterParts()
    if hum then hum.WalkSpeed = 0 end
end

function Freecam.goto()
    local _, _, hrp = getCharacterParts()
    if hrp then
        hrp.CFrame = CFrame.new(Freecam.pos + Vector3.new(0, 2.5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

function Freecam.disable()
    if not Freecam.active then return end
    Freecam.active = false
    pcall(function() RunService:UnbindFromRenderStep(FREECAM_BIND) end)
    local cam = workspace.CurrentCamera
    if cam and Freecam.savedType then cam.CameraType = Freecam.savedType end
    local _, hum = getCharacterParts()
    if hum and Freecam.savedWalk then hum.WalkSpeed = Freecam.savedWalk end
    Freecam.savedWalk, Freecam.savedType = nil, nil
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
end

-- ============================================================
-- 6e. SPEED
-- ============================================================
local Speed = {
    acc = 0, phase = 0, tick = 0,
    groundOff = 3, lastSafe = nil, rescueAt = 0, attachReady = false,
}

local sweepParams = RaycastParams.new()
sweepParams.FilterType = Enum.RaycastFilterType.Exclude
sweepParams.IgnoreWater = true

function Speed.reset()
    Speed.acc, Speed.phase, Speed.tick = 0, 0, 0
    Speed.lastSafe = nil
    Speed.rescueAt = 0
end

local function speedLegacyStep(hrp, hum, moveDir)
    local dir = moveDir.Unit
    local v = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * Cfg.speed, v.Y, dir.Z * Cfg.speed)
    if hum.WalkSpeed ~= Cfg.speed then hum.WalkSpeed = Cfg.speed end
end

function Speed.calcGroundOff(char, hrp)
    sweepParams.FilterDescendantsInstances = { char }
    local d = workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -16, 0), sweepParams)
    Speed.groundOff = d and math.clamp(hrp.Position.Y - d.Position.Y, 2, 6) or 3
end

function Speed.sweep(char, hrp, dir, dist)
    if dist <= 0.0005 then return end
    sweepParams.FilterDescendantsInstances = { char }

    local base = hrp.Position
    local origin = base + Vector3.new(0, 0.75, 0)
    local hit = workspace:Raycast(origin, dir * (dist + 0.45), sweepParams)

    if hit and hit.Normal.Y < 0.5 then
        local over = workspace:Raycast(hit.Position + Vector3.new(0, 2.9, 0), dir * (dist + 0.9), sweepParams)
        if not over then
            local down = workspace:Raycast(hit.Position + dir * 0.9 + Vector3.new(0, 3.6, 0),
                Vector3.new(0, -9, 0), sweepParams)
            if down and (down.Position.Y - base.Y) < 3.6 then
                local cf = hrp.CFrame
                local targetY = down.Position.Y + Speed.groundOff
                hrp.CFrame = CFrame.new(cf.X + dir.X * 1.0, targetY, cf.Z + dir.Z * 1.0) * (cf - cf.Position)
                return
            end
        end
        local travel = math.max(0, (hit.Position - origin).Magnitude - 0.32)
        local move = math.min(travel, dist)
        hrp.CFrame = hrp.CFrame + dir * move
        local rem = dist - move
        if rem > 0.05 then
            local slide = dir - hit.Normal * dir:Dot(hit.Normal)
            if slide.Magnitude > 0.05 then
                hrp.CFrame = hrp.CFrame + slide.Unit * math.min(rem, dist * 0.7)
            end
        end
        return
    end

    hrp.CFrame = hrp.CFrame + dir * dist
    if hit then
        local down = workspace:Raycast(hrp.Position + Vector3.new(0, 4.5, 0), Vector3.new(0, -10, 0), sweepParams)
        if down then
            local targetY = down.Position.Y + Speed.groundOff
            if math.abs(targetY - hrp.Position.Y) < 4.5 then
                local cf = hrp.CFrame
                hrp.CFrame = CFrame.new(cf.X, targetY, cf.Z) * (cf - cf.Position)
            end
        end
    end
end

function Speed.step(hrp, hum, dt)
    local char = LocalPlayer.Character
    local moveDir = hum.MoveDirection
    local moving = moveDir.Magnitude > 0

    if Cfg.fallRescue then
        if hum.FloorMaterial ~= Enum.Material.Air then
            Speed.lastSafe = hrp.Position
        elseif Speed.lastSafe and hrp.Position.Y < (Speed.lastSafe.Y - 70) then
            if os.clock() - Speed.rescueAt > 1.0 then
                Speed.rescueAt = os.clock()
                hrp.CFrame = CFrame.new(Speed.lastSafe + Vector3.new(0, 3, 0))
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                Speed.acc = 0
            end
        end
    end

    if not moving then
        Speed.acc = 0
        local v = hrp.AssemblyLinearVelocity
        local keep = math.exp(-(Cfg.speedBrake or SPEED_BRAKE_DEFAULT) * dt)
        local nx, nz = v.X * keep, v.Z * keep
        if math.abs(nx) < 0.12 then nx = 0 end
        if math.abs(nz) < 0.12 then nz = 0 end
        hrp.AssemblyLinearVelocity = Vector3.new(nx, v.Y, nz)
        AntiTrip.step(hrp, hum, false, moveDir, dt)
        return
    end

    local dir = moveDir.Unit

    if Cfg.speedLegacy then
        speedLegacyStep(hrp, hum, moveDir)
    else
        local base = (hum.WalkSpeed > 0) and hum.WalkSpeed or DEFAULT_WALKSPEED
        local micro = math.clamp((Cfg.microStep or 20) / 100, MICRO_MIN / 100, MICRO_MAX / 100)

        Speed.acc += math.max(0, Cfg.speed - base) * dt

        local dist = Speed.acc
        Speed.acc = 0
        if dist > 0.0005 then
            local steps = math.clamp(math.ceil(dist / micro), 1, SWEEP_SUBSTEPS)
            local inc = dist / steps
            for _ = 1, steps do
                Speed.sweep(char, hrp, dir, inc)
            end
        end

        Speed.phase += dt
        Speed.tick += 1

        if Cfg.netSleep and Speed.tick % SLEEP_PERIOD ~= 0 then
            local osc = 0.94 + 0.12 * math.sin(Speed.phase * 7.3)
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * base * osc, v.Y, dir.Z * base * osc)
        end
    end

    AntiTrip.step(hrp, hum, true, moveDir, dt)
end

function Speed.exit()
    Speed.reset()
    pcall(function()
        local _, hum = getCharacterParts()
        if hum and Cfg.speedLegacy and hum.WalkSpeed ~= DEFAULT_WALKSPEED then
            hum.WalkSpeed = DEFAULT_WALKSPEED
        end
    end)
    AntiTrip.release()
end

-- ---------- 6e2. Anti-Fling / Anti-Void ----------
local function antiFlingStep()
    if not Cfg.antiFling then return end
    local _, _, hrp = getCharacterParts()
    if not hrp then return end
    local v = hrp.AssemblyLinearVelocity
    if v.Magnitude > 900 then
        hrp.AssemblyLinearVelocity = v.Unit * 180
    end
    if hrp.Position.Y < -500 then
        hrp.CFrame = CFrame.new(hrp.Position.X, 150, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- ---------- 6e3. Jump / Auto-jump ----------
local function jumpStep()
    local _, hum, hrp = getCharacterParts()
    if not hum or not hrp then return end
    if Cfg.jumpPower and Cfg.jumpPower > 0 then
        pcall(function()
            hum.UseJumpPower = true
            if hum.JumpPower ~= Cfg.jumpPower then hum.JumpPower = Cfg.jumpPower end
        end)
    end
    if Cfg.autoJump then
        if hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0.1 then
            hum.Jump = true
        end
    end
end

-- ---------- 6e4. Auto Clicker ----------
local AutoClick = { acc = 0 }

local function autoClickStep(dt)
    if not Cfg.autoClick then return end
    local cps = math.clamp(Cfg.autoClickCps or 10, 1, 60)
    local interval = 1 / cps
    AutoClick.acc += dt
    if AutoClick.acc < interval then return end
    AutoClick.acc = AutoClick.acc % interval
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
end

-- ---------- 6f. Melee Aura ----------
local Aura = { token = 0, cooldowns = setmetatable({}, { __mode = "k" }), lastSwing = 0 }

local auraParams = OverlapParams.new()
auraParams.FilterType = Enum.RaycastFilterType.Exclude
auraParams.MaxParts = 300

local function findHumanoidModel(part)
    local node = part
    while node and node ~= workspace do
        if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return node end
        node = node.Parent
    end
    return nil
end

local function swingTool(char)
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    return pcall(function() tool:Activate() end)
end

function Aura.scan()
    if not Cfg.aura then return end
    local char, hum, hrp = getCharacterParts()
    if not (char and hum and hrp) or hum.Health <= 0 then return end

    auraParams.FilterDescendantsInstances = { char }

    local ok, parts = pcall(function()
        return workspace:GetPartBoundsInRadius(hrp.Position, Cfg.auraRadius or AURA_RADIUS_DEFAULT, auraParams)
    end)
    if not ok or not parts then return end

    local handled, now = {}, os.clock()
    local anyTarget = false

    for _, part in ipairs(parts) do
        local model = findHumanoidModel(part)
        if model and model ~= char and not handled[model] then
            handled[model] = true
            local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
            local friendly = isFriendly(model)
            if ((not isPlayer) or Cfg.auraPlayers) and not friendly then
                local targetHum = model:FindFirstChildOfClass("Humanoid")
                local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if targetHum and targetHum.Health > 0 and root and not root.Anchored then
                    anyTarget = true
                    local last = Aura.cooldowns[model]
                    if not last or now - last >= AURA_COOLDOWN then
                        Aura.cooldowns[model] = now
                        local offset = root.Position - hrp.Position
                        local flat = Vector3.new(offset.X, 0, offset.Z)
                        if flat.Magnitude < 0.1 then
                            local look = hrp.CFrame.LookVector
                            flat = Vector3.new(look.X, 0, look.Z)
                        end
                        flat = flat.Unit
                        pcall(function()
                            root.AssemblyLinearVelocity = flat * AURA_PUSH + Vector3.new(0, AURA_LIFT, 0)
                            root.AssemblyAngularVelocity = Vector3.new(
                                math.random(-40, 40), math.random(-40, 40), math.random(-40, 40))
                        end)
                    end
                end
            end
        end
    end

    if anyTarget and now - Aura.lastSwing >= AURA_SWING_INTERVAL then
        Aura.lastSwing = now
        swingTool(char)
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

-- ---------- 6f2. Hitbox Expander ----------
local Hitbox = { orig = setmetatable({}, { __mode = "k" }), handle = nil }
local HITBOX_PARTS = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso" }

function Hitbox.applyToChar(char)
    if not char then return end
    local scale = Cfg.hitboxScale or 2
    for _, name in ipairs(HITBOX_PARTS) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            if Hitbox.orig[p] == nil then Hitbox.orig[p] = p.Size end
            local o = Hitbox.orig[p]
            local want = Vector3.new(o.X * scale, o.Y * scale, o.Z * scale)
            if p.Size ~= want then p.Size = want end
        end
    end
end

function Hitbox.restoreChar(char)
    if not char then return end
    for _, name in ipairs(HITBOX_PARTS) do
        local p = char:FindFirstChild(name)
        if p and Hitbox.orig[p] then
            pcall(function() p.Size = Hitbox.orig[p] end)
            Hitbox.orig[p] = nil
        end
    end
end

function Hitbox.step()
    if not Cfg.hitbox then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then Hitbox.applyToChar(plr.Character) end
    end
end

function Hitbox.start()
    if Hitbox.handle then Loop.remove(Hitbox.handle) end
    Hitbox.handle = Loop.register("Hitbox Expander", Hitbox.step, { interval = 0.4, feature = "hitbox" })
    Hitbox.step()
end

function Hitbox.stop()
    if Hitbox.handle then Loop.remove(Hitbox.handle); Hitbox.handle = nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then Hitbox.restoreChar(plr.Character) end
    end
end

-- ---------- 6g. ESP ----------
local ESP = { folder = nil, arrowLayer = nil, highlights = {}, tags = {}, charConns = {},
    playerAdded = nil, playerRemoving = nil, handle = nil }
local HP_LOW, HP_HIGH = Color3.fromRGB(255, 84, 108), Color3.fromRGB(80, 230, 150)

function ESP.nameOf(player)
    if Cfg.espUsername then return player.Name end
    return player.DisplayName
end

function ESP.colorFor(player)
    if Cfg.teamCheck and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
        return Theme.Green
    end
    return Theme.Red
end

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
        MaxDistance = math.huge,
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
    local nameLbl = lbl(0, 16, 14, ESP.nameOf(player), Theme.White)
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
    local box = create("Frame", {
        Name = "Box", BackgroundTransparency = 1, Visible = false, ZIndex = 44,
        BorderSizePixel = 0,
    }, ESP.folder)
    local boxStroke = addStroke(box, ESP.colorFor(player), 1.5, 0.15)
    ESP.tags[player] = { gui = gui, distL = distL, fill = fill, arrow = arrow, char = char, box = box,
        hum = char:FindFirstChildOfClass("Humanoid"), nameLbl = nameLbl, player = player }
end

function ESP.update()
    local cam = workspace.CurrentCamera
    if not cam or not ESP.folder then return end
    local _, _, myHrp = getCharacterParts()
    local vp = cam.ViewportSize
    local center = vp / 2
    local distLimit = Cfg.espDistance or 0
    for player, t in pairs(ESP.tags) do
        local char = t.char
        local wanted = ESP.nameOf(player)
        if t.nameLbl.Text ~= wanted then t.nameLbl.Text = wanted end
        local root = char and char.Parent and char:FindFirstChild("HumanoidRootPart")
        if not root then
            t.arrow.Visible = false
            if t.box then t.box.Visible = false end
        else
            local from = myHrp and myHrp.Position or cam.CFrame.Position
            local dist = (root.Position - from).Magnitude
            t.distL.Text = math.floor(dist) .. " studs"
            local visible = (distLimit <= 0) or (dist <= distLimit)
            local hum = t.hum
            local frac = (hum and hum.MaxHealth > 0) and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
            t.fill.Size = UDim2.new(frac, 0, 1, 0)
            t.fill.BackgroundColor3 = HP_LOW:Lerp(HP_HIGH, frac)
            t.gui.Enabled = visible and Cfg.espInfo ~= false
            if t.boxStroke then
                local col = ESP.colorFor(player)
                if t.boxStroke.Color ~= col then t.boxStroke.Color = col end
            end

            -- box esp
            if Cfg.espBox and visible and t.box then
                local head = char:FindFirstChild("Head")
                local topPos = head and head.Position or (root.Position + Vector3.new(0, 2, 0))
                local botPos = root.Position - Vector3.new(0, 3, 0)
                local v1, on1 = cam:WorldToViewportPoint(topPos)
                local v2, on2 = cam:WorldToViewportPoint(botPos)
                if on1 and on2 then
                    local bh = math.abs(v2.Y - v1.Y)
                    local bw = bh * 0.62
                    t.box.Size = UDim2.fromOffset(bw, bh)
                    t.box.Position = UDim2.fromOffset(v1.X - bw / 2, math.min(v1.Y, v2.Y))
                    t.box.Visible = true
                else
                    t.box.Visible = false
                end
            elseif t.box then
                t.box.Visible = false
            end

            local v, onScreen = cam:WorldToViewportPoint(root.Position)
            if not visible or Cfg.espInfo == false or (onScreen and v.Z > 0) then
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
                FillColor = ESP.colorFor(player),
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
            Noclip.orig[p] = true
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
        vu:ClickButton2(Vector2.new(0, 0))
    end)
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.05), 0) end
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

-- ---------- 6g4. Aim Lock ----------
local Aim = { bound = false, target = nil, pinned = nil, pinnedPlayer = nil,
    highlight = nil, lastFire = 0, lastPin = 0 }

local function aimRange()
    return Cfg.aimRange or 150
end

local function aimPart(char)
    if not char then return nil end
    local part = Cfg.aimHead and char:FindFirstChild("Head") or nil
    return part or char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function aimPos(part)
    if Cfg.aimPredict then
        local v = part.AssemblyLinearVelocity
        if v.Magnitude > 1 then
            local ping = 0
            pcall(function() ping = LocalPlayer:GetNetworkPing() end)
            return part.Position + v * (ping + 0.05)
        end
    end
    return part.Position
end

local function aimAngle(cam, char)
    local part = aimPart(char)
    if not part then return nil end
    local dir = aimPos(part) - cam.CFrame.Position
    if dir.Magnitude < 0.1 then return nil end
    return math.deg(math.acos(math.clamp(dir.Unit:Dot(cam.CFrame.LookVector), -1, 1))), part
end

local function aimValid(char, maxDist)
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local part = aimPart(char)
    if not part then return false end
    local cam = workspace.CurrentCamera
    if cam and maxDist and (part.Position - cam.CFrame.Position).Magnitude > maxDist then return false end
    return true
end

local function aimCandidates(cam, fov, range)
    local myChar = LocalPlayer.Character
    local origin = cam.CFrame.Position
    local best, bestScore = nil, nil
    local function consider(char)
        if not char or char == myChar or not char.Parent then return end
        if isFriendly(char) then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local part = aimPart(char)
        if not part then return end
        if (part.Position - origin).Magnitude > range then return end
        local ang = aimAngle(cam, char)
        if not ang or ang > fov then return end
        if not bestScore or ang < bestScore then bestScore, best = ang, char end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then consider(plr.Character) end
    end
    if Cfg.aimNpc then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid")
                and Players:GetPlayerFromCharacter(obj) == nil then
                consider(obj)
            end
        end
    end
    return best
end

local function aimResolvePin()
    if aimValid(Aim.pinned, aimRange() * 1.25) then return Aim.pinned end
    local plr = Aim.pinnedPlayer
    if plr and plr.Parent then
        local char = plr.Character
        if aimValid(char, aimRange() * 1.25) then
            Aim.pinned = char
            return char
        end
    end
    if Aim.pinned or Aim.pinnedPlayer then
        Aim.pinned = nil
        if not (plr and plr.Parent) then Aim.pinnedPlayer = nil end
    end
    return nil
end

function Aim.clearPin(silent)
    local had = (Aim.pinned ~= nil) or (Aim.pinnedPlayer ~= nil)
    Aim.pinned, Aim.pinnedPlayer = nil, nil
    if had and not silent then Toast.show("Pin released", Theme.Off, 1.5) end
end

local function aimPickUnderMouse()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local range = aimRange()
    local myChar = LocalPlayer.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = myChar and { myChar } or {}
    local m = UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(m.X, m.Y)
    local hit = workspace:Raycast(ray.Origin, ray.Direction * range, params)
    if hit then
        local node = hit.Instance
        while node and node ~= workspace do
            if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return node end
            node = node.Parent
        end
    end
    local best, bestD = nil, 70
    local function consider(char)
        if not aimValid(char, range) then return end
        local part = aimPart(char)
        local sp, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen or sp.Z <= 0 then return end
        local d = (Vector2.new(sp.X, sp.Y) - m).Magnitude
        if d < bestD then bestD, best = d, char end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then consider(plr.Character) end
    end
    if Cfg.aimNpc then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid")
                and Players:GetPlayerFromCharacter(obj) == nil then
                consider(obj)
            end
        end
    end
    return best
end

function Aim.pinUnderMouse()
    local now = os.clock()
    if now - Aim.lastPin < 0.15 then return end
    Aim.lastPin = now
    if Aim.pinned or Aim.pinnedPlayer then
        Aim.clearPin()
        return
    end
    local char = aimPickUnderMouse()
    if not char then
        Toast.show("No target under the crosshair to pin", Theme.Off, 1.8)
        return
    end
    local plr = Players:GetPlayerFromCharacter(char)
    Aim.pinned, Aim.pinnedPlayer = char, plr
    Aim.target = char
    Toast.show("Target pinned: " .. (plr and plr.DisplayName or char.Name) .. " (middle click to unpin)", Theme.Accent, 2.5)
end

local function aimHighlight(char, pinned)
    if not char then
        if Aim.highlight then pcall(function() Aim.highlight.Adornee = nil end) end
        return
    end
    if not Aim.highlight or not Aim.highlight.Parent then
        Aim.highlight = create("Highlight", {
            Name = "EkantoAimTarget",
            FillColor = Theme.Accent2, FillTransparency = 0.75,
            OutlineColor = Theme.White, OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        }, ScreenGui)
    end
    pcall(function()
        Aim.highlight.FillColor = pinned and Theme.Accent or Theme.Accent2
        Aim.highlight.OutlineColor = pinned and Theme.Accent or Theme.White
    end)
    if Aim.highlight.Adornee ~= char then Aim.highlight.Adornee = char end
end

local function aimStep(dt)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local fov = Cfg.aimFov or 25
    local range = aimRange()
    local target = nil
    local pinned = false

    if Aim.pinned or Aim.pinnedPlayer then
        target = aimResolvePin()
        pinned = target ~= nil
    end

    if not target then
        local keep = false
        if Aim.target and Aim.target.Parent then
            local hum = Aim.target:FindFirstChildOfClass("Humanoid")
            local part = hum and aimPart(Aim.target)
            if hum and hum.Health > 0 and part and not isFriendly(Aim.target) then
                local dist = (part.Position - cam.CFrame.Position).Magnitude
                local ang = aimAngle(cam, Aim.target)
                if dist <= range * 1.15 and ang and ang <= fov * 1.4 then keep = true end
            end
        end
        if keep then target = Aim.target else target = aimCandidates(cam, fov, range) end
    end

    Aim.target = target
    if not target then aimHighlight(nil) return end
    local part = aimPart(target)
    if not part then Aim.target = nil; aimHighlight(nil); return end
    aimHighlight(target, pinned)

    local desired = CFrame.lookAt(cam.CFrame.Position, aimPos(part))
    local smooth = Cfg.aimSmooth or 0
    if smooth <= 0 then
        cam.CFrame = desired
    else
        cam.CFrame = cam.CFrame:Lerp(desired, 1 - math.exp(-smooth * dt))
    end

    if Cfg.aimFire then
        local now = os.clock()
        if now - Aim.lastFire >= 0.08 then
            Aim.lastFire = now
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end
    end
end

local AIM_BIND = "EkantoAimLock"

function Aim.start()
    if Aim.bound then return end
    Aim.bound = true
    pcall(function() RunService:UnbindFromRenderStep(AIM_BIND) end)
    RunService:BindToRenderStep(AIM_BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
        local ok, err = pcall(aimStep, dt)
        if not ok then
            Aim.bound = false
            pcall(function() RunService:UnbindFromRenderStep(AIM_BIND) end)
            Errors.report("Aim Lock", err, "aimLock")
        end
    end)
end

function Aim.stop()
    Aim.bound = false
    pcall(function() RunService:UnbindFromRenderStep(AIM_BIND) end)
    Aim.target = nil
    Aim.clearPin(true)
    aimHighlight(nil)
end

-- ---------- 6g5. FOV circle ----------
local FovCircle = { frame = nil }

function FovCircle.ensure()
    if FovCircle.frame and FovCircle.frame.Parent then return end
    local f = create("Frame", {
        Name = "FovCircle", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(200, 200),
        BackgroundTransparency = 1, Active = false, Visible = false, ZIndex = 40,
    }, ScreenGui)
    addCorner(f, 999)
    local st = addStroke(f, Theme.Accent2, 1.5, 0.25)
    st:SetAttribute("NoTheme", true)
    FovCircle.frame = f
end

function FovCircle.refresh()
    local f = FovCircle.frame
    if not f then return end
    if not (Cfg.fovCircle and Cfg.aimLock) then f.Visible = false return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local halfV = math.rad(math.max(cam.FieldOfView, 1) / 2)
    local r = (vp.Y / 2) * math.tan(math.rad(Cfg.aimFov or 25)) / math.tan(halfV)
    r = math.clamp(r, 10, vp.Y)
    f.Size = UDim2.fromOffset(r * 2, r * 2)
    f.Visible = true
end

-- ---------- 6h. Environment ----------
local Optimizer = {
    saved = setmetatable({}, { __mode = "k" }),
    conn = nil, token = 0, lighting = nil, mesh = nil, terrain = nil,
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
                Optimizer.saved[inst] = { mat = inst.Material, refl = inst.Reflectance, shadow = inst.CastShadow,
                    fid = inst:IsA("MeshPart") and inst.RenderFidelity or nil }
            end
            inst.Material = Enum.Material.SmoothPlastic
            inst.Reflectance = 0
            inst.CastShadow = false
            if inst:IsA("MeshPart") then inst.RenderFidelity = Enum.RenderFidelity.Performance end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if LocalPlayer.Character and inst:IsDescendantOf(LocalPlayer.Character) then return end
            if Optimizer.saved[inst] == nil then Optimizer.saved[inst] = { t = inst.Transparency } end
            inst.Transparency = 1
        elseif inst:IsA("Light") then
            if Optimizer.saved[inst] == nil then Optimizer.saved[inst] = { lightShadows = inst.Shadows } end
            inst.Shadows = false
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
        local r = settings().Rendering
        if Optimizer.mesh == nil then Optimizer.mesh = r.MeshPartDetailLevel end
        r.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    end)
    pcall(function()
        local t = workspace:FindFirstChildOfClass("Terrain")
        if not t then return end
        Optimizer.terrain = Optimizer.terrain or {}
        local saved = Optimizer.terrain
        local function put(prop, value)
            pcall(function()
                if saved[prop] == nil then saved[prop] = t[prop] end
                t[prop] = value
            end)
        end
        put("WaterWaveSize", 0)
        put("WaterReflectance", 0)
        put("Decoration", false)
    end)
    if Optimizer.conn then pcall(function() Optimizer.conn:Disconnect() end) end
    Optimizer.conn = workspace.DescendantAdded:Connect(optimizeInstance)
    task.spawn(function()
        pcall(function()
            for _, d in ipairs(Lighting:GetDescendants()) do optimizeInstance(d) end
            local t0 = os.clock()
            for _, d in ipairs(workspace:GetDescendants()) do
                if not Runtime.alive or Optimizer.token ~= myToken then return end
                optimizeInstance(d)
                if os.clock() - t0 > 0.0025 then task.wait(); t0 = os.clock() end
            end
        end)
    end)
end

function Optimizer.disable()
    Optimizer.token += 1
    if Optimizer.conn then pcall(function() Optimizer.conn:Disconnect() end); Optimizer.conn = nil end
    local t0 = os.clock()
    for inst, data in pairs(Optimizer.saved) do
        pcall(function()
            if data.enabled ~= nil then inst.Enabled = data.enabled
            elseif data.mat ~= nil then
                inst.Material = data.mat
                inst.Reflectance = data.refl
                inst.CastShadow = data.shadow
                if data.fid ~= nil then inst.RenderFidelity = data.fid end
            elseif data.lightShadows ~= nil then inst.Shadows = data.lightShadows
            elseif data.t ~= nil then inst.Transparency = data.t end
        end)
        Optimizer.saved[inst] = nil
        if os.clock() - t0 > 0.0025 then task.wait(); t0 = os.clock() end
    end
    pcall(function()
        if Optimizer.lighting then Lighting.GlobalShadows = Optimizer.lighting.shadows; Optimizer.lighting = nil end
    end)
    pcall(function()
        if Optimizer.mesh ~= nil then
            settings().Rendering.MeshPartDetailLevel = Optimizer.mesh
            Optimizer.mesh = nil
        end
    end)
    pcall(function()
        local t = workspace:FindFirstChildOfClass("Terrain")
        if t and Optimizer.terrain then
            for prop, value in pairs(Optimizer.terrain) do pcall(function() t[prop] = value end) end
        end
        Optimizer.terrain = nil
    end)
end

local Env = { fog = nil, bright = nil, far = nil, viewHandle = nil, time = nil, grav = nil, fov = nil }

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
    end)
end

function Env.setFog(on)
    pcall(function()
        if on then
            if not Env.fog then
                local atmo = getAtmosphere()
                local far = Env.far
                Env.fog = {
                    fogStart = far and far.fogStart or Lighting.FogStart,
                    fogEnd = far and far.fogEnd or Lighting.FogEnd,
                    density = far and far.density or (atmo and atmo.Density),
                    haze = far and far.haze or (atmo and atmo.Haze),
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
                    brightness = Lighting.Brightness,
                }
            end
            assertBright()
        elseif Env.bright then
            Lighting.Ambient = Env.bright.ambient
            Lighting.OutdoorAmbient = Env.bright.outdoor
            Lighting.Brightness = Env.bright.brightness
            Env.bright = nil
        end
    end)
end

function Env.setTime(v)
    pcall(function()
        if v and v > 0 then
            if Env.time == nil then Env.time = Lighting.ClockTime end
            Lighting.ClockTime = v
        elseif Env.time ~= nil then
            Lighting.ClockTime = Env.time
            Env.time = nil
        end
    end)
end

function Env.setGravity(v)
    pcall(function()
        if v and v > 0 then
            if Env.grav == nil then Env.grav = workspace.Gravity end
            workspace.Gravity = v
        elseif Env.grav ~= nil then
            workspace.Gravity = Env.grav
            Env.grav = nil
        end
    end)
end

function Env.setFov(v)
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        if v and v > 0 then
            if Env.fov == nil then Env.fov = cam.FieldOfView end
            cam.FieldOfView = v
        elseif Env.fov ~= nil then
            cam.FieldOfView = Env.fov
            Env.fov = nil
        end
    end)
end

function Env.assertView()
    local far, v = Env.far, Cfg.viewDist or 0
    if not far or v <= 0 then return end
    pcall(function()
        Lighting.FogEnd = math.max(far.fogEnd, v)
        Lighting.FogStart = math.max(far.fogStart, v * 0.6)
        local atmo = getAtmosphere()
        if atmo and far.density then
            local k = math.clamp(1500 / v, 0.02, 1)
            atmo.Density = far.density * k
            atmo.Haze = (far.haze or 0) * k
        end
    end)
end

function Env.setView(v)
    pcall(function()
        if v > 0 then
            if not Env.far then
                local atmo = getAtmosphere()
                Env.far = {
                    fogStart = Lighting.FogStart, fogEnd = Lighting.FogEnd,
                    density = atmo and atmo.Density, haze = atmo and atmo.Haze,
                }
            end
            if not Cfg.noFog then Env.assertView() end
            if not Env.viewHandle then
                Env.viewHandle = Loop.register("View Distance", function()
                    if (Cfg.viewDist or 0) > 0 and not Cfg.noFog then Env.assertView() end
                end, { interval = 0.1, keep = true })
            end
        elseif Env.far then
            local far = Env.far
            Env.far = nil
            if Env.viewHandle then Loop.remove(Env.viewHandle); Env.viewHandle = nil end
            if not Cfg.noFog then
                Lighting.FogStart = far.fogStart
                Lighting.FogEnd = far.fogEnd
                local atmo = getAtmosphere()
                if atmo and far.density ~= nil then
                    atmo.Density = far.density
                    atmo.Haze = far.haze
                end
            end
        end
    end)
end

function Env.startLoop()
    Loop.register("Environment", function()
        if (Cfg.viewDist or 0) > 0 and not Cfg.noFog then Env.assertView() end
        if Cfg.noFog then assertFog() end
        if Cfg.fullBright then assertBright() end
        if (Cfg.timeOfDay or 0) > 0 then Lighting.ClockTime = Cfg.timeOfDay end
    end, { interval = 0.5, keep = true })
end

-- ---------- 6h-b. Performance caps ----------
local Perf = {
    origQuality = nil, origFps = nil, fpsWarned = false, notify = nil,
    anim = { animators = setmetatable({}, { __mode = "k" }), frozen = setmetatable({}, { __mode = "k" }),
        handle = nil, conn = nil, token = 0 },
}

function Perf.applyQuality()
    pcall(function()
        local rendering = settings().Rendering
        local want = ((Cfg.renderLevel or 0) > 0) and Cfg.renderLevel or nil
        if want then
            if Perf.origQuality == nil then Perf.origQuality = rendering.QualityLevel end
            rendering.QualityLevel = Enum.QualityLevel[string.format("Level%02d", want)]
        elseif Perf.origQuality ~= nil then
            rendering.QualityLevel = Perf.origQuality
            Perf.origQuality = nil
        end
    end)
end

function Perf.applyFpsCap()
    local v = Cfg.fpsCap or 0
    if typeof(setfpscap) ~= "function" then
        if v > 0 and not Perf.fpsWarned then
            Perf.fpsWarned = true
            if Perf.notify then Perf.notify("FPS cap isn't supported by this executor") end
        end
        return
    end
    if v > 0 then
        if Perf.origFps == nil then
            local cur = 60
            if typeof(getfpscap) == "function" then
                local ok, r = pcall(getfpscap)
                if ok and type(r) == "number" then cur = r end
            end
            Perf.origFps = cur
        end
        pcall(setfpscap, math.max(20, v))
    elseif Perf.origFps ~= nil then
        pcall(setfpscap, Perf.origFps)
        Perf.origFps = nil
    end
end

local function trackAnimator(inst)
    if inst:IsA("Animator") then Perf.anim.animators[inst] = true end
end

function Perf.animThaw(animator)
    local list = Perf.anim.frozen[animator]
    if not list then return end
    for track, spd in pairs(list) do pcall(function() track:AdjustSpeed(spd) end) end
    Perf.anim.frozen[animator] = nil
end

function Perf.animStep()
    local dist = Cfg.animCap or 0
    if dist <= 0 then return end
    local char, _, hrp = getCharacterParts()
    if not hrp then return end
    local origin = hrp.Position
    for animator in pairs(Perf.anim.animators) do
        if not animator.Parent then
            Perf.anim.animators[animator] = nil
            Perf.anim.frozen[animator] = nil
        else
            pcall(function()
                local model = animator:FindFirstAncestorOfClass("Model")
                if not model or model == char then return end
                local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if not root then return end
                if (root.Position - origin).Magnitude > dist then
                    local list = Perf.anim.frozen[animator]
                    if not list then list = {}; Perf.anim.frozen[animator] = list end
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        if list[track] == nil then list[track] = track.Speed end
                        if track.Speed ~= 0 then track:AdjustSpeed(0) end
                    end
                else
                    Perf.animThaw(animator)
                end
            end)
        end
    end
end

function Perf.animStart()
    local a = Perf.anim
    if a.handle then return end
    a.token += 1
    local tok = a.token
    a.conn = workspace.DescendantAdded:Connect(function(d) pcall(trackAnimator, d) end)
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if not Runtime.alive or a.token ~= tok then return end
            pcall(trackAnimator, d)
            n += 1
            if n % 500 == 0 then task.wait() end
        end
    end)
    a.handle = Loop.register("Animation Cap", Perf.animStep, { interval = 0.4, keep = true })
end

function Perf.animStop()
    local a = Perf.anim
    a.token += 1
    if a.conn then pcall(function() a.conn:Disconnect() end); a.conn = nil end
    if a.handle then Loop.remove(a.handle); a.handle = nil end
    for animator in pairs(a.frozen) do Perf.animThaw(animator) end
    table.clear(a.frozen)
end

function Perf.applyAnim()
    if (Cfg.animCap or 0) > 0 then Perf.animStart() else Perf.animStop() end
end

function Perf.restoreAll()
    pcall(function()
        if Perf.origQuality ~= nil then
            settings().Rendering.QualityLevel = Perf.origQuality
            Perf.origQuality = nil
        end
    end)
    if Perf.origFps ~= nil and typeof(setfpscap) == "function" then
        pcall(setfpscap, Perf.origFps)
        Perf.origFps = nil
    end
    pcall(Perf.animStop)
    pcall(Env.setView, 0)
end

-- ---------- 6i. Feature setters ----------
local Features = {}

function Features.fly(on) Cfg.fly = on end

function Features.godMode(on)
    Cfg.godMode = on
    pcall(function()
        if on then
            local _, hum = getCharacterParts()
            if hum and hum.Health > 0 then hum.Health = hum.MaxHealth end
        end
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
    Perf.applyQuality()
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

function Features.espUsername(on)
    Cfg.espUsername = on
    for player, t in pairs(ESP.tags) do
        if t.nameLbl then t.nameLbl.Text = ESP.nameOf(player) end
    end
end

function Features.espBox(on)
    Cfg.espBox = on
    if not on then
        for _, t in pairs(ESP.tags) do if t.box then t.box.Visible = false end end
    end
end

function Features.aimLock(on)
    Cfg.aimLock = on
    if on then Aim.start() else Aim.stop() end
    FovCircle.refresh()
end

function Features.aimPredict(on) Cfg.aimPredict = on end

function Features.teamCheck(on)
    Cfg.teamCheck = on
    for player in pairs(ESP.highlights) do
        local h = ESP.highlights[player]
        if h then h.FillColor = ESP.colorFor(player) end
    end
end

function Features.fovCircle(on)
    Cfg.fovCircle = on
    FovCircle.ensure()
    FovCircle.refresh()
end

function Features.hitbox(on)
    Cfg.hitbox = on
    if on then Hitbox.start() else Hitbox.stop() end
end

function Features.autoClick(on)
    Cfg.autoClick = on
    AutoClick.acc = 0
end

function Features.freecam(on)
    Cfg.freecam = on
    if on then Freecam.enable() else Freecam.disable() end
end

function Features.antiFling(on) Cfg.antiFling = on end

function Features.autoJump(on) Cfg.autoJump = on end

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
        local char, hum, hrp = getCharacterParts()
        if hum then AntiTrip.engage(hum) end
        if char and hrp then Speed.calcGroundOff(char, hrp) end
    end
end

local function movementStep(dt)
    do
        local char, hum, hrp = getCharacterParts()
        if not (char and hum and hrp) then return end
        local alive = hum.Health > 0
        local desired = "idle"
        if Freecam.active then
            desired = "idle"
        elseif Cfg.fly and alive then
            desired = "fly"
        elseif Cfg.speed > SPEED_MIN and alive and hum.SeatPart == nil then
            desired = "boost"
        end
        if desired ~= Runtime.mode then
            local from = Runtime.mode
            Runtime.mode = desired
            transition(from, desired)
        end
        if desired == "fly" then Fly.step(hrp, hum, dt)
        elseif desired == "boost" then Speed.step(hrp, hum, dt) end
    end
end

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
    Loop.register("Anti-Fling", antiFlingStep, { feature = "antiFling" })
    Loop.register("Jump", jumpStep, { keep = true })
    Loop.register("Auto Clicker", autoClickStep, { feature = "autoClick" })
end

local function onCharacterAdded(char)
    table.clear(originalVisual)
    table.clear(originalDisplay)
    table.clear(Noclip.orig); Noclip.char = nil
    Runtime.mode = "idle"
    AntiTrip.reset()
    Fly.reset()
    Speed.reset()
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
    pcall(Hitbox.stop)
    pcall(ESP.disable)
    pcall(Noclip.stop)
    pcall(AntiAFK.stop)
    pcall(Aim.stop)
    pcall(Freecam.disable)
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
    pcall(Env.setTime, 0)
    pcall(Env.setGravity, 0)
    pcall(Env.setFov, 0)
    pcall(Perf.restoreAll)
    task.spawn(function() pcall(Optimizer.disable) end)
    for _, k in ipairs(TOGGLE_KEYS) do Cfg[k] = false end
end

-- ============================================================
-- 8. UI FRAMEWORK
-- ============================================================
local function staggerIn(holder)
    local items = {}
    for _, c in ipairs(holder:GetChildren()) do
        if c:IsA("GuiObject") then table.insert(items, c) end
    end
    table.sort(items, function(a, b) return (a.LayoutOrder or 0) < (b.LayoutOrder or 0) end)
    for i, card in ipairs(items) do
        local s = card:FindFirstChildOfClass("UIScale")
        if not s then s = create("UIScale", { Scale = 1 }, card) end
        s.Scale = 0.965
        task.delay((i - 1) * 0.04, function()
            if card.Parent then
                TweenService:Create(s, SPRING_INFO, { Scale = 1 }):Play()
            end
        end)
    end
end

function Toast.init(gui)
    Toast.layer = create("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18),
        Size = UDim2.fromOffset(310, 330),
        BackgroundTransparency = 1, Active = false, ZIndex = 90,
    }, gui)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 7),
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
                Size = UDim2.fromOffset(TOAST_TEXT_W + 18, textH + 18),
                BackgroundColor3 = Theme.Surface,
                BackgroundTransparency = 0.06,
                BorderSizePixel = 0,
                ZIndex = 91,
            }, Toast.layer)
            addCorner(frame, 10)
            addStroke(frame, Theme.Hairline, 1, 0.4)
            local bar = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
                Size = UDim2.new(0, 3, 1, -16),
                BackgroundColor3 = accent or Theme.Accent,
                BorderSizePixel = 0, ZIndex = 92,
            }, frame)
            addCorner(bar, 2)
            local label = create("TextLabel", {
                Size = UDim2.new(1, -22, 1, 0),
                Position = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text = text, TextTransparency = 1,
                TextSize = 14, TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 92,
            }, frame)

            local tin = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(frame, tin, { BackgroundTransparency = 0.06 }):Play()
            TweenService:Create(label, tin, { TextTransparency = 0 }):Play()

            task.wait(duration)
            if not frame.Parent then return end
            local tout = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            TweenService:Create(frame, tout, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(label, tout, { TextTransparency = 1 }):Play()
            task.wait(0.3)
            frame:Destroy()
        end)
    end)
end

function Errors.disable(featureKey)
    if not featureKey or Errors.busy then return end
    Errors.busy = true
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

local Tooltip = { frame = nil, label = nil, size = Vector2.new(0, 0), token = 0 }

function Tooltip.init(gui)
    Tooltip.frame = create("Frame", {
        Name = "Tooltip",
        Visible = false,
        Size = UDim2.fromOffset(120, 30),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0, Active = false, ZIndex = 100,
    }, gui)
    addCorner(Tooltip.frame, 9)
    addStroke(Tooltip.frame, Theme.Hairline, 1, 0.35)
    Tooltip.label = create("TextLabel", {
        Position = UDim2.fromOffset(11, 8),
        Size = UDim2.fromOffset(100, 20),
        BackgroundTransparency = 1,
        Text = "", TextTransparency = 1,
        TextSize = 14, TextWrapped = true, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 101,
    }, Tooltip.frame)
end

function Tooltip.set(text)
    text = text or ""
    local w, h = measureText(text, 14, TOOLTIP_MAX_W)
    Tooltip.label.Text = text
    Tooltip.label.Size = UDim2.fromOffset(w, h)
    Tooltip.frame.Size = UDim2.fromOffset(w + 22, h + 16)
    Tooltip.size = Vector2.new(w + 22, h + 16)
end

function Tooltip.move()
    pcall(function()
        local m = UserInputService:GetMouseLocation()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local x = math.min(m.X + 16, vp.X - Tooltip.size.X - 8)
        local y = math.min(m.Y + 18, vp.Y - Tooltip.size.Y - 8)
        Tooltip.frame.Position = UDim2.fromOffset(math.max(x, 4), math.max(y, 4))
    end)
end

function Tooltip.show()
    if not Tooltip.frame then return end
    Tooltip.token += 1
    Tooltip.frame.Visible = true
    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(Tooltip.frame, info, { BackgroundTransparency = 0.04 }):Play()
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

local function addHoverFX(obj, stroke, restTransparency)
    local base = obj.BackgroundColor3
    local baseStroke = stroke and stroke.Color or nil
    track(obj.MouseEnter:Connect(function()
        Sfx.play("hover")
        TweenService:Create(obj, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
        if stroke then
            TweenService:Create(stroke, HOVER_INFO, { Transparency = 0, Color = Theme.Accent }):Play()
        end
    end))
    track(obj.MouseLeave:Connect(function()
        TweenService:Create(obj, HOVER_INFO, { BackgroundColor3 = base }):Play()
        if stroke then
            TweenService:Create(stroke, HOVER_INFO, {
                Transparency = restTransparency or 0.55,
                Color = baseStroke or Theme.Hairline }):Play()
        end
    end))
end

local CardContext = { open = nil, t = 0 }
local function createCard(page, name, height, accent)
    page.order += 1
    local card = create("Frame", {
        Name = name .. "Card",
        LayoutOrder = page.order,
        Size = UDim2.new(1, -10, 0, height),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
    }, page.frame)
    addCorner(card, 11)
    local stroke = addStroke(card, Theme.Hairline, 1, 0.55)
    track(card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and CardContext.open then
            guard("Context menu", nil, CardContext.open, card)
        end
    end))
    return card, stroke
end

local function createSlider(page, spec)
    local card, cardStroke = createCard(page, spec.name, 80, spec.accent)
    card:SetAttribute("desc", spec.desc or spec.name)
    card:SetAttribute("search", string.lower(spec.name .. " " .. (spec.desc or "") .. " " .. (spec.tip or "")))

    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(0.65, 0, 0, 22),
        BackgroundTransparency = 1, Text = spec.name, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 31), Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1, Text = spec.desc, TextSize = 13, TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    local valueLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 9),
        Size = UDim2.new(0, 74, 0, 22), BackgroundTransparency = 1,
        Text = tostring(spec.value), TextSize = 16,
        TextColor3 = Theme.Accent2,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, card)

    local sliderTrack = create("Frame", {
        Name = "Track",
        Position = UDim2.new(0, 14, 0, 64),
        Size = UDim2.new(1, -28, 0, 8),
        BackgroundColor3 = Theme.Track, BorderSizePixel = 0,
    }, card)
    addCorner(sliderTrack, 4)
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
    }, sliderTrack)
    addCorner(fill, 4)
    addGradient(fill, Theme.Accent, Theme.Accent2, 0)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18), BackgroundColor3 = Theme.White,
        BorderSizePixel = 0, ZIndex = 3,
    }, sliderTrack)
    addCorner(knob, 9)
    addStroke(knob, Theme.Accent2, 2, 0)

    local popup = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0, -10),
        Size = UDim2.fromOffset(46, 20),
        BackgroundColor3 = Theme.Bg, BackgroundTransparency = 1,
        Text = tostring(spec.value), TextSize = 12, TextColor3 = Theme.Text,
        TextTransparency = 1, Visible = false, ZIndex = 8,
    }, knob)
    addCorner(popup, 6)
    addStroke(popup, Theme.Accent, 1, 0.1)

    local hit = create("TextButton", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 4,
    }, sliderTrack)

    local value = spec.value
    local displayValue = value
    local knobInfo = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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

local function createToggle(page, spec)
    local card, cardStroke = createCard(page, spec.name, 60, spec.accent)
    card:SetAttribute("search", string.lower(spec.name .. " " .. (spec.desc or "") .. " " .. (spec.tip or "")))
    card:SetAttribute("desc", spec.name .. " - " .. (spec.desc or ""))
    if spec.rebind then card:SetAttribute("rebind", spec.rebind) end

    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(1, -96, 0, 22),
        BackgroundTransparency = 1, Text = spec.name, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -96, 0, 18),
        BackgroundTransparency = 1, Text = spec.desc, TextSize = 13, TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)

    local switch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 50, 0, 28), BackgroundColor3 = Theme.Track,
        Text = "", AutoButtonColor = false, ZIndex = 5,
    }, card)
    addCorner(switch, 14)
    local swStroke = addStroke(switch, Theme.Off, 1.2, 0.4)
    local sKnob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 20), BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0, ZIndex = 6,
    }, switch)
    addCorner(sKnob, 10)
    local sGrad = create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = 0 }, sKnob)
    sGrad.Enabled = false

    local on = false
    local pulseToken = 0

    local function render()
        if on then
            TweenService:Create(sKnob, SPRING_INFO, { Position = UDim2.new(1, -24, 0.5, 0), BackgroundColor3 = Theme.White }):Play()
            TweenService:Create(switch, SPRING_INFO, { BackgroundColor3 = Theme.OnAccent }):Play()
            TweenService:Create(swStroke, SPRING_INFO, { Color = Theme.Accent, Transparency = 0 }):Play()
            sGrad.Enabled = true
            pulseToken += 1
            local tok = pulseToken
            task.spawn(function()
                while on and card.Parent and tok == pulseToken do
                    TweenService:Create(swStroke, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 2 }):Play()
                    task.wait(0.75)
                    if not (on and tok == pulseToken) then break end
                    TweenService:Create(swStroke, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Thickness = 1.2 }):Play()
                    task.wait(0.75)
                end
            end)
        else
            pulseToken += 1
            sGrad.Enabled = false
            TweenService:Create(sKnob, SPRING_INFO, { Position = UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = Theme.Off }):Play()
            TweenService:Create(switch, SPRING_INFO, { BackgroundColor3 = Theme.Track }):Play()
            TweenService:Create(swStroke, SPRING_INFO, { Color = Theme.Off, Transparency = 0.4, Thickness = 1.2 }):Play()
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

local function createButton(page, text, accent, tip, callback)
    local card, cardStroke = createCard(page, text, 46, accent)
    card:SetAttribute("search", string.lower(text .. " " .. (tip or "")))
    card:SetAttribute("desc", text .. (tip and (" - " .. tip) or ""))
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = text, TextSize = 15, AutoButtonColor = false, ZIndex = 5,
    }, card)
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

local function createInfo(page, text, accent)
    local _, h = measureText(text, 14, 400)
    local card = createCard(page, "Info" .. tostring(page.order + 1), h + 34, accent or Theme.Off)
    create("TextLabel", {
        Position = UDim2.fromOffset(14, 11),
        Size = UDim2.new(1, -28, 1, -22),
        BackgroundTransparency = 1, Text = text, TextSize = 13, TextColor3 = Theme.TextDim,
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
            Toast.show(label .. (on and " enabled" or " disabled"), on and Theme.Accent2 or Theme.Off)
        end
    end
end

local function applyConfigToUI()
    local missing = {}
    local function slider(key, v)
        local s = UI.sliders[key]
        if s and v ~= nil then s.Set(v) else table.insert(missing, "slider:" .. key) end
    end
    local function toggle(key, v)
        local t = UI.toggles[key]
        if t then t.Set(v, true) else table.insert(missing, "toggle:" .. key) end
    end
    slider("speed", Cfg.speed)
    slider("flySpeed", Cfg.flySpeed)
    slider("freecamSpeed", Cfg.freecamSpeed)
    slider("auraRadius", Cfg.auraRadius)
    slider("hitboxScale", Cfg.hitboxScale)
    slider("autoClickCps", Cfg.autoClickCps)
    slider("espDistance", Cfg.espDistance)
    slider("jumpPower", Cfg.jumpPower)
    slider("timeOfDay", Cfg.timeOfDay)
    slider("camFov", Cfg.camFov)
    slider("gravity", Cfg.gravity)
    for _, key in ipairs({ "renderLevel", "fpsCap", "animCap", "viewDist", "microStep", "flySpoof",
        "aimFov", "aimSmooth", "aimRange", "speedBrake" }) do
        slider(key, Cfg[key])
    end
    for _, k in ipairs(TOGGLE_KEYS) do toggle(k, Cfg[k] and PASSIVE_RESTORE[k] == true) end
    if #missing > 0 then
        Toast.show("Config restore: missing " .. table.concat(missing, ", "), Theme.Red, 5)
    end
end

local function buildMain()
    PanelSize = UDim2.fromOffset(Cfg.panelW or PANEL_SIZE.X.Offset, Cfg.panelH or PANEL_SIZE.Y.Offset)
    Main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = PanelSize,
        BackgroundTransparency = 1,
        Active = true,
    }, ScreenGui)

    local shadowParts = addPanelShadow(Main)

    local bgFill = create("Frame", {
        Name = "BgFill", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, ZIndex = 2,
    }, Main)
    addCorner(bgFill, PANEL_RADIUS)
    create("UIGradient", { Color = ColorSequence.new(Theme.Bg2, Theme.Bg), Rotation = 90 }, bgFill)
    local bgStroke = addStroke(bgFill, Theme.Hairline, 1, 0.4)
    local bgBorder = addGradientBorder(bgFill, 1.2)

    local body = create("CanvasGroup", {
        Name = "Panel", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
        GroupTransparency = 0,
    }, Main)

    local scale = create("UIScale", { Scale = ENTRY_START_SCALE * userScale() }, Main)
    TweenService:Create(scale, ENTRY_INFO, { Scale = userScale() }):Play()
    task.delay(ENTRY_INFO.Time + 0.2, function()
        if Main and Main.Parent then snapToPixel(Main) end
    end)

    -- ==================== SIDEBAR ====================
    local sidebar = create("Frame", {
        Name = "Sidebar",
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(0, SIDEBAR_W, 1, -20),
        BackgroundColor3 = Theme.Bg2, BackgroundTransparency = 0.35,
        BorderSizePixel = 0, ZIndex = 3,
    }, body)
    addCorner(sidebar, 12)
    addStroke(sidebar, Theme.Hairline, 1, 0.55)

    local logo = create("Frame", {
        Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, ZIndex = 4,
    }, sidebar)
    local logoText = create("TextLabel", {
        Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22),
        BackgroundTransparency = 1, Text = "EKANTO", TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, logo)
    logoText:SetAttribute("NoBoost", true)
    create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = 0 }, logoText)
    local verLabel = create("TextLabel", {
        Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 14),
        BackgroundTransparency = 1, Text = "v2.3  •  PRO", TextSize = 10,
        TextColor3 = Theme.TextFaint, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, logo)
    verLabel:SetAttribute("NoBoost", true)
    local dot = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 2),
        Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.Green,
        BorderSizePixel = 0, ZIndex = 5,
    }, logo)
    addCorner(dot, 4)

    local navList = create("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 68),
        Size = UDim2.new(1, -16, 1, -140),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
    }, sidebar)
    create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, navList)

    local sbFooter = create("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -10),
        Size = UDim2.new(1, -16, 0, 54),
        BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0.15,
        BorderSizePixel = 0, ZIndex = 5,
    }, sidebar)
    addCorner(sbFooter, 10)
    addStroke(sbFooter, Theme.Hairline, 1, 0.5)

    local avWrap = create("Frame", {
        Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, ZIndex = 6,
    }, sbFooter)
    addCorner(avWrap, 17)
    addStroke(avWrap, Theme.Accent, 1.5, 0.25)
    local avatar = create("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ZIndex = 7,
    }, avWrap)
    addCorner(avatar, 17)
    local avDot = create("Frame", {
        Position = UDim2.fromOffset(31, 33), Size = UDim2.fromOffset(9, 9),
        BackgroundColor3 = Theme.Green, BorderSizePixel = 0, ZIndex = 9,
    }, sbFooter)
    addCorner(avDot, 5)
    addStroke(avDot, Theme.Surface, 2, 0)

    local nameLbl = create("TextLabel", {
        Position = UDim2.fromOffset(50, 11), Size = UDim2.new(1, -58, 0, 14),
        BackgroundTransparency = 1, Text = LocalPlayer.DisplayName, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7,
    }, sbFooter)
    nameLbl:SetAttribute("NoBoost", true)
    local handleLbl = create("TextLabel", {
        Position = UDim2.fromOffset(50, 27), Size = UDim2.new(1, -58, 0, 12),
        BackgroundTransparency = 1, Text = "@" .. LocalPlayer.Name, TextSize = 10,
        TextColor3 = Theme.TextFaint, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7,
    }, sbFooter)
    handleLbl:SetAttribute("NoBoost", true)

    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and url and avatar.Parent then avatar.Image = url end
    end)

    -- ==================== CONTENT ====================
    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.new(0, SIDEBAR_W + 20, 0, 0),
        Size = UDim2.new(1, -(SIDEBAR_W + 20), 1, 0),
        BackgroundTransparency = 1, ZIndex = 3,
    }, body)

    local header = create("Frame", {
        Position = UDim2.new(0, 12, 0, 12),
        Size = UDim2.new(1, -24, 0, 38),
        BackgroundTransparency = 1, Active = true, ZIndex = 4,
    }, content)

    local pageTitle = create("TextLabel", {
        Position = UDim2.fromOffset(2, 0), Size = UDim2.new(0, 118, 1, 0),
        BackgroundTransparency = 1, Text = "Movement", TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, header)

    local function makeHeaderButton(name, text, xOffset, hoverColor)
        local btn = create("TextButton", {
            Name = name, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.new(0, 30, 0, 30),
            BackgroundColor3 = Theme.Surface, Text = text, TextSize = 16,
            AutoButtonColor = false, ZIndex = 6,
        }, header)
        addCorner(btn, 9)
        addStroke(btn, Theme.Hairline, 1, 0.5)
        track(btn.MouseEnter:Connect(function()
            TweenService:Create(btn, HOVER_INFO, { BackgroundColor3 = hoverColor }):Play()
        end))
        track(btn.MouseLeave:Connect(function()
            TweenService:Create(btn, HOVER_INFO, { BackgroundColor3 = Theme.Surface }):Play()
        end))
        return btn
    end

    local closeBtn = makeHeaderButton("Close", "×", -2, Theme.Red)
    local minBtn = makeHeaderButton("Minimize", "–", -38, Theme.HoverGrey)

    track(closeBtn.MouseButton1Click:Connect(function()
        ripple(body, Theme.Red)
        pcall(saveConfig)
        pcall(function() ScreenGui:Destroy() end)
    end))
    track(minBtn.MouseButton1Click:Connect(function()
        ripple(body, Theme.Accent)
    end))

    local searchBox = create("TextBox", {
        Name = "Search", Position = UDim2.new(0, 130, 0.5, 0),
        Size = UDim2.new(1, -130 - 80, 0, 32),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Surface, Text = "", PlaceholderText = "Search or run a command...",
        PlaceholderColor3 = Theme.TextFaint, ClearTextOnFocus = false,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, header)
    addCorner(searchBox, 9)
    local searchStroke = addStroke(searchBox, Theme.Hairline, 1, 0.5)
    create("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 28) }, searchBox)
    track(searchBox.Focused:Connect(function()
        TweenService:Create(searchStroke, HOVER_INFO, { Color = Theme.Accent, Transparency = 0 }):Play()
    end))
    track(searchBox.FocusLost:Connect(function()
        TweenService:Create(searchStroke, HOVER_INFO, { Color = Theme.Hairline, Transparency = 0.5 }):Play()
    end))
    local clearBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Text = "×",
        TextSize = 16, TextColor3 = Theme.TextDim, Visible = false, AutoButtonColor = false, ZIndex = 8,
    }, searchBox)

    makeDraggable(header, Main, nil, nil, true)
    makeDraggable(logo, Main, nil, nil, true)

    local tabs = {}
    local tabNames = {}
    local currentTab = "Movement"
    local tabOrder = 0

    local function selectTab(name)
        if not tabs[name] then return end
        currentTab = name
        pageTitle.Text = name
        for n, t in pairs(tabs) do
            local active = (n == name)
            t.page.frame.Visible = active
            t.label.TextColor3 = active and Theme.Text or Theme.TextDim
            t.item.BackgroundTransparency = active and 0.15 or 1
            t.bar.Visible = active
            t.hl.Visible = active
        end
        staggerIn(tabs[name].page.frame)
    end

    local function createTab(name)
        tabOrder += 1
        local item = create("TextButton", {
            LayoutOrder = tabOrder, Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = Theme.Surface, BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 5,
        }, navList)
        addCorner(item, 9)

        local hl = create("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 5, Visible = false,
        }, item)
        addCorner(hl, 9)

        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 18), BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0, ZIndex = 6, Visible = false,
        }, item)
        addCorner(bar, 2)
        addGradient(bar, Theme.Accent, Theme.Accent2, 90)

        local label = create("TextLabel", {
            Position = UDim2.fromOffset(17, 0), Size = UDim2.new(1, -22, 1, 0),
            BackgroundTransparency = 1, Text = name, TextSize = 14,
            TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
        }, item)

        local frame = create("ScrollingFrame", {
            Position = UDim2.new(0, 12, 0, 58),
            Size = UDim2.new(1, -24, 1, -70),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Hairline,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ZIndex = 4,
        }, content)
        create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, frame)
        local layout = create("UIListLayout", {
            Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder,
        }, frame)
        track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            pcall(function()
                frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
            end)
        end))

        local page = { frame = frame, order = 0 }
        tabs[name] = { button = item, item = item, hl = hl, bar = bar, label = label, page = page, index = tabOrder }
        table.insert(tabNames, name)

        track(item.MouseEnter:Connect(function()
            if currentTab ~= name then
                TweenService:Create(item, HOVER_INFO, { BackgroundTransparency = 0.55 }):Play()
                label.TextColor3 = Theme.Text
            end
        end))
        track(item.MouseLeave:Connect(function()
            if currentTab ~= name then
                TweenService:Create(item, HOVER_INFO, { BackgroundTransparency = 1 }):Play()
                label.TextColor3 = Theme.TextDim
            end
        end))
        track(item.MouseButton1Click:Connect(function()
            ripple(item, Theme.Accent)
            Sfx.play("click")
            selectTab(name)
        end))
        return page
    end

    local movePage = createTab("Movement")
    local combatPage = createTab("Combat")
    local perfPage = createTab("Performance")
    local toolsPage = createTab("Tools")
    local gamesPage = createTab("Games")
    local settingsPage = createTab("Settings")

    local function createSection(page, text)
        page.order += 1
        return create("TextLabel", {
            Name = "Section" .. page.order, LayoutOrder = page.order,
            Size = UDim2.new(1, -10, 0, 22), BackgroundTransparency = 1,
            Text = string.upper(text), TextSize = 11, TextColor3 = Theme.Accent2,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, page.frame)
    end

    local function cardLabels(card, title, desc, rightPad)
        create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(1, -(rightPad or 28), 0, 22),
            BackgroundTransparency = 1, Text = title, TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
        return create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -(rightPad or 28), 0, 18),
            BackgroundTransparency = 1, Text = desc, TextSize = 13, TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, card)
    end

    -- ---------- Movement ----------
    createSection(movePage, "Speed")
    createSlider(movePage, {
        key = "speed", name = "Speed Boost (Swept Micro-Teleport)",
        desc = "16 - 500 • WalkSpeed stays untouched",
        tip = "The extra distance is delivered as a SWEPT micro-move: a raycast sweep clamps you at walls, slides you along them, steps up small ledges and hugs slopes.",
        min = SPEED_MIN, max = SPEED_MAX, value = Cfg.speed, accent = Theme.Accent,
        onChange = function(v) Cfg.speed = v; scheduleSave() end,
    })
    createSlider(movePage, {
        key = "speedBrake", name = "Stop Brake (Inertia Fix)",
        desc = "Higher = stops faster • 5 - 60",
        tip = "How hard the leftover engine velocity is killed the instant you let go of the keys.",
        min = 5, max = 60, value = Cfg.speedBrake, accent = Theme.Accent2,
        onChange = function(v) Cfg.speedBrake = v; scheduleSave() end,
    })
    createSlider(movePage, {
        key = "microStep", name = "Sweep Granularity (x0.01 studs)",
        desc = "20 = 0.20 studs per swept step • 5 - 50",
        tip = "How finely the frame distance is chopped before each collision sweep.",
        min = MICRO_MIN, max = MICRO_MAX, value = Cfg.microStep, accent = Theme.Accent2,
        onChange = function(v) Cfg.microStep = v; scheduleSave() end,
    })
    createToggle(movePage, {
        key = "fallRescue", name = "Fall Rescue",
        desc = "Warps you back up if you fall below the map",
        tip = "Remembers the last solid ground you stood on. If you somehow end up 70 studs below it, you are placed back on top.",
        accent = Theme.Accent,
        callback = function(on) Cfg.fallRescue = on and true or false; scheduleSave() end,
    })
    createToggle(movePage, {
        key = "netSleep", name = "Network Sleep Emulation",
        desc = "Periodic velocity write gaps",
        tip = "On most ticks your reported velocity is a small organic oscillation. Every 14th tick the write is skipped entirely.",
        accent = Theme.Accent,
        callback = function(on) Cfg.netSleep = on and true or false; scheduleSave() end,
    })
    createToggle(movePage, {
        key = "speedLegacy", name = "Legacy Body-Force Speed",
        desc = "Fallback: pushes root part + sets WalkSpeed",
        tip = "The old method. Use it for the rare game where the swept movement fights with a custom controller.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.speedLegacy = on and true or false; scheduleSave() end,
    })

    createSection(movePage, "Flight")
    createToggle(movePage, {
        key = "fly", name = "Fly Hack Mode",
        desc = "F • WASD move • Space = up (look down + W to descend)",
        tip = "Flight is driven by real engine velocity with gravity cancelled every frame, so the hover is dead still and you collide properly with the world.",
        accent = Theme.Accent, rebind = "fly",
        callback = featureCallback("Fly Hack Mode", Features.fly),
    })
    createSlider(movePage, {
        key = "flySpeed", name = "Fly Speed Control",
        desc = "Live flight speed • 10 - 300",
        tip = "Changes flight speed in real time, even mid-flight.",
        min = FLY_MIN, max = FLY_MAX, value = Cfg.flySpeed, accent = Theme.Accent2,
        onChange = function(v) Cfg.flySpeed = v; scheduleSave() end,
    })
    createSlider(movePage, {
        key = "flySpoof", name = "Fly Collision Blend",
        desc = "100 = full engine physics (collides, admin-like) • 0 - 100",
        tip = "How much of the flight is delivered through real engine velocity. 100 = pure physics: you stop at walls and rest on the ground.",
        min = 0, max = 100, value = Cfg.flySpoof, accent = Theme.Accent,
        onChange = function(v) Cfg.flySpoof = v; scheduleSave() end,
    })

    createSection(movePage, "Freecam")
    createToggle(movePage, {
        key = "freecam", name = "Freecam (Detached Camera)",
        desc = "V • WASD + Space up / Shift down • mouse look",
        tip = "Frees the camera from your character. Move around with WASD and look with the mouse. Use Teleport To Camera to snap your body over.",
        accent = Theme.Accent2, rebind = "freecam",
        callback = featureCallback("Freecam", Features.freecam),
    })
    createSlider(movePage, {
        key = "freecamSpeed", name = "Freecam Speed", desc = "Camera travel speed • 10 - 400",
        tip = "How fast the free camera moves with WASD.",
        min = FREECAM_MIN, max = FREECAM_MAX, value = Cfg.freecamSpeed, accent = Theme.Accent2,
        onChange = function(v) Cfg.freecamSpeed = v; scheduleSave() end,
    })
    createButton(movePage, "Teleport To Camera", Theme.Accent,
        "Snaps your character to the freecam position.", function() Freecam.goto() end)

    createSection(movePage, "Jump")
    createSlider(movePage, {
        key = "jumpPower", name = "Jump Power", desc = "0 = game default • 50 - 500",
        tip = "Sets your jump power. Turn off if a game uses JumpHeight instead.",
        min = 0, max = 500, value = Cfg.jumpPower, accent = Theme.Accent,
        onChange = function(v) Cfg.jumpPower = v; scheduleSave() end,
    })
    createToggle(movePage, {
        key = "autoJump", name = "Auto Jump (Bhop)", desc = "Jumps automatically while moving",
        tip = "Hops the instant you land while moving forward.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.autoJump = on and true or false; scheduleSave() end,
    })

    createSection(movePage, "Misc")
    createToggle(movePage, {
        key = "noclip", name = "Noclip",
        desc = "N • walk through walls",
        tip = "Loops CanCollide off on every character part while enabled.",
        accent = Theme.Accent2, rebind = "noclip",
        callback = featureCallback("Noclip", Features.noclip),
    })
    createToggle(movePage, {
        key = "antiFling", name = "Anti-Fling / Anti-Void",
        desc = "Kills absurd velocity, rescues you from the void",
        tip = "If something launches you with insane velocity it is damped. If you drop below Y -500 you are warped back up.",
        accent = Theme.Accent,
        callback = function(on) Cfg.antiFling = on and true or false; scheduleSave() end,
    })

    -- ---------- Combat ----------
    createSection(combatPage, "Targeting")
    createToggle(combatPage, {
        key = "teamCheck", name = "Team Check",
        desc = "Ignore teammates (aim / aura / ESP color)",
        tip = "Uses your Team and the target's Team. Teammates are skipped by aim and aura and shown green in ESP.",
        accent = Theme.Accent,
        callback = function(on) Cfg.teamCheck = on and true or false; scheduleSave() end,
    })

    createToggle(combatPage, {
        key = "esp", name = "Universal Player ESP",
        desc = "Highlights other players through walls",
        tip = "Flat highlight with white outline on every other player, always visible through walls.",
        accent = Theme.Accent,
        callback = featureCallback("Player ESP", Features.esp),
    })
    createToggle(combatPage, {
        key = "espBox", name = "Box ESP",
        desc = "Draws a box around every player",
        tip = "Projected 2D box around each player. Colored by team when Team Check is on.",
        accent = Theme.Accent2,
        callback = featureCallback("Box ESP", Features.espBox),
    })
    createToggle(combatPage, {
        key = "espInfo", name = "ESP Info Tags + Arrows",
        desc = "Name • distance • health bar • edge arrows",
        tip = "Needs Player ESP on. Shows a tag above each player plus an arrow at the screen edge.",
        accent = Theme.Accent2,
        callback = featureCallback("ESP Info", Features.espInfo),
    })
    createToggle(combatPage, {
        key = "espUsername", name = "ESP Show Username",
        desc = "Off = display name • On = @username",
        tip = "Switches the name above every player between display name and real username.",
        accent = Theme.Accent,
        callback = featureCallback("ESP Username", Features.espUsername),
    })
    createSlider(combatPage, {
        key = "espDistance", name = "ESP Max Distance", desc = "0 = unlimited • 100 - 2000 studs",
        tip = "Hide ESP for players farther than this.",
        min = 0, max = 2000, value = Cfg.espDistance, accent = Theme.Accent,
        onChange = function(v) Cfg.espDistance = v; scheduleSave() end,
    })

    createSection(combatPage, "Aim")
    createToggle(combatPage, {
        key = "aimLock", name = "Aim Lock (Auto-Aim)",
        desc = "Hotkey: " .. (Cfg.keys.aimLock or "LeftAlt") .. " • camera locks onto the crosshair target",
        tip = "Picks the player closest to the centre of your screen inside the FOV cone AND Aim Range. Middle click pins a target.",
        accent = Theme.Accent2, rebind = "aimLock",
        callback = featureCallback("Aim Lock", Features.aimLock),
    })
    createToggle(combatPage, {
        key = "fovCircle", name = "Aim FOV Circle",
        desc = "Draws the aim cone on screen",
        tip = "A ring showing exactly where the aim can grab targets.",
        accent = Theme.Accent,
        callback = featureCallback("FOV Circle", Features.fovCircle),
    })
    createSlider(combatPage, {
        key = "aimFov", name = "Aim FOV", desc = "How far from the crosshair it grabs • 5 - 90 degrees",
        tip = "The aim only engages when a target is inside this cone.",
        min = 5, max = 90, value = Cfg.aimFov, accent = Theme.Accent,
        onChange = function(v) Cfg.aimFov = v; FovCircle.refresh(); scheduleSave() end,
    })
    createSlider(combatPage, {
        key = "aimRange", name = "Aim Range Control", desc = "Hard stud limit • 10 - 500",
        tip = "The engine strictly ignores any player or NPC farther than this.",
        min = 10, max = 500, value = Cfg.aimRange, accent = Theme.Accent2,
        onChange = function(v) Cfg.aimRange = v; scheduleSave() end,
    })
    createSlider(combatPage, {
        key = "aimSmooth", name = "Aim Smoothness", desc = "0 = instant snap • higher = smoother",
        tip = "0 snaps the camera straight onto the target. Higher values glide the camera over.",
        min = 0, max = 30, value = Cfg.aimSmooth, accent = Theme.Accent,
        onChange = function(v) Cfg.aimSmooth = v; scheduleSave() end,
    })
    createToggle(combatPage, {
        key = "aimHead", name = "Aim at Head", desc = "Head instead of torso",
        tip = "On: locks onto the Head. Off: locks onto the torso / root part.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.aimHead = on and true or false; scheduleSave() end,
    })
    createToggle(combatPage, {
        key = "aimPredict", name = "Aim Prediction (Lead)",
        desc = "Leads moving targets using their velocity",
        tip = "Aims at where the target will be, compensating for ping and their movement.",
        accent = Theme.Accent,
        callback = featureCallback("Aim Prediction", Features.aimPredict),
    })
    createToggle(combatPage, {
        key = "aimNpc", name = "Aim at NPCs too", desc = "Include non-player humanoids",
        tip = "Also locks onto NPCs / dummies / mobs, not just real players.",
        accent = Theme.Accent,
        callback = function(on) Cfg.aimNpc = on and true or false; scheduleSave() end,
    })
    createToggle(combatPage, {
        key = "aimFire", name = "Auto Fire (Trigger)", desc = "Activates your tool while locked",
        tip = "While a target is locked, your equipped tool is activated about 12 times a second.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.aimFire = on and true or false; scheduleSave() end,
    })
    createButton(combatPage, "Clear Pinned Target", Theme.Off,
        "Releases a middle-click pin.",
        function() Aim.clearPin() end)

    createSection(combatPage, "Melee")
    createToggle(combatPage, {
        key = "hitbox", name = "Hitbox Expander",
        desc = "Enlarges other players' hit parts",
        tip = "Scales HumanoidRootPart / Head / torso of every other player so your weapon hits from farther.",
        accent = Theme.Accent2,
        callback = featureCallback("Hitbox Expander", Features.hitbox),
    })
    createSlider(combatPage, {
        key = "hitboxScale", name = "Hitbox Size Multiplier", desc = "1 = normal • up to 6x",
        tip = "How much bigger the target's hit parts become.",
        min = 1, max = 6, value = Cfg.hitboxScale, accent = Theme.Accent,
        onChange = function(v) Cfg.hitboxScale = v; scheduleSave() end,
    })
    createToggle(combatPage, {
        key = "aura", name = "Auto-Hit / M1 Damage Aura",
        desc = "Force-fires your tool + flings NPCs in range",
        tip = "Scans every 0.05s and force-activates your equipped Tool so its real hit registration and damage land.",
        accent = Theme.Accent2,
        callback = featureCallback("Damage Aura", Features.aura),
    })
    createSlider(combatPage, {
        key = "auraRadius", name = "Aura Radius", desc = "5 - 60 studs",
        tip = "How far the damage aura reaches.",
        min = 5, max = 60, value = Cfg.auraRadius, accent = Theme.Accent,
        onChange = function(v) Cfg.auraRadius = v; scheduleSave() end,
    })
    createToggle(combatPage, {
        key = "auraPlayers", name = "Aura Hits Players Too",
        desc = "Include real players, not just NPCs",
        tip = "Off (default): only NPCs / dummies are targeted. On: real players in range are also swung at and flung.",
        accent = Theme.Accent,
        callback = function(on) Cfg.auraPlayers = on and true or false; scheduleSave() end,
    })

    createSection(combatPage, "Survivability")
    createToggle(combatPage, {
        key = "godMode", name = "100% God Mode",
        desc = "Health locked to max • CanTouch stays ON (pickups work)",
        tip = "Immunity WITHOUT touching CanTouch, so TouchTransmitter signals survive and pickups keep working.",
        accent = Theme.Accent,
        callback = featureCallback("God Mode", Features.godMode),
    })
    createToggle(combatPage, {
        key = "invisible", name = "Smart Invisibility",
        desc = "Sever tracking + full immunity, still hits back",
        tip = "Hides your character, name tag and query box and force-locks health. Your tool's own hit registration is untouched.",
        accent = Theme.Accent2,
        callback = featureCallback("Smart Invisibility", Features.invisible),
    })

    -- ---------- Performance ----------
    createToggle(perfPage, {
        key = "optimizer", name = "Graphics & Animation Optimizer",
        desc = "Less effects, flat materials, cheaper meshes",
        tip = "Disables particles/trails/beams/post effects, flattens materials, hides decals, turns off light shadows, lowers mesh detail and terrain water/grass.",
        accent = Theme.Accent2,
        callback = featureCallback("FPS Optimizer", Features.optimizer),
    })
    createToggle(perfPage, {
        key = "noFog", name = "Remove Fog",
        desc = "Pushes fog out to infinity",
        tip = "FogStart/FogEnd huge, Atmosphere density and haze zeroed. Originals restored when off.",
        accent = Theme.Accent,
        callback = featureCallback("Remove Fog", Features.noFog),
    })
    createToggle(perfPage, {
        key = "fullBright", name = "Full Bright Mode",
        desc = "Pure white ambient light",
        tip = "Forces Ambient/OutdoorAmbient to white and raises brightness.",
        accent = Theme.Accent2,
        callback = featureCallback("Full Bright", Features.fullBright),
    })
    Perf.notify = function(msg) Toast.show(msg, Theme.Red, 3) end
    createSlider(perfPage, {
        key = "renderLevel", name = "Render Quality Level", desc = "0 = game setting • higher draws farther",
        tip = "Roblox hides far and small objects at low quality levels, so a high level lets you see farther.",
        min = 0, max = 10, value = Cfg.renderLevel, accent = Theme.Accent,
        onChange = function(v) Cfg.renderLevel = v; Perf.applyQuality(); scheduleSave() end,
    })
    createSlider(perfPage, {
        key = "fpsCap", name = "FPS Cap", desc = "Limit frame rate • 0 = leave as is • 20 - 240",
        tip = "Uses your executor's setfpscap. A lower cap saves GPU, heat and battery.",
        min = 0, max = 240, value = Cfg.fpsCap, accent = Theme.Accent2,
        onChange = function(v) Cfg.fpsCap = v; Perf.applyFpsCap(); scheduleSave() end,
    })
    createSlider(perfPage, {
        key = "animCap", name = "Animation Distance Cap", desc = "Freeze far characters' animations • 0 = off",
        tip = "Characters farther than this many studs stop animating on your screen only.",
        min = 0, max = 500, value = Cfg.animCap, accent = Theme.Accent,
        onChange = function(v) Cfg.animCap = v; Perf.applyAnim(); scheduleSave() end,
    })
    createSlider(perfPage, {
        key = "viewDist", name = "View Distance", desc = "Fog / detail range in studs • 0 = game default",
        tip = "Pushes fog out to this distance, thins the atmosphere and keeps mesh detail high far away.",
        min = 0, max = 5000, value = Cfg.viewDist, accent = Theme.Accent2,
        onChange = function(v) Cfg.viewDist = v; Env.setView(v); scheduleSave() end,
    })
    pcall(function()
        local streaming = workspace.StreamingEnabled
        if streaming then
            createInfo(perfPage, "This game uses world streaming (target radius about "
                .. math.floor(workspace.StreamingTargetRadius) .. " studs).", Theme.Off)
        else
            createInfo(perfPage, "This game does not stream the world, so View Distance and Remove Fog fully control how far you can see.", Theme.Off)
        end
    end)

    createSection(perfPage, "World")
    createSlider(perfPage, {
        key = "timeOfDay", name = "Time Of Day", desc = "0 = game default • 1 - 24 hours",
        tip = "Sets the lighting clock. Great for making night maps bright.",
        min = 0, max = 24, value = Cfg.timeOfDay, accent = Theme.Accent,
        onChange = function(v) Cfg.timeOfDay = v; Env.setTime(v); scheduleSave() end,
    })
    createSlider(perfPage, {
        key = "camFov", name = "Camera FOV", desc = "0 = game default • 70 - 130",
        tip = "Wider field of view sees more around you.",
        min = 0, max = 130, value = Cfg.camFov, accent = Theme.Accent2,
        onChange = function(v) Cfg.camFov = v; Env.setFov(v); scheduleSave() end,
    })
    createSlider(perfPage, {
        key = "gravity", name = "Gravity", desc = "0 = game default • 1 - 400",
        tip = "Lower gravity for floaty movement, higher to slam down.",
        min = 0, max = 400, value = Cfg.gravity, accent = Theme.Accent,
        onChange = function(v) Cfg.gravity = v; Env.setGravity(v); scheduleSave() end,
    })

    createToggle(perfPage, {
        key = "liteUI", name = "Lite Panel Mode", desc = "Stops the panel's animated borders",
        tip = "The neon borders re-draw every frame. Lite mode freezes them.",
        accent = Theme.Accent,
        callback = function(on)
            Cfg.liteUI = on and true or false
            if Cfg.liteUI then
                for _, g in ipairs(animatedGradients) do pcall(function() g.Rotation = 45 end) end
            end
            scheduleSave()
        end,
    })
    createToggle(perfPage, {
        key = "perfGuard", name = "Performance Guard", desc = "Auto optimizer when FPS drops",
        tip = "Watches your FPS. If it stays under the threshold for 5 seconds it turns the Graphics Optimizer on by itself.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.perfGuard = on and true or false; scheduleSave() end,
    })
    createSlider(perfPage, {
        key = "guardFps", name = "Guard Threshold", desc = "Turn the optimizer on below this FPS • 15 - 60",
        tip = "Performance Guard reacts when your FPS stays below this number.",
        min = 15, max = 60, value = Cfg.guardFps, accent = Theme.Accent2,
        onChange = function(v) Cfg.guardFps = v; scheduleSave() end,
    })
    UI.toggles.liteUI.Set(Cfg.liteUI == true, true)
    UI.toggles.perfGuard.Set(Cfg.perfGuard == true, true)

    local Guard = { acc = 0, frames = 0, low = 0, ok = 0, engaged = false }
    Loop.register("Performance Guard", function(dt)
        if dt > 0.5 then Guard.acc, Guard.frames = 0, 0 return end
        Guard.acc += dt
        Guard.frames += 1
        if Guard.acc < 1 then return end
        local fps = Guard.frames / Guard.acc
        Guard.acc, Guard.frames = 0, 0
        if not Cfg.perfGuard then Guard.low, Guard.ok, Guard.engaged = 0, 0, false return end
        local thr = Cfg.guardFps or 30
        if Guard.engaged and not Cfg.optimizer then Guard.engaged = false end
        if not Guard.engaged then
            Guard.ok = 0
            if fps < thr then Guard.low += 1 else Guard.low = 0 end
            if Guard.low >= 5 then
                Guard.low = 0
                if not Cfg.optimizer then
                    Guard.engaged = true
                    UI.toggles.optimizer.Set(true, false)
                    Toast.show("Performance Guard: FPS stayed under " .. thr .. ", optimizer turned on", Theme.Accent, 4)
                end
            end
        else
            Guard.low = 0
            if fps > thr + 15 then Guard.ok += 1 else Guard.ok = 0 end
            if Guard.ok >= 20 then
                Guard.ok, Guard.engaged = 0, false
                UI.toggles.optimizer.Set(false, false)
                Toast.show("Performance Guard: FPS recovered, optimizer turned off", Theme.Accent, 4)
            end
        end
    end, { keep = true })

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

    local RESERVED = { W = true, A = true, S = true, D = true, E = true, Q = true,
        Space = true, LeftShift = true, Return = true, Tab = true }
    local NON_TYPING = { RightControl = true, LeftControl = true, RightShift = true, Insert = true,
        Home = true, End = true, Delete = true, PageUp = true, PageDown = true,
        LeftAlt = true, RightAlt = true }
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
        Toast.show("Key set to " .. code.Name, Theme.Accent2, 2)
    end

    local function createKeybindRow(page, spec)
        local card, cardStroke = createCard(page, "Key" .. spec.id, 60, Theme.Accent)
        card:SetAttribute("search", string.lower("keybind hotkey key " .. spec.name .. " " .. spec.desc))
        cardLabels(card, spec.name, spec.desc, 172)
        local btn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(130, 32), BackgroundColor3 = Theme.Bg,
            Text = "", TextSize = 13, AutoButtonColor = false, ZIndex = 5,
        }, card)
        addCorner(btn, 9)
        local bStroke = addStroke(btn, Theme.Hairline, 1, 0.5)
        local function refresh()
            if Rebind.action == spec.id then
                btn.Text = "Press a key..."
                btn.TextColor3 = Theme.Accent2
                bStroke.Color = Theme.Accent2
            else
                btn.Text = Cfg.keys[spec.id] or DEFAULT_KEYS[spec.id]
                btn.TextColor3 = Theme.Text
                bStroke.Color = Theme.Hairline
            end
        end
        table.insert(Rebind.refreshers, refresh)
        refresh()
        track(btn.MouseButton1Click:Connect(function()
            ripple(card, Theme.Accent)
            if Rebind.action == spec.id then Rebind.cancel() else Rebind.begin(spec.id) end
        end))
        addHoverFX(card, cardStroke)
        Tooltip.attach(card, "Click, then press the new key. Esc cancels.")
    end

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
        Toast.show("Profile " .. i .. " saved", Theme.Accent2)
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
        Toast.show("Profile " .. i .. " loaded", Theme.Accent2)
        return true
    end

    local function createProfileCard(page, i)
        local key = tostring(i)
        local card, cardStroke = createCard(page, "Profile" .. i, 60, Theme.Accent)
        card:SetAttribute("search", string.lower("profile preset slot " .. i .. " save load"))
        local desc = cardLabels(card, "Profile " .. i, profileSummary(Cfg.profiles[key]), 172)

        local function miniBtn(text, xOff, color)
            local b = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0),
                Size = UDim2.fromOffset(68, 30), BackgroundColor3 = Theme.Bg,
                Text = text, TextSize = 13, AutoButtonColor = false, ZIndex = 5,
            }, card)
            addCorner(b, 8)
            addStroke(b, color, 1, 0.35)
            track(b.MouseEnter:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
            end))
            track(b.MouseLeave:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Bg }):Play()
            end))
            return b
        end
        local saveB = miniBtn("Save", -86, Theme.Accent)
        local loadB = miniBtn("Load", -12, Theme.Accent2)

        ProfileApi.descs[key] = desc
        track(saveB.MouseButton1Click:Connect(function()
            ripple(card, Theme.Accent); Sfx.play("click"); ProfileApi.save(i)
        end))
        track(loadB.MouseButton1Click:Connect(function()
            ripple(card, Theme.Accent2); Sfx.play("click"); ProfileApi.load(i)
        end))
        addHoverFX(card, cardStroke)
    end

    -- ---------- Stats HUD ----------
    local HUD = { frame = nil }
    local HUD_NAMES = { fly = "Fly", godMode = "God", invisible = "Invis", esp = "ESP",
        aura = "Aura", optimizer = "Opt", noFog = "NoFog", fullBright = "Bright",
        noclip = "Clip", antiAfk = "AFK", espUsername = "User", aimLock = "Aim",
        aimHead = "Head", aimNpc = "NPC", aimFire = "Fire", netSleep = "Sleep",
        speedLegacy = "Legacy", smartHop = "Smart", auraPlayers = "AuraP", fallRescue = "Rescue",
        teamCheck = "Team", fovCircle = "FOV", hitbox = "Hitbox", autoClick = "Click",
        aimPredict = "Lead", freecam = "Cam", autoJump = "Jump", antiFling = "Fling",
        espBox = "Box" }

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
            Name = "StatsHUD", Position = UDim2.new(0, 14, 0, 14),
            Size = UDim2.fromOffset(178, 118), BackgroundColor3 = Theme.Surface,
            BackgroundTransparency = 0.08, BorderSizePixel = 0, Active = true,
            Visible = false, ZIndex = 60,
        }, ScreenGui)
        addCorner(f, 12)
        addStroke(f, Theme.Hairline, 1, 0.4)
        local dot = create("Frame", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 9),
            Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Theme.Green,
            BorderSizePixel = 0, ZIndex = 61,
        }, f)
        addCorner(dot, 4)
        local lbl = create("TextLabel", {
            Position = UDim2.fromOffset(11, 8), Size = UDim2.new(1, -22, 0, 50),
            BackgroundTransparency = 1, Text = "", TextSize = 12, Font = Enum.Font.RobotoMono,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 61,
        }, f)
        local onLbl = create("TextLabel", {
            Position = UDim2.fromOffset(11, 60), Size = UDim2.new(1, -20, 0, 16),
            BackgroundTransparency = 1, Text = "", TextSize = 12, Font = Enum.Font.RobotoMono,
            TextColor3 = Theme.Accent2, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61,
        }, f)
        makeDraggable(f, f, nil, nil, true)
        HUD.frame = f

        local spark = create("Frame", {
            Position = UDim2.fromOffset(11, 80), Size = UDim2.new(1, -22, 0, 28),
            BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 61,
        }, f)
        addCorner(spark, 4)
        local bars = {}
        for i = 1, SPARK_SAMPLES do
            bars[i] = create("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new((i - 1) / SPARK_SAMPLES, 0, 1, 0),
                Size = UDim2.new(1 / SPARK_SAMPLES, 0, 0, 0),
                BackgroundColor3 = Theme.Accent2, BorderSizePixel = 0, ZIndex = 62,
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
                    b.BackgroundColor3 = v >= 50 and Theme.Accent2
                        or (v >= 30 and Theme.Amber or Theme.Red)
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
                    local pinText = (Aim.pinned or Aim.pinnedPlayer) and "  PIN" or ""
                    lbl.Text = string.format("FPS %d   %dms\nPOS %s\nPLR %d/%s   %s%s",
                        math.floor(fps + 0.5), getPing(), posText,
                        #Players:GetPlayers(), tostring(Players.MaxPlayers), timeText, pinText)
                    onLbl.Text = "ON " .. (#active > 0 and table.concat(active, " ") or "-")
                    dot.BackgroundColor3 = fps >= 50 and Theme.Green
                        or (fps >= 30 and Theme.Amber or Theme.Red)
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
        accent = Theme.Accent,
        callback = function(on)
            Cfg.hud = on and true or false
            if HUD.frame then HUD.frame.Visible = Cfg.hud end
            scheduleSave()
        end,
    })

    createSection(toolsPage, "Automation")
    createToggle(toolsPage, {
        key = "autoClick", name = "Auto Clicker",
        desc = "Auto-activates your equipped tool",
        tip = "Fires your tool at the set CPS while enabled. Great for farming clicks and m1 games.",
        accent = Theme.Accent2,
        callback = featureCallback("Auto Clicker", Features.autoClick),
    })
    createSlider(toolsPage, {
        key = "autoClickCps", name = "Auto Clicker CPS", desc = "Clicks per second • 1 - 60",
        tip = "How many tool activations per second.",
        min = 1, max = 60, value = Cfg.autoClickCps, accent = Theme.Accent2,
        onChange = function(v) Cfg.autoClickCps = v; scheduleSave() end,
    })
    createToggle(toolsPage, {
        key = "antiAfk", name = "Anti-AFK",
        desc = "Dodges the 20-minute idle kick",
        tip = "Every ~4 minutes sends a harmless right-click and a microscopic camera nudge.",
        accent = Theme.Accent2,
        callback = featureCallback("Anti-AFK", Features.antiAfk),
    })

    createSection(toolsPage, "Players")
    local PlayerList = { card = nil, list = nil, spectating = nil, refreshAt = 0 }

    local plCard = createCard(toolsPage, "PlayerList", 240, Theme.Accent)
    plCard:SetAttribute("search", "player list goto teleport spectate follow names")
    cardLabels(plCard, "Player List", "Go = teleport to player • Spec = follow with camera")
    PlayerList.card = plCard
    local plList = create("ScrollingFrame", {
        Position = UDim2.new(0, 12, 0, 58), Size = UDim2.new(1, -24, 1, -70),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Hairline, CanvasSize = UDim2.new(), ZIndex = 4,
    }, plCard)
    local plLayout = create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, plList)
    track(plLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        plList.CanvasSize = UDim2.new(0, 0, 0, plLayout.AbsoluteContentSize.Y + 4)
    end))
    PlayerList.list = plList

    local function spectate(plr)
        local cam = workspace.CurrentCamera
        if not cam then return end
        if PlayerList.spectating == plr then
            PlayerList.spectating = nil
            local _, hum = getCharacterParts()
            if hum then cam.CameraSubject = hum end
            Toast.show("Spectate off", Theme.Off, 1.5)
            return
        end
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then Toast.show("Player has no character", Theme.Red, 1.8) return end
        PlayerList.spectating = plr
        cam.CameraSubject = hum
        Toast.show("Spectating " .. plr.DisplayName, Theme.Accent2, 1.8)
    end

    local function gotoPlayer(plr)
        local _, _, myHrp = getCharacterParts()
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (myHrp and hrp) then Toast.show("Can't teleport right now", Theme.Red, 1.8) return end
        myHrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
        myHrp.AssemblyLinearVelocity = Vector3.zero
        Speed.lastSafe = myHrp.Position
    end

    local function refreshPlayerList()
        if not plList.Parent then return end
        for _, c in ipairs(plList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local _, _, myHrp = getCharacterParts()
        local others = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then table.insert(others, plr) end
        end
        table.sort(others, function(a, b) return a.Name < b.Name end)
        if #others == 0 then
            create("TextLabel", {
                Size = UDim2.new(1, -6, 0, 24), BackgroundTransparency = 1,
                Text = "No other players.", TextSize = 12, TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, plList)
            return
        end
        for i, plr in ipairs(others) do
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local dist = (myHrp and hrp) and math.floor((hrp.Position - myHrp.Position).Magnitude) or 0
            local row = create("TextButton", {
                LayoutOrder = i, Size = UDim2.new(1, -6, 0, 30), BackgroundColor3 = Theme.Bg,
                Text = "", AutoButtonColor = false, ZIndex = 5,
            }, plList)
            addCorner(row, 7)
            local friendly = Cfg.teamCheck and LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team
            create("TextLabel", {
                Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -150, 1, 0),
                BackgroundTransparency = 1, Text = plr.DisplayName .. "  (" .. dist .. "m)",
                TextSize = 12, TextColor3 = friendly and Theme.Green or Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
            }, row)
            local function rowBtn(text, xOff, color, fn)
                local b = create("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0),
                    Size = UDim2.fromOffset(52, 22), BackgroundColor3 = Theme.Surface,
                    Text = text, TextSize = 11, AutoButtonColor = false, ZIndex = 6,
                }, row)
                addCorner(b, 6)
                addStroke(b, color, 1, 0.4)
                track(b.MouseButton1Click:Connect(function() Sfx.play("click"); guard("PlayerList " .. text, nil, fn) end))
            end
            rowBtn("Spec", -9, Theme.Accent2, function() spectate(plr) end)
            rowBtn("Go", -65, Theme.Accent, function() gotoPlayer(plr) end)
        end
    end
    PlayerList.refresh = refreshPlayerList

    Loop.register("Player List", function()
        refreshPlayerList()
    end, { interval = 1.2, keep = true })
    refreshPlayerList()

    createSection(toolsPage, "Profiles")
    for i = 1, 3 do createProfileCard(toolsPage, i) end

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
        Speed.lastSafe = hrp.Position
        Toast.show("Teleported to " .. w.name, Theme.Accent2, 1.8)
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
        Toast.show("Saved " .. Cfg.waypoints[key].name, Theme.Accent2, 1.8)
        return true
    end
    function Waypoints.delete(i)
        Cfg.waypoints[tostring(i)] = nil
        scheduleSave()
        for _, fn in ipairs(Waypoints.refreshers) do pcall(fn) end
        Toast.show("Cleared slot " .. i, Theme.Off, 1.5)
    end

    for i = 1, WAYPOINT_SLOTS do
        local card, cardStroke = createCard(toolsPage, "Waypoint" .. i, 60, Theme.Accent)
        card:SetAttribute("search", "waypoint teleport position slot save " .. i)
        card:SetAttribute("desc", "Waypoint slot " .. i)
        local title = create("TextBox", {
            Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(1, -180, 0, 22),
            BackgroundTransparency = 1, Text = "", TextSize = 15, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            PlaceholderText = "Slot " .. i, PlaceholderColor3 = Theme.TextFaint,
        }, card)
        local desc = create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -180, 0, 18),
            BackgroundTransparency = 1, Text = "", TextSize = 13, TextColor3 = Theme.TextDim,
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
                Size = UDim2.fromOffset(48, 30), BackgroundColor3 = Theme.Bg,
                Text = text, TextSize = 13, AutoButtonColor = false, ZIndex = 5,
            }, card)
            b:SetAttribute("NoBoost", true)
            addCorner(b, 8)
            addStroke(b, color, 1, 0.35)
            track(b.MouseEnter:Connect(function()
                Sfx.play("hover")
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
            end))
            track(b.MouseLeave:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Bg }):Play()
            end))
            track(b.MouseButton1Click:Connect(function()
                ripple(card, color); Sfx.play("click"); guard("Waypoint " .. text, nil, fn)
            end))
        end
        wpBtn("Del", -14, Theme.Red, function() Waypoints.delete(i) end)
        wpBtn("Go", -66, Theme.Accent2, function() Waypoints.go(i) end)
        wpBtn("Set", -118, Theme.Accent, function() Waypoints.set(i) end)
        addHoverFX(card, cardStroke)
        Tooltip.attach(card, "Set stores your current position. Go teleports you there. Click the name to rename it. Del clears the slot.")
    end

    -- ---------- Servers ----------
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

    local function hopScore(sv, limit)
        local playing = tonumber(sv.playing) or 0
        local maxP = math.max(tonumber(sv.maxPlayers) or 1, 1)
        local fill = playing / maxP
        local popScore = 1 - math.clamp(playing / math.max(limit, 1), 0, 1)
        local fillScore = 1 - math.clamp(fill, 0, 1)
        local freshBonus = (playing <= 4) and 1 or 0
        local fpsScore = 0.5
        if type(sv.fps) == "number" and sv.fps > 0 then
            fpsScore = math.clamp(sv.fps / 60, 0, 1)
        end
        local pingScore = 0.5
        if type(sv.ping) == "number" and sv.ping > 0 then
            pingScore = 1 - math.clamp(sv.ping / 200, 0, 1)
        end
        return popScore * 0.40 + fillScore * 0.25 + freshBonus * 0.20 + fpsScore * 0.10 + pingScore * 0.05
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
        Toast.show("Joining server with " .. tostring(sv.playing) .. " player(s)...", Theme.Accent2, 3)
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
        Toast.show("Searching servers...", Theme.Accent, 2)
        task.spawn(function()
            local servers, err = Hop.fetch()
            local pool = {}
            local minPop = (mode == "low" and Cfg.smartHop) and 0 or 1
            for _, sv in ipairs(servers) do
                if type(sv.id) == "string" and sv.id ~= game.JobId and not Hop.bad[sv.id]
                    and type(sv.playing) == "number" and type(sv.maxPlayers) == "number"
                    and sv.playing >= minPop and sv.playing < sv.maxPlayers then
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
                local under = {}
                for _, sv in ipairs(pool) do
                    if sv.playing <= limit then table.insert(under, sv) end
                end
                if #under == 0 then
                    Hop.busy = false
                    Toast.show("No server with " .. limit .. " or fewer players. Lowest is "
                        .. pool[1].playing .. " - raise the limit.", Theme.Red, 4.5)
                    return
                end
                if Cfg.smartHop then
                    local scored = {}
                    for _, sv in ipairs(under) do
                        table.insert(scored, { sv = sv, score = hopScore(sv, limit) + math.random() * 0.06 })
                    end
                    table.sort(scored, function(a, b) return a.score > b.score end)
                    for _, e in ipairs(scored) do table.insert(list, e.sv) end
                    local top = scored[1]
                    Toast.show(string.format("Smart matchmaking: freshest lobby %d/%d players (fresh score %.0f%%)",
                        top.sv.playing, top.sv.maxPlayers, top.score * 100), Theme.Accent, 3.5)
                else
                    list = under
                    for i = #list, 2, -1 do
                        local j = math.random(1, i)
                        list[i], list[j] = list[j], list[i]
                    end
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

    local serverCard = createCard(toolsPage, "ServerInfo", 60, Theme.Off)
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

    createToggle(toolsPage, {
        key = "smartHop", name = "Smart Matchmaking (Noob Farm)",
        desc = "Rank servers by freshness instead of pure lowest count",
        tip = "Scores every candidate lobby and picks the freshest one: low fill ratio, low population, tiny player clusters, healthy server fps and ping.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.smartHop = on and true or false; scheduleSave() end,
    })
    createInfo(toolsPage,
        "Matchmaking note: the public server list gives id, population, max players, fps and ping - not uptime or account ages. Smart Matchmaking ranks on those real signals.", Theme.Off)

    createSlider(toolsPage, {
        key = "hopMax", name = "Low-Pop Limit", desc = "Max players allowed in the server • 1 - 30",
        tip = "Join Low-Pop Server only picks servers with this many players or fewer.",
        min = 1, max = 30, value = Cfg.hopMax or 8, accent = Theme.Accent,
        onChange = function(v) Cfg.hopMax = v; scheduleSave() end,
    })
    createButton(toolsPage, "Join Low-Pop Server", Theme.Accent2,
        "Looks up this game's public servers, ranks them and teleports you to the freshest low-pop lobby.",
        function() startHop("low") end)
    createButton(toolsPage, "Join Random Server", Theme.Accent,
        "Teleports you to a random other public server that isn't full.",
        function() startHop("random") end)

    createSection(toolsPage, "Server Tools")
    local function joinServer(id)
        Hop.pending = id
        pcall(saveConfig)
        Toast.show("Joining server...", Theme.Accent2, 2.5)
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
        end)
        if not ok then Toast.show("Teleport failed", Theme.Red, 3) end
    end
    local function rejoin()
        pcall(saveConfig)
        Toast.show("Rejoining...", Theme.Accent, 2.5)
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
        Toast.show(ok and "JobId copied" or "Clipboard unavailable here", ok and Theme.Accent2 or Theme.Red)
    end
    createButton(toolsPage, "Rejoin Current Server", Theme.Accent,
        "Teleports you back into this exact server (or a fresh one if it is private).", rejoin)
    createButton(toolsPage, "Copy JobId", Theme.Accent2,
        "Copies this server's JobId to the clipboard (needs setclipboard).", copyJobId)

    local jobIdCard, jobIdStroke = createCard(toolsPage, "JoinByJobId", 94, Theme.Accent)
    jobIdCard:SetAttribute("search", "join by jobid job id server paste teleport")
    jobIdCard:SetAttribute("desc", "Join by JobId - paste a JobId from this game, then press Join")
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 22),
        BackgroundTransparency = 1, Text = "Join by JobId", TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, jobIdCard)
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 29), Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1, Text = "Paste a JobId from this game, then press Join",
        TextSize = 12, TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, jobIdCard)
    local jobIdBox = create("TextBox", {
        Position = UDim2.new(0, 14, 0, 54), Size = UDim2.new(1, -86, 0, 30),
        BackgroundColor3 = Theme.Bg, Text = "", ClearTextOnFocus = false,
        PlaceholderText = "XXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
        PlaceholderColor3 = Theme.TextFaint,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, jobIdCard)
    addCorner(jobIdBox, 8)
    addStroke(jobIdBox, Theme.Hairline, 1, 0.5)
    create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, jobIdBox)
    local joinIdBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 54),
        Size = UDim2.fromOffset(58, 30), BackgroundColor3 = Theme.Bg,
        Text = "Join", TextSize = 13, AutoButtonColor = false, ZIndex = 5,
    }, jobIdCard)
    addCorner(joinIdBtn, 8)
    addStroke(joinIdBtn, Theme.Accent2, 1, 0.3)
    track(joinIdBtn.MouseButton1Click:Connect(function()
        ripple(jobIdCard, Theme.Accent2); Sfx.play("click")
        local id = string.gsub(jobIdBox.Text, "^%s*(.-)%s*$", "%1")
        if id == "" then Toast.show("Enter a JobId first", Theme.Red, 2) return end
        joinServer(id)
    end))
    addHoverFX(jobIdCard, jobIdStroke)

    local ServerBrowser = { busy = false }
    local sbCard = createCard(toolsPage, "ServerBrowser", 250, Theme.Accent)
    sbCard:SetAttribute("search", "server browser list join players count rejoin fresh score")
    sbCard:SetAttribute("desc", "Server Browser - click a server to join it")
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -120, 0, 22),
        BackgroundTransparency = 1, Text = "Server Browser", TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sbCard)
    local sbRefresh = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.fromOffset(86, 28), BackgroundColor3 = Theme.Bg,
        Text = "Refresh", TextSize = 13, AutoButtonColor = false, ZIndex = 5,
    }, sbCard)
    addCorner(sbRefresh, 8)
    addStroke(sbRefresh, Theme.Accent2, 1, 0.3)
    local sbList = create("ScrollingFrame", {
        Position = UDim2.new(0, 12, 0, 40), Size = UDim2.new(1, -24, 1, -52),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Hairline, CanvasSize = UDim2.new(), ZIndex = 4,
    }, sbCard)
    local sbLayout = create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sbList)
    track(sbLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sbList.CanvasSize = UDim2.new(0, 0, 0, sbLayout.AbsoluteContentSize.Y + 4)
    end))
    local sbNote = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "Press Refresh to list public servers.",
        TextSize = 12, TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
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
            if #rows == 0 then
                sbNote.Text = err and ("Failed: " .. err) or "No servers found."
                return
            end
            if Cfg.smartHop then
                local limit = Cfg.hopMax or 8
                table.sort(rows, function(a, b)
                    local sa = hopScore(a, limit) + (a.playing > limit and -0.3 or 0)
                    local sb2 = hopScore(b, limit) + (b.playing > limit and -0.3 or 0)
                    return sa > sb2
                end)
            else
                table.sort(rows, function(a, b) return a.playing < b.playing end)
            end
            sbNote.Visible = false
            for n = 1, math.min(#rows, 60) do
                local sv = rows[n]
                local here = sv.id == game.JobId
                local ping = type(sv.ping) == "number" and (sv.ping .. "ms") or "--"
                local info = string.format("%d / %d players   %s", sv.playing, sv.maxPlayers, ping)
                if Cfg.smartHop then
                    info = string.format("fresh %.0f%%   ", hopScore(sv, Cfg.hopMax or 8) * 100) .. info
                end
                local row = create("TextButton", {
                    LayoutOrder = n, Size = UDim2.new(1, -6, 0, 27), BackgroundColor3 = Theme.Bg,
                    Text = string.format("%s%s   %s", here and "* " or "", info, string.sub(sv.id, 1, 6)),
                    TextSize = 12, AutoButtonColor = false, ZIndex = 5,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = here and Theme.Accent2 or Theme.Text,
                }, sbList)
                row:SetAttribute("NoBoost", true)
                create("UIPadding", { PaddingLeft = UDim.new(0, 9) }, row)
                addCorner(row, 7)
                track(row.MouseEnter:Connect(function()
                    Sfx.play("hover")
                    TweenService:Create(row, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
                end))
                track(row.MouseLeave:Connect(function()
                    TweenService:Create(row, HOVER_INFO, { BackgroundColor3 = Theme.Bg }):Play()
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
        ripple(sbCard, Theme.Accent2); Sfx.play("click"); guard("Server browser", nil, ServerBrowser.refresh)
    end))

    createSection(toolsPage, "Activity")
    local histCard = createCard(toolsPage, "History", 82, Theme.Off)
    histCard:SetAttribute("search", "notification history log activity toasts")
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1, Text = "Notification History", TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, histCard)
    local histBody = create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -28, 1, -42),
        BackgroundTransparency = 1, Text = "", TextSize = 12, TextColor3 = Theme.TextDim,
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
        local w = 400
        local abs = histCard.AbsoluteSize.X
        if abs > 60 then w = math.floor(abs / math.max(scale.Scale, 0.1)) - 32 end
        local _, h = measureText(txt, 12, math.max(w, 160))
        histCard.Size = UDim2.new(1, -10, 0, math.max(62, h + 46))
    end
    table.insert(NotifLog.listeners, refreshHistory)
    refreshHistory()
    createButton(toolsPage, "Clear Notification History", Theme.Off, "Wipes the log above.", function()
        table.clear(NotifLog.entries)
        refreshHistory()
    end)

    -- ======================= GAMES TAB =======================
    local MarketplaceService = game:GetService("MarketplaceService")

    local function fmtAgo(t)
        local d = os.time() - (t or 0)
        if d < 60 then return "just now"
        elseif d < 3600 then return math.floor(d / 60) .. " min ago"
        elseif d < 86400 then return math.floor(d / 3600) .. " h ago" end
        return math.floor(d / 86400) .. " d ago"
    end

    local function joinPlace(placeId, name)
        placeId = tonumber(placeId)
        if not placeId then return end
        if placeId == game.PlaceId then
            Toast.show("You are already in that game", Theme.Off, 2.5)
            return
        end
        pcall(saveConfig)
        Toast.show("Joining " .. tostring(name or placeId) .. "...", Theme.Accent2, 3)
        local ok = pcall(function() TeleportService:Teleport(placeId, LocalPlayer) end)
        if not ok then Toast.show("Couldn't start the teleport", Theme.Red, 3) end
    end

    local function makeList(parent, y)
        local frame = create("ScrollingFrame", {
            Position = UDim2.new(0, 12, 0, y), Size = UDim2.new(1, -24, 1, -(y + 12)),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Hairline, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4,
        }, parent)
        local layout = create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
        track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
        end))
        return frame
    end
    local function clearList(list)
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
    end
    local function listNote(list, text)
        create("TextLabel", {
            Size = UDim2.new(1, -6, 0, 28), BackgroundTransparency = 1, Text = text,
            TextSize = 13, TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        }, list)
    end

    local function makeGameRow(list, order, name, info, placeId)
        local row = create("TextButton", {
            LayoutOrder = order, Size = UDim2.new(1, -6, 0, 38), BackgroundColor3 = Theme.Bg,
            Text = "", AutoButtonColor = false, ZIndex = 5,
        }, list)
        addCorner(row, 8)
        local stroke = addStroke(row, Theme.Hairline, 1, 0.5)
        local nameLbl = create("TextLabel", {
            Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -134, 1, 0),
            BackgroundTransparency = 1, Text = name, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
        }, row)
        create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -11, 0, 0), Size = UDim2.new(0, 116, 1, 0),
            BackgroundTransparency = 1, Text = info or "", TextSize = 11, TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
        }, row)
        row.MouseEnter:Connect(function()
            Sfx.play("hover")
            TweenService:Create(row, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, HOVER_INFO, { BackgroundColor3 = Theme.Bg }):Play()
        end)
        local armed = false
        row.MouseButton1Click:Connect(function()
            Sfx.play("click")
            if armed then
                armed = false
                guard("Join game", nil, joinPlace, placeId, name)
                return
            end
            armed = true
            nameLbl.Text = "Tap again to join"
            nameLbl.TextColor3 = Theme.Accent2
            stroke.Color = Theme.Accent2
            task.delay(3, function()
                if armed and row.Parent then
                    armed = false
                    nameLbl.Text = name
                    nameLbl.TextColor3 = Theme.Text
                    stroke.Color = Theme.Hairline
                end
            end)
        end)
        return row
    end

    createSection(gamesPage, "Recent games")
    local recentCard = createCard(gamesPage, "RecentGames", 260, Theme.Accent)
    recentCard:SetAttribute("search", "recent games history join play last played")
    cardLabels(recentCard, "Recent games", "Games where you used the panel • tap twice to join", 28)
    local recentList = makeList(recentCard, 58)
    local function refreshRecent()
        if not recentList.Parent then return end
        clearList(recentList)
        local list = Cfg.recentGames
        if type(list) ~= "table" or #list == 0 then
            listNote(recentList, "Nothing yet. Games you open the panel in show up here.")
            return
        end
        for i, e in ipairs(list) do
            makeGameRow(recentList, i, e.name, e.id == game.PlaceId and "current game" or fmtAgo(e.t), e.id)
        end
    end

    createSection(gamesPage, "Find & join any game")
    local findCard = createCard(gamesPage, "GameSearch", 350, Theme.Accent2)
    findCard:SetAttribute("search", "search find game join place id link roblox any game")
    cardLabels(findCard, "Find a game", "Type a name, a Place ID or a roblox.com/games link", 28)
    local gameBox = create("TextBox", {
        Position = UDim2.new(0, 14, 0, 58), Size = UDim2.new(1, -112, 0, 32),
        BackgroundColor3 = Theme.Bg, Text = "", PlaceholderText = "Game name, Place ID or link...",
        PlaceholderColor3 = Theme.TextFaint, ClearTextOnFocus = false,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, findCard)
    addCorner(gameBox, 8)
    addStroke(gameBox, Theme.Hairline, 1, 0.5)
    create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, gameBox)
    local findBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 58),
        Size = UDim2.fromOffset(78, 32), BackgroundColor3 = Theme.Bg, Text = "Search",
        TextSize = 13, AutoButtonColor = false, ZIndex = 5,
    }, findCard)
    addCorner(findBtn, 8)
    addStroke(findBtn, Theme.Accent2, 1, 0.3)
    local resultList = makeList(findCard, 100)
    listNote(resultList, "Results appear here.")

    local function searchGames(query)
        local url = "https://apis.roblox.com/search-api/omni-search?searchQuery=" .. HttpService:UrlEncode(query)
            .. "&sessionId=" .. HttpService:GenerateGUID(false) .. "&pageType=all"
        local body = httpGet(url)
        if not body then return {}, "no HTTP access in this executor" end
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok or type(data) ~= "table" then return {}, "search failed or was blocked" end
        local found, seen = {}, {}
        local function walk(t, depth)
            if depth > 7 then return end
            local uid = tonumber(t.universeId)
            if uid and type(t.name) == "string" and not seen[uid] then
                seen[uid] = true
                table.insert(found, { uid = uid, name = t.name, place = tonumber(t.rootPlaceId),
                    players = tonumber(t.playerCount) })
            end
            if #t > 0 then
                for _, v in ipairs(t) do if type(v) == "table" then walk(v, depth + 1) end end
            else
                for _, v in pairs(t) do if type(v) == "table" then walk(v, depth + 1) end end
            end
        end
        walk(data, 0)
        if #found == 0 then return {}, "no games found" end
        local details, ids = {}, {}
        for i = 1, math.min(#found, 30) do table.insert(ids, tostring(found[i].uid)) end
        local body2 = httpGet("https://games.roblox.com/v1/games?universeIds=" .. table.concat(ids, ","))
        if body2 then
            local ok2, d2 = pcall(function() return HttpService:JSONDecode(body2) end)
            if ok2 and type(d2) == "table" and type(d2.data) == "table" then
                for _, g in ipairs(d2.data) do
                    if type(g) == "table" and tonumber(g.id) then details[tonumber(g.id)] = g end
                end
            end
        end
        local rows = {}
        for i = 1, math.min(#found, 30) do
            local e = found[i]
            local d = details[e.uid]
            local place = (d and tonumber(d.rootPlaceId)) or e.place
            local players = (d and tonumber(d.playing)) or e.players
            if place then
                table.insert(rows, { name = e.name, id = place, info = players and (players .. " playing") or "" })
            end
        end
        if #rows == 0 then return {}, "no joinable games found" end
        return rows, nil
    end

    local searchingGames = false
    local function runGameSearch()
        if searchingGames then return end
        local q = string.match(gameBox.Text, "^%s*(.-)%s*$") or ""
        if q == "" then
            Toast.show("Type a game name, Place ID or link first", Theme.Red, 2.5)
            return
        end
        searchingGames = true
        findBtn.Text = "..."
        task.spawn(function()
            clearList(resultList)
            listNote(resultList, "Searching...")
            local rows, err = {}, nil
            local pid = string.match(q, "/games/(%d+)") or string.match(q, "^(%d+)$")
            if pid then
                local name = "Place " .. pid
                pcall(function() name = MarketplaceService:GetProductInfo(tonumber(pid)).Name end)
                rows = { { name = name, id = tonumber(pid), info = "by Place ID" } }
            else
                rows, err = searchGames(q)
            end
            clearList(resultList)
            if #rows == 0 then
                listNote(resultList, err and ("Nothing: " .. err) or "No games found.")
            end
            for i, r in ipairs(rows) do makeGameRow(resultList, i, r.name, r.info, r.id) end
            findBtn.Text = "Search"
            searchingGames = false
        end)
    end
    track(findBtn.MouseButton1Click:Connect(function()
        Sfx.play("click")
        guard("Game search", nil, runGameSearch)
    end))
    track(gameBox.FocusLost:Connect(function(enter)
        if enter then guard("Game search", nil, runGameSearch) end
    end))
    Tooltip.attach(findCard, "Search any public game by name, or paste a Place ID / roblox.com/games link. Tap a result twice to teleport there.")

    local function recordCurrentGame()
        if game.PlaceId == 0 then return end
        local list = type(Cfg.recentGames) == "table" and Cfg.recentGames or {}
        local entry
        for i = #list, 1, -1 do
            if list[i].id == game.PlaceId then entry = table.remove(list, i) end
        end
        entry = entry or { id = game.PlaceId, name = game.Name }
        entry.t = os.time()
        table.insert(list, 1, entry)
        while #list > 25 do table.remove(list) end
        Cfg.recentGames = list
        scheduleSave()
        refreshRecent()
        task.spawn(function()
            local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
            if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
                entry.name = info.Name
                scheduleSave()
                refreshRecent()
            end
        end)
    end
    refreshRecent()
    guard("Recent games", nil, recordCurrentGame)

    -- ======================= SETTINGS TAB =======================
    createSection(settingsPage, "Appearance")
    local themeCard = createCard(settingsPage, "Theme", 104, Theme.Accent)
    themeCard:SetAttribute("search", "theme accent color colour appearance")
    cardLabels(themeCard, "Accent Theme", "Pick a color scheme • applies instantly")
    local swatchRow = create("Frame", {
        Position = UDim2.new(0, 14, 0, 64), Size = UDim2.new(1, -28, 0, 32),
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
            st.Color = sel and Theme.Text or Theme.Hairline
            st.Thickness = sel and 3 or 2
        end
    end
    for i, pr in ipairs(THEME_PRESETS) do
        local b = create("TextButton", {
            LayoutOrder = i, Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Theme.White,
            Text = "", AutoButtonColor = false, ZIndex = 5,
        }, swatchRow)
        b:SetAttribute("NoTheme", true)
        addCorner(b, 16)
        create("UIGradient", { Color = ColorSequence.new(pr.c1, pr.c2), Rotation = 45 }, b)
        swatches[pr.name] = create("UIStroke", {
            Color = Theme.Hairline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, b)
        Tooltip.attach(b, pr.name .. " theme")
        track(b.MouseButton1Click:Connect(function()
            applyTheme(pr.name)
            refreshSwatches()
            Toast.show(pr.name .. " theme applied", Theme.Accent, 1.8)
        end))
    end
    refreshSwatches()

    createSlider(settingsPage, {
        key = "uiScale", name = "UI Scale", desc = "Panel size in percent • 70 - 140",
        tip = "Scales the whole panel. Applies a moment after you stop dragging.",
        min = 70, max = 140, value = Cfg.uiScale, accent = Theme.Accent,
        onChange = function(v) Cfg.uiScale = v; applyUiScale(); scheduleSave() end,
    })
    local fontCard = createCard(settingsPage, "FontStyle", 104, Theme.Accent)
    fontCard:SetAttribute("search", "font text style readable bold sharp clean modern retro")
    cardLabels(fontCard, "Text Style", "Pick whichever font is easiest to read")
    local fontRow = create("Frame", {
        Position = UDim2.new(0, 14, 0, 64), Size = UDim2.new(1, -28, 0, 32),
        BackgroundTransparency = 1,
    }, fontCard)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, fontRow)
    local fontStrokes = {}
    local function refreshFontButtons()
        for name, st in pairs(fontStrokes) do
            st.Color = (name == Cfg.font) and Theme.Accent2 or Theme.Hairline
        end
    end
    local nFonts = #FONT_PRESETS
    for i, fp in ipairs(FONT_PRESETS) do
        local b = create("TextButton", {
            LayoutOrder = i, Size = UDim2.new(1 / nFonts, -8 * (nFonts - 1) / nFonts, 1, 0),
            BackgroundColor3 = Theme.Bg, Text = fp.name, TextSize = 13, Font = fp.font,
            AutoButtonColor = false, ZIndex = 5,
        }, fontRow)
        b:SetAttribute("NoFont", true)
        b:SetAttribute("NoBoost", true)
        addCorner(b, 8)
        fontStrokes[fp.name] = addStroke(b, Theme.Hairline, 1, 0.5)
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
        min = 0, max = 4, value = Cfg.textBoost, accent = Theme.Accent,
        onChange = function(v) Cfg.textBoost = v; applyTextStyle(); scheduleSave() end,
    })
    createToggle(settingsPage, {
        key = "toasts", name = "Notifications", desc = "Pop-up toasts • history always logs",
        tip = "Turns the corner pop-ups on or off. The Notification History in Tools keeps logging either way.",
        accent = Theme.Accent2,
        callback = function(on) Cfg.toasts = on and true or false; scheduleSave() end,
    })

    createSection(settingsPage, "Sound")
    createSlider(settingsPage, {
        key = "volume", name = "Master Volume", desc = "Hover, click and toggle sounds • 0 - 100",
        tip = "Controls every UI sound. Set to 0 to mute.",
        min = 0, max = 100, value = Cfg.volume, accent = Theme.Accent2,
        onChange = function(v) Cfg.volume = v; scheduleSave() end,
    })

    createSection(settingsPage, "Keybinds")
    for _, spec in ipairs({
        { id = "toggleUI", name = "Show / Hide Panel", desc = "Toggles the whole window" },
        { id = "minimize", name = "Minimize Panel", desc = "Collapse to the floating E button" },
        { id = "fly", name = "Toggle Fly", desc = "Quick on / off for Fly Hack Mode" },
        { id = "noclip", name = "Toggle Noclip", desc = "Quick on / off for Noclip" },
        { id = "freecam", name = "Toggle Freecam", desc = "Quick on / off for the free camera" },
        { id = "aimLock", name = "Toggle Aim Lock", desc = "Quick on / off for the auto-aim" },
        { id = "search", name = "Focus Command Bar", desc = "Jumps to the search / command box" },
    }) do
        createKeybindRow(settingsPage, spec)
    end

    createSection(settingsPage, "Data")
    createToggle(settingsPage, {
        key = "perGame", name = "Per-game settings",
        desc = "Separate config for each game (PlaceId)",
        tip = "Saves to EkantoConfig_" .. tostring(game.PlaceId) .. ".json and loads it here next time.",
        accent = Theme.Accent,
        callback = function(on, silent)
            Cfg.perGame = on and true or false
            scheduleSave()
            if not silent then
                Toast.show(on and "Per-game config on for this place" or "Per-game config off (global file only)", Theme.Accent)
            end
        end,
    })
    local resetArmed = false
    local function doReset()
        for _, k in ipairs(TOGGLE_KEYS) do pcall(function() UI.toggles[k].Set(false, true) end) end
        pcall(function() UI.sliders.speed.Set(SPEED_MIN) end)
        pcall(function() UI.sliders.flySpeed.Set(DEFAULT_CONFIG.flySpeed) end)
        pcall(function() UI.sliders.freecamSpeed.Set(60) end)
        pcall(function() UI.sliders.uiScale.Set(100) end)
        pcall(function() UI.sliders.hopMax.Set(8) end)
        pcall(function() UI.sliders.renderLevel.Set(0) end)
        pcall(function() UI.sliders.fpsCap.Set(0) end)
        pcall(function() UI.sliders.animCap.Set(0) end)
        pcall(function() UI.sliders.viewDist.Set(0) end)
        pcall(function() UI.sliders.timeOfDay.Set(0) end)
        pcall(function() UI.sliders.camFov.Set(0) end)
        pcall(function() UI.sliders.gravity.Set(0) end)
        pcall(function() UI.sliders.auraRadius.Set(AURA_RADIUS_DEFAULT) end)
        pcall(function() UI.sliders.hitboxScale.Set(2) end)
        pcall(function() UI.sliders.autoClickCps.Set(10) end)
        pcall(function() UI.sliders.espDistance.Set(0) end)
        pcall(function() UI.sliders.jumpPower.Set(0) end)
        pcall(function() UI.toggles.liteUI.Set(false, true) end)
        pcall(function() UI.toggles.perfGuard.Set(false, true) end)
        pcall(function() UI.sliders.guardFps.Set(30) end)
        pcall(function() UI.sliders.volume.Set(40) end)
        pcall(function() UI.toggles.aimHead.Set(true, true) end)
        pcall(function() UI.toggles.netSleep.Set(true, true) end)
        pcall(function() UI.toggles.smartHop.Set(true, true) end)
        pcall(function() UI.toggles.auraPlayers.Set(false, true) end)
        pcall(function() UI.toggles.fallRescue.Set(true, true) end)
        pcall(function() UI.toggles.antiFling.Set(true, true) end)
        pcall(function() UI.toggles.fovCircle.Set(true, true) end)
        pcall(function() UI.toggles.teamCheck.Set(false, true) end)
        pcall(function() UI.toggles.aimPredict.Set(false, true) end)
        pcall(function() UI.toggles.hitbox.Set(false, true) end)
        pcall(function() UI.toggles.autoClick.Set(false, true) end)
        pcall(function() UI.toggles.freecam.Set(false, true) end)
        pcall(function() UI.toggles.autoJump.Set(false, true) end)
        pcall(function() UI.toggles.espBox.Set(false, true) end)
        pcall(function() UI.sliders.aimFov.Set(25) end)
        pcall(function() UI.sliders.aimRange.Set(150) end)
        pcall(function() UI.sliders.aimSmooth.Set(8) end)
        pcall(function() UI.sliders.microStep.Set(20) end)
        pcall(function() UI.sliders.flySpoof.Set(100) end)
        pcall(function() UI.sliders.speedBrake.Set(SPEED_BRAKE_DEFAULT) end)
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
        applyTheme("Aurora")
        refreshSwatches()
        Cfg.panelW, Cfg.panelH = PANEL_SIZE.X.Offset, PANEL_SIZE.Y.Offset
        Cfg.posX, Cfg.posY = 0, 0
        PanelSize = PANEL_SIZE
        if not Runtime.minimized then
            TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Size = PANEL_SIZE, Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
        end
        scheduleSave()
        Toast.show("Everything reset to default", Theme.Accent2)
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
            Toast.show("Locked. Key required on next run.", Theme.Accent)
        end)
    createButton(settingsPage, "Copy Settings JSON", Theme.Accent2,
        "Copies your current settings to the clipboard (if your executor supports it).",
        function()
            pcall(saveConfig)
            local ok = pcall(function() setclipboard(HttpService:JSONEncode(Cfg)) end)
            Toast.show(ok and "Settings copied to clipboard" or "Clipboard unavailable here",
                ok and Theme.Accent2 or Theme.Red)
        end)

    local importCard, importStroke = createCard(settingsPage, "ImportConfig", 112, Theme.Accent2)
    importCard:SetAttribute("search", "import config settings paste load json string restore")
    importCard:SetAttribute("desc", "Import Settings - paste a copied config string then press Import")
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1, Text = "Import Settings", TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, importCard)
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(1, -28, 0, 16),
        BackgroundTransparency = 1, Text = "Paste a copied config (encrypted or JSON), then Import",
        TextSize = 12, TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
    }, importCard)
    local importBox = create("TextBox", {
        Position = UDim2.new(0, 14, 0, 48), Size = UDim2.new(1, -96, 0, 30),
        BackgroundColor3 = Theme.Bg, Text = "", ClearTextOnFocus = false,
        PlaceholderText = "EK2:... or {json}", PlaceholderColor3 = Theme.TextFaint,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    }, importCard)
    addCorner(importBox, 8)
    addStroke(importBox, Theme.Hairline, 1, 0.5)
    create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, importBox)
    local importBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 48),
        Size = UDim2.fromOffset(68, 30), BackgroundColor3 = Theme.Bg,
        Text = "Import", TextSize = 13, AutoButtonColor = false, ZIndex = 5,
    }, importCard)
    addCorner(importBtn, 8)
    addStroke(importBtn, Theme.Accent2, 1, 0.3)
    track(importBtn.MouseButton1Click:Connect(function()
        ripple(importCard, Theme.Accent2); Sfx.play("click")
        local raw = string.gsub(importBox.Text, "^%s*(.-)%s*$", "%1")
        if raw == "" then Toast.show("Paste a config string first", Theme.Red, 2) return end
        local data = decodeConfig(raw)
        if not data then Toast.show("Invalid config string", Theme.Red, 2.5) return end
        applyConfigData(data)
        applyConfigToUI()
        pcall(setThemeColors, Cfg.theme)
        applyTheme(Cfg.theme)
        refreshSwatches()
        Theme.Font = fontPreset(Cfg.font).font
        applyTextStyle(true)
        Cfg.freecam = false
        pcall(function() UI.sliders.uiScale.Set(Cfg.uiScale) end)
        scheduleSave()
        Toast.show("Config imported", Theme.Accent2, 2.5)
    end))
    addHoverFX(importCard, importStroke)

    createInfo(settingsPage,
        "Tips: drag the header or the logo to move the panel, drag the bottom-right corner to resize it, and use the search box at the top to filter features across every page.",
        Theme.Off)

    -- ======================= SEARCH =======================
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
            Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 46,
        }, body)
        for _, ln in ipairs({ { 4, 7 }, { 8, 13 }, { 12, 19 } }) do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(20 - ln[1], 20 - ln[1]),
                Size = UDim2.fromOffset(ln[2], 2), Rotation = -45,
                BackgroundColor3 = Theme.TextFaint, BorderSizePixel = 0, ZIndex = 47,
            }, grip)
        end
        local MIN_W, MIN_H, MAX_W, MAX_H = 680, 380, 1000, 800
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

    track(ScreenGui.DescendantAdded:Connect(function(d) pcall(styleText, d) end))
    applyTextStyle(true)

    UI.toggles.hud.Set(Cfg.hud == true, true)
    UI.toggles.toasts.Set(Cfg.toasts ~= false, true)
    UI.toggles.perGame.Set(Cfg.perGame == true, true)

    FovCircle.ensure()

    applyConfigToUI()
    selectTab("Movement")

    -- ---------- sidebar dot pulse ----------
    task.spawn(function()
        local on = true
        while Runtime.alive and sidebar.Parent do
            TweenService:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { BackgroundTransparency = on and 0.35 or 0 }):Play()
            TweenService:Create(avDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { BackgroundTransparency = on and 0.35 or 0 }):Play()
            on = not on
            task.wait(0.9)
        end
    end)

    -- ---------- Minimize ----------
    local MINI_TWEEN = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local minToken = 0
    local setMinimized

    local function fadeMini(m, visible, duration)
        pcall(function()
            local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(m, info, {
                BackgroundTransparency = visible and 0.06 or 1,
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
            BackgroundColor3 = Theme.Surface, BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "E", TextSize = 24, TextTransparency = 1,
            AutoButtonColor = false, ZIndex = 50,
        }, ScreenGui)
        addCorner(m, 14)
        create("UIGradient", { Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = 45 }, m)
        local stroke = addStroke(m, Theme.Accent, 1.5, 0)
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

    local function fadeBody(target, duration)
        if not (body and body.Parent) then return end
        local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(body, info, { GroupTransparency = target }):Play()
        TweenService:Create(bgFill, info, { BackgroundTransparency = target }):Play()
        TweenService:Create(bgStroke, info, { Transparency = 0.4 + 0.6 * target }):Play()
        TweenService:Create(bgBorder, info, { Transparency = 0.15 + 0.85 * target }):Play()
    end

    local function fadeShadow(scaleFade, duration)
        for _, s in ipairs(shadowParts) do
            local target = s.base + (1 - s.base) * scaleFade
            TweenService:Create(s.f, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = target }):Play()
        end
    end

    setMinimized = function(state)
        if Runtime.minimized == state then return end
        Runtime.minimized = state
        minToken += 1
        local myToken = minToken
        Tooltip.hide()
        if state then
            fadeBody(1, 0.22)
            fadeShadow(1, 0.26)
            local pos = Main.Position + miniDelta()
            local tw = TweenService:Create(Main, MINI_TWEEN, { Size = MINI_SIZE, Position = pos })
            tw.Completed:Connect(function()
                if myToken ~= minToken or not Runtime.minimized or not Main.Parent then return end
                Main.Visible = false
                local m = createMini(pos)
                if not mainShown then m.Visible = false end
            end)
            tw:Play()
        else
            local pos = Main.Position
            if MiniState.frame then pos = MiniState.frame.Position end
            closeMini()
            Main.Position = pos
            Main.Size = MINI_SIZE
            Main.Visible = mainShown
            body.GroupTransparency = 1
            bgFill.BackgroundTransparency = 1
            bgStroke.Transparency = 1
            bgBorder.Transparency = 1
            fadeShadow(1, 0.2)
            fadeBody(0, 0.3)
            fadeShadow(0, 0.34)
            TweenService:Create(Main, MINI_TWEEN, { Size = PanelSize, Position = pos - miniDelta() }):Play()
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
        if input.UserInputType == Enum.UserInputType.MouseButton3 then
            if Cfg.aimLock and not UserInputService:GetFocusedTextBox() then
                guard("Aim pin", nil, Aim.pinUnderMouse)
            end
            return
        end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local code = input.KeyCode
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
        elseif code == Rebind.codeOf("freecam") then
            pcall(function() UI.toggles.freecam.Toggle() end)
        elseif code == Rebind.codeOf("aimLock") then
            pcall(function() UI.toggles.aimLock.Toggle() end)
        elseif code == Rebind.codeOf("search") then
            if mainShown and not Runtime.minimized then
                task.defer(function()
                    searchBox:CaptureFocus()
                    RunService.Heartbeat:Wait()
                    searchBox.Text = ""
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
        aim = "aimLock", aimlock = "aimLock", uname = "espUsername", username = "espUsername",
        sleep = "netSleep", netsleep = "netSleep", legacy = "speedLegacy", smart = "smartHop",
        auraplayers = "auraPlayers", rescue = "fallRescue", team = "teamCheck", fov = "fovCircle",
        hitbox = "hitbox", click = "autoClick", autoclick = "autoClick", cam = "freecam",
        freecam = "freecam", jump = "autoJump", fling = "antiFling", box = "espBox", lead = "aimPredict",
    }
    local function runToggle(key, arg)
        local t = UI.toggles[key]
        if not t then return end
        if arg == "on" then t.Set(true, false)
        elseif arg == "off" then t.Set(false, false)
        else t.Toggle() end
    end
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
                        Toast.show(pr.name .. " theme applied", Theme.Accent, 1.8)
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
        elseif cmd == "pin" then
            return function() Aim.pinUnderMouse() end
        elseif cmd == "unpin" then
            return function() Aim.clearPin() end
        elseif cmd == "gotocam" then
            return function() Freecam.goto() end
        elseif (cmd == "speed" or cmd == "flyspeed") and tonumber(a1) then
            return function() UI.sliders[cmd == "speed" and "speed" or "flySpeed"].Set(tonumber(a1)) end
        elseif cmd == "aimfov" and tonumber(a1) then
            return function() UI.sliders.aimFov.Set(tonumber(a1)) end
        elseif cmd == "aimrange" and tonumber(a1) then
            return function() UI.sliders.aimRange.Set(tonumber(a1)) end
        elseif cmd == "micro" and tonumber(a1) then
            return function() UI.sliders.microStep.Set(tonumber(a1)) end
        elseif cmd == "brake" and tonumber(a1) then
            return function() UI.sliders.speedBrake.Set(tonumber(a1)) end
        elseif cmd == "aura" and tonumber(a1) then
            return function() UI.sliders.auraRadius.Set(tonumber(a1)) end
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
                Toast.show("Commands: fly god invis esp aura noclip afk fog bright fps hud aim team fov hitbox click cam jump fling box lead uname sleep smart legacy rescue • theme <name> • hop [random] • rejoin • jobid • servers • pin • unpin • gotocam • speed N • brake N • aura N • aimfov N • aimrange N • micro N • tp N • setwp N • profile N", Theme.Accent, 6)
            end
        end
        return nil
    end
    track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchBox.TextColor3 = resolveCommand(searchBox.Text) and Theme.Accent2 or Theme.Text
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

    -- ======================= CONTEXT MENU =======================
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
                Toast.show("Press a new key for " .. rebindAction .. " (Esc cancels)", Theme.Accent, 3)
            end })
        end
        for i = 1, 3 do
            table.insert(items, { "Save to profile " .. i, function() ProfileApi.save(i) end })
        end
        table.insert(items, { "Copy description", function()
            local ok = pcall(function() setclipboard(card:GetAttribute("desc") or card.Name) end)
            Toast.show(ok and "Description copied" or "Clipboard unavailable here", ok and Theme.Accent2 or Theme.Red, 1.8)
        end })

        local root = create("TextButton", {
            Name = "ContextMenu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 96,
        }, ScreenGui)
        ctx.gui = root
        track(root.MouseButton1Click:Connect(closeContext))
        track(root.MouseButton2Click:Connect(closeContext))
        local w, h = 184, #items * 30 + 10
        local m = UserInputService:GetMouseLocation()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local menu = create("Frame", {
            Position = UDim2.fromOffset(math.clamp(m.X, 4, vp.X - w - 4), math.clamp(m.Y, 4, vp.Y - h - 4)),
            Size = UDim2.fromOffset(w, h), BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, ZIndex = 97,
        }, root)
        addCorner(menu, 10)
        addStroke(menu, Theme.Hairline, 1, 0.3)
        for i, it in ipairs(items) do
            local b = create("TextButton", {
                Position = UDim2.fromOffset(5, 5 + (i - 1) * 30), Size = UDim2.new(1, -10, 0, 28),
                BackgroundColor3 = Theme.Surface, Text = it[1], TextSize = 13, AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 98,
            }, menu)
            b:SetAttribute("NoBoost", true)
            create("UIPadding", { PaddingLeft = UDim.new(0, 9) }, b)
            addCorner(b, 7)
            track(b.MouseEnter:Connect(function()
                Sfx.play("hover")
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
            end))
            track(b.MouseLeave:Connect(function()
                TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Surface }):Play()
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
    Toast.show("EKANTO v2.3 loaded. " .. Cfg.keys.toggleUI .. " hides, " .. Cfg.keys.minimize
        .. " minimizes, " .. Cfg.keys.fly .. " flies, " .. Cfg.keys.freecam .. " freecam, "
        .. (Cfg.keys.aimLock or "LeftAlt") .. " aims.",
        Theme.Accent2, 4.5)
end

-- ============================================================
-- 10. VERIFICATION GATE  (premium animated backdrop)
-- ============================================================
local gateToken = 0

local function buildGateBackdrop(parent)
    local clip = create("Frame", {
        Name = "Backdrop", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0,
        ClipsDescendants = true, ZIndex = 0,
    }, parent)
    addCorner(clip, 16)

    -- animated aurora
    local aurora = create("Frame", {
        Size = UDim2.fromScale(1.8, 1.8), Position = UDim2.fromScale(-0.4, -0.4),
        BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 0,
    }, clip)
    aurora:SetAttribute("NoTheme", true)
    local agrad = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Theme.Bg),
            ColorSequenceKeypoint.new(0.35, Theme.OnAccent),
            ColorSequenceKeypoint.new(0.62, Theme.Bg2),
            ColorSequenceKeypoint.new(1.0, Theme.Bg),
        }),
        Rotation = 0,
    }, aurora)

    -- glow orbs
    local orbs = {}
    for i = 1, 3 do
        local orb = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(140, 140),
            BackgroundColor3 = (i % 2 == 0) and Theme.Accent or Theme.Accent2,
            BackgroundTransparency = 0.84, BorderSizePixel = 0, ZIndex = 0,
        }, clip)
        addCorner(orb, 999)
        table.insert(orbs, orb)
    end

    -- moving grid
    local grid = create("Frame", {
        Size = UDim2.new(1, 60, 1, 60), Position = UDim2.fromOffset(-30, -30),
        BackgroundTransparency = 1, ZIndex = 0,
    }, clip)
    for i = 0, 9 do
        create("Frame", {
            Position = UDim2.new(i / 9, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
            BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 0,
        }, grid)
    end
    for i = 0, 11 do
        create("Frame", {
            Position = UDim2.new(0, 0, i / 11, 0), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.Accent2, BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 0,
        }, grid)
    end

    -- floating particles
    local partLayer = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, clip)
    local function spawnParticle()
        if not partLayer.Parent then return end
        local size = math.random(2, 4)
        local p = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(math.random(), 1.08),
            Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = (math.random() < 0.5) and Theme.Accent or Theme.Accent2,
            BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 0,
        }, partLayer)
        addCorner(p, 999)
        local dur = math.random(30, 70) / 10
        TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
            Position = UDim2.fromScale(math.clamp(p.Position.X.Scale + (math.random(-15, 15) / 100), 0, 1), -0.08),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(dur, function() pcall(function() p:Destroy() end) end)
    end
    for _ = 1, 14 do
        task.delay(math.random() * 40 / 10, spawnParticle)
    end

    local tok = gateToken
    task.spawn(function()
        local t = 0
        while parent.Parent and gateToken == tok and Runtime.alive do
            t += 0.05
            pcall(function()
                agrad.Rotation = (t * 12) % 360
                grid.Position = UDim2.fromOffset(-30 + (t * 8) % 30, -30 + (t * 6) % 30)
                for i, orb in ipairs(orbs) do
                    orb.Position = UDim2.fromScale(
                        0.5 + 0.35 * math.sin(t * (0.3 + i * 0.12) + i),
                        0.5 + 0.35 * math.cos(t * (0.24 + i * 0.1) + i * 1.7))
                end
            end)
            task.wait(0.05)
        end
    end)
    task.spawn(function()
        while parent.Parent and gateToken == tok and Runtime.alive do
            spawnParticle()
            task.wait(0.22)
        end
    end)
    return clip
end

local function buildGate()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local fit = math.clamp(math.min((vp.X - 40) / 440, (vp.Y - 40) / 500), 0.55, 1)

    local GATE_W, GATE_H = 420, 480

    local KeyFrame = create("Frame", {
        Name = "KeyFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(GATE_W, GATE_H),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
    }, ScreenGui)
    addCorner(KeyFrame, 16)
    addStroke(KeyFrame, Theme.Hairline, 1, 0.4)
    local gateBorder = addGradientBorder(KeyFrame, 1.4)
    local basePos = KeyFrame.Position

    buildGateBackdrop(KeyFrame)

    create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1, Text = "EKANTO // SECURE SHELL", TextSize = 16, ZIndex = 2,
    }, KeyFrame)
    local shellSub = create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1, Text = "v2.3  •  PREMIUM ACCESS", TextSize = 10,
        TextColor3 = Theme.TextFaint, ZIndex = 2,
    }, KeyFrame)
    shellSub:SetAttribute("NoBoost", true)

    local scanline = create("Frame", {
        Position = UDim2.new(0, 14, 0, -2),
        Size = UDim2.new(1, -28, 0, 2),
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.5,
        BorderSizePixel = 0, ZIndex = 3,
    }, KeyFrame)
    addCorner(scanline, 1)

    local bootHolder = create("Frame", {
        Position = UDim2.new(0, 26, 0, 62),
        Size = UDim2.new(1, -52, 0, 58),
        BackgroundTransparency = 1, ZIndex = 2,
    }, KeyFrame)
    local bootLines = {
        "> EKANTO SECURE SHELL V2.3",
        "> SWEPT COLLISION MODULE ... OK",
        "> AUTH REQUIRED // AWAITING KEY",
    }

    local noiseLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 26, 1, -12),
        Size = UDim2.new(1, -52, 0, 14),
        BackgroundTransparency = 1, Text = "",
        TextSize = 10, TextColor3 = Theme.TextFaint,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
    }, KeyFrame)

    local inputBox = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 130),
        Size = UDim2.new(1, -52, 0, 44),
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, Visible = false, ZIndex = 2,
    }, KeyFrame)
    addCorner(inputBox, 10)
    local inputStroke = addStroke(inputBox, Theme.Hairline, 1, 0.3)
    local inputLabel = create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = "",
        TextSize = 20, TextColor3 = Theme.Accent2,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    }, inputBox)
    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(44, 16), BackgroundTransparency = 1,
        Text = "KEY", TextSize = 10, TextColor3 = Theme.TextFaint,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3,
    }, inputBox)

    local hintLabel = create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 180), Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
        Text = "keyboard or tap the keypad below",
        TextSize = 10, TextColor3 = Theme.TextFaint,
        Visible = false, ZIndex = 2,
    }, KeyFrame)
    local statusLabel = create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 196), Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1, Text = "",
        TextSize = 13, TextColor3 = Theme.Accent, ZIndex = 2,
    }, KeyFrame)

    local keypad = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 222),
        Size = UDim2.new(1, -52, 0, 154),
        BackgroundTransparency = 1, Visible = false, ZIndex = 2,
    }, KeyFrame)
    create("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -6, 0, 33),
        CellPadding = UDim2.fromOffset(7, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, keypad)

    local verifyBtn = create("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 386),
        Size = UDim2.new(1, -52, 0, 40),
        BackgroundColor3 = Theme.Surface, Text = "VERIFY",
        TextSize = 16, AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 2,
    }, KeyFrame)
    addCorner(verifyBtn, 10)
    local vStroke = addStroke(verifyBtn, Theme.Accent, 1.2, 0)
    track(verifyBtn.MouseEnter:Connect(function()
        TweenService:Create(verifyBtn, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
        TweenService:Create(vStroke, HOVER_INFO, { Color = Theme.Accent2 }):Play()
    end))
    track(verifyBtn.MouseLeave:Connect(function()
        TweenService:Create(verifyBtn, HOVER_INFO, { BackgroundColor3 = Theme.Surface }):Play()
        TweenService:Create(vStroke, HOVER_INFO, { Color = Theme.Accent }):Play()
    end))

    local padKeys = { "1","2","3","4","5","6","7","8","9","CLR","0","DEL" }
    for i, label in ipairs(padKeys) do
        local b = create("TextButton", {
            LayoutOrder = i, Text = label, TextSize = 15,
            BackgroundColor3 = Theme.Surface, AutoButtonColor = false, BorderSizePixel = 0,
            TextColor3 = (label == "CLR" or label == "DEL") and Theme.Accent2 or Theme.Text, ZIndex = 3,
        }, keypad)
        addCorner(b, 9)
        addStroke(b, Theme.Hairline, 1, 0.6)
        track(b.MouseEnter:Connect(function()
            TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Surface2 }):Play()
        end))
        track(b.MouseLeave:Connect(function()
            TweenService:Create(b, HOVER_INFO, { BackgroundColor3 = Theme.Surface }):Play()
        end))
        track(b.MouseButton1Click:Connect(function()
            if label == "CLR" then clearAll()
            elseif label == "DEL" then backspace()
            else pushChar(label) end
        end))
    end

    local buffer = ""
    local MAX_LEN = 12
    local inputReady = false
    local busy = false
    local attempts = 0

    local function renderInput(cursorOn)
        inputLabel.Text = string.rep("*", #buffer) .. (cursorOn and "_" or " ")
    end
    renderInput(true)

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

    -- animated glow border pulse
    task.spawn(function()
        local tok = gateToken
        local on = true
        while KeyFrame.Parent and gateToken == tok and Runtime.alive do
            TweenService:Create(gateBorder, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Transparency = on and 0.05 or 0.4, Thickness = on and 1.8 or 1.2 }):Play()
            on = not on
            task.wait(1.4)
        end
    end)

    task.spawn(function()
        local tok = gateToken
        while KeyFrame and KeyFrame.Parent and gateToken == tok do
            scanline.Position = UDim2.new(0, 14, 0, -2)
            local tw = TweenService:Create(scanline,
                TweenInfo.new(2.4, Enum.EasingStyle.Linear),
                { Position = UDim2.new(0, 14, 1, 0) })
            tw:Play()
            tw.Completed:Wait()
        end
    end)

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

    task.spawn(function()
        local tok = gateToken
        local on = true
        while KeyFrame and KeyFrame.Parent and gateToken == tok do
            if inputReady and not busy then renderInput(on) end
            on = not on
            task.wait(0.4)
        end
    end)

    task.spawn(function()
        task.wait(0.4)
        for i, line in ipairs(bootLines) do
            if not (KeyFrame and KeyFrame.Parent) then return end
            local lbl = create("TextLabel", {
                Position = UDim2.new(0, 0, 0, (i - 1) * 19),
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1, Text = "",
                TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
                TextColor3 = (i == #bootLines) and Theme.Accent2 or Theme.TextDim,
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
            statusLabel.TextColor3 = Theme.Accent2
            task.spawn(function()
                pcall(scramble, statusLabel, "ACCESS GRANTED // WELCOME, OPERATOR", 0.7)
                TweenService:Create(inputStroke, TweenInfo.new(0.3), { Color = Theme.Accent2, Transparency = 0 }):Play()
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
            TweenService:Create(inputStroke, TweenInfo.new(0.1), { Color = Theme.Red, Transparency = 0 }):Play()
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
                    TweenService:Create(inputStroke, TweenInfo.new(0.4), { Color = Theme.Hairline }):Play()
                end)
                buffer = ""
                pcall(renderInput, true)
                task.wait(0.3)
                busy = false
            end)
        end
    end

    track(verifyBtn.MouseButton1Click:Connect(attemptVerify))

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

    local kScale = create("UIScale", { Scale = ENTRY_START_SCALE * fit }, KeyFrame)
    TweenService:Create(kScale, ENTRY_INFO, { Scale = fit }):Play()
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
        Cfg.textBoost = 2
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

do
    local t = 0
    Loop.register("Visuals", function(dt)
        t += dt
        if Cfg.liteUI then
            for _, step in pairs(countups) do pcall(step, dt) end
            return
        end
        local speedMul = 1
        if Main and Main.Visible then
            pcall(function()
                local m = UserInputService:GetMouseLocation()
                local center = Main.AbsolutePosition + Main.AbsoluteSize * 0.5
                local d = (m - center).Magnitude
                speedMul = 1 + math.clamp(1 - d / 600, 0, 1) * 2.5
            end)
        end
        local gradT = t * 70 * speedMul
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
    Loop.register("FOV circle", FovCircle.refresh, { interval = 0.05, keep = true })
    Loop.start()
end

do
    local age = type(Cfg.verifiedAt) == "number" and (os.time() - Cfg.verifiedAt) or math.huge
    if age >= 0 and age < KEY_REMEMBER_SECONDS then
        local ok, err = pcall(buildMain)
        if not ok then
            warn("[EKANTO] buildMain failed: " .. tostring(err))
            buildGate()
        end
    else
        buildGate()
    end
end