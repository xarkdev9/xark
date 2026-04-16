import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../../main.dart';
import '../../../theme.dart';

// --- State Machine ---
enum AuthStep { phoneEntry, otpEntry, tasteEntry, verifying }

class AuthState {
  final AuthStep step;
  final String phoneNumber;
  final String otpCode;
  final String? error;
  final String? verificationId;

  AuthState({
    required this.step,
    this.phoneNumber = '',
    this.otpCode = '',
    this.error,
    this.verificationId,
  });

  AuthState copyWith({
    AuthStep? step,
    String? phoneNumber,
    String? otpCode,
    String? error,
    String? verificationId,
  }) {
    return AuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otpCode: otpCode ?? this.otpCode,
      error: error,
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

class AuthFlowNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState(step: AuthStep.phoneEntry);

  void submitPhone(String phone) {
    if (phone.trim().isEmpty) return;
    state = state.copyWith(step: AuthStep.otpEntry, phoneNumber: phone);
  }

  void setVerificationId(String id) {
    state = state.copyWith(verificationId: id);
  }

  void setError(String message) {
    state = state.copyWith(error: message);
  }

  void updateOtp(String code) {
    if (state.step != AuthStep.otpEntry) return;

    if (code.length == 6 && state.otpCode.length != 6) {
      state = state.copyWith(otpCode: code, step: AuthStep.tasteEntry);
    } else {
      state = state.copyWith(otpCode: code);
    }
  }

  void completeTaste() {
    state = state.copyWith(step: AuthStep.verifying);
  }

  void reset() {
    state = AuthState(step: AuthStep.phoneEntry);
  }
}

final authFlowProvider = NotifierProvider<AuthFlowNotifier, AuthState>(() {
  return AuthFlowNotifier();
});

class AuthFlowPage extends ConsumerStatefulWidget {
  const AuthFlowPage({super.key});

  @override
  ConsumerState<AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends ConsumerState<AuthFlowPage> {
  int _currentPhase = 0; // 0: Spark/Phone, 1: OTP, 2: Taste Onboarding
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _tasteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start listening to the state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(authFlowProvider, (previous, next) {
        if (next.step == AuthStep.phoneEntry && _currentPhase != 0) {
          setState(() => _currentPhase = 0);
        } else if (next.step == AuthStep.otpEntry && _currentPhase != 1) {
          setState(() => _currentPhase = 1);
        } else if (next.step == AuthStep.tasteEntry && _currentPhase != 2) {
          setState(() => _currentPhase = 2);
        } else if (next.step == AuthStep.verifying && _currentPhase != 3) {
          setState(() => _currentPhase = 3);
        }
      });
    });
  }

  void _nextPhase() {
    final authState = ref.read(authFlowProvider);
    if (_currentPhase == 0) {
      ref.read(authFlowProvider.notifier).submitPhone(_phoneController.text);
      _startFirebasePhoneAuth(_phoneController.text);
    } else if (_currentPhase == 1) {
      ref.read(authFlowProvider.notifier).updateOtp(_otpController.text);
    } else if (_currentPhase == 2) {
      ref.read(authFlowProvider.notifier).completeTaste();
      _verifyOtpAndLogin();
    }
  }

  Future<void> _startFirebasePhoneAuth(String phone) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ref.read(authFlowProvider.notifier).setError(e.message ?? 'Phone verification failed');
          ref.read(authFlowProvider.notifier).reset();
        },
        codeSent: (String verificationId, int? resendToken) {
          ref.read(authFlowProvider.notifier).setVerificationId(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          ref.read(authFlowProvider.notifier).setVerificationId(verificationId);
        },
      );
    } catch (e) {
      ref.read(authFlowProvider.notifier).setError('Failed to send OTP: $e');
      ref.read(authFlowProvider.notifier).reset();
    }
  }

  Future<void> _verifyOtpAndLogin() async {
    final authState = ref.read(authFlowProvider);
    final verificationId = authState.verificationId;
    final code = authState.otpCode;

    if (verificationId == null) {
      ref.read(authFlowProvider.notifier).setError('Verification not started');
      ref.read(authFlowProvider.notifier).reset();
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      ref.read(authFlowProvider.notifier).setError('Verification failed: $e');
      ref.read(authFlowProvider.notifier).reset();
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await userCredential.user?.getIdToken();

      if (firebaseIdToken == null) {
        ref.read(authFlowProvider.notifier).setError('Failed to get ID token');
        ref.read(authFlowProvider.notifier).reset();
        return;
      }

      final authService = AuthService(Uri.parse(serverUrl));
      final result = await authService.authenticateWithFirebase(
        firebaseIdToken: firebaseIdToken,
      );

      if (!mounted) return;

      await initializeEngine(
        ref: ref,
        authToken: result.accessToken,
        userId: result.userId,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      ref.read(authFlowProvider.notifier).setError(e.message ?? 'Authentication failed');
      ref.read(authFlowProvider.notifier).reset();
    } on AuthException catch (e) {
      ref.read(authFlowProvider.notifier).setError(e.message);
      ref.read(authFlowProvider.notifier).reset();
    } catch (e) {
      ref.read(authFlowProvider.notifier).setError('Auth failed: $e');
      ref.read(authFlowProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'hello',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1,
                  color: HelloColors.accent,
                ),
              ),
              const SizedBox(height: 64),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOutExpo,
                switchOutCurve: Curves.easeInExpo,
                child: _buildCurrentPhase(),
              ),
              if (ref.watch(authFlowProvider).error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    ref.watch(authFlowProvider).error!,
                    style: const TextStyle(
                      color: HelloColors.accent,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    switch (_currentPhase) {
      case 0:
        return _buildPhoneEntry(key: const ValueKey(0));
      case 1:
        return _buildOtpEntry(key: const ValueKey(1));
      case 2:
        return _buildTasteEntry(key: const ValueKey(2));
      case 3:
        return Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: HelloColors.inkPrimary,
              strokeWidth: 2,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhoneEntry({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter your phone number.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 24, color: Colors.white, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: '+1 (000) 000-0000',
            hintStyle: TextStyle(color: Colors.white.withAlpha(50)),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _nextPhase(),
        ),
      ],
    );
  }

  Widget _buildOtpEntry({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Check your messages.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Code sent to ${_phoneController.text}',
          style: TextStyle(
            color: HelloColors.inkSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          obscuringCharacter: '●',
          style: const TextStyle(fontSize: 32, letterSpacing: 8, color: Colors.white),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
          ),
          onChanged: (val) {
            if (val.length == 6) {
              ref.read(authFlowProvider.notifier).updateOtp(val);
              _nextPhase();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTasteEntry({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What is your taste?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Describe how you travel, eat, and plan. We will generate your constraint baseline.',
          style: TextStyle(
            color: HelloColors.inkSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _tasteController,
          maxLines: 4,
          style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
          decoration: InputDecoration(
            hintText: 'e.g. I only stay in boutique hotels. I refuse to fly before 9am. I love cheap street food.',
            hintStyle: TextStyle(color: Colors.white.withAlpha(50)),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _nextPhase(),
        ),
      ],
    );
  }
}
