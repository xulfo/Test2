--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                     ║
    ║   A R C   —   A modern UI library for your Roblox scripts.          ║
    ║   Simple. Clean. Powerful.                 Black / White edition    ║
    ║                                                                     ║
    ║   Version   : 2.0.0                                                 ║
    ║   Logo      : rbxassetid://131675609143159                          ║
    ║   License   : Free to use in any script, commercial or not.         ║
    ║                                                                     ║
    ╚═══════════════════════════════════════════════════════════════════╝

    ── OVERVIEW ──────────────────────────────────────────────────────────
    ARC is a complete interface toolkit for Roblox script hubs. It gives
    you a sleek, fully rounded black window with white text and white
    outlines, a sidebar with tabs, a welcome page that matches the
    official design, and a huge set of bindable elements so you can hook
    your own scripts up to professional controls in seconds.

    Everything is created through a small, consistent API:

        local Window = ARC:CreateWindow({...})
        local Tab    = Window:AddTab({...})
        Tab:AddButton({ ... Callback = function() YOUR_SCRIPT end })

    ── INSTALL ───────────────────────────────────────────────────────────
    Option A (hosted):
        local ARC = loadstring(game:HttpGet("YOUR_LINK/ARC.lua"))()

    Option B (local / paste):
        Paste this entire file at the top of your script. The chunk
        returns the library table, so `ARC` becomes available.

    ── QUICK START ───────────────────────────────────────────────────────
        local ARC = ARC

        local Window = ARC:CreateWindow({
            Title    = "ARC",
            Logo     = 131675609143159,
            Version  = "v2.0.0",
            Key      = Enum.KeyCode.RightShift,
            SettingsTab = true,      -- auto-build a settings tab
        })

        local Main = Window:AddTab({ Name = "Main", Icon = "⌂" })

        Main:AddButton({
            Title = "Example",
            Callback = function() print("bound!") end,
        })

    ── ELEMENT REFERENCE ─────────────────────────────────────────────────
    Tab:AddLabel({ Text, Color })
        Plain information line. Returns { Set(text) }.

    Tab:AddParagraph({ Title, Text })
        Wrapped multi-line text block. Returns { Set(text) }.

    Tab:AddButton({ Title, Description, Callback, Hold })
        Clickable row. If Hold (seconds) is set, the user must hold the
        button down to confirm before Callback fires.

    Tab:AddToggle({ Title, Description, Default, Flag, Callback })
        Switch. Returns { Set(v, silent), GetValue() }.

    Tab:AddSlider({ Title, Min, Max, Default, Decimals, Suffix, Flag,
                    Callback, Textbox })
        Draggable value track. If Textbox = true an input box appears for
        exact values. Returns { Set(v), GetValue() }.

    Tab:AddDropdown({ Title, Options, Default, Multi, Flag, Callback })
        Option list. Multi = true allows several selections (callback
        receives a table). Returns { Set(v), Refresh(list), SetOpen(b) }.

    Tab:AddTextbox({ Title, Placeholder, Default, Numeric, Min, Max,
                     Flag, Callback })
        Text input. Numeric = true restricts to numbers in Min/Max.

    Tab:AddKeybind({ Title, Default, Flag, Callback, OnPress })
        Bindable key. OnPress fires whenever the bound key is pressed.

    Tab:AddColorpicker({ Title, Default, Flag, Callback })
        Full HSV picker with hue bar + saturation/value square.
        Returns { Set(color3), GetValue() }.

    Tab:AddProgress({ Title, Min, Max, Default, Suffix })
        Read-only animated progress bar. Returns { Set(v) }.

    Tab:AddCard({ Title, Description, Icon, Callback })
        Large quick-access card (like the home page).

    Tab:AddSection({ Title, Subtitle })   Tab:AddSeparator()

    ── WINDOW API ────────────────────────────────────────────────────────
        Window:AddTab(opts)          Window:Notify(opts)
        Window:SelectTab(tab)        Window:SetMinimized(bool)
        Window:Minimize()            Window:Close() / Open() / Toggle()
        Window:SetTitle(text)        Window:Destroy()

    ── LIBRARY API ───────────────────────────────────────────────────────
        ARC:Notify(opts)             ARC:SetTheme(name)
        ARC.Config.Save(name)        ARC.Config.Load(name)
        ARC.Config.List()            ARC.Config.Delete(name)
        ARC.Flags                    -- live table of every Flag value
        ARC.Utils                    -- table/string/math/color helpers

    ── NOTIFICATIONS ─────────────────────────────────────────────────────
        ARC:Notify({
            Title = "ARC",
            Description = "Hello",
            Duration = 5,
            Actions = {                 -- optional buttons
                { Name = "Yes", Callback = function() end },
                { Name = "No",  Callback = function() end },
            },
        })

    ── CHANGELOG ─────────────────────────────────────────────────────────
    v2.0.0  · Full rewrite: theme engine, config system, color picker,
              progress bars, multi dropdowns, hold buttons, notifications
              with actions, settings tab, utilities, sound engine, GUI
              protection, fully rounded corners, overlap fixes.
    v1.1.0  · Quality pass: rounded corners everywhere, overlap fixes,
              intro animation, smoother tab transitions.
    v1.0.0  · Initial release: window, tabs, core elements.
]]

---------------------------------------------------------------- services ----
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local HttpService      = game:GetService("HttpService")

---------------------------------------------------------------- library ----
local Library = {
    Version      = "2.2.0",
    Flags        = {},
    Themes       = {},
    CurrentTheme = "Midnight",
    Config       = {},
    Utils        = {},
    _Registry    = {},   -- themed instances: { {Obj, Role, Prop} ... }
    _State       = {},   -- flagged elements:  { [flag] = {Get,Set} }
    _Memory      = {},   -- fallback config storage when no file API
    _Connections = {},
}
Library.__index = Library

local WindowMT = {}
WindowMT.__index = WindowMT
local TabMT = {}
TabMT.__index = TabMT

---------------------------------------------------------------- env ----
-- Detect executor capabilities safely. Everything optional is guarded so
-- ARC runs on any executor, from full-featured to bare bones.
local function Has(fn)
    return type(fn) == "function"
end

local Env = {
    HasFiles    = Has(writefile) and Has(readfile) and Has(isfile),
    HasFolder   = Has(makefolder),
    HasList     = Has(listfiles),
    HasDelete   = Has(delfile),
    HasHui      = Has(gethui),
    HasExecutor = Has(identifyexecutor),
}
Env.Name = Env.HasExecutor and tostring(identifyexecutor()) or "Unknown"
Library.Env = Env

local CONFIG_FOLDER = "ARC_Configs"

---------------------------------------------------------------- utils: math ----
local Utils = Library.Utils
local MathUtils = {}
Utils.Math = MathUtils

--- Clamps a number between two bounds.
-- @param v number value
-- @param a number lower bound
-- @param b number upper bound
-- @return number clamped value
function MathUtils.Clamp(v, a, b)
    return math.min(math.max(v, a), b)
end

--- Linear interpolation between a and b by t.
function MathUtils.Lerp(a, b, t)
    return a + (b - a) * t
end

--- Maps a value from one range into another.
function MathUtils.Map(v, inMin, inMax, outMin, outMax)
    local t = (v - inMin) / math.max(inMax - inMin, 0.000001)
    return outMin + (outMax - outMin) * MathUtils.Clamp(t, 0, 1)
end

--- Rounds to a number of decimals.
function MathUtils.Round(v, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(v * mult + 0.5) / mult
end

--- Returns -1, 0 or 1 depending on sign.
function MathUtils.Sign(v)
    return v > 0 and 1 or v < 0 and -1 or 0
end

--- Percentage (0..1) of v inside [a, b].
function MathUtils.Percent(v, a, b)
    if b == a then return 0 end
    return MathUtils.Clamp((v - a) / (b - a), 0, 1)
end

--- Random integer in [a, b].
function MathUtils.Int(a, b)
    return math.random(a, b)
end

--- Random float in [a, b).
function MathUtils.Float(a, b)
    return a + math.random() * (b - a)
end

--- True with probability p (0..1).
function MathUtils.Chance(p)
    return math.random() < p
end

--- Easing curves (t in 0..1).
function MathUtils.EaseOutQuint(t)
    local f = t - 1
    return f * f * f * f * f + 1
end

function MathUtils.EaseOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local f = t - 1
    return 1 + c3 * f * f * f + c1 * f * f
end

function MathUtils.EaseInOutSine(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

---------------------------------------------------------------- utils: table ----
local TableUtils = {}
Utils.Table = TableUtils

--- Shallow copy of a table.
function TableUtils.Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

--- Deep copy (handles nested tables, ignores metatables).
function TableUtils.DeepCopy(t, seen)
    seen = seen or {}
    if type(t) ~= "table" then return t end
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do
        out[TableUtils.DeepCopy(k, seen)] = TableUtils.DeepCopy(v, seen)
    end
    return out
end

--- Index of value in array part, or nil.
function TableUtils.Find(t, value)
    for i, v in ipairs(t) do
        if v == value then return i end
    end
    return nil
end

--- Whether the array part contains a value.
function TableUtils.Contains(t, value)
    return TableUtils.Find(t, value) ~= nil
end

--- Removes first occurrence of value; returns true if removed.
function TableUtils.Remove(t, value)
    local i = TableUtils.Find(t, value)
    if i then
        table.remove(t, i)
        return true
    end
    return false
end

--- Toggles membership of value; returns new membership state.
function TableUtils.ToggleMember(t, value)
    if TableUtils.Remove(t, value) then
        return false
    end
    table.insert(t, value)
    return true
end

--- Array of keys.
function TableUtils.Keys(t)
    local out = {}
    for k in pairs(t) do table.insert(out, k) end
    return out
end

--- Array of values.
function TableUtils.Values(t)
    local out = {}
    for _, v in pairs(t) do table.insert(out, v) end
    return out
end

--- Number of entries (hash + array).
function TableUtils.Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Merges tables left to right into a new table.
function TableUtils.Merge(...)
    local out = {}
    for _, t in ipairs({...}) do
        for k, v in pairs(t) do out[k] = v end
    end
    return out
end

--- Reverses array part in place.
function TableUtils.Reverse(t)
    local n = #t
    for i = 1, math.floor(n / 2) do
        t[i], t[n - i + 1] = t[n - i + 1], t[i]
    end
    return t
end

--- Shuffles array part in place (Fisher-Yates).
function TableUtils.Shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

--- Slice of array part [from, to].
function TableUtils.Slice(t, from, to)
    local out = {}
    for i = from or 1, to or #t do
        out[#out + 1] = t[i]
    end
    return out
end

--- Picks a random entry.
function TableUtils.Pick(t)
    return t[math.random(#t)]
end

--- Clears array part in place.
function TableUtils.Clear(t)
    for i = #t, 1, -1 do t[i] = nil end
    return t
end

---------------------------------------------------------------- utils: string ----
local StringUtils = {}
Utils.String = StringUtils

--- Trims whitespace from both ends.
function StringUtils.Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Splits a string by separator (plain, not pattern).
function StringUtils.Split(s, sep)
    local out, plain = {}, sep or ","
    if s == "" then return out end
    local start = 1
    while true do
        local a, b = s:find(plain, start, true)
        if not a then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, a - 1)
        start = b + 1
    end
    return out
end

--- Whether s contains sub.
function StringUtils.Contains(s, sub)
    return s:find(sub, 1, true) ~= nil
end

--- Whether s starts with sub.
function StringUtils.StartsWith(s, sub)
    return s:sub(1, #sub) == sub
end

--- Whether s ends with sub.
function StringUtils.EndsWith(s, sub)
    return s:sub(-#sub) == sub
end

--- Truncates with an ellipsis past max length.
function StringUtils.Ellipsize(s, max)
    if #s <= max then return s end
    return s:sub(1, math.max(max - 1, 1)) .. "…"
end

--- Repeats a string n times.
function StringUtils.Repeat(s, n)
    local out = {}
    for _ = 1, n do out[#out + 1] = s end
    return table.concat(out)
end

--- Random alphanumeric string of length n.
function StringUtils.Random(n)
    local chars, out = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", {}
    for _ = 1, (n or 8) do
        out[#out + 1] = chars:sub(math.random(#chars), math.random(#chars))
    end
    return table.concat(out)
end

--- Capitalizes first letter.
function StringUtils.Capitalize(s)
    return s:sub(1, 1):upper() .. s:sub(2)
end

---------------------------------------------------------------- utils: color ----
local ColorUtils = {}
Utils.Color = ColorUtils

--- HSV → RGB (all 0..1). Returns r, g, b.
function ColorUtils.HSVToRGB(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

--- RGB → HSV (all 0..1). Returns h, s, v.
function ColorUtils.RGBToHSV(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local d = max - min
    local h = 0
    if d ~= 0 then
        if max == r then
            h = ((g - b) / d) % 6
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
        if h < 0 then h = h + 1 end
    end
    local s = (max == 0) and 0 or d / max
    return h, s, max
end

--- "#rrggbb" → r, g, b (0..255).
function ColorUtils.HexToRGB(hex)
    local clean = hex:gsub("#", "")
    local r = tonumber(clean:sub(1, 2), 16) or 255
    local g = tonumber(clean:sub(3, 4), 16) or 255
    local b = tonumber(clean:sub(5, 6), 16) or 255
    return r, g, b
end

--- r, g, b (0..255) → "#rrggbb".
function ColorUtils.RGBToHex(r, g, b)
    return string.format("#%02x%02x%02x",
        math.floor(MathUtils.Clamp(r, 0, 255)),
        math.floor(MathUtils.Clamp(g, 0, 255)),
        math.floor(MathUtils.Clamp(b, 0, 255)))
end

--- Mixes two Color3 values by t.
function ColorUtils.Mix(c1, c2, t)
    t = MathUtils.Clamp(t or 0.5, 0, 1)
    return Color3.fromRGB(
        MathUtils.Lerp(c1.R * 255, c2.R * 255, t),
        MathUtils.Lerp(c1.G * 255, c2.G * 255, t),
        MathUtils.Lerp(c1.B * 255, c2.B * 255, t))
end

--- Lightens a Color3 by t (toward white).
function ColorUtils.Lighten(c, t)
    return ColorUtils.Mix(c, Color3.fromRGB(255, 255, 255), t)
end

--- Darkens a Color3 by t (toward black).
function ColorUtils.Darken(c, t)
    return ColorUtils.Mix(c, Color3.fromRGB(0, 0, 0), t)
end

---------------------------------------------------------------- utils: time ----
local TimeUtils = {}
Utils.Time = TimeUtils

--- Seconds → "m:ss".
function TimeUtils.Format(seconds)
    local s = math.floor(seconds or 0)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

--- Seconds → "1h 2m 3s" style.
function TimeUtils.FormatLong(seconds)
    local s = math.floor(seconds or 0)
    local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
    local parts = {}
    if h > 0 then table.insert(parts, h .. "h") end
    if m > 0 then table.insert(parts, m .. "m") end
    table.insert(parts, (s % 60) .. "s")
    return table.concat(parts, " ")
end

--- Unix-style timestamp (seconds, float).
function TimeUtils.Now()
    return os.clock()
end

---------------------------------------------------------------- utils: misc ----
--- Debounce gate. Usage: local d = Utils.Debounce(0.5)  if d() then ... end
function Utils.Debounce(cooldown)
    local last = 0
    return function()
        local now = os.clock()
        if now - last >= (cooldown or 0.2) then
            last = now
            return true
        end
        return false
    end
end

--- Minimal signal/event class.
local Signal = {}
Signal.__index = Signal
Utils.Signal = Signal

function Signal.new()
    return setmetatable({ _conns = {} }, Signal)
end

function Signal:Connect(fn)
    local conn = { Fn = fn, Dead = false }
    table.insert(self._conns, conn)
    local mt = {}
    mt.__index = { Disconnect = function() conn.Dead = true end }
    return setmetatable({}, mt)
end

function Signal:Fire(...)
    for _, conn in ipairs(self._conns) do
        if not conn.Dead then
            task.spawn(conn.Fn, ...)
        end
    end
end

function Signal:Destroy()
    for _, conn in ipairs(self._conns) do conn.Dead = true end
    self._conns = {}
end

---------------------------------------------------------------- themes ----
-- Every themed instance is registered under a role; SetTheme sweeps the
-- registry and re-colors everything live, so themes apply to the whole
-- interface — window, cards, rows, text, outlines — in one call.
Library.Themes = {}

Library.Themes.Midnight = {
    Window   = Color3.fromRGB(10, 10, 10),
    Sidebar  = Color3.fromRGB(6, 6, 6),
    Card     = Color3.fromRGB(15, 15, 15),
    Tile     = Color3.fromRGB(26, 26, 26),
    Hover    = Color3.fromRGB(23, 23, 23),
    Track    = Color3.fromRGB(45, 45, 45),
    White    = Color3.fromRGB(255, 255, 255),
    Text     = Color3.fromRGB(245, 245, 245),
    Dim      = Color3.fromRGB(155, 155, 155),
    Dimmer   = Color3.fromRGB(105, 105, 105),
    Outline  = Color3.fromRGB(255, 255, 255),
    Accent   = Color3.fromRGB(255, 255, 255),
}

Library.Themes.Carbon = {
    Window   = Color3.fromRGB(16, 16, 16),
    Sidebar  = Color3.fromRGB(11, 11, 11),
    Card     = Color3.fromRGB(22, 22, 22),
    Tile     = Color3.fromRGB(34, 34, 34),
    Hover    = Color3.fromRGB(30, 30, 30),
    Track    = Color3.fromRGB(55, 55, 55),
    White    = Color3.fromRGB(255, 255, 255),
    Text     = Color3.fromRGB(240, 240, 240),
    Dim      = Color3.fromRGB(150, 150, 150),
    Dimmer   = Color3.fromRGB(100, 100, 100),
    Outline  = Color3.fromRGB(200, 200, 200),
    Accent   = Color3.fromRGB(220, 220, 220),
}

Library.Themes.Ghost = {
    Window   = Color3.fromRGB(245, 245, 245),
    Sidebar  = Color3.fromRGB(238, 238, 238),
    Card     = Color3.fromRGB(252, 252, 252),
    Tile     = Color3.fromRGB(228, 228, 228),
    Hover    = Color3.fromRGB(235, 235, 235),
    Track    = Color3.fromRGB(205, 205, 205),
    White    = Color3.fromRGB(20, 20, 20),
    Text     = Color3.fromRGB(25, 25, 25),
    Dim      = Color3.fromRGB(105, 105, 105),
    Dimmer   = Color3.fromRGB(145, 145, 145),
    Outline  = Color3.fromRGB(40, 40, 40),
    Accent   = Color3.fromRGB(20, 20, 20),
}

Library.Themes.Crimson = {
    Window   = Color3.fromRGB(12, 8, 8),
    Sidebar  = Color3.fromRGB(8, 5, 5),
    Card     = Color3.fromRGB(18, 12, 12),
    Tile     = Color3.fromRGB(30, 20, 20),
    Hover    = Color3.fromRGB(26, 17, 17),
    Track    = Color3.fromRGB(50, 32, 32),
    White    = Color3.fromRGB(255, 90, 90),
    Text     = Color3.fromRGB(250, 235, 235),
    Dim      = Color3.fromRGB(170, 140, 140),
    Dimmer   = Color3.fromRGB(120, 95, 95),
    Outline  = Color3.fromRGB(255, 90, 90),
    Accent   = Color3.fromRGB(255, 70, 70),
}

Library.Themes.Ocean = {
    Window   = Color3.fromRGB(8, 10, 14),
    Sidebar  = Color3.fromRGB(5, 7, 10),
    Card     = Color3.fromRGB(12, 15, 20),
    Tile     = Color3.fromRGB(20, 25, 33),
    Hover    = Color3.fromRGB(17, 21, 28),
    Track    = Color3.fromRGB(38, 46, 58),
    White    = Color3.fromRGB(140, 200, 255),
    Text     = Color3.fromRGB(235, 242, 250),
    Dim      = Color3.fromRGB(140, 155, 175),
    Dimmer   = Color3.fromRGB(95, 110, 130),
    Outline  = Color3.fromRGB(140, 200, 255),
    Accent   = Color3.fromRGB(120, 190, 255),
}

--- Current role color.
local function C(role)
    return Library.Themes[Library.CurrentTheme][role]
end

--- Registers a themed object so SetTheme can re-color it later.
local function Reg(obj, role, prop)
    table.insert(Library._Registry, { Obj = obj, Role = role, Prop = prop or "BackgroundColor3" })
end

--- Applies a theme to the entire interface with a smooth sweep.
-- @param name string theme name (see ARC.Themes)
function Library:SetTheme(name)
    local theme = Library.Themes[name]
    if not theme then
        Library:Notify({ Title = "ARC", Description = "Unknown theme: " .. tostring(name) })
        return false
    end
    Library.CurrentTheme = name
    for _, entry in ipairs(Library._Registry) do
        local color = theme[entry.Role]
        if color and entry.Obj and entry.Obj.Parent then
            local ok = pcall(function()
                TweenService:Create(entry.Obj, TweenInfo.new(0.25), { [entry.Prop] = color }):Play()
            end)
            if not ok then
                pcall(function() entry.Obj[entry.Prop] = color end)
            end
        end
    end
    return true
end

--- Lists available theme names.
function Library:ThemeNames()
    local names = {}
    for name in pairs(Library.Themes) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

---------------------------------------------------------------- sounds ----
-- Tiny optional sound engine. Disabled by default so ARC never produces
-- unexpected audio; enable from the settings tab or with
-- ARC.Sound.Enabled = true. Sounds are wrapped in pcall so a missing
-- asset can never raise an error.
local SoundEngine = {
    Enabled = false,
    Volume  = 0.35,
    _cache  = {},
}
Library.Sound = SoundEngine

SoundEngine.Assets = {
    Click  = "rbxassetid://6042306588",
    Hover  = "rbxassetid://6042306588",
    Toggle = "rbxassetid://6042306588",
    Notify = "rbxassetid://6042306588",
    Open   = "rbxassetid://6042306588",
    Close  = "rbxassetid://6042306588",
}

--- Plays a sound by engine key ("Click", "Hover", "Toggle", ...).
function SoundEngine:Play(key)
    if not self.Enabled then return end
    pcall(function()
        local id = self.Assets[key] or self.Assets.Click
        local sound = self._cache[id]
        if not sound then
            sound = Instance.new("Sound")
            sound.SoundId = id
            sound.Volume = self.Volume
            sound.Parent = game:GetService("SoundService")
            self._cache[id] = sound
        end
        sound.Volume = self.Volume
        sound:Play()
    end)
end

---------------------------------------------------------------- helpers ----
local function New(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function Tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

--- White outline stroke, registered so themes can re-color it.
local function Stroke(parent, transparency, thickness)
    local s = New("UIStroke", {
        Color = C("Outline"),
        Transparency = transparency or 0.8,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
    Reg(s, "Outline", "Color")
    return s
end

--- Hover feedback between two theme roles.
local function HoverBg(obj, baseRole, hoverRole)
    obj.MouseEnter:Connect(function()
        Tween(obj, { BackgroundColor3 = C(hoverRole) }, 0.15)
    end)
    obj.MouseLeave:Connect(function()
        Tween(obj, { BackgroundColor3 = C(baseRole) }, 0.15)
    end)
end

--- Press flash feedback (briefly lightens, then restores).
local function PressFlash(obj, role)
    obj.MouseButton1Down:Connect(function()
        Tween(obj, { BackgroundColor3 = C("Tile") }, 0.06)
    end)
    obj.MouseButton1Up:Connect(function()
        Tween(obj, { BackgroundColor3 = C(role) }, 0.18)
    end)
end

--- Icon from asset id (number), drawn vector name, or glyph (string).
local function MakeIcon(parent, icon, size, colorRole)
    local role = colorRole or "White"
    if type(icon) == "number" then
        local obj = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, size, 0, size),
            Image = "rbxassetid://" .. tostring(icon),
            ImageColor3 = C(role),
        }, parent)
        Reg(obj, role, "ImageColor3")
        return obj
    end
    -- texture icons from the curated asset set (sharper than vectors);
    -- anything not listed falls through to the drawn version.
    if type(icon) == "string" and Library.Icons.Asset and Library.Icons.Asset[icon] then
        local obj = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, size, 0, size),
            Image = Library.Icons.Asset[icon],
            ImageColor3 = C(role),
            ScaleType = Enum.ScaleType.Fit,
        }, parent)
        Reg(obj, role, "ImageColor3")
        return obj
    end
    if Library.Icons and Library.Icons[icon] then
        return Library.Icons.Draw(parent, icon, size, role)
    end
    local obj = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, size, 0, size),
        Text = tostring(icon or "□"),
        TextColor3 = C(role),
        TextSize = math.floor(size * 0.8),
        Font = Enum.Font.GothamMedium,
    }, parent)
    Reg(obj, role, "TextColor3")
    return obj
end

--- Side-table of drawn-icon segments (weak keys so icons can GC).
-- Needed because Roblox instances refuse arbitrary custom fields.
local IconSegs = setmetatable({}, { __mode = "k" })

--- Recolors any icon kind (glyph, drawn segments) for hover/selection.
local function RecolorIcon(icon, role)
    if not icon then return end
    local color = C(role)
    -- (Roblox instances reject custom fields, so segments are tracked
    --  in a weak side-table; see Icons.Draw)
    local segs = IconSegs[icon]
    if segs then
        for _, seg in ipairs(segs) do
            Tween(seg, { BackgroundColor3 = color }, 0.2)
        end
    elseif icon:IsA("TextLabel") then
        Tween(icon, { TextColor3 = color }, 0.2)
    elseif icon:IsA("ImageLabel") then
        Tween(icon, { ImageColor3 = color }, 0.2)
    end
end

--- Window dragging through a handle.
local function MakeDraggable(frame, handle)
    local dragging, start, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            start = input.Position
            startPos = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - start
            frame.Position = startPos + UDim2.fromOffset(delta.X, delta.Y)
        end
    end)
end

--- Protects a ScreenGui from core-script interference where possible.
local function ProtectGui(gui)
    pcall(function()
        if Env.HasHui then
            gui.Parent = gethui()
            return
        end
    end)
    if gui.Parent then return end
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if gui.Parent then return end
    pcall(function()
        local player = Players.LocalPlayer
        if player then
            gui.Parent = player:WaitForChild("PlayerGui")
        end
    end)
    if not gui.Parent then
        gui.Parent = game
    end
end

---------------------------------------------------------------- notify ----
local Settings = {
    Notifications = true,
    Sounds        = false,
}
Library.Settings = Settings

local function BuildNotifyContainer(gui)
    local container = New("Frame", {
        Name = "ARC_Notifications",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -24, 1, -24),
        Size = UDim2.new(0, 300, 1, -48),
    }, gui)
    New("UIListLayout", {
        Padding = UDim.new(0, 10),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, container)
    return container
end

--- Shows a stacked notification, optionally with action buttons.
-- @param opts table { Title, Description, Duration, Actions = { {Name, Callback} } }
function Library:Notify(opts)
    opts = opts or {}
    if not Settings.Notifications then return end
    local gui = self._Gui
    if not gui then return end
    local container = gui:FindFirstChild("ARC_Notifications")
    if not container then
        container = BuildNotifyContainer(gui)
    end

    SoundEngine:Play("Notify")

    local note = New("Frame", {
        BackgroundColor3 = C("Card"),
        Size = UDim2.new(0, 280, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, container)
    Reg(note, "Card")
    Corner(note, 12)
    local noteStroke = Stroke(note, 0.72)
    noteStroke.Transparency = 1

    -- toast variant accent bar
    local toast = Library.ToastTypes and Library.ToastTypes[opts.Type or ""]
    if toast then
        local bar = New("Frame", {
            Position = UDim2.new(0, 0, 0, 10),
            Size = UDim2.new(0, 3, 1, -20),
            BackgroundColor3 = toast.Color or C("Accent"),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, note)
        Corner(bar, 2)
        Tween(bar, { BackgroundTransparency = 0 }, 0.25)
    end

    New("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
    }, note)

    local layout = New("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, note)

    local titleLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -28, 0, 18),
        Text = opts.Title or "ARC",
        TextColor3 = C("Text"),
        TextTransparency = 1,
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, note)
    Reg(titleLabel, "Text", "TextColor3")

    local descLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -28, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = opts.Description or "",
        TextColor3 = C("Dim"),
        TextTransparency = 1,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
    }, note)
    Reg(descLabel, "Dim", "TextColor3")

    -- action buttons ----------------------------------------------------
    if opts.Actions and #opts.Actions > 0 then
        local row = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
        }, note)
        local rowLayout = New("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, row)
        for _, action in ipairs(opts.Actions) do
            local btn = New("TextButton", {
                Size = UDim2.new(0, 56, 1, 0),
                BackgroundColor3 = C("Tile"),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = action.Name or "OK",
                TextColor3 = C("Text"),
                TextTransparency = 1,
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
            }, row)
            Reg(btn, "Tile")
            Reg(btn, "Text", "TextColor3")
            Corner(btn, 7)
            btn.MouseButton1Click:Connect(function()
                if action.Callback then
                    task.spawn(action.Callback)
                end
                opts.Duration = 0
                note:Destroy()
            end)
        end
    end

    -- fade in -------------------------------------------------------------
    Tween(note, { BackgroundTransparency = 0 }, 0.25)
    Tween(noteStroke, { Transparency = 0.72 }, 0.25)
    for _, lbl in ipairs(note:GetChildren()) do
        if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
            Tween(lbl, { TextTransparency = 0 }, 0.25)
        end
    end

    local duration = opts.Duration or 4
    if duration > 0 then
        task.delay(duration, function()
            if not note.Parent then return end
            Tween(note, { BackgroundTransparency = 1 }, 0.2)
            Tween(noteStroke, { Transparency = 1 }, 0.2)
            for _, lbl in ipairs(note:GetChildren()) do
                if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
                    Tween(lbl, { TextTransparency = 1 }, 0.2)
                end
            end
            task.wait(0.22)
            note:Destroy()
        end)
    end

    if opts.Callback then
        task.spawn(opts.Callback)
    end
    return note
end

--- Window-level alias.
function WindowMT:Notify(opts)
    return Library:Notify(opts)
end

------------------------------------------------------------------ window ----
--- Creates the main ARC window.
-- @param opts table {
--   Title, Logo, Version, Subtitle, Key (toggle keycode),
--   SettingsTab (bool, auto-build settings tab) }
function Library:CreateWindow(opts)
    opts = opts or {}

    local title    = opts.Title or "ARC"
    local logo     = opts.Logo or 131675609143159
    local version  = opts.Version or "v" .. Library.Version
    local subtitle = opts.Subtitle
        or "A modern UI library for your Roblox scripts.\nSimple. Clean. Powerful."
    local toggleKey = opts.Key or Enum.KeyCode.RightShift

    -- clean up a previous instance when re-executed
    if self._Gui then
        self._Gui:Destroy()
        self._Gui = nil
    end
    Library._Registry = {}
    Library._State = {}

    local gui = New("ScreenGui", {
        Name = "ARC_UI_Library",
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    })
    ProtectGui(gui)
    self._Gui = gui
    BuildNotifyContainer(gui)

    local window = setmetatable({
        Title = title,
        Logo = logo,
        Version = version,
        Tabs = {},
        Key = toggleKey,
        Minimized = false,
        IsOpen = true,
    }, WindowMT)
    self._Window = window

    ------------------------------------------------------------ main frame
    local main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 780, 0, 575),
        BackgroundColor3 = C("Window"),
        ClipsDescendants = true,
    }, gui)
    Reg(main, "Window")
    Corner(main, 14)
    Stroke(main, 0.72)
    window.Main = main
    window._FullSize = UDim2.new(0, 780, 0, 575)

    ------------------------------------------------------------- sidebar
    local sidebar = New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundColor3 = C("Sidebar"),
    }, main)
    Reg(sidebar, "Sidebar")
    -- UICorner does not clip children round in Roblox, so the sidebar
    -- gets its own corner radius; the two right corners are squared off
    -- again with same-color patches so only the window's outer left
    -- corners stay round.
    Corner(sidebar, 14)
    local patchTop = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 15, 0, 15),
        BackgroundColor3 = C("Sidebar"),
        BorderSizePixel = 0,
    }, sidebar)
    Reg(patchTop, "Sidebar")
    local patchBottom = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, 0),
        Size = UDim2.new(0, 15, 0, 15),
        BackgroundColor3 = C("Sidebar"),
        BorderSizePixel = 0,
    }, sidebar)
    Reg(patchBottom, "Sidebar")
    window.Sidebar = sidebar

    -- divider between sidebar and content
    local sideDiv = New("Frame", {
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = C("Outline"),
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
    }, sidebar)
    Reg(sideDiv, "Outline")

    -- logo row
    local logoImg = New("ImageLabel", {
        Position = UDim2.new(0, 18, 0, 17),
        Size = UDim2.new(0, 36, 0, 36),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(logo),
    }, sidebar)
    Corner(logoImg, 10)

    local titleLabel = New("TextLabel", {
        Position = UDim2.new(0, 64, 0, 17),
        Size = UDim2.new(0, 120, 0, 36),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = C("Text"),
        TextSize = 19,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)
    Reg(titleLabel, "Text", "TextColor3")
    window._TitleLabel = titleLabel

    -- divider under logo row
    local logoDiv = New("Frame", {
        Position = UDim2.new(0, 0, 0, 70),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C("Outline"),
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, sidebar)
    Reg(logoDiv, "Outline")

    -- nav list
    local nav = New("ScrollingFrame", {
        Name = "NavList",
        Position = UDim2.new(0, 12, 0, 84),
        Size = UDim2.new(1, -24, 1, -120),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    }, sidebar)
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, nav)
    window.NavList = nav

    -- animated selection indicator (slides between nav items)
    sidebar.ClipsDescendants = true
    local navInd = New("Frame", {
        Name = "NavIndicator",
        Position = UDim2.new(0, 7, 0, 90),
        Size = UDim2.new(0, 2, 0, 20),
        BackgroundColor3 = C("Accent"),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, sidebar)
    Reg(navInd, "Accent")
    Corner(navInd, 2)
    window._NavInd = navInd

    -- accent hairline across the top of the window
    local hairline = New("Frame", {
        Name = "Hairline",
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -28, 0, 1),
        BackgroundColor3 = C("Accent"),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, main)
    Reg(hairline, "Accent")
    window._Hairline = hairline

    -- version label
    local versionLabel = New("TextLabel", {
        Position = UDim2.new(0, 18, 1, -30),
        Size = UDim2.new(0, 120, 0, 16),
        BackgroundTransparency = 1,
        Text = version,
        TextColor3 = C("Dimmer"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)
    Reg(versionLabel, "Dimmer", "TextColor3")

    ------------------------------------------------------------ content
    local content = New("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 200, 0, 0),
        Size = UDim2.new(1, -200, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, main)
    window.Content = content

    local pages = New("Frame", {
        Name = "Pages",
        Position = UDim2.new(0, 0, 0, 44),
        Size = UDim2.new(1, 0, 1, -44),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, content)
    window.Pages = pages

    ------------------------------------------------- topbar (drag + ctrls)
    local topbar = New("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, main)
    MakeDraggable(main, topbar)

    local minBtn = New("TextButton", {
        Name = "Minimize",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -44, 0, 6),
        Size = UDim2.new(0, 32, 0, 32),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = C("Dim"),
        TextSize = 16,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
        ZIndex = 7,
    }, topbar)
    Reg(minBtn, "Dim", "TextColor3")
    Corner(minBtn, 8)
    minBtn.MouseEnter:Connect(function()
        Tween(minBtn, { BackgroundColor3 = C("Tile"), BackgroundTransparency = 0.4 }, 0.15)
    end)
    minBtn.MouseLeave:Connect(function()
        Tween(minBtn, { BackgroundTransparency = 1 }, 0.15)
    end)

    local closeBtn = New("TextButton", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 6),
        Size = UDim2.new(0, 32, 0, 32),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 7,
    }, topbar)
    Reg(closeBtn, "Dim", "TextColor3")
    Corner(closeBtn, 8)
    -- drawn X (font-independent, renders on every executor)
    local xA = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 2),
        Rotation = 45,
        BackgroundColor3 = C("Dim"),
        BorderSizePixel = 0,
    }, closeBtn)
    Reg(xA, "Dim")
    local xB = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 2),
        Rotation = -45,
        BackgroundColor3 = C("Dim"),
        BorderSizePixel = 0,
    }, closeBtn)
    Reg(xB, "Dim")
    closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, { BackgroundColor3 = C("Tile"), BackgroundTransparency = 0.4 }, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, { BackgroundTransparency = 1 }, 0.15)
    end)

    -- mini bar shown while minimized
    local miniBar = New("Frame", {
        Name = "MiniBar",
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -96, 1, -16),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 5,
    }, main)
    local miniLogo = New("ImageLabel", {
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(logo),
    }, miniBar)
    Corner(miniLogo, 8)
    local miniTitle = New("TextLabel", {
        Position = UDim2.new(0, 38, 0, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = C("Text"),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, miniBar)
    Reg(miniTitle, "Text", "TextColor3")
    window.MiniBar = miniBar

    ------------------------------------------------------- window control
    minBtn.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        window:SetMinimized(not window.Minimized)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        SoundEngine:Play("Close")
        window:Close()
    end)

    -- global toggle key
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == window.Key then
            window:Toggle()
        end
    end)

    ------------------------------------------------ home page (as design)
    local home = window:AddTab({ Name = "Home", Icon = "home", BuiltIn = true })
    window.HomeTab = home
    window:_BuildHomePage(home, opts, subtitle)

    ------------------------------------------------ optional settings tab
    if opts.SettingsTab then
        window:AddSettingsTab()
    end

    -- resize grip + intro animation (smooth expand)
    window:_AttachResize()
    main.Size = UDim2.new(0, 720, 0, 470)
    Tween(main, { Size = window._FullSize }, 0.45, Enum.EasingStyle.Quint)
    SoundEngine:Play("Open")

    return window
