// lib/main.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'local_store.dart';
import 'root_shell.dart';

/// Varsayılan personel id (şimdilik tek cihaz için)
const String kDefaultPersonelId = 'p1';

/// Uygulama modu: kişisel / kurumsal
enum AppMode { personal, corporate }

Future<void> _setupPushAndSaveToken() async {
  // Android 13+ bildirim izni
  await FirebaseMessaging.instance.requestPermission();

  final token = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM token: $token');

  if (token != null) {
    await FirebaseFirestore.instance.collection('tokens').doc(token).set({
      'personelId': kDefaultPersonelId,
      'platform': kIsWeb ? 'web' : 'android',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _setupPushAndSaveToken();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF0B1B3B); // koyu lacivert
    return MaterialApp(
      title: 'Hospital Code App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: const Color(0xFF0B1B3B),
              displayColor: const Color(0xFF0B1B3B),
            ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.7),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(8),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1B),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.07),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(8),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const SessionGate(),
    );
  }
}

/// Açılış kapısı: kaydedilmiş session varsa direkt RootShell
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String email, AppMode mode})?>(
      future: LocalStore.readSession(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snap.data;
        if (session == null) return const IntroPage();

        return RootShell(
          email: session.email,
          mode: session.mode,
        );
      },
    );
  }
}

