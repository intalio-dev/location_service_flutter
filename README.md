## Usage
1. Import the necessary packages:

```dart
  location_service:
    git:
      url: https://source.intalio.com/etgs-qatar/shared_group/flutter_packages/location_service_flutter.git
      ref: main
```

2. Permission:

```dart
add permission in android manifest
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

add permission in ios Podfile
    target.build_configurations.each do |config|
        #  Preprocessor definitions can be found at: https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler_apple/ios/Classes/PermissionHandlerEnums.h
            config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
            '$(inherited)',
            ## dart: [PermissionGroup.location, PermissionGroup.locationAlways, PermissionGroup.locationWhenInUse]
            'PERMISSION_LOCATION=1',
        ]
    end
```

3. Implementation:

```dart
    in main or splash
    final locationServiceConfig = LocationServiceConfig(
        periodicRefreshDuration: const Duration(minutes: 5),
        triggerDelayedRefreshDuration: const Duration(seconds: 30),
        enablePeriodicRefresh: true,
        requestToOpenLocationCount: 3,
        onError: (error, isTriggered, isPermissionDenied) {
            // Handle error
            if (kDebugMode) {
              print('Error: $error');
            }
        },
    );
    
    await LocationService.init(config: locationServiceConfig);

```
4.  Functions:

```dart
LocationService.getMyLocation(); // return Position
LocationService.getCurrentLocation(); // return LocationData
LocationService.calculateDistance(); // return String
LocationService.myLocationStream();
```
5. Classes:

```dart
GlobalLatLng(); // use it to pass latitude and longitude
LocationData(); // use it to pass state, country and error
```