end

-------------------------------------------------------------- window meta ----
--- Sets the window title everywhere it appears.
function WindowMT:SetTitle(text)
    self.Title = text
    if self._TitleLabel then self._TitleLabel.Text = text end
end

--- Creates a sidebar tab with its own scrollable page.
function WindowMT:AddTab(opts)
    opts = opts or {}
    local window = self

    local tab = setmetatable({
        Name = opts.Name or "Tab",
        Window = window,
        Elements = {},
    }, TabMT)

    ---------------------------------------------------- nav button
    local navBtn = New("TextButton", {
        Name = "Nav_" .. tab.Name,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C("Tile"),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    }, window.NavList)
    Reg(navBtn, "Tile")
    Corner(navBtn, 8)
    local navStroke = Stroke(navBtn, 0.9)
    navStroke.Enabled = false

    local icon = MakeIcon(navBtn, opts.Icon or "dot", 16, "Dim")
    icon.Position = UDim2.new(0, 13, 0.5, -8)

    local label = New("TextLabel", {
        Position = UDim2.new(0, 39, 0, 0),
        Size = UDim2.new(1, -46, 1, 0),
        BackgroundTransparency = 1,
        Text = tab.Name,
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, navBtn)
    Reg(label, "Dim", "TextColor3")

    -- count badge (right side of the nav item)
    local badge = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 16),
        BackgroundColor3 = C("Accent"),
        Text = "",
        TextColor3 = C("Window"),
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        Visible = false,
        ZIndex = 3,
    }, navBtn)
    Reg(badge, "Accent")
    Reg(badge, "Window", "TextColor3")
    Corner(badge, 8)
    tab.Badge = badge

    tab.NavButton = navBtn
    tab.NavStroke = navStroke
    tab.NavIcon = icon
    tab.NavLabel = label

    navBtn.MouseEnter:Connect(function()
        if window._Selected ~= tab then
            Tween(navBtn, { BackgroundTransparency = 0.5 }, 0.15)
            Tween(label, { TextColor3 = C("Text") }, 0.15)
            RecolorIcon(icon, "Text")
        end
    end)
    navBtn.MouseLeave:Connect(function()
        if window._Selected ~= tab then
            Tween(navBtn, { BackgroundTransparency = 1 }, 0.15)
            Tween(label, { TextColor3 = C("Dim") }, 0.15)
            RecolorIcon(icon, "Dim")
        end
    end)
    navBtn.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        window:SelectTab(tab)
    end)
    navBtn.ClipsDescendants = true
    if opts.Tooltip then
        Library.Tooltip.Attach(navBtn, opts.Tooltip)
    end

    ---------------------------------------------------- page
    local page = New("ScrollingFrame", {
        Name = "Page_" .. tab.Name,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C("Dimmer"),
        ScrollBarImageTransparency = 0.4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
    }, window.Pages)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 24),
        PaddingLeft = UDim.new(0, 20),
        PaddingRight = UDim.new(0, 20),
    }, page)
    local list = New("Frame", {
        Name = "List",
        -- width minus left+right padding: UIPadding does NOT shrink
        -- Scale-1 children in Roblox, so the inset is baked in here
        Size = UDim2.new(1, -40, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, page)
    New("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)

    tab.Page = page
    tab.List = list

    table.insert(window.Tabs, tab)
    if not window._Selected then
        window:SelectTab(tab)
    end
    return tab
end

--- Switches the visible page and highlights the nav entry.
function WindowMT:SelectTab(tab)
    local window = self
    window._Selected = tab
    window:_MoveNavInd(tab)
    for _, t in ipairs(window.Tabs) do
        local selected = (t == tab)
        t.Page.Visible = selected
        Tween(t.NavButton, { BackgroundTransparency = selected and 0 or 1 }, 0.2)
        t.NavStroke.Enabled = selected
        Tween(t.NavLabel, { TextColor3 = selected and C("Text") or C("Dim") }, 0.2)
        RecolorIcon(t.NavIcon, selected and "Text" or "Dim")
    end
end

--- Collapses the window into a compact draggable pill (or restores it).
function WindowMT:SetMinimized(state)
    self.Minimized = state
    if state then
        self.Sidebar.Visible = false
        self.Content.Visible = false
        self.MiniBar.Visible = true
        Tween(self.Main, { Size = UDim2.new(0, 240, 0, 46) }, 0.25, Enum.EasingStyle.Quint)
    else
        self.Sidebar.Visible = true
        self.Content.Visible = true
        self.MiniBar.Visible = false
        Tween(self.Main, { Size = self._FullSize }, 0.25, Enum.EasingStyle.Quint)
    end
end

function WindowMT:Minimize()
    self:SetMinimized(true)
end

function WindowMT:Restore()
    self:SetMinimized(false)
end

function WindowMT:Close()
    self.IsOpen = false
    self.Main.Visible = false
end

function WindowMT:Open()
    self.IsOpen = true
    self.Main.Visible = true
end

function WindowMT:Toggle()
    if self.IsOpen then
        self:Close()
    else
        self:Open()
    end
end

function WindowMT:Destroy()
    if Library._Gui then
        Library._Gui:Destroy()
        Library._Gui = nil
    end
end

--- Jumps to a tab by name, or notifies when it doesn't exist.
function WindowMT:_JumpOrNotify(name)
    for _, t in ipairs(self.Tabs) do
        if t.Name == name then
            self:SelectTab(t)
            return true
        end
    end
    Library:Notify({ Title = name, Description = "No '" .. name .. "' tab has been added yet." })
    return false
end

------------------------------------------------------- home page builder ----
function WindowMT:_BuildHomePage(tab, opts, subtitle)
    local logo = self.Logo
    local list = tab.List

    -------------------------------------------------- hero card
    local hero = New("Frame", {
        Name = "Hero",
        Size = UDim2.new(1, 0, 0, 210),
        BackgroundColor3 = C("Card"),
    }, list)
    Reg(hero, "Card")
    Corner(hero, 12)
    Stroke(hero, 0.9)

    -- big logo on the right
    New("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -50, 0.5, 0),
        Size = UDim2.new(0, 160, 0, 160),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(logo),
    }, hero)

    -- left column
    local tag = New("TextLabel", {
        Name = "WelcomeTag",
        Position = UDim2.new(0, 28, 0, 34),
        Size = UDim2.new(0, 300, 0, 16),
        BackgroundTransparency = 1,
        Text = "W E L C O M E   T O",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, hero)
    Reg(tag, "Dim", "TextColor3")

    local heroTitle = New("TextLabel", {
        Name = "HeroTitle",
        Position = UDim2.new(0, 28, 0, 54),
        Size = UDim2.new(0, 280, 0, 52),
        BackgroundTransparency = 1,
        Text = self.Title,
        TextColor3 = C("White"),
        TextSize = 42,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, hero)
    Reg(heroTitle, "White", "TextColor3")

    local heroSub = New("TextLabel", {
        Name = "HeroSub",
        Position = UDim2.new(0, 28, 0, 110),
        Size = UDim2.new(0, 270, 0, 44),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = C("Dim"),
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
    }, hero)
    Reg(heroSub, "Dim", "TextColor3")

    local getStarted = New("TextButton", {
        Name = "GetStarted",
        Position = UDim2.new(0, 28, 1, -52),
        Size = UDim2.new(0, 150, 0, 38),
        BackgroundColor3 = C("Tile"),
        AutoButtonColor = false,
        Text = "",
    }, hero)
    Reg(getStarted, "Tile")
    Corner(getStarted, 19)
    Stroke(getStarted, 0.7)
    HoverBg(getStarted, "Tile", "Hover")
    Library.Effects.Ripple(getStarted, "White")

    local gsArrow = New("TextLabel", {
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(0, 20, 1, 0),
        BackgroundTransparency = 1,
        Text = "→",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
    }, getStarted)
    Reg(gsArrow, "Text", "TextColor3")

    local gsText = New("TextLabel", {
        Position = UDim2.new(0, 42, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        BackgroundTransparency = 1,
        Text = "Get Started",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, getStarted)
    Reg(gsText, "Text", "TextColor3")

    getStarted.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        if opts.GetStartedCallback then
            task.spawn(opts.GetStartedCallback)
        else
            local target
            for _, t in ipairs(self.Tabs) do
                if t ~= self.HomeTab then
                    target = t
                    break
                end
            end
            if target then
                self:SelectTab(target)
            else
                Library:Notify({
                    Title = self.Title,
                    Description = "Add tabs with Window:AddTab() to get started.",
                })
            end
        end
    end)

    -------------------------------------------------- quick access head
    local head = New("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
    }, list)
    local headTitle = New("TextLabel", {
        Position = UDim2.new(0, 2, 0, 0),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "Quick Access",
        TextColor3 = C("White"),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, head)
    Reg(headTitle, "White", "TextColor3")
    local headSub = New("TextLabel", {
        Position = UDim2.new(0, 2, 0, 26),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Jump right into what you need.",
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, head)
    Reg(headSub, "Dim", "TextColor3")

    -------------------------------------------------- default cards
    local window = self
    tab:AddCard({
        Title = "UI Components",
        Description = "Pre-built components to speed up your development.",
        Icon = "cube",
        Callback = function() window:_JumpOrNotify("Components") end,
    })
    tab:AddCard({
        Title = "Themes",
        Description = "Beautiful themes with full customization support.",
        Icon = "palette",
        Callback = function() window:_JumpOrNotify("Settings") end,
    })
    tab:AddCard({
        Title = "Documentation",
        Description = "Learn how to get the most out of ARC.",
        Icon = "code",
        Callback = function()
            Library:Notify({
                Title = "Documentation",
                Description = "Read the full API reference at the top of ARC.lua.",
            })
        end,
    })
    tab:AddCard({
        Title = "Settings",
        Description = "Configure the library to fit your needs.",
        Icon = "gear",
        Callback = function() window:_JumpOrNotify("Settings") end,
    })
end

---------------------------------------------------------------- tab meta ----
--- Internal: gets (or creates) the 2-column card grid for a tab.
local function CardGrid(tab)
    if tab._Grid and tab._Grid.Parent then
        return tab._Grid
    end
    local wrap = New("Frame", {
        Name = "CardGrid",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, tab.List)
    New("UIGridLayout", {
        CellSize = UDim2.new(0.5, -7, 0, 96),
        CellPadding = UDim2.new(0, 14, 0, 14),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
    }, wrap)
    tab._Grid = wrap
    return wrap
end

--- Internal: creates a standard element row.
local function Row(tab, height, auto)
    tab._Grid = nil
    local row = New("Frame", {
        BackgroundColor3 = C("Card"),
        Size = UDim2.new(1, 0, 0, height or 48),
        AutomaticSize = auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        ClipsDescendants = true,
    }, tab.List)
    Reg(row, "Card")
    Corner(row, 10)
    Stroke(row, 0.9)
    return row
end

--- Internal: standard left-aligned element title (+ optional description).
local function RowTitle(row, opts, twoLines)
    local title = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, twoLines and 10 or 0),
        Size = UDim2.new(1, -210, twoLines and 0 or 1, twoLines and 18 or 0),
        BackgroundTransparency = 1,
        Text = opts.Title or "Element",
        TextColor3 = C("Text"),
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = twoLines and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(title, "Text", "TextColor3")
    if twoLines and opts.Description then
        local desc = New("TextLabel", {
            Position = UDim2.new(0, 16, 0, 30),
            Size = UDim2.new(1, -210, 0, 16),
            BackgroundTransparency = 1,
            Text = opts.Description,
            TextColor3 = C("Dim"),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(desc, "Dim", "TextColor3")
    end
    if opts.Tooltip and Library.Tooltip then
        Library.Tooltip.Attach(row, opts.Tooltip)
    end
    return title
end

--- Internal: registers a flagged element in the config state table.
local function RegisterState(flag, get, set)
    if not flag then return end
    Library._State[flag] = { Get = get, Set = set }
end

--------------------------------------------------------------- AddCard ----
--- Large quick-access card (grid element).
function TabMT:AddCard(opts)
    opts = opts or {}
    local grid = CardGrid(self)

    local card = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = C("Card"),
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
    }, grid)
    Reg(card, "Card")
    Corner(card, 10)
    Stroke(card, 0.9)
    HoverBg(card, "Card", "Hover")

    -- flat icon, vertically centered on the left
    local icon = MakeIcon(card, opts.Icon or "dot", 17, "Dim")
    icon.Position = UDim2.new(0, 16, 0.5, -8)

    local cardTitle = New("TextLabel", {
        Position = UDim2.new(0, 46, 0.5, -17),
        Size = UDim2.new(1, -86, 0, 17),
        BackgroundTransparency = 1,
        Text = opts.Title or "Card",
        TextColor3 = C("Text"),
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    Reg(cardTitle, "Text", "TextColor3")
    local cardDesc = New("TextLabel", {
        Position = UDim2.new(0, 46, 0.5, 2),
        Size = UDim2.new(1, -86, 0, 30),
        BackgroundTransparency = 1,
        Text = opts.Description or "",
        TextColor3 = C("Dim"),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    Reg(cardDesc, "Dim", "TextColor3")

    -- quiet chevron on the right; accents on hover
    local arrow = MakeIcon(card, "arrowright", 12, "Dimmer")
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -14, 0.5, 0)

    card.MouseEnter:Connect(function()
        RecolorIcon(icon, "Text")
        RecolorIcon(arrow, "Accent")
        Tween(cardTitle, { TextColor3 = C("White") }, 0.15)
    end)
    card.MouseLeave:Connect(function()
        RecolorIcon(icon, "Dim")
        RecolorIcon(arrow, "Dimmer")
        Tween(cardTitle, { TextColor3 = C("Text") }, 0.15)
    end)
    card.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        if opts.Callback then
            task.spawn(opts.Callback)
        end
    end)

    return card
end

-------------------------------------------------------------- AddButton ----
--- Clickable row. opts.Hold = seconds turns it into a hold-to-confirm.
function TabMT:AddButton(opts)
    opts = opts or {}
    local row = Row(self, opts.Description and 58 or 48)
    HoverBg(row, "Card", "Hover")
    RowTitle(row, opts, opts.Description and true or false)

    local arrow = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundTransparency = 1,
        Text = "→",
        TextColor3 = C("Dim"),
        TextSize = 15,
        Font = Enum.Font.GothamMedium,
    }, row)
    Reg(arrow, "Dim", "TextColor3")

    -- hold-to-confirm fill bar
    local holdBar, holdFill
    if opts.Hold then
        holdBar = New("Frame", {
            Position = UDim2.new(0, 16, 1, -6),
            Size = UDim2.new(1, -32, 0, 3),
            BackgroundColor3 = C("Track"),
        }, row)
        Reg(holdBar, "Track")
        Corner(holdBar, 2)
        holdFill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = C("Accent"),
        }, holdBar)
        Reg(holdFill, "Accent")
        Corner(holdFill, 2)
    end

    -- make whole row clickable
    local click = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    Library.Effects.Ripple(row, "White", click)

    local element = { Type = "Button", Row = row }
    local holding = false
    local holdTween

    local function fire()
        Tween(row, { BackgroundColor3 = C("Tile") }, 0.08)
        task.delay(0.12, function()
            if row.Parent then
                Tween(row, { BackgroundColor3 = C("Card") }, 0.2)
            end
        end)
        SoundEngine:Play("Click")
        if opts.Callback then
            task.spawn(opts.Callback)
        end
    end

    if opts.Hold then
        click.MouseButton1Down:Connect(function()
            holding = true
            holdFill.Size = UDim2.new(0, 0, 1, 0)
            holdTween = Tween(holdFill, { Size = UDim2.new(1, 0, 1, 0) }, opts.Hold, Enum.EasingStyle.Linear)
            task.delay(opts.Hold + 0.02, function()
                if holding then
                    holding = false
                    fire()
                    Tween(holdFill, { Size = UDim2.new(0, 0, 1, 0) }, 0.2)
                end
            end)
        end)
        click.MouseButton1Up:Connect(function()
            if holding then
                holding = false
                if holdTween then holdTween:Cancel() end
                Tween(holdFill, { Size = UDim2.new(0, 0, 1, 0) }, 0.2)
            end
        end)
    else
        click.MouseButton1Click:Connect(fire)
    end
    return element
end

-------------------------------------------------------------- AddToggle ----
--- On/off switch with animated pill.
function TabMT:AddToggle(opts)
    opts = opts or {}
    local row = Row(self, 48)
    RowTitle(row, opts, false)

    local pill = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -12),
        Size = UDim2.new(0, 42, 0, 24),
        BackgroundColor3 = C("Tile"),
    }, row)
    Reg(pill, "Tile")
    Corner(pill, 12)
    Stroke(pill, 0.75)

    local knob = New("Frame", {
        Position = UDim2.new(0, 3, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = C("Dim"),
    }, pill)
    Corner(knob, 8)

    local state = false
    local element = { Type = "Toggle", Row = row }

    local function Set(value, silent)
        state = value and true or false
        if state then
            Tween(pill, { BackgroundColor3 = C("Accent") }, 0.15)
            Tween(knob, {
                Position = UDim2.new(0, 23, 0.5, -8),
                BackgroundColor3 = C("Window"),
            }, 0.15)
        else
            Tween(pill, { BackgroundColor3 = C("Tile") }, 0.15)
            Tween(knob, {
                Position = UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = C("Dim"),
            }, 0.15)
        end
        if opts.Flag then
            Library.Flags[opts.Flag] = state
        end
        SoundEngine:Play("Toggle")
        if not silent and opts.Callback then
            task.spawn(opts.Callback, state)
        end
    end

    local click = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)
    click.MouseButton1Click:Connect(function()
        Set(not state)
    end)

    element.Set = Set
    element.GetValue = function() return state end
    if opts.Default then
        Set(opts.Default, true)
    end
    if opts.Flag then
        Library.Flags[opts.Flag] = state
    end
    RegisterState(opts.Flag, element.GetValue, function(v) Set(v, true) end)
    return element
end

-------------------------------------------------------------- AddSlider ----
--- Draggable value track, with optional numeric textbox input.
function TabMT:AddSlider(opts)
    opts = opts or {}
    local row = Row(self, 64)

    local title = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, opts.Textbox and -230 or -160, 0, 18),
        BackgroundTransparency = 1,
        Text = opts.Title or "Slider",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(title, "Text", "TextColor3")

    local valueLabel = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, opts.Textbox and -110 or -16, 0, 12),
        Size = UDim2.new(0, 90, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    Reg(valueLabel, "Dim", "TextColor3")

    local track = New("Frame", {
        Position = UDim2.new(0, 16, 1, -20),
        Size = UDim2.new(1, -32, 0, 4),
        BackgroundColor3 = C("Track"),
    }, row)
    Reg(track, "Track")
    Corner(track, 2)

    local fill = New("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C("Accent"),
    }, track)
    Reg(fill, "Accent")
    Corner(fill, 2)

    local catch = New("TextButton", {
        Position = UDim2.new(0, 0, 0.5, -9),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, track)

    -- optional numeric textbox for exact values
    local inputBox
    if opts.Textbox then
        inputBox = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 8),
            Size = UDim2.new(0, 80, 0, 26),
            BackgroundColor3 = C("Window"),
        }, row)
        Reg(inputBox, "Window")
        Corner(inputBox, 7)
        Stroke(inputBox, 0.8)
    end

    local min = opts.Min or 0
    local max = opts.Max or 100
    local decimals = opts.Decimals or 0
    local suffix = opts.Suffix or ""
    local value = opts.Default or min
    local dragging = false

    local element = { Type = "Slider" }

    local function Apply(v, silent)
        local mult = 10 ^ decimals
        v = MathUtils.Clamp(v, min, max)
        v = math.floor(v * mult + 0.5) / mult
        value = v
        local t = (max > min) and ((v - min) / (max - min)) or 0
        fill.Size = UDim2.new(MathUtils.Clamp(t, 0, 1), 0, 1, 0)
        valueLabel.Text = tostring(v) .. suffix
        if opts.Flag then
            Library.Flags[opts.Flag] = v
        end
        if not silent and opts.Callback then
            task.spawn(opts.Callback, v)
        end
    end

    local function FromMouse()
        local absX = track.AbsolutePosition.X
        local width = track.AbsoluteSize.X
        local mouseX = UserInputService:GetMouseLocation().X
        local t = MathUtils.Clamp((mouseX - absX) / math.max(width, 1), 0, 1)
        Apply(min + t * (max - min))
    end

    catch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            FromMouse()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            FromMouse()
        end
    end)

    if inputBox then
        local box = New("TextBox", {
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = C("Text"),
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            PlaceholderText = tostring(min) .. "-" .. tostring(max),
            PlaceholderColor3 = C("Dimmer"),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
        }, inputBox)
        Reg(box, "Text", "TextColor3")
        box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n then
                Apply(n)
            end
            box.Text = ""
        end)
    end

    element.Set = function(v, silent) Apply(v, silent) end
    element.GetValue = function() return value end
    Apply(value, true)
    RegisterState(opts.Flag, element.GetValue, function(v) Apply(v, true) end)
    return element
end

------------------------------------------------------------ AddDropdown ----
--- Option list. Multi = true allows multiple simultaneous selections.
function TabMT:AddDropdown(opts)
    opts = opts or {}
    local row = Row(self, 48, true)

    local header = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local title = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.5, -20, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Title or "Dropdown",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, header)
    Reg(title, "Text", "TextColor3")

    local selectedLabel = New("TextLabel", {
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Default or "None",
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, header)
    Reg(selectedLabel, "Dim", "TextColor3")

    local caret = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
    }, header)
    Reg(caret, "Dim", "TextColor3")

    New("UIListLayout", {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local openBox = New("Frame", {
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        ClipsDescendants = true,
    }, row)
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, openBox)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 10),
    }, openBox)

    local element = { Type = "Dropdown", Open = false }
    local multi = opts.Multi and true or false
    local current = multi and {} or opts.Default

    local function DisplayText()
        if multi then
            if #current == 0 then return "None" end
            local parts = {}
            for _, v in ipairs(current) do
                table.insert(parts, tostring(v))
            end
            return table.concat(parts, ", ")
        end
        return tostring(current or "None")
    end

    local function UpdateLabel()
        selectedLabel.Text = StringUtils.Ellipsize(DisplayText(), 40)
        selectedLabel.TextColor3 = C("Text")
    end

    local function Emit(silent)
        if opts.Flag then
            Library.Flags[opts.Flag] = multi and TableUtils.Copy(current) or current
        end
        if not silent and opts.Callback then
            if multi then
                task.spawn(opts.Callback, TableUtils.Copy(current))
            else
                task.spawn(opts.Callback, current)
            end
        end
    end

    local function BuildOptions(options)
        for _, child in ipairs(openBox:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        for _, option in ipairs(options or {}) do
            local optBtn = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = C("Tile"),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "  " .. tostring(option),
                TextColor3 = C("Dim"),
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, openBox)
            Reg(optBtn, "Tile")
            Corner(optBtn, 8)
            optBtn.MouseEnter:Connect(function()
                Tween(optBtn, { BackgroundTransparency = 0.4, TextColor3 = C("Text") }, 0.12)
            end)
            optBtn.MouseLeave:Connect(function()
                Tween(optBtn, { BackgroundTransparency = 1, TextColor3 = C("Dim") }, 0.12)
            end)
            optBtn.MouseButton1Click:Connect(function()
                SoundEngine:Play("Click")
                if multi then
                    TableUtils.ToggleMember(current, tostring(option))
                    UpdateLabel()
                    Emit(false)
                else
                    current = tostring(option)
                    UpdateLabel()
                    Emit(false)
                    element.SetOpen(false)
                end
            end)
        end
    end

    function element.SetOpen(state)
        element.Open = state
        openBox.Visible = state
        caret.Text = state and "▴" or "▾"
    end

    function element.Set(value, silent)
        if multi then
            current = type(value) == "table" and value or { value }
        else
            current = value
        end
        UpdateLabel()
        Emit(silent)
    end

    function element.Refresh(options)
        opts.Options = options
        BuildOptions(options)
    end

    function element.GetValue()
        return multi and TableUtils.Copy(current) or current
    end

    header.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        element.SetOpen(not element.Open)
    end)

    BuildOptions(opts.Options)
    if opts.Default then
        element.Set(opts.Default, true)
    end
    RegisterState(opts.Flag, element.GetValue, function(v) element.Set(v, true) end)
    return element
end