/// 1) Mod seçimi
class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  void _goToMode(BuildContext context, AppMode mode) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AuthPage(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HHLogo(size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Hospital Code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lütfen kullanım şeklini seçin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _goToMode(context, AppMode.personal),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Kişisel Kullanım',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _goToMode(context, AppMode.corporate),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Kurumsal Kullanım (Hastane vb.)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seçiminizi daha sonra hesap ayarlarından da değiştirebileceğiz.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2) Email giriş ekranı
class AuthPage extends StatefulWidget {
  final AppMode mode;
  const AuthPage({super.key, required this.mode});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  bool _loading = false;

  String get _modeText =>
      widget.mode == AppMode.personal ? 'Kişisel kullanım' : 'Kurumsal kullanım';

  Future<void> _continue() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir e-posta adresi girin.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await LocalStore.saveSession(email: email, mode: widget.mode);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RootShell(
            email: email,
            mode: widget.mode,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HHLogo(size: 36),
                  const SizedBox(height: 8),
                  Text(_modeText, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Devam etmek için e-posta adresinizi girin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta adresi',
                      hintText: 'ornek@hastane.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _continue,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Devam et'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Not: Gerçek doğrulama kodu ve davet mailleri Blaze açıldıktan sonra aktif edilecek.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3) Ana sayfa (RootShell içinde kullanılacak)
class HomePage extends StatefulWidget {
  final AppMode mode;
  final String email;

  const HomePage({super.key, required this.mode, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String projectId = '';
  final TextEditingController _msg = TextEditingController(text: 'Kod verildi');

  @override
  void initState() {
    super.initState();
    projectId = Firebase.app().options.projectId;
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> sendCode(String color, String message) async {
    await FirebaseFirestore.instance.collection('codes').add({
      'color': color,
      'message': message.isEmpty ? '${color.toUpperCase()} KOD' : message,
      'createdAt': FieldValue.serverTimestamp(),
      'by': kDefaultPersonelId,
      'mode': widget.mode.name,
      'email': widget.email,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${color.toUpperCase()} kod gönderildi')),
    );
  }

  Future<void> _confirmAndSend(CodeSpec spec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${spec.title} verilsin mi?'),
        content: Text('Mesaj: ${_msg.text.isEmpty ? '(boş)' : _msg.text}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await sendCode(spec.key, _msg.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codes = <CodeSpec>[
      CodeSpec(key: 'mavi', title: 'Mavi Kod', color: const Color(0xFF1565FF)),
      CodeSpec(key: 'beyaz', title: 'Beyaz Kod', color: const Color(0xFFFFFFFF)),
      CodeSpec(key: 'kırmızı', title: 'Kırmızı Kod', color: const Color(0xFFFF3B30)),
      CodeSpec(key: 'pembe', title: 'Pembe Kod', color: const Color(0xFFFF2D8B)),
      CodeSpec(key: 'turuncu', title: 'Turuncu Kod', color: const Color(0xFFFF8A00)),
      CodeSpec(key: 'sarı', title: 'Sarı Kod', color: const Color(0xFFFFD60A)),
    ];

    final modeChipText = widget.mode == AppMode.personal ? 'Kişisel mod' : 'Kurumsal mod';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            const HHLogo(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text('Hospital Code', overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      modeChipText,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: GlassBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Firebase: $projectId',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          widget.email,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bildirim mesajı'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _msg,
                      decoration: const InputDecoration(
                        hintText: 'Örn: Mavi kod verildi, Dahiliye 2. kat',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => FirebaseFirestore.instance.collection('test').add({
                          'message': 'Merhaba Firestore',
                          'time': FieldValue.serverTimestamp(),
                        }),
                        icon: const Icon(Icons.bolt_outlined),
                        label: const Text('Firestore’a Test Yaz'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _GlassCard(
                child: _Emergency112Panel(
                  onSend: () {
                    _confirmAndSend(
                      CodeSpec(
                        key: '112',
                        title: '112 Yayını',
                        color: const Color(0xFF00E5FF),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: codes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, i) => CodeButton(
                    spec: codes[i],
                    onTap: () => _confirmAndSend(codes[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ————— Görsel Bileşenler —————

/// Cam (glass) arka plan: degrade + blur
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          child: _Blob(
            size: 260,
            colors: [
              const Color(0xFF3E5BFF).withOpacity(isDark ? .18 : .22),
              const Color(0xFF00E5FF).withOpacity(isDark ? .10 : .14),
            ],
          ),
        ),
        Positioned(
          bottom: -140,
          right: -40,
          child: _Blob(
            size: 300,
            colors: [
              const Color(0xFFFF2D8B).withOpacity(isDark ? .10 : .14),
              const Color(0xFFFFD60A).withOpacity(isDark ? .08 : .12),
            ],
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.transparent),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final List<Color> colors;
  const _Blob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

/// HH monogram
class HHLogo extends StatelessWidget {
  final double size;
  const HHLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final base = const Color(0xFF0B1B3B);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'H',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: base,
            letterSpacing: -1,
          ),
        ),
        Transform.translate(
          offset: Offset(size * 0.35, 0),
          child: Transform.rotate(
            angle: -0.10,
            child: Text(
              'H',
              style: TextStyle(
                fontSize: size * 0.92,
                fontWeight: FontWeight.w900,
                color: base.withOpacity(0.92),
                letterSpacing: -1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _Emergency112Panel extends StatefulWidget {
  final VoidCallback onSend;
  const _Emergency112Panel({required this.onSend});

  @override
  State<_Emergency112Panel> createState() => _Emergency112PanelState();
}

class _Emergency112PanelState extends State<_Emergency112Panel> {
  bool active = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.emergency_share_outlined),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('112 Yayını', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                active
                    ? 'Yakın çevre yayın hazır (PIN gerekiyorsa ayarlardan)'
                    : '112 yayını devre dışı',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Switch(
          value: active,
          onChanged: (v) => setState(() => active = v),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: active ? widget.onSend : null,
          child: const Text('Gönder'),
        ),
      ],
    );
  }
}

/// Veri modeli
class CodeSpec {
  final String key;
  final String title;
  final Color color;
  CodeSpec({required this.key, required this.title, required this.color});
}

class CodeButton extends StatefulWidget {
  final CodeSpec spec;
  final VoidCallback onTap;
  const CodeButton({super.key, required this.spec, required this.onTap});

  @override
  State<CodeButton> createState() => _CodeButtonState();
}

class _CodeButtonState extends State<CodeButton> {
  bool _pressed = false;
  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final bg = widget.spec.color;
    final fg = bg.computeLuminance() > 0.7 ? Colors.black : Colors.white;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: Text(
                widget.spec.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
