package com.telink.sig.mesh;

/**
 * Created by kee on 2019/2/27.
 */

public enum PrivateDevice {

    // TODO: 这些数据后续也许可以考虑移到 JS 层的 Defines.js，以便于定制客户私有设备

    // PANEL(0x0211, 0x0007, "panel",
    //         new byte[]{(byte) 0x11, (byte) 0x02, (byte) 0x07, (byte) 0x00, (byte) 0x32, (byte) 0x37, (byte) 0x69, (byte) 0x00, (byte) 0x07, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0x00
    //                 , (byte) 0x02, (byte) 0x00, (byte) 0x03, (byte) 0x00, (byte) 0x04, (byte) 0x00, (byte) 0x05, (byte) 0x00, (byte) 0x00, (byte) 0xfe, (byte) 0x01, (byte) 0xfe, (byte) 0x02, (byte) 0xfe, (byte) 0x00, (byte) 0xff
    //                 , (byte) 0x01, (byte) 0xff, (byte) 0x00, (byte) 0x12, (byte) 0x01, (byte) 0x12, (byte) 0x00, (byte) 0x10, (byte) 0x03, (byte) 0x12, (byte) 0x04, (byte) 0x12, (byte) 0x06, (byte) 0x12, (byte) 0x07, (byte) 0x12
    //                 , (byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0x00, (byte) 0x11, (byte) 0x02, (byte) 0x01, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x05, (byte) 0x01, (byte) 0x00, (byte) 0x10, (byte) 0x03, (byte) 0x12
    //                 , (byte) 0x04, (byte) 0x12, (byte) 0x06, (byte) 0x12, (byte) 0x07, (byte) 0x12, (byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x05, (byte) 0x01, (byte) 0x00, (byte) 0x10
    //                 , (byte) 0x03, (byte) 0x12, (byte) 0x04, (byte) 0x12, (byte) 0x06, (byte) 0x12, (byte) 0x07, (byte) 0x12, (byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0x00}),

    // CT(0x0211, 0x0001, "ct",
    //         new byte[]{(byte) 0x11, (byte) 0x02, (byte) 0x01, (byte) 0x00, (byte) 0x32, (byte) 0x37, (byte) 0x69, (byte) 0x00, (byte) 0x07, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x19, (byte) 0x01, (byte) 0x00, (byte) 0x00
    //                 , (byte) 0x02, (byte) 0x00, (byte) 0x03, (byte) 0x00, (byte) 0x04, (byte) 0x00, (byte) 0x05, (byte) 0x00, (byte) 0x00, (byte) 0xfe, (byte) 0x01, (byte) 0xfe, (byte) 0x02, (byte) 0xfe, (byte) 0x00, (byte) 0xff
    //                 , (byte) 0x01, (byte) 0xff, (byte) 0x00, (byte) 0x12, (byte) 0x01, (byte) 0x12, (byte) 0x00, (byte) 0x10, (byte) 0x02, (byte) 0x10, (byte) 0x04, (byte) 0x10, (byte) 0x06, (byte) 0x10, (byte) 0x07, (byte) 0x10
    //                 , (byte) 0x03, (byte) 0x12, (byte) 0x04, (byte) 0x12, (byte) 0x06, (byte) 0x12, (byte) 0x07, (byte) 0x12, (byte) 0x00, (byte) 0x13, (byte) 0x01, (byte) 0x13, (byte) 0x03, (byte) 0x13, (byte) 0x04, (byte) 0x13
    //                 , (byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x02, (byte) 0x00, (byte) 0x02, (byte) 0x10, (byte) 0x06, (byte) 0x13}),

    // 当固件中调整了 element 或 model 导致 cpsData 有变动时，需要同步修改这里的数据
    // 这里只需要提供 0xFB00 ，因为 onProvisionSuccess() 中会将其补完至比如 0xFB78
    FB00(0x0211, 0xFB00, "lightstring",
            new byte[]{(byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0xFB, (byte) 0x31, (byte) 0x32, (byte) 0x69, (byte) 0x00, (byte) 0x07, (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x13, (byte) 0x01, (byte) 0x00, (byte) 0x00
                    , (byte) 0x02, (byte) 0x00, (byte) 0x03, (byte) 0x00, (byte) 0x04, (byte) 0x00, (byte) 0x00, (byte) 0xFE, (byte) 0x01, (byte) 0xFE, (byte) 0x00, (byte) 0xFF, (byte) 0x01, (byte) 0xFF, (byte) 0x00, (byte) 0x12
                    , (byte) 0x01, (byte) 0x12, (byte) 0x00, (byte) 0x10, (byte) 0x02, (byte) 0x10, (byte) 0x04, (byte) 0x10, (byte) 0x06, (byte) 0x10, (byte) 0x07, (byte) 0x10, (byte) 0x06, (byte) 0x12, (byte) 0x07, (byte) 0x12
                    , (byte) 0x00, (byte) 0x13, (byte) 0x01, (byte) 0x13, (byte) 0x11, (byte) 0x02, (byte) 0x00, (byte) 0x00});

    PrivateDevice(int vid, int pid, String name, byte[] cpsData) {
        this.vid = vid;
        this.pid = pid;
        this.name = name;
        this.cpsData = cpsData;
    }

    private final int vid;
    private final int pid;
    private final String name;
    private final byte[] cpsData;

    public int getVid() {
        return vid;
    }

    public int getPid() {
        return pid;
    }

    public String getName() {
        return name;
    }

    public byte[] getCpsData() {
        return cpsData;
    }

    public static PrivateDevice filter(byte[] serviceData) {
        if (serviceData.length < 3) return null;
        int vid = (serviceData[0] & 0xFF) + (((serviceData[1] & 0xFF) << 8));
        int pid = (serviceData[2] & 0xFF) + (((serviceData[3] & 0xFF) << 8));
        PrivateDevice[] values = PrivateDevice.values();
        for (PrivateDevice device :
                values) {
            if (device.vid == vid) {
                if ((pid & 0xFF00) == 0xFB00 && device.pid == 0xFB00) {
                    return device;
                } else if (device.pid == pid) {
                    return device;
                }
            }
        }
        return null;

    }
}
