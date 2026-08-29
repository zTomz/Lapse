import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/lapse_theme.dart';
import '../analytics/usage_analytics.dart';
import '../application_tracking/application_models.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';

enum DashboardPage { dashboard, applications, sessions, settings }

class DashboardWindow extends StatelessWidget {
  const DashboardWindow({
    super.key,
    required this.controller,
    required this.page,
    this.windowState,
    this.isMaximized,
    this.onBeginDrag,
    this.onMinimize,
    this.onToggleMaximize,
    this.onClose,
  });

  final SessionController controller;
  final ValueNotifier<DashboardPage> page;
  final Listenable? windowState;
  final bool Function()? isMaximized;
  final VoidCallback? onBeginDrag;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    Widget titleBar() => _DashboardTitleBar(
      isMaximized: isMaximized?.call() ?? false,
      onBeginDrag: onBeginDrag,
      onMinimize: onMinimize,
      onToggleMaximize: onToggleMaximize,
      onClose: onClose,
    );
    final chrome = windowState == null
        ? titleBar()
        : AnimatedBuilder(
            animation: windowState!,
            builder: (_, _) => titleBar(),
          );
    return Material(
      color: Colors.transparent,
      child: ColoredBox(
        color: LapseColors.background.withValues(alpha: 0.68),
        child: Column(
          children: [
            chrome,
            const Divider(height: 1, color: LapseColors.border),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 184, child: _Sidebar(page: page)),
                  const VerticalDivider(width: 1, color: LapseColors.border),
                  Expanded(
                    child: ValueListenableBuilder<DashboardPage>(
                      valueListenable: page,
                      builder: (context, selected, _) => AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => _DashboardContent(
                          page: selected,
                          controller: controller,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTitleBar extends StatelessWidget {
  const _DashboardTitleBar({
    required this.isMaximized,
    this.onBeginDrag,
    this.onMinimize,
    this.onToggleMaximize,
    this.onClose,
  });

  final bool isMaximized;
  final VoidCallback? onBeginDrag;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            key: const Key('dashboardDragRegion'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onBeginDrag?.call(),
            onDoubleTap: onToggleMaximize,
            child: const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Row(
                children: [
                  Image(
                    image: AssetImage('assets/images/app_icon.png'),
                    width: 24,
                    height: 24,
                    filterQuality: FilterQuality.high,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Lapse',
                    style: TextStyle(
                      color: LapseColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _WindowButton(
          key: const Key('minimizeWindowButton'),
          icon: Icons.remove_rounded,
          tooltip: 'Minimize',
          onPressed: onMinimize,
        ),
        _WindowButton(
          key: const Key('maximizeWindowButton'),
          icon: isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          tooltip: isMaximized ? 'Restore' : 'Maximize',
          onPressed: onToggleMaximize,
        ),
        _WindowButton(
          key: const Key('closeWindowButton'),
          icon: Icons.close_rounded,
          tooltip: 'Close',
          danger: true,
          onPressed: onClose,
        ),
      ],
    ),
  );
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.danger = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback? onPressed;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 46,
          height: 42,
          color: !_hovered
              ? Colors.transparent
              : widget.danger
              ? const Color(0xFFC42B1C)
              : Colors.white.withValues(alpha: 0.08),
          child: Icon(widget.icon, size: 15, color: Colors.white),
        ),
      ),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.page});
  final ValueNotifier<DashboardPage> page;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LapseColors.surface.withValues(alpha: 0.56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: LapseColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final item in const [
              (
                DashboardPage.dashboard,
                Icons.space_dashboard_outlined,
                'Dashboard',
              ),
              (DashboardPage.applications, Icons.apps_outlined, 'Applications'),
              (DashboardPage.sessions, Icons.history_rounded, 'Sessions'),
              (DashboardPage.settings, Icons.settings_outlined, 'Settings'),
            ])
              ValueListenableBuilder<DashboardPage>(
                valueListenable: page,
                builder: (context, selected, _) => _NavItem(
                  icon: item.$2,
                  label: item.$3,
                  selected: selected == item.$1,
                  onTap: () => page.value = item.$1,
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? LapseColors.accent.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: selected ? LapseColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 9),
            Icon(
              icon,
              size: 17,
              color: selected ? LapseColors.text : LapseColors.textMuted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? LapseColors.text : LapseColors.textMuted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.page, required this.controller});
  final DashboardPage page;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.state.session.copyWith(
      activeDuration: controller.state.displayDuration,
    );
    final sessions = [...controller.state.sessionHistory, current];
    final content = switch (page) {
      DashboardPage.dashboard => _OverviewPage(sessions: sessions),
      DashboardPage.applications => _ApplicationsPage(sessions: sessions),
      DashboardPage.sessions => _SessionsPage(
        sessions: sessions.reversed.toList(),
      ),
      DashboardPage.settings => _SettingsPage(controller: controller),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.012, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(page), child: content),
    );
  }
}

class _PageShell extends StatelessWidget {
  const _PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: LapseColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 26),
        Expanded(child: child),
      ],
    ),
  );
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.sessions});
  final List<ComputerSession> sessions;
  @override
  Widget build(BuildContext context) {
    final summary = UsageAnalytics.summarize(sessions);
    return _PageShell(
      title: 'Dashboard',
      subtitle: 'Your active computer time at a glance.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final metrics = [
            ('Today', _duration(summary.today)),
            ('7-day average', _duration(summary.sevenDayAverage)),
            ('This week', _duration(summary.thisWeek)),
            ('Sessions today', '${summary.sessionsToday}'),
          ];
          return Column(
            children: [
              _Panel(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: compact ? 2 : 4,
                    childAspectRatio: compact ? 2.7 : 1.9,
                  ),
                  itemCount: metrics.length,
                  itemBuilder: (context, index) => _Metric(
                    label: metrics[index].$1,
                    value: metrics[index].$2,
                    showLeftBorder: index % (compact ? 2 : 4) != 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _Panel(
                  title: 'Active time',
                  child: _UsageChart(points: summary.lastSevenDays),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.showLeftBorder,
  });
  final String label;
  final String value;
  final bool showLeftBorder;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: showLeftBorder
          ? const Border(left: BorderSide(color: LapseColors.border))
          : null,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: LapseColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({this.title, required this.child});
  final String? title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: LapseColors.surface.withValues(alpha: 0.62),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: LapseColors.border.withValues(alpha: 0.8)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: title == null
        ? child
        : Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: child),
              ],
            ),
          ),
  );
}

