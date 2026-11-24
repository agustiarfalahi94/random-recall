# Release notes ("What's new" in the Play Console)

Play limits this to 500 characters per language. Paste the block for the version being
uploaded; the top block always matches the version currently in `pubspec.yaml`.

---

## 0.14.3 (56)

**en-US**

```
Compatibility update: Random Recall is now built for newer Android devices with 16 KB memory
pages, so it keeps working (and keeps installing) as phones and Play itself move to that format.
Smaller app download, too.

No feature changes.
```

**id-ID**

```
Pembaruan kompatibilitas: Random Recall kini dibangun untuk perangkat Android baru dengan
halaman memori 16 KB, jadi aplikasi tetap berjalan (dan tetap bisa dipasang) saat ponsel dan
Play beralih ke format tersebut. Ukuran unduhan juga lebih kecil.

Tidak ada perubahan fitur.
```

---

## 0.14.2 (55)

**en-US**

```
Ads now work properly: the banner loads on the first open instead of waiting for a reload,
and it fills the full width of your screen on tall phones.

Reminder scheduling and study features are unchanged. Smaller fixes under the hood keep
purchases out and the app ad-supported only.
```

**id-ID**

```
Iklan sekarang berjalan semestinya: banner muncul sejak pertama kali dibuka, tidak lagi
menunggu muat ulang, dan lebarnya memenuhi layar di HP bertubuh tinggi.

Jadwal pengingat dan fitur belajar tidak berubah. Perbaikan kecil di balik layar menjaga
aplikasi tetap tanpa langganan dan hanya didukung iklan.
```

---

## Notes for future releases

- Play requires the same `versionCode` to be uploaded only once; bump `version` in
  `pubspec.yaml` (`X.Y.Z+build`) for every upload, including re-uploads of a fixed build.
- Keep the three blocks (listing copy, this file, `CHANGELOG.md`) agreeing with each other.
  `CHANGELOG.md` is the developer-facing record; this file is the user-facing one.
