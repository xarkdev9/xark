import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';

// Mock Riverpod state for the user's name and photo link
class ProfileState {
  final String name;
  final String? photoUrl;
  
  const ProfileState({required this.name, this.photoUrl});
  
  ProfileState copyWith({String? name, String? photoUrl}) {
    return ProfileState(
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    return const ProfileState(name: "Ram Chitturi", photoUrl: null);
  }
  
  void updateName(String newName) {
    state = state.copyWith(name: newName);
  }

  void simulatePhotoPicker() async {
    HapticFeedback.selectionClick();
    // Simulate a native photo picker delay
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(photoUrl: "simulated_local_path.jpg");
    HapticFeedback.lightImpact();
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Initialize controller with current state
    final currentName = ref.read(profileProvider).name;
    _nameController = TextEditingController(text: currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

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
            
            const Spacer(),
            
            // The Avatar Interaction: 120x120 circular avatar centered at the top
            GestureDetector(
              onTap: () {
                ref.read(profileProvider.notifier).simulatePhotoPicker();
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HelloColors.inkSecondary.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: profile.photoUrl != null
                      ? const Icon(Icons.check, size: 48, color: HelloColors.accent)
                      : const Icon(Icons.add_a_photo_outlined, size: 48, color: HelloColors.inkSecondary),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // The Name Input: Borderless collapsed TextField, massive text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                onChanged: (val) {
                  ref.read(profileProvider.notifier).updateName(val);
                },
                decoration: InputDecoration.collapsed(
                  hintText: "Your Name",
                  hintStyle: HelloTypography.hero.copyWith(
                    color: HelloColors.inkTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                style: HelloTypography.hero.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
