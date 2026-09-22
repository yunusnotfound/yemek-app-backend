import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/owner_order_model.dart';
import '../../domain/repositories/business_owner_repository.dart';

part 'owner_orders_event.dart';
part 'owner_orders_state.dart';

class OwnerOrdersBloc extends Bloc<OwnerOrdersEvent, OwnerOrdersState> {
  final BusinessOwnerRepository _repository;
  String? _currentBusinessId;
  String? _currentStatus;

  OwnerOrdersBloc({required BusinessOwnerRepository repository})
    : _repository = repository,
      super(OwnerOrdersInitial()) {
    on<OwnerOrdersEvent>((event, emit) async {
      if (event is LoadBusinessOrders) await _onLoadBusinessOrders(event, emit);
      if (event is RefreshOrders) await _onRefreshOrders(event, emit);
    }, transformer: restartable());
  }

  Future<void> _onLoadBusinessOrders(
    LoadBusinessOrders event,
    Emitter<OwnerOrdersState> emit,
  ) async {
    _currentBusinessId = event.businessId;
    _currentStatus = event.status;
    emit(OwnerOrdersLoading());
    try {
      final orders = await _repository.getBusinessOrders(
        event.businessId,
        status: event.status,
        page: event.page,
        limit: event.limit,
      );
      if (emit.isDone) return;
      emit(OwnerOrdersLoaded(orders: orders, status: event.status));
    } catch (e) {
      if (emit.isDone) return;
      emit(OwnerOrdersError(message: e.toString()));
    }
  }

  Future<void> _onRefreshOrders(
    RefreshOrders event,
    Emitter<OwnerOrdersState> emit,
  ) async {
    if (_currentBusinessId == null) return;
    emit(OwnerOrdersLoading());
    try {
      final orders = await _repository.getBusinessOrders(
        _currentBusinessId!,
        status: _currentStatus,
      );
      if (emit.isDone) return;
      emit(OwnerOrdersLoaded(orders: orders, status: _currentStatus));
    } catch (e) {
      if (emit.isDone) return;
      emit(OwnerOrdersError(message: e.toString()));
    }
  }
}
