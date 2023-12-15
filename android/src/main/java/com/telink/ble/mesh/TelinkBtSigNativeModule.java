package com.telink.ble.mesh;

import javax.annotation.Nullable;

import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Iterator;
import java.util.List;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.provider.Settings;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import android.util.Log;
import android.util.SparseArray;
import android.util.SparseIntArray;
import android.widget.Toast;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import com.telink.ble.mesh.core.MeshUtils;
import com.telink.ble.mesh.core.access.BindingBearer;
import com.telink.ble.mesh.core.access.fu.BlobTransferType;
import com.telink.ble.mesh.core.access.fu.DistributorType;
import com.telink.ble.mesh.core.access.fu.FUCallback;
import com.telink.ble.mesh.core.access.fu.FUState;
import com.telink.ble.mesh.core.access.fu.UpdatePolicy;
import com.telink.ble.mesh.core.message.MeshMessage;
import com.telink.ble.mesh.core.message.MeshSigModel;
import com.telink.ble.mesh.core.message.NotificationMessage;
import com.telink.ble.mesh.core.message.OpcodeType;
import com.telink.ble.mesh.core.message.config.ModelSubscriptionSetMessage;
import com.telink.ble.mesh.core.message.config.ModelSubscriptionStatusMessage;
import com.telink.ble.mesh.core.message.config.NodeResetMessage;
import com.telink.ble.mesh.core.message.config.NodeResetStatusMessage;
import com.telink.ble.mesh.core.message.config.ConfigStatus;
import com.telink.ble.mesh.core.message.firmwareupdate.FirmwareUpdateInfoGetMessage;
import com.telink.ble.mesh.core.message.firmwareupdate.FirmwareUpdateInfoStatusMessage;
import com.telink.ble.mesh.core.message.generic.LevelStatusMessage;
import com.telink.ble.mesh.core.message.generic.OnOffSetMessage;
import com.telink.ble.mesh.core.message.generic.OnOffStatusMessage;
import com.telink.ble.mesh.core.message.lighting.CtlStatusMessage;
import com.telink.ble.mesh.core.message.lighting.CtlTemperatureSetMessage;
import com.telink.ble.mesh.core.message.lighting.CtlTemperatureStatusMessage;
import com.telink.ble.mesh.core.message.lighting.HslSetMessage;
import com.telink.ble.mesh.core.message.lighting.LightnessSetMessage;
import com.telink.ble.mesh.core.message.lighting.LightnessStatusMessage;
import com.telink.ble.mesh.core.message.scheduler.SchedulerActionGetMessage;
import com.telink.ble.mesh.core.message.scheduler.SchedulerActionSetMessage;
import com.telink.ble.mesh.core.message.scheduler.SchedulerActionStatusMessage;
import com.telink.ble.mesh.core.message.time.TimeGetMessage;
import com.telink.ble.mesh.core.message.time.TimeSetMessage;
import com.telink.ble.mesh.core.message.time.TimeStatusMessage;
import com.telink.ble.mesh.core.networking.ExtendBearerMode;
import com.telink.ble.mesh.core.networking.NetworkingController;
import com.telink.ble.mesh.entity.AdvertisingDevice;
import com.telink.ble.mesh.entity.BindingDevice;
import com.telink.ble.mesh.entity.CompositionData;
import com.telink.ble.mesh.entity.ConnectionFilter;
import com.telink.ble.mesh.entity.FastProvisioningConfiguration;
import com.telink.ble.mesh.entity.FastProvisioningDevice;
import com.telink.ble.mesh.entity.FirmwareUpdateConfiguration;
import com.telink.ble.mesh.entity.MeshUpdatingDevice;
import com.telink.ble.mesh.entity.OnlineStatusInfo;
import com.telink.ble.mesh.entity.ProvisioningDevice;
import com.telink.ble.mesh.entity.Scheduler;
import com.telink.ble.mesh.foundation.Event;
import com.telink.ble.mesh.foundation.EventHandler;
import com.telink.ble.mesh.foundation.MeshConfiguration;
import com.telink.ble.mesh.foundation.MeshController;
import com.telink.ble.mesh.foundation.MeshService;
import com.telink.ble.mesh.foundation.event.AutoConnectEvent;
import com.telink.ble.mesh.foundation.event.BindingEvent;
import com.telink.ble.mesh.foundation.event.FastProvisioningEvent;
import com.telink.ble.mesh.foundation.event.GattOtaEvent;
import com.telink.ble.mesh.foundation.event.MeshEvent;
import com.telink.ble.mesh.foundation.event.NetworkInfoUpdateEvent;
import com.telink.ble.mesh.foundation.event.OnlineStatusEvent;
import com.telink.ble.mesh.foundation.event.ProvisioningEvent;
import com.telink.ble.mesh.foundation.event.ReliableMessageProcessEvent;
import com.telink.ble.mesh.foundation.event.ScanEvent;
import com.telink.ble.mesh.foundation.event.StatusNotificationEvent;
import com.telink.ble.mesh.foundation.parameter.AutoConnectParameters;
import com.telink.ble.mesh.foundation.parameter.BindingParameters;
import com.telink.ble.mesh.foundation.parameter.FastProvisioningParameters;
import com.telink.ble.mesh.foundation.parameter.GattOtaParameters;
import com.telink.ble.mesh.foundation.parameter.MeshOtaParameters;
import com.telink.ble.mesh.foundation.parameter.ProvisioningParameters;
import com.telink.ble.mesh.foundation.parameter.ScanParameters;
import com.telink.ble.mesh.DeviceInfo;
import com.telink.ble.mesh.NodeInfo;
import com.telink.ble.mesh.UnitConvert;
import com.telink.ble.mesh.util.ContextUtil;
import com.telink.ble.mesh.util.MeshLogger;
import com.telink.ble.mesh.util.Strings;

import static com.telink.ble.mesh.TelinkBtSigPackage.TAG;

