// Flutter's desktop Windowing API is intentionally internal while experimental.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_window.dart';
import '../features/overlay/overlay_window.dart';
import '../features/session/session_controller.dart';
import 'app_constants.dart';
import 'lapse_theme.dart';

class _CallbackWindowDelegate with WindowControllerDelegate {
  _CallbackWindowDelegate(this.onClose);
  final VoidCallback onClose;
  @override
  void onWindowCloseRequested(WindowController controller) => onClose();
}

class LapseWindowHost extends ConsumerStatefulWidget {
  const LapseWindowHost({super.key});
  @override
  ConsumerState<LapseWindowHost> createState() => _LapseWindowHostState();
}

class _LapseWindowHostState extends ConsumerState<LapseWindowHost> {
  late final WindowController _overlayWindowController;
  late final WindowEntry _overlayEntry;
  final _dashboardPage = ValueNotifier(DashboardPage.dashboard);
  WindowController? _dashboardWindowController;
  WindowEntry? _dashboardEntry;

  @override
  void initState() {
    super.initState();
    _overlayWindowController = WindowController(
      size: AppConstants.collapsedSize,
      constraints: const BoxConstraints(
        minWidth: 244,
        minHeight: 52,
        maxWidth: 312,
        maxHeight: 356,
      ),
      title: AppConstants.name,
      delegate: _CallbackWindowDelegate(() {
        unawaited(ref.read(sessionControllerProvider).hide());
      }),
    );
    _overlayEntry = WindowEntry(
      controller: _overlayWindowController,
      builder: (registryContext) => Consumer(
        builder: (context, ref, _) {
          final controller = ref.watch(sessionControllerProvider);
          controller.attachWindowResizer(_overlayWindowController.setSize);
          controller.attachDashboardNavigation(
            openDashboard: () =>
                _openDashboard(registryContext, DashboardPage.dashboard),
            openSettings: () =>
                _openDashboard(registryContext, DashboardPage.settings),
          );
          return MaterialApp(
            title: AppConstants.name,
            debugShowCheckedModeBanner: false,
            color: Colors.transparent,
            theme: buildLapseTheme(),
            home: OverlayWindow(
              controller: controller,
              onOpenDashboard: () =>
                  _openDashboard(registryContext, DashboardPage.dashboard),
            ),
          );
        },
      ),
    );
  }

  void _openDashboard(BuildContext registryContext, DashboardPage page) {
    _dashboardPage.value = page;
    final existing = _dashboardWindowController;
    if (existing != null && !existing.isDestroyed) {
      existing.activate();
      return;
    }

    final sessionController = ref.read(sessionControllerProvider);
    final registry = WindowRegistry.of(registryContext);
    late final WindowController windowController;
    late final WindowEntry entry;

    Future<void> closeDashboard() async {
      if (_dashboardEntry != entry) return;
      await sessionController.saveDashboardBounds();
      registry.unregister(entry);
      _dashboardEntry = null;
      _dashboardWindowController = null;
      windowController.destroy();
      windowController.dispose();
    }

    final preferences = sessionController.state.preferences;
    windowController = WindowController(
      size: Size(preferences.dashboardWidth, preferences.dashboardHeight),
      constraints: const BoxConstraints(minWidth: 760, minHeight: 520),
      title: '${AppConstants.name} Dashboard',
      delegate: _CallbackWindowDelegate(() => unawaited(closeDashboard())),
    );
    entry = WindowEntry(
      controller: windowController,
      builder: (context) => Consumer(
        builder: (context, ref, _) => MaterialApp(
          title: '${AppConstants.name} Dashboard',
          debugShowCheckedModeBanner: false,
          color: Colors.transparent,
          theme: buildLapseTheme(),
          home: DashboardWindow(
            controller: ref.watch(sessionControllerProvider),
            page: _dashboardPage,
            windowState: windowController,
            isMaximized: () => windowController.isMaximized,
            onBeginDrag: sessionController.beginDashboardDrag,
            onMinimize: () => windowController.setMinimized(true),
            onToggleMaximize: () =>
                windowController.setMaximized(!windowController.isMaximized),
            onClose: () => unawaited(closeDashboard()),
          ),
        ),
      ),
    );
    _dashboardWindowController = windowController;
    _dashboardEntry = entry;
    registry.register(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(sessionController.configureDashboardWindow());
    });
  }

  @override
  void dispose() {
    final dashboardController = _dashboardWindowController;
    if (dashboardController != null) {
      dashboardController.destroy();
      dashboardController.dispose();
    }
    _dashboardPage.dispose();
    _overlayWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WindowManager(initialWindows: [_overlayEntry]);
}
