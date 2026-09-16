import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/order_model.dart';
import '../../domain/repositories/orders_repository.dart';

part 'orders_event.dart';
part 'orders_state.dart';

enum OrderFilter { active, completed, cancelled }

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrdersRepository _repository;
  List<OrderModel> _allOrders = [];
  int _currentPage = 1;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  OrderFilter _filter = OrderFilter.active;
  int _requestGeneration = 0;

  OrdersBloc({required OrdersRepository repository})
    : _repository = repository,
      super(const OrdersInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<LoadMoreOrders>(_onLoadMoreOrders);
    on<RefreshOrders>(_onRefreshOrders);
    on<CancelOrder>(_onCancelOrder);
    on<ChangeOrderFilter>(_onChangeFilter);
  }

  Future<void> _onLoadOrders(
    LoadOrders event,
    Emitter<OrdersState> emit,
  ) async {
    final generation = ++_requestGeneration;
    _isLoadingMore = false;
    _isRefreshing = true;
    emit(const OrdersLoading());
    try {
      _currentPage = 1;
      final response = await _repository.getMyOrders(page: 1);
      if (generation != _requestGeneration || emit.isDone) return;
      _allOrders = response.orders;
      _hasReachedMax = response.page >= response.totalPages;
      emit(
        OrdersLoaded(
          orders: _allOrders,
          hasReachedMax: _hasReachedMax,
          filter: _filter,
        ),
      );
    } catch (e) {
      if (generation != _requestGeneration || emit.isDone) return;
      emit(OrdersError(message: e.toString()));
    } finally {
      if (generation == _requestGeneration) _isRefreshing = false;
    }
  }

  Future<void> _onLoadMoreOrders(
    LoadMoreOrders event,
    Emitter<OrdersState> emit,
  ) async {
    if (_isLoadingMore || _isRefreshing || _hasReachedMax) return;
    final currentState = state;
    if (currentState is! OrdersLoaded) return;

    _isLoadingMore = true;
    final generation = _requestGeneration;
    final nextPage = _currentPage + 1;
    emit(OrdersLoadingMore(orders: _allOrders, filter: currentState.filter));

    try {
      final response = await _repository.getMyOrders(page: nextPage);
      if (generation != _requestGeneration || emit.isDone) return;
      _currentPage = nextPage;
      _allOrders = [..._allOrders, ...response.orders];
      _hasReachedMax = response.page >= response.totalPages;
      emit(
        OrdersLoaded(
          orders: _allOrders,
          hasReachedMax: _hasReachedMax,
          filter: _filter,
        ),
      );
    } catch (e) {
      if (generation != _requestGeneration || emit.isDone) return;
      emit(
        OrdersLoaded(
          orders: _allOrders,
          hasReachedMax: _hasReachedMax,
          filter: _filter,
        ),
      );
    } finally {
      if (generation == _requestGeneration) _isLoadingMore = false;
    }
  }

  Future<void> _onRefreshOrders(
    RefreshOrders event,
    Emitter<OrdersState> emit,
  ) async {
    final generation = ++_requestGeneration;
    _isLoadingMore = false;
    _isRefreshing = true;
    try {
      _currentPage = 1;
      final response = await _repository.getMyOrders(page: 1);
      if (generation != _requestGeneration || emit.isDone) return;
      _allOrders = response.orders;
      _hasReachedMax = response.page >= response.totalPages;
      emit(
        OrdersLoaded(
          orders: _allOrders,
          hasReachedMax: _hasReachedMax,
          filter: _filter,
        ),
      );
    } catch (e) {
      if (generation != _requestGeneration || emit.isDone) return;
      emit(OrdersError(message: e.toString()));
    } finally {
      if (generation == _requestGeneration) _isRefreshing = false;
    }
  }

  Future<void> _onCancelOrder(
    CancelOrder event,
    Emitter<OrdersState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrdersLoaded) return;

    try {
      await _repository.cancelOrder(event.orderId);
      // Update local state
      _allOrders = _allOrders.map((order) {
        if (order.id == event.orderId) {
          return OrderModel(
            id: order.id,
            packageId: order.packageId,
            quantity: order.quantity,
            totalPrice: order.totalPrice,
            discountAmount: order.discountAmount,
            finalPrice: order.finalPrice,
            pickupCode: order.pickupCode,
            status: 'cancelled',
            couponId: order.couponId,
            createdAt: order.createdAt,
            package: order.package,
          );
        }
        return order;
      }).toList();

      emit(OrderCancelSuccess(orderId: event.orderId));
      emit(
        OrdersLoaded(
          orders: _allOrders,
          hasReachedMax: _hasReachedMax,
          filter: currentState.filter,
        ),
      );
    } catch (e) {
      emit(OrderCancelError(message: e.toString()));
      emit(
        OrdersLoaded(
          orders: _allOrders,
          hasReachedMax: _hasReachedMax,
          filter: currentState.filter,
        ),
      );
    }
  }

  void _onChangeFilter(ChangeOrderFilter event, Emitter<OrdersState> emit) {
    _filter = event.filter;
    if (_isLoadingMore) {
      emit(OrdersLoadingMore(orders: _allOrders, filter: _filter));
      return;
    }
    emit(
      OrdersLoaded(
        orders: _allOrders,
        hasReachedMax: _hasReachedMax,
        filter: event.filter,
      ),
    );
  }
}