public class TelinkBtSigNativeModule extends ReactContextBaseJavaModule implements ActivityEventListener,
        LifecycleEventListener, EventHandler, FUCallback {

    // Debugging
    private static final boolean D = true;

    private static final int REQUEST_CODE_LOCATION_SETTINGS = 2;
    private static final int ACCESS_COARSE_LOCATION_RESULT_CODE = 4;
    private static final int BLUETOOTH_RESULT_CODE = 5;
    private static final int REQUEST_ENABLE_BT = 7;

    // TODO: why telink_sig_mesh_sdk_v3.3.3.5/app/android/TelinkBleMesh/TelinkBleMesh/TelinkBleMeshDemo/src/main/java/com/telink/ble/mesh/ui/MeshOTAActivity.java
    // use 0xC00F ?
    /**
     * group mesh address used in mesh-OTA procedure
     */
    private static final int MESH_OTA_GROUP_ADDRESS = 0xC00F;

    // Event names
    public static final String BT_ENABLED = "bluetoothEnabled";
    public static final String BT_DISABLED = "bluetoothDisabled";
    public static final String SYSTEM_LOCATION_ENABLED = "systemLocationEnabled";
    public static final String SYSTEM_LOCATION_DISABLED = "systemLocationDisabled";
    public static final String SERVICE_CONNECTED = "serviceConnected";
    public static final String SERVICE_DISCONNECTED = "serviceDisconnected";
    public static final String NOTIFICATION_ONLINE_STATUS = "notificationOnlineStatus";
    public static final String NOTIFICATION_GET_DEVICE_STATE = "notificationGetDeviceState";
    public static final String NOTIFICATION_VENDOR_RESPONSE = "notificationVendorResponse";
    public static final String NOTIFICATION_DATA_GET_ON_OFF = "notificationDataGetOnOff";
    public static final String NOTIFICATION_DATA_GET_LEVEL = "notificationDataGetLevel";
    public static final String NOTIFICATION_DATA_GET_LIGHTNESS = "notificationDataGetLightness";
    public static final String NOTIFICATION_DATA_GET_CTL = "notificationDataGetCtl";
    public static final String NOTIFICATION_DATA_GET_TEMP = "notificationDataGetTemp";
    public static final String NOTIFICATION_DATA_GET_VERSION = "notificationDataGetVersion";
    public static final String NOTIFICATION_DATA_GET_MESH_OTA_PROGRESS = "notificationDataGetMeshOtaProgress";
    public static final String NOTIFICATION_DATA_GET_MESH_OTA_APPLY_STATUS = "notificationDataGetMeshOtaApplyStatus";
    public static final String NOTIFICATION_DATA_GET_MESH_OTA_FIRMWARE_DISTRIBUTION_STATUS = "notificationDataGetMeshOtaFirmwareDistributionStatus";
    public static final String NOTIFICATION_DATA_GET_OTA_STATE = "notificationDataGetOtaState";
    public static final String NOTIFICATION_DATA_SET_OTA_MODE_RES = "notificationDataSetOtaModeRes";
    public static final String DEVICE_STATUS_CONNECTING = "deviceStatusConnecting";
    public static final String DEVICE_STATUS_CONNECTED = "deviceStatusConnected";
    public static final String DEVICE_STATUS_LOGINING = "deviceStatusLogining";
    public static final String DEVICE_STATUS_LOGIN = "deviceStatusLogin";
    public static final String DEVICE_STATUS_LOGOUT = "deviceStatusLogout";
    public static final String DEVICE_STATUS_ERROR_N = "deviceStatusErrorAndroidN";
    public static final String DEVICE_STATUS_UPDATE_MESH_COMPLETED = "deviceStatusUpdateMeshCompleted";
    public static final String DEVICE_STATUS_UPDATING_MESH = "deviceStatusUpdatingMesh";
    public static final String DEVICE_STATUS_UPDATE_MESH_FAILURE = "deviceStatusUpdateMeshFailure";
    public static final String DEVICE_STATUS_UPDATE_ALL_MESH_COMPLETED = "deviceStatusUpdateAllMeshCompleted";
    public static final String DEVICE_STATUS_GET_LTK_COMPLETED = "deviceStatusGetLtkCompleted";
    public static final String DEVICE_STATUS_GET_LTK_FAILURE = "deviceStatusGetLtkFailure";
    public static final String DEVICE_STATUS_MESH_OFFLINE = "deviceStatusMeshOffline";
    public static final String DEVICE_STATUS_MESH_SCAN_COMPLETED = "deviceStatusMeshScanCompleted";
    public static final String DEVICE_STATUS_MESH_SCAN_TIMEOUT = "deviceStatusMeshScanTimeout";
    public static final String DEVICE_STATUS_OTA_MASTER_PROGRESS = "deviceStatusOtaMasterProgress";
    public static final String DEVICE_STATUS_OTA_MASTER_COMPLETE = "deviceStatusOtaMasterComplete";
    public static final String DEVICE_STATUS_OTA_MASTER_FAIL = "deviceStatusOtaMasterFail";
    public static final String DEVICE_STATUS_GET_FIRMWARE_COMPLETED = "deviceStatusGetFirmwareCompleted";
    public static final String DEVICE_STATUS_GET_FIRMWARE_FAILURE = "deviceStatusGetFirmwareFailure";
    public static final String DEVICE_STATUS_DELETE_COMPLETED = "deviceStatusDeleteCompleted";
    public static final String DEVICE_STATUS_DELETE_FAILURE = "deviceStatusDeleteFailure";
    public static final String LE_SCAN = "leScan";
    public static final String LE_SCAN_COMPLETED = "leScanCompleted";
    public static final String LE_SCAN_TIMEOUT = "leScanTimeout";
    public static final String MESH_OFFLINE = "meshOffline";
    public static final String SAVE_OR_UPDATE_JS = "saveOrUpdateJS";

    // Members
    private static TelinkBtSigNativeModule mThis;
    private static MeshService mService;
    private BluetoothAdapter mBluetoothAdapter;
    private ReactApplicationContext mReactContext;
    protected Context mContext;
    private Handler mHandler = new Handler(Looper.getMainLooper());

    // 这里猥琐地存在与 JS 层一样的数据，特别是较大的 devices :(
    // 不过好处是 JS 层只需保存紧凑的 nodeInfo 数组数据而有利于减少分享配置
    // 时的数据量，而且 element 的处理也在这里 NodeInfo.from() 后进行，有
    // 利于与其它没有 element 概念的 react-native-bt* 一起兼容于同一份 JS
    public byte[] mNetKey;
    // 大部分简单用途的蓝牙 APP 只会控制一种类型蓝牙设备比如灯泡，所以本 JAVA 文件只
    // 使用了一个 mAppKey ，如果有复杂用途的比如同时控制灯泡和门锁之类的，请自行修改
    public byte[] mAppKey;
    public int mAppKeyIndex = 0;
    public int sno = 0; // provisioner sequence number
    public int ivIndex = 0;
    public int mMeshAddressOfApp; // localAddress in telink demo
    public List<DeviceInfo> devices = new ArrayList<>();
    public ExtendBearerMode extendBearerMode = ExtendBearerMode.NONE;
    DistributorType otaDistributorType = DistributorType.PHONE;
    private boolean manuallyCheckSystemLocation = false;
    private boolean manuallyRequestLocationPermissions = false;

    private boolean hasOnlineStatusNotifyRaw;
    private boolean kickDirect; // is kicking out direct connected device?
    private int mConfigNodeResetMeshAddress;
    private String mConfigNodeResetMacAddress;
    private int mSetNodeGroupAddrType;
    private int mSetNodeGroupMeshAddr;
    private int mSetNodeGroupAddrGroupAddr;
    private ReadableArray mSetNodeGroupAddrEleIds;
    private int mSetNodeGroupAddrEleIdsIndex = 0;

    // Promises
    private Promise mConfigNodePromise;
    private Promise mClaimAllAtOncePromise;
    private Promise mConfigNodeResetPromise;
    private Promise mSetNodeGroupAddrPromise;
    private Promise mSendCommandRspPromise = null;
    private Promise mGetTimePromise;
    private Promise mGetAlarmPromise;
    private Promise mStartOtaPromise;

    final BroadcastReceiver mBluetoothStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();

            if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
                final int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR);
                switch (state) {
                    case BluetoothAdapter.STATE_OFF:
                        if (D) Log.d(TAG, "Bluetooth was disabled");
                        sendEvent(BT_DISABLED);
                        break;
                    case BluetoothAdapter.STATE_ON:
                        if (D) Log.d(TAG, "Bluetooth was enabled");
                        sendEvent(BT_ENABLED);
                        break;
                }
            }
        }
    };

    public TelinkBtSigNativeModule(ReactApplicationContext reactContext) {
        super(reactContext);
        mThis = this;
        mReactContext = reactContext;
        mContext = mReactContext.getApplicationContext();
    }

    @Override
    public String getName() {
        return "TelinkBtSig";
    }

    public static TelinkBtSigNativeModule getInstance() {
        return mThis;
    }

    @Override
    public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent intent) {
        if (D) Log.d(TAG, "On activity result request: " + requestCode + ", result: " + resultCode);
        // if (requestCode == REQUEST_ENABLE_BLUETOOTH) {
        //     if (resultCode == Activity.RESULT_OK) {
        //         if (D) Log.d(TAG, "User enabled Bluetooth");
        //         if (mEnabledPromise != null) {
        //             mEnabledPromise.resolve(true);
        //         }
        //     } else {
        //         if (D) Log.d(TAG, "User did *NOT* enable Bluetooth");
        //         if (mEnabledPromise != null) {
        //             mEnabledPromise.reject(new Exception("User did not enable Bluetooth"));
        //         }
        //     }
        //     mEnabledPromise = null;
        // }

        // if (requestCode == REQUEST_PAIR_DEVICE) {
        //     if (resultCode == Activity.RESULT_OK) {
        //         if (D) Log.d(TAG, "Pairing ok");
        //     } else {
        //         if (D) Log.d(TAG, "Pairing failed");
        //     }
        // }

        if (requestCode == REQUEST_CODE_LOCATION_SETTINGS) {
            // checkSystemLocation() will be invoked in onHostResume() if
            // not in manuallyCheckSystemLocation, we don't want redundant,
            // so be if here
            if (manuallyCheckSystemLocation) {
                checkSystemLocation();
            }
        }
    }

    @Override
    public void onNewIntent(Intent intent) {
        if (D) Log.d(TAG, "On new intent");
    }


    @Override
    public void onHostResume() {
        if (D) Log.d(TAG, "Host resume");
        // if (mService != null) {
            this.doResume();
        // }
    }

    @Override
    public void onHostPause() {
        if (D) Log.d(TAG, "Host pause");
    }

    @Override
    public void onHostDestroy() {
        if (D) Log.d(TAG, "Host destroy");
        // APP 切到后台时也会调用此处，导致切回前台 Resume 时无法再正常使用本组件，因此使不在此处调用 doDestroy
        // if (mService != null) {
        //     this.doDestroy();
        // }
    }

    @Override
    public void onCatalystInstanceDestroy() {
        if (D) Log.d(TAG, "Catalyst instance destroyed");
        super.onCatalystInstanceDestroy();
        if (mService != null) {
            this.doDestroy();
        }
    }

    public void saveOrUpdateJS() {
        WritableMap params = Arguments.createMap();
        params.putInt("provisionerSno", sno);
        params.putBoolean("hasOnlineStatusNotifyRaw", hasOnlineStatusNotifyRaw);
        sendEvent(SAVE_OR_UPDATE_JS, params);
    }

    @ReactMethod
    public void setDevices(ReadableArray devices) {
        this.devices = new ArrayList<>();

        int size = devices.size();
        for(int i = 0; i < size; i++) {
            ReadableMap device = devices.getMap(i);
            DeviceInfo deviceInfo = new DeviceInfo();
            deviceInfo.meshAddress = device.getInt("meshAddress");
            deviceInfo.macAddress = device.getString("macAddress");
            deviceInfo.elementCnt = device.getInt("elementCnt");
            deviceInfo.deviceKey = readableArray2ByteArray(device.getArray("dhmKey"));
            deviceInfo.nodeInfo = NodeInfo.from(readableArray2ByteArray(device.getArray("nodeInfo")));
            // MeshLogger.d("readableArray2ByteArray: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(readableArray2ByteArray(device.getArray("nodeInfo")), ":"));
            insertDevice(deviceInfo);
        }
    }

    /**
     * init and setup mesh network
     */
    private void startMeshService(ExtendBearerMode extendBearerMode) {
        // init
        mService.init(getCurrentActivity().getApplication(), this);

        mService.setupMeshNetwork(convertToConfiguration());

        // set DLE enable
        mService.resetExtendBearerMode(extendBearerMode);
    }

    @ReactMethod
    public void doInit(String netKey, String appKey, int meshAddressOfApp, ReadableArray devices, int provisionerSno, int provisionerIvIndex, int extendBearerMode) {
        mNetKey = Strings.stringToBytes(netKey);
        mAppKey = Strings.stringToBytes(appKey);
        mMeshAddressOfApp = meshAddressOfApp;
        sno = provisionerSno;
        ivIndex = provisionerIvIndex;
        setDevices(devices);
        this.extendBearerMode = ExtendBearerMode.values()[extendBearerMode];

        // on Android 13, onHostResume() will not be invoked, so use it to
        // call checkSystemLocation(), Android 13 is a shit!
        this.doResume();

        if (!manuallyRequestLocationPermissions) {
            checkPermissions();
            doInitAfterCheckPermissions();
        }
    }

    @ReactMethod
    public void doInitAfterCheckPermissions() {
        if (mService != null) {
            return;
        }

        mService = MeshService.getInstance();
        this.startMeshService(extendBearerMode);
        sendEvent(SERVICE_CONNECTED);

        if (mBluetoothAdapter == null) {
            mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        }

        if (mBluetoothAdapter != null && mBluetoothAdapter.isEnabled()) {
            sendEvent(BT_ENABLED);
        } else {
            sendEvent(BT_DISABLED);
        }

        mReactContext.addActivityEventListener(this);
        mReactContext.addLifecycleEventListener(this);

        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
        mReactContext.registerReceiver(mBluetoothStateReceiver, intentFilter);

        sendEvent(DEVICE_STATUS_LOGOUT);
     }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public void setManuallyCheckSystemLocation(boolean isManually) {
        manuallyCheckSystemLocation = isManually;
     }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public boolean getManuallyCheckSystemLocation() {
        return manuallyCheckSystemLocation;
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public void setManuallyRequestLocationPermissions(boolean isManually) {
        manuallyRequestLocationPermissions = isManually;
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public boolean getManuallyRequestLocationPermissions() {
        return manuallyRequestLocationPermissions;
    }

    @ReactMethod
    public void setLogLevel(int level) {
    }

    @ReactMethod
    public void doDestroy() {
        if (mService != null) {
            mService.clear();
            mService = null;
            sendEvent(SERVICE_DISCONNECTED);
        }
    }

    @ReactMethod
    public void doResume() {
        Log.d(TAG, "onResume");
        // 检查是否支持蓝牙设备
        // if (!LeBluetooth.getInstance().isSupport(mContext)) {
        //     Toast.makeText(mContext, "ble not support", Toast.LENGTH_SHORT).show();
        //     return;
        // }

        // If user click `don't ask again`, will frequently
        // sendEvent(SYSTEM_LOCATION_ENABLED) to JS which cause APP stuck,
        // that's why need move checkPermissions() into doInit().
        // checkPermissions();

        if (!manuallyCheckSystemLocation) {
            checkSystemLocation();
        }
    }

    private void checkPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) { // M is Android API 23
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(getCurrentActivity(),
                            new String[]{Manifest.permission.BLUETOOTH_SCAN,
                                Manifest.permission.BLUETOOTH_CONNECT,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                                Manifest.permission.ACCESS_FINE_LOCATION},
                            BLUETOOTH_RESULT_CODE);
                }
            } else {
                boolean reqPermLoc = false;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { // Q is Android API 29
                    reqPermLoc = ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED;
                } else {
                    // If use above when running on Android 9 (SDK < 29), and use
                    // checkPermissions() in doResume(), will frequently
                    // sendEvent(SYSTEM_LOCATION_ENABLED) to JS which cause APP stuck,
                    // that's why need below to prevent it.
                    // If use below when running on Android 10 (SDK >= 29), will not
                    // have any device result after startScan(), that's why need above.
                    reqPermLoc = ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED;
                }

                if (reqPermLoc) {
                    ActivityCompat.requestPermissions(getCurrentActivity(),
                            new String[]{Manifest.permission.ACCESS_COARSE_LOCATION,
                                Manifest.permission.ACCESS_FINE_LOCATION},
                            ACCESS_COARSE_LOCATION_RESULT_CODE);
                }
            }

            if (ContextCompat.checkSelfPermission(getCurrentActivity(),
                    Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(getCurrentActivity(),
                        new String[]{Manifest.permission.BLUETOOTH},
                        BLUETOOTH_RESULT_CODE);
            }

            // if (ContextCompat.checkSelfPermission(getCurrentActivity(),
            //         Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            //     ActivityCompat.requestPermissions(getCurrentActivity(),
            //             new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
            //             STORAGE_RESULT_CODE);
            // }
        }
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public boolean isLocationPermissionsGranted() {
        boolean reqPermLoc = false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) { // M is Android API 23
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                reqPermLoc = ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED;
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { // Q is Android API 29
                    reqPermLoc = ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED;
                } else {
                    reqPermLoc = ContextCompat.checkSelfPermission(getCurrentActivity(),
                        Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED;
                }
            }
        }
        return !reqPermLoc;
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public boolean isSystemLocationEnabled() {
        boolean enabled = true;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextUtil.isLocationEnable(mContext)) {
                enabled = true;
            } else {
                enabled = false;
            }
        }
        return enabled;
    }

    @ReactMethod
    public void checkSystemLocation() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextUtil.isLocationEnable(mContext)) {
                sendEvent(SYSTEM_LOCATION_ENABLED);
            } else {
                sendEvent(SYSTEM_LOCATION_DISABLED);
            }
        }
    }

    @ReactMethod
    public void enableBluetooth() {
        Intent intent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
        // getCurrentActivity().startActivityForResult(intent, REQUEST_ENABLE_BT);
        getCurrentActivity().startActivity(intent);

        // below not working on Android 13, so use above instead
        // if (mBluetoothAdapter != null && !mBluetoothAdapter.isEnabled()) {
        //     mBluetoothAdapter.enable();
        // }
    }

    @ReactMethod
    public void enableSystemLocation() {
        Intent locationIntent = new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
        getCurrentActivity().startActivityForResult(locationIntent, REQUEST_CODE_LOCATION_SETTINGS);
    }

    @ReactMethod
    public void requestLocationPermissions() {
        checkPermissions();
        if (manuallyRequestLocationPermissions) {
            doInitAfterCheckPermissions();
        }
    }


    @ReactMethod
    public void resetExtendBearerMode(int extendBearerMode) {
        this.extendBearerMode = ExtendBearerMode.values()[extendBearerMode];
        mService.resetExtendBearerMode(this.extendBearerMode);
    }

    @ReactMethod
    public void notModeAutoConnectMesh(Promise promise) {
        if (mService != null) {
            if (mService.getCurrentMode() != MeshController.Mode.AUTO_CONNECT) {
                promise.resolve(true);
            } else {
                promise.reject(new Exception("Already in mode AutoConnectMesh"));
            }
        } else {
            promise.reject(new Exception("MeshService is null"));
        }
    }

    @ReactMethod
    public void autoConnect() {
        mService.autoConnect(new AutoConnectParameters());
    }

    @ReactMethod
    public void idleMode(boolean disconnect) {
        mService.idle(disconnect);
    }

    @ReactMethod
    public void startScan(int timeoutSeconds, boolean isSingleNode) {
        ScanParameters parameters = ScanParameters.getDefault(false, isSingleNode);
        parameters.setScanTimeout(timeoutSeconds * 1000);
        mService.startScan(parameters);
    }

    // public static String[] readableArray2StringArray(ReadableArray arr) {
    //     int size = arr.size();
    //     String[] StringArr = new String[size];
    //     for(int i = 0; i < size; i++) {
    //         StringArr[i] = arr.getString(i);
    //     }

    //     return StringArr;
    // }

    public static WritableArray byteArray2WritableArray(byte[] byteArr) {
        int size = byteArr.length;
        WritableArray writableArr = Arguments.createArray();
        for (int i = 0; i < size; i++) {
            writableArr.pushInt(byteArr[i]);
        }

        return writableArr;
    }

    public static int[] readableArray2IntArray(ReadableArray arr) {
        int size = arr.size();
        int[] intArr = new int[size];
        for(int i = 0; i < size; i++) {
            intArr[i] = arr.getInt(i);
        }

        return intArr;
    }

    public static short[] readableArray2ShortArray(ReadableArray arr) {
        int size = arr.size();
        short[] shortArr = new short[size];
        for(int i = 0; i < size; i++) {
            shortArr[i] = (short)arr.getInt(i);
        }

        return shortArr;
    }

    public static byte[] readableArray2ByteArray(ReadableArray arr) {
        int size = arr.size();
        byte[] byteArr = new byte[size];
        for(int i = 0; i < size; i++) {
            byteArr[i] = (byte)arr.getInt(i);
        }

        return byteArr;
    }

    @ReactMethod
    public void setCommandsQueueIntervalMs(int interval) {
        NetworkingController.NETWORK_INTERVAL_DEFAULT = interval;
        NetworkingController.netPktSendInterval = interval;
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public int getCommandsQueueIntervalMs() {
        return (int)NetworkingController.netPktSendInterval;
    }

    @ReactMethod
    public void clearCommandQueue() {
        mService.clearMeshMessage();
    }

    @ReactMethod(isBlockingSynchronousMethod = true)
    public int getCommandQueueLength() {
        return mService.getCommandQueueLength();
    }

    @ReactMethod
    public void sendCommand(int opcode, int meshAddress, ReadableArray value, int rspOpcode, int tidPosition, boolean immediate) {
        // telink sdk 3.1.0 do not but 3.3.3.5 do has a queue to cache commands,
        // so let immediate make sense in 3.3.3.5
        if (immediate) {
            mService.clearMeshMessage();
        }

        MeshMessage meshMessage = new MeshMessage();
        meshMessage.setDestinationAddress(meshAddress);
        meshMessage.setOpcode(opcode);
        meshMessage.setParams(readableArray2ByteArray(value));
        meshMessage.setAppKeyIndex(mAppKeyIndex);
        meshMessage.setTidPosition(tidPosition);
        // meshMessage.setAccessType(accessType);
        meshMessage.setResponseOpcode(rspOpcode);

        mService.sendMeshMessage(meshMessage);
    }

    @ReactMethod
    public void sendCommandRsp(int opcode, int meshAddress, ReadableArray value, int rspOpcode, int relayTimes, int retryCnt, int tidPosition, boolean immediate, Promise promise) {
        // telink sdk 3.1.0 do not but 3.3.3.5 do has a queue to cache commands,
        // so let immediate make sense in 3.3.3.5
        if (immediate) {
            mService.clearMeshMessage();
        }

        MeshMessage meshMessage = new MeshMessage();
        meshMessage.setDestinationAddress(meshAddress);
        meshMessage.setOpcode(opcode);
        meshMessage.setParams(readableArray2ByteArray(value));
        meshMessage.setAppKeyIndex(mAppKeyIndex);
        meshMessage.setTidPosition(tidPosition);
        // meshMessage.setAccessType(accessType);
        meshMessage.setResponseOpcode(rspOpcode);
        meshMessage.setResponseMax(relayTimes);
        meshMessage.setRetryCnt(retryCnt);

        mSendCommandRspPromise = promise;
        mService.sendMeshMessage(meshMessage);
    }

    private synchronized void onSendCommandRspCompleted(ReliableMessageProcessEvent reliableMessageProcessEvent) {
        if (mSendCommandRspPromise != null) {
            WritableMap params = Arguments.createMap();
            // params.putBoolean("success", reliableMessageProcessEvent.isSuccess());
            params.putInt("opcode", reliableMessageProcessEvent.getOpcode());
            mSendCommandRspPromise.resolve(params);
            mSendCommandRspPromise = null;
        }
    }

    private synchronized void onSendCommandRspFailure(ReliableMessageProcessEvent reliableMessageProcessEvent) {
        if (mSendCommandRspPromise != null) {
            mSendCommandRspPromise.reject(new Exception(
                "onSendCommandRspFailure opcode: 0x" +
                String.format("%04X", reliableMessageProcessEvent.getOpcode()) +
                " rsp: " +
                reliableMessageProcessEvent.getRspCount() +
                "/" +
                reliableMessageProcessEvent.getRspMax()
            ));
            mSendCommandRspPromise = null;
        } else if (mGetAlarmPromise != null) {
            mGetAlarmPromise.reject(new Exception("GetAlarm onSendCommandRspFailure"));
            mGetAlarmPromise = null;
        } else if (mGetTimePromise != null) {
            mGetTimePromise.reject(new Exception("GetTime onSendCommandRspFailure"));
            mGetTimePromise = null;
        }
    }

    @ReactMethod
    public void changePower(int meshAddress, int value) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_G_ONOFF_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        OnOffSetMessage onOffSetMessage = OnOffSetMessage.getSimple(elementAddr, mAppKeyIndex, value, true, 0);
        mService.sendMeshMessage(onOffSetMessage);
    }

    @ReactMethod
    public void changeBrightness(int meshAddress, int value) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_LIGHTNESS_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        LightnessSetMessage message = LightnessSetMessage.getSimple(elementAddr,
                mAppKeyIndex,
                UnitConvert.lum2lightness(value),
                false, 0);
        mService.sendMeshMessage(message);
    }

    @ReactMethod
    public void changeColorTemp(int meshAddress, int value) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_LIGHT_CTL_TEMP_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        CtlTemperatureSetMessage temperatureSetMessage =
                CtlTemperatureSetMessage.getSimple(elementAddr,
                        mAppKeyIndex, UnitConvert.temp100ToTemp(value),
                        0, false, 0);
        mService.sendMeshMessage(temperatureSetMessage);
    }

    @ReactMethod
    public void changeColor(int meshAddress, int hue, int saturation, int lightness) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_LIGHT_HSL_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        HslSetMessage hslSetMessage = HslSetMessage.getSimple(elementAddr, mAppKeyIndex,
                lightness,
                hue,
                saturation,
                false, 0);
        mService.sendMeshMessage(hslSetMessage);
    }

    @ReactMethod
    public void configNode(ReadableMap node, ReadableArray cpsDataArray, int elementCnt, boolean isToClaim, Promise promise) {
        if (isToClaim) {
            mConfigNodePromise = promise;
            String macAddress = node.getString("macAddress");
            int address = node.getInt("meshAddress");
            MeshLogger.d("alloc address: " + address);

            List<AdvertisingDevice> advDevices = new ArrayList<AdvertisingDevice>(mService.getAdvDevices());
            AdvertisingDevice advDevice = null;
            for (int i = 0; i < advDevices.size(); i++) {
                if (advDevices.get(i).device.getAddress().equals(macAddress)) {
                    advDevice = advDevices.get(i);
                }
            }

            if (advDevice == null) {
                mConfigNodePromise.reject(new Exception("no such device"));
                return;
            }

            byte[] serviceData = MeshUtils.getMeshServiceData(advDevice.scanRecord, true);
            if (serviceData == null || serviceData.length < 16) {
                MeshLogger.log("serviceData error", MeshLogger.LEVEL_ERROR);
                return;
            }
            final int uuidLen = 16;
            byte[] deviceUUID = new byte[uuidLen];

            System.arraycopy(serviceData, 0, deviceUUID, 0, uuidLen);
// MeshLogger.d("serviceData: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(serviceData, ":"));
// MeshLogger.d("deviceUUID: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(deviceUUID, ":"));
// 如果打印出的如下信息中没有 11:02 开头的比如 11:02:01:00 ，就会导致后面的
// device.nodeInfo.cpsData.pid = (deviceUUID[2] & 0xFF) | ((deviceUUID[3] & 0xFF) << 8);
// 没有被赋予正确的值
// telink 的工程师回答说需要在设备固件代码中打开 fastbind 宏 PROVISION_FLOW_SIMPLE_EN
// 在 fastbind 模式下 deviceUUID 前两个字节是 vid(0x0211) （即 vendor identifier ，在 CompositionData
// 中也称为 cid 即 company identifier），第三、四个字节是 pid ，果然
// before set PROVISION_FLOW_SIMPLE_EN to 1 in telink_sig_mesh/vendor/common/mesh_config.h
// serviceData: D3:7C:64:89:C3:03:A0:3B:92:CB:6C:C5:D6:38:C1:A4:00:00
// deviceUUID:  D3:7C:64:89:C3:03:A0:3B:92:CB:6C:C5:D6:38:C1:A4
// after set PROVISION_FLOW_SIMPLE_EN to 1 in telink_sig_mesh/vendor/common/mesh_config.h
// serviceData: 11:02:00:FB:31:32:69:00:07:00:6C:C5:D6:38:C1:A4:00:00
// deviceUUID:  11:02:00:FB:31:32:69:00:07:00:6C:C5:D6:38:C1:A4
// 这里 deviceUUID 中的 00:FB 要如何变成 78:FB 详见 onLeScan() 中的注释
//
// 在 telink sdk 3.1.0 中如果 APP 不使用 privateMode 固件不使用 PROVISION_FLOW_SIMPLE_EN 的话，认领
// 过程需要 20 秒，否则可以降低为 6 秒；
// 在 telink sdk 3.3.3.5 中不论 APP 是否使用 privateMode 固件是否使用 PROVISION_FLOW_SIMPLE_EN ，认领
// 过程皆为 6 秒，所以现在使用 react-native-btsig-telink@2.x 时也可以不再关心 privateMode

            final int oobInfo = MeshUtils.bytes2Integer(serviceData, 16, 2, ByteOrder.LITTLE_ENDIAN);

            mService.stopScan();

            ProvisioningDevice provisioningDevice = new ProvisioningDevice(advDevice.device, deviceUUID, address);

            // TODO: modify oob related code comes from telink demo
            // if (AppSettings.DRAFT_FEATURES_ENABLE) {
            //     provisioningDevice.setOobInfo(oobInfo);
            // }

            // check if oob exists
            // byte[] oob = TelinkMeshApplication.getInstance().getMeshInfo().getOOBByDeviceUUID(deviceUUID);
            // if (oob != null) {
            //     provisioningDevice.setAuthValue(oob);
            // } else {
            //     final boolean autoUseNoOOB = SharedPreferenceHelper.isNoOOBEnable(this);
            //     provisioningDevice.setAutoUseNoOOB(autoUseNoOOB);
            // }

            provisioningDevice.setAutoUseNoOOB(true);

            // for static oob test
            /*provisioningDevice.setAuthValue(new byte[]{
                    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                    0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
            });*/

            // TODO: modify cert related code comes from telink demo
            // provisioningDevice.setRootCert(CertCacheService.getInstance().getRootCert());

            ProvisioningParameters provisioningParameters = new ProvisioningParameters(provisioningDevice);
            if (mService.startProvisioning(provisioningParameters)) {
                DeviceInfo device = new DeviceInfo();
                device.meshAddress = address;
                // if (AppSettings.DRAFT_FEATURES_ENABLE) {
                //     device.oobInfo = oobInfo;
                // }
                device.deviceUUID = deviceUUID;
                // device.macAddress = mService.getCurDeviceMac().toUpperCase();
                device.macAddress = advDevice.device.getAddress();

                if (cpsDataArray.size() > 0) {
                    NodeInfo nodeInfo = new NodeInfo();
                    nodeInfo.nodeAdr = device.meshAddress;
                    nodeInfo.elementCnt = elementCnt;
                    nodeInfo.cpsData = CompositionData.from(readableArray2ByteArray(cpsDataArray));
                    nodeInfo.cpsDataLen = cpsDataArray.size();
                    device.nodeInfo = nodeInfo;
                }

                insertDevice(device);
            } else {
                MeshLogger.d("provisioning busy");
            }
        } else {
            mConfigNodeResetPromise = promise;
            mConfigNodeResetMacAddress = node.getString("macAddress");
            mConfigNodeResetMeshAddress = node.getInt("meshAddress");

            kickDirect = mConfigNodeResetMacAddress.equals(mService.getCurDeviceMac());
            // kickDirect above sometime is not correct, so use kickDirect below
            // kickDirect = mService.getDirectConnectedNodeAddress() == mConfigNodeResetMeshAddress;

            mService.sendMeshMessage(new NodeResetMessage(mConfigNodeResetMeshAddress));
            MeshLogger.d("kickDirect: " + kickDirect);
        }
    }

    @ReactMethod
    public void claimAllAtOnce(int firstMeshAddress, ReadableArray pidEleCnts, Promise promise) {
        mClaimAllAtOncePromise = promise;
        SparseIntArray elementPidMap = new SparseIntArray(pidEleCnts.size());
        for (int i = 0; i < pidEleCnts.size(); i++) {
            ReadableMap pidEleCnt = pidEleCnts.getMap(i);
            int pid = pidEleCnt.getInt("pid");
            int eleCnt = pidEleCnt.getInt("eleCnt");
            elementPidMap.put(pid, eleCnt);
        }
        mService.startFastProvision(new FastProvisioningParameters(FastProvisioningConfiguration.getDefault(
                firstMeshAddress,
                elementPidMap
        )));
    }

    private void onKickOutFinish() {
        kickDirect = false;

        if (mConfigNodeResetPromise != null) {
            mService.removeDevice(mConfigNodeResetMeshAddress);
            this.removeDeviceByMesh(mConfigNodeResetMeshAddress);
            WritableMap params = Arguments.createMap();
            mConfigNodeResetPromise.resolve(params);
            mConfigNodeResetPromise = null;
        } else if (mConfigNodePromise != null) {    // provision successful but keybind failure
            mConfigNodePromise.reject(new Exception("onUpdateMeshFailure"));
            mConfigNodePromise = null;
        }
    }

    public DeviceInfo getDeviceByMacAddress(String address) {
        for (DeviceInfo device : devices) {
            if (device.macAddress.equals(address))
                return device;
        }
        return null;
    }

    public DeviceInfo getDeviceByMeshAddress(int address) {
        for (DeviceInfo device : devices) {
            if (device.meshAddress == address)
                return device;
        }
        return null;
    }

    public void insertDevice(DeviceInfo device) {
        DeviceInfo local = getDeviceByMacAddress(device.macAddress);
        if (local != null) {
            this.removeDeviceByMac(device.macAddress);
        }
        devices.add(device);
    }

    public boolean removeDeviceByMac(String address) {
        if (devices == null || devices.size() == 0) return false;
        Iterator<DeviceInfo> iterator = devices.iterator();
        while (iterator.hasNext()) {
            DeviceInfo device = iterator.next();
            if (device.macAddress.endsWith(address)) {
                iterator.remove();
                return true;
            }
        }
        return false;
    }

    public boolean removeDeviceByMesh(int address) {
        if (devices == null || devices.size() == 0) return false;
        Iterator<DeviceInfo> iterator = devices.iterator();
        while (iterator.hasNext()) {
            DeviceInfo device = iterator.next();
            if (device.meshAddress == address) {
                iterator.remove();
                return true;
            }
        }
        return false;
    }

    public AdvertisingDevice getAdvDeviceByMacAddress(String address) {
        List<AdvertisingDevice> advDevices = new ArrayList<AdvertisingDevice>(mService.getAdvDevices());
        for (AdvertisingDevice advDevice : advDevices) {
            if (advDevice.device.getAddress().equals(address))
                return advDevice;
        }
        return null;
    }

    private void onProvisionSuccess(ProvisioningEvent event) {
        if (D) Log.d(TAG, "onProvisionSuccess");
        ProvisioningDevice provisioningDevice = event.getProvisioningDevice();

        DeviceInfo device = getDeviceByMeshAddress(provisioningDevice.getUnicastAddress());

        // check if device support fast bind
        boolean defaultBound = device.nodeInfo != null;

        device.elementCnt = defaultBound ? device.nodeInfo.elementCnt : provisioningDevice.getDeviceCapability().eleNum;
        device.deviceKey = provisioningDevice.getDeviceKey();

        byte[] deviceUUID = provisioningDevice.getDeviceUUID();
        if (defaultBound) {
            MeshLogger.d("private device");
            device.nodeInfo.deviceKey = device.deviceKey;

            // maybe your project does not need this line
            // pid 可能不同，比如某个灯串产品将实际的灯珠数放在预定义好的灯串 cpsData 中 pid 的低位字节，所以需要在此处替换
            // 注意，这里一定要在可能为负数的 deviceUUID[2] 上 & 0xFF ，否则容易使得 pid 的高 8 位 字节无条件为 0xFF
            device.nodeInfo.cpsData.pid = (deviceUUID[2] & 0xFF) | ((deviceUUID[3] & 0xFF) << 8);

            // PrivateDevice.js 中预定义的版本号不一定与固件中的相同，所以需要在此处替换
            device.nodeInfo.cpsData.vid = (deviceUUID[4] & 0xFF) | ((deviceUUID[5] & 0xFF) << 8);
        }

        BindingDevice bindingDevice = new BindingDevice(device.meshAddress, device.deviceUUID, mAppKeyIndex);
        bindingDevice.setDefaultBound(defaultBound);
        bindingDevice.setBearer(BindingBearer.GattOnly);
        mService.startBinding(new BindingParameters(bindingDevice));
    }

    private void onProvisionFail(ProvisioningEvent event) {
        if (D) Log.d(TAG, "onProvisionFail");
        if (mConfigNodePromise != null) {
            mConfigNodePromise.reject(new Exception("onProvisionFail"));
        }
        mConfigNodePromise = null;
    }

    private void onUpdateMeshCompleted(BindingEvent event) {
        BindingDevice bindingDevice = event.getBindingDevice();
        DeviceInfo device = getDeviceByMeshAddress(bindingDevice.getMeshAddress());
        if (device == null) {
            if (D) Log.d(TAG, "can't find device in devices of native");
            if (mConfigNodePromise != null) {
                mConfigNodePromise.reject(new Exception("can't find device in devices of native"));
                mConfigNodePromise = null;
            }
            return;
        };

        // if is default bound, composition data has been valued ahead of binding action
        if (!bindingDevice.isDefaultBound()) {
            NodeInfo nodeInfo = new NodeInfo();
            nodeInfo.nodeAdr = device.meshAddress;
            nodeInfo.elementCnt = device.elementCnt;
            nodeInfo.deviceKey = device.deviceKey;
            nodeInfo.cpsData = bindingDevice.getCompositionData();
            byte[] cpsData = NodeInfo.cpsDataToBytes(nodeInfo.cpsData);
            nodeInfo.cpsDataLen = cpsData.length;
            device.nodeInfo = nodeInfo;
        }

        if (mConfigNodePromise != null) {
            WritableMap params = Arguments.createMap();

            // 来自 MeshController.java 中 BindingEvent.EVENT_TYPE_BIND_SUCCESS 处
            WritableArray nodeInfo = Arguments.createArray();
            byte[] nodeInfoArray = device.nodeInfo.toVCNodeInfo();
            // MeshLogger.d("nodeInfoArray: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(nodeInfoArray, ":"));
            int nodeInfoWithoutCpsDataLength = 22;
            int nodeInfoValidLength = nodeInfoWithoutCpsDataLength + device.nodeInfo.cpsDataLen;
            for (int i = 0; i < nodeInfoValidLength; i++) {
                nodeInfo.pushInt(nodeInfoArray[i]);
            }

            // telink sdk 3.2.1 内含 NodeInfo.java ，当时发给 JS 的是 nodeInfo 数组来保存 element 等信息，
            // telink sdk 3.3.3.5 不再内含 NodeInfo.java ，但为了兼容性考虑以及数组更容易发送给 JS （并在
            // index.native.js 中使用 byteArray2HexString() 转换为字符串返回给 APP ），予以保留
            params.putArray("nodeInfo", nodeInfo);

            params.putInt("elementCnt", device.elementCnt);
            params.putInt("type", device.nodeInfo.cpsData.pid);
            WritableArray array = Arguments.createArray();
            byte[] dhmKey = device.deviceKey;
            // MeshLogger.d("dhmKey: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(dhmKey, ":"));
            for (int i = 0; i < dhmKey.length; i++) {
                array.pushInt(dhmKey[i]);
            }
            params.putArray("dhmKey", array);

            mConfigNodePromise.resolve(params);
        }
        mConfigNodePromise = null;
    }

    private void onUpdateMeshFailure(BindingEvent event) {
        BindingDevice bindingDevice = event.getBindingDevice();
        if (D) Log.d(TAG, "onUpdateMeshFailure");
        kickDirect = true;
        mService.sendMeshMessage(new NodeResetMessage(bindingDevice.getMeshAddress()));
        // mConfigNodePromise 将在 onKickOutFinish() 中被置 null
    }

    private void onUpdateMeshFailure() {
        if (D) Log.d(TAG, "onUpdateMeshFailure");
        if (mConfigNodePromise != null) {
            mConfigNodePromise.reject(new Exception("onUpdateMeshFailure"));
        }
        mConfigNodePromise = null;
    }

    private void onFastProvisionDeviceFound(FastProvisioningEvent event) {
        FastProvisioningDevice fastProvisioningDevice = event.getFastProvisioningDevice();

        WritableMap params = Arguments.createMap();
        params.putString("macAddress", com.telink.ble.mesh.util.Arrays.bytesToHexString(fastProvisioningDevice.getMac(), ":"));
        params.putInt("meshAddress", fastProvisioningDevice.getNewAddress());
        params.putInt("productUUID", fastProvisioningDevice.getPid());
        WritableArray array = Arguments.createArray();
        byte[] dhmKey = fastProvisioningDevice.getDeviceKey();
        for (int i = 0; i < dhmKey.length; i++) {
            array.pushInt(dhmKey[i]);
        }
        params.putArray("dhmKey", array);
        sendEvent(DEVICE_STATUS_UPDATING_MESH, params);
    }

    private void onFastProvisionComplete(boolean success) {
        if (success) {
            WritableMap params = Arguments.createMap();
            mClaimAllAtOncePromise.resolve(params);
        } else {
            mClaimAllAtOncePromise.reject(new Exception("onFastProvisionFailure"));
        }
    }

    private synchronized void onOnlineStatusNotify(OnlineStatusEvent onlineStatusEvent) {
        List<OnlineStatusInfo> infoList = onlineStatusEvent.getOnlineStatusInfoList();
        if (infoList != null) {
            WritableArray params = Arguments.createArray();
            for (OnlineStatusInfo onlineStatusInfo : infoList) {
                if (onlineStatusInfo.status == null || onlineStatusInfo.status.length < 3) break;
                WritableMap map = Arguments.createMap();
                map.putInt("meshAddress", onlineStatusInfo.address);
                map.putInt("brightness", onlineStatusInfo.status[0]);
                map.putInt("colorTemp", onlineStatusInfo.status[1]);
                map.putInt("reserve", onlineStatusInfo.status[2]);
                int connectionStatus;
                if (onlineStatusInfo.sn == 0) {
                    connectionStatus = -1;
                } else {
                    if (onlineStatusInfo.status[0] == 0) {
                        connectionStatus = 0;
                    } else {
                        connectionStatus = 1;
                    }
                }
                map.putInt("status", connectionStatus);
                params.pushMap(map);
            }
            sendEvent(NOTIFICATION_ONLINE_STATUS, params);
        }
    }

    // private synchronized void onMeshOffline(MeshEvent event) {
    //     // onUpdateMeshFailure();
    //     sendEvent(MESH_OFFLINE);
    // }

    private synchronized void onVendorResponse(NotificationMessage notificationMessage) {
        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationMessage.getSrc());
        params.putInt("opcode", notificationMessage.getOpcode());
        params.putArray("params", byteArray2WritableArray(notificationMessage.getParams()));
        sendEvent(NOTIFICATION_VENDOR_RESPONSE, params);
    }

    private synchronized void onGetOnOffNotify(NotificationMessage message) {
        OnOffStatusMessage onOffStatusMessage = (OnOffStatusMessage) message.getStatusMessage();

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", message.getSrc());
        params.putInt("onOff", onOffStatusMessage.isComplete() ? onOffStatusMessage.getTargetOnOff() : onOffStatusMessage.getPresentOnOff());
        sendEvent(NOTIFICATION_DATA_GET_ON_OFF, params);
    }

    private synchronized void onGetLevelNotify(NotificationMessage message) {
        LevelStatusMessage levelStatusMessage = (LevelStatusMessage) message.getStatusMessage();

        int srcAdr = message.getSrc();
        int level = levelStatusMessage.isComplete() ? levelStatusMessage.getTargetLevel() : levelStatusMessage.getPresentLevel();
        int tarVal = UnitConvert.level2lum((short) level); // 测试得： level 为 0x7FFF 时， level2Lum 会转换为 100

        WritableMap params = Arguments.createMap();
        // 如下这么折腾 element ，而且还可能会调用多次 sendEvent ，则还不如直接使用 onGetCtlNotify 更简洁
        // MeshLogger.d("lightness status val: " + tarVal);
        for (DeviceInfo device : devices) {
            if (device.nodeInfo == null) {
                continue;
            }
            int deviceAdr = -1;
            int elementAddr = device.meshAddress;
            for (CompositionData.Element element : device.nodeInfo.cpsData.elements) {
                if (elementAddr == srcAdr) {
                    if (element.containModel(MeshSigModel.SIG_MD_LIGHTNESS_S.modelId)) {
                        params.putInt("brightness", tarVal);
                        deviceAdr = device.meshAddress;
                        break;
                    } else if (element.containModel(MeshSigModel.SIG_MD_LIGHT_CTL_TEMP_S.modelId)) {
                        params.putInt("colorTemp", tarVal);
                        deviceAdr = device.meshAddress;
                        break;
                    }
                }
                elementAddr++;
            }

            if (deviceAdr != -1) {
                params.putInt("meshAddress", deviceAdr);
                sendEvent(NOTIFICATION_DATA_GET_LEVEL, params);
                return;
            }
        }
    }

    private synchronized void onGetLightnessNotify(NotificationMessage message) {
        LightnessStatusMessage lightnessStatusMessage = (LightnessStatusMessage) message.getStatusMessage();

        int srcAdr = message.getSrc();
        int lightness = lightnessStatusMessage.isComplete() ? lightnessStatusMessage.getTargetLightness() : lightnessStatusMessage.getPresentLightness();
        int lum = UnitConvert.lightness2lum(lightness); // 测试得：上面 lightness 为 0xFFFF 时， lightness2lum 会转换为 100

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", srcAdr);
        params.putInt("brightness", lum);
        sendEvent(NOTIFICATION_DATA_GET_LIGHTNESS, params);
    }

    private synchronized void onGetCtlNotify(NotificationMessage message) {
        CtlStatusMessage ctlStatusMessage = (CtlStatusMessage) message.getStatusMessage();

        MeshLogger.d("ctl : " + ctlStatusMessage.toString());
        int srcAdr = message.getSrc();
        int lum = ctlStatusMessage.isComplete() ? ctlStatusMessage.getTargetLightness() : ctlStatusMessage.getPresentLightness();
        int temp = ctlStatusMessage.isComplete() ? ctlStatusMessage.getTargetTemperature() : ctlStatusMessage.getPresentTemperature();

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", srcAdr);
        params.putInt("brightness", UnitConvert.lightness2lum(lum));
        params.putInt("colorTemp", UnitConvert.tempToTemp100(temp));
        sendEvent(NOTIFICATION_DATA_GET_CTL, params);
    }

    private synchronized void onGetTempNotify(NotificationMessage message) {
        CtlTemperatureStatusMessage ctlTemperatureStatusMessage = (CtlTemperatureStatusMessage) message.getStatusMessage();

        int srcAdr = message.getSrc();
        int temp = ctlTemperatureStatusMessage.isComplete() ? ctlTemperatureStatusMessage.getTargetTemperature() : ctlTemperatureStatusMessage.getPresentTemperature();
        int colorTemp = UnitConvert.lightness2lum(temp);

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", srcAdr);
        params.putInt("colorTemp", colorTemp);
        sendEvent(NOTIFICATION_DATA_GET_TEMP, params);
    }

    @ReactMethod
    public void setNodeGroupAddr(boolean toDel, int meshAddress, int groupAddress, ReadableArray eleIds, Promise promise) {
        mSetNodeGroupAddrType = toDel ? 1 : 0;
        mSetNodeGroupMeshAddr = meshAddress;
        mSetNodeGroupAddrGroupAddr = groupAddress;
        mSetNodeGroupAddrEleIds = eleIds;
        mSetNodeGroupAddrEleIdsIndex = 0;
        mSetNodeGroupAddrPromise = promise;
        setNextModelGroupAddr();
    }

    private void setNextModelGroupAddr() {
        if (mSetNodeGroupAddrEleIdsIndex > mSetNodeGroupAddrEleIds.size() - 1) {
            if (mSetNodeGroupAddrPromise != null) {
                WritableArray params = Arguments.createArray();
                mSetNodeGroupAddrPromise.resolve(params);
            }
            mSetNodeGroupAddrPromise = null;
        } else {
            ReadableMap eleId = mSetNodeGroupAddrEleIds.getMap(mSetNodeGroupAddrEleIdsIndex);
            int elementAddr = eleId.getInt("elementAddr");
            int modelId = eleId.getInt("modelId");
            boolean isSig = eleId.getBoolean("isSig");
            MeshMessage groupingMessage = ModelSubscriptionSetMessage.getSimple(mSetNodeGroupMeshAddr, mSetNodeGroupAddrType, elementAddr, mSetNodeGroupAddrGroupAddr, modelId, isSig);
            if (!mService.sendMeshMessage(groupingMessage)) {
                if (mSetNodeGroupAddrPromise != null) {
                    mSetNodeGroupAddrPromise.reject(new Exception("setSubscription return false"));
                }
                mSetNodeGroupAddrPromise = null;
            }
        }
    }

    private synchronized void onGetModelSubscription(NotificationMessage message) {
        ModelSubscriptionStatusMessage modelSubscriptionStatusMessage = (ModelSubscriptionStatusMessage) message.getStatusMessage();
        if (mSetNodeGroupAddrPromise != null) {
            if (modelSubscriptionStatusMessage.getStatus() == ConfigStatus.SUCCESS.code) {
                MeshLogger.d("group address: " + modelSubscriptionStatusMessage.getAddress());
                mSetNodeGroupAddrEleIdsIndex++;
                setNextModelGroupAddr();
            } else {
                if (mSetNodeGroupAddrPromise != null) {
                    mSetNodeGroupAddrPromise.reject(new Exception("grouping status fail!"));
                }
                mSetNodeGroupAddrPromise = null;
                MeshLogger.e("set group sub error");
            }
        }
    }

    @ReactMethod
    private void setTime(int meshAddress) {
        long time = MeshUtils.getTaiTime();
        int offset = UnitConvert.getZoneOffset();

        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_TIME_SETUP_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        TimeSetMessage timeSetMessage = TimeSetMessage.getSimple(elementAddr, mAppKeyIndex,
                time, offset, 0);

        // 由于 TimeSetMessage 的 getOpcode() 中 `ack ? Opcode.TIME_SET.value : Opcode.TIME_STATUS.value`
        // 在 ack 为默认 false 时的 Opcode.TIME_STATUS.value 会触发固件代码中的 mesh_cmd_sig_time_status() ，
        // 但打印发现其内 `if(p_set->TAI_sec && (!g_TAI_sec)){` 中 g_TAI_sec 不为 0 (而是一个随时间递增的值) ,
        // 导致无法进入 mesh_time_set() ，因而并不会象 telink 人员说的那样 Opcode.TIME_STATUS.value 也能顺带设置
        // 固件内置的时间，估计是一个 BUG ，所以这里需要显式 setAck(true) 来明确使用 Opcode.TIME_SET.value
        timeSetMessage.setAck(true);
        if (mSendCommandRspPromise != null ||
            mGetAlarmPromise != null ||
            mGetTimePromise != null) {
            // 由于上面 setAck(true) ，此时必然会导致 core/networking/NetworkingController.java
            // 中的 reliableBusy 引起 `reliable message send err: busy` 进而触发预期外的
            // onSendCommandRspFailure ，所以这里不如直接 return
            MeshLogger.d("setTime fail is in mSendCommandRspPromise: " + (mSendCommandRspPromise != null) +
                " mGetAlarmPromise: " + (mGetAlarmPromise != null) +
                " mGetTimePromise: " + (mGetTimePromise != null)
            );
            return;
        }

        boolean re = mService.sendMeshMessage(timeSetMessage);
        if (re) {
            MeshLogger.d("setTime time: " + time + " zone " + offset);
        } else {
            MeshLogger.d("setTime fail");
        }
    }

    @ReactMethod
    public void getTime(int meshAddress, int relayTimes, Promise promise) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_TIME_S.modelId);
            if (elementAddr == -1) {
                promise.reject(new Exception("GetTime no time model in device elements"));
                return;
            }
        } else {
            promise.reject(new Exception("GetTime device null"));
            return;
        }

        mGetTimePromise = promise;
        TimeGetMessage timeGetMessage = TimeGetMessage.getSimple(elementAddr, mAppKeyIndex, 0);
        mService.sendMeshMessage(timeGetMessage);
    }

    private synchronized void onGetTimeNotify(NotificationMessage message) {
// typedef struct{
//     u32 TAI_sec;     // 32bit is enough for 2000 ~ 2099 year
//     u8 TAI_sec_rsv;
//     u8 sub_sec;
//     u8 uncertainty;
//     u16 time_auth       :1;
//     u16 TAI_UTC_delta   :15;
//     u8 zone_offset;
// }time_status_t;
        TimeStatusMessage timeStatusMessage = (TimeStatusMessage) message.getStatusMessage();

        long taiSec = timeStatusMessage.getTaiSeconds();
        MeshLogger.d("taiSec: " + taiSec);
        long sec = taiSec + MeshUtils.TAI_OFFSET_SECOND;
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(sec * 1000);

        if (calendar == null) {
            if (mGetTimePromise != null) {
                mGetTimePromise.reject(new Exception("GetTime return null"));
                mGetTimePromise = null;
            }
            return;
        }

        if (mGetTimePromise != null) {
            WritableMap params = Arguments.createMap();
            params.putString("time", String.valueOf(calendar.getTime().getTime()));
            mGetTimePromise.resolve(params);
        }
        mGetTimePromise = null;
    }

    @ReactMethod
    private void setAlarm(int meshAddress, int index, int year, int month, int day, int hour, int minute, int second, int week, int action, int sceneId) {
        int transitionTime = 0;

        Scheduler scheduler = new Scheduler.Builder()
                .setIndex((byte) index)
                .setYear((byte) year)
                .setMonth((short) month)
                .setDay((byte) day)
                .setHour((byte) hour)
                .setMinute((byte) minute)
                .setSecond((byte) second)
                .setWeek((byte) week)
                .setAction((byte) action)
                .setTransTime((byte) transitionTime)
                .setSceneId((short) sceneId).build();
        byte[] schedulerData = scheduler.toBytes();
        MeshLogger.log("scheduler data: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(schedulerData, ""));

        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_SCHED_SETUP_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        SchedulerActionSetMessage schedulerActionSetMessage = SchedulerActionSetMessage.getSimple(elementAddr,
                mAppKeyIndex, scheduler, true, 0);
        mService.sendMeshMessage(schedulerActionSetMessage);
    }

    @ReactMethod
    public void getAlarm(int meshAddress, int relayTimes, int alarmId, Promise promise) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(MeshSigModel.SIG_MD_SCHED_S.modelId);
            if (elementAddr == -1) {
                promise.reject(new Exception("getAlarm no sched model in device elements"));
                return;
            }
        } else {
            promise.reject(new Exception("getAlarm device null"));
            return;
        }

        mGetAlarmPromise = promise;
        SchedulerActionGetMessage schedulerActionGetMessage = SchedulerActionGetMessage.getSimple(elementAddr,
                mAppKeyIndex, (byte) alarmId, 0);
        mService.sendMeshMessage(schedulerActionGetMessage);
    }

    private synchronized void onGetAlarmNotify(NotificationMessage message) {
        SchedulerActionStatusMessage schedulerActionStatusMessage = (SchedulerActionStatusMessage) message.getStatusMessage();
        Scheduler scheduler = schedulerActionStatusMessage.getScheduler();
        if (scheduler == null) {
            if (mGetAlarmPromise != null) {
                mGetAlarmPromise.reject(new Exception("GetAlarm return null"));
                mGetAlarmPromise = null;
            }
            return;
        }

        Scheduler.Register register = scheduler.getRegister();
        if (mGetAlarmPromise != null) {
            WritableMap params = Arguments.createMap();
            params.putInt("alarmId", scheduler.getIndex());
            params.putInt("year", (int)register.getYear() & 0xFF);
            params.putInt("month", (int)register.getMonth() & 0xFFFF);
            params.putInt("day", (int)register.getDay() & 0xFF);
            params.putInt("hour", (int)register.getHour() & 0xFF);
            params.putInt("minute", (int)register.getMinute() & 0xFF);
            params.putInt("second", (int)register.getSecond() & 0xFF);
            params.putInt("week", (int)register.getWeek() & 0xFF);
            params.putInt("action", (int)register.getAction() & 0xFF);
            params.putInt("transTime", (int)register.getTransTime() & 0xFF);
            params.putInt("sceneId", register.getSceneId() & 0xFFFF);
            mGetAlarmPromise.resolve(params);
        }
        mGetAlarmPromise = null;
    }

    @ReactMethod
    public void getFirmwareInfo(int meshAddress) {
        FirmwareUpdateInfoGetMessage infoGetMessage = FirmwareUpdateInfoGetMessage.getSimple(meshAddress,
                mAppKeyIndex);
        infoGetMessage.setResponseMax(0);
        if (mService.sendMeshMessage(infoGetMessage)) {
            MeshLogger.d("getFirmwareInfo success");
        } else {
            MeshLogger.d("getFirmwareInfo fail");
        }
    }

    private synchronized void onGetFirmwareInfo(NotificationMessage message) {
// 在 telink_sig_mesh_sdk_v3.1.0/firmware/vendor/common/mesh_ota.h 里的
// typedef struct{
//    u16 cid;
//    u32 fw_id;
// }fw_cid_fwid_t;
//
// typedef struct{
//    fw_cid_fwid_t id;
// }fw_info_status_t;
// fw_info_status_t 结构体对应着 3.1.0 里 onGetFirmwareInfo() 收到的数据，这也是
// sig_mesh_sdk_v3.1.0/app/Android/TelinkSigMeshRelease/TelinkSigMeshDemo/src/main/java/com/telink/sig/mesh/demo/ui/MeshOTAActivity.java 中
//        /*
//        u16 cid，  (vendor id)
//        u16 pid,   (设备类型)
//        u16 vid    (版本id)
//         */
// 这句注释的由来。
//
// 而在 telink_sig_mesh_sdk_v3.2.1/firmware/vendor/common/mesh_ota.h 里的
// typedef struct{
//    u16 pid;
//    u16 vid;
// }fw_id_t;
//
// typedef struct{
//     u8 list_count;
//     u8 first_index;
// #if 1   // only one firmware for telink SDK
//     u8 fw_id_len;
//     fw_id_t fw_id;
//     u8 uri_len; // set 0 now.
//     // uri[];
// #endif
// }fw_update_info_status_t;
// fw_update_info_status_t 结构体对应着这里 onGetFirmwareInfo() 收到的数据

        FirmwareUpdateInfoStatusMessage firmwareUpdateInfoStatusMessage = (FirmwareUpdateInfoStatusMessage) message.getStatusMessage();

        FirmwareUpdateInfoStatusMessage.FirmwareInformationEntry firstEntry = firmwareUpdateInfoStatusMessage.getFirstEntry();
        if (firstEntry == null) {
            return;
        }

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", message.getSrc());
        params.putString("version", Strings.bytesToString(Arrays.copyOfRange(firstEntry.currentFirmwareID, 2, 4)));
        sendEvent(NOTIFICATION_DATA_GET_VERSION, params);
    }

    @ReactMethod
    public void startMeshOTA(ReadableArray meshAddresses, ReadableArray firmware) {
        final int directAddress = mService.getDirectConnectedNodeAddress();

        // for test - start
//        firmwareData = new byte[4 * 1024];
//        for (int i = 0; i < firmwareData.length; i++) {
//            firmwareData[i] = (byte) (i % 0x0F);
//        }
        // for test - end

        List<MeshUpdatingDevice> meshUpdatingDevices = new ArrayList<>();
        MeshUpdatingDevice device;
        MeshUpdatingDevice directDevice = null;
        int size = meshAddresses.size();
        for(int i = 0; i < size; i++) {
            if (directAddress == meshAddresses.getInt(i)) {
                directDevice = new MeshUpdatingDevice();
            } else {
                device = new MeshUpdatingDevice();
                meshUpdatingDevices.add(device);
            }
        }
        // put direct device to last
        if (directDevice != null) {
            meshUpdatingDevices.add(directDevice);
        }

        byte[] firmwareData = readableArray2ByteArray(firmware);
        byte[] metadata = new byte[8];
        System.arraycopy(firmwareData, 2, metadata, 0, 4);

        FirmwareUpdateConfiguration configuration = new FirmwareUpdateConfiguration(meshUpdatingDevices,
                firmwareData, metadata,
                mAppKeyIndex, MESH_OTA_GROUP_ADDRESS);
        configuration.setUpdatePolicy(UpdatePolicy.VerifyAndApply);
        configuration.setDistributorType(otaDistributorType);
        configuration.setDistributorAddress(otaDistributorType == DistributorType.DEVICE ? directAddress : MeshUtils.LOCAL_MESSAGE_ADDRESS);
        if (otaDistributorType == DistributorType.PHONE) {
            configuration.setProxyAddress(directAddress);
        }
        configuration.setCallback(this);
        byte[] firmwareId = new byte[4];
        System.arraycopy(firmwareData, 2, firmwareId, 0, 4);
        configuration.setFirmwareId(firmwareId);

        MeshOtaParameters meshOtaParameters = new MeshOtaParameters(configuration);
        mService.startMeshOta(meshOtaParameters);
    }

    @ReactMethod
    public void stopMeshOTA() {
        mService.stopMeshOta();
    }

    private synchronized void onGetMeshOtaProgress(int progress) {
        WritableMap params = Arguments.createMap();
        params.putInt("otaSlaveProgress", progress);
        sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_PROGRESS, params);
    }

    private synchronized void onGetGattOtaProgress(int progress) {
        WritableMap params = Arguments.createMap();
        params.putInt("otaMasterProgress", progress);
        sendEvent(DEVICE_STATUS_OTA_MASTER_PROGRESS, params);
    }

    private synchronized void onGetMeshOtaApplyStatus(MeshUpdatingDevice device) {
        if (device.state == MeshUpdatingDevice.STATE_SUCCESS || device.state == MeshUpdatingDevice.STATE_FAIL) {
            WritableMap params = Arguments.createMap();
            params.putInt("meshAddress", device.meshAddress);
            params.putString("status", device.state == MeshUpdatingDevice.STATE_SUCCESS ? "success" : "failure");
            sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_APPLY_STATUS, params);
        }
    }

    private synchronized void onGetMeshOtaFirmwareDistributionStatus(FUState state) {
        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", mMeshAddressOfApp);
        if (state == FUState.TRANSFER_START) {
            params.putString("status", "start");
        }
        if (state == FUState.UPDATE_COMPLETE) {
            params.putString("status", "stop");
        }
        if (state == FUState.INITIATE_FAIL || state == FUState.UPDATE_FAIL) {
            params.putString("status", "error");
        }

        sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_FIRMWARE_DISTRIBUTION_STATUS, params);
    }

    /****************************************************************
     * FUCallback start
     ****************************************************************/

    @Override
    public void onLog(String tag, String log, int logLevel) {
        MeshLogger.log(log, tag, logLevel);
    }

    @Override
    public void onStateUpdated(FUState state, String extraInfo) {
        MeshLogger.d("onStateUpdated - state: " + state.desc + " - " + extraInfo);
        this.onGetMeshOtaFirmwareDistributionStatus(state);
    }

    @Override
    public void onDeviceStateUpdate(MeshUpdatingDevice device, String desc) {
        MeshLogger.d("onDeviceStateUpdate - adr: " + device.meshAddress + " - state: " + device.state + " - " + desc);

        // if (device.state == MeshUpdatingDevice.STATE_SUCCESS) {
        //     final AdditionalInformation addInfo = device.additionalInformation;
        //     if (addInfo == AdditionalInformation.NODE_UNPROVISIONED) {
        //         MeshLogger.d("device will be removed : " + device.meshAddress);
        //         removeDeviceByMesh(device.meshAddress);
        //         saveOrUpdateJS(this);
        //     } else if (addInfo == AdditionalInformation.CPS_CHANGED_1 || addInfo == AdditionalInformation.CPS_CHANGED_2) {
        //     }
        // }

        this.onGetMeshOtaApplyStatus(device);
    }

    @Override
    public void onTransferProgress(int progress, BlobTransferType transferType) {
        onLog("null", "transfer progress update: " + progress + " type - " + transferType, MeshLogger.DEFAULT_LEVEL);
        if (transferType == BlobTransferType.MESH_DIST) {
            this.onGetMeshOtaProgress(progress);
        }
        if (transferType == BlobTransferType.GATT_DIST) {
            this.onGetGattOtaProgress(progress);
        }
    }

    /****************************************************************
     * FUCallback end
     ****************************************************************/

    @ReactMethod
    public void startOta(String mac, ReadableArray firmware, Promise promise) {
        ConnectionFilter connectionFilter = new ConnectionFilter(ConnectionFilter.TYPE_MAC_ADDRESS, mac);
        GattOtaParameters parameters = new GattOtaParameters(connectionFilter, readableArray2ByteArray(firmware));
        mStartOtaPromise = promise;
        mService.startGattOta(parameters);
    }

    private synchronized void onGetOtaProgress(GattOtaEvent event) {
        this.onGetGattOtaProgress(event.getProgress());
    }

    private void onLeScan(ScanEvent event) {
        AdvertisingDevice advDevice = event.getAdvertisingDevice();
        BluetoothDevice btDevice = advDevice.device;
        // MeshLogger.w("name" + btDevice.getName());                       // null
        // MeshLogger.w("addr" + btDevice.getAddress());                    // AB:CD:4F:03:CA:80
        // MeshLogger.w("type" + btDevice.getType());                       // 0
        // MeshLogger.w("uuid" + btDevice.getUuids());                      // null
        // MeshLogger.w("desc" + btDevice.describeContents());              // 0
        // MeshLogger.w("bond" + btDevice.getBondState());                  // 10
        // MeshLogger.w("clas" + btDevice.getBluetoothClass().toString());  // 0
        // MeshLogger.w("hash" + btDevice.hashCode());                      // 1098112549
// MeshLogger.d("scanRecord: " + com.telink.ble.mesh.util.Arrays.bytesToHexString(advDevice.scanRecord, ":"));
// before set PROVISION_FLOW_SIMPLE_EN to 1 in telink_sig_mesh/vendor/common/mesh_config.h
// scanRecord: 02:01:06:03:03:27:18:15:16:27:18:D3:7C:64:89:C3:03:A0:3B:92:CB:6C:C5:D6:38:C1:A4:00:00:1E:FF:6C:C5:D6:38:C1:A4:6C:45:00:00:00:00:00:00:00:00:00:00:01:02:03:04:05:06:07:08:09:0A:0B:00:00
// after set PROVISION_FLOW_SIMPLE_EN to 1 in telink_sig_mesh/vendor/common/mesh_config.h
// scanRecord: 02:01:06:03:03:27:18:15:16:27:18:11:02:00:FB:31:32:69:00:07:00:6C:C5:D6:38:C1:A4:00:00:1E:FF:6C:C5:D6:38:C1:A4:6C:45:00:00:00:00:00:00:00:00:00:00:01:02:03:04:05:06:07:08:09:0A:0B:00:00
// after set rsv_user in mesh_scan_rsp_init() of telink_sig_mesh/vendor/common/mesh_common.c
// scanRecord: 02:01:06:03:03:27:18:15:16:27:18:11:02:00:FB:31:32:69:00:07:00:6C:C5:D6:38:C1:A4:00:00:1E:FF:6C:C5:D6:38:C1:A4:6C:45:00:00:00:00:00:00:00:00:00:00:78:FB:03:04:05:06:07:08:09:0A:0B:00:00
// after set cps_head in set_dev_uuid_for_simple_flow() of telink_sig_mesh/vendor/common/mesh_common.c
// scanRecord: 02:01:06:03:03:27:18:15:16:27:18:11:02:78:FB:31:32:69:00:07:00:6C:C5:D6:38:C1:A4:00:00:1E:FF:6C:C5:D6:38:C1:A4:6C:45:00:00:00:00:00:00:00:00:00:00:78:FB:03:04:05:06:07:08:09:0A:0B:00:00

        WritableArray rsvUser = Arguments.createArray();
        for (int i = 49; i < 60; i++) {
            rsvUser.pushInt(advDevice.scanRecord[i] & 0xFF);
        }

        WritableArray version = Arguments.createArray();
        for (int i = 15; i < 17; i++) {
            version.pushInt(advDevice.scanRecord[i] & 0xFF);
        }

        WritableMap params = Arguments.createMap();
        params.putString("macAddress", btDevice.getAddress());
        // params.putString("deviceName", btDevice.getName());
        // params.putString("meshName", btDevice.describeContents());
        // params.putInt("meshAddress", deviceInfo.meshAddress);
        // params.putInt("meshUUID", btDevice.getUuids());
        params.putInt("productUUID", (advDevice.scanRecord[49] & 0xFF) + (((advDevice.scanRecord[50] & 0xFF) << 8)));
        // params.putInt("status", btDevice.getBondState());
        params.putArray("rsvUser", rsvUser);
        params.putInt("rssi", advDevice.rssi);
        params.putArray("version", version);
        sendEvent(LE_SCAN, params);
    }

    private MeshConfiguration convertToConfiguration() {
        MeshConfiguration meshConfiguration = new MeshConfiguration();

        meshConfiguration.deviceKeyMap = new SparseArray<>();
        if (this.devices != null) {
            for (DeviceInfo device : this.devices) {
                meshConfiguration.deviceKeyMap.put(device.meshAddress, device.deviceKey);
            }
        }

        meshConfiguration.netKeyIndex = 0;
        meshConfiguration.networkKey = mNetKey; // TODO: 不再使用 mNetKey

        meshConfiguration.appKeyMap = new SparseArray<>();

        meshConfiguration.appKeyMap.put(mAppKeyIndex, mAppKey);

        meshConfiguration.ivIndex = ivIndex;

        meshConfiguration.sequenceNumber = sno;

        meshConfiguration.localAddress = mMeshAddressOfApp;

        return meshConfiguration;
    }

    /**
     * after import config (shared by other people) from JS, can invoke this function
     */
    @ReactMethod
    public void replaceMeshSetting(String netKey, String appKey, ReadableArray devices) {
        mService.idle(true);
        mNetKey = Strings.stringToBytes(netKey);
        mAppKey = Strings.stringToBytes(appKey);
        setDevices(devices);

        mService.setupMeshNetwork(convertToConfiguration());
    }

    /**
     * save sequence number and iv index when mesh info updated
     */
    protected void onNetworkInfoUpdate(NetworkInfoUpdateEvent networkInfoUpdateEvent) {
        MeshLogger.d(String.format("mesh info update from local sequenceNumber-%06X ivIndex-%08X to sequenceNumber-%06X ivIndex-%08X",
                sno, ivIndex,
                networkInfoUpdateEvent.getSequenceNumber(), networkInfoUpdateEvent.getIvIndex()));
        ivIndex = networkInfoUpdateEvent.getIvIndex();
        sno = networkInfoUpdateEvent.getSequenceNumber();
        saveOrUpdateJS();
    }

    @Override
    public void onEventHandle(Event<String> event) {
        String eventType = event.getType();
        MeshLogger.d("event handle: " + eventType);

        switch (eventType) {
            case NetworkInfoUpdateEvent.EVENT_TYPE_NETWORKD_INFO_UPDATE:
                this.onNetworkInfoUpdate((NetworkInfoUpdateEvent) event);
                break;
            case OnlineStatusEvent.EVENT_TYPE_ONLINE_STATUS_NOTIFY:
                this.onOnlineStatusNotify((OnlineStatusEvent) event);
                break;
            case GattOtaEvent.EVENT_TYPE_OTA_SUCCESS:
                if (mStartOtaPromise != null) {
                    mStartOtaPromise.resolve(true);
                }
                mStartOtaPromise = null;
                break;
            case GattOtaEvent.EVENT_TYPE_OTA_FAIL:
                if (mStartOtaPromise != null) {
                    mStartOtaPromise.reject(new Exception("OTA_FAIL"));
                }
                mStartOtaPromise = null;
                break;
            case GattOtaEvent.EVENT_TYPE_OTA_PROGRESS:
                this.onGetOtaProgress((GattOtaEvent) event);
                break;
            case AutoConnectEvent.EVENT_TYPE_AUTO_CONNECT_LOGIN:
                if (mConfigNodePromise != null) {
                    return;
                }

                hasOnlineStatusNotifyRaw = mService.getOnlineStatus();
                saveOrUpdateJS();

                WritableMap params = Arguments.createMap();
                params.putInt("connectMeshAddress", mService.getDirectConnectedNodeAddress());
                sendEvent(DEVICE_STATUS_LOGIN, params);
                break;
            case MeshEvent.EVENT_TYPE_DISCONNECTED:
                MeshLogger.d("kickDirect: " + kickDirect + " debug logout");
                if (kickDirect) {
                    mHandler.postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            onKickOutFinish();
                            sendEvent(DEVICE_STATUS_LOGOUT);
                        }
                    }, 2000);
                } else {
                    sendEvent(DEVICE_STATUS_LOGOUT);
                }
                break;
            case ScanEvent.EVENT_TYPE_DEVICE_FOUND:
                onLeScan((ScanEvent) event);
                break;
            case ScanEvent.EVENT_TYPE_SCAN_TIMEOUT:
                sendEvent(LE_SCAN_TIMEOUT);
                sendEvent(DEVICE_STATUS_LOGOUT);
                break;
            case ProvisioningEvent.EVENT_TYPE_PROVISION_SUCCESS:
                onProvisionSuccess((ProvisioningEvent) event);
                break;
            case ProvisioningEvent.EVENT_TYPE_PROVISION_FAIL:
                onProvisionFail((ProvisioningEvent) event);
                break;
            case BindingEvent.EVENT_TYPE_BIND_SUCCESS:
                onUpdateMeshCompleted((BindingEvent) event);
                break;
            case BindingEvent.EVENT_TYPE_BIND_FAIL:
                onUpdateMeshFailure((BindingEvent) event);
                break;
            case FastProvisioningEvent.EVENT_TYPE_FAST_PROVISIONING_ADDRESS_SET:
                onFastProvisionDeviceFound((FastProvisioningEvent) event);
                break;
            case FastProvisioningEvent.EVENT_TYPE_FAST_PROVISIONING_FAIL:
                onFastProvisionComplete(false);
                break;
            case FastProvisioningEvent.EVENT_TYPE_FAST_PROVISIONING_SUCCESS:
                onFastProvisionComplete(true);
                break;
            case StatusNotificationEvent.EVENT_TYPE_NOTIFICATION_MESSAGE_UNKNOWN:
                NotificationMessage message = ((StatusNotificationEvent) event).getNotificationMessage();
                int opcode = message.getOpcode();
                OpcodeType opType = OpcodeType.getByFirstByte((byte)(opcode & 0xFF));
                if (opType == OpcodeType.VENDOR) {
                    this.onVendorResponse(message);
                } else {
                    MeshLogger.d(String.format("Unknown status notify opcode:%04X", opcode) + " -- params:" + com.telink.ble.mesh.util.Arrays.bytesToHexString(message.getParams()));
                }
                break;
            case ReliableMessageProcessEvent.EVENT_TYPE_MSG_PROCESS_COMPLETE:
                this.onSendCommandRspCompleted((ReliableMessageProcessEvent) event);
                break;
            case ReliableMessageProcessEvent.EVENT_TYPE_MSG_PROCESS_ERROR:
                this.onSendCommandRspFailure((ReliableMessageProcessEvent) event);
                break;
            default:
                if (eventType.equals(NodeResetStatusMessage.class.getName())) {
                    MeshLogger.d("kickDirect: " + kickDirect + " confirm");
                    if (!kickDirect) {
                        mHandler.postDelayed(new Runnable() {
                            @Override
                            public void run() {
                                onKickOutFinish();
                            }
                        }, 5500);
                    }
                } else if (eventType.equals(ModelSubscriptionStatusMessage.class.getName())) {
                    this.onGetModelSubscription(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(TimeStatusMessage.class.getName())) {
                    this.onGetTimeNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(SchedulerActionStatusMessage.class.getName())) {
                    this.onGetAlarmNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(OnOffStatusMessage.class.getName())) {
                    this.onGetOnOffNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(LevelStatusMessage.class.getName())) {
                    this.onGetLevelNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(LightnessStatusMessage.class.getName())) {
                    this.onGetLightnessNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(CtlStatusMessage.class.getName())) {
                    this.onGetCtlNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(CtlTemperatureStatusMessage.class.getName())) {
                    this.onGetTempNotify(((StatusNotificationEvent) event).getNotificationMessage());
                } else if (eventType.equals(FirmwareUpdateInfoStatusMessage.class.getName())) {
                    this.onGetFirmwareInfo(((StatusNotificationEvent) event).getNotificationMessage());
                }
                break;
        }
    }

    /**
     * Send event to javascript
     * @param eventName Name of the event
     * @param params Additional params
     */
    public void sendEvent(String eventName, @Nullable WritableMap params) {
        if (mReactContext.hasActiveCatalystInstance()) {
            if (D) Log.d(TAG, "Sending event: " + eventName);
            mReactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
        }
    }

    public void sendEvent(String eventName, @Nullable WritableArray params) {
        if (mReactContext.hasActiveCatalystInstance()) {
            if (D) Log.d(TAG, "Sending event: " + eventName);
            mReactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
        }
    }

    public void sendEvent(String eventName) {
        if (mReactContext.hasActiveCatalystInstance()) {
            if (D) Log.d(TAG, "Sending event: " + eventName);
            mReactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, null);
        }
    }
}
