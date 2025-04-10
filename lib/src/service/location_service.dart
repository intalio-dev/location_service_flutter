import 'dart:async';
import 'dart:io';
import 'dart:math' show cos, sqrt, asin;
import 'package:core_utils/core_utils.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_service/src/configs/location_service_config.dart';
import 'package:location_service/src/models/global_latlng.dart';
import 'package:location_service/src/models/location_data.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  static int _requestToOpenLocationCounter = 0;

  static Future<bool> get isLocationPermissionGranted async {
    var permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<bool> get isLocationServiceOpen async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  static GlobalLatLng? get myLocation {
    return myPosition == null
        ? null
        : GlobalLatLng(myPosition!.latitude, myPosition!.longitude);
  }

  static Position? _myPosition;

  static Position? get myPosition => _myPosition;

  static bool _requireRefresh(bool isTriggered) {
    if (myPosition == null) return true;
    return (isTriggered &&
            DateTime.now().difference(myPosition!.timestamp) >
                _config.triggerDelayedRefreshDuration) ||
        (_config.enablePeriodicRefresh &&
            DateTime.now().difference(myPosition!.timestamp) >
                _config.periodicRefreshDuration);
  }

  // ignore: unused_field
  static late Timer _delayedRefreshTimer;

  static bool _isGettingLocation = false;
  static late final LocationServiceConfig _config;

  static Future<void> init({required LocationServiceConfig config}) async {
    try {
      _config = config;
      var hasPermission = await handlePermission();
      if (hasPermission) {
        _isGettingLocation = true;
        _myPosition = await Geolocator.getCurrentPosition();
        _isGettingLocation = false;
      }
    } catch (e) {
      _config.onError(e, false, false);
      _isGettingLocation = false;
    }
    AppLogs.debugLog("Initial: $_myPosition",
        runtimeType: _instance.runtimeType);
    if (config.enablePeriodicRefresh) {
      _delayedRefreshTimer = Timer.periodic(
        config.periodicRefreshDuration,
        (timer) async {
          if (_requireRefresh(false)) {
            await _delayedRefresh();
          }
        },
      );
    }
  }

  static Future<bool> handlePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.locationWhenInUse.request();
      if (status.isDenied) {
        return false;
      }
    }
    if (Platform.isIOS) {
      final status = await Permission.locationWhenInUse.request();
      if (status.isDenied) {
        return false;
      }
    }
    return true;
  }

  static Future<Position?> _delayedRefresh({bool isTriggered = false}) async {
    try {
      if ((_config.customDelayedRefreshCondition?.call() ?? true) &&
          !_isGettingLocation &&
          _requireRefresh(isTriggered) &&
          await handlePermission()) {
        if (!await isLocationServiceOpen &&
            _requestToOpenLocationCounter <
                _config.requestToOpenLocationCount) {
          _requestToOpenLocationCounter++;
        } else {
          throw const LocationServiceDisabledException();
        }
        _isGettingLocation = true;
        _myPosition = await Geolocator.getCurrentPosition();
        _isGettingLocation = false;
        AppLogs.debugLog(
            "delayedRefresh(isTriggered = $isTriggered): $_myPosition",
            runtimeType: _instance.runtimeType);
      }
    } catch (e) {
      _config.onError(e, isTriggered, false);
      _isGettingLocation = false;
      return null;
    }
    return _myPosition;
  }

  static Future<Position?> triggerDelayedRefresh() async {
    return await _delayedRefresh(isTriggered: true);
  }

  static Future<Position?> getMyLocation() async {
    try {
      var hasPermission = await handlePermission();
      if (!hasPermission) {
        _config.onError(null, false, true);
        return null;
      }
      if (!_isGettingLocation) {
        _isGettingLocation = true;
        _myPosition = await Geolocator.getCurrentPosition();
        _isGettingLocation = false;
      }
      while (_isGettingLocation) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      AppLogs.successLog("Instant Refresh: $_myPosition",
          runtimeType: _instance.runtimeType);
    } catch (e) {
      _config.onError(e, false, false);
      _isGettingLocation = false;
      return null;
    }
    return _myPosition;
  }

  static Future<LocationData?> getCurrentLocation() async {
    LocationData locationData = LocationData();

    try {
      if (_myPosition == null) {
        await getMyLocation();
      }
      List<Placemark> placeMarks = await placemarkFromCoordinates(
          _myPosition!.latitude, _myPosition!.longitude);

      if (placeMarks.isNotEmpty) {
        Placemark placeMark = placeMarks[0];
        locationData.country = placeMark.country ?? 'Unknown';
        locationData.state = placeMark.administrativeArea ?? 'Unknown';
      } else {
        locationData.error = 'No placeMarks found';
      }
    } catch (e) {
      locationData.error = e.toString();
    }

    return locationData;
  }

  static String calculateDistance({
    required GlobalLatLng fromLocation,
    required GlobalLatLng toLocation,
  }) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((toLocation.latitude - fromLocation.latitude) * p) / 2 +
        c(fromLocation.latitude * p) *
            c(toLocation.latitude * p) *
            (1 - c((toLocation.longitude - fromLocation.longitude) * p)) /
            2;
    return (12742 * asin(sqrt(a))).toStringAsFixed(2);
  }

  static late Stream<Position> _positionStream;

  static Future<void> myLocationStream({
    required GlobalLatLng myLocation,
    required Function(GlobalLatLng) newLocation,
  }) async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    );

    _positionStream.listen((Position position) {
      if (position.latitude.toStringAsFixed(2) !=
              myLocation.latitude.toStringAsFixed(2) ||
          position.longitude.toStringAsFixed(2) !=
              myLocation.longitude.toStringAsFixed(2)) {
        AppLogs.successLog(
            'New location: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}');
        Throttle.run(() {
          newLocation(GlobalLatLng(position.latitude, position.longitude));
        });
      }
    });
  }
}
