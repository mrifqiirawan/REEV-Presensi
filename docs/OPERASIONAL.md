# Panduan admin dan guru

## Peran

Admin mengelola data, akun, pengaturan, rekap, WhatsApp, dan pemeliharaan. Guru
membuka Scan QR setelah login dan dapat berpindah ke Presensi manual. Semua guru
aktif dapat memindai semua kelas aktif pada semester yang dipilih admin. Wali kelas
menentukan tujuan notifikasi wali, bukan membatasi scanner pada satu kelas.

Nonaktifkan akun melalui edit akun. Token lama tetap ditolak oleh fungsi database
karena status aktif dibaca pada setiap pencatatan dan kebijakan RLS. Admin aktif
terakhir dilindungi trigger; akun sendiri tidak dapat diturunkan/nonaktifkan lewat API.
Password diubah oleh admin pada kolom password baru; kosong berarti tidak diubah.
Perubahan password tidak dijanjikan mengakhiri seluruh JWT yang sudah terbit.
Untuk segera memblokir akses, nonaktifkan akun. Tidak tersedia tombol pencabutan
semua sesi per akun pada rilis ini; Keluar menutup sesi perangkat saat ini.

## Data & penugasan

Urutan kerja: akun guru → tahun/semester → kelas/wali → siswa → semester aktif.
Semester memuat tahun ajaran sehingga tidak diperlukan tab tahun yang terpisah.
Satu siswa memiliki satu kelas aktif saat ini. Riwayat menyimpan snapshot nama,
NISN, kelas, dan semester saat pencatatan. Mengubah nama/kelas tidak mengubah
snapshot riwayat. Mengganti tahun/semester dan memindahkan siswa dilakukan admin.

Form pilihan relasi menampilkan maksimal 30 pilihan dan mencari di server.
Tabel menggunakan 25 baris per halaman. Tidak ada tombol CSV generik pada setiap
menu; CSV digunakan untuk impor, template, dan ekspor rekap sesuai kebutuhan.

## CSV siswa

Gunakan template `public/templates/template-siswa.csv`:

```csv
nisn,name,birthDate,address,parentName,contact,qr
```

- NISN tepat 10 digit, format kolom TEXT di Excel agar nol tidak hilang.
- Nama wajib. `birthDate` opsional dengan format YYYY-MM-DD; alamat opsional.
- `parentName` dan `contact` untuk orang tua/wali. `parentPhone` juga diterima.
- Nomor berawalan 0 dinormalisasi menjadi 62. Nomor kosong berarti tanpa pesan.
- `qr` kosong → token acak baru. Isi teks/URL lama secara persis untuk mempertahankan kartu.
  URL adalah isi QR, bukan perintah redirect saat scan. Tidak ada pengambilan data dari URL tersebut.
- Pilih kelas tujuan satu kali di dialog impor. Maksimal 200 siswa / 500 KB.
- CSV koma/titik koma, BOM, sel bertanda kutip, dan baris baru dalam sel didukung.
- Penyimpanan siswa satu transaksi: jika salah satu bentrok NISN/QR, seluruh file
  tersebut ditolak. Tidak menimpa siswa yang sudah ada. Koreksi file lalu impor ulang.

## CSV guru

```csv
username,name,password,phone
```

Username 3–40 karakter (huruf kecil, angka, titik, garis bawah, tanda minus).
Password 12–128 karakter. Maksimal 100 akun/file. Semua akun hasil CSV adalah GURU;
untuk admin gunakan tambah/edit satu akun. Password tidak ditampilkan di pratinjau.

Akun dibuat satu per satu. Progres yang sudah berhasil tetap tersimpan bila baris
berikutnya gagal. Lanjutkan dari dialog yang sama setelah menyelesaikan masalah.
Jika request terakhir mengalami timeout, periksa daftar akun terlebih dahulu: akun
mungkin telah berhasil dibuat. Tutup dialog dan buat file sisa tanpa akun yang sudah
ada. Tidak ada overwrite password otomatis ketika username bentrok. Simpan CSV
password secara privat dan hapus setelah distribusi akun selesai sesuai aturan sekolah.

## Presensi dan kamera

Pagi, pelajaran, dan sore mengikuti waktu server yang dikonversi ke zona sekolah.
Jadwal harus berurutan dan tidak tumpang tindih. Di luar jadwal, pencatatan ditolak.
Scan QR selalu HADIR, manual menyediakan empat status. ALPA tidak dibuat otomatis
untuk siswa yang tidak memindai. Presensi yang sudah ada tidak diubah oleh scan/manual
berikutnya pada sesi yang sama. Rilis ini tidak menyediakan koreksi riwayat di UI.

Kamera meminta izin browser. Setelah izin diberikan, guru langsung melihat scanner
saat login berikutnya, sejauh izin perangkat masih berlaku. Jika autoplay/kamera
bermasalah, ketuk Kamera untuk memulai ulang. Tidak ada unggah foto atau input QR
teks pada alur guru. Hindari webview WhatsApp; buka langsung di Chrome/Safari.
Pergantian halaman dan Keluar menghentikan semua track kamera.

