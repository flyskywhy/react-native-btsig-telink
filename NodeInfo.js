const {CompositionData} = require("./CompositionData");

/**
 * 参考 app_provision.h#VC_node_info_t & spec
 * Created by kee on 2018/10/22.
 */
class NodeInfo {
    // 2 bytes
    nodeAdr;

    // 1 byte
    elementCnt;

    // 1 byte 用于字节对齐
    rsv;

    // 16 bytes
    deviceKey;

    // 2 bytes, composition data valid array data length
    cpsDataLen;

    // CompositionData, not array data
    cpsData;

    /**
     * 组装成VC_node_info 用于网络恢复时配置网络信息
     *
     * @return VC_node_info_t
     */
    toVCNodeInfo() {
        let result = new Array(404);
        for (let i = 0; i < result.length; i++) {
            result[i] = 0xFF;
        }
        let index = 0;
        result[index++] = this.nodeAdr & 0xFF;
        result[index++] = (this.nodeAdr >> 8) & 0xFF;

        result[index++] = this.elementCnt & 0xFF;

        result[index++] = this.rsv & 0xFF;

        let keyLen = 16;
        result.splice(index, keyLen, ...this.deviceKey);
        index += keyLen;

        // record cps len info
        let cpsLenPos = index;

        index += 2;

        let cpsDataBytes = CompositionData.toBytes(this.cpsData);
        let cpsLen = cpsDataBytes.length;
        result.splice(index, cpsLen, ...cpsDataBytes);

        result[cpsLenPos] = cpsLen & 0xFF;
        result[cpsLenPos + 1] = (cpsLen >> 8) & 0xFF;
        return result;
    }

    /**
     * 从 VC_node_info 变为 NodeInfo
     *
     * @param data byte[]
     */
    static from(data) {
        let index = 0;
        let info = new NodeInfo();
        info.nodeAdr = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        info.elementCnt = data[index++] & 0xFF;
        info.rsv = data[index++] & 0xFF;
        let keyLen = 16;
        info.deviceKey = new Array(keyLen);
        for(let i = 0; i < keyLen; i++) {
            info.deviceKey[i] = data[index++];
        }

        info.cpsDataLen = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        let cpsData = new Array(info.cpsDataLen);
        for(let i = 0; i < info.cpsDataLen; i++) {
            cpsData[i] = data[index++];
        }
        info.cpsData = CompositionData.from(cpsData);
        return info;
    }

    /**
     * @param tarModelId target model id
     * @return element address: -1 err
     */
    getTargetEleAdr(tarModelId) {
        let eleAdr = this.nodeAdr;
        for (let element of this.cpsData.elements) {
            if (element.sigModels != null) {
                for (let modelId of element.sigModels) {
                    if (modelId == tarModelId) {
                        return eleAdr;
                    }
                }
            }

            if (element.vendorModels != null) {
                for (let modelId of element.vendorModels) {
                    if (modelId == tarModelId) {
                        return eleAdr;
                    }
                }
            }

            eleAdr++;
        }
        return -1;
    }
}

module.exports = NodeInfo;
