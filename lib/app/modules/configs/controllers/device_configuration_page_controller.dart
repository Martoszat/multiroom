import 'dart:async';

import 'package:collection/collection.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../injector.dart';
import '../../../core/enums/mono_side.dart';
import '../../../core/enums/page_state.dart';
import '../../../core/enums/zone_mode.dart';
import '../../../core/extensions/list_extensions.dart';
import '../../../core/interactor/controllers/base_controller.dart';
import '../../../core/interactor/controllers/socket_mixin.dart';
import '../../../core/interactor/repositories/settings_contract.dart';
import '../../../core/models/device_model.dart';
import '../../../core/models/zone_group_model.dart';
import '../../../core/models/zone_model.dart';
import '../../../core/models/zone_wrapper_model.dart';
import '../../../core/utils/mr_cmd_builder.dart';

class DeviceConfigurationPageController extends BaseController with SocketMixin {
  DeviceConfigurationPageController() : super(InitialState());

  final settings = injector.get<SettingsContract>();

  final deviceName = "".toSignal(debugLabel: "deviceName");
  final device = DeviceModel.empty().toSignal(debugLabel: "device");
  final editingWrapper = ZoneWrapperModel.empty().toSignal(debugLabel: "editingWrapper");
  final editingGroup = ZoneGroupModel.empty().toSignal(debugLabel: "editingGroup");
  final editingZone = ZoneModel.empty().toSignal(debugLabel: "editingZone");
  final isEditingDevice = false.toSignal(debugLabel: "isEditingDevice");
  final isEditingZone = false.toSignal(debugLabel: "isEditingZone");
  final isEditingGroup = false.toSignal(debugLabel: "isEditingGroup");
  final availableZones = listSignal([], debugLabel: "availableZones");
  final maxVolumeL = 100.toSignal(debugLabel: "maxVolumeL");
  final maxVolumeR = 100.toSignal(debugLabel: "maxVolumeR");

  Future<void> init({required DeviceModel dev}) async {
    device.value = dev;
    deviceName.value = dev.name;

    try {
      await initSocket(ip: dev.ip);
      await run(_updateDeviceData);
    } catch (exception) {
      logger.e(exception);
      if (exception is Exception) {
        setError(exception);
      } else {
        setError(Exception(exception));
      }
    }

    disposables.addAll([
      effect(() {
        final differenceZones =
            device.value.zones.toSet().difference(device.value.groups.expand((g) => g.zones).toSet());

        availableZones.value = differenceZones.toList();
      }),
      effect(() {
        settings.saveDevice(device: device.value);
      })
    ]);
  }

  void toggleEditingDevice() {
    isEditingDevice.value = isEditingDevice.value == false;

    if (isEditingDevice.value == false) {
      device.value = device.peek().copyWith(name: deviceName.value);
    }
  }

  Future<void> onAddZoneToGroup(ZoneGroupModel group, ZoneModel zone) async {
    try {
      if (group.zones.containsZone(zone)) {
        // Show error
      }

      final List<ZoneGroupModel> groups = List.from(device.peek().groups);
      final updatedZones = [...group.zones, zone];

      device.value = device.peek().copyWith(
            groups: groups.withReplacement(
              (g) => g.id == group.id,
              group.copyWith(
                zones: updatedZones,
              ),
            ),
          );

      await socketSender(
        MrCmdBuilder.setGroup(
          group: group,
          zones: updatedZones,
        ),
      );
    } catch (exception) {
      if (exception is Exception) {
        setError(exception);
      } else {
        setError(Exception(exception));
      }
    }
  }

  Future<void> onRemoveZoneFromGroup(ZoneGroupModel group, ZoneModel zone) async {
    if (group.zones.containsZone(zone) == false) {
      return;
    }

    final List<ZoneGroupModel> groups = List.from(device.peek().groups);
    final List<ZoneModel> tempZones = List.from(group.zones);
    final idx = groups.indexOf(group);

    groups[idx] = groups[idx].copyWith(zones: tempZones..remove(zone));
    device.value = device.peek().copyWith(groups: groups);

    await socketSender(
      MrCmdBuilder.setGroup(
        group: groups[idx],
        zones: groups[idx].zones,
      ),
    );
  }

  Future<void> onChangeZoneMode(ZoneWrapperModel wrapper, bool isStereo) async {
    try {
      isEditingZone.value = false;
      editingZone.value = editingZone.initialValue;

      await socketSender(
        MrCmdBuilder.setZoneMode(
          zone: wrapper,
          mode: isStereo ? ZoneMode.stereo : ZoneMode.mono,
        ),
      );

      editingWrapper.value = wrapper.copyWith(mode: isStereo ? ZoneMode.stereo : ZoneMode.mono);

      device.value = device.peek().copyWith(
            zoneWrappers: device.peek().zoneWrappers.map((z) => z.id == wrapper.id ? editingWrapper.value : z).toList(),
          );

      _updateGroupZones(editingWrapper.value);
    } catch (exception) {
      if (exception is Exception) {
        setError(exception);
      } else {
        setError(Exception(exception));
      }
    }
  }

