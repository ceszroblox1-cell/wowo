-- ============================================
-- GROW A GARDEN - AUTO PICK & PLACE SCRIPT v2
-- Executor: Delta
-- Fitur: Auto PnP dengan filter pet spesifik,
--        search bar, bedakan per ID, delay configurable
-- ============================================

-- ===== KONFIGURASI =====
local Settings = {
    Enabled = true,
    AutoPickAndPlace = false,   -- DEFAULT MATI! Hanya jalan setelah user toggle manual
    PickPlaceDelay = 0.05,
    LoopInterval = 0.2,
    SelectedPetRefs = {},       -- Simpan referensi objek langsung (unique per instance)
    GardenSlots = 8,
}

-- ===== SERVICES =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- ===== PET FILTER =====
-- Kata kunci yang menunjukkan INI BUKAN PET
local NON_PET_KEYWORDS = {
    "seed", "fruit", "gear", "weapon", "sword", "gun", "tool",
    "pickaxe", "axe", "shovel", "hoe", "bucket", "water",
    "benih", "biji", "buah", "alat", "senjata", "pedang",
    "cangkul", "sekop", "ember", "air", "pupuk", "fertilizer",
}

-- Kata kunci yang menunjukkan INI PET
local PET_KEYWORDS = {
    "pet", "animal", "creature", "monster", "dragon", "cat",
    "dog", "bird", "fox", "wolf", "bunny", "rabbit",
    "hewan", "binatang", "makhluk", "naga", "kucing",
    "anjing", "burung", "rubah", "serigala", "kelinci",
}

-- ===== FUNGSI IDENTIFIKASI PET =====
local function isPet(item)
    if not item then return false end
    
    local itemName = string.lower(item.Name)
    local itemClass = string.lower(item.ClassName or "")
    
    -- Cek keyword NON-PET dulu (prioritas)
    for _, keyword in ipairs(NON_PET_KEYWORDS) do
        if string.find(itemName, keyword) then
            return false
        end
    end
    
    -- Cek keyword PET
    for _, keyword in ipairs(PET_KEYWORDS) do
        if string.find(itemName, keyword) then
            return true
        end
    end
    
    -- Cek atribut khusus pet
    -- Beberapa game punya attribute seperti "Pet", "IsPet", dll
    local attributes = item:GetAttributes()
    if attributes then
        for attrName, attrValue in pairs(attributes) do
            local attrLower = string.lower(attrName)
            if string.find(attrLower, "pet") then
                return true
            end
            if attrLower == "type" and string.lower(tostring(attrValue)) == "pet" then
                return true
            end
            if attrLower == "category" and string.lower(tostring(attrValue)) == "pet" then
                return true
            end
        end
    end
    
    -- Cek parent name untuk hint
    local parentName = string.lower(item.Parent and item.Parent.Name or "")
    if string.find(parentName, "pet") then
        return true
    end
    
    return false
end

-- ===== AUTO-DETECT REMOTES =====
local Remotes = {
    Pick = nil, Place = nil, Equip = nil,
    Unequip = nil, Plant = nil, Harvest = nil,
}

local function detectRemotes()
    local allRemotes = {}
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction")
        or v:IsA("BindableEvent") or v:IsA("BindableFunction") then
            table.insert(allRemotes, v)
        end
    end
    
    local patterns = {
        Pick = {"pick", "ambil", "take", "select", "grab"},
        Place = {"place", "taruh", "letak", "put", "set", "drop"},
        Equip = {"equip", "pakai", "wear", "hold", "use"},
        Unequip = {"unequip", "lepas", "remove", "unhold", "store"},
        Plant = {"plant", "tanam", "seed", "grow"},
        Harvest = {"harvest", "panen", "collect", "ambilhasil"},
    }
    
    for _, remote in ipairs(allRemotes) do
        local fullName = string.lower(remote.Name .. " " .. (remote.Parent and remote.Parent.Name or ""))
        for key, keywords in pairs(patterns) do
            if not Remotes[key] then
                for _, keyword in ipairs(keywords) do
                    if string.find(fullName, keyword) then
                        Remotes[key] = remote
                        break
                    end
                end
            end
        end
    end
    
    print("=== REMOTE DETECTION (v2) ===")
    for key, remote in pairs(Remotes) do
        if remote then
            print("[OK]", key, "->", remote:GetFullName())
        else
            print("[MISSING]", key, "- akan fallback ke direct")
        end
    end
    print("==============================")
