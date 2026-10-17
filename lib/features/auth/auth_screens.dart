import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/form_validators.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0E5FD2), AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(27),
                      ),
                      child: const Icon(
                        Icons.headset_mic_outlined,
                        size: 42,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Solusi cepat untuk kendala IT Anda',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => context.go(AppRoutes.onboarding),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Mulai Sekarang'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'IT Helpdesk · v1.0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .62),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slides = [
    (
      Icons.confirmation_number_outlined,
      'Laporkan kendala dengan mudah',
      'Buat tiket dalam beberapa langkah dan jelaskan kendala IT yang Anda alami.',
    ),
    (
      Icons.access_time,
      'Pantau progres kapan saja',
      'Lihat status dan catatan penanganan secara transparan dari satu tempat.',
    ),
    (
      Icons.headset_mic_outlined,
      'Bekerja nyaman tanpa hambatan',
      'Tim IT siap membantu agar Anda dapat kembali produktif lebih cepat.',
    ),
  ];
  int _current = 0;

  void _finish() => context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Lewati'),
                ),
              ),
              Expanded(
                flex: 5,
                child: Center(
                  child: Container(
                    width: 190,
                    height: 205,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x221769E0),
                          blurRadius: 40,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Icon(slide.$1, size: 64, color: AppColors.primary),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == _current ? 24 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == _current
                                ? AppColors.primary
                                : const Color(0xFFCDD6E4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      slide.$2,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      slide.$3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _current == _slides.length - 1
                    ? _finish
                    : () => setState(() => _current++),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_current == _slides.length - 1 ? 'Mulai' : 'Lanjut'),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _busy = false;
  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    context.read<AuthProvider>().clearError();
    setState(() => _validationError = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _validationError = 'Email dan password wajib diisi.');
      return;
    }
    final emailError = FormValidators.email(email);
    if (emailError != null) {
      setState(() => _validationError = emailError);
      return;
    }
    setState(() => _busy = true);
    await context.read<AuthProvider>().signIn(email, password);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: _AppLogo(size: 56),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Selamat datang',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Masuk untuk melanjutkan ke IT Helpdesk',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('login-email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('login-password'),
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: 'Tampilkan password',
                            onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_validationError != null ||
                          context.watch<AuthProvider>().error != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(
                          text: _validationError ??
                              context.watch<AuthProvider>().error!,
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.go(AppRoutes.resetPassword),
                          child: const Text('Lupa Password?'),
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Memproses...' : 'Masuk'),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Belum punya akun? ',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          GestureDetector(
                            onTap: () => context.go(AppRoutes.register),
                            child: const Text(
                              'Daftar',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class RegisterEmployeeScreen extends StatefulWidget {
  const RegisterEmployeeScreen({super.key});

  @override
  State<RegisterEmployeeScreen> createState() => _RegisterEmployeeScreenState();
}

class _RegisterEmployeeScreenState extends State<RegisterEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _department = TextEditingController();
  final _companyCode = TextEditingController();
  bool _busy = false;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _department.dispose();
    _companyCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if ([
      _name,
      _email,
      _password,
      _confirmPassword,
      _department,
      _companyCode,
    ].any((controller) => controller.text.trim().isEmpty)) {
      setState(() => _formError = 'Semua field wajib diisi.');
      return;
    }
    final emailError = FormValidators.email(_email.text);
    final passwordError = FormValidators.password(_password.text);
    if (emailError != null || passwordError != null) {
      setState(() => _formError = emailError ?? passwordError);
      return;
    }
    if (_confirmPassword.text != _password.text) {
      setState(() => _formError = 'Konfirmasi password tidak cocok.');
      return;
    }
    setState(() => _busy = true);
    await context.read<AuthProvider>().registerEmployee(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          department: _department.text,
          companyCode: _companyCode.text,
        );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Karyawan'),
          leading: IconButton(
            onPressed: () => context.go(AppRoutes.login),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Buat akun karyawan',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _EntryField(
                controller: _name,
                label: 'Nama lengkap',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _EntryField(
                controller: _email,
                label: 'Email perusahaan',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _EntryField(
                controller: _password,
                label: 'Password',
                hint: 'Minimal 8 karakter',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _EntryField(
                controller: _confirmPassword,
                label: 'Konfirmasi password',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _EntryField(
                controller: _department,
                label: 'Departemen',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _EntryField(
                controller: _companyCode,
                label: 'Kode perusahaan',
                textCapitalization: TextCapitalization.characters,
              ),
              if (_formError != null || context.watch<AuthProvider>().error != null) ...[
                const SizedBox(height: 12),
                _InlineError(
                  text: _formError ?? context.watch<AuthProvider>().error!,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Mendaftarkan...' : 'Daftar'),
              ),
            ],
          ),
        ),
      );
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  String? _validationError;
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final validationError = FormValidators.email(_email.text);
    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }
    setState(() => _validationError = null);
    setState(() => _busy = true);
    final sent = await context.read<AuthProvider>().sendPasswordReset(
          _email.text,
        );
    if (mounted) {
      setState(() {
        _busy = false;
        _sent = sent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lupa Password'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.login),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 36),
          Icon(
            _sent ? Icons.check_circle_outline : Icons.lock_outline,
            size: 58,
            color: _sent ? AppColors.completed : AppColors.primary,
          ),
          const SizedBox(height: 22),
          Text(
            _sent ? 'Periksa email Anda' : 'Atur ulang password',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            _sent
                ? 'Instruksi reset password telah dikirim ke email Anda.'
                : 'Masukkan email perusahaan Anda. Kami akan mengirimkan instruksi reset password.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 26),
          if (!_sent) ...[
            _EntryField(
              controller: _email,
              label: 'Email perusahaan',
              keyboardType: TextInputType.emailAddress,
            ),
            if (_validationError != null || auth.error != null) ...[
              const SizedBox(height: 12),
              _InlineError(text: _validationError ?? auth.error!),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Mengirim...' : 'Kirim Link Reset'),
            ),
          ] else
            FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Kembali ke Login'),
            ),
        ],
      ),
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final requiredRole =
        user?.isAdmin == true ? 'Karyawan' : 'Admin IT';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.cancelled,
              ),
              const SizedBox(height: 20),
              Text(
                'Akses ditolak',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Halaman ini hanya dapat diakses oleh $requiredRole. Role akun dibaca dari data pengguna dan tidak dapat diubah secara mandiri.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => context.go(
                  user?.isAdmin == true
                      ? AppRoutes.adminHome
                      : AppRoutes.employeeHome,
                ),
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryField extends StatelessWidget {
  const _EntryField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.headset_mic_outlined,
          color: Colors.white,
          size: size * .52,
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cancelledSoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 17,
                color: AppColors.cancelled,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.cancelled,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
