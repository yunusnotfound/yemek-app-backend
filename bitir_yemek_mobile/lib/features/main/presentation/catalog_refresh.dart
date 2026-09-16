import 'dart:async';

import 'package:flutter/material.dart';

/// Refreshes only the visible catalog. Network overlap is coalesced by its bloc.
class CatalogRefresh extends StatefulWidget {
  final Object activeTab;
  final VoidCallback onRefresh;
  final Widget child;
  final Duration interval;

  const CatalogRefresh({
    super.key,
    required this.activeTab,
    required this.onRefresh,
    required this.child,
    this.interval = const Duration(seconds: 15),
  });

  @override
  State<CatalogRefresh> createState() => _CatalogRefreshState();
}

class _CatalogRefreshState extends State<CatalogRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_foreground) {
      _timer = Timer.periodic(widget.interval, (_) => _refresh());
    }
  }

  void _refresh() {
    if (!mounted || !_foreground) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    widget.onRefresh();
  }

  @override
  void didUpdateWidget(CatalogRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) _startTimer();
    if (oldWidget.activeTab != widget.activeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    _startTimer();
    if (_foreground && !wasForeground) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
