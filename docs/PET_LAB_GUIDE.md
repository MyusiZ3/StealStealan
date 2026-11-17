# Pet Lab Workbench Guide (`StealStealan_PetLab`)

**Pet Lab** adalah *Place* Roblox Studio terpisah di repo yang sama (`petlab.project.json`) untuk memodelkan, mengecek rig `Motor6D`, menguji mutasi, dan memverifikasi animasi pet voxel tanpa terhalang map utama, UI HUD game, atau DataStore.

Karena [`petlab.project.json`](../petlab.project.json) memetakan folder `src/ReplicatedStorage/Modules` yang sama dengan [`default.project.json`](../default.project.json), setiap revisi pet di *Pet Lab* langsung tersinkron otomatis ke game utama.

---

## 1. Struktur Modular `VoxelPets` (`1 Hewan = 1 File`)

```text
src/ReplicatedStorage/Modules/VoxelPets/
├── init.luau            -- Registry otomatis + API publik (Build, StepRig, ResetRig, InspectModel)
├── RigCore.luau         -- Builder voxel, pewarnaan mutasi, dan session Motor6D
├── AnimArchetypes.luau  -- Kurva animasi Idle/Walk/Fly/Ride/StressTest + AnimSaves
├── VFXPresets.luau      -- Trail & partikel anti-glare (tanpa PointLight)
├── Validator.luau       -- Auto-check voxel melayang, risiko Z-fighting, & ground offset
└── Species/             -- 1 file Luau per hewan!
    ├── _TemplateSpecies.luau
    ├── SylphPlumeDrake.luau
    ├── FaeLaceDragon.luau
    └── CelestiaStarCat.luau
```

*(File `src/ReplicatedStorage/Modules/VoxelFantasyPets.luau` tetap dipertahankan sebagai wrapper tipis demi backward compatibility.)*

---

## 2. Membuka & Live-Sync `Pet Lab` di Roblox Studio

1. **Generate / update file `PetLab.rbxl`:**
   ```powershell
   C:\Users\muham\.gemini\bin\rojo.exe build petlab.project.json -o PetLab.rbxl
   ```
2. Buka `PetLab.rbxl` di Roblox Studio (boleh dibuka **bersamaan** dengan Place utama `StealSteala`).
3. **(Opsional) Live-sync kode saat *Pet Lab* terbuka:**
   ```powershell
   C:\Users\muham\.gemini\bin\rojo.exe serve petlab.project.json
   ```
   *(Default port di [`petlab.project.json`](../petlab.project.json) adalah `34873`, sehingga tidak bentrok dengan `rojo serve default.project.json` di port `34872`.)*
4. Tekan **Play (F5)** di `PetLab.rbxl` untuk membuka **Pet Lab Inspector UI**.

---

## 3. Fitur Utama Pet Lab Inspector

- **Top Diagnostic Banner (`Validator.InspectModel`)**:
  Otomatis mengecek setiap kali pet di-*spawn*:
  - Deteksi voxel terputus / melayang (*Disconnected Voxel* via BFS 3D).
  - Deteksi permukaan sejajar beda warna (*Coplanar Z-Fighting*).
  - Kalibrasi tinggi telapak kaki ke `WorldPivot` (`Ground ~0.00 st`).
- **Mode Animasi & `Stress Test`**:
  - `Idle`, `Walk`, `Fly`, `Ride`
  - **`Stress Test`**: Memutar `NeckJoint`, `HeadJoint`, sayap, ekor, telinga, dan kaki ke sudut ekstrem secara bersamaan untuk memastikan tidak ada sudut blok yang menembus rahang atau pipi saat bergerak.
  - `BaseC0 (Bind)`: Mengembalikan rig ke pose netral untuk cek sambungan dasar.
- **Tombol Debug & Kamera**:
  - **Joint Pivots**: Menampilkan titik engsel `Motor6D` berwarna cyan/emas langsung di atas model.
  - **Scale Dummy**: Memunculkan dummy karakter 5-stud & penggaris tinggi 1–8 stud di samping meja putar.
  - **Camera Presets**: `Orbit 3/4`, `Head Close` (zoom langsung ke kepala/leher), `Side`, `Top`, atau `Player Walk`. Gunakan **Klik Kanan + Drag** untuk memutar kamera dan **Scroll** untuk zoom.
  - **Scale & Mutation Grid**: Uji cepat ukuran `0.55x` – `3.50x` serta seluruh 14 mutasi (termasuk *Rainbow hue cycle* live).

---

## 4. Menambah Pet Baru (Cukup 1 File)

1. Duplikat `src/ReplicatedStorage/Modules/VoxelPets/Species/_TemplateSpecies.luau` dan beri nama file sesuai `SpeciesId` (tanpa awalan `_`), misalnya `NebulaFox.luau`.
2. Ubah `Id`, `DisplayName`, `Archetype` (`"WingedDrake" | "QuadrupedFeline" | "QuadrupedBeast"`), dan susunan voxel + `AttachMotor`.
3. Daftarkan statistik ekonomi/biome hewan tersebut di [`AnimalConfig.luau`](../src/ReplicatedStorage/Config/AnimalConfig.luau) dan [`BiomeConfig.luau`](../src/ReplicatedStorage/Config/BiomeConfig.luau).
4. `VoxelPets` akan otomatis memuat file tersebut tanpa perlu mengedit registry.