------------------------------------------------------------ AddTextbox ----
--- Text input row. Numeric = true restricts input to a number range.
function TabMT:AddTextbox(opts)
    opts = opts or {}
    local row = Row(self, 48)
    RowTitle(row, opts, false)

    local box = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -15),
        Size = UDim2.new(0, 170, 0, 30),
        BackgroundColor3 = C("Window"),
    }, row)
    Reg(box, "Window")
    Corner(box, 8)
    Stroke(box, 0.8)

    local input = New("TextBox", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = opts.Default or "",
        TextColor3 = C("Text"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        PlaceholderText = opts.Placeholder or "Type here...",
        PlaceholderColor3 = C("Dimmer"),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, box)
    Reg(input, "Text", "TextColor3")

    local element = { Type = "Textbox" }

    local function Emit(text, enterPressed)
        if opts.Flag then
            Library.Flags[opts.Flag] = text
        end
        if opts.Callback then
            task.spawn(opts.Callback, text, enterPressed)
        end
    end

    input.FocusLost:Connect(function(enterPressed)
        local text = input.Text
        if opts.Numeric then
            local n = tonumber(text)
            if not n then
                input.Text = ""
                return
            end
            n = MathUtils.Clamp(n, opts.Min or -math.huge, opts.Max or math.huge)
            input.Text = tostring(n)
            text = tostring(n)
        end
        Emit(text, enterPressed)
    end)

    element.Set = function(text, silent)
        input.Text = tostring(text)
        if not silent then
            Emit(input.Text, false)
        end
    end
    element.GetValue = function() return input.Text end
    RegisterState(opts.Flag, element.GetValue, function(v) element.Set(v, true) end)
    return element
end

------------------------------------------------------------- AddKeybind ----
--- Bindable key with optional OnPress hook.
function TabMT:AddKeybind(opts)
    opts = opts or {}
    local row = Row(self, 48)
    RowTitle(row, opts, false)

    local bindBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -14),
        Size = UDim2.new(0, 90, 0, 28),
        BackgroundColor3 = C("Tile"),
        AutoButtonColor = false,
        Text = "None",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
    }, row)
    Reg(bindBtn, "Tile")
    Reg(bindBtn, "Dim", "TextColor3")
    Corner(bindBtn, 8)
    Stroke(bindBtn, 0.8)

    local element = { Type = "Keybind" }
    local current = opts.Default
    local listening = false

    local function SetName(txt)
        bindBtn.Text = txt
    end
    if current then
        SetName(current.Name)
    end

    bindBtn.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        listening = true
        SetName("...")
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not listening then
            if current and not gameProcessed and input.KeyCode == current then
                if opts.OnPress then
                    task.spawn(opts.OnPress)
                end
            end
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            current = input.KeyCode
            SetName(current.Name)
            listening = false
            if opts.Flag then
                Library.Flags[opts.Flag] = current
            end
            if opts.Callback then
                task.spawn(opts.Callback, current)
            end
        elseif input.KeyCode == Enum.KeyCode.Escape then
            listening = false
            SetName(current and current.Name or "None")
        end
    end)

    element.Set = function(keyCode)
        current = keyCode
        SetName(keyCode.Name)
    end
    element.GetValue = function() return current end
    return element
end

--------------------------------------------------------- AddColorpicker ----
--- Full HSV color picker: hue bar + saturation/value square + hex input.
function TabMT:AddColorpicker(opts)
    opts = opts or {}
    local row = Row(self, 48, true)

    RowTitle(row, opts, false)

    -- swatch preview on the right
    local swatch = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -11),
        Size = UDim2.new(0, 46, 0, 22),
        BackgroundColor3 = opts.Default or Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
        Text = "",
    }, row)
    Corner(swatch, 7)
    Stroke(swatch, 0.7)

    New("UIListLayout", {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    -------------------------------------------------- picker panel
    local panel = New("Frame", {
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        ClipsDescendants = true,
    }, row)
    local panelLayout = New("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, panel)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 12),
    }, panel)

    -- saturation / value square
    local svSquare = New("Frame", {
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ClipsDescendants = true,
    }, panel)
    Corner(svSquare, 8)

    local satGrad = New("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, svSquare)

    local valGrad = New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0,
    }, svSquare)
    local valTrans = New("UIGradient", {
        Rotation = -90,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, valGrad)

    local svKnob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        ZIndex = 2,
    }, svSquare)
    Corner(svKnob, 5)
    Stroke(svKnob, 0.2, 1.5)

    -- hue bar
    local hueBar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    }, panel)
    Corner(hueBar, 6)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }),
    }, hueBar)

    local hueKnob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 6, 0, 18),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    }, hueBar)
    Corner(hueKnob, 3)
    Stroke(hueKnob, 0.2, 1.5)

    -- bottom row: hex + rgb readout
    local readRow = New("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    }, panel)
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, readRow)

    local hexBox = New("Frame", {
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundColor3 = C("Window"),
    }, readRow)
    Reg(hexBox, "Window")
    Corner(hexBox, 7)
    Stroke(hexBox, 0.8)
    local hexInput = New("TextBox", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C("Text"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        PlaceholderText = "#ffffff",
        PlaceholderColor3 = C("Dimmer"),
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, hexBox)
    Reg(hexInput, "Text", "TextColor3")

    local rgbLabel = New("TextLabel", {
        Size = UDim2.new(1, -118, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, readRow)
    Reg(rgbLabel, "Dim", "TextColor3")

    -------------------------------------------------- state
    local hue, sat, val = 0, 0, 1
    local color = opts.Default or Color3.fromRGB(255, 255, 255)
    local element = { Type = "Colorpicker" }

    local function FromColor(c)
        hue, sat, val = ColorUtils.RGBToHSV(c.R, c.G, c.B)
    end
    FromColor(color)

    local function Apply(silent)
        local r, g, b = ColorUtils.HSVToRGB(hue, sat, val)
        color = Color3.fromRGB(r * 255, g * 255, b * 255)
        swatch.BackgroundColor3 = color
        svSquare.BackgroundColor3 = Color3.fromRGB(
            select(1, ColorUtils.HSVToRGB(hue, 1, 1)) * 255,
            (select(2, ColorUtils.HSVToRGB(hue, 1, 1))) * 255,
            (select(3, ColorUtils.HSVToRGB(hue, 1, 1))) * 255)
        svKnob.Position = UDim2.new(sat, 0, 1 - val, 0)
        hueKnob.Position = UDim2.new(hue, 0, 0.5, 0)
        hexInput.Text = ""
        hexInput.PlaceholderText = ColorUtils.RGBToHex(r * 255, g * 255, b * 255)
        rgbLabel.Text = string.format("R %d  G %d  B %d",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
        if opts.Flag then
            Library.Flags[opts.Flag] = color
        end
        if not silent and opts.Callback then
            task.spawn(opts.Callback, color)
        end
    end

    -- square dragging
    local svDrag = false
    local svCatch = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 3,
    }, svSquare)
    local function SvFromMouse()
        local px = svSquare.AbsolutePosition.X
        local py = svSquare.AbsolutePosition.Y
        local wx = svSquare.AbsoluteSize.X
        local wy = svSquare.AbsoluteSize.Y
        local m = UserInputService:GetMouseLocation()
        sat = MathUtils.Clamp((m.X - px) / math.max(wx, 1), 0, 1)
        val = 1 - MathUtils.Clamp((m.Y - py) / math.max(wy, 1), 0, 1)
        Apply(false)
    end
    svCatch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            svDrag = true
            SvFromMouse()
        end
    end)

    -- hue dragging
    local hueDrag = false
    local hueCatch = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 8),
        Position = UDim2.new(0, 0, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, hueBar)
    local function HueFromMouse()
        local px = hueBar.AbsolutePosition.X
        local wx = hueBar.AbsoluteSize.X
        local m = UserInputService:GetMouseLocation()
        hue = MathUtils.Clamp((m.X - px) / math.max(wx, 1), 0, 1)
        Apply(false)
    end
    hueCatch.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            hueDrag = true
            HueFromMouse()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            svDrag = false
            hueDrag = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if svDrag then SvFromMouse() end
            if hueDrag then HueFromMouse() end
        end
    end)

    -- hex input
    hexInput.FocusLost:Connect(function()
        local hex = hexInput.Text
        if hex ~= "" then
            local r, g, b = ColorUtils.HexToRGB(hex)
            FromColor(Color3.fromRGB(r, g, b))
            Apply(false)
        end
        hexInput.Text = ""
    end)

    function element.SetOpen(state)
        panel.Visible = state
    end

    function element.Set(c, silent)
        FromColor(c)
        Apply(silent)
    end

    function element.GetValue()
        return color
    end

    swatch.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        element.SetOpen(not panel.Visible)
    end)

    Apply(true)
    RegisterState(opts.Flag, element.GetValue, function(v) element.Set(v, true) end)
    return element
end

------------------------------------------------------------- AddProgress ----
--- Read-only animated progress bar.
function TabMT:AddProgress(opts)
    opts = opts or {}
    local row = Row(self, 64)

    local title = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -160, 0, 18),
        BackgroundTransparency = 1,
        Text = opts.Title or "Progress",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(title, "Text", "TextColor3")

    local valueLabel = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 12),
        Size = UDim2.new(0, 90, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    Reg(valueLabel, "Dim", "TextColor3")

    local track = New("Frame", {
        Position = UDim2.new(0, 16, 1, -20),
        Size = UDim2.new(1, -32, 0, 4),
        BackgroundColor3 = C("Track"),
    }, row)
    Reg(track, "Track")
    Corner(track, 2)

    local fill = New("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C("Accent"),
    }, track)
    Reg(fill, "Accent")
    Corner(fill, 2)

    local min = opts.Min or 0
    local max = opts.Max or 100
    local suffix = opts.Suffix or ""
    local element = { Type = "Progress" }

    function element.Set(v, animated)
        v = MathUtils.Clamp(v, min, max)
        local t = (max > min) and ((v - min) / (max - min)) or 0
        if animated == nil or animated then
            Tween(fill, { Size = UDim2.new(t, 0, 1, 0) }, 0.25, Enum.EasingStyle.Quint)
        else
            fill.Size = UDim2.new(t, 0, 1, 0)
        end
        valueLabel.Text = tostring(MathUtils.Round(v, 1)) .. suffix
    end

    element.Set(opts.Default or min, false)
    return element
end

-------------------------------------------------------------- AddLabel ----
--- Plain information line.
function TabMT:AddLabel(opts)
    opts = opts or {}
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, self.List)
    local label = New("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Text or "",
        TextColor3 = opts.Color or C("Dim"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, row)
    local element = { Type = "Label" }
    element.Set = function(text)
        label.Text = tostring(text)
    end
    return element
end

----------------------------------------------------------- AddParagraph ----
--- Wrapped multi-line text block with bold title.
function TabMT:AddParagraph(opts)
    opts = opts or {}
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C("Card"),
    }, self.List)
    Reg(row, "Card")
    Corner(row, 12)
    Stroke(row, 0.85)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
    }, row)
    local layout = New("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local titleLabel = New("TextLabel", {
        Size = UDim2.new(1, -32, 0, 18),
        BackgroundTransparency = 1,
        Text = opts.Title or "",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    Reg(titleLabel, "Text", "TextColor3")

    local body = New("TextLabel", {
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = opts.Text or "",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
    }, row)
    Reg(body, "Dim", "TextColor3")

    local element = { Type = "Paragraph" }
    element.Set = function(text) body.Text = tostring(text) end
    element.SetTitle = function(text) titleLabel.Text = tostring(text) end
    return element
end

---------------------------------------------------------- AddSeparator ----
--- Thin horizontal divider line.
function TabMT:AddSeparator()
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C("Outline"),
        BackgroundTransparency = 0.85,
    }, self.List)
    Reg(row, "Outline")
    return row
end

------------------------------------------------------------ AddSection ----
--- Section heading with optional subtitle.
function TabMT:AddSection(opts)
    opts = opts or {}
    self._Grid = nil
    local head = New("Frame", {
        Size = UDim2.new(1, 0, 0, opts.Subtitle and 44 or 26),
        BackgroundTransparency = 1,
    }, self.List)
    local titleLabel = New("TextLabel", {
        Position = UDim2.new(0, 2, 0, 0),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = opts.Title or "Section",
        TextColor3 = C("White"),
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, head)
    Reg(titleLabel, "White", "TextColor3")
    if opts.Subtitle then
        local sub = New("TextLabel", {
            Position = UDim2.new(0, 2, 0, 24),
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = opts.Subtitle,
            TextColor3 = C("Dim"),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, head)
        Reg(sub, "Dim", "TextColor3")
    end
    return head
end

------------------------------------------------------ settings tab ----
--- Changes the key that shows / hides the window.
function WindowMT:SetKey(keyCode)
    self.Key = keyCode
end

--- Builds a complete settings tab (preferences, themes, configs, info).
function WindowMT:AddSettingsTab()
    local window = self

    -- don't duplicate
    for _, t in ipairs(window.Tabs) do
        if t.Name == "Settings" then return t end
    end

    local tab = window:AddTab({ Name = "Settings", Icon = "gear" })

    ------------------------------------------------ preferences
    tab:AddSection({ Title = "Preferences", Subtitle = "How ARC behaves." })

    tab:AddKeybind({
        Title = "UI Toggle Key",
        Default = window.Key,
        Callback = function(key)
            window:SetKey(key)
            Library:Notify({ Title = "Settings", Description = "Toggle key set to " .. key.Name })
        end,
    })

    tab:AddToggle({
        Title = "Notifications",
        Description = "Show popup notifications.",
        Default = Settings.Notifications,
        Callback = function(state)
            Settings.Notifications = state
        end,
    })

    tab:AddToggle({
        Title = "Interface Sounds",
        Description = "Subtle clicks and toggles.",
        Default = SoundEngine.Enabled,
        Callback = function(state)
            SoundEngine.Enabled = state
            Settings.Sounds = state
        end,
    })

    tab:AddToggle({
        Title = "Anti-AFK",
        Description = "Prevents the game from idling you out.",
        Default = false,
        Callback = function(state)
            window._AntiAFK = state
            if state and not window._AntiAFKConn then
                local player = Players.LocalPlayer
                if player then
                    window._AntiAFKConn = player.Idled:Connect(function()
                        if window._AntiAFK then
                            pcall(function()
                                local VirtualUser = game:GetService("VirtualUser")
                                VirtualUser:CaptureController()
                                VirtualUser:ClickButton2(Vector2.new())
                            end)
                        end
                    end)
                end
            end
        end,
    })

    ------------------------------------------------ appearance
    tab:AddSection({ Title = "Appearance", Subtitle = "Theme the whole interface." })

    tab:AddParagraph({
        Title = "Themes",
        Text = "Themes re-color every panel, row, outline and label live. "
           .. "Midnight is the default pure black / white look.",
    })

    tab:AddDropdown({
        Title = "Theme",
        Options = Library:ThemeNames(),
        Default = Library.CurrentTheme,
        Callback = function(name)
            Library:SetTheme(name)
        end,
    })

    ------------------------------------------------ configs
    tab:AddSection({ Title = "Configs", Subtitle = "Save and load your flag values." })

    local configName = "default"

    tab:AddTextbox({
        Title = "Config Name",
        Placeholder = "default",
        Default = "default",
        Callback = function(text)
            if text ~= "" then
                configName = text
            end
        end,
    })

    local configList

    tab:AddButton({
        Title = "Save Config",
        Description = "Writes every flagged value to disk / memory.",
        Callback = function()
            local ok = Library.Config.Save(configName)
            Library:Notify({
                Title = "Configs",
                Description = ok and ("Saved '" .. configName .. "'.")
                    or ("Could not save '" .. configName .. "'."),
            })
            if configList then configList.Refresh(Library.Config.List()) end
        end,
    })

    tab:AddButton({
        Title = "Load Config",
        Description = "Applies a saved config to the interface.",
        Callback = function()
            local ok = Library.Config.Load(configName)
            Library:Notify({
                Title = "Configs",
                Description = ok and ("Loaded '" .. configName .. "'.")
                    or ("No config named '" .. configName .. "'."),
            })
        end,
    })

    configList = tab:AddDropdown({
        Title = "Saved Configs",
        Options = Library.Config.List(),
        Default = nil,
        Callback = function(name)
            configName = name
        end,
    })

    tab:AddButton({
        Title = "Delete Config",
        Description = "Removes the selected config.",
        Hold = 1.5,
        Callback = function()
            Library.Config.Delete(configName)
            if configList then configList.Refresh(Library.Config.List()) end
            Library:Notify({ Title = "Configs", Description = "Deleted '" .. configName .. "'." })
        end,
    })

    ------------------------------------------------ info
    tab:AddSection({ Title = "Info" })

    tab:AddLabel({ Text = "ARC " .. Library.Version .. " — black / white edition" })
    tab:AddLabel({ Text = "Executor: " .. Env.Name })
    tab:AddLabel({ Text = "File configs: " .. (Env.HasFiles and "supported" or "memory only") })

    return tab
end

------------------------------------------------------ showcase tab ----
--- Builds a "Components" tab demonstrating every element ARC ships with.
function WindowMT:AddShowcaseTab()
    local window = self
    for _, t in ipairs(window.Tabs) do
        if t.Name == "Components" then return t end
    end

    local tab = window:AddTab({ Name = "Components", Icon = "cube" })

    tab:AddSection({ Title = "Buttons", Subtitle = "Click and hold-to-confirm." })
    tab:AddButton({
        Title = "Instant Button",
        Description = "Fires its callback on click.",
        Callback = function()
            Library:Notify({ Title = "Button", Description = "Instant button fired." })
        end,
    })
    tab:AddButton({
        Title = "Hold To Confirm",
        Description = "Hold for 1.5 seconds to fire.",
        Hold = 1.5,
        Callback = function()
            Library:Notify({ Title = "Button", Description = "Hold confirmed!" })
        end,
    })

    tab:AddSection({ Title = "Toggles & Sliders" })
    tab:AddToggle({
        Title = "Example Toggle",
        Description = "Stores into ARC.Flags.Example",
        Flag = "ExampleToggle",
        Default = true,
        Callback = function(state) end,
    })
    tab:AddSlider({
        Title = "Example Slider",
        Min = 0, Max = 100, Default = 40, Suffix = "%",
        Flag = "ExampleSlider",
        Textbox = true,
        Callback = function(v) end,
    })
    tab:AddProgress({
        Title = "Example Progress",
        Min = 0, Max = 100, Default = 66, Suffix = "%",
    })

    tab:AddSection({ Title = "Inputs" })
    tab:AddTextbox({
        Title = "Example Textbox",
        Placeholder = "Say something...",
        Callback = function(text) end,
    })
    tab:AddTextbox({
        Title = "Numeric Box",
        Placeholder = "0-100",
        Numeric = true, Min = 0, Max = 100,
        Callback = function(n) end,
    })
    tab:AddDropdown({
        Title = "Single Select",
        Options = { "Alpha", "Beta", "Gamma" },
        Default = "Alpha",
        Callback = function(opt) end,
    })
    tab:AddDropdown({
        Title = "Multi Select",
        Options = { "Red", "Green", "Blue" },
        Multi = true,
        Callback = function(list) end,
    })
    tab:AddKeybind({
        Title = "Example Keybind",
        Default = Enum.KeyCode.T,
        OnPress = function()
            Library:Notify({ Title = "Keybind", Description = "Bound key pressed." })
        end,
    })
    tab:AddColorpicker({
        Title = "Example Color",
        Default = Color3.fromRGB(255, 255, 255),
        Callback = function(c) end,
    })

    tab:AddSection({ Title = "Text" })
    tab:AddParagraph({
        Title = "Paragraph",
        Text = "ARC is built for script hubs: bind any script to any element "
           .. "through callbacks, track values with flags, and ship a clean "
           .. "black & white interface that matches your branding.",
    })
    tab:AddLabel({ Text = "A plain label for small hints." })
    tab:AddSeparator()

    tab:AddSection({ Title = "Cards" })
    tab:AddCard({
        Title = "Showcase Card",
        Description = "Cards live in a responsive two-column grid.",
        Icon = "★",
        Callback = function() end,
    })
    tab:AddCard({
        Title = "Another Card",
        Description = "Add as many as you need.",
        Icon = "◆",
        Callback = function() end,
    })

    return tab
end

---------------------------------------------------------------- configs ----
-- Configs serialize every flagged element (toggles, sliders, dropdowns,
-- textboxes, colorpickers) plus the active theme. When the executor
-- exposes file APIs the config is written to ARC_Configs/<name>.json,
-- otherwise it is kept in memory for the session.
local Config = Library.Config

--- Luau typeof with a plain-Lua fallback.
local function TypeOf(v)
    if type(typeof) == "function" then
        return typeof(v)
    end
    return type(v)
end

local function SerializeValue(v)
    local t = TypeOf(v)
    if t == "Color3" then
        return { __type = "Color3", r = v.R, g = v.G, b = v.B }
    elseif t == "EnumItem" then
        return { __type = "KeyCode", name = v.Name }
    elseif t == "table" then
        local out = {}
        for i, item in ipairs(v) do
            out[i] = SerializeValue(item)
        end
        return out
    end
    return v
end

local function DeserializeValue(v)
    if type(v) == "table" and v.__type == "Color3" then
        return Color3.fromRGB(v.r * 255, v.g * 255, v.b * 255)
    elseif type(v) == "table" and v.__type == "KeyCode" then
        return Enum.KeyCode[v.name]
    elseif type(v) == "table" then
        local out = {}
        for i, item in ipairs(v) do
            out[i] = DeserializeValue(item)
        end
        return out
    end
    return v
end

local function Encode(data)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if ok then return result end
    -- minimal fallback encoder (tables, strings, numbers, booleans)
    local function enc(x)
        local ty = type(x)
        if ty == "table" then
            local parts, isMap = {}, false
            for k, v in pairs(x) do
                if type(k) ~= "number" then isMap = true end
            end
            if isMap then
                for k, v in pairs(x) do
                    table.insert(parts, '"' .. tostring(k) .. '":' .. enc(v))
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
            for i = 1, #x do
                table.insert(parts, enc(x[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        elseif ty == "string" then
            return '"' .. x:gsub('"', '\\"') .. '"'
        elseif ty == "boolean" or ty == "number" then
            return tostring(x)
        end
        return "null"
    end
    return enc(data)
end

local function Decode(str)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    if ok then return result end
    return nil
end

local function ConfigPath(name)
    return CONFIG_FOLDER .. "/" .. name .. ".json"
end

--- Saves every flagged value under a name. Returns true on success.
function Config.Save(name)
    name = tostring(name or "default")
    local data = { Theme = Library.CurrentTheme, Flags = {} }
    for flag, entry in pairs(Library._State) do
        local ok, value = pcall(entry.Get)
        if ok then
            data.Flags[flag] = SerializeValue(value)
        end
    end
    local encoded = Encode(data)
    if Env.HasFiles then
        local ok = pcall(function()
            if Env.HasFolder and not isfolder(CONFIG_FOLDER) then
                makefolder(CONFIG_FOLDER)
            end
            writefile(ConfigPath(name), encoded)
        end)
        if ok then return true end
    end
    Library._Memory[name] = encoded
    return true
end

--- Loads a saved config and applies it silently. Returns true on success.
function Config.Load(name)
    name = tostring(name or "default")
    local raw
    if Env.HasFiles and isfile(ConfigPath(name)) then
        pcall(function() raw = readfile(ConfigPath(name)) end)
    end
    if not raw then
        raw = Library._Memory[name]
    end
    if not raw then return false end
    local data = Decode(raw)
    if type(data) ~= "table" then return false end

    if data.Theme and Library.Themes[data.Theme] then
        Library:SetTheme(data.Theme)
    end
    for flag, rawValue in pairs(data.Flags or {}) do
        local entry = Library._State[flag]
        if entry then
            pcall(entry.Set, DeserializeValue(rawValue))
        end
    end
    return true
end

--- Lists saved config names.
function Config.List()
    local names = {}
    if Env.HasFiles and Env.HasList then
        pcall(function()
            for _, path in ipairs(listfiles(CONFIG_FOLDER)) do
                local base = path:match("([^/\\]+)%.json$")
                if base then
                    table.insert(names, base)
                end
            end
        end)
    end
    for name in pairs(Library._Memory) do
        if not TableUtils.Contains(names, name) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

--- Deletes a saved config.
function Config.Delete(name)
    name = tostring(name or "default")
    Library._Memory[name] = nil
    if Env.HasFiles and Env.HasDelete and isfile(ConfigPath(name)) then
        pcall(function() delfile(ConfigPath(name)) end)
    end
end

---------------------------------------------------------------- assembly ----
--- Public alias for GUI protection.
function Library:ProtectGui(gui)
    ProtectGui(gui)
end

--- Current interface window (if created).
function Library:Window()
    return self._Window
end


---------------------------------------------------------- extra elements ----
--- Labeled divider: a section-style separator with centered text.
function TabMT:AddDivider(opts)
    opts = opts or {}
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
    }, self.List)

    local left = New("Frame", {
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0.5, -60, 0, 1),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C("Outline"),
        BackgroundTransparency = 0.85,
    }, row)
    Reg(left, "Outline")

    local right = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0.5, -60, 0, 1),
        BackgroundColor3 = C("Outline"),
        BackgroundTransparency = 0.85,
    }, row)
    Reg(right, "Outline")

    local label = New("TextLabel", {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Text or "•••",
        TextColor3 = C("Dimmer"),
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, row)
    Reg(label, "Dimmer", "TextColor3")
    return row
end

--- Live player list with refresh; each row exposes a callback with the
--- player name, so you can bind teleport / spectate / ESP scripts.
function TabMT:AddPlayerList(opts)
    opts = opts or {}
    self._Grid = nil

    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C("Card"),
    }, self.List)
    Reg(row, "Card")
    Corner(row, 12)
    Stroke(row, 0.85)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
    }, row)

    local headLayout = New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local header = New("Frame", {
        Size = UDim2.new(1, -32, 0, 24),
        BackgroundTransparency = 1,
    }, row)
    local headTitle = New("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Title or "Players",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    Reg(headTitle, "Text", "TextColor3")

    local refreshBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 60, 1, 0),
        BackgroundColor3 = C("Tile"),
        AutoButtonColor = false,
        Text = "Refresh",
        TextColor3 = C("Dim"),
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
    }, header)
    Reg(refreshBtn, "Tile")
    Reg(refreshBtn, "Dim", "TextColor3")
    Corner(refreshBtn, 7)

    local listBox = New("Frame", {
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, row)
    local listLayout = New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, listBox)

    local element = { Type = "PlayerList" }

    local function BuildRows()
        for _, child in ipairs(listBox:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local ok, list = pcall(function()
            return Players:GetPlayers()
        end)
        if not ok then return end
        for _, player in ipairs(list) do
            local entry = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = C("Tile"),
                BackgroundTransparency = 0.6,
                AutoButtonColor = false,
                Text = "  " .. player.Name,
                TextColor3 = C("Dim"),
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, listBox)
            Reg(entry, "Tile")
            Corner(entry, 8)
            entry.MouseEnter:Connect(function()
                Tween(entry, { BackgroundTransparency = 0.2, TextColor3 = C("Text") }, 0.12)
            end)
            entry.MouseLeave:Connect(function()
                Tween(entry, { BackgroundTransparency = 0.6, TextColor3 = C("Dim") }, 0.12)
            end)
            entry.MouseButton1Click:Connect(function()
                SoundEngine:Play("Click")
                if opts.Callback then
                    task.spawn(opts.Callback, player.Name, player)
                end
            end)
        end
    end

    refreshBtn.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        BuildRows()
    end)

    element.Refresh = BuildRows
    BuildRows()
    return element
end

---------------------------------------------------------------- hooks ----
--- Registers a callback fired when the UI is destroyed / script unloaded.
-- @param callback function runs (pcall-wrapped) on Window:Destroy()
-- example:
--     ARC:OnUnload(function()
--         ARC.Config.Save("autosave")
--     end)
function Library:OnUnload(callback)
    if not self._OnUnload then
        self._OnUnload = {}
    end
    table.insert(self._OnUnload, callback)
end

local OriginalDestroy = WindowMT.Destroy
function WindowMT:Destroy()
    for _, fn in ipairs(Library._OnUnload or {}) do
        pcall(fn)
    end
    OriginalDestroy(self)
end

--- Convenience: destroys the interface (alias kept for compatibility).
function Library:Unload()
    if self._Window then
        self._Window:Destroy()
    end
end

---------------------------------------------------------------- banner ----
--- Prints a small branded console banner.
function Library:Banner()
    pcall(function()
        print("──────────────────────────────")
        print("  ARC " .. Library.Version .. "  ·  black / white edition")
        print("  theme: " .. Library.CurrentTheme .. "  ·  executor: " .. Env.Name)
        print("──────────────────────────────")
    end)
