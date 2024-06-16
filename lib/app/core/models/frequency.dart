import 'package:equatable/equatable.dart';

class Frequency extends Equatable {
  const Frequency({
    required this.name,
    required this.value,
  });

  factory Frequency.empty() {
    return const Frequency(
      name: '',
      value: 0,
    );
  }

  factory Frequency.fromMap(Map<String, dynamic> map) {
    return Frequency(
      name: map["name"],
      value: map["value"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "value": value,
    };
  }

  static List<Frequency> build([
    int v60 = 0,
    int v250 = 0,
    int v1k = 0,
    int v3k = 0,
    int v6k = 0,
    int v16k = 0,
  ]) =>
      [
        Frequency(name: "60", value: v60),
        Frequency(name: "250", value: v250),
        Frequency(name: "1k", value: v1k),
        Frequency(name: "3k", value: v3k),
        Frequency(name: "6k", value: v6k),
        Frequency(name: "16k", value: v16k),
      ];

  /* 
ROCK
•  60 Hz: +2 dB
•  250 Hz: 0 dB 
•  1 kHz: +1 
•  3 kHz: +2
•  6 kHz: +2 dB
•  16 kHz: +1 dB

POP
•  60 Hz: +2 dB
•  250 Hz: +1 dB 
•  1 kHz: +2 dB
•  3 kHz: +3 dB
•  6 kHz: +2 dB
•  16 kHz: +2 dB

CLASSICO
•  60 Hz: +1 dB
•  250 Hz: 0 dB 
•  1 kHz: +1 dB
•  3 kHz: +2 dB
•  6 kHz: +1
•  16 kHz: +1

JAZZ
•  60 Hz: +1
•  250 Hz: 0 dB
•  1 kHz: +2 dB
•  3 kHz: +3 dB
•  6 kHz: +2 dB
•  16 kHz: +1 dB

DANCE MUSIC
•  60 Hz: +4 dB
•  250 Hz: +2 dB
•  1 kHz: 0 dB 
•  3 kHz: +3 dB
•  6 kHz: +3 dB
•  16 kHz: +2 dB
  */

  final String name;
  final int value;

  Frequency copyWith({
    String? name,
    int? value,
  }) {
    return Frequency(
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }

  @override
  List<Object?> get props => [
        name,
        value,
      ];
}
