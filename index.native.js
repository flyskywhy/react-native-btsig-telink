const {
    NativeModules,
    DeviceEventEmitter,
    NativeEventEmitter,
    Platform
} = require('react-native');
const NativeModule = NativeModules.TelinkBtSig;
const tinycolor = require("tinycolor2");

class TelinkBtSig {
    static MESH_ADDRESS_MIN = 0x0001;
    static MESH_ADDRESS_MAX = 0x00FF;

    // 虽然 bluetooth SIG mesh 协议理论上一个 mesh 网络最多支持
    // 32767 个设备，不过一般比如植物照明工厂最多拥有两百多盏灯，差
    // 不多刚好一般蓝牙模块提供商代码中所写的最大地址 255 ，而且天猫
    // 或小米等相关产品的设备数都在 100 以内，由于设备数越多，需要设
    // 备上的 ram 越大，越贵，所以一般蓝牙模块提供商只会批量提供 ram
    // 刚够用 200 设备数左右的模块。
    // 另外，在 `SIG Mesh iOS APP(OC版本)使用以及开发手册.docx`
    // 中提到地址范围是 1~0x7eff
    // static MESH_ADDRESS_MAX = 0x7EFF;
    // static MESH_ADDRESS_MAX = 0x7FFF;

    static GROUP_ADDRESS_MIN = 0xC001;
    static GROUP_ADDRESS_MAX = 0xC0FF;
    // static GROUP_ADDRESS_MAX = 0xFEFF;
    static GROUP_ADDRESS_MASK = 0x00FF;
    static HUE_MIN = 0;
    static HUE_MAX = 360;
    static SATURATION_MIN = 0;
    static SATURATION_MAX = 100;
    static BRIGHTNESS_MIN = 45; // 实测灯串不会随着亮度变化而改变颜色的最低亮度，比如 30 的话就代表 30%
    static BRIGHTNESS_MAX = 100;
    static LED_GREEN_MAX = 65;  // 如果 LED 中绿色灯珠容易烧坏，此处记录着实际（也就是经过下面的 whiteBalance 之后）发给灯珠不会烧坏的最大值，比如 65 代表 65/255
    static COLOR_TEMP_MIN = 5;
    static COLOR_TEMP_MAX = 100;
    static NODE_STATUS_OFF = 0;
    static NODE_STATUS_ON = 1;
    static NODE_STATUS_OFFLINE = -1;
    static RELAY_TIMES_MAX = 16;
    static DELAY_MS_AFTER_UPDATE_MESH_COMPLETED = 500;
    // telink sig mesh 的 SDK 中没有自带命令队列然后自动在命令间加入延时，所以需要
    // 手动加入足够延时，否则比如连续两次设置开关，则第 2 个设备极有可能收不到开关命令
    static DELAY_MS_COMMAND = 500;
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
    static whiteBalance = { // cooler
        r: 1,
        g: 0.6,
        b: 0.24,
    };
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

    static needRefreshMeshNodesBeforeConfig = true;
    static canConfigEvenDisconnected = true;
    static needClaimedBeforeConnect = true;
    static isClaiming = false;

    static del4GroupStillSendOriginGroupAddress = true;
    static defaultAllGroupAddress = 0xFFFF;
    static isSetNodeGroupAddrReturnAddresses = false;

    // 需要如下两个变量来保证韵律期间频发音量转亮度 changeBrightness() 的情况下也能正常 changeScene() ，
    // 否则在两串灯时， All 组，开启韵律后，切换效果很多时候只有一盏灯能切换效果，另外一盏没变
    static isSceneCadenceBusy = false;
    static allowSceneCadence = true;

    static netKey = 'netKey';
    static appKey = 'appKey';
    // 测试得：手机 mesh 地址不能设为 0 ，也不能设为 >= 32768
    // 分享相同蓝牙设备数据的两台手机各自的 APP 需要不同的手机 mesh 地址，否则无法同时控制设备
    static meshAddressOfApp = this.MESH_ADDRESS_MAX + parseInt(Math.random() * 10000, 10);
    static devices = [];
    static provisionerSno = 0;

