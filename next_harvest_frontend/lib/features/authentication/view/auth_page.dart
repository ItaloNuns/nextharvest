import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/auth_viewmodel.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _confirmPassword.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(authViewModelProvider.notifier)
        .submit(
          email: _email.text,
          password: _password.text,
          register: _register,
          name: _register ? _name.text : null,
          onRegistrationSuccess: () async {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully'),
                duration: Duration(seconds: 2),
              ),
            );
            await Future<void>.delayed(const Duration(seconds: 2));
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          theme.brightness == Brightness.dark
                              ? 'assets/images/nh_logo_horizontal_light.png'
                              : 'assets/images/nh_logo_horizontal.png',
                          width: 180,
                          height: 114,
                          semanticLabel: 'Next Harvest',
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _register ? 'Create your account' : 'Welcome back',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !state.isLoading,
                          decoration: const InputDecoration(labelText: 'Name'),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !state.isLoading,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        validator: (value) =>
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter a valid email address.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !state.isLoading,
                        obscureText: _hidePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: _register
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!state.isLoading) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      if (_register) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPassword,
                          enabled: !state.isLoading,
                          obscureText: _hidePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!state.isLoading) _submit();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm your password.';
                            }
                            if (value != _password.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (state.hasError) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            state.error.toString(),
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: state.isLoading ? null : _submit,
                        child: state.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_register ? 'Create account' : 'Sign in'),
                      ),
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () {
                                ref
                                    .read(authViewModelProvider.notifier)
                                    .clearError();
                                _form.currentState?.reset();
                                _password.clear();
                                _confirmPassword.clear();
                                setState(() => _register = !_register);
                              },
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
