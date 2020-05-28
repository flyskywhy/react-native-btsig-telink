/********************************************************************************************************
 * @file TelinkApplication.java
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
package com.telink.sig.mesh;

import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.HandlerThread;
import android.support.v4.content.LocalBroadcastManager;

import com.telink.sig.mesh.ble.AdvertisingDevice;
import com.telink.sig.mesh.event.CommandEvent;
import com.telink.sig.mesh.event.Event;
import com.telink.sig.mesh.event.EventBus;
import com.telink.sig.mesh.event.EventListener;
import com.telink.sig.mesh.event.MeshEvent;
import com.telink.sig.mesh.event.MeshOtaApplyStatusEvent;
import com.telink.sig.mesh.event.MeshOtaEvent;
import com.telink.sig.mesh.event.MeshOtaProgressEvent;
import com.telink.sig.mesh.event.NotificationEvent;
import com.telink.sig.mesh.event.OnlineStatusEvent;
import com.telink.sig.mesh.event.OtaEvent;
import com.telink.sig.mesh.event.ScanEvent;
import com.telink.sig.mesh.event.SettingEvent;
import com.telink.sig.mesh.lib.MeshLib;
import com.telink.sig.mesh.light.MeshController;
import com.telink.sig.mesh.light.MeshService;
import com.telink.sig.mesh.light.StorageType;
import com.telink.sig.mesh.model.DeviceInfo;
import com.telink.sig.mesh.model.MeshCommand;
import com.telink.sig.mesh.model.NotificationInfo;
import com.telink.sig.mesh.model.OtaDeviceInfo;
import com.telink.sig.mesh.model.storage.CommonModelStorage;
import com.telink.sig.mesh.model.storage.ConfigModelStorage;
import com.telink.sig.mesh.model.storage.MeshKeyStorage;
import com.telink.sig.mesh.model.storage.MeshOTAModelStorage;
import com.telink.sig.mesh.model.storage.MiscStorage;
import com.telink.sig.mesh.util.Arrays;
import com.telink.sig.mesh.util.TelinkLog;

import java.security.Security;
import java.util.ArrayList;
import java.util.List;

/**
 * Telin application base
 * Created by kee on 2017/8/17.
 */

