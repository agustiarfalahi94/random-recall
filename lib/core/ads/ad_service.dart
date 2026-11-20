import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/date_utils.dart' as date_utils;
import 'ad_config.dart';

/// Master switch for all ad serving.
///
/// Random Recall ships as a single **full version**: nothing is locked and
/// there is no subscription, so ads are the only revenue and every user sees
/// them. Keep this `true` for anything that reaches a store.
///
/// Two Android-specific constraints shaped this class:
///  * An [AdWidget] is a platform view. Mounting one forces the whole app onto
///    the hybrid-composition path, which made typing in the question/answer
///    fields visibly laggy (v0.13.20 regression). The banner is therefore never
///    mounted while the keyboard is up, and text-entry screens opt out with
///    [AdService.enterExcludedScreen].
///  * On a device where ad domains are filtered at the DNS level every request
///    fails. Failures are retried with exponential backoff (capped) instead of
///    hot-looping, and the app stays fully usable without ads.
const bool kAdsEnabled = true;

class AdService {
  static final AdService instance = AdService._();
  AdService._();

  // ── State ──────────────────────────────────────────────────────────────────

  bool _onExcludedScreen = false;
  bool _initialized = false;

  /// Whether the UMP consent flow allows ad requests. Always check this before
  /// requesting ads — Google requires consent to be established first in
  /// regions where it applies.
  bool _canRequestAds = false;
  bool get canRequestAds => _canRequestAds;

  final ValueNotifier<bool> bannerVisible = ValueNotifier(false);

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  /// Screen width the banner should fit, reported by [ensureBannerLoaded].
  double? _bannerWidth;

  /// Width the currently loaded ad was sized for (null while none is loaded).
  double? _loadedForWidth;

  /// True once `MobileAds.initialize()` finished — loads before that would fail.
  bool _sdkReady = false;

  /// Guards against an out-of-order async size lookup replacing a newer ad.
  int _bannerLoadToken = 0;

  /// Backoff for banner reloads after a failure (no fill, offline, or blocked).
  int _bannerRetryMinutes = 1;
  static const int _bannerRetryMaxMinutes = 10;

  /// Actual loaded banner height — used by the wrapper to compute bottom padding.
  /// Falls back to AdSize.banner.height (50dp) until the ad is loaded.
  double get bannerHeight =>
      (_bannerAd?.size.height.toDouble()) ?? AdSize.banner.height.toDouble();

  InterstitialAd? _interstitialAd;

  // Frequency cap state
  int _adsShownToday = 0;
  DateTime? _lastAdTime;

  // Ad unit IDs and the App ID live in `ad_config.dart` — one file to edit at
  // launch. Debug builds resolve to Google's sample IDs.

