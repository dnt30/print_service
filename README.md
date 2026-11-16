# Print Service

Aplikasi Flutter dengan layanan cetak native Android untuk printer POS **Bluetooth Classic SPP / ESC/POS**. Kertas default **58 mm**, dengan pilihan **80 mm** sebelum mencetak. Antarmuka berbahasa Indonesia, menyesuaikan layar ponsel dan tablet.

## Fitur

- Memilih perangkat Bluetooth yang sudah dipasangkan melalui pengaturan Android.
- Menyimpan hingga 30 printer, printer utama, ukuran kertas, serta 100 catatan cetak secara lokal.
- Dialog cetak teks dengan pratinjau, 58/80 mm, dan 1–5 salinan; tersedia struk uji.
- Android `PrintService`: printer muncul pada dialog cetak sistem setelah layanan diaktifkan. Dokumen PDF/HTML dirender menjadi raster ESC/POS, termasuk gambar dan teks Unicode.
- Menerima pekerjaan cetak dari Chrome, browser luar, dan aplikasi lain melalui dialog cetak Android. Website dibuka menggunakan browser bawaan ponsel.
- Antrean cetak bersama untuk mencegah data dari dua pekerjaan bercampur, batas waktu koneksi/tulis, dan pembatalan pekerjaan melalui antrean cetak Android.
- Pemotong otomatis opsional; nonaktif secara default.

## Penggunaan di ponsel

1. Nyalakan printer dan pasangkan melalui **Pengaturan Android → Bluetooth**. Beberapa printer meminta PIN dari manual perangkat.
2. Pasang APK, buka aplikasi, ketuk **Pilih printer**, dan izinkan **Perangkat terdekat** bila diminta. Pilih printer POS dari daftar. Daftar ini mencakup perangkat berpasangan; aplikasi tidak menganggap semua perangkat Bluetooth sebagai printer.
3. Gunakan **Tes printer**. Pilih kertas yang sesuai dengan printer fisik, lalu cetak.
4. Buka **Pengaturan → Buka pengaturan cetak**, aktifkan **Print Service · Bluetooth POS**.
5. Buka website kasir langsung di **Chrome atau browser luar lain**. Tombol **Buka browser** di aplikasi hanya membantu membuka URL pada browser bawaan ponsel; aplikasi tidak memiliki browser internal.
6. Tekan tombol Cetak website yang menjalankan `window.print()`. Jika browser meneruskan panggilan tersebut ke sistem, dialog cetak Android akan terbuka. Jika browser tidak merespons, gunakan **menu browser → Bagikan → Cetak** (urutan menu dapat berbeda).
7. Pada dialog Android, pilih daftar printer / **Semua printer**, lalu printer POS yang sudah ditambahkan melalui aplikasi. Pilih media **POS 58 mm** atau **POS 80 mm**, jumlah salinan dan halaman, lalu tekan Cetak. Aplikasi Print Service tidak harus berada di layar depan.

Printer tersimpan berarti pernah dipilih, bukan koneksi yang terus aktif. Aplikasi membuat koneksi ketika pekerjaan dikirim. Status **Terkirim** berarti data berhasil ditulis ke Bluetooth, bukan bukti bahwa kertas sudah keluar. Setelah kegagalan atau pembatalan, sebagian struk mungkin sudah tercetak; periksa hasil sebelum mengulang.

## Integrasi website

Alur utama adalah **website di browser luar → dialog cetak Android → Print Service → Bluetooth ESC/POS**. Aplikasi bertindak sebagai penyedia printer Android, bukan pengganti JavaScript browser. Website dapat memakai API standar:

```html
<button type="button" onclick="window.print()">Cetak struk</button>
```