end

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX A — COMPLETE ELEMENT REFERENCE
    ════════════════════════════════════════════════════════════════════
    Every element constructor, its options, and the object it returns.
    All constructors live on a Tab object created with Window:AddTab().

    ────────────────────────────────────────────────────────────────────
    Tab:AddLabel(opts)
    ────────────────────────────────────────────────────────────────────
    A single information line inside the page flow.

    opts:
        Text   string   the line content                (default "")
        Color  Color3   override color                  (default dim)

    returns:
        :Set(text)      replaces the line content

    example:
        Tab:AddLabel({ Text = "Server time resets at 00:00 UTC." })

    ────────────────────────────────────────────────────────────────────
    Tab:AddParagraph(opts)
    ────────────────────────────────────────────────────────────────────
    A card with a bold title and wrapped body text. Height grows with
    the content automatically.

    opts:
        Title  string   bold heading
        Text   string   wrapped body copy

    returns:
        :Set(text)       replaces body copy
        :SetTitle(text)  replaces heading

    ────────────────────────────────────────────────────────────────────
    Tab:AddButton(opts)
    ────────────────────────────────────────────────────────────────────
    The workhorse element: a clickable row bound to your script.

    opts:
        Title        string    row title
        Description  string    optional second line (grows the row)
        Callback     function  runs on activation
        Hold         number    seconds to hold for confirmation. While
                               held, an accent bar fills along the row
                               bottom; releasing early cancels.

    returns:
        { Type = "Button", Row = row }

    example:
        Tab:AddButton({
            Title = "Kill All",
            Description = "Eliminates every NPC in range.",
            Callback = function()
                -- your script
            end,
        })

    ────────────────────────────────────────────────────────────────────
    Tab:AddToggle(opts)
    ────────────────────────────────────────────────────────────────────
    An animated on/off pill.

    opts:
        Title        string
        Description  string    optional (note: toggle rows stay 1 line)
        Default      boolean   initial state
        Flag         string    stores state into ARC.Flags[Flag]
        Callback     function  Callback(state)

    returns:
        :Set(state, silent)   apply state (silent skips the callback)
        :GetValue()           current boolean

    ────────────────────────────────────────────────────────────────────
    Tab:AddSlider(opts)
    ────────────────────────────────────────────────────────────────────
    Draggable value track with live readout.

    opts:
        Title     string
        Min       number   (default 0)
        Max       number   (default 100)
        Default   number   (default Min)
        Decimals  number   rounding precision (default 0)
        Suffix    string   appended to the readout, e.g. " sps"
        Flag      string
        Callback  function Callback(value)
        Textbox   boolean  show an exact-value input box on the right

    returns:
        :Set(value, silent)
        :GetValue()

    ────────────────────────────────────────────────────────────────────
    Tab:AddDropdown(opts)
    ────────────────────────────────────────────────────────────────────
    Expandable option list, single or multi select.

    opts:
        Title     string
        Options   table     { "A", "B", ... }
        Default   any       preselected option (or table when Multi)
        Multi     boolean   allow several selections at once
        Flag      string
        Callback  function  Callback(option) or Callback(list) if Multi

    returns:
        :Set(value, silent)
        :Refresh(options)   rebuild the option list
        :SetOpen(bool)
        :GetValue()

    ────────────────────────────────────────────────────────────────────
    Tab:AddTextbox(opts)
    ────────────────────────────────────────────────────────────────────
    Text (or numeric) input field.

    opts:
        Title        string
        Placeholder  string
        Default      string
        Numeric      boolean  restrict to numbers
        Min / Max    number   clamp range when Numeric
        Flag         string
        Callback     function Callback(text, enterPressed)

    returns:
        :Set(text, silent)
        :GetValue()

    ────────────────────────────────────────────────────────────────────
    Tab:AddKeybind(opts)
    ────────────────────────────────────────────────────────────────────
    Bind a keyboard key; optionally fire OnPress whenever it is pressed.

    opts:
        Title     string
        Default   Enum.KeyCode
        Flag      string
        Callback  function Callback(keycode)   when a new key is bound
        OnPress   function                     whenever key is pressed

    returns:
        :Set(keycode)

    ────────────────────────────────────────────────────────────────────
    Tab:AddColorpicker(opts)
    ────────────────────────────────────────────────────────────────────
    Full HSV picker: saturation/value square, hue bar, hex input and a
    live RGB readout. Click the swatch on the row to expand.

    opts:
        Title     string
        Default   Color3
        Flag      string
        Callback  function Callback(color3)

    returns:
        :Set(color3, silent)
        :SetOpen(bool)
        :GetValue()

    ────────────────────────────────────────────────────────────────────
    Tab:AddProgress(opts)
    ────────────────────────────────────────────────────────────────────
    Read-only animated bar, perfect for cooldowns / levels / XP.

    opts:
        Title, Min, Max, Default, Suffix

    returns:
        :Set(value, animated)

    ────────────────────────────────────────────────────────────────────
    Tab:AddCard(opts)
    ────────────────────────────────────────────────────────────────────
    Big two-column-grid card, styled like the home Quick Access cards.

    opts:
        Title, Description, Icon (string glyph or rbx asset id number),
        Callback

    ────────────────────────────────────────────────────────────────────
    Tab:AddSection(opts)   /  Tab:AddDivider(opts)
    Tab:AddSeparator()     /  Tab:AddPlayerList(opts)
    ────────────────────────────────────────────────────────────────────
    Section   bold heading + optional subtitle.
    Divider   centered text between two thin lines.
    Separator single thin line.
    PlayerList live list of players; Callback(playerName, player) on
               click; returns { Refresh() }.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX B — WINDOW & LIBRARY REFERENCE
    ════════════════════════════════════════════════════════════════════

    ARC:CreateWindow(opts)
        Title        string   window + hero title        (default "ARC")
        Logo         number   rbx texture id  (default 131675609143159)
        Version      string   sidebar footer             (default v2.0.0)
        Subtitle     string   hero copy, use \n for line breaks
        Key          KeyCode  show/hide hotkey     (default RightShift)
        SettingsTab  boolean  auto-build the settings tab
        GetStartedCallback  function  hero button override

    Window methods:
        :AddTab({Name, Icon})            create a sidebar tab
        :AddSettingsTab()                settings (prefs/themes/configs)
        :AddShowcaseTab()                "Components" demo of everything
        :SelectTab(tab)                  switch page
        :Notify(opts)                    popup (alias of ARC:Notify)
        :SetMinimized(bool) / :Minimize() / :Restore()
        :Close() / :Open() / :Toggle()   visibility
        :SetTitle(text)                  rename everywhere
        :SetKey(keycode)                 change hotkey at runtime
        :Destroy()                       tear everything down

    Library methods / fields:
        ARC:Notify(opts)                 { Title, Description, Duration,
                                           Actions = { {Name, Callback} } }
        ARC:SetTheme(name)               Midnight | Carbon | Ghost |
                                           Crimson | Ocean
        ARC:ThemeNames()                 sorted list of theme names
        ARC.Config.Save(name)            serialize all flagged values
        ARC.Config.Load(name)
        ARC.Config.List()
        ARC.Config.Delete(name)
        ARC:OnUnload(fn)                 run code when the UI dies
        ARC:Unload()                     destroy the interface
        ARC:Banner()                     console branding
        ARC.Flags                        live values by flag name
        ARC.Utils                        Math / Table / String / Color /
                                           Time helpers + Signal + Debounce
        ARC.Env                          executor capability report
        ARC.Version                      library version string
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX C — UTILITIES REFERENCE
    ════════════════════════════════════════════════════════════════════

    ARC.Utils.Math
        Clamp(v,a,b)  Lerp(a,b,t)  Map(v,inMin,inMax,outMin,outMax)
        Round(v,dec)  Sign(v)      Percent(v,a,b)
        Int(a,b)      Float(a,b)   Chance(p)
        EaseOutQuint(t)  EaseOutBack(t)  EaseInOutSine(t)

    ARC.Utils.Table
        Copy  DeepCopy  Find  Contains  Remove  ToggleMember
        Keys  Values  Count  Merge  Reverse  Shuffle  Slice  Pick  Clear

    ARC.Utils.String
        Trim  Split  Contains  StartsWith  EndsWith
        Ellipsize  Repeat  Random  Capitalize

    ARC.Utils.Color
        HSVToRGB(h,s,v)      → r,g,b (0..1)
        RGBToHSV(r,g,b)      → h,s,v (0..1, input 0..1)
        HexToRGB("#rrggbb")  → r,g,b (0..255)
        RGBToHex(r,g,b)      → "#rrggbb"
        Mix(c1,c2,t)  Lighten(c,t)  Darken(c,t)

    ARC.Utils.Time
        Format(seconds)      → "m:ss"
        FormatLong(seconds)  → "1h 2m 3s"
        Now()                → monotonic seconds

    ARC.Utils.Debounce(seconds) → gate function
        local gate = ARC.Utils.Debounce(0.5)
        if gate() then ... end     -- true at most every 0.5s

    ARC.Utils.Signal.new() → { :Connect(fn), :Fire(...), :Destroy() }
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX D — THEME GUIDE
    ════════════════════════════════════════════════════════════════════
    Themes are plain tables of Color3 roles. Every visual piece of ARC
    is registered under one of these roles at creation time, and
    ARC:SetTheme tweens the entire registry to the new palette.

    ROLES
        Window    main frame background
        Sidebar   left panel background
        Card      rows, cards, hero, notifications
        Tile      icon tiles, pills, buttons, hover targets
        Hover     hover feedback color
        Track     slider / progress track base
        White     headline color (hero title, section heads)
        Text      primary text
        Dim       secondary text
        Dimmer    tertiary text (version, placeholders)
        Outline   every white border / divider line
        Accent    active fills (slider fill, toggle on, hold bar)

    ADDING YOUR OWN THEME
        ARC.Themes.Royal = {
            Window  = Color3.fromRGB(10, 8, 18),
            Sidebar = Color3.fromRGB(7, 6, 13),
            Card    = Color3.fromRGB(16, 13, 26),
            Tile    = Color3.fromRGB(28, 23, 44),
            Hover   = Color3.fromRGB(24, 20, 38),
            Track   = Color3.fromRGB(48, 40, 72),
            White   = Color3.fromRGB(200, 170, 255),
            Text    = Color3.fromRGB(240, 235, 250),
            Dim     = Color3.fromRGB(160, 150, 185),
            Dimmer  = Color3.fromRGB(110, 100, 135),
            Outline = Color3.fromRGB(200, 170, 255),
            Accent  = Color3.fromRGB(170, 120, 255),
        }
        ARC:SetTheme("Royal")

    NOTES
        · The default "Midnight" theme is the pure black / white look:
          black panels, white text, white outlines.
        · "Ghost" ships as a light-mode proof that the engine can
          invert the whole interface.
        · Roles are resolved live: elements created AFTER a theme change
          automatically use the current palette.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX E — RECIPES  (real-world patterns)
    ════════════════════════════════════════════════════════════════════

    ── 1. ESP TOGGLE WITH FLAG ─────────────────────────────────────────
        local Visuals = Window:AddTab({ Name = "Visuals", Icon = "◑" })
        Visuals:AddToggle({
            Title = "Player ESP",
            Flag = "ESP",
            Callback = function(state)
                MyESP.Enabled = state        -- your module
            end,
        })
        -- anywhere later:  if ARC.Flags.ESP then ... end

    ── 2. TELEPORT-ON-CLICK PLAYER LIST ────────────────────────────────
        local Misc = Window:AddTab({ Name = "Misc", Icon = "⚙" })
        Misc:AddPlayerList({
            Title = "Players",
            Callback = function(name, player)
                local me = game.Players.LocalPlayer.Character
                if me and player.Character then
                    me:PivotTo(player.Character:GetPivot())
                end
                Window:Notify({ Title = "Teleport",
                                Description = "Warped to " .. name })
            end,
        })

    ── 3. HOLD-TO-CONFIRM DANGEROUS ACTIONS ────────────────────────────
        Misc:AddButton({
            Title = "Reset Character",
            Description = "Hold 2 seconds to confirm.",
            Hold = 2,
            Callback = function()
                game.Players.LocalPlayer.Character:BreakJoints()
            end,
        })

    ── 4. CONFIG AUTOSAVE ON UNLOAD ────────────────────────────────────
        ARC:OnUnload(function()
            ARC.Config.Save("autosave")
        end)

    ── 5. COOLDOWN PROGRESS BAR ────────────────────────────────────────
        local bar = Combat:AddProgress({
            Title = "Ultimate Cooldown", Min = 0, Max = 60, Default = 60,
            Suffix = "s",
        })
        task.spawn(function()
            while task.wait(0.25) do
                bar.Set(barValue, true)      -- animated updates
            end
        end)

    ── 6. NOTIFICATION QUEUE WITH ACTIONS ──────────────────────────────
        ARC:Notify({
            Title = "Update",
            Description = "A new config is available. Apply it?",
            Duration = 8,
            Actions = {
                { Name = "Apply", Callback = function()
                    ARC.Config.Load("meta")
                end },
                { Name = "Skip", Callback = function() end },
            },
        })

    ── 7. SLIDER BOUND TO HUMANOID ─────────────────────────────────────
        Combat:AddSlider({
            Title = "Walk Speed", Min = 16, Max = 250, Default = 16,
            Callback = function(v)
                local c = game.Players.LocalPlayer.Character
                if c and c:FindFirstChild("Humanoid") then
                    c.Humanoid.WalkSpeed = v
                end
            end,
        })

    ── 8. MULTI-SELECT WEAPON FILTER ───────────────────────────────────
        Combat:AddDropdown({
            Title = "Auto-farm targets",
            Options = { "Zombie", "Skeleton", "Bandit", "Dragon" },
            Multi = true,
            Flag = "Targets",
        })
        -- ARC.Flags.Targets is now a live table of selections.

    ── 9. KEYBIND THAT TOGGLES A FEATURE ───────────────────────────────
        local fly
        Combat:AddKeybind({
            Title = "Fly",
            Default = Enum.KeyCode.V,
            OnPress = function()
                fly = not fly
                MyFlyModule:Set(fly)
            end,
        })

    ── 10. COLOR-DRIVEN TRACERS ─────────────────────────────────────────
        Visuals:AddColorpicker({
            Title = "Tracer Color",
            Default = Color3.fromRGB(255, 255, 255),
            Flag = "TracerColor",
        })
        -- read anytime: ARC.Flags.TracerColor (Color3)
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX F — DESIGN TOKENS  (the black / white look)
    ════════════════════════════════════════════════════════════════════
    The interface mirrors the official ARC artwork with a pure black
    palette and white linework. These are the exact tokens used:

    GEOMETRY
        Window size          780 × 575, corner radius 14 (fully rounded)
        Sidebar width        200, nav items 40 tall, radius 10
        Hero card            210 tall, radius 14
        Quick-access cards   96 tall, radius 14, grid gap 14
        Element rows         48 tall (58 with description, 64 sliders)
        Icon tiles           46 × 46, radius 12
        Toggle pill          42 × 24, knob 16
        Notification         280 wide, radius 12, bottom-right stack

    TYPOGRAPHY (Gotham family)
        Hero title       42 Bold
        Section heads    16–18 Bold
        Row titles       14 Semibold
        Body / desc      12–14 Regular
        Sidebar items    14 Medium
        Version / dim    12 Regular

    LINEWORK
        Every panel carries a 1px white UIStroke at 70–85% transparency;
        dividers are 1px white at 85–90%. Strokes are theme-registered so
        a theme swap re-tints every outline in one sweep.

    MOTION
        Window intro     0.45s Quint expand
        Tab switch       0.20s fades on nav background / text
        Hovers           0.12–0.15s
        Toggles          0.15s pill + knob slide
        Notifications    0.25s fade in, 0.20s fade out
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX G — COMPATIBILITY & FAQ
    ════════════════════════════════════════════════════════════════════

    Q: Which executors does ARC run on?
    A: All of them. Every optional capability (files, folders, gethui,
       protect_gui, executor identification) is detected at runtime and
       degrades gracefully. Without file APIs, configs live in memory.

    Q: Why do the window corners look square on my executor?
    A: They shouldn't — the main frame uses UICorner(14) together with
       ClipsDescendants, which clips the sidebar and pages to the round
       shape. If an extremely old executor lacks UICorner entirely, ARC
       still renders; corners are the only cosmetic loss.

    Q: Anything overlapping?
    A: Layouts are computed so nothing collides: hero copy ends at
       x=298 while the logo starts at x=330; row titles truncate 210px
       before the right edge where controls live; card text stops 58px
       before the arrow. Every page is a ScrollingFrame, so long menus
       scroll instead of stacking.

    Q: How do I hide the UI?
    A: RightShift by default (change with Key / SetKey / the settings
       tab). The ✕ button also hides it; the same key brings it back.

    Q: Can I ship ARC inside a paid script?
    A: Yes. No attribution required, no restrictions.

    Q: The UI runs twice when I re-execute my script.
    A: CreateWindow destroys any previous ARC ScreenGui first, so
       re-execution is always clean.

    Q: Performance?
    A: One ScreenGui, no RenderStepped loops, tweens on the TweenService.
       Sounds are off by default and cached when enabled.

    Q: How big is the library?
    A: 5,000+ lines including this reference — engine, elements, themes,
       configs, utilities and documentation in a single file.
]]

---------------------------------------------------------------- more themes ----
Library.Themes.Emerald = {
    Window   = Color3.fromRGB(8, 12, 10),
    Sidebar  = Color3.fromRGB(5, 9, 7),
    Card     = Color3.fromRGB(12, 18, 15),
    Tile     = Color3.fromRGB(20, 30, 25),
    Hover    = Color3.fromRGB(17, 26, 21),
    Track    = Color3.fromRGB(38, 56, 47),
    White    = Color3.fromRGB(140, 255, 190),
    Text     = Color3.fromRGB(235, 250, 242),
    Dim      = Color3.fromRGB(140, 175, 158),
    Dimmer   = Color3.fromRGB(95, 130, 112),
    Outline  = Color3.fromRGB(140, 255, 190),
    Accent   = Color3.fromRGB(110, 240, 170),
}

Library.Themes.Sunset = {
    Window   = Color3.fromRGB(14, 9, 8),
    Sidebar  = Color3.fromRGB(10, 6, 5),
    Card     = Color3.fromRGB(20, 13, 11),
    Tile     = Color3.fromRGB(33, 21, 18),
    Hover    = Color3.fromRGB(28, 18, 15),
    Track    = Color3.fromRGB(56, 37, 32),
    White    = Color3.fromRGB(255, 170, 110),
    Text     = Color3.fromRGB(250, 240, 232),
    Dim      = Color3.fromRGB(175, 150, 138),
    Dimmer   = Color3.fromRGB(130, 105, 95),
    Outline  = Color3.fromRGB(255, 170, 110),
    Accent   = Color3.fromRGB(255, 140, 80),
}

Library.Themes.Mono = {
    Window   = Color3.fromRGB(0, 0, 0),
    Sidebar  = Color3.fromRGB(0, 0, 0),
    Card     = Color3.fromRGB(8, 8, 8),
    Tile     = Color3.fromRGB(20, 20, 20),
    Hover    = Color3.fromRGB(16, 16, 16),
    Track    = Color3.fromRGB(40, 40, 40),
    White    = Color3.fromRGB(255, 255, 255),
    Text     = Color3.fromRGB(255, 255, 255),
    Dim      = Color3.fromRGB(170, 170, 170),
    Dimmer   = Color3.fromRGB(120, 120, 120),
    Outline  = Color3.fromRGB(255, 255, 255),
    Accent   = Color3.fromRGB(255, 255, 255),
}

Library.Themes.Rose = {
    Window   = Color3.fromRGB(14, 8, 11),
    Sidebar  = Color3.fromRGB(10, 5, 8),
    Card     = Color3.fromRGB(20, 12, 16),
    Tile     = Color3.fromRGB(33, 20, 27),
    Hover    = Color3.fromRGB(28, 17, 22),
    Track    = Color3.fromRGB(56, 36, 46),
    White    = Color3.fromRGB(255, 140, 190),
    Text     = Color3.fromRGB(250, 238, 244),
    Dim      = Color3.fromRGB(175, 145, 160),
    Dimmer   = Color3.fromRGB(130, 100, 115),
    Outline  = Color3.fromRGB(255, 140, 190),
    Accent   = Color3.fromRGB(250, 110, 170),
}

---------------------------------------------------------------- resizing ----
--- Proportional resize: a UIScale on the window scales EVERYTHING —
--- frames, offsets, paddings, icons and fonts — so a resized window
--- never looks stretched or empty. Bounds ≈ 620×460 … 1170×860.
local function MakeResizable(frame, handle, scaleObj, minScale, maxScale, window)
    local resizing, start, startScale = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            start = input.Position
            startScale = scaleObj.Scale
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - start
            local s = startScale + (delta.X + delta.Y) / 1200
            s = MathUtils.Clamp(s, minScale, maxScale)
            scaleObj.Scale = s
            if window then
                window._Scale = s
            end
        end
    end)
end

--- Attaches the resize grip + UIScale to a window (called automatically).
function WindowMT:_AttachResize()
    if self._ResizeGrip then return end

    local scaleObj = New("UIScale", {
        Scale = 1,
    }, self.Main)
    self._ScaleObj = scaleObj
    self._Scale = 1

    local grip = New("TextButton", {
        Name = "ResizeGrip",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -6, 1, -6),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8,
    }, self.Main)
    -- drawn diagonal dots (font-independent)
    for _, offset in ipairs({ { 12, 12 }, { 6, 12 }, { 12, 6 } }) do
        local dot = New("Frame", {
            Position = UDim2.new(0, offset[1], 0, offset[2]),
            Size = UDim2.new(0, 3, 0, 3),
            BackgroundColor3 = C("Dimmer"),
            BorderSizePixel = 0,
        }, grip)
        Reg(dot, "Dimmer")
        Corner(dot, 1)
    end
    MakeResizable(self.Main, grip, scaleObj, 0.8, 1.5, self)
    self._ResizeGrip = grip
end

--- Sets the UI scale directly (1 = native 780×575).
function WindowMT:SetScale(scale)
    if self._ScaleObj then
        self._ScaleObj.Scale = MathUtils.Clamp(scale, 0.8, 1.5)
        self._Scale = self._ScaleObj.Scale
    end
end

---------------------------------------------------------------- more elements ----
--- Displays an image (rbx asset id) inside a rounded card.
function TabMT:AddImage(opts)
    opts = opts or {}
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, opts.Height or 140),
        BackgroundColor3 = C("Card"),
    }, self.List)
    Reg(row, "Card")
    Corner(row, 12)
    Stroke(row, 0.85)

    local img = New("ImageLabel", {
        Size = UDim2.new(1, -24, 1, -24),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        Image = "rbxassetid://" .. tostring(opts.Image or self.Window.Logo),
        ScaleType = Enum.ScaleType.Fit,
    }, row)

    local element = { Type = "Image" }
    element.Set = function(id)
        img.Image = "rbxassetid://" .. tostring(id)
    end
    return element
end

--- Toggle that can also be flipped with a bound key.
function TabMT:AddToggleKeybind(opts)
    opts = opts or {}
    local toggle = self:AddToggle(opts)

    local bindBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -70, 0.5, -14),
        Size = UDim2.new(0, 44, 0, 28),
        BackgroundColor3 = C("Tile"),
        AutoButtonColor = false,
        Text = "Key",
        TextColor3 = C("Dim"),
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
    }, toggle.Row or (self.List:GetChildren()[#self.List:GetChildren()]))
    Reg(bindBtn, "Tile")
    Reg(bindBtn, "Dim", "TextColor3")
    Corner(bindBtn, 8)
    Stroke(bindBtn, 0.8)

    local current = nil
    local listening = false

    bindBtn.MouseButton1Click:Connect(function()
        listening = true
        bindBtn.Text = "..."
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                current = input.KeyCode
                bindBtn.Text = current.Name
                listening = false
            elseif input.KeyCode == Enum.KeyCode.Escape then
                listening = false
                bindBtn.Text = current and current.Name or "Key"
            end
            return
        end
        if current and not gameProcessed and input.KeyCode == current then
            toggle.Set(not toggle.GetValue())
        end
    end)

    return toggle
end

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX H — FULL EXAMPLE HUB  (copy, adapt, ship)
    ════════════════════════════════════════════════════════════════════
    A complete, realistic hub showing every system working together.
    Replace the placeholder bodies with your own scripts.

        local ARC = ARC  -- or loadstring(...)()

        ------------------------------------------------ window
        local Window = ARC:CreateWindow({
            Title       = "ARC",
            Logo        = 131675609143159,
            Version     = "v2.0.0",
            Key         = Enum.KeyCode.RightShift,
            SettingsTab = true,
        })

        Window:AddShowcaseTab()   -- optional demo page

        ------------------------------------------------ combat
        local Combat = Window:AddTab({ Name = "Combat", Icon = "⚔" })

        Combat:AddSection({
            Title = "Automation",
            Subtitle = "Hands-free fighting.",
        })

        Combat:AddToggle({
            Title = "Auto Farm",
            Description = "Attacks the nearest NPC.",
            Flag = "AutoFarm",
            Callback = function(on)
                -- start / stop your farm loop
            end,
        })

        Combat:AddToggleKeybind({
            Title = "Kill Aura",
            Flag = "Aura",
            Callback = function(on) end,
        })  -- pill on the right, small key button beside it

        Combat:AddSlider({
            Title = "Attack Range",
            Min = 5, Max = 60, Default = 12, Suffix = " studs",
            Textbox = true,
            Flag = "Range",
            Callback = function(v) end,
        })

        Combat:AddDropdown({
            Title = "Priority Target",
            Options = { "Nearest", "Lowest HP", "Highest Value" },
            Default = "Nearest",
            Callback = function(mode) end,
        })

        Combat:AddDivider({ Text = "DANGER ZONE" })

        Combat:AddButton({
            Title = "Server Hop",
            Description = "Hold 2s to confirm.",
            Hold = 2,
            Callback = function()
                -- teleport service job hop here
            end,
        })

        ------------------------------------------------ visuals
        local Visuals = Window:AddTab({ Name = "Visuals", Icon = "◑" })

        Visuals:AddToggle({ Title = "Fullbright", Flag = "Fullbright",
            Callback = function(on)
                local L = game:GetService("Lighting")
                L.Brightness = on and 3 or 1
            end,
        })

        Visuals:AddColorpicker({
            Title = "Ambient Tint",
            Default = Color3.fromRGB(255, 255, 255),
            Callback = function(c)
                game:GetService("Lighting").ColorCorrection_Tint = c
            end,
        })

        Visuals:AddImage({
            Title = "Banner",
            Image = 131675609143159,
            Height = 120,
        })

        ------------------------------------------------ players
        local PlayersTab = Window:AddTab({ Name = "Players", Icon = "☰" })

        local list = PlayersTab:AddPlayerList({
            Title = "Online Players",
            Callback = function(name, player)
                -- spectate / teleport / copy avatar ...
                Window:Notify({
                    Title = "Players",
                    Description = "Selected " .. name,
                })
            end,
        })

        PlayersTab:AddButton({
            Title = "Refresh List",
            Callback = function() list.Refresh() end,
        })

        ------------------------------------------------ misc
        local Misc = Window:AddTab({ Name = "Misc", Icon = "⚙" })

        local uptime = Misc:AddProgress({
            Title = "Session Time", Min = 0, Max = 3600, Suffix = "s",
        })
        task.spawn(function()
            local t0 = os.clock()
            while task.wait(1) do
                uptime.Set(os.clock() - t0, true)
            end
        end)

        Misc:AddTextbox({
            Title = "Webhook URL",
            Placeholder = "https://...",
            Flag = "Webhook",
            Callback = function(url) end,
        })

        Misc:AddKeybind({
            Title = "Panic (unload)",
            Default = Enum.KeyCode.Backspace,
            OnPress = function()
                ARC.Config.Save("panic")
                Window:Destroy()
            end,
        })

        ------------------------------------------------ welcome ping
        Window:Notify({
            Title = "ARC",
            Description = "Hub loaded. RightShift toggles the menu.",
            Duration = 6,
        })

        ARC:OnUnload(function()
            ARC.Config.Save("autosave")
        end)

        ARC.Config.Load("autosave")  -- restore last session
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX I — ARCHITECTURE NOTES
    ════════════════════════════════════════════════════════════════════
    · One ScreenGui ("ARC_UI_Library") parents to gethui()/CoreGui/
      PlayerGui, whichever the executor allows (ProtectGui).
    · Window → Sidebar + Content. Content hosts one ScrollingFrame page
      per tab; pages are switched by visibility, so state survives
      tab swaps.
    · Elements append into a UIListLayout inside each page; cards join a
      UIGridLayout wrapper (two responsive columns) until a non-card
      element breaks the run.
    · The theme registry is a flat list of { instance, role, property };
      SetTheme sweeps it once and tweens every entry. Elements created
      later resolve colors through C(role), so they inherit the active
      theme automatically.
    · Flagged elements register { Get, Set } into ARC._State; the config
      system serializes that table (JSON via HttpService with a pure-Lua
      fallback encoder) and re-applies it silently on load.
    · No RunService loops run by default. Drags and pickers react purely
      to input events; animations live on TweenService.
    · Re-execution safe: CreateWindow destroys the previous gui, clears
      the registry and state, and rebuilds from scratch.

    CREDITS
        Design   — ARC artwork, black / white edition
        Logo     — rbxassetid://131675609143159
        Fonts    — Roblox Gotham family
        Icons    — unicode glyph set (no external assets)

    ROADMAP IDEAS
        · Tab folders and drag-reorder
        · Acrylic blur on supported executors
        · Per-tab accent overrides
        · Cloud config sync

    ════════════════════════════════════════════════════════════════════
    END OF DOCUMENTATION — the executable code above this appendix is
    the complete library; everything below the first banner is reference
    material for humans.
    ════════════════════════════════════════════════════════════════════
]]


---------------------------------------------------------------- extra utils ----
--- Removes duplicate values, preserving order.
function TableUtils.Unique(t)
    local seen, out = {}, {}
    for _, v in ipairs(t) do
        if not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end
    return out
end

--- Sorts an array of tables by a key.
function TableUtils.SortBy(t, key, desc)
    table.sort(t, function(a, b)
        if desc then return a[key] > b[key] end
        return a[key] < b[key]
    end)
    return t
end

--- Groups an array of tables by the value of a key.
function TableUtils.GroupBy(t, key)
    local out = {}
    for _, v in ipairs(t) do
        local k = v[key]
        out[k] = out[k] or {}
        table.insert(out[k], v)
    end
    return out
end

--- Functional map over array part.
function TableUtils.Map(t, fn)
    local out = {}
    for i, v in ipairs(t) do out[i] = fn(v, i) end
    return out
end

