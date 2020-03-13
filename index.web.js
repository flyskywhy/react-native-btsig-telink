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
    static BRIGHTNESS_MIN = 1;
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

    static longCommandParams = true;
    static needRefreshMeshNodesClaimed = true;
    static needRefreshMeshNodesBeforeConfig = true;
    static canConfigEvenDisconnected = true;
    static needClaimedBeforeConnect = true;
    static del4GroupStillSendOriginGroupAddress = true;
    static defaultAllGroupAddress = 0xFFFF;
    static isSetNodeGroupAddrReturnAddresses = false;

    static netKey = 'netKey';
    static appKey = 'appKey';
    static meshAddressOfApp = this.MESH_ADDRESS_MAX;

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
            reject();
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
                                        let bulbsColorR = subdata[3] >> 16 & 0xFF;
                                        let bulbsColorG = subdata[3] >> 8 & 0xFF;
                                        let bulbsColorB = subdata[3] & 0xFF;
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
