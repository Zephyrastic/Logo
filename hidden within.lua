-- Hidden Within | Guns - Silent Aim (no team checks) + MS ESP + Obsidian UI
-- Game: Hidden Within (PlaceId 123907164579958)
-- Guns: AKM, Glock_19X, SMG9, TEC9, Revolver, TommyGun, etc.
-- How it works (verified against live client):
--   GunClass._Shoot reads workspace.Camera.CFrame, calls Raycasts.getAimDirection(CFrame),
--   then Raycasts.Raycast(camPos, dir, range) for hitPos, then fires
--   Packet("GunService_S"):Fire("UpdateGunState", {"Shoot", toolName, CFrame, hitPos, {hitInstance}})
-- Silent aim spoofs ONLY the network packet (CFrame / hitPos / instances).
-- Local camera + tracer stay untouched, so it is silent.
-- No team checks per request: every player except LocalPlayer is a valid target.

if getgenv().HiddenWithinHubLoaded then
    return
end
getgenv().HiddenWithinHubLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// Obsidian
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

-- Safe UI reads: return fallback instead of erroring if a key is missing.
-- (Prevents the ":369 attempt to index nil with 'Value'" spam class entirely.)
local function TVal(id, fb)
    local t = Toggles[id]
    if t ~= nil then
        local ok, v = pcall(function() return t.Value end)
        if ok and v ~= nil then
            return v
        end
    end
    return fb
end
local function OVal(id, fb)
    local o = Options[id]
    if o ~= nil then
        local ok, v = pcall(function() return o.Value end)
        if ok and v ~= nil then
            return v
        end
    end
    return fb
end