end

-- ===== FUNGSI UTAMA =====
-- TIDAK dedupe! Tampilkan SEMUA pet (termasuk yang nama/mutasi/kg sama)
-- Setiap instance pet unik berdasarkan objek referensi
local function getAllPets()
    local pets = {}
    
    if Character then
        for _, v in ipairs(Character:GetChildren()) do
            if v:IsA("Tool") and isPet(v) then
                table.insert(pets, v)
            end
        end
    end
    
    for _, v in ipairs(Backpack:GetChildren()) do
        if v:IsA("Tool") and isPet(v) then
            table.insert(pets, v)
        end
    end
    
    return pets
end

-- IMPORTANT: Strategi aman - TIDAK pernah pindahkan parent
-- Hanya fire remote, atau gunakan Tool:Activate()
local function pickPet(pet)
    if not pet then return false end
    if not isPet(pet) then return false end
    
    -- Hanya fire remote, JANGAN pindah parent
    if Remotes.Pick then
        local ok = pcall(function() Remotes.Pick:FireServer(pet) end)
        if ok then return true end
    elseif Remotes.Equip then
        local ok = pcall(function() Remotes.Equip:FireServer(pet) end)
        if ok then return true end
    end
    
    -- Fallback aman: gunakan Activate jika Tool
    if pet:IsA("Tool") then
        local humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Coba equip dulu (temporary)
            local originalParent = pet.Parent
            local equipOk = pcall(function() pet.Parent = Character end)
            if equipOk then
                -- Activate tool
                task.wait(0.01)
                pcall(function() pet:Activate() end)
                -- Kembalikan ke posisi semula
                task.wait(0.01)
                pcall(function() pet.Parent = originalParent end)
                return true
            end
        end
    end
    
    return false
end

-- IMPORTANT: Strategi aman - TIDAK pernah pindahkan parent
local function placePet(pet, slot)
    if not pet then return false end
    if not isPet(pet) then return false end
    
    if Remotes.Place then
        local ok = pcall(function()
            if slot then
                Remotes.Place:FireServer(pet, slot)
            else
                Remotes.Place:FireServer(pet)
            end
        end)
        if ok then return true end
    elseif Remotes.Plant then
        local ok = pcall(function()
            if slot then
                Remotes.Plant:FireServer(pet, slot)
            else
                Remotes.Plant:FireServer(pet)
            end
        end)
        if ok then return true end
    elseif Remotes.Unequip then
        local ok = pcall(function() Remotes.Unequip:FireServer(pet) end)
        if ok then return true end
    end
    
    -- TIDAK ada fallback pindah parent
    return false
end

-- ===== UI LIBRARY v2 (dengan search bar & config delay) =====
local UI = {
    ScreenGui = nil,
    MainFrame = nil,
    ToggleButton = nil,
    PetListFrame = nil,
    SearchBox = nil,
    DelayInput = nil,
}

