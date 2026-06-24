import '../datasources/payment_remote_datasource.dart';
import '../models/payment_status_model.dart';
import '../../domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;

  PaymentRepositoryImpl({required PaymentRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<PaymentStatusResult> getStatus(String conversationId, {bool sync = false}) async {
    try {
      final response = await _remoteDataSource.getStatus(conversationId, sync: sync);
      final status = PaymentStatusModel.fromJson(response);
      return PaymentStatusResult.success(status);
    } on PaymentException catch (e) {
      return PaymentStatusResult.failure(e.message);
    } catch (e) {
      return PaymentStatusResult.failure('Bir hata oluştu: $e');
    }
  }
}

class PaymentStatusResult {
  final bool isSuccess;
  final PaymentStatusModel? status;
  final String? error;

  PaymentStatusResult._({required this.isSuccess, this.status, this.error});

  factory PaymentStatusResult.success(PaymentStatusModel status) =>
      PaymentStatusResult._(isSuccess: true, status: status);

  factory PaymentStatusResult.failure(String error) =>
      PaymentStatusResult._(isSuccess: false, error: error);
}
