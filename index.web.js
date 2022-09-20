var pako = require('pako');

class TelinkBtSig {
    static MESH_ADDRESS_MIN = 0x0001;
    static MESH_ADDRESS_MAX = 0x00FF;
    static GROUP_ADDRESS_MIN = 0xC001;
    static GROUP_ADDRESS_MAX = 0xC0FF;
    static GROUP_ADDRESS_MASK = 0x00FF;
    static HUE_MIN = 0;
    static HUE_MAX = 360;
    static SATURATION_MIN = 0;
    static SATURATION_MAX = 100;
    static BRIGHTNESS_MIN = 39;
    static BRIGHTNESS_MAX = 100;
    static COLOR_TEMP_MIN = 1;
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
    static longCommandParams = true;
    static MESH_CMD_ACCESS_LEN_MAX = 380;
    static needRefreshMeshNodesClaimed = true;
    static needRefreshMeshNodesBeforeConfig = true;
    static canConfigEvenDisconnected = true;
    static needClaimedBeforeConnect = true;
    static del4GroupStillSendOriginGroupAddress = true;
    static defaultAllGroupAddress = 0xFFFF;
    static isSetNodeGroupAddrReturnAddresses = false;

    static netKey = '_16_BYTES_NETKEY';
    static appKey = '_16_BYTES_APPKEY';
    static meshAddressOfApp = this.MESH_ADDRESS_MAX + parseInt(Math.random() * 10000, 10);

    static otaFileVersionOffset = 4;    // 把二进制固件作为一个字节数组看待的话，描述着版本号的第一个字节的数组地址
    static otaFileVersionLength = 2;    // 二进制固件中描述版本号用了几个字节

    static doInit() {}

    static doDestroy() {}

    static addListener(eventName, handler) {}

    static removeListener(eventName, handler) {}

    static enableBluetooth() {}

    static enableSystemLocation() {}

    static notModeAutoConnectMesh() {
        return new Promise((resolve, reject) => {
            resolve(true);
        });
    }

    static autoConnect({
        userMeshPwd,
    }) {}

    static autoRefreshNotify({
        repeatCount,
        Interval
    }) {}

    static idleMode({
        disconnect
    }) {}

    static startScan({
        timeoutSeconds,
        isSingleNode,
    }) {}

    static sendCommand({
        opcode,
        meshAddress,
        valueArray
    }) {}

    static remind({
        meshAddress,
    }) {}

    static isOnline(status) {}

    static isOn(status) {}

    static changePower({
        meshAddress,
        value
    }) {}

    static changeBrightness({
        meshAddress,
        value
    }) {}

    static changeColorTemp({
        meshAddress,
        value
    }) {}

    static changeColor({
        meshAddress,
        hue = 0,
        saturation = 0,
        value,
        type,
    }) {}

    static ledFilter3040(value) {
        if (value <= 0x30) {
            return 0;
        }
        if (value < 0x40) {
            return 0x40;
        }
        return value;
    }

    static changeScene({
        meshAddress,
        scene,
        hue = 0,
        saturation = 0,
        value,
        colorIds = [1, 2, 3, 4, 5],
        data = [],
        speed = 3,
        type,
    }) {
        if (scene === 0x80) {
                                let rawData = [];
                                data.map(subdata => {
                                    let bulbsMode = subdata[0];
                                    if (bulbsMode === 0 || bulbsMode === 1 || bulbsMode === 2) {
                                        let subdataLength = 7;
                                        let bulbsStart = subdata[1];
                                        let bulbsLength = subdata[2];
                                        let bulbsColorR = this.ledFilter3040(subdata[3] >> 16 & 0xFF);
                                        let bulbsColorG = this.ledFilter3040(subdata[3] >> 8 & 0xFF);
                                        let bulbsColorB = this.ledFilter3040(subdata[3] & 0xFF);
                                        rawData = rawData.concat([
                                            subdataLength,
                                            bulbsMode,
                                            bulbsStart,
                                            bulbsLength,
                                            bulbsColorR,
                                            bulbsColorG,
                                            bulbsColorB,
                                        ])
                                    }
                                });
                                let dataType = 0;
                                let dataLengthLowByte = rawData.length & 0xFF;
                                let dataLengthHightByte = rawData.length >> 8 & 0xFF;

                                // TODO: dataType = 1;
                                let compressedData = pako.deflateRaw(new Uint8Array(rawData), {
                                    strategy: pako.Z_HUFFMAN_ONLY,
                                });  // 可被 https://github.com/jibsen/tinf/tree/master/test/test_tinf.c 里的 inflate_huffman_only 解压缩
                                // console.warn(rawData.length, compressedData.length)
                                console.warn(rawData, compressedData)

                                console.warn([0, 0, scene, speed, dataType, dataLengthLowByte, dataLengthHightByte, ...rawData])
        }
    }

    static configNode({
        node,
        // cfg,
        isToClaim,
    }) {}

    static getTotalOfGroupIndex({
        meshAddress,
    }) {}

    static setNodeGroupAddr({
        meshAddress,
        groupIndex,
        groupAddress,
    }) {}

    static setTime({
        meshAddress,
        year,
        month,
        day,
        hour,
        minute,
        second = 0,
    }) {}

    static getTime({
        meshAddress,
        relayTimes,
    }) {}

    static setAlarm({
        meshAddress,
        crud,
        alarmId,
        status,
        action,
        type,
        month = 1,
        dayOrweek,
        hour,
        minute,
        second = 0,
        sceneId = 0,
    }) {}

    static getAlarm({
        meshAddress,
        relayTimes,
        alarmId,
    }) {}

    static cascadeLightStringGroup({
        meshAddress,
    }) {}

    static getNodeInfoWithNewType({
        nodeInfo = '',
        newType = 0xA5A5,
    }) {}

    static getFwVerInNodeInfo({
        nodeInfo = '',
    }) {}

    static getNodeInfoWithNewFwVer({
        nodeInfo = '',
        newFwVer = '',
    }) {}

    static getFirmwareVersion({
        meshAddress = 0xFFFF,
        relayTimes = 7,
        immediate = false,
    }) {}

    static isTestFw({
        fwVer,
    }) {}

    static getOtaState({
        meshAddress = 0x0000,
        relayTimes = 7,
        immediate = false,
    }) {}

    static setOtaMode({
        meshAddress = 0x0000,
        relayTimes = 7,     // 转发次数
        otaMode = 'gatt',   // OTA 模式， gatt 为单灯升级， mesh 为单灯升级后由单灯自动通过 mesh 网络发送新固件给其它灯
        type = 0xFB00,      // 设备类型（gatt OTA 模式请忽略此字段）
        immediate = false,
    }) {}

    static stopMeshOta({
        meshAddress = 0xFFFF,
        immediate = false,
    }) {}

    static startOta({
        firmware,
    }) {}

    static isValidFirmware(firmware) {
        return firmware[0] === 0x0E &&
            (firmware[1] & 0xFF) === 0x80 &&
            firmware.length > 6;
    }
}

module.exports = TelinkBtSig;
