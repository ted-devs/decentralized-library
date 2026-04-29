import 'package:flutter/material.dart';
import 'dart:math' as math;

class ActionButton {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final Color? foregroundColor;

  const ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.foregroundColor,
  });
}

class ExpandableFab extends StatefulWidget {
  final bool initialOpen;
  final double distance;
  final List<ActionButton> children;
  final IconData openIcon;
  final IconData closeIcon;

  const ExpandableFab({
    super.key,
    this.initialOpen = false,
    required this.distance,
    required this.children,
    this.openIcon = Icons.add,
    this.closeIcon = Icons.close,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen;
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          ..._buildExpandingActionButtons(),
          _buildMainFab(),
        ],
      ),
    );
  }

  Widget _buildMainFab() {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _open ? const Color(0xFFE57373) : const Color(0xFF81C784), // Pastel Red / Pastel Green
          borderRadius: BorderRadius.circular(_open ? 28.0 : 16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: _open ? 0.375 : 0.0, // 135 degrees (3/8 of a turn)
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: Icon(
            Icons.add,
            color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    for (var i = 0; i < count; i++) {
      children.add(
        _ExpandingActionButton(
          index: i,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: _buildActionRow(widget.children[i]),
        ),
      );
    }
    return children;
  }

  Widget _buildActionRow(ActionButton action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              action.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: null,
          backgroundColor: action.color ?? Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: action.foregroundColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
          onPressed: () {
            _toggle();
            action.onPressed();
          },
          child: action.icon,
        ),
      ],
    );
  }


}

class _ExpandingActionButton extends StatelessWidget {
  final int index;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  const _ExpandingActionButton({
    required this.index,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final bottomOffset = 4.0 + ((index + 1) * maxDistance * progress.value);
        return Positioned(
          right: 4.0,
          bottom: bottomOffset,
          child: Transform.translate(
            offset: Offset(0, (1.0 - progress.value) * 20),
            child: child!,
          ),
        );
      },
      child: FadeTransition(
        opacity: progress,
        child: child,
      ),
    );
  }
}