    static otaFileVersionOffset = 4;    // 把二进制固件作为一个字节数组看待的话，描述着版本号的第一个字节的数组地址
    static otaFileVersionLength = 2;    // 二进制固件中描述版本号用了几个字节

    static lastSceneSyncMeshAddress = undefined;

    static doInit() {
        NativeModule.doInit(this.netKey, this.appKey, this.meshAddressOfApp, this.devices.map(device => {
            return { ...device,
                dhmKey: this.hexString2ByteArray(device.dhmKey),
                nodeInfo: this.hexString2ByteArray(device.nodeInfo),
            };
        }), this.provisionerSno);
    }

    static doDestroy() {
        NativeModule.doDestroy();
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

    static enableBluetooth() {
        NativeModule.enableBluetooth();
    }

    static enableSystemLocation() {
        NativeModule.enableSystemLocation();
    }

    static notModeAutoConnectMesh() {
        return NativeModule.notModeAutoConnectMesh();
    }

    static autoConnect({
        userMeshPwd,
    }) {
        return NativeModule.autoConnect(userMeshPwd);
    }

    static async postConnected({
        meshAddress,
        type,
        immediate = false,
    }) {
        this.remind({
            meshAddress: 0xFFFF,
        })

        await this.sleepMs(this.DELAY_MS_COMMAND);

        let changed = false;

        if (this.passthroughMode) {
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(type)) {
                    if (mode === 'silan') {
                        // 估计是 telink sig Android SDK 或固件的 bug ，在多个灯串时莫名
                        // 返回离线，所以只能无视 public void saveOrUpdateJS() 中对
                        // hasOnlineStatusNotifyRaw 的赋值，而强制给这里的 if 喂 true
                        if (true /* !this.hasOnlineStatusNotifyRaw */) {
                            // 它返回 的 onVendorResponse 的 opcode 是 0x0211E3
                            NativeModule.sendCommand(0x0211E1, 0xFFFF, [0x00, 0x00], immediate);

                            // 可能因为上面的 this.remind 导致固件开灯了一会而需要再次查看开关状态
                            await this.sleepMs(this.DELAY_MS_COMMAND);
                            NativeModule.sendCommand(0x0211E1, 0xFFFF, [0x00, 0x00], immediate);
                            // 测试发现还需要再次查看开关状态才能保证关灯情况下 APP 打开时能获得 2 个设备的关灯状态
                            await this.sleepMs(this.DELAY_MS_COMMAND);
                            NativeModule.sendCommand(0x0211E1, 0xFFFF, [0x00, 0x00], immediate);
                            changed = true;
                        }
                    }
                    break;
                }
            }
        }

