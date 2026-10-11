# Upgrade REEV Presensi 2.0.0 ke 2.0.1

Paket source lengkap. Belum dipasang pada Vercel/Supabase Anda. Pengujian aplikasi dan build tidak dijalankan sesuai permintaan.

## Langkah pemasangan pada aplikasi yang sudah berjalan

1. Unduh cadangan dari menu Backup. Simpan ZIP versi 2.0.0 untuk rollback.
2. Aktifkan sementara “Jeda seluruh pengiriman” di Pengaturan. Tunggu request worker yang sedang berlangsung selesai.
3. Buka Supabase SQL Editor. Jalankan seluruh `supabase/003_upgrade_v2_0_1.sql`. **Jangan jalankan ulang 001_schema.sql pada database lama.** Migrasi tidak menghapus siswa, akun, QR, presensi, atau pesan. Migrasi menetapkan jeda global 5 detik dan jeda penerima sama 0 menit. Batas harian, jam kirim, status jeda, dan blokir lama tetap dipertahankan.
4. Ganti source proyek dengan isi folder `REEV_Presensi_v2.0.1`, kemudian redeploy di Vercel. Root Directory harus menunjuk folder yang memiliki `package.json`. Pertahankan environment Supabase milik Anda.
5. Pada environment server Vercel, isi `REEV_GATEWAY_URL=https://103.253.244.29:3000`, `REEV_API_KEY` sesuai gateway, `REEV_DEVICE_ID` sesuai perangkat yang terhubung, dan `CRON_SECRET`. Jika nilai environment berubah, redeploy lagi. Jangan gunakan awalan VITE_ untuk secret ini.
6. Perbarui scheduler dengan menjalankan `supabase/002_optional_scheduler.sql`. Aktifkan pg_cron dan pg_net lebih dahulu. Buat secret Vault `reev_worker_url` (URL produksi Vercel diakhiri `/api/wa-worker`) serta `reev_cron_secret` yang sama dengan CRON_SECRET Vercel. Job bernama `reev-wa-worker` diperbarui menjadi setiap 5 detik. Hentikan scheduler lain yang mengarah ke worker sama.
7. Masuk halaman WhatsApp. Klik **Aktifkan pengiriman**. Jika diblokir, periksa penyebab gateway dan gunakan **Buka blokir & aktifkan**. Pastikan Pengaturan mengaktifkan notifikasi orang tua dan data siswa memiliki nomor orang tua.
8. Buka scanner dan ketuk **Aktifkan suara** sekali. Bunyi contoh menandakan audio aktif. Bunyi keberhasilan hanya diputar sesudah server menyimpan presensi baru. Hasil baru berwarna hijau. Scan duplikat tetap menampilkan keterangan sudah tercatat tanpa bunyi keberhasilan baru.

Untuk instalasi baru: jalankan 001, lanjutkan 003, deploy, lalu pasang 002. Berkas 001 dipertahankan sebagai skema dasar historis, bukan satu-satunya SQL instalasi versi ini.

## Mengapa pesan antrean sebelumnya muncul?

Versi 2.0.0 mengembalikan teks yang sama untuk banyak kondisi: pause, blokir gateway, di luar jam, batas harian, jeda global, jeda penerima, atau antrean kosong. Teks tersebut muncul sebelum request ke gateway. Karena itu, memiliki gateway aktif saja tidak cukup.

Versi 2.0.1 memberikan alasan spesifik saat menekan Proses satu pesan. Hasilnya tampil di halaman, bukan hanya toast singkat. Tombol aktifkan/buka blokir kini sekaligus mengubah `wa_paused=false`.

| Kondisi | Tindakan |
| --- | --- |
| PAUSED | Klik Aktifkan pengiriman |
| BLOCKED | Periksa key, izin/perangkat, atau kuota gateway; lalu buka blokir |
| EMPTY | Periksa filter status, notifikasi orang tua dan nomor siswa. Scan yang sudah tercatat tidak membuat notifikasi baru |
| OUTSIDE_HOURS | Sesuaikan jam kirim dan zona waktu di Pengaturan |
| DAILY_LIMIT | Tunggu tanggal berikutnya atau sesuaikan batas harian |
| COOLDOWN | Tunggu sisa jeda yang ditampilkan |
| RECIPIENT_COOLDOWN | Isi jeda penerima 0 menit untuk mengikuti jeda global saja |
| CONFIG_MISSING | Isi environment server dan redeploy |
| UNKNOWN | Periksa log gateway sebelum mengantrekan ulang |

