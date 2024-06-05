import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multiroom/app/(modules)/devices/ui/widgets/device_info_header.dart';
import 'package:multiroom/app/core/widgets/loading_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routefly/routefly.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../../injector.dart';
import '../../../../../routes.dart';
import '../../../../core/extensions/mask_text_input_formatter_extension.dart';
import '../../../../core/extensions/number_extensions.dart';
import '../../interactor/controllers/home_page_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = injector.get<HomePageController>();

  @override
  void initState() {
    super.initState();

    scheduleMicrotask(() async {
      if (Platform.isAndroid || Platform.isAndroid) {
        await [
          Permission.location,
          Permission.nearbyWifiDevices,
          Permission.locationWhenInUse,
        ].request();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (_) => LoadingOverlay(
        state: _controller.state,
        child: Scaffold(
          appBar: AppBar(
            leading: Image.asset("assets/logo.png"),
            title: const Text('Multiroom'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            scrolledUnderElevation: 0,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                flex: 2,
                                child: TextFormField(
                                  enabled:
                                      _controller.isConnected.value == false,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'IP do Host',
                                  ),
                                  onChanged: _controller.host.set,
                                  initialValue: _controller.host.peek(),
                                  inputFormatters: [
                                    MaskTextInputFormatterExt.ip(),
                                  ],
                                ),
                              ),
                              8.asSpace,
                              Flexible(
                                child: TextFormField(
                                  enabled:
                                      _controller.isConnected.value == false,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Porta',
                                  ),
                                  initialValue: _controller.port.peek(),
                                  onChanged: _controller.port.set,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(4)
                                  ],
                                ),
                              )
                            ],
                          ),
                          12.asSpace,
                          Watch(
                            (_) => AnimatedSwitcher(
                              duration: Durations.medium1,
                              child: ElevatedButton(
                                key: ValueKey(_controller.isConnected.value),
                                onPressed: _controller.toggleConnection,
                                child: Text(
                                  _controller.isConnected.value
                                      ? "Desconectar"
                                      : "Conectar",
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  18.asSpace,
                  DeviceInfoHeader(
                    device: _controller.device.value,
                    currentZone: _controller.currentZone.value,
                    currentInput: _controller.currentInput.value,
                    onChangeZone: _controller.currentZone.set,
                    onChangeInput: _controller.currentInput.set,
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.arrow_forward_rounded),
            onPressed: () =>
                Routefly.pushNavigate(routePaths.devices.ui.pages.deviceInfo),
          ),
        ),
      ),
    );
  }
}
