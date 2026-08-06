// lib/widgets/tour/tour_overlay.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../core/tutorial/tour_service.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show navigatorKey;

/// Drives the interactive tutorial: wraps the app content with one [Showcase]
/// per [TourStep] and orchestrates the advance rules (runAction / tabSwitch /
/// tapThrough / done) + the skip button.
///
/// ## Placement constraint (important)
/// [TourOverlay] must be mounted **inside the Navigator's subtree** (e.g.
/// wrapping the Home screen content). The `Showcase` widgets resolve the root
/// `Overlay` via `context.findRootAncestorStateOfType<OverlayState>()`; if the
/// overlay is mounted above the Navigator (e.g. inside `MaterialApp.builder`),
/// that lookup returns null and the spotlight overlay silently fails to render.
///
/// ## Why the overlay drives the real actions itself
/// ShowcaseView's translucent `TargetWidget` sits on top of the target and wins
/// the tap arena, so the real button's `onPressed` / the `NavigationBar`'s tap
/// never fire on their own. Step 1–6 therefore use `onTargetClick` to (a) fire
/// the real action by traversing the target's element tree, and (b) control the
/// advance.
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.child});

  /// The app content the tour highlights.
  final Widget child;

  /// Convenience: starts the tour from any context that is a descendant of
  /// [TourOverlay] (e.g. from the Home screen), after the UI has settled.
  static void start(BuildContext context) {
    context.findAncestorStateOfType<TourOverlayState>()?.start();
  }

  @override
  State<TourOverlay> createState() => TourOverlayState();
}

/// Public state so callers can hold a `GlobalKey<TourOverlayState>` and call
/// [TourOverlayState.start] after the first frame.
class TourOverlayState extends State<TourOverlay> {
  static const String _scopeName = 'random_recall_tour';

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
    // `ShowcaseView.register` (v5 API) is used instead of the deprecated
    // `ShowCaseWidget` so `flutter analyze` stays clean.
    _showcaseView = ShowcaseView.register(
      scope: _scopeName,
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
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        for (final step in _steps)
          _TourShowcase(step: step, l10n: l10n, onStepAction: _onStepAction),
      ],
    );
  }

  // ── Step lifecycle ──────────────────────────────────────────────────────

  void _onStepStart(int? index, GlobalKey key) {
    final step = _stepByKey(key);
    if (step == null) return;
    switch (step.behavior) {
      case TourStepBehavior.tapThrough:
        // Step 7: `scheduleTileKey` has no context (not attached in this task
        // scope), so the real in-sheet spotlight is impossible. Use the
        // documented fallback: a plain text overlay over the sheet.
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

  /// The overlay's translucent TargetWidget wins the tap arena, so the real
  /// button's `onPressed` never fires on its own. Walk the target's element
  /// tree to find the button and invoke it directly.
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
        body: _tourCopy(l10n, step.copyKey).replaceAll('**', ''),
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

/// One `Showcase` for one `TourStep`, positioned exactly over the step's target
/// via a [Positioned] box.
///
/// The `Showcase`'s `key` is a registry id in showcaseview 5.x (never attached
/// to the element), so reusing the same `GlobalKey` as the screen's KeyedSubtree
/// is safe. The overlay computes the target rect from this box via
/// `box.localToGlobal(ancestor: rootOverlay)`.
class _TourShowcase extends StatefulWidget {
  const _TourShowcase({
    required this.step,
    required this.l10n,
    required this.onStepAction,
  });

  final TourStep step;
  final AppLocalizations l10n;
  final ValueChanged<TourStep> onStepAction;

  @override
  State<_TourShowcase> createState() => _TourShowcaseState();
}

class _TourShowcaseState extends State<_TourShowcase> {
  Rect? _rect;

  Rect? _measureNow() {
    final ctx = widget.step.targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return Rect.fromLTWH(
      box.localToGlobal(Offset.zero).dx,
      box.localToGlobal(Offset.zero).dy,
      box.size.width,
      box.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Measure in build (targets are laid out by the time the tour starts) and
    // re-measure post-frame to catch any later size/position changes.
    final measured = _measureNow();
    if (measured != _rect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      _rect = measured;
    }

    final rect = _rect;
    final behavior = widget.step.behavior;
    final isManaged =
        behavior == TourStepBehavior.tapThrough ||
        behavior == TourStepBehavior.done;

    final showcase = Showcase(
      key: widget.step.targetKey,
      title: null,
      description: isManaged
          ? ''
          : _tourCopy(widget.l10n, widget.step.copyKey).replaceAll('**', ''),
      targetPadding: const EdgeInsets.all(8),
      // runAction: a barrier tap must not advance/strand the tour behind a
      // route. Managed steps are fully covered by the custom overlay, so their
      // placeholder Showcase must not react to taps either.
      disableBarrierInteraction:
          isManaged || behavior == TourStepBehavior.runAction,
      onTargetClick: isManaged ? null : () => widget.onStepAction(widget.step),
      disposeOnTap: isManaged ? null : false,
      child: SizedBox(width: rect?.width ?? 0, height: rect?.height ?? 0),
    );

    if (!isManaged && rect != null) {
      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: showcase,
      );
    }
    // Placeholder (steps 7–8): zero-size, hidden behind the managed overlay,
    // but still registered so the controller does not auto-finish the tour.
    return const Positioned(
      left: 0,
      top: 0,
      width: 0,
      height: 0,
      child: SizedBox.shrink(),
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

/// Resolves the localized copy for a tour `copyKey`.
String _tourCopy(AppLocalizations l10n, String copyKey) {
  switch (copyKey) {
    case 'tourPracticeBody':
      return l10n.tourPracticeBody;
    case 'tourQuestionsBody':
      return l10n.tourQuestionsBody;
    case 'tourAddBody':
      return l10n.tourAddBody;
    case 'tourAnalyticsBody':
      return l10n.tourAnalyticsBody;
    case 'tourHomeBody':
      return l10n.tourHomeBody;
    case 'tourSettingsBody':
      return l10n.tourSettingsBody;
    case 'tourScheduleBody':
      return l10n.tourScheduleBody;
    case 'tourDoneBody':
      return l10n.tourDoneBody;
    default:
      return copyKey;
  }
}
