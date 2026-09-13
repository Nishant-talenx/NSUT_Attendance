import 'dart:async';
import 'dart:convert';

import 'package:cookie_store/cookie_store.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:imsnsit/model/functions.dart';
import 'package:imsnsit/model/session.dart';
import 'package:imsnsit/parsers/parseData.dart';
import 'package:imsnsit/provider/intenet_availability.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginProperties {
  wrongCaptcha,
  wrongPassword,
  loginedSuccesfully,
  timeout,
}

enum HttpProperties {
  timeout,
  succesful,
  unsuccesful,
}

String getFinancialYear() {
  final DateTime now = DateTime.now();
  final int year = now.year;
  final int month = now.month;

  if (month <= 5) {
    return '${year - 1}-${(year % 100).toString().padLeft(2, '0')}';
  }

  return '$year-${((year + 1) % 100).toString().padLeft(2, '0')}';
}

class Ims {
  String? username;
  String? password;

  final Map<String, String> baseHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.6099.119 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
  };

  final Uri baseUrl = Uri.parse(
    'https://www.imsnsit.org/imsnsit/',
  );

  String? profileUrl;
  String? myActivitiesUrl;
  String? logoutUrl;
  String? referrer;

  Map<String, dynamic> allUrls = {};

  final Session session = Session();

  bool isAuthenticated = false;

  String? hrandNum;
  String? semester;

  // ------------------------------------------------------------
  // LOAD SAVED SESSION
  // ------------------------------------------------------------

  Future<void> getSessionAttributes() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    final savedCookies = prefs.getString('cookies');

    if (savedCookies != null && savedCookies.isNotEmpty) {
      session.cookies = CookieStore()
        ..updateCookies(
          savedCookies,
          'imsnsit.org',
          '/',
        );
    }

    profileUrl = prefs.getString('profileUrl');
    myActivitiesUrl = prefs.getString('myActivitiesUrl');
    logoutUrl = prefs.getString('logoutUrl');
    referrer = prefs.getString('referrer');

    final String? savedUrls = prefs.getString('allUrls');

    if (savedUrls != null && savedUrls.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedUrls);

        if (decoded is Map) {
          allUrls = Map<String, dynamic>.from(decoded);
        } else {
          allUrls = {};
        }
      } catch (_) {
        allUrls = {};
      }
    }

    username = prefs.getString('username');
    password = prefs.getString('password');
  }

  // ------------------------------------------------------------
  // SAVE SESSION
  // ------------------------------------------------------------

  Future<void> store(Map<String, dynamic> data) async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await prefs.setString(key, value);
      } else {
        await prefs.setString(
          key,
          jsonEncode(value),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // CHECK AUTHENTICATION
  // ------------------------------------------------------------

  Future<bool> isUserAuthenticated() async {
    if (profileUrl == null || profileUrl!.isEmpty) {
      return false;
    }

    try {
      baseHeaders['Referer'] =
          'https://www.imsnsit.org/imsnsit/student_login.php';

      final response = await session
          .get(
            Uri.parse(profileUrl!),
            headers: baseHeaders,
          )
          .timeout(
            const Duration(seconds: 5),
          );

      if (response.body.contains('Session expired')) {
        isAuthenticated = false;
        return false;
      }

      if (response.body.contains('student_login.php') &&
          response.body.contains('Password')) {
        isAuthenticated = false;
        return false;
      }

      isAuthenticated = true;
      return true;
    } catch (_) {
      isAuthenticated = false;
      return false;
    }
  }

  // ------------------------------------------------------------
  // INITIAL DATA
  // ------------------------------------------------------------

  Future<void> getInitialData() async {
    await getSessionAttributes();
  }

  // ------------------------------------------------------------
  // CHECK IMS SERVER
  // ------------------------------------------------------------

  Future<HttpResult> isImsUp() async {
    try {
      final response = await session
          .get(
            baseUrl,
            headers: baseHeaders,
          )
          .timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        return HttpResult.successful;
      }

      return HttpResult.unsuccesful;
    } on TimeoutException {
      return HttpResult.timeout;
    } catch (_) {
      return HttpResult.unsuccesful;
    }
  }

  // ------------------------------------------------------------
  // LOGIN
  // ------------------------------------------------------------

  Future<LoginProperties> authenticate(
    String cap,
    String username,
    String password,
  ) async {
    baseHeaders.addAll({
      'Referer':
          'https://www.imsnsit.org/imsnsit/student_login.php',
      'Content-Type':
          'application/x-www-form-urlencoded',
      'Origin':
          'https://www.imsnsit.org',
      'Upgrade-Insecure-Requests':
          '1',
      'Sec-Fetch-Dest':
          'frame',
    });

    final Map<String, String> data = {
      'f': '',
      'uid': username,
      'pwd': password,
      'HRAND_NUM': hrandNum ?? '',
      'fy': getFinancialYear(),
      'comp':
          'NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY',
      'cap': cap,
      'logintype': 'student',
    };

    try {
      final response = await session
          .post(
            Uri.parse(
              'https://www.imsnsit.org/imsnsit/student_login.php',
            ),
            headers: baseHeaders,
            data: data,
          )
          .timeout(
            const Duration(seconds: 8),
          );

      final doc = parse(response.body);

      final loginResults = doc.querySelectorAll(
        'html body form table tbody tr td.plum_field font',
      );

      if (loginResults.length >= 3) {
        final loginResult = loginResults[2].text.trim();

        if (loginResult.contains(
          'Invalid Security Number',
        )) {
          isAuthenticated = false;
          return LoginProperties.wrongCaptcha;
        }

        if (loginResult.contains('Invalid password') ||
            loginResult.contains(
              'Your password does not match',
            )) {
          isAuthenticated = false;
          return LoginProperties.wrongPassword;
        }
      }

      referrer = response.request?.url.toString();

      final List<dom.Element> links =
          doc.getElementsByTagName('a');

      profileUrl = null;
      myActivitiesUrl = null;
      logoutUrl = null;

      for (final dom.Element link in links) {
        final String text = link.text.trim();
        final String? href = link.attributes['href'];

        if (href == null || href == '#') {
          continue;
        }

        if (text == 'My Profile') {
          profileUrl = href;
        }

        if (text == 'My Activities') {
          myActivitiesUrl = href;
        }

        if (text == 'Logout') {
          logoutUrl = href;
        }
      }

      if (myActivitiesUrl == null ||
          myActivitiesUrl!.isEmpty) {
        isAuthenticated = false;
        return LoginProperties.timeout;
      }

      final methodResponse = await getAllUrls();

      if (methodResponse == HttpProperties.timeout) {
        isAuthenticated = false;
        return LoginProperties.timeout;
      }

      if (methodResponse == HttpProperties.unsuccesful) {
        isAuthenticated = false;
        return LoginProperties.timeout;
      }

      final cookies = session.getCookies(
        Uri.parse(
          'https://www.imsnsit.org/imsnsit/student_login.php',
        ),
      );

      await store({
        'username': username,
        'password': password,
        'cookies': cookies,
        'profileUrl': profileUrl ?? '',
        'myActivitiesUrl': myActivitiesUrl ?? '',
        'referrer': referrer ?? '',
        'allUrls': allUrls,
        'logoutUrl': logoutUrl ?? '',
      });

      this.username = username;
      this.password = password;

      isAuthenticated = true;

      return LoginProperties.loginedSuccesfully;
    } on TimeoutException {
      isAuthenticated = false;
      return LoginProperties.timeout;
    } catch (_) {
      isAuthenticated = false;
      return LoginProperties.timeout;
    }
  }

  // ------------------------------------------------------------
  // CAPTCHA
  // ------------------------------------------------------------

  Future<String> getCaptcha() async {
    baseHeaders.addAll({
      'Referer':
          'https://www.imsnsit.org/imsnsit/',
      'Sec-Fetch-User': '?1',
    });

    await session
        .get(
          Uri.parse(
            'https://www.imsnsit.org/imsnsit/student_login110.php',
          ),
          headers: baseHeaders,
        )
        .timeout(
          const Duration(seconds: 8),
        );

    final response = await session
        .get(
          Uri.parse(
            'https://www.imsnsit.org/imsnsit/student_login.php',
          ),
          headers: baseHeaders,
        )
        .timeout(
          const Duration(seconds: 8),
        );

    final doc = parse(response.body);

    final captchaElement =
        doc.getElementById('captchaimg');

    final hrandElement =
        doc.getElementById('HRAND_NUM');

    if (captchaElement == null ||
        hrandElement == null) {
      throw Exception(
        'Unable to load captcha',
      );
    }

    final String? captchaSource =
        captchaElement.attributes['src'];

    final String? hrand =
        hrandElement.attributes['value'];

    if (captchaSource == null ||
        captchaSource.isEmpty ||
        hrand == null ||
        hrand.isEmpty) {
      throw Exception(
        'Invalid captcha data',
      );
    }

    hrandNum = hrand;

    return baseUrl
        .resolve(captchaSource)
        .toString();
  }

  // ------------------------------------------------------------
  // PROFILE
  // ------------------------------------------------------------

  Future<Map<String, String>> getProfileData() async {
    if (profileUrl == null ||
        profileUrl!.isEmpty) {
      return {};
    }

    baseHeaders['Referer'] =
        'https://www.imsnsit.org/imsnsit/student_login.php';

    final response = await session.get(
      Uri.parse(profileUrl!),
      headers: baseHeaders,
    );

    final Map<String, String> profileData =
        ParseData.parseProfileData(
      response.body,
    );

    if (profileData.isEmpty) {
      return {};
    }

    final String? imagePath =
        profileData['profile_image'];

    if (imagePath != null &&
        imagePath.isNotEmpty) {
      final profileImageUrl =
          baseUrl.resolve(imagePath).toString();

      profileData['profileImage'] =
          profileImageUrl;
    }

    profileData['profileUrl'] = profileUrl!;

    await Functions.saveJsonToFile(
      jsonEncode(profileData),
      DataType.profile,
    );

    return profileData;
  }

  // ------------------------------------------------------------
  // GET IMS "MY ACTIVITIES" LINKS
  // ------------------------------------------------------------

  Future<HttpProperties> getAllUrls() async {
    if (myActivitiesUrl == null ||
        myActivitiesUrl!.isEmpty) {
      return HttpProperties.unsuccesful;
    }

    try {
      final response = await session
          .get(
            Uri.parse(myActivitiesUrl!),
            headers: baseHeaders,
          )
          .timeout(
            const Duration(seconds: 8),
          );

      final doc = parse(response.body);

      final List<dom.Element> links =
          doc.getElementsByTagName('a');

      for (final dom.Element linkElement in links) {
        final String? link =
            linkElement.attributes['href'];

        if (link == null || link == '#') {
          continue;
        }

        String key = linkElement.text.trim();

        key = cleanUrlKey(key);

        if (key.isNotEmpty) {
          allUrls[key] = link;
        }
      }
    } on TimeoutException {
      return HttpProperties.timeout;
    } catch (_) {
      return HttpProperties.unsuccesful;
    }

    return HttpProperties.succesful;
  }

  // ------------------------------------------------------------
  // ENROLLED COURSES
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getEnrolledCourses() async {
    final dynamic courseUrl =
        allUrls['currentsemcoursesregistered'];

    if (courseUrl == null) {
      return {};
    }

    final Uri url = Uri.parse(
      courseUrl.toString(),
    );

    final response = await session.get(
      url,
      headers: baseHeaders,
    );

    final Map<String, dynamic> enrolledCourses =
        ParseData.parseEnrolledCoursesData(
      response.body,
    );

    final String sem =
        ParseData.parseSemester(response.body);

    semester = sem;

    return enrolledCourses;
  }

  // ------------------------------------------------------------
  // SUBJECT-WISE ATTENDANCE
  // ------------------------------------------------------------

  Future<Map<String, dynamic>>
      getAbsoulteAttandanceData({
    String? rollNo,
    String? dept,
    String? degree,
  }) async {
    final dynamic attendanceUrl =
        allUrls['myattendance'];

    if (attendanceUrl == null) {
      return {};
    }

    final Uri url = Uri.parse(
      attendanceUrl.toString(),
    );

    http.Response response = await session.get(
      url,
      headers: baseHeaders,
    );

    final doc = parse(response.body);

    final String encYear =
        doc.getElementById('enc_year')
                ?.attributes['value'] ??
            '';

    final String encSem =
        doc.getElementById('enc_sem')
                ?.attributes['value'] ??
            '';

    if (rollNo == '' ||
        dept == null ||
        degree == null) {
      rollNo = doc
              .querySelector(
                '[name=recentitycode]',
              )
              ?.attributes['value'] ??
          '';

      dept = doc
              .querySelector('[name=dept]')
              ?.attributes['value'] ??
          '';

      degree = doc
              .querySelector('[name=degree]')
              ?.attributes['value'] ??
          '';
    }

    if (semester == null) {
      await getEnrolledCourses();
    }

    final Map<String, String> data = {
      'year': getFinancialYear(),
      'enc_year': encYear,
      'sem': semester ?? '',
      'enc_sem': encSem,
      'submit': 'Submit',
      'recentitycode': rollNo ?? '',
      'dept': dept ?? '',
      'degree': degree ?? '',
      'ename': '',
      'ecode': '',
    };

    response = await session.post(
      url,
      headers: baseHeaders,
      data: data,
    );

    final Map<String, Map<String, String>>
        attendanceData =
        ParseData.parseAbsoluteAttandanceData(
      response.body,
    );

    await Functions.saveJsonToFile(
      jsonEncode(attendanceData),
      DataType.absoluteAttendance,
    );

    return attendanceData;
  }

  // ------------------------------------------------------------
  // TOTAL ATTENDANCE
  // ------------------------------------------------------------

  Future<Map<String, dynamic>>
      getAttandanceData({
    String? rollNo,
    String? dept,
    String? degree,
  }) async {
    final dynamic attendanceUrl =
        allUrls['myattendance'];

    if (attendanceUrl == null) {
      return {};
    }

    final Uri url = Uri.parse(
      attendanceUrl.toString(),
    );

    http.Response response = await session.get(
      url,
      headers: baseHeaders,
    );

    final doc = parse(response.body);

    final String encYear =
        doc.getElementById('enc_year')
                ?.attributes['value'] ??
            '';

    final String encSem =
        doc.getElementById('enc_sem')
                ?.attributes['value'] ??
            '';

    if (rollNo == '' ||
        dept == null ||
        degree == null) {
      rollNo = doc
              .querySelector(
                '[name=recentitycode]',
              )
              ?.attributes['value'] ??
          '';

      dept = doc
              .querySelector('[name=dept]')
              ?.attributes['value'] ??
          '';

      degree = doc
              .querySelector('[name=degree]')
              ?.attributes['value'] ??
          '';
    }

    final Map<String, dynamic> courses =
        await getEnrolledCourses();

    final Map<String, String> data = {
      'year': getFinancialYear(),
      'enc_year': encYear,
      'sem': semester ?? '',
      'enc_sem': encSem,
      'submit': 'Submit',
      'recentitycode': rollNo ?? '',
      'dept': dept ?? '',
      'degree': degree ?? '',
      'ename': '',
      'ecode': '',
    };

    response = await session.post(
      url,
      headers: baseHeaders,
      data: data,
    );

    final Map<String, Map<String, String>>
        attendanceData =
        ParseData.parseAttandanceData(
      response.body,
      courses,
    );

    await Functions.saveJsonToFile(
      jsonEncode(attendanceData),
      DataType.attendance,
    );

    return attendanceData;
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> logout() async {
    if (logoutUrl != null &&
        logoutUrl!.isNotEmpty) {
      try {
        await session.get(
          Uri.parse(logoutUrl!),
          headers: baseHeaders,
        );
      } catch (_) {}
    }

    session.cookies.cookies = [];

    username = null;
    password = null;
    profileUrl = '';
    myActivitiesUrl = '';
    logoutUrl = '';
    referrer = '';
    allUrls = {};
    semester = null;
    hrandNum = null;
    isAuthenticated = false;

    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('cookies');
    await prefs.remove('profileUrl');
    await prefs.remove('myActivitiesUrl');
    await prefs.remove('logoutUrl');
    await prefs.remove('referrer');
    await prefs.remove('allUrls');
    await prefs.remove('username');
    await prefs.remove('password');

    await prefs.remove(
      'attendanceDataLastUpdated',
    );

    await prefs.remove(
      'subjectWiseAttendanceDataLastUpdated',
    );

    await prefs.remove(
      'profileDataLastUpdated',
    );
  }
}
