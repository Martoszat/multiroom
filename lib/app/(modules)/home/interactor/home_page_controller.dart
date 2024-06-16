import 'dart:async';

import 'package:flutter/material.dart';
import 'package:multi_dropdown/multiselect_dropdown.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../injector.dart';
import '../../../core/enums/page_state.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/interactor/controllers/base_controller.dart';
import '../../../core/interactor/controllers/socket_mixin.dart';
import '../../../core/interactor/repositories/settings_contract.dart';
import '../../../core/models/channel_model.dart';
import '../../../core/models/device_model.dart';
import '../../../core/models/equalizer_model.dart';
import '../../../core/models/frequency.dart';
import '../../../core/models/zone_model.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/mr_cmd_builder.dart';

class HomePageController extends BaseController with SocketMixin {
  HomePageController() : super(InitialState()) {
    localDevices.value = settings.devices;
    device.value = localDevices.first;
    currentEqualizer.value = equalizers.last;

    device.subscribe((value) async {
      if (value.isEmpty) {
        return;
      }

      // currentZone.value = value.zones.first;
    });

    currentZone.subscribe((newZone) async {
      if (newZone.isEmpty) {
        return;
      }

      // final idx = device.value.zones.indexWhere((zone) => currentZone.value.name == zone.name);
      // channels.set(newZone.channels);

      // untracked(() async {
      //   device.value.zones[idx] = newZone;

      //   if (currentZone.previousValue!.id != currentZone.value.id) {
      //     _logger.i("UPDATE ALL DATA");
      //     await run(_updateAllDeviceData);
      //   }
      // });
    });

    channels.subscribe((newValue) {
      untracked(() {
        channelController.setOptions(
          List.generate(
            newValue.length,
            (idx) => ValueItem(
              label: newValue[idx].name,
              value: idx,
            ),
          ),
        );
      });
    });

    equalizers.subscribe((newValue) {
      untracked(() {
        equalizerController.setOptions(
          List.generate(
            newValue.length,
            (idx) => ValueItem(
              label: newValue[idx].name,
              value: idx,
            ),
          ),
        );
      });
    });

    currentChannel.subscribe((channel) {
      if (channel.isEmpty) {
        return;
      }

      untracked(() {
        final id = int.parse(channel.id.numbersOnly);

        channelController.setSelectedOptions(
          [
            channelController.options.firstWhere(
              (opt) => opt.value == id - 1,
              orElse: () => channelController.options.first,
            ),
          ],
        );
      });
    });

    currentEqualizer.subscribe((equalizer) {
      if (equalizer.isEmpty /* || equalizer.name == currentEqualizer.value.name */) {
        return;
      }

      untracked(() {
        equalizerController.setSelectedOptions(
          [
            equalizerController.options.firstWhere(
              (opt) => opt.label == equalizer.name,
              orElse: () => equalizerController.options.firstWhere(
                (e) => e.label == "Custom",
                orElse: () => equalizerController.options.first,
              ),
            ),
          ],
        );
      });
    });
  }

  final settings = injector.get<SettingsContract>();

  final equalizers = listSignal<EqualizerModel>(
    [
      EqualizerModel.builder(name: "Rock", v60: 20, v250: 0, v1k: 10, v3k: 20, v6k: 20, v16k: 10),
      EqualizerModel.builder(name: "Pop", v60: 20, v250: 10, v1k: 20, v3k: 30, v6k: 20, v16k: 20),
      EqualizerModel.builder(name: "Clássico", v60: 10, v250: 0, v1k: 10, v3k: 20, v6k: 10, v16k: 10),
      EqualizerModel.builder(name: "Jazz", v60: 10, v250: 0, v1k: 20, v3k: 30, v6k: 20, v16k: 10),
      EqualizerModel.builder(name: "Dance Music", v60: 40, v250: 20, v1k: 0, v3k: 30, v6k: 30, v16k: 20),
      EqualizerModel.builder(name: "Custom"),
    ],
    debugLabel: "equalizers",
  );

  final channels = listSignal<ChannelModel>(
    [],
    debugLabel: "channels",
  );

