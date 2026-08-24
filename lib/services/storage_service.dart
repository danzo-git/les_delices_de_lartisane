import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProductImage(File image, String productId) async {
    try {
      final ref = _storage.ref().child('products/$productId.jpg');
      
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      final uploadTask = await ref.putFile(image, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image produit: $e');
      return null;
    }
  }
}
