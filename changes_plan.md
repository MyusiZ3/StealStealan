# StealStealan — 9-Point Gameplay, Visual, HUD & Admin Overhaul Plan

Dokumen ini berisi rencana teknis lengkap untuk 9 perubahan utama sebelum/selama tahap implementasi kode.

---

## 1. Treadmill 12 Level (`+2/Step` s/d `+125K/Step`), Perubahan Bentuk Tiap Level, & Bubble Boost `x3 Speed`

### A. Tabel Kurva 12 Level Treadmill (`Lv. 1: +2/Step` $\rightarrow$ `Lv. 12 MAX: +125K/Step`)
Setiap kenaikan 1 level memberikan lonjakan *Base Speed per Step* (~`2.7x` per level) serta perubahan langsung pada bentuk, warna, sabuk, dan ornamen 3D Treadmill:

| Level | Nama & Bentuk Visual Treadmill (Berubah Setiap Naik 1 Level) | Base Speed / Step | Base Speed / Sec (2 Step/s) | Biaya Upgrade |
| :---: | :--- | :---: | :---: | :---: |
| **Lv. 1** | **Basic Gym Treadmill** — Bodi besi hitam-abu standar, layar LED kecil | `+2 / Step` | `+4 / s` | **Gratis (Starter)** |
| **Lv. 2** | **Sport Blue Runner** — Bodi biru sport, *handrail* putih, chevron sabuk biru | `+6 / Step` | `+12 / s` | `$400` |
| **Lv. 3** | **Sci-Fi Neon Deck** — Sasis metalik gelap, rel & layar hologram cyan | `+16 / Step` | `+32 / s` | `$2.5K` |
| **Lv. 4** | **Flame Turbo Belt** — Bodi merah-oranye, sirip knalpot api di sisi kiri-kanan | `+45 / Step` | `+90 / s` | `$18K` |
| **Lv. 5** | **Emerald Bio-Tech** — Rangka hijau zamrud dengan tabung energi kristal di pilar | `+125 / Step` | `+250 / s` | `$140K` |
| **Lv. 6** | **Golden Sovereign** — Sasis berlapis emas murni, mahkota kecil di atas konsol | `+350 / Step` | `+700 / s` | `$1.2M` |
| **Lv. 7** | **Frostbite Cryo** — Rangka biru glasier dengan pilar bongkahan es *sapphire* | `+950 / Step` | `+1.9K / s` | `$12M` |
| **Lv. 8** | **Cyber Hacker Matrix** — Bodi hitam obsidian, garis neon hijau matriks & 3 layar | `+2,600 / Step` (`2.6K`) | `+5.2K / s` | `$125M` |
| **Lv. 9** | **Abyssal Demonic** — Rangka ungu-merah gelap dengan ornamen tanduk & sabuk magma | `+7,200 / Step` (`7.2K`) | `+14.4K / s` | `$1.5B` |
| **Lv. 10** | **Seraphim Angelic** — Marmer putih gading & emas dengan sayap malaikat di pilar | `+20,000 / Step` (`20K`) | `+40K / s` | `$20B` |
| **Lv. 11** | **Astral Singularity** — Kosmik biru-ungu dengan cincin halo melayang & orb bintang | `+52,000 / Step` (`52K`) | `+104K / s` | `$300B` |
| **Lv. 12** | **Primordial Cataclysm (MAX)** — Rangka naga obsidian-emas, tanduk dorsal & inti merah | **`+125,000 / Step` (`125K`)** | **`+250K / s`** | `$5T` |

### B. Sistem Bubble Boost `⚡ x3 Speed` Saat Latihan (Active-AFK Mechanic)
- **Cara Kerja**:
  - Ketika pemain sedang berada di atas treadmill (`OnTreadmill == true`), setiap `15–22` detik akan muncul **Gelembung Boost (`⚡ x3 SPEED!`)** yang mengambang di area layar/treadmill selama `5.5` detik.
  - Apabila pemain meng-klik / tap gelembung tersebut sebelum hilang:
    1. Gelembung meletup dengan efek partikel & SFX *power-up*,
    2. Pemain mendapatkan **Buff `x3 Treadmill Speed` selama `15 detik`** (tervalidasi di server pada `TrainingSystem.luau`),
    3. Muncul badge/timer aktif `⚡ x3 SPEED (15s)` di atas kepala/treadmill dan animasi lari menjadi lebih cepat.