local Window = Library:CreateWindow({
    Title = "Hidden Within | Guns",
    Footer = "v1.0 | silent + esp",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Combat = Window:AddTab("Combat", "crosshair"),
    ESP = Window:AddTab("ESP", "eye"),
    Settings = Window:AddTab("UI Settings", "settings"),
}

local SilentMain = Tabs.Combat:AddGroupbox({ Side = "Left", Name = "Silent Aim", IconName = "crosshair" })
local SilentFOV = Tabs.Combat:AddGroupbox({ Side = "Right", Name = "Target / FOV", IconName = "circle-dot" })
local GunMods = Tabs.Combat:AddGroupbox({ Side = "Right", Name = "Gun Mods", IconName = "wrench" })

local ESPMain = Tabs.ESP:AddGroupbox({ Side = "Left", Name = "Player ESP", IconName = "eye" })
local ESPItems = Tabs.ESP:AddGroupbox({ Side = "Left", Name = "Item ESP", IconName = "package" })
local ESPVisuals = Tabs.ESP:AddGroupbox({ Side = "Right", Name = "ESP Style", IconName = "palette" })

--// Combat UI
SilentMain:AddToggle("SilentEnabled", { Text = "Enable Silent Aim", Default = false, Tooltip = "Redirect gun shots to closest target. No team checks." })
SilentMain:AddToggle("UseFOV", { Text = "Use FOV", Default = true, Tooltip = "When OFF, FOV limit is removed and any visible target can be hit." })
SilentMain:AddToggle("WallCheck", { Text = "Wall Check", Default = true, Tooltip = "Skip targets behind walls." })
SilentMain:AddToggle("ShowFOV", { Text = "Show FOV Circle", Default = true })
SilentMain:AddToggle("ShowTarget", { Text = "Target Indicator", Default = true, Tooltip = "Draw name marker on the current silent-aim target." })
SilentMain:AddLabel("SilentStatus", { Text = "Status: idle", DoesWrap = true })
SilentMain:AddLabel("FOV Color"):AddColorPicker("FOVColor", { Default = Color3.fromRGB(255, 255, 255), Title = "FOV Circle" })
SilentMain:AddLabel("Target Color"):AddColorPicker("TargetColor", { Default = Color3.fromRGB(255, 50, 50), Title = "Target Indicator" })

SilentFOV:AddDropdown("TargetPart", {
    Values = { "Head", "HumanoidRootPart", "Torso", "Closest" },
    Default = "Head",
    Multi = false,
    Text = "Target Part",
})
SilentFOV:AddDropdown("TargetMode", {
    Values = { "Mouse", "Center" },
    Default = "Mouse",
    Multi = false,
    Text = "FOV Center",
    Tooltip = "Mouse = closest to cursor. Center = closest to screen center.",
})
SilentFOV:AddSlider("FOVRadius", { Text = "FOV Radius", Default = 300, Min = 10, Max = 1000, Rounding = 0, Suffix = "px" })
SilentFOV:AddSlider("HitChance", { Text = "Hit Chance", Default = 100, Min = 0, Max = 100, Rounding = 0, Suffix = "%" })
SilentFOV:AddSlider("SilentMaxDist", { Text = "Max Target Dist", Default = 600, Min = 50, Max = 2000, Rounding = 0, Suffix = "st" })
SilentFOV:AddToggle("EnablePrediction", { Text = "Enable Prediction", Default = true, Tooltip = "Lead moving targets using their velocity." })
SilentFOV:AddSlider("PredictionAmount", { Text = "Prediction", Default = 0.13, Min = 0, Max = 0.5, Rounding = 3, Suffix = "s", Tooltip = "Seconds to lead the target. ~ping + a bit." })

--// Gun Mods (client GunConfig; restored when toggled off)
GunMods:AddToggle("InfAmmo", { Text = "Infinite Ammo", Default = false, Tooltip = "Keeps <Gun>_Ammo topped up on your character." })
GunMods:AddToggle("FullAuto", { Text = "Automatic Fire", Default = false, Tooltip = "Makes semi guns fire while held." })
GunMods:AddToggle("RapidFire", { Text = "No Fire Delay", Default = false, Tooltip = "Sets every gun FireRate to 0." })
GunMods:AddToggle("NoRecoil", { Text = "No Recoil", Default = false })
GunMods:AddToggle("NoSpread", { Text = "No Spread", Default = false, Tooltip = "Kills recoil shake applied to the camera. Re-equip gun to restore feel." })
GunMods:AddToggle("RemoveBounds", { Text = "Remove KillBounds", Default = false, Tooltip = "Strips touch-kill from KillBoundaries folders. Rejoin to restore." })

--// ESP UI
ESPMain:AddToggle("ESPEnabled", { Text = "Enable Player ESP", Default = false })
ESPMain:AddToggle("UseBox2D", { Text = "2D Box", Default = true })
ESPMain:AddToggle("UseBox3D", { Text = "3D Box", Default = false })
ESPMain:AddToggle("UseTracer", { Text = "Tracer", Default = true })
ESPMain:AddToggle("UseArrow", { Text = "Off-screen Arrow", Default = false })
ESPMain:AddToggle("UseSkeleton", { Text = "Skeleton", Default = false })
ESPMain:AddToggle("ShowNames", { Text = "Names", Default = true })
ESPMain:AddToggle("ShowDistance", { Text = "Distance", Default = true })
ESPMain:AddToggle("ShowHealth", { Text = "Health", Default = true, Tooltip = "Append HP to ESP names and tint by health." })

ESPVisuals:AddDropdown("TracerFrom", {
    Values = { "Bottom", "Top", "Center", "Mouse" },
    Default = "Bottom",
    Multi = false,
    Text = "Tracer Origin",
})
ESPVisuals:AddSlider("ESPMaxDist", { Text = "Max Distance", Default = 1000, Min = 100, Max = 5000, Rounding = 0 })
ESPVisuals:AddSlider("ESPTextSize", { Text = "Text Size", Default = 16, Min = 10, Max = 24, Rounding = 0 })
ESPVisuals:AddLabel("ESP Color"):AddColorPicker("ESPColor", { Default = Color3.fromRGB(255, 100, 100), Title = "ESP Color" })
ESPVisuals:AddToggle("RainbowESP", { Text = "Rainbow", Default = false })

ESPItems:AddToggle("ItemESPEnabled", { Text = "Enable Item ESP", Default = false, Tooltip = "Track Workspace.Items pickups." })
ESPItems:AddToggle("ItemMedkits", { Text = "Medkits", Default = true })
ESPItems:AddToggle("ItemArmor", { Text = "Armor", Default = true })
ESPItems:AddToggle("ItemGrenades", { Text = "Grenades", Default = true })
ESPItems:AddToggle("ItemFlashes", { Text = "Flashes", Default = true })
ESPItems:AddToggle("ItemSticks", { Text = "Sticks", Default = true })
ESPItems:AddToggle("ItemPeels", { Text = "Peels", Default = true })
ESPItems:AddSlider("ItemMaxDist", { Text = "Item Max Dist", Default = 1000, Min = 100, Max = 5000, Rounding = 0 })
ESPItems:AddLabel("Item Color"):AddColorPicker("ItemColor", { Default = Color3.fromRGB(100, 255, 100), Title = "Item ESP" })

--// MS ESP lib
local ESPLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/mstudio45/MSESP/refs/heads/main/source.luau"))()
ESPLib.GlobalConfig.Billboards = true
ESPLib.GlobalConfig.Distance = true

local ESPInstances = {}
local ESPSetupDone = {}

local function GetESPColor()
    return Options.ESPColor and Options.ESPColor.Value or Color3.fromRGB(255, 100, 100)
end

local function BuildESPSettings(player, character)
    local c = GetESPColor()
    local tracerFrom = OVal("TracerFrom", "Bottom")
    return {
        Name = player.Name,
        Model = character,
        Color = c,
        MaxDistance = OVal("ESPMaxDist", 1000),
        TextSize = OVal("ESPTextSize", 16),
        ESPType = "Highlight",
        FillColor = c,
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0,
        Tracer = { Enabled = TVal("UseTracer", true), Color = c, From = tracerFrom },
        Arrow = { Enabled = TVal("UseArrow", false), Color = c },
        Box2D = { Enabled = TVal("UseBox2D", true), Color = c, Thickness = 2, Filled = false },
        Box3D = { Enabled = TVal("UseBox3D", false), Color = c, Thickness = 1.5 },
        Skeleton = { Enabled = TVal("UseSkeleton", false), Color = Color3.fromRGB(255, 255, 255), Thickness = 1 },
        BeforeUpdate = function(self)
            if TVal("ShowHealth", true) then
                local h = character:FindFirstChildOfClass("Humanoid")
                if h then
                    local hp = math.clamp(math.floor(h.Health), 0, 9999)
                    local pct = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
                    self.CurrentSettings.Name = player.Name .. " [" .. hp .. "HP]"
                    local col = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 20)
                    self.CurrentSettings.FillColor = col
                    self.CurrentSettings.Color = col
                end
            else
                if self.CurrentSettings.Name ~= player.Name then
                    self.CurrentSettings.Name = player.Name
                end
                local base = GetESPColor()
                self.CurrentSettings.FillColor = base
                self.CurrentSettings.Color = base
            end
        end,
    }
