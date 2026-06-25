part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchPackages extends SearchEvent {
  final double latitude;
  final double longitude;
  final String? query;
  final SortOrder sortOrder;

  /// Pull-to-refresh: cache'i bypass ederek taze veri çeker.
  final bool forceRefresh;

  const SearchPackages({
    required this.latitude,
    required this.longitude,
    this.query,
    this.sortOrder = SortOrder.distance,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    query,
    sortOrder,
    forceRefresh,
  ];
}

class LoadMoreSearchResults extends SearchEvent {
  final double latitude;
  final double longitude;

  const LoadMoreSearchResults({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}

class UpdateSortOrder extends SearchEvent {
  final SortOrder sortOrder;

  const UpdateSortOrder({required this.sortOrder});

  @override
  List<Object?> get props => [sortOrder];
}

class UpdateSearchFilters extends SearchEvent {
  final double? maxPrice;
  final int? categoryId;
  final double? radius;

  const UpdateSearchFilters({this.maxPrice, this.categoryId, this.radius});

  @override
  List<Object?> get props => [maxPrice, categoryId, radius];
}
