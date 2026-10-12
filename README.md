# REEV Presensi 2.0.3 | Vercel + Supabase

**Upgrade dari 2.0.2: baca docs/UPGRADE_2.0.3.md.** Dukungan NISN/WA bertanda petik dan tanggal M/D/YYYY pada impor CSV. Tidak memerlukan migrasi database baru.

Riwayat 2.0.2 — docs/UPGRADE_2.0.2.md: Perbaikan reset, template pesan di Pengaturan, pemicu WA otomatis setelah scan, dan audio tanpa tombol khusus.

## Yang tersedia

- Login username/password melalui Supabase Auth. Akun guru/admin dibuat admin;
  skrip terminal membuat admin pertama tanpa password bawaan.
- Guru langsung membuka kamera scanner. QR selalu mencatat HADIR. Kunci unik
  PostgreSQL melindungi siswa + semester + tanggal + sesi dari catatan ganda.
- Manual: pilih kelas → siswa → HADIR/SAKIT/IZIN/ALPA. Jadwal tiga sesi ditentukan server.
- Data & penugasan: siswa, kelas/wali, tahun/semester, akun. Pilihan relasi dapat dicari.
- CSV siswa: NISN, nama, lahir, alamat, orang tua, WA, isi QR. QR kosong dibuat otomatis.
- CSV guru: username, nama, password, WA. Cetak kartu QR; rekap filter tanggal/kelas/status.
- Dashboard, desain responsif, tema terang/gelap, warna/identitas sekolah.
- Tombol **Keluar** berikon dan berlabel, tersedia di header ponsel dan bagian akun,
  dialog konfirmasi, status proses, penutupan kamera, pengakhiran sesi perangkat.
- Antrean REEV WA Gateway: batas harian, jeda global/penerima, jam pengiriman,
  kedaluwarsa, penghentian saat 401/403/429, tanpa auto-retry.
- Backup JSON, verifikasi file unduhan sebelum reset, pemulihan transaksi atomik.
- Audit perubahan tersimpan di tabel `audit` (dilihat lewat Supabase Table Editor admin).

## Struktur

| Lokasi | Kegunaan |
|---|---|
| `src/` | React, scanner, halaman, validasi CSV, tema |
| `api/accounts.js` | Fungsi Vercel untuk administrasi akun |
| `api/wa-worker.js` | Fungsi Vercel untuk satu pengiriman antrean |
| `server/` | Pemeriksaan token/role server dan client service Supabase |
| `supabase/001_schema.sql` | Skema, constraint, RLS, fungsi transaksi |
| `supabase/002_optional_scheduler.sql` | Scheduler opsional setiap 5 detik |
| `supabase/003_upgrade_v2_0_1.sql` | Migrasi dasar versi 2.0.1 |
| `supabase/004_upgrade_v2_0_2.sql` | Reset, template pesan dan trigger otomatis |
| `supabase/005_enable_automation.sql` | Validasi konfigurasi dan scheduler otomatis |
| `scripts/create-admin.mjs` | Pembuatan admin pertama |
| `public/templates/` | Template CSV kosong |
| `tests/` | Pengujian PostgreSQL lokal dan logika aplikasi |
| `.env.example` | Nama konfigurasi yang harus diisi |
| `docs/` | Panduan deploy, operasi, arsitektur, dan hasil uji |

## Perintah

Gunakan Node.js 22 atau 24 LTS. Dari folder yang memuat `package.json`:

```sh
npm ci
npm run admin
npm run dev
npm test
npm run build
```

`npm run admin` memerlukan `.env.local` (salin dari `.env.example`).
`npm run dev` menjalankan frontend saja. Untuk menguji `/api/*` lokal gunakan
`npx vercel dev` dengan environment proyek; login/CRUD Supabase tetap membutuhkan
proyek Supabase yang telah diatur. Jangan unggah `.env.local` ke GitHub.

## Batas yang perlu diketahui

- Belum dipublikasikan atau diuji pada akun Supabase/Vercel pengguna, kamera fisik,
  dan gateway nyata. Lihat `docs/HASIL_UJI.md` dan checklist penerimaan.
- Internet diperlukan; aplikasi tidak menyimpan presensi offline.
- Guru aktif boleh memindai semua siswa aktif pada semester aktif, seperti aplikasi
  sebelumnya. Guru dapat membaca master siswa/kelas untuk pemilihan manual, tetapi
  tidak mengubah master atau membaca rekap/antrean admin.
- Backup aplikasi maksimal 3 MB, tanpa kredensial Supabase Auth. Pemulihan pada
  proyek yang sama; pemulihan lintas proyek membutuhkan prosedur akun terpisah.
  Jika melebihi batas, reset aplikasi ditolak; gunakan backup database Supabase.
- Data siswa/kelas/akun dinonaktifkan, bukan dihapus lewat UI. Tidak ada pengubahan
  catatan presensi yang sudah ada melalui UI. Duplikasi mengembalikan catatan pertama.
- CSV siswa 200 baris/file (satu transaksi), guru 100 baris/file (akun diproses satu
  per satu). Rekap maksimal 20.000 catatan per unduhan. Paging 25 baris.
- Pintasan layar utama disertai panduan Android/iOS; tidak menjamin browser
  menampilkan dialog instalasi otomatis. Perizinan kamera tetap diperlukan.
- Jadwal WA otomatis harus dipasang terpisah. `vercel.json` tidak mengaktifkan cron
  berbayar tanpa pilihan Anda. Gunakan Supabase Cron atau scheduler pada server sendiri.

Referensi resmi platform dan detail pemasangan tercantum dalam panduan deploy.