  static const int _maxAdsPerDay = 5;
  static const Duration _minAdGap = Duration(minutes: 10);

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!kAdsEnabled) return;
    if (_initialized) return;
    _initialized = true;

    // Consent first: Google requires the UMP flow to run before the first ad
    // request. Existing consent from a previous session is reused automatically.
    await _gatherConsent();
    if (!_canRequestAds) {
      debugPrint('AdService: no consent to request ads — ads stay off');
      return;
    }

    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: kDebugMode
            ? AdMobConfig.testDeviceIds
            : const <String>[],
      ),
    );
    if (kReleaseMode && !AdMobConfig.isConfigured) {
      debugPrint(
        'AdService: release build with placeholder AdMob IDs — no ads will '
        'serve. Fill in lib/core/ads/ad_config.dart before uploading.',
      );
    }
    await _loadFrequencyState();
    _sdkReady = true;
    // The banner itself is requested by AdBannerWidget once it knows the real
    // screen width; if a widget mounted before the SDK was ready, load now.
    if (_bannerWidth != null) _loadBannerAd();
    _preloadInterstitialAd();
  }

  // ── Consent (Google User Messaging Platform) ───────────────────────────────

  /// Refreshes consent information and shows the consent form when the user's
  /// region requires it.
  ///
  /// The form itself is authored in the AdMob console (Privacy & messaging).
  /// Until such a message exists this completes without showing anything and
  /// `canRequestAds` stays true outside consent-required regions.
  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(consentDebugSettings: _consentDebugSettings()),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint(
              'AdService: consent form error ${formError.errorCode}: '
              '${formError.message}',
            );
          }
          if (!done.isCompleted) done.complete();
        });
      },
      (formError) {
        // Consent info could not be updated (offline, no message configured).
        // Fall back to whatever status the SDK already has.
        debugPrint(
          'AdService: consent update failed ${formError.errorCode}: '
          '${formError.message}',
        );
        if (!done.isCompleted) done.complete();
      },
    );

    // Never let a slow/hanging consent fetch block startup.
    await done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => debugPrint('AdService: consent update timed out'),
    );
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    debugPrint('AdService: canRequestAds=$_canRequestAds');
  }

  /// Debug-only geography override from `AdMobConfig.debugConsentGeography`, so
  /// the consent form and the Settings → Ad privacy row can be tested from a
  /// country where Google would not show a form. Always null in release builds.
  static ConsentDebugSettings? _consentDebugSettings() {
    if (kReleaseMode) return null;
    final geography = switch (AdMobConfig.debugConsentGeography.toLowerCase()) {
      'eea' => DebugGeography.debugGeographyEea,
      'us' ||
      'usstate' ||
      'regulatedusstate' => DebugGeography.debugGeographyRegulatedUsState,
      _ => null,
    };
    if (geography == null) return null;
    debugPrint(
      'AdService: UMP debug geography = ${AdMobConfig.debugConsentGeography} '
      '(test devices: ${AdMobConfig.testDeviceIds.join(", ")})',
    );
    return ConsentDebugSettings(
      debugGeography: geography,
      testIdentifiers: AdMobConfig.testDeviceIds,
    );
  }

  /// Whether the user's region/message requires a persistent entry point to the
  /// privacy options form (shown in Settings when true).
  Future<bool> isPrivacyOptionsRequired() async {
    if (!kAdsEnabled) return false;
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('AdService: privacy options status failed: $e');
      return false;
    }
  }

  /// Re-opens the UMP privacy options form so the user can change or withdraw
  /// their ad consent at any time. Returns true if a form was shown.
  Future<bool> showPrivacyOptionsForm() async {
    if (!kAdsEnabled) return false;
    final done = Completer<bool>();
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint(
            'AdService: privacy options form error ${formError.errorCode}: '
            '${formError.message}',
          );
        }
        if (!done.isCompleted) done.complete(formError == null);
      });
      final shown = await done.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
      await _applyConsentChange();
      return shown;
    } catch (e) {
      debugPrint('AdService: privacy options form failed: $e');
      return false;
    }
  }

  /// Re-reads consent after the user edits their choices and stops serving ads
  /// immediately if consent was withdrawn.
  Future<void> _applyConsentChange() async {
    final previous = _canRequestAds;
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (!_canRequestAds) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _bannerLoaded = false;
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _refreshBannerVisible();
      debugPrint('AdService: consent withdrawn — ads stopped');
    } else if (!previous) {
      // Consent granted (or restored) after the SDK was skipped at startup.
      _loadBannerAd();
      _preloadInterstitialAd();
    }
  }

  // ── Banner visibility ──────────────────────────────────────────────────────

  /// Call in initState of screens where the banner must be hidden
  /// (QuestionScreen, NotificationQuestionScreen, text-entry screens).
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
    final next = !_onExcludedScreen && _bannerLoaded;
    if (bannerVisible.value == next) return;
    // Defer to avoid markNeedsBuild during build (called from initState/dispose).
    Future.microtask(() => bannerVisible.value = next);
  }

  // ── Banner ad loading ──────────────────────────────────────────────────────

  BannerAd? get bannerAd => _bannerLoaded ? _bannerAd : null;

  /// Asks for a banner that fits [width] (device-independent pixels).
  ///
  /// Called from [AdBannerWidget.didChangeDependencies] — the only place where
  /// `MediaQuery.sizeOf` is valid and where we know the real screen width. Safe
  /// to call repeatedly: a loaded ad of the same width is reused, and a call
  /// before `MobileAds.initialize()` simply records the width to load later.
  void ensureBannerLoaded(double width) {
    if (!kAdsEnabled) return;
    final w = width.roundToDouble();
    if (w <= 0) return;
    _bannerWidth = w;
    if (!_sdkReady || !_canRequestAds) return;
    if (_bannerLoaded && _loadedForWidth == w) return;
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    if (!_canRequestAds) return;
    final width = _bannerWidth ?? AdSize.banner.width.toDouble();
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerLoaded = false;
    _loadedForWidth = null;
    _refreshBannerVisible();

    final token = ++_bannerLoadToken;

    // Anchored adaptive banner: fills the width with the right height for the
    // current orientation. Falls back to the standard 320x50 banner if the
    // platform can't size it.
    AdSize size = AdSize.banner;
    try {
      final adaptive = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
        width.round(),
      );
      if (adaptive != null) size = adaptive;
    } catch (e) {
      debugPrint('AdService: adaptive banner size unavailable ($e)');
    }
    // A newer request (rotation, wider screen) or a consent withdrawal won the
    // race while we awaited the size.
    if (token != _bannerLoadToken || !_canRequestAds) return;

    _bannerAd = BannerAd(
      adUnitId: AdMobConfig.resolvedBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          _loadedForWidth = width;
          _bannerRetryMinutes = 1; // healthy again — reset the backoff
          debugPrint(
            'AdService: banner loaded '
            '(${_bannerAd?.size.width}x${_bannerAd?.size.height})',
          );
          _refreshBannerVisible();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _bannerLoaded = false;
          _loadedForWidth = null;
          _refreshBannerVisible();
          debugPrint(
            'AdMob Banner failed to load: code=${error.code}, '
            'domain=${error.domain}, message=${error.message}',
          );
          // Non-fatal: ads are best-effort and must never disturb the user.
          FirebaseCrashlytics.instance
              .recordError(
                error,
                StackTrace.current,
                reason: 'AdMob banner load failed (code ${error.code})',
                fatal: false,
              )
              .ignore();
          final delay = Duration(minutes: _bannerRetryMinutes);
          _bannerRetryMinutes = (_bannerRetryMinutes * 2).clamp(
            1,
            _bannerRetryMaxMinutes,
          );
          debugPrint('AdService: retrying banner in $_bannerRetryMinutes min');
          Future.delayed(delay, () => _loadBannerAd());
        },
      ),
    )..load();
  }

  // ── Interstitial ad ────────────────────────────────────────────────────────

  void _preloadInterstitialAd() {
    if (!_canRequestAds) return;
    // No production interstitial unit configured yet — don't fire requests that
    // can only fail.
    if (!AdMobConfig.hasRealInterstitial) return;
    if (_interstitialAd != null) return;
    InterstitialAd.load(
      adUnitId: AdMobConfig.resolvedInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  bool get _canShowInterstitial {
    if (!_canRequestAds) return false;
    if (_interstitialAd == null) return false;
    _checkDailyReset();
    if (_adsShownToday >= _maxAdsPerDay) return false;
    if (_lastAdTime != null &&
        DateTime.now().difference(_lastAdTime!) < _minAdGap) {
      return false;
    }
    return true;
  }

  /// Shows the interstitial ad if frequency rules allow it.
  /// Safe to call on every organic answer — the rules are enforced internally.
  Future<void> showInterstitialAd() async {
    if (!kAdsEnabled) return;
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
    debugPrint(
      'AdService: loaded — adsToday=$_adsShownToday, lastAd=$_lastAdTime',
    );
  }

  Future<void> _saveFrequencyState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ad_last_date', _dateKey(DateTime.now()));
    await prefs.setInt('ad_count_today', _adsShownToday);
    if (_lastAdTime != null) {
      await prefs.setInt(
        'ad_last_time_ms',
        _lastAdTime!.millisecondsSinceEpoch,
      );
    }
  }

  String _dateKey(DateTime d) => date_utils.dateKey(d);
}
