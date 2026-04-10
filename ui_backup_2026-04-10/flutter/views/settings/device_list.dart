import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';

// Mock Device Data Model
class DeviceMetadata {
  final String id;
  final String name;
  final String lastSeen;

  const DeviceMetadata({
    required this.id,
    required this.name,
    required this.lastSeen,
  });
}

// Mock Riverpod State
class DeviceNotifier extends Notifier<List<DeviceMetadata>> {
  @override
  List<DeviceMetadata> build() {
    return const [
      DeviceMetadata(id: 'dev_1', name: 'iPhone 15 Pro', lastSeen: 'Active now'),
      DeviceMetadata(id: 'dev_2', name: 'MacBook Air', lastSeen: 'Last seen 2 hours ago'),
      DeviceMetadata(id: 'dev_3', name: 'Sesame Web', lastSeen: 'Last seen yesterday'),
    ];
  }

  void revokeDevice(String id) {
    HapticFeedback.heavyImpact();
    state = state.where((device) => device.id != id).toList();
  }
}

final devicesProvider = NotifierProvider<DeviceNotifier, List<DeviceMetadata>>(() {
  return DeviceNotifier();
});

class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: HelloColors.inkPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Linked Devices",
                  style: HelloTypography.hero,
                ),
              ),
            ),
            
            const SizedBox(height: 24.0),
            
            Expanded(
              child: ListView.separated(
                itemCount: devices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  
                  // Wrap in Dismissible with a strictly colored void background 
                  // revealing the "Revoke" text in the Rose tint. No boxes.
                  return Dismissible(
                    key: Key(device.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      ref.read(devicesProvider.notifier).revokeDevice(device.id);
                    },
                    background: Container(
                      color: HelloColors.voidBg,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        "Revoke",
                        style: HelloTypography.spaceTitle.copyWith(
                          color: const Color(0xFFD4536B), // Rose tint
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: HelloTypography.spaceTitle.copyWith(
                              color: HelloColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            device.lastSeen,
                            style: HelloTypography.hint.copyWith(
                              color: device.lastSeen == 'Active now' 
                                  ? HelloColors.successGreen 
                                  : HelloColors.inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
