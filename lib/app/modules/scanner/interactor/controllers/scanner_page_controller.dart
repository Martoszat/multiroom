import 'dart:async';
import 'dart:io';

import 'package:routefly/routefly.dart';
import 'package:signals/signals_flutter.dart';
import 'package:udp/udp.dart';

import '../../../../../injector.dart';
import '../../../../../routes.g.dart';
import '../../../../core/enums/device_type.dart';
import '../../../../core/enums/page_state.dart';
import '../../../../core/extensions/list_extensions.dart';
import '../../../../core/extensions/socket_extensions.dart';
import '../../../../core/extensions/stream_iterator_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/interactor/controllers/base_controller.dart';
import '../../../../core/interactor/repositories/settings_contract.dart';
import '../../../../core/models/device_model.dart';
import '../../../../core/models/project_model.dart';
import '../../../../core/utils/datagram_data_parser.dart';
import '../../../../core/utils/mr_cmd_builder.dart';
import '../models/network_device_model.dart';

class ScannerPageController extends BaseController {
  ScannerPageController() : super(InitialState());

  UDP? _udpServer;

  final settings = injector.get<SettingsContract>();

  final isUdpListening = false.toSignal(debugLabel: "isUdpListening");
  final projects = listSignal<ProjectModel>([], debugLabel: "projects");
  final networkDevices = listSignal<NetworkDeviceModel>([], debugLabel: "networkDevices");
  final deviceType = NetworkDeviceType.undefined.toSignal(debugLabel: "deviceType");
  final projectName = "".toSignal(debugLabel: "projectName");
  final currentProject = ProjectModel.empty().toSignal(debugLabel: "currentProject");
  final hasDevices = false.toSignal(debugLabel: "hasDevices");

  final isMasterAvailable = true.toSignal(debugLabel: "isMasterAvailable");
  final slave1Available = true.toSignal(debugLabel: "slave1Available");
  final slave2Available = true.toSignal(debugLabel: "slave2Available");
  final hasAvailableSlots = false.toSignal(debugLabel: "hasAvailableSlots");

  final _localDevices = listSignal(
    <DeviceModel>[],
    debugLabel: "localDevices",
  );

  Future<void> init() async {
    projects.value = settings.projects;
    hasDevices.value = projects.value.expand((p) => p.devices).toList().isNotEmpty;

    disposables.addAll(
      [
        effect(() {
          hasAvailableSlots.value = currentProject.value.devices.length < 3;
          isMasterAvailable.value = currentProject.value.devices.isEmpty ||
              currentProject.value.devices.every((d) => d.type != DeviceType.master);
          slave1Available.value = isMasterAvailable.peek() == false &&
              currentProject.value.devices.where((d) => d.type == DeviceType.slave).isEmpty;
          slave2Available.value = slave1Available.peek() == false &&
              currentProject.value.devices.where((d) => d.type == DeviceType.slave).length == 1;

          if (hasAvailableSlots.value == false) {
            stopUdpServer();
          }
        }),
        effect(() {
          _localDevices.value = projects.value.expand((p) => p.devices).toList();
        }),
        effect(() {
          if (isUdpListening.value) {
            logger.i("UDP LISTENING ON --> ${_udpServer?.local.address?.address}:${_udpServer?.local.port?.value} ");
          } else {
            logger.i("UDP SERVER CLOSED");
          }
        }),
        effect(() {
          settings.saveProjects(projects.value);
          hasDevices.value = projects.value.expand((p) => p.devices).toList().isNotEmpty;
        }),
      ],
    );
  }

  Future<void> startUdpServer() async {
    if (isUdpListening.value) {
      return;
    }

    try {
      _udpServer = await UDP.bind(
        Endpoint.unicast(
          InternetAddress.anyIPv4,
          port: const Port(4055),
        ),
      );

      isUdpListening.value = true;

      _udpServer?.asStream().listen(
        (datagram) {
          if (datagram == null) {
            return;
          }

          try {
            final data = datagram.data;
            logger.i("UDP DATA --> $data | FROM ${datagram.address.address}:${datagram.port}");

            final (serialNumber, firmware) = DatagramDataParser.getSerialAndFirmware(datagram.data);

            // Ignore already added devices
            if (_localDevices.value.any((d) => d.serialNumber == serialNumber) ||
                networkDevices.any((d) => d.serialNumber == serialNumber)) {
              return;
            }

            networkDevices.add(
              NetworkDeviceModel(
                ip: datagram.address.address,
                serialNumber: serialNumber,
                firmware: firmware,
              ),
            );
          } catch (exception) {
            logger.e("Datagram parse error [${datagram.address.address}]-> $exception");
          }
        },
      );

      // for (int i = 0; i < 5; i++) {
      //   networkDevices.add(
      //     NetworkDeviceModel(
      //       ip: "192.168.0.${i + 1}",
      //       serialNumber: "MR-123456-00$i",
      //       firmware: "1.0",
      //     ),
      //   );
      // }

      // await Future.delayed(
      //   const Duration(seconds: 2),
      //   () => networkDevices.add(
      //     const NetworkDeviceModel(
      //       ip: "192.188.0.1",
      //       serialNumber: "123456",
      //       firmware: "1.0",
      //     ),
      //   ),
      // );
    } catch (exception) {
      logger.e(exception);
      setError(exception as Exception);
    }
  }

