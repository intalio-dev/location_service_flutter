typedef LocationErrorCallback = void Function(
  Object? e,
  bool isTriggeredManually,
  bool noPermissionError,
);

class LocationServiceConfig {
  final LocationErrorCallback onError;

  final Duration periodicRefreshDuration;

  final Duration triggerDelayedRefreshDuration;
  final bool enablePeriodicRefresh;

  final bool Function()? customDelayedRefreshCondition;

  final int requestToOpenLocationCount;

  const LocationServiceConfig({
    required this.onError,
    required this.enablePeriodicRefresh,
    this.periodicRefreshDuration = const Duration(minutes: 20),
    this.triggerDelayedRefreshDuration = const Duration(minutes: 5),
    this.customDelayedRefreshCondition,
    this.requestToOpenLocationCount = 1,
  });
}
