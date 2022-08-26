/********************************************************************************************************
 * @file SubnetBridgeStatusMessage.java
 *
 * @brief for TLSR chips
 *
 * @author telink
 * @date Sep. 30, 2017
 *
 * @par Copyright (c) 2017, Telink Semiconductor (Shanghai) Co., Ltd. ("TELINK")
 *
 *          Licensed under the Apache License, Version 2.0 (the "License");
 *          you may not use this file except in compliance with the License.
 *          You may obtain a copy of the License at
 *
 *              http://www.apache.org/licenses/LICENSE-2.0
 *
 *          Unless required by applicable law or agreed to in writing, software
 *          distributed under the License is distributed on an "AS IS" BASIS,
 *          WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *          See the License for the specific language governing permissions and
 *          limitations under the License.
 *******************************************************************************************************/
package com.telink.ble.mesh.core.message.config;

import android.os.Parcel;
import android.os.Parcelable;

import com.telink.ble.mesh.core.message.StatusMessage;

/**
 * Created by kee on 2019/9/10.
 */

public class SubnetBridgeStatusMessage extends StatusMessage implements Parcelable {

    /**
     * 1 byte
     * 0x00	Subnet bridge functionality is disabled.
     * 0x01	Subnet bridge functionality is enabled.
     */
    private byte subnetBridgeState;

    public SubnetBridgeStatusMessage() {
    }


    protected SubnetBridgeStatusMessage(Parcel in) {
        subnetBridgeState = in.readByte();
    }

    public static final Creator<SubnetBridgeStatusMessage> CREATOR = new Creator<SubnetBridgeStatusMessage>() {
        @Override
        public SubnetBridgeStatusMessage createFromParcel(Parcel in) {
            return new SubnetBridgeStatusMessage(in);
        }

        @Override
        public SubnetBridgeStatusMessage[] newArray(int size) {
            return new SubnetBridgeStatusMessage[size];
        }
    };

    @Override
    public void parse(byte[] params) {
        subnetBridgeState = params[0];
    }

    public byte getSubnetBridgeState() {
        return subnetBridgeState;
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeByte(subnetBridgeState);
    }
}
