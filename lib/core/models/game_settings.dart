import '../engine/game_rules.dart';

/// Player preferences. Mobile-first: what a tap does is a setting, not a
/// gesture you have to hold for.
class GameSettings {
  const GameSettings({
    this.defaultInputMode = InputMode.reveal,
    this.haptics = true,
    this.animations = true,
    this.longPressToFlag = true,
    this.confirmSalvage = true,
  });

  /// Which action a plain tap performs when a run starts.
  final InputMode defaultInputMode;

  final bool haptics;

  /// Off for players who find the reveal ripple distracting, and for anyone
  /// running the phone in a reduced-motion setup.
  final bool animations;

  /// Long-press does the other action, so both are reachable without visiting
  /// the toggle.
  final bool longPressToFlag;

  /// Ask before cashing in a batch. Off for players who want the speed.
  final bool confirmSalvage;

  GameSettings copyWith({
    InputMode? defaultInputMode,
    bool? haptics,
    bool? animations,
    bool? longPressToFlag,
    bool? confirmSalvage,
  }) {
    return GameSettings(
      defaultInputMode: defaultInputMode ?? this.defaultInputMode,
      haptics: haptics ?? this.haptics,
      animations: animations ?? this.animations,
      longPressToFlag: longPressToFlag ?? this.longPressToFlag,
      confirmSalvage: confirmSalvage ?? this.confirmSalvage,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultInputMode': defaultInputMode.name,
    'haptics': haptics,
    'animations': animations,
    'longPressToFlag': longPressToFlag,
    'confirmSalvage': confirmSalvage,
  };

  static GameSettings fromJson(Map<String, dynamic> json) {
    return GameSettings(
      defaultInputMode:
          InputMode.values.asNameMap()[json['defaultInputMode']] ??
          InputMode.reveal,
      haptics: json['haptics'] as bool? ?? true,
      animations: json['animations'] as bool? ?? true,
      longPressToFlag: json['longPressToFlag'] as bool? ?? true,
      confirmSalvage: json['confirmSalvage'] as bool? ?? true,
    );
  }
}
