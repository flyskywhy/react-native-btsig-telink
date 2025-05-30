const {
    AppState,
    NativeModules,
    DeviceEventEmitter,
    NativeEventEmitter,
    Platform
} = require('react-native');
const NativeModule = NativeModules.TelinkBtSig;
const tinycolor = require("tinycolor2");
const createNewFifo = require('fifo');
const MeshSigModel = require("./MeshSigModel");
const NodeInfo = require("./NodeInfo");
const {CompositionData} = require("./CompositionData");
const PrivateDevice = require("./PrivateDevice");
const Opcode = require("./Opcode");

class TelinkBtSig {
    static MESH_ADDRESS_MIN = 0x0001;
    static MESH_ADDRESS_MAX = 0x00FF;

    // 虽然 bluetooth SIG mesh 协议理论上一个 mesh 网络最多支持
    // 32767 个设备，不过一般比如植物照明工厂最多拥有两百多盏灯，差
    // 不多刚好一般蓝牙模块提供商代码中所写的最大地址 255 ，而且天猫
    // 或小米等相关产品的设备数都在 100 以内，由于设备数越多，需要设
    // 备上的 ram 越大，越贵，所以一般蓝牙模块提供商只会批量提供 ram
    // 刚够用 200 设备数左右的模块。
    // 另外，在 `telink_sig_mesh_sdk_v3.3.3.5/app/ios/document/TelinkSigMeshLib开放源代码版本SDK使用以及开发手册.docx`
    // 中提到地址范围是 1~0x7eff
    // static MESH_ADDRESS_MAX = 0x7EFF;
    // static MESH_ADDRESS_MAX = 0x7FFF;

    // since telink_sig_mesh_sdk_v3.3.3.5 increase the bytes per packet and speed,
    // act in concert with defaultAllGroupAddress and longCommandParams,
    // it's better to use meshAddresses in packet instead of group address.
    static useAddressesInsteadOfGroup = true;
    static PAR_VER_init = 1;
    static PAR_VER_useAddressesInsteadOfGroup = 2;
    static PAR_VER_useDurationInsteadOfAddresses = 3;

    static GROUP_ADDRESS_MIN = 0xC000;
    static GROUP_ADDRESS_MAX = 0xC0FF;
    // `telink_sig_mesh_sdk_v3.3.3.5/app/android/TelinkBleMesh/TelinkBleMesh/TelinkBleMeshDemo/src/main/java/com/telink/ble/mesh/model/Scene.java`
    // 中提到组地址范围是 C000 - 0xFEFF
    // static GROUP_ADDRESS_MAX = 0xFEFF;
    static GROUP_ADDRESS_MASK = 0x00FF;
    static HUE_MIN = 0;
    static HUE_MAX = 360;
    static SATURATION_MIN = 0;
    static SATURATION_MAX = 100;
    static BRIGHTNESS_MIN = 42; // 实测灯串不会随着亮度变化而改变颜色的最低亮度，比如 30 的话就代表 30% ，但也不建议为 0 ，否则上层代码如果将颜色作为亮度则会导致上层更改亮度时会把所有颜色变为黑、白或灰色
    static BRIGHTNESS_MAX = 100;

    // 如果 LED 中绿色灯珠容易烧坏，此处记录着实际（也就是经过下面的 whiteBalance 之后）发给灯珠不会烧坏的最大值，比如 65 代表 65/255
    // 纯绿色情况下的 g 值
    // 100% 153
    // 95%  135
    // 90%  119
    // 85%  103
    // 80%  89
    // 75%  76
    // 70%  65

    // 白色情况下的 r g b 值
    // 100% 255, 153, 61
    // 95%  225, 135, 54
    // 90%  199, 119, 47
    // 85%  173, 103, 41
    // 80%  149, 89,  35
    // 75%  127, 76,  30
    // 70%  109, 65,  26
    // static LED_GREEN_MAX = 103;
    static LED_GREEN_MAX = 255;

    static COLOR_TEMP_MIN = 5;
    static COLOR_TEMP_MAX = 100;
    static NODE_STATUS_OFF = 0;
    static NODE_STATUS_ON = 1;
    static NODE_STATUS_OFFLINE = -1;
    static RELAY_TIMES_MAX = 16;
    static DELAY_MS_AFTER_UPDATE_MESH_COMPLETED = 500;
    static DELAY_MS_COMMAND = 240;
    static ALARM_CREATE = 0;
    static ALARM_REMOVE = 1;
    static ALARM_UPDATE = 2;
    static ALARM_ENABLE = 3;
    static ALARM_DISABLE = 4;
    static ALARM_YEAR_ANY = 0x64;
    static ALARM_MONTH_ALL = 0b111111111111;
    static ALARM_DAY_ANY = 0;
    static ALARM_HOUR_ANY = 0x18;
    static ALARM_HOUR_RANDOM = 0x19;
    static ALARM_MINUTE_ANY = 0x3C;
    static ALARM_MINUTE_CYCLE_15 = 0x3D;
    static ALARM_MINUTE_CYCLE_20 = 0x3E;
    static ALARM_MINUTE_RANDOM = 0x3F;
    static ALARM_SECOND_ANY = 0x3C;
    static ALARM_SECOND_CYCLE_15 = 0x3D;
    static ALARM_SECOND_CYCLE_20 = 0x3E;
    static ALARM_SECOND_RANDOM = 0x3F;
    static ALARM_WEEK_ALL = 0b1111111;
    static ALARM_ACTION_TURN_OFF = 0;
    static ALARM_ACTION_TURN_ON = 1;
    static ALARM_ACTION_SCENE = 2;
    static ALARM_ACTION_NO = 0xF;
    static ALARM_TYPE_DAY = 0;
    static ALARM_TYPE_WEEK = 1;

    static commandFifoConsumer = undefined;
    // ref to getReliableMessageTimeout() in
    // android/src/main/java/com/telink/ble/mesh/core/networking/NetworkingController.java
    static DELAY_MS_CMD_RSP_TIMEOUT = 1280;

    // -1 ref to android/src/main/java/com/telink/ble/mesh/core/message/MeshMessage.java
    // 0 ref to ((vendorOpcodeResponse & 0xff) != 0) inTelinkSigMeshLib/TelinkSigMeshLib/Utils/SDKLibCommand.m
    // whether op_rsp is -1 or 0, it only affect APP SDK to determine if the command is rsp, it
    // will not affect FW because cb_par->op_rsp only can be the definition that match op in
    // telink_sig_mesh/vendor/comon/generic_model.c
    static OPCODE_INVALID = (Platform.OS === 'ios') ? 0 : -1;

    static passthroughMode = undefined; // 通过串口或者说自定义发送数据来控制蓝牙节点
    static gamma = [  // gamma 2.4 ，normal color ，据说较暗时颜色经 gamma 校正后会比较准
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,                                 // 0
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2,                                 // 16
        2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4,                                 // 32
        5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9,                                 // 48
        9, 10, 10, 10, 11, 11, 11, 12, 12, 13, 13, 14, 14, 14, 15, 15,                  // 64
        16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 22, 22, 23, 23, 24,                 // 80
        24, 25, 26, 26, 27, 28, 28, 29, 30, 30, 31, 32, 32, 33, 34, 35,                 // 96
        35, 36, 37, 38, 39, 39, 40, 41, 42, 43, 43, 44, 45, 46, 47, 48,                 // 112
        49, 50, 51, 52, 53, 53, 54, 55, 56, 57, 58, 59, 60, 62, 63, 64,                 // 128
        65, 66, 67, 68, 69, 70, 71, 73, 74, 75, 76, 77, 78, 80, 81, 82,                 // 144
        83, 85, 86, 87, 88, 90, 91, 92, 94, 95, 96, 98, 99, 100, 102, 103,              // 160
        105, 106, 108, 109, 111, 112, 114, 115, 117, 118, 120, 121, 123, 124, 126, 127, // 176
        129, 131, 132, 134, 136, 137, 139, 141, 142, 144, 146, 148, 149, 151, 153, 155, // 192
        156, 158, 160, 162, 164, 166, 167, 169, 171, 173, 175, 177, 179, 181, 183, 185, // 208
        187, 189, 191, 193, 195, 197, 199, 201, 203, 205, 207, 210, 212, 214, 216, 218, // 224
        220, 223, 225, 227, 229, 232, 234, 236, 239, 241, 243, 246, 248, 250, 253, 255  // 240
    ];
    // static gamma = [  // gamma 2.8 ，vivid color ，据说较明亮时颜色经 gamma 校正后会比较准
    //     0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,                                 // 0
    //     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,                                 // 16
    //     1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3,                                 // 32
    //     3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 6,                                 // 48
    //     6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 10, 10,                               // 64
    //     10, 11, 11, 12, 12, 12, 13, 13, 13, 14, 14, 15, 15, 16, 16, 17,                 // 80
    //     17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 24, 24, 25, 25,                 // 96
    //     26, 27, 27, 28, 29, 29, 30, 31, 31, 32, 33, 34, 34, 35, 36, 37,                 // 112
    //     38, 38, 39, 40, 41, 42, 43, 43, 44, 45, 46, 47, 48, 49, 50, 51,                 // 128
    //     52, 53, 54, 55, 56, 57, 58, 59, 60, 62, 63, 64, 65, 66, 67, 68,                 // 144
    //     70, 71, 72, 73, 75, 76, 77, 78, 80, 81, 82, 84, 85, 87, 88, 89,                 // 160
    //     91, 92, 94, 95, 97, 98, 100, 101, 103, 104, 106, 108, 109, 111, 112, 114,       // 176
    //     116, 117, 119, 121, 123, 124, 126, 128, 130, 131, 133, 135, 137, 139, 141, 143, // 192
    //     145, 147, 149, 151, 153, 155, 157, 159, 161, 163, 165, 167, 169, 171, 173, 176, // 208
    //     178, 180, 182, 185, 187, 189, 192, 194, 196, 199, 201, 203, 206, 208, 211, 213, // 224
    //     216, 218, 221, 223, 226, 228, 231, 234, 236, 239, 242, 244, 247, 250, 253, 255  // 240
    // ];
    static whiteBalance = { // 为了让灯串能够在低电压下（就可以低温了）保持足够亮度，需要不再按照 1:6:3 的比例来设置 rgb 的白平衡
        r: 1,
        g: 0.85,
        b: 0.4,
    };
    // static whiteBalance = { // cooler
    //     r: 1,
    //     g: 0.6,
    //     b: 0.24,
    // };
    // static whiteBalance = { // warmer
    //     r: 1,
    //     g: 0.5,
    //     b: 0.18,
    // };

    static longCommandParams = true; // 可以在一条命令中发送大量数据，无需拆分成许多小命令
    static MESH_CMD_ACCESS_LEN_MAX = 380;

    // 逻辑上能否通过蓝牙模块返回的在线状态或者开关灯等状态推理出在线状态
    static hasOnlineStatusNotify = true;
    // 物理上蓝牙模块是否支持返回在线状态
    static hasOnlineStatusNotifyRaw = false;

    static needRefreshMeshNodesBeforeConfig = false;
    static canConfigEvenDisconnected = true;
    static needClaimedBeforeConnect = true;
    static isClaiming = false;
    static needSceneSync = true;

    static del4GroupStillSendOriginGroupAddress = true;
    static defaultAllGroupAddress = 0xFFFF;
    static isSetNodeGroupAddrReturnAddresses = false;

    // 需要如下两个变量来保证韵律期间频发音量转亮度 changeBrightness() 的情况下也能正常 changeScene() ，
    // 否则在两串灯时， All 组，开启韵律后，切换效果很多时候只有一盏灯能切换效果，另外一盏没变
    static isSceneCadenceBusy = false;
    static allowSceneCadence = true;

    static isCreatingSceneParList = false;  // 为 true 时仅仅准备发给设备的数据，而不是真正发给设备
    static sceneParList = [];

    static netKey = '_16_BYTES_NETKEY';
    static appKey = '_16_BYTES_APPKEY';

    // 测试得：手机 mesh 地址不能设为 0 ，也不能设为 >= 32768
    // 分享相同蓝牙设备数据的两台手机各自的 APP 需要不同的手机 mesh 地址，否则无法同时控制设备。
    // 随机地址的好处：本来如果每次启动 (仅有 Android ？) APP 时使用与上次连接时相同的 meshAddressOfApp ，则需要
    // 很长时间才能连接上设备，除非将设备断电再上电才能不受相同 meshAddressOfApp 的影响，感觉好像设备中保存着上次连接的（或是
    // mesh_proxy_filter_add_adr 增加的白名单）手机地址与这次想要连接的手机地址相同的话，就需要很长时间才能连接上设备，而现在
    // 每次启动 APP 时使用一个随机 meshAddressOfApp 就能解决这个问题。
    // 随机地址的坏处：实际上设备中有一张 CRPL 表，里面针对每个短地址记录着 sno ，所以如果太多设备比如太多随机地址的手机 APP
    // 连过设备的话，可能 CRPL 无法再记录新的地址。这可能也解释了上面每次都能快速连接上设备——因为 CRPL 中新来地址的 sno 从 0 开始
    static meshAddressOfApp = this.MESH_ADDRESS_MAX + parseInt(Math.random() * 10000, 10);

