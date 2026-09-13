import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imsnsit/model/imsnsit.dart';
import 'package:imsnsit/provider/ims_provider.dart';
import 'package:imsnsit/provider/intenet_availability.dart';
import 'package:imsnsit/provider/mode_provider.dart';
import 'package:imsnsit/provider/version.dart';
import 'package:imsnsit/widgets/conditional_visibilty.dart';
import 'package:imsnsit/widgets/update_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NeedToLogin {
  checking,
  no,
  yes,
  completeLogin,
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  HttpResult internetAvailable = HttpResult.waiting;
  HttpResult imsUp = HttpResult.waiting;

  NeedToLogin userLoggedIn = NeedToLogin.checking;

  bool checkingForUpdate = false;
  bool useOfflineMode = false;
  bool retry = false;

  late final InternetProvider internetProvider;
  late final VersionProvider versionProvider;
  late final Ims ims;

  Future<bool?> waitForUpdateDialog =
      Future<bool?>.value(false);

  @override
  void initState() {
    super.initState();

    internetProvider = context.read<InternetProvider>();
    versionProvider = context.read<VersionProvider>();
    ims = context.read<ImsProvider>().ims;

    context.read<ModeProvider>().reset();

    _initialize();
  }

  Future<void> _initialize() async {
    final availability =
        await internetProvider.checkForInternet();

    if (!mounted) {
      return;
    }

    setState(() {
      internetAvailable = availability;
    });

    if (!availability.value) {
      setOfflineMode();
      return;
    }

    _checkForUpdate();

    final serverStatus = await ims.isImsUp();

    if (!mounted) {
      return;
    }

    setState(() {
      imsUp = serverStatus;
    });

    if (!serverStatus.value) {
      setOfflineMode();
      return;
    }

    final loginStatus = await doesUserNeedToLogin();

    if (!mounted) {
      return;
    }

    setState(() {
      userLoggedIn = loginStatus;
    });

    if (loginStatus == NeedToLogin.no) {
      waitForUpdateDialog.whenComplete(() {
        if (!mounted) {
          return;
        }

        context.go('/attendance/total');
      });

      return;
    }

    if (loginStatus == NeedToLogin.completeLogin) {
      waitForUpdateDialog.whenComplete(() {
        if (!mounted) {
          return;
        }

        context.go('/authentication/login_screen');
      });

      return;
    }

    /*
     * The old app attempted to solve the IMS CAPTCHA
     * automatically using Tesseract OCR.
     *
     * We removed OCR because the trained data file is
     * not part of the repository.
     *
     * Instead, send the user directly to the existing
     * manual CAPTCHA screen.
     */
    waitForUpdateDialog.whenComplete(() {
      if (!mounted) {
        return;
      }

      context.go('/authentication/manual_login');
    });
  }

  Future<NeedToLogin> doesUserNeedToLogin() async {
    if (ims.username != null && ims.password != null) {
      final authenticated =
          await ims.isUserAuthenticated();

      if (authenticated) {
        return NeedToLogin.no;
      }

      return NeedToLogin.yes;
    }

    return NeedToLogin.completeLogin;
  }

  void _checkForUpdate() {
    versionProvider.isLatestVersion().then((isUpdateAvailable) {
      if (!mounted) {
        return;
      }

      setState(() {
        checkingForUpdate = true;
      });

      if (isUpdateAvailable) {
        waitForUpdateDialog = showDialog<bool>(
          barrierColor: Colors.transparent,
          context: context,
          builder: (_) => const UpdateDialog(),
        ).then((_) {
          return false;
        });
      }
    });
  }

  void setOfflineMode() {
    final prefs = context.read<SharedPreferences>();

    if (prefs.containsKey(
      'attendanceDataLastUpdated',
    )) {
      context.read<ModeProvider>().setOffline();

      setState(() {
        useOfflineMode = true;
        retry = true;
      });
    } else {
      setState(() {
        retry = true;
      });
    }
  }

  void retryInitialization() {
    context.push('/initial_screen');
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConditionalyVisible(
                  showIf: true,
                  child: _statusRow(
                    text: 'Checking internet',
                    completed:
                        internetAvailable.value,
                    waiting:
                        internetAvailable ==
                            HttpResult.waiting,
                    color: baseColor,
                  ),
                ),

                ConditionalyVisible(
                  showIf: internetAvailable.value,
                  child: _statusRow(
                    text: 'Checking for updates',
                    completed: checkingForUpdate,
                    waiting: !checkingForUpdate,
                    color: baseColor,
                  ),
                ),

                ConditionalyVisible(
                  showIf: checkingForUpdate,
                  child: _statusRow(
                    text: 'NSUT IMS available',
                    completed: imsUp.value,
                    waiting:
                        imsUp == HttpResult.waiting,
                    color: baseColor,
                  ),
                ),

                ConditionalyVisible(
                  showIf: imsUp.value,
                  child: _statusRow(
                    text: 'Checking login session',
                    completed:
                        userLoggedIn ==
                            NeedToLogin.no,
                    waiting:
                        userLoggedIn ==
                            NeedToLogin.checking,
                    color: baseColor,
                  ),
                ),

                if (retry) ...[
                  const SizedBox(height: 20),

                  SizedBox(
                    width: 180,
                    child: ElevatedButton.icon(
                      onPressed: retryInitialization,
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: Text(
                        'Retry',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                if (useOfflineMode) ...[
                  const SizedBox(height: 10),

                  SizedBox(
                    width: 180,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context
                            .read<ModeProvider>()
                            .setOffline();

                        context.go(
                          '/attendance/total',
                        );
                      },
                      icon: const Icon(
                        Icons
                            .signal_wifi_connected_no_internet_4_rounded,
                      ),
                      label: Text(
                        'Offline Mode',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusRow({
    required String text,
    required bool completed,
    required bool waiting,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: GoogleFonts.lexend(),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 20,
            height: 20,
            child: waiting
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  )
                : Icon(
                    completed
                        ? Icons.check
                        : Icons.close,
                    color: color,
                  ),
          ),
        ],
      ),
    );
  }
}
