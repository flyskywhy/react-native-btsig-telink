# React Native Bluetooth SIG Telink
Component implementation for Bluetooth SIG mesh SDK of Telink.

## Usage

    npm install react-native-btsig-telink --save

For RN < 0.60, run `react-native link react-native-btsig-telink`.

### iOS
Open `SigMeshOC/SigMeshOC.xcodeproj` by Xcode, in 'Signing & Capabilities' of Target 的 'SigMeshOC', choose `Team` to your Apple ID, then close Xcode and:

    cd node_modules/react-native-btsig-telink/SigMeshOC/
    ./Script.sh

results:
```
SigMeshOC/Build/Products/SigMeshOC/Release-iphoneos/SigMeshOC.framework/
```

Add bellow (after `pod 'Folly'`) into `ios/Podfile`
```
  pod 'SigMeshOC', :path => '../node_modules/react-native-btsig-telink/SigMeshOC'
```

    cd ios
    pod install

    import btsigTelink from 'react-native-btsig-telink';

