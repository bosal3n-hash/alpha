--[[
    ========================================================================
    ALPHA XK — ROBLOX AIMBOT + SKELETON ESP + RMB AUTO & RAPID FIRE
    Executor  : Xeno (Anti-Crash / Anti-Double-Inject Build)
    Version   : 2.3
    Features  : Instant Headshot Aimbot (RMB Hold, Camera, Smooth 0, Visible Priority)
                Team Check covers Players + NPCs/Bots (No extra Aim UI buttons)
                OUTHER Tab (Auto Fire + Rapid Fire Drawer + Bot-Only Wallbang)
                Safe Mode Toggle (Off by default: Mouse + Smooth 0.92 [92] + WallCheck)
                Menu Toggle Keybind: Home
    ========================================================================
]]

-- ░░ CLEANUP PREVIOUS INSTANCE (PREVENTS CRASH ON RE-EXECUTE) ░░
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__ALPHA_XK_CLEANUP) == "function" then
    pcall(env.__ALPHA_XK_CLEANUP)
end

-- ░░ SERVICES ░░
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")
local VirtualInputManager = select(1, pcall(function() return game:GetService("VirtualInputManager") end)) and game:GetService("VirtualInputManager") or nil
local LocalPlayer         = Players.LocalPlayer

local Connections = {}
local function TrackConn(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

local function GetCam()
    return Workspace.CurrentCamera
end

local Camera = GetCam()
TrackConn(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        Camera = Workspace.CurrentCamera
    end
end))

-- ░░ EXECUTOR POLYFILLS ░░
local moveMouse = mousemoverel or MouseMoveRel
if type(moveMouse) ~= "function" then
    moveMouse = function() end
end

local pressMouse1   = mouse1press or MouseButton1Down or mouse1down
local releaseMouse1 = mouse1release or MouseButton1Up or mouse1up
local hasDrawing    = type(Drawing) == "table" and type(Drawing.new) == "function"

local function SafeDrawingNew(kind)
    if not hasDrawing then return nil end
    local ok, obj = pcall(Drawing.new, kind)
    return ok and obj or nil
end

-- ░░ CONFIG ░░
local Config = {
    Menu = {
        Open    = true,
        Keybind = Enum.KeyCode.Home,
    },
    Aim = {
        Enabled    = true,
        SafeMode   = false,          -- Locked/Off by default: enables Mouse + Smooth 0.92 (92) + WallCheck when ON
        Keybind    = Enum.UserInputType.MouseButton2,
        Mode       = "Hold",         -- "Hold" | "Toggle"
        Method     = "Camera",       -- "Camera" | "Mouse"
        FOV        = 140,
        Smoothness = 0,              -- 0 = instant lock, 0.92 = 92 smooth, 1 = slowest
        Part       = "Head",         -- "Head" | "Neck" | "UpperTorso"
        TeamCheck  = true,           -- Applies to both Players and NPCs/Bots
        WallCheck  = false,          -- false = locks through walls when no visible target exists
        ShowFOV    = true,
        TargetNPCs = true,
    },
    ESP = {
        Enabled     = true,
        Box         = true,
        Name        = true,
        Health      = true,
        Distance    = true,
        Tracer      = false,
        Skeleton    = true,          -- Green = Visible, Red = Behind Wall
        TeamCheck   = true,
        ShowNPCs    = true,
        MaxDistance = 5000,
        TextSize    = 14,
    },
    Outher = {
        AutoFire       = true,       -- Fires ONLY when RMB keybind is active & Target is eligible
        RapidFire      = true,       -- Integrated with Auto Fire for single-shot / semi-auto weapons
        WallbangBots   = true,       -- Allows shooting through walls ONLY when target is a Bot/NPC
        FireDelay      = 0.02,
        RapidDelay     = 0.015,      -- Fast tap interval for single-shot weapons
        HoldDuration   = 0.025,
    },
}

local Theme = {
    bg      = Color3.fromRGB(18, 18, 22),
    panel   = Color3.fromRGB(26, 26, 32),
    elem    = Color3.fromRGB(38, 38, 46),
    accent  = Color3.fromRGB(255, 75, 75),
    text    = Color3.fromRGB(240, 240, 240),
    sub     = Color3.fromRGB(140, 140, 150),
    enemy   = Color3.fromRGB(255, 70, 70),
    team    = Color3.fromRGB(70, 180, 255),
    npc     = Color3.fromRGB(255, 185, 50),
    visible = Color3.fromRGB(0, 255, 110),
    hidden  = Color3.fromRGB(255, 55, 55),
}

local function FormatBindName(bind)
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.UserInputType then
            if bind == Enum.UserInputType.MouseButton2 then
                return "Right Click"
            elseif bind == Enum.UserInputType.MouseButton1 then
                return "Left Click"
            elseif bind == Enum.UserInputType.MouseButton3 then
                return "Middle Click"
            end
        end
        return bind.Name
    end
    return tostring(bind)
end

local function IsBindMatch(input, bind)
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.UserInputType then
            return input.UserInputType == bind
        elseif bind.EnumType == Enum.KeyCode then
            return input.KeyCode == bind and input.UserInputType == Enum.UserInputType.Keyboard
        end
    end
    return false
end