  void onChangeZoneName(ZoneModel zone, String value) {
    editingWrapper.value = editingWrapper.peek().copyWith(zone: zone.copyWith(name: value));
  }

  void onChangeGroupName(ZoneGroupModel group, String value) {
    editingGroup.value = editingGroup.value.copyWith(name: value);
  }

  void toggleEditingZone(ZoneWrapperModel wrapper, ZoneModel zone) {
    if (wrapper.id == editingWrapper.value.id && zone.id == editingZone.peek().id) {
      isEditingZone.value = !isEditingZone.peek();
    } else {
      isEditingZone.value = true;
      editingWrapper.value = wrapper;
      editingZone.value = zone;

      return;
    }

    if (isEditingZone.value == false) {
      device.value = device.peek().copyWith(
            zoneWrappers: device
                .peek()
                .zoneWrappers
                .map(
                  (z) => z.id == editingWrapper.peek().id ? editingWrapper.value : z,
                )
                .toList(),
          );

      _updateGroupZoneNames(switch (zone.side) {
        MonoSide.undefined => editingWrapper.peek().stereoZone,
        MonoSide.left => editingWrapper.peek().monoZones.left,
        MonoSide.right => editingWrapper.peek().monoZones.right,
      });

      editingZone.value = editingZone.initialValue;
      editingWrapper.value = editingWrapper.initialValue;
    }
  }

  void toggleEditingGroup(ZoneGroupModel group) {
    if (group.id == editingGroup.peek().id) {
      isEditingGroup.value = !isEditingGroup.peek();
    } else {
      isEditingGroup.value = true;
      editingGroup.value = group;

      return;
    }

    if (isEditingGroup.peek() == false) {
      device.value = device.peek().copyWith(
            groups: device
                .peek()
                .groups
                .map(
                  (z) => z.id == editingGroup.peek().id ? editingGroup.value : z,
                )
                .toList(),
          );

      editingGroup.value = editingGroup.initialValue;
    }
  }

  void onRemoveDevice() {
    settings.removeDevice(projectId: device.peek().projectId, deviceId: device.peek().serialNumber);
  }

  Future<void> onFactoryRestore() async {
    await socketSender(MrCmdBuilder.setDefaultConfigs);

    device.value = DeviceModel.builder(
      projectName: device.value.projectName,
      projectId: device.value.projectId,
      serialNumber: device.value.serialNumber,
      name: device.value.name,
      ip: device.value.ip,
      version: device.value.version,
      type: device.value.type,
    );

    await _updateDeviceData();
  }

  Future<void> onSetMaxVolume(ZoneWrapperModel wrapper) async {
    editingWrapper.value = wrapper.copyWith(
      zone: wrapper.isStereo
          ? wrapper.stereoZone.copyWith(
              maxVolumeRight: maxVolumeR.value,
              maxVolumeLeft: maxVolumeL.value,
            )
          : null,
      monoZones: wrapper.isStereo
          ? null
          : wrapper.monoZones.copyWith(
              left: wrapper.monoZones.left.copyWith(maxVolumeLeft: maxVolumeL.value),
              right: wrapper.monoZones.right.copyWith(maxVolumeRight: maxVolumeR.value),
            ),
    );

    device.value = device.peek().copyWith(
          zoneWrappers: device.peek().zoneWrappers.withReplacement(
                (w) => w.id == wrapper.id,
                editingWrapper.value,
              ),
        );

    try {
      await socketSender(MrCmdBuilder.setMaxVolume(
        zone: wrapper.monoZones.left,
        volumePercent: maxVolumeL.value,
      ));

      await socketSender(MrCmdBuilder.setMaxVolume(
        zone: wrapper.monoZones.right,
        volumePercent: maxVolumeR.value,
      ));
    } catch (exception) {
      setError(Exception("Erro ao definir volume máximo --> $exception"));
    }
  }

  Future<void> _updateDeviceData() async {
    device.value = device.peek().copyWith(
          zoneWrappers: await _getZones(),
          groups: await _getGroups(),
        );
  }

  void _updateGroupZoneNames(ZoneModel zone) {
    for (final group in device.peek().groups) {
      final zoneIndex = group.zones.indexWhere((z) => z.id == zone.id);

      if (zoneIndex != -1) {
        final List<ZoneGroupModel> groups = List.from(device.peek().groups);
        final List<ZoneModel> newZones = List.from(group.zones);
        final idx = groups.indexOf(group);

        newZones[zoneIndex] = zone;
        groups[idx] = groups[idx].copyWith(zones: newZones);
        device.value = device.peek().copyWith(groups: groups);

        break;
      }
    }
  }