Pesan lama yang sudah FAILED, UNKNOWN, EXPIRED, atau CANCELLED tidak otomatis berubah menjadi PENDING. Tombol Ulangi hanya untuk FAILED/UNKNOWN yang masih berlaku dan belum mencapai tiga percobaan. Notifikasi yang dulu tidak dibuat karena nomor kosong atau notifikasi dimatikan tidak dibuat ulang oleh migrasi.

## Jeda 5 detik

Jeda minimum global di database kini 5 detik, termasuk jika beberapa worker dipanggil bersamaan. Pengiriman masih memerlukan scheduler aktif. Mengganti angka Pengaturan saja tidak mengubah scheduler satu menit menjadi lima detik.

Scheduler disetel 5 detik dengan pemeriksaan awal pause, jam, kuota, dan antrean. Database tetap memutuskan secara atomik pesan yang boleh diklaim. Jeda aktual bisa lebih panjang akibat waktu jaringan, jadwal scheduler, atau gateway. Ini bukan jaminan pesan tiba tepat setiap 5 detik. Nilai 0 menit untuk penerima sama berarti memakai jeda global, sehingga satu orang tua dengan beberapa anak tidak tertahan 30 menit.

Batas harian lama tetap dipertahankan, default awal 300 percobaan. Jika sekolah membutuhkan lebih banyak, ubah sesuai kebutuhan di Pengaturan. HTTP 429 tetap mengikuti batas gateway, tidak dilewati paksa.

Dokumentasi Supabase menyatakan interval detik membutuhkan Postgres 15.1.1.61 atau lebih baru. Jika proyek tidak mendukung, gunakan scheduler server gateway dengan interval 5 detik dan header Authorization Bearer CRON_SECRET. Jangan memakai cron lima kolom `*/5 * * * *` karena itu berarti lima menit.
Sumber: https://supabase.com/docs/guides/cron/quickstart

## Kontrak gateway dan HTTPS

Kontrak dipertahankan dari source 2.0.0:
- POST `/api/messages/send`.
- Header `Authorization: Bearer REEV_API_KEY` dan `Idempotency-Key` berisi ID antrean.
- JSON `recipient`, `message`, `deviceId`.
- HTTP sukses dengan JSON `success:true` berarti SENT (diterima gateway, bukan bukti diterima orang tua).

Halaman/API gateway belum dapat diverifikasi dari lingkungan penyusunan. Jika gateway Anda memakai endpoint, autentikasi, atau struktur lain, diperlukan dokumentasi API atau contoh request yang berhasil untuk menyesuaikannya. Jangan menyimpulkan gateway rusak hanya dari ketidaktersediaan akses ini.

Alamat IP dengan HTTPS memerlukan sertifikat tepercaya yang mencakup IP tersebut. Jika sertifikat hanya cocok untuk nama domain, gunakan domain yang sesuai pada REEV_GATEWAY_URL. Kode menampilkan keterangan TLS saat koneksi gagal. Verifikasi sertifikat tetap aktif. Pastikan perangkat WhatsApp terhubung dan port dapat diakses Vercel.

## Rollback

Jeda pengiriman, nonaktifkan job `reev-wa-worker` melalui Cron, lalu deploy kembali source 2.0.0. Fungsi lama `claim_notice()` tetap tersedia dengan kontrak lama. Jika perlu, set jeda global 60 dan jeda penerima 30 pada Pengaturan. Tidak perlu menghapus migrasi, menghapus tabel, atau memulihkan cadangan untuk rollback kode. Aktifkan kembali scheduler lama hanya setelah konfigurasi sesuai. Jangan mengulang pesan UNKNOWN tanpa memeriksa log gateway.