-- ░░ UNIFIED TEAM CHECK (PLAYERS + BOTS / NPCs) ░░
local function IsSameTeamEntity(char, plr)
    local myTeam = LocalPlayer.Team
    local myTeamName = myTeam and string.lower(myTeam.Name) or nil
    local myTeamColor = myTeam and myTeam.TeamColor or nil

    if plr then
        if plr.Team and myTeam and plr.Team == myTeam then
            return true
        end
        if plr.TeamColor and myTeamColor and plr.TeamColor == myTeamColor then
            return true
        end
        return false
    end

    if not char then return false end

    -- Check ObjectValue / StringValue / BrickColor attributes or children on NPC model
    local okVal, teamObj = pcall(function()
        return char:FindFirstChild("Team", true)
    end)
    if okVal and teamObj then
        if teamObj:IsA("ObjectValue") and teamObj.Value and myTeam and teamObj.Value == myTeam then
            return true
        elseif teamObj:IsA("StringValue") and myTeamName and string.lower(teamObj.Value) == myTeamName then
            return true
        elseif teamObj:IsA("BrickColorValue") and myTeamColor and teamObj.Value == myTeamColor then
            return true
        end
    end

    local okAttr, attrTeam = pcall(function()
        return char:GetAttribute("Team") or char:GetAttribute("TeamName")
    end)
    if okAttr and type(attrTeam) == "string" and myTeamName and string.lower(attrTeam) == myTeamName then
        return true
    end

    -- Check ancestor folder/model names matching team name (e.g., "TeamA", "Blue", "Red")
    if myTeamName and myTeamName ~= "" then
        local curr = char.Parent
        while curr and curr ~= Workspace do
            local n = string.lower(curr.Name)
            if n == myTeamName or string.find(n, myTeamName, 1, true) then
                return true
            end
            curr = curr.Parent
        end
    end

    return false
end

-- ░░ COMPATIBLE RIG VALIDATION ░░
local function FindAnyBasePart(char)
    if not char then return nil end
    local candidates = { "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso" }
    for _, name in ipairs(candidates) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            return p
        end
    end
    if char.PrimaryPart and char.PrimaryPart:IsA("BasePart") then
        return char.PrimaryPart
    end
    return nil
end

local function GetValidRig(char)
    if not char or not char.Parent then return nil end
    if LocalPlayer.Character and char == LocalPlayer.Character then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
    if hum.Health <= 0 or hum.Health > maxHp * 10 then
        return nil
    end

    local head  = char:FindFirstChild("Head")
    if head and not head:IsA("BasePart") then head = nil end

    local hrp   = char:FindFirstChild("HumanoidRootPart")
    if hrp and not hrp:IsA("BasePart") then hrp = nil end

    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if torso and not torso:IsA("BasePart") then torso = nil end

    local anchor = hrp or torso or head or FindAnyBasePart(char)
    if not anchor then return nil end

    return hum, anchor, (head or anchor), torso
end

-- ░░ VISIBILITY CHECK ░░
local function IsPartVisible(part, char)
    Camera = Camera or GetCam()
    if not (Camera and part and char) then return false end
    local origin = Camera.CFrame.Position
    local offset = part.Position - origin
    if offset.Magnitude <= 0.01 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = { char }
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    if Camera then
        table.insert(ignoreList, Camera)
    end
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = true

    local ok, result = pcall(function()
        return Workspace:Raycast(origin, offset, params)
    end)
    if not ok then return true end
    return result == nil
end

local function IsCharacterVisible(char, head, torso, anchor)
    if not char then return false end
    if head and IsPartVisible(head, char) then return true end
    if torso and IsPartVisible(torso, char) then return true end
    if anchor and anchor ~= head and anchor ~= torso and IsPartVisible(anchor, char) then return true end
    return false
end

-- ░░ NON-BLOCKING NPC / BOT CACHE SYSTEM ░░
local NPCModels = {}
local ScriptAlive = true

local function TryRegisterNPC(inst)
    if inst and inst:IsA("Humanoid") then
        local model = inst.Parent
        if model and model:IsA("Model") and model ~= LocalPlayer.Character then
            if not Players:GetPlayerFromCharacter(model) then
                NPCModels[model] = inst
            end
        end
    end
end

task.spawn(function()
    local descendants = Workspace:GetDescendants()
    for i = 1, #descendants do
        if not ScriptAlive then return end
        TryRegisterNPC(descendants[i])
        if i % 400 == 0 then
            task.wait()
        end
    end
end)

TrackConn(Workspace.DescendantAdded:Connect(function(desc)
    TryRegisterNPC(desc)
end))

TrackConn(Workspace.DescendantRemoving:Connect(function(desc)
    if NPCModels[desc] then
        NPCModels[desc] = nil
    elseif desc:IsA("Humanoid") and desc.Parent and NPCModels[desc.Parent] then
        NPCModels[desc.Parent] = nil
    end
end))

-- ░░ TARGET POSITION RESOLVER (Head / Neck / UpperTorso) ░░
local function GetTargetAimPoint(char, head, anchor, torso)
    if Config.Aim.Part == "Head" then
        local part = head or torso or anchor
        return part and part.Position or nil, part
    elseif Config.Aim.Part == "Neck" then
        if head and torso then
            return head.Position:Lerp(torso.Position, 0.45), head
        elseif head then
            return head.Position - Vector3.new(0, math.max(0.3, head.Size.Y * 0.55), 0), head
        elseif torso then
            return torso.Position + Vector3.new(0, math.max(0.3, torso.Size.Y * 0.45), 0), torso
        elseif anchor then
            return anchor.Position + Vector3.new(0, 1.2, 0), anchor
        end
    elseif Config.Aim.Part == "UpperTorso" then
        local part = torso or anchor or head
        return part and part.Position or nil, part
    end

    local fallback = head or anchor
    return fallback and fallback.Position or nil, fallback
