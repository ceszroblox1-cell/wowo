-- ============================================
-- GROW A GARDEN - AUTO PICK & PLACE SCRIPT
-- Executor: Delta
-- Fitur: Menghilangkan cooldown skill dengan
--        auto pick & place pet di 8 slot garden
-- ============================================

-- ===== KONFIGURASI =====
local Settings = {
    Enabled = true,
    AutoPickAndPlace = true,
    PickPlaceDelay = 0.05,
    LoopInterval = 0.2,
    SelectedPets = {},
    GardenSlots = 8,
}

-- ===== SERVICES =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

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
        Pick = {"pick", "ambil", "take", "select"},
        Place = {"place", "taruh", "letak", "put", "set"},
        Equip = {"equip", "pakai", "wear", "hold"},
        Unequip = {"unequip", "lepas", "remove", "unhold"},
        Plant = {"plant", "tanam", "seed"},
        Harvest = {"harvest", "panen", "collect"},
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
    
    print("=== REMOTE DETECTION ===")
    for key, remote in pairs(Remotes) do
        if remote then
            print("OK", key, "->", remote:GetFullName())
        else
            print("MISSING", key)
        end
    end
end

-- ===== FUNGSI UTAMA =====
local function getAllPets()
    local pets = {}
    local seen = {}
    if Character then
        for _, v in ipairs(Character:GetChildren()) do
            if v:IsA("Tool") and not seen[v.Name] then
                table.insert(pets, v)
                seen[v.Name] = true
            end
        end
    end
    for _, v in ipairs(Backpack:GetChildren()) do
        if v:IsA("Tool") and not seen[v.Name] then
            table.insert(pets, v)
            seen[v.Name] = true
        end
    end
    return pets
end

local function getGardenSlots()
    local slots = {}
    local ws = game:GetService("Workspace")
    local patterns = {"slot", "garden", "plot", "pot", "place", "tanah", "lahan", "field"}
    for _, obj in ipairs(ws:GetDescendants()) do
        local nameLower = string.lower(obj.Name)
        for _, pattern in ipairs(patterns) do
            if string.find(nameLower, pattern) then
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    table.insert(slots, obj)
                    break
                end
            end
        end
    end
    if #slots == 0 then
        for i = 1, Settings.GardenSlots do
            table.insert(slots, {Name = "Slot" .. i, Placeholder = true})
        end
    end
    return slots
end

local function pickPet(pet)
    if not pet then return false end
    if pet:IsA("Tool") then
        if Remotes.Pick then
            pcall(function() Remotes.Pick:FireServer(pet) end)
            return true
        elseif Remotes.Equip then
            pcall(function() Remotes.Equip:FireServer(pet) end)
            return true
        else
            pcall(function() pet.Parent = Character end)
            return true
        end
    end
    return false
end

local function placePet(pet, slot)
    if not pet then return false end
    if Remotes.Place then
        pcall(function()
            if slot then
                Remotes.Place:FireServer(pet, slot)
            else
                Remotes.Place:FireServer(pet)
            end
        end)
        return true
    elseif Remotes.Plant then
        pcall(function()
            if slot then
                Remotes.Plant:FireServer(pet, slot)
            else
                Remotes.Plant:FireServer(pet)
            end
        end)
        return true
    elseif Remotes.Unequip then
        pcall(function() Remotes.Unequip:FireServer(pet) end)
        return true
    else
        pcall(function() pet.Parent = Backpack end)
        return true
    end
end

-- ===== UI LIBRARY (SEDERHANA) =====
local UI = {
    ScreenGui = nil,
    MainFrame = nil,
    ToggleButton = nil,
    PetListFrame = nil,
}

local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GrowAGardenPicker"
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
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0, 80, 0.5, -200)
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
    title.Text = "Grow A Garden - Auto Pick"
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
    
    local petListLabel = Instance.new("TextLabel")
    petListLabel.Size = UDim2.new(1, 0, 0, 30)
    petListLabel.Position = UDim2.new(0, 0, 0, 100)
    petListLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    petListLabel.TextColor3 = Color3.new(1, 1, 1)
    petListLabel.Text = "Pilih Pet (klik untuk toggle):"
    petListLabel.Font = Enum.Font.SourceSans
    petListLabel.TextSize = 13
    petListLabel.Parent = mainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -150)
    scrollFrame.Position = UDim2.new(0, 5, 0, 135)
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
        
        if #pets == 0 then
            local noPetLabel = Instance.new("TextLabel")
            noPetLabel.Size = UDim2.new(1, -10, 0, 40)
            noPetLabel.Position = UDim2.new(0, 5, 0, yOffset)
            noPetLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            noPetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            noPetLabel.Text = "Tidak ada pet ditemukan."
            noPetLabel.Font = Enum.Font.SourceSans
            noPetLabel.TextSize = 12
            noPetLabel.Parent = scrollFrame
        else
            for _, pet in ipairs(pets) do
                local petBtn = Instance.new("TextButton")
                petBtn.Size = UDim2.new(1, -10, 0, 35)
                petBtn.Position = UDim2.new(0, 5, 0, yOffset)
                petBtn.Name = pet.Name
                
                local isSelected = false
                for _, selectedName in ipairs(Settings.SelectedPets) do
                    if selectedName == pet.Name then
                        isSelected = true
                        break
                    end
                end
                
                petBtn.BackgroundColor3 = isSelected and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 60)
                petBtn.TextColor3 = Color3.new(1, 1, 1)
                petBtn.Text = (isSelected and "[X] " or "[ ] ") .. pet.Name
                petBtn.Font = Enum.Font.SourceSansBold
                petBtn.TextSize = 13
                
                petBtn.MouseButton1Click:Connect(function()
                    local found = false
                    for i, name in ipairs(Settings.SelectedPets) do
                        if name == pet.Name then
                            table.remove(Settings.SelectedPets, i)
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(Settings.SelectedPets, pet.Name)
                    end
                    refreshPetList()
                end)
                
                petBtn.Parent = scrollFrame
                yOffset = yOffset + 40
            end
        end
        
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    end
    
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

-- ===== MAIN LOOP =====
local function startAutoPickPlace()
    task.spawn(function()
        while task.wait(Settings.LoopInterval) do
            if not Settings.Enabled or not Settings.AutoPickAndPlace then
                continue
            end
            
            local petsToUse = {}
            
            if #Settings.SelectedPets > 0 then
                local allPets = getAllPets()
                for _, pet in ipairs(allPets) do
                    for _, selectedName in ipairs(Settings.SelectedPets) do
                        if pet.Name == selectedName then
                            table.insert(petsToUse, pet)
                            break
                        end
                    end
                end
            else
                petsToUse = getAllPets()
            end
            
            for _, pet in ipairs(petsToUse) do
                if pet and pet.Parent then
                    pickPet(pet)
                    task.wait(Settings.PickPlaceDelay)
                    placePet(pet)
                    task.wait(Settings.PickPlaceDelay)
                end
            end
        end
    end)
end

-- ===== INISIALISASI =====
local function init()
    print("Starting Grow A Garden - Auto Pick & Place")
    print("Player:", LocalPlayer.Name)
    
    detectRemotes()
    pcall(createUI)
    startAutoPickPlace()
    
    print("Script loaded successfully!")
    print("Tekan tombol MENU di kiri layar untuk membuka panel")
end

init()

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Grow A Garden",
    Text = "Auto Pick & Place Loaded! Tekan MENU untuk konfigurasi",
    Duration = 5,
})