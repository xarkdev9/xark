import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e2ee_chat_sdk/e2ee_chat.dart';
import '../../main.dart';
import '../../theme.dart';

// --- State Machine ---
enum AuthStep { phoneEntry, otpEntry, verifying }

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
      state = state.copyWith(otpCode: code, step: AuthStep.verifying);
    } else {
      state = state.copyWith(otpCode: code);
    }
  }

  void reset() {
    state = AuthState(step: AuthStep.phoneEntry);
  }
}

final authFlowProvider = NotifierProvider<AuthFlowNotifier, AuthState>(() {
  return AuthFlowNotifier();
});

// --- Page Widget ---
class AuthFlowPage extends ConsumerStatefulWidget {
  AuthFlowPage({super.key});

  @override
  ConsumerState<AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends ConsumerState<AuthFlowPage> {
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onPhoneSubmitted(String phone) {
    ref.read(authFlowProvider.notifier).submitPhone(phone);
    Future.microtask(() => _otpFocusNode.requestFocus());
    _startFirebasePhoneAuth(phone);
  }

  Future<void> _startFirebasePhoneAuth(String phone) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only) — sign in immediately
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ref.read(authFlowProvider.notifier).setError(
            e.message ?? 'Phone verification failed',
          );
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
    }
  }

  void _onOtpChanged(String code, BuildContext context) {
    final oldCode = ref.read(authFlowProvider).otpCode;
    if (oldCode.length != code.length) {
      HapticFeedback.lightImpact();
    }

    ref.read(authFlowProvider.notifier).updateOtp(code);

    if (code.length == 6 && oldCode.length != 6) {
      HapticFeedback.heavyImpact();
      _verifyOtp(code, context);
    }
  }

  Future<void> _verifyOtp(String code, BuildContext context) async {
    final authState = ref.read(authFlowProvider);
    final verificationId = authState.verificationId;

    if (verificationId == null) {
      ref.read(authFlowProvider.notifier).setError('Verification not started');
      return;
    }

    FocusScope.of(context).unfocus();

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await userCredential.user?.getIdToken();

      if (firebaseIdToken == null) {
        ref.read(authFlowProvider.notifier).setError('Failed to get ID token');
        return;
      }

      // Exchange Firebase token for Supabase JWT via engine AuthService
      final authService = AuthService(Uri.parse(serverUrl));
      final result = await authService.authenticateWithFirebase(
        firebaseIdToken: firebaseIdToken,
      );

      if (!mounted) return;

      // Boot the engine with the real auth token
      await initializeEngine(
        ref: ref,
        authToken: result.accessToken,
        userId: result.userId,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      ref.read(authFlowProvider.notifier).setError(
        e.message ?? 'Authentication failed',
      );
    } on AuthException catch (e) {
      ref.read(authFlowProvider.notifier).setError(e.message);
    } catch (e) {
      ref.read(authFlowProvider.notifier).setError('Auth failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowProvider);

    return Scaffold(
      backgroundColor: HelloColors.voidBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 400),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    final children = <Widget>[...previousChildren];
                    if (currentChild != null) {
                      children.add(currentChild);
                    }
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: children,
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, childWidget) {
                          final blurValue = (1 - animation.value) * 10;
                          return ImageFilterWidget(
                            blur: blurValue,
                            child: childWidget!,
                          );
                        },
                        child: child,
                      ),
                    );
                  },
                  child: _buildStepContent(authState, context),
                ),
              ),
              if (authState.error != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 32.0),
                  child: Text(
                    authState.error!,
                    style: HelloTypography.body.copyWith(
                      color: HelloColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(AuthState state, BuildContext context) {
    switch (state.step) {
      case AuthStep.phoneEntry:
        return _PhoneEntryView(
          key: ValueKey('phone'),
          focusNode: _phoneFocusNode,
          onSubmitted: _onPhoneSubmitted,
        );
      case AuthStep.otpEntry:
        return _OtpEntryView(
          key: ValueKey('otp'),
          focusNode: _otpFocusNode,
          otpCode: state.otpCode,
          onChanged: (val) => _onOtpChanged(val, context),
        );
      case AuthStep.verifying:
        return _VerifyingView(
          key: ValueKey('verifying'),
        );
    }
  }
}

class ImageFilterWidget extends StatelessWidget {
  final double blur;
  final Widget child;

  ImageFilterWidget({
    super.key,
    required this.blur,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (blur <= 0) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}

// --- Phone Entry View ---
class _PhoneEntryView extends StatelessWidget {
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  _PhoneEntryView({
    super.key,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "What is your number?",
          style: HelloText.display,
        ),
        SizedBox(height: 16),
        TextField(
          focusNode: focusNode,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.send,
          style: HelloText.display,
          cursorColor: HelloColors.accent,
          decoration: InputDecoration.collapsed(
            hintText: "",
            border: InputBorder.none,
          ),
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}

// --- OTP Entry View ---
class _OtpEntryView extends StatefulWidget {
  final FocusNode focusNode;
  final String otpCode;
  final ValueChanged<String> onChanged;

  _OtpEntryView({
    super.key,
    required this.focusNode,
    required this.otpCode,
    required this.onChanged,
  });

  @override
  State<_OtpEntryView> createState() => _OtpEntryViewState();
}

class _OtpEntryViewState extends State<_OtpEntryView> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.otpCode);
  }

  @override
  void didUpdateWidget(_OtpEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otpCode != widget.otpCode && _controller.text != widget.otpCode) {
      _controller.text = widget.otpCode;
      _controller.selection = TextSelection.collapsed(offset: widget.otpCode.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRichText() {
    List<TextSpan> spans = [];
    for (int i = 0; i < 6; i++) {
      final hasChar = i < widget.otpCode.length;
      final char = hasChar ? widget.otpCode[i] : '\u00B7';
      spans.add(TextSpan(
        text: char + (i < 5 ? '   ' : ''),
        style: HelloText.display.copyWith(
          color: hasChar ? HelloColors.inkPrimary : HelloColors.inkTertiary,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invisible input
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                counterText: "",
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // Visual Typographic Display
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.focusNode.requestFocus(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Enter the code.",
                  style: HelloText.display,
                ),
                SizedBox(height: 16),
                _buildRichText(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Verifying View ---
class _VerifyingView extends StatelessWidget {
  _VerifyingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Verifying...",
          style: HelloText.display,
        ),
        SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: HelloColors.inkPrimary,
              strokeWidth: 2,
            ),
          ),
        ),
      ],
    );
  }
}