end

-- ░░ UI HELPERS ░░
local function Create(cls, props, children)
    local inst = Instance.new(cls)
    for k, v in pairs(props or {}) do
        pcall(function() inst[k] = v end)
    end
    for _, c in ipairs(children or {}) do
        pcall(function() c.Parent = inst end)
    end
    return inst
end

local function Corner(r) return Create("UICorner", {CornerRadius = UDim.new(0, r or 6)}) end

local UI = {}

function UI.Toggle(parent, text, default, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.elem,
        BorderSizePixel = 0,
        Parent = parent,
    }, { Corner(6) })

    Create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = frame,
    })

    local btn = Create("Frame", {
        Size = UDim2.new(0, 32, 0, 18),
        Position = UDim2.new(1, -42, 0.5, -9),
        BackgroundColor3 = default and Theme.accent or Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0,
        Parent = frame,
    }, { Corner(9) })

    local knob = Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = btn,
    }, { Corner(7) })

    local state = default
    local function setVisual(s, fireCallback)
        state = s
        btn.BackgroundColor3 = s and Theme.accent or Color3.fromRGB(60, 60, 70)
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = s and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        }):Play()
        if fireCallback then
            callback(s)
        end
    end
    setVisual(default, true)

    Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = frame,
    }).MouseButton1Click:Connect(function() setVisual(not state, true) end)

    return function(s)
        setVisual(s, false)
    end
end

function UI.AutoFireWithDrawer(parent, defaultAutoFire, onAutoFireChanged, onDrawerStateChanged)
    local container = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parent,
    }, {
        Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    })

    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        LayoutOrder = 1,
        BackgroundColor3 = Theme.elem,
        BorderSizePixel = 0,
        Parent = container,
    }, { Corner(6) })

    Create("TextLabel", {
        Size = UDim2.new(1, -92, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "Auto Fire (On RMB)",
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = frame,
    })

    local arrowBtn = Create("TextButton", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -72, 0.5, -11),
        BackgroundColor3 = Theme.panel,
        Text = "▾",
        TextColor3 = Theme.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        BorderSizePixel = 0,
        Visible = defaultAutoFire and true or false,
        Parent = frame,
    }, { Corner(5) })

    local btn = Create("Frame", {
        Size = UDim2.new(0, 32, 0, 18),
        Position = UDim2.new(1, -42, 0.5, -9),
        BackgroundColor3 = defaultAutoFire and Theme.accent or Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0,
        Parent = frame,
    }, { Corner(9) })

    local knob = Create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = defaultAutoFire and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = btn,
    }, { Corner(7) })

    local drawer = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = container,
    }, {
        Create("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
        }),
        Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    })

    local autoState = defaultAutoFire
    local expanded = false

    local function syncArrowAndDrawer()
        if not autoState then
            expanded = false
            arrowBtn.Visible = false
            drawer.Visible = false
        else
            arrowBtn.Visible = true
            arrowBtn.Text = expanded and "▴" or "▾"
            drawer.Visible = expanded
        end
        if onDrawerStateChanged then
            onDrawerStateChanged()
        end
    end

    local function applyAutoState(s)
        autoState = s
        btn.BackgroundColor3 = s and Theme.accent or Color3.fromRGB(60, 60, 70)
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = s and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        }):Play()
        syncArrowAndDrawer()
        if onAutoFireChanged then
            onAutoFireChanged(s)
        end
    end

    applyAutoState(defaultAutoFire)

    Create("TextButton", {
        Size = UDim2.new(1, -80, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = frame,
    }).MouseButton1Click:Connect(function()
        applyAutoState(not autoState)
    end)

    arrowBtn.MouseButton1Click:Connect(function()
        if not autoState then return end
        expanded = not expanded
        syncArrowAndDrawer()
    end)

    return drawer
end

function UI.Slider(parent, text, min, max, default, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.elem,
        BorderSizePixel = 0,
        Parent = parent,
    }, { Corner(6) })

    Create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 20),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = frame,
    })

    local valueLabel = Create("TextLabel", {
        Size = UDim2.new(0, 80, 0, 20),
        Position = UDim2.new(1, -90, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Theme.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = frame,
    })

    local track = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 4),
        Position = UDim2.new(0, 10, 0, 32),
        BackgroundColor3 = Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0,
        Parent = frame,
    }, { Corner(99) })

    local fill = Create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Parent = track,
    }, { Corner(99) })

    local knob = Create("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 0, 0.5, -6),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = track,
    }, { Corner(6) })

    local value = default
    local function set(v, fireCallback)
        value = math.clamp(v, min, max)
        local pct = (value - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, -6)
        if max > 10 then
            valueLabel.Text = tostring(math.floor(value + 0.5))
        else
            valueLabel.Text = string.format("%.2f", value)
        end
        if fireCallback then
            callback(value)
        end
    end
    set(default, true)

    local dragging = false
    local hitbox = Create("TextButton", {
        Size = UDim2.new(1, 20, 1, 20),
        Position = UDim2.new(0, -10, 0, -10),
        BackgroundTransparency = 1,
        Text = "",
        Parent = track,
    })
    hitbox.MouseButton1Down:Connect(function() dragging = true end)

    TrackConn(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    TrackConn(UserInputService.InputChanged:Connect(function(i)
        if not dragging or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local mx = UserInputService:GetMouseLocation().X
        local ax = track.AbsolutePosition.X
        local aw = track.AbsoluteSize.X
        local pct = math.clamp((mx - ax) / math.max(1, aw), 0, 1)
        set(min + (max - min) * pct, true)
    end))

    return function(v)
        set(v, false)
    end
end

function UI.Dropdown(parent, text, options, defaultIndex, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.elem,
        BorderSizePixel = 0,
        Parent = parent,
    }, { Corner(6) })

    Create("TextLabel", {
        Size = UDim2.new(0, 115, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = frame,
    })

    local idx = defaultIndex or 1
    local btn = Create("TextButton", {
        Size = UDim2.new(0, 120, 0, 22),
        Position = UDim2.new(1, -128, 0.5, -11),
        BackgroundColor3 = Theme.panel,
        Text = options[idx],
        TextColor3 = Theme.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        BorderSizePixel = 0,
        Parent = frame,
    }, { Corner(5) })

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        btn.Text = options[idx]
        callback(options[idx], idx)
    end)

    return function(val)
        for i, opt in ipairs(options) do
            if opt == val then
                idx = i
                btn.Text = opt
                break
            end
        end
    end
