# Upgrade REEV Presensi 2.0.2 → 2.0.3

Rilis ini memperbaiki pembacaan CSV. Tidak ada perubahan dependensi atau skema database.

## Perubahan
- NISN dan nomor WhatsApp menerima teks biasa atau teks dibungkus tanda petik ganda, misalnya `"0012345670"`. Dalam file CSV hasil Excel, nilai tersebut dapat tampil sebagai `"""0012345670"""`; parser menangani pembungkus CSV dan aplikasi membersihkan satu pasang petik pada nilainya.
- NISN diproses sebagai string, tanpa konversi ke angka; nol awal dan akhir dipertahankan. NISN tetap wajib tepat 10 digit.
- WA tetap menggunakan normalisasi lama: `08…` menjadi `628…`; nol akhir tidak dibuang. Huruf/formula/karakter tidak valid tetap ditolak.
- Tanggal lahir menerima `YYYY-MM-DD` atau `M/D/YYYY` (bulan/hari/tahun). Contoh `2/8/2014` berarti **8 Februari 2014**, bukan 2 Agustus. Tanggal kalender tidak valid tetap ditolak.
- Nomor WA pada impor guru juga menerima pembungkus petik; nama, alamat, QR dan password tidak dibersihkan dengan aturan identifier.
- Duplikasi NISN dicek setelah normalisasi. Jika ada satu baris tidak valid, seluruh file belum dapat diimpor.

## Memperbarui aplikasi
1. Ekstrak ZIP dan gunakan source versi 2.0.3 untuk mengganti source aplikasi pada repository Vercel yang sama. Pertahankan environment variables proyek.
2. Jalankan `npm ci`, `npm test`, dan `npm run build` bila menguji secara lokal; lalu deploy ulang melalui alur Vercel yang biasa digunakan.
3. Untuk upgrade dari 2.0.2 yang sudah terpasang lengkap, **tidak perlu menjalankan SQL/migrasi baru atau reset database**. Panduan instalasi awal dan upgrade versi lama tetap tersedia di dokumen sebelumnya.
4. Setelah deploy, muat ulang halaman. Buka Data → Siswa → Impor CSV, pilih kelas tujuan, pilih CSV, periksa pratinjau lalu mulai impor.
5. Impor tetap menambah data baru (bukan upsert). Data dengan NISN yang sudah ada akan ditolak database; jangan mengimpor ulang siswa yang sudah tersimpan.

## Hasil pemeriksaan file 7A.csv
32 baris siswa dibaca (baris kosong diabaikan). Sebanyak 31 baris valid saat diperiksa satu per satu; NISN dan WA sesuai digit asli. Satu baris, yaitu baris CSV 13, berisi NISN `"0"`; ganti dengan NISN 10 digit yang benar sebelum mengimpor seluruh file. Aplikasi tidak menebak identifier yang hilang. File asli tidak diubah dan data siswa tidak disertakan dalam paket distribusi.

Tanda petik di CSV tidak menjamin Excel selalu mempertahankan format ketika dibuka dan disimpan ulang. Atur kolom NISN/WA sebagai **Text/Teks** sejak memasukkan data. Angka nol yang sudah hilang dari file tidak dapat dipulihkan otomatis dengan pasti.

## Rollback dan batas uji
Untuk rollback, deploy ulang source 2.0.2. Tidak ada migrasi untuk dibalik; data yang sudah diimpor tetap tersimpan. Build dan pengujian lokal sudah dijalankan, tetapi deployment Vercel, impor melalui browser, dan penyimpanan ke Supabase produksi belum dijalankan.
