import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads/ad_service.dart';

/// Renders the loaded banner ad, sized exactly to the ad's reported dimensions.
///
/// The ad itself is owned by [AdService] — it has to outlive this widget,
/// because the banner is remounted every time the keyboard closes or the user
/// leaves a question screen. This widget only asks the service to load a banner
/// that fits the current screen width, then renders it. When there is no loaded
/// ad (offline, no fill, consent missing) it collapses to nothing.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only valid from here on (not in initState), and this must
    // run once per mount — not on every rebuild.
    if (_requested) return;
    _requested = true;
    AdService.instance.ensureBannerLoaded(MediaQuery.sizeOf(context).width);
  }

  @override
  Widget build(BuildContext context) {
    final ad = AdService.instance.bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