end

local listeningForBind = false

function UI.Keybind(parent, text, default, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.elem,
        BorderSizePixel = 0,
        Parent = parent,
    }, { Corner(6) })

    Create("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = frame,
    })

    local current = default
    local btn = Create("TextButton", {
        Size = UDim2.new(0, 95, 0, 22),
        Position = UDim2.new(1, -105, 0.5, -11),
        BackgroundColor3 = Theme.panel,
        Text = FormatBindName(current),
        TextColor3 = Theme.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BorderSizePixel = 0,
        Parent = frame,
    }, { Corner(5) })

    local listening = false
    btn.MouseButton1Click:Connect(function()
        listening = true
        listeningForBind = true
        btn.Text = "…"
    end)

    TrackConn(UserInputService.InputBegan:Connect(function(input)
        if not listening then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            current = input.KeyCode
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            current = input.UserInputType
        else
            return
        end
        btn.Text = FormatBindName(current)
        listening = false
        task.defer(function()
            listeningForBind = false
        end)
        callback(current)
    end))
end

-- ░░ UI BUILD ░░
local parentGui
pcall(function()
    if type(gethui) == "function" then
        parentGui = gethui()
    end
end)
if not parentGui then
    parentGui = LocalPlayer:WaitForChild("PlayerGui")
end

pcall(function()
    local old = parentGui:FindFirstChild("ALPHA_XK_UI")
    if old then old:Destroy() end
end)

local ScreenGui = Create("ScreenGui", {
    Name = "ALPHA_XK_UI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = parentGui,
})

local Main = Create("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 286, 0, 440),
    Position = UDim2.new(0, 30, 0, 30),
    BackgroundColor3 = Theme.bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
    Visible = Config.Menu.Open,
    Parent = ScreenGui,
}, { Corner(10) })

local function SetMenuOpen(open)
    Config.Menu.Open = open
    Main.Visible = open
end

Create("UIStroke", {
    Color = Theme.accent,
    Thickness = 1,
    Transparency = 0.6,
    Parent = Main,
})

Create("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    Parent = Main,
}, { Corner(10) })

Create("TextLabel", {
    Size = UDim2.new(1, -50, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "ALPHA XK — RBX [HOME]",
    TextColor3 = Theme.accent,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    Parent = Main,
})

local minimizeBtn = Create("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -30, 0, 6),
    BackgroundColor3 = Theme.elem,
    Text = "—",
    TextColor3 = Theme.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    BorderSizePixel = 0,
    Parent = Main,
}, { Corner(5) })

local TabBar = Create("Frame", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 44),
    BackgroundColor3 = Theme.panel,
    BorderSizePixel = 0,
    Parent = Main,
}, { Corner(6) })

local Content = Create("ScrollingFrame", {
    Size = UDim2.new(1, -20, 0, 340),
    Position = UDim2.new(0, 10, 0, 82),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.accent,
    Parent = Main,
}, { Corner(6) })

local AimPage = Create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Parent = Content,
}, {
    Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
})

local ESPPage = Create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = Content,
}, {
    Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
})

local OutherPage = Create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = Content,
}, {
    Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
})

local function MakeTab(name, index)
    return Create("TextButton", {
        Size = UDim2.new(1 / 3, -4, 1, -4),
        Position = UDim2.new(index / 3, 2, 0, 2),
        BackgroundColor3 = index == 0 and Theme.accent or Theme.elem,
        Text = name,
        TextColor3 = Theme.text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        BorderSizePixel = 0,
        Parent = TabBar,
    }, { Corner(4) })
end

local AimTab    = MakeTab("AIM", 0)
local ESPTab    = MakeTab("ESP", 1)
local OutherTab = MakeTab("OUTHER", 2)

local allPages = { AimPage, ESPPage, OutherPage }
local allTabs  = { AimTab, ESPTab, OutherTab }

local function RefreshCanvas()
    for _, page in ipairs(allPages) do
        if page.Visible then
            local layout = page:FindFirstChildOfClass("UIListLayout")
            if layout then
                Content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
            end
        end
    end
end

local function SwitchTab(targetPage, activeBtn)
    for _, page in ipairs(allPages) do
        page.Visible = (page == targetPage)
    end
    for _, btn in ipairs(allTabs) do
        btn.BackgroundColor3 = (btn == activeBtn) and Theme.accent or Theme.elem
    end
    RefreshCanvas()
