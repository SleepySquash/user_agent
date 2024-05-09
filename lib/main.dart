import 'dart:io';
import 'dart:ffi';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stdlibc/stdlibc.dart';
import 'package:win32/win32.dart';

import 'config.dart';
import 'ios_utils.dart';
import 'platform_utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _text = '';

  @override
  void initState() {
    _init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFD0D0),
        body: SelectionArea(child: Center(child: Text(_text))),
      ),
    );
  }

  Future<void> _init() async {
    final DeviceInfoPlugin device = DeviceInfoPlugin();

    String? system;

    if (PlatformUtils.isMacOS) {
      final info = await device.macOsInfo;
      final StringBuffer buffer = StringBuffer(
        'macOS ${info.osRelease}; ${info.model}; ${info.kernelVersion}; ${info.arch};',
      );

      final res = await Process.run('sysctl', ['machdep.cpu.brand_string']);
      if (res.exitCode == 0) {
        buffer.write(
          ' ${res.stdout.toString().substring('machdep.cpu.brand_string: '.length, res.stdout.toString().length - 1)}',
        );
      }

      if (info.systemGUID != null) {
        buffer.write('; ${info.systemGUID}');
      }

      system = buffer.toString();
    } else if (PlatformUtils.isWindows) {
      final info = await device.windowsInfo;

      final StringBuffer buffer = StringBuffer(
        '${info.productName}; build ${info.buildLabEx}; ${info.displayVersion}',
      );

      Pointer<SYSTEM_INFO> lpSystemInfo = calloc<SYSTEM_INFO>();
      try {
        GetNativeSystemInfo(lpSystemInfo);

        String? architecture;

        switch (lpSystemInfo.ref.Anonymous.Anonymous.wProcessorArchitecture) {
          case PROCESSOR_ARCHITECTURE_AMD64:
            architecture = 'x64';
            break;

          case PROCESSOR_ARCHITECTURE_ARM:
            architecture = 'ARM';
            break;

          case PROCESSOR_ARCHITECTURE_ARM64:
            architecture = 'ARM64';
            break;

          case PROCESSOR_ARCHITECTURE_IA64:
            architecture = 'IA64';
            break;

          case PROCESSOR_ARCHITECTURE_INTEL:
            architecture = 'x86';
            break;
        }

        if (architecture != null) {
          buffer.write('; $architecture');
        }
      } finally {
        free(lpSystemInfo);
      }

      buffer.write('; ${info.deviceId}');

      system = buffer.toString();
    } else if (PlatformUtils.isLinux) {
      final info = await device.linuxInfo;
      final utsname = uname();

      final StringBuffer buffer = StringBuffer(info.prettyName);

      if (utsname != null) {
        buffer.write(' ${utsname.release}');
      }

      if (info.variant != null || info.buildId != null) {
        buffer.write(';');
      }

      if (info.variant != null) {
        buffer.write(' ${info.variant}');
      }

      if (info.buildId != null) {
        buffer.write(' (build ${info.buildId})');
      }

      if (utsname != null) {
        buffer.write('; ${utsname.machine}');
      }

      if (info.machineId != null) {
        buffer.write('; ${info.machineId}');
      }

      system = buffer.toString();
    } else if (PlatformUtils.isAndroid) {
      final info = await device.androidInfo;
      final utsname = uname();

      final StringBuffer buffer = StringBuffer(
        'Android ${info.version.release}; ${info.manufacturer} ${info.model}; ${info.id}; ${info.version.incremental} (build ${info.fingerprint}); SDK ${info.version.sdkInt}',
      );

      if (utsname != null) {
        buffer.write('; ${utsname.machine} ${info.hardware}');
      }

      system = buffer.toString();
    } else if (PlatformUtils.isIOS) {
      final info = await device.iosInfo;
      final StringBuffer buffer = StringBuffer(
        '${info.systemName} ${info.systemVersion}; ${info.utsname.machine}; ${info.utsname.version}',
      );

      try {
        buffer.write('; ${await IosUtils.getArchitecture()}');
      } catch (_) {
        // No-op.
      }

      if (info.identifierForVendor != null) {
        buffer.write('; ${info.identifierForVendor}');
      }

      system = buffer.toString();
    }

    String agent = '${Config.userAgentProduct}/${Config.userAgentVersion}';
    if (system != null) {
      agent = '$agent ($system)';
    }

    if (mounted) {
      setState(() => _text = system ?? '');
    }
  }
}
