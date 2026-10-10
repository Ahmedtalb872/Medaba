import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/cloud.dart';
import '../data/synced_storage.dart';
import '../main.dart';
import '../models/invoice.dart';
import '../state/app_state.dart';
import '../widgets/brand.dart';

/// بوابة التطبيق المربوط بقاعدة البيانات: شاشة الدخول، ثم تحميل البيانات،
/// ثم التطبيق. تسجيل الخروج يعيد إلى شاشة الدخول.
class CloudGate extends StatefulWidget {
  const CloudGate({super.key});

  @override
  State<CloudGate> createState() => _CloudGateState();
}

class _CloudGateState extends State<CloudGate> {
  final _auth = Supabase.instance.client.auth;
  late final StreamSubscription<AuthState> _sub;
  AppState? _state;
  SyncedStorage? _storage;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    cloudSignOut = _signOut;
    _sub = _auth.onAuthStateChange.listen((_) => _sessionChanged());
    _sessionChanged();
  }

  @override
  void dispose() {
    _sub.cancel();
    _closeStorage();
    cloudSignOut = null;
    super.dispose();
  }

  void _closeStorage() {
    _storage?.status.removeListener(_publishStatus);
    _storage?.dispose();
    _storage = null;
    cloudSync.value = null;
  }

  void _publishStatus() => cloudSync.value = _storage?.status.value;

  Future<void> _sessionChanged() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (_state != null || _loadedFor != null) {
        _closeStorage();
        setState(() {
          _state = null;
          _loadedFor = null;
        });
      }
      return;
    }
    // تجديد الجلسة يرسل نفس المستخدم مرة أخرى؛ لا نعيد التحميل.
    if (_loadedFor == user.id) return;
    _loadedFor = user.id;
    setState(() => _state = null);

    final storage = SyncedStorage(
      local: await openLocalStorage(),
      remote: SupabaseRemoteStore(Supabase.instance.client),
    );
    await storage.init(AppState.storageKeys);
    final state = AppState(storage);
    await state.load();
    if (!mounted || _loadedFor != user.id) {
      storage.dispose();
      return;
    }
    _storage = storage..status.addListener(_publishStatus);
    _publishStatus();
    setState(() => _state = state);
  }

  /// يرفع ما لم يُرفع بعد (بحد أقصى بضع ثوانٍ) ثم يخرج.
  Future<void> _signOut() async {
    try {
      await _storage?.flush().timeout(const Duration(seconds: 8));
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return buildMaterialApp(home: const LoginScreen());
    }
    final state = _state;
    if (state == null) {
      return buildMaterialApp(
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(size: 44, name: CompanyInfo.defaultName),
                SizedBox(height: 24),
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('جارٍ تحميل البيانات...'),
              ],
            ),
          ),
        ),
      );
    }
    return MedabaApp(state: state);
  }
}

/// تسجيل الدخول بالبريد وكلمة المرور (الحسابات يضيفها المدير من Supabase).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = _message(e));
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال بالخادم، تحقق من الإنترنت');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _message(AuthException e) {
    if (e is AuthRetryableFetchException) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة';
    if (m.contains('not confirmed')) return 'الحساب لم يُفعَّل بعد';
    return 'تعذّر تسجيل الدخول: ${e.message}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: BrandLogo(
                            size: 44,
                            name: CompanyInfo.defaultName,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'تسجيل الدخول',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => (v ?? '').contains('@')
                              ? null
                              : 'اكتب بريداً صحيحاً',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _hide,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hide ? 'إظهار' : 'إخفاء',
                              icon: Icon(
                                _hide
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                          validator: (v) =>
                              (v ?? '').isEmpty ? 'اكتب كلمة المرور' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('دخول'),
                        ),
                      ],
                    ),
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
