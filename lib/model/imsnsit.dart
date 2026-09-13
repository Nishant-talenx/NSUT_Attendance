import 'dart:async';
import 'dart:convert';

import 'package:cookie_store/cookie_store.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:imsnsit/model/functions.dart';
import 'package:imsnsit/model/session.dart';
import 'package:imsnsit/parsers/parse_data.dart';
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

```
final String? savedCookies = prefs.getString('cookies');

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
    final dynamic decoded = jsonDecode(savedUrls);

    if (decoded is Map) {
      allUrls = Map<String, dynamic>.from(decoded);
    } else {
      allUrls = {};
    }
  } catch (e) {
    debugPrint('Error loading saved URLs: $e');
    allUrls = {};
  }
}

username = prefs.getString('username');
password = prefs.getString('password');
```

}

// ------------------------------------------------------------
// SAVE SESSION
// ------------------------------------------------------------

Future<void> store(Map<String, dynamic> data) async {
final SharedPreferences prefs =
await SharedPreferences.getInstance();

```
for (final MapEntry<String, dynamic> entry in data.entries) {
  final String key = entry.key;
  final dynamic value = entry.value;

  if (value is String) {
    await prefs.setString(key, value);
  } else {
    await prefs.setString(
      key,
      jsonEncode(value),
    );
  }
}
```

}

// ------------------------------------------------------------
// CHECK AUTHENTICATION
// ------------------------------------------------------------

Future<bool> isUserAuthenticated() async {
if (profileUrl == null || profileUrl!.isEmpty) {
isAuthenticated = false;
return false;
}

```
try {
  baseHeaders['Referer'] =
      'https://www.imsnsit.org/imsnsit/student_login.php';

  final response = await session
      .get(
        Uri.parse(profileUrl!),
        headers: baseHeaders,
      )
      .timeout(
        const Duration(seconds: 8),
      );

  if (response.statusCode != 200) {
    isAuthenticated = false;
    return false;
  }

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
} on TimeoutException {
  isAuthenticated = false;
  return false;
} catch (e, stackTrace) {
  debugPrint('Authentication check error: $e');
  debugPrintStack(stackTrace: stackTrace);

  isAuthenticated = false;
  return false;
}
```

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

Future<HttpProperties> isImsUp() async {
try {
final response = await session
.get(
baseUrl,
headers: baseHeaders,
)
.timeout(
const Duration(seconds: 8),
);

```
  if (response.statusCode == 200) {
    return HttpProperties.succesful;
  }

  return HttpProperties.unsuccesful;
} on TimeoutException {
  return HttpProperties.timeout;
} catch (e) {
  debugPrint('IMS server check error: $e');
  return HttpProperties.unsuccesful;
}
```

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
'document',
});

```
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
        const Duration(seconds: 10),
      );

  if (response.statusCode != 200) {
    isAuthenticated = false;
    return LoginProperties.timeout;
  }

  final dom.Document doc = parse(response.body);

  final List<dom.Element> loginResults =
      doc.querySelectorAll(
    'html body form table tbody tr td.plum_field font',
  );

  if (loginResults.length >= 3) {
    final String loginResult =
        loginResults[2].text.trim();

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

    if (href == null || href.isEmpty || href == '#') {
      continue;
    }

    final String resolvedUrl =
        baseUrl.resolve(href).toString();

    if (text == 'My Profile') {
      profileUrl = resolvedUrl;
    }

    if (text == 'My Activities') {
      myActivitiesUrl = resolvedUrl;
    }

    if (text == 'Logout') {
      logoutUrl = resolvedUrl;
    }
  }

  if (myActivitiesUrl == null ||
      myActivitiesUrl!.isEmpty) {
    isAuthenticated = false;
    return LoginProperties.timeout;
  }

  final HttpProperties methodResponse =
      await getAllUrls();

  if (methodResponse != HttpProperties.succesful) {
    isAuthenticated = false;
    return LoginProperties.timeout;
  }

  final String cookies = session.getCookies(
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
} catch (e, stackTrace) {
  debugPrint('Login error: $e');
  debugPrintStack(stackTrace: stackTrace);

  isAuthenticated = false;
  return LoginProperties.timeout;
}
```

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

```
final http.Response firstResponse =
    await session
        .get(
          Uri.parse(
            'https://www.imsnsit.org/imsnsit/student_login110.php',
          ),
          headers: baseHeaders,
        )
        .timeout(
          const Duration(seconds: 10),
        );

if (firstResponse.statusCode != 200) {
  throw Exception(
    'Unable to initialize login session '
    '(HTTP ${firstResponse.statusCode})',
  );
}

final http.Response response =
    await session
        .get(
          Uri.parse(
            'https://www.imsnsit.org/imsnsit/student_login.php',
          ),
          headers: baseHeaders,
        )
        .timeout(
          const Duration(seconds: 10),
        );

if (response.statusCode != 200) {
  throw Exception(
    'Unable to load login page '
    '(HTTP ${response.statusCode})',
  );
}

final dom.Document doc = parse(response.body);

final dom.Element? captchaElement =
    doc.getElementById('captchaimg');

final dom.Element? hrandElement =
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
```

}

// ------------------------------------------------------------
// PROFILE
// ------------------------------------------------------------