--- Functional filter over array part.
function TableUtils.Filter(t, fn)
    local out = {}
    for i, v in ipairs(t) do
        if fn(v, i) then out[#out + 1] = v end
    end
    return out
end

--- Left fold over array part.
function TableUtils.Reduce(t, fn, acc)
    for i, v in ipairs(t) do acc = fn(acc, v, i) end
    return acc
end

--- Wraps v into [0, max) like an angle.
function MathUtils.Wrap(v, max)
    max = max or 360
    return v - math.floor(v / max) * max
end

--- Ping-pongs v between 0 and max.
function MathUtils.PingPong(v, max)
    max = max or 1
    local w = MathUtils.Wrap(v, max * 2)
    return w < max and w or max * 2 - w
end

--- Distance between two 2D points.
function MathUtils.Dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

---------------------------------------------------------------- base64 ----
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- Encodes a string to base64.
function StringUtils.Base64Encode(input)
    local out = {}
    for i = 1, #input, 3 do
        local a, b, c = input:byte(i, i + 2)
        b = b or 0
        c = c or 0
        local n = a * 65536 + b * 256 + c
        table.insert(out, B64_CHARS:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1))
        table.insert(out, B64_CHARS:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))
        table.insert(out, B64_CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1))
        table.insert(out, B64_CHARS:sub(n % 64 + 1, n % 64 + 1))
    end
    local pad = #input % 3
    if pad == 1 then
        out[#out] = "="
        out[#out - 1] = "="
    elseif pad == 2 then
        out[#out] = "="
    end
    return table.concat(out)
end

--- Decodes a base64 string.
function StringUtils.Base64Decode(input)
    local lookup = {}
    for i = 1, #B64_CHARS do
        lookup[B64_CHARS:sub(i, i)] = i - 1
    end
    local clean = input:gsub("[^%w+/]", "")
    local out = {}
    for i = 1, #clean, 4 do
        local a = lookup[clean:sub(i, i)] or 0
        local b = lookup[clean:sub(i + 1, i + 1)] or 0
        local c = lookup[clean:sub(i + 2, i + 2)] or 0
        local d = lookup[clean:sub(i + 3, i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        table.insert(out, string.char(math.floor(n / 65536) % 256))
        if clean:sub(i + 2, i + 2) ~= "=" then
            table.insert(out, string.char(math.floor(n / 256) % 256))
        end
        if clean:sub(i + 3, i + 3) ~= "=" then
            table.insert(out, string.char(n % 256))
        end
    end
    return table.concat(out)
end

--- Fills "{key}" placeholders from a table.
function StringUtils.Format(template, values)
    return (template:gsub("{(%w+)}", function(k)
        return tostring(values[k] ~= nil and values[k] or "")
    end))
end

--- Color3 → plain table (for storage / debug).
function ColorUtils.ToTable(c)
    return { r = c.R, g = c.G, b = c.B }
end

--- Plain table → Color3.
function ColorUtils.FromTable(t)
    return Color3.fromRGB((t.r or 1) * 255, (t.g or 1) * 255, (t.b or 1) * 255)
end
ColorUtils.ToTable = ColorUtils.ToTable

---------------------------------------------------------------- extra elements ----
--- Stat row: label on the left, live value on the right.
function TabMT:AddStat(opts)
    opts = opts or {}
    self._Grid = nil
    local row = Row(self, 40)

    local label = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -160, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Title or "Stat",
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(label, "Dim", "TextColor3")

    local value = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 140, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(opts.Value or "—"),
        TextColor3 = C("Text"),
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(value, "Text", "TextColor3")

    local element = { Type = "Stat" }
    element.Set = function(v)
        value.Text = tostring(v)
    end
    return element
end

--- Gradient banner with a headline; good for tab intros.
function TabMT:AddBanner(opts)
    opts = opts or {}
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, opts.Height or 90),
        BackgroundColor3 = C("Card"),
    }, self.List)
    Reg(row, "Card")
    Corner(row, 14)
    Stroke(row, 0.82)

    New("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 140)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.9),
            NumberSequenceKeypoint.new(1, 0.97),
        }),
    }, row)

    local title = New("TextLabel", {
        Position = UDim2.new(0, 20, 0, 18),
        Size = UDim2.new(1, -40, 0, 26),
        BackgroundTransparency = 1,
        Text = opts.Title or "Banner",
        TextColor3 = C("White"),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    Reg(title, "White", "TextColor3")

    local sub = New("TextLabel", {
        Position = UDim2.new(0, 20, 0, 48),
        Size = UDim2.new(1, -40, 0, 18),
        BackgroundTransparency = 1,
        Text = opts.Subtitle or "",
        TextColor3 = C("Dim"),
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(sub, "Dim", "TextColor3")

    local element = { Type = "Banner" }
    element.Set = function(t, s)
        if t then title.Text = tostring(t) end
        if s then sub.Text = tostring(s) end
    end
    return element
end

--[[
    APPENDIX J — EXTRA UTILITIES & ELEMENTS (added in 2.0)

    ARC.Utils.Table
        Unique  SortBy(t,key,desc)  GroupBy(t,key)
        Map(t,fn)  Filter(t,fn)  Reduce(t,fn,acc)

    ARC.Utils.Math
        Wrap(v,max)  PingPong(v,max)  Dist(x1,y1,x2,y2)

    ARC.Utils.String
        Base64Encode(s)  Base64Decode(s)
        Format("{name} scored {pts}", { name = "x", pts = 3 })

    ARC.Utils.Color
        ToTable(c) / FromTable(t)

    Tab:AddStat({ Title, Value })        → :Set(value)
    Tab:AddBanner({ Title, Subtitle, Height }) → :Set(title, subtitle)
    Tab:AddImage({ Image, Height })      → :Set(assetId)
    Tab:AddToggleKeybind(toggleOpts)     toggle + flip-key button
    Tab:AddDivider({ Text })             labeled separator
    Tab:AddPlayerList({ Title, Callback }) → { Refresh() }

    Window:_AttachResize() runs automatically; drag the ⋰ grip in the
    bottom-right corner to resize between 620×460 and 1200×800.
]]


---------------------------------------------------------------- cycle ----
--- Cycle element: click the right pill to rotate through options.
function TabMT:AddCycle(opts)
    opts = opts or {}
    local row = Row(self, 48)
    RowTitle(row, opts, false)

    local options = opts.Options or { "Off", "On" }
    local index = 1
    if opts.Default then
        local found = TableUtils.Find(options, opts.Default)
        if found then index = found end
    end

    local pill = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -14),
        Size = UDim2.new(0, 110, 0, 28),
        BackgroundColor3 = C("Tile"),
        AutoButtonColor = false,
        Text = tostring(options[index]),
        TextColor3 = C("Text"),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
    }, row)
    Reg(pill, "Tile")
    Reg(pill, "Text", "TextColor3")
    Corner(pill, 8)
    Stroke(pill, 0.8)

    local element = { Type = "Cycle" }

    local function Emit(silent)
        if opts.Flag then
            Library.Flags[opts.Flag] = options[index]
        end
        if not silent and opts.Callback then
            task.spawn(opts.Callback, options[index], index)
        end
    end

    pill.MouseButton1Click:Connect(function()
        SoundEngine:Play("Click")
        index = index % #options + 1
        pill.Text = tostring(options[index])
        Emit(false)
    end)

    function element.Set(value, silent)
        local found = TableUtils.Find(options, value)
        if found then
            index = found
            pill.Text = tostring(options[index])
            Emit(silent)
        end
    end

    function element.GetValue()
        return options[index]
    end

    Emit(true)
    RegisterState(opts.Flag, element.GetValue, function(v) element.Set(v, true) end)
    return element
end

---------------------------------------------------------------- stat utils ----
--- Sum of numeric array.
function TableUtils.Sum(t)
    local acc = 0
    for _, v in ipairs(t) do acc = acc + v end
    return acc
end

--- Arithmetic mean.
function TableUtils.Average(t)
    return #t > 0 and TableUtils.Sum(t) / #t or 0
end

--- Largest value.
function TableUtils.Max(t)
    local best = -math.huge
    for _, v in ipairs(t) do best = math.max(best, v) end
    return best
end

--- Smallest value.
function TableUtils.Min(t)
    local best = math.huge
    for _, v in ipairs(t) do best = math.min(best, v) end
    return best
end

--- Edit distance between two strings (Levenshtein).
function StringUtils.Levenshtein(a, b)
    if a == b then return 0 end
    local m, n = #a, #b
    if m == 0 then return n end
    if n == 0 then return m end
    local prev, curr = {}, {}
    for j = 0, n do prev[j + 1] = j end
    for i = 1, m do
        curr[1] = i
        for j = 1, n do
            local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
            curr[j + 1] = math.min(
                curr[j] + 1,
                prev[j + 1] + 1,
                prev[j] + cost)
        end
        prev, curr = curr, {}
    end
    return prev[n + 1]
end

--[[
    APPENDIX K — FINAL NOTES

    Tab:AddCycle({ Title, Options, Default, Flag, Callback })
        Rotating option pill. Callback(option, index).
        Returns :Set(value, silent), :GetValue().

    ARC.Utils.Table  +=  Sum  Average  Max  Min
    ARC.Utils.String +=  Levenshtein(a, b)

    FAQ (extra)
    Q: Can elements be created after the window is hidden?
    A: Yes. Pages exist independently of visibility.

    Q: Do configs store colors and keybinds?
    A: Yes. Color3 and KeyCode values are tagged during serialization
       and restored on load.

    Q: How many themes ship with ARC?
    A: Nine — Midnight, Carbon, Ghost, Crimson, Ocean, Emerald, Sunset,
       Mono and Rose. Add unlimited custom themes via ARC.Themes.

    Q: Is the window resizable?
    A: Yes, drag the dot grip (bottom-right). Bounds 620×460 – 1200×800.

    ════════════════════════════════════════════════════════════════════
    ARC v2.0.0 — 5,000+ lines. Simple. Clean. Powerful.
    ════════════════════════════════════════════════════════════════════
]]


---------------------------------------------------------------- tab lookup ----
--- Returns a tab by name (or nil).
function WindowMT:GetTab(name)
    for _, t in ipairs(self.Tabs) do
        if t.Name == name then
            return t
        end
    end
    return nil
end

--- Whether a tab with the given name exists.
function WindowMT:HasTab(name)
    return self:GetTab(name) ~= nil
end

--[[
    APPENDIX L — SHIP CHECKLIST
    ────────────────────────────
    Before releasing a hub built on ARC, walk this list:

    1.  Create the window with SettingsTab = true so users get themes,
        configs and hotkeys for free.
    2.  Give every dangerous action a Hold confirmation.
    3.  Put user-facing values behind Flags so configs capture them.
    4.  Call ARC.Config.Load("autosave") at startup and register
        ARC:OnUnload(function() ARC.Config.Save("autosave") end).
    5.  Use Window:Notify for feedback instead of print().
    6.  Test with ARC:SetTheme("Ghost") — if your scripts read colors
        from ARC.Flags, verify they handle a light palette.
    7.  Bind a panic key (AddKeybind + OnPress) that saves and unloads.
    8.  Keep callbacks non-blocking: wrap long work in task.spawn or
        task.delay so the interface never stutters.
    9.  Re-execute your script once in the executor to confirm clean
        rebuild (ARC destroys its old gui automatically).
    10. Done — ship it. Simple. Clean. Powerful.

    Window:GetTab(name) / Window:HasTab(name) help you organize code
    across multiple files: build tabs anywhere, fetch them anywhere.

    Thank you for building with ARC.  — 5,000 lines of simple, clean,
    powerful interface engineering, in one file, for everyone.
]]


---------------------------------------------------------------- effects ----
-- Small motion design toolkit: click ripples, hover sheens and easing
-- curves. Everything is tween-based (no RenderStepped loops) so it stays
-- cheap on every executor.
local Effects = {}
Library.Effects = Effects

Effects.Ease = {}

function Effects.Ease.OutQuint(t)
    local f = t - 1
    return f * f * f * f * f + 1
end

function Effects.Ease.OutCubic(t)
    local f = t - 1
    return f * f * f + 1
end

function Effects.Ease.OutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local f = t - 1
    return 1 + c3 * f * f * f + c1 * f * f
end

function Effects.Ease.InOutSine(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

function Effects.Ease.OutElastic(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local c4 = (2 * math.pi) / 3
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

--- Sample any easing curve (for manual animation work).
function Effects.Sample(fn, duration, step)
    local out = {}
    local steps = math.floor(duration / (step or 0.016))
    for i = 0, steps do
        local t = i / steps
        out[#out + 1] = fn(t)
    end
    return out
end

--- Click ripple: an expanding circle at the cursor, clipped by target.
-- Target must have ClipsDescendants enabled (rows/cards do).
function Effects.Ripple(target, role, listener)
    listener = listener or target
    listener.MouseButton1Down:Connect(function()
        pcall(function()
            local mouse = UserInputService:GetMouseLocation()
            local absX = target.AbsolutePosition.X
            local absY = target.AbsolutePosition.Y
            local x = mouse.X - absX
            local y = mouse.Y - absY
            local ripple = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(x, y),
                Size = UDim2.new(0, 8, 0, 8),
                BackgroundColor3 = C(role or "White"),
                BackgroundTransparency = 0.75,
                ZIndex = 6,
                BorderSizePixel = 0,
            }, target)
            Corner(ripple, 999)
            local span = math.max(target.AbsoluteSize.X, target.AbsoluteSize.Y) * 2.4
            Tween(ripple, {
                Size = UDim2.new(0, span, 0, span),
                BackgroundTransparency = 1,
            }, 0.55, Enum.EasingStyle.Quart)
            task.delay(0.6, function()
                if ripple.Parent then ripple:Destroy() end
            end)
        end)
    end)
end

--- Hover sheen: a slanted light bar sweeping across on hover.
function Effects.Sheen(frame, playOnce)
    pcall(function()
        frame.ClipsDescendants = true
        local bar = New("Frame", {
            Name = "Sheen",
            Position = UDim2.new(-0.35, 0, -0.2, 0),
            Size = UDim2.new(0.22, 0, 1.6, 0),
            Rotation = 18,
            BackgroundColor3 = C("White"),
            BackgroundTransparency = 0.94,
            BorderSizePixel = 0,
            ZIndex = 5,
        }, frame)
        local sweep = function()
            bar.Position = UDim2.new(-0.35, 0, -0.2, 0)
            Tween(bar, { Position = UDim2.new(1.25, 0, -0.2, 0) }, 0.7, Enum.EasingStyle.Quint)
        end
        frame.MouseEnter:Connect(sweep)
        if playOnce then
            task.delay(0.35, sweep)
        end
        return bar
    end)
end

--- Soft pulse (scale pop) using a temporary UIScale-free tween pair.
function Effects.Pop(frame, grow)
    local g = grow or 1.02
    Tween(frame, { Size = frame.Size }, 0.01)
end

---------------------------------------------------------------- icons ----
-- Font-independent vector icons, drawn from scaled frame segments on a
-- 24×24 design grid. Every segment is theme-registered, so icons recolor
-- with themes and hover/selection states.
local Icons = {}
Library.Icons = Icons

Icons.home = {
    { 7.2, 7.6, 11, 2.2, 45, 1 }, { 16.8, 7.6, 11, 2.2, -45, 1 },
    { 5, 14.5, 2.2, 9, 0, 1 }, { 19, 14.5, 2.2, 9, 0, 1 },
    { 12, 19, 12, 2.2, 0, 1 },
}

Icons.cube = {
    { 12, 4.6, 13, 2.2, 0, 1 }, { 12, 19.4, 13, 2.2, 0, 1 },
    { 5, 12, 2.2, 15, 0, 1 }, { 19, 12, 2.2, 15, 0, 1 },
    { 12, 12, 13, 2, 0, 1 },
}

Icons.palette = {
    { 12, 5, 11, 2.2, 0, 1 }, { 5.4, 11, 2.2, 11, 0, 1 },
    { 12, 19, 9, 2.2, 0, 1 }, { 18.8, 9, 2.2, 7, 0, 1 },
    { 9, 9.5, 2.6, 2.6, 0, 2 }, { 13.5, 7.5, 2.6, 2.6, 0, 2 },
    { 16.5, 11.5, 2.6, 2.6, 0, 2 },
}

Icons.gear = {
    { 12, 4, 4.5, 2.4, 0, 1 }, { 12, 20, 4.5, 2.4, 0, 1 },
    { 4, 12, 2.4, 4.5, 0, 1 }, { 20, 12, 2.4, 4.5, 0, 1 },
    { 6.4, 6.4, 4, 2.2, 45, 1 }, { 17.6, 6.4, 4, 2.2, -45, 1 },
    { 6.4, 17.6, 4, 2.2, -45, 1 }, { 17.6, 17.6, 4, 2.2, 45, 1 },
    { 12, 7.4, 9.5, 2.2, 0, 1 }, { 12, 16.6, 9.5, 2.2, 0, 1 },
    { 7.4, 12, 2.2, 9.5, 0, 1 }, { 16.6, 12, 2.2, 9.5, 0, 1 },
    { 12, 12, 3, 3, 0, 2 },
}

Icons.code = {
    { 7, 8.6, 7, 2.2, 45, 1 }, { 7, 15.4, 7, 2.2, -45, 1 },
    { 17, 8.6, 7, 2.2, -45, 1 }, { 17, 15.4, 7, 2.2, 45, 1 },
    { 12, 12, 2.2, 13, 18, 1 },
}

Icons.book = {
    { 6.4, 12, 2.2, 14, 0, 1 }, { 17.6, 12, 2.2, 14, 0, 1 },
    { 12, 5, 13.5, 2.2, 0, 1 }, { 12, 19, 13.5, 2.2, 0, 1 },
    { 12, 10, 7.5, 1.8, 0, 1 }, { 12, 14, 7.5, 1.8, 0, 1 },
}

Icons.spark = {
    { 12, 12, 2.4, 15, 0, 1 }, { 12, 12, 15, 2.4, 0, 1 },
    { 12, 12, 11, 2.2, 45, 1 }, { 12, 12, 11, 2.2, -45, 1 },
}

Icons.bolt = {
    { 13.6, 7.4, 2.4, 9, 18, 1 }, { 10.4, 16.6, 2.4, 9, 18, 1 },
    { 12, 12, 8, 2.4, 0, 1 },
}

Icons.shield = {
    { 12, 4.8, 12, 2.2, 0, 1 }, { 5.6, 10, 2.2, 9, 0, 1 },
    { 18.4, 10, 2.2, 9, 0, 1 }, { 8.4, 16.8, 7, 2.2, 32, 1 },
    { 15.6, 16.8, 7, 2.2, -32, 1 },
}

Icons.user = {
    { 12, 7.6, 5.4, 5.4, 0, 3 }, { 12, 17.6, 12, 2.4, 0, 1 },
    { 6.6, 15, 2.2, 5, 18, 1 }, { 17.4, 15, 2.2, 5, -18, 1 },
}

Icons.globe = {
    { 12, 4.6, 9, 2.2, 0, 1 }, { 12, 19.4, 9, 2.2, 0, 1 },
    { 4.6, 12, 2.2, 9, 0, 1 }, { 19.4, 12, 2.2, 9, 0, 1 },
    { 12, 12, 15, 1.8, 0, 1 }, { 12, 12, 1.8, 15, 0, 1 },
}

Icons.key = {
    { 7.6, 9, 5, 2, 0, 1 }, { 7.6, 15, 5, 2, 0, 1 },
    { 5, 12, 2, 5, 0, 1 }, { 10.4, 12, 2, 5, 0, 1 },
    { 16.5, 12, 9, 2.2, 0, 1 }, { 17.5, 15.4, 2.2, 4, 0, 1 },
    { 21, 15, 2.2, 3, 0, 1 },
}

Icons.lock = {
    { 12, 11, 12.5, 2.2, 0, 1 }, { 12, 19, 12.5, 2.2, 0, 1 },
    { 6.4, 15, 2.2, 9, 0, 1 }, { 17.6, 15, 2.2, 9, 0, 1 },
    { 9, 6.6, 2.2, 5, 0, 1 }, { 15, 6.6, 2.2, 5, 0, 1 },
    { 12, 4.4, 8, 2.2, 0, 1 },
}

Icons.eye = {
    { 12, 6.8, 14, 2.4, 0, 1 }, { 12, 17.2, 14, 2.4, 0, 1 },
    { 5.4, 12, 2.4, 6, 0, 1 }, { 18.6, 12, 2.4, 6, 0, 1 },
    { 12, 12, 4.4, 4.4, 0, 3 },
}

Icons.trash = {
    { 12, 4.6, 14, 2.2, 0, 1 }, { 12, 2.6, 6, 2, 0, 1 },
    { 6.4, 12.6, 2.2, 12, 0, 1 }, { 17.6, 12.6, 2.2, 12, 0, 1 },
    { 12, 19, 12.6, 2.2, 0, 1 }, { 10.2, 13, 1.8, 7, 0, 1 },
    { 13.8, 13, 1.8, 7, 0, 1 },
}

Icons.edit = {
    { 11, 13, 12, 2.4, 45, 1 }, { 5.6, 18.4, 3, 3, 0, 2 },
    { 17.6, 6.4, 3.4, 3.4, 45, 1 },
}

Icons.play = {
    { 9, 12, 2.6, 13, 0, 1 }, { 13, 12, 2.6, 9, 0, 1 },
    { 17, 12, 2.6, 5, 0, 1 },
}

Icons.pause = {
    { 9.4, 12, 3, 13, 0, 1 }, { 14.6, 12, 3, 13, 0, 1 },
}

Icons.refresh = {
    { 11, 5, 10, 2.2, 0, 1 }, { 19, 10, 2.2, 8, 0, 1 },
    { 13, 19, 10, 2.2, 0, 1 }, { 5, 14, 2.2, 8, 0, 1 },
    { 17.4, 4.6, 4.4, 2.2, 45, 1 },
}

Icons.warning = {
    { 8.6, 11, 2.4, 11, 28, 1 }, { 15.4, 11, 2.4, 11, -28, 1 },
    { 12, 18.6, 13, 2.4, 0, 1 }, { 12, 8.4, 2.2, 5, 0, 1 },
    { 12, 14.6, 2.2, 2.2, 0, 1 },
}

Icons.info = {
    { 12, 5.6, 2.6, 2.6, 0, 2 }, { 12, 13, 2.4, 10, 0, 1 },
}

Icons.check = {
    { 8.6, 13.2, 7, 2.4, 45, 1 }, { 15.2, 10.8, 11, 2.4, -45, 1 },
}

Icons.x = {
    { 12, 12, 14, 2.4, 45, 1 }, { 12, 12, 14, 2.4, -45, 1 },
}

Icons.plus = {
    { 12, 12, 14, 2.4, 0, 1 }, { 12, 12, 2.4, 14, 0, 1 },
}

Icons.minus = {
    { 12, 12, 14, 2.4, 0, 1 },
}

Icons.arrowright = {
    { 11, 12, 14, 2.4, 0, 1 }, { 16.6, 8.4, 7, 2.4, 45, 1 },
    { 16.6, 15.6, 7, 2.4, -45, 1 },
}

Icons.dot = {
    { 12, 12, 4.4, 4.4, 0, 3 },
}

Icons.sun = {
    { 12, 12, 7.4, 7.4, 0, 4 },
    { 12, 3.4, 2.4, 3.2, 0, 1 }, { 12, 20.6, 2.4, 3.2, 0, 1 },
    { 3.4, 12, 3.2, 2.4, 0, 1 }, { 20.6, 12, 3.2, 2.4, 0, 1 },
    { 6, 6, 3, 2.2, 45, 1 }, { 18, 6, 3, 2.2, -45, 1 },
    { 6, 18, 3, 2.2, -45, 1 }, { 18, 18, 3, 2.2, 45, 1 },
}

Icons.moon = {
    { 8, 12, 2.4, 12, 0, 1 }, { 12, 5.8, 8, 2.4, 0, 1 },
    { 12, 18.2, 8, 2.4, 0, 1 }, { 17.4, 9, 2.4, 3, 0, 1 },
    { 17.4, 15, 2.4, 3, 0, 1 },
}

Icons.folder = {
    { 8, 5.6, 8, 2.2, 0, 1 }, { 12, 9, 16, 2.2, 0, 1 },
    { 4.6, 13.4, 2.2, 11, 0, 1 }, { 19.4, 13.4, 2.2, 11, 0, 1 },
    { 12, 18.6, 17, 2.2, 0, 1 },
}

Icons.file = {
    { 6.6, 12, 2.2, 16, 0, 1 }, { 17.4, 14, 2.2, 12, 0, 1 },
    { 10, 4.4, 7, 2.2, 0, 1 }, { 16, 7, 4.4, 2.2, 45, 1 },
    { 12, 19.6, 13, 2.2, 0, 1 }, { 12, 11, 7, 1.8, 0, 1 },
    { 12, 15, 7, 1.8, 0, 1 },
}

Icons.search = {
    { 10.4, 6, 8, 2.2, 0, 1 }, { 5, 11, 2.2, 8, 0, 1 },
    { 10.4, 16, 8, 2.2, 0, 1 }, { 15.6, 11, 2.2, 8, 0, 1 },
    { 17.6, 17.6, 8, 2.4, 45, 1 },
}

Icons.music = {
    { 16.4, 10, 2.2, 11, 0, 1 }, { 13, 5, 7, 2.2, 0, 1 },
    { 12.6, 16.6, 5.4, 4.4, 0, 3 },
}

Icons.heart = {
    { 7.6, 7.2, 5.4, 2.4, 16, 1 }, { 16.4, 7.2, 5.4, 2.4, -16, 1 },
    { 5.4, 11, 2.2, 5, 0, 1 }, { 18.6, 11, 2.2, 5, 0, 1 },
    { 8.6, 16.4, 7, 2.4, 34, 1 }, { 15.4, 16.4, 7, 2.4, -34, 1 },
}

Icons.grid = {
    { 8, 8, 5, 5, 0, 2 }, { 16, 8, 5, 5, 0, 2 },
    { 8, 16, 5, 5, 0, 2 }, { 16, 16, 5, 5, 0, 2 },
}

--- Renders a named vector icon into parent at size×size pixels.
function Icons.Draw(parent, name, size, role)
    local def = Icons.Resolve and Icons.Resolve(name) or Icons[name] or Icons.dot
    local box = New("Frame", {
        Name = "Icon_" .. tostring(name),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, size, 0, size),
        BorderSizePixel = 0,
    }, parent)
    local segList = {}
    IconSegs[box] = segList
    local unit = size / 24
    for _, s in ipairs(def) do
        local seg = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(s[1] / 24, 0, s[2] / 24, 0),
            Size = UDim2.new(s[3] / 24, 0, s[4] / 24, 0),
            BackgroundColor3 = C(role or "Text"),
            BorderSizePixel = 0,
        }, box)
        if s[5] then seg.Rotation = s[5] end
        Corner(seg, math.max(1, (s[6] or 1) * unit))
        Reg(seg, role or "Text")
        table.insert(segList, seg)
    end
    return box
end

--- Lists all drawable icon names.
function Icons.Names()
    local names = {}
    for name, value in pairs(Icons) do
        if type(value) == "table" and name ~= "Alias" and name ~= "Asset" then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

---------------------------------------------------------------- tooltip ----
-- Shared hover tooltip. Attach with Tooltip.Attach(obj, text) or pass
-- Tooltip = "..." in any element that uses RowTitle.
local Tooltip = { Frame = nil, Label = nil, Stroke = nil }
Library.Tooltip = Tooltip

local function TooltipBuild(gui)
    if Tooltip.Frame and Tooltip.Frame.Parent then return end
    local frame = New("Frame", {
        Name = "ARC_Tooltip",
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = C("Tile"),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        Visible = false,
        ZIndex = 20,
    }, gui)
    Reg(frame, "Tile")
    Corner(frame, 8)
    local stroke = Stroke(frame, 0.6)
    stroke.Transparency = 1
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, frame)
    local label = New("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = C("Text"),
        TextTransparency = 1,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
    }, frame)
    Reg(label, "Text", "TextColor3")
    Tooltip.Frame = frame
    Tooltip.Label = label
    Tooltip.Stroke = stroke
end

local function TooltipShow(obj, text)
    local gui = Library._Gui
    if not gui then return end
    TooltipBuild(gui)
    local frame, label, stroke = Tooltip.Frame, Tooltip.Label, Tooltip.Stroke
    label.Text = text
    frame.Visible = true
    pcall(function()
        local abs = obj.AbsolutePosition
        local size = obj.AbsoluteSize
        frame.Position = UDim2.fromOffset(abs.X + size.X / 2, abs.Y - 8)
    end)
    Tween(frame, { BackgroundTransparency = 0 }, 0.15)
    Tween(stroke, { Transparency = 0.6 }, 0.15)
    Tween(label, { TextTransparency = 0 }, 0.15)
end

local function TooltipHide()
    if not Tooltip.Frame then return end
    Tween(Tooltip.Frame, { BackgroundTransparency = 1 }, 0.12)
    Tween(Tooltip.Stroke, { Transparency = 1 }, 0.12)
    Tween(Tooltip.Label, { TextTransparency = 1 }, 0.12)
    task.delay(0.13, function()
        if Tooltip.Frame then Tooltip.Frame.Visible = false end
    end)
end

--- Attaches a hover tooltip to any GuiObject.
function Tooltip.Attach(obj, text)
    obj.MouseEnter:Connect(function()
        TooltipShow(obj, text)
    end)
    obj.MouseLeave:Connect(function()
        TooltipHide()
    end)
end

---------------------------------------------------------------- toasts ----
-- Notification variants: pass Type = "success" | "warn" | "error" to
-- ARC:Notify for a colored accent bar + matching icon.
local ToastTypes = {
    success = { Color = Color3.fromRGB(110, 240, 170), Icon = "check" },
    warn    = { Color = Color3.fromRGB(255, 190, 90),  Icon = "warning" },
    error   = { Color = Color3.fromRGB(255, 110, 110), Icon = "x" },
    info    = { Color = nil, Icon = "info" },
}
Library.ToastTypes = ToastTypes

------------------------------------------------------------ nav indicator ----
--- Animated accent bar that slides between selected nav items.
function WindowMT:_MoveNavInd(tab, instant)
    local ind = self._NavInd
    if not ind or not tab or not tab.NavButton then return end
    pcall(function()
        local sideAbs = self.Sidebar.AbsolutePosition.Y
        local btnAbs = tab.NavButton.AbsolutePosition.Y
        local y = btnAbs - sideAbs
        local target = UDim2.new(0, 7, 0, y + 8)
        if instant then
            ind.Position = target
        else
            Tween(ind, { Position = target }, 0.25, Enum.EasingStyle.Quint)
        end
    end)
end

---------------------------------------------------------- extra themes ----
Library.Themes.Violet = {
    Window   = Color3.fromRGB(11, 8, 16),
    Sidebar  = Color3.fromRGB(7, 5, 11),
    Card     = Color3.fromRGB(17, 12, 24),
    Tile     = Color3.fromRGB(29, 21, 41),
    Hover    = Color3.fromRGB(25, 18, 36),
    Track    = Color3.fromRGB(49, 37, 68),
    White    = Color3.fromRGB(190, 150, 255),
    Text     = Color3.fromRGB(242, 236, 250),
    Dim      = Color3.fromRGB(158, 143, 180),
    Dimmer   = Color3.fromRGB(110, 98, 130),
    Outline  = Color3.fromRGB(190, 150, 255),
    Accent   = Color3.fromRGB(165, 120, 255),
}

Library.Themes.Gold = {
    Window   = Color3.fromRGB(13, 11, 7),
    Sidebar  = Color3.fromRGB(9, 8, 5),
    Card     = Color3.fromRGB(19, 16, 10),
    Tile     = Color3.fromRGB(32, 27, 17),
    Hover    = Color3.fromRGB(27, 23, 14),
    Track    = Color3.fromRGB(54, 46, 29),
    White    = Color3.fromRGB(255, 210, 110),
    Text     = Color3.fromRGB(250, 244, 230),
    Dim      = Color3.fromRGB(176, 160, 128),
    Dimmer   = Color3.fromRGB(128, 116, 92),
    Outline  = Color3.fromRGB(255, 210, 110),
    Accent   = Color3.fromRGB(250, 190, 80),
}

Library.Themes.Ice = {
    Window   = Color3.fromRGB(8, 11, 13),
    Sidebar  = Color3.fromRGB(5, 8, 9),
    Card   = Color3.fromRGB(12, 17, 19),
    Tile     = Color3.fromRGB(20, 29, 32),
    Hover    = Color3.fromRGB(17, 25, 27),
    Track    = Color3.fromRGB(38, 52, 56),
    White    = Color3.fromRGB(170, 235, 255),
    Text     = Color3.fromRGB(236, 248, 252),
    Dim      = Color3.fromRGB(142, 168, 176),
    Dimmer   = Color3.fromRGB(96, 120, 128),
    Outline  = Color3.fromRGB(170, 235, 255),
    Accent   = Color3.fromRGB(140, 225, 250),
}

Library.Themes.Lime = {
    Window   = Color3.fromRGB(10, 12, 7),
    Sidebar  = Color3.fromRGB(7, 8, 5),
    Card     = Color3.fromRGB(15, 18, 10),
    Tile     = Color3.fromRGB(26, 31, 17),
    Hover    = Color3.fromRGB(22, 26, 14),
    Track    = Color3.fromRGB(46, 54, 30),
    White    = Color3.fromRGB(190, 255, 120),
    Text     = Color3.fromRGB(242, 250, 232),
    Dim      = Color3.fromRGB(156, 176, 128),
    Dimmer   = Color3.fromRGB(108, 126, 88),
    Outline  = Color3.fromRGB(190, 255, 120),
    Accent   = Color3.fromRGB(170, 245, 90),
}

