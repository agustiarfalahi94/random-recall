// lib/widgets/tour/tour_overlay.dart
//
// REDESIGNED (2026-08-06): the tour now uses showcaseview's intended API —
// the REAL target widgets are wrapped in `Showcase(key: ..., child: ...)` via
// [TourTarget]. Each GlobalKey belongs to exactly ONE showcase, so the element
// tree stays consistent. This file hosts the ShowcaseView controller, the
// step-advance logic, and the managed full-screen overlays for the two steps
// that have no real target (the in-sheet schedule step + the done step).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:random_recall/l10n/app_localizations.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../core/tutorial/tour_service.dart';
import '../../main.dart' show navigatorKey;

/// Wraps the app content with the tour's showcase controller. Must be mounted
/// inside the Navigator's subtree (e.g. wrapping the Home screen scaffold).
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.child});

  /// The app content the tour highlights.
  final Widget child;

  /// Scope used to link [TourTarget] showcases to this controller.
  static const String scopeName = 'random_recall_tour';

  /// Convenience: starts the tour from any context that is a descendant of
  /// [TourOverlay] (e.g. from the Home screen), after the UI has settled.
  static void start(BuildContext context) {
    context.findAncestorStateOfType<TourOverlayState>()?.start();
  }

  /// Called by the [TourTarget] wrappers when their highlighted target is
  /// tapped while the tour is running.
  static void handleTargetTap(BuildContext context, GlobalKey targetKey) {
    context.findAncestorStateOfType<TourOverlayState>()?.onTargetTapped(
      targetKey,
    );
  }

  @override
  State<TourOverlay> createState() => TourOverlayState();
}

/// Public state so callers can hold a `GlobalKey<TourOverlayState>` and call
/// [start] after the first frame.
class TourOverlayState extends State<TourOverlay> {
  late final ShowcaseView _showcaseView;

  List<TourStep> _steps = const [];
  Timer? _pendingTimer;
  bool _sheetOpenForTour = false; // settings sheet opened by the tour (step 6)
  bool _skipping = false;
  bool _disposing = false;
  final List<OverlayEntry> _managedEntries = [];

