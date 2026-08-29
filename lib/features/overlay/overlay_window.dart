import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/lapse_theme.dart';
import '../session/session_controller.dart';
import '../session/session_models.dart';

class OverlayWindow extends StatelessWidget {
  const OverlayWindow({
    super.key,
    required this.controller,
    required this.onOpenDashboard,
  });

  final SessionController controller;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.displayDuration]),
      builder: (context, _) {
        final state = controller.state;
        return ColoredBox(
          color: LapseColors.background,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final collapsed =
                  constraints.maxWidth < 260 ||
                  state.preferences.overlayMode == OverlayMode.collapsed;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) =>
                    currentChild ?? const SizedBox.shrink(),
                child: collapsed
                    ? _CollapsedOverlay(
                        key: const ValueKey('collapsed'),
                        controller: controller,
                        state: state,
                      )
                    : _ExpandedOverlay(
                        key: const ValueKey('expanded'),
                        controller: controller,
                        state: state,
                        onOpenDashboard: onOpenDashboard,
                      ),
              );
            },
          ),
        );
      },
    );
  }
}

class _OverlaySurface extends StatelessWidget {
  const _OverlaySurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LapseColors.surface,
          border: Border.all(color: LapseColors.border.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _CollapsedOverlay extends StatelessWidget {
  const _CollapsedOverlay({
    super.key,
    required this.controller,
    required this.state,
  });
  final SessionController controller;
  final SessionViewState state;

  @override
  Widget build(BuildContext context) {
    return _OverlaySurface(
      child: Row(
        children: [
          const SizedBox(width: 13),
          _StatusDot(state: state.activityState, compact: true),
          const SizedBox(width: 9),
          Expanded(
            child: _DragRegion(
              onDrag: controller.beginDrag,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDuration(state.displayDuration),
                  key: const Key('sessionTimer'),
                  style: const TextStyle(
                    color: LapseColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const Icon(
            Icons.check_rounded,
            size: 14,
            color: LapseColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            '${state.completedTaskCount}/${state.session.tasks.length}',
            style: const TextStyle(color: LapseColors.textMuted, fontSize: 11),
          ),
          const SizedBox(width: 6),
          _SmallIconButton(
            key: const Key('pauseButtonCollapsed'),
            icon: state.session.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            semanticLabel: state.session.isPaused
                ? 'Resume tracking'
                : 'Pause tracking',
            onPressed: controller.toggleManualPause,
          ),
          _SmallIconButton(
            key: const Key('expandButton'),
            icon: Icons.expand_more_rounded,
            semanticLabel: 'Expand Lapse',
            onPressed: controller.toggleOverlayMode,
          ),
          const SizedBox(width: 5),
        ],
      ),
    );
  }
}

class _ExpandedOverlay extends StatefulWidget {
  const _ExpandedOverlay({
    super.key,
    required this.controller,
    required this.state,
    required this.onOpenDashboard,
  });
  final SessionController controller;
  final SessionViewState state;
  final VoidCallback onOpenDashboard;

  @override
  State<_ExpandedOverlay> createState() => _ExpandedOverlayState();
}

class _ExpandedOverlayState extends State<_ExpandedOverlay> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String? _editingId;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) return;
    scheduleMicrotask(() {
      if (!mounted || _focusNode.hasFocus) return;
      if ((_adding && _textController.text.trim().isEmpty) ||
          _editingId != null) {
        _cancelEditing();
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startAdding() {
    setState(() {
      _editingId = null;
      _adding = true;
      _textController.clear();
    });
    _focusNode.requestFocus();
  }

  void _startEditing(SessionTask task) {
    setState(() {
      _adding = false;
      _editingId = task.id;
      _textController.text = task.title;
      _textController.selection = TextSelection.collapsed(
        offset: task.title.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _submit() {
    if (_adding) {
      widget.controller.addTask(_textController.text);
    } else if (_editingId case final id?) {
      widget.controller.editTask(id, _textController.text);
    }
    _cancelEditing();
  }

  void _cancelEditing() {
    setState(() {
      _adding = false;
      _editingId = null;
      _textController.clear();
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final total = state.session.tasks.length;
    final completed = state.completedTaskCount;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!_focusNode.hasFocus) return;
        if ((_adding && _textController.text.trim().isEmpty) ||
            _editingId != null) {
          _cancelEditing();
        } else {
          _focusNode.unfocus();
        }
      },
      child: _OverlaySurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          child: Column(
            children: [
              _Header(controller: widget.controller, state: state),
              const SizedBox(height: 18),
              Text(
                _formatDuration(state.displayDuration),
                key: const Key('sessionTimer'),
                style: const TextStyle(
                  color: LapseColors.text,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.8,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _activitySubtitle(state.activityState),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'TODO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completed / $total',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 180),
                  tween: Tween(end: total == 0 ? 0 : completed / total),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    backgroundColor: LapseColors.surfaceRaised,
                    color: LapseColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: state.session.tasks.isEmpty && !_adding
                    ? Center(
                        child: Text(
                          'No tasks for this session',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount:
                            state.session.tasks.length + (_adding ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.session.tasks.length) {
                            return _buildEditor();
                          }
                          final task = state.session.tasks[index];
                          if (_editingId == task.id) {
                            return _buildEditor();
                          }
                          return _TaskRow(
                            key: Key('task-${task.id}'),
                            task: task,
                            onToggle: () =>
                                widget.controller.toggleTask(task.id),
                            onEdit: () => _startEditing(task),
                            onDelete: () =>
                                widget.controller.deleteTask(task.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    key: const Key('addTaskButton'),
                    onPressed: _adding || _editingId != null
                        ? null
                        : _startAdding,
                    style: TextButton.styleFrom(
                      foregroundColor: LapseColors.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      minimumSize: const Size(0, 28),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Add task',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  _SmallIconButton(
                    key: const Key('launchButton'),
                    icon: Icons.launch_rounded,
                    tooltip: 'Open Lapse dashboard',
                    onPressed: widget.onOpenDashboard,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) => _cancelEditing(),
            ),
          },
          child: TextField(
            key: const Key('taskEditor'),
            controller: _textController,
            focusNode: _focusNode,
            autofocus: true,
            maxLength: 100,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onTapOutside: (_) {
              if ((_adding && _textController.text.trim().isEmpty) ||
                  _editingId != null) {
                _cancelEditing();
              } else {
                _focusNode.unfocus();
              }
            },
            decoration: InputDecoration(
              hintText: _adding ? 'What needs doing?' : 'Update task title',
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 34,
                height: 32,
              ),
              suffixIcon: IconButton(
                key: Key(_adding ? 'addTaskConfirm' : 'editTaskConfirm'),
                tooltip: _adding ? 'Add task' : 'Save task',
                onPressed: _textController.text.trim().isEmpty ? null : _submit,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.check_rounded, size: 17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.state});
  final SessionController controller;
  final SessionViewState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const Text(
            'Lapse',
            style: TextStyle(
              color: LapseColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          _StatusBadge(state: state.activityState),
          const SizedBox(width: 3),
          _SmallIconButton(
            key: const Key('pauseButton'),
            icon: state.session.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            tooltip: state.session.isPaused
                ? 'Resume tracking'
                : 'Pause tracking',
            semanticLabel: state.session.isPaused
                ? 'Resume tracking'
                : 'Pause tracking',
            onPressed: controller.toggleManualPause,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DragRegion(
              onDrag: controller.beginDrag,
              child: const SizedBox.expand(),
            ),
          ),
          _SmallIconButton(
            key: const Key('collapseButton'),
            icon: Icons.remove_rounded,
            tooltip: 'Collapse',
            onPressed: controller.toggleOverlayMode,
          ),
          _SmallIconButton(
            key: const Key('closeButton'),
            icon: Icons.close_rounded,
            tooltip: 'Hide to tray',
            onPressed: controller.hide,
          ),
        ],
      ),
    );
  }
}

class _DragRegion extends StatelessWidget {
  const _DragRegion({required this.onDrag, required this.child});
  final Future<void> Function() onDrag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => unawaited(onDrag()),
        child: child,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});
  final UserActivityState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(state).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(state: state),
          const SizedBox(width: 5),
          Text(
            state.name.toUpperCase(),
            style: TextStyle(
              color: _statusColor(state),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.state, this.compact = false});
  final UserActivityState state;
  final bool compact;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: compact ? 7 : 6,
    height: compact ? 7 : 6,
    decoration: BoxDecoration(
      color: _statusColor(state),
      shape: BoxShape.circle,
    ),
  );
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final SessionTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Tooltip(
              message: widget.task.isCompleted
                  ? 'Mark incomplete'
                  : 'Mark complete',
              child: InkWell(
                key: Key('toggle-${widget.task.id}'),
                borderRadius: BorderRadius.circular(5),
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    widget.task.isCompleted
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 17,
                    color: widget.task.isCompleted
                        ? LapseColors.accent
                        : LapseColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onDoubleTap: widget.onEdit,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: widget.task.isCompleted
                        ? LapseColors.textMuted
                        : LapseColors.text,
                    fontSize: 12,
                    decoration: widget.task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  child: Text(
                    widget.task.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _hovered ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Row(
                children: [
                  _SmallIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit task',
                    onPressed: widget.onEdit,
                  ),
                  _SmallIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete task',
                    onPressed: widget.onDelete,
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

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.semanticLabel,
    required this.onPressed,
  });
  final IconData icon;
  final String? tooltip;
  final String? semanticLabel;
  final FutureOr<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel ?? tooltip,
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 16),
      color: LapseColors.textMuted,
      hoverColor: Colors.white.withValues(alpha: 0.06),
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      padding: EdgeInsets.zero,
    ),
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _activitySubtitle(UserActivityState state) => switch (state) {
  UserActivityState.active => 'Active session',
  UserActivityState.paused => 'Tracking paused',
  UserActivityState.idle => 'Paused while idle',
  UserActivityState.locked => 'Paused while Windows is locked',
  UserActivityState.sleeping => 'Paused while the PC sleeps',
};

Color _statusColor(UserActivityState state) => switch (state) {
  UserActivityState.active => LapseColors.active,
  UserActivityState.paused => LapseColors.accent,
  UserActivityState.idle => LapseColors.idle,
  UserActivityState.locked || UserActivityState.sleeping => LapseColors.locked,
};
