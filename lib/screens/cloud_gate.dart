import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../data/cloud.dart';
import '../data/storage.dart';
import '../data/synced_storage.dart';
import '../main.dart';
import '../models/invoice.dart';
import '../state/app_state.dart';
import '../widgets/brand.dart';

/// بوابة التطبيق المربوط بقاعدة البيانات: شاشة الدخول، ثم تحميل البيانات،
/// ثم التطبيق. الدخول يبقى محفوظاً على الجهاز حتى «تسجيل الخروج».
class CloudGate extends StatefulWidget {
  const CloudGate({super.key});

  @override
  State<CloudGate> createState() => _CloudGateState();
}

enum _Stage { starting, login, loading, ready }

class _CloudGateState extends State<CloudGate> {
  static const _savedKey = 'cloud_login';

  _Stage _stage = _Stage.starting;
  AppState? _state;
  SyncedStorage? _storage;
  SupabaseRemoteStore? _remote;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    cloudSignOut = _signOut;
    cloudChangePassword = _changePassword;
    _start();
  }

  @override
  void dispose() {
    _closeStorage();
    cloudSignOut = null;
    cloudChangePassword = null;
    super.dispose();
  }

  Future<Storage> get _local => openLocalStorage();

  Future<void> _start() async {
    final saved = await (await _local).readList(_savedKey);
    final login = saved.isEmpty ? null : CloudLogin.fromJson(saved.first);
    if (login == null) {
      setState(() => _stage = _Stage.login);
      return;
    }
    setState(() => _stage = _Stage.loading);
    CloudLogin? checked = login;
    var online = true;
    try {
      checked = await checkLogin(cloudClient, login);
    } catch (_) {
      // بدون إنترنت: نفتح بآخر نسخة على الجهاز.
      online = false;
    }
    if (online && checked == null) {
      // تغيّرت كلمة المرور في قاعدة البيانات.
      await (await _local).writeList(_savedKey, const []);
      setState(() {
        _stage = _Stage.login;
        _loginError = 'تغيّرت كلمة المرور، سجّل الدخول من جديد';
      });
      return;
    }
    if (online) await (await _local).writeList(_savedKey, [checked!.toJson()]);
    await _open(checked ?? login);
  }

  /// يُرجع رسالة خطأ، أو null عند نجاح الدخول.
  Future<String?> _signIn(String username, String password) async {
    CloudLogin? login;
    // الصيغة الموحّدة أولاً، ثم كما كُتبت (لحسابات أُنشئت قبل التوحيد).
    final users = {cleanUsername(username), cleanCredential(username)};
    final passwords = {cleanCredential(password), password};
    try {
      search:
      for (final u in users) {
        for (final p in passwords) {
          login = await checkLogin(cloudClient, CloudLogin(u, p));
          if (login != null) break search;
        }
      }
    } catch (_) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }
    if (login == null) return 'اسم المستخدم أو كلمة المرور غير صحيحة';
    await (await _local).writeList(_savedKey, [login.toJson()]);
    setState(() {
      _stage = _Stage.loading;
      _loginError = null;
    });
    await _open(login);
    return null;
  }

  Future<void> _open(CloudLogin login) async {
    final remote = SupabaseRemoteStore(cloudClient, login);
    final storage = SyncedStorage(local: await _local, remote: remote);
    await storage.init(AppState.storageKeys);
    cloudLogin = login;
    final state = AppState(storage);
    await state.load();
    if (!isStockWorker) {
      // قاعدة بيانات المؤسسة لا تحتاج البيانات التجريبية القديمة.
      await state.removeDemoData();
      await state.ensureDefaultWarehouses();
      await state.ensureDefaultProducts();
    }
    if (!mounted) {
      storage.dispose();
      return;
    }
    _remote = remote;
    _storage = storage..status.addListener(_publishStatus);
    _publishStatus();
    setState(() {
      _state = state;
      _stage = _Stage.ready;
    });
  }

  void _closeStorage() {
    _storage?.status.removeListener(_publishStatus);
    _storage?.dispose();
    _storage = null;
    _remote = null;
    cloudSync.value = null;
    cloudLogin = null;
  }

  void _publishStatus() => cloudSync.value = _storage?.status.value;

  /// يُرجع رسالة خطأ، أو null بعد تغيير كلمة المرور. يبقى المستخدم داخلاً.
  Future<String?> _changePassword(String current, String next) async {
    final login = cloudLogin;
    final remote = _remote;
    if (login == null || remote == null) return 'سجّل الدخول أولاً';
    if (current != login.password &&
        cleanCredential(current) != login.password) {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    final password = cleanCredential(next);
    if (password.length < 4) return '4 أحرف أو أرقام على الأقل';
    // يُرفع ما لم يُرفع بكلمة المرور القديمة قبل تغييرها.
    try {
      await _storage?.flush().timeout(const Duration(seconds: 8));
    } catch (_) {}
    try {
      await cloudClient.rpc(
        'app_change_password',
        params: {...login.params, 'p_new': password},
      );
    } on PostgrestException catch (e) {
      return e.code == 'PGRST202'
          ? 'شغّل كود SQL الجديد في Supabase أولاً'
          : 'تعذّر تغيير كلمة المرور';
    } catch (_) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }
    final updated = CloudLogin(login.username, password, login.role);
    remote.login = updated;
    cloudLogin = updated;
    await (await _local).writeList(_savedKey, [updated.toJson()]);
    return null;
  }

  /// يرفع ما لم يُرفع بعد (بحد أقصى بضع ثوانٍ) ثم يخرج.
  Future<void> _signOut() async {
    try {
      await _storage?.flush().timeout(const Duration(seconds: 8));
    } catch (_) {}
    await (await _local).writeList(_savedKey, const []);
    _closeStorage();
    setState(() {
      _state = null;
      _stage = _Stage.login;
    });
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _Stage.ready => MedabaApp(state: _state!),
    _Stage.login => buildMaterialApp(
      home: LoginScreen(onSubmit: _signIn, initialError: _loginError),
    ),
    _ => buildMaterialApp(
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
    ),
  };
}

/// تسجيل الدخول باسم المستخدم وكلمة المرور (الحسابات في الجدول app_users).
class LoginScreen extends StatefulWidget {
  /// يُرجع رسالة الخطأ، أو null عند النجاح.
  final Future<String?> Function(String username, String password) onSubmit;
  final String? initialError;
  const LoginScreen({super.key, required this.onSubmit, this.initialError});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  late String? _error = widget.initialError;

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
    final error = await widget.onSubmit(_email.text, _password.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
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
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'اكتب اسم المستخدم'
                              : null,
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