end

local function ClearPlayerESP(player)
    local inst = ESPInstances[player]
    if inst then
        pcall(function() inst:Destroy() end)
        ESPInstances[player] = nil
    end
end

local function SetupPlayerESP(player)
    if player == LocalPlayer then
        return
    end
    if not ESPSetupDone[player] then
        ESPSetupDone[player] = true
        player.CharacterAdded:Connect(function(character)
            -- Reuse OnChar path via fresh setup call
            ClearPlayerESP(player)
            if not TVal("ESPEnabled", false) then
                return
            end
            local hrp = character:WaitForChild("HumanoidRootPart", 10)
            if not hrp then
                return
            end
            local ok, inst = pcall(function()
                return ESPLib:Add(BuildESPSettings(player, character))
            end)
            if ok and inst then
                ESPInstances[player] = inst
            end
        end)
        player.CharacterRemoving:Connect(function()
            ClearPlayerESP(player)
        end)
    end
    local function OnChar(character)
        ClearPlayerESP(player)
        if not Toggles.ESPEnabled.Value then
            return
        end
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then
            return
        end
        local ok, inst = pcall(function()
            return ESPLib:Add(BuildESPSettings(player, character))
        end)
        if ok and inst then
            ESPInstances[player] = inst
        end
    end
    if player.Character then
        task.spawn(OnChar, player.Character)
    end
end

local function RefreshAllESP()
    for player, inst in pairs(ESPInstances) do
        if inst and not inst.Deleted then
            local c = GetESPColor()
            pcall(function()
                inst.CurrentSettings.MaxDistance = OVal("ESPMaxDist", 1000)
                inst.CurrentSettings.TextSize = OVal("ESPTextSize", 16)
                inst:SetEveryColor(c, true)
                inst.CurrentSettings.Skeleton.Color = Color3.fromRGB(255, 255, 255)
                inst.CurrentSettings.Tracer.Enabled = TVal("UseTracer", true)
                inst.CurrentSettings.Tracer.From = OVal("TracerFrom", "Bottom")
                inst.CurrentSettings.Arrow.Enabled = TVal("UseArrow", false)
                inst.CurrentSettings.Box2D.Enabled = TVal("UseBox2D", true)
                inst.CurrentSettings.Box3D.Enabled = TVal("UseBox3D", false)
                inst.CurrentSettings.Skeleton.Enabled = TVal("UseSkeleton", false)
            end)
        end
    end
    ESPLib.GlobalConfig.Billboards = TVal("ShowNames", true)
    ESPLib.GlobalConfig.Distance = TVal("ShowDistance", true)
    ESPLib.GlobalConfig.Rainbow = TVal("RainbowESP", false)
end

local function SetESPEnabled(state)
    if state then
        for _, p in ipairs(Players:GetPlayers()) do
            SetupPlayerESP(p)
        end
    else
        for p, _ in pairs(ESPInstances) do
            ClearPlayerESP(p)
        end
    end