  final localDevices = listSignal<DeviceModel>([], debugLabel: "device");
  final device = DeviceModel.empty().toSignal(debugLabel: "device");
  final currentZone = ZoneModel.empty().toSignal(debugLabel: "currentZone");
  final currentChannel = ChannelModel.empty().toSignal(debugLabel: "currentChannel");
  final currentEqualizer = EqualizerModel.empty().toSignal(debugLabel: "currentEqualizer");

  final _writeDebouncer = Debouncer(delay: Durations.short4);
  final channelController = MultiSelectController<int>();
  final equalizerController = MultiSelectController<int>();

  void setCurrentZone(ZoneModel zone) {
    currentZone.value = zone;
  }

  void setCurrentChannel(ChannelModel channel) {
    if (channel.id == currentChannel.value.id) {
      logger.i("SET CHANNEL [SAME CHANNEL] --> ${channel.id}");
      return;
    }

    final channelIndex = channels.indexWhere((c) => c.name == channel.name);
    final tempList = List<ChannelModel>.from(channels);

    tempList[channelIndex] = channel;

    currentZone.value = currentZone.value.copyWith(channels: tempList);
    currentChannel.value = channel;

    socketSender(
      MrCmdBuilder.setChannel(
        zone: currentZone.value,
        channel: channel,
      ),
    );
  }

  void setBalance(int balance) {
    currentZone.value = currentZone.value.copyWith(balance: balance);

    debounceSendCommand(
      MrCmdBuilder.setBalance(
        zone: currentZone.value,
        balance: balance,
      ),
    );
  }

  void setVolume(int volume) {
    currentZone.value = currentZone.value.copyWith(volume: volume);

    debounceSendCommand(
      MrCmdBuilder.setVolume(
        zone: currentZone.value,
        volume: volume,
      ),
    );
  }

  Future<void> setEqualizer(String equalizerName) async {
    if (equalizerName == currentEqualizer.value.name) {
      logger.i("SET EQUALIZER [SAME EQUALIZER] --> $equalizerName");
      return;
    }

    currentEqualizer.value = equalizers.firstWhere((e) => e.name == equalizerName);
    currentZone.value = currentZone.value.copyWith(equalizer: currentEqualizer.value);

    for (final freq in currentZone.value.equalizer.frequencies) {
      debounceSendCommand(
        MrCmdBuilder.setEqualizer(
          zone: currentZone.value,
          frequency: freq,
          gain: freq.value,
        ),
      );

      // Delay to avoid sending commands too fast
    }
  }

  void setFrequency(Frequency frequency) {
    final freqIndex = currentEqualizer.value.frequencies.indexWhere((f) => f.name == frequency.name);
    final tempList = List<Frequency>.from(currentEqualizer.value.frequencies);

    tempList[freqIndex] = currentEqualizer.value.frequencies[freqIndex].copyWith(value: frequency.value.toInt());

    currentEqualizer.value = EqualizerModel.custom(frequencies: tempList);
    currentZone.value = currentZone.value.copyWith(equalizer: currentEqualizer.value);

    debounceSendCommand(
      MrCmdBuilder.setEqualizer(
        zone: currentZone.value,
        frequency: frequency,
        gain: frequency.value,
      ),
    );
  }

  Future<void> debounceSendCommand(String cmd) async {
    _writeDebouncer(() async {
      try {
        await socketSender(cmd);
      } catch (exception) {
        setError(Exception("Erro no comando [$cmd] --> $exception"));
      }
    });
  }