end

AimTab.MouseButton1Click:Connect(function() SwitchTab(AimPage, AimTab) end)
ESPTab.MouseButton1Click:Connect(function() SwitchTab(ESPPage, ESPTab) end)
OutherTab.MouseButton1Click:Connect(function() SwitchTab(OutherPage, OutherTab) end)

minimizeBtn.MouseButton1Click:Connect(function()
    Content.Visible = not Content.Visible
    Main.Size = Content.Visible and UDim2.new(0, 286, 0, 440) or UDim2.new(0, 286, 0, 44)
end)

-- ░░ AIM PAGE (NO EXTRA BUTTONS; TEAM CHECK COVERS PLAYERS + NPCs) ░░
local setMethodUI
local setSmoothUI
local setWallCheckUI

UI.Toggle(AimPage, "Enable Aimbot", Config.Aim.Enabled, function(v) Config.Aim.Enabled = v end)

UI.Toggle(AimPage, "Safe Mode", Config.Aim.SafeMode, function(enabled)
    Config.Aim.SafeMode = enabled
    if enabled then
        Config.Aim.Method = "Mouse"
        Config.Aim.Smoothness = 0.92
        Config.Aim.WallCheck = true
    else
        Config.Aim.Method = "Camera"
        Config.Aim.Smoothness = 0
        Config.Aim.WallCheck = false
    end
    if setMethodUI then setMethodUI(Config.Aim.Method) end
    if setSmoothUI then setSmoothUI(Config.Aim.Smoothness) end
    if setWallCheckUI then setWallCheckUI(Config.Aim.WallCheck) end
end)

UI.Keybind(AimPage, "Keybind", Config.Aim.Keybind, function(k) Config.Aim.Keybind = k end)
UI.Keybind(AimPage, "Menu Key (Home)", Config.Menu.Keybind, function(k) Config.Menu.Keybind = k end)
UI.Dropdown(AimPage, "Mode", { "Hold", "Toggle" }, 1, function(v) Config.Aim.Mode = v end)
setMethodUI = UI.Dropdown(AimPage, "Method", { "Camera", "Mouse" }, 1, function(v) Config.Aim.Method = v end)
UI.Dropdown(AimPage, "Target Part", { "Head", "Neck", "UpperTorso" }, 1, function(v) Config.Aim.Part = v end)
UI.Slider(AimPage, "FOV", 30, 500, Config.Aim.FOV, function(v) Config.Aim.FOV = v end)
setSmoothUI = UI.Slider(AimPage, "Smoothness", 0, 1, Config.Aim.Smoothness, function(v) Config.Aim.Smoothness = v end)
UI.Toggle(AimPage, "Target NPCs / Bots", Config.Aim.TargetNPCs, function(v) Config.Aim.TargetNPCs = v end)
UI.Toggle(AimPage, "Team Check", Config.Aim.TeamCheck, function(v) Config.Aim.TeamCheck = v end)
setWallCheckUI = UI.Toggle(AimPage, "Wall Check", Config.Aim.WallCheck, function(v) Config.Aim.WallCheck = v end)
UI.Toggle(AimPage, "Show FOV Circle", Config.Aim.ShowFOV, function(v) Config.Aim.ShowFOV = v end)