end

--// Item ESP (Workspace.Items pickups)
local ItemESPInstances = {}

local function GetItemCategory(item)
    local cur = item
    while cur and cur.Parent do
        local parent = cur.Parent
        if parent == Workspace:FindFirstChild("Items") then
            return cur.Name
        end
        cur = parent
    end
    return "Item"
end

local function ShouldShowItemCategory(category)
    if category == "Medkits" then
        return TVal("ItemMedkits", true)
    elseif category == "Armor" then
        return TVal("ItemArmor", true)
    elseif category == "Grenades" then
        return TVal("ItemGrenades", true)
    elseif category == "Flashes" then
        return TVal("ItemFlashes", true)
    elseif category == "Sticks" then
        return TVal("ItemSticks", true)
    elseif category == "Peels" then
        return TVal("ItemPeels", true)
    end
    return true
end

local function GetItemColor()
    return Options.ItemColor and Options.ItemColor.Value or Color3.fromRGB(100, 255, 100)
end

local function SetupItemESP(item)
    if not TVal("ItemESPEnabled", false) then
        return
    end
    if not (item:IsA("BasePart") or item:IsA("Model")) then
        return
    end
    if ItemESPInstances[item] and not ItemESPInstances[item].Deleted then
        return
    end
    local category = GetItemCategory(item)
    if not ShouldShowItemCategory(category) then
        return
    end
    local c = GetItemColor()
    local ok, inst = pcall(function()
        return ESPLib:Add({
            Name = category .. ": " .. item.Name,
            Model = item,
            Color = c,
            MaxDistance = OVal("ItemMaxDist", 1000),
            TextSize = OVal("ESPTextSize", 16),
            ESPType = "Highlight",
            FillColor = c,
            OutlineColor = c,
            FillTransparency = 0.6,
            OutlineTransparency = 0,
            Box2D = { Enabled = true, Color = c, Thickness = 1, Filled = false },
        })
    end)
    if ok and inst then
        ItemESPInstances[item] = inst
    end
end

local function ClearItemESP(item)
    local inst = ItemESPInstances[item]
    if inst then
        pcall(function() inst:Destroy() end)
        ItemESPInstances[item] = nil
    end
end

local function ClearAllItemESP()
    for item, _ in pairs(ItemESPInstances) do
        ClearItemESP(item)
    end
end

local function ScanItemESP()
    ClearAllItemESP()
    if not TVal("ItemESPEnabled", false) then
        return
    end
    local folder = Workspace:FindFirstChild("Items")
    if not folder then
        return
    end
    for _, desc in ipairs(folder:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Model") then
            -- Skip bare spawn parts without prompts? Still show real pickups only:
            -- real pickups have ProximityPrompt or are MeshPart/Model, spawn Parts are empty.
            SetupItemESP(desc)
        end
    end
end

local function RefreshItemESPColors()
    local c = GetItemColor()
    for _, inst in pairs(ItemESPInstances) do
        if inst and not inst.Deleted then
            pcall(function()
                inst.CurrentSettings.MaxDistance = OVal("ItemMaxDist", 1000)
                inst:SetEveryColor(c, true)
            end)
        end
    end
end

Players.PlayerAdded:Connect(SetupPlayerESP)
Players.PlayerRemoving:Connect(function(player)
    ClearPlayerESP(player)
    ESPSetupDone[player] = nil
end)

-- Track item spawns/despawns live.
task.spawn(function()
    local folder = Workspace:WaitForChild("Items", 20)
    if not folder then
        return
    end
    folder.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") or desc:IsA("Model") then
            task.delay(0.25, function()
                SetupItemESP(desc)
            end)
        end
    end)
    folder.DescendantRemoving:Connect(function(desc)
        ClearItemESP(desc)
    end)
end)

--// Silent aim core (no team checks)
local GunConfigCache = nil
pcall(function()
    GunConfigCache = require(ReplicatedStorage.Shared.Modules.Configs.GunConfig)
end)

local function GetCurrentGunRange()
    local char = LocalPlayer.Character
    if char and GunConfigCache then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and GunConfigCache[tool.Name] and GunConfigCache[tool.Name].Range then
            return GunConfigCache[tool.Name].Range
        end
    end
    return 1000
end