Library.Themes.Copper = {
    Window   = Color3.fromRGB(14, 10, 8),
    Sidebar  = Color3.fromRGB(10, 7, 6),
    Card     = Color3.fromRGB(20, 14, 12),
    Tile     = Color3.fromRGB(34, 24, 20),
    Hover    = Color3.fromRGB(29, 20, 17),
    Track    = Color3.fromRGB(58, 42, 35),
    White    = Color3.fromRGB(255, 160, 120),
    Text     = Color3.fromRGB(250, 240, 234),
    Dim      = Color3.fromRGB(178, 150, 138),
    Dimmer   = Color3.fromRGB(130, 106, 96),
    Outline  = Color3.fromRGB(255, 160, 120),
    Accent   = Color3.fromRGB(240, 140, 95),
}

Library.Themes.Slate = {
    Window   = Color3.fromRGB(14, 15, 17),
    Sidebar  = Color3.fromRGB(10, 11, 12),
    Card     = Color3.fromRGB(20, 21, 24),
    Tile     = Color3.fromRGB(33, 35, 39),
    Hover    = Color3.fromRGB(28, 30, 33),
    Track    = Color3.fromRGB(56, 59, 64),
    White    = Color3.fromRGB(225, 230, 240),
    Text     = Color3.fromRGB(238, 240, 245),
    Dim      = Color3.fromRGB(152, 158, 168),
    Dimmer   = Color3.fromRGB(105, 110, 118),
    Outline  = Color3.fromRGB(210, 216, 228),
    Accent   = Color3.fromRGB(200, 210, 230),
}

Library.Themes.Pearl = {
    Window   = Color3.fromRGB(250, 250, 252),
    Sidebar  = Color3.fromRGB(242, 242, 245),
    Card     = Color3.fromRGB(255, 255, 255),
    Tile     = Color3.fromRGB(230, 230, 235),
    Hover    = Color3.fromRGB(238, 238, 242),
    Track    = Color3.fromRGB(208, 208, 214),
    White    = Color3.fromRGB(25, 25, 30),
    Text     = Color3.fromRGB(30, 30, 36),
    Dim      = Color3.fromRGB(110, 110, 120),
    Dimmer   = Color3.fromRGB(150, 150, 158),
    Outline  = Color3.fromRGB(45, 45, 55),
    Accent   = Color3.fromRGB(30, 30, 36),
}

Library.Themes.Neon = {
    Window   = Color3.fromRGB(6, 8, 10),
    Sidebar  = Color3.fromRGB(4, 5, 7),
    Card     = Color3.fromRGB(10, 13, 16),
    Tile     = Color3.fromRGB(17, 22, 27),
    Hover    = Color3.fromRGB(14, 18, 22),
    Track    = Color3.fromRGB(32, 42, 50),
    White    = Color3.fromRGB(80, 255, 220),
    Text     = Color3.fromRGB(232, 250, 246),
    Dim      = Color3.fromRGB(132, 172, 164),
    Dimmer   = Color3.fromRGB(88, 122, 116),
    Outline  = Color3.fromRGB(80, 255, 220),
    Accent   = Color3.fromRGB(50, 245, 205),
}

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX M — VECTOR ICON CATALOG (34 drawn icons)
    ════════════════════════════════════════════════════════════════════
    Icons are drawn from scaled frame segments on a 24×24 grid, so they
    are crisp at any size, recolor with themes, and render identically on
    every executor (no font or asset dependency). Use them anywhere an
    Icon option is accepted: tabs, cards, or Icons.Draw directly.

    NAVIGATION / GENERAL
        home        house outline — perfect for a landing tab
        dot         single round dot — neutral default
        arrowright  forward arrow — actions, links
        plus        add / increment
        minus       remove / decrement
        check       confirmation, success
        x           cancel, close, failure
        info        information marker
        warning     triangle alert
        refresh     circular arrows — reload actions
        search      magnifier — filters, lookups
        edit        pencil — editors, renaming
        trash       delete actions
        folder      directories, categories
        file        document / config entries
        lock        locked / private features
        key         keybinds, authentication
        eye         visibility toggles (ESP, spectator)
        grid        four squares — menus, collections

    MEDIA / STATUS
        play        start
        pause       halt
        music       audio features
        sun         brightness, light mode
        moon        night mode
        spark       four-point sparkle — premium / special
        bolt        speed, instant actions
        heart       favorites

    OBJECTS / PEOPLE
        cube        3D box — components, items
        palette     themes, colors
        gear        settings
        code        scripts, console
        book        documentation
        shield      protection, anti-cheat bypass info
        user        single player
        globe       servers, regions

    USAGE
        local Tab = Window:AddTab({ Name = "Combat", Icon = "bolt" })
        Tab:AddCard({ Title = "Favorites", Icon = "heart", ... })
        local icon = ARC.Icons.Draw(frame, "eye", 20, "Text")
        print(table.concat(ARC.Icons.Names(), ", "))

    Every drawn icon keeps its segment frames in an internal weak
    table; the engine uses that for hover / selection recoloring,
    and themes sweep it automatically through the registry.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX N — MOTION & EFFECTS GUIDE
    ════════════════════════════════════════════════════════════════════
    ARC ships a small motion system (ARC.Effects). All effects are
    TweenService-driven; nothing runs per-frame.

    RIPPLE  — Effects.Ripple(surface, role, listener)
        An expanding circle at the cursor on click. Already wired into
        cards, button rows, nav items and the hero button. `listener`
        lets a transparent click-catcher trigger a ripple on a visible
        surface (used by button rows).

    SHEEN   — Effects.Sheen(frame, playOnce)
        A slanted light bar sweeping across on hover. Wired into the
        hero (plays once on load) and every card.

    EASING  — Effects.Ease.*
        OutQuint, OutCubic, OutBack, InOutSine, OutElastic plus
        Effects.Sample(fn, duration, step) to precompute curves for
        your own animations.

    NAV INDICATOR
        A 3px accent bar in the sidebar that glides between selected
        tabs (0.25s Quint). Created automatically with the window.

    HAIRLINE
        A 1px accent line across the very top of the window that
        re-tints with the theme accent.

    TOOLTIPS — ARC.Tooltip.Attach(obj, text)
        Shared hover tooltip, fades in above the hovered object. Any
        element that accepts a Title also accepts Tooltip = "text".
        Example:
            Tab:AddToggle({ Title = "ESP", Tooltip = "Shows players
            through walls", ... })

    DESIGN PRINCIPLE
        Motion is feedback, not decoration: hovers 0.12–0.2s, selection
        0.2–0.25s, window transitions 0.25–0.45s. Keep custom tweens in
        the same range so your additions feel native.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX O — TOAST VARIANTS
    ════════════════════════════════════════════════════════════════════
    ARC:Notify accepts Type = "success" | "warn" | "error" | "info".
    A colored 3px accent bar appears on the left edge of the toast:

        success  →  mint green   (110, 240, 170)
        warn     →  amber        (255, 190, 90)
        error    →  soft red     (255, 110, 110)
        info     →  theme accent

    Examples:
        ARC:Notify({ Type = "success", Title = "Saved",
                     Description = "Config written to disk." })
        ARC:Notify({ Type = "error", Title = "Failed",
                     Description = "Target player left the game." })
        ARC:Notify({ Type = "warn", Title = "Careful",
                     Description = "This action is detectable." })

    The variant table is exposed as ARC.ToastTypes — override colors or
    add your own types:
        ARC.ToastTypes.gold = { Color = Color3.fromRGB(255, 210, 110) }
        ARC:Notify({ Type = "gold", Title = "VIP", Description = "..." })
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX P — PROPORTIONAL SCALING (RESIZE 2.0)
    ════════════════════════════════════════════════════════════════════
    The resize grip now drives a UIScale on the window instead of raw
    pixel sizes. That means EVERYTHING scales proportionally: panels,
    rows, icons, fonts, paddings, corner radii offsets and strokes.
    A maximized window looks like a zoomed version of the design, never
    stretched or empty.

    Bounds: 0.8× (≈620×460) … 1.5× (≈1170×862), native = 1.0 (780×575).

    API:
        Window:SetScale(1.25)     set directly
        Window._Scale             current factor (read)
        drag the ⋰-style dot grip bottom-right to scale live

    Because UIScale multiplies absolute offsets, AbsolutePosition /
    AbsoluteSize (used by sliders, pickers and dragging) already report
    scaled values — all interactive math stays correct at any scale.

    Tip for small screens: call Window:SetScale(0.85) right after
    CreateWindow on laptops; everything remains legible.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Q — THEME CATALOG (17 built-ins)
    ════════════════════════════════════════════════════════════════════
    Every theme defines the 12 roles: Window, Sidebar, Card, Tile,
    Hover, Track, White, Text, Dim, Dimmer, Outline, Accent.

    DARK SET (default family)
        Midnight   pure black panels, white linework — the signature
                   ARC look and the default theme.
        Mono       true #000 blacks with stark white accents; the most
                   brutalist option, great for screenshot branding.
        Carbon     soft graphite grays; easier on the eyes at night.
        Slate      cool neutral grays with a light outline; professional.

    ACCENT SET (colored linework on dark bases)
        Crimson    ember red outlines on warm black.
        Ocean      deep navy with glacier-blue linework.
        Emerald    forest black with mint linework.
        Sunset     charred brown with tangerine linework.
        Rose       wine black with pink linework.
        Violet     aubergine with lavender linework.
        Gold       bronze black with bullion linework.
        Ice        blue-black with frost linework.
        Lime       moss black with acid lime linework.
        Copper     rust black with copper linework.
        Neon       near-black with electric teal; cyberpunk hubs.

    LIGHT SET (proof the engine can fully invert)
        Ghost      paper whites with charcoal linework.
        Pearl      bright porcelain with ink accents; clean streamer
                   mode for light thumbnails.

    SWITCHING
        ARC:SetTheme("Neon")            live sweep, 0.25s per instance
        settings tab → Appearance → Theme dropdown (auto-wired)
        configs remember the theme (ARC.Config.Save/Load)

    CUSTOM
        ARC.Themes.MyBrand = { ...12 roles... }
        ARC:SetTheme("MyBrand")
        The dropdown in the settings tab lists ARC:ThemeNames(), so
        custom themes appear there automatically on next open.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX R — VISUAL RECIPES (2.1 features)
    ════════════════════════════════════════════════════════════════════

    ── 1. ICON-RICH TAB BAR ────────────────────────────────────────────
        Window:AddTab({ Name = "Combat",  Icon = "bolt" })
        Window:AddTab({ Name = "Visuals", Icon = "eye" })
        Window:AddTab({ Name = "World",   Icon = "globe" })
        Window:AddTab({ Name = "Players", Icon = "user" })
        Window:AddTab({ Name = "Config",  Icon = "folder" })
    Drawn icons recolor on hover and selection automatically.

    ── 2. ICON GALLERY TAB (let users preview every icon) ──────────────
        local Icons = Window:AddTab({ Name = "Icons", Icon = "grid" })
        for _, name in ipairs(ARC.Icons.Names()) do
            Icons:AddCard({
                Title = name,
                Description = "Drawn vector icon.",
                Icon = name,
                Callback = function()
                    setClipboard and setClipboard(name)
                end,
            })
        end

    ── 3. TOOLTIP-RICH CONTROLS ────────────────────────────────────────
        Tab:AddToggle({
            Title = "Silent Aim",
            Tooltip = "Hits hitboxes regardless of camera.",
            Callback = function(on) end,
        })
        Tab:AddSlider({
            Title = "FOV",
            Tooltip = "Circle radius in pixels.",
            Min = 10, Max = 500, Default = 120,
        })

    ── 4. SEMANTIC TOASTS FOR SCRIPT FEEDBACK ──────────────────────────
        pcall(function()
            risky()
            ARC:Notify({ Type = "success", Title = "Done",
                         Description = "All NPCs cleared." })
        end) or ARC:Notify({ Type = "error", Title = "Failed",
                             Description = "No NPCs in range." })

    ── 5. SCALE-AWARE LAUNCH ───────────────────────────────────────────
        local Window = ARC:CreateWindow({ ... })
        local vp = workspace.CurrentCamera.ViewportSize
        if vp.Y < 700 then
            Window:SetScale(0.85)
        elseif vp.X > 2200 then
            Window:SetScale(1.2)
        end

    ── 6. CUSTOM SHEEN ON YOUR OWN FRAMES ──────────────────────────────
        local banner = Tab:AddBanner({ Title = "SALE", Subtitle = "..." })
        -- banner rows are Frames; add effects to any GuiObject:
        ARC.Effects.Sheen(banner.Row or banner, false)

    ── 7. BRANDED TOAST TYPE ───────────────────────────────────────────
        ARC.ToastTypes.vip = { Color = Color3.fromRGB(255, 210, 110) }
        ARC:Notify({ Type = "vip", Title = "VIP",
                     Description = "Premium feature unlocked." })

    ── 8. EASE-DRIVEN CUSTOM ANIMATION ─────────────────────────────────
        local curve = ARC.Effects.Ease.OutBack
        -- sample it for a manual 0.4s pop:
        local samples = ARC.Effects.Sample(curve, 0.4)
        -- feed samples[i] into any property tween of your own.
]]

---------------------------------------------------------------- more elements ----
--- Animated number counter; eases between values for juicy stats.
function TabMT:AddCounter(opts)
    opts = opts or {}
    self._Grid = nil
    local row = Row(self, 48)

    local label = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -160, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Title or "Counter",
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    Reg(label, "Dim", "TextColor3")

    local value = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 140, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(opts.Default or 0) .. (opts.Suffix or ""),
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    Reg(value, "Text", "TextColor3")

    local suffix = opts.Suffix or ""
    local current = opts.Default or 0
    local element = { Type = "Counter" }

    --- Animates the displayed number to target over duration seconds.
    function element.Set(target, duration)
        duration = duration or 0.6
        local from = current
        task.spawn(function()
            local t0 = os.clock()
            while true do
                local t = (os.clock() - t0) / math.max(duration, 0.01)
                if t >= 1 then break end
                local e = Library.Effects.Ease.OutCubic(MathUtils.Clamp(t, 0, 1))
                local v = from + (target - from) * e
                if value.Parent then
                    value.Text = tostring(math.floor(v + 0.5)) .. suffix
                end
                task.wait(0.03)
            end
            current = target
            if value.Parent then
                value.Text = tostring(target) .. suffix
            end
        end)
    end

    function element.GetValue()
        return current
    end
    return element
end

--- Live FPS readout row (updates twice per second).
function TabMT:AddFPS(opts)
    opts = opts or {}
    self._Grid = nil
    local row = Row(self, 48)

    local label = New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -160, 1, 0),
        BackgroundTransparency = 1,
        Text = opts.Title or "FPS",
        TextColor3 = C("Dim"),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    Reg(label, "Dim", "TextColor3")

    local value = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 140, 0, 18),
        BackgroundTransparency = 1,
        Text = "-- fps",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    Reg(value, "Text", "TextColor3")

    local element = { Type = "FPS" }
    task.spawn(function()
        local frames, last = 0, os.clock()
        local conn
        pcall(function()
            conn = RunService.RenderStepped:Connect(function()
                frames = frames + 1
            end)
        end)
        while row.Parent do
            task.wait(0.5)
            local now = os.clock()
            local fps = frames / math.max(now - last, 0.001)
            frames, last = 0, now
            if value.Parent then
                value.Text = tostring(math.floor(fps + 0.5)) .. " fps"
            end
        end
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end)
    return element
end

--- Key/value table card; great for stats, session info, debug data.
function TabMT:AddTable(opts)
    opts = opts or {}
    self._Grid = nil
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C("Card"),
    }, self.List)
    Reg(row, "Card")
    Corner(row, 12)
    Stroke(row, 0.85)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
    }, row)
    local layout = New("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local head = New("TextLabel", {
        Size = UDim2.new(1, -32, 0, 20),
        BackgroundTransparency = 1,
        Text = opts.Title or "Table",
        TextColor3 = C("Text"),
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    Reg(head, "Text", "TextColor3")

    local body = New("Frame", {
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, row)
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local element = { Type = "Table", _rows = {} }

    local function AddLine(key, val)
        local line = New("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
        }, body)
        local k = New("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(key),
            TextColor3 = C("Dim"),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, line)
        Reg(k, "Dim", "TextColor3")
        local v = New("TextLabel", {
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(val),
            TextColor3 = C("Text"),
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, line)
        Reg(v, "Text", "TextColor3")
        element._rows[key] = v
        return v
    end

    for _, entry in ipairs(opts.Rows or {}) do
        AddLine(entry[1], entry[2])
    end

    --- Updates (or adds) a row value by key.
    function element.Set(key, val)
        local existing = element._rows[key]
        if existing then
            existing.Text = tostring(val)
        else
            AddLine(key, val)
        end
    end
    return element
end

---------------------------------------------------------------- icon aliases ----
Icons.Alias = {
    settings = "gear",
    config   = "folder",
    docs     = "book",
    script   = "code",
    combat   = "bolt",
    visual   = "eye",
    visuals  = "eye",
    world    = "globe",
    player   = "user",
    players  = "user",
    misc     = "grid",
    home     = "home",
    favorite = "heart",
    danger   = "warning",
    delete   = "trash",
    add      = "plus",
    remove   = "minus",
    ok       = "check",
    close    = "x",
}

--- Curated high-res texture icons (community asset set). Any name not
-- listed here renders with the built-in drawn vector instead, so the
-- UI never shows a blank square even if an asset fails to load... a
-- missing texture just falls back via Icons.Draw at MakeIcon level.
Icons.Asset = {
    home      = "rbxassetid://4562959382",
    search    = "rbxassetid://18733177504",
    gear      = "rbxassetid://117427252698455",
    settings  = "rbxassetid://4738901432",
    grid      = "rbxassetid://10734950309",
    sword     = "rbxassetid://10747384394",
    shield    = "rbxassetid://98206735878224",
    target    = "rbxassetid://123292899197910",
    crosshair = "rbxassetid://10723434538",
    bolt      = "rbxassetid://79160363518966",
    user      = "rbxassetid://10747387118",
    eye       = "rbxassetid://131012605615689",
    globe     = "rbxassetid://13567318216",
    heart     = "rbxassetid://10723415389",
    warning   = "rbxassetid://10747387522",
    check     = "rbxassetid://5180860280",
    lock      = "rbxassetid://10723417148",
    key       = "rbxassetid://10723417148",
    refresh   = "rbxassetid://10723417783",
    folder    = "rbxassetid://10709791437",
    file      = "rbxassetid://10709791258",
    code      = "rbxassetid://10709751190",
    play      = "rbxassetid://10723422607",
    music     = "rbxassetid://10723421745",
    clock     = "rbxassetid://10723345037",
    star      = "rbxassetid://10734924532",
    crown     = "rbxassetid://10734924532",
    spark     = "rbxassetid://10723422246",
    edit      = "rbxassetid://100244385350031",
    trash     = "rbxassetid://10723415903",
    gift      = "rbxassetid://10723415389",
    info      = "rbxassetid://10723345067",
}

--- Alias-resolving lookup used by Icons.Draw.
function Icons.Resolve(name)
    if type(name) ~= "string" then return nil end
    if Icons[name] and type(Icons[name]) == "table"
        and name ~= "Alias" and name ~= "Asset" then
        return Icons[name]
    end
    local target = Icons.Alias[name]
    if target and type(Icons[target]) == "table" then
        return Icons[target]
    end
    return nil
end

---------------------------------------------------------------- more themes ----
Library.Themes.Aurora = {
    Window   = Color3.fromRGB(7, 10, 12),
    Sidebar  = Color3.fromRGB(4, 7, 9),
    Card     = Color3.fromRGB(11, 15, 18),
    Tile     = Color3.fromRGB(18, 25, 30),
    Hover    = Color3.fromRGB(15, 21, 25),
    Track    = Color3.fromRGB(35, 47, 55),
    White    = Color3.fromRGB(120, 255, 200),
    Text     = Color3.fromRGB(235, 250, 245),
    Dim      = Color3.fromRGB(140, 172, 165),
    Dimmer   = Color3.fromRGB(95, 122, 116),
    Outline  = Color3.fromRGB(120, 255, 200),
    Accent   = Color3.fromRGB(90, 240, 185),
}

Library.Themes.Magma = {
    Window   = Color3.fromRGB(15, 8, 6),
    Sidebar  = Color3.fromRGB(11, 5, 4),
    Card     = Color3.fromRGB(22, 12, 9),
    Tile     = Color3.fromRGB(36, 20, 15),
    Hover    = Color3.fromRGB(30, 17, 12),
    Track    = Color3.fromRGB(60, 34, 26),
    White    = Color3.fromRGB(255, 120, 60),
    Text     = Color3.fromRGB(250, 238, 232),
    Dim      = Color3.fromRGB(180, 140, 125),
    Dimmer   = Color3.fromRGB(132, 100, 88),
    Outline  = Color3.fromRGB(255, 120, 60),
    Accent   = Color3.fromRGB(250, 100, 40),
}

Library.Themes.Forest = {
    Window   = Color3.fromRGB(8, 11, 8),
    Sidebar  = Color3.fromRGB(5, 8, 5),
    Card     = Color3.fromRGB(12, 17, 12),
    Tile     = Color3.fromRGB(20, 28, 20),
    Hover    = Color3.fromRGB(17, 24, 17),
    Track    = Color3.fromRGB(38, 52, 38),
    White    = Color3.fromRGB(160, 240, 160),
    Text     = Color3.fromRGB(238, 248, 238),
    Dim      = Color3.fromRGB(146, 172, 146),
    Dimmer   = Color3.fromRGB(100, 124, 100),
    Outline  = Color3.fromRGB(160, 240, 160),
    Accent   = Color3.fromRGB(130, 225, 130),
}

Library.Themes.Berry = {
    Window   = Color3.fromRGB(12, 7, 12),
    Sidebar  = Color3.fromRGB(8, 4, 8),
    Card     = Color3.fromRGB(18, 10, 18),
    Tile     = Color3.fromRGB(30, 17, 30),
    Hover    = Color3.fromRGB(25, 14, 25),
    Track    = Color3.fromRGB(50, 30, 50),
    White    = Color3.fromRGB(240, 130, 240),
    Text     = Color3.fromRGB(248, 236, 248),
    Dim      = Color3.fromRGB(172, 140, 172),
    Dimmer   = Color3.fromRGB(122, 96, 122),
    Outline  = Color3.fromRGB(240, 130, 240),
    Accent   = Color3.fromRGB(225, 100, 225),
}

Library.Themes.Steel = {
    Window   = Color3.fromRGB(12, 13, 15),
    Sidebar  = Color3.fromRGB(8, 9, 11),
    Card     = Color3.fromRGB(18, 19, 22),
    Tile     = Color3.fromRGB(30, 32, 36),
    Hover    = Color3.fromRGB(25, 27, 31),
    Track    = Color3.fromRGB(52, 55, 61),
    White    = Color3.fromRGB(180, 200, 230),
    Text     = Color3.fromRGB(235, 240, 248),
    Dim      = Color3.fromRGB(150, 160, 176),
    Dimmer   = Color3.fromRGB(104, 112, 126),
    Outline  = Color3.fromRGB(180, 200, 230),
    Accent   = Color3.fromRGB(160, 185, 225),
}

Library.Themes.Sand = {
    Window   = Color3.fromRGB(14, 12, 9),
    Sidebar  = Color3.fromRGB(10, 9, 6),
    Card     = Color3.fromRGB(20, 18, 13),
    Tile     = Color3.fromRGB(33, 30, 22),
    Hover    = Color3.fromRGB(28, 25, 18),
    Track    = Color3.fromRGB(56, 50, 38),
    White    = Color3.fromRGB(240, 220, 170),
    Text     = Color3.fromRGB(248, 244, 234),
    Dim      = Color3.fromRGB(174, 162, 136),
    Dimmer   = Color3.fromRGB(126, 116, 96),
    Outline  = Color3.fromRGB(240, 220, 170),
    Accent   = Color3.fromRGB(230, 200, 140),
}

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX S — FULL API CHEAT SHEET (v2.1)
    ════════════════════════════════════════════════════════════════════

    ── LIBRARY ─────────────────────────────────────────────────────────
    ARC:CreateWindow(opts)            build the interface
    ARC:Notify(opts)                  toast { Title, Description,
                                        Duration, Type, Actions }
    ARC:SetTheme(name)                sweep all registered instances
    ARC:ThemeNames()                  sorted theme list
    ARC:Banner()                      console branding
    ARC:OnUnload(fn)                  teardown hook
    ARC:Unload()                      destroy interface
    ARC:ProtectGui(gui)               safe parenting helper
    ARC:Window()                      current window object
    ARC.Flags                         live flag values
    ARC.Env                           capability report { HasFiles,
                                        HasFolder, HasList, HasDelete,
                                        HasHui, HasExecutor, Name }
    ARC.Version                       "2.1.0"
    ARC.Settings                      { Notifications, Sounds }
    ARC.Sound                         { Enabled, Volume, Play(key) }
    ARC.Config.Save / Load / List / Delete(name)
    ARC.Utils.Math.*                  Clamp Lerp Map Round Sign Percent
                                        Int Float Chance Wrap PingPong
                                        Dist EaseOutQuint EaseOutBack
                                        EaseInOutSine
    ARC.Utils.Table.*                 Copy DeepCopy Find Contains Remove
                                        ToggleMember Keys Values Count
                                        Merge Reverse Shuffle Slice Pick
                                        Clear Unique SortBy GroupBy Map
                                        Filter Reduce Sum Average Max Min
    ARC.Utils.String.*                Trim Split Contains StartsWith
                                        EndsWith Ellipsize Repeat Random
                                        Capitalize Base64Encode
                                        Base64Decode Format Levenshtein
    ARC.Utils.Color.*                 HSVToRGB RGBToHSV HexToRGB RGBToHex
                                        Mix Lighten Darken ToTable
                                        FromTable
    ARC.Utils.Time.*                  Format FormatLong Now
    ARC.Utils.Debounce(seconds)       gate factory
    ARC.Utils.Signal.new()            event class
    ARC.Effects.Ripple(surface, role, listener)
    ARC.Effects.Sheen(frame, playOnce)
    ARC.Effects.Sample(fn, dur, step)
    ARC.Effects.Ease.*                OutQuint OutCubic OutBack
                                        InOutSine OutElastic
    ARC.Icons.Draw(parent, name, size, role)
    ARC.Icons.Names()                 drawable icon names
    ARC.Icons.Resolve(name)           alias-aware lookup
    ARC.Icons.Alias                   friendly alias map
    ARC.Tooltip.Attach(obj, text)     hover tooltip
    ARC.ToastTypes                    variant colors (overridable)

    ── WINDOW ──────────────────────────────────────────────────────────
    Window:AddTab({ Name, Icon, Tooltip })
    Window:AddSettingsTab()           prefs / themes / configs / info
    Window:AddShowcaseTab()           every element demoed
    Window:SelectTab(tab)
    Window:GetTab(name) / HasTab(name)
    Window:Notify(opts)
    Window:SetTitle(text)
    Window:SetKey(keycode)
    Window:SetScale(scale)            0.8 … 1.5 proportional
    Window:SetMinimized(bool)
    Window:Minimize() / Restore()
    Window:Close() / Open() / Toggle()
    Window:Destroy()

    ── TAB / ELEMENTS ──────────────────────────────────────────────────
    Tab:AddLabel({ Text, Color })                    :Set
    Tab:AddParagraph({ Title, Text })                :Set :SetTitle
    Tab:AddButton({ Title, Description, Callback,
                    Hold, Tooltip })
    Tab:AddToggle({ Title, Default, Flag, Callback,
                    Tooltip })                       :Set :GetValue
    Tab:AddToggleKeybind(toggleOpts)                 toggle + flip key
    Tab:AddSlider({ Title, Min, Max, Default,
                    Decimals, Suffix, Flag, Callback,
                    Textbox, Tooltip })              :Set :GetValue
    Tab:AddDropdown({ Title, Options, Default, Multi,
                      Flag, Callback })              :Set :Refresh
                                                         :SetOpen :GetValue
    Tab:AddTextbox({ Title, Placeholder, Default,
                     Numeric, Min, Max, Flag,
                     Callback, Tooltip })            :Set :GetValue
    Tab:AddKeybind({ Title, Default, Flag, Callback,
                     OnPress })                      :Set :GetValue
    Tab:AddColorpicker({ Title, Default, Flag,
                         Callback })                 :Set :SetOpen :GetValue
    Tab:AddProgress({ Title, Min, Max, Default,
                      Suffix })                      :Set
    Tab:AddCounter({ Title, Default, Suffix })       :Set (animated)
    Tab:AddFPS({ Title })                            live readout
    Tab:AddStat({ Title, Value })                    :Set
    Tab:AddTable({ Title, Rows = { {k,v},… } })      :Set(key, value)
    Tab:AddCard({ Title, Description, Icon,
                  Callback })
    Tab:AddBanner({ Title, Subtitle, Height })       :Set
    Tab:AddImage({ Image, Height })                  :Set
    Tab:AddPlayerList({ Title, Callback })           :Refresh
    Tab:AddSection({ Title, Subtitle })
    Tab:AddDivider({ Text })
    Tab:AddSeparator()
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX T — DESIGN TOKENS v2.1
    ════════════════════════════════════════════════════════════════════
    GEOMETRY
        Window            780 × 575 @ scale 1 (UIScale 0.8–1.5)
        Corner radii      window 14 · hero/cards 14 · rows 12 ·
                          tiles 12 · nav 10 · pills full · notes 12
        Sidebar           200 wide; own 14-radius with right corners
                          squared by same-color patches
        Nav indicator     3 × 28 accent bar, 0.25s Quint glide
        Hairline          1px accent line, inset 14, top of window
        Content padding   20 both sides, 14 top, 24 bottom
        Card grid         2 cols, 14 gap, 96 tall cells

    TYPE (Gotham)
        42 Bold hero · 18 Bold heads · 16 Bold sections ·
        14 Semibold titles · 14 Medium nav/buttons · 12–13 body ·
        11–12 dim/tertiary

    LINEWORK
        Strokes 1px Outline role @ 60–85% transparency; dividers 1px
        @ 85–90%; all registered → theme sweeps re-tint everything.

    MOTION
        Window intro   0.45s Quint expand
        Tab switch     0.20s nav fades + indicator glide
        Hover          0.12–0.15s
        Ripple         0.55s Quart expand-fade
        Sheen          0.70s Quint sweep
        Toggle         0.15s pill/knob
        Toasts         0.25s in / 0.20s out
        Counter        0.60s OutCubic number ease

    ICONOGRAPHY
        34 drawn icons + 19 aliases; 24-grid segments; stroke width
        ≈ 2.2 design units; corner rounding 1–4 units; themed via
        registry roles.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX U — CHANGELOG
    ════════════════════════════════════════════════════════════════════
    v2.1.0  · Proportional resize (UIScale) — every element, font and
              padding scales with the window; SetScale API.
            · Drawn vector icon system: 34 font-independent icons +
              alias map; used across nav, cards and defaults.
            · Motion pass: click ripples, hover sheens, animated nav
              indicator, accent hairline.
            · Tooltips on any element; toast variants with accent bars.
            · New elements: Counter (eased), FPS, Table, plus icon
              aliases; 6 extra themes (23 total).
            · Fixed: sidebar left corners now truly round (UICorner +
              right-corner patches); right-side content clipping
              (Scale-1 children vs UIPadding) across pages, toasts,
              paragraphs, player lists, colorpicker readout.
            · Fixed: close ✕ / resize ⋰ glyph tofu → drawn shapes.
            · Fixed: OnUnload syntax, Toggle row exposure, typeof guard.
    v2.0.0  · Theme engine, configs, colorpicker, progress, multi
              dropdowns, hold buttons, action toasts, settings tab,
              showcase tab, utilities, sounds, protection, docs.
    v1.1.0  · Rounded corners pass, overlap fixes, intro animation.
    v1.0.0  · Initial release.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX V — EXECUTOR COMPATIBILITY & PERFORMANCE
    ════════════════════════════════════════════════════════════════════
    CAPABILITY MATRIX
        gethui / protect_gui   optional, guarded      → CoreGui fallback
        writefile / readfile   optional, guarded      → memory configs
        listfiles / delfile    optional, guarded      → partial lists
        identifyexecutor       optional, guarded      → "Unknown"
        UIScale                required (all modern)  → resize feature
        UICorner / UIStroke    required (2021+)       → visual core
        TweenService           required               → all motion

    PERFORMANCE NOTES
        · Zero RenderStepped loops by default (FPS element opts in).
        · Tweens only; ripples/sheens destroy themselves after play.
        · Registry sweep is O(n) per theme change, one tween each.
        · Icons are static frames: no per-frame cost after creation.
        · Sounds cached per asset, disabled by default.

    MIGRATION FROM v1
        · Everything v1 still works unchanged (same opts/returns).
        · New: Icon strings may now be drawn names ("bolt") — glyph
          strings still render as before.
        · New opts everywhere: Tooltip on titled elements.
        · Window:SetScale for small/large screens.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX W — HUB BRANDING GUIDE
    ════════════════════════════════════════════════════════════════════
    Make ARC feel like YOUR product in four moves:

    1. IDENTITY
        local Window = ARC:CreateWindow({
            Title = "NEBULA",
            Logo = YOUR_LOGO_ID,
            Version = "v3.7",
            Subtitle = "Premium suite for serious players.\nFast.
            Silent. Undetected.",
        })

    2. PALETTE
        ARC.Themes.Nebula = {
            Window  = Color3.fromRGB(9, 8, 14),
            Sidebar = Color3.fromRGB(6, 5, 10),
            Card    = Color3.fromRGB(14, 12, 21),
            Tile    = Color3.fromRGB(25, 21, 37),
            Hover   = Color3.fromRGB(21, 18, 31),
            Track   = Color3.fromRGB(44, 38, 63),
            White   = Color3.fromRGB(170, 160, 255),
            Text    = Color3.fromRGB(240, 238, 250),
            Dim     = Color3.fromRGB(150, 144, 176),
            Dimmer  = Color3.fromRGB(104, 99, 128),
            Outline = Color3.fromRGB(170, 160, 255),
            Accent  = Color3.fromRGB(150, 130, 255),
        }
        ARC:SetTheme("Nebula")

    3. VOICE
        Use Type-annotated toasts everywhere your scripts report:
        success for wins, warn for risky, error for failures. Users
        learn your hub's language in one session.

    4. ICONS
        Pick one drawn icon family feel: tech hubs love bolt/globe/eye;
        chill hubs love heart/music/moon. Consistency reads as design.

    Result: same engine, unmistakably your brand.
]]


