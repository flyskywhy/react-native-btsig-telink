/********************************************************************************************************
 * @file DeviceInfo.java
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

import android.os.Handler;
import android.util.SparseBooleanArray;

import com.telink.ble.mesh.entity.CompositionData;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

public class DeviceInfo implements Serializable {

    /**
     * primary element unicast address
     */
    public int meshAddress;

    /**
     * mac address
     */
    public String macAddress;
    /**
     * device-uuid from scan-record when normal provision
     * or
     * device scan report when fast-provision or remote-provision
     */
    public byte[] deviceUUID;

    /**
     * element count
     */
    public int elementCnt = 0;

    /**
     * device subscription/group info
     */
    public List<Integer> subList = new ArrayList<>();

    public NodeInfo nodeInfo = null;

    // provision完成后保存设备的device key信息， 防止 bind 失败后同步json数据时， 因找不到device key无法重新bind的情况出现
    public byte[] deviceKey;

    /**
     * @param tarModelId target model id
     * @return element address: -1 err
     */
    public int getTargetEleAdr(int tarModelId) {
        if (nodeInfo == null) return -1;
        int eleAdr = this.meshAddress;
        for (CompositionData.Element element : nodeInfo.cpsData.elements) {
            if (element.sigModels != null) {
                for (int modelId : element.sigModels) {
                    if (modelId == tarModelId) {
                        return eleAdr;
                    }
                }
            }

            if (element.vendorModels != null) {
                for (int modelId : element.vendorModels) {
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
