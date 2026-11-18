# Kebijakan Keamanan

## Versi yang didukung

Perbaikan keamanan ditujukan untuk rilis stabil terbaru. Pengguna versi lama sebaiknya memperbarui sebelum melaporkan masalah. Proyek dikelola secara sukarela dan belum menjanjikan batas waktu respons atau program bug bounty.

## Melaporkan kerentanan

Gunakan [pelaporan kerentanan privat GitHub](https://github.com/dnt30/print_service/security/advisories/new) melalui **Security → Advisories → Report a vulnerability** bila fitur tersebut sudah diaktifkan.

Jika tombol tersebut belum tersedia, hubungi maintainer [@dnt30](https://github.com/dnt30) melalui kanal privat yang tersedia pada profilnya. Jika belum ada, buat issue singkat berjudul **Permintaan kanal pelaporan keamanan** tanpa rincian kerentanan, lalu tunggu kanal privat dari maintainer. Jangan lampirkan eksploit, kredensial, dokumen pelanggan, atau data transaksi pada issue/PR publik.

Dalam laporan privat, sertakan:

- Versi aplikasi atau commit, versi Android, serta model perangkat/printer bila terkait.
- Ringkasan dampak dan kondisi yang diperlukan.
- Langkah reproduksi minimal menggunakan data buatan.
- Log yang sudah disamarkan dan usulan mitigasi bila ada.

Uji hanya pada perangkat dan dokumen yang Anda miliki atau diizinkan untuk diuji. Koordinasikan publikasi rincian teknis dengan maintainer setelah laporan ditinjau dan perbaikan tersedia.

## Catatan untuk maintainer

Sebelum membuka repositori ke publik, aktifkan **Private vulnerability reporting** di pengaturan keamanan GitHub dan pastikan kanal tersebut dapat digunakan. Lihat [panduan resmi GitHub](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository).
