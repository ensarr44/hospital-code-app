// lib/settings_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ⬇️ CSV içe aktarma için (mevcutsa)
import 'csv_importer.dart';

/// Ana ekrandaki sabitle aynı kişiyi temsil etsin diye burada da sabit tutuyoruz.
/// İleride login/çoklu kullanıcı geldiğinde burası dinamik yapılacak.
const String kPersonelIdForSettings = 'p1';

DocumentReference<Map<String, dynamic>> _settingsRef(String personelId) =>
    FirebaseFirestore.instance.collection('settings').doc(personelId);

class AppSettings {
  final String personelId;
  final String role; // "Acil Hekim", "Acil Hemşire", "Güvenlik", "112", "İdari"
  final List<String> allowedCodes; // ["mavi","beyaz","kırmızı","pembe","turuncu","sarı","112"]
  final bool notifPush;
  final bool notifLocal;
  final bool dndBypassForCritical;
  final int repeatSeconds;
  final double radiusKm112;
  final int ttlMinutes112;
  final bool requirePinFor112;
  final String pinCode;
  final bool highAccuracyLocation;
  final int locationPollSec;
  final int logLimit;
  final String language; // "tr","en"
  final bool largeText;
  final bool highContrast;

  /// ⬇️ Kodların görünen adları (ör. {"mavi":"Mavi Kod"})
  final Map<String, String> codeNames;

  AppSettings({
    required this.personelId,
    required this.role,
    required this.allowedCodes,
    required this.notifPush,
    required this.notifLocal,
    required this.dndBypassForCritical,
    required this.repeatSeconds,
    required this.radiusKm112,
    required this.ttlMinutes112,
    required this.requirePinFor112,
    required this.pinCode,
    required this.highAccuracyLocation,
    required this.locationPollSec,
    required this.logLimit,
    required this.language,
    required this.largeText,
    required this.highContrast,
    required this.codeNames,
  });

  factory AppSettings.defaults(String personelId) => AppSettings(
        personelId: personelId,
        role: 'Acil Hekim',
        allowedCodes: [
          'mavi',
          'beyaz',
          'kırmızı',
          '112',
          'pembe',
          'turuncu',
          'sarı',
        ],
        notifPush: true,
        notifLocal: true,
        dndBypassForCritical: true,
        repeatSeconds: 0,
        radiusKm112: 1.0,
        ttlMinutes112: 10,
        requirePinFor112: false,
        pinCode: '',
        highAccuracyLocation: true,
        locationPollSec: 60,
        logLimit: 50,
        language: 'tr',
        largeText: false,
        highContrast: false,
        codeNames: const {
          'mavi': 'Mavi Kod',
          'beyaz': 'Beyaz Kod',
          'kırmızı': 'Kırmızı Kod',
          'pembe': 'Pembe Kod',
          'turuncu': 'Turuncu Kod',
          'sarı': 'Sarı Kod',
          '112': '112 Yayını',
        },
      );