### C. File yang Diubah
- `src/ReplicatedStorage/Config/GameConfig.luau`: Menambahkan `TREADMILL.MAX_LEVEL = 12`, tabel `TREADMILL.LEVEL_SPEED_PER_STEP`, dan `TREADMILL.LEVEL_COSTS`.
- `src/ServerScriptService/Systems/TrainingSystem.luau`: Menggunakan tabel 12 level, validasi `TreadmillBubbleClaim` remote untuk buff `x3 Speed` berdurasi 15 detik.
- `src/ServerScriptService/Services/EconomyService.luau` & `PlotService.luau`: Membatasi pembelian upgrade treadmill hingga `Lv. 12 (MAX)`.
- `src/ReplicatedStorage/Modules/PlotVisualBuilder.luau`: Mengubah `BuildTreadmillTier` agar membangun **12 variasi bentuk/model treadmill** (Lv. 1 s/d Lv. 12).
- `src/StarterPlayer/StarterPlayerScripts/TreadmillClient.client.luau`: Menampilkan dan menganimasikan *clickable bubble* `⚡ x3 SPEED!` saat berlari di treadmill.

---

## 2. Kandang (Open-Pen) Memanjang ke Belakang + Pola Evolusi Bertingkat

### A. Ekspansi Panjang ke Arah Belakang (`+Z`)
- **Posisi Depan Tetap (`Z = -8.5`)**: Gerbang depan kandang, `CashCollectorPad`, `PenUpgradeBoard`, dan `Treadmill` **tetap di posisinya** di dekat jalan utama Hub.
- **Bagian Belakang (`+Z`) Memanjang Setiap Naik Level**:
  - **Level 1 (Kapasitas 8 Pet)**: Panjang kandang awal `24 studs` (dari `Z = -8.5` s/d `Z = +15.5`).
  - **Setiap Naik 1 Level Upgrade**: Bagian belakang kandang mundur **`+3.5 studs` ke arah `+Z`** (`OpenPaddockFloor`, `PlotBase`, pagar samping kiri-kanan, dan pagar belakang ikut memanjang).
  - **Sinkronisasi Area Jalan Pet & Slot Crate**: `RoamingPenClient.client.luau` membaca dimensi `OpenPaddockFloor.Size.Z` dan `CFrame` secara dinamis sehingga pet yang berkeliaran dan *grid* penempatan crate otomatis mengisi area belakang yang baru bertambah panjang.

### B. Pola Evolusi Visual (Tiap Level Tambah Aksesori, Tiap 3 Level Ganti Material & Bentuk)
- **Setiap 3 Level (Lv. 1, Lv. 4, Lv. 7, Lv. 10, Lv. 13+)** $\rightarrow$ **Perubahan Bentuk & Material Utama Pagar**:
  - `Tier 1 (Lv. 1–3)`: **Rustic Wood Ranch** (Pagar kayu klasik)
  - `Tier 2 (Lv. 4–6)`: **White Picket & Oak Trim** (Pagar piket putih bersih dengan tiang kayu ek)
  - `Tier 3 (Lv. 7–9)`: **Stone & Wrought-Iron Bastion** (Tembok batu bata & jeruji besi tempa)
  - `Tier 4 (Lv. 10–12)`: **Royal Marble & Gold Conservatory** (Dinding marmer putih & pagar emas)
  - `Tier 5 (Lv. 13+)`: **Celestial Obsidian Sanctum** (Basalt obsidian hitam, aksen emas & kristal kosmik)
- **Di Level Antara (Sub-Level +1 dan +2 di dalam setiap Tier)** $\rightarrow$ **Penambahan Aksesori Kandang**:
  - **Sub-Level +1 (Lv. 2, 5, 8, 11, 14)**: Menambahkan **Tiang Lentera / Obor di 4 Sudut Kandang** + **Gapura Lengkungan Pintu Masuk (*Front Gate Archway*)**.
  - **Sub-Level +2 (Lv. 3, 6, 9, 12, 15)**: Menambahkan **Pilar Totem / Patung Ornamen di Sudut Belakang** + **Banner/Pennant Dekoratif & Petak Bunga/Batu Hias di Tepi Luar Pagar**.

