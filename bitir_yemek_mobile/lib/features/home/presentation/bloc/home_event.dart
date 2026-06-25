part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategories extends HomeEvent {
  const LoadCategories();
}

/// Pull-to-refresh: kategorileri cache'i bypass ederek yeniden çeker.
/// HomeLoading emit edilmez; mevcut kategori şeridi kaybolmaz.
class RefreshCategories extends HomeEvent {
  const RefreshCategories();
}