Kartu per siswa atau 25 siswa yang tampil dapat dicetak. Pada dialog print gunakan
A4, skala 100%; periksa satu kartu fisik sebelum mencetak banyak. Guru mendapatkan
hasil hanya setelah server mengonfirmasi penyimpanan. Tidak ada antrean offline.

Pada scanner, ketuk Aktifkan suara sekali. Presensi baru yang berhasil tersimpan membunyikan dua nada dan mengubah kotak HASIL TERAKHIR menjadi hijau.

## WhatsApp

Setelah migrasi 003: jeda global 5 detik, batas harian lama dipertahankan (default awal 300), jeda nomor sama 0 menit,
jam 06:00–20:00, kedaluwarsa 12 jam, pengiriman dijeda hingga admin mengaktifkan.
Batas tersebut aturan aplikasi, bukan jaminan bebas blokir atau kapasitas resmi WA.

PENDING menunggu. SENT diterima gateway. FAILED penolakan HTTP 4xx selain 408. UNKNOWN
berarti hasil belum pasti, termasuk worker yang terhenti setelah reservasi. EXPIRED
melewati masa berlaku. CANCELLED adalah pesan backup yang dibatalkan saat restore.
401/403/429 memblokir antrean sampai admin memeriksa gateway dan membuka blokir.

Tidak ada retry otomatis. Ulang manual hanya untuk FAILED/UNKNOWN, maksimal tiga
percobaan, selama belum kedaluwarsa. Pastikan pesan belum terkirim pada log gateway.
Header Idempotency-Key dipasang, tetapi kemampuan deduplikasi tetap tergantung gateway.
Notifikasi wali kelas dapat tertahan karena batas penerima sama. 300 siswa × tiga
sesi × satu penerima bisa menghasilkan 900 pesan, melebihi kuota default 300.

Sebelum reset/restore, jeda pengiriman dan tunggu setidaknya 30 detik agar request
worker yang sedang berjalan selesai. Pesan yang sudah diterima gateway tidak dapat
ditarik kembali. Kuota harian dan waktu percobaan global disimpan di `wa_state` dan
bertahan setelah reset. Riwayat jeda per penerima berasal dari outbox, sehingga
reset outbox menghapus riwayat jeda penerima; gunakan jeda pengiriman saat pemeliharaan.

## Backup dan pemulihan

1. Jeda WA, pastikan tidak ada pencatatan aktif bila hendak mereset.
2. Unduh backup baru. Pilih kembali file unduhan yang sama untuk verifikasi.
3. Bukti backup berlaku 30 menit dan satu operasi. Jika presensi/antrean berubah,
   unduh ulang. Browser tidak dapat membuktikan file tersimpan permanen; pemilihan
   kembali file memastikan operator memiliki salinan yang sama saat operasi.
4. Reset meminta ketikan RESET, menghapus presensi/antrean, mempertahankan master.
5. Restore meminta PULIHKAN, mengganti master/presensi secara atomik. File harus
   format REEV-2 dari proyek yang sama. Foreign key memeriksa keberadaan akun referensi.
6. Notifikasi hasil restore dibatalkan semua dan pengiriman dijeda.

Backup tidak mencakup password/token Supabase Auth, audit, receipt, secret lingkungan,
atau snapshot konfigurasi platform. Informasi profil disertakan sebagai referensi saja;
profil/akun tidak ditimpa saat restore. Backup JSON bukan pengganti disaster recovery
seluruh proyek. Simpan juga prosedur backup database/Auth sesuai fasilitas Supabase.
Batas aplikasi 3 MB; jika terlampaui, aplikasi menolak membuat receipt/reset dan
memerlukan backup melalui tooling Supabase (misalnya pg_dump).

## Checklist penerimaan setelah deploy

- [ ] Login admin; buka semua menu dan ubah identitas/warna.
- [ ] Buat guru, periode, kelas dan siswa uji; tetapkan semester aktif.
- [ ] Impor CSV dengan nol awal NISN; coba file duplikat dan periksa tidak ada salinan.
- [ ] Login guru di Android/iOS: kamera aktif setelah izin, langsung layar scanner.
- [ ] Scan kartu uji dan pindai bersamaan pada dua HP; hanya satu record per sesi.
- [ ] Manual SAKIT untuk siswa lain; pastikan scan berikutnya tidak menimpa catatan.
- [ ] Coba akun nonaktif: pencatatan ditolak.
- [ ] Cetak kartu dan pindai cetakan; uji header/logout pada layar sempit.
- [ ] Rekap sesuai filter; ekspor lebih dari 25 baris mencakup semua hasil.
- [ ] WA satu pesan uji pada nomor sendiri; periksa request, response, cooldown,
      scheduler, dan arti SENT pada gateway sebenarnya.
- [ ] Backup dan restore pada data uji; tidak ada kirim ulang notifikasi historis.
- [ ] Keluar: kembali ke login dan indikator kamera mati.
