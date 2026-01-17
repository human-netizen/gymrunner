# Android Release Notes (Gym Runner)

## Generate a keystore
```bash
keytool -genkey -v -keystore ~/gym_runner_release.keystore -alias gym_runner -keyalg RSA -keysize 2048 -validity 10000
```

## Configure signing
1) Create `android/key.properties` (do not commit):
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=gym_runner
storeFile=/absolute/path/to/gym_runner_release.keystore
```

2) Update `android/app/build.gradle`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

## Build release APK
```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Versioning
Update `pubspec.yaml`:
```
version: MAJOR.MINOR.PATCH+BUILD
```
Example: `1.0.1+2`
