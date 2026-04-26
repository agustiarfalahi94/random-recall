import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService instance = AdService._();
  AdService._();

  // ── State ──────────────────────────────────────────────────────────────────

  bool _isPremium = false;
  bool _onExcludedScreen = false;
  bool _initialized = false;

  final ValueNotifier<bool> bannerVisible = ValueNotifier(false);

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  InterstitialAd? _interstitialAd;

  // Frequency cap state
  int _adsShownToday = 0;
  DateTime? _lastAdTime;

  // ── Ad unit IDs (test IDs — swap for real ones when account is ready) ──────

  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const int _maxAdsPerDay = 5;
  static const Duration _minAdGap = Duration(minutes: 10);

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> initialize({required bool isPremium}) async {
    if (_initialized) return;
    _initialized = true;
    _isPremium = isPremium;

    if (_isPremium) return; // premium users never get ads

    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: [
          '83E09F11EC864330DDCC14D0732D7D30', // Xiaomi 15
          '511C623543A19E3BE41273359A5C2BE8', // Xiaomi 12T
        ],
      ),
    );
    await _loadFrequencyState();
    _loadBannerAd();
    _preloadInterstitialAd();
  }

  // ── Premium toggle ─────────────────────────────────────────────────────────

  void setPremium(bool isPremium) {
    _isPremium = isPremium;
    if (_isPremium) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _bannerLoaded = false;
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }
    _refreshBannerVisible();
  }

  // ── Banner visibility ──────────────────────────────────────────────────────

  /// Call in initState of screens where the banner must be hidden
  /// (QuestionScreen, NotificationQuestionScreen).
  void enterExcludedScreen() {
    _onExcludedScreen = true;
    _refreshBannerVisible();
  }

  /// Call in dispose of the excluded screens to restore the banner.
  void exitExcludedScreen() {
    _onExcludedScreen = false;
    _refreshBannerVisible();
  }

  void _refreshBannerVisible() {
    bannerVisible.value = !_isPremium && !_onExcludedScreen && _bannerLoaded;
  }

  // ── Banner ad loading ──────────────────────────────────────────────────────

  BannerAd? get bannerAd => _bannerLoaded ? _bannerAd : null;

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerLoaded = false;
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          _refreshBannerVisible();
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
          _bannerLoaded = false;
          _refreshBannerVisible();
          // Retry after a delay
          Future.delayed(const Duration(minutes: 1), _loadBannerAd);
        },
      ),
    )..load();
  }

  // ── Interstitial ad ────────────────────────────────────────────────────────

  void _preloadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  bool get _canShowInterstitial {
    if (_isPremium || _interstitialAd == null) return false;
    _checkDailyReset();
    if (_adsShownToday >= _maxAdsPerDay) return false;
    if (_lastAdTime != null &&
        DateTime.now().difference(_lastAdTime!) < _minAdGap) return false;
    return true;
  }

  /// Shows the interstitial ad if frequency rules allow it.
  /// Safe to call on every organic answer — the rules are enforced internally.
  Future<void> showInterstitialAd() async {
    if (!_canShowInterstitial) {
      // Preload for next eligible window if we don't have one
      if (_interstitialAd == null) _preloadInterstitialAd();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preloadInterstitialAd();
      },
    );

    await ad.show();

    _adsShownToday++;
    _lastAdTime = DateTime.now();
    await _saveFrequencyState();
  }

  // ── Frequency cap persistence ──────────────────────────────────────────────

  void _checkDailyReset() {
    final today = _dateKey(DateTime.now());
    if (_lastAdTime != null && _dateKey(_lastAdTime!) != today) {
      _adsShownToday = 0;
    }
  }

  Future<void> _loadFrequencyState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final savedDate = prefs.getString('ad_last_date') ?? '';
    if (savedDate == today) {
      _adsShownToday = prefs.getInt('ad_count_today') ?? 0;
      final lastMs = prefs.getInt('ad_last_time_ms');
      if (lastMs != null) {
        _lastAdTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
    } else {
      _adsShownToday = 0;
    }
    debugPrint('AdService: loaded — adsToday=$_adsShownToday, lastAd=$_lastAdTime');
  }

  Future<void> _saveFrequencyState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ad_last_date', _dateKey(DateTime.now()));
    await prefs.setInt('ad_count_today', _adsShownToday);
    if (_lastAdTime != null) {
      await prefs.setInt(
          'ad_last_time_ms', _lastAdTime!.millisecondsSinceEpoch);
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