-- ░░ ESP PAGE ░░
UI.Toggle(ESPPage, "Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
UI.Toggle(ESPPage, "Show NPCs / Bots", Config.ESP.ShowNPCs, function(v) Config.ESP.ShowNPCs = v end)
UI.Toggle(ESPPage, "Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
UI.Toggle(ESPPage, "Show Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
UI.Toggle(ESPPage, "Health Bar", Config.ESP.Health, function(v) Config.ESP.Health = v end)
UI.Toggle(ESPPage, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
UI.Toggle(ESPPage, "Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
UI.Toggle(ESPPage, "Skeleton (Vis)", Config.ESP.Skeleton, function(v) Config.ESP.Skeleton = v end)
UI.Toggle(ESPPage, "Team Check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
UI.Slider(ESPPage, "Max Distance", 100, 5000, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance = v end)
UI.Slider(ESPPage, "Text Size", 10, 24, Config.ESP.TextSize, function(v) Config.ESP.TextSize = v end)

-- ░░ OUTHER PAGE (AUTO FIRE + RAPID FIRE DRAWER + BOT-ONLY WALLBANG) ░░
local autoFireDrawer = UI.AutoFireWithDrawer(OutherPage, Config.Outher.AutoFire, function(v)
    Config.Outher.AutoFire = v
end, RefreshCanvas)

UI.Toggle(autoFireDrawer, "Rapid Fire", Config.Outher.RapidFire, function(v)
    Config.Outher.RapidFire = v
end)

UI.Slider(autoFireDrawer, "Fire Delay (s)", 0.01, 0.30, Config.Outher.FireDelay, function(v)
    Config.Outher.FireDelay = v
end)

UI.Slider(autoFireDrawer, "Rapid Delay (s)", 0.01, 0.20, Config.Outher.RapidDelay, function(v)
    Config.Outher.RapidDelay = v
end)

UI.Toggle(OutherPage, "Wallbang Bots (NPC Only)", Config.Outher.WallbangBots, function(v)
    Config.Outher.WallbangBots = v
end)

for _, page in ipairs(allPages) do
    TrackConn(page:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(RefreshCanvas))
end
RefreshCanvas()

-- ░░ FOV CIRCLE ░░
local FOVCircle = SafeDrawingNew("Circle")
if FOVCircle then
    pcall(function()
        FOVCircle.Thickness = 1
        FOVCircle.NumSides = 64
        FOVCircle.Filled = false
        FOVCircle.Color = Color3.new(1, 1, 1)
        FOVCircle.Transparency = 0.7
        FOVCircle.Visible = false
    end)
end

-- ░░ SKELETON BONE PAIRS ░░
local R15Bones = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local R6Bones = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

-- ░░ ESP SYSTEM ░░
local ESPObjects = {}

local function NewSquare()
    local s = SafeDrawingNew("Square")
    if s then
        pcall(function()
            s.Thickness = 1
            s.Filled = false
            s.Visible = false
        end)
    end
    return s
end

local function NewText()
    local t = SafeDrawingNew("Text")
    if t then
        pcall(function()
            t.Center = true
            t.Outline = true
            t.Visible = false
        end)
    end
    return t
end

local function NewLine(thickness)
    local l = SafeDrawingNew("Line")
    if l then
        pcall(function()
            l.Thickness = thickness or 1.6
            l.Visible = false
        end)
    end
    return l
end

local function SetVis(obj, vis)
    if obj then
        pcall(function() obj.Visible = vis end)
    end
end

local function EnsureObjects(key)
    if ESPObjects[key] then return ESPObjects[key] end
    local skeletonLines = {}
    for i = 1, #R15Bones do
        skeletonLines[i] = NewLine(1.6)
    end
    local hpBg = NewSquare()
    local hpFill = NewSquare()
    if hpBg then pcall(function() hpBg.Filled = true end) end
    if hpFill then pcall(function() hpFill.Filled = true end) end

    local o = {
        box      = NewSquare(),
        name     = NewText(),
        hpBg     = hpBg,
        hpFill   = hpFill,
        dist     = NewText(),
        tracer   = NewLine(1),
        skeleton = skeletonLines,
    }
    ESPObjects[key] = o
    return o
end

local function HideSkeleton(o)
    if not o or not o.skeleton then return end
    for _, line in ipairs(o.skeleton) do
        SetVis(line, false)
    end
end

local function HideAll(o)
    if not o then return end
    SetVis(o.box, false)
    SetVis(o.name, false)
    SetVis(o.hpBg, false)
    SetVis(o.hpFill, false)
    SetVis(o.dist, false)
    SetVis(o.tracer, false)
    HideSkeleton(o)
end

local function RemoveESPKey(key)
    local o = ESPObjects[key]
    if not o then return end
    for k, obj in pairs(o) do
        if k == "skeleton" then
            for _, line in ipairs(obj) do pcall(function() line:Remove() end) end
        else
            pcall(function() obj:Remove() end)
        end
    end
    ESPObjects[key] = nil
end

local function DrawTargetESP(char, hum, hrp, head, torso, displayName, isTeam, isNPC)
    if not hasDrawing then return end
    Camera = Camera or GetCam()
    if not Camera then return end

    local o = EnsureObjects(char)

    if not Config.ESP.Enabled then
        HideAll(o)
        return
    end

    if Config.ESP.TeamCheck and isTeam then
        HideAll(o)
        return
    end

    local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
    if distance > Config.ESP.MaxDistance then
        HideAll(o)
        return
    end

    local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    if not onScreen or headPos.Z <= 0 then
        HideAll(o)
        return
    end

    local footPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    local isVisible = IsCharacterVisible(char, head, torso, hrp)
    local visColor = isVisible and Theme.visible or Theme.hidden
    local labelColor = isNPC and Theme.npc or (isTeam and Theme.team or Theme.enemy)

    if Config.ESP.Box and o.box then
        local top    = headPos.Y - 15
        local bottom = footPos.Y + 5
        local h = math.max(10, bottom - top)
        local w = h / 2
        pcall(function()
            o.box.Size = Vector2.new(w, h)
            o.box.Position = Vector2.new(headPos.X - w / 2, top)
            o.box.Color = visColor
            o.box.Visible = true
        end)
    else
        SetVis(o.box, false)
    end

    if Config.ESP.Name and o.name then
        pcall(function()
            o.name.Text = isNPC and ("[BOT] " .. displayName) or displayName
            o.name.Size = Config.ESP.TextSize
            o.name.Color = labelColor
            o.name.Position = Vector2.new(headPos.X, headPos.Y - 35)
            o.name.Visible = true
        end)
    else
        SetVis(o.name, false)
    end

    if Config.ESP.Health and o.box and o.box.Visible and o.hpBg and o.hpFill then
        local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
        local pct = math.clamp(hum.Health / maxHp, 0, 1)
        local bx, by, bw, bh = o.box.Position.X - 6, o.box.Position.Y, 3, o.box.Size.Y
        pcall(function()
            o.hpBg.Size = Vector2.new(bw, bh)
            o.hpBg.Position = Vector2.new(bx, by)
            o.hpBg.Color = Color3.fromRGB(40, 40, 40)
            o.hpBg.Visible = true

            local fillH = bh * pct
            o.hpFill.Size = Vector2.new(bw, fillH)
            o.hpFill.Position = Vector2.new(bx, by + (bh - fillH))
            o.hpFill.Color = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
            o.hpFill.Visible = true
        end)
    else
        SetVis(o.hpBg, false)
        SetVis(o.hpFill, false)
    end

    if Config.ESP.Distance and o.dist then
        pcall(function()
            o.dist.Text = string.format("[%d]", math.floor(distance))
            o.dist.Size = math.max(10, Config.ESP.TextSize - 2)
            o.dist.Color = labelColor
            o.dist.Position = Vector2.new(headPos.X, footPos.Y + 10)
            o.dist.Visible = true
        end)
    else
        SetVis(o.dist, false)
    end

    if Config.ESP.Tracer and o.tracer then
        pcall(function()
            o.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            o.tracer.To = Vector2.new(headPos.X, headPos.Y)
            o.tracer.Color = visColor
            o.tracer.Visible = true
        end)
    else
        SetVis(o.tracer, false)
    end

    if Config.ESP.Skeleton and o.skeleton then
        local bones = char:FindFirstChild("UpperTorso") and R15Bones or R6Bones
        for i, line in ipairs(o.skeleton) do
            local pair = bones[i]
            if pair and line then
                local p1 = char:FindFirstChild(pair[1])
                local p2 = char:FindFirstChild(pair[2])
                if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                    local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
                    local v2, on2 = Camera:WorldToViewportPoint(p2.Position)
                    if on1 and on2 and v1.Z > 0 and v2.Z > 0 then
                        pcall(function()
                            line.From = Vector2.new(v1.X, v1.Y)
                            line.To = Vector2.new(v2.X, v2.Y)
                            line.Color = visColor
                            line.Visible = true
                        end)
                    else
                        SetVis(line, false)
                    end
                else
                    SetVis(line, false)
                end
            else
                SetVis(line, false)
            end
        end
    else
        HideSkeleton(o)
    end
end

local function UpdateESP()
    if not hasDrawing then return end
    local activeChars = {}
    local seenNPCSignatures = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        local hum, hrp, head, torso = GetValidRig(char)
        if hum and hrp and head then
            activeChars[char] = true
            local isTeam = IsSameTeamEntity(char, plr)
            DrawTargetESP(char, hum, hrp, head, torso, plr.Name, isTeam, false)
        end
    end

    if Config.ESP.ShowNPCs then
        for model, hum in pairs(NPCModels) do
            if Players:GetPlayerFromCharacter(model) then
                NPCModels[model] = nil
                continue
            end
            local vHum, hrp, head, torso = GetValidRig(model)
            if not vHum or not hrp or not head then
                if not model.Parent then
                    NPCModels[model] = nil
                end
                continue
            end

            local gridKey = string.format("%s_%d_%d",
                model.Name,
                math.floor(hrp.Position.X / 2),
                math.floor(hrp.Position.Z / 2)
            )
            if seenNPCSignatures[gridKey] then
                continue
            end
            seenNPCSignatures[gridKey] = true

            activeChars[model] = true
            local isTeam = IsSameTeamEntity(model, nil)
            DrawTargetESP(model, vHum, hrp, head, torso, model.Name, isTeam, true)
        end
    end

    for char, _ in pairs(ESPObjects) do
        if not activeChars[char] then
            if not char.Parent then
                RemoveESPKey(char)
            else
                HideAll(ESPObjects[char])
            end
        end
    end
end

-- ░░ AIMBOT SYSTEM (VISIBLE / GREEN SKELETON PRIORITY — PLAYERS + NPCs) ░░
local aimActive = false

TrackConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if listeningForBind then return end

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.Menu.Keybind then
        SetMenuOpen(not Config.Menu.Open)
        return
    end

    if gpe and input.UserInputType == Enum.UserInputType.Keyboard then return end
    if not IsBindMatch(input, Config.Aim.Keybind) then return end
    if Config.Aim.Mode == "Hold" then
        aimActive = true
    else
        aimActive = not aimActive
    end
end))

TrackConn(UserInputService.InputEnded:Connect(function(input)
    if IsBindMatch(input, Config.Aim.Keybind) and Config.Aim.Mode == "Hold" then
        aimActive = false
    end
end))

local function CollectCandidate(char, isNPC, refPos, bestVisible, bestVisibleDist, bestHidden, bestHiddenDist)
    Camera = Camera or GetCam()
    if not Camera then
        return bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
    end

    local hum, hrp, head, torso = GetValidRig(char)
    if not hum or not hrp or not head then
        return bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
    end

    local aimPos, part = GetTargetAimPoint(char, head, hrp, torso)
    if not aimPos then
        return bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
    if not onScreen or screenPos.Z <= 0 then
        return bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
    end

    local d = (Vector2.new(screenPos.X, screenPos.Y) - refPos).Magnitude
    if d > Config.Aim.FOV then
        return bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
    end

    local isVisible = IsCharacterVisible(char, head, torso, hrp)
    local canFireThroughWall = isNPC and Config.Outher.WallbangBots

    local entry = {
        char = char,
        isNPC = isNPC,
        part = part,
        pos = aimPos,
        screen = Vector2.new(screenPos.X, screenPos.Y),
        visible = isVisible,
        canFire = isVisible or canFireThroughWall,
    }

    if isVisible then
        if d < bestVisibleDist then
            return entry, d, bestHidden, bestHiddenDist
        end
    elseif (not Config.Aim.WallCheck) or canFireThroughWall then
        if d < bestHiddenDist then
            return bestVisible, bestVisibleDist, entry, d
        end
    end

    return bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
end

local function GetClosestTarget()
    Camera = Camera or GetCam()
    if not Camera then return nil end

    local bestVisible, bestVisibleDist = nil, math.huge
    local bestHidden, bestHiddenDist   = nil, math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local centerScreen = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    local refPos = (Config.Aim.Method == "Camera") and centerScreen or mousePos

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Config.Aim.TeamCheck and IsSameTeamEntity(plr.Character, plr) then continue end
        bestVisible, bestVisibleDist, bestHidden, bestHiddenDist = CollectCandidate(
            plr.Character, false, refPos, bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
        )
    end

    if Config.Aim.TargetNPCs then
        for model, hum in pairs(NPCModels) do
            if not model.Parent or not hum.Parent or Players:GetPlayerFromCharacter(model) then
                NPCModels[model] = nil
                continue
            end
            if Config.Aim.TeamCheck and IsSameTeamEntity(model, nil) then continue end
            bestVisible, bestVisibleDist, bestHidden, bestHiddenDist = CollectCandidate(
                model, true, refPos, bestVisible, bestVisibleDist, bestHidden, bestHiddenDist
            )
        end
    end

    return bestVisible or bestHidden
end

local function ApplyInstantAim(target)
    if not Config.Aim.Enabled or not aimActive or not target then return end
    Camera = Camera or GetCam()
    if not Camera then return end

    local aimPos = target.pos
    if Config.Aim.Method == "Camera" then
        local camPos = Camera.CFrame.Position
        if (aimPos - camPos).Magnitude > 0.001 then
            local targetCF = CFrame.lookAt(camPos, aimPos)
            pcall(function()
                if Config.Aim.Smoothness <= 0 then
                    Camera.CFrame = targetCF
                else
                    local factor = 1 - math.clamp(Config.Aim.Smoothness, 0, 0.95)
                    Camera.CFrame = Camera.CFrame:Lerp(targetCF, factor)
                end
            end)
        end
    else
        local mousePos = UserInputService:GetMouseLocation()
        local delta = target.screen - mousePos
        pcall(function()
            if Config.Aim.Smoothness <= 0 then
                moveMouse(delta.X, delta.Y)
            else
                local factor = 1 - math.clamp(Config.Aim.Smoothness, 0, 0.95)
                moveMouse(delta.X * factor, delta.Y * factor)
            end
        end)
    end
end

-- ░░ OUTHER AUTO + RAPID FIRE (BOT WALLBANG ALLOWED; REAL PLAYERS REQUIRE VISIBILITY) ░░
local lastShotTime = 0
local firingPulse = false

local function PerformSingleTap(holdTime)
    local didMouse = false
    if type(pressMouse1) == "function" then
        didMouse = pcall(pressMouse1)
        task.wait(holdTime)
        if type(releaseMouse1) == "function" then
            pcall(releaseMouse1)
        end
    elseif VirtualInputManager then
        local center = Camera and Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5) or Vector2.new(500, 500)
        didMouse = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
        end)
        task.wait(holdTime)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        end)
    end

    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool and (not didMouse or not hasDrawing) then
        pcall(function() tool:Activate() end)
    end
end

local function TriggerShot(isRapid)
    if firingPulse then return end
    firingPulse = true
    task.spawn(function()
        if isRapid then
            PerformSingleTap(Config.Outher.HoldDuration)
            task.wait(math.max(0.008, Config.Outher.RapidDelay * 0.5))
            PerformSingleTap(Config.Outher.HoldDuration)
        else
            PerformSingleTap(Config.Outher.HoldDuration)
        end
        firingPulse = false
    end)
end

local function ProcessOutherAutoFire(currentTarget)
    if not Config.Outher.AutoFire or not aimActive then return end

    local candidate = currentTarget or GetClosestTarget()
    local allowedTarget = candidate and (candidate.visible or (candidate.isNPC and Config.Outher.WallbangBots))
    if allowedTarget then
        local activeDelay = Config.Outher.RapidFire
            and math.min(Config.Outher.FireDelay, Config.Outher.RapidDelay)
            or Config.Outher.FireDelay
        local now = os.clock()
        if (now - lastShotTime) >= activeDelay then
            lastShotTime = now
            TriggerShot(Config.Outher.RapidFire)
        end
    end
end

local function OnRenderStep()
    if not ScriptAlive then return end
    Camera = Camera or GetCam()
    if not Camera then return end

    local fovCenter = (Config.Aim.Method == "Camera")
        and Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
        or UserInputService:GetMouseLocation()

    if FOVCircle then
        pcall(function()
            if Config.Aim.ShowFOV then
                FOVCircle.Position = fovCenter
                FOVCircle.Radius = Config.Aim.FOV
                FOVCircle.Visible = true
            else
                FOVCircle.Visible = false
            end
        end)
    end

    pcall(UpdateESP)

    local target
    pcall(function()
        target = GetClosestTarget()
    end)

    if aimActive and target then
        ApplyInstantAim(target)
        pcall(function()
            ProcessOutherAutoFire(target)
        end)
    end
end

TrackConn(RunService.RenderStepped:Connect(OnRenderStep))

-- ░░ REGISTER CLEANUP HOOK FOR SAFE RE-INJECTION ░░
env.__ALPHA_XK_CLEANUP = function()
    ScriptAlive = false
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)

    if FOVCircle then
        pcall(function() FOVCircle:Remove() end)
        FOVCircle = nil
    end

    for key, _ in pairs(ESPObjects) do
        RemoveESPKey(key)
    end
    table.clear(ESPObjects)
    table.clear(NPCModels)

    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
        ScreenGui = nil
    end
end

print("[ALPHA XK v2.3] Unified Team Check + Bot-Only Wallbang + Auto/Rapid Fire loaded.")
