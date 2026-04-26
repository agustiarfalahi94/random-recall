import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads/ad_service.dart';

/// Renders the loaded banner ad. Sized exactly to the ad's reported dimensions.
/// Only shown when AdService.bannerVisible is true — this widget itself doesn't
/// check visibility; that is handled by the root-level wrapper in main.dart.
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({super.key});

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
