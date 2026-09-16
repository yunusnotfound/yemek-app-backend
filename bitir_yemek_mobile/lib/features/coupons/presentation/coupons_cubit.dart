import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/coupons_repository.dart';

class CouponsState {
  final CouponWallet? wallet;
  final bool loading;
  final String? error;
  const CouponsState({this.wallet, this.loading = false, this.error});
}

class CouponsCubit extends Cubit<CouponsState> {
  final CouponsRepository repository;
  late final StreamSubscription<void> _changes;
  bool _reload = false;
  CouponsCubit({CouponsRepository? repository})
    : repository = repository ?? CouponsRepository(),
      super(const CouponsState()) {
    _changes = CouponsRepository.changes.listen((_) {
      if (state.loading) {
        _reload = true;
      } else {
        load();
      }
    });
  }
  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }

  Future<void> load() async {
    if (state.loading || isClosed) return;
    emit(CouponsState(wallet: state.wallet, loading: true));
    try {
      final wallet = await repository.wallet();
      if (!isClosed) emit(CouponsState(wallet: wallet));
    } catch (e) {
      if (!isClosed) {
        emit(
          CouponsState(wallet: state.wallet, error: CouponsRepository.error(e)),
        );
      }
    } finally {
      if (_reload && !isClosed) {
        _reload = false;
        load();
      }
    }
  }
}
