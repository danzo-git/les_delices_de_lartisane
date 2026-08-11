import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String?> initierPaiement(String orderId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('createPayment');
      final result = await callable.call(<String, dynamic>{
        'orderId': orderId,
      });

      if (result.data != null && result.data['checkout_url'] != null) {
        return result.data['checkout_url'] as String;
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      print('Erreur Firebase Functions: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Erreur inattendue lors de l\'initiation du paiement: $e');
      rethrow;
    }
  }
}