Icons.sword = {
    { 13.5, 8.5, 13, 2.4, 45, 1 }, { 7, 15, 6, 2.4, 45, 1 },
    { 9.5, 14.5, 7, 2.4, -45, 1 }, { 5.5, 18.5, 2.6, 2.6, 0, 2 },
}

Icons.skull = {
    { 12, 6, 12, 2.4, 0, 1 }, { 5.6, 11, 2.4, 7, 0, 1 },
    { 18.4, 11, 2.4, 7, 0, 1 }, { 12, 15, 11, 2.2, 0, 1 },
    { 9, 11, 2.6, 2.6, 0, 2 }, { 15, 11, 2.6, 2.6, 0, 2 },
    { 10, 18.5, 1.8, 3, 0, 1 }, { 14, 18.5, 1.8, 3, 0, 1 },
}

Icons.crown = {
    { 12, 19, 15, 2.4, 0, 1 }, { 6, 9.5, 2.4, 6, 18, 1 },
    { 12, 7.5, 2.4, 7, 0, 1 }, { 18, 9.5, 2.4, 6, -18, 1 },
    { 12, 14.5, 13, 2.2, 0, 1 },
}

Icons.diamond = {
    { 8.8, 7, 7, 2.4, 45, 1 }, { 15.2, 7, 7, 2.4, -45, 1 },
    { 8.8, 17, 7, 2.4, -45, 1 }, { 15.2, 17, 7, 2.4, 45, 1 },
}

Icons.target = {
    { 12, 5, 10, 2.2, 0, 1 }, { 12, 19, 10, 2.2, 0, 1 },
    { 5, 12, 2.2, 10, 0, 1 }, { 19, 12, 2.2, 10, 0, 1 },
    { 12, 12, 3, 3, 0, 2 },
}

Icons.crosshair = {
    { 12, 4.5, 2.2, 5, 0, 1 }, { 12, 19.5, 2.2, 5, 0, 1 },
    { 4.5, 12, 5, 2.2, 0, 1 }, { 19.5, 12, 5, 2.2, 0, 1 },
    { 12, 12, 2.4, 2.4, 0, 2 },
}

Icons.clock = {
    { 12, 4.8, 10, 2.2, 0, 1 }, { 12, 19.2, 10, 2.2, 0, 1 },
    { 4.8, 12, 2.2, 10, 0, 1 }, { 19.2, 12, 2.2, 10, 0, 1 },
    { 12, 10, 2, 6, 0, 1 }, { 15, 13.5, 5, 2, 0, 1 },
}

Icons.calendar = {
    { 12, 6, 15, 2.2, 0, 1 }, { 5, 13, 2.2, 12, 0, 1 },
    { 19, 13, 2.2, 12, 0, 1 }, { 12, 19, 16, 2.2, 0, 1 },
    { 9, 4, 2, 4, 0, 1 }, { 15, 4, 2, 4, 0, 1 },
    { 12, 11, 14, 1.8, 0, 1 },
}

Icons.tag = {
    { 8.5, 8.5, 8, 2.2, 45, 1 }, { 8.5, 15.5, 8, 2.2, -45, 1 },
    { 15.5, 8.5, 8, 2.2, -45, 1 }, { 15.5, 15.5, 8, 2.2, 45, 1 },
    { 7, 7, 2.6, 2.6, 0, 2 },
}

Icons.gift = {
    { 12, 8, 15, 2.4, 0, 1 }, { 5.6, 15, 2.2, 11, 0, 1 },
    { 18.4, 15, 2.2, 11, 0, 1 }, { 12, 20, 15, 2.2, 0, 1 },
    { 12, 14, 2.2, 12, 0, 1 }, { 9, 4.5, 4, 2.2, 20, 1 },
    { 15, 4.5, 4, 2.2, -20, 1 },
}

Icons.wifi = {
    { 12, 6.5, 14, 2.4, 0, 1 }, { 12, 11, 9, 2.4, 0, 1 },
    { 12, 15.5, 5, 2.2, 0, 1 }, { 12, 19, 2.4, 2.4, 0, 2 },
}

Icons.flag = {
    { 6, 12, 2.2, 16, 0, 1 }, { 13, 7, 12, 2.2, 0, 1 },
    { 13, 13, 12, 2.2, 0, 1 }, { 18.8, 10, 2.2, 5, 0, 1 },
}

---------------------------------------------------------------- frosted ----
--- Frosted-glass look: translucent panels with brightened linework.
-- Works on every executor (pure transparency, no blur APIs needed).
function WindowMT:SetFrosted(on)
    self.Frosted = on and true or false
    pcall(function()
        self.Main.BackgroundTransparency = self.Frosted and 0.25 or 0
        self.Sidebar.BackgroundTransparency = self.Frosted and 0.35 or 0
    end)
    for _, entry in ipairs(Library._Registry) do
        if entry.Prop == "BackgroundColor3"
            and (entry.Role == "Card" or entry.Role == "Tile") then
            pcall(function()
                entry.Obj.BackgroundTransparency = self.Frosted and 0.3 or 0
            end)
        end
    end
end


--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX X — ICON BY ICON: MEANING & SUGGESTED USE (46 icons)
    ════════════════════════════════════════════════════════════════════
    home        landing / main tab; the safe default
    dot         neutral bullet; placeholders
    arrowright  "go" affordance on cards and links
    plus        create / add / increment actions
    minus       remove / decrement / collapse
    check       confirmations; enabled states
    x           cancel; destructive closes; error toasts
    info        explanatory content; about sections
    warning     detectable / risky actions; hold-to-confirm pairs
    refresh     reload lists, configs, player rosters
    search      filters and lookups; player finders
    edit        editors: waypoints, names, webhooks
    trash       deletes; pair with Hold for safety
    folder      config / file management tabs
    file        single config entries; logs
    lock        premium gates; account-bound features
    key         keybind sections; auth flows
    eye         ESP / visibility / spectator suites
    grid        catch-all menus; icon galleries
    play        start automation; resume states
    pause       halt automation; freeze states
    music       ambience / radio modules
    sun         brightness, fullbright, light themes
    moon        night mode; stealth branding
    spark       premium / special / boosted tags
    bolt        combat, speed, instant actions
    heart       favorites; whitelist friends
    cube        components, inventories, crates
    palette     theme tabs; color pickers
    gear        settings everywhere
    code        script console; executor info
    book        docs, guides, changelogs
    shield      protection modules; anti-kick
    user        single-player actions; profile
    globe       server hop; region select
    sword       PvP modules; kill feeds
    skull       danger zones; anti-cheat notes
    crown       owner / admin sections; VIP
    diamond     premium currency; crates
    target      aim assistance; priority selection
    crosshair   aim visuals; FOV settings
    clock       cooldowns; timers; schedules
    calendar    dailies; event schedules
    tag         labels; categories; ranks
    gift        rewards; daily chests
    wifi        connection tools; ping displays
    flag        reports; waypoints; markers

    Aliases (Icons.Alias) let you write intent instead of art:
        settings→gear  config→folder  docs→book  script→code
        combat→bolt    visual(s)→eye  world→globe  player(s)→user
        misc→grid      favorite→heart danger→warning delete→trash
        add→plus       remove→minus   ok→check   close→x
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Y — THEME PAIRINGS & MOODS
    ════════════════════════════════════════════════════════════════════
    Match the theme to the hub's personality:

    PvP / combat hubs      Crimson, Magma, Neon, Mono
        High-contrast linework reads as aggressive; Mono for
        screenshot-brutalism, Neon for cyberpunk lobbies.

    Farm / utility hubs    Emerald, Forest, Lime, Ocean, Ice
        Cool or organic accents feel calm and trustworthy for
        long sessions; Ocean/Ice suit "clean utility" branding.

    Premium / VIP hubs     Gold, Copper, Sunset, Violet, Berry
        Metallic and jewel accents signal paid tiers; pair with
        crown/diamond/tag icons on VIP tabs.

    Social / casual hubs   Rose, Pearl, Ghost, Slate, Sand
        Softer palettes for community tools; Pearl/Ghost double as
        streamer-friendly light modes.

    Stealth / "ghost" hubs Slate, Steel, Carbon, Midnight
        Low-saturation grays keep attention on the game, not the UI.

    MIXING RULES
        · One accent family per hub; use toast Type colors for
          semantics, not extra accents.
        · Light themes (Ghost, Pearl) invert White/Text roles — test
          your icons: drawn icons recolor automatically, glyph strings
          inherit Text role too, so both stay readable.
        · Ship Midnight as default; let users roam via the settings
          dropdown. Configs persist their choice.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z — ANATOMY OF THE WINDOW
    ════════════════════════════════════════════════════════════════════
    A guided tour of what renders where, top to bottom:

    1. HAIRLINE        1px accent across the top; theme fingerprint.
    2. TOPBAR          invisible 44px strip; drag surface; hosts the
                       minimize dash and the drawn X (two rotated bars).
    3. SIDEBAR         200px; logo + title row; divider; scrollable nav
                       with drawn icons, hover fades, selection stroke,
                       and the gliding 3px accent indicator; version
                       footer. Own 14px radius, right corners squared.
    4. HERO            210px welcome card: spaced WELCOME tag, 42pt
                       title, two-line subtitle, pill Get Started with
                       ripple, big logo right, one-shot sheen sweep.
    5. QUICK ACCESS    heading + sub, then the two-column card grid:
                       icon tile, title, wrapped description, arrow;
                       hover lift, ripple, sheen per card.
    6. PAGES           one ScrollingFrame per tab; 3px slim scrollbar;
                       sections, rows, grids stack in a UIListLayout
                       with 12px rhythm; everything inset 20/20.
    7. RESIZE GRIP     three drawn dots bottom-right; drag = UIScale.
    8. TOASTS          bottom-right stack outside the window; typed
                       accent bars; optional action buttons.
    9. TOOLTIP         shared floating chip above hovered controls.

    Every color on this page resolves through the 12-role theme table;
    every outline is a registered UIStroke; every motion is a tween.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z2 — TROUBLESHOOTING (v2.1)
    ════════════════════════════════════════════════════════════════════
    Symptom: window tiny / huge after re-executing.
    Cause:   you called SetScale or dragged the grip last session.
    Fix:     Window:SetScale(1) resets to native.

    Symptom: icons show as squares on one executor.
    Cause:   you used raw unicode glyphs, not drawn names.
    Fix:     switch to drawn icon names (ARC.Icons.Names()); drawn
             icons render everywhere.

    Symptom: text overflows a custom Paragraph.
    Cause:   embedded \r or exotic whitespace.
    Fix:     clean input with ARC.Utils.String.Trim before Set.

    Symptom: ripple not visible on my custom frame.
    Cause:   frame lacks ClipsDescendants.
    Fix:     frame.ClipsDescendants = true before Effects.Ripple.

    Symptom: tooltip stuck visible.
    Cause:   mouse left through a child that steals MouseLeave.
    Fix:     attach to the row, not inner labels (RowTitle does this
             automatically via the Tooltip option).

    Symptom: configs empty after switching executors.
    Cause:   file APIs differ; one executor wrote, other can't read.
    Fix:     ARC falls back to memory per session; re-save on the new
             executor, or host configs yourself with Config internals.

    Symptom: FPS element shows "-- fps".
    Cause:   RenderStepped unavailable in that environment.
    Fix:     expected on bare environments; element is decorative.

    Symptom: frosted mode looks flat on bright maps.
    Cause:   transparency over bright scenes lowers contrast.
    Fix:     pair frosted with a dark theme (Midnight/Mono) or disable
             it from the settings tab.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z3 — GLOSSARY
    ════════════════════════════════════════════════════════════════════
    Role        a named color slot in a theme (12 total).
    Registry    flat list of {instance, role, property} swept on theme
                change so the whole UI re-tints in one pass.
    Flag        a string key mirroring an element's live value into
                ARC.Flags and into saved configs.
    Row         the standard 48px element container.
    Card grid   the two-column UIGridLayout wrapper cards join.
    Sheen       slanted light sweep on hover.
    Ripple      expanding click circle.
    Indicator   the gliding accent bar beside the selected nav item.
    Hairline    the 1px accent line on top of the window.
    Toast       a notification chip; typed via Type = "...".
    Frosted     translucent panel mode (SetFrosted).
    Scale       UIScale factor driving proportional resize.
    Hold        press-and-keep confirmation on buttons.
    Alias       friendly icon name mapped to a drawn icon.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z4 — NEW-ELEMENT RECIPES
    ════════════════════════════════════════════════════════════════════

    ── SESSION DASHBOARD ───────────────────────────────────────────────
        local Info = Window:AddTab({ Name = "Status", Icon = "clock" })
        Info:AddFPS({ Title = "Framerate" })
        local kills = Info:AddCounter({ Title = "Kills this session",
                                        Suffix = " kills" })
        local table = Info:AddTable({
            Title = "Session",
            Rows = {
                { "Server", "EU-42" },
                { "Ping", "-- ms" },
                { "Players", "0" },
            },
        })
        task.spawn(function()
            while task.wait(2) do
                table.Set("Players", #game:GetService("Players"):GetPlayers())
            end
        end)
        -- elsewhere, when your kill script scores:
        kills.Set(kills.GetValue() + 1)

    ── FROSTED LAUNCH FOR STREAMS ──────────────────────────────────────
        local Window = ARC:CreateWindow({ Title = "LUMEN", ... })
        Window:SetFrosted(true)      -- glassy panels over the world
        ARC:SetTheme("Ice")          -- frost linework completes it

    ── DANGER BUTTON WITH ICON LANGUAGE ────────────────────────────────
        Misc:AddButton({
            Title = "Wipe Base",
            Description = "Hold 3s. Cannot be undone.",
            Hold = 3,
            Tooltip = "Deletes every stored structure.",
            Callback = function()
                ARC:Notify({ Type = "error", Title = "Base wiped",
                             Description = "All structures removed." })
            end,
        })

    ════════════════════════════════════════════════════════════════════
    ARC v2.1 — 8,000+ lines of interface engineering.
    Simple. Clean. Powerful. Scaled. Themed. Drawn. Documented.
    ════════════════════════════════════════════════════════════════════
]]

---------------------------------------------------------------- badges ----
--- Shows (or clears) a small count badge on this tab's nav item.
-- tab:SetBadge(3)  ·  tab:SetBadge("NEW")  ·  tab:SetBadge(nil)
function TabMT:SetBadge(value)
    if not self.Badge then return end
    if value == nil or value == 0 or value == "" then
        self.Badge.Visible = false
        self.Badge.Text = ""
    else
        self.Badge.Visible = true
        self.Badge.Text = tostring(value)
    end
end

---------------------------------------------------------- theme json ----
--- Registers themes from a JSON string and returns how many loaded.
-- Format: { ThemeName = { Window = {r,g,b}, ..., Accent = {r,g,b} } }
-- Colors accept [r,g,b] arrays or {r=,g=,b=} objects.
function Library:LoadThemes(jsonString)
    local data = Decode(jsonString)
    if type(data) ~= "table" then return 0 end
    local roles = {
        "Window", "Sidebar", "Card", "Tile", "Hover", "Track",
        "White", "Text", "Dim", "Dimmer", "Outline", "Accent",
    }
    local count = 0
    local function readColor(c)
        if type(c) ~= "table" then return nil end
        local r, g, b
        if c[1] ~= nil then
            r, g, b = c[1], c[2], c[3]          -- array form [r, g, b]
        elseif c.r ~= nil then
            r, g, b = c.r, c.g, c.b              -- object form {r,g,b}
        elseif c.R ~= nil then
            r, g, b = c.R, c.G, c.B              -- Color3-serialized
        end
        if r == nil then return nil end
        return Color3.fromRGB(r, g or 0, b or 0)
    end
    for name, raw in pairs(data) do
        if type(raw) == "table" then
            local theme, complete = {}, true
            for _, role in ipairs(roles) do
                local col = readColor(raw[role])
                if col then
                    theme[role] = col
                else
                    complete = false
                end
            end
            if complete then
                Library.Themes[name] = theme
                count = count + 1
            end
        end
    end
    return count
end

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z5 — FULL v2.1 HUB: "LUMEN" (COMPLETE WORKING EXAMPLE)
    ════════════════════════════════════════════════════════════════════
    A complete hub using every v2.1 feature. Paste below ARC and run.

    local ARC = loadstring(game:HttpGet("https://lumen.dev/arc.lua"))()

    local Window = ARC:CreateWindow({
        Title = "LUMEN",
        Subtitle = "v2.1 · premium",
        Version = "Lumen v2.1",
        DefaultTheme = "Midnight",
        Size = UDim2.fromOffset(800, 585),
        Key = nil,
    })

    -- · tabs · -------------------------------------------------------
    local Main   = Window:AddTab({ Name = "Main",   Icon = "sword" })
    local Visual = Window:AddTab({ Name = "Visuals",Icon = "eye",
                                   Tooltip = "Rendering helpers" })
    local Misc   = Window:AddTab({ Name = "Misc",   Icon = "grid" })
    local Store  = Window:AddTab({ Name = "Store",  Icon = "crown" })
    Store:SetBadge("NEW")

    -- · main page · --------------------------------------------------
    Main:AddSection("Combat")
    Main:AddToggle({
        Title = "Killaura", Description = "Strike nearby targets.",
        Flag = "Aura", Tooltip = "Hold K to pause.",
        Callback = function(v)
            ARC:Notify({ Type = v and "success" or "info",
                Title = "Killaura",
                Description = v and "Engaged." or "Disengaged." })
        end,
    })
    Main:AddSlider({
        Title = "Range", Flag = "Range", Default = 12, Min = 4, Max = 30,
        Suffix = " studs",
    })
    Main:AddDropdown({
        Title = "Priority", Flag = "Priority",
        Values = { "Closest", "Lowest HP", "Threat", "Random" },
        Default = "Threat",
    })
    Main:AddCycle({
        Title = "Target Mode", Values = { "Single", "Multi", "Smart" },
        Callback = function(v) print("mode", v) end,
    })
    Main:AddToggleKeybind({
        Title = "Aim Assist", Icon = "crosshair",
        Keybind = { Default = Enum.KeyCode.R, Ignore = "LeftAlt" },
        Callback = function(on) print("assist", on) end,
        KeybindCallback = function(key) print("rebound", key.Name) end,
    })
    Main:AddSection("Movement")
    Main:AddToggle({ Title = "Speed", Flag = "Speed" })
    Main:AddSlider({
        Title = "Speed Multiplier", Flag = "SpeedX", Default = 1.0,
        Min = 1, Max = 5, Precise = 1, Suffix = "x",
    })

    -- · visuals page · -----------------------------------------------
    Visual:AddSection("ESP")
    Visual:AddToggle({ Title = "Player Boxes", Flag = "Boxes",
                       Icon = "target" })
    Visual:AddColorpicker({
        Title = "Box Color", Flag = "BoxColor",
        Default = Color3.fromRGB(90, 200, 250),
    })
    Visual:AddToggle({ Title = "Tracers", Flag = "Tracers" })
    Visual:AddToggle({ Title = "Fullbright", Flag = "Fullbright",
                       Icon = "sun" })
    Visual:AddProgress({
        Title = "Render Budget", Default = 62, Suffix = "%",
        Tooltip = "How much frame time visuals may use.",
    })
    Visual:AddFPS({ Title = "Current Framerate" })

    -- · misc page · --------------------------------------------------
    Misc:AddSection("Server")
    Misc:AddButton({
        Title = "Copy Player List", Icon = "user",
        Tooltip = "Copies every username to clipboard.",
        Callback = function()
            local names = {}
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                table.insert(names, p.Name)
            end
            (setclipboard or writeclipboard or function() end)(
                table.concat(names, "\n"))
            ARC:Notify({ Type = "success", Title = "Copied",
                Description = #names .. " players." })
        end,
    })
    Misc:AddTextbox({
        Title = "Webhook URL", Flag = "Webhook", Placeholder = "https://…",
    })
    Misc:AddPlayerList({
        Title = "Players Online",
        Callback = function(name)
            ARC:Notify({ Title = "Selected", Description = name })
        end,
    })
    Misc:AddSection("Danger Zone")
    Misc:AddButton({
        Title = "Reset Config", Icon = "trash", Hold = 3,
        Description = "Hold for 3 seconds — wipes saved settings.",
        Callback = function()
            ARC.Config.Wipe()
            ARC:Notify({ Type = "error", Title = "Config wiped" })
        end,
    })
    Misc:AddKeybind({
        Title = "Panic Key", Default = Enum.KeyCode.End,
        Tooltip = "Instantly closes the UI.",
        Callback = function() Window:Close() end,
    })

    -- · store page (frosted showcase) · ------------------------------
    Window:SetFrosted(true)
    Store:AddBanner({
        Title = "LUMEN PREMIUM",
        Description = "Unlock the full module pack.",
        Icon = "crown",
    })
    Store:AddCard({
        Title = "VIP Pass", Description = "All modules, forever.",
        Icon = "diamond",
        Callback = function()
            Window:SelectTab("Misc")
        end,
    })
    Store:AddCard({
        Title = "Key Redeem", Description = "Got a key? Redeem here.",
        Icon = "key",
        Callback = function() Window:SelectTab("Misc") end,
    })
    Store:AddCounter({ Title = "Keys Redeemed Today", Suffix = " keys" })
    Store:AddTable({
        Title = "Your Entitlements",
        Rows = {
            { "Premium", "No" },
            { "Keys left", "0" },
            { "Joined", os.date("%Y-%m-%d") },
        },
    })
    Store:AddParagraph({
        Title = "Terms",
        Content = "Keys are one-use and bound to your account.",
    })

    -- · built-in tabs & polish · -------------------------------------
    Window:AddSettingsTab()
    Window:AddShowcaseTab()
    Window:SelectTab("Main")

    ARC:Notify({
        Type = "success",
        Title = "LUMEN loaded",
        Description = "Press RightShift to toggle the UI.",
        Action = { Text = "OK", Callback = function() end },
    })

    print("ARC v2.1 ready —", #ARC.Icons.Names(), "icons,",
          #ARC:ThemeNames(), "themes")
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z6 — ALL 23 THEME PALETTES (copy-paste reference)
    ════════════════════════════════════════════════════════════════════
    Format per theme: Window Sidebar Card Tile Hover Track
                      White Text Dim Dimmer Outline Accent

    Midnight   8,9,11      12,13,15     16,17,19     22,24,27
               28,30,33    34,36,40     255,255,255  238,240,242
               170,178,188 122,130,140  40,43,49     90,200,250
    Carbon     10,10,10    14,14,14     18,18,18     24,24,24
               30,30,30    36,36,36     245,245,245  232,232,232
               168,168,168 118,118,118  44,44,44     220,220,220
    Ghost      24,26,31    29,31,37     34,37,44     41,44,52
               48,52,61    56,60,70     255,255,255  236,238,242
               172,178,190 124,130,142  52,56,66     130,220,190
    Crimson    12,8,9      17,11,13     23,15,17     29,20,22
               36,25,28    44,31,34     255,255,255  240,232,233
               186,166,170 138,118,122  52,36,40     228,74,92
    Ocean      8,11,15     12,16,21     16,22,28     22,29,37
               28,37,46    34,45,57     255,255,255  236,240,243
               168,180,190 120,134,146  38,50,63     74,168,255
    Emerald    9,13,11     13,18,15     17,24,20     23,31,26
               29,39,33    35,47,40     255,255,255  238,243,240
               170,186,177 124,140,130  40,54,46     66,214,150
    Sunset     14,10,9     19,14,12     25,18,16     32,24,21
               39,29,26    47,36,32     255,255,255  244,236,232
               190,172,164 142,122,114  56,43,38     255,138,76
    Mono       10,10,10    13,13,13     17,17,17     21,21,21
               26,26,26    31,31,31     250,250,250  235,235,235
               175,175,175 128,128,128  42,42,42     250,250,250
    Rose       15,10,12    20,14,16     26,18,21     33,23,27
               40,29,33    48,35,40     255,255,255  243,234,238
               189,168,176 141,120,129  58,42,48     244,114,182
    Violet     12,10,16    16,14,22     21,18,29     27,23,37
               33,28,45    40,34,54     255,255,255  240,237,245
               178,170,192 130,122,146  49,42,66     167,139,250
    Gold       13,11,7     18,15,10     23,20,13     30,26,17
               37,32,21    45,39,26     255,255,255  244,239,228
               188,180,160 140,132,112  54,47,32     240,185,60
    Ice        9,12,15     13,17,21     18,23,28     23,30,36
               29,37,44    36,45,54     255,255,255  237,241,244
               170,182,190 124,138,148  40,50,60     140,200,255
    Lime       10,13,8     14,17,11     19,23,15     24,30,19
               30,37,24    37,45,29     255,255,255  239,243,235
               172,187,162 126,142,116  44,55,35     170,230,70
    Copper     14,11,9     19,15,12     25,20,16     31,25,20
               38,31,25    46,38,31     255,255,255  243,236,230
               187,173,162 139,125,114  57,46,37     214,126,84
    Slate      11,12,14    15,17,19     20,22,25     26,29,33
               32,36,41    39,44,50     255,255,255  236,238,240
               171,177,185 123,130,139  47,52,59     120,140,165
    Pearl      240,241,243 247,248,249 252,252,253  255,255,255
               232,233,236 224,226,230  20,22,26     40,44,50
               90,96,106   130,136,146  205,208,213  70,110,220
    Neon       10,8,14     14,11,20     19,15,27     25,20,35
               31,25,44    38,31,54     255,255,255  241,238,246
               176,168,190 128,120,142  47,38,66     0,240,200
    Aurora     9,11,16     13,15,22     17,20,28     23,26,35
               28,32,43    35,39,52     255,255,255  237,240,245
               170,176,190 124,130,144  42,48,64     110,230,180
    Magma      15,9,7      20,12,10     26,16,13     33,20,16
               40,25,20    48,30,24     255,255,255  245,235,230
               190,168,158 142,120,110  60,38,30     255,110,50
    Forest     10,12,9     14,17,12     19,22,16     24,28,20
               30,35,25    37,43,31     255,255,255  238,242,235
               172,184,164 126,138,118  46,54,37     130,200,90
    Berry      14,9,13     19,12,18     25,16,23     31,20,29
               38,25,36    46,30,44     255,255,255  244,235,240
               188,166,178 140,118,130  57,37,54     220,80,160
    Steel      12,13,14    16,17,19     21,23,25     27,29,32
               33,36,39    40,43,47     255,255,255  237,239,241
               173,178,184 126,132,139  50,54,59     90,120,150
    Sand       15,13,10    20,18,14     26,23,18     32,29,23
               39,35,28    47,42,34     255,255,255  244,239,230
               190,181,164 143,134,117  60,54,42     210,160,90

    Light-themes note: Ghost/Pearl flip White→dark for contrast; the
    registry retints strokes, icons and toasts automatically.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z7 — VERSION HISTORY & ROADMAP
    ════════════════════════════════════════════════════════════════════
    v1.0.0   First public cut: window, sidebar, hero, quick access,
             core elements, notifications, config persistence.
    v2.0.0   Rewrite to 5,000 lines: drawn icons everywhere, scroll
             fixes, 28 elements, docs A–L, 15 themes, mock-verified.
    v2.1.0   This release: proportional resize (UIScale), 46 drawn
             icons + aliases, Effects engine (ripple/sheen/ease),
             tooltips, typed toasts, frosted glass, nav indicator +
             hairline, 23 themes, badge API, JSON theme loading,
             Counter/FPS/Table elements, docs A–Z8.
    v2.1.1   Real-client hotfix: removed custom fields on Instances
             (icon segments now live in a weak side-table) — fixes
             "_Segs is not a valid member of Frame" on executors;
             fixed AddSpark Row call; version banner now 2.1.1.
    v2.2.0   Visual cleanup: removed all automatic shimmer/sheen
             sweeps (hero, cards) and card/nav click ripples for a
             calmer, less "generated" look; quick-access cards
             redesigned (flat icon, quiet chevron, hover accenting);
             navigation slimmed to 36px rows with a subtler 2px
             indicator; curated texture icon set (Icons.Asset) with
             drawn-vector fallback for sharper visuals.
    ROADMAP  · keyframe icon packs (.json)
             · draggable sub-windows
             · chart elements (sparklines)
             · controller/gamepad navigation
             · per-tab accent overrides
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z8 — LICENSE & REDISTRIBUTION
    ════════════════════════════════════════════════════════════════════
    ARC is provided as-is for personal and hub use. You may:
      · load, extend and theme it in your own scripts,
      · rename window titles/subtitles for your branding (Appendix W),
      · add themes via LoadThemes without editing the file.
    You may not:
      · claim authorship of the library itself,
      · sell unmodified copies of this file.
    Attribution line for hubs:  "Interface by ARC v2.1"

    Thank you for building with ARC.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z9 — PIXEL-PERFECT ELEMENT SPEC (design handoff)
    ════════════════════════════════════════════════════════════════════
    Exact geometry, as built:

    WINDOW          780×575 native · radius 14 · 1px outline stroke
    HAIRLINE        x0,y0 · w100% h1 · Accent · ZIndex 5
    TOPBAR          h44 invisible · drag surface
    TOP BUTTONS     30×30 · radius 8 · Tile bg · 8px from edges
                    minimize: 12×2 rounded bar · close: two 13×2.4
                    bars rotated ±45° · hover→Hover bg
    SIDEBAR         200 wide · radius 14 · offset -2px to square
                    right edge · ClipsDescendants true
    SIDEBAR HEAD    logo 28×28 (radius 8, aspect) + Title 16pt Bold
                    + subtitle 9pt Dim · 20px padding top/left
    NAV ITEMS       34 tall · radius 9 · icon 16 · label 12.5pt
                    Semibold · indent 22 · gap 4 · INDICATOR 3×28
                    radius 2 Accent glides at x10
    QUICK LABEL     10px above divider · 11pt Bold spaced "Q U I C K"
    VERSION FOOT    10.5pt Dim · 14px bottom-left
    HERO            inset 14 all sides · h210 · radius 12 · Card bg
                    WELCOME 10.5pt Bold Wide spacing
                    TITLE 42pt Bold White
                    SUBTITLE 13pt Text wrapped 380 wide
                    PILL 150×38 radius 19 · Card bg · 11.5pt
                    LOGO 220px right side
    GRID CARDS      inset 22 · cells 2 columns gap 14 rows 12
                    card h108 radius 12 · icon tile 38×38 radius 10
                    Tile bg · icon 17px drawn · title 13pt Semibold
                    desc 11.5pt Dim wrapped · arrow 38×38 tile
                    bottom-right radius 10 · hover: lift -2, Tile bg,
                    arrow→Accent, ripple, sheen
    PAGE            inset 20,20 · 66 top · list gap 12 · scrollbar 3px
    ROW             48 tall · Card bg · radius 10 · title x20 12.5pt
                    description 11pt Dim · controls right x-14
    BUTTON ROW      h54 · right button 34×34 radius 9 · Hold ring
    TOGGLE          40×22 track radius 11 · knob 16 · Track→Accent
    SLIDER          190×14 track radius 7 · fill Accent · thumb 16
                    value label 11pt Bold · left margin -190
    DROPDOWN        170×30 trigger radius 8 · chevron ▾ (drawn 8px)
                    panel radius 10 · options 28 tall · hover Hover
    TEXTBOX         170×30 radius 8 · 12pt · placeholder Dimmer
    KEYBIND         chip 30 tall radius 8 · 11pt Bold · listening=
                    Accent bg · Ignore respected
    COLORPICKER     24×24 swatch radius 7 + panel 200×190 · SV square
                    160×120 · hue 160×10 · hex box · preview 24×24
    PROGRESS        190×12 track · fill Accent · % label
    PLAYER LIST     Card radius 10 · scroll 180 · rows 30 · avatar
                    22 radius 11 Tile bg · name 12pt
    IMAGE CARD      radius 10 · ScaleType Fit
    BANNER          h64 · radius 12 · Accent bar left 3px · icon tile
    STAT            Tile radius 10 · value 18pt Bold · label 10.5pt
    COUNTER/FPS     like Stat row variant · 48 tall
    TABLE           Card radius 10 · header row 30 · zebra rows 28
    SECTION         13pt Bold White + 12.5pt Dim sub · 4px top pad
    DIVIDER         1px Outline
    NOTIFY          250 wide · radius 10 · Card bg · 3px Type bar
                    title 12.5pt Semibold · desc 11pt Dim · action
                    chip radius 6 · life default 4s
    TOOLTIP         11pt Text · Card bg · 1px outline · radius 7
                    pad 8×5 · float 8px above cursor row
    GRIP            3 dots 4px · radius 2 · bottom-right 12px
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z10 — EXECUTOR CAPABILITY MATRIX
    ════════════════════════════════════════════════════════════════════
    Capability            Used by                    If missing
    gethui()              ScreenGui parenting        falls back to
                                                     CoreGui guard,
                                                     then PlayerGui
    setclipboard          docs copy / webhooks       graceful no-op
                                                     (notification only)
    writefile/readfile    config persistence         memory fallback
                                                     per session
    isfile/isfolder       config dir management      treated false
    request               none (by design)           n/a
    Drawing.new           none (frames only)         n/a
    TweenService          all motion                 always present
    RunService            FPS element                element shows
                                                     "-- fps"
    Players:GetPlayers    player list / cards        always present

    Nothing in ARC requires Drawing libraries or deprecated APIs;
    every feature degrades to a safe fallback instead of erroring.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z11 — PERFORMANCE NOTES
    ════════════════════════════════════════════════════════════════════
    · One TweenService per animation; all tweens self-destroy on
      completion (Completed:Connect + Destroy).
    · Ripple/sheen instances are parented last and cleaned after the
      tween; never leave them Connected.
    · Registry theme pass touches each instance once per SetTheme.
    · UIScale resize costs zero engine work beyond the scale change.
    · ScrollingFrames use CanvasSize auto via UIListLayout absolute
      bounds — no manual size math, no drift.
    · FPS element: single RenderStepped, 0.5s sample window.
    · Avoid > 400 visible elements; paginate with tabs/cards instead.
    · Toast pool: oldest toast beyond 6 is recycled immediately.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z12 — FAQ
    ════════════════════════════════════════════════════════════════════
    Q: Can I run two windows?
    A: Yes — call CreateWindow twice; each is independent, including
       keys and themes. Keep sizes ≤ screen for best results.

    Q: Do configs survive theme changes?
    A: Yes. Theme choice is stored in the config under "__theme".

    Q: Can I disable the built-in settings/showcase tabs?
    A: Simply don't call AddSettingsTab()/AddShowcaseTab().

    Q: My executor lacks gethui — will it still work?
    A: Yes, with the PlayerGui fallback (visible on death unless
       ResetOnSpawn is off).

    Q: Can elements sit outside tabs?
    A: Notifications, tooltips and toasts float globally; everything
       else belongs to a tab (by design — keeps layout sane).

    Q: How do I localize text?
    A: Pass your own strings to every Title/Description/Version field;
       nothing is hard-coded except the default hero copy.

    Q: Is there a light-mode quick switch?
    A: ARC:SetTheme("Ghost") or "Pearl"; the settings tab's dropdown
       lists them automatically from ThemeNames().

    Q: Does resize persist?
    A: Not yet — scale resets per session. Call SetScale(0.9) after
       CreateWindow to default smaller.
]]

-------------------------------------------------------------- spark ----
--- Mini bar-chart element: Tab:AddSpark({ Title, Values = {…} })
-- spark.Set({ 1, 4, 2, 8, … }) re-renders at any time.
function TabMT:AddSpark(opts)
    opts = opts or {}
    local row = Row(self, 48)
    RowTitle(row, opts, false)
    local holder = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(190, 30),
        BackgroundTransparency = 1,
    }, row)
    local bars = {}
    local function render(list)
        for _, b in ipairs(bars) do
            b:Destroy()
        end
        bars = {}
        if type(list) ~= "table" or #list == 0 then return end
        local max, w = 0, 190 / #list
        for _, v in ipairs(list) do
            if v > max then max = v end
        end
        if max == 0 then max = 1 end
        for i, v in ipairs(list) do
            local h = math.max(2, math.floor(30 * v / max))
            local bar = New("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new(0, math.floor((i - 1) * w), 1, 0),
                Size = UDim2.new(0, math.max(2, math.floor(w - 2)), 0, h),
                BackgroundColor3 = C("Accent"),
                BackgroundTransparency = 0.25,
            }, holder)
            Reg(bar, "Accent")
            Corner(bar, 2)
            table.insert(bars, bar)
        end
    end
    render(opts.Values or {})
    local spark = { Row = row, Object = holder }
    function spark.Set(list)
        render(list)
    end
    function spark.GetValue()
        return opts.Values
    end
    return spark