--// Gun Mods: mutate shared client GunConfig (restored on toggle-off).
local GunOrig = {}
local function ApplyGunMods()
    if not GunConfigCache then
        return
    end
    for name, cfg in pairs(GunConfigCache) do
        if type(cfg) == "table" then
            if not GunOrig[name] then
                GunOrig[name] = { FireRate = cfg.FireRate, Auto = cfg.Auto, RecoilForce = cfg.RecoilForce }
            end
            local o = GunOrig[name]
            cfg.FireRate = TVal("RapidFire", false) and 0 or o.FireRate
            cfg.Auto = TVal("FullAuto", false) and true or o.Auto
            if TVal("NoRecoil", false) or TVal("NoSpread", false) then
                cfg.RecoilForce = Vector3.new()
            else
                cfg.RecoilForce = o.RecoilForce
            end
        end
    end
end

-- Infinite ammo: top up <Gun>_Ammo attributes (the exact check _Shoot uses).
task.spawn(function()
    while true do
        task.wait(0.2)
        pcall(function()
            if TVal("InfAmmo", false) and GunConfigCache then
                local char = LocalPlayer.Character
                if char then
                    for name, cfg in pairs(GunConfigCache) do
                        if type(cfg) == "table" and cfg.ClipSize then
                            char:SetAttribute(name .. "_Ammo", cfg.ClipSize)
                        end
                    end
                end
            end
        end)
        if Library.Unloaded then
            break
        end
    end
end)

-- No Spread: unbind the recoil camera shake (game rebinds on equip).
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if TVal("NoSpread", false) then
                RunService:UnbindFromRenderStep("CameraEffect")
            end
        end)
        if Library.Unloaded then
            break
        end
    end
end)

-- Remove KillBounds: strip TouchTransmitters + touch under KillBoundaries folders.
local BoundsHook = nil
local function StripBounds(root)
    local n = 0
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            local p = d.Parent
            if p and (p.Name == "KillBoundaries" or p.Name == "KillBoundary") then
                if d:IsA("BasePart") then
                    d.CanTouch = false
                    d.CanCollide = false
                end
                local tt = d:FindFirstChildOfClass("TouchTransmitter")
                if tt then
                    pcall(function() tt:Destroy() end)
                    n += 1
                end
                if d.ClassName == "TouchTransmitter" then
                    pcall(function() d:Destroy() end)
                    n += 1
                end
            end
        end
    end)
    return n
end
local function SetBoundsRemoved(on)
    if on then
        local n = StripBounds(Workspace)
        if BoundsHook == nil then
            BoundsHook = Workspace.DescendantAdded:Connect(function(d)
                if not TVal("RemoveBounds", false) then
                    return
                end
                local p = d.Parent
                if p and (p.Name == "KillBoundaries" or p.Name == "KillBoundary") then
                    task.delay(0.5, function()
                        StripBounds(Workspace)
                    end)
                end
            end)
        end
        Library:Notify({ Title = "KillBounds", Description = "Stripped " .. n .. " kill touches. Rejoin restores.", Time = 4 })
    else
        if BoundsHook then
            pcall(function() BoundsHook:Disconnect() end)
            BoundsHook = nil
        end
    end
end

local function ResolvePart(character, mode)
    if not character then
        return nil
    end
    if mode == "Head" then
        return character:FindFirstChild("Head")
    elseif mode == "HumanoidRootPart" then
        return character:FindFirstChild("HumanoidRootPart")
    elseif mode == "Torso" then
        return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    elseif mode == "Closest" then
        local cam = Workspace.CurrentCamera
        if not cam then
            return character:FindFirstChild("Head")
        end
        local mouse = UserInputService:GetMouseLocation()
        local best, bestDist = nil, math.huge
        for _, name in ipairs({ "Head", "HumanoidRootPart", "Torso", "UpperTorso" }) do
            local part = character:FindFirstChild(name)
            if part then
                local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = part
                    end
                end
            end
        end
        return best
    end
    return character:FindFirstChild("Head")
end

local AimParams = RaycastParams.new()
AimParams.FilterType = Enum.RaycastFilterType.Exclude
AimParams.IgnoreWater = true

local function IsBlocked(origin, targetPos, targetChar)
    local liveCam = Workspace.CurrentCamera
    local filter = { LocalPlayer.Character }
    if liveCam then
        table.insert(filter, liveCam)
    end
    AimParams.FilterDescendantsInstances = filter
    local dir = targetPos - origin
    local dist = dir.Magnitude
    if dist < 0.001 then
        return false
    end
    local result = Workspace:Raycast(origin, dir, AimParams)
    if not result then
        return false
    end
    if targetChar and result.Instance:IsDescendantOf(targetChar) then
        return false
    end
    -- Forgive hits very close to the target point (edge of hitbox).
    if (result.Position - targetPos).Magnitude <= 3 then
        return false
    end
    return true
end

