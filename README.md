# Flowly

Flowly adalah aplikasi pencatat keuangan pribadi yang dirancang untuk bekerja
offline. Data akun, transaksi, dan target tabungan tersimpan di SQLite lokal
pada perangkat.

## Fitur

- Catat pemasukan, pengeluaran, dan transfer antar akun.
- Kelola akun dan kategori transaksi.
- Buat target tabungan, catat setoran, dan pulihkan dana saat setoran dibatalkan.
- Cari dan filter transaksi berdasarkan jenis, tanggal, akun, atau kategori.
- Lihat saldo, ringkasan bulanan, dan grafik pengeluaran.
- Ekspor transaksi sebagai berkas CSV melalui menu berbagi perangkat.

## Menjalankan aplikasi

Persyaratan: Flutter SDK yang sesuai dengan batas versi pada `pubspec.yaml`,
Android SDK, dan Java yang disediakan/disarankan oleh Android Studio.

```shell
flutter pub get
flutter run
```

Jalankan pengujian dan analisis statis:

```shell
flutter test
flutter analyze
```

## Build Android

Build debug:

```shell
flutter build apk --debug
```

Build release untuk distribusi memerlukan keystore milik pemilik aplikasi.
Buat `android/key.properties` secara lokal (jangan commit atau bagikan berkas
ini) dengan nilai berikut:

```properties
storeFile=path/ke/keystore.jks
storePassword=isi-lokal
keyAlias=alias-keystore
keyPassword=isi-lokal
```

`storeFile` relatif terhadap folder `android/`. Tanpa `key.properties`, build
release tidak ditandatangani; debug key tidak digunakan untuk rilis.

Sebelum publikasi, ganti `applicationId` contoh
`com.example.projek_tugas_akhir` di `android/app/build.gradle.kts` dengan ID
unik milik aplikasi. Mengubah ID setelah distribusi akan membuat Android
mengenalinya sebagai aplikasi berbeda.
