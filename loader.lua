-- ============================================================
-- clarity_loader.lua
--   Runs on execute. Plays the clarity intro cinematic
--   (biohazard glyph sliding in + "clarity.tk" typing), then
--   shows the loader card with three games to pick from, and
--   loadstring()s the matching URL on inject.
-- ============================================================

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Accent      = Color3.fromRGB(110, 214, 58)

----------------------------------------------------------------
-- menu-matched font family. Mirrors the main clarity menu:
--   F_WM   = Roboto Bold  (watermark / big display)
--   F_BOLD = Arial Bold   (headers / buttons)
--   F_REG  = Arial Regular (body)
----------------------------------------------------------------
local function family(enumFont, weight)
    local okFF, ff = pcall(Font.fromEnum, enumFont)
    if okFF and ff then
        if weight then ff.Weight = weight end
        return ff
    end
    return nil
end
local F_WM   = family(Enum.Font.Roboto, Enum.FontWeight.Bold)
local F_BOLD = family(Enum.Font.Arial,  Enum.FontWeight.Bold)
local F_REG  = family(Enum.Font.Arial,  Enum.FontWeight.Regular)

local function withText(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        if k == "FontFace" and v then pcall(function() o.FontFace = v end)
        else o[k] = v end
    end
    return o
end
local function new(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    return o
end

local function protectGui(g)
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(g) end end)
end
local function hostGui()
    if gethui then return gethui() end
    return CoreGui
end

----------------------------------------------------------------
-- biohazard icon asset. Base64-embedded PNG, decoded + written to
-- disk once, then served via getcustomasset so the loader can use
-- the real icon instead of a frames fallback. Tinted green.
----------------------------------------------------------------
local BIOHAZARD_B64 = [==[
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
]==]

local function b64decode(data)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #chars do lookup[chars:sub(i, i)] = i - 1 end
    data = data:gsub("[^A-Za-z0-9%+%/%=]", "")
    local out = {}
    local n = #data
    local i = 1
    while i <= n do
        local a = lookup[data:sub(i,     i)]     or 0
        local b = lookup[data:sub(i + 1, i + 1)] or 0
        local c = lookup[data:sub(i + 2, i + 2)]
        local d = lookup[data:sub(i + 3, i + 3)]
        local n1 = a * 4 + math.floor(b / 16)
        out[#out + 1] = string.char(n1)
        if c then
            local n2 = (b % 16) * 16 + math.floor(c / 4)
            out[#out + 1] = string.char(n2)
            if d then
                local n3 = (c % 4) * 64 + d
                out[#out + 1] = string.char(n3)
            end
        end
        i = i + 4
    end
    return table.concat(out)
end

local BIOHAZARD_ASSET = nil
pcall(function()
    if writefile and getcustomasset then
        local path = "clarity_biohazard.png"
        if (not isfile) or (not isfile(path)) then
            writefile(path, b64decode(BIOHAZARD_B64))
        end
        BIOHAZARD_ASSET = getcustomasset(path)
    end
end)

local function buildBiohazard(parent, size)
    if BIOHAZARD_ASSET then
        return new("ImageLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(size, size),
            Image = BIOHAZARD_ASSET,
            ImageColor3 = Accent,
            ScaleType = Enum.ScaleType.Fit,
            Parent = parent,
        })
    end
    local box = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1, Parent = parent,
    })
    local ring = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size * 0.9, size * 0.9),
        BackgroundTransparency = 1, Parent = box,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    new("UIStroke", { Color = Accent, Thickness = math.max(3, size * 0.06), Parent = ring })
    return box
end

----------------------------------------------------------------
-- clean up any prior loader GUI
----------------------------------------------------------------
for _, name in ipairs({ "ClarityLoaderGui", "clarity_intro", "clarity_loader" }) do
    local old = hostGui():FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

local gui = new("ScreenGui", {
    Name = "clarity_loader",
    IgnoreGuiInset = true, ResetOnSpawn = false,
    DisplayOrder = 10^9, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
protectGui(gui)
gui.Parent = hostGui()

----------------------------------------------------------------
-- 1. INTRO CINEMATIC
--    Black backdrop. Biohazard glyph slides in from the left.
--    "clarity.tk" types out beside it. Hold a beat. Fade.
----------------------------------------------------------------
local introBack = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0, Parent = gui,
})

local stage = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(640, 220),
    BackgroundTransparency = 1, Parent = introBack,
})

-- biohazard carrier slides in from offscreen left
local markBox = new("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Size = UDim2.fromOffset(160, 160),
    Position = UDim2.new(0, -260, 0.5, 0),
    BackgroundTransparency = 1, Parent = stage,
})
buildBiohazard(markBox, 160)

local word = withText("TextLabel", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.fromOffset(180, 110),
    Size = UDim2.fromOffset(440, 120),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    FontFace = F_WM, TextSize = 72,
    TextColor3 = Color3.fromRGB(245, 245, 245),
    Text = "", Parent = stage,
})