Future<Map<String, String>> getProfileData() async {
if (profileUrl == null ||
profileUrl!.isEmpty) {
return {};
}

```
try {
  baseHeaders['Referer'] =
      'https://www.imsnsit.org/imsnsit/student_login.php';

  final http.Response response =
      await session
          .get(
            Uri.parse(profileUrl!),
            headers: baseHeaders,
          )
          .timeout(
            const Duration(seconds: 10),
          );

  if (response.statusCode != 200) {
    return {};
  }

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
    final String profileImageUrl =
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
} catch (e, stackTrace) {
  debugPrint('Profile error: $e');
  debugPrintStack(stackTrace: stackTrace);
  return {};
}
```

}

// ------------------------------------------------------------
// GET IMS "MY ACTIVITIES" LINKS
// ------------------------------------------------------------

Future<HttpProperties> getAllUrls() async {
if (myActivitiesUrl == null ||
myActivitiesUrl!.isEmpty) {
return HttpProperties.unsuccesful;
}

```
try {
  final http.Response response =
      await session
          .get(
            Uri.parse(myActivitiesUrl!),
            headers: baseHeaders,
          )
          .timeout(
            const Duration(seconds: 10),
          );

  if (response.statusCode != 200) {
    return HttpProperties.unsuccesful;
  }

  final dom.Document doc = parse(response.body);

  final List<dom.Element> links =
      doc.getElementsByTagName('a');

  for (final dom.Element linkElement in links) {
    final String? link =
        linkElement.attributes['href'];

    if (link == null ||
        link.isEmpty ||
        link == '#') {
      continue;
    }

    String key = linkElement.text.trim();

    key = cleanUrlKey(key);

    if (key.isNotEmpty) {
      allUrls[key] =
          baseUrl.resolve(link).toString();
    }
  }
} on TimeoutException {
  return HttpProperties.timeout;
} catch (e, stackTrace) {
  debugPrint('Get all URLs error: $e');
  debugPrintStack(stackTrace: stackTrace);

  return HttpProperties.unsuccesful;
}

return HttpProperties.succesful;
```

}

// ------------------------------------------------------------
// ENROLLED COURSES
// ------------------------------------------------------------

Future<Map<String, dynamic>>
getEnrolledCourses() async {
final dynamic courseUrl =
allUrls['currentsemcoursesregistered'];

```
if (courseUrl == null) {
  return {};
}

try {
  final Uri url =
      baseUrl.resolve(courseUrl.toString());

  final http.Response response =
      await session
          .get(
            url,
            headers: baseHeaders,
          )
          .timeout(
            const Duration(seconds: 10),
          );

  if (response.statusCode != 200) {
    return {};
  }

  final Map<String, dynamic> enrolledCourses =
      ParseData.parseEnrolledCoursesData(
    response.body,
  );

  final String sem =
      ParseData.parseSemester(response.body);

  semester = sem;

  return enrolledCourses;
} catch (e, stackTrace) {
  debugPrint('Enrolled courses error: $e');
  debugPrintStack(stackTrace: stackTrace);
  return {};
}
```

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

```
if (attendanceUrl == null) {
  return {};
}

try {
  final Uri url =
      baseUrl.resolve(attendanceUrl.toString());

  http.Response response =
      await session.get(
    url,
    headers: baseHeaders,
  );

  if (response.statusCode != 200) {
    return {};
  }

  final dom.Document doc = parse(response.body);

  final String encYear =
      doc.getElementById('enc_year')
              ?.attributes['value'] ??
          '';

  final String encSem =
      doc.getElementById('enc_sem')
              ?.attributes['value'] ??
          '';

  if (rollNo == null ||
      rollNo.isEmpty ||
      dept == null ||
      dept.isEmpty ||
      degree == null ||
      degree.isEmpty) {
    rollNo = doc
            .querySelector(
              '[name=recentitycode]',
            )
            ?.attributes['value'] ??
        '';

    dept = doc
            .querySelector(
              '[name=dept]',
            )
            ?.attributes['value'] ??
        '';

    degree = doc
            .querySelector(
              '[name=degree]',
            )
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

  if (response.statusCode != 200) {
    return {};
  }

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
} catch (e, stackTrace) {
  debugPrint('Subject-wise attendance error: $e');
  debugPrintStack(stackTrace: stackTrace);
  return {};
}
```

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

```
if (attendanceUrl == null) {
  return {};
}

try {
  final Uri url =
      baseUrl.resolve(attendanceUrl.toString());

  http.Response response =
      await session.get(
    url,
    headers: baseHeaders,
  );

  if (response.statusCode != 200) {
    return {};
  }

  final dom.Document doc = parse(response.body);

  final String encYear =
      doc.getElementById('enc_year')
              ?.attributes['value'] ??
          '';

  final String encSem =
      doc.getElementById('enc_sem')
              ?.attributes['value'] ??
          '';

  if (rollNo == null ||
      rollNo.isEmpty ||
      dept == null ||
      dept.isEmpty ||
      degree == null ||
      degree.isEmpty) {
    rollNo = doc
            .querySelector(
              '[name=recentitycode]',
            )
            ?.attributes['value'] ??
        '';

    dept = doc
            .querySelector(
              '[name=dept]',
            )
            ?.attributes['value'] ??
        '';

    degree = doc
            .querySelector(
              '[name=degree]',
            )
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

  if (response.statusCode != 200) {
    return {};
  }

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
} catch (e, stackTrace) {
  debugPrint('Attendance error: $e');
  debugPrintStack(stackTrace: stackTrace);
  return {};
}
```

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
} catch (e) {
debugPrint('Logout request error: $e');
}
}

```
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
```

}
}
