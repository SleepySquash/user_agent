import 'package:flutter/services.dart';

class IosUtils {
  static const platform = MethodChannel('team113.flutter.dev/ios_utils');

  static Future<String> getArchitecture() async {
    return await platform.invokeMethod('getArchitecture');
  }
}