local slide = TweenService:Create(markBox,
    TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    { Position = UDim2.new(0, 0, 0.5, 0) })
slide:Play()
slide.Completed:Wait()

local target = "clarity.tk"
for i = 1, #target do
    word.Text = target:sub(1, i)
    task.wait(0.065)
end

task.wait(0.6)

-- fade intro out
local fo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(introBack, fo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(word,      fo, { TextTransparency       = 1 }):Play()
for _, d in ipairs(markBox:GetDescendants()) do
    if d:IsA("UIStroke") then
        TweenService:Create(d, fo, { Transparency = 1 }):Play()
    elseif d:IsA("Frame") then
        TweenService:Create(d, fo, { BackgroundTransparency = 1 }):Play()
    end
end
task.wait(0.5)
pcall(function() stage:Destroy() end)

----------------------------------------------------------------
-- 2. LOADER CARD
--    Three games (BLOX STRIKE / COUNTER BLOX / kontra).
--    Click a row to select, click INJECT to loadstring the URL.
--    Uses the same font family as the main menu.
----------------------------------------------------------------
local backdrop = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0, Parent = gui,
})

local card = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(340, 400),
    BackgroundColor3 = Color3.fromRGB(16, 17, 16),
    BorderSizePixel = 0, Parent = backdrop,
})
new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = card })
new("UIStroke", { Color = Color3.fromRGB(55, 55, 55), Thickness = 1, Parent = card })

-- top-of-card biohazard glyph
local logoBox = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 16),
    Size = UDim2.fromOffset(56, 56),
    BackgroundTransparency = 1, Parent = card,
})
buildBiohazard(logoBox, 56)

withText("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 80),
    Text = "clarity.tk",
    TextColor3 = Accent, FontFace = F_WM, TextSize = 16,
    Parent = card,
})

withText("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 104),
    Text = "clarity loader",
    TextColor3 = Color3.fromRGB(150, 150, 150),
    FontFace = F_REG, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = card,
})

withText("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 124),
    Text = "welcome, " .. LocalPlayer.Name:lower() .. ".",
    TextColor3 = Color3.fromRGB(220, 220, 220),
    FontFace = F_REG, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = card,
})

withText("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 148),
    Text = "select module",
    TextColor3 = Color3.fromRGB(140, 140, 140),
    FontFace = F_REG, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = card,
})

local listContainer = new("Frame", {
    Size = UDim2.new(1, -24, 0, 128),
    Position = UDim2.fromOffset(12, 170),
    BackgroundColor3 = Color3.fromRGB(18, 18, 18),
    BorderSizePixel = 0, Parent = card,
})
new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = listContainer })
new("UIStroke", { Color = Color3.fromRGB(38, 38, 38), Thickness = 1, Parent = listContainer })
local lay = new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4), Parent = listContainer,
})
local pad = new("UIPadding", { Parent = listContainer })
pad.PaddingTop    = UDim.new(0, 10)
pad.PaddingLeft   = UDim.new(0, 12)
pad.PaddingRight  = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 10)

-- game catalog
-- [patched] all three lanes point at the user's own clarity_v2 raw url.
local CLARITY_V2_URL =
    "https://raw.githubusercontent.com/Az00zX/clarity-v2/refs/heads/main/clarity_v2.lua"

local gameConfigs = {
    ["blox strike"]  = {
        placeIds = { 114234929420007 },
        url      = CLARITY_V2_URL,
    },
    ["counter blox"] = {
        placeIds = { 301549746 },
        url      = CLARITY_V2_URL,
    },
    ["kontra"]       = {
        placeIds = { 87204735676240 },
        url      = CLARITY_V2_URL,
    },
}
local gamesOrder = { "blox strike", "counter blox", "kontra" }

-- auto-pick the current place
local currentPlaceId = game.PlaceId
local selectedGame = "counter blox"
for name, cfg in pairs(gameConfigs) do
    for _, id in ipairs(cfg.placeIds) do
        if id == currentPlaceId then selectedGame = name; break end
    end
end

local gameButtons = {}
local function repaint()
    for name, btn in pairs(gameButtons) do
        btn.TextColor3 = (name == selectedGame)
            and Accent
            or Color3.fromRGB(150, 150, 150)
    end
end

for i, name in ipairs(gamesOrder) do
    local btn = withText("TextButton", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = name,
        FontFace = F_REG, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = (name == selectedGame) and Accent or Color3.fromRGB(150, 150, 150),
        LayoutOrder = i, Parent = listContainer,
    })
    gameButtons[name] = btn
    btn.MouseButton1Click:Connect(function()
        selectedGame = name
        repaint()
    end)
end

local injectBtn = withText("TextButton", {
    Name = "InjectBtn",
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.new(0, 12, 1, -50),
    BackgroundColor3 = Color3.fromRGB(26, 26, 26),
    BorderSizePixel = 0,
    Text = "inject",
    TextColor3 = Color3.fromRGB(220, 220, 220),
    FontFace = F_BOLD, TextSize = 13,
    AutoButtonColor = false, Parent = card,
})
new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = injectBtn })
new("UIStroke", { Color = Color3.fromRGB(38, 38, 38), Thickness = 1, Parent = injectBtn })

