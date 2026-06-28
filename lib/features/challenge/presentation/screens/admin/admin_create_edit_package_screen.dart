import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';

class AdminCreateEditPackageScreen extends StatefulWidget {
  final String challengeId;
  final ChallengePackage? existingPackage;

  const AdminCreateEditPackageScreen({
    Key? key,
    required this.challengeId,
    this.existingPackage,
  }) : super(key: key);

  @override
  State<AdminCreateEditPackageScreen> createState() => _AdminCreateEditPackageScreenState();
}

class _AdminCreateEditPackageScreenState extends State<AdminCreateEditPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _currencyController;
  late TextEditingController _orderController;
  bool _challengeEntryIncluded = true;
  bool _isActive = true;
  List<ChallengeShopifyVariant> _variants = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingPackage?.name ?? '');
    _descriptionController = TextEditingController(text: widget.existingPackage?.description ?? '');
    _priceController = TextEditingController(text: widget.existingPackage?.packagePrice.toString() ?? '0');
    _currencyController = TextEditingController(text: widget.existingPackage?.currency ?? 'USD');
    _orderController = TextEditingController(text: widget.existingPackage?.displayOrder.toString() ?? '0');
    _challengeEntryIncluded = widget.existingPackage?.challengeEntryIncluded ?? true;
    _isActive = widget.existingPackage?.isActive ?? true;
    _variants = widget.existingPackage != null ? List.from(widget.existingPackage!.shopifyVariants) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      _variants.add(ChallengeShopifyVariant(productId: '', variantId: '', quantity: 1));
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final adminId = context.read<AuthService>().currentUser?.id ?? '';
    final service = context.read<ChallengePackageService>();
    final audit = context.read<AdminAuditService>();

    final package = ChallengePackage(
      id: widget.existingPackage?.id ?? '',
      challengeId: widget.challengeId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      packagePrice: double.parse(_priceController.text),
      currency: _currencyController.text.trim(),
      displayOrder: int.parse(_orderController.text),
      isActive: _isActive,
      challengeEntryIncluded: _challengeEntryIncluded,
      shopifyVariants: _variants,
      createdAt: widget.existingPackage?.createdAt,
    );

    try {
      if (widget.existingPackage == null) {
        await service.savePackage(package);
      } else {
        await service.updatePackage(package);
      }

      await audit.logAction(
        adminId: adminId,
        challengeId: widget.challengeId,
        action: widget.existingPackage == null ? 'create_package' : 'update_package',
        targetCollection: 'challengePackages',
        targetId: package.id,
        newData: package.toMap(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package saved successfully'), backgroundColor: AppTheme.lime),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: Text(widget.existingPackage == null ? 'Create Package' : 'Edit Package', style: AppTheme.headingMD),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: AppTheme.textPrimary),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('BASIC INFO'),
                const SizedBox(height: 16),
                _buildTextField(label: 'Package Name', controller: _nameController, hint: 'e.g. Starter Kit', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField(label: 'Description', controller: _descriptionController, hint: 'What is included?', maxLines: 3, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(label: 'Price', controller: _priceController, keyboardType: TextInputType.number, validator: (v) => (double.tryParse(v!) ?? -1) < 0 ? 'Invalid' : null)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(label: 'Currency', controller: _currencyController, hint: 'USD', validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(label: 'Display Order', controller: _orderController, keyboardType: TextInputType.number, validator: (v) => int.tryParse(v!) == null ? 'Invalid' : null),
                const SizedBox(height: 24),
                _buildSwitchRow('Challenge Entry Included', _challengeEntryIncluded, (v) => setState(() => _challengeEntryIncluded = v)),
                _buildSwitchRow('Active (Visible to users)', _isActive, (v) => setState(() => _isActive = v)),
                
                const SizedBox(height: 32),
                _buildSectionTitle('SHOPIFY VARIANTS'),
                const SizedBox(height: 8),
                const Text(
                  'WARNING: Product/Variant IDs are references only. Shopify remains the source of truth for catalog data.',
                  style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._variants.asMap().entries.map((entry) => _buildVariantEditor(entry.key, entry.value)),
                const SizedBox(height: 16),
                EFButton(
                  label: 'Add Shopify Variant',
                  onTap: _addVariant,
                  variant: EFButtonVariant.ghost,
                  height: 44,
                ),

                const SizedBox(height: 48),
                EFButton(
                  label: _isLoading ? 'Saving...' : 'Save Package',
                  onTap: _isLoading ? null : _save,
                  loading: _isLoading,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTheme.labelMD.copyWith(letterSpacing: 2.0));
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.labelSM.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: AppTheme.surface1,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyMD.copyWith(color: AppTheme.textPrimary)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.lime,
            activeThumbColor: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildVariantEditor(int index, ChallengeShopifyVariant variant) {
    return EFCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: variant.productId,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(hintText: 'Product ID (GID)', labelText: 'Product ID', labelStyle: TextStyle(fontSize: 10)),
                  onChanged: (v) => _variants[index] = ChallengeShopifyVariant(productId: v, variantId: _variants[index].variantId, quantity: _variants[index].quantity),
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error), onPressed: () => _removeVariant(index)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: variant.variantId,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(hintText: 'Variant ID (GID)', labelText: 'Variant ID', labelStyle: TextStyle(fontSize: 10)),
                  onChanged: (v) => _variants[index] = ChallengeShopifyVariant(productId: _variants[index].productId, variantId: v, quantity: _variants[index].quantity),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: variant.quantity.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Qty', labelStyle: TextStyle(fontSize: 10)),
                  onChanged: (v) => _variants[index] = ChallengeShopifyVariant(productId: _variants[index].productId, variantId: _variants[index].variantId, quantity: int.tryParse(v) ?? 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