public /*abstract*/ class TelinkApplication /*extends Application*/ implements MeshLib.StorageHelper {

    private static final String TAG = "TelinkApplication";

    private static TelinkApplication mApp;
    protected Application mContext;
    protected TelinkBtSigNativeModule mRnModule;

    // private List<LogInfo> logs;
    private List<String> logs;

    private boolean logEnable = false;

    private MeshLib meshLib;

    private EventBus<String> mEventBus;

    private BroadcastReceiver mLightReceiver;

    private Handler mOfflineCheckHandler;

    private static final short VENDOR_ID = 0x0211;

    static {
        Security.insertProviderAt(new org.spongycastle.jce.provider.BouncyCastleProvider(), 1);
    }

    // @Override
    // public void onCreate() {
    /**
     * Constructor for react-native.
     * @param context Application which handles service events
     */
    TelinkApplication(Application context, TelinkBtSigNativeModule rnModule) {
        mApp = this;
        this.mContext = context;
        this.mRnModule = rnModule;
    }

    public void doInit() {
        HandlerThread offlineCheckThread = new HandlerThread("offline check thread");
        offlineCheckThread.start();
        mOfflineCheckHandler = new Handler(offlineCheckThread.getLooper());
        LocalBroadcastManager.getInstance(mContext).registerReceiver(makeLightReceiver(), makeLightFilter());
        mEventBus = new EventBus<>();

        // initMesh();
        initMeshLib();
        logs = new ArrayList<>();
    }

    public void doDestroy() {
    }

    protected void initMeshLib() {
        meshLib = new MeshLib(mContext);
        meshLib.setStorageHelper(this);
        // getLibVersion
        int libVersion = meshLib.getLibVersion();
        TelinkLog.w("mesh lib version:" + Integer.toHexString(libVersion));
        meshLib.masterClockInit();
        meshLib.meshInitAll();
        meshLib.resetVendorId(VENDOR_ID);
    }

    public Handler getOfflineCheckHandler() {
        return mOfflineCheckHandler;
    }

    public static TelinkApplication getInstance() {
        return mApp;
    }

    public MeshLib getMeshLib() {
        return meshLib;
    }

    // public abstract void saveLog(String log);
    public void saveLog(String action) {
        if (logEnable) {
            // logs.add(new LogInfo(action));
            logs.add(action);
        }
    }

    @Override
    public byte[] onMeshStorageRetrieve(int len, int storageType) {
        StorageType type = StorageType.valueOf(storageType);
        if (type == null) return null;
        return this.onMeshInfoRequired(len, type);
    }

    @Override
    public void onMeshStorageUpdate(byte[] buffer, int storageType) {
        StorageType type = StorageType.valueOf(storageType);
        if (type == null) return;
        this.onMeshInfoUpdate(buffer, type);
    }

    public byte[] onMeshInfoRequired(int len, StorageType type) {
        TelinkLog.d("onMeshInfoRequired: " + type + " len: " + len);
        switch (type) {
            case MESH_KEY:
                byte[] meshKeyData = getMeshKey().toBytes();
                TelinkLog.d("mesh key: " + Arrays.bytesToHexString(meshKeyData, ":"));
                return meshKeyData;

            case MISC:
                byte[] miscData = getMisc().toBytes();
                TelinkLog.d("misc: " + Arrays.bytesToHexString(miscData, ":"));
                return miscData;

            case NODE_INFO:
                byte[] nodeInfoData = getVCNodeInfo();
                TelinkLog.d("node info: " + Arrays.bytesToHexString(nodeInfoData, ":"));
                return nodeInfoData;

            case CONFIG_MODEL:
                byte[] configData = getConfigModel().toBytes();
                TelinkLog.d("config: " + Arrays.bytesToHexString(configData, ":"));
                return configData;

            case MESH_OTA:
                byte[] meshOtaModelData = getMeshOTAModelInfo().toBytes();
                TelinkLog.d("mesh ota model data: " + Arrays.bytesToHexString(meshOtaModelData, ":"));
                return meshOtaModelData;
        }
        return null;
    }

    public void onMeshInfoUpdate(byte[] data, StorageType type) {
        TelinkLog.d("onMeshInfoUpdate: " + type + " data: " + Arrays.bytesToHexString(data, ":"));
        switch (type) {
            case MESH_KEY:
                saveMeshKey(data);
                break;

            case MISC:
                saveMisc(data);
                break;
        }
    }


    public MeshKeyStorage getMeshKey() {
        MeshKeyStorage.MeshAppKeyStorage meshAppKeyStorage
                = MeshKeyStorage.MeshAppKeyStorage.getDefault(mRnModule.mAppKey);

        MeshKeyStorage.MeshNetKeyStorage meshNetKeyStorage
                = MeshKeyStorage.MeshNetKeyStorage.getDefault(mRnModule.mNetKey, meshAppKeyStorage);

        return MeshKeyStorage.getDefault(meshNetKeyStorage);
    }

    public void saveMeshKey(byte[] data) {
        MeshKeyStorage meshKeyStorage = MeshKeyStorage.fromBytes(data);
        TelinkLog.d("save mesh key: " + meshKeyStorage.toString());

// telink sdk demo 中都是如下注释掉的代码，而且本函数也从没被调用过，所以可以忽略这些 key 的保存了？
//        mMesh.appKey = appKey;
//        mMesh.networkKey = netKey;

//        mMesh.saveOrUpdate(this);
    }

    public MiscStorage getMisc() {
        return MiscStorage.getDefault(mRnModule.sno, mRnModule.ivIndex);
    }


    public void saveMisc(byte[] data) {

        MiscStorage miscStorage = MiscStorage.fromBytes(data);

        TelinkLog.d("save misc: " + miscStorage);
        if (miscStorage == null) return;
        // iv index saved as big endian in misc
        mRnModule.sno = miscStorage.sno;
        mRnModule.ivIndex = ((miscStorage.ivIndex[0] & 0xFF) << 24)
                | ((miscStorage.ivIndex[1] & 0xFF) << 16)
                | ((miscStorage.ivIndex[2] & 0xFF) << 8)
                | (miscStorage.ivIndex[3] & 0xFF);
        mRnModule.saveOrUpdateJS();
    }

    public ConfigModelStorage getConfigModel() {
//        int modelId = SigMeshModel.SIG_MD_CFG_SERVER.modelId;
        CommonModelStorage commonModelStorage =
                CommonModelStorage.getDefault(mRnModule.mMeshAddressOfApp, 0);
        return ConfigModelStorage.getDefault(commonModelStorage);
    }


    public MeshOTAModelStorage getMeshOTAModelInfo() {
        return MeshOTAModelStorage.getDefault(mRnModule.mMeshAddressOfApp, 0);
    }

    public byte[] getVCNodeInfo() {
        if (mRnModule.devices == null || mRnModule.devices.size() == 0) {
            return null;
        }
        final int sLen = 404;
        byte[] re = new byte[sLen * mRnModule.devices.size()];
        int index = 0;
        for (DeviceInfo node : mRnModule.devices) {
            if (node.nodeInfo != null) {
                System.arraycopy(node.nodeInfo.toVCNodeInfo(), 0, re, index, sLen);
            }
            index += sLen;
        }
        return re;
    }

    // public void saveLogInFile(String fileName, String logInfo) {
    //     File root = Environment.getExternalStorageDirectory();
    //     File dir = new File(root.getAbsolutePath() + File.separator + "TelinkSigMeshSetting");
    //     if (FileSystem.writeString(dir, fileName + ".txt", logInfo) != null) {
    //         TelinkLog.d("log saved in: " + fileName);
    //     }
    // }

    // public List<LogInfo> getLogInfo() {
    public List<String> getLogInfo() {
        return logs;
    }

    public void clearLogInfo() {
        logs.clear();
    }

    protected BroadcastReceiver makeLightReceiver() {
        if (this.mLightReceiver == null)
            this.mLightReceiver = new BroadcastReceiver() {

                @Override
                public void onReceive(Context context, Intent intent) {

                    if (intent.getAction() == null) return;
                    switch (intent.getAction()) {
                        case MeshController.ACTION_SCAN_EVENT:
                            onScanEvent(intent);
                            break;

                        case MeshController.ACTION_MESH_EVENT:
                            onMeshEvent(intent);
                            break;

                        case MeshController.ACTION_COMMAND_EVENT:
                            onCommandEvent(intent);
                            break;

                        case MeshController.ACTION_SETTING_EVENT:
                            onSettingEvent(intent);
                            break;

                        case MeshController.ACTION_STATUS_RESPONSE:
                            onNotificationRsp(intent);
                            break;

                        case MeshService.ACTION_SERVICE_CREATE:
                            onServiceCreated();
                            break;
                        case MeshService.ACTION_SERVICE_DESTROY:
                            onServiceDestroyed();
                            break;
                        case MeshController.ACTION_OTA:
                            dispatchEvent(new OtaEvent(this, intent.getStringExtra(MeshController.EXTRA_EVENT_TYPE),
                                    (OtaDeviceInfo) intent.getSerializableExtra(MeshController.EXTRA_DEVICE_INFO)));
                            break;

                        case MeshController.ACTION_ONLINE_STATUS:
                            onOnlineStatusNotify(intent);
                            break;

                        case MeshController.ACTION_MESH_OTA:
                            onMeshOtaEvent(intent);
                            break;
                    }
                }
            };

        return this.mLightReceiver;
    }

    protected void onMeshOtaEvent(Intent intent) {
        String eventType = intent.getStringExtra(MeshController.EXTRA_EVENT_TYPE);
        MeshOtaEvent event = null;
        if (eventType.equals(MeshOtaEvent.EVENT_TYPE_PROGRESS_UPDATE)) {
            event = new MeshOtaProgressEvent(this, eventType,
                    intent.getIntExtra(MeshController.EXTRA_MESH_OTA_PROGRESS, 0));
        } else if (eventType.equals(MeshOtaEvent.EVENT_TYPE_APPLY_STATUS)) {
            event = new MeshOtaApplyStatusEvent(this, eventType,
                    intent.getIntExtra(MeshController.EXTRA_MESH_OTA_APPLY_SRC, 0),
                    intent.getByteArrayExtra(MeshController.EXTRA_NOTIFY_RAW)
            );
        }
        if (event != null) {
            dispatchEvent(event);
        }
    }


    protected void onServiceCreated() {
        dispatchEvent(new Event<>(this, MeshController.EVENT_TYPE_SERVICE_CREATE));
    }

    protected void onServiceDestroyed() {
        dispatchEvent(new Event<>(this, MeshController.EVENT_TYPE_SERVICE_DESTROY));
    }

    protected void onScanEvent(Intent intent) {
        TelinkLog.d(TAG + "#ACTION_SCAN_EVENT");
        String eventType = intent.getStringExtra(MeshController.EXTRA_EVENT_TYPE);
        if (eventType.equals(ScanEvent.DEVICE_FOUND)) {
            dispatchEvent(new ScanEvent(this, eventType, (AdvertisingDevice) intent.getParcelableExtra(MeshController.EXTRA_ADV_DEVICE)));
        } else {
            dispatchEvent(new ScanEvent(this, eventType));
        }

    }

    protected void onMeshEvent(Intent intent) {
        TelinkLog.d(TAG + "#onMeshEvent");
        dispatchEvent(new MeshEvent(this, intent.getStringExtra(MeshController.EXTRA_EVENT_TYPE),
                (DeviceInfo) intent.getSerializableExtra(MeshController.EXTRA_DEVICE_INFO)));
    }

    protected void onCommandEvent(Intent intent) {
        TelinkLog.d(TAG + "#onCommandEvent");
        dispatchEvent(new CommandEvent(this,
                intent.getStringExtra(MeshController.EXTRA_EVENT_TYPE),
                (MeshCommand) intent.getSerializableExtra(MeshController.EXTRA_MESH_COMMAND)));
    }

    protected void onSettingEvent(Intent intent) {
        TelinkLog.d(TAG + "#onSettingEvent");
        dispatchEvent(new SettingEvent(this, intent.getStringExtra(MeshController.EXTRA_EVENT_TYPE),
                intent.getIntExtra(MeshController.EXTRA_SETTING_INFO, -1)));
    }

    protected void onNotificationRsp(Intent intent) {
        TelinkLog.d(TAG + "#onNotificationRsp");
        NotificationEvent event = new NotificationEvent(this, intent.getByteArrayExtra(MeshController.EXTRA_NOTIFY_RAW), (NotificationInfo) intent.getSerializableExtra(MeshController.EXTRA_NOTIFY_INFO));
        dispatchEvent(event);
    }

    protected void onOnlineStatusNotify(Intent intent) {
        TelinkLog.d(TAG + "#onOnlineStatusNotify");
        byte[] data = intent.getByteArrayExtra(MeshController.EXTRA_NOTIFY_RAW);
        dispatchEvent(new OnlineStatusEvent(this, OnlineStatusEvent.ONLINE_STATUS_NOTIFY, data));
    }

    protected IntentFilter makeLightFilter() {
        final IntentFilter filter = new IntentFilter();
        filter.addAction(MeshController.ACTION_SCAN_EVENT);
        filter.addAction(MeshController.ACTION_MESH_EVENT);
        filter.addAction(MeshController.ACTION_COMMAND_EVENT);
        filter.addAction(MeshController.ACTION_SETTING_EVENT);
        filter.addAction(MeshController.ACTION_STATUS_RESPONSE);
        filter.addAction(MeshController.ACTION_OTA);
        filter.addAction(MeshController.ACTION_MESH_OTA);
        filter.addAction(MeshController.ACTION_ONLINE_STATUS);
        filter.addAction(MeshService.ACTION_SERVICE_CREATE);
        filter.addAction(MeshService.ACTION_SERVICE_DESTROY);
        return filter;
    }

    /********************************************************************************
     * Event API
     *******************************************************************************/

    /**
     * 添加一个事件监听器
     *
     * @param eventType 事件类型
     * @param listener  事件监听器
     */
    public void addEventListener(String eventType, EventListener<String> listener) {
        this.mEventBus.addEventListener(eventType, listener);
    }

    /**
     * 移除事件监听器
     */
    public void removeEventListener(EventListener<String> listener) {
        this.mEventBus.removeEventListener(listener);
    }

    /**
     * 从事件监听器中移除指定的事件
     *
     * @param eventType type
     * @param listener  ls
     */
    public void removeEventListener(String eventType, EventListener<String> listener) {
        this.mEventBus.removeEventListener(eventType, listener);
    }

    /**
     * 移除所有的事件监听器
     */
    public void removeEventListeners() {
        this.mEventBus.removeEventListeners();
    }

    /**
     * 分发事件
     *
     * @param event ev
     */
    public void dispatchEvent(Event<String> event) {
        this.mEventBus.dispatchEvent(event);
    }
}
