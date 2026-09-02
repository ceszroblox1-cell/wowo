# 🌱 Grow A Garden - Auto Pick & Place Script

Script untuk game **Grow A Garden** di Roblox, khusus untuk **Delta Executor**.

## Fitur
- ✅ Auto Pick & Place (menghilangkan cooldown skill)
- ✅ UI untuk memilih pet yang akan dipakai
- ✅ Auto-detect remote events
- ✅ Support 8 slot garden
- ✅ Master toggle ON/OFF

## Cara Pakai
1. Buka Delta Executor
2. Copy isi file `PickAndPlace.lua`
3. Paste ke executor dan jalankan
4. Tekan tombol **MENU** di kiri layar untuk membuka panel
5. Pilih pet yang ingin diaktifkan (klik untuk toggle)
6. Script akan otomatis pick & place pet yang dipilih

## Konfigurasi
Di bagian atas script ada `Settings`:
```lua
local Settings = {
    Enabled = true,              -- Master switch
    AutoPickAndPlace = true,     -- Fitur utama
    PickPlaceDelay = 0.05,       -- Delay pick-place (detik)
    LoopInterval = 0.2,          -- Interval loop
    GardenSlots = 8,             -- Jumlah slot garden
}
```

## Catatan Penting
- Script auto-detect remote events, tapi jika game update mungkin perlu penyesuaian
- Pastikan pet ada di inventory/backpack
- Jika remote tidak terdeteksi, script akan fallback ke metode direct equip/unequip
- Lihat output console untuk hasil deteksi remote