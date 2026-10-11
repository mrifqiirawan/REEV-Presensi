# Panduan pemasangan dari nol

## 1. Siapkan Supabase

1. Buat proyek baru di https://supabase.com/dashboard. Pilih region yang dekat dengan sekolah.
2. Buka SQL Editor. Salin seluruh `supabase/001_schema.sql`, lalu Run sekali pada
   database baru. Skrip menggunakan transaksi; kegagalan membatalkan seluruh migrasi.
   Jangan jalankan ulang pada database yang sudah memiliki tabel REEV.
3. Di Authentication → Sign In / Providers, aktifkan email/password. **Matikan
   Allow new users to sign up**, anonymous sign-in, dan provider yang tidak digunakan.
   Akun dibuat menggunakan API admin, sehingga tidak memerlukan pendaftaran publik.
4. Di Project Settings / Connect / API Keys, ambil Project URL dan publishable
   (atau legacy anon) key. Ambil secret key (atau legacy service_role) untuk server.
   Label panel dapat berubah; yang penting key publik untuk browser dan key rahasia
   hanya untuk server.
5. Jangan mengekspos schema `net` atau `vault` ke Data API. Default aplikasi menggunakan `public`.

## 2. Isi konfigurasi lokal dan buat admin

Ekstrak ZIP, masuk folder yang memiliki `package.json`. Instal Node.js 22/24 LTS.
Salin `.env.example` menjadi `.env.local`, lalu isi setidaknya:

```dotenv
VITE_SUPABASE_URL=https://PROJECT_ANDA.supabase.co
VITE_SUPABASE_ANON_KEY=KEY_PUBLIK_ANDA
SUPABASE_URL=https://PROJECT_ANDA.supabase.co
SUPABASE_SERVICE_ROLE_KEY=KEY_RAHASIA_ANDA
```

Jalankan terminal:

```sh
npm ci
npm run admin
```

Masukkan username, nama admin, dan password minimal 12 karakter. Password tidak
muncul saat diketik. Tidak ada akun/password default. Email internal disusun menjadi
`username@presensi.internal`; pengguna tetap mengetik username, bukan email.
Email internal bukan kotak masuk: reset password dilakukan oleh admin melalui aplikasi.
Jika admin satu-satunya kehilangan akses, jalankan skrip lagi dengan username admin
baru, lalu kelola akun lama dari aplikasi.

## 3. Unggah source ke GitHub

Buat repository pribadi baru. Unggah isi folder aplikasi, termasuk `api/`, `server/`,
`src/`, `public/`, `package.json`, `package-lock.json`, `vite.config.js`, `index.html`,
dan `vercel.json`. Jangan unggah `node_modules`, `.env.local`, atau file CSV berisi
password/data siswa. `.gitignore` sudah disediakan.

Anda juga dapat memakai Vercel CLI dari folder aplikasi tanpa GitHub; paket ini
mengutamakan alur Import Git Repository agar pembaruan berikutnya mudah dilakukan.

## 4. Pasang pada Vercel

1. Buka https://vercel.com/new → Import repository tersebut.
2. Framework: **Vite**. Root Directory: folder yang memuat `package.json`.
3. Node.js: 22.x atau 24.x. Build Command: `npm run build`. Output: `dist`.
4. Tambahkan empat environment pada tabel berikut untuk environment Production.
   Tambahkan juga ke Preview/Development bila Anda memang ingin mengujinya di sana.

| Environment | Nilai | Sifat |
|---|---|---|
| `VITE_SUPABASE_URL` | Project URL | Publik |
| `VITE_SUPABASE_ANON_KEY` | Publishable / anon key | Publik, dilindungi RLS |
| `SUPABASE_URL` | Project URL yang sama | Server |
| `SUPABASE_SERVICE_ROLE_KEY` | Secret / service_role key | Rahasia, server saja |

5. Klik Deploy. Setelah selesai, buka URL HTTPS aplikasi secara langsung.
6. Set Authentication → URL Configuration → Site URL Supabase ke URL produksi.
   Login password tidak memakai redirect, tetapi konfigurasi domain tetap perlu benar.
7. Masuk memakai username/password admin yang dibuat tadi.

**Jangan beri awalan `VITE_` pada secret/service_role, API key gateway, atau CRON_SECRET.**
Vite menanam environment berawalan tersebut ke file JavaScript publik saat build.
Jika environment publik berubah, lakukan Redeploy agar build memakai nilai baru.
Jangan mengunggah hanya folder `dist`: fungsi server di `api/` juga diperlukan.

## 5. Siapkan data awal

1. Data & penugasan → Akun guru/admin → tambah atau impor guru.
2. Tahun & semester → buat `2026/2027`, semester Ganjil atau Genap.
3. Kelas & wali → buat kelas, pilih semester dan wali kelas.
4. Siswa → Impor CSV, pilih kelas tujuan, periksa 5 baris pratinjau, mulai impor.
5. Pengaturan → pilih semester aktif, zona waktu, dan jam tiga sesi.
6. Cetak kartu QR dari baris siswa atau per halaman 25 siswa.
7. Login sebagai guru pada HP, izinkan kamera, pindai kartu uji.

## 6. Hubungkan REEV WA Gateway

Tambahkan environment server Vercel berikut dan redeploy:

```dotenv
REEV_GATEWAY_URL=https://HOST_GATEWAY_ANDA
REEV_API_KEY=API_KEY_DARI_GATEWAY
REEV_DEVICE_ID=device_primary
CRON_SECRET=STRING_ACAK_PANJANG
```

