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
    static BRIGHTNESS_MIN = 5;
    static BRIGHTNESS_MAX = 100;
    static COLOR_TEMP_MIN = 5;
    static COLOR_TEMP_MAX = 100;
    static NODE_STATUS_OFF = 0;
    static NODE_STATUS_ON = 1;
    static NODE_STATUS_OFFLINE = -1;
    static RELAY_TIMES_MAX = 16;
    static DELAY_MS_AFTER_UPDATE_MESH_COMPLETED = 1;
    static DELAY_MS_COMMAND = 320;
    static ALARM_CREATE = 0;
    static ALARM_REMOVE = 1;
    static ALARM_UPDATE = 2;
    static ALARM_ENABLE = 3;
    static ALARM_DISABLE = 4;
    static ALARM_ACTION_TURN_OFF = 0;
    static ALARM_ACTION_TURN_ON = 1;
    static ALARM_ACTION_SCENE = 2;
    static ALARM_TYPE_DAY = 0;
    static ALARM_TYPE_WEEK = 1;

    static passthroughMode = undefined; // 通过串口或者说自定义发送数据来控制蓝牙节点

    // 逻辑上能否通过蓝牙模块返回的在线状态或者开关灯等状态推理出在线状态
    static hasOnlineStatusNotify = true;
    // 物理上蓝牙模块是否支持返回在线状态
    static hasOnlineStatusNotifyRaw = false;

    static needRefreshMeshNodesBeforeConfig = true;
    static canConfigEvenDisconnected = true;
    static needClaimedBeforeConnect = true;

    static del4GroupStillSendOriginGroupAddress = true;
    static defaultAllGroupAddress = 0xFFFF;
    static isSetNodeGroupAddrReturnAddresses = false;

    static netKey = 'netKey';
    static appKey = 'appKey';
    static meshAddressOfApp = this.MESH_ADDRESS_MAX; // 测试得：手机 mesh 地址不能设为 0
    static devices = [];
    static provisionerSno = 0;

    static doInit() {
        NativeModule.doInit(this.netKey, this.appKey, this.meshAddressOfApp, this.devices.map(device => {
            return { ...device,
                dhmKey: this.hexString2ByteArray(device.dhmKey),
                nodeInfo: this.hexString2ByteArray(device.nodeInfo),
            }
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

    static postConnected({
        meshAddress,
        immediate = false,
    }) {
        let changed = false;

        if (!changed) {
            if (!this.hasOnlineStatusNotifyRaw) {
                // 如果后续从蓝牙设备固件代码中得知 telink 也实现了（应该实现了） sig mesh 协议中
                // model 之间关联功能，放到这里就是实现了亮度 modle 如果亮度为 <= 0 的话就会关联
                // 开关灯 model 为关灯状态，则此处可以不再使用 getOnOff 而只用 getCtl 等代替
                NativeModule.sendCommand(0x0182, 0xFFFF, [], immediate); // mService.getOnOff(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_DEVICE_ON_OFF_STATUS

                // 测试得：如果紧接着上面 getOnOff 后立即进行其它 get ，则只会触发 getOnOff 对应的 EVENT，因此需要延迟进行
                setTimeout(() => {
                    // 因为此处只会返回第一个 get 函数的结果，所以那些注释掉的 get 函数仅用于测试
                    // NativeModule.sendCommand(0x0582, 0xFFFF, [], immediate); // mService.getLevel(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_DEVICE_LEVEL_STATUS
                    // NativeModule.sendCommand(0x4B82, 0xFFFF, [], immediate); // mService.getLightness(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_LIGHTNESS_STATUS_NOTIFY

                    // 如 TelinkBtSigNativeModule.java 的 onGetLevelNotify() 中注释所说，使用 onGetCtlNotify() 更简洁
                    NativeModule.sendCommand(0x5D82, 0xFFFF, [], immediate); // mService.getCtl(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_CTL_STATUS_NOTIFY

                    // NativeModule.sendCommand(0x6182, 0xFFFF, [], immediate); // mService.getTemperature(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_TEMP_STATUS_NOTIFY
                }, 1 * 1000); // 测试得：当延时为 100 时无法触发对应的 EVENT ，而 500 是可以的，保险起见，这里可以使用 1000
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
        return NativeModule.startScan(timeoutSeconds, isSingleNode);
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
        NativeModule.sendCommand(0xF2, meshAddress, [], immediate);
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
        NativeModule.changePower(meshAddress, value);
    }

    static changeBrightness({
        meshAddress,
        hue = 0,
        saturation = 0,
        value,
        type,
        immediate = false,
    }) {
        NativeModule.changeBrightness(meshAddress, value);
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
        })

        return array;
    }

    static byteArray2HexString(bytes) {
        return bytes.map(byte => this.padHexString((byte & 0xFF).toString(16))).toString().replace(/,/g, '').toUpperCase();
    }

    static changeScene({
        meshAddress,
        scene,
        hue = 0,
        saturation = 0,
        value,
        color,
        colorBg,
        colorsLength = 1,
        colorSequence = 1,
        colorIds = [1, 2, 3, 4, 5],
        colorBgId = 2,
        colorId = 1,
        speed = 3,
        type,
        immediate = false,
    }) {
        let changed = false;

        if (this.passthroughMode) {
            let color3 = color && tinycolor(color).toRgb();
            if (!color3) {
                color3 = tinycolor.fromRatio({
                    h: hue / this.HUE_MAX,
                    s: saturation / this.SATURATION_MAX,
                    v: value / this.BRIGHTNESS_MAX,
                }).toRgb();;
            }
            let color3Bg = colorBg && tinycolor(colorBg).toRgb();
            for (let mode in this.passthroughMode) {
                if (this.passthroughMode[mode].includes(type)) {
                    if (mode === 'silan') {
                        switch (scene) {
                            case 0:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, 3, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 1:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 2:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 3:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 4:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 5:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed], immediate);
                                changed = true;
                                break;
                            case 6:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 7:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 8:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 9:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 10:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed], immediate);
                                changed = true;
                                break;
                            case 11:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 12:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 13:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            case 14:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed], immediate);
                                changed = true;
                                break;
                            case 15:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed], immediate);
                                changed = true;
                                break;
                            case 16:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed], immediate);
                                changed = true;
                                break;
                            case 17:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed], immediate);
                                changed = true;
                                break;
                            case 18:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b], immediate);
                                changed = true;
                                break;
                            case 19:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 20:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, colorSequence, colorsLength], immediate);
                                changed = true;
                                break;
                            case 21:
                                NativeModule.sendCommand(0xF1, meshAddress, [scene, speed, color3.r, color3.g, color3.b, color3Bg.r, color3Bg.g, color3Bg.b], immediate);
                                changed = true;
                                break;
                            default:
                                break;
                        }
                    }
                    if (changed) {
                        break;
                    }
                }
            }
        }

        if (!changed) {
            NativeModule.sendCommand(0xEF, meshAddress, [scene], immediate);
        }
    }

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
            })
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
            }, reject)
        })
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
            }, reject)
        })
    }

    static setAlarm({
        meshAddress,
        crud,
        alarmId,
        status,
        action,
        type,
        month = 1, // telink 固件中时间月份是 1~12 而非 Java 或 JS 中标准的 0~11 （TODO: 此注释在 sig 中可能已过时，待调试完 setAlarm 后修改）
        dayOrweek,
        hour,
        minute,
        second = 0,
        sceneId = 0,
        immediate = false,
    }) {
        // NativeModule.sendCommand(0xE5, meshAddress, [crud, alarmId, status << 7 | type << 4 | action, month, dayOrweek, hour, minute, second, sceneId], immediate);
    }

    static getAlarm({
        meshAddress,
        relayTimes,
        alarmId,
    }) {
        return new Promise((resolve, reject) => {
            let timer = setTimeout(() => reject({errCode: 'getAlarm time out'}), 10000);
            NativeModule.getAlarm(meshAddress, relayTimes, alarmId).then(payload => {
                clearTimeout(timer);
                resolve(payload);
            }, reject)
        })
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
        immediate = false,
    }) {
        NativeModule.sendCommand(0xF5, meshAddress, [
            timeSequence,
            nodeBulbs,
            collideCenter,
        ], immediate);
    }

    static getFirmwareVersion({
        meshAddress = 0xFFFF,
        relayTimes = 7,
        immediate = false,
    }) {
        NativeModule.sendCommand(0xC7, meshAddress, [
            relayTimes,
            0,  // 0xC7 的子命令，0 为获取版本信息
        ], immediate);
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
        otaMode = 'gatt',   // OTA 模式， gatt 为单灯升级， mesh 为单灯升级后有单灯自动通过 mesh 网络发送新固件给其它灯
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
        meshAddress = 0xFFFF,
        immediate = false,
    }) {
        NativeModule.sendCommand(0xC6, meshAddress, [
            0xFE,
            0xFF,
        ], immediate);
    }

    static startOta({
        firmware,
    }) {
        NativeModule.startOta(firmware);
    }

    static isValidFirmware(firmware) {
        return firmware[0] === 0x0E &&
            (firmware[1] & 0xFF) === 0x80 &&
            firmware.length > 6;
    }
}

module.exports = TelinkBtSig;
