import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:routefly/routefly.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../injector.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../core/models/zone_group_model.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../controllers/device_configuration_page_controller.dart';
import '../widgets/device_config_header.dart';
import '../widgets/groups_expandable_card.dart';
import '../widgets/zones_expandable_card.dart';

class DeviceConfigurationPage extends StatefulWidget {
  const DeviceConfigurationPage({super.key});

  @override
  State<DeviceConfigurationPage> createState() => _DeviceConfigurationPageState();
}

class _DeviceConfigurationPageState extends State<DeviceConfigurationPage> {
  final _controller = injector.get<DeviceConfigurationPageController>();

  final _zonesExpandableController = ExpandableController(initialExpanded: false);
  final _groupsExpandableController = ExpandableController(initialExpanded: false);

  void _showAddZoneGroupBottomSheet(ZoneGroupModel group) {
    context.showCustomModalBottomSheet(
      isScrollControlled: false,
      child: Watch(
        (_) => ListView.builder(
          shrinkWrap: true,
          itemCount: _controller.availableZones.value.length,
          itemBuilder: (_, index) {
            final zone = _controller.availableZones.value[index];

            return ListTile(
              title: Text(zone.label),
              trailing: const Icon(Icons.add_circle_rounded),
              onTap: () {
                _controller.onAddZoneToGroup(group, zone);
                Routefly.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _controller.init(dev: Routefly.query.arguments);
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (_) => LoadingOverlay(
        state: _controller.state,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Configuração do dispositivo"),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  DeviceConfigHeader(
                    device: _controller.device.value,
                    deviceName: _controller.deviceName.value,
                    isEditingDevice: _controller.isEditingDevice.value,
                    onChangeDeviceName: _controller.deviceName.set,
                    toggleEditingDevice: _controller.toggleEditingDevice,
                    onDeleteDevice: _controller.onRemoveDevice,
                  ),
                  8.asSpace,
                  ZonesExpandableCard(
                    expandableController: _zonesExpandableController,
                    zones: _controller.device.value.zoneWrappers,
                    editingWrapper: _controller.editingWrapper.value,
                    editingZone: _controller.editingZone.value,
                    isEditing: _controller.isEditingZone.value,
                    onChangeZoneMode: _controller.onChangeZoneMode,
                    onChangeZoneName: _controller.onChangeZoneName,
                    toggleEditingZone: _controller.toggleEditingZone,
                  ),
                  8.asSpace,
                  GroupsExpandableCard(
                    isEditing: _controller.isEditingGroup.value,
                    groups: _controller.device.value.groups,
                    expandableController: _groupsExpandableController,
                    editingGroup: _controller.editingGroup.value,
                    onTapAddGroup: _showAddZoneGroupBottomSheet,
                    onTapRemoveZone: _controller.onRemoveZoneFromGroup,
                    toggleEditingGroup: _controller.toggleEditingGroup,
                    onChangeGroupName: _controller.onChangeGroupName,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _zonesExpandableController.dispose();
    _controller.dispose();

    super.dispose();
  }
}