Buat secret menggunakan terminal lokal:

```sh
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

`REEV_GATEWAY_URL` harus origin HTTPS, tanpa `/api`, path, atau kredensial di URL.
Paket mempertahankan kontrak v1.1.0: POST `/api/messages/send`, Bearer API key,
body `{recipient,message,deviceId}`, serta respons sukses `{success:true}`.
Periksa kontrak pada versi gateway yang Anda pakai sebelum digunakan operasional.
Alamat gateway lama yang masih `http://IP:3000` perlu diberi domain + HTTPS/reverse
proxy terlebih dahulu. Koneksi berasal dari server Vercel; key tidak dikirim ke browser.

Di aplikasi, Pengaturan → hilangkan centang Jeda seluruh pengiriman setelah gateway
siap. Gunakan tombol **Proses satu pesan** untuk uji dengan nomor yang Anda kelola.
Pengiriman nyata tidak dilakukan oleh pembuat paket ini.

## 7. Aktifkan pengiriman otomatis (pilih satu scheduler)

### Pilihan A — Supabase Cron

1. Aktifkan extension `pg_cron` dan `pg_net` pada Supabase.
2. Di Supabase Vault buat secret `reev_worker_url` berisi
   `https://NAMA-APP.vercel.app/api/wa-worker`.
3. Buat secret `reev_cron_secret`, sama persis dengan `CRON_SECRET` Vercel.
4. Jalankan `supabase/002_optional_scheduler.sql`.
5. Periksa Cron → Jobs → History dan hasil HTTP. Respon 401 berarti secret salah;
   HTML sign-in dapat berarti deployment protection Vercel menghalangi scheduler.
   Gunakan URL produksi yang dapat diakses oleh scheduler; login aplikasi tetap wajib.
6. Cron berjalan setiap menit. Pembatas database tetap dapat melewatkan proses jika
   belum cukup jeda, di luar jam, kuota habis, dijeda, atau tidak ada pesan.

Vault mengenkripsi secret saat disimpan; pg_net menggunakan header yang telah
didekripsi saat antrean HTTP dibentuk. Gunakan **hanya secret worker dengan akses
terbatas** pada header, bukan service_role. Orang yang memiliki akses SQL langsung
ke database dapat membaca antrean tersebut. Tidak ada kredensial akun/gateway
pada URL atau hasil respons worker.

### Pilihan B — Scheduler pada VM gateway Anda

Jadwalkan GET ke endpoint yang sama setiap menit, memakai header
`Authorization: Bearer CRON_SECRET`. Simpan token pada konfigurasi privat server;
jangan taruh pada query URL. Tidak perlu mengaktifkan Supabase Cron bila memilih ini.

### Pilihan C — Vercel Cron dengan paket yang mendukung setiap menit

Tambahkan properti berikut pada `vercel.json` kemudian deploy ulang:

```json
"crons": [{ "path": "/api/wa-worker", "schedule": "* * * * *" }]
```

Vercel otomatis mengirim CRON_SECRET sebagai Bearer token. Dokumentasi yang diperiksa
11 Oktober 2026 menyatakan Vercel Hobby membatasi cron sekali sehari; karena itu
cron satu menit tidak dimasukkan secara default. Periksa paket/limit akun saat deploy.

## 8. Google Sites dan layar utama

Jika tetap memakai Google Sites, tambahkan tombol menuju URL Vercel. Jangan embed
aplikasi: header keamanan paket menolak iframe dan kamera dirancang untuk halaman
langsung. Di aplikasi terdapat panduan Tambah ke layar utama untuk Android/iOS.

## Pemecahan masalah

| Gejala | Yang diperiksa |
|---|---|
| Layar meminta konfigurasi | Dua `VITE_` environment terisi, lalu Redeploy |
| Login gagal | Admin berhasil dibuat, username benar, password benar, Supabase Auth aktif |
| Akun belum siap | `profiles.id` cocok dengan Auth user; akun aktif; SQL sudah dijalankan |
| Akun guru tidak bisa membuat akun | Memang khusus admin, diperiksa di server |
| Kamera ditolak | Buka URL HTTPS langsung; izinkan kamera; tutup aplikasi lain yang memakai kamera |
| Scan di luar jadwal | Zona waktu dan rentang tiga sesi pada Pengaturan |
| QR/siswa tidak aktif | Status siswa, kelas, dan semester aktif |
| WA PENDING terus | Pengaturan jeda/jadwal/kuota, scheduler, key/URL/device gateway |
| WA UNKNOWN | Periksa log gateway sebelum ulang manual; mungkin request telah diterima |
| CSV ditolak duplikat | Periksa NISN/QR/username yang sudah ada, jangan mengganti ID sembarangan |
| Backup kedaluwarsa | Unduh dan verifikasi ulang; data telah berubah atau lewat 30 menit |
| Endpoint `/api` 404 lokal | `npm run dev` hanya frontend; gunakan `npx vercel dev` atau deployment |

## Referensi resmi

- https://vercel.com/docs/frameworks/frontend/vite
- https://vercel.com/docs/cron-jobs/manage-cron-jobs
- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/auth/general-configuration
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/secure-data
- https://supabase.com/docs/guides/cron/quickstart
- https://supabase.com/docs/guides/troubleshooting/database-roles-can-read-request-headers-queued-by-pg_net-ad6357