  Map<String, dynamic> toMap() => {
        'personelId': personelId,
        'role': role,
        'allowedCodes': allowedCodes,
        'notifPush': notifPush,
        'notifLocal': notifLocal,
        'dndBypassForCritical': dndBypassForCritical,
        'repeatSeconds': repeatSeconds,
        'radiusKm112': radiusKm112,
        'ttlMinutes112': ttlMinutes112,
        'requirePinFor112': requirePinFor112,
        'pinCode': pinCode,
        'highAccuracyLocation': highAccuracyLocation,
        'locationPollSec': locationPollSec,
        'logLimit': logLimit,
        'language': language,
        'largeText': largeText,
        'highContrast': highContrast,
        'codeNames': codeNames,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static AppSettings fromMap(String personelId, Map<String, dynamic> m) {
    final defaults = AppSettings.defaults(personelId);

    // codeNames güvenli okuma + merge
    final rawNames = m['codeNames'];
    final mapNames =
        rawNames is Map ? Map<String, dynamic>.from(rawNames) : <String, dynamic>{};

    final parsedNames = <String, String>{};
    for (final e in mapNames.entries) {
      final k = e.key.toString();
      final v = e.value?.toString() ?? '';
      if (k.isNotEmpty && v.isNotEmpty) {
        parsedNames[k] = v;
      }
    }
    final mergedNames = {...defaults.codeNames, ...parsedNames};

    return AppSettings(
      personelId: personelId,
      role: (m['role'] as String?) ?? defaults.role,
      allowedCodes: List<String>.from(
        m['allowedCodes'] ??
            [
              'mavi',
              'beyaz',
              'kırmızı',
              '112',
              'pembe',
              'turuncu',
              'sarı',
            ],
      ),
      notifPush: (m['notifPush'] as bool?) ?? defaults.notifPush,
      notifLocal: (m['notifLocal'] as bool?) ?? defaults.notifLocal,
      dndBypassForCritical:
          (m['dndBypassForCritical'] as bool?) ?? defaults.dndBypassForCritical,
      repeatSeconds: (m['repeatSeconds'] as num?)?.toInt() ?? defaults.repeatSeconds,
      radiusKm112: (m['radiusKm112'] as num?)?.toDouble() ?? defaults.radiusKm112,
      ttlMinutes112: (m['ttlMinutes112'] as num?)?.toInt() ?? defaults.ttlMinutes112,
      requirePinFor112:
          (m['requirePinFor112'] as bool?) ?? defaults.requirePinFor112,
      pinCode: (m['pinCode'] as String?) ?? defaults.pinCode,
      highAccuracyLocation:
          (m['highAccuracyLocation'] as bool?) ?? defaults.highAccuracyLocation,
      locationPollSec:
          (m['locationPollSec'] as num?)?.toInt() ?? defaults.locationPollSec,
      logLimit: (m['logLimit'] as num?)?.toInt() ?? defaults.logLimit,
      language: (m['language'] as String?) ?? defaults.language,
      largeText: (m['largeText'] as bool?) ?? defaults.largeText,
      highContrast: (m['highContrast'] as bool?) ?? defaults.highContrast,
      codeNames: mergedNames,
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings? _settings;
  final _pinController = TextEditingController();
  Timer? _debounce;

  Future<void> _saveDebounced() async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final s = _settings;
      if (s == null) return;
      await _settingsRef(s.personelId).set(s.toMap(), SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar kaydedildi')),
      );
    });
  }

