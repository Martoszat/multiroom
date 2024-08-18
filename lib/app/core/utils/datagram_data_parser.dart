import 'dart:typed_data';

import 'package:multiroom/app/core/extensions/string_extensions.dart';

abstract class DatagramDataParser {
  static (String serialNumber, String firmware) getSerialAndFirmware(Uint8List data) {
    String serialNumber = String.fromCharCodes(data.sublist(29, 45));
    final firmware =
        ((data.sublist(45, 46).toList().first + (data.sublist(46, 47).toList().first * 256)) / 1000).toString();
    final formatted =
        "${firmware.substring(0, 2)}${firmware.substring(3).isNotNullOrEmpty ? firmware.substring(3) : firmware.substring(2)}";

    return (serialNumber, formatted);
  }
}
