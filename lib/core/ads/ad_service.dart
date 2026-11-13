import 'dart:async';

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
    _loadBannerAd();
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

  void _loadBannerAd() {
    if (!_canRequestAds) return;
    _bannerAd?.dispose();
    _bannerLoaded = false;
    _bannerAd = BannerAd(
      adUnitId: AdMobConfig.resolvedBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          _bannerRetryMinutes = 1; // healthy again — reset the backoff
          _refreshBannerVisible();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _bannerLoaded = false;
          _refreshBannerVisible();
          debugPrint(
            'AdService: banner load failed (${error.code}) — retrying in '
            '$_bannerRetryMinutes min',
          );
          final delay = Duration(minutes: _bannerRetryMinutes);
          _bannerRetryMinutes = (_bannerRetryMinutes * 2).clamp(
            1,
            _bannerRetryMaxMinutes,
          );
          Future.delayed(delay, _loadBannerAd);
        },
      ),
    )..load();
  }

  // ── Interstitial ad ────────────────────────────────────────────────────────

  void _preloadInterstitialAd() {
    if (!_canRequestAds) return;
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