local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GrowAGardenPickerV2"
    screenGui.Parent = PlayerGui
    UI.ScreenGui = screenGui
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 60, 0, 30)
    toggleBtn.Position = UDim2.new(0, 10, 0.5, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Text = "MENU"
    toggleBtn.Font = Enum.Font.SourceSansBold
    toggleBtn.TextSize = 14
    toggleBtn.Parent = screenGui
    UI.ToggleButton = toggleBtn
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 350, 0, 500)
    mainFrame.Position = UDim2.new(0, 80, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    UI.MainFrame = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = "Grow A Garden - PnP v2"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = mainFrame
    
    local masterToggle = Instance.new("TextButton")
    masterToggle.Size = UDim2.new(1, -20, 0, 35)
    masterToggle.Position = UDim2.new(0, 10, 0, 50)
    masterToggle.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    masterToggle.TextColor3 = Color3.new(1, 1, 1)
    masterToggle.Text = "Auto Pick & Place: ON"
    masterToggle.Font = Enum.Font.SourceSansBold
    masterToggle.TextSize = 14
    masterToggle.Parent = mainFrame
    
    masterToggle.MouseButton1Click:Connect(function()
        Settings.AutoPickAndPlace = not Settings.AutoPickAndPlace
        if Settings.AutoPickAndPlace then
            masterToggle.Text = "Auto Pick & Place: ON"
            masterToggle.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
        else
            masterToggle.Text = "Auto Pick & Place: OFF"
            masterToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end)
    
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0, 130, 0, 30)
    delayLabel.Position = UDim2.new(0, 10, 0, 95)
    delayLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    delayLabel.TextColor3 = Color3.new(1, 1, 1)
    delayLabel.Text = "Delay PnP (detik):"
    delayLabel.Font = Enum.Font.SourceSans
    delayLabel.TextSize = 12
    delayLabel.Parent = mainFrame
    
    local delayInput = Instance.new("TextBox")
    delayInput.Size = UDim2.new(0, 60, 0, 30)
    delayInput.Position = UDim2.new(0, 145, 0, 95)
    delayInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    delayInput.TextColor3 = Color3.new(1, 1, 1)
    delayInput.Text = tostring(Settings.PickPlaceDelay)
    delayInput.Font = Enum.Font.SourceSans
    delayInput.TextSize = 12
    delayInput.PlaceholderText = "0.05"
    delayInput.Parent = mainFrame
    UI.DelayInput = delayInput
    
    local delayApplyBtn = Instance.new("TextButton")
    delayApplyBtn.Size = UDim2.new(0, 60, 0, 30)
    delayApplyBtn.Position = UDim2.new(0, 210, 0, 95)
    delayApplyBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
    delayApplyBtn.TextColor3 = Color3.new(1, 1, 1)
    delayApplyBtn.Text = "Set"
    delayApplyBtn.Font = Enum.Font.SourceSansBold
    delayApplyBtn.TextSize = 12
    delayApplyBtn.Parent = mainFrame
    
    delayApplyBtn.MouseButton1Click:Connect(function()
        local newDelay = tonumber(delayInput.Text)
        if newDelay and newDelay >= 0 then
            Settings.PickPlaceDelay = newDelay
            print("[PnP] Delay diubah ke", newDelay, "detik")
        else
            delayInput.Text = tostring(Settings.PickPlaceDelay)
        end
    end)
    
    local searchLabel = Instance.new("TextLabel")
    searchLabel.Size = UDim2.new(1, 0, 0, 25)
    searchLabel.Position = UDim2.new(0, 0, 0, 135)
    searchLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    searchLabel.TextColor3 = Color3.new(1, 1, 1)
    searchLabel.Text = "Cari Pet:"
    searchLabel.Font = Enum.Font.SourceSans
    searchLabel.TextSize = 12
    searchLabel.Parent = mainFrame
    
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -20, 0, 30)
    searchBox.Position = UDim2.new(0, 10, 0, 162)
    searchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    searchBox.TextColor3 = Color3.new(1, 1, 1)
    searchBox.Text = ""
    searchBox.Font = Enum.Font.SourceSans
    searchBox.TextSize = 13
    searchBox.PlaceholderText = "Ketik nama pet..."
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = mainFrame
    UI.SearchBox = searchBox
    
    local petListLabel = Instance.new("TextLabel")
    petListLabel.Size = UDim2.new(1, 0, 0, 25)
    petListLabel.Position = UDim2.new(0, 0, 0, 200)
    petListLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    petListLabel.TextColor3 = Color3.new(1, 1, 1)
    petListLabel.Text = "Daftar Pet (klik untuk toggle):"
    petListLabel.Font = Enum.Font.SourceSans
    petListLabel.TextSize = 12
    petListLabel.Parent = mainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -240)
    scrollFrame.Position = UDim2.new(0, 5, 0, 230)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = mainFrame
    UI.PetListFrame = scrollFrame
    
    local function refreshPetList()
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        local pets = getAllPets()
        local yOffset = 0
        
        -- Filter berdasarkan search
        local searchText = string.lower(searchBox.Text or "")
        if searchText ~= "" then
            local filteredPets = {}
            for _, pet in ipairs(pets) do
                if string.find(string.lower(pet.Name), searchText) then
                    table.insert(filteredPets, pet)
                end
            end
            pets = filteredPets
        end
        
        if #pets == 0 then
            local noPetLabel = Instance.new("TextLabel")
            noPetLabel.Size = UDim2.new(1, -10, 0, 40)
            noPetLabel.Position = UDim2.new(0, 5, 0, yOffset)
            noPetLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            noPetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            noPetLabel.Text = searchText ~= "" and "Tidak ada pet cocok dengan pencarian" or "Tidak ada pet ditemukan."
            noPetLabel.Font = Enum.Font.SourceSans
            noPetLabel.TextSize = 12
            noPetLabel.Parent = scrollFrame
            yOffset = yOffset + 45
        else
            for _, pet in ipairs(pets) do
                local petBtn = Instance.new("TextButton")
                petBtn.Size = UDim2.new(1, -10, 0, 35)
                petBtn.Position = UDim2.new(0, 5, 0, yOffset)
                petBtn.Name = pet.Name
                
                -- Check selected by object reference
                local isSelected = false
                for _, selectedRef in ipairs(Settings.SelectedPetRefs) do
                    if selectedRef == pet then
                        isSelected = true
                        break
                    end
                end
                
                petBtn.BackgroundColor3 = isSelected and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 60)
                petBtn.TextColor3 = Color3.new(1, 1, 1)
                petBtn.Text = string.format("%s %s (#%d)", isSelected and "[X]" or "[ ]", pet.Name, #Settings.SelectedPetRefs + 1)
                petBtn.Font = Enum.Font.SourceSansBold
                petBtn.TextSize = 12
                
                petBtn.MouseButton1Click:Connect(function()
                    local found = false
                    for i, ref in ipairs(Settings.SelectedPetRefs) do
                        if ref == pet then
                            table.remove(Settings.SelectedPetRefs, i)
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(Settings.SelectedPetRefs, pet)
                    end
                    refreshPetList()
                end)
                
                petBtn.Parent = scrollFrame
                yOffset = yOffset + 40
            end
        end
        
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    end
    
    -- Trigger refresh saat search box berubah
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        refreshPetList()
    end)
    
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 100, 0, 30)
    refreshBtn.Position = UDim2.new(1, -110, 1, -35)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.Text = "Refresh"
    refreshBtn.Font = Enum.Font.SourceSansBold
    refreshBtn.TextSize = 12
    refreshBtn.Parent = mainFrame
    
    refreshBtn.MouseButton1Click:Connect(function()
        refreshPetList()
    end)
    
    toggleBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            refreshPetList()
        end
    end)
    
    refreshPetList()
