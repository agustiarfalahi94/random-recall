# Play Store listing — Random Recall

Copy-paste source of truth for the Play Console. Assets live in `store/assets/`; the raw device
captures they were built from are in `store/raw/` (regenerate with `tools/make_store_graphics.py`
and `tools/make_store_screenshots.py`).

Package: `com.inkpebble.randomrecall` · Category: **Education** · Price: **Free, contains ads**

---

## App name (max 30)

```
Random Recall: Daily Practice
```

## Short description (max 80)

```
Turn your own notes into daily recall drills. Streaks, stats, offline.
```

Count: 69 characters.

## Full description (max 4000) — English

```
Random Recall turns the notes you already keep into a few seconds of daily practice.

Write your own questions and answers — interview prep, a language you are learning,
a course you are taking, exam facts — and the app brings one back at random, as often
as you want, until it actually sticks.

WHY IT WORKS
Answering from memory (retrieval practice) is one of the most reliable ways to remember
something. Re-reading a note feels productive but does very little. Random Recall makes
the effective method the easy one.

HOW IT WORKS
1. Add a question and its answer. Group them by topic — coffee, cooking, networking,
   whatever you are studying.
2. Choose when the reminders arrive: which days, what hours, and how many per day.
3. When a notification lands, answer it in your head, then reveal the answer and mark
   whether you got it.
4. Watch the streak and the per-topic statistics build up.

WHAT IS INSIDE
• Your own question bank, unlimited topics and questions
• Reminder scheduling from a few to many times per day, on the days you choose
• Practice anytime from the home screen, without waiting for a notification
• 7-day and 14-day challenge modes with badges and titles
• Per-topic analytics: accuracy, attempts, weak spots
• Streaks, undo, and an interactive first-run tour
• Optional account with cloud backup, so a new phone does not start from zero
• Works offline; your questions stay on the device until you choose to sync
• English and Bahasa Indonesia

HONEST ABOUT THE MODEL
One full version. No subscription, no in-app purchases, no locked features, no limits on
how many questions you can add. The app is supported by ads only, so the occasional banner
is what keeps it free.

PRIVACY
Your questions are stored locally. An account is optional and only used for backup and
sync. Nothing is sold.

Questions, feedback or a bug? Send it from Settings → Send feedback inside the app.
```

## Full description (max 4000) — Bahasa Indonesia

```
Random Recall mengubah catatan yang sudah kamu punya menjadi latihan singkat setiap hari.

Tulis pertanyaan dan jawabanmu sendiri — persiapan interview, bahasa yang sedang dipelajari,
materi kuliah, atau fakta ujian — lalu aplikasi memunculkannya secara acak sesering yang
kamu mau, sampai benar-benar melekat.

KENAPA CARA INI BEKERJA
Menjawab dari ingatan (retrieval practice) adalah salah satu cara paling andal untuk
mengingat sesuatu. Membaca ulang catatan terasa produktif, tapi hasilnya kecil. Random
Recall membuat cara yang efektif jadi cara yang paling mudah.

CARA PAKAI
1. Tambahkan pertanyaan dan jawabannya, kelompokkan per topik — kopi, masak, jaringan,
   apa pun yang sedang kamu pelajari.
2. Atur kapan pengingatnya datang: hari apa, jam berapa, dan berapa kali sehari.
3. Saat notifikasi muncul, jawab di kepala, buka jawabannya, lalu tandai benar atau salah.
4. Lihat streak dan statistik per topik terus bertambah.

YANG ADA DI DALAMNYA
• Bank soal milikmu sendiri, topik dan jumlah pertanyaan tanpa batas
• Jadwal pengingat dari beberapa kali hingga sering dalam sehari, di hari pilihanmu
• Latihan kapan saja dari halaman utama, tanpa menunggu notifikasi
• Mode tantangan 7 hari dan 14 hari dengan badge dan gelar
• Statistik per topik: akurasi, percobaan, bagian yang masih lemah
• Streak, undo, dan tur interaktif saat pertama kali membuka
• Akun opsional dengan cadangan di cloud, jadi ganti HP tidak mulai dari nol
• Bisa dipakai offline; pertanyaan tetap di perangkat sampai kamu memilih sinkron
• Bahasa Indonesia dan Inggris

SOAL MODEL BISNIS
Satu versi penuh. Tanpa langganan, tanpa pembelian dalam aplikasi, tanpa fitur terkunci,
tanpa batas jumlah pertanyaan. Aplikasi ini didukung iklan, jadi banner sesekali adalah
yang membuatnya tetap gratis.

PRIVASI
Pertanyaanmu disimpan di perangkat. Akun bersifat opsional dan hanya dipakai untuk cadangan
dan sinkronisasi. Tidak ada data yang dijual.

Ada pertanyaan, masukan, atau bug? Kirim dari Settings → Send feedback di dalam aplikasi.
```

---

## Graphics inventory (`store/assets/`)

| Play Console slot | File | Spec | Status |
|---|---|---|---|
| App icon | `play-store-icon-512.png` | 512×512, 32-bit PNG | ✅ |
| Feature graphic (default) | `feature-graphic-en.png` | 1024×500 PNG | ✅ |
| Feature graphic (id-ID) | `feature-graphic-id.png` | 1024×500 PNG | ✅ |
| Phone screenshots (en-US) | `screenshots/home.png`, `question.png`, `answer.png`, `questions.png`, `settings.png` | 1080×1920 PNG | ✅ 5 of 8 |
| Phone screenshots (id-ID) | — | 1080×1920 | ⬜ needs a pass with the app set to Bahasa Indonesia |
| 7" / 10" tablet screenshots | — | — | ⬜ only if tablet support is claimed |

Play's limits: 2–8 screenshots per device type, each side between 320 and 3840 px, and the
long side no more than twice the short side. A raw 1220×2712 capture (20:9) breaks that
2:1 rule, which is why the framer pads each shot onto a 1080×1920 canvas.

## Store settings

| Field | Value |
|---|---|
| App name | Random Recall: Daily Practice |
| Category | Education |
| Tags | Study, Flashcards, Learning |
| Contact email | *(the address that goes on the listing — same one as the privacy policy)* |
| Website | *(optional; the privacy policy page works)* |
| Privacy policy URL | **required** — not built yet |
| Ads | Yes, contains ads |

## Data safety (draft — verify against the real SDKs before submitting)

| Data type | Collected | Shared | Purpose |
|---|---|---|---|
| Email address | Yes (only if the user creates an account) | No | Account management, sync |
| App activity (study progress) | Yes (only if signed in) | No | Sync/backup |
| Crash logs | Yes | No | Diagnostics (Firebase Crashlytics) |
| Device or other IDs (advertising ID) | Yes | Yes — Google AdMob | Advertising |

Also declare: data is encrypted in transit, users can delete their account from inside the
app (Profile → Delete account), and no data is sold.

## Content rating notes

- Ads present, but the app itself serves no ads inside the question flow.
- User-created content stays on the device and is never published or shared with other users.
- No location, no camera, no microphone, no contacts.