  @override
  void initState() {
    super.initState();
    _showcaseView = ShowcaseView.register(
      scope: TourOverlay.scopeName,
      onStart: _onStepStart,
      onComplete: _onStepComplete,
      onFinish: _onShowcaseFinished,
      onDismiss: _onShowcaseDismissed,
      disableMovingAnimation: true,
      disableScaleAnimation: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    // A Skip button on every tooltip.
    _showcaseView.globalTooltipActions = [
      TooltipActionButton(
        type: TooltipDefaultActionType.skip,
        name: l10n.tourSkip,
        onTap: _skip,
      ),
    ];
  }

  /// Starts the tour from step 1. No-op if it is already running. Safe to call
  /// again later (e.g. re-running the tour from the Settings sheet).
  void start() {
    if (_showcaseView.isShowcaseRunning) return;
    setState(() {
      _steps = TourService.instance.steps;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDriver());
  }

  void _startDriver() {
    if (!mounted || _steps.isEmpty) return;
    _showcaseView.startShowCase([for (final s in _steps) s.targetKey]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Steps without a real target (in-sheet schedule fallback + done)
        // still need a registered Showcase so the controller can advance to
        // them. They are zero-size and fully covered by the managed overlays.
        for (final step in _steps)
          if (step.behavior == TourStepBehavior.tapThrough ||
              step.behavior == TourStepBehavior.done)
            Showcase(
              key: step.targetKey,
              scope: TourOverlay.scopeName,
              title: null,
              description: '',
              child: const SizedBox.shrink(),
            ),
      ],
    );
  }

  /// Invoked by [TourTarget] when the user taps the highlighted target.
  void onTargetTapped(GlobalKey key) {
    if (_skipping) return;
    final step = _stepByKey(key);
    if (step == null) return;
    _onStepAction(step);
  }

  // ── Step lifecycle ──────────────────────────────────────────────────────

  void _onStepStart(int? index, GlobalKey key) {
    final step = _stepByKey(key);
    if (step == null) return;
    switch (step.behavior) {
      case TourStepBehavior.tapThrough:
        // Step 7: `scheduleTileKey` has no real target (inside the settings
        // sheet), so use the documented fallback: a text overlay over the
        // sheet.
        _showManagedOverlay(step, onTap: _onStep7Tapped);
      case TourStepBehavior.done:
        // Step 8: "You're all set" overlay, tap anywhere to finish.
        _showManagedOverlay(step, onTap: _onDoneTapped);
      case TourStepBehavior.runAction:
      case TourStepBehavior.tabSwitch:
        break;
    }
  }

  void _onStepComplete(int? index, GlobalKey key) {
    // Safety net: if a managed step is ever completed without its overlay tap
    // handler (e.g. a stray advance), drop the floating overlay.
    _removeManagedEntries();
  }

  void _onShowcaseFinished() {
    _removeManagedEntries();
    _closeSheetIfOpen();
  }

  void _onShowcaseDismissed(GlobalKey? dismissedAt) {
    _removeManagedEntries();
    if (_skipping) {
      _skipping = false;
      unawaited(TourService.instance.markSkipped());
    }
  }

  // ── Target interaction (steps 1–6) ──────────────────────────────────────

  void _onStepAction(TourStep step) {
    switch (step.behavior) {
      case TourStepBehavior.runAction:
        final fired = _fireRealAction(step);
        _handleRunActionAdvance(step, fired: fired);
      case TourStepBehavior.tabSwitch:
        _performTabSwitch(step);
      case TourStepBehavior.tapThrough:
      case TourStepBehavior.done:
        break; // handled by the managed full-screen overlays
    }
  }

  /// The showcase's TargetWidget wins the tap arena, so the real button's
  /// `onPressed` never fires on its own. Walk the target's element tree to
  /// find the button and invoke it directly.
  bool _fireRealAction(TourStep step) {
    final ctx = step.targetKey.currentContext;
    if (ctx == null) return false;
    return _fireButtonIn(ctx as Element);
  }

  bool _fireButtonIn(Element element) {
    final onPressed = _onPressedOf(element.widget);
    if (onPressed != null) {
      onPressed();
      return true;
    }
    var fired = false;
    element.visitChildElements((child) {
      if (!fired && _fireButtonIn(child)) fired = true;
    });
    return fired;
  }

  VoidCallback? _onPressedOf(Widget widget) {
    if (widget is FloatingActionButton) return widget.onPressed;
    if (widget is ElevatedButton) return widget.onPressed;
    if (widget is IconButton) return widget.onPressed;
    if (widget is OutlinedButton) return widget.onPressed;
    if (widget is TextButton) return widget.onPressed;
    if (widget is FilledButton) return widget.onPressed;
    return null;
  }

  void _handleRunActionAdvance(TourStep step, {required bool fired}) {
    if (step.copyKey == 'tourPracticeBody') {
      // Step 1: Practice Now pushes a route — advance when the user comes back.
      unawaited(_waitForRoutePop());
    } else if (step.closesSheetOnAdvance) {
      // Step 3: the Add FAB opens the Add-menu sheet — close it, then advance.
      _pendingTimer = Timer(Duration(milliseconds: fired ? 600 : 400), () {
        if (fired) navigatorKey.currentState?.pop();
        _advance();
      });
    } else {
      // Step 6: the settings gear opens the settings sheet. Keep it open — the
      // step 7 overlay floats over it. Advance once the sheet has settled.
      _sheetOpenForTour = fired;
      _pendingTimer = Timer(const Duration(milliseconds: 400), _advance);
    }
  }

  /// Polls until the route pushed by the practice button pops (user backs out),
  /// then advances the tour. Safe if the action did not actually push a route:
  /// `canPop()` is already false, so it advances immediately.
  Future<void> _waitForRoutePop() async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    while (mounted && !_skipping && nav.canPop()) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted || _skipping) return;
    _advance();
  }

  /// The nav icons have no tap handler of their own (the `NavigationBar`
  /// handles it), and the overlay captures the tap anyway — so drive the tab
  /// switch directly, then advance once the new tab has settled.
  void _performTabSwitch(TourStep step) {
    final ctx = step.targetKey.currentContext;
    final navBar = ctx?.findAncestorWidgetOfExactType<NavigationBar>();
    if (navBar == null) return;
    navBar.onDestinationSelected?.call(_tabIndexFor(step.copyKey));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_skipping) _advance();
    });
  }

  int _tabIndexFor(String copyKey) {
    switch (copyKey) {
      case 'tourQuestionsBody':
        return 1;
      case 'tourAnalyticsBody':
        return 2;
      case 'tourHomeBody':
        return 0;
      default:
        return 0;
    }
  }

  // ── Managed full-screen overlays (step 7 fallback + done step) ──────────

  void _showManagedOverlay(TourStep step, {required VoidCallback onTap}) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    _insertManagedEntry(
      _TourOverlayScreen(
        body: TourService.instance.copyFor(l10n, step.targetKey),
        onTap: onTap,
        onSkip: _skip,
        skipLabel: l10n.tourSkip,
        dim: step.behavior == TourStepBehavior.done,
      ),
    );
  }

  void _onStep7Tapped() {
    if (_skipping) return;
    _removeManagedEntries();
    _advance(); // → done step
  }

  void _onDoneTapped() {
    if (_skipping) return;
    _removeManagedEntries();
    _closeSheetIfOpen();
    unawaited(TourService.instance.markCompleted());
    _advance(); // finishes the sequence → onFinish
  }

  // ── Skip / finish / teardown ────────────────────────────────────────────

  void _skip() {
    if (_skipping) return;
    _skipping = true;
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _removeManagedEntries();
    _closeSheetIfOpen();
    _showcaseView.dismiss();
  }

  void _advance() {
    if (_disposing || _showcaseView.isShowCaseCompleted) return;
    _showcaseView.next();
  }

  void _closeSheetIfOpen() {
    if (_disposing) return;
    if (_sheetOpenForTour && (navigatorKey.currentState?.canPop() ?? false)) {
      navigatorKey.currentState?.pop();
    }
    _sheetOpenForTour = false;
  }

  void _insertManagedEntry(Widget child) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    final entry = OverlayEntry(builder: (_) => child);
    _managedEntries.add(entry);
    overlay.insert(entry);
  }

  void _removeManagedEntries() {
    for (final entry in _managedEntries) {
      if (entry.mounted) entry.remove();
    }
    _managedEntries.clear();
  }

  TourStep? _stepByKey(GlobalKey key) {
    for (final step in _steps) {
      if (step.targetKey == key) return step;
    }
    return null;
  }

  @override
  void dispose() {
    _disposing = true;
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _removeManagedEntries();
    if (_showcaseView.isShowcaseRunning) {
      _showcaseView.dismiss();
    }
    _showcaseView.unregister();
    super.dispose();
  }
}

