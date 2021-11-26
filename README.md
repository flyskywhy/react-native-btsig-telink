# React Native Bluetooth SIG Telink

[![npm version](http://img.shields.io/npm/v/react-native-btsig-telink.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")
[![npm downloads](http://img.shields.io/npm/dm/react-native-btsig-telink.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")
[![npm licence](http://img.shields.io/npm/l/react-native-btsig-telink.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")
[![Platform](https://img.shields.io/badge/platform-ios%20%7C%20android-989898.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")

Component implementation for Bluetooth SIG Mesh SDK of Telink.

## Install
For RN >= 0.60 and Android SDK >= 29
```shell
npm i --save react-native-btsig-telink
```

For RN >= 0.60 and Android SDK < 29
```shell
npm i --save react-native-btsig-telink@1.2.x
```

For RN < 0.60
```shell
npm i --save react-native-btsig-telink@1.0.x
```

### Android
For RN < 0.60, need files edited below:

In `android/app/build.gradle`
```
dependencies {
    implementation project(':react-native-btsig-telink')
}
```

In `android/app/src/main/java/com/YourProject/MainApplication.java`
```
import com.telink.sig.mesh.TelinkBtSigPackage;
...
    new TelinkBtSigPackage(),
```

In `android/settings.gradle`
```
include ':react-native-btsig-telink'
project(':react-native-btsig-telink').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-btsig-telink/android')
```

Sometimes will meet compile error `java.io.FileNotFoundException: SOME_PATH/.externalNativeBuild/cmake/SOME_PATH/android_gradle_build.json (The system cannot find the file specified)` after upgrade this pacakge by `npm install`, can solve it by [add ` --rerun-tasks` to your gradlew command](https://stackoverflow.com/a/68126063/6318705) like

    ./android/gradlew assembleDebug --rerun-tasks -p ./android/

### iOS
Open `SigMeshOC/SigMeshOC.xcodeproj` by Xcode, in 'Signing & Capabilities' of Target 的 'SigMeshOC', choose `Team` to your Apple ID, then close Xcode and:

    cd node_modules/react-native-btsig-telink/SigMeshOC/
    ./Script.sh

results:
```
SigMeshOC/Build/Products/SigMeshOC/Release-iphoneos/SigMeshOC.framework/
```

For RN >= 0.60, in `ios/Podfile`
```
  pod 'SigMeshOC', :path => '../node_modules/react-native-btsig-telink/SigMeshOC'
```

For RN < 0.60, in `ios/Podfile`
```
  pod 'SigMeshOC', :path => '../node_modules/react-native-btsig-telink/SigMeshOC'
  pod 'RNBtSigTelink', :path => '../node_modules/react-native-btsig-telink'
```

For RN < 0.60 and RN >= 0.60

    cd ios
    pod install

## fastBind
If you want fastBind, you need put the cpsData of your device into `android/src/main/java/com/telink/sig/mesh/PrivateDevice.java` and `DeviceTypeModel` in `SigMeshOC/SigMeshOC/Model.m`.

## Usage

```jsx
import React from 'react';
import { View } from 'react-native';
import meshModule from 'react-native-btsig-telink';

export default class MeshModuleExample extends React.Component {
    constructor(props) {
        super(props);
        meshModule.passthroughMode = {
            silan: [
                1,
                7,
            ],
            sllc: [
                30848,
            ],
        };
    }

    componentDidMount() {
        meshModule.addListener('leScan', this.onLeScan);
        meshModule.doInit();
        meshModule.startScan({
            isSingleNode: false, // if true, will stop scan after found one device
            timeoutSeconds: 10,
        });
    }

    onLeScan = data => console.warn(data)

    render() {
        return (
            <View/>
        );
    }
}
```

Please discover more in `index.native.js`.

## Donate
To support my work, please consider donate.

- ETH: 0xd02fa2738dcbba988904b5a9ef123f7a957dbb3e

- <img src="https://raw.githubusercontent.com/flyskywhy/flyskywhy/main/assets/alipay_weixin.png" width="500">
