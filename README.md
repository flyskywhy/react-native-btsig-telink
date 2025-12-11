# React Native Bluetooth SIG Telink

[![npm version](http://img.shields.io/npm/v/react-native-btsig-telink.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")
[![npm downloads](http://img.shields.io/npm/dm/react-native-btsig-telink.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")
[![npm licence](http://img.shields.io/npm/l/react-native-btsig-telink.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")
[![Platform](https://img.shields.io/badge/platform-ios%20%7C%20android-989898.svg?style=flat-square)](https://npmjs.org/package/react-native-btsig-telink "View this project on npm")

Component implementation for Bluetooth SIG Mesh SDK of Telink.

## Install
For RN >= 0.60 and Android SDK >= 31 , must
```shell
npm i --save react-native-btsig-telink
```

For RN >= 0.60 and Android SDK >= 29 but < 31 , also can
```shell
npm i --save react-native-btsig-telink@2.x
```

For RN >= 0.60 and Android SDK < 29 , must
```shell
npm i --save react-native-btsig-telink@1.2.x
```

For RN < 0.60 , must
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

### iOS
    cd ios
    pod install

For RN < 0.60, add below in `ios/Podfile` before `pod install`
```
  pod 'RNBtSigTelink', :path => '../node_modules/react-native-btsig-telink'
```

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
        meshModule.netKey = YOUR_16_BYTES_NETKEY;
        meshModule.appKey = YOUR_16_BYTES_APPKEY;

        // you can save data comes from (provision then bind function) meshModule.configNode()
        // Promise into devicesSavedInRedux after onLeScan() , then `meshModule.devices = devicesSavedInRedux`
        // here befor meshModule.doInit() so that can auto connect them after APP restart.
        // // devicesSavedInRedux = [{
        // //     meshAddress: 1,
        // //     macAddress: 'AB:CD:EF:GH:IJ:KL',
        // //     elementCnt: 2,
        // //     dhmKey: [12, 34, 56...],
        // //     nodeInfo: [12, 34, 56, ...]
        // // }];
        // meshModule.devices = devicesSavedInRedux;

        // if you want 8KB/s not 42B/s
        //
        // also need change firmware:
        //     set EXTENDED_ADV_ENABLE to 1 in `vendor/common/mesh_config.h`
        //     (maybe) let is_not_use_extend_adv() return 0 in `vendor/common/mesh_node.c`
        //
        // change JS here:
        // meshModule.extendBearerMode = meshModule.EXTEND_BEARER_MODE.GATT_ADV;

        meshModule.doInit();
        meshModule.startScan({
            isSingleNode: false, // if true, will stop scan after found one device
            timeoutSeconds: 10,
        });
    }

    onLeScan = data => {
        // if you want data.productUUID here is same with your device's PID, you
        // should enable `PROVISION_FLOW_SIMPLE_EN` in your device's firmware code.
        console.warn(data);
    }

    render() {
        return (
            <View/>
        );
    }
}
```

Please discover more in `index.native.js`.

If ios, maybe you need disable `meshModule.idleMode()` by yourself, ref to comment in `RCT_EXPORT_METHOD(idleMode:(BOOL)disconnect)` of `ios/RNBtSigTelink.m`.

## fastBind
If you want fastBind, you can copy `PrivateDevice.js` to create your own and modify, then put `PrivateDevice.filterWithPid(PID).cpsData` into `configNode({cpsData})`, here `PID` comes from `productUUID` with `startScan()`.

You also need enable `PROVISION_FLOW_SIMPLE_EN` in firmware code.

The provision + bind time of 1 device, in telink sdk `3.1.0`, with fastBind is 7s and without fastBind is 20s, but in telink sdk `3.3.3.5`, with or without fastBind is almost the same 7s, so the fastBind is not important now, only except that you want data.productUUID in `onLeScan` to be same with your device's PID then you only need enable `PROVISION_FLOW_SIMPLE_EN` in firmware code.

## version
`react-native-btsig-telink@1.x` is based on telink sdk `3.1.0`.

`react-native-btsig-telink@2.x` and `@3.x` is based on telink sdk `3.3.3.5`.

`react-native-btsig-telink@4.x` suggest useAddressesInsteadOfGroup but default still false.

`react-native-btsig-telink@5.x` let useAddressesInsteadOfGroup default true.

## migrate from `react-native-btsig-telink@1.x` to `react-native-btsig-telink@2.x` or `@3.x`
Use `PrivateDevice.js` instead of `PrivateDevice.java` and `DeviceTypeModel` on iOS, ref to fastBind above.

`getFirmwareVersion()` is not working by default, ref to the comments of `canMeshOta =`.

To keep data usage after APP upgrade from `react-native-btsig-telink@1.x` based to `react-native-btsig-telink@2.x` based, data comes from (provision then bind function) `configNode()` still use `nodeInfo`, ref to `NodeInfo.js` which comes from `react-native-btsig-telink@1.x/android/src/main/java/com/telink/sig/mesh/model/NodeInfo.java`.

## compatibility
### connectivity
When device A is `3.1.0` and device B is `3.3.3.5`, direct connected is device B, if APP is `3.1.0`, then `sendCommand({meshAddress: 0xFFFF})` can't affect (mesh to) device B, but it's OK if APP is `3.3.3.5`.

### speed
Below table: despite `is_not_use_extend_adv()` return 0 or not; "delay_while" means user business code use `while` loop as precise delay; "bytes" means `MeshMessage.params`; "2nd device" means not direct connected device; 8KB/s and 42B/s tested by 300 bytes, no 8KB/s or 42B/s means "2 devices" not controlled.

PS: test also found, despite `is_not_use_extend_adv()` return 0 or not, not only not affect 8KB/s test result with 300 bytes, but also not affect OTA speed is still so high.

2 devices\APP                       | 3.3.3.5 GATT_ADV                                                                                 | 3.3.3.5 GATT_NONE                                                                                  | 3.1.0
:-:                                 |-                                                                                                 |-                                                                                                   |-
3.3.3.5 without EXTENDED_ADV_ENABLE | 8KB/s; 2nd device not controlled if delay_while too often                                        | 42B/s; 2nd device delay 3s if delay_while too often                                                | 2 devices not controlled if == 300 bytes; 2nd device not controlled even delay_while not often
3.3.3.5 with EXTENDED_ADV_ENABLE    | 8KB/s; 2nd device delay 3s if delay_while too often                                              | 42B/s; 2nd device delay 3s if delay_while too often, and 2nd device not controlled if == 300 bytes | 2 devices not controlled if == 300 bytes; 2nd device not controlled even delay_while not often
3.1.0                               | 2nd device not controlled if delay_while too often, and 2 devices not controlled if == 300 bytes | 42B/s                                                                                              | 42B/s

如下表格: 无关乎 `is_not_use_extend_adv()` 是否返回 0 ；"delay_while" 意为用户业务代码中用 `while` 死循环作为精确延时； “字节”意为 `MeshMessage.params` ；“第 2 个设备”意指非直连设备； 8KB/s 和 42B/s 都是使用 300 字节来测试的，如果不存在 8KB/s 或 42B/s 则表明“ 2 个设备”都不受控。

2 个设备\APP                     | 3.3.3.5 GATT_ADV                                                             | 3.3.3.5 GATT_NONE                                                                       | 3.1.0
:-:                             |-                                                                             |-                                                                                        |-
3.3.3.5 禁用 EXTENDED_ADV_ENABLE | 8KB/s; 如果 delay_while 太频繁则第 2 个设备不受控                                | 42B/s; 如果 delay_while 太频繁则第 2 个设备延后 3s 受控                                      | 如果 == 300 字节则 2 个设备都不受控; 甚至 delay_while 不频繁时第 2 个设备也不受控
3.3.3.5 使用 EXTENDED_ADV_ENABLE | 8KB/s; 如果 delay_while 太频繁则第 2 个设备延后 3s 受控                          | 42B/s; 如果 delay_while 太频繁则第 2 个设备延后 3s 受控，且如果此时 == 300 字节则第 2 个设备不受控 | 如果 == 300 字节则 2 个设备都不受控; 甚至 delay_while 不频繁时第 2 个设备也不受控
3.1.0                           | 如果 delay_while 太频繁则第 2 个设备不受控，且如果此时 == 300 字节则 2 个设备都不受控 | 42B/s                                                                                    | 42B/s

另：测试还发现，无关乎 `is_not_use_extend_adv()` 是否返回 0 ，除了不会影响 300 字节时测得 8KB/s ，而且也不会影响 OTA 速度仍然那么快。

To solve the problem of "2nd device delay 3s if delay_while too often", you should put

    blt_sdk_main_loop();

besides your delay_while code.

Because `blt_sdk_main_loop()` itself also cost some time, maybe you prefer `mesh_send_adv_in_connected()`:

    mesh_send_adv_in_connected();

    extern u32 adv_in_conn_tick;
    extern u32 blt_advExpectTime;
    void mesh_send_adv_in_connected()
    {
        if (BLS_LINK_STATE_CONN == blt_state) {
            if (clock_time_exceed(adv_in_conn_tick, 10 * 1000)) {
                adv_in_conn_tick = clock_time();
                mesh_send_adv2scan_mode(1);
            }
        } else if ((u32)(clock_time() - blt_advExpectTime) < BIT(31) && !blc_tlkEvent_pending ) {
            blt_send_adv2scan_mode(1);
        }
    }

## Donate
To support my work, please consider donate.

- ETH: 0xd02fa2738dcbba988904b5a9ef123f7a957dbb3e

- <img src="https://raw.githubusercontent.com/flyskywhy/flyskywhy/main/assets/alipay_weixin.png" width="500">