### C. File yang Diubah
- `src/ReplicatedStorage/Modules/PlotVisualBuilder.luau`
- `src/ReplicatedStorage/Modules/PlotPrefabSystem.luau`
- `src/StarterPlayer/StarterPlayerScripts/RoamingPenClient.client.luau`

---

## 3. Voxel Cash Pile & Animasi Tersedot Saat Diambil di `CashCollectorPad`

### A. Tumpukan Uang Voxel 3D Dinamis
- Di atas `CashCollectorPad`, dibuat container `VoxelCashPile` yang merender **0 s/d 24 tumpukan gepokan uang kertas hijau berikat pita putih (`Voxel Cash Bundles`) + batangan emas (`Gold Bars` pada tumpukan atas)**.
- Jumlah gepokan yang muncul dihitung secara proporsional dari jumlah `unclaimedPenCoins` dibandingkan dengan `incomePerSec` pemilik plot (saat `$0` pad kosong; semakin lama belum diambil, tumpukan uang semakin tinggi dan padat).

### B. Animasi Uang Tersedot ke Pemain (*Magnet Suction Tween*)
- Saat pemilik plot menginjak `CashCollectorPad` dan mengklaim uang:
  1. Server mengirim event visual/jumlah tumpukan ke client (`CrateDelivered` / `CashCollectedVFX`),
  2. Gepokan-gepokan uang voxel yang ada di atas pad di-kloning di client lalu **melayang cepat membentuk kurva (*bezier/magnet tween* selama `0.25–0.45` detik) tersedot langsung ke `HumanoidRootPart` pemain**,
  3. Disertai SFX koin (`CoinCollect`) dan *pop* partikel hijau/emas, sementara tumpukan di pad langsung kembali bersih (`0`).

### C. File yang Diubah
- `src/ReplicatedStorage/Modules/PlotVisualBuilder.luau`
- `src/ServerScriptService/Services/PlotService.luau`
- `src/ServerScriptService/Services/EconomyService.luau`
- `src/StarterPlayer/StarterPlayerScripts/RoamingPenClient.client.luau` (atau handler VFX client)

---

## 4. Penyeragaman BGM (Single Seamless Loop Lagu Hub)

### A. Perubahan Sistem Audio
- Menghapus mekanisme pergantian `bgmPlayer.SoundId` berdasarkan posisi `Z` biome maupun saat dikejar Poacher di `SettingsAndAudioClient.client.luau`.
- BGM selalu memutar **`SoundConfig.BGM.Hub` (`rbxassetid://1838933509`)** secara terus-menerus (`Looped = true`) tanpa pernah ter-reset atau *glitch* saat pemain berpindah area.
- Peringatan saat dikejar Poacher tetap menggunakan `SoundConfig.SFX.PoacherAlarm` pada channel `SFXGroup`.

### B. File yang Diubah
- `src/StarterPlayer/StarterPlayerScripts/SettingsAndAudioClient.client.luau`

---

## 5. Redesign Admin Panel (Compact UI, Scope `This Server` vs `All Servers`, Spawner, Give Player, & Semi-RNG Config)

### A. Global Scope Switch: `📍 This Server` vs `🌐 All Servers`
- Di bagian header Admin Panel terdapat toggle **`Scope: [📍 This Server] / [🌐 All Servers]`**:
  - **`📍 This Server`**: Perintah dieksekusi langsung di server tempat Admin berada.
  - **`🌐 All Servers`**: Menggunakan Roblox `MessagingService:PublishAsync("StealStealan_GlobalAdmin", payload)` + penyimpanan state aktif di `DataStoreService` agar **semua server aktif** mengeksekusi *Admin Abuse Event*, *Global Crate Spawn*, *Global Broadcast*, atau *Global Semi-RNG Rate Config* secara serentak.

### B. Struktur Tab Baru yang Bersih, Compact, & Hemat Space
1. **Tab 1 — `📦 World Spawner` (Satu Kesatuan Spawning Kotak di Dunia)**
   - **Multi-Select Rarity Dropdown**: Dropdown ringkas tempat Admin bisa mencentang **1 atau beberapa Rarity sekaligus** (misal centang `Legendary`, `Mythic`, `Primordial`), lengkap dengan kolom `%` peluang per rarity yang dipilih.
   - **Mutation Selector & % Chance**: Pilih mutasi (atau *Random Pool*) beserta input `%` peluang crate berisi mutasi (`0%–100%`).
   - **Weight / Size Range**: Input **`Min Weight (KG / Ratio)`** dan **`Max Weight (KG / Ratio)`** dalam satu baris compact.
   - **Spawn Count & Area**: Input jumlah kotak (`Qty: 1–100`) dan pilihan area (`Default Biome Sesuai Rarity`, `PineWoods`, `MangroveSwamp`, `SavannaCamp`, `AlpinePeaks`, `VolcanicJungle`, atau `Near Admin`).
   - Tombol eksekusi tunggal: **`🚀 Spawn Crates` (`This Server` / `All Servers`)**.

