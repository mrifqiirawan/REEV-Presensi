# REEV Presensi 2.0.2

## Pasang upgrade

1. Jika sudah menggunakan v2.0.1, jalankan `supabase/004_upgrade_v2_0_2.sql` pada Supabase SQL Editor. Jika masih v2.0.0, jalankan 003 dahulu, kemudian 004. Jangan jalankan ulang 001 pada database lama.
2. Ganti source dengan isi folder versi 2.0.2 lalu redeploy Vercel. Pertahankan environment Supabase dan gateway.
3. Untuk pengiriman otomatis, aktifkan extension pg_net dan pg_cron di Supabase. Isi dua secret di Supabase Vault:
   - `reev_worker_url`: URL produksi aplikasi, contoh `https://NAMA-APP.vercel.app/api/wa-worker`.
   - `reev_cron_secret`: nilai yang sama persis dengan CRON_SECRET pada environment server Vercel.
4. Jalankan `supabase/005_enable_automation.sql`. Berkas ini memeriksa konfigurasi dasar lalu memasang/memperbarui scheduler 5 detik. Tidak perlu menjalankan 002 lagi. Pastikan hanya satu scheduler aktif.
5. Pada Pengaturan, aktifkan Kirim ke orang tua/wali dan hilangkan centang Jeda seluruh pengiriman. Sesuaikan jam kirim dan zona waktu. Jika ada blokir gateway, periksa penyebabnya lalu gunakan Buka blokir & aktifkan.
6. Pastikan REEV_GATEWAY_URL, REEV_API_KEY, REEV_DEVICE_ID dan CRON_SECRET benar pada environment Vercel. Setelah mengubah environment, redeploy.

Instalasi baru: 001 → 003 → 004 → deploy → konfigurasi Vault/extension → 005.

## Reset data operasional

Penyebab error sebelumnya adalah DELETE tanpa WHERE pada fungsi reset. Versi ini memakai WHERE eksplisit pada penghapusan seluruh presensi. Relasi database menghapus antrean terkait secara otomatis. Backup dan verifikasi tetap wajib; pemeriksaan tersebut tidak dilewati.

Urutan percobaan satu ID card:
1. Unduh backup baru, lalu pilih kembali file yang sama untuk verifikasi.
2. Klik Reset presensi & antrean, ketik RESET, kemudian konfirmasi.
3. Buka scanner dan pindai ID card yang sama. Catatan baru dapat dibuat untuk sesi yang sama setelah reset.

Reset ini menghapus SEMUA presensi dan antrean, bukan hanya satu siswa. Siswa, kelas, akun, ID QR, template pesan, status aktif/jeda pengiriman, dan penghitung batas harian tetap tersimpan. Jika pesan baru saja diproses, tunggu 30 detik sebelum reset. Jika worker mengubah antrean setelah backup dibuat, unduh dan verifikasi backup baru. Pesan yang telah diterima gateway tidak bisa ditarik kembali melalui reset.

Perintah DELETE pada fungsi pemulihan juga diperbarui. Pemulihan tetap menjeda pengiriman dan membatalkan pesan hasil restore. Backup lama yang belum memiliki template pesan memakai template bawaan.

## Template pesan di Pengaturan

Kolom Template pesan orang tua dapat diubah hingga 3.000 karakter. Pratinjau memakai data contoh. Tekan Simpan pengaturan untuk menerapkan.

Contoh:
```
Assalamu'alaikum Bapak/Ibu {orang_tua}.

Kami informasikan presensi putra/putri Anda:
Nama: {nama}
Kelas: {kelas}
Sesi: {sesi}
Status: {status}
Waktu: {waktu} ({zona_waktu})

Terima kasih.
{sekolah}
```

Placeholder tersedia: {aplikasi}, {sekolah}, {nama}, {kelas}, {sesi}, {status}, {waktu}, {zona_waktu}, {orang_tua}. Placeholder yang tidak dikenal tetap menjadi teks biasa. Template berlaku untuk pesan baru, termasuk notifikasi wali kelas jika fitur tersebut diaktifkan. Pesan yang sudah masuk antrean tidak diubah.

## WhatsApp otomatis setelah scan

Setelah presensi baru tersimpan, database membuat pesan antrean dan memicu worker melalui pg_net setelah transaksi commit. Tidak perlu membuka halaman WhatsApp atau menekan Proses satu pesan. Pengiriman tidak bergantung pada tab scanner yang tetap terbuka.

Antrean tetap mengikuti urutan, jeda global minimal 5 detik, jam kirim, batas harian, dan respons gateway. Scheduler melanjutkan pesan yang tertahan jeda. Jika masih ada pesan lama, pesan baru menunggu giliran. Scan duplikat tidak membuat notifikasi baru. Bunyi scan menandakan presensi tersimpan, bukan bukti WhatsApp diterima orang tua.

Jika konfigurasi otomatis belum tersedia, presensi tetap tersimpan dan pesan tetap PENDING. Admin dapat melihat audit WA_AUTO_CONFIG atau WA_AUTO_UNAVAILABLE di Supabase. Untuk kegagalan HTTP, periksa net._http_response dan log Vercel. Status Cron sukses tidak membuktikan HTTP berhasil. Pastikan deployment protection tidak menghalangi endpoint worker.

Vault dan schema net tidak boleh diekspos ke Data API. Secret worker bukan service_role key. Verifikasi TLS gateway tetap aktif. Kontrak API gateway tetap sama seperti v2.0.1 dan belum diverifikasi pada server nyata.

## Suara otomatis

Tombol Aktifkan suara dihapus. Audio dipersiapkan saat aplikasi dibuka dan dibuka izinnya melalui interaksi biasa, seperti mengetik/login atau membuka menu. AudioContext tetap tersedia saat berpindah halaman sehingga bunyi tidak perlu diaktifkan lagi di scanner.

Browser tertentu membatasi suara sebelum interaksi pengguna. Pada sesi yang langsung pulih setelah reload, sentuh bagian mana saja pada halaman jika browser masih memblokir audio. Ini batas browser, bukan pengaturan aplikasi yang dapat dipaksa. Bunyi hanya untuk presensi baru yang berhasil tersimpan; duplikat tidak berbunyi. Pastikan volume perangkat aktif.

## Status dan rollback

Source ditinjau secara statis. Build, tes aplikasi, eksekusi SQL, kamera/audio perangkat, pengiriman gateway nyata, dan deployment tidak dijalankan sesuai preferensi sebelumnya. Tidak ada klaim sudah bekerja di akun produksi.

Untuk rollback: jeda pengiriman, nonaktifkan Cron reev-wa-worker, dan nonaktifkan trigger dengan SQL `alter table public.outbox disable trigger outbox_wake_worker;`, lalu deploy kembali source v2.0.1. Kolom template dapat tetap ada. Untuk kembali ke v2.0.2, aktifkan trigger dengan `alter table public.outbox enable trigger outbox_wake_worker;`, aktifkan Cron dan pengiriman kembali. Tidak perlu menghapus tabel.

Referensi:
- https://supabase.com/docs/guides/database/extensions/pg_net
- https://supabase.com/docs/guides/cron/quickstart
- https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay
