import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';
import 'package:voyageur/shared_widgets/inputs/app_text_field.dart';
import 'package:voyageur/screens/auth/widgets/auth_form_header.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // ── Indicatif Algérie ─────────────────────────────────────────────────────
  static const String _kPhonePrefix = '+213';

  /// Valide un numéro algérien : doit commencer par +213 et contenir
  /// au moins 9 chiffres après l'indicatif (ex : +213 6 12 34 56 78).
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // champ optionnel
    final digits = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!digits.startsWith(_kPhonePrefix)) {
      return "Le numéro doit commencer par $_kPhonePrefix";
    }
    final localPart = digits.substring(_kPhonePrefix.length);
    if (localPart.length < 9) {
      return 'Numéro trop court (9 chiffres requis après +213)';
    }
    if (!RegExp(r'^\d+$').hasMatch(localPart)) {
      return 'Numéro invalide';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.maybeWhen(
      loading: () => true,
      orElse: () => false,
    );

    ref.listen(authProvider, (prev, next) {
      next.when(
        initial: () {},
        loading: () {},
        authenticated: (_) => context.go(AppRoutes.home),
        unauthenticated: () {},
        guest: () => context.go(AppRoutes.home),
        error: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const AuthFormHeader(
                  title: 'Créer un compte',
                  subtitle: 'Rejoignez-nous pour commencer votre voyage.',
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Nom complet ──────────────────────────────────────────────
                AppTextField(
                  label: 'Nom complet',
                  // Exemple avec nom algérien (prénom + nom de famille).
                  hint: 'Abdelhadi Merine',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.person_outlined),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Email ────────────────────────────────────────────────────
                AppTextField(
                  label: 'Email',
                  hint: 'votre@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email obligatoire';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Téléphone (indicatif Algérie +213) ──────────────────────
                AppTextField(
                  label: 'Téléphone',
                  hint: '+213 6 12 34 56 78',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  validator: _validatePhone,
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Mot de passe ─────────────────────────────────────────────
                AppTextField(
                  label: 'Mot de passe',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Mot de passe obligatoire';
                    if (v.length < 8) return 'Minimum 8 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Confirmation mot de passe ────────────────────────────────
                AppTextField(
                  label: 'Confirmer le mot de passe',
                  hint: '••••••••',
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                PrimaryButton(
                  label: "S'inscrire",
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà un compte ?'),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
