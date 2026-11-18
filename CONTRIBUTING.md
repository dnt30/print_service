# Berkontribusi pada Print Service

Kontribusi berupa laporan bug, dokumentasi, pengujian printer, dan perubahan kode diterima. Gunakan bahasa Indonesia atau Inggris dan ikuti [kode etik](CODE_OF_CONDUCT.md).

## Melaporkan masalah dan mengusulkan fitur

- Cari issue yang sudah ada sebelum membuat laporan baru. Gunakan template bug atau usulan fitur di [GitHub Issues](https://github.com/dnt30/print_service/issues).
- Untuk bug, sertakan versi aplikasi, model ponsel, versi Android, model/protokol printer, lebar kertas, browser bila terkait, serta langkah reproduksi dan hasil yang diharapkan.
- Gunakan struk contoh dengan data buatan. Samarkan alamat Bluetooth/MAC, data pelanggan, URL privat, kredensial, dan isi transaksi pada log atau tangkapan layar.
- Ikuti [kebijakan keamanan](SECURITY.md) untuk kerentanan; jangan kirim rincian sensitif ke issue publik.
- Diskusikan perubahan besar atau dukungan protokol/platform baru melalui issue sebelum mengerjakannya.

## Menyiapkan lingkungan

1. Fork repositori lalu clone fork Anda dan buat branch untuk perubahan.
2. Pasang Flutter **3.50.0** (Dart **3.14.0**) atau versi kompatibel yang memenuhi `pubspec.yaml`. CI menggunakan Flutter 3.50.0.
3. Untuk Android, pasang Android SDK 36 dan JDK yang kompatibel dengan Gradle/AGP pada proyek. Lihat [panduan build](README.md#pengembangan-dan-build).
4. Jalankan `flutter doctor` dan `flutter pub get` dari root proyek.

`pubspec.lock` disertakan karena ini aplikasi. Commit perubahan lockfile hanya jika memang mengubah dependensi. `publish_to: 'none'` mencegah publikasi sebagai paket pub.dev; kode aplikasi tetap dapat dibagikan sebagai open source.

## Membuat perubahan

- Batasi setiap PR pada satu tujuan dan ikuti pola kode di sekitarnya.
- Tambahkan atau sesuaikan tes untuk perubahan perilaku yang memerlukannya. Perubahan dokumentasi cukup diperiksa tautan dan ketepatan isinya.
- Perbarui README dan [changelog](CHANGELOG.md) bila ada perubahan perilaku, dukungan printer, atau cara build.
- Jangan commit hasil build, `local.properties`, keystore, kata sandi, atau berkas konfigurasi pribadi.

Jalankan pemeriksaan Flutter berikut sebelum mengirim perubahan kode:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Untuk perubahan native Android, build debug terlebih dahulu agar Flutter menyiapkan berkas Gradle yang dihasilkan, lalu jalankan tes unit:

```powershell
flutter build apk --debug
cd android
.\gradlew.bat testDebugUnitTest
```

Pada Linux/macOS, gunakan `./gradlew testDebugUnitTest`. Tes instrumentasi memakai `connectedDebugAndroidTest` dan membutuhkan emulator; tes Chrome lintas aplikasi hanya boleh dijalankan pada emulator sekali pakai sesuai [README](README.md#pengembangan-dan-build).

Jika perubahan menyentuh koneksi atau hasil cetak, laporkan model printer, kertas 58/80 mm, dan hasil pengujian fisik. Nyatakan bila perangkat fisik tidak tersedia; kelulusan tes otomatis belum membuktikan hasil kertas.

## Mengirim pull request

Jelaskan masalah, perubahan perilaku, issue terkait, pemeriksaan yang dijalankan beserta hasilnya, dan keterbatasan yang masih ada. Lampirkan tangkapan layar untuk perubahan UI atau foto struk dengan data buatan bila relevan. CI menjalankan format Dart, analisis, dan tes Flutter; tes native/perangkat dilaporkan pada PR.

Dengan mengirim kontribusi, Anda menyetujui kontribusi tersebut didistribusikan menggunakan [lisensi MIT](LICENSE) proyek ini. Pastikan Anda berhak menyumbangkannya dan pertahankan atribusi serta lisensi kode/aset pihak ketiga.
