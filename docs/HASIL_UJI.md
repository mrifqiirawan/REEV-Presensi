# Hasil uji REEV Presensi 2.0.3

Lingkungan: Node.js 24.19.0; dependency sesuai package-lock.json. Fokus: kompatibilitas impor CSV dari 2.0.2.

| Pemeriksaan | Status | Bukti/batas |
|---|---|---|
| Instalasi lockfile | PASS | npm ci --no-audit --no-fund |
| Unit/regresi | PASS | npm test: 12 tes lulus; 5 tes baru CSV serta tes domain, database PGlite dan worker bawaan |
| Build produksi | PASS | npm run build; Vite 7.3.7 |
| CSV petik, BOM, koma/titik koma, multiline | PASS | tests/csvImport.test.mjs memakai parser yang sama dengan UI |
| Nol NISN/WA, tanggal ISO dan M/D/YYYY | PASS | Fixture sintetis; validasi tanggal kalender dan penolakan formula tetap berlaku |
| Duplikasi setelah normalisasi | PASS | Seluruh file ditolak; tidak mengirim baris parsial |
| 7A.csv asli | PASS (validasi) | 32 siswa; 31 valid satu per satu; tepat satu error NISN pada baris 13. Seluruh file ditahan sampai diperbaiki; digit 31 baris sesuai asli |
| Browser/perangkat, Supabase produksi, deploy Vercel | NOT_RUN | Tidak tersedia sesi proyek produksi; tidak ada klaim data tersimpan/live |

Tes PGlite dan mock worker adalah regresi lokal, bukan bukti Auth hosted atau WA nyata. Tidak ada perubahan skema, autentikasi, RLS atau gateway pada rilis ini. File siswa asli tidak dikemas.
