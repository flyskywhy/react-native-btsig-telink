/********************************************************************************************************
 * @file GattConnectionEvent.java
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
package com.telink.ble.mesh.foundation.event;


import android.os.Parcel;

import com.telink.ble.mesh.foundation.Event;

/**
 * Created by kee on 2017/8/30.
 */

public class GattConnectionEvent extends Event<String> {

    public static final String EVENT_TYPE_CONNECT_SUCCESS = "com.telink.sig.mesh.CONNECT_SUCCESS";

    public static final String EVENT_TYPE_CONNECT_FAIL = "com.telink.sig.mesh.CONNECT_FAIL";

    private String desc;


    public GattConnectionEvent(Object sender, String type, String desc) {
        super(sender, type);
        this.desc = desc;
    }

    protected GattConnectionEvent(Parcel in) {
        desc = in.readString();
    }

    public static final Creator<GattConnectionEvent> CREATOR = new Creator<GattConnectionEvent>() {
        @Override
        public GattConnectionEvent createFromParcel(Parcel in) {
            return new GattConnectionEvent(in);
        }

        @Override
        public GattConnectionEvent[] newArray(int size) {
            return new GattConnectionEvent[size];
        }
    };

    public String getDesc() {
        return desc;
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        dest.writeString(desc);
    }
}
