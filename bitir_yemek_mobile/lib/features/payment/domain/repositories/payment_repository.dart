import '../../data/repositories/payment_repository_impl.dart';

abstract class PaymentRepository {
  Future<PaymentStatusResult> getStatus(String conversationId, {bool sync});
}
