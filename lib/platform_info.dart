import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// `Platform` aus dart:io wirft im Browser eine Exception – daher nur über
/// diesen Getter abfragen.
bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;