  Future<void> _parseInfos(Map<String, String> params) async {
/*
  Params Response
  {SWM1L: (null), SWM1R: (null), SWM2L: (null), SWM2R: (null), SWM3L: (null), SWM3R: (null), SWM4L: (null), SWM4R: (null), SWM5L: (null), SWM5R: (null), SWM6L: (null), SWM6R: (null), SWM7L: (null), SWM7R: (null), SWM8L: (null), SWM8R: (null), SWS1: Z1, SWS2: Z1, SWS3: Z4, SWS4: Z4, SWS5: Z5, SWS6: Z6, SWS7: Z7, SWS8: Z8, VG1L: 47[%], VG1R: 47[%], VG2L: 100[%], VG2R: 100[%], VG3L: 50[%], VG3R: 50[%], VG4L: 100[%], VG4R: 100[%], VG5L: 100[%], VG5R: 100[%], VG6L: 100[%], VG6R: 100[%], VG7L: 100[%], VG7R: 100[%], VG8L: 100[%], VG8R: 100[%], EQ1L_32Hz: 80[0.1dB], EQ1R_32Hz: 80[0.1dB], EQ1L_64Hz: 60[0.1dB], EQ1R_64Hz: 60[0.1dB], EQ1L_125Hz: 60[0.1dB], EQ1R_125Hz: 60[0.1dB], EQ1L_250Hz: 60[0.1dB], EQ1R_250Hz: 60[0.1dB], EQ1L_500Hz: 60[0.1dB], EQ1R_500Hz: 60[0.1dB], EQ1L_1KHz: 60[0.1dB], EQ1R_1KHz: 60[0.1dB], EQ1L_2KHz: 60[0.1dB], EQ1R_2KHz: 60[0.1dB], EQ1L_4KHz: 60[0.1dB], EQ1R_4KHz: 60[0.1dB], EQ1L_8KHz: 60[0.1dB], EQ1R_8KHz: 60[0.1dB], EQ1L_16KHz: 60[0.1dB], EQ1R_16KHz: 60[0.1dB], EQ2L_32Hz: 1[0.1dB], EQ2R_32Hz: 1[0.1dB], EQ2L_64Hz: 1[0.1dB], EQ2R_64Hz: 1[0.1dB], EQ2L_125Hz: 1[0.1dB], EQ2R_125Hz: 1[0.1dB], EQ2L_250Hz: 1[0.1dB], EQ2R_250Hz: 1[0.1dB], EQ2L_500Hz: 1[0.1dB], EQ2R_500Hz: 1[0.1dB], EQ2L_1KHz: 1[0.1dB], EQ2R_1KHz: 1[0.1dB], EQ2L_2KHz: 1[0.1dB], EQ2R_2KHz: 1[0.1dB], EQ2L_4KHz: 1[0.1dB], EQ2R_4KHz: 1[0.1dB], EQ2L_8KHz: 1[0.1dB], EQ2R_8KHz: 1[0.1dB], EQ2L_16KHz: 1[0.1dB], EQ2R_16KHz: 1[0.1dB], EQ3L_32Hz: 1[0.1dB], EQ3R_32Hz: 1[0.1dB], EQ3L_64Hz: 1[0.1dB], EQ3R_64Hz: 1[0.1dB], EQ3L_125Hz: 1[0.1dB], EQ3R_125Hz: 1[0.1dB], EQ3L_250Hz: 1[0.1dB], EQ3R_250Hz: 1[0.1dB], EQ3L_500Hz: 1[0.1dB], EQ3R_500Hz: 1[0.1dB], EQ3L_1KHz: 1[0.1dB], EQ3R_1KHz: 1[0.1dB], EQ3L_2KHz: 1[0.1dB], EQ3R_2KHz: 1[0.1dB], EQ3L_4KHz: 1[0.1dB], EQ3R_4KHz: 1[0.1dB], EQ3L_8KHz: 1[0.1dB], EQ3R_8KHz: 1[0.1dB], EQ3L_16KHz: 1[0.1dB], EQ3R_16KHz: 1[0.1dB], EQ4L_32Hz: 0[0.1dB], EQ4R_32Hz: 0[0.1dB], EQ4L_64Hz: 0[0.1dB], EQ4R_64Hz: 0[0.1dB], EQ4L_125Hz: 0[0.1dB], EQ4R_125Hz: 0[0.1dB], EQ4L_250Hz: 0[0.1dB], EQ4R_250Hz: 0[0.1dB], EQ4L_500Hz: 0[0.1dB], EQ4R_500Hz: 0[0.1dB], EQ4L_1KHz: 0[0.1dB], EQ4R_1KHz: 0[0.1dB], EQ4L_2KHz: 0[0.1dB], EQ4R_2KHz: 0[0.1dB], EQ4L_4KHz: 0[0.1dB], EQ4R_4KHz: 0[0.1dB], EQ4L_8KHz: 0[0.1dB], EQ4R_8KHz: 0[0.1dB], EQ4L_16KHz: 0[0.1dB], EQ4R_16KHz: 0[0.1dB], EQ5L_32Hz: 0[0.1dB], EQ5R_32Hz: 0[0.1dB], EQ5L_64Hz: 0[0.1dB], EQ5R_64Hz: 0[0.1dB], EQ5L_125Hz: 0[0.1dB], EQ5R_125Hz: 0[0.1dB], EQ5L_250Hz: 0[0.1dB], EQ5R_250Hz: 0[0.1dB], EQ5L_500Hz: 0[0.1dB], EQ5R_500Hz: 0[0.1dB], EQ5L_1KHz: 0[0.1dB], EQ5R_1KHz: 0[0.1dB], EQ5L_2KHz: 0[0.1dB], EQ5R_2KHz: 0[0.1dB], EQ5L_4KHz: 0[0.1dB], EQ5R_4KHz: 0[0.1dB], EQ5L_8KHz: 0[0.1dB], EQ5R_8KHz: 0[0.1dB], EQ5L_16KHz: 0[0.1dB], EQ5R_16KHz: 0[0.1dB], EQ6L_32Hz: 0[0.1dB], EQ6R_32Hz: 0[0.1dB], EQ6L_64Hz: 0[0.1dB], EQ6R_64Hz: 0[0.1dB], EQ6L_125Hz: 0[0.1dB], EQ6R_125Hz: 0[0.1dB], EQ6L_250Hz: 0[0.1dB], EQ6R_250Hz: 0[0.1dB], EQ6L_500Hz: 0[0.1dB], EQ6R_500Hz: 0[0.1dB], EQ6L_1KHz: 0[0.1dB], EQ6R_1KHz: 0[0.1dB], EQ6L_2KHz: 0[0.1dB], EQ6R_2KHz: 0[0.1dB], EQ6L_4KHz: 0[0.1dB], EQ6R_4KHz: 0[0.1dB], EQ6L_8KHz: 0[0.1dB], EQ6R_8KHz: 0[0.1dB], EQ6L_16KHz: 0[0.1dB], EQ6R_16KHz: 0[0.1dB], EQ7L_32Hz: 0[0.1dB], EQ7R_32Hz: 0[0.1dB], EQ7L_64Hz: 0[0.1dB], EQ7R_64Hz: 0[0.1dB], EQ7L_125Hz: 0[0.1dB], EQ7R_125Hz: 0[0.1dB], EQ7L_250Hz: 0[0.1dB], EQ7R_250Hz: 0[0.1dB], EQ7L_500Hz: 0[0.1dB], EQ7R_500Hz: 0[0.1dB], EQ7L_1KHz: 0[0.1dB], EQ7R_1KHz: 0[0.1dB], EQ7L_2KHz: 0[0.1dB], EQ7R_2KHz: 0[0.1dB], EQ7L_4KHz: 0[0.1dB], EQ7R_4KHz: 0[0.1dB], EQ7L_8KHz: 0[0.1dB], EQ7R_8KHz: 0[0.1dB], EQ7L_16KHz: 0[0.1dB], EQ7R_16KHz: 0[0.1dB], EQ8L_32Hz: 0[0.1dB], EQ8R_32Hz: 0[0.1dB], EQ8L_64Hz: 0[0.1dB], EQ8R_64Hz: 0[0.1dB], EQ8L_125Hz: 0[0.1dB], EQ8R_125Hz: 0[0.1dB], EQ8L_250Hz: 0[0.1dB], EQ8R_250Hz: 0[0.1dB], EQ8L_500Hz: 0[0.1dB], EQ8R_500Hz: 0[0.1dB], EQ8L_1KHz: 0[0.1dB], EQ8R_1KHz: 0[0.1dB], EQ8L_2KHz: 0[0.1dB], EQ8R_2KHz: 0[0.1dB], EQ8L_4KHz: 0[0.1dB], EQ8R_4KHz: 0[0.1dB], EQ8L_8KHz: 0[0.1dB], EQ8R_8KHz: 0[0.1dB], EQ8L_16KHz: 0[0.1dB], EQ8R_16KHz: 0[0.1dB], PWR1L: ON, PWR1R: ON, PWR2L: ON, PWR2R: ON, PWR3L: ON, PWR3R: ON, PWR4L: ON, PWR4R: ON, PWR5L: ON, PWR5R: ON, PWR6L: ON, PWR6R: ON, PWR7L: ON, PWR7R: ON, PWR8L: ON, PWR8R: ON}
*/

    final modes = params.entries.where((entry) => entry.key.toUpperCase().startsWith("MODE"));

    // final zonesList = <ZoneWrapperModel>[];

    // for (final mode in modes) {
    //   ZoneWrapperModel zone = switch (mode.key) {
    //     "MODE1" => ZoneWrapperModel.builder(index: 1, name: "Zona 1"),
    //     "MODE2" => ZoneWrapperModel.builder(index: 2, name: "Zona 2"),
    //     "MODE3" => ZoneWrapperModel.builder(index: 3, name: "Zona 3"),
    //     "MODE4" => ZoneWrapperModel.builder(index: 4, name: "Zona 4"),
    //     "MODE5" => ZoneWrapperModel.builder(index: 5, name: "Zona 5"),
    //     "MODE6" => ZoneWrapperModel.builder(index: 6, name: "Zona 6"),
    //     "MODE7" => ZoneWrapperModel.builder(index: 7, name: "Zona 7"),
    //     "MODE8" => ZoneWrapperModel.builder(index: 8, name: "Zona 8"),
    //     _ => ZoneWrapperModel.empty(),
    //   };

    //   if (zone.isEmpty) {
    //     continue;
    //   }

    //   if (mode.value.toUpperCase() == "STEREO") {
    //     zone = zone.copyWith(mode: ZoneMode.stereo);
    //   } else {
    //     zone = zone.copyWith(mode: ZoneMode.mono);
    //   }

    //   zonesList.add(zone);
    // }

    // return zonesList;
  }

