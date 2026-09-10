-- =========================================================
--  keysystem.lua — Проверка ключа + система рангов
--  Ранги: User, Moderator, Senior Moderator,
--         Junior Administrator, Administrator,
--         Senior Administrator, Head Administrator
-- =========================================================

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local KEYFILE = "iy_keys.json"

-- ---------- Ранги ----------
local RANKS = {
    ["User"]                = 0,
    ["Moderator"]           = 1,
    ["Senior Moderator"]    = 2,
    ["Junior Administrator"]= 3,
    ["Administrator"]       = 4,
    ["Senior Administrator"]= 5,
    ["Head Administrator"]  = 6,
}

-- Кто какие ключи может создавать
local CAN_CREATE = {
    ["Head Administrator"]  = {
        "User","Moderator","Senior Moderator",
        "Junior Administrator","Administrator",
        "Senior Administrator","Head Administrator"
    },
    ["Senior Administrator"] = {
        "User","Moderator","Senior Moderator",
        "Junior Administrator","Administrator"
    },
    ["Administrator"]        = {
        "User","Moderator","Senior Moderator"
    },
    ["Junior Administrator"] = {
        "User","Moderator"
    },
}

-- ---------- Хранилище ----------
local Keys = {}

local function fileExists(n) return isfile and isfile(n) end

local function saveKeys()
    if writefile then
        pcall(function()
            writefile(KEYFILE, HttpService:JSONEncode(Keys))
        end)
    end
end

local function loadKeys()
    if fileExists and fileExists(KEYFILE) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(KEYFILE))
        end)
        if ok and type(data) == "table" then
            Keys = data
            return
        end
    end
    -- Первый запуск — мастер-ключ
    Keys = {
        ["HEAD-MASTER-KEY-0001"] = {
            rank = "Head Administrator",
            owner = "System",
            created = os.time(),
            active = true,
        }
    }
    saveKeys()
end

loadKeys()

-- ---------- Утилиты ----------
local function generateKey(rank)
    -- префикс из первых 3 букв без пробелов, в верхнем регистре
    local clean = string.gsub(rank, "%s+", "")
    local prefix = string.upper(string.sub(clean, 1, 3))
    local rand = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 12)
    return prefix .. "-" .. rand
end

local function rankLevel(r) return RANKS[r] or -1 end
local function hasRankAtLeast(r, need) return rankLevel(r) >= rankLevel(need) end

-- ---------- UI ввода ключа ----------
local function showKeyPrompt()
    local gui = Instance.new("ScreenGui")
    gui.Name = "IY_KeySystem"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 380, 0, 220)
    frame.Position = UDim2.new(0.5, -190, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0, 10); c1.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "🔐 Infinite Yield — Вход"
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.85, 0, 0, 40)
    box.Position = UDim2.new(0.075, 0, 0, 55)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    box.TextColor3 = Color3.fromRGB(240, 240, 240)
    box.PlaceholderText = "Введите ключ..."
    box.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    box.Font = Enum.Font.Gotham
    box.TextSize = 16
    box.Text = ""
    box.ClearTextOnFocus = false
    box.Parent = frame

    local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0, 6); c2.Parent = box

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85, 0, 0, 40)
    btn.Position = UDim2.new(0.075, 0, 0, 110)
    btn.BackgroundColor3 = Color3.fromRGB(80, 130, 220)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.Text = "Войти"
    btn.Parent = frame

    local c3 = Instance.new("UICorner"); c3.CornerRadius = UDim.new(0, 6); c3.Parent = btn

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 25)
    status.Position = UDim2.new(0, 0, 0, 160)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(230, 80, 80)
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.Parent = frame

    local result = nil

    btn.MouseButton1Click:Connect(function()
        local entry = Keys[box.Text]
        if entry and entry.active then
            result = { key = box.Text, rank = entry.rank, owner = entry.owner }
            status.TextColor3 = Color3.fromRGB(80, 220, 120)
            status.Text = "Успешно! Ранг: " .. entry.rank
            task.wait(0.4)
            gui:Destroy()
        else
            status.Text = "Неверный или отозванный ключ"
            box.Text = ""
        end
    end)

    while result == nil do task.wait(0.1) end
    return result