    static devices = [];

    static EXTEND_BEARER_MODE = {
        // no extension
        // 42B/s
        NONE: 0,

        /// gatt only
        // 关闭 DLE 功能后， SDK 的 Access 消息是长度大于 15 字节才进行 segment 分包
        // 42B/s
        GATT: 1,

        /// gatt and adv
        // 打开 DLE 功能后， SDK 的 Access 消息是长度大于 229 字节才进行 segment 分包
        // also need change firmware:
        //     set EXTENDED_ADV_ENABLE to 1 in `vendor/common/mesh_config.h`
        //     (maybe) let is_not_use_extend_adv() return 0 in `vendor/common/mesh_node.c`
        // 8KB/s
        GATT_ADV: 2,
    };
    static extendBearerMode = this.EXTEND_BEARER_MODE.NONE;

    // after telink sig mesh sdk 3.2.1 , by default, not support
    // FirmwareUpdateInfoGetMessage (0x01B6) and startMeshOta() , only support startGattOta() ,
    // you should register on https://www.bluetooth.com/ then get mesh OTA code from telink,
    // before that, use getFwVerInNodeInfo() and NativeModule.startOta() instead,
    // and use valid (even canMeshOta is false) getFirmwareVersion() to get version then use
    // getNodeInfoWithNewFwVer() to update device.nodeInfo after NativeModule.startOta() resolved
    static canMeshOta = false;

    static provisionerSno = 0;
    static provisionerIvIndex = 0;

    static otaFileVersionOffset = 4;    // 把二进制固件作为一个字节数组看待的话，描述着版本号的第一个字节的数组地址
    static otaFileVersionLength = 2;    // 二进制固件中描述版本号用了几个字节

    static lastSceneSyncMeshAddress = undefined;

    // why manuallyCheckSystemLocation and manuallyRequestLocationPermissions?
    // because it's more convenient to deal with location privacy policy of Google Play
    // default is false
    static set manuallyCheckSystemLocation(isManually) {
        if (Platform.OS === 'android') {
            NativeModule.setManuallyCheckSystemLocation(isManually);
        }
    }

    static get manuallyCheckSystemLocation() {
        if (Platform.OS === 'android') {
            return NativeModule.getManuallyCheckSystemLocation();
        }
    }

    // default is false, if set to true, can use isLocationPermissionsGranted() and requestLocationPermissions() later,
    // if set to true and on Android 13, also need doInitAfterCheckPermissions() after them and doInit() to avoid crash
    // cause Android 13 is a shit.
    static set manuallyRequestLocationPermissions(isManually) {
        if (Platform.OS === 'android') {
            NativeModule.setManuallyRequestLocationPermissions(isManually);
        }
    }

    static get manuallyRequestLocationPermissions() {
        if (Platform.OS === 'android') {
            return NativeModule.getManuallyRequestLocationPermissions();
        }
    }

    static _handleAppStateChange(newState) {
        if (newState === 'active') {
            this.checkSystemLocation();
        }
    }

    static doInit() {
        if (Platform.OS === 'android') {
            // on Android 13, java onHostResume() will not be invoked, so use it to
            // call checkSystemLocation(), Android 13 is a shit!
            AppState.addEventListener('change', this._handleAppStateChange.bind(this));
        }

        NativeModule.doInit(this.netKey, this.appKey, this.meshAddressOfApp, this.devices.map(device => {
            // for debug
            // if (device.meshAddress === 1) {
            //     let nodeInfo = NodeInfo.from(this.hexString2ByteArray(device.nodeInfo));
            //     console.warn(nodeInfo.cpsData.toString());
            // }

            return { ...device,
                dhmKey: this.hexString2ByteArray(device.dhmKey),
                nodeInfo: this.hexString2ByteArray(device.nodeInfo),
            };

        }), this.provisionerSno, this.provisionerIvIndex,
        // telink sdk 3.1.0 实测发现，不管上面的 ivIndex ，甚至也不用管 sno ，而是每次打开 APP 时将这两者都设为 0 ，然后每次就都可以连接上了。
        // 唯一的例外是如果 APP 一直开在那里足够长时间，然后 sno 足够大时让 ivIndex 变成 1 后，就再也连不上了，而按照
        // int sno 溢出计算，这个“足够长时间”是好几年，而一般 APP 应用情景不可能连续开启几年，所以一般这两者都设为 0 就可以了。
        // 但有些应用场景里，设备可能与网关不停在交互比如提供电压信息等以便网关传给网页服务器，那么 sno 随着这些消息不停增加然后在较短时间内 ivIndex
        // 就增加了，此时 APP 可能就需要这个新的 ivIndex 来进行连接。

        // telink sdk 3.1.0 以下现象在 Android 上测了许多次，在 iOS 测得少一点，但也有此现象：
        // 0、不论之前 sno 是多少，（上面随机 meshAddressOfApp 所提到的额外好处？）再次用 sno 0 （会瞬间由手机上的 sdk store 变为 128）来打开手机，仍然能够连上蓝牙设备
        // （然后设备的 sno 从 128 开始 store 回手机，然后每隔 17 秒 store + 129 ）。
        // 1、代码中写死以 ivIndex 1 进行设备认领、连接，然后重启 APP 进行连接时从打印信息可以看到，先是 retrieve 了
        // ivIndex 1 ，然后立即 store 了 ivIndex 1 （这次的 store 不用关心，因为这不是蓝牙设备发来的而是手机上的 sdk
        // 发来的），然后稍等几秒，就 store 了蓝牙设备发来的 ivIndex 1 并且连接上蓝牙设备。
        // 2、此时代码中写死以 ivIndex 0 连接，从打印信息可以看到，先是 retrieve 了 ivIndex 0 ，然后立即 store 了
        // ivIndex 0 （这次的 store 不用关心，因为这不是蓝牙设备发来的而是手机上的 sdk 发来的），然后就再也没有然后了
        // ……连不上蓝牙设备。
        // 3、在上面 1 和 2 步骤中，如果是先以足够大的 ivIndex A 进行认领再以足够小的 ivIndex B 进行连接，且 A - B > 1，
        // 那么是可以连接上的。
        // 4、由于 3 中  A - B > 1 的现象，则可以预测，当 ivIndex 由 0 变为 1 时，那么另外一台很早之前以 ivIndex 0
        // 分享出去且不在现场的手机，后续将永远连接不上蓝牙设备。
        // }), 0, 0);

        // telink sdk 3.1.0 上测得如果不设成 129 而设成 0 的话，有时候删除设备时会一直没有任何动静
        // telink sdk 3.3.3.5 上懒得再把上面都测一遍了，就这样吧
        // }), 129, 0,
        this.extendBearerMode);

        // NativeModule.setLogLevel(0x1F);

        this.DELAY_MS_COMMAND = NativeModule.getCommandsQueueIntervalMs();
        this.commandFifoBusy = false;
        this.commandFifoConsumer = {
            fifo: createNewFifo(),
            consumer: (fc) => {
                if (fc.fifo.length) {
                    const commandHandler = fc.fifo.shift();
                    if (commandHandler) {
                        commandHandler();
                    }
                } else {
                    this.commandFifoBusy = false;
                }
            },
            timer: undefined,
        }
    }

    static doInitAfterCheckPermissions() {
        if (Platform.OS === 'android') {
            NativeModule.doInitAfterCheckPermissions();
        }
    }

    static doDestroy() {
        const fc = this.commandFifoConsumer;
        fc.timer && clearTimeout(fc.timer);
        this.commandFifoBusy = false;

        this.getOnlineStatueTimer && clearTimeout(this.getOnlineStatueTimer);
        NativeModule.doDestroy();
        if (Platform.OS === 'android') {
            AppState.removeEventListener('change', this._handleAppStateChange.bind(this));
        }
   }

    static addListener(eventName, handler) {
        if (Platform.OS === 'ios') {
            const TelinkBtEmitter = new NativeEventEmitter(NativeModule);

            TelinkBtEmitter.addListener(eventName, handler);
        } else {
            DeviceEventEmitter.addListener(eventName, handler);
        }
    }

    static removeListener(eventName, handler) {
        if (Platform.OS === 'ios') {
            const TelinkBtEmitter = new NativeEventEmitter(NativeModule);

            TelinkBtEmitter.removeListener(eventName, handler);
        } else {
            DeviceEventEmitter.removeListener(eventName, handler);
        }
    }

    static isLocationPermissionsGranted() {
        if (Platform.OS === 'android') {
            return NativeModule.isLocationPermissionsGranted();
        }
    }

    static enableBluetooth() {
        NativeModule.enableBluetooth();
    }

    static isSystemLocationEnabled() {
        if (Platform.OS === 'android') {
            return NativeModule.isSystemLocationEnabled();
        }
    }

    // will receive event of 'systemLocationEnabled' or 'systemLocationDisabled'
    static checkSystemLocation() {
        if (Platform.OS === 'android') {
            NativeModule.checkSystemLocation();
        }
    }

    static enableSystemLocation() {
        NativeModule.enableSystemLocation();
    }

    static requestLocationPermissions() {
        if (Platform.OS === 'android') {
            NativeModule.requestLocationPermissions();
        }
    }

    static resetExtendBearerMode(extendBearerMode = this.extendBearerMode) {
        this.extendBearerMode = extendBearerMode;
        NativeModule.resetExtendBearerMode(this.extendBearerMode);
    }

    static notModeAutoConnectMesh() {
        return NativeModule.notModeAutoConnectMesh();
    }

    static autoConnect({}) {
        NativeModule.autoConnect();
    }