2. **Tab 2 — `🎁 Give Player` (Kirim Kotak / Pet Langsung ke Pemain)**
   - **Target Selector**: Pilih pemain di server (`@Me` atau dropdown player) atau input `UserId`.
   - **Tipe Pemberian**: Toggle **`[🎒 Give Crate (Inv)]`**, **`[🏡 Give Ready Crate (Pen)]`**, atau **`[🐾 Give Direct Pet]`**.
   - **Konfigurasi Isi**:
     - Pilih **Rarity & Species** (dilengkapi filter cepat per Biome/Rarity),
     - Pilih **Mutation** (`None` s/d `Celestial`),
     - Input **Berat / Ukuran (`Weight KG / Size Ratio`)**,
     - Input **Jumlah (`Quantity: 1–50`)**.

3. **Tab 3 — `🎲 Semi-RNG & Rates` (Konfigurasi Peluang Global `This Server` / `All Servers`)**
   - Menampilkan dan mengedit persentase (`%`) peluang game secara transparan dalam 3 bagian ringkas:
     1. **Crate Rarity Spawn Rates (`%`)**: Persentase kemunculan `Common` s/d `Primordial` (termasuk peluang munculnya tier `Primordial`, `Singularity`, dll.).
     2. **Pet Mutation Roll Rates (`%`)**: Persentase kemunculan tiap mutasi (`Normal`, `Albino`, `Golden`, `Rainbow`, `Celestial`, dll.).
     3. **Pet Weight / Giant Size Brackets (`%`) & Semi-RNG Pity**:
        - Persentase peluang dapat pet ukuran `Micro`, `Normal`, `Big`, `Giant`, hingga `Colossal` (berat ekstrem),
        - Pengaturan *Semi-RNG / Lucky Pity Counter* (jaminan minimal rarity/size setelah $N$ tangkapan/bukaan).

4. **Tab 4 — `🎉 Events & Broadcast` (Terbagi Kategori + Support `All Servers`)**
   - Kontrol durasi (`30s`, `1m`, `2m`, `5m`, `10m`, `Custom Detik`) & *Sub-Category Filter Chips*:
     - **💵 Economy & Speed Events**: `2x Cash Rush`, `2x Speed Surge`, `25x Golden Fever`
     - **🍀 Luck & Hatch Events**: `5x Crate Luck`, `100x Mutation Party`, `Instant Unbox Party`
     - **🌪️ World & Chaos Events**: `Admin Crate Rain`, `Titanic Zoo`, `Zero Resistance`, `Poacher Stampede`
     - **📢 Global Announcement**: Input pesan banner server.

5. **Tab 5 — `👤 Players & Mod`**
   - Teleportasi (`TP to Player`, `Bring`, `TP Plot`, `TP Biome`), Status (`Heal`, `Freeze`, `Kill`), Economy Cepat (`Give/Set Cash`, `Give/Set Speed`, `Give Rebirth`), Moderasi (`Kick`, `Temp Ban`, `Perm Ban`, `Unban`), & Role (`Grant Admin/Owner`, `Wipe Data`).

6. **Tab 6 — `🛠️ Self Tools`**
   - Toggle cepat `God Mode`, `Instant Lasso Pull`, `Instant Crate Unbox`, `Super Speed`, dan `Invisible Mode`.

### C. File yang Diubah
- `src/ServerScriptService/Services/AdminUI/AdminPanel.client.luau`
- `src/ServerScriptService/Services/AdminService.luau`
- `src/ServerScriptService/Services/AdminConfig.luau`

---

## 6. Cinematic 3D Close-Up Hatch Reveal (Untuk Rarity di Atas Epic: `Legendary` s/d `Primordial`)