class _UsageChart extends StatefulWidget {
  const _UsageChart({required this.points});
  final List<DailyUsagePoint> points;

  @override
  State<_UsageChart> createState() => _UsageChartState();
}

class _UsageChartState extends State<_UsageChart> {
  int? _hoveredIndex;
  Offset? _pointerPosition;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final points = widget.points;
      final hoveredIndex = _hoveredIndex;
      return MouseRegion(
        cursor: SystemMouseCursors.basic,
        onExit: (_) => setState(() {
          _hoveredIndex = null;
          _pointerPosition = null;
        }),
        onHover: (event) {
          if (points.isEmpty || constraints.maxWidth <= 0) return;
          final slotWidth = constraints.maxWidth / points.length;
          final index = (event.localPosition.dx / slotWidth).floor().clamp(
            0,
            points.length - 1,
          );
          setState(() {
            _hoveredIndex = index;
            _pointerPosition = event.localPosition;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: const Key('usageChart'),
                painter: _ChartPainter(points, hoveredIndex: hoveredIndex),
              ),
            ),
            if (hoveredIndex != null && _pointerPosition != null)
              _ChartTooltipPositioned(
                point: points[hoveredIndex],
                pointer: _pointerPosition!,
                chartSize: constraints.biggest,
                sevenDayTotal: points.fold(
                  Duration.zero,
                  (total, point) => total + point.duration,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ChartTooltipPositioned extends StatelessWidget {
  const _ChartTooltipPositioned({
    required this.point,
    required this.pointer,
    required this.chartSize,
    required this.sevenDayTotal,
  });

  static const _width = 174.0;
  static const _height = 84.0;
  final DailyUsagePoint point;
  final Offset pointer;
  final Size chartSize;
  final Duration sevenDayTotal;

  @override
  Widget build(BuildContext context) {
    final preferredLeft = pointer.dx + 14;
    final left = preferredLeft + _width <= chartSize.width
        ? preferredLeft
        : math.max(0.0, pointer.dx - _width - 14);
    final preferredTop = pointer.dy - _height - 12;
    final top = preferredTop >= 0
        ? preferredTop
        : math.min(chartSize.height - _height, pointer.dy + 14);
    final share = sevenDayTotal == Duration.zero
        ? 0
        : (point.duration.inMicroseconds / sevenDayTotal.inMicroseconds * 100)
              .round();
    return Positioned(
      left: left,
      top: math.max(0.0, top),
      width: _width,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: 1,
          child: Material(
            key: const Key('chartTooltip'),
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.42),
            color: LapseColors.surfaceRaised,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: LapseColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chartDate(point.date),
                    style: const TextStyle(
                      color: LapseColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: LapseColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _duration(point.duration),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$share%',
                        style: const TextStyle(
                          color: LapseColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Text(
                      'active · 7-day share',
                      style: TextStyle(
                        color: LapseColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, {required this.hoveredIndex});
  final List<DailyUsagePoint> points;
  final int? hoveredIndex;
  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  @override
  void paint(Canvas canvas, Size size) {
    final maxMinutes = math.max(
      60,
      points.fold<int>(
        0,
        (value, point) => math.max(value, point.duration.inMinutes),
      ),
    );
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final chartHeight = math.max(0.0, size.height - 30);
    final slot = size.width / points.length;
    final guidePaint = Paint()
      ..color = LapseColors.border.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var guide = 0; guide <= 3; guide++) {
      final y = chartHeight * guide / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final hovered = hoveredIndex == index;
      if (hovered) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(index * slot + 3, 0, slot - 6, chartHeight),
            const Radius.circular(6),
          ),
          Paint()..color = LapseColors.accent.withValues(alpha: 0.055),
        );
      }
      final measuredHeight =
          chartHeight * point.duration.inMinutes / maxMinutes;
      final barHeight = point.duration == Duration.zero ? 2.0 : measuredHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * slot + slot * .24,
          chartHeight - barHeight,
          slot * .52,
          barHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = point.duration == Duration.zero
              ? (hovered
                    ? LapseColors.accent.withValues(alpha: 0.55)
                    : LapseColors.border)
              : (hovered
                    ? Color.lerp(LapseColors.accent, Colors.white, 0.18)!
                    : LapseColors.accent),
      );
      labelPainter.text = TextSpan(
        text: dayNames[point.date.weekday - 1],
        style: TextStyle(
          color: hovered ? LapseColors.text : LapseColors.textMuted,
          fontSize: 10,
          fontWeight: hovered ? FontWeight.w600 : FontWeight.w400,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          index * slot + (slot - labelPainter.width) / 2,
          chartHeight + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.hoveredIndex != hoveredIndex;
}

class _ApplicationsPage extends StatefulWidget {
  const _ApplicationsPage({required this.sessions});
  final List<ComputerSession> sessions;
  @override
  State<_ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<_ApplicationsPage> {
  var _days = 1;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: _days - 1));
    final usages = UsageAnalytics.applicationTotals(
      widget.sessions,
      from: from,
    );
    final total = usages.fold(
      Duration.zero,
      (sum, usage) => sum + usage.activeDuration,
    );
    return _PageShell(
      title: 'Applications',
      subtitle: 'Foreground application usage while Lapse was active.',
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _duration(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _days == 1 ? 'tracked today' : 'tracked in 7 days',
                style: const TextStyle(
                  color: LapseColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              _PeriodPicker(
                value: _days,
                onChanged: (value) => setState(() => _days = value),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _Panel(
              child: usages.isEmpty
                  ? const _EmptyState(
                      icon: Icons.apps_outlined,
                      message: 'No application usage recorded yet.',
                    )
                  : Column(
                      children: [
                        const _ApplicationListHeader(),
                        const Divider(height: 1, color: LapseColors.border),
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: usages.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 64,
                              color: LapseColors.border,
                            ),
                            itemBuilder: (context, index) => _ApplicationRow(
                              rank: index + 1,
                              usage: usages[index],
                              total: total,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: LapseColors.surface,
      border: Border.all(color: LapseColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PeriodOption(
            label: 'Today',
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
          _PeriodOption(
            label: 'Last 7 days',
            selected: value == 7,
            onTap: () => onChanged(7),
          ),
        ],
      ),
    ),
  );
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? LapseColors.surfaceRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? LapseColors.text : LapseColors.textMuted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _ApplicationListHeader extends StatelessWidget {
  const _ApplicationListHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: Row(
      children: [
        SizedBox(width: 44),
        Expanded(child: Text('APPLICATION', style: _tableHeaderStyle)),
        SizedBox(
          width: 76,
          child: Text(
            'TIME',
            textAlign: TextAlign.right,
            style: _tableHeaderStyle,
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(
            'SHARE',
            textAlign: TextAlign.right,
            style: _tableHeaderStyle,
          ),
        ),
      ],
    ),
  );
}

const _tableHeaderStyle = TextStyle(
  color: LapseColors.textMuted,
  fontSize: 9,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({
    required this.rank,
    required this.usage,
    required this.total,
  });
  final int rank;
  final ApplicationUsage usage;
  final Duration total;
  @override
  Widget build(BuildContext context) {
    final ratio = total == Duration.zero
        ? 0.0
        : usage.activeDuration.inMicroseconds / total.inMicroseconds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? LapseColors.accent.withValues(alpha: 0.14)
                  : LapseColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? LapseColors.accent : LapseColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usage.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usage.executableName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LapseColors.textMuted,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 2,
                    color: LapseColors.accent,
                    backgroundColor: LapseColors.surfaceRaised,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 76,
            child: Text(
              _duration(usage.activeDuration),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              '${(ratio * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: LapseColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsPage extends StatelessWidget {
  const _SessionsPage({required this.sessions});
  final List<ComputerSession> sessions;
  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Sessions',
    subtitle: 'Recent computer sessions stored on this device.',
    child: sessions.isEmpty
        ? const _EmptyState(
            icon: Icons.history_rounded,
            message: 'No sessions recorded yet.',
          )
        : ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final completed = session.tasks
                  .where((task) => task.isCompleted)
                  .length;
              return _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sessionDate(session.startedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_time(session.startedAt)} – ${session.endedAt == null ? 'Current' : _time(session.endedAt!)}',
                              style: const TextStyle(
                                color: LapseColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Active ${_duration(session.activeDuration)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 30),
                      Text(
                        'Tasks $completed / ${session.tasks.length}',
                        style: const TextStyle(
                          color: LapseColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller});
  final SessionController controller;
  @override
  Widget build(BuildContext context) => _PageShell(
    title: 'Settings',
    subtitle: 'Control how Lapse behaves on Windows.',
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          children: [
            _SettingRow(
              title: 'Start with Windows',
              subtitle: 'Launch Lapse when you sign in.',
              value: controller.state.preferences.autostart,
              onChanged: controller.setAutostart,
            ),
            const SizedBox(height: 8),
            _SettingRow(
              title: 'Always on top',
              subtitle: 'Keep the overlay above regular windows.',
              value: controller.state.preferences.alwaysOnTop,
              onChanged: controller.setAlwaysOnTop,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => _Panel(
    child: SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: LapseColors.textMuted, fontSize: 11),
      ),
      value: value,
      onChanged: onChanged,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: LapseColors.textMuted),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(color: LapseColors.textMuted, fontSize: 12),
        ),
      ],
    ),
  );
}

String _duration(Duration value) {
  if (value < const Duration(minutes: 1)) return '${value.inSeconds}s';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  return hours == 0
      ? '${minutes}m'
      : '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _chartDate(DateTime value) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '${weekdays[value.weekday - 1]}, $day.$month.${value.year}';
}

String _sessionDate(DateTime value) {
  final now = DateTime.now();
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
