import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/form_widgets.dart';
import 'dashboard_format.dart';

/// Where the device page's back buttons go: My devices.
const _home = '/home';

/// The device page while its device or device type is still loading, e.g. the moment after Add
/// device saved it and before My devices has caught up. Never shows placeholder text.
class DeviceLoading extends StatelessWidget {
  const DeviceLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: context.l10n.commonLoading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// The device page for a device that is not one of the user's (removed, another user's, a bad
/// link) or whose type is no longer in the config.
class DeviceNotFound extends StatelessWidget {
  const DeviceNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CircleBackButton(onPressed: () => context.go(_home)),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: tokens.soft, shape: BoxShape.circle),
                  child: Icon(Icons.search_off, size: 30, color: tokens.accent),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.deviceNotFoundTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.deviceNotFoundBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: tokens.muted),
              ),
              const Spacer(),
              PrimaryButton(label: l10n.deviceNotFoundBack, onPressed: () => context.go(_home)),
            ],
          ),
        ),
      ),
    );
  }
}
