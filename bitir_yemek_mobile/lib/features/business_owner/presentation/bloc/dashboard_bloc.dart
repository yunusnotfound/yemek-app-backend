import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../domain/repositories/business_owner_repository.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final BusinessOwnerRepository _repository;

  DashboardBloc({required BusinessOwnerRepository repository})
    : _repository = repository,
      super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard, transformer: restartable());
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final stats = await _repository.getDashboardStats(event.businessId);
      if (emit.isDone) return;
      emit(DashboardLoaded(stats: stats));
    } catch (e) {
      if (emit.isDone) return;
      emit(DashboardError(message: e.toString()));
    }
  }
}
