import 'package:equatable/equatable.dart';
import '../../../home/data/models/business_model.dart';
import '../../../home/data/models/package_model.dart';

abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => [];
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapLoading extends MapState {
  const MapLoading();
}

class MapLoaded extends MapState {
  final List<BusinessModel> businesses;
  final BusinessModel? selectedBusiness;
  final Map<String, dynamic>?
  directions; // contains 'distance', 'duration', 'geometry'
  final PackageModel? selectedPackage; // seçili işletmenin temsilî paketi
  final bool packageLoading; // paket çekilirken true

  const MapLoaded({
    required this.businesses,
    this.selectedBusiness,
    this.directions,
    this.selectedPackage,
    this.packageLoading = false,
  });

  MapLoaded copyWith({
    List<BusinessModel>? businesses,
    BusinessModel? selectedBusiness,
    bool clearSelection = false,
    Map<String, dynamic>? directions,
    bool clearDirections = false,
    PackageModel? selectedPackage,
    bool clearPackage = false,
    bool? packageLoading,
  }) {
    return MapLoaded(
      businesses: businesses ?? this.businesses,
      selectedBusiness: clearSelection
          ? null
          : (selectedBusiness ?? this.selectedBusiness),
      directions: clearDirections ? null : (directions ?? this.directions),
      selectedPackage: (clearSelection || clearPackage)
          ? null
          : (selectedPackage ?? this.selectedPackage),
      packageLoading: clearSelection
          ? false
          : (packageLoading ?? this.packageLoading),
    );
  }

  @override
  List<Object?> get props => [
    businesses,
    selectedBusiness,
    directions,
    selectedPackage,
    packageLoading,
  ];
}

class MapError extends MapState {
  final String message;
  final List<BusinessModel> businesses;

  const MapError({required this.message, this.businesses = const []});

  @override
  List<Object?> get props => [message, businesses];
}