Dukungan `window.print()` ditentukan browser dan versinya. `PrintService` baru menerima dokumen setelah browser membuat pekerjaan cetak pada Android dan pengguna memilih printer. Memasang aplikasi ini tidak dapat mengubah browser yang mengabaikan JavaScript print. Untuk browser tersebut, gunakan menu cetak bawaannya. Chrome mendokumentasikan jalur **Menu → Bagikan → Cetak** pada [panduan resmi Android](https://support.google.com/chrome/answer/1069693?co=GENIE.Platform%3DAndroid&hl=en).

Tidak ada injeksi JavaScript, jembatan WebView, layanan aksesibilitas, server cetak jaringan, atau pengambilan alih browser. Aplikasi tidak menerima data website secara langsung dan tidak melakukan cetak diam-diam. Untuk mengirim otomatis dari website tanpa memakai fasilitas cetak browser, diperlukan integrasi eksplisit pada website; hal tersebut belum diimplementasikan.

Contoh struk responsif: [`examples/receipt.html`](examples/receipt.html). Sajikan berkas ini pada website Anda lalu buka di Chrome Android. Hindari lebar A4 tetap pada CSS struk; gunakan lebar konten relatif. Dialog sistem menetapkan media 58/80 mm dengan tinggi halaman 300 mm; struk panjang dipaginasi. Renderer menghapus area kosong akhir halaman untuk menghemat kertas. URL HTTP lokal untuk kasir LAN juga dapat dibuka melalui browser bawaan.

**Batas platform:** hanya browser/aplikasi yang mendukung Android Print Framework dapat memakai penyedia printer ini. Bluetooth BLE/GATT, printer non-ESC/POS, iOS, dan AirPrint belum diimplementasikan. Build web adalah pratinjau UI dan tidak menyediakan koneksi Bluetooth Classic.

## Pengembangan dan build

- Flutter **3.50+**, Dart **3.14+**, Android SDK 36; minimum Android 7.0 / API 24.
- Gradle 9.5, Android Gradle Plugin 9.3.1; gunakan JDK kompatibel (Android Studio JBR 25 pada mesin ini).
- UI menggunakan paket `material_ui` dari template Flutter. Kanal native dan layanan cetak memakai API Android. Tidak ada dependensi browser/WebView pada aplikasi.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d <id-android>
flutter build apk --debug
```

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`. Build debug cocok untuk pengujian perangkat. Sebelum distribusi produksi, gunakan application ID milik Anda dan konfigurasi keystore release (template masih memakai penandatanganan debug).

Untuk APK dengan optimasi dan ukuran lebih kecil:

```sh
flutter build apk --release --split-per-abi
```

Hasil di `build/app/outputs/flutter-apk/`: `app-arm64-v8a-release.apk` untuk mayoritas ponsel Android modern, `app-armeabi-v7a-release.apk` untuk ARM 32 bit, dan `app-x86_64-release.apk` untuk emulator/perangkat x86. Sertifikatnya masih debug milik lingkungan pengembangan; APK ini untuk uji lokal, belum untuk publikasi Play Store.

Pengujian encoder native:

```powershell
cd android
.\gradlew.bat testDebugUnitTest
```

Pengujian pada emulator yang sudah menyala:

```powershell
cd android
.\gradlew.bat connectedDebugAndroidTest
```

Tes perangkat memeriksa deklarasi layanan, persistensi dengan penyimpanan terpisah, pemilihan halaman PDF dan penghapusan area kosong, serta Intent browser luar. Tes lintas aplikasi membuka halaman uji HTTP loopback di Chrome asli, mencoba tombol `window.print()` atau menu Chrome, dan memeriksa dialog cetak Android. Tes Chrome dijalankan hanya pada emulator sekali pakai; gunakan bahasa antarmuka Inggris. Server loopback hanya ada dalam APK pengujian, ditutup setelah tes, dan tidak disertakan pada aplikasi utama. Pengujian ini tidak mengirim data ke printer fisik.

Pratinjau browser:

```sh
flutter run -d chrome
flutter build web
```

## Struktur

| Lokasi | Tanggung jawab |
| --- | --- |
| `lib/src/app.dart` | UI responsif, pemilihan printer, dialog cetak, pratinjau, riwayat |
| `lib/src/print_controller.dart` | State Flutter dan kontrak MethodChannel |
| `android/.../MainActivity.kt` | Perizinan dan jembatan Flutter → Android |
| `android/.../PosPrintService.kt` | Penemuan printer dan antrean cetak sistem |
| `android/.../BrowserLauncher.kt` | Intent pembukaan URL melalui browser luar |
| `android/.../BluetoothTransport.kt` | Koneksi SPP, antrean, timeout, pembatalan |
| `android/.../EscPos.kt` | Render teks/PDF per potongan kecil ke ESC/POS |
| `android/.../RasterEncoder.kt` | Pengemasan bitmap 1 bit yang diuji tanpa perangkat |
| `android/.../StateStore.kt` | Preferensi dan riwayat lokal bersama |

Konten cetakan tidak disimpan dalam riwayat; hanya judul, nama printer, waktu, kertas, dan status. Backup aplikasi dinonaktifkan. Cookie, login, sesi, dan navigasi website dikelola browser luar. Layanan hanya menampilkan perangkat yang sudah ditambahkan sebagai printer dalam aplikasi, sehingga perangkat berpasangan lain seperti headset tidak ikut tampil.

## Verifikasi perangkat fisik

Pengujian otomatis mencakup UI ukuran ponsel/tablet, dialog dan payload cetak, error Bluetooth, validasi URL, serta byte raster ESC/POS. Validasi hasil kertas tetap memerlukan printer nyata: uji kedua lebar kertas pada model yang sesuai, cetak logo/gambar, putuskan koneksi saat cetak, dan pastikan pengulangan tidak menggandakan transaksi. Lebar area cetak yang digunakan adalah 384 dot untuk 58 mm dan 576 dot untuk 80 mm; model dengan resolusi/protokol lain perlu penyesuaian.

Verifikasi versi 1.1.0: **10 tes Flutter, 4 tes unit encoder, dan 6 tes Android pada emulator lulus**. Pada Chrome **157.0.8103.78**, tombol `window.print()` dari halaman di browser luar langsung membuka dialog cetak Android; layanan Print Service terdaftar dalam sistem. Pengujian lintas aplikasi tidak memakai WebView. Build debug, release per arsitektur, dan web berhasil. Belum ada pengujian dengan printer fisik.

Referensi: [Android PrintService](https://developer.android.com/reference/android/printservice/PrintService), [cetak dari Chrome Android](https://support.google.com/chrome/answer/1069693?co=GENIE.Platform%3DAndroid&hl=en), dan [izin Bluetooth](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions).
