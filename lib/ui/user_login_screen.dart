import 'package:flutter/material.dart';

import '../app.dart';
import '../telegram/td_client.dart';
import '../telegram/user_session.dart';
import 'widgets.dart';

/// Optional login with the owner's own account, used only to delete old posts the
/// bot is refused.
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _field = TextEditingController();
  var _busy = false;
  String? _error;
  String? _result;

  UserSession get _s => app.userSession;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() step) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await step();
      _field.clear();
    } on TdError catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Gets this device its own session by having a logged-in device approve a login link.
  Future<void> _qr(String peerId) => _run(() async {
        _s.td.qrLink.value = null;
        await _s.beginQr();
        for (var i = 0; i < 20 && _s.td.qrLink.value == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        final link = _s.td.qrLink.value;
        if (link == null) throw TdError(0, 'Telegram gave no login link. Try again.');
        app.link.sendQr(peerId, link);
        _result = 'Asked the other device. Allow it there.';
      });

  Future<void> _deleteOld() => _run(() async {
        var n = await app.mover.retryRefused();
        n += await app.filer.mover.retryRefused();
        _result = n == 0 ? 'Nothing was waiting to be deleted' : 'Deleted $n old posts';
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your account (optional)')),
        body: ListenableBuilder(
          listenable: Listenable.merge([_s.loggedIn, _s.td.auth]),
          builder: (context, _) {
            final state = _s.td.auth.value;
            if (_s.loggedIn.value || state == 'authorizationStateReady') {
              if (!_s.loggedIn.value) Future.microtask(_s.finished);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text("Logged in. Your account is only used to delete old posts the bot can't, after they've been copied to their topic."),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _deleteOld, child: const Text('Delete refused posts now')),
                  if (_result != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_result!)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _busy ? null : () => _run(_s.logOut), child: const Text('Log out')),
                  if (app.link.devices.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  final ok = await confirm(
                                    context,
                                    'Log out on all devices?',
                                    'Your account is logged out here and on every connected device. Old posts then can\'t be deleted until you log in again.',
                                    'Log out everywhere',
                                  );
                                  if (!ok) return;
                                  app.link.sendLogoutAll();
                                  await _s.logOut();
                                }),
                        child: const Text('Log out on all devices'),
                      ),
                    ),
                ],
              );
            }
            final (label, hint, Future<void> Function(String) send) = switch (state) {
              'authorizationStateWaitCode' => ('Code', 'The code Telegram just sent you', _s.code),
              'authorizationStateWaitPassword' => ('Password', 'Your two-step verification password', _s.password),
              _ => ('Phone number', 'With country code, like +91…', _s.phone),
            };
            final started = _s.td.started && state.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const InfoText("Telegram won't let bots delete posts older than 48 hours. With your account logged in, the app deletes those after copying them to their topic. It doesn't read or post anything, and the session stays on this device. Telegram could still limit an account used from an unofficial app. Usage here is kept low, but that can't be ruled out."),
                const SizedBox(height: 16),
                if (!started) ...[
                  FilledButton(
                    onPressed: _busy ? null : () => _run(_s.begin),
                    child: const Text('Start login'),
                  ),
                  ListenableBuilder(
                    listenable: app.link.accounts,
                    builder: (context, _) => Column(
                      children: [
                        for (final d in app.link.devices.value)
                          if (app.link.accounts.value[d.id] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                onPressed: _busy ? null : () => _qr(d.id),
                                child: Text('Sign in using ${d.name}'),
                              ),
                            ),
                      ],
                    ),
                  ),
                ]
                else ...[
                  TextField(
                    controller: _field,
                    obscureText: state == 'authorizationStateWaitPassword',
                    decoration: InputDecoration(labelText: label, helperText: hint),
                    onSubmitted: (v) => _run(() => send(v.trim())),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(() => send(_field.text.trim())),
                    child: const Text('Continue'),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            );
          },
        ),
      );
}
