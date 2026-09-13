import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imsnsit/model/functions.dart';
import 'package:imsnsit/model/imsnsit.dart';
import 'package:imsnsit/provider/ims_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final captchaController = TextEditingController();

  late final Ims ims;

  String? captchaImagePath;

  bool loadingCaptcha = false;
  bool loggingIn = false;

  @override
  void initState() {
    super.initState();

    ims = context.read<ImsProvider>().ims;
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    captchaController.dispose();

    super.dispose();
  }

  Future<void> loadCaptcha() async {
    if (loadingCaptcha) {
      return;
    }

    setState(() {
      loadingCaptcha = true;
    });

    try {
      final imageUrl = await ims.getCaptcha();

      final imagePath = await Functions.downloadFile(
        imageUrl,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        captchaImagePath = imagePath;
        captchaController.clear();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      showErrorDialog(
        'Unable to load CAPTCHA. Please check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingCaptcha = false;
        });
      }
    }
  }

  Future<void> onLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final captcha = captchaController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showErrorDialog(
        'Please enter your username and password.',
      );
      return;
    }

    if (captchaImagePath == null) {
      await loadCaptcha();
      return;
    }

    if (captcha.isEmpty) {
      showErrorDialog(
        'Please enter the CAPTCHA shown above.',
      );
      return;
    }

    if (loggingIn) {
      return;
    }

    setState(() {
      loggingIn = true;
    });

    try {
      final result = await ims.authenticate(
        captcha,
        username,
        password,
      );

      if (!mounted) {
        return;
      }

      if (result == LoginProperties.timeout) {
        showTimeoutDialog();
        return;
      }

      if (result == LoginProperties.wrongCaptcha) {
        showErrorDialog(
          'Incorrect CAPTCHA. A new CAPTCHA has been loaded.',
        );

        await loadCaptcha();
        return;
      }

      if (result == LoginProperties.wrongPassword) {
        showErrorDialog(
          'Username or password is incorrect.',
        );
        return;
      }

      if (ims.isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          'username',
          username,
        );

        await prefs.setString(
          'password',
          password,
        );

        if (!mounted) {
          return;
        }

        context.go('/attendance/total');
      } else {
        showErrorDialog(
          'Unable to log in. Please try again.',
        );

        await loadCaptcha();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      showErrorDialog(
        'Something went wrong while connecting to NSUT IMS.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loggingIn = false;
        });
      }
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(
            255,
            169,
            37,
            16,
          ),
          title: Text(
            'Login Error',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.roboto(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(
            255,
            169,
            37,
            16,
          ),
          title: Text(
            'Connection Timeout',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Timeout occurred while connecting to NSUT IMS. Please try again.',
            style: GoogleFonts.roboto(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.lexend(
        color: theme.colorScheme.onSurface,
      ),
      hintStyle: GoogleFonts.lexend(
        color: theme.colorScheme.onSurface,
      ),
      filled: true,
      fillColor: theme.colorScheme.primary.withAlpha(150),
      isDense: true,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(20),
        ),
      ),
    );
  }

  Widget buildCaptchaSection() {
    if (captchaImagePath == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter CAPTCHA',
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh CAPTCHA',
              onPressed: loadingCaptcha || loggingIn
                  ? null
                  : loadCaptcha,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha(100),
          ),
          child: Image.file(
            File(captchaImagePath!),
            height: 80,
            width: 180,
            fit: BoxFit.contain,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return const SizedBox(
                height: 80,
                width: 180,
                child: Center(
                  child: Text(
                    'CAPTCHA unavailable',
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          child: TextField(
            controller: captchaController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 8,
            cursorColor:
                Theme.of(context).colorScheme.onSurface,
            onSubmitted: (_) => onLogin(),
            decoration: inputDecoration(
              label: 'CAPTCHA',
              hint: 'Enter the digits shown above',
              icon: Icons.security_rounded,
            ).copyWith(
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome to',
                    style: GoogleFonts.lexend(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Image.asset(
                    'assets/nsut.png',
                    width: 100,
                    height: 100,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'NSUT Attendance',
                    style: GoogleFonts.lexend(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign in using your NSUT IMS credentials',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    cursorColor:
                        theme.colorScheme.onSurface,
                    decoration: inputDecoration(
                      label: 'Username',
                      hint: 'Enter your username',
                      icon: Icons.person_rounded,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [
                      AutofillHints.password,
                    ],
                    cursorColor:
                        theme.colorScheme.onSurface,
                    decoration: inputDecoration(
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_rounded,
                    ),
                  ),

                  buildCaptchaSection(),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loadingCaptcha || loggingIn
                          ? null
                          : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.onSurface,
                        foregroundColor:
                            theme.colorScheme.primary,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape:
                            const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.all(
                            Radius.circular(12),
                          ),
                        ),
                      ),
                      icon: loggingIn
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              captchaImagePath == null
                                  ? Icons
                                      .image_search_rounded
                                  : Icons.login_rounded,
                            ),
                      label: Text(
                        loggingIn
                            ? 'Logging in...'
                            : captchaImagePath == null
                                ? 'Get CAPTCHA'
                                : 'Login',
                        style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  if (captchaImagePath != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Enter the CAPTCHA exactly as shown.',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
