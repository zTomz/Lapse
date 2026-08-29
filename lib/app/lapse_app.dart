// Flutter's desktop Windowing API is intentionally internal while experimental.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/overlay/overlay_window.dart';
import '../features/session/session_controller.dart';
import 'app_constants.dart';
import 'lapse_theme.dart';

class _HideOnCloseDelegate with WindowControllerDelegate {
  void Function()? onClose;

  @override
  void onWindowCloseRequested(WindowController controller) => onClose?.call();
}

class LapseWindowHost extends ConsumerStatefulWidget {
  const LapseWindowHost({super.key});

  @override
  ConsumerState<LapseWindowHost> createState() => _LapseWindowHostState();
}

class _LapseWindowHostState extends ConsumerState<LapseWindowHost> {
  late final _HideOnCloseDelegate _delegate;
  late final WindowController _windowController;

  @override
  void initState() {
    super.initState();
    _delegate = _HideOnCloseDelegate();
    _windowController = WindowController(
      size: AppConstants.expandedSize,
      constraints: const BoxConstraints(
        minWidth: 228,
        minHeight: 52,
        maxWidth: 312,
        maxHeight: 356,
      ),
      title: AppConstants.name,
      delegate: _delegate,
    );
  }

  @override
  void dispose() {
    _windowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(sessionControllerProvider);
    controller.attachWindowResizer(_windowController.setSize);
    _delegate.onClose = () => unawaited(controller.hide());
    return Window(
      controller: _windowController,
      child: MaterialApp(
        title: AppConstants.name,
        debugShowCheckedModeBanner: false,
        theme: buildLapseTheme(),
        home: OverlayWindow(controller: controller),
      ),
    );
  }
}