### A. Mengganti Popup 2D Lama dengan 3D World Camera Cutscene
- **Dihapus**: Popup kartu 2D penuh layar (`RareHatchCinematicGui` di `CinematicVFX.luau`) yang menutupi layar dengan kotak UI.
- **Alur Sinematik Baru (Gaya *Surf & Rescue* / *Steal & Ride a Pet*)**:
  1. Berlaku otomatis setiap membuka crate dengan rarity **di atas Epic** (`Legendary`, `Mythic`, `Cosmic`, `Secret`, `Eternal`, `Divine`, `Infinity`, `Astral`, `Omega`, `Singularity`, `Primordial`).
  2. Saat crate terbuka di kandang, layar melakukan **transisi *black flash/fade* cepat (`0.14s`)** sementara model 3D Pet asli dimunculkan di titik crate tersebut.
  3. **Kamera Utama (`Workspace.CurrentCamera`)** langsung mengarah (*close-up hero framing*) ke model 3D Pet di kandang dengan gerakan *dolly/orbit* halus.
  4. Muncul **Black Bar Sinematik (Letterbox Atas & Bawah)** + SFX *reveal* dramatis.
  5. Di atas *letterbox* bawah, muncul tipografi sinematik bersih tanpa kotak background yang mengganggu:
     - **Nama Pet & Badge Mutasi**
     - **Tier Rarity & Berat (`KG`) / Income (`+$X/s`)**
  6. Setelah `~2.5` detik (atau saat pemain klik/tap layar untuk *skip*), kamera dan *black bar* kembali normal dengan mulus.

### B. Opsi Disable di Menu Settings
- Menambahkan toggle **`Cinematic Hatch Camera` (`ON / OFF`)** di modal Settings (`profile.settings.hatchCutsceneEnabled`, default `true`). Jika dimatikan, crate `Legendary+` langsung menetas di kandang tanpa menggeser kamera pemain.

### C. File yang Diubah
- `src/ReplicatedStorage/Modules/CinematicVFX.luau`
- `src/StarterPlayer/StarterPlayerScripts/RoamingPenClient.client.luau`
- `src/ReplicatedStorage/Config/GameConfig.luau` & `src/ReplicatedStorage/Shared/Types.luau`
- `src/StarterGui/UI/MainHUD.client.luau` (Settings Modal toggle)

---

## 7. Fix Bug Notifikasi (`Volcanic Zone` & `Crate Spawned` Tidak Hilang)

### A. Akar Masalah yang Ditemukan di `MainHUD.client.luau`
1. **`BiomeBanner` (`Volcanic Zone 😈 / Recommended: 500B Speed`) Selalu Muncul**:
   - Pada `MainHUD.client.luau` baris `6208–6216`, `biomeBanner.Visible = true` disetel setiap frame `Heartbeat` selama pemain berada di dalam koordinat `Z` biome tersebut.
2. **`CrateSpawnBanner` (`Crate Spawned` / `ALL CRATES RESET!`) & Banner Event Nyangkut**:
   - Penghapusan baris notifikasi mengandalkan `task.delay` + `TweenService` tanpa *expiration watchdog*, sehingga saat terjadi *wave reset* / cuaca / spawn beruntun, teks bisa tertinggal di `linesHolder` atau `resetHeaderLbl`. Selain itu, server memanggil `announceCrateSpawn` setiap 22–35 detik bahkan untuk crate `Common`.

### B. Solusi Perbaikan
1. **Biome Entry Banner Berdurasi `3.0 Detik`**:
   - Melacak `lastEnteredBiomeId`. `biomeBanner` **hanya muncul saat pemain baru memasuki biome berbeda**, tampil selama `3.0 detik`, lalu otomatis *fade-out* dan `Visible = false`.
2. **Global Notification Watchdog di `Heartbeat`**:
   - Setiap elemen di `CrateSpawnBanner` (`resetHeaderLbl` dan setiap `SpawnLine`), `GlobalEventBanner`, `RescueSuccessLabel`, serta `PopupToastGui` diberi atribut waktu kedaluwarsa `ExpiresAt = os.clock() + holdSec`.
   - Loop `Heartbeat` memeriksa setiap `0.25` detik dan langsung menghancurkan/menyembunyikan semua notifikasi yang sudah melewati `ExpiresAt` (mustahil ada teks yang nyangkut selamanya).
