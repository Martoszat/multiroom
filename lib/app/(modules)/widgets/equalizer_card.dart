import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../core/extensions/build_context_extensions.dart';
import '../../core/extensions/number_extensions.dart';
import '../../core/models/equalizer_model.dart';
import '../../core/models/frequency.dart';
import '../../core/widgets/app_button.dart';

class EqualizerCard extends StatefulWidget {
  const EqualizerCard({
    super.key,
    required this.equalizers,
    required this.currentEqualizer,
    required this.onChangeEqualizer,
    required this.onUpdateFrequency,
  });

  final List<EqualizerModel> equalizers;
  final EqualizerModel currentEqualizer;
  final Function(Frequency) onUpdateFrequency;
  final Function() onChangeEqualizer;

  @override
  State<EqualizerCard> createState() => _EqualizerCardState();
}

class _EqualizerCardState extends State<EqualizerCard> {
  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Equalizador",
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            12.asSpace,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    type: ButtonType.secondary,
                    leading: const Icon(Icons.equalizer_rounded),
                    key: ValueKey(widget.currentEqualizer.name),
                    text: widget.currentEqualizer.name,
                    onPressed: widget.onChangeEqualizer,
                  ),
                ),
              ],
            ),
            18.asSpace,
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.currentEqualizer.frequencies.length,
                  itemBuilder: (_, index) {
                    final current = widget.currentEqualizer.frequencies[index];

                    return Column(
                      children: [
                        Text(
                          "${current.name} db",
                          style: context.textTheme.bodyMedium,
                        ),
                        Watch(
                          (_) => Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                min: -100,
                                max: 100,
                                divisions: 200 ~/ 5,
                                value: current.value.toDouble(),
                                onChanged: (v) {
                                  widget.onUpdateFrequency(
                                    current.copyWith(value: v.toInt()),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Text(
                          "${current.value.round()}",
                          style: context.textTheme.labelLarge,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