    static async postConnected({
        meshAddress,
        type,
        immediate = false,
    }) {
        // 需要此处，否则在 1 个设备的情况下，走过
        // 设置效果、删除设备、认领设备、设置效果
        // 这 4 个步骤时，除非重启 APP ，否则因为
        // 无法符合 selectNodeToResponseSceneId()
        // 中 sceneSyncMeshAddress !== this.lastSceneSyncMeshAddress
        // 的条件而导致 APP 一直没有发出设置同步的命令
        this.lastSceneSyncMeshAddress = undefined;

        this.remind({
            meshAddress: this.defaultAllGroupAddress,
        })

        await this.sleepMs(this.DELAY_MS_COMMAND);

        let changed = false;

        if (this.passthroughMode) {
            let preDefinedType = type | 0xf000;
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(preDefinedType)) {
                    if (mode === 'silan') {
                        // 获取 GIF 文件列表的状态
                        this.sendCommand({
                            opcode: 0x0211E6,
                            meshAddress: this.defaultAllGroupAddress,
                            valueArray: [0xa1, 5, 1, 1, 0xFF],
                            immediate,
                        });
                        // 获取 BMP 文件列表的状态
                        this.sendCommand({
                            opcode: 0x0211E6,
                            meshAddress: this.defaultAllGroupAddress,
                            valueArray: [0xa1, 5, 1, 2, 0xFF],
                            immediate,
                        });

                        // 因为上面的 this.remind() 爆闪时导致固件有几个瞬间是处于开灯状态的，所以等待爆闪结束时
                        // 用 0x0211E1 发起开关灯状态查询，才能得到正确的开关灯状态。
                        // sleepMs 等待爆闪结束的时间长短，可以通过在关灯情况下再打开 APP 看是否能获得 2 个设备
                        // 的关灯状态的测试方式来调节，目前测的在调用上面两个 this.sendCommand 后，在 3 个设备
                        // 的情况下，无需 sleepMs 就能正常
                        // await this.sleepMs(2000);

                        // 我们项目的固件里将 0x0211E1 返回的 TelinkBtSigNativeModule.onVendorResponse 的 opcode 设为了 0x0211E3 ，
                        // 这就是为何下面的 parseVendorResponse() 中有 0x0211E3 存在
                        this.sendCommand({
                            opcode: 0x0211E1,
                            meshAddress: this.defaultAllGroupAddress,
                            valueArray: [],
                            immediate,
                        });

                        changed = true;
                    }
                    break;
                }
            }
        }

        if (!changed) {
            if (!this.hasOnlineStatusNotifyRaw) {
                // 如果后续从蓝牙设备固件代码中得知 telink 也实现了（应该实现了） sig mesh 协议中
                // model 之间关联功能，放到这里就是实现了亮度 modle 如果亮度为 <= 0 的话就会关联
                // 开关灯 model 为关灯状态，则此处可以不再使用 Opcode.G_ONOFF_GET 而只用 Opcode.LIGHT_CTL_GET 等代替
                await this.sendCommandRsp({
                    opcode: Opcode.G_ONOFF_GET,
                    meshAddress: this.defaultAllGroupAddress,
                    valueArray: [],
                    rspOpcode: Opcode.G_ONOFF_STATUS,
                    immediate,
                });

                // 下面注释掉的 Get Opcode 仅用于测试

                // await this.sendCommandRsp({
                //     opcode: Opcode.G_LEVEL_GET,
                //     meshAddress: this.defaultAllGroupAddress,
                //     valueArray: [],
                //     rspOpcode: Opcode.G_LEVEL_STATUS,
                //     immediate,
                // });

                // await this.sendCommandRsp({
                //     opcode: Opcode.LIGHTNESS_GET,
                //     meshAddress: this.defaultAllGroupAddress,
                //     valueArray: [],
                //     rspOpcode: Opcode.LIGHTNESS_STATUS,
                //     immediate,
                // });

                // 如 TelinkBtSigNativeModule.java 的 onGetLevelNotify() 中注释所说，使用 onGetCtlNotify() 更简洁
                await this.sendCommandRsp({
                    opcode: Opcode.LIGHT_CTL_GET,
                    meshAddress: this.defaultAllGroupAddress,
                    valueArray: [],
                    rspOpcode: Opcode.LIGHT_CTL_STATUS,
                    immediate,
                });

                // await this.sendCommandRsp({
                //     opcode: Opcode.LIGHT_CTL_TEMP_GET,
                //     meshAddress: this.defaultAllGroupAddress,
                //     valueArray: [],
                //     rspOpcode: Opcode.LIGHT_CTL_TEMP_STATUS,
                //     immediate,
                // });
            }
        }
    }

    static autoRefreshNotify({
        repeatCount,
        Interval
    }) {}

    static idleMode({
        disconnect
    }) {
        return NativeModule.idleMode(disconnect);
    }

    static startScan({
        timeoutSeconds = 15,
        isSingleNode = false,
    }) {
        this.isClaiming = false;
        return NativeModule.startScan(timeoutSeconds, isSingleNode);
    }

    static parseVendorResponse(resRaw) {
        let res;
        switch (resRaw.opcode) {
            case 0x0211E3:
                res = {
                    opcode: 'ONOFF_STATUS',
                    meshAddress: resRaw.meshAddress,
                    isOnline: true,
                    isOn: resRaw.params[0] !== 0,
                };
                break;
            case 0x0211E7: {
                res = {
                    meshAddress: resRaw.meshAddress,
                }
                const scene = resRaw.params[0] & 0xff;
                if (scene === 0xa1) {
                    const action = resRaw.params[1] & 0xff;
                    if (action === 6) {
                        res.opcode = 'FILES_STATUS'
                        const filesLength = resRaw.params[3] & 0xff;
                        res.fileType = resRaw.params[4] & 0xff;
                        res.files = [];
                        let offset = 5;
                        for (let i = 0; i < filesLength; i++) {
                            const version = resRaw.params[offset++] & 0xff;
                            const nameLength = resRaw.params[offset++] & 0xff;
                            const name = [];
                            for (let j = 0; j < nameLength; j++) {
                                name.push(resRaw.params[offset++] & 0xff);
                            }
                            res.files.push({
                                version,
                                name: String.fromCharCode(...name),
                            })
                        }
                    } else if (action === 7) {
                        res.opcode = 'LOST_CHUNKS_STATUS'
                        res.fileType = resRaw.params[3] & 0xff;
                        res.fileVersion = resRaw.params[4] & 0xff;
                        let offset = 5;

                        const nameLength = resRaw.params[offset++] & 0xff;
                        const name = [];
                        for (let i = 0; i < nameLength; i++) {
                            name.push(resRaw.params[offset++] & 0xff);
                        }
                        res.fileName = String.fromCharCode(...name);

                        const maxChunkLengthLowByte = resRaw.params[offset++] & 0xff;
                        const maxChunkLengthHightByte = resRaw.params[offset++] & 0xff;
                        res.maxChunkLength = (maxChunkLengthHightByte << 8) | maxChunkLengthLowByte;

                        res.lostChunks = [];
                        const lostChunksLength = resRaw.params[offset++] & 0xff;
                        for (let i = 0; i < lostChunksLength; i++) {
                            res.lostChunks.push(resRaw.params[offset++] & 0xff);
                        }
                    }
                }
                break;
            }
            case 0x0211F6:
                res = {
                    opcode: 'SCENE_SYNC',
                    meshAddress: resRaw.meshAddress,
                    isOnline: true,
                    isOn: resRaw.params[0] !== 0,
                    sceneID: resRaw.params[1] & 0xFF,
                    sceneSyncTime: resRaw.params[1] && new Date().getTime(),
                };
                break;
            case 0x0211FB:
                switch (resRaw.params[0]) {
                    case 1:
                        res = {
                            opcode: 'notificationDataGetVersion',
                            meshAddress: resRaw.meshAddress,

                            // 为了保持兼容性，返回的 version 格式仍然沿用
                            // telink_sig_mesh_sdk_v3.1.0/firmware/vendor/common/version.h
                            // 中 FW_VERSION_TELINK_RELEASE 的 (VERSION_GET(0x31, 0x42)) 定义方法，所以弃用
                            // telink_sig_mesh_sdk_v3.3.3.5/firmware/vendor/common/version.h
                            // 中 ((SW_VERSION_SPEC << 4) + (SW_VERSION_MAJOR << 0) 的定义方法
                            version: String.fromCharCode(resRaw.params[1], resRaw.params[2]),
                        };
                        break;
                    default:
                        res = {};
                        break;
                }
                break;
            case 0x0211FF:
                res = {
                    opcode: 'DEBUG_FW_PRINT',
                    meshAddress: resRaw.meshAddress,
                    params: resRaw.params,
                };
                break;
            default:
                res = {};
                break;
        }

        return res;
    }

    static setCommandsQueueIntervalMs(interval) {
        NativeModule.setCommandsQueueIntervalMs(interval);
        this.DELAY_MS_COMMAND = interval;
    }

    static getCommandsQueueIntervalMs() {
        return this.DELAY_MS_COMMAND;
    }

    static clearCommandFifo({
        opcodeImmediate,
    }) {
        NativeModule.clearCommandQueue();
        let fc = this.commandFifoConsumer;
        for (let i = 0; i < fc.fifo.length; i++) {
            const commandHandler = fc.fifo.shift();
            if (commandHandler) {
                commandHandler(opcodeImmediate);
            }
        }
        this.commandFifoBusy = false;
    }

    static addCommandFifo(fifoData) {
        if (this.commandFifoBusy) {
            const fc = this.commandFifoConsumer;
            fc.fifo.push(fifoData);
        } else {
            this.commandFifoBusy = true;
            const fc = this.commandFifoConsumer;
            fc.timer && clearTimeout(fc.timer);
            fc.fifo.push(fifoData);
            fc.consumer(fc);
        }
    }

    // 这里 delayMs 之所以可以设置为 0 是因为 telink SDK 中本身自带 native 层队列，当 fc.consumer(fc) 被执行后
    // 就会有相应命令被堆入 native 层的队列中，然后 Android 会定时(getCommandsQueueIntervalMs 得 240ms) 从队列
    // 中或 iOS 会在前次命令结束后立即 handleResultCallback 从队列中取出一个命令用蓝牙硬件发送出去，这里的 delayMs
    // 可以控制 js 层 fifo 队列往 native 层队列发送的时机，设为 0 的话可以让蓝牙命令尽快被发出，特别是由于 iOS 的
    // handleResultCallback 的关系如果设为 0 的话则在命令众多的情况下测得即使 2 设备时也会比 Android 更快速地被发
    // 出，但由于如果命令多到十几个的情况下容易丢几个命令，所以当为 iOS 时这里还是不使用 0 而是就当作这个备注了：
    // 备注：如果 SDK 没有或取消 native 层队列的话，单独使用 delayMs 配合 js 层 fifo 队列也是可以的。
    static setNextFcTimer(delayMs = this.DELAY_MS_COMMAND) {
        const fc = this.commandFifoConsumer;
        fc.timer = setTimeout(() => {
            fc.consumer(fc);
        }, delayMs);
    }

    // telink, why do you have so many ack cmd in queue if there are many device? I have to use {immediate: true}
    static getCommandQueueLength() {
        return NativeModule.getCommandQueueLength();
    }

    static getCmdRspTimeoutMs(retryCnt = 2) {
        return NativeModule.getCommandQueueLength() * this.DELAY_MS_COMMAND + (retryCnt + 1) * this.DELAY_MS_CMD_RSP_TIMEOUT;
    }

    // without response, quickly (1/3 time of this.sendCommandRsp below), but despite whether devices received cmd
    static sendCommand({
        opcode,
        meshAddress,
        valueArray, // means the MeshMessage.params on Android, IniCommandModel.commandData on iOS
        rspOpcode = this.OPCODE_INVALID,
        tidPosition = -1, // if > 0 , means the tid is stored in valueArray[tidPosition - 1]
        immediate = false,
    }) {
        if (immediate) {
            this.commandFifoConsumer.fifo.length && this.clearCommandFifo({
                opcodeImmediate: opcode,
            })
            NativeModule.sendCommand(opcode, meshAddress, valueArray, rspOpcode, tidPosition, true);
        } else {
            this.addCommandFifo((opcodeImmediateCancelBy) => {
                if (opcodeImmediateCancelBy !== undefined) {
                    return;
                }

                // if (opcode === 0x0211E6 && valueArray[0] === 0xa1 && valueArray[1] === 0) {
                //     console.log('transfer', meshAddress.toString(16), valueArray[11] + '/' + (valueArray[12] - 1), '0x' + valueArray[8].toString(16));
                // } else {
                //     console.log('sendCommand', meshAddress.toString(16), 'opcode:' + opcode.toString(16), valueArray);
                // }

                NativeModule.sendCommand(opcode, meshAddress, valueArray, rspOpcode, tidPosition, false);
                this.setNextFcTimer(rspOpcode === this.OPCODE_INVALID ? undefined : this.getCmdRspTimeoutMs());
            });
        }
    }

    // with Promise response, 3x slower than this.sendCommand() above, but more ensure
    //
    // if device fw not response, will cause reject timeout then other command in fifo
    // can run, so please debug fw or other command just use NativeModule.sendCommand
    // directly by this.sendCommand(immediate: true)
    //
    // if mix many NativeModule.sendCommand and this.sendCommandRsp in a short period,
    // maybe cause once reject timeout, please adjust your APP code
    //
    // here relayTimes AKA responseMax, means native will not resolve Promise until
    // receive relayTimes response with rspOpcode from device, so APP can
    // sendCommandRsp({relayTimes: onlineCountInGroup}) where onlineCountInGroup is:
    //   1 or 0 if MESH_ADDRESS is online or not
    //   online count if GROUP_ADDRESS or defaultAllGroupAddress
    static sendCommandRsp({
        opcode,
        meshAddress,
        valueArray, // means the MeshMessage.params on Android, IniCommandModel.commandData on iOS
        rspOpcode = this.OPCODE_INVALID,
        relayTimes = 0, // ref to `responseMax = 0` in android/src/main/java/com/telink/ble/mesh/core/message/MeshMessage.java
        retryCnt = 2, // ref to `DEFAULT_RETRY_CNT = 2` in android/src/main/java/com/telink/ble/mesh/core/message/MeshMessage.java
        tidPosition = -1, // if > 0 , means the tid is stored in valueArray[tidPosition - 1]
        immediate = false,
    }) {
        if (immediate) {
            this.clearCommandFifo({
                opcodeImmediate: opcode,
            })
        }

        // use fifo and Promise and this.commandFifoBusy to avoid the BUG: if current
        // rsp command not get rspMax rsp to means complete, but here comes next rsp
        // command, then will `reliable message send err: busy` with reliableBusy in
        // android/src/main/java/com/telink/ble/mesh/core/networking/NetworkingController.java
        // in another word, APP now can `await this.sendCommandRsp()` or just `this.sendCommandRsp()`
        // many times quickly(no need wait 240ms), and still ensure every cmd works fine
        return new Promise((resolve, reject) => this.addCommandFifo((opcodeImmediateCancelBy) => {
            if (opcodeImmediateCancelBy !== undefined) {
                reject(new TypeError('opcode ' + opcode.toString(16) + ' is canceled by opcodeImmediate ' + opcodeImmediateCancelBy.toString(16)));
                return;
            }

            const timeout = this.getCmdRspTimeoutMs(retryCnt);
            let timer = setTimeout(() => {
                // to ensure exit Promise if `reject(error)` never invoked from native
                // console.warn('sendCommandRsp @' + meshAddress.toString(16) + ' time out ' + timeout + 'ms');
                reject(new TypeError('sendCommandRsp @' + meshAddress.toString(16) + ' opcode ' + opcode.toString(16) + ' time out ' + timeout + 'ms'));
                this.setNextFcTimer();
            }, timeout);
            NativeModule.sendCommandRsp(opcode, meshAddress, valueArray, rspOpcode, relayTimes, retryCnt, tidPosition, false).then(payload => {
                clearTimeout(timer);
                // console.log('sendCommandRsp @' + meshAddress.toString(16) + ' opcode:' + opcode.toString(16) + ' relayTimes:' + relayTimes + ' valueArray:' + valueArray);
                resolve(payload);
                this.setNextFcTimer();
            }, error => {
                clearTimeout(timer);
                // after retry in native (DEFAULT_RETRY_CNT = 2 in android/src/main/java/com/telink/ble/mesh/core/message/MeshMessage.java)
                // still error then reject here to APP
                // console.warn('sendCommandRsp @' + meshAddress.toString(16) + ' opcode:' + opcode.toString(16) + ' ' + error);
                reject(error);
                this.setNextFcTimer();
            });
        }));
    }

    // 让灯爆闪几下
    static remind({
        meshAddress,
        immediate = false,
    }) {
        this.sendCommand({
            opcode: 0x0211F0,
            meshAddress,
            valueArray: [],
            immediate,
        });
    }

    static isOnline(status) {
        return (status) !== this.NODE_STATUS_OFFLINE;
    }

    static isOn(status) {
        return (status) === this.NODE_STATUS_ON;
    }

    static async changePower({
        meshAddress,
        meshAddresses = [],
        value,
        type,
        parVer = this.useAddressesInsteadOfGroup === true ? this.PAR_VER_useAddressesInsteadOfGroup : this.PAR_VER_init,
        delaySec = 0,
        immediate = true, // ack is true in native code and that will cause delay if changePower again in short time, except immediate is true
    }) {
        let changed = false;

        if (this.passthroughMode) {
            let preDefinedType = type | 0xf000;
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(preDefinedType)) {
                    if (mode === 'silan') {
                        // 不论这里是 this.OPCODE_INVALID 还是 0x0211E3 ，返回的 TelinkBtSigNativeModule.onVendorResponse 的 opcode 都是 0x0211E3 ，
                        // 究其根本原因其实是我们自己的固件代码中写成了只要收到开关灯命令，就一定通过 E3 返回开关灯状态
                        // this.sendCommand({
                        //     opcode: this.hasOnlineStatusNotifyRaw ? 0x0211E2 : 0x0211E0,
                        //     meshAddress,
                        //     valueArray: [value],
                        //     rspOpcode: 0x0211E3,
                        //     immediate,
                        // });
                        // 按说在 this.hasOnlineStatusNotifyRaw 被 saveOrUpdateJS 事件设为 true 的情况下，只要使用上面
                        // 的不带返回值的开关命令 E2 即可，但是发现当在界面上快速点击开关的情况下，只有下面的带返回值的开关命
                        // 令 E0 额外返回的开关状态才能保证开关按钮的状态能够快速切换且能快速地开关灯。

                        const par = [value];
                        if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                            par.push(parVer);
                            par.push(meshAddresses.length);
                            par.push(...meshAddresses);

                            if (meshAddresses.length === 0) {
                                // 当 meshAddresses.length 为 0 时，如果不使用下面的语句，则 par 最后一个字节为 0 ，
                                // 但不可为 0，否则 E0 命令在固件收到后变成了 1、2、3、4 ... 而非 0 (BUG 或是没有
                                // TODO: 设置好 tid?)，虽然 F3 之类的命令不会如此，所以这里添加一个不为 0 的比如 0xFF
                                par.push(0xFF);
                            }
                        }
                        // NativeModule.sendCommand(0x0211E0, meshAddress, par, 0x0211E3, -1, immediate);
                        // 如果使用下面带 fifo 的 this.sendCommandRsp ，则当 immediate 为 false 且用户短时间内连续点击开关灯
                        // 时，会导致用户松手后仍然会自动开关灯连续切换一段时间，所以下面 immediate 最好为 true
                        await this.sendCommandRsp({
                            opcode: 0x0211E0,
                            meshAddress,
                            valueArray: par,
                            rspOpcode: 0x0211E3,
                            immediate,
                        });
                        changed = true;
                    }
                    break;
                }
            }
        }

        if (!changed) {
            NativeModule.changePower(meshAddress, value);
        }
    }

    static setAudioFrequencyHistogram({
        meshAddress = this.defaultAllGroupAddress,
        loudness = 0,
        value = [
            10, // height of frequency 0 on histogram
            90, // height of frequency 1 on histogram
            40, // ...
            90,
            10,
            0,
            0,
            1,
        ],
        relayTimes = 7,
        immediate = false,
    }) {
        if (this.allowSceneCadence) {
            this.isSceneCadenceBusy = true;
            this.sendCommand({
                opcode: 0x0211FA,       // 0x0211FA means set without rsp in my product
                meshAddress,
                valueArray: [
                    3,                  // 3 means setAudioFrequencyHistogram in my product
                    this.gamma[loudness],
                    value.length, // how many frequency
                    ...value,
                ],
                immediate,
            });
        }
    }

    static async onOffAudioFrequencyHistogram({
        meshAddress = this.defaultAllGroupAddress,
        value = 0, // 0: off, 1: on
        relayTimes = 7,
        immediate = false,
    }) {
        if (this.isSceneCadenceBusy) {
            this.allowSceneCadence = false;
            // 因音乐图谱功能是不停地（每隔 50ms 左右）在发送 setAudioFrequencyHistogram 蓝牙消息，
            // 这样关闭音乐图谱功能时，如果不在这里等待足够长时间以便让那些图谱消息发送完成，有时就就无法关闭
            await this.sleepMs(this.DELAY_MS_COMMAND);
            this.isSceneCadenceBusy = false;
        }

        this.sendCommand({
            opcode: 0x0211FA,       // 0x0211FA means set without rsp in my product
            meshAddress,
            valueArray: [
                4,                  // 4 means onOffAudioFrequencyHistogram in my product
                value,
                0, // reserve
            ],
            immediate,
        });

        this.allowSceneCadence = true;
    }

    static changeBrightness({
        meshAddress,
        hue = 0,
        saturation = 0,
        value,
        type,
        immediate = false,
    }) {
        let changed = false;

        if (this.passthroughMode) {
            let preDefinedType = type | 0xf000;
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(preDefinedType)) {
                    if (mode === 'silan') {
                        if (this.allowSceneCadence) {
                            this.isSceneCadenceBusy = true;
                            NativeModule.sendCommand(0x0211F3, meshAddress, [this.gamma[value]], this.OPCODE_INVALID, -1, immediate);
                        }
                        changed = true;
                    }
                    break;
                }
            }
        }

        if (!changed) {
            NativeModule.changeBrightness(meshAddress, value);
        }
    }

    static changeColorTemp({
        meshAddress,
        value
    }) {
        NativeModule.changeColorTemp(meshAddress, value);
    }

    static changeColor({
        meshAddress,
        hue = 0,
        saturation = 0,
        value,
        type,
        immediate = false,
    }) {
        const h = parseInt(65535 * hue / this.HUE_MAX, 10);
        const s = parseInt(65535 * saturation / this.SATURATION_MAX, 10);
        const v = parseInt(65535 * value / this.BRIGHTNESS_MAX, 10);

        NativeModule.changeColor(meshAddress, h, s, v);
    }

    static padHexString(string) {
        if (string.length === 1) {
            return '0' + string;
        } else {
            return string;
        }
    }

    static hexString2ByteArray(string) {
        let array = [];
        [].map.call(string, (value, index, str) => {
            if (index % 2 === 0) {
                array.push(parseInt(value + str[index + 1], 16));
            }
        });

        return array;
    }

    static byteArray2HexString(bytes) {
        return bytes.map(byte => this.padHexString((byte & 0xFF).toString(16))).toString().replace(/,/g, '').toUpperCase();
    }

    static sleepMs(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // 为了解决颜色不准的问题，最终发现原因是灯串硬件亮度级别是 8 位与手机估计至少 12 位亮度级别
    // 存在矛盾，也就是说是灯串硬件等级（成本）较低造成的，光靠调灯串硬件固件是不行的。现在的解决方
    // 法是查看 RGB 中的某个分量，如果低于某个值（视灯串 LED 的 gamma 表而定）的就变为 0 之类的方法。
    // 具体来说，低于等于 0x30 的就变为 0 ，位于 0x30 和 0x40 之间的就变为 0x40，其它不变。
    //
    // 后来发现颜色不准主要是由于固件中效果变化时 gamma 重复操作导致的，所以下面代码暂时简单禁用 ledFilter3040
    static ledFilter3040(value) {
        if (value <= 0x30) {
            return 0;
        }
        if (value < 0x40) {
            return 0x40;
        }
        return value;
    }

    static ledFilterBurnGreen({
        r,
        g,
        b,
        scene,
    }) {
        if (g > this.LED_GREEN_MAX) {
            return {
                r: parseInt(r * this.LED_GREEN_MAX / g, 10),
                g: this.LED_GREEN_MAX,
                b: parseInt(b * this.LED_GREEN_MAX / g, 10),
            }
        } else if (r === 0 && g === 0 && scene !== 45) {    // 因为当前使用的灯串的蓝色偏暗，而又受到白平衡和 LED_GREEN_MAX 的限制，所以这里单独将纯蓝亮度提高到客户满意的 2 倍
            let newB = b * 2;
            if (newB > 122) {
                newB = 122;
            }
            return {
                r,
                g,
                b: newB,
            }
        } else {
            return {
                r,
                g,
                b,
            }
        }
    }

    static startCreateScenePar() {
        this.sceneParList = [];
        this.isCreatingSceneParList = true;
    }

    // 按 startCreateScenePar() 、 多次 changeScene() 、 stopCreateScenePar()
    // 的顺序调用，就可获得播放列表 data ，后续可以将这个 data 作为文件保存到灯串中
    static stopCreateScenePar() {
        this.isCreatingSceneParList = false;
        const data = this.arrayList2Data(this.sceneParList);
        this.sceneParList = [];
        return data;
    }

    static arrayList2Data(arrayList) {
        const listLength = arrayList.length;
        const sceneParData = [listLength & 0xff, (listLength >>> 8) & 0xff];
        const lengthOfListLength = 2;
        const lengthOfOffsetAndLen = (2 + 2) * listLength;
        let offset = lengthOfListLength + lengthOfOffsetAndLen;
        for (let i = 0; i < listLength; i++) {
            const arrayLength = arrayList[i].length;
            sceneParData.push(offset & 0xff);
            sceneParData.push((offset >>> 8) & 0xff);
            sceneParData.push(arrayLength & 0xff);
            sceneParData.push((arrayLength >>> 8) & 0xff);
            offset += arrayLength;
        }

        return sceneParData.concat(arrayList.flat());
    }

    static async changeScene({
        meshAddress,
        meshAddresses = [],
        relayTimes = 0,
        retryCnt = 2,
        sceneSyncMeshAddress,
        scene,
        sceneMode = 5, // e.g. 二维图片的平移方向
        sceneModeOpt = 0, // e.g. 二维图片斜向平移时是否填充空边
        sceneRotate = 0, // 图片旋转
        sceneMirror = 0, // 图片镜像翻转
        sceneDisplayRange = 0, // 显示范围
        sceneImageResizeMode = 0, // 图片缩放模式
        fileVersion = 0,
        text = 'flyskywhy',
        hue = 0,
        saturation = 0,
        value,
        reserve = 0,
        color,
        reserveBg = 0,
        colorBg,
        reserves = [],
        colors = [],
        colorsLength = 1,
        colorSequence = 1,
        colorIds = [1, 2, 3, 4, 5],
        colorBgId = 2,
        colorId = 1,
        data = [],
        isEditingCustom = false,
        needPostProcessColor = true,
        speed = -2,

        // 效果持续播放的毫秒数，如果为 0 ，则表示无限时长（无限循环），
        // 一般只在 this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses
        // 时才需要折腾，于是固件收到的数据中不包含 ms 的也定义为表示无限时长
        ms = 10100,

        bigDataAction,
        bigDataType = 0,
        bigDataLostRetry = false,
        datasIndex,
        datasCount,
        chunksIndex,
        chunksCount,
        chunk,
        maxChunkLength = 200,

        type,
        parVer = this.useAddressesInsteadOfGroup === true ? this.PAR_VER_useAddressesInsteadOfGroup : this.PAR_VER_init,
        immediate = false,
    }) {
        if (this.isSceneCadenceBusy && !this.isCreatingSceneParList) {
            this.allowSceneCadence = false;
            // 因 Cadence 韵律功能是不停地（每隔 50ms 左右）在发送 changeBrightness 蓝牙消息，
            // 这样切换效果时，如果不在这里等待足够长时间以便让韵律消息发送完成，就无法切换效果
            await this.sleepMs(this.DELAY_MS_COMMAND);
            this.isSceneCadenceBusy = false;
        }

        let changed = false;

        if (this.passthroughMode) {
            let color3 = color && tinycolor(color).toRgb();
            if (!color3) {
                color3 = tinycolor.fromRatio({
                    h: hue / this.HUE_MAX,
                    s: saturation / this.SATURATION_MAX,
                    v: value / this.BRIGHTNESS_MAX,
                }).toRgb();
            } else if (needPostProcessColor) {
                // color3.r = this.ledFilter3040(color3.r);
                // color3.g = this.ledFilter3040(color3.g);
                // color3.b = this.ledFilter3040(color3.b);
                color3.r = parseInt(this.gamma[color3.r] * this.whiteBalance.r, 10);
                color3.g = parseInt(this.gamma[color3.g] * this.whiteBalance.g, 10);
                color3.b = parseInt(this.gamma[color3.b] * this.whiteBalance.b, 10);
                let safeColor = this.ledFilterBurnGreen(color3);
                color3.r = safeColor.r;
                color3.g = safeColor.g;
                color3.b = safeColor.b;
            }
            let color3Bg = colorBg && tinycolor(colorBg).toRgb();
            if (color3Bg && needPostProcessColor) {
                // color3Bg.r = this.ledFilter3040(color3Bg.r);
                // color3Bg.g = this.ledFilter3040(color3Bg.g);
                // color3Bg.b = this.ledFilter3040(color3Bg.b);
                color3Bg.r = parseInt(this.gamma[color3Bg.r] * this.whiteBalance.r, 10);
                color3Bg.g = parseInt(this.gamma[color3Bg.g] * this.whiteBalance.g, 10);
                color3Bg.b = parseInt(this.gamma[color3Bg.b] * this.whiteBalance.b, 10);
                let safeColor = this.ledFilterBurnGreen(color3Bg);
                color3Bg.r = safeColor.r;
                color3Bg.g = safeColor.g;
                color3Bg.b = safeColor.b;
            }
            let colors3 = [];
            colors.map((colour, index) => {
                colors3.push(reserves[index] || 0);    // reserve 是固件代码中某个颜色的保留字节（固件代码中每个颜色有 4 个字节）
                let rgb = tinycolor(colour).toRgb();
                if (needPostProcessColor) {
                    // rgb.r = this.ledFilter3040(rgb.r);
                    // rgb.g = this.ledFilter3040(rgb.g);
                    // rgb.b = this.ledFilter3040(rgb.b);
                    rgb.r = parseInt(this.gamma[rgb.r] * this.whiteBalance.r, 10);
                    rgb.g = parseInt(this.gamma[rgb.g] * this.whiteBalance.g, 10);
                    rgb.b = parseInt(this.gamma[rgb.b] * this.whiteBalance.b, 10);
                    let safeColor = this.ledFilterBurnGreen({
                        ...rgb,
                        scene,
                    });
                    rgb.r = safeColor.r;
                    rgb.g = safeColor.g;
                    rgb.b = safeColor.b;
                }
                colors3.push(rgb.r);
                colors3.push(rgb.g);
                colors3.push(rgb.b);
            });
            let preDefinedType = type | 0xf000;
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(preDefinedType)) {
                    if (mode === 'silan') {
                        if (!isEditingCustom) {
                            this.selectNodeToResponseSceneId({
                                sceneSyncMeshAddress,
                            });
                        }

                        switch (scene) {
                            case 0:
                            case 1:
                            case 2:
                            case 3:
                            case 4:
                            case 5:
                            case 6:
                            case 10:
                            case 14:
                            case 15:
                            case 16:
                            case 17:
                            case 18:
                            case 24:
                            case 33:
                            case 37:
                            case 39:
                            case 47:
                            case 49:
                            case 61:
                            case 0x9e:
                            case 166:
                            case 50: {
                                                  // 这里的 1 是颜色个数， reserve 是固件代码中某个颜色的保留字节（固件代码中每个颜色有 4 个字节）对应固件代码中的 ltstr_scene_status_t，下同
                                const par = [scene, speed, 1, reserve, color3.r, color3.g, color3.b];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            case 7:
                            case 8:
                            case 9:
                            case 11:
                            case 12:
                            case 19:
                            case 20:
                            case 22:
                            case 23:
                            case 25:
                            case 27:
                            case 28:
                            case 29:
                            case 30:
                            case 31:
                            case 32:
                            case 35:
                            case 36:
                            case 38:
                            case 40:
                            case 41:
                            case 43:
                            case 44:
                            case 45:
                            case 51:
                            case 52:
                            case 53:
                            case 60:
                            case 62:
                            case 63: {
                                const par = [scene, speed, colorsLength, ...colors3];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            case 13:
                            case 21:
                            case 26:
                            case 34:
                            case 42: {
                                const par = [scene, speed, 2, reserve, color3.r, color3.g, color3.b, reserveBg, color3Bg.r, color3Bg.g, color3Bg.b];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            case 46: {
                                const par = [scene, speed, 1, reserve, color3.r, color3.g, color3.b, 1, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }

                            // [
                            //     // 以下是自定义效果命令参数中每个字节的含义
                            //     scene,              // 效果的 id
                            //     speed,              // 效果的整体速度，在目前自定义效果只有一帧的情况下，可以为 2
                            //     dataType,           // 后续数据的压缩类型， 0 代表无压缩
                            //     dataLengthLowByte,  // 后续数据压缩后的字节长度，由两个字节表示，本字节为低位字节，本字节并不计算在该长度之内
                            //     dataLengthHightByte,// 后续数据压缩后的字节长度，由两个字节表示，本字节为高位字节，本字节并不计算在该长度之内
                            //     [   // 实际的 sig mesh 命令参数中是没有本中括号以及下面中括号的，放在这里是为了表明这里就像是二维数组一样，
                            //         // 然后数组中所有元素的 subdataLength 相加其实就等于上面提到的 dataLength
                            //         [
                            //             subdataLength,  // 本子数据的长度，本字节也计算在该长度之内，在本例子中，该长度为 7 （当 bulbsStart <= 255）或 8 （当 bulbsStart > 255）
                            //             bulbsMode,      // 本小段灯珠的变化模式， 0 为擦除， 1 为简单常亮， 2 为简单闪烁， 3 为简单呼吸
                            //             bulbsStartLsb,  // 本小段灯珠的起始地址低 8 位字节
                            //             bulbsStartMsb,  // 本小段灯珠的起始地址高 8 位字节，当 bulbsStart <= 255 ，本字节不存在
                            //             bulbsLength,    // 本小段灯珠的个数
                            //             bulbsColorR,    // 本小段灯珠颜色的 R 的值
                            //             bulbsColorG,    // 本小段灯珠颜色的 G 的值
                            //             bulbsColorB,    // 本小段灯珠颜色的 B 的值
                            //         ]
                            //     ]
                            // ]

                            // 下面是一段 NativeModule.sendCommand 命令参数数组的示例
                            // [
                            //     128,// 效果的 id 也就是 0x80
                            //     2,  // 速度 暂时无用
                            //     0,  // 0 代表无压缩
                            //     15, // 数据字节长度的低位字节
                            //     0,  // 数据字节长度的高位字节，无压缩情况下一般只有一个灯珠的话，数据字节是 7 或 8 ，这里是 15 （结合上面的低位字节来看），代表有两段数据
                            //     7,  // subdataLength
                            //     2,  // bulbsMode
                            //     0,  // bulbsStart
                            //     4,  // bulbsLength
                            //     255,// bulbsColorR
                            //     0,  // bulbsColorG
                            //     0,  // bulbsColorB
                            //     8,  // subdataLength
                            //     1,  // bulbsMode
                            //     55, // bulbsStartLsb
                            //     1,  // bulbsStartMsb
                            //     2,  // bulbsLength
                            //     255,// bulbsColorR
                            //     0,
                            //     0
                            // ]

                            case 0x80: {
                                let rawData = [];
                                data.map(subdata => {
                                    let bulbsMode = subdata[0];
                                    let bulbsStart = subdata[1];
                                    let bulbsLength = subdata[2];
                                    let bulbsColorR = subdata[3] >> 16 & 0xFF;
                                    let bulbsColorG = subdata[3] >> 8 & 0xFF;
                                    let bulbsColorB = subdata[3] & 0xFF;
                                    if (needPostProcessColor) {
                                        // let bulbsColorR = this.ledFilter3040(bulbsColorR);
                                        // let bulbsColorG = this.ledFilter3040(bulbsColorG);
                                        // let bulbsColorB = this.ledFilter3040(bulbsColorB);
                                        let bulbsColorR = parseInt(this.gamma[bulbsColorR] * this.whiteBalance.r, 10);
                                        let bulbsColorG = parseInt(this.gamma[bulbsColorG] * this.whiteBalance.g, 10);
                                        let bulbsColorB = parseInt(this.gamma[bulbsColorB] * this.whiteBalance.b, 10);
                                        let safeColor = this.ledFilterBurnGreen({
                                            r: bulbsColorR,
                                            g: bulbsColorG,
                                            b: bulbsColorB,
                                        });
                                        bulbsColorR = safeColor.r;
                                        bulbsColorG = safeColor.g;
                                        bulbsColorB = safeColor.b;
                                    }
                                    if (bulbsStart > 255) {
                                        let subdataLength = 8;
                                        rawData = rawData.concat([
                                            subdataLength,
                                            bulbsMode,
                                            bulbsStart & 0xFF,
                                            bulbsStart >> 8 & 0xFF,
                                            bulbsLength,
                                            bulbsColorR,
                                            bulbsColorG,
                                            bulbsColorB,
                                        ]);
                                    } else {
                                        let subdataLength = 7;
                                        rawData = rawData.concat([
                                            subdataLength,
                                            bulbsMode,
                                            bulbsStart,
                                            bulbsLength,
                                            bulbsColorR,
                                            bulbsColorG,
                                            bulbsColorB,
                                        ]);
                                    }
                                });
                                let dataType = 0;
                                let dataLengthLowByte = rawData.length & 0xFF;
                                let dataLengthHightByte = rawData.length >> 8 & 0xFF;

                                // TODO: 后续将 0x0211F4 整合进 0x0211E6 中
                                if (isEditingCustom) {
                                    NativeModule.sendCommand(0x0211F4, meshAddress, [scene, speed, dataType, dataLengthLowByte, dataLengthHightByte, ...rawData], this.OPCODE_INVALID, -1, immediate);
                                } else {
                                    const par = [scene, speed, 0];
                                    if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                        par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                        par.push(ms & 0xff);
                                        par.push((ms >>> 8) & 0xff);
                                        par.push((ms >>> 16) & 0xff);
                                        par.push((ms >>> 24) & 0xff);
                                    } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                        par.push(parVer);
                                        par.push(meshAddresses.length);
                                        par.push(...meshAddresses);
                                    }
                                    if (this.isCreatingSceneParList) {
                                        this.sceneParList.push(par);
                                        return;
                                    }
                                    NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                    // 这里之所以将数据命令 0xF4 注释掉，是为了解决效果间快速切换时，如果自定义效果散点较多也就是需
                                    // 更多数据发送时间，而同时从自定义效果切出去时太快的话就会导致下一个效果的命令没生效的 BUG
                                    // 至于以前之所以灯串固件中已经保存了自定义数据，但切换时仍然 0xF4 再发一遍的原因，是如果不同用户手机上保存着自己
                                    // 的与别人不同的自定义效果数据，此时只发效果切换命令的话，手机模拟显示与实际灯串不同，可能会被认
                                    // 为是瑕疵，但这个瑕疵可以让用户在创建自定义页面重新保存到固件来解决，所以用户也不一定认为是 BUG
                                    // await this.sleepMs(this.DELAY_MS_COMMAND);
                                    // 这里一定要先发上面的效果切换命令 0xE6 ，再发下面的自定义效果数据命令 0xF4 ，否则数据较大时无法切换
                                    // NativeModule.sendCommand(0x0211F4, meshAddress, [scene, speed, dataType, dataLengthLowByte, dataLengthHightByte, ...rawData], this.OPCODE_INVALID, -1, immediate);
                                }
                                changed = true;
                                break;
                            }
                            case 0x9f: {
                                const par = [scene, speed, colorsLength, ...colors3, sceneMode, sceneModeOpt];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            case 0xa0: {
                                                                                            // 这里的 1 是保留字节，也许后续有用                           // 这里的 0 是用来表明字符串结尾以利于固件 C 代码判断之用？
                                const par = [scene, speed, 1, reserve, color3.r, color3.g, color3.b, 1, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            case 0xa1: {
// 大数据传输协议，协议之所以如此制定的原因：

// * telink sig mesh SDK 中发送一个消息的最大数据是 380 字节，而一幅 bmp 数据就要 1KB 多，一个消息肯定容不下，更不要说多幅 bmp 来表示 gif 了
// * telink sig mesh SDK 3.1.0 未提供大数据传输 API ，虽说可以参考 OTA 传输大数据的 GATT 协议，但 GATT 需要单对单连接，而我们灯串的常用场景是单对多广播数据，而且就算我们自己定义一套往复传输协议，也很难解决单往多发送后多回复单的复杂处理问题
// * telink sig mesh SDK 3.3.3.5 提供了 GATT 协议传输模式，说是可以让原来的传输命令自动变为大数据传输，但只是将原来 380 字节拆分为 11 字节方式改为不拆包，使得数据传输率从 42B/s 提升为 8KB/s ，但仍然受限 380 字节，所以实际上不是大数据传输 API
// * 因此这里定的协议传输方式就是与以往效果切换一样的广播模式，然后由灯串固件自行将 datasIndex datasCount 和 chunksIndex chunksCount 所索引的数据拼接为多幅 bmp 或一个 gif 数据
// * 这样的协议，也可以在 WiFi 灯串上实现，从而使得蓝牙和 WiFi 灯串可以维护基本相同的大数据发送代码
// * gif 数据量是 bmp 的一半左右，我们在固件中内嵌 gif 解码功能，然后把传输几个 bmp 数据修改为传输一个 gif 数据

// 每条消息会包含一段 chunk 数据，所谓 chunk 指的是一个数组内容的一部分，而整体上完整的数据则是一个二维数组：

// * 当传输几个 bmp 数据时：[[bmp1][bmp2]...[bmpN]]
// * 当传输一个 gif 数据时：[[gif]]

// ### 传输数据的消息数据格式

//     scene,          // 效果的 id
//     action,         // 0: 传输数据。固件此时可以仅仅在内存中放置数据
//     speed,          // 速度。 bmp 时指 gif 的 fps ； gif 时该值无所谓（因为 gif 文件内含 fps ）
//     1,              // 颜色个数为 1
//     reserve,        // 固件代码中某个颜色的保留字节（固件代码中每个颜色有 4 个字节）对应固件代码中的 ltstr_scene_status_t
//     color3.r,
//     color3.g,
//     color3.b;       // 颜色
//     schema,         // 当最高位[7]为 0 时表明是正常的传输，为 1 时表明是丢包重发的传输
//     datasIndex,     // 当前 chunk 属于二维数组中的哪个数组。 bmp 时，表明当前 chunk 属于第 0...n 幅的 bmp ； gif 时，总为 0
//     datasCount,     // 二维数组包含几个数组。 bmp 时，一共几幅 bmp ； gif 时，总为 1
//     chunksIndex,    // 当前 chunk 属于当前数组的第 0...n 部分
//     chunksCount,    // 当前数组一共几段 chunk
//     direction,      // 平移方向， 0 为不平移， 1 为东向， 2 为东南向，以此类推，直到 8 为东北向
//     dataType,       // 数组中数据的类型， 0: 固件自己从数据头中判断，比如 bmp 数据头二个字节一般为 BM ， gif 为 GIF ； 1: 显式指定为 gif ； 2: 显式指定为 bmp
//     chunkLengthLowByte,  // 当前 chunk 的字节长度，由两个字节表示，本字节为低位字节，本字节并不计算在该长度之内
//     chunkLengthHightByte,// 当前 chunk 的字节长度，由两个字节表示，本字节为高位字节，本字节并不计算在该长度之内
//     chunk[0],       // chunk 的第一个字节
//     chunk[1],       // chunk 的第二个字节
//     ...
//     chunk[n],       // 以此类推

// 考虑到用户操作 APP 修改 gif 时会希望灯串能及时响应， APP 的行为已设定为就算代表一个 gif 的多段 chunk 还没有发送完，只要用户一生成（或切换）新的 gif ， APP 就会停止发送之前还剩余的几段 chunk ，转而重新开始发送新 gif ，因而灯串固件只要发现新收到的消息中， datasIndex 和 chunksIndex 都为 0 ，就表明新的 gif 数据过来了，如果之前旧的 gif 数据已接收了一部分，也立即放弃旧数据。

// ### 保存数据的消息数据格式

//     scene,          // 效果的 id
//     action,         // 1: 保存数据。固件将之前放置在内存中的数据以 fileName[] 的名义保存到 flash 中
//     schema,         // 当最高位[7]为 0 时表明是正常的保存，为 1 时表明是丢包重发的保存
//     maxChunkLengthLowByte,     // APP 分割文件时所用的基准长度，一般与第一个 chunk 的字节长度相同，由两个字节表示，本字节为低位字节
//     maxChunkLengthHightByte,   // APP 分割文件时所用的基准长度，一般与第一个 chunk 的字节长度相同，由两个字节表示，本字节为高位字节
//     fileType,       // 文件类型， 1: 为 gif ； 2: 为 bmp ，其实就是上面的 dataType ，放在这里是为了方便固件编写丢包细节的代码
//     fileVersion,    // file 的文件版本，范围为 1~255 递增循环
//     fileName[0],    // fileName 字符串的第一个 ascii 字符值
//     fileName[1],    // fileName 字符串的第二个 ascii 字符值
//     ...
//     fileName[n],    // 以此类推
//     0,              // 用来表明 fileName 字符串结尾以利于固件 C 代码判断之用

// ### 在灯串上展示数据的消息数据格式

//     scene,          // 效果的 id
//     action,         // 2: 展示数据。固件将之前以 fileName[] 的名义保存在 flash 中的数据展示到灯串上
//     speed,          // 速度。 bmp 时指 gif 的 fps ； gif 时，如果该值为 0 ，则使用 gif 文件内含的 fps ，否则用该值替代
//     1,              // 颜色个数为 1
//     reserve,        // 固件代码中某个颜色的保留字节（固件代码中每个颜色有 4 个字节）对应固件代码中的 ltstr_scene_status_t
//     color3.r,
//     color3.g,
//     color3.b;       // 颜色
//     direction,      // 平移方向， 0 为不平移， 1 为东向， 2 为东南向，以此类推，直到 8 为东北向
//     rev,            // 保留字节，也许后续有用
//     fileName[0],    // fileName 字符串的第一个 ascii 字符值
//     fileName[1],    // fileName 字符串的第二个 ascii 字符值
//     ...
//     fileName[n],    // 以此类推
//     0,              // 用来表明 fileName 字符串结尾以利于固件 C 代码判断之用

// ### 删除数据的消息数据格式

//     scene,          // 效果的 id
//     action,         // 4: 删除数据。固件删除之前以 fileName[] 的名义保存在 flash 中的数据
//     rev,            // 保留字节，也许后续有用
//     fileName[0],    // fileName 字符串的第一个 ascii 字符值
//     fileName[1],    // fileName 字符串的第二个 ascii 字符值
//     ...
//     fileName[n],    // 以此类推
//     0,              // 用来表明 fileName 字符串结尾以利于固件 C 代码判断之用

// ### APP 向灯串发出查询文件列表请求的消息数据格式

//     scene,            // 效果的 id
//     action,           // 5: 查询文件列表
//     rev,              // 保留字节
//     fileType,         // 所要查询的文件类型， 1: 为 gif ； 2: 为 bmp

// ### 灯串应 APP 的查询文件列表请求而返回的消息数据格式(opcode 0x0211E7)

//     scene,            // 效果的 id
//     action,           // 6: 向 APP 返回当前的文件列表
//     rev,              // 保留字节
//     filesLength,      // 文件个数
//     fileType,         // 文件类型， 1: 为 gif ； 2: 为 bmp
//     file0Version,     // file0 的文件版本，范围为 1~255 递增循环
//     file0NameLength,  // file0Name 的字节长度
//     file0Name[0],     // file0Name 字符串的第一个 ascii 字符值
//     file0Name[1],     // file0Name 字符串的第二个 ascii 字符值
//     ...
//     file0Name[n],     // 以此类推
//     file1Version,
//     file1NameLength,  // file1Name 的字节长度
//     file1Name[0],     // file1Name 字符串的第一个 ascii 字符值
//     file1Name[1],     // file1Name 字符串的第二个 ascii 字符值
//     ...
//     file1Name[n],     // 以此类推
//     ...

// ### 灯串收到 APP 的保存命令但发现灯串自己曾有丢包因而无法保存转而向 APP 反馈的消息数据格式(opcode 0x0211E7)

// 灯串向 APP 返回丢包细节的数据格式如下：

//     scene,                  // 效果的 id
//     action,                 // 7: 向 APP 返回丢包细节
//     reserve,                // 保留字节
//     fileType,               // 文件类型， 1: 为 gif ； 2: 为 bmp
//     fileVersion,            // file 的文件版本，范围为 1~255 递增循环
//     fileNameLength,         // fileName 的字节长度
//     fileName[0],            // fileName 字符串的第一个 ascii 字符值
//     fileName[1],            // fileName 字符串的第二个 ascii 字符值
//     ...
//     fileName[n],            // 以此类推

//     // 这里需要考虑特殊情况：
//     // 1、灯串丢失了所有传输命令的包，这样 lostChunksLength 就不可知，然后此时又收到了保存命令
//     // 2、灯串丢失了超过 200 个包，这样本命令就有可能超过一条蓝牙命令的最大值 240 字节
//     // 这些情况下做这样的约定：maxChunkLengthLowByte 、 maxChunkLengthLowByte 和 lostChunksLength 皆设为 0
//     maxChunkLengthLowByte,     // APP 分割文件时所用的基准长度，一般与第一个 chunk 的字节长度相同，由两个字节表示，本字节为低位字节
//     maxChunkLengthHightByte,   // APP 分割文件时所用的基准长度，一般与第一个 chunk 的字节长度相同，由两个字节表示，本字节为高位字节

//     lostChunksLength,       // 共丢失了几个 chunk
//     lostChunksIndex[0],     // 所丢失的某个 chunk 的 chunksIndex （不一定是 0）
//     lostChunksIndex[1],     // 所丢失的某个 chunk 的 chunksIndex （不一定是 1）
//     ...
//     lostChunksIndex[n],     // 以此类推

                               switch (bigDataAction) {
                                    case 0: {
                                        const chunkLengthLowByte = chunk.length & 0xff;
                                        const chunkLengthHightByte = (chunk.length >> 8) & 0xff;
                                        let schema = 0;
                                        if (bigDataLostRetry) {
                                            schema |= 0x80;
                                        }
                                        // console.warn('transfer', meshAddress.toString(16), chunksIndex + '/' + (chunksCount - 1), '0x' + schema.toString(16));
                                        // NativeModule.sendCommand(0x0211E6, meshAddress, [scene, bigDataAction, speed, 1, reserve, color3.r, color3.g, color3.b, schema, datasIndex, datasCount, chunksIndex, chunksCount, sceneMode, bigDataType, chunkLengthLowByte, chunkLengthHightByte, ...chunk], this.OPCODE_INVALID, -1, immediate);
                                        this.sendCommand({
                                            opcode: 0x0211E6,
                                            meshAddress,
                                            valueArray: [scene, bigDataAction, speed, 1, reserve, color3.r, color3.g, color3.b, schema, datasIndex, datasCount, chunksIndex, chunksCount, sceneMode, bigDataType, chunkLengthLowByte, chunkLengthHightByte, ...chunk],
                                            immediate,
                                        });
                                        // 上面所花时间是下面 await rsp 的 1/3 （30个包每包200字节时测得 7s/20s），所以使用上面的
                                        // await this.sendCommandRsp({
                                        //     opcode: 0x0211E4,
                                        //     meshAddress,
                                        //     valueArray: [scene, bigDataAction, speed, 1, reserve, color3.r, color3.g, color3.b, schema, datasIndex, datasCount, chunksIndex, chunksCount, sceneMode, bigDataType, chunkLengthLowByte, chunkLengthHightByte, ...chunk],
                                        //     rspOpcode: 0x0211E7,
                                        //     relayTimes,
                                        //     retryCnt,
                                        //     tidPosition: -1,
                                        //     immediate,
                                        // });
                                        changed = true;
                                        break;
                                    }
                                    case 1: {
                                        const maxChunkLengthLowByte = maxChunkLength & 0xff;
                                        const maxChunkLengthHightByte = (maxChunkLength >> 8) & 0xff;
                                        let schema = 0;
                                        if (bigDataLostRetry) {
                                            schema |= 0x80;
                                        }
                                        // console.warn('save', {meshAddress: meshAddress.toString(16), responMax: relayTimes, bigDataAction, schema: '0x' + schema.toString(16), maxChunkLengthLowByte, bigDataType, fileVersion, text});
                                        const par = [scene, bigDataAction, schema, maxChunkLengthLowByte, maxChunkLengthHightByte, bigDataType, fileVersion, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                        if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                            par.push(parVer);
                                            par.push(meshAddresses.length);
                                            par.push(...meshAddresses);
                                        }
                                        // NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                        try {
                                            await this.sendCommandRsp({
                                                opcode: 0x0211E4,
                                                meshAddress,
                                                valueArray: par,
                                                rspOpcode: 0x0211E7,
                                                relayTimes,
                                                retryCnt,
                                                tidPosition: -1,
                                                immediate,
                                            });
                                        } catch (err) {
                                            __DEV__ && console.warn('save bigData err: ' + err.message);
                                        }
                                        changed = true;
                                        break;
                                    }
                                    case 2: {
                                        let rev = 0;
                                        // console.warn('show', bigDataAction, text, sceneMode, sceneRotate, sceneMirror);
                                        const par = [scene, bigDataAction, speed, rev, reserve, color3.r, color3.g, color3.b, sceneMode, sceneModeOpt, sceneRotate, sceneMirror, sceneDisplayRange, sceneImageResizeMode, bigDataType, 1, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                        if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                            par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                            par.push(ms & 0xff);
                                            par.push((ms >>> 8) & 0xff);
                                            par.push((ms >>> 16) & 0xff);
                                            par.push((ms >>> 24) & 0xff);
                                        } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                            par.push(parVer);
                                            par.push(meshAddresses.length);
                                            par.push(...meshAddresses);
                                        }
                                        if (this.isCreatingSceneParList) {
                                            this.sceneParList.push(par);
                                            return;
                                        }
                                        NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                        changed = true;
                                        break;
                                    }
                                    case 4: {
                                        let rev = 0;
                                        // console.warn('delete', bigDataAction, text, sceneMode);
                                        const par = [scene, bigDataAction, rev, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                        if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                            par.push(parVer);
                                            par.push(meshAddresses.length);
                                            par.push(...meshAddresses);
                                        }
                                        NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                        changed = true;
                                        break;
                                    }
                                    case 5: {
                                        let rev = 0;
                                        // console.warn('query', bigDataAction, bigDataType);
                                        const par = [scene, bigDataAction, rev, bigDataType];
                                        if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                            par.push(parVer);
                                            par.push(meshAddresses.length);
                                            par.push(...meshAddresses);
                                        }
                                        NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                        changed = true;
                                        break;
                                    }
                                    default:
                                        break;
                                }
                                break;
                            }
                            case 0xa2: {
                                                                                            // 这里的 1 是保留字节，也许后续有用                           // 这里的 0 是用来表明字符串结尾以利于固件 C 代码判断之用？
                                const par = [scene, speed, 1, reserve, color3.r, color3.g, color3.b, 1, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            case 0xa3: {
                                                                                                                     // 这里的 1 是保留字节，也许后续有用                           // 这里的 0 是用来表明字符串结尾以利于固件 C 代码判断之用？
                                const par = [scene, speed, sceneMode, sceneModeOpt, 1, reserve, color3.r, color3.g, color3.b, 1, ...Array.from(text).map((char) => char.charCodeAt()), 0];
                                if (this.isCreatingSceneParList || parVer === this.PAR_VER_useDurationInsteadOfAddresses) {
                                    par.push(this.PAR_VER_useDurationInsteadOfAddresses);
                                    par.push(ms & 0xff);
                                    par.push((ms >>> 8) & 0xff);
                                    par.push((ms >>> 16) & 0xff);
                                    par.push((ms >>> 24) & 0xff);
                                } else if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
                                    par.push(parVer);
                                    par.push(meshAddresses.length);
                                    par.push(...meshAddresses);
                                }
                                if (this.isCreatingSceneParList) {
                                    this.sceneParList.push(par);
                                    return;
                                }
                                NativeModule.sendCommand(0x0211E6, meshAddress, par, this.OPCODE_INVALID, -1, immediate);
                                changed = true;
                                break;
                            }
                            default:
                                break;
                        }
                    }
                    if (changed) {
                        // if (!this.allowSceneCadence && this.extendBearerMode !== this.EXTEND_BEARER_MODE.GATT_ADV) {
                        if (!this.allowSceneCadence) {
                            // 如果不是 EXTEND_BEARER_MODE.GATT_ADV 高速模式，实测这里需要等待才能切换那些字节数较多
                            // 的不只一个消息包的效果比如 colorsLength 大于 3 的效果，因为需要等待足够长时间以便让切换
                            // 效果的那些消息包发送完成，以免被 immediate 为 true 的 changeBrightness() 给打断
                            //
                            // 另外如果使用了 https://github.com/flyskywhy/react-native-live-audio-fft 提供的
                            // 频繁韵律能力，则不论是否 EXTEND_BEARER_MODE.GATT_ADV ，貌似都需要等待足够长时间
                            await this.sleepMs(this.DELAY_MS_COMMAND);
                            // 实测发现，当电磁环境复杂时，需要更多延时
                            await this.sleepMs(this.DELAY_MS_COMMAND);
                            await this.sleepMs(this.DELAY_MS_COMMAND);
                        }
                        this.allowSceneCadence = true;
                        break;
                    }
                }
            }
        }

        if (!changed) {
                       // 0x4282(SCENE_RECALL) in is_cmd_with_tid() vendor/common/generic_model.c is 2
            NativeModule.sendCommand(Opcode.SCENE_RECALL, meshAddress, [scene], this.OPCODE_INVALID, 2, immediate);
        }
    }

    static async selectNodeToResponseSceneId({
        sceneSyncMeshAddress,
        immediate = false,
    }) {
        if (this.needSceneSync && sceneSyncMeshAddress !== undefined && sceneSyncMeshAddress !== null && sceneSyncMeshAddress !== this.lastSceneSyncMeshAddress) {
            this.lastSceneSyncMeshAddress = sceneSyncMeshAddress;
            // 设置同步的消息里的参数里的 mesh 地址（不是消息本身的目的地址）需要传输两个字节，因为固件那里是按 u16 读取参数中的两个字节的
            let addrLowByte = sceneSyncMeshAddress & 0xFF;
            let addrHightByte = sceneSyncMeshAddress >> 8 & 0xFF;
            NativeModule.sendCommand(0x0211F2, this.defaultAllGroupAddress, [addrLowByte, addrHightByte], this.OPCODE_INVALID, -1, immediate);
            // await this.sleepMs(this.DELAY_MS_COMMAND);
        }
    }

    static saveCustomScene({
        meshAddress,
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211F5, meshAddress, [], this.OPCODE_INVALID, -1, immediate);
    }

    static getTypeFromUuid = uuid => uuid;

    static removeDeviceByMesh(address) {
        if (this.devices.length == 0) return false;
        let index = this.devices.findIndex(device => device.meshAddress == address);
        if (index !== -1) {
            this.devices.splice(index, 1);
            return true;
        }
        return false;
    }

    // claim or delete 1 device
    // claim speed is 7s with 1 device despite of PrivateDevice or not
    static configNode({
        node,
        cpsData = [], // cpsData.length not 0 means PrivateDevice
        isToClaim,
    }) {
        return new Promise((resolve, reject) => {
            let elementCnt = 0;
            let originalExtendBearerMode = this.extendBearerMode;
            if (isToClaim) {
                if (this.isClaiming) {
                    reject(new TypeError('Association already in progress. Parallel association disabled'));
                    return;
                } else {
                    this.isClaiming = true;
                }

                if (cpsData.length) {
                    let compositionData = CompositionData.from(cpsData);
                    elementCnt = compositionData.elements.length;
                }

                // If APP using EXTEND_BEARER_MODE.GATT_ADV (using telink sdk 3.3.3.5) but
                // device using telink sdk 3.1.0 (without EXTEND_BEARER_MODE idea), APP will
                // fail when claiming device, so temporarily EXTEND_BEARER_MODE.NONE here.
                // And found EXTEND_BEARER_MODE.NONE claim speed is also 7s with 1 device
                // despite of cpsData.length is 0 or not
                if (originalExtendBearerMode !== this.EXTEND_BEARER_MODE.NONE) {
                    this.resetExtendBearerMode(this.EXTEND_BEARER_MODE.NONE);
                }
            }

            let newNode = {
                ...node
            };
            if (node.dhmKey) {
                newNode.dhmKey = this.hexString2ByteArray(node.dhmKey);
            }
            NativeModule.configNode(newNode, cpsData, elementCnt, isToClaim).then(payload => {
                if (isToClaim) {
                    this.isClaiming = false;
                    if (originalExtendBearerMode !== this.EXTEND_BEARER_MODE.NONE) {
                        this.resetExtendBearerMode(originalExtendBearerMode);
                    }
                    resolve({
                        ...payload,
                        dhmKey: this.byteArray2HexString(payload.dhmKey),
                        nodeInfo: this.byteArray2HexString(payload.nodeInfo),
                    });
                } else {
                    resolve(payload);
                    this.removeDeviceByMesh(node.meshAddress);
                }
            }, err => {
                if (isToClaim) {
                    this.isClaiming = false;
                    if (originalExtendBearerMode !== this.EXTEND_BEARER_MODE.NONE) {
                        this.resetExtendBearerMode(originalExtendBearerMode);
                    }
                }
                reject(err);
            });
        });
    }

    // when firmware set FAST_PROVISION_ENABLE to 1 , can use claimAllAtOnce()
    // to claim many devices all at once(18s on Android, 25s on iOS)
    // receive (devices count) EVENT_TYPE_FAST_PROVISIONING_ADDRESS_SET at 9s so emit JS event 'deviceStatusUpdatingMesh'
    // receive EVENT_TYPE_FAST_PROVISIONING_SUCCESS at 18s so Promise resolved here
    //
    // Cons: no cpsdata received from device, so can't get device version infomation in it
    static claimAllAtOnce({
        meshAddress, // the address of the first device, other addresses will be auto += eleCnt
        privateDeviceList = Object.values(PrivateDevice.allList),
    }) {
        if (Platform.OS === 'android') {
            let pidEleCnts = [];
            privateDeviceList.map(device => {
                let compositionData = CompositionData.from(device.cpsData);
                pidEleCnts.push({
                    pid: device.pid,
                    eleCnt: compositionData.elements.length,
                })
            })
            return NativeModule.claimAllAtOnce(meshAddress, pidEleCnts);
        } else {
            let pids = [];
            privateDeviceList.map(device => {
                NativeModule.add2defaultNodeInfos(device.vid, device.pid, device.cpsData);
                pids.push(device.pid);
            })
            return NativeModule.claimAllAtOnce(meshAddress, pids);
        }

    }

    static getTotalOfGroupIndex({
        meshAddress,
    }) {}

    static setNodeGroupAddr({
        toDel,
        meshAddress,
        groupAddress,
        modelSubList = MeshSigModel.getDefaultSubList(),
    }) {

        let device = this.devices.find(device => device.meshAddress == meshAddress);
        if (device) {
            let nodeInfo = NodeInfo.from(this.hexString2ByteArray(device.nodeInfo));
            let eleIds = [];
            modelSubList.map(model => {
                let elementAddr = nodeInfo.getTargetEleAdr(model.modelId);
                if (elementAddr !== -1) {
                    eleIds.push({
                        elementAddr,
                        modelId: model.modelId,
                        isSig: model.isSig === true,
                    })
                }
            })

            return new Promise((resolve, reject) => {
                let timer = setTimeout(() => reject(new TypeError('setNodeGroupAddr time out')), 10000);
                NativeModule.setNodeGroupAddr(toDel, meshAddress, groupAddress, eleIds).then(() => {
                    clearTimeout(timer);
                    resolve();
                }, reject);
            });
        } else {
            return new Promise((resolve, reject) => reject(new TypeError('setNodeGroupAddr device null')));
        }

    }

    static setTime({
        meshAddress,
        year,
        month,
        day,
        hour,
        minute,
        second = 0,
        immediate = false,
    }) {
        if (immediate) {
            this.commandFifoConsumer.fifo.length && this.clearCommandFifo({
                opcodeImmediate: opcode,
            })
            NativeModule.setTime(meshAddress);
        } else {
            this.addCommandFifo((opcodeImmediateCancelBy) => {
                if (opcodeImmediateCancelBy !== undefined) {
                    return;
                }

                NativeModule.setTime(meshAddress);

                // 这里 timeout 的存在理由参见
                // android/src/main/java/com/telink/ble/mesh/TelinkBtSigNativeModule.java
                // 中 setTime() 处的注释
                const timeout = this.getCmdRspTimeoutMs();
                this.setNextFcTimer(timeout);
            });
        }
    }

    static getTime({
        meshAddress, // only support mesh address, no group address
        relayTimes, // should be 0 or 1
    }) {
        return new Promise((resolve, reject) => this.addCommandFifo((opcodeImmediateCancelBy) => {
            if (opcodeImmediateCancelBy !== undefined) {
                reject(new TypeError('getTime meshAddress ' + meshAddress.toString(16) + ' is canceled by opcodeImmediate ' + opcodeImmediateCancelBy.toString(16)));
                return;
            }

            const timeout = this.getCmdRspTimeoutMs();
            let timer = setTimeout(() => {
                reject(new TypeError('getTime @' + meshAddress + ' time out ' + timeout + 'ms'))
                this.setNextFcTimer();
            }, timeout);
            NativeModule.getTime(meshAddress, relayTimes).then(payload => {
                clearTimeout(timer);
                resolve({
                    ...payload,
                    time: parseInt(payload.time, 10), // seconds from 1970
                });
                this.setNextFcTimer();
            }, error => {
                clearTimeout(timer);
                // after retry in native (DEFAULT_RETRY_CNT = 2 in android/src/main/java/com/telink/ble/mesh/core/message/MeshMessage.java)
                // still error then reject here to APP
                reject(error);
                this.setNextFcTimer();
            });
        }));
    }

    static setAlarm({
        meshAddress,
        alarmId,
        year = this.ALARM_YEAR_ANY,
        month,
        day = this.ALARM_DAY_ANY,
        hour,
        minute,
        second = 0,
        week = this.ALARM_WEEK_ALL,
        action,
        type,
        sceneId = 0,
        immediate = false,
    }) {
        let realDay = day;
        let realWeek = week;
        if (type === this.ALARM_TYPE_DAY) {
            realDay = new Date().getDate();
            realWeek = 0;
        }

        if (immediate) {
            this.commandFifoConsumer.fifo.length && this.clearCommandFifo({
                opcodeImmediate: opcode,
            })
            NativeModule.setAlarm(meshAddress, alarmId, year, month !== undefined ? 1 << month : this.ALARM_MONTH_ALL, realDay, hour, minute, second, realWeek, action, sceneId);
        } else {
            this.addCommandFifo((opcodeImmediateCancelBy) => {
                if (opcodeImmediateCancelBy !== undefined) {
                    return;
                }

                NativeModule.setAlarm(meshAddress, alarmId, year, month !== undefined ? 1 << month : this.ALARM_MONTH_ALL, realDay, hour, minute, second, realWeek, action, sceneId);
                this.setNextFcTimer();
            });
        }
    }

    static getAlarm({
        meshAddress, // only support mesh address, no group address
        relayTimes, // should be 0 or 1
        alarmId,
    }) {
        return new Promise((resolve, reject) => this.addCommandFifo((opcodeImmediateCancelBy) => {
            if (opcodeImmediateCancelBy !== undefined) {
                reject(new TypeError('getAlarm meshAddress ' + meshAddress.toString(16) + ' alarmId ' + alarmId + ' is canceled by opcodeImmediate ' + opcodeImmediateCancelBy.toString(16)));
                return;
            }

            const timeout = this.getCmdRspTimeoutMs();
            let timer = setTimeout(() => {
                reject(new TypeError('getAlarm ' + alarmId + '@' + meshAddress + ' time out ' + timeout + 'ms'));
                this.setNextFcTimer();
            }, timeout);
            NativeModule.getAlarm(meshAddress, relayTimes, alarmId).then(payload => {
                clearTimeout(timer);
                if (payload.action === 0 && payload.week === 0 && payload.month === 0 && payload.year === 0) {
                    reject(new TypeError(payload.alarmId + ' getAlarm data 0'))
                } else {
                    resolve({
                        alarmId: payload.alarmId,
                        year: payload.year,
                        month: payload.month,
                        day: payload.day,
                        hour: payload.hour,
                        minute: payload.minute,
                        second: payload.second,
                        week: payload.week,
                        action: payload.action,
                        transTime: payload.transTime,
                        sceneId: payload.sceneId,

                        status: payload.action === this.ALARM_ACTION_NO ? 0 : 1,
                        type: payload.day === 0 ? this.ALARM_TYPE_WEEK : this.ALARM_TYPE_DAY,
                    });
                }
                this.setNextFcTimer();
            }, error => {
                clearTimeout(timer);
                // after retry in native (DEFAULT_RETRY_CNT = 2 in android/src/main/java/com/telink/ble/mesh/core/message/MeshMessage.java)
                // still error then reject here to APP
                reject(error);
                this.setNextFcTimer();
            });
        }));
    }

    static cascadeLightStringGroup({ // 用于将一个组中的几个灯串级联模拟成一个灯串
        meshAddress,
        cascadeSeq = 1, // 向固件表明当前节点（一般为灯串）所处级联顺序，从 1 开始计数；如为 0 则代表退出级联模式
        groupNodes = 4, // 参与级联的灯串总数，也即 group.length
        groupBulbs = 96 * 4, // 参与级联总灯珠个数
        bulbOffset = 0, // 当前灯串首个灯珠地址偏移量，从 0 开始计数
        largestBulbs = 96, // 拥有最多灯珠的那个灯串上的灯珠数
        groupWidth = 0, // 用于二维，表示所有灯串整体覆盖范围的宽度
        groupHeight = 0,
        nodeX = 0, // 用于二维，表示某个灯串的左上角在 groupWidth 中的坐标
        nodeY = 0,
        nodeWidth = 0, // 用于二维，表示某个灯串的宽度
        nodeHeight = 0,
        largestWidth = 0, // 用于二维，表示宽度最宽的灯串的宽度，该灯串不一定是 largestHeight 相关的同一个灯串
        largestHeight = 0,
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211EE, meshAddress, [
            cascadeSeq,
            groupNodes,
            groupBulbs & 0xFF,
            groupBulbs >>> 8 & 0xFF,
            bulbOffset & 0xFF,
            bulbOffset >>> 8 & 0xFF,
            largestBulbs & 0xFF,
            largestBulbs >>> 8 & 0xFF,
            groupWidth & 0xFF,
            groupWidth >>> 8 & 0xFF,
            groupHeight & 0xFF,
            groupHeight >>> 8 & 0xFF,
            nodeX & 0xFF,
            nodeX >>> 8 & 0xFF,
            nodeY & 0xFF,
            nodeY >>> 8 & 0xFF,
            nodeWidth,
            nodeHeight,
            largestWidth,
            largestHeight,
        ], this.OPCODE_INVALID, -1, immediate);
    }

    static rgbSequence = {
        rgb: 1,
        RGB: 1,
        rbg: 2,
        RBG: 2,
        brg: 3,
        BRG: 3,
        bgr: 4,
        BGR: 4,
        grb: 5,
        GRB: 5,
        gbr: 6,
        GBR: 6,
    };

    static flashWriteAttr({ // 设置灯串信息（工厂使用）
        meshAddress,
        timeSequence = 1, // 灯串时序，1 为短时序，0 为长时序
        nodeBulbs = 96, // 灯串上激活灯珠的个数,最大值为 65535
        collideCenter = 40, // 碰撞特效的碰撞位置，因为灯串摆成树形时，碰撞位置如果为总灯数的 1/2 的话不好看
        flagPercent = 100, // 国旗模式下相邻两个颜色所属灯串长度百分比
        gamma_enable = 0,  // 是否启用灯串固件内置 gamma 校正，一般不校正，否则（可能固件代码有 BUG 导致）颜色不正常
        rgbSequence = 'rgb', // 灯珠的 rgb 顺序
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211E8, meshAddress, [
            nodeBulbs & 0xFF,
            timeSequence,
            collideCenter,
            flagPercent,
            gamma_enable,
            (nodeBulbs >>> 8) & 0xFF,
            this.rgbSequence.hasOwnProperty(rgbSequence) ? this.rgbSequence[rgbSequence] : 1,
        ], this.OPCODE_INVALID, -1, immediate);
    }

    static flashWriteAttrByUser({ // 设置灯串信息（普通用户使用）
        meshAddress,
        nodeBulbs = 96, // 灯串上激活灯珠的个数,最大值为 65535
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211F7, meshAddress, [
            nodeBulbs & 0xFF,
            (nodeBulbs >>> 8) & 0xFF,
        ], this.OPCODE_INVALID, -1, immediate);
    }

    static getNodeInfoWithNewType({
        nodeInfo = '',
        newType = 0xA5A5,
    }) {
        if (nodeInfo.length > 26 * 2) { // nodeInfo 里存的是 hexString ，每 2 个字符代表一个字节，所以需要 * 2
            let bytes = this.hexString2ByteArray(nodeInfo);
            bytes[24] = newType & 0xFF;
            bytes[25] = (newType >>> 8) & 0xFF;
            return this.byteArray2HexString(bytes);
        } else {
            return nodeInfo;
        }
    }

    // If node comes from configNode(), the nodeInfo comes from device, so the version in nodeInfo is correct;
    // if node comes from claimAllAtOnce(), the nodeInfo comes from predefined value in PrivateDevice.js ,
    // so the version in nodeInfo is not correct, except developer can invoke valid getFirmwareVersion()
    // and update nodeInfo by getNodeInfoWithNewFwVer() later
    static getFwVerInNodeInfo({
        nodeInfo = '',
    }) {
        let bytes = this.hexString2ByteArray(nodeInfo);
        let version = String.fromCharCode(bytes[26], bytes[27]);
        return version;
    }

    static getNodeInfoWithNewFwVer({
        nodeInfo = '',
        newFwVer = '',
    }) {
        if (nodeInfo.length > 28 * 2 && newFwVer.length === 2) { // nodeInfo 里存的是 hexString ，每 2 个字符代表一个字节，所以需要 * 2
            let bytes = this.hexString2ByteArray(nodeInfo);
            bytes[26] = newFwVer.charCodeAt(0);
            bytes[27] = newFwVer.charCodeAt(1);
            return this.byteArray2HexString(bytes);
        } else {
            return nodeInfo;
        }
    }

    static getFirmwareVersion({
        meshAddress = this.defaultAllGroupAddress,
        relayTimes = 7,
        immediate = false,
    }) {
        if (this.canMeshOta) {
            NativeModule.sendCommand(0x01B6, meshAddress, [0, 1], 0x02B6, -1, immediate);
            // NativeModule.getFirmwareInfo(meshAddress);
        } else {
            this.sendCommandRsp({
                opcode: 0x0211F9,
                meshAddress,
                valueArray: [1],        // 0x0211F9 means get, and 1 means (get) fw version in my product
                rspOpcode: 0x0211FB,    // 0x0211FB means status in my product
                immediate,
            });
        }
    }

    static setScene2d({
        meshAddress = this.defaultAllGroupAddress,
        meshAddresses = [],
        scene = 11,
        isScene2d = true,
        parVer = this.useAddressesInsteadOfGroup === true ? this.PAR_VER_useAddressesInsteadOfGroup : this.PAR_VER_init,
        relayTimes = 7,
        immediate = false,
    }) {
        const par =[
            2,                          // 2 means (set) scene 2d in my product
            scene,
            isScene2d ? 1 : 0,
        ];
        if (parVer === this.PAR_VER_useAddressesInsteadOfGroup) {
            par.push(parVer);
            par.push(meshAddresses.length);
            par.push(...meshAddresses);
        }
        this.sendCommand({
            opcode: 0x0211FA,           // 0x0211FA means set without rsp in my product
            meshAddress,
            valueArray: par,
            immediate,
        });

    }

    // 是否是两个发布版本之间的测试版本
    static isTestFw({
        fwVer,
    }) {
        // 一般发布版本号都是 '16' 代表 v1.6 之类的，类似 'g7' 或 'h7' 或 'i7' 之类的代表正在开发中的下一个版本的测试版本
        return 'a' <= fwVer[0] && fwVer[0] <= 'z';
    }

    // 在 react-native-bt-telink 中曾用，现在 react-native-btsig-telink 中应该无用
    static getOtaState({
        meshAddress = 0x0000,
        relayTimes = 7,
        immediate = false,
    }) {
        // NativeModule.sendCommand(0xC7, meshAddress, [
        //     relayTimes,
        //     5,  // 0xC7 的子命令，5 为获取 OTA 状态
        // ], this.OPCODE_INVALID, -1, immediate);
    }

    // 在 react-native-bt-telink 中曾用，现在 react-native-btsig-telink 中应该无用
    static setOtaMode({
        meshAddress = 0x0000,
        relayTimes = 7,     // 转发次数
        otaMode = 'gatt',   // OTA 模式， gatt 为单灯升级， mesh 为单灯升级后由单灯自动通过 mesh 网络发送新固件给其它灯
        type = 0xFB00,      // 设备类型（gatt OTA 模式请忽略此字段）
        immediate = false,
    }) {
        // NativeModule.sendCommand(0xC7, meshAddress, [
        //     relayTimes,
        //     6,  // 0xC7 的子命令，6 为设置 OTA 模式(OTA mode)与设备类型(Device type)
        //     otaMode === 'mesh' ? 1 : 0,
        //     type & 0xFF,
        //     type >>> 8 & 0xFF,
        // ], this.OPCODE_INVALID, -1, immediate);
    }

    static stopMeshOta({}) {
        NativeModule.stopMeshOTA();
    }

    static startOta({
        mac,
        meshAddresses,
        firmware,
    }) {
        if (meshAddresses) {
            // TODO: debug, cause getFirmwareInfo above and startMeshOTA here need mesh OTA code as described in comments of `canMeshOta =`,
            // please use startOta instead for now
            NativeModule.startMeshOTA(meshAddresses, firmware);
        } else {
            // TODO: debug startOta on iOS, cause for me, it's boring that DocumentPicker (firmware file) requires the iCloud entitlement,
            // and startOta can be done with Android on my project. The startOta code on iOS is ready, maybe someone test it and PR me.
            return NativeModule.startOta(mac, firmware);
        }
    }

    // 在 react-native-bt-telink 中曾用，现在 react-native-btsig-telink 中应该无用
    static pauseMeshOta() {}

    // 在 react-native-bt-telink 中曾用，现在 react-native-btsig-telink 中应该无用
    static continueMeshOta() {}

    // after import data shared by others, to avoid restart APP and
    // instantly connect to device, you should let your APP call
    // replaceMeshSetting then call autoConnect
    static replaceMeshSetting() {
        // NativeModule.replaceMeshSetting(this.netKey, this.appKey, this.devices.map(device => {
        //     return { ...device,
        //         dhmKey: this.hexString2ByteArray(device.dhmKey),
        //         nodeInfo: this.hexString2ByteArray(device.nodeInfo),
        //     };})
        // );
        NativeModule.replaceMeshSetting6(this.netKey, this.appKey, this.meshAddressOfApp, this.devices.map(device => {
            return { ...device,
                dhmKey: this.hexString2ByteArray(device.dhmKey),
                nodeInfo: this.hexString2ByteArray(device.nodeInfo),
            };}), this.provisionerSno, this.provisionerIvIndex
        );
    }

    static isValidFirmware(firmware) {
        return (firmware[0] === 0x26 || // telink sdk 3.1.0
            firmware[0] === 0x56) && // telink sdk 3.3.3.5
            (firmware[1] & 0xFF) === 0x80 &&
            firmware.length > 6;
    }
}

module.exports = TelinkBtSig;