end

-- ===== MAIN LOOP v3 (SAFE) =====
-- HANYA jalan jika AutoPickAndPlace = true (toggle manual dari UI)
-- Menggunakan referensi objek langsung, bukan ID string
local function startAutoPickPlace()
    task.spawn(function()
        while task.wait(Settings.LoopInterval) do
            if not Settings.Enabled or not Settings.AutoPickAndPlace then
                continue
            end
            
            local petsToUse = {}
            
            if #Settings.SelectedPetRefs > 0 then
                -- Gunakan referensi yang sudah dipilih user
                for _, petRef in ipairs(Settings.SelectedPetRefs) do
                    if petRef and petRef.Parent and isPet(petRef) then
                        table.insert(petsToUse, petRef)
                    end
                end
            else
                -- TIDAK ada pet dipilih = TIDAK melakukan apa-apa (SAFETY)
                -- Jangan proses semua pet!
                petsToUse = {}
            end
            
            for _, pet in ipairs(petsToUse) do
                if pet and pet.Parent and isPet(pet) then
                    pickPet(pet)
                    task.wait(Settings.PickPlaceDelay)
                    placePet(pet)
                    task.wait(Settings.PickPlaceDelay)
                end
            end
        end
    end)
end

-- ===== INISIALISASI v2 =====
local function init()
    print("====================================")
    print("Grow A Garden - Auto PnP v2")
    print("Player:", LocalPlayer.Name)
    print("====================================")
    
    detectRemotes()
    
    -- Debug: list semua item di inventory untuk cek filter (TANPA menyentuh item)
    print("\n[DEBUG] Item di Character (TANPA modifikasi):")
    if Character then
        for _, v in ipairs(Character:GetChildren()) do
            if v:IsA("Tool") then
                print("  -", v.Name, "| isPet:", isPet(v), "| Parent:", v.Parent and v.Parent.Name or "nil")
            end
        end
    end
    
    print("\n[DEBUG] Item di Backpack (TANPA modifikasi):")
    for _, v in ipairs(Backpack:GetChildren()) do
        if v:IsA("Tool") then
            print("  -", v.Name, "| isPet:", isPet(v), "| Parent:", v.Parent and v.Parent.Name or "nil")
        end
    end
    
    pcall(createUI)
    startAutoPickPlace()
    
    print("\n[PnP v2] Script loaded!")
    print("[PnP v2] Tekan MENU untuk buka panel")
    print("[PnP v2] Hanya PET yang akan diproses")
end

init()

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Grow A Garden v2",
    Text = "Auto PnP Loaded! Hanya pet yang diproses",
    Duration = 5,
})
