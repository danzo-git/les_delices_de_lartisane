import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../theme/app_colors.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  void _showAddAddressDialog(BuildContext context) {
    final labelController = TextEditingController();
    final communeController = TextEditingController();
    final detailsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une adresse'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Libellé (ex: Maison)'),
                  validator: (val) => (val == null || val.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: communeController,
                  decoration: const InputDecoration(labelText: 'Commune'),
                  validator: (val) => (val == null || val.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: detailsController,
                  decoration: const InputDecoration(labelText: 'Détails de livraison'),
                  validator: (val) => (val == null || val.isEmpty) ? 'Requis' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newAddress = UserAddress(
                  label: labelController.text.trim(),
                  commune: communeController.text.trim(),
                  details: detailsController.text.trim(),
                );
                
                final profile = ref.read(authProvider).profile;
                if (profile != null) {
                  final newAddresses = List<UserAddress>.from(profile.adresses)..add(newAddress);
                  await ref.read(authProvider.notifier).updateAddresses(newAddresses);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAddress(int index) async {
    final profile = ref.read(authProvider).profile;
    if (profile != null) {
      final newAddresses = List<UserAddress>.from(profile.adresses)..removeAt(index);
      await ref.read(authProvider.notifier).updateAddresses(newAddresses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final addresses = profile?.adresses ?? [];

    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mes adresses',
          style: TextStyle(
            color: AppColors.texte,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.texte),
      ),
      body: addresses.isEmpty
          ? const Center(child: Text('Aucune adresse enregistrée.', style: TextStyle(color: AppColors.secondaire)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final addr = addresses[index];
                return Dismissible(
                  key: ValueKey('${addr.label}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeAddress(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.location_on, color: AppColors.primaire),
                      title: Text(addr.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${addr.commune}\n${addr.details}'),
                      isThreeLine: true,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAddressDialog(context),
        backgroundColor: AppColors.primaire,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
