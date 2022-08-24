/********************************************************************************************************
 * @file NodeInfo.java
 *
 * @brief for TLSR chips
 *
 * @author telink
 * @date Sep. 30, 2010
 *
 * @par Copyright (c) 2010, Telink Semiconductor (Shanghai) Co., Ltd.
 *           All rights reserved.
 *
 *			 The information contained herein is confidential and proprietary property of Telink
 * 		     Semiconductor (Shanghai) Co., Ltd. and is available under the terms
 *			 of Commercial License Agreement between Telink Semiconductor (Shanghai)
 *			 Co., Ltd. and the licensee in separate contract or the terms described here-in.
 *           This heading MUST NOT be removed from this file.
 *
 * 			 Licensees are granted free, non-transferable use of the information in this
 *			 file under Mutual Non-Disclosure Agreement. NO WARRENTY of ANY KIND is provided.
 *
 *******************************************************************************************************/
package com.telink.ble.mesh;

import com.telink.ble.mesh.entity.CompositionData;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

/**
 * 参考 app_provision.h#VC_node_info_t & spec
 * Created by kee on 2018/10/22.
 */
public class NodeInfo implements Serializable {


    //    byte[] rawData;

    // 2 bytes
    public int nodeAdr;

    // 1 byte
    public int elementCnt;

    // 1 byte 用于字节对齐
    public int rsv;

    // 16 bytes
    public byte[] deviceKey;


    /**
     * composition data valid data length
     */
    public int cpsDataLen;


    public CompositionData cpsData;


    public NodeInfo() {

    }

    public static byte[] cpsDataToBytes(CompositionData cpsData) {
        byte[] result = new byte[404];
        int index = 0;

        result[index++] = (byte) (cpsData.cid & 0xFF);
        result[index++] = (byte) ((cpsData.cid >> 8) & 0xFF);
        result[index++] = (byte) (cpsData.pid & 0xFF);
        result[index++] = (byte) ((cpsData.pid >> 8) & 0xFF);
        result[index++] = (byte) (cpsData.vid & 0xFF);
        result[index++] = (byte) ((cpsData.vid >> 8) & 0xFF);
        result[index++] = (byte) (cpsData.crpl & 0xFF);
        result[index++] = (byte) ((cpsData.crpl >> 8) & 0xFF);
        result[index++] = (byte) (cpsData.features & 0xFF);
        result[index++] = (byte) ((cpsData.features >> 8) & 0xFF);

        for (CompositionData.Element element : cpsData.elements) {
            result[index++] = (byte) (element.location & 0xFF);
            result[index++] = (byte) ((element.location >> 8) & 0xFF);

            result[index++] = (byte) (element.sigNum & 0xFF);
            result[index++] = (byte) (element.vendorNum & 0xFF);

            for (int model : element.sigModels) {
                result[index++] = (byte) (model & 0xFF);
                result[index++] = (byte) ((model >> 8) & 0xFF);
            }


            for (int model : element.vendorModels) {
                result[index++] = (byte) (model & 0xFF);
                result[index++] = (byte) ((model >> 8) & 0xFF);
                result[index++] = (byte) ((model >> 16) & 0xFF);
                result[index++] = (byte) ((model >> 24) & 0xFF);
            }
        }
        int cpsLen = index;

        byte[] cpsDataBytes = new byte[cpsLen];
        System.arraycopy(result, 0, cpsDataBytes, 0, cpsLen);
        return cpsDataBytes;
    }

    /**
     * 组装成VC_node_info 用于网络恢复时配置网络信息
     *
     * @return VC_node_info_t
     */
    public byte[] toVCNodeInfo() {
        byte[] result = new byte[404];
        for (int i = 0; i < result.length; i++) {
            result[i] = (byte) 0xFF;
        }
        int index = 0;
        result[index++] = (byte) (nodeAdr & 0xFF);
        result[index++] = (byte) ((nodeAdr >> 8) & 0xFF);

        result[index++] = (byte) (elementCnt & 0xFF);

        result[index++] = (byte) (rsv & 0xFF);

        int keyLen = 16;
        System.arraycopy(deviceKey, 0, result, index, keyLen);
        index += keyLen;

        // record cps len info
        int cpsLenPos = index;

        index += 2;

        byte[] cpsDataBytes = cpsDataToBytes(cpsData);
        int cpsLen = cpsDataBytes.length;
        System.arraycopy(cpsDataBytes, 0, result, index, cpsLen);

        result[cpsLenPos] = (byte) (cpsLen & 0xFF);
        result[cpsLenPos + 1] = (byte) ((cpsLen >> 8) & 0xFF);
        return result;
    }

    public static NodeInfo from(byte[] data) {
        int index = 0;
        NodeInfo info = new NodeInfo();
        info.nodeAdr = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        info.elementCnt = data[index++] & 0xFF;
        info.rsv = data[index++] & 0xFF;
        int keyLen = 16;
        info.deviceKey = new byte[keyLen];
        System.arraycopy(data, index, info.deviceKey, 0, keyLen);
        index += keyLen;

        info.cpsDataLen = (data[index++] & 0xFF) | ((data[index++] & 0xFF) << 8);
        byte[] cpsData = new byte[info.cpsDataLen];
        System.arraycopy(data, index, cpsData, 0, info.cpsDataLen);
        info.cpsData = CompositionData.from(cpsData);
        return info;
    }
}
