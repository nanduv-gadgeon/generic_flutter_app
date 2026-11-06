import 'package:flutter/material.dart';

import '../strings/add_device_strings.dart';
import 'add_device_parts.dart';

/// Phase 2: the key the cloud gave the device, masked (screen 12). Null [deviceKey] means the
/// cloud has not sent it yet.
class DeviceKeyCard extends StatelessWidget {
  const DeviceKeyCard({super.key, required this.deviceKey});

  final String? deviceKey;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final key = deviceKey;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.key_outlined, size: 18, color: tokens?.accent)),
              const SizedBox(width: 10),
              Semantics(
                header: true,
                child: const Text(
                  AddDeviceStrings.deviceKey,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens?.chipBg,
              borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
            ),
            child: Text(
              key == null ? AddDeviceStrings.waitingForCloud : AddDeviceStrings.maskedKey(key),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontFamily: key == null ? null : 'monospace',
                fontFamilyFallback: const ['Menlo', 'Roboto Mono'],
                color: key == null ? tokens?.muted : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AddDeviceStrings.deviceKeyNote,
            style: TextStyle(fontSize: 12, height: 1.4, color: tokens?.muted),
          ),
        ],
      ),
    );
  }
}
