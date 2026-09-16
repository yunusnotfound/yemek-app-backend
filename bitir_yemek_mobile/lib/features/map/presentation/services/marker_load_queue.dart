import 'dart:async';
import 'dart:collection';

/// A small, replaceable work queue for optional map-marker logos.
///
/// A new filter/location discards queued work from the previous view. Existing
/// requests finish within their timeout and share the same worker limit with
/// the next view; [isCurrent] prevents their results changing stale markers.
class MarkerLoadQueue<T> {
  MarkerLoadQueue({this.concurrency = 4, this.onError})
    : assert(concurrency > 0);

  final int concurrency;
  final void Function(Object error, StackTrace stack)? onError;
  final Queue<Future<void> Function()> _pending = Queue();
  int _generation = 0;
  int _active = 0;
  Completer<void>? _idle;

  Future<void> get settled => _idle?.future ?? Future<void>.value();

  void replace(
    Iterable<T> items,
    Future<void> Function(T item, bool Function() isCurrent) load,
  ) {
    cancel();
    final generation = _generation;
    for (final item in items) {
      _pending.add(() => load(item, () => generation == _generation));
    }
    if (_pending.isEmpty) return;
    _idle ??= Completer<void>();
    while (_active < concurrency && _pending.isNotEmpty) {
      _active++;
      unawaited(_work());
    }
  }

  void cancel() {
    _generation++;
    _pending.clear();
  }

  Future<void> _work() async {
    try {
      while (_pending.isNotEmpty) {
        final work = _pending.removeFirst();
        try {
          await work();
        } catch (error, stack) {
          onError?.call(error, stack);
        }
        // Warm-cache raster work also yields to pointer events and frames.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _active--;
      if (_active == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }
}
