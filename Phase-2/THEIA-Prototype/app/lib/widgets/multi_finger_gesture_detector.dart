import 'dart:async';
import 'package:flutter/material.dart';

/// Listens for multi-finger tap gestures (two-finger double tap, three-finger triple tap).
class MultiFingerGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTwoFingerDoubleTap;
  final VoidCallback? onThreeFingerTripleTap;

  const MultiFingerGestureDetector({
    super.key,
    required this.child,
    this.onTwoFingerDoubleTap,
    this.onThreeFingerTripleTap,
  });

  @override
  State<MultiFingerGestureDetector> createState() => _MultiFingerGestureDetectorState();
}

class _MultiFingerGestureDetectorState extends State<MultiFingerGestureDetector> {
  int _tapCount = 0;
  int _fingerCount = 0;
  Timer? _tapTimer;

  void _handlePointerDown(PointerDownEvent event) {
    _fingerCount++;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_fingerCount == 2 || _fingerCount == 3) {
      final targetFingers = _fingerCount;
      _tapCount++;

      _tapTimer?.cancel();
      _tapTimer = Timer(const Duration(milliseconds: 300), () {
        if (targetFingers == 2 && _tapCount == 2 && widget.onTwoFingerDoubleTap != null) {
          widget.onTwoFingerDoubleTap!();
        } else if (targetFingers == 3 && _tapCount == 3 && widget.onThreeFingerTripleTap != null) {
          widget.onThreeFingerTripleTap!();
        }
        _tapCount = 0;
      });
    }

    _fingerCount = 0;
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: widget.child,
    );
  }
}
