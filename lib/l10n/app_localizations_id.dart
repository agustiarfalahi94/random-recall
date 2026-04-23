// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Random Recall';

  @override
  String get back => 'Kembali';

  @override
  String get cancel => 'Batal';

  @override
  String get save => 'Simpan';

  @override
  String get delete => 'Hapus';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Tutup';

  @override
  String get send => 'Kirim';

  @override
  String get all => 'Semua';

  @override
  String get off => 'Mati';

  @override
  String get secondsUnit => ' detik';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSubtitle => 'English / Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get dayMon => 'Sen';

  @override
  String get dayTue => 'Sel';

  @override
  String get dayWed => 'Rab';

  @override
  String get dayThu => 'Kam';

  @override
  String get dayFri => 'Jum';

  @override
  String get daySat => 'Sab';

  @override
  String get daySun => 'Min';

  @override
  String get presetDaily => 'Setiap Hari';

  @override
  String get presetWeekdays => 'Hari Kerja';

  @override
  String get presetWeekends => 'Akhir Pekan';

  @override
  String get everyDay => 'Setiap hari';

  @override
  String get weekdaysOnly => 'Hari kerja saja';

  @override
  String get weekendsOnly => 'Akhir pekan saja';

  @override
  String get mustChooseDay => 'Kamu harus pilih minimal 1 hari!';

  @override
  String get startTime => 'Waktu mulai';

  @override
  String get endTime => 'Waktu selesai';

  @override
  String get selectStartTime => 'Pilih waktu mulai';

  @override
  String get selectEndTime => 'Pilih waktu selesai';

  @override
  String get fieldQuestion => 'Pertanyaan';

  @override
  String get fieldAnswer => 'Jawaban';

  @override
  String get fieldCategory => 'Kategori';

  @override
  String get selectCategory => 'Pilih kategori';

  @override
  String get loginWelcomeTitle => 'Selamat Datang di Random Recall';

  @override
  String get loginSubtitle =>
      'Masuk untuk sinkronisasi progres dan membuka fitur premium.';

  @override
  String get continueWithGoogle => 'Lanjutkan dengan Google';

  @override
  String get continueWithEmail => 'Lanjutkan dengan Email';

  @override
  String get providerGoogle => 'Google';

  @override
  String get providerEmail => 'Email';

  @override
  String loginFailedSnack(String error) {
    return 'Login gagal: $error';
  }

  @override
  String get emailAuthTitle => 'Masuk';

  @override
  String get welcomeBack => 'Selamat datang kembali!';

  @override
  String get emailAddress => 'Alamat Email';

  @override
  String get password => 'Kata Sandi';

  @override
  String get showPassword => 'Tampilkan kata sandi';

  @override
  String get hidePassword => 'Sembunyikan kata sandi';

  @override
  String get loginButton => 'Masuk';

  @override
  String get needAccount => 'Belum punya akun? Daftar';

  @override
  String get forgotPasswordLink => 'Lupa Kata Sandi?';

  @override
  String get validationEnterEmail => 'Masukkan email kamu';

  @override
  String get validationValidEmail => 'Masukkan alamat email yang valid';

  @override
  String get validationEnterPassword => 'Masukkan kata sandi kamu';

  @override
  String get validationPasswordLength => 'Kata sandi minimal 6 karakter';

  @override
  String get errorNoAccount => 'Tidak ada akun untuk email ini.';

  @override
  String get errorWrongPassword => 'Email atau kata sandi salah.';

  @override
  String get errorInvalidEmail => 'Alamat email tidak valid.';

  @override
  String get errorAccountDisabled => 'Akun ini telah dinonaktifkan.';

  @override
  String get errorTooManyRequests =>
      'Terlalu banyak percobaan. Coba lagi nanti.';

  @override
  String get errorAuthFailed => 'Autentikasi gagal. Coba lagi.';

  @override
  String get errorUnexpected => 'Terjadi kesalahan tak terduga. Coba lagi.';

  @override
  String get signupTitle => 'Buat Akun';

  @override
  String get joinTitle => 'Bergabung dengan Random Recall';

  @override
  String get signUpButton => 'Daftar';

  @override
  String get alreadyHaveAccount => 'Sudah punya akun? Masuk';

  @override
  String get accountCreatedSnack =>
      'Akun berhasil dibuat! Cek inbox email kamu untuk verifikasi.';

  @override
  String get validationEnterNewPassword => 'Masukkan kata sandi';

  @override
  String get errorEmailInUse =>
      'Email ini sudah digunakan. Silakan masuk atau gunakan email lain.';

  @override
  String get errorWeakPassword =>
      'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';

  @override
  String get errorSignUpFailed => 'Pendaftaran gagal. Coba lagi.';

  @override
  String get resetPasswordTitle => 'Reset Kata Sandi';

  @override
  String get forgotPasswordTitle => 'Lupa Kata Sandi?';

  @override
  String get forgotPasswordSubtitle =>
      'Masukkan email kamu dan kami akan mengirim link reset jika akun tersebut ada.';

  @override
  String get sendResetLink => 'Kirim Link Reset';

  @override
  String get resetSuccess => 'Berhasil! Cek inbox email kamu untuk link reset.';

  @override
  String get enterYourEmail => 'Masukkan email kamu';

  @override
  String get resetError => 'Terjadi kesalahan. Coba lagi.';

  @override
  String get verifyEmailTitle => 'Verifikasi email kamu';

  @override
  String verifyEmailSent(String email) {
    return 'Kami telah mengirim link verifikasi ke $email.\nCek inbox kamu dan klik link tersebut untuk melanjutkan.';
  }

  @override
  String get iHaveClickedLink => 'Saya sudah klik link-nya';

  @override
  String get resendEmail => 'Kirim Ulang Email';

  @override
  String get cancelSignOut => 'Batal / Keluar';

  @override
  String get waitingVerification => 'Menunggu verifikasi...';

  @override
  String get verificationResent => 'Email verifikasi telah dikirim ulang!';

  @override
  String get signingOut => 'Keluar...';

  @override
  String get onboardingTagline => 'Tes dirimu tentang apa saja.\nSecara acak.';

  @override
  String get onboardingDescription =>
      'Tambahkan pertanyaanmu sendiri, pilih kapan ingin diingatkan, dan biarkan Random Recall menjaga pengetahuanmu tetap tajam — satu kuis acak setiap saat.';

  @override
  String get featureRandom => 'Acak';

  @override
  String get featureNotifications => 'Notifikasi';

  @override
  String get featureAnalytics => 'Analitik';

  @override
  String get getStarted => 'Mulai →';

  @override
  String get firstQuestionTitle => 'Pertanyaan pertamamu';

  @override
  String get firstQuestionSubtitle =>
      'Tambahkan sesuatu yang ingin kamu ingat. Kamu bisa tambah lebih banyak nanti.';

  @override
  String get questionHintOnboarding => 'contoh: Apa ibukota Indonesia?';

  @override
  String get answerHintOnboarding => 'contoh: Jakarta';

  @override
  String get validationEnterQuestion => 'Masukkan pertanyaan';

  @override
  String get validationQuestionTooShort => 'Pertanyaan terlalu pendek';

  @override
  String get validationEnterAnswer => 'Masukkan jawaban';

  @override
  String get validationSelectCategory => 'Pilih kategori';

  @override
  String get notifSetupTitle => 'Kapan kami harus\nmengingatkanmu?';

  @override
  String get notifSetupSubtitle =>
      'Kamu bisa ubah pengaturan ini nanti di aplikasi.';

  @override
  String get timingSection => 'Waktu';

  @override
  String get anytimeOption => 'Kapan saja (sepenuhnya acak)';

  @override
  String get anytimeSubtitle => 'Notifikasi bisa datang di jam berapa saja';

  @override
  String get setTimeRange => 'Atur rentang waktu';

  @override
  String get setTimeRangeSubtitle =>
      'Hanya beri notifikasi dalam jendela waktu yang kamu pilih';

  @override
  String get timeWindowSection => 'Jendela waktu';

  @override
  String get activeDaysSection => 'Hari aktif';

  @override
  String get howManyTimesPerDay => 'Berapa kali per hari?';

  @override
  String get timePerDay => 'kali per hari';

  @override
  String get timesPerDay => 'kali per hari';

  @override
  String get notificationsOff => 'Notifikasi dimatikan';

  @override
  String get notifPermDeniedMsg =>
      'Ketuk tombol di bawah untuk membuka Pengaturan Notifikasi. Aktifkan \"Random Recall\" di sana, lalu kembali ke sini.';

  @override
  String get notifNeedsPermission =>
      'Random Recall butuh notifikasi untuk mengingatkanmu. Izinkan notifikasi saat diminta.';

  @override
  String get checkingPermission => 'Memeriksa izin notifikasi…';

  @override
  String get openNotifSettings => 'Buka Pengaturan Notifikasi ↗';

  @override
  String get tryAgain => 'Coba lagi';

  @override
  String get startRecalling => 'Mulai Mengingat! 🚀';

  @override
  String get skipForNow => 'Lewati dulu — aktifkan notifikasi nanti';

  @override
  String get endTimeMustBeAfter =>
      'Waktu selesai harus minimal 1 jam setelah waktu mulai.';

  @override
  String get notifRequired => 'Notifikasi Diperlukan';

  @override
  String get notifRequiredDesc =>
      'Random Recall bekerja dengan mengirimkan notifikasi kuis acak sepanjang hari. Tanpa izin ini, aplikasi tidak bisa berfungsi.';

  @override
  String get enableNotifications => 'Aktifkan Notifikasi';

  @override
  String get exitApp => 'Keluar Aplikasi';

  @override
  String get enableInSettings =>
      'Aktifkan notifikasi di pengaturan sistem untuk melanjutkan.';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsTooltip => 'Pengaturan';

  @override
  String get syncDataNow => 'Sinkronisasi Data Sekarang';

  @override
  String get syncSubtitle => 'Tarik perubahan terbaru dari cloud';

  @override
  String get syncSingleDeviceNote =>
      'Hanya satu perangkat yang bisa aktif sekaligus. Masuk di perangkat baru akan otomatis mengeluarkan kamu dari perangkat ini.';

  @override
  String get sendTestNotification => 'Kirim notifikasi uji coba';

  @override
  String get sendTestSubtitle =>
      'Verifikasi notifikasi berfungsi di perangkatmu';

  @override
  String get notifScheduleMenuItem => 'Jadwal notifikasi';

  @override
  String get notifScheduleMenuSubtitle => 'Atur waktu, hari & frekuensi';

  @override
  String get manageCategoriesMenuItem => 'Kelola kategori';

  @override
  String get manageCategoriesMenuSubtitle =>
      'Tambah atau hapus kategori pertanyaan';

  @override
  String get sendFeedbackMenuItem => 'Kirim masukan';

  @override
  String get sendFeedbackMenuSubtitle =>
      'Beri tahu kami apa yang bisa lebih baik';

  @override
  String get faqMenuItem => 'FAQ';

  @override
  String get faqMenuSubtitle => 'Pertanyaan umum & perilaku yang diharapkan';

  @override
  String get signOut => 'Keluar';

  @override
  String get syncCompleteSnack =>
      'Sinkronisasi selesai! Data sudah terbaru. 🔄';

  @override
  String syncFailedSnack(String error) {
    return 'Sinkronisasi gagal: $error';
  }

  @override
  String get testNotifSentSnack =>
      'Notifikasi uji coba terkirim! Cek bilah notifikasimu 🔔';

  @override
  String testNotifFailedSnack(String error) {
    return 'Gagal mengirim: $error';
  }

  @override
  String signOutFailedSnack(String error) {
    return 'Keluar gagal: $error';
  }

  @override
  String get signingOutSafely => 'Keluar dengan aman...';

  @override
  String get backingUpData => 'Mencadangkan datamu';

  @override
  String get sendFeedbackDialogTitle => 'Kirim masukan';

  @override
  String get feedbackHint => 'Apa yang bisa lebih baik?';

  @override
  String get feedbackSentSnack => 'Masukan terkirim — terima kasih!';

  @override
  String get feedbackFailedSnack =>
      'Tidak dapat mengirim masukan. Coba lagi nanti.';

  @override
  String get navHome => 'Beranda';

  @override
  String get navQuestions => 'Pertanyaan';

  @override
  String get navAnalytics => 'Analitik';

  @override
  String get readyToRecall => 'Siap untuk mengingat?';

  @override
  String get homeSubtitle =>
      'Ketuk di bawah untuk berlatih kapan saja,\natau tunggu notifikasi acak.';

  @override
  String get practiceNow => 'Latihan Sekarang';

  @override
  String get timerChallengeTitle => 'Tantangan Timer';

  @override
  String bonusCountLabel(int count) {
    return '+$count bonus';
  }

  @override
  String timerChallengeActiveDesc(int seconds) {
    return 'Timer diatur ke $seconds detik — tantangan aktif! Jawab setiap hari selama 7 hari untuk mendapatkan +1 slot pertanyaan.';
  }

  @override
  String timerChallengeRelaxedDesc(int seconds, int threshold) {
    return 'Timer $seconds detik — terlalu santai untuk tantangan. Atur ke $threshold detik atau kurang untuk mendapatkan streak.';
  }

  @override
  String timerChallengeOffDesc(int threshold) {
    return 'Atur timer ($threshold detik atau kurang) untuk membuka tantangan. Jawab setiap hari selama 7 hari → dapatkan +1 slot pertanyaan!';
  }

  @override
  String get setATimer => 'Atur Timer';

  @override
  String get streakStart => 'Mulai hari ini! Jawab dengan timer aktif.';

  @override
  String streakProgress(int streak, String plural, int days) {
    return 'Streak $streak hari$plural — $days lagi untuk mendapatkan bonus!';
  }

  @override
  String get notifScheduleTitle => 'Jadwal Notifikasi';

  @override
  String get challengeModeName => 'Mode\nTantangan';

  @override
  String challengeModeOff(int threshold) {
    return 'Atur timer ke $threshold detik atau kurang → jawab setiap hari → capai streak 7 hari → dapatkan +1 slot pertanyaan gratis!';
  }

  @override
  String get challengeModeActive =>
      '🔥 Tantangan aktif! Terus lakukan setiap hari selama 7 hari untuk mendapatkan +1 slot pertanyaan gratis!';

  @override
  String challengeModeRelaxed(int threshold) {
    return 'Timer terlalu santai. Turunkan ke $threshold detik atau kurang untuk mengaktifkan tantangan.';
  }

  @override
  String get responseTimer => 'Timer respons';

  @override
  String get noTimeLimit => 'Tanpa batas waktu — mode santai';

  @override
  String get autoMarksWrong => 'Otomatis salah jika waktu habis';

  @override
  String get sendAtAnyTime => 'Kirim kapan saja';

  @override
  String get sendAtAnyTimeSubtitle => 'Notifikasi tiba sepanjang hari';

  @override
  String get frequencySection => 'Frekuensi';

  @override
  String get activeDaysSectionTitle => 'Hari Aktif';

  @override
  String get notifPerDay => 'Notifikasi per hari';

  @override
  String get saveSchedule => 'Simpan Jadwal';

  @override
  String get saving => 'Menyimpan...';

  @override
  String get timeWindowError => 'Jendela waktu harus minimal 1 jam.';

  @override
  String get selectActiveDayError => 'Pilih minimal satu hari aktif.';

  @override
  String get scheduleSavedSnack => 'Jadwal notifikasi tersimpan! 🔔';

  @override
  String saveFailedSnack(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get batteryOptOn => 'Optimasi baterai AKTIF';

  @override
  String get batteryOptSubtitle =>
      'Ketuk untuk mengizinkan Random Recall selalu berjalan (pengaturan Android standar) — memperbaiki notifikasi yang terlewat';

  @override
  String get miuiFixTitle => 'MIUI / HyperOS: perbaiki pengiriman notifikasi';

  @override
  String get miuiFixSubtitle =>
      'Ketuk untuk melihat panduan pengaturan Autostart & baterai';

  @override
  String get freqOnce => 'Sekali sehari — santai saja';

  @override
  String freqRecommended(int count) {
    return '$count kali sehari — direkomendasikan';
  }

  @override
  String freqActive(int count) {
    return '$count kali sehari — cukup aktif';
  }

  @override
  String freqIntense(int count) {
    return '$count kali sehari — intensif!';
  }

  @override
  String get freqMax => '10 kali sehari — maksimum';

  @override
  String get editQuestionTitle => 'Edit Pertanyaan';

  @override
  String get newQuestionTitle => 'Pertanyaan Baru';

  @override
  String get questionHintAdd =>
      'contoh: Saat memasak nasi goreng, apa yang ditambahkan terakhir?';

  @override
  String get answerHintAdd => 'contoh: Kecap dan minyak wijen';

  @override
  String get saveChanges => 'Simpan Perubahan';

  @override
  String get addQuestion => 'Tambah Pertanyaan';

  @override
  String get validationEnterQuestion2 => 'Masukkan pertanyaan';

  @override
  String get validationQuestionTooShort2 => 'Pertanyaan terlalu pendek';

  @override
  String get validationEnterAnswer2 => 'Masukkan jawaban';

  @override
  String get validationSelectCategory2 => 'Pilih kategori';

  @override
  String questionCount(int current, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other: '$current / $max pertanyaan',
      one: '1 / $max pertanyaan',
      zero: 'Tidak ada pertanyaan',
    );
    return '$_temp0';
  }

  @override
  String questionWarning(int current, int max) {
    return 'Mendekati batas pertanyaan — $current / $max';
  }

  @override
  String questionLimitReached(int current, int max) {
    return 'Batas pertanyaan tercapai — $current / $max';
  }

  @override
  String get upgradeButton => 'Upgrade ›';

  @override
  String get noQuestionsInCategory => 'Tidak ada pertanyaan di kategori ini';

  @override
  String get noQuestionsYet => 'Belum ada pertanyaan';

  @override
  String get tapToAddFirst =>
      'Ketuk tombol di bawah untuk menambahkan pertanyaan pertamamu.';

  @override
  String get deleteQuestionTitle => 'Hapus pertanyaan?';

  @override
  String get newQuestionMenuTitle => 'Pertanyaan Baru';

  @override
  String get newQuestionMenuSubtitle =>
      'Tambahkan sesuatu yang ingin kamu ingat';

  @override
  String get newCategoryMenuTitle => 'Kategori Baru';

  @override
  String get newCategoryMenuSubtitle =>
      'Kelompokkan pertanyaan ke dalam grup baru';

  @override
  String get categoriesTitle => 'Kategori';

  @override
  String get freePlanLimitReachedBanner =>
      'Paket gratis: kamu sudah menggunakan 1 slot kategori kustom. Upgrade ke Premium untuk kategori tak terbatas.';

  @override
  String get freePlanInfoBanner =>
      'Paket gratis: kamu bisa menambahkan 1 kategori kustom. Kategori bawaan (General, Work) tidak dihitung.';

  @override
  String get noCategoriesYet => 'Belum ada kategori kustom';

  @override
  String get noCategoriesSubtitle =>
      'General dan Work sudah tersedia. Ketuk tombol di bawah untuk membuat kategorimu sendiri.';

  @override
  String get newCategorySheetTitle => 'Kategori Baru';

  @override
  String get iconSectionLabel => 'IKON';

  @override
  String get nameSectionLabel => 'NAMA';

  @override
  String get categoryNameHint => 'contoh: Memasak, Perjalanan, Keuangan…';

  @override
  String get validationCategoryNameEmpty => 'Masukkan nama kategori';

  @override
  String get validationCategoryNameShort => 'Nama terlalu pendek';

  @override
  String get premiumUnlimitedCategories =>
      'Premium — buat sebanyak kategori yang kamu mau!';

  @override
  String freePlanCategoryNote(int count) {
    return 'Paket gratis: $count kategori kustom diizinkan (General & Work sudah tersedia). Upgrade ke Premium untuk tak terbatas.';
  }

  @override
  String get hasQuestions => 'Ada pertanyaan';

  @override
  String get emptySafeToDelete => 'Kosong — aman dihapus';

  @override
  String get cannotDeleteTooltip => 'Tidak bisa dihapus — ada pertanyaan';

  @override
  String get deleteTooltip => 'Hapus';

  @override
  String get deleteCategoryTitle => 'Hapus kategori?';

  @override
  String deleteCategoryContent(String icon, String name) {
    return 'Hapus \"$icon $name\"? Ini tidak bisa dibatalkan.';
  }

  @override
  String categoryHasQuestionsError(String name) {
    return '\"$name\" ada pertanyaannya. Hapus atau pindahkan dulu.';
  }

  @override
  String get limitReachedFab => 'Batas Tercapai';

  @override
  String get newCategoryFab => 'Kategori Baru';

  @override
  String categoryCount(int current, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      current,
      locale: localeName,
      other: '$current / $max kategori',
      one: '1 / $max kategori',
      zero: 'Tidak ada kategori',
    );
    return '$_temp0';
  }

  @override
  String categoryWarning(int current, int max) {
    return 'Mendekati batas kategori — $current / $max';
  }

  @override
  String categoryLimitReached(int current, int max) {
    return 'Batas kategori tercapai — $current / $max';
  }

  @override
  String saveCategoryFailedSnack(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get questionLabel => 'PERTANYAAN';

  @override
  String get answerLabel => 'JAWABAN';

  @override
  String get revealAnswer => 'Tampilkan Jawaban';

  @override
  String get didYouKnowIt => 'Apakah kamu tahu?';

  @override
  String get didntKnowIt => 'Tidak tahu';

  @override
  String get knewIt => 'Saya tahu!';

  @override
  String get nextQuestion => 'Pertanyaan Berikutnya';

  @override
  String get backToHome => 'Kembali ke Beranda';

  @override
  String get nextQuestionPrompt => 'Pertanyaan berikutnya?';

  @override
  String get keepPracticing => 'Terus berlatih!';

  @override
  String failedToSaveScore(String error) {
    return 'Gagal menyimpan skor: $error';
  }

  @override
  String get undoSuccess => 'Hasil dibatalkan. Kamu bisa coba lagi! ↩️';

  @override
  String undoFailed(String error) {
    return 'Batal gagal: $error';
  }

  @override
  String get undoButton => 'Batal';

  @override
  String get undoOncePerDay => 'Batal (hanya 1 kali per hari)';

  @override
  String get noQuestionsEmptyTitle => 'Belum ada pertanyaan';

  @override
  String get noQuestionsEmptySubtitle =>
      'Tambahkan pertanyaan dulu dari tab Pertanyaan.';

  @override
  String get goBack => 'Kembali';

  @override
  String get skipToNext => 'Lewati ke pertanyaan berikutnya';

  @override
  String get scoreRecordedClosing => 'Skor tersimpan! Menutup sebentar lagi...';

  @override
  String get closingInMoment => 'Menutup sebentar lagi...';

  @override
  String get scoreRecordedKeepPracticing => 'Skor tersimpan! Terus berlatih';

  @override
  String get closeButton => 'Tutup';

  @override
  String streakDayTitle(int streak) {
    return 'Streak $streak Hari!';
  }

  @override
  String streakDescription(int streak) {
    return 'Kamu sudah menjawab dengan timer aktif selama $streak hari berturut-turut. Kamu mendapatkan +1 slot pertanyaan bonus! 🎉';
  }

  @override
  String get awesome => 'Luar biasa!';

  @override
  String get analyticsNoData => 'Belum ada data';

  @override
  String get analyticsNoDataSubtitle =>
      'Jawab beberapa pertanyaan dulu dan statistikmu akan muncul di sini.';

  @override
  String get analyticsByCategory => 'Per Kategori';

  @override
  String get analyticsOutstanding => 'Luar biasa!';

  @override
  String get analyticsGoodProgress => 'Kemajuan bagus!';

  @override
  String get analyticsKeepGoing => 'Terus semangat!';

  @override
  String get analyticsJustStarted => 'Baru mulai';

  @override
  String get analyticsOverallScore => 'Skor Keseluruhan';

  @override
  String get analyticsAnswered => 'Dijawab';

  @override
  String get analyticsCorrect => 'Benar';

  @override
  String get analyticsWrong => 'Salah';

  @override
  String get analyticsTotal => 'Total';

  @override
  String get analyticsCorrectLabel => '✅ Benar';

  @override
  String get analyticsWrongLabel => '❌ Salah';

  @override
  String get analyticsUnlockTitle => 'Buka Analitik Kategori';

  @override
  String get analyticsUnlockSubtitle =>
      'Lihat persis kategori mana yang masih perlu dipelajari.\nBerlangganan untuk membuka analitik lengkap.';

  @override
  String get analyticsSubscribeButton => 'Berlangganan untuk Membuka';

  @override
  String get createCategoryButton => 'Buat Kategori';

  @override
  String get upgradeToPremium => 'Upgrade ke Premium';

  @override
  String get premiumUnlockTitle => 'Buka Potensi Penuh';

  @override
  String get premiumUnlockSubtitle => 'Kuasai pengetahuanmu tanpa batas.';

  @override
  String get featureUnlimitedQuestions => 'Pertanyaan Tak Terbatas';

  @override
  String get featureUnlimitedQuestionsSubtitle =>
      'Tambahkan sebanyak fakta yang perlu kamu ingat.';

  @override
  String get featureUnlimitedCategories => 'Kategori Tak Terbatas';

  @override
  String get featureUnlimitedCategoriesSubtitle =>
      'Organisir belajarmu ke dalam topik spesifik.';

  @override
  String get featureUndoMistakes => 'Batalkan Kesalahan';

  @override
  String get featureUndoMistakesSubtitle =>
      'Koreksi jawaban salah untuk menjaga streak tetap hidup.';

  @override
  String get featureAdvancedAnalytics => 'Analitik Lanjutan';

  @override
  String get featureAdvancedAnalyticsSubtitle =>
      'Temukan titik lemahmu dengan skor per kategori.';

  @override
  String get featureRealTimeSync => 'Sinkronisasi Real-time';

  @override
  String get featureRealTimeSyncSubtitle =>
      'Akses mulus di semua perangkat Android kamu.';

  @override
  String getPremiumButton(String price) {
    return 'Dapatkan Premium — $price';
  }

  @override
  String get loadingPlans => 'Memuat paket yang tersedia...';

  @override
  String get restorePurchase => 'Pulihkan Pembelian';

  @override
  String get cancelAnytime =>
      'Batalkan kapan saja di Google Play Store. Pengaturan > Langganan.';

  @override
  String purchaseFailedSnack(String error) {
    return 'Pembelian gagal: $error';
  }

  @override
  String get premiumActiveMember => 'Kamu adalah Anggota Premium!';

  @override
  String get premiumActiveDesc =>
      'Terima kasih telah mendukung Random Recall. Nikmati semua fitur yang telah dibuka.';

  @override
  String get premiumGreat => 'Bagus!';

  @override
  String get premiumIncludes => 'Premium mencakup:';

  @override
  String get premiumPerkUnlimitedQuestions => '✅ Pertanyaan tak terbatas';

  @override
  String get premiumPerkAllCategories => '✅ Semua kategori';

  @override
  String get premiumPerkFullAnalytics => '✅ Analitik lengkap';

  @override
  String get premiumPerkUndo => '✅ Batalkan jawaban salah (hadiah)';

  @override
  String get questionLimitReachedTitle => 'Batas Pertanyaan Tercapai';

  @override
  String get categoryLimitReachedTitle => 'Batas Kategori Tercapai';

  @override
  String get questionLimitReachedDesc =>
      'Akun gratis dapat menyimpan hingga 20 pertanyaan (+ slot bonus dari streakmu). Upgrade ke Premium untuk pertanyaan tak terbatas.';

  @override
  String get categoryLimitReachedDesc =>
      'Akun gratis dapat menambahkan pertanyaan ke maksimal 2 kategori. Upgrade ke Premium untuk menggunakan semua kategori tanpa batas.';

  @override
  String get maybeLater => 'Nanti saja';

  @override
  String get miuiDialogTitle => 'Perbaiki notifikasi di MIUI / HyperOS';

  @override
  String get miuiDialogSubtitle =>
      'HP Xiaomi membatasi aplikasi latar belakang secara default. Dua perubahan cepat ini akan memastikan notifikasi kuismu tiba dengan andal.';

  @override
  String get miuiStep1Title => 'Aktifkan Background Start';

  @override
  String get miuiStep1Desc =>
      'Pengaturan → Aplikasi → Background Start → cari Random Recall → aktifkan';

  @override
  String get miuiStep2Title => 'Atur Daya ke Tanpa Pembatasan';

  @override
  String get miuiStep2Desc =>
      'Pengaturan → Aplikasi → Random Recall → Daya → Tanpa Pembatasan';

  @override
  String get openBackgroundStartBtn => 'Buka Pengaturan Background Start';

  @override
  String get openAppSettingsBtn => 'Buka Pengaturan Aplikasi — Atur Daya';

  @override
  String get doneDismissBtn => 'Sudah selesai — tutup';

  @override
  String get notificationTitle => 'Saatnya mengingat kembali! 🧠';

  @override
  String get notificationBody => 'Tap untuk menjawab pertanyaan';

  @override
  String get testNotificationTitle => 'Notifikasi Pengujian 🧪';

  @override
  String get testNotificationBody => 'Tap untuk menjawab pertanyaan';

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqSectionNotifications => 'Notifikasi';

  @override
  String get faqSectionQuestionBank => 'Bank Pertanyaan & Batas';

  @override
  String get faqSectionChallengeMode => 'Mode Tantangan';

  @override
  String get faqSectionAccountSync => 'Akun & Sinkronisasi';

  @override
  String get faqSectionPermissions => 'Izin';

  @override
  String get faqQ1 =>
      'Mengapa semua notifikasi saya tiba sekaligus saat membuka kunci ponsel?';

  @override
  String get faqA1 =>
      'Di perangkat Xiaomi / MIUI / HyperOS, OS menahan alarm terjadwal saat layar mati dan melepaskan semuanya bersama saat kamu membuka kunci. Ini adalah manajemen daya Android — aplikasi tidak bisa menggantinya secara langsung. Memasukkan aplikasi ke dalam daftar putih di pengaturan baterai (Pengaturan → Baterai → Tanpa pembatasan) mengurangi penundaan secara signifikan.';

  @override
  String get faqQ2 =>
      'Mengapa angka badge menampilkan lebih sedikit dari notifikasi di tray saya?';

  @override
  String get faqA2 =>
      'Badge menghitung pertanyaan unik yang tertunda, bukan jumlah total notifikasi. Jika bank pertanyaanmu kecil (misalnya 3 pertanyaan dengan frekuensi 6 per hari), pertanyaan yang sama dijadwalkan ke beberapa slot — tapi kamu hanya perlu menjawabnya sekali, jadi dihitung 1 di badge.';

  @override
  String get faqQ3 =>
      'Mengapa beberapa notifikasi menghilang saat saya menjawab hanya satu?';

  @override
  String get faqA3 =>
      'Saat kamu menjawab pertanyaan, semua pengingat yang tertunda untuk pertanyaan yang sama dihapus sekaligus. Jika bank pertanyaanmu kecil dan pertanyaan yang sama muncul di beberapa slot, semua notifikasi itu hilang bersama. Ini benar — kamu sudah menjawab pertanyaannya, jadi pengingat tidak lagi diperlukan.';

  @override
  String get faqQ4 =>
      'Mengapa jumlah badge saya berkurang setelah mengubah jadwal notifikasi?';

  @override
  String get faqA4 =>
      'Menyimpan pengaturan jadwal baru memicu penjadwalan ulang penuh. Di versi sebelumnya, ini bisa secara tidak sengaja membuang notifikasi yang sudah terpicu dari jumlah badge jika ID internalnya bertabrakan dengan slot baru. Bug ini sudah diperbaiki — notifikasi yang terpicu-tapi-belum-dijawab sekarang dipertahankan melalui perubahan jadwal apa pun.';

  @override
  String get faqQ5 => 'Apa maksud \"Kirim kapan saja\"?';

  @override
  String get faqA5 =>
      'Saat diaktifkan, notifikasi harianmu tersebar merata sepanjang 24 jam penuh (tengah malam hingga 11 malam). Saat dinonaktifkan, notifikasi diberi jarak dalam jendela waktu yang kamu atur (misalnya 9 pagi – 6 sore). Gunakan jendela waktu jika kamu hanya ingin diingatkan selama jam aktif.';

  @override
  String get faqQ6 => 'Mengapa notifikasi saya tidak tiba tepat waktu?';

  @override
  String get faqA6 =>
      'Dua penyebab umum: (1) Optimasi baterai AKTIF untuk aplikasi — masukkan ke daftar putih menggunakan prompt di pengaturan Jadwal Notifikasi. (2) MIUI / HyperOS menahan alarm saat layar mati dan menyalakannya semua saat dibuka — lihat pertanyaan pertama di atas.';

  @override
  String get faqQ7 =>
      'Berapa banyak pertanyaan yang bisa saya tambahkan secara gratis?';

  @override
  String get faqA7 =>
      'Paket gratis mulai dengan 20 slot pertanyaan. Kamu bisa mendapatkan slot tambahan dengan menyelesaikan streak Tantangan 7 hari (+1 slot per streak). Premium menghapus batas sepenuhnya.';

  @override
  String get faqQ8 =>
      'Berapa banyak kategori kustom yang bisa saya buat secara gratis?';

  @override
  String get faqA8 =>
      'Akun gratis dapat membuat 1 kategori kustom. Kategori bawaan \"General\" dan \"Work\" tidak dihitung terhadap batas ini. Premium memberikan kategori tak terbatas.';

  @override
  String get faqQ9 => 'Apa itu Batal harian?';

  @override
  String get faqA9 =>
      'Kamu bisa membatalkan jawaban terakhirmu sekali per hari kalender. Batas ini direset tengah malam. Ini tersedia untuk akun gratis dan premium.';

  @override
  String get faqQ10 => 'Apa itu Mode Tantangan dan bagaimana cara kerjanya?';

  @override
  String get faqA10 =>
      'Mulai Mode Tantangan BARU dari Jadwal Notifikasi. Mode ini mewajibkan timer 5–10 detik dan jawaban sempurna. Jawab minimal satu notifikasi per hari selama 7 hari berturut-turut untuk menyelesaikan tantangan. Melewatkan satu hari atau menjawab salah akan menggagalkan tantangan.';

  @override
  String get faqQ11 => 'Apakah timer mempengaruhi skor saya jika habis?';

  @override
  String get faqA11 =>
      'Ya — jika hitungan mundur mencapai nol sebelum kamu menjawab, pertanyaan secara otomatis ditandai salah. Atur timer ke 0 di pengaturan untuk menonaktifkannya dan menjawab sesuai kecepatan kamu.';

  @override
  String get faqQ12 =>
      'Apakah pertanyaan saya tersinkronisasi di berbagai perangkat?';

  @override
  String get faqA12 =>
      'Ya. Pertanyaan, kategori, dan pengaturanmu dicadangkan ke akunmu secara otomatis. Masuk di perangkat baru memulihkan semuanya. Kamu juga bisa memicu sinkronisasi manual melalui Pengaturan → Sinkronisasi Data Sekarang.';

  @override
  String get faqQ13 => 'Apa yang terjadi pada data saya jika saya keluar?';

  @override
  String get faqA13 =>
      'Datamu disimpan ke cloud sebelum proses keluar selesai. Tidak ada yang dihapus secara lokal maupun jarak jauh. Masuk kembali memulihkan semua pertanyaan dan pengaturanmu.';

  @override
  String get faqQ14 =>
      'Mengapa aplikasi meminta untuk menonaktifkan optimasi baterai?';

  @override
  String get faqA14 =>
      'Optimasi baterai Android dapat mematikan alarm terjadwal untuk aplikasi yang berjalan di latar belakang. Memasukkan aplikasi ke daftar putih (pengaturan Android standar) memberi tahu OS untuk menjaga alarmnya tetap aktif — ini adalah perbaikan paling efektif untuk notifikasi yang terlewat atau terlambat di perangkat Android mana pun.';

  @override
  String get faqQ15 =>
      'Apa yang saya kehilangan jika saya menolak izin notifikasi?';

  @override
  String get faqA15 =>
      'Tujuan utama aplikasi — pengingat recall berwaktu — berhenti bekerja. Kamu tidak akan menerima pertanyaan apa pun. Layar izin akan muncul setiap kali aplikasi dibuka sampai izin diberikan di pengaturan perangkatmu.';

  @override
  String onboardingSomethingWentWrong(String error) {
    return 'Ada yang salah: $error';
  }

  @override
  String welcomeMessage(String name) {
    return 'Selamat datang, $name';
  }

  @override
  String get profilePageTitle => 'Profil';

  @override
  String get nameLabel => 'Nama';

  @override
  String get phoneLabel => 'Nomor Telepon';

  @override
  String get emailLabel => 'Email';

  @override
  String get subscriptionStatusLabel => 'Status Langganan';

  @override
  String get subscriptionStatusPremium => 'Premium';

  @override
  String get subscriptionStatusFree => 'Gratis';

  @override
  String get changePasswordButton => 'Ubah Kata Sandi';

  @override
  String get deleteAccountButton => 'Hapus Akun';

  @override
  String get deleteAccountWarning =>
      'Apakah Anda yakin? Penghapusan akun bersifat permanen. Semua data Anda akan dihapus.';

  @override
  String get deleteAccountConfirm => 'Hapus Akun';

  @override
  String get deleteAccountCancel => 'Batal';

  @override
  String get profileUpdateSuccess => 'Profil berhasil diperbarui';

  @override
  String get profileUpdateFailed => 'Gagal memperbarui profil';

  @override
  String get passwordChangedSuccess => 'Kata sandi berhasil diubah';

  @override
  String get passwordChangedFailed => 'Gagal mengubah kata sandi';

  @override
  String get accountDeletedSuccess => 'Akun berhasil dihapus';

  @override
  String get accountDeleteFailed => 'Gagal menghapus akun';

  @override
  String get googleAccountLabel => 'Akun Google';

  @override
  String get emailAccountLabel => 'Email';

  @override
  String get displayNameInputHint => 'Masukkan nama Anda';

  @override
  String get displayNameLabel => 'Nama Tampilan';

  @override
  String get displayNameMaxLength => 'Maksimal 50 karakter';

  @override
  String get displayNameInvalidCharacters =>
      'Hanya huruf, angka, spasi, tanda hubung, dan garis bawah yang diperbolehkan.';

  @override
  String get displayNameEmpty => 'Silakan masukkan nama.';

  @override
  String get displayNameProfanity =>
      'Nama ini mengandung konten yang tidak pantas. Silakan pilih yang lain.';

  @override
  String get displayNameError => 'Kesalahan menyimpan nama. Silakan coba lagi.';

  @override
  String get displayNameSubmit => 'Lanjutkan';

  @override
  String get displayNameCancel => 'Batal';

  @override
  String get challengeModeFrequencyTitle =>
      'Mode Tantangan: Pilih Frekuensi Harian';

  @override
  String challengeModeFrequencyHint(int duration) {
    return 'Berapa pertanyaan per hari selama tantangan $duration hari ini?';
  }

  @override
  String get challengeModeFrequencyRange => '1-50 pertanyaan per hari';

  @override
  String challengeWarningTitle(int duration) {
    return '⚠️ Mode Tantangan — Rangkaian $duration Hari';
  }

  @override
  String get challengeWarningRule1 =>
      '• Harus menjawab SEMUA pertanyaan dengan benar (tidak ada kesalahan)';

  @override
  String get challengeWarningRule2 =>
      '• Timer terkunci pada 5 atau 10 detik saja';

  @override
  String get challengeWarningRule3 =>
      '• Frekuensi notifikasi terkunci (tidak dapat diubah)';

  @override
  String challengeWarningRule4(int duration) {
    return '• Harus menyelesaikan setiap hari selama $duration hari berturut-turut';
  }

  @override
  String challengeWarningRule5(int duration) {
    return 'Selesaikan semua $duration hari untuk mendapatkan hadiah';
  }

  @override
  String get challengeWarningCancel => 'Batal';

  @override
  String get challengeWarningStart => 'Saya Mengerti, Mulai Tantangan';

  @override
  String challengeRewardFreeQuestions(int count) {
    return '+$count slot pertanyaan';
  }

  @override
  String challengeRewardFreeCategories(int count) {
    return '+$count slot kategori';
  }

  @override
  String get challengeRewardBadge => '🏆 Lencana';

  @override
  String get challengeRewardTitle => '👑 Judul Progresif';

  @override
  String get challengeRewardNotification => '🔥 Tampilan notifikasi khusus';

  @override
  String get challengeFailureMessage =>
      'Anda melewatkan hari atau menjawab dengan salah. Tantangan gagal.';

  @override
  String get challengeCompleteMessage =>
      'Tantangan selesai! Hadiah telah diperoleh.';

  @override
  String challengeDayCounter(int day, int total) {
    return 'Hari Tantangan $day/$total';
  }

  @override
  String get lockedDuringChallenge => 'Terkunci selama tantangan';

  @override
  String get challengeTimerRequirementSnack =>
      'Mode Tantangan membutuhkan timer hanya 5 atau 10 detik.';

  @override
  String challengeActivatedSnack(int days) {
    return '🔥 Mode Tantangan aktif! Kamu punya $days hari.';
  }

  @override
  String challengeConfirmTitle(int days) {
    return '🔥 Mulai Mode Tantangan $days Hari?';
  }

  @override
  String get challengeConfirmBody =>
      'Ini akan mereset Streak Reguler kamu dan memulai tantangan baru.';

  @override
  String get challengeConfirmRequirementsTitle => 'Syarat Mode Tantangan:';

  @override
  String get challengeConfirmRequirementAnswers =>
      '✓ Harus jawab SEMUA dengan benar';

  @override
  String challengeConfirmRequirementTimer(int seconds) {
    return '✓ Timer terkunci di $seconds detik';
  }

  @override
  String challengeConfirmRequirementFrequency(int count) {
    return '✓ Frekuensi notifikasi terkunci $count/hari';
  }

  @override
  String challengeConfirmRequirementDays(int days) {
    return '✓ Selesaikan $days hari berturut-turut';
  }

  @override
  String get challengeConfirmFooter =>
      'Pengaturan waktu kamu terkunci selama tantangan. Jika \"Kirim kapan saja\" AKTIF, jendela waktu terkunci. Jika NONAKTIF, kamu bisa mengubah jam mulai/selesai selama tantangan.';

  @override
  String get existingStreakTitle => 'Anda Memiliki Streak Reguler Aktif';

  @override
  String existingStreakMessage(int streak) {
    return 'Anda saat ini memiliki streak reguler $streak hari! Terus tingkatkan atau coba Mode Tantangan baru.';
  }

  @override
  String get existingStreakWarning =>
      '⚠️ Pilih Jalur Anda:\n\n📊 STREAK REGULER (Pertahankan):\n• Jawab setiap hari dengan timer apa saja\n• Kecepatan lambat, menyesuaikan\n• Bangun konsistensi\n\n🔥 MODE TANTANGAN (Baru):\n• Mode intensif 7 hari\n• HARUS jawab SEMUA dengan benar\n• HARUS gunakan timer 5–10 detik saja\n• Hari aktif terkunci selama tantangan\n• Pengaturan waktu terkunci selama tantangan\n• Ketinggalan satu = ulang\n• Menang = Lencana + pertanyaan gratis';

  @override
  String get existingStreakKeep => 'Pertahankan Streak Reguler';

  @override
  String get existingStreakStart => 'Mulai Mode Tantangan';
}
