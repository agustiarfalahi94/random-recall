import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/tutorial/tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TourService', () {
    late TourService tour;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tour = TourService();
      await tour.initialize();
    });

    test('shouldShowTour is true when flag absent', () {
      expect(tour.shouldShowTour(), true);
    });

    test('markCompleted sets flag and hides tour', () async {
      await tour.markCompleted();
      expect(tour.shouldShowTour(), false);
    });

    test('markSkipped sets flag and hides tour', () async {
      await tour.markSkipped();
      expect(tour.shouldShowTour(), false);
    });
  });
}