  void stopUdpServer() {
    if (_udpServer?.closed == false) {
      _udpServer?.close();
    }

    isUdpListening.value = false;
  }

  Computed<bool> get isProjectNameValid => computed(() => projectName.value.isNotNullOrEmpty);

  void onTapConfigDevice(DeviceModel device) {
    stopUdpServer();

    Routefly.push(routePaths.modules.configs.pages.deviceConfiguration, arguments: device).then(
      (_) async {
        if (projects.peek() != settings.projects) {
          projects.value = settings.projects;
        }
      },
    );
  }

  Future<void> onConfirmAddDevice(NetworkDeviceModel netDevice) async {
    final type = await _setDeviceType(
      netDevice.ip,
      DeviceType.fromString(deviceType.value.name.lettersOnly),
    );

    final newDevice = DeviceModel.builder(
      projectId: currentProject.value.id,
      projectName: currentProject.value.name,
      ip: netDevice.ip,
      serialNumber: netDevice.serialNumber,
      version: netDevice.firmware,
      name: deviceType.value.readable,
      // type: DeviceType.fromString(deviceType.value.name.lettersOnly),
      type: DeviceType.fromString(type),
    );

    _updateProject(newDevice);
    onTapConfigDevice(newDevice);

    deviceType.value = deviceType.initialValue;
    networkDevices.removeWhere((d) => d.serialNumber == netDevice.serialNumber);
  }

  void addProject() {
    final project = ProjectModel.builder(
      name: projectName.value,
    );

    projects.add(project);

    currentProject.value = project;
    projectName.value = projectName.initialValue;
  }

  void removeProject(ProjectModel project) {
    settings.removeProject(project.id);
    projects.value = settings.projects;

    projectName.value = projectName.initialValue;
    currentProject.value = currentProject.initialValue;
  }

  void _updateProject(DeviceModel newDevice) {
    currentProject.value = currentProject.peek().copyWith(devices: [...currentProject.peek().devices, newDevice]);

    final List<ProjectModel> newProjects = List.from(projects.peek());
    newProjects.replaceWhere((p) => p.id == currentProject.peek().id, currentProject.value);

    projects.value = newProjects;
  }

  Future<String> _setDeviceType(String ip, DeviceType type) async {
    final Socket socket;

    try {
      socket = await run(
        () => Socket.connect(
          ip,
          4998,
          timeout: const Duration(seconds: 2),
        ),
      );

      final streamIterator = StreamIterator(socket);

      socket.writeLog(MrCmdBuilder.setExpansionMode(type: type));
      final response = MrCmdBuilder.parseResponse(await streamIterator.readSync());

      if (response.contains("OK") == false) {
        throw Exception("Erro ao configurar dispositivo, tente novamente.");
      }

      socket.writeLog(MrCmdBuilder.expansionMode);
      final deviceMode = MrCmdBuilder.parseResponse(await streamIterator.readSync());

      socket.close().ignore();

      return deviceMode;
    } catch (exception) {
      logger.e(exception);
      setError(exception as Exception);

      rethrow;
    }
  }

  void _clearEmptyProjects() {
    final emptyProjects = projects.value = projects.value.where((p) => p.devices.isEmpty).toList();

    for (final p in emptyProjects) {
      settings.removeProject(p.id);
    }
  }

  @override
  void dispose() {
    super.dispose();

    _clearEmptyProjects();
    stopUdpServer();
    isUdpListening.value = isUdpListening.initialValue;
    deviceType.value = deviceType.initialValue;
    projectName.value = projectName.initialValue;
    currentProject.value = currentProject.initialValue;

    isMasterAvailable.value = isMasterAvailable.initialValue;
    slave1Available.value = slave1Available.initialValue;
    slave2Available.value = slave2Available.initialValue;
    hasAvailableSlots.value = hasAvailableSlots.initialValue;

    projects.value = <ProjectModel>[];
    networkDevices.value = <NetworkDeviceModel>[];
  }
}
