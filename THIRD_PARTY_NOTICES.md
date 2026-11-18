# Lisensi Pihak Ketiga

[Lisensi MIT proyek](LICENSE) berlaku untuk kontribusi asli Print Service. Dependensi, komponen SDK, dan aset pihak ketiga tetap mengikuti lisensi serta atribusi pemiliknya masing-masing.

## Dependensi utama

Ringkasan berikut diperiksa dari berkas `LICENSE` pada Flutter SDK dan cache paket yang digunakan proyek. Versi paket mengikuti `pubspec.lock` saat dokumen ini ditambahkan.

| Komponen | Versi yang diperiksa | Lisensi | Sumber |
| --- | --- | --- | --- |
| Flutter SDK | 3.50.0 | BSD-3-Clause | [Flutter LICENSE](https://github.com/flutter/flutter/blob/3.50.0/LICENSE) |
| material_ui | 1.11.0 | BSD-3-Clause | [Paket dan lisensi](https://pub.dev/packages/material_ui/versions/1.11.0/license) |
| cupertino_ui (transitif) | 1.1.6 | BSD-3-Clause | [Paket dan lisensi](https://pub.dev/packages/cupertino_ui/versions/1.1.6/license) |
| flutter_lints (pengembangan) | 6.0.0 | BSD-3-Clause | [Paket dan lisensi](https://pub.dev/packages/flutter_lints/versions/6.0.0/license) |
| flutter_launcher_icons (pengembangan) | 0.14.4 | MIT | [Paket dan lisensi](https://pub.dev/packages/flutter_launcher_icons/versions/0.14.4/license) |

Tabel ini merupakan ringkasan, bukan kumpulan lengkap pemberitahuan lisensi untuk distribusi biner. Dependensi transitif lainnya tercatat dalam `pubspec.lock`; dependensi native Android tercatat dalam konfigurasi Gradle dan dependensi SDK.

## Saat mendistribusikan aplikasi

- Sertakan `LICENSE` proyek serta teks lisensi dan atribusi pihak ketiga yang diwajibkan oleh komponen yang didistribusikan, termasuk dependensi transitif dan komponen native.
- Flutter mengumpulkan pemberitahuan lisensi paket ke aset hasil build. Periksa hasil build dan pastikan pemberitahuan tersebut ikut didistribusikan; ringkasan ini tidak menggantikan teks lisensi aslinya.
- Jika menambah atau memperbarui dependensi, periksa kembali berkas `LICENSE`/`NOTICE` miliknya dan perbarui ringkasan ini bila perlu.
- Sebelum menambahkan logo, font, gambar, atau contoh dari pihak lain, pastikan izin distribusinya dan sertakan atribusi yang diwajibkan.
