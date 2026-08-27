/// Kayıt sırasında kullanılan hesap rolü.
///
/// [apiValue] backend'in beklediği değerdir: authController 'business_owner'
/// dışındaki her şeyi 'customer'a düşürür ve 'admin' dışarıdan atanamaz.
enum AppRole {
  customer('customer'),
  businessOwner('business_owner');

  final String apiValue;
  const AppRole(this.apiValue);
}
