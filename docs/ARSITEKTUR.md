# Arsitektur teknis

Frontend React/Vite dilayani Vercel CDN. Supabase Auth menangani password dan sesi.
Username dipetakan deterministik ke email internal. Tidak ada hash password buatan
sendiri. Browser menyimpan sesi melalui SDK Supabase standar; gunakan perangkat
sekolah yang dipercaya dan Keluar setelah selesai.

Master CRUD memakai Supabase Data API dengan RLS. Penulisan presensi, reservasi
antrean, reset dan restore memakai fungsi PostgreSQL security definer dengan
`search_path` tetap. Semua fungsi PUBLIC dicabut lalu dibuka hanya sesuai allowlist.
Service key Vercel hanya digunakan untuk akun admin dan worker, tidak dibundel frontend.
Endpoint akun memverifikasi JWT lewat `auth.getUser` lalu profil ADMIN aktif dari DB.

| Tabel | Peran |
|---|---|
| profiles | Identitas/role/aktif, FK auth.users |
| terms | Tahun ajaran + semester |
| classes | Semester, wali kelas, status aktif |
| students | Data siswa, wali, QR unik, kelas |
| settings | Identitas, jadwal, semester aktif, batas WA |
| attendance | Snapshot siswa/kelas, tanggal, sesi, status, metode, pencatat |
| outbox | Pesan, tujuan, status, waktu/percobaan |
| wa_state | Kuota tanggal lokal, waktu terakhir, blokir gateway |
| audit | Jejak perubahan master/akun/presensi/pemeliharaan |
| backup_receipts | Bukti backup sekali pakai, masa berlaku, fingerprint data |

Unique constraint presensi menangani duplikasi pada tingkat database. Advisory lock
8120 menyelaraskan fungsi presensi, reservasi worker, dan pemeliharaan. Lock 8121
menserialkan pemeriksaan admin aktif terakhir. Worker melepas transaksi reservasi
sebelum request HTTP, sehingga request internet tidak menahan lock PostgreSQL.
Status UNKNOWN dicatat sebelum HTTP; respons hanya memperbarui hasil reservasi.

RLS: guru aktif membaca master untuk scanner/manual, hanya profil sendiri; admin
membaca rekap, antrean, audit, dan master. Penulisan profil hanya lewat server.
Anonymous tidak memiliki akses aplikasi. Role berasal dari tabel profil yang tidak
bisa ditulis oleh guru, bukan dari metadata yang dapat diedit pengguna.

Ekspor rekap menggunakan pagination 500 per permintaan, maksimum 20.000 catatan.
Di tengah ekspor, presensi yang masuk dapat menggeser pagination; untuk laporan
arsip konsisten pilih tanggal yang sudah selesai, bukan sesi yang masih berjalan.
Backup JSON dibuat dalam satu statement/transaksi; receipt menolak reset bila
fingerprint data operasional berubah. Restore seluruhnya atomik dan semua pesan
historis menjadi CANCELLED.

Tidak ada klaim throughput/laten produksi dari uji lokal. Indeks tanggal presensi,
kelas siswa, antrean pending dan penerima tersedia. Dashboard menghitung aggregate
PostgreSQL, bukan mengunduh seluruh siswa/presensi ke browser. Akun admin pertama
memerlukan server key hanya pada lingkungan privat operator.