  Future<void> _ensureDocExists() async {
    final snap = await _settingsRef(kPersonelIdForSettings).get();
    if (!snap.exists) {
      final def = AppSettings.defaults(kPersonelIdForSettings);
      await _settingsRef(kPersonelIdForSettings).set(def.toMap());
    }
  }

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() {
      final s = _settings;
      if (s == null) return;
      _settings = AppSettings(
        personelId: s.personelId,
        role: s.role,
        allowedCodes: s.allowedCodes,
        notifPush: s.notifPush,
        notifLocal: s.notifLocal,
        dndBypassForCritical: s.dndBypassForCritical,
        repeatSeconds: s.repeatSeconds,
        radiusKm112: s.radiusKm112,
        ttlMinutes112: s.ttlMinutes112,
        requirePinFor112: s.requirePinFor112,
        pinCode: _pinController.text,
        highAccuracyLocation: s.highAccuracyLocation,
        locationPollSec: s.locationPollSec,
        logLimit: s.logLimit,
        language: s.language,
        largeText: s.largeText,
        highContrast: s.highContrast,
        codeNames: s.codeNames,
      );
      _saveDebounced();
    });
    _ensureDocExists();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _update(void Function() change) {
    setState(change);
    _saveDebounced();
  }

  List<String> _knownCodes(AppSettings s) {
    final base = [
      'mavi',
      'beyaz',
      'kırmızı',
      'pembe',
      'turuncu',
      'sarı',
      '112',
    ];
    final set = {...base, ...s.allowedCodes};
    return set.toList()..sort();
  }

  Future<void> _showCodesInfo(BuildContext context) async {
    final s = _settings ?? AppSettings.defaults(kPersonelIdForSettings);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.7;
        final textTheme = Theme.of(ctx).textTheme;

        return SafeArea(
          child: SizedBox(
            height: h,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kodlar ne işe yarar?',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _infoRow(
                    ctx,
                    'mavi',
                    s.codeNames['mavi'] ?? 'Mavi Kod',
                    'Hayati tehlike/kalp-solunum acili ve tüm ekibin hızlı yönlendirilmesi.',
                  ),
                  _infoRow(
                    ctx,
                    'beyaz',
                    s.codeNames['beyaz'] ?? 'Beyaz Kod',
                    'Sözlü/fiziksel şiddet, güvenlik ve idari sürecin tetiklenmesi.',
                  ),
                  _infoRow(
                    ctx,
                    'kırmızı',
                    s.codeNames['kırmızı'] ?? 'Kırmızı Kod',
                    'Yangın/afet ve tahliye, ilgili ekiplerin harekete geçmesi.',
                  ),
                  _infoRow(
                    ctx,
                    'pembe',
                    s.codeNames['pembe'] ?? 'Pembe Kod',
                    'Bebek/çocuk kaçırma şüphesi, güvenlik kilitlenmesi.',
                  ),
                  _infoRow(
                    ctx,
                    'turuncu',
                    s.codeNames['turuncu'] ?? 'Turuncu Kod',
                    'Tehlikeli madde/sızıntı, alan izolasyonu ve müdahale.',
                  ),
                  _infoRow(
                    ctx,
                    'sarı',
                    s.codeNames['sarı'] ?? 'Sarı Kod',
                    'Kayıp/hasta kaybolması ve arama süreci.',
                  ),
                  _infoRow(
                    ctx,
                    '112',
                    s.codeNames['112'] ?? '112 Yayını',
                    'Yakın çevrede görevli personele konum bazlı acil bildirim.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tamam'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(
    BuildContext context,
    String key,
    String title,
    String desc,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            ),
            child: Text(
              key.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final s = _settings ?? AppSettings.defaults(kPersonelIdForSettings);
    final codes = _knownCodes(s);
    String currentKey = codes.first;
    final controller =
        TextEditingController(text: s.codeNames[currentKey] ?? currentKey);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Kodu yeniden adlandır'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: currentKey,
                  decoration: const InputDecoration(
                    labelText: 'Kod seç',
                    border: OutlineInputBorder(),
                  ),
                  items: codes
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setStateDialog(() {
                      currentKey = v;
                      controller.text = s.codeNames[v] ?? v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Yeni görünen ad',
                    hintText: 'Örn: Acil Müdahale',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 30,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final s0 = _settings ?? AppSettings.defaults(kPersonelIdForSettings);
      final newMap = {
        ...s0.codeNames,
        currentKey: controller.text.trim(),
      };
      _update(() {
        _settings = AppSettings(
          personelId: s0.personelId,
          role: s0.role,
          allowedCodes: s0.allowedCodes,
          notifPush: s0.notifPush,
          notifLocal: s0.notifLocal,
          dndBypassForCritical: s0.dndBypassForCritical,
          repeatSeconds: s0.repeatSeconds,
          radiusKm112: s0.radiusKm112,
          ttlMinutes112: s0.ttlMinutes112,
          requirePinFor112: s0.requirePinFor112,
          pinCode: s0.pinCode,
          highAccuracyLocation: s0.highAccuracyLocation,
          locationPollSec: s0.locationPollSec,
          logLimit: s0.logLimit,
          language: s0.language,
          largeText: s0.largeText,
          highContrast: s0.highContrast,
          codeNames: newMap,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _settingsRef(kPersonelIdForSettings).snapshots(),
      builder: (context, snap) {
        if (snap.hasData) {
          final data = snap.data!.data();
          if (data != null) {
            _settings ??= AppSettings.fromMap(kPersonelIdForSettings, data);
          }
          if (_settings != null &&
              _pinController.text != _settings!.pinCode) {
            _pinController.text = _settings!.pinCode;
          }
        }
        final s = _settings ?? AppSettings.defaults(kPersonelIdForSettings);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ayarlar'),
            actions: [
              IconButton(
                tooltip: 'İzinleri Yenile (bildirim)',
                onPressed: () {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Bildirim izni uygulama açılışında yeniden istenir.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_active_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: '1) Profil & Rol',
                child: Column(
                  children: [
                    _ReadOnlyTile(label: 'Personel ID', value: s.personelId),
                    const SizedBox(height: 8),
                    _Dropdown<String>(
                      label: 'Birim/Rol',
                      value: s.role,
                      items: const [
                        'Acil Hekim',
                        'Acil Hemşire',
                        'Güvenlik',
                        '112',
                        'İdari',
                      ],
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'role': v},
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    _ChipsMultiSelect(
                      label: 'Kod Gönderme Yetkisi',
                      all: const [
                        'mavi',
                        'beyaz',
                        'kırmızı',
                        'pembe',
                        'turuncu',
                        'sarı',
                        '112',
                      ],
                      selected: s.allowedCodes,
                      onChanged: (list) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'allowedCodes': list},
                        );
                      }),
                    ),
                  ],
                ),
              ),
              _Section(
                title: '2) Bildirimler',
                child: Column(
                  children: [
                    _SwitchTile(
                      label: 'Push Bildirimleri',
                      value: s.notifPush,
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'notifPush': v},
                        );
                      }),
                    ),
                    _SwitchTile(
                      label: 'Yerel Bildirim (cihaz içi)',
                      value: s.notifLocal,
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'notifLocal': v},
                        );
                      }),
                    ),
                    _SwitchTile(
                      label: 'Mavi/Kırmızı DND’yi aşsın',
                      value: s.dndBypassForCritical,
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'dndBypassForCritical': v},
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    _Dropdown<int>(
                      label: 'Tekrarlı uyarı (sn)',
                      value: s.repeatSeconds,
                      items: const [0, 30, 60, 120],
                      toText: (v) => v == 0 ? 'Kapalı' : '$v sn',
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'repeatSeconds': v},
                        );
                      }),
                    ),
                  ],
                ),
              ),
              _Section(
                title: '3) 112 (Yakın Çevre)',
                child: Column(
                  children: [
                    _SliderTile(
                      label:
                          'Yarıçap (km): ${s.radiusKm112.toStringAsFixed(1)}',
                      value: s.radiusKm112,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'radiusKm112': v},
                        );
                      }),
                    ),
                    _Dropdown<int>(
                      label: 'Geçerlilik (dk)',
                      value: s.ttlMinutes112,
                      items: const [5, 10, 15],
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'ttlMinutes112': v},
                        );
                      }),
                    ),
                    _SwitchTile(
                      label: '112 Yayını için PIN iste',
                      value: s.requirePinFor112,
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'requirePinFor112': v},
                        );
                      }),
                    ),
                    if (s.requirePinFor112)
                      TextField(
                        controller: _pinController,
                        decoration: const InputDecoration(
                          labelText: 'PIN Kodu',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                      ),
                  ],
                ),
              ),
              _Section(
                title: '4) Gelişmiş',
                child: Column(
                  children: [
                    _SwitchTile(
                      label: 'Konum doğruluğu (Yüksek)',
                      value: s.highAccuracyLocation,
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'highAccuracyLocation': v},
                        );
                      }),
                    ),
                    _Dropdown<int>(
                      label: 'Konum kontrol sıklığı',
                      value: s.locationPollSec,
                      items: const [30, 60, 120],
                      toText: (v) => '$v sn',
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'locationPollSec': v},
                        );
                      }),
                    ),
                    _Dropdown<int>(
                      label: 'Bildirim günlüğü limiti',
                      value: s.logLimit,
                      items: const [50, 100, 200],
                      onChanged: (v) => _update(() {
                        _settings = AppSettings.fromMap(
                          s.personelId,
                          {...s.toMap(), 'logLimit': v},
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Not: Bildirim izinleri ve DND aşma davranışı platform ayarlarına bağlıdır.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Section(
                title: '5) Yardım & Özelleştirme',
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showCodesInfo(context),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Kodlar ne işe yarar?'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _showRenameDialog(context),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Kodları yeniden adlandır'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final def = AppSettings.defaults(s.personelId);
                  await _settingsRef(s.personelId).set(def.toMap());
                },
                icon: const Icon(Icons.restore),
                label: const Text('Varsayılanlara dön'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => CsvImporter.pickAndImport(context),
                icon: const Icon(Icons.file_upload),
                label: const Text('Excel/CSV içe aktar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyTile extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value),
      enabled: false,
      decoration: const InputDecoration(
        labelText: 'Personel ID',
        border: OutlineInputBorder(),
      ).copyWith(labelText: label),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T)? toText;
  final ValueChanged<T> onChanged;
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.toText,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration:
          const InputDecoration(labelText: '', border: OutlineInputBorder())
              .copyWith(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(toText != null ? toText!(e) : e.toString()),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ChipsMultiSelect extends StatelessWidget {
  final String label;
  final List<String> all;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const _ChipsMultiSelect({
    super.key,
    required this.label,
    required this.all,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sel = Set<String>.from(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: all.map((k) {
            final active = sel.contains(k);
            return FilterChip(
              label: Text(k.toUpperCase()),
              selected: active,
              onSelected: (v) {
                final n = Set<String>.from(sel);
                if (v) {
                  n.add(k);
                } else {
                  n.remove(k);
                }
                onChanged(n.toList()..sort());
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  const _SliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
