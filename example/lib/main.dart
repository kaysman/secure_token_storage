import 'package:flutter/material.dart';
import 'package:secure_token_storage/secure_token_storage.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureTokenStorage example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = const SecureTokenStorage();
  TokenBundle? _bundle;
  String _status = 'No tokens loaded.';

  Future<void> _fakeLogin() async {
    final now = DateTime.now().toUtc();
    final bundle = TokenBundle(
      accessToken: 'fake-access-${now.millisecondsSinceEpoch}',
      refreshToken: 'fake-refresh-${now.millisecondsSinceEpoch}',
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshExpiresAt: now.add(const Duration(days: 30)),
    );
    await _storage.save(bundle);
    await _refresh();
  }

  Future<void> _refresh() async {
    final bundle = await _storage.read();
    setState(() {
      _bundle = bundle;
      _status = bundle == null ? 'No tokens stored.' : 'Tokens loaded.';
    });
  }

  Future<void> _logout() async {
    await _storage.clear();
    await _refresh();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      appBar: AppBar(title: const Text('Secure token storage')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (bundle != null) ...[
              Text('access:  ${bundle.accessToken}'),
              Text('refresh: ${bundle.refreshToken}'),
              Text('access expires:  ${bundle.accessExpiresAt}'),
              Text('refresh expires: ${bundle.refreshExpiresAt}'),
              const SizedBox(height: 8),
              Text(
                bundle.isAccessExpired()
                    ? 'Access token is EXPIRED — refresh needed.'
                    : 'Access token is still valid.',
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _fakeLogin,
              child: const Text('Simulate login'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _refresh,
              child: const Text('Re-read'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _logout,
              child: const Text('Logout (clear)'),
            ),
          ],
        ),
      ),
    );
  }
}