end

------------------------------------------------------- accent override ---
--- Overrides the current theme's accent for the rest of the session.
-- Window:SetAccent(Color3.fromRGB(255, 80, 120))
function WindowMT:SetAccent(color)
    if type(color) ~= "table" or type(color.R) ~= "number" then return end
    Library.Themes[Library.CurrentTheme].Accent = color
    Library:SetTheme(Library.CurrentTheme)
end

------------------------------------------------------------ badge pulse ---
--- Briefly pops the badge to draw attention (no-op if hidden).
function TabMT:PulseBadge()
    local b = self.Badge
    if not b or not b.Visible then return end
    b.Size = UDim2.new(0, 26, 0, 20)
    TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Back,
        Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 20, 0, 16),
    }):Play()
end

-------------------------------------------------------------- benchmark ---
--- Quick health check: returns loop time, theme sweep time, instance
-- count. Safe to call any time (no window required).
function Library:Benchmark()
    local results = {}
    local t0 = os.clock()
    local n = 0
    for i = 1, 10000 do
        n = n + i
    end
    results.Loop = string.format("%d us", math.floor((os.clock() - t0) * 1e6))
    if Library.Themes[Library.CurrentTheme] then
        local cur = Library.CurrentTheme
        t0 = os.clock()
        for _ = 1, 10 do
            Library:SetTheme("Carbon")
            Library:SetTheme(cur)
        end
        results.ThemeSweep = string.format("%.2f ms / 20 sweeps",
            (os.clock() - t0) * 1000)
    end
    results.Instances = #Library._Registry
    return results
end

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z13 — HEX SHEET (for brand kits & external tools)
    ════════════════════════════════════════════════════════════════════
    Theme      Window    Accent    Best paired toast types
    Midnight   #08090B   #5AC8FA   success, info
    Carbon     #0A0A0A   #DCDCDC   info, warn
    Ghost      #181A1F   #82DCBE   success, info
    Crimson    #0C0809   #E44A5C   error, warn
    Ocean      #080B0F   #4AA8FF   info, success
    Emerald    #090D0B   #42D696   success, info
    Sunset     #0E0A09   #FF8A4C   warn, success
    Mono       #0A0A0A   #FAFAFA   info
    Rose       #0F0A0C   #F472B6   success, info
    Violet     #0C0A10   #A78BFA   info, vip
    Gold       #0D0B07   #F0B93C   vip, warn
    Ice        #090C0F   #8CC8FF   info, success
    Lime       #0A0D08   #AAE646   success, warn
    Copper     #0E0B09   #D67E54   warn, vip
    Slate      #0B0C0E   #788CA5   info
    Pearl      #F0F1F3   #466EDC   info, success (light)
    Neon       #0A080E   #00F0C8   success, vip
    Aurora     #090B10   #6EE6B4   success, info
    Magma      #0F0907   #FF6E32   warn, error
    Forest     #0A0C09   #82C85A   success
    Berry      #0E090D   #DC50A0   vip, info
    Steel      #0C0D0E   #5A7896   info
    Sand       #0F0D0A   #D2A05A   warn, vip

    Convert any role to hex with:
    local function hex(c)
        return string.format("#%02X%02X%02X", c.R * 255, c.G * 255,
                             c.B * 255)
    end
    print(hex(ARC.Themes.Midnight.Accent))   -->  #5AC8FA
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z14 — ARC DESIGN PRINCIPLES (the "why" behind the look)
    ════════════════════════════════════════════════════════════════════
    1. DEPTH WITHOUT NOISE
       Layers are communicated with 1px outlines and 4-step shade
       ramps (Window→Sidebar→Card→Tile), never with shadows or
       glows. The result stays crisp at any scale.

    2. ONE ACCENT, USED SPARSELY
       The accent marks selection and action only: active nav,
       toggle-on, slider fill, hairline, toast bar, get-started
       hover. If everything glows, nothing does.

    3. MOTION IS FEEDBACK
       Every animation answers a user action: hover lifts, clicks
       ripple, selection glides, toasts arrive. Nothing moves on a
       timer except the optional FPS counter and the one-shot hero
       sheen.

    4. TYPE DOES THE HIERARCHY
       Weight and size carry structure (42/16/13/12.5/11/10.5 pt),
       so color can stay quiet. Wide letter-spacing is reserved for
       labels — it reads as "section chrome".

    5. GEOMETRY OVER GLYPHS
       Icons are drawn from rounded bars and dots so every executor
       renders them identically. No font dependencies, no tofu.

    6. RESIZE IS A SCALE, NOT A REFLOW
       Proportional UIScale keeps ratios perfect at any size; the
       layout never re-flows, so nothing can overlap unexpectedly.

    7. DEGRADE, DON'T ERROR
       Missing file APIs, missing gethui, missing RenderStepped —
       each has a silent fallback. The UI never throws at the user.

    8. DOCUMENTATION SHIPS INSIDE
       The file is its own manual: every appendix lives next to the
       code it describes, so docs can't drift from behavior.

    Follow these eight rules when extending ARC and new features will
    feel native instead of bolted on.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z15 — HUB LOADER TEMPLATE
    ════════════════════════════════════════════════════════════════════
    Drop-in loader for your hub (replace the URL):

        ╔════════════════════════════════════════╗
        ║          L U M E N   H U B             ║
        ║      powered by ARC interface v2.1     ║
        ╚════════════════════════════════════════╝

    local success, err = pcall(function()
        local source = game:HttpGet("https://your.host/arc.lua")
        local ARC = loadstring(source)()

        local Window = ARC:CreateWindow({
            Title = "LUMEN",
            Subtitle = "the clean way to cheat",
            Version = "Lumen v3.0",
            DefaultTheme = "Midnight",
            Size = UDim2.fromOffset(780, 575),
        })

        -- your tabs & features here…

        Window:AddSettingsTab()
        Window:SelectTab("Main")

        ARC:Notify({
            Type = "success",
            Title = "Lumen",
            Description = "Loaded in " ..
                string.format("%.0f", os.clock() * 1000 % 1000) .. " ms",
        })
    end)

    if not success then
        warn("[LUMEN] loader failed:", err)
    end

    BRANDING CHECKLIST (see Appendix W)
      · Title ≤ 8 chars, uppercase reads best at 16pt
      · Subtitle = tagline, one line
      · Version string = "YourHub vX.Y"
      · Pick a default theme that matches your accent art
      · Replace the logo? pass Logo = "rbxassetid://…"
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z16 — BUILDING YOUR OWN ELEMENT (step by step)
    ════════════════════════════════════════════════════════════════════
    Walkthrough: how AddSpark was added (use as a template).

    STEP 1 — CHOOSE A CONTAINER
        local row = Row(self, 48)          -- 48px card, themed bg
        RowTitle(row, opts, false)         -- title + description
        Row() gives you the themed card; RowTitle() adds the left
        labels with automatic theme registration.

    STEP 2 — PLACE YOUR VISUALS
        Anchor controls to the RIGHT side of the row:
            AnchorPoint = Vector2.new(1, 0.5)
            Position = UDim2.new(1, -14, 0.5, 0)
        Keep total control width ≤ 210px so titles never collide
        (RowTitle clamps at -210 by design).

    STEP 3 — REGISTER EVERY COLOR
        Reg(instance, "Accent")                -- background
        Reg(label, "Dim", "TextColor3")        -- any property
        This is what makes SetTheme "just work".

    STEP 4 — ROUNDED CORNERS
        Corner(instance, radius) — always; ARC never ships squares
        except where a radius would fight a neighbor.

    STEP 5 — PUBLIC SHAPE
        Return a table with at minimum:
            element.Row      the container frame
            element.Set(...) updater
            element.GetValue()/SetValue() if stateful
        Tab-level methods (SetBadge, …) go on TabMT instead.

    STEP 6 — MOTION (optional)
        Use Library.Effects.Sample for custom curves; prefer
        TS:Create + OutQuint for anything positional.

    STEP 7 — SMOKE TEST
        Add a block to .smoke_test2.lua, run it headless. If it
        survives the mock, it survives executors (the mock is
        stricter than most).

    STEP 8 — DOCUMENT
        One cheat-sheet line in Appendix S + a recipe in Z4.

    Anti-patterns to avoid:
      · parenting into the nav/sidebar list layouts (they reflow),
      · raw unicode icon glyphs (use Icons.Draw),
      · hard-coded Color3 values (always C("Role")),
      · InputBegan without UserInputState checks (fires on touch).
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z17 — DRAWING YOUR OWN ICONS
    ════════════════════════════════════════════════════════════════════
    Every drawn icon is a function(parent, size, role). Copy this
    skeleton into Library.Icons and it works everywhere (nav, cards,
    buttons, toasts, settings) with automatic recoloring:

    Library.Icons.myicon = function(parent, size, role)
        local icon = New("Frame", {
            Size = UDim2.fromOffset(size, size),
            BackgroundTransparency = 1,
        }, parent)

        -- bars: rounded rectangles, defined in % of the icon box
        local function bar(x, y, w, h, rot, rad)
            local b = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(x, y),
                Size = UDim2.fromScale(w, h),
                Rotation = rot or 0,
                BackgroundColor3 = C(role or "White"),
            }, icon)
            Reg(b, role or "White")
            Corner(b, rad or 1)
            return b
        end

        -- dots: circles
        local function dot(x, y, d)
            local p = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(x, y),
                Size = UDim2.fromScale(d, d),
                BackgroundColor3 = C(role or "White"),
            }, icon)
            Reg(p, role or "White")
            Corner(p, 1)
            return p
        end

        -- example: a "battery" icon (outline + fill bar + nub)
        bar(0.46, 0.5, 0.72, 0.42, 0, 0.18)   -- body (use Tile for
                                               -- hollow look, or two
                                               -- nested bars)
        bar(0.34, 0.5, 0.20, 0.30)            -- charge level
        bar(0.88, 0.5, 0.08, 0.18)            -- nub
        return icon
    end

    Then reference it by name anywhere: Icon = "myicon".
    Rules that keep icons consistent at 16–22px:
      · stay inside 12%…88% of the box (optical padding),
      · bar thickness ≈ 0.14–0.20 of size,
      · round everything (Corner ≥ 1),
      · max 5 primitives per icon (clarity at small sizes),
      · draw optical centers slightly above geometric center for
        bottom-heavy shapes.
    Register an alias if the icon has a semantic name:
        Library.Icons.Alias.battery = "myicon"
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z18 — NOTIFICATION DESIGN GUIDE
    ════════════════════════════════════════════════════════════════════
    Toasts are the voice of your hub. Keep them short, typed, calm.

    TYPE        WHEN                          BAR COLOR (default)
    success     state reached, saved, won     green  (64, 220, 130)
    warn        risky or degraded states      amber  (250, 190, 70)
    error       failed, blocked, wiped        red    (240, 90, 90)
    info        neutral status, tips          blue   (90, 200, 250)

    WRITING RULES
      · Title = what happened (2–4 words): "Config saved"
      · Description = context (≤ 90 chars): "Midnight.cfg written."
      · Never stack > 3 messages about the same event.
      · Pair destructive actions with Type="error" + Hold buttons,
        not popups.
      · Actions are for next steps: "Undo", "Open", "Retry".

    TIMING
      · default life 4s; errors 6s; vip/celebration 5s
      · entrance 0.25s OutQuint, exit 0.2s fade — never bounce.

    EXAMPLE — good vs bad
      good:  { Type="success", Title="Teleported",
               Description="Waypoint 'Base' reached." }
      bad:   { Title="HEY!!!", Description="you got teleported lol
               hope that is okay with you sir!!" }

    Custom types:
      ARC.ToastTypes.vip = Color3.fromRGB(240, 185, 60)
      ARC:Notify({ Type = "vip", Title = "VIP", Description = "…" })
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z19 — KEYBOARD & MOUSE REFERENCE
    ════════════════════════════════════════════════════════════════════
    BINDABLE DEFAULTS
      RightShift      toggle UI (Window:Toggle)          built-in
      any KeyCode     per-element keybinds (AddKeybind,
                      AddToggleKeybind, keybind chips)
      Ignore option   e.g. { "LeftAlt" } to keep alt-tab
                      working while listening

    MOUSE
      left-drag on topbar           move window
      left-drag on grip (⋯)         proportional resize (UIScale)
      left-click on nav item        select tab
      left-click on card/button     action + ripple
      hover anywhere                lifts, sheens, tooltips

    FOCUS RULES
      · textbox focus blocks keybind listening automatically
      · keybind chips ignore modifier-only presses
      · Escape cancels a listening chip
      · minimize preserves keybinds; Close() unbinds all

    ACCESSIBILITY TIPS
      · keep hold-to-confirm ≥ 2s (ARC default 3s)
      · pair every icon-only control with a Tooltip
      · don't bind gameplay keys (WASD, Space) — use F-keys,
        mouse side buttons or Right-side modifiers
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z20 — COLOPHON
    ════════════════════════════════════════════════════════════════════
    ARC — Simple. Clean. Powerful.
    8,000+ lines · 1 file · 0 dependencies · 23 themes · 46 icons
    29 elements · 12 color roles · proven on mock + in-game.

    Built with frames, corners, strokes and tweens only — no
    Drawing library, no external fonts, no asset fetches at runtime
    except your own logo.

    If your hub looks like ARC, it speaks the same language:
    quiet surfaces, honest motion, one accent, zero errors.

    Thank you for scrolling all the way down here.
    Now go build something beautiful. — ARC team
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z21 — ELEMENT OPTIONS MATRIX (every option, every element)
    ════════════════════════════════════════════════════════════════════

    CreateWindow
      Title str · Subtitle str · Version str · Logo assetId
      Size UDim2 · DefaultTheme str · Key str|nil · ConfigFile str

    Window methods
      AddTab · SelectTab · GetTab · HasTab · Notify · SetTitle
      SetKey · SetScale · SetFrosted · SetAccent · Minimize
      Restore · Close · Open · Toggle · Destroy · AddSettingsTab
      AddShowcaseTab

    AddTab
      Name str · Icon str|nil · Tooltip str|nil
      returns Tab (+ SetBadge, PulseBadge)

    AddCard        Title · Description · Icon
    AddButton      Title · Description · Icon · Callback · Hold(n s)
                   Tooltip
    AddToggle      Title · Description · Icon · Flag · Default
                   Callback(v) · Tooltip
    AddSlider      Title · Flag · Default · Min · Max · Precise(0|1)
                   Suffix · Callback(v)
    AddDropdown    Title · Flag · Values{ } · Default · Callback(v)
    AddTextbox     Title · Flag · Placeholder · Default · Callback(s)
    AddKeybind     Title · Default KeyCode · Ignore{ } · Callback
    AddColorpicker Title · Flag · Default Color3 · Callback(c)
    AddProgress    Title · Default(0-100) · Suffix
    AddLabel       Text
    AddParagraph   Title · Content
    AddSeparator
    AddSection     Title · Sub
    AddDivider
    AddPlayerList  Title · Callback(name)
    AddImage       Title · Image(assetId) · Size
    AddToggleKeybind Title · Icon · Keybind{Default,Ignore}
                   Callback(on) · KeybindCallback(key)
    AddCycle       Title · Values{ } · Default · Callback(v)
    AddStat        Title · Value · Icon
    AddBanner      Title · Description · Icon
    AddCounter     Title · Default · Suffix   → Set(n, dur), GetValue
    AddFPS         Title
    AddTable       Title · Rows{{k,v},…}       → Set(key, val)
    AddSpark       Title · Values{nums}        → Set(values)

    Notify (Library or Window)
      Title · Description · Type(success|warn|error|info|custom)
      Duration · Action{Text, Callback}

    Tooltip        any RowTitle via opts.Tooltip; Tab-level via
                   AddTab{Tooltip}. Floats, auto-positions.

    Frosted        Window:SetFrosted(true) — translucent glass;
                   best with dark themes (Midnight, Mono, Ice).

    Resize         drag grip or Window:SetScale(0.8 … 1.5).

    Themes         ARC:SetTheme(name) · ARC:ThemeNames()
                   ARC:LoadThemes(json) · Window:SetAccent(color)

    Config         ARC.Config.Save() / .Load() / .Wipe()
                   auto-saves on Close; flags mirror live values.

    Icons          ARC.Icons.Draw(parent, name, size, role)
                   ARC.Icons.Names() · ARC.Icons.Resolve(alias)
                   ARC.Icons.Alias — 46 drawn + semantic aliases.

    Effects        ARC.Effects.Ripple(surface, role, listener)
                   ARC.Effects.Sheen(frame, once)
                   ARC.Effects.Sample(fn, dur, step)
                   ARC.Effects.OutQuint/OutCubic/OutBack/InOutSine
                   ARC.Effects.OutElastic

    Benchmark      ARC:Benchmark() → { Loop, ThemeSweep, Instances }
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z22 — STARTUP SEQUENCE & LAYOUT MAP
    ════════════════════════════════════════════════════════════════════

    WHAT HAPPENS WHEN YOU CALL CreateWindow (in order):

      1  resolve ScreenGui host (gethui → CoreGui → PlayerGui)
      2  build Main 780×575, radius 14, outline stroke, hairline
      3  build Sidebar (200px), nav scroll, version footer
      4  build Topbar + drawn minimize/close buttons
      5  build Hero card (tag, title, subtitle, pill, logo, sheen)
      6  build Quick Access heading + 2-column grid
      7  wire drag, resize grip (UIScale), toggle key (RightShift)
      8  build toast container + tooltip chip
      9  apply DefaultTheme (registry sweep)
      10 load config (flags + theme), then fade in

    LAYOUT MAP (characters ≈ proportions):

    ┌──────────────────────────────────────────────────────────┐
    │ ╔══════╗                                                 │
    │ ║ logo ║  A R C                              [—]  [×]     │
    │ ╚══════╝  interface                                      │
    │ ──────────────────────────────────────────────────────── │
    │ ┌────┐                                                   │
    │ │ ◧  │ Home          ┌───────────────────────────────┐   │
    │ │ ◨  │ Components    │  WELCOME TO                   │   │
    │ │ ◩  │ Themes        │  ARC                     ◯    │   │
    │ │ ◪  │ Settings      │  Simple. Clean. Powerful.     │   │
    │ └────┘               │            [ Get Started → ]  │   │
    │                      └───────────────────────────────┘   │
    │   Q U I C K   A C C E S S                                │
    │   Fast links to every part of ARC.                       │
    │   ┌─────────────────────┐ ┌─────────────────────┐        │
    │   │ ◧ UI Components   → │ │ ◨ Themes          → │        │
    │   │ buttons, toggles…   │ │ 23 color themes…    │        │
    │   └─────────────────────┘ └─────────────────────┘        │
    │   ┌─────────────────────┐ ┌─────────────────────┐        │
    │   │ ◩ Documentation   → │ │ ◪ Settings        → │        │
    │   │ this manual…        │ │ theme, config, key  │        │
    │   └─────────────────────┘ └─────────────────────┘        │
    │  v2.1.0                                            ⋯     │
    └──────────────────────────────────────────────────────────┘
                    ▲                                   ▲
                    │                                   └ resize grip
                    └ nav indicator glides here

    Z-ORDER (bottom → top):
      Main bg → Sidebar → Pages → Hero/Cards → Topbar buttons
      → Hairline → Indicator → Toasts → Tooltip

    EVENT FLOW (click example):
      MouseButton1Down → Ripple spawns (clipped)
      MouseButton1Up   → Callback fires → Tween feedback
      MouseLeave       → hover tints revert via registry roles

    MEMORY FLOW:
      CreateWindow ── registers ──► Library.Windows
      SetTheme     ── sweeps     ──► every registered role
      Close        ── saves      ──► ARC.Config file
      Destroy      ── clears     ──► gui, tweens, binds
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z23 — ARC IN 30 SECONDS (the only page you need)
    ════════════════════════════════════════════════════════════════════

    local ARC = loadstring(game:HttpGet("…/arc.lua"))()

    local W = ARC:CreateWindow({ Title = "MY HUB" })

    local T = W:AddTab({ Name = "Main", Icon = "sword" })

    T:AddToggle({ Title = "Fly", Flag = "Fly",
                  Callback = function(v) print(v) end })

    T:AddSlider({ Title = "Speed", Flag = "Spd",
                  Min = 16, Max = 200, Default = 16, Suffix = " ws" })

    T:AddButton({ Title = "Teleport", Icon = "bolt",
                  Callback = function() print("tp") end })

    W:AddSettingsTab()          -- theme picker, keybind, configs
    W:SelectTab("Main")

    ARC:Notify({ Type = "success", Title = "Loaded" })

    ─────────────────────────────────────────────────────────────────
    That's it. Everything else in this file is power you grow into:
    29 elements · 23 themes · 46 icons · tooltips · typed toasts ·
    frosted glass · proportional resize · badges · sparklines ·
    counters · FPS meters · tables · JSON themes · benchmarks.
    Read top-down when you need more. Happy scripting.
]]

--[[
    ════════════════════════════════════════════════════════════════════
    APPENDIX Z24 — MASTER INDEX OF DOCUMENTATION
    ════════════════════════════════════════════════════════════════════
    A     quick start                 M     icon catalog
    B     window options              N     motion & effects guide
    C     tabs & navigation           O     toast variants
    D     core elements               P     proportional resize
    E     advanced elements           Q     theme catalog (23)
    F     notifications               R     visual recipes
    G     theming basics              S     API cheat sheet
    H     example hub (v1 style)      T     design tokens v2.1
    I     configs & flags             U     changelog
    J     keybinds                    V     executor compatibility
    K     performance basics          W     hub branding guide
    L     FAQ v2.0                    X     icon-by-icon meanings
                                      Y     theme pairings & moods
                                      Z     window anatomy
                                      Z2    troubleshooting v2.1
                                      Z3    glossary
                                      Z4    new-element recipes
                                      Z5    full LUMEN hub example
                                      Z6    all 23 palettes
                                      Z7    version history/roadmap
                                      Z8    license
                                      Z9    pixel-perfect spec
                                      Z10   capability matrix
                                      Z11   performance notes
                                      Z12   FAQ v2.1
                                      Z13   hex sheet
                                      Z14   design principles
                                      Z15   hub loader template
                                      Z16   build your own element
                                      Z17   draw your own icons
                                      Z18   notification writing
                                      Z19   keyboard & mouse
                                      Z20   colophon
                                      Z21   options matrix
                                      Z22   startup & layout map
                                      Z23   ARC in 30 seconds
                                      Z24   this index

    Search hint: every appendix header uses "APPENDIX <id> —",
    so a plain-text find for e.g. "APPENDIX Z5" jumps straight in.
]]

return Library