local function GetPredictedPos(character, part)
    if not TVal("EnablePrediction", false) then
        return part.Position
    end
    local amount = OVal("PredictionAmount", 0)
    if not amount or amount <= 0 then
        return part.Position
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local vel = nil
    if hrp then
        pcall(function()
            vel = hrp.AssemblyLinearVelocity
        end)
        if (not vel or vel.Magnitude < 0.01) and hrp.Velocity then
            vel = hrp.Velocity
        end
    end
    if not vel or vel.Magnitude < 0.5 then
        return part.Position
    end
    -- Lead the target; damp vertical so jumping doesn't overshoot the hitbox.
    local flat = Vector3.new(vel.X, vel.Y * 0.5, vel.Z)
    return part.Position + flat * amount
end

local CurrentTarget = nil

local function GetClosestTarget()
    -- Intentionally no team checks: all non-local alive players are valid.
    if not TVal("SilentEnabled", false) then
        return nil
    end
    local cam = Workspace.CurrentCamera
    if not cam then
        return nil
    end
    local mode = OVal("TargetMode", "Mouse")
    local center
    if mode == "Center" then
        local vs = cam.ViewportSize
        center = Vector2.new(vs.X / 2, vs.Y / 2)
    else
        center = UserInputService:GetMouseLocation()
    end
    local useFOV = TVal("UseFOV", true)
    local fov = OVal("FOVRadius", 300)
    local maxDist = OVal("SilentMaxDist", 600)
    local partMode = OVal("TargetPart", "Head")
    local origin = cam.CFrame.Position
    local wallCheck = TVal("WallCheck", true)

    local best, bestPart, bestAim, bestDist = nil, nil, nil, (useFOV and fov or math.huge)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = ResolvePart(char, partMode)
                if part then
                    local aimPos = GetPredictedPos(char, part)
                    if (origin - aimPos).Magnitude <= maxDist then
                        local sp, onScreen = cam:WorldToViewportPoint(aimPos)
                        if onScreen then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if not useFOV or d <= bestDist then
                                if useFOV then
                                    if d <= bestDist and (not wallCheck or not IsBlocked(origin, aimPos, char)) then
                                        best = player
                                        bestPart = part
                                        bestAim = aimPos
                                        bestDist = d
                                    end
                                else
                                    -- No FOV limit: pick closest to center/mouse regardless of radius.
                                    if d < bestDist and (not wallCheck or not IsBlocked(origin, aimPos, char)) then
                                        best = player
                                        bestPart = part
                                        bestAim = aimPos
                                        bestDist = d
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if best and bestPart then
        return { Player = best, Character = best.Character, Part = bestPart, AimPos = bestAim or bestPart.Position }
    end
    return nil
end

-- FOV circle
local FOVCircle = nil
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 64
    FOVCircle.Filled = false
end)

-- Target indicator drawings (who silent is currently aiming at).
local TargetDot, TargetText = nil, nil
pcall(function()
    TargetDot = Drawing.new("Circle")
    TargetDot.Thickness = 2
    TargetDot.NumSides = 24
    TargetDot.Filled = false
    TargetDot.Radius = 12
    TargetDot.Visible = false
    TargetText = Drawing.new("Text")
    TargetText.Size = 14
    TargetText.Center = true
    TargetText.Outline = true
    TargetText.Visible = false
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
    if FOVCircle then
        -- Remove FOV option: when UseFOV is OFF, hide circle entirely.
        local show = TVal("ShowFOV", true) and TVal("UseFOV", true) and TVal("SilentEnabled", false)
        FOVCircle.Visible = show
        if show then
            local liveCam = Workspace.CurrentCamera
            if not liveCam then
                FOVCircle.Visible = false
            else
                local pos
                if OVal("TargetMode", "Mouse") == "Center" then
                    local vs = liveCam.ViewportSize
                    pos = Vector2.new(vs.X / 2, vs.Y / 2)
                else
                    pos = UserInputService:GetMouseLocation()
                end
                FOVCircle.Position = pos
                FOVCircle.Radius = OVal("FOVRadius", 300)
                FOVCircle.Color = OVal("FOVColor", Color3.fromRGB(255, 255, 255))
            end
        end
    end
    -- In-world target indicator: marker + name on whoever silent is aiming at.
    if TargetDot and TargetText then
        local showT = TVal("ShowTarget", true) and TVal("SilentEnabled", false) and CurrentTarget ~= nil
        if showT then
            local ok, sp, onScreen = pcall(function()
                local aim = GetPredictedPos(CurrentTarget.Character, CurrentTarget.Part)
                return Workspace.CurrentCamera:WorldToViewportPoint(aim)
            end)
            if ok and onScreen and CurrentTarget.Part and CurrentTarget.Part.Parent then
                local col = OVal("TargetColor", Color3.fromRGB(255, 50, 50))
                TargetDot.Visible = true
                TargetDot.Position = Vector2.new(sp.X, sp.Y)
                TargetDot.Color = col
                TargetText.Visible = true
                TargetText.Position = Vector2.new(sp.X, sp.Y - 22)
                TargetText.Color = col
                pcall(function()
                    TargetText.Text = "◉ " .. CurrentTarget.Player.Name
                end)
            else
                TargetDot.Visible = false
                TargetText.Visible = false
            end
        else
            TargetDot.Visible = false
            TargetText.Visible = false
        end
    end
    end)