  void _updateGroupZones(ZoneWrapperModel wrapper) {
    for (final group in device.value.groups) {
      final groupZones = group.zones.toSet();
      final wrapperZones = wrapper.isStereo ? {wrapper.monoZones.left, wrapper.monoZones.right} : {wrapper.stereoZone};

      final newZones = groupZones.intersection(wrapperZones);

      if (newZones.isEmpty) {
        continue;
      }

      final List<ZoneGroupModel> groups = List.from(device.peek().groups);
      final idx = groups.indexOf(group);

      groups[idx] = groups[idx].copyWith(zones: groupZones.difference(wrapperZones).toList());
      device.value = device.peek().copyWith(groups: groups);

      break;
    }
  }

  Future<List<ZoneWrapperModel>> _getZones() async {
    final zonesList = <ZoneWrapperModel>[];

    try {
      for (final wrapper in device.value.zoneWrappers) {
        final mode = MrCmdBuilder.parseResponse(await socketSender(MrCmdBuilder.getZoneMode(zone: wrapper.stereoZone)));

        final maxVolR = await _getZoneMaxVol(wrapper.monoZones.right);
        final maxVolL = await _getZoneMaxVol(wrapper.monoZones.left);

        final setWrapper = wrapper.copyWith(
          mode: mode.toUpperCase() == "STEREO" ? ZoneMode.stereo : ZoneMode.mono,
          zone: wrapper.stereoZone.copyWith(
            maxVolumeRight: MrCmdBuilder.fromDbToPercent(maxVolR),
          ),
          monoZones: wrapper.monoZones.copyWith(
            right: wrapper.monoZones.right.copyWith(
              maxVolumeRight: MrCmdBuilder.fromDbToPercent(maxVolR),
            ),
            left: wrapper.monoZones.left.copyWith(
              maxVolumeLeft: MrCmdBuilder.fromDbToPercent(maxVolL),
            ),
          ),
        );

        zonesList.add(setWrapper);
      }

      return zonesList;
    } on StateError {
      logger.w("No Modes (MODE) received");

      return <ZoneWrapperModel>[];
    }
  }

  Future<List<ZoneGroupModel>> _getGroups() async {
    try {
      final zonesMap = <int, List<ZoneModel>>{
        1: [],
        2: [],
        3: [],
      };
      final List<ZoneModel> zonesList = List.from(device.peek().zones);

      for (final grp in zonesMap.keys) {
        final zones = MrCmdBuilder.parseResponse(
          await socketSender(
            longRet: true,
            MrCmdBuilder.getGroup(groupId: grp),
          ),
        );

        if (zones.toLowerCase().contains("null")) {
          continue;
        }

        for (final z in zones.split(",")) {
          final zone = zonesList.getZoneById(z);

          if (zone == null) {
            continue;
          }

          zonesMap[grp].addIfAbsent(zone);
        }
      }

      final groupsList = <ZoneGroupModel>[];

      zonesMap.entries.forEachIndexed((index, entry) {
        groupsList.add(device.value.groups[index].copyWith(zones: entry.value));
      });

      return groupsList;
    } on StateError catch (e) {
      logger.w("No Groups (GRP) received");
      setError(Exception(e));

      return <ZoneGroupModel>[];
    } catch (exception) {
      logger.e(exception);
      setError(exception as Exception);

      return <ZoneGroupModel>[];
    }
  }

  Future<String> _getZoneMaxVol(ZoneModel zone) async {
    try {
      final response = await socketSender(
        MrCmdBuilder.getMaxVolume(zone: zone),
      );

      final parsedResponse = response.split(",").first.substring(response.indexOf("=") + 1);

      return parsedResponse;
    } catch (exception) {
      logger.e(exception);
      setError(exception as Exception);

      return "";
    }
  }

  @override
  void dispose() {
    super.dispose();
    mixinDispose();

    deviceName.value = deviceName.initialValue;
    device.value = device.initialValue;
    editingWrapper.value = editingWrapper.initialValue;
    editingGroup.value = editingGroup.initialValue;
    editingZone.value = editingZone.initialValue;
    isEditingDevice.value = isEditingDevice.initialValue;
    isEditingZone.value = isEditingZone.initialValue;
    isEditingGroup.value = isEditingGroup.initialValue;
    maxVolumeL.value = maxVolumeL.initialValue;
    maxVolumeR.value = maxVolumeR.initialValue;

    availableZones.value = <ZoneModel>[];
  }
}
