import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/category_model.dart';
import '../../domain/repositories/businesses_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final BusinessesRepository _repository;

  HomeBloc({required BusinessesRepository repository})
    : _repository = repository,
      super(HomeInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<RefreshCategories>(_onRefreshCategories);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    await _fetchCategories(emit);
  }

  Future<void> _onRefreshCategories(
    RefreshCategories event,
    Emitter<HomeState> emit,
  ) async {
    // HomeLoading emit etmiyoruz: pull-to-refresh sırasında kategori şeridi
    // kaybolup geri gelmesin. Cache bypass ile taze veri çekilir.
    await _fetchCategories(emit, forceRefresh: true);
  }

  Future<void> _fetchCategories(
    Emitter<HomeState> emit, {
    bool forceRefresh = false,
  }) async {
    try {
      final result = await _repository.getCategories(forceRefresh: forceRefresh);

      if (result.isSuccess &&
          result.categories != null &&
          result.categories!.isNotEmpty) {
        // Add "Hepsi" (All) category at the beginning
        final allCategory = CategoryModel(id: 0, name: 'Hepsi', slug: 'all');
        final categories = [allCategory, ...result.categories!];

        emit(HomeLoaded(categories: categories));
      } else if (state is! HomeLoaded) {
        // Refresh sırasında mevcut kategoriler varsa onları koru.
        emit(HomeError(message: result.error ?? 'Kategoriler yüklenemedi'));
      }
    } catch (e) {
      if (state is! HomeLoaded) {
        emit(HomeError(message: 'Kategoriler yüklenirken hata: $e'));
      }
    }
  }
}
