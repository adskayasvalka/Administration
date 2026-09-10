-- =========================================================
--  keysystem.lua — Проверка ключа + ранги
-- =========================================================

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- >>> ЗАМЕНИ НА СВОЙ URL К keys.json <<<
local KEYS_URL = "https://raw.githubusercontent.com/adskayasvalka/Administration/main/keys.json"

local RANKS = {
    ["User"]                 = 0,
    ["Moderator"]            = 1,
    ["Senior Moderator"]     = 2,
    ["Junior Administrator"] = 3,
    ["Administrator"]        = 4,
    ["Senior Administrator"] = 5,
    ["Head Administrator"]   = 6,
}

local CAN_CREATE = {
    ["Head Administrator"]   = { "User","Moderator","Senior Moderator","Junior Administrator","Administrator","Senior Administrator","Head Administrator" },
    ["Senior Administrator"] = { "User","Moderator","Senior Moderator","Junior Administrator","Administrator" },
    ["Administrator"]        = { "User","Moderator","Senior Moderator" },
    ["Junior Administrator"] = { "User","Moderator" },
}

local function fetchKeys()
    local ok, body = pcall(game.HttpGet, game, KEYS_URL, true)
    if not ok or not body then return {} end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 or type(data) ~= "table" then return {} end
    return data
end

local Keys = fetchKeys()

local function rankLevel(r) return RANKS[r] or -1 end
local function hasRankAtLeast(r, need) return rankLevel(r) >= rankLevel(need) end

-- --- UI ввода ключа ---
local function prompt()
    local gui = Instance.new("ScreenGui")
    gui.Name = "IY_KeySystem"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 380, 0, 200)
    f.Position = UDim2.new(0.5, -190, 0.5, -100)
    f.BackgroundColor3 = Color3.fromRGB(25,25,30); f.BorderSizePixel = 0; f.Parent = gui
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,0,40); t.BackgroundTransparency = 1
    t.Text = "🔐 Infinite Yield — Вход"
    t.TextColor3 = Color3.fromRGB(240,240,240)
    t.Font = Enum.Font.GothamBold; t.TextSize = 20; t.Parent = f

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.85,0,0,40); box.Position = UDim2.new(0.075,0,0,55)
    box.BackgroundColor3 = Color3.fromRGB(40,40,45); box.TextColor3 = Color3.fromRGB(240,240,240)
    box.PlaceholderText = "Введите ключ..."; box.Font = Enum.Font.Gotham
    box.TextSize = 16; box.ClearTextOnFocus = false; box.Parent = f
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85,0,0,40); btn.Position = UDim2.new(0.075,0,0,110)
    btn.BackgroundColor3 = Color3.fromRGB(80,130,220); btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 16; btn.Text = "Войти"; btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1,0,0,25); st.Position = UDim2.new(0,0,0,160)
    st.BackgroundTransparency = 1; st.Text = ""
    st.TextColor3 = Color3.fromRGB(230,80,80); st.Font = Enum.Font.Gotham
    st.TextSize = 14; st.Parent = f

    local result = nil
    btn.MouseButton1Click:Connect(function()
        local e = Keys[box.Text]
        if e and e.active then
            result = { key = box.Text, rank = e.rank, owner = e.owner }
            st.TextColor3 = Color3.fromRGB(80,220,120)
            st.Text = "Успешно! Ранг: " .. e.rank
            task.wait(0.4); gui:Destroy()
        else
            st.Text = "Неверный или отозванный ключ"; box.Text = ""
        end
    end)
    while result == nil do task.wait(0.1) end
    return result
end

local session = prompt()

getgenv().IY_RANK  = session.rank
getgenv().IY_KEY   = session.key
getgenv().IY_OWNER = session.owner
getgenv().IY_RANKS = RANKS

getgenv().IY_hasPerm = function(need) return hasRankAtLeast(getgenv().IY_RANK, need) end

getgenv().IY_createKey = function(rank)
    local allowed = CAN_CREATE[getgenv().IY_RANK]
    if not allowed or not table.find(allowed, rank) then return nil, "Нет прав" end
    if not RANKS[rank] then return nil, "Неизвестный ранг" end
    local prefix = string.upper(string.sub(string.gsub(rank,"%s+",""),1,3))
    local newKey = prefix .. "-" .. HttpService:GenerateGUID(false):gsub("-",""):sub(1,12)
    Keys[newKey] = { rank = rank, owner = getgenv().IY_OWNER, active = true }
    return newKey
end

getgenv().IY_revokeKey = function(key)
    if not hasRankAtLeast(getgenv().IY_RANK, "Head Administrator") then return false, "Только Head Administrator" end
    if Keys[key] then Keys[key].active = false; return true end
    return false, "Ключ не найден"
end

getgenv().IY_rotateKey = function(old)
    if not Keys[old] then return nil, "Ключ не найден" end
    if not hasRankAtLeast(getgenv().IY_RANK, "Head Administrator") then return nil, "Только Head Administrator" end
    Keys[old].active = false
    local prefix = string.upper(string.sub(string.gsub(Keys[old].rank,"%s+",""),1,3))
    local newKey = prefix .. "-" .. HttpService:GenerateGUID(false):gsub("-",""):sub(1,12)
    Keys[newKey] = { rank = Keys[old].rank, owner = Keys[old].owner, active = true }
    return newKey
end

getgenv().IY_registerKeyCommands = function(IY)
    if not IY or not IY.Commands then return end
    IY.Commands["createkey"] = { ListArgs={{Type="string",Name="rank"}}, Function=function(a)
        local k,e = getgenv().IY_createKey(a[1]); return k and ("Ключ: "..k) or ("Ошибка: "..tostring(e)) end }
    IY.Commands["revokekey"] = { ListArgs={{Type="string",Name="key"}}, Function=function(a)
        local ok,e = getgenv().IY_revokeKey(a[1]); return ok and "Отозван" or ("Ошибка: "..tostring(e)) end }
    IY.Commands["rotatekey"] = { ListArgs={{Type="string",Name="key"}}, Function=function(a)
        local k,e = getgenv().IY_rotateKey(a[1]); return k and ("Новый: "..k) or ("Ошибка: "..tostring(e)) end }
    IY.Commands["myrank"] = { Function=function() return "Ранг: "..tostring(getgenv().IY_RANK) end }
end

return true