  Future<void> updateAllDeviceData() async {
    final channelStr = await socketSender(MrCmdBuilder.getChannel(zone: currentZone.value));

    final volume = await socketSender(MrCmdBuilder.getVolume(zone: currentZone.value));

    final balance = await socketSender(MrCmdBuilder.getBalance(zone: currentZone.value));

    final f32 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[0],
      ),
    );

    final f64 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[1],
      ),
    );

    final f125 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[2],
      ),
    );

    final f250 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[3],
      ),
    );

    final f500 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[4],
      ),
    );

    final f1000 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[5],
      ),
    );

    final f2000 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[6],
      ),
    );

    final f4000 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[7],
      ),
    );

    final f8000 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[8],
      ),
    );

    final f16000 = await socketSender(
      MrCmdBuilder.getEqualizer(
        zone: currentZone.value,
        frequency: currentZone.value.equalizer.frequencies[9],
      ),
    );

    currentChannel.value = channels.value.firstWhere(
      (c) => c.id.trim() == channelStr.trim(),
      orElse: () => currentChannel.value.copyWith(name: channelStr),
    );

    final equalizer = currentZone.value.equalizer;
    final newEqualizer = EqualizerModel.custom(
      frequencies: [
        equalizer.frequencies[0].copyWith(value: int.tryParse(f32) ?? equalizer.frequencies[0].value),
        equalizer.frequencies[1].copyWith(value: int.tryParse(f64) ?? equalizer.frequencies[1].value),
        equalizer.frequencies[2].copyWith(value: int.tryParse(f125) ?? equalizer.frequencies[2].value),
        equalizer.frequencies[3].copyWith(value: int.tryParse(f250) ?? equalizer.frequencies[3].value),
        equalizer.frequencies[4].copyWith(value: int.tryParse(f500) ?? equalizer.frequencies[4].value),
        equalizer.frequencies[5].copyWith(value: int.tryParse(f1000) ?? equalizer.frequencies[5].value),
        equalizer.frequencies[6].copyWith(value: int.tryParse(f2000) ?? equalizer.frequencies[6].value),
        equalizer.frequencies[7].copyWith(value: int.tryParse(f4000) ?? equalizer.frequencies[7].value),
        equalizer.frequencies[8].copyWith(value: int.tryParse(f8000) ?? equalizer.frequencies[8].value),
        equalizer.frequencies[9].copyWith(value: int.tryParse(f16000) ?? equalizer.frequencies[9].value),
      ],
    );

    equalizers[equalizers.indexWhere((e) => e.name == currentEqualizer.value.name)] = newEqualizer;
    currentEqualizer.value = newEqualizer;

    currentZone.value = currentZone.value.copyWith(
      volume: int.tryParse(volume) ?? currentZone.value.volume,
      balance: int.tryParse(balance) ?? currentZone.value.balance,
      equalizer: newEqualizer,
    );
  }
}
