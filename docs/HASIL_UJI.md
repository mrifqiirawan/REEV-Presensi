# Hasil pengujian — 11 Oktober 2026

## Lulus lokal

`npm ci` / instalasi dependensi dan `npm run build`: berhasil pada Node 24.19.0.
`npm test`: 7 pengujian, seluruhnya lulus.

| Cakupan | Bukti |
|---|---|
| SQL skema + fungsi | Migrasi lengkap dieksekusi pada PostgreSQL embedded PGlite |
| RLS dan hak fungsi | Guru tidak melihat rekap/antrean admin, hanya profil sendiri; tidak bisa menaikkan role, mengubah settings, memanggil worker/backup |
| QR HADIR | Status ALPA pada request QR dipaksa menjadi HADIR oleh DB |
| Duplikasi | Scan ulang mengembalikan ID sama; unique constraint tersedia |
| Worker reservasi | UNKNOWN tercatat sebelum HTTP; panggilan berikut tertahan cooldown |
| Backup/reset/restore | Round trip mengembalikan presensi; master dipertahankan saat reset; pesan restore CANCELLED |
| Receipt | Sekali pakai dan perubahan outbox membuat receipt lama ditolak |
| Proteksi akun | Admin aktif terakhir tidak bisa dinonaktifkan; guru nonaktif ditolak meski identitas token masih ada |
| CSV | Nol awal NISN, pemisah titik koma, sel berisi delimiter/baris baru, tanggal invalid, normalisasi WA, password minimal |
| Ekspor | Sel formula dinetralisasi sebelum masuk CSV |
| Worker HTTP | Tanpa auth ditolak; success, HTTP 429, timeout diuji dengan fetch mock; konfigurasi kosong tidak menghabiskan reservasi |

PGlite menjalankan SQL nyata secara lokal, tetapi bukan proyek Supabase hosted dan
bukan uji beban multi-koneksi. Request gateway menggunakan mock, tidak mengirim WA.
Tidak ada data siswa nyata pada pengujian atau seed database produksi.

## Belum dijalankan

- Build/deploy Vercel pada akun pengguna, routing fungsi Vercel di produksi.
- Supabase Auth hosted, pembuatan admin live, API akun hosted, dan konfigurasi RLS
  di proyek Supabase pengguna (RLS diuji lokal dengan role PostgreSQL).
- Browser UI end-to-end dan inspeksi screenshot responsif. Tidak tersedia browser
  kontrol yang sesuai pada lingkungan penyusunan; CSS/build diperiksa, bukan visual perangkat.
- Izin/autoplay kamera Android/iOS, pembacaan QR fisik, hasil cetak kartu.
- Pemindaian simultan dengan beberapa perangkat dan pengukuran latensi produksi.
- Gateway nyata, ketersediaan endpoint, dukungan Idempotency-Key, penerimaan pesan.
- Scheduler Supabase Cron atau Vercel Cron pada akun nyata.

Gunakan checklist pada OPERASIONAL.md untuk penerimaan sebelum operasional.
