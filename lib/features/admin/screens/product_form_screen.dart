import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _allergenesController = TextEditingController();

  String? _selectedCategoryId;
  List<Category> _categories = [];

  File? _selectedImage;
  String? _existingImageUrl;

  final List<ProductOption> _options = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descController.dispose();
    _ingredientsController.dispose();
    _allergenesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _firestoreService.getCategories();
      
      if (widget.productId != null) {
        final product = await _firestoreService.getProduct(widget.productId!);
        if (product != null) {
          _nomController.text = product.nom;
          _descController.text = product.description;
          _ingredientsController.text = product.ingredients;
          _allergenesController.text = product.allergenes;
          _selectedCategoryId = product.categorieId;
          _existingImageUrl = product.imageUrl;
          _options.addAll(product.options);
        }
      } else {
        // Mode création, ajouter au moins une option vide
        _options.add(ProductOption(label: 'Standard', prix: 0));
      }

      setState(() {
        _categories = categories;
        if (_selectedCategoryId == null && _categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur au chargement: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80, // Compression natif via image_picker !
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImage == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une image')),
      );
      return;
    }

    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins une option')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isEditing = widget.productId != null;
      
      // 1. Déterminer l'ID du produit
      final String productId = isEditing 
          ? widget.productId! 
          : FirebaseFirestore.instance.collection('products').doc().id;

      // 2. Upload de l'image (si nouvelle)
      String finalImageUrl = _existingImageUrl ?? '';
      if (_selectedImage != null) {
        final url = await _storageService.uploadProductImage(_selectedImage!, productId);
        if (url != null) {
          finalImageUrl = url;
        } else {
          throw Exception("L'upload de l'image a échoué");
        }
      }

      // 3. Préparer les données du produit
      final productData = Product(
        id: productId,
        nom: _nomController.text.trim(),
        description: _descController.text.trim(),
        categorieId: _selectedCategoryId ?? '',
        imageUrl: finalImageUrl,
        disponible: true, // Par défaut dispo à la création
        ingredients: _ingredientsController.text.trim(),
        allergenes: _allergenesController.text.trim(),
        noteMoyenne: 0.0, // Initialisation
        nombreAvis: 0,
        options: _options,
        createdAt: isEditing ? null : DateTime.now(), // Ignoré à l'update si on utilise toMap partiel
      );

      // 4. Enregistrer dans Firestore
      if (isEditing) {
        // En mode édition on ne modifie pas noteMoyenne, nombreAvis ni createdAt s'ils existent déjà
        final updateData = {
          'nom': productData.nom,
          'description': productData.description,
          'categorie_id': productData.categorieId,
          'image_url': productData.imageUrl,
          'ingredients': productData.ingredients,
          'allergenes': productData.allergenes,
          'options': productData.options.map((o) => o.toMap()).toList(),
        };
        await _firestoreService.updateProduct(productId, updateData);
      } else {
        await _firestoreService.createProduct(productData);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit enregistré avec succès!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addOption() {
    setState(() {
      _options.add(ProductOption(label: 'Nouvelle option', prix: 0));
    });
  }

  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
    });
  }

  void _updateOptionLabel(int index, String value) {
    _options[index] = ProductOption(label: value, prix: _options[index].prix);
  }

  void _updateOptionPrice(int index, String value) {
    final price = double.tryParse(value) ?? 0.0;
    _options[index] = ProductOption(label: _options[index].label, prix: price);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier produit' : 'Nouveau produit', style: const TextStyle(color: AppColors.texte)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.texte),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaire))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- IMAGE SECTION ---
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover),
                              )
                            : (_existingImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
                                      imageUrl: _existingImageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Ajouter une image', style: TextStyle(color: Colors.grey)),
                                    ],
                                  )),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- DETAILS SECTION ---
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(labelText: 'Nom du produit', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 3,
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                      items: _categories.map((c) {
                        return DropdownMenuItem(value: c.id, child: Text(c.nom));
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                      },
                      validator: (v) => v == null ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ingredientsController,
                      decoration: const InputDecoration(labelText: 'Ingrédients', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _allergenesController,
                      decoration: const InputDecoration(labelText: 'Allergènes', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),

                    // --- OPTIONS SECTION ---
                    const Text('Options (Tailles, Quantités...)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...List.generate(_options.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: _options[index].label,
                                decoration: const InputDecoration(labelText: 'Label (ex: Boîte de 6)', border: OutlineInputBorder()),
                                onChanged: (val) => _updateOptionLabel(index, val),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: _options[index].prix.toString(),
                                decoration: const InputDecoration(labelText: 'Prix', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _updateOptionPrice(index, val),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeOption(index),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une option'),
                    ),
                    const SizedBox(height: 32),

                    // --- SUBMIT BUTTON ---
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaire,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveProduct,
                      child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