        if (!changed) {
            if (!this.hasOnlineStatusNotifyRaw) {
                // 如果后续从蓝牙设备固件代码中得知 telink 也实现了（应该实现了） sig mesh 协议中
                // model 之间关联功能，放到这里就是实现了亮度 modle 如果亮度为 <= 0 的话就会关联
                // 开关灯 model 为关灯状态，则此处可以不再使用 getOnOff 而只用 getCtl 等代替
                NativeModule.sendCommand(0x0182, 0xFFFF, [], immediate); // mService.getOnOff(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_DEVICE_ON_OFF_STATUS

                // 测试得：如果紧接着上面 getOnOff 后立即进行其它 get ，则只会触发 getOnOff 对应的 EVENT，因此需要延迟进行
                await this.sleepMs(this.DELAY_MS_COMMAND);
                // 因为此处只会返回第一个 get 函数的结果，所以那些注释掉的 get 函数仅用于测试
                // NativeModule.sendCommand(0x0582, 0xFFFF, [], immediate); // mService.getLevel(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_DEVICE_LEVEL_STATUS
                // NativeModule.sendCommand(0x4B82, 0xFFFF, [], immediate); // mService.getLightness(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_LIGHTNESS_STATUS_NOTIFY

                // 如 TelinkBtSigNativeModule.java 的 onGetLevelNotify() 中注释所说，使用 onGetCtlNotify() 更简洁
                NativeModule.sendCommand(0x5D82, 0xFFFF, [], immediate); // mService.getCtl(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_CTL_STATUS_NOTIFY

                // NativeModule.sendCommand(0x6182, 0xFFFF, [], immediate); // mService.getTemperature(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_TEMP_STATUS_NOTIFY
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
        timeoutSeconds,
        isSingleNode,
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

    static sendCommand({
        opcode,
        meshAddress,
        valueArray,
        immediate = false,
    }) {
        NativeModule.sendCommand(opcode, meshAddress, valueArray, immediate);
    }

    static remind({
        meshAddress,
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211F0, meshAddress, [0x00, 0x00], immediate);
    }

    static isOnline(status) {
        return (status) !== this.NODE_STATUS_OFFLINE;
    }

    static isOn(status) {
        return (status) === this.NODE_STATUS_ON;
    }

    static changePower({
        meshAddress,
        value,
        type,
        delaySec = 0,
        immediate = false,
    }) {
        let changed = false;

        if (this.passthroughMode) {
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(type)) {
                    if (mode === 'silan') {
                        // 测试得：不论这里是 [0, 0, value] 还是 [0xE3, 0x02, value] ，返回
                        // 的 onVendorResponse 的 opcode 都是 0x0211E3
                        // NativeModule.sendCommand(this.hasOnlineStatusNotifyRaw ? 0x0211E2 : 0x0211E0, meshAddress, [0xE3, 0x02, value], immediate);
                        // 按说在 this.hasOnlineStatusNotifyRaw 的情况下，只要使用上面的无需返回开关灯的开关命令 E2 即可，但是发现当在界面上快速点击开关的情况下，
                        // 只有下面的开关命令 E0 额外返回的开关状态才能保证开关按钮的状态能够快速切换且能快速地开关灯。
                        NativeModule.sendCommand(0x0211E0, meshAddress, [0xE3, 0x02, value], immediate);
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
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(type)) {
                    if (mode === 'silan') {
                        if (this.allowSceneCadence) {
                            this.isSceneCadenceBusy = true;
                            NativeModule.sendCommand(0x0211F3, meshAddress, [0, 0, value], immediate);
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
    }) {
        if (g > this.LED_GREEN_MAX) {
            return {
                r: parseInt(r * this.LED_GREEN_MAX / g, 10),
                g: this.LED_GREEN_MAX,
                b: parseInt(b * this.LED_GREEN_MAX / g, 10),
            }
        } else {
            return {
                r,
                g,
                b,
            }
        }
    }

    static async changeScene({
        meshAddress,
        sceneSyncMeshAddress,
        scene,
        hue = 0,
        saturation = 0,
        value,
        color,
        colorBg,
        colors = [],
        colorsLength = 1,
        colorSequence = 1,
        colorIds = [1, 2, 3, 4, 5],
        colorBgId = 2,
        colorId = 1,
        data = [],
        isEditingCustom = false,
        speed = 3,
        type,
        immediate = false,
    }) {
        if (this.isSceneCadenceBusy) {
            this.allowSceneCadence = false;
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
            } else {
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
            if (color3Bg) {
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
            colors.map(colour => {
                colors3.push(0);    // 0 是固件代码中某个颜色的保留字节（固件代码中每个颜色有 4 个字节）
                let rgb = tinycolor(colour).toRgb();
                // rgb.r = this.ledFilter3040(rgb.r);
                // rgb.g = this.ledFilter3040(rgb.g);
                // rgb.b = this.ledFilter3040(rgb.b);
                rgb.r = parseInt(this.gamma[rgb.r] * this.whiteBalance.r, 10);
                rgb.g = parseInt(this.gamma[rgb.g] * this.whiteBalance.g, 10);
                rgb.b = parseInt(this.gamma[rgb.b] * this.whiteBalance.b, 10);
                let safeColor = this.ledFilterBurnGreen(rgb);
                rgb.r = safeColor.r;
                rgb.g = safeColor.g;
                rgb.b = safeColor.b;
                colors3.push(rgb.r);
                colors3.push(rgb.g);
                colors3.push(rgb.b);
            });
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(type)) {
                    if (mode === 'silan') {
                        if (!isEditingCustom) {
                            this.selectNodeToResponseSceneId({
                                sceneSyncMeshAddress,
                            });
                        }

                        let patchedSpeed = speed - 3;   // 不过如下所示没有使用 patchedSpeed 的就是那些无法使用跳帧（固件判断是负值的话就会跳帧）的效果
                        switch (scene) {
                            case 0:                                                             //这里的 1 是颜色个数， 0 是固件代码中某个颜色的保留字节（固件代码中每个颜色有 4 个字节）对应固件代码中的 ltstr_scene_status_t，下同
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 1:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, speed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 2:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 3:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, speed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 4:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 5:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, speed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 6:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 7:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 8:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, speed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 9:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, speed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 10:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 11:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 12:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 13:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 2, 0, color3.r, color3.g, color3.b, 0, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            case 14:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 15:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 16:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 17:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 18:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 19:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 20:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 21:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 2, 0, color3.r, color3.g, color3.b, 0, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            case 22:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 23:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 24:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 25:
                                // 这里对 patchedSpeed 做特殊处理以不传 0 给固件，是因为固件代码 e12005a 提交点会使得该效果在速度为零时，第二轮效果飞快运行，找不到根本的解决方法，那就将错就错吧
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed >= 0 ? patchedSpeed + 1 : patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 26:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 2, 0, color3.r, color3.g, color3.b, 0, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            case 27:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 28:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 29:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 30:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 31:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 32:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 33:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 34:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 2, 0, color3.r, color3.g, color3.b, 0, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            case 35:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 36:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 37:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 38:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 39:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 40:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 1, 0, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 41:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 42:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, 2, 0, color3.r, color3.g, color3.b, 0, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            case 43:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;
                            case 44:
                                NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed, colorsLength, ...colors3], immediate);
                                changed = true;
                                break;

                            // [
                            //     // 以下是自定义效果命令参数中每个字节的含义
                            //     0,                  // telink sig mesh 的命令中必需的字节，表示固件返回的 opcode ，暂时发现可以为 0
                            //     0,                  // telink sig mesh 的命令中必需的字节，表示消息返回的跳跃次数，暂时发现可以为 0
                            //     scene,              // 效果的 id
                            //     speed,              // 效果的整体速度，在目前自定义效果只有一帧的情况下，可以为 2
                            //     dataType,           // 后续数据的压缩类型， 0 代表无压缩
                            //     dataLengthLowByte,  // 后续数据压缩后的字节长度，由两个字节表示，本字节为低位字节，本字节并不计算在该长度之内
                            //     dataLengthHightByte,// 后续数据压缩后的字节长度，由两个字节表示，本字节为高位字节，本字节并不计算在该长度之内
                            //     [   // 实际的 sig mesh 命令参数中是没有本中括号以及下面中括号的，放在这里是为了表明这里就像是二维数组一样，
                            //         // 然后数组中所有元素的 subdataLength 相加其实就等于上面提到的 dataLength
                            //         [
                            //             subdataLength,  // 本子数据的长度，本字节也计算在该长度之内，在本例子中，该长度为 7
                            //             bulbsMode,      // 本小段灯珠的变化模式， 0 为简单常亮， 1 为简单闪烁， 2 为简单呼吸
                            //             bulbsStart,     // 本小段灯珠的起始地址
                            //             bulbsLength,    // 本小段灯珠的个数
                            //             bulbsColorR,    // 本小段灯珠颜色的 R 的值
                            //             bulbsColorG,    // 本小段灯珠颜色的 G 的值
                            //             bulbsColorB,    // 本小段灯珠颜色的 B 的值
                            //         ]
                            //     ]
                            // ]

                            // 下面是一段 NativeModule.sendCommand 命令参数数组的示例
                            // [
                            //     0,
                            //     0,
                            //     128,// 效果的 id 也就是 0x80
                            //     2,  // 速度 暂时无用
                            //     0,  // 0 代表无压缩
                            //     14, // 数据字节长度的低位字节
                            //     0,  // 数据字节长度的高位字节，无压缩情况下一般只有一个灯珠的话，数据字节是 7 ，这里是 14 （结合上面的低位字节来看），代表有两段数据
                            //     7,  // subdataLength
                            //     0,  // bulbsMode
                            //     0,  // bulbsStart
                            //     4,  // bulbsLength
                            //     255,// bulbsColorR
                            //     0,  // bulbsColorG
                            //     0,  // bulbsColorB
                            //     7,  //下同
                            //     0,
                            //     12,
                            //     1,
                            //     255,
                            //     0,
                            //     0
                            // ]

                            case 0x80: {
                                let rawData = [];
                                data.map(subdata => {
                                    let bulbsMode = subdata[0];
                                    if (bulbsMode > 0) {
                                        let subdataLength = 7;
                                        let bulbsStart = subdata[1];
                                        let bulbsLength = subdata[2];
                                        // let bulbsColorR = this.ledFilter3040(subdata[3] >> 16 & 0xFF);
                                        // let bulbsColorG = this.ledFilter3040(subdata[3] >> 8 & 0xFF);
                                        // let bulbsColorB = this.ledFilter3040(subdata[3] & 0xFF);
                                        let bulbsColorR = parseInt(this.gamma[subdata[3] >> 16 & 0xFF] * this.whiteBalance.r, 10);
                                        let bulbsColorG = parseInt(this.gamma[subdata[3] >> 8 & 0xFF] * this.whiteBalance.g, 10);
                                        let bulbsColorB = parseInt(this.gamma[subdata[3] & 0xFF] * this.whiteBalance.b, 10);
                                        let safeColor = this.ledFilterBurnGreen({
                                            r: bulbsColorR,
                                            g: bulbsColorG,
                                            b: bulbsColorB,
                                        });
                                        bulbsColorR = safeColor.r;
                                        bulbsColorG = safeColor.g;
                                        bulbsColorB = safeColor.b;
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
                                    NativeModule.sendCommand(0x0211F4, meshAddress, [0, 0, scene, patchedSpeed, dataType, dataLengthLowByte, dataLengthHightByte, ...rawData], immediate);
                                } else {
                                    NativeModule.sendCommand(0x0211E6, meshAddress, [0, 0, scene, patchedSpeed], immediate);
                                    await this.sleepMs(this.DELAY_MS_COMMAND);
                                    // 这里一定要先发上面的效果切换命令 0xE4 ，再发下面的自定义效果数据命令 0xF4 ，否则数据较大时无法切换
                                    NativeModule.sendCommand(0x0211F4, meshAddress, [0, 0, scene, patchedSpeed, dataType, dataLengthLowByte, dataLengthHightByte, ...rawData], immediate);
                                }
                                changed = true;
                                break;
                            }
                            default:
                                break;
                        }
                    }
                    if (changed) {
                        await this.sleepMs(this.DELAY_MS_COMMAND);
                        this.allowSceneCadence = true;
                        break;
                    }
                }
            }
        }

        if (!changed) {
            // NativeModule.sendCommand(0xEF, meshAddress, [scene], immediate);
        }
    }

    static async selectNodeToResponseSceneId({
        sceneSyncMeshAddress,
        immediate = false,
    }) {
        if (sceneSyncMeshAddress !== undefined && sceneSyncMeshAddress !== null && sceneSyncMeshAddress !== this.lastSceneSyncMeshAddress) {
            this.lastSceneSyncMeshAddress = sceneSyncMeshAddress;
            // 设置同步的消息里的参数里的 mesh 地址（不是消息本身的目的地址）需要传输两个字节，因为固件那里是按 u16 读取参数中的两个字节的
            let addrLowByte = sceneSyncMeshAddress & 0xFF;
            let addrHightByte = sceneSyncMeshAddress >> 8 & 0xFF;
            NativeModule.sendCommand(0x0211F2, this.defaultAllGroupAddress, [0, 0, addrLowByte, addrHightByte], immediate);
            await this.sleepMs(this.DELAY_MS_COMMAND);
        }
    }

    static saveCustomScene({
        meshAddress,
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211F5, meshAddress, [0, 0], immediate);
    }

    static getTypeFromUuid = uuid => uuid;

    static configNode({
        node,
        isToClaim,
        immediate = false,
    }) {
        return new Promise((resolve, reject) => {
            if (isToClaim) {
                if (this.isClaiming) {
                    reject('Association already in progress. Parallel association disabled');
                    return;
                } else {
                    this.isClaiming = true;
                }
            }

            let newNode = {
                ...node
            };
            if (node.dhmKey) {
                newNode.dhmKey = this.hexString2ByteArray(node.dhmKey);
            }
            NativeModule.configNode(newNode, isToClaim).then(payload => {
                if (isToClaim) {
                    this.isClaiming = false;
                    resolve({
                        ...payload,
                        dhmKey: this.byteArray2HexString(payload.dhmKey),
                        nodeInfo: this.byteArray2HexString(payload.nodeInfo),
                    });
                } else {
                    resolve(payload);
                }
            }, err => {
                if (isToClaim) {
                    this.isClaiming = false;
                }
                reject(err);
            });
        });
    }

    static getTotalOfGroupIndex({
        meshAddress,
    }) {}

    static setNodeGroupAddr({
        toDel,
        meshAddress,
        groupAddress,
    }) {
        return new Promise((resolve, reject) => {
            let timer = setTimeout(() => reject({errCode: 'setNodeGroupAddr time out'}), 10000);
            NativeModule.setNodeGroupAddr(toDel, meshAddress, groupAddress).then(() => {
                clearTimeout(timer);
                resolve();
            }, reject);
        });
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
        NativeModule.setTime(meshAddress);
    }

    static getTime({
        meshAddress,
        relayTimes,
    }) {
        return new Promise((resolve, reject) => {
            let timer = setTimeout(() => reject({errCode: 'getTime time out'}), 10000);
            NativeModule.getTime(meshAddress, relayTimes).then(payload => {
                clearTimeout(timer);
                resolve(payload);
            }, reject);
        });
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

        NativeModule.setAlarm(meshAddress, alarmId, year, month !== undefined ? 1 << month : this.ALARM_MONTH_ALL, realDay, hour, minute, second, realWeek, action, sceneId);
    }

    static getAlarm({
        meshAddress,
        relayTimes,
        alarmId,
    }) {
        return new Promise((resolve, reject) => {
            let timer = setTimeout(() => reject({errCode: alarmId + ' getAlarm time out'}), 10000);
            NativeModule.getAlarm(meshAddress, relayTimes, alarmId).then(payload => {
                clearTimeout(timer);
                if (payload.action === 0 && payload.week === 0 && payload.month === 0 && payload.year === 0) {
                    reject({errCode: payload.alarmId + ' getAlarm data 0'})
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
            }, reject);
        });
    }

    static cascadeLightStringGroup({ // 用于将一个组中的几个灯串级联模拟成一个灯串
        meshAddress,
        cascadeSeq = 1, // 向固件表明当前节点（一般为灯串）所处级联顺序，从 1 开始计数；如为 0 则代表退出级联模式
        groupNodes = 4, // 参与级联的灯串总数，也即 group.length
        groupBulbs = 96 * 4, // 参与级联总灯珠个数
        bulbOffset = 0, // 当前灯串首个灯珠地址偏移量，从 0 开始计数
        largestBulbs = 96, // 组中最多灯珠的灯串上的灯珠数
        immediate = false,
    }) {
        NativeModule.sendCommand(0xF6, meshAddress, [
            cascadeSeq,
            groupNodes,
            groupBulbs >>> 8 & 0xFF,
            groupBulbs & 0xFF,
            bulbOffset >>> 8 & 0xFF,
            bulbOffset & 0xFF,
            largestBulbs,
        ], immediate);
    }

    static flashWriteAttr({ // 设置灯串信息
        meshAddress,
        timeSequence = 1, // 灯串时序，1 为短时序，0 为长时序
        nodeBulbs = 96, // 灯串上激活灯的个数,最大值为255
        collideCenter = 40, // 碰撞特效的碰撞位置，因为灯串摆成树形时，碰撞位置如果为总灯数的 1/2 的话不好看
        flagPercent = 100, // 国旗模式下相邻两个颜色所属灯串长度百分比
        immediate = false,
    }) {
        NativeModule.sendCommand(0x0211E8, meshAddress, [
            0,
            0,
            nodeBulbs,
            timeSequence,
            collideCenter,
            flagPercent,
        ], immediate);
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
        meshAddress = 0xFFFF,
        relayTimes = 7,
        immediate = false,
    }) {
        NativeModule.sendCommand(0x01B6, meshAddress, [0, 0], immediate);
    }

    // 是否是两个发布版本之间的测试版本
    static isTestFw({
        fwVer,
    }) {
        // 一般发布版本号都是 '16' 代表 v1.6 之类的，类似 'g7' 或 'h7' 或 'i7' 之类的代表正在开发中的下一个版本的测试版本
        return 'a' <= fwVer[0] && fwVer[0] <= 'z';
    }

    static getOtaState({
        meshAddress = 0x0000,
        relayTimes = 7,
        immediate = false,
    }) {
        NativeModule.sendCommand(0xC7, meshAddress, [
            relayTimes,
            5,  // 0xC7 的子命令，5 为获取 OTA 状态
        ], immediate);
    }

    static setOtaMode({
        meshAddress = 0x0000,
        relayTimes = 7,     // 转发次数
        otaMode = 'gatt',   // OTA 模式， gatt 为单灯升级， mesh 为单灯升级后由单灯自动通过 mesh 网络发送新固件给其它灯
        type = 0xFB00,      // 设备类型（gatt OTA 模式请忽略此字段）
        immediate = false,
    }) {
        NativeModule.sendCommand(0xC7, meshAddress, [
            relayTimes,
            6,  // 0xC7 的子命令，6 为设置 OTA 模式(OTA mode)与设备类型(Device type)
            otaMode === 'mesh' ? 1 : 0,
            type & 0xFF,
            type >>> 8 & 0xFF,
        ], immediate);
    }

    static stopMeshOta({
        tag = 'dist_stop',
    }) {
        NativeModule.stopMeshOTA(tag);
    }

    static startOta({
        mac,
        meshAddresses,
        firmware,
    }) {
        if (meshAddresses) {
            NativeModule.startMeshOTA(meshAddresses, firmware);
        } else {
            return NativeModule.startOta(mac, firmware);
        }
    }

    static pauseMeshOta() {
        NativeModule.pauseMeshOta();
    }

    static continueMeshOta() {
        NativeModule.continueMeshOta();
    }

    static isValidFirmware(firmware) {
        return firmware[0] === 0x26 &&
            (firmware[1] & 0xFF) === 0x80 &&
            firmware.length > 6;
    }
}

module.exports = TelinkBtSig;