end)

-- Status label: shows current target so you can tell silent is working without firing.
task.spawn(function()
    while true do
        task.wait(0.25)
        pcall(function()
            local label = Options.SilentStatus
            local function setStatus(t)
                if label then
                    pcall(function() label:SetText(t) end)
                end
            end
            if not TVal("SilentEnabled", false) then
                CurrentTarget = nil
                setStatus("Status: disabled")
            else
                local t = GetClosestTarget()
                CurrentTarget = t
                if t then
                    setStatus("Status: locked on " .. t.Player.Name)
                else
                    if not TVal("UseFOV", true) then
                        setStatus("Status: no target (check range/walls)")
                    else
                        setStatus("Status: no target in FOV (enlarge FOV or disable Use FOV)")
                    end
                end
            end
        end)
        if Library.Unloaded then
            break
        end
    end
end)

-- Packet hook: spoof GunService_S shoot packet only.
local HookedPacket = false
local ShotCount, RedirectCount = 0, 0
local function HookGunPacket()
    local ok, err = pcall(function()
        -- Require GunClass first so Packet("GunService_S") is already created with correct types.
        pcall(function()
            require(ReplicatedStorage.Client.Modules.Tools.GunClass)
        end)
        local PacketMod = require(ReplicatedStorage.Shared.Packages.Packet)
        -- Pass full type signature so we never poison the cache with an incomplete packet
        -- if GunClass has not created it yet. Cached packets ignore extra args.
        local GunPacket
        pcall(function()
            GunPacket = PacketMod("GunService_S", PacketMod.String, {
                PacketMod.String,
                PacketMod.String,
                PacketMod.CFrameF24U8,
                PacketMod.Vector3F24,
                { PacketMod.Instance },
            })
        end)
        if not GunPacket then
            -- Fallback: cached instance only (no creation).
            GunPacket = PacketMod("GunService_S")
        end
        if not GunPacket then
            error("GunService_S packet not found")
        end
        local OldFire = GunPacket.Fire
        if not OldFire then
            error("packet Fire missing")
        end
        if GunPacket.__SilentHooked then
            HookedPacket = true
            return
        end
        GunPacket.__SilentHooked = true
        GunPacket.Fire = function(self, eventName, data, ...)
            if eventName == "UpdateGunState" and type(data) == "table" and data[1] == "Shoot" then
                ShotCount += 1
                getgenv().HiddenWithinShots = ShotCount
                getgenv().HiddenWithinRedirects = RedirectCount
                -- Spoof block is fully guarded: any failure falls through to a normal shot.
                pcall(function()
                    if TVal("SilentEnabled", false) then
                        local target = GetClosestTarget()
                        if target and math.random(1, 100) <= OVal("HitChance", 100) then
                            local camPos = Workspace.CurrentCamera.CFrame.Position
                            local targetPos = target.AimPos or target.Part.Position
                            data[3] = CFrame.lookAt(camPos, targetPos)
                            data[4] = targetPos
                            data[5] = { target.Part }
                            RedirectCount += 1
                            getgenv().HiddenWithinRedirects = RedirectCount
                            getgenv().HiddenWithinLastTarget = target.Player.Name
                        end
                    end
                end)
            end
            return OldFire(self, eventName, data, ...)
        end
        if GunPacket.Fire == OldFire then
            error("Fire assignment did not stick")
        end
        HookedPacket = true
    end)
    if HookedPacket then
        Library:Notify({ Title = "Silent Aim", Description = "Hooked GunService_S shoot packet.", Time = 4 })
    else
        Library:Notify({ Title = "Silent Aim", Description = "Hook failed: " .. tostring(err), Time = 6 })
        warn("[HiddenWithin] gun packet hook failed:", err)
    end