/// Wraps a REAL target widget with the tour's `Showcase`.
///
/// Inert when the tour is disabled (renders [child] untouched). When enabled,
/// the widget registers the target in the tour's scope; tapping the
/// highlighted target while the tour is running fires [TourOverlay]'s step
/// logic. Each [targetKey] is used by exactly one showcase.
class TourTarget extends StatelessWidget {
  const TourTarget({super.key, required this.targetKey, required this.child});

  final GlobalKey targetKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!TourService.enabled || l10n == null) return child;

    final step = TourService.instance.stepForKey(targetKey);
    final isManaged =
        step?.behavior == TourStepBehavior.tapThrough ||
        step?.behavior == TourStepBehavior.done;

    return Showcase(
      key: targetKey,
      scope: TourOverlay.scopeName,
      title: null,
      description: step == null
          ? ''
          : TourService.instance.copyFor(l10n, targetKey),
      // runAction: a barrier tap must not advance/strand the tour behind a
      // route. Managed steps are fully covered by the custom overlay, so their
      // placeholder Showcase must not react to taps either.
      disableBarrierInteraction:
          isManaged || step?.behavior == TourStepBehavior.runAction,
      onTargetClick: isManaged
          ? null
          : () => TourOverlay.handleTargetTap(context, targetKey),
      disposeOnTap: isManaged ? null : false,
      child: child,
    );
  }
}

/// Full-screen plain-text overlay used for the step 7 fallback and the final
/// "You're all set" step. Tap anywhere advances; the Skip button skips.
class _TourOverlayScreen extends StatelessWidget {
  const _TourOverlayScreen({
    required this.body,
    required this.onTap,
    required this.onSkip,
    required this.skipLabel,
    this.dim = false,
  });

  final String body;
  final VoidCallback onTap;
  final VoidCallback onSkip;
  final String skipLabel;

  /// Darker background for the done step.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: dim ? Colors.black87 : Colors.black45,
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: onSkip, child: Text(skipLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