3. **Filter Pengumuman Background Spawn**:
   - Background spawn rutin di `LassoRescueSystem.luau` hanya mengumumkan crate `Legendary` ke atas (atau saat *Wave Reset / Crate Rain*).

### C. File yang Diubah
- `src/StarterGui/UI/MainHUD.client.luau`
- `src/ServerScriptService/Systems/LassoRescueSystem.luau`

---

## 8. Fix Trigger Tabrakan Musuh (Kotak Trigger Transparan) & Knockback/Ragdoll Jauh + Smooth

### A. Kotak Trigger Transparan (`HitboxTriggerPart`) pada Poacher & Boss
- Setiap model Poacher & Boss di `PoacherAISystem.luau` dilengkapi part **`HitboxTrigger`** berupa kotak transparan (`Transparency = 1`, `CanCollide = false`, `CanTouch = true`, `CanQuery = true`, ukuran sedikit lebih lebar dari visual musuh: misal `5.5 x 6.5 x 5.5` untuk Guard dan `8.0 x 8.5 x 8.0` untuk Boss).
- **Deteksi Tabrakan Instan (Zero-Delay)**:
  - Menggabungkan *spatial overlap* kotak `HitboxTrigger` (`Workspace:GetPartsInPart` / bounding box local-space check di Server + *client-side touch trigger* yang melapor ke server jika karakter lokal menyentuh kotak musuh saat sedang aggro), sehingga begitu bersentuhan langsung memicu *tackle* tanpa jeda *latency*.

### B. Ragdoll & Mental Lebih Jauh + Lebih Smooth
- Pada `RescueClient.client.luau` (`PlayerKnockback`):
  - Mengganti dorongan satu-frame `AssemblyLinearVelocity` (yang cepat tertahan gesekan lantai) dengan **impuls `LinearVelocity` terarah selama `0.22` detik + gaya angkat parabolik (`Horizontal Speed: 95–115`, `Upward Lift: 58–68`) + rotasi *ragdoll tumble* terkontrol**.
  - Karakter pemain akan terpental melambung jauh ke belakang dalam busur parabolik yang mulus, memantul ringan, lalu bangkit kembali (`GettingUp`) tanpa tersendat.

### C. File yang Diubah
- `src/ServerScriptService/Systems/PoacherAISystem.luau`
- `src/StarterPlayer/StarterPlayerScripts/RescueClient.client.luau`

---

## 9. Sembunyikan Mutasi pada Crate di Biome + Animasi Tangan Menarik Tali Lasso

### A. Sembunyikan Mutasi pada Wild Crate di Biome
- Di `LassoRescueSystem.luau`:
  - Menghapus `WildMutationHighlight` dan menghapus prefix `[BLOOM]` / `[GOLDEN]` / dll. dari `CrateTitleLabel` di atas crate yang spawn di biome, serta dari teks pengumuman `CrateSpawnAnnounce`.
  - Crate di biome **hanya menampilkan Nama Crate & Rarity-nya saja** (contoh: `Forest Emerald Cage` / `Uncommon`). Mutasi tetap tersimpan di data server (`customMutation`) dan baru terungkap sebagai kejutan saat crate dibuka di kandang.

### B. Animasi Tangan Menarik Tali Saat Ngelasso Crate
- Di `RescueClient.client.luau`:
  - Saat pemain sedang menarik crate (`isPullActive == true`):
    1. Karakter pemain otomatis berputar halus menghadap ke arah crate yang sedang ditarik,
    2. Menjalankan **animasi prosedural kedua tangan menarik tali tambang ke belakang secara ritmis (*two-handed tug-of-war pulling motion*)** menggunakan `Motor6D` bahu/lengan (`RightShoulder` / `LeftShoulder` pada R15 dan `Right Shoulder` / `Left Shoulder` pada R6) disertai gerakan condong badan (*lean-back*) yang berdenyut ekstra setiap kali pemain menekan *Tap/Click Boost*.
    3. Begitu tarik selesai atau dibatalkan, pose lengan langsung dikembalikan (`Transform` / `C0` reset) ke animasi normal.

### C. File yang Diubah
- `src/ServerScriptService/Systems/LassoRescueSystem.luau`
- `src/StarterPlayer/StarterPlayerScripts/RescueClient.client.luau`
- `src/StarterGui/UI/MainHUD.client.luau`