end

-- ---------- Проверка ----------
local session = showKeyPrompt()

-- Публикуем для IY и других модулей
getgenv().IY_RANK  = session.rank
getgenv().IY_KEY   = session.key
getgenv().IY_OWNER = session.owner
getgenv().IY_RANKS = RANKS

getgenv().IY_hasPerm = function(needed)
    return hasRankAtLeast(getgenv().IY_RANK, needed)
end

-- ---------- API управления ключами ----------
getgenv().IY_createKey = function(rank)
    local myRank = getgenv().IY_RANK
    local allowed = CAN_CREATE[myRank]
    if not allowed or not table.find(allowed, rank) then
        return nil, "Недостаточно прав для создания ключа ранга " .. tostring(rank)
    end
    if not RANKS[rank] then return nil, "Неизвестный ранг" end

    local newKey = generateKey(rank)
    Keys[newKey] = {
        rank = rank,
        owner = getgenv().IY_OWNER,
        created = os.time(),
        active = true,
    }
    saveKeys()
    return newKey
end

getgenv().IY_revokeKey = function(key)
    if not hasRankAtLeast(getgenv().IY_RANK, "Head Administrator") then
        return false, "Только Head Administrator может отзывать ключи"
    end
    if Keys[key] then
        Keys[key].active = false
        saveKeys()
        return true
    end
    return false, "Ключ не найден"
end

-- Смена ключа: старый деактивируется, генерируется новый того же ранга
getgenv().IY_rotateKey = function(oldKey)
    local entry = Keys[oldKey]
    if not entry then return nil, "Ключ не найден" end
    if not hasRankAtLeast(getgenv().IY_RANK, "Head Administrator") then
        return nil, "Только Head Administrator"
    end

    entry.active = false  -- старый ключ больше не работает

    local newKey = generateKey(entry.rank)
    Keys[newKey] = {
        rank = entry.rank,
        owner = entry.owner,
        created = os.time(),
        active = true,
    }
    saveKeys()
    return newKey
end

getgenv().IY_listKeys = function()
    if not hasRankAtLeast(getgenv().IY_RANK, "Head Administrator") then
        return nil, "Только Head Administrator"
    end
    return Keys
end

-- ---------- Команды для IY ----------
getgenv().IY_registerKeyCommands = function(IY)
    if not IY or not IY.Commands then
        warn("[IY] Не нашёл таблицу команд — пропускаю регистрацию")
        return
    end

    IY.Commands["createkey"] = {
        ListArgs = {{ Type = "string", Name = "rank" }},
        Function = function(args)
            local k, err = getgenv().IY_createKey(args[1])
            return k and ("Ключ создан: " .. k) or ("Ошибка: " .. tostring(err))
        end,
    }

    IY.Commands["revokekey"] = {
        ListArgs = {{ Type = "string", Name = "key" }},
        Function = function(args)
            local ok, err = getgenv().IY_revokeKey(args[1])
            return ok and "Ключ отозван" or ("Ошибка: " .. tostring(err))
        end,
    }

    IY.Commands["rotatekey"] = {
        ListArgs = {{ Type = "string", Name = "key" }},
        Function = function(args)
            local k, err = getgenv().IY_rotateKey(args[1])
            return k and ("Новый ключ: " .. k) or ("Ошибка: " .. tostring(err))
        end,
    }

    IY.Commands["myrank"] = {
        Function = function()
            return "Ваш ранг: " .. tostring(getgenv().IY_RANK)
        end,
    }

    IY.Commands["listkeys"] = {
        Function = function()
            local list, err = getgenv().IY_listKeys()
            if not list then return err end
            local out = {}
            for k, v in pairs(list) do
                table.insert(out, string.format("%s | %s | active=%s", k, v.rank, tostring(v.active)))
            end
            return table.concat(out, "\n")
        end,
    }
end

-- Возвращаем true — main.lua поймёт, что можно грузить IY
return true