end
task.spawn(function()
    -- Wait for game network objects before hooking.
    local t0 = os.clock()
    while os.clock() - t0 < 20 do
        local ok = pcall(function()
            ReplicatedStorage.Shared.Packages.Packet:WaitForChild("RemoteEvent", 2)
            ReplicatedStorage.Shared.Modules.Configs:WaitForChild("GunConfig", 2)
        end)
        if ok then
            break
        end
        task.wait(1)
    end
    HookGunPacket()
end)

--// UI callbacks (guarded: a missing key must never kill the rest of setup)
local function OnToggle(id, fn)
    local t = Toggles[id]
    if t then
        t:OnChanged(fn)
    else
        warn("[HiddenWithin] missing toggle: " .. id)
    end
end
local function OnOption(id, fn)
    local o = Options[id]
    if o then
        o:OnChanged(fn)
    else
        warn("[HiddenWithin] missing option: " .. id)
    end
end

OnToggle("ESPEnabled", function()
    SetESPEnabled(TVal("ESPEnabled", false))
end)
OnToggle("UseBox2D", RefreshAllESP)
OnToggle("UseBox3D", RefreshAllESP)
OnToggle("UseTracer", RefreshAllESP)
OnToggle("UseArrow", RefreshAllESP)
OnToggle("UseSkeleton", RefreshAllESP)
OnToggle("ShowNames", RefreshAllESP)
OnToggle("ShowDistance", RefreshAllESP)
OnToggle("ShowHealth", RefreshAllESP)
OnToggle("RainbowESP", RefreshAllESP)
OnOption("TracerFrom", RefreshAllESP)
OnOption("ESPMaxDist", RefreshAllESP)
OnOption("ESPTextSize", RefreshAllESP)
OnOption("ESPColor", RefreshAllESP)

OnToggle("ItemESPEnabled", function()
    ScanItemESP()
end)
OnToggle("ItemMedkits", ScanItemESP)
OnToggle("ItemArmor", ScanItemESP)
OnToggle("ItemGrenades", ScanItemESP)
OnToggle("ItemFlashes", ScanItemESP)
OnToggle("ItemSticks", ScanItemESP)
OnToggle("ItemPeels", ScanItemESP)
OnOption("ItemMaxDist", RefreshItemESPColors)
OnOption("ItemColor", RefreshItemESPColors)
OnOption("ESPTextSize", RefreshItemESPColors)

OnToggle("InfAmmo", function() end)
OnToggle("FullAuto", ApplyGunMods)
OnToggle("RapidFire", ApplyGunMods)
OnToggle("NoRecoil", ApplyGunMods)
OnToggle("NoSpread", ApplyGunMods)
OnToggle("RemoveBounds", function()
    SetBoundsRemoved(TVal("RemoveBounds", false))
end)

-- Startup self-check: surface any missing UI keys immediately.
task.spawn(function()
    task.wait(1)
    local missing = {}
    for _, id in ipairs({ "SilentEnabled", "UseFOV", "WallCheck", "ShowFOV", "ShowTarget", "TargetPart", "TargetMode", "FOVRadius", "HitChance", "SilentMaxDist", "EnablePrediction", "PredictionAmount", "ESPEnabled", "ShowHealth", "ItemESPEnabled", "InfAmmo", "FullAuto", "RapidFire", "NoRecoil", "NoSpread", "RemoveBounds" }) do
        if Toggles[id] == nil then
            table.insert(missing, id)
        end
    end
    for _, id in ipairs({ "FOVColor", "TargetColor", "TracerFrom", "ESPMaxDist", "ESPTextSize", "ESPColor", "ItemMaxDist", "ItemColor", "SilentStatus" }) do
        if Options[id] == nil then
            table.insert(missing, id)
        end
    end
    if #missing > 0 then
        warn("[HiddenWithin] missing UI keys: " .. table.concat(missing, ", "))
        Library:Notify({ Title = "UI Warning", Description = "Missing keys: " .. table.concat(missing, ", "), Time = 8 })
    end
end)

--// UI Settings tab
local MenuGroup = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })
MenuGroup:AddToggle("KeybindMenuOpen", { Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) Library.KeybindFrame.Visible = v end })
MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Default = Library.ShowCustomCursor, Callback = function(v) Library.ShowCustomCursor = v end })
MenuGroup:AddDropdown("NotificationSide", { Values = { "Left", "Right" }, Default = "Right", Text = "Notification Side", Callback = function(v) Library:SetNotifySide(v) end })
MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(v)
        v = v:gsub("%%", "")
        Library:SetDPIScale(tonumber(v))
    end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("HiddenWithinHub")
SaveManager:SetFolder("HiddenWithinHub/guns")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Library:Notify({ Title = "Hidden Within", Description = "Silent Aim + ESP loaded. Enable from Combat / ESP tabs.", Time = 5 })