injectBtn.MouseEnter:Connect(function()
    injectBtn.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    injectBtn.TextColor3       = Accent
end)
injectBtn.MouseLeave:Connect(function()
    injectBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    injectBtn.TextColor3       = Color3.fromRGB(220, 220, 220)
end)

injectBtn.MouseButton1Click:Connect(function()
    local cfg = gameConfigs[selectedGame]
    if not cfg then return end

    -- place guard: refuse if the current place isn't in the module's list
    local isMatch = false
    for _, id in ipairs(cfg.placeIds) do
        if id == game.PlaceId then isMatch = true; break end
    end
    if not isMatch then
        injectBtn.Text       = "invalid game!"
        injectBtn.TextColor3 = Color3.fromRGB(255, 75, 75)
        task.wait(1.2)
        injectBtn.Text       = "inject"
        injectBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        return
    end

    -- loading state: button text + animated overlay on the card.
    injectBtn.Text       = "loading..."
    injectBtn.TextColor3 = Accent

    -- loading overlay: dims the card contents and spins a biohazard
    -- ring until the main script hands control back (or errors).
    local loader = new("Frame", {
        Name = "InjectLoader",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(16, 17, 16),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 50, Parent = card,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = loader })

    local spinner = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -16),
        Size = UDim2.fromOffset(48, 48),
        BackgroundTransparency = 1,
        ZIndex = 51, Parent = loader,
    })
    -- outer dim ring
    local ringDim = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Parent = spinner,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ringDim })
    new("UIStroke", { Color = Color3.fromRGB(40, 44, 40), Thickness = 3, Parent = ringDim })
    -- bright arc (quarter)
    local ringArc = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Parent = spinner,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ringArc })
    new("UIStroke", { Color = Accent, Thickness = 3, Parent = ringArc })
    -- mask covers 3/4 of the circle so only one bright arc shows
    local mask = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.new(0.75, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(16, 17, 16),
        BorderSizePixel = 0, Parent = ringArc,
    })

    withText("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 30),
        Size = UDim2.fromOffset(220, 18),
        Text = "loading...",
        TextColor3 = Color3.fromRGB(220, 220, 220),
        FontFace = F_REG, TextSize = 13,
        ZIndex = 51, Parent = loader,
    })

    local spinning = true
    task.spawn(function()
        while spinning and spinner.Parent do
            spinner.Rotation = (spinner.Rotation + 6) % 360
            RunService.RenderStepped:Wait()
        end
    end)
    -- make sure the spinner stops if the gui gets torn down
    gui.AncestryChanged:Connect(function(_, parent)
        if not parent then spinning = false end
    end)

    -- note: kontra ships its own server-side moderation. A loader has no
    -- way to prevent a server kick from fairly-detected traffic, and this
    -- loader deliberately does not try to defeat an anti-cheat. If kontra
    -- kicks on inject, pick a map where the main script is intended to
    -- run (counter blox, blox strike) and use that lane instead.


    -- blox strike needs its debug/getfenv/string.lower hooks installed
    -- before the main script runs; keeps the executor from leaking stack
    -- info into the game's own code paths.
    if selectedGame == "blox strike" or game.PlaceId == 114234929420007 then
        pcall(function()
            if debug and debug.info and hookfunction and newcclosure then
                local old
                old = hookfunction(debug.info, newcclosure(function(a, ...)
                    if type(a) == "number" then
                        local ok, r1, r2, r3, r4, r5 = pcall(old, a, ...)
                        if ok then return r1, r2, r3, r4, r5 end
                        return ""
                    end
                    return old(a, ...)
                end))
            end
            if string and string.lower and hookfunction and newcclosure then
                local old
                old = hookfunction(string.lower, newcclosure(function(s, ...)
                    if type(s) ~= "string" then return "" end
                    return old(s, ...)
                end))
            end
            if getfenv and hookfunction and newcclosure then
                local old
                old = hookfunction(getfenv, newcclosure(function(a, ...)
                    if type(a) == "number" then
                        local ok, env = pcall(old, a, ...)
                        if ok then return env end
                        return old(1)
                    end
                    return old(a or 1, ...)
                end))
            end
        end)
    end

    -- fetch + run the main script from the configured URL
    local ok, err = pcall(function()
        loadstring(game:HttpGet(cfg.url))()
    end)

    if not ok then
        if loader and loader.Parent then loader:Destroy() end
        injectBtn.Text       = "load failed"
        injectBtn.TextColor3 = Color3.fromRGB(255, 75, 75)
        warn("[clarity loader]", err)
        task.wait(2)
        injectBtn.Text       = "inject"
        injectBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        return
    end

    injectBtn.Text       = "loaded"
    injectBtn.TextColor3 = Accent
    task.wait(0.35)
    gui:Destroy()
end)
