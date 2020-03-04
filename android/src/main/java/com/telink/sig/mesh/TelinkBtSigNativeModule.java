package com.telink.sig.mesh;

import javax.annotation.Nullable;

import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.ParcelUuid;
import android.provider.Settings;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.annotations.ReactProp;
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

// import com.telink.bluetooth.event.DeviceEvent;
import com.telink.sig.mesh.ble.AdvertisingDevice;
import com.telink.sig.mesh.ble.MeshScanRecord;
import com.telink.sig.mesh.ble.UnprovisionedDevice;
import com.telink.sig.mesh.event.CommandEvent;
import com.telink.sig.mesh.event.Event;
import com.telink.sig.mesh.event.EventListener;
import com.telink.sig.mesh.event.MeshEvent;
import com.telink.sig.mesh.event.MeshOtaApplyStatusEvent;
import com.telink.sig.mesh.event.MeshOtaEvent;
import com.telink.sig.mesh.event.MeshOtaProgressEvent;
import com.telink.sig.mesh.event.NotificationEvent;
import com.telink.sig.mesh.event.OnlineStatusEvent;
import com.telink.sig.mesh.event.OtaEvent;
import com.telink.sig.mesh.event.ScanEvent;
import com.telink.sig.mesh.light.CtlStatusNotificationParser;
import com.telink.sig.mesh.light.LeBluetooth;
import com.telink.sig.mesh.light.MeshController;
import com.telink.sig.mesh.light.MeshService;
import com.telink.sig.mesh.light.ScanParameters;
import com.telink.sig.mesh.light.ProvisionDataGenerator;
import com.telink.sig.mesh.light.parameter.AutoConnectParameters;
import com.telink.sig.mesh.light.parameter.KeyBindParameters;
import com.telink.sig.mesh.light.parameter.ProvisionParameters;
import com.telink.sig.mesh.light.parser.OnlineStatusInfoParser;
import com.telink.sig.mesh.light.UuidInfo;
import com.telink.sig.mesh.model.DeviceBindState;
import com.telink.sig.mesh.model.DeviceInfo;
import com.telink.sig.mesh.model.MeshCommand;
import com.telink.sig.mesh.model.NodeInfo;
import com.telink.sig.mesh.model.NotificationInfo;
import com.telink.sig.mesh.model.Scheduler;
import com.telink.sig.mesh.model.SigMeshModel;
import com.telink.sig.mesh.model.OtaDeviceInfo;
import com.telink.sig.mesh.util.ContextUtil;
import com.telink.sig.mesh.util.MeshUtils;
import com.telink.sig.mesh.util.Strings;
import com.telink.sig.mesh.util.TelinkLog;
import com.telink.sig.mesh.util.UnitConvert;

import static com.telink.sig.mesh.TelinkBtSigPackage.TAG;

public class TelinkBtSigNativeModule extends ReactContextBaseJavaModule implements ActivityEventListener, LifecycleEventListener, EventListener<String> {

    // Debugging
    private static final boolean D = true;

    private static final int REQUEST_CODE_LOCATION_SETTINGS = 2;
    private static final int ACCESS_COARSE_LOCATION_RESULT_CODE = 4;
    private static final int BLUETOOTH_RESULT_CODE = 5;

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

    // TAG_CMD
    private static final String TAG_CMD_SET_NODE_GROUP = "TAG_CMD_SET_NODE_GROUP";

    // Members
    private static TelinkBtSigNativeModule mThis;
    private static MeshService mService;
    private TelinkApplication mTelinkApplication;
    private BluetoothAdapter mBluetoothAdapter;
    private ReactApplicationContext mReactContext;
    protected Context mContext;
    private Handler mHandler = new Handler(Looper.getMainLooper());
    protected boolean isServiceStarted = false;
    private SigMeshModel[] models = SigMeshModel.getDefaultSubList();

    // 为了让 ./TelinkApplication.java 中的 MeshLib.StorageHelper 的
    // onMeshStorageRetrieve() 和 onMeshStorageUpdate() 两个回调函数
    // 能够正常运行，这里不得不猥琐地存在与 JS 层一样的数据，特别是较大的 devices :(
    // 不过好处是 JS 层只需保存紧凑的 nodeInfo 数组数据而有利于减少分享配置
    // 时的数据量，而且 element 的处理也在这里 NodeInfo.from() 后进行，有
    // 利于与其它没有 element 概念的 react-native-bt* 一起兼容于同一份 JS
    public byte[] mNetKey;
    public byte[] mAppKey;
    public int sno = 0; // provisioner sequence number
    public int ivIndex = 0;
    public int mMeshAddressOfApp; // localAddress in telink demo
    public List<DeviceInfo> devices = new ArrayList<>();

    private boolean hasOnlineStatusNotifyRaw;
    private boolean kickDirect; // is kicking out direct connected device?
    private int mConfigNodeResetMeshAddress;
    private String mConfigNodeResetMacAddress;
    private int mSetNodeGroupAddrType;
    private DeviceInfo mSetNodeGroupAddrDevice = null;
    private int mSetNodeGroupAddrGroupAddr;
    private int mSetNodeGroupAddrModelIndex = 0;

    // Promises
    private Promise mConfigNodePromise;
    private Promise mSetNodeGroupAddrPromise;
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
            checkSystemLocation();
        }
    }

    @Override
    public void onNewIntent(Intent intent) {
        if (D) Log.d(TAG, "On new intent");
    }


    @Override
    public void onHostResume() {
        if (D) Log.d(TAG, "Host resume");
        if (mTelinkApplication != null) {
            this.doResume();
        }
    }

    @Override
    public void onHostPause() {
        if (D) Log.d(TAG, "Host pause");
    }

    @Override
    public void onHostDestroy() {
        if (D) Log.d(TAG, "Host destroy");
        // APP 切到后台时也会调用此处，导致切回前台 Resume 时无法再正常使用本组件，因此使不在此处调用 doDestroy
        // if (mTelinkApplication != null) {
        //     this.doDestroy();
        // }
    }

    @Override
    public void onCatalystInstanceDestroy() {
        if (D) Log.d(TAG, "Catalyst instance destroyed");
        super.onCatalystInstanceDestroy();
        if (mTelinkApplication != null) {
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
        int size = devices.size();
        for(int i = 0; i < size; i++) {
            ReadableMap device = devices.getMap(i);
            DeviceInfo deviceInfo = new DeviceInfo();
            deviceInfo.meshAddress = device.getInt("meshAddress");
            deviceInfo.macAddress = device.getString("macAddress");
            deviceInfo.elementCnt = device.getInt("elementCnt");
            deviceInfo.deviceKey = readableArray2ByteArray(device.getArray("dhmKey"));

            // deviceInfo.bindState = (node.appKeys != null && node.appKeys.size() != 0)
            //         ? DeviceBindState.BOUND : DeviceBindState.UNBIND;
            // 如上 telink sdk demo 是曾经在绑定过程中向设备发送了一个或多个 appKey ，同时在手机
            // APP 中保存了这些 appKey ，而后续过程中应该不可能用某个命令从设备获取这些 appKey
            // TODO: 大部分简单用途的蓝牙 APP 只会控制一种类型蓝牙设备比如灯泡，所以本 JAVA 文件只
            // 使用了一个 mAppKey ，如果有复杂用途的比如同时控制灯泡和门锁之类的，则需要在 JS 层每个
            // node 数据结构中都记录这些 appKey ，然后在这里用 device.getString("appKey") 来
            // 判定 deviceInfo.bindState 。此时还需弄清 ./TelinkApplication.java 中
            // getMeshKey() 怎么折腾
            deviceInfo.bindState = DeviceBindState.BOUND;

            deviceInfo.nodeInfo = NodeInfo.from(readableArray2ByteArray(device.getArray("nodeInfo")));
            // TelinkLog.d("readableArray2ByteArray: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(readableArray2ByteArray(device.getArray("nodeInfo")), ":"));
            insertDevice(deviceInfo);
        }
    }

    @ReactMethod
    public void doInit(String netKey, String appKey, int meshAddressOfApp, ReadableArray devices, int provisionerSno) {
        mNetKey = Strings.stringToBytes(netKey);
        mAppKey = Strings.stringToBytes(appKey);
        mMeshAddressOfApp = meshAddressOfApp;
        sno = provisionerSno;
        setDevices(devices);
        if (mTelinkApplication == null) {
            mTelinkApplication = new TelinkApplication(getCurrentActivity().getApplication(), this);
        }

        mTelinkApplication.doInit();

        // 监听各种事件
        mTelinkApplication.addEventListener(OnlineStatusEvent.ONLINE_STATUS_NOTIFY, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_VENDOR_RESPONSE, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_DEVICE_ON_OFF_STATUS, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_DEVICE_LEVEL_STATUS, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_LIGHTNESS_STATUS_NOTIFY, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_CTL_STATUS_NOTIFY, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_TEMP_STATUS_NOTIFY, this);
        mTelinkApplication.addEventListener(CommandEvent.EVENT_TYPE_CMD_COMPLETE, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_MESH_OTA_FIRMWARE_INFO_STATUS, this);
        mTelinkApplication.addEventListener(MeshOtaEvent.EVENT_TYPE_PROGRESS_UPDATE, this);
        mTelinkApplication.addEventListener(MeshOtaEvent.EVENT_TYPE_APPLY_STATUS, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_MESH_OTA_FIRMWARE_DISTRIBUTION_STATUS, this);
        mTelinkApplication.addEventListener(OtaEvent.EVENT_TYPE_OTA_SUCCESS, this);
        mTelinkApplication.addEventListener(OtaEvent.EVENT_TYPE_OTA_FAIL, this);
        mTelinkApplication.addEventListener(OtaEvent.EVENT_TYPE_OTA_PROGRESS, this);
        // mTelinkApplication.addEventListener(DeviceEvent.STATUS_CHANGED, this);
        // mTelinkApplication.addEventListener(NotificationEvent.GET_DEVICE_STATE, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_AUTO_CONNECT_LOGIN, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_DISCONNECTED, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_KICK_OUT_CONFIRM, this);
        mTelinkApplication.addEventListener(ScanEvent.DEVICE_FOUND, this);
        mTelinkApplication.addEventListener(ScanEvent.SCAN_TIMEOUT, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_PROVISION_SUCCESS, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_PROVISION_FAIL, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_KEY_BIND_SUCCESS, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_KEY_BIND_FAIL, this);
        mTelinkApplication.addEventListener(MeshEvent.EVENT_TYPE_DEVICE_OFFLINE, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_TIME_STATUS, this);
        mTelinkApplication.addEventListener(NotificationEvent.EVENT_TYPE_SCHEDULER_STATUS, this);

        if (isServiceStarted)
            return;

        isServiceStarted = true;
        Intent bindIntent = new Intent(mContext, MeshService.class);
        mContext.bindService(bindIntent, mServiceConnection, Context.BIND_AUTO_CREATE);

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

    @ReactMethod
    public void doDestroy() {
        if (mTelinkApplication != null) {
            mHandler.removeCallbacksAndMessages(null);
            mReactContext.unregisterReceiver(mBluetoothStateReceiver);
            mTelinkApplication.doDestroy();
            mTelinkApplication = null;
        }

        if (isServiceStarted) {
            isServiceStarted = false;
            if (mService != null) {
                mContext.unbindService(mServiceConnection);
                mService = null;
            }
        }
    }

    @ReactMethod
    public void doResume() {
        Log.d(TAG, "onResume");
        //检查是否支持蓝牙设备
        if (!LeBluetooth.getInstance().isSupport(mContext)) {
            Toast.makeText(mContext, "ble not support", Toast.LENGTH_SHORT).show();
            return;
        }

        checkPermissions();
        checkSystemLocation();
    }

    private void checkPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextCompat.checkSelfPermission(getCurrentActivity(),
                    Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(getCurrentActivity(),
                        new String[]{Manifest.permission.ACCESS_COARSE_LOCATION},
                        ACCESS_COARSE_LOCATION_RESULT_CODE);
            }
            else if (ContextCompat.checkSelfPermission(getCurrentActivity(),
                    Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(getCurrentActivity(),
                        new String[]{Manifest.permission.BLUETOOTH},
                        BLUETOOTH_RESULT_CODE);
            // }
            // else if (ContextCompat.checkSelfPermission(getCurrentActivity(),
            //         Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            //     ActivityCompat.requestPermissions(getCurrentActivity(),
            //             new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE},
            //             STORAGE_RESULT_CODE);
            }
            else {
                Log.d(TAG, "checkPermissions ok");
            }
        }
    }

    private void checkSystemLocation() {
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
        if (mBluetoothAdapter != null && !mBluetoothAdapter.isEnabled()) {
            mBluetoothAdapter.enable();
        }
    }

    @ReactMethod
    public void enableSystemLocation() {
        Intent locationIntent = new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
        getCurrentActivity().startActivityForResult(locationIntent, REQUEST_CODE_LOCATION_SETTINGS);
    }

    @ReactMethod
    public void notModeAutoConnectMesh(Promise promise) {
        if (mService != null) {
            if (mService.getMode() != MeshController.MODE_AUTO_CONNECT) {
                promise.resolve(true);
            } else {
                promise.reject(new Exception("Already in mode AutoConnectMesh"));
            }
        } else {
            promise.reject(new Exception("MeshService is null"));
        }
    }

    @ReactMethod
    public void autoConnect(String networkKey) {
        int size = devices.size();
        int[] unicastAddresses = new int[size];
        for(int i = 0; i < size; i++) {
            unicastAddresses[i] = devices.get(i).meshAddress;
        }
        AutoConnectParameters connectParams = AutoConnectParameters.getDefault(unicastAddresses, mNetKey);
        connectParams.setScanMinPeriod(1000);
        mService.autoConnect(connectParams);
    }

    @ReactMethod
    public void idleMode(boolean disconnect) {
        mService.idle(disconnect);
    }

    @ReactMethod
    public void startScan(int timeoutSeconds, boolean isSingleNode) {
        ScanParameters parameters = ScanParameters.getDefault(false, isSingleNode);
        List<AdvertisingDevice> advDevices = new ArrayList<AdvertisingDevice>(mService.getAdvDevices());
        if (advDevices.size() != 0) {
            String[] excludeMacs = new String[advDevices.size()];
            for (int i = 0; i < advDevices.size(); i++) {
                excludeMacs[i] = advDevices.get(i).device.getAddress();
            }
            parameters.setExcludeMacs(excludeMacs);
        }
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
    public void sendCommand(int opcode, int meshAddress, ReadableArray value, boolean immediate) {
        MeshCommand command = MeshCommand.newInstance(0, 0, 0, meshAddress, opcode);
        command.params = readableArray2ByteArray(value);
        mService.sendMeshCommand(command);
    }

    @ReactMethod
    public void changePower(int meshAddress, int value) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_G_ONOFF_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        mService.setOnOff(elementAddr, (byte) value, true, 0, 0, (byte) 0, null);
    }

    @ReactMethod
    public void changeBrightness(int meshAddress, int value) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_LIGHTNESS_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        mService.setLum(elementAddr, value, false, 0, 0, (byte) 0, null);
    }

    @ReactMethod
    public void changeColorTemp(int meshAddress, int value) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_LIGHT_CTL_TEMP_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        mService.setTemperature100(elementAddr, value, false, 0, 0, (byte) 0, null);
    }

    @ReactMethod
    public void changeColor(int meshAddress, int hue, int saturation, int lightness) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_LIGHT_HSL_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        mService.setHSL(elementAddr, hue, saturation, lightness, false, 0, 0, (byte) 0, null);
    }

    @ReactMethod
    public void configNode(ReadableMap node, boolean isToClaim, Promise promise) {
        mConfigNodePromise = promise;

        if (isToClaim) {
            String macAddress = node.getString("macAddress");
            int address = node.getInt("meshAddress");
            TelinkLog.d("alloc address: " + address);

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

            UnprovisionedDevice targetDevice = new UnprovisionedDevice(advDevice, address);
            byte[] provisionData = ProvisionDataGenerator.getProvisionData(mNetKey, 0, (byte)0, 0, address);
            ProvisionParameters parameters = ProvisionParameters.getDefault(provisionData, targetDevice);
            mService.startProvision(parameters);
        } else {
            mConfigNodeResetMacAddress = node.getString("macAddress");
            mConfigNodeResetMeshAddress = node.getInt("meshAddress");
            kickDirect = mConfigNodeResetMacAddress.equals(mService.getCurDeviceMac());
            mService.resetNode(mConfigNodeResetMeshAddress, null);
            if (!kickDirect) {
                mHandler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        onKickOutFinish();
                    }
                }, 3 * 1000);
            }

            // startScan();
        }
    }

    private void onKickOutFinish() {
        kickDirect = false;

        if (mService == null) {
            Log.e(TAG, "xxxxxxx onKickOutFinish mService == null");
        }

        mService.removeNodeInfo(mConfigNodeResetMeshAddress);
        this.removeDeviceByMesh(mConfigNodeResetMeshAddress);
        if (mConfigNodePromise != null) {
            WritableMap params = Arguments.createMap();
            mConfigNodePromise.resolve(params);
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

    private PrivateDevice getPrivateDevice(byte[] scanRecord) {
        if (scanRecord == null) return null;
        MeshScanRecord sr = MeshScanRecord.parseFromBytes(scanRecord);
        byte[] serviceData = sr.getServiceData(ParcelUuid.fromString(UuidInfo.PROVISION_SERVICE_UUID.toString()));
        if (serviceData == null) return null;

// TODO: 认领成功时 MeshController.java 的 onMeshEvent() 中 nodeInfoData 的数据是
// 02:00:02:FF:8E:E7:40:5C:38:96:8C:1B:D1:EF:DB:5E:09:8C:05:A0:3C:00:11:02:01:00:33:30:69:00:07:00:00:00:11:01:00:00:02:00:03:00:04:00:00:FE:01:FE:00:FF:01:FF:00:10:02:10:04:10:06:10:07:10:00:13:01:13:03:13:04:13:11:02:00:00:00:00:02:00:02:10:06:13
// 可以看到里面是有 11:02:01:00 的，也就是说应该是符合 PrivateDevice.java 中的 CT(0x0211, 0x01
// 但为什么在认领刚开始调用的 getPrivateDevice() 中打印如下信息中没有 11:02:01:00 ，反而代之以 FE:E2:D6:E1 ？（这也是为何 PrivateDevice.filter() 返回的是 null 所以无法进行 fastBind 的原因）
// scanRecord: 02:01:06:03:03:27:18:15:16:27:18:FE:E2:D6:E1:A4:A2:02:3A:A3:B0:3F:2A:4C:C4:CD:AB:00:00:1E:FF:3F:2A:4C:C4:CD:AB:3F:2A:00:00:00:00:00:00:00:00:00:00:01:02:03:04:05:06:07:08:09:0A:0B:00:00
// serviceData: FE:E2:D6:E1:A4:A2:02:3A:A3:B0:3F:2A:4C:C4:CD:AB:00:00
// telink 的工程师回答说需要在设备固件代码中打开 fastbind 宏 PROVISION_FLOW_SIMPLE_EN
// 在 fastbind 模式下 service data 前两个字节是 vid(0x0211) （应该就是 NodeInfo.CompositionData
// 中的 cid），第三个字节是 pid

        return PrivateDevice.filter(serviceData);
    }

    private void onProvisionSuccess(MeshEvent event) {
        if (D) Log.d(TAG, "onProvisionSuccess");
        DeviceInfo device = event.getDeviceInfo();
        device.bindState = DeviceBindState.BINDING;

        insertDevice(device);

        // check if private mode opened
        // final boolean privateMode = SharedPreferenceHelper.isPrivateMode(this);
        final boolean privateMode = true;

        AdvertisingDevice advDevice = this.getAdvDeviceByMacAddress(device.macAddress);

        // check if device support fast bind
        boolean fastBind = false;
        if (privateMode && advDevice != null && advDevice.scanRecord != null) {
            PrivateDevice prvDevice = getPrivateDevice(advDevice.scanRecord);

            if (prvDevice != null) {
                TelinkLog.d("private device");
                NodeInfo nodeInfo = new NodeInfo();

                nodeInfo.nodeAdr = device.meshAddress;
                nodeInfo.elementCnt = device.elementCnt;
                nodeInfo.deviceKey = device.deviceKey;
                final byte[] cpsData = prvDevice.getCpsData();
                nodeInfo.cpsData = NodeInfo.CompositionData.from(cpsData);
                nodeInfo.cpsDataLen = cpsData.length;
                device.nodeInfo = nodeInfo;
                fastBind = true;
            }else {
                TelinkLog.d("private device null");
            }
        }

        // KeyBindParameters parameters = KeyBindParameters.getDefault(device,
                // mAppKey, 0, 0, fastBind);
        KeyBindParameters parameters = KeyBindParameters.getDefault(device,
                mAppKey, 0, 0, false);

        if (mService == null) {
            Log.e(TAG, "xxxxxxx onProvisionSuccess mService == null");
        }

        mService.startKeyBind(parameters);
    }

    private void onProvisionFail(MeshEvent event) {
        if (D) Log.d(TAG, "onProvisionFail");
        if (mConfigNodePromise != null) {
            mConfigNodePromise.reject(new Exception("onProvisionFail"));
        }
        mConfigNodePromise = null;
    }

// 后续如果有需要在 JS 中用 json 而非数组保存 element 等信息，可以参考如下 telink sdk demo 代码
    // mesh中的deviceInfo 转成 json 中的 node
//     public MeshStorage.Node convertDeviceInfoToNode(DeviceInfo deviceInfo, int appKeyIndex) {
//         MeshStorage.Node node = new MeshStorage.Node();
//         node.macAddress = deviceInfo.macAddress.replace(":", "").toUpperCase();
//         node.unicastAddress = String.format("%04X", deviceInfo.meshAddress);

//         if (deviceInfo.deviceKey != null) {
//             node.deviceKey = Arrays.bytesToHexString(deviceInfo.deviceKey, "").toUpperCase();
//         }
//         node.elements = new ArrayList<>(deviceInfo.elementCnt);

//         if (deviceInfo.nodeInfo != null) {
//             node.deviceKey = Arrays.bytesToHexString(deviceInfo.nodeInfo.deviceKey, "").toUpperCase();
//             node.cid = String.format("%04X", deviceInfo.nodeInfo.cpsData.cid);
//             node.pid = String.format("%04X", deviceInfo.nodeInfo.cpsData.pid);
//             node.vid = String.format("%04X", deviceInfo.nodeInfo.cpsData.vid);
//             node.crpl = String.format("%04X", deviceInfo.nodeInfo.cpsData.crpl);
//             int features = deviceInfo.nodeInfo.cpsData.features;
//             // 支持的节点默认都是打开的， 即为1， 不支持的节点 composition 数据是0， 传到 node 中为2
//             // 已关闭相关判断
//             /*node.features = new MeshStorage.Features((features & 0b0001) == 0 ? 2 : 1,
//                     (features & 0b0010) == 0 ? 2 : 1,
//                     (features & 0b0100) == 0 ? 2 : 1,
//                     (features & 0b1000) == 0 ? 2 : 1);*/
//             node.features = new MeshStorage.Features(features & 0b0001,
//                     features & 0b0010,
//                     features & 0b0100,
//                     features & 0b1000);

//             PublishModel publishModel = deviceInfo.getPublishModel();

//             if (deviceInfo.nodeInfo.cpsData.elements != null) {
//                 List<NodeInfo.Element> elements = deviceInfo.nodeInfo.cpsData.elements;
//                 MeshStorage.Element element;
//                 for (int i = 0; i < elements.size(); i++) {
//                     NodeInfo.Element ele = elements.get(i);
//                     element = new MeshStorage.Element();
//                     element.index = i;
//                     element.location = String.format("%04X", ele.location);

//                     element.models = new ArrayList<>();
//                     MeshStorage.Model model;

//                     if (ele.sigNum != 0 && ele.sigModels != null) {
//                         for (int modelId : ele.sigModels) {
//                             model = new MeshStorage.Model();
//                             model.modelId = String.format("%04X", modelId);
//                             model.bind = new ArrayList<>();
//                             model.bind.add(appKeyIndex);

//                             model.subscribe = new ArrayList<>();
//                             if (inDefaultSubModel(modelId)) {
//                                 for (int subAdr : deviceInfo.subList) {
//                                     model.subscribe.add(String.format("%04X", subAdr));
//                                 }
//                             }

//                             if (publishModel != null && publishModel.modelId == modelId) {
//                                 final MeshStorage.Publish publish = new MeshStorage.Publish();
//                                 publish.address = String.format("%04X", publishModel.address);
//                                 publish.index = 0;

//                                 publish.ttl = publishModel.ttl;
//                                 publish.period = publishModel.period;
//                                 publish.credentials = publishModel.credential;
//                                 publish.retransmit = new MeshStorage.Transmit(publishModel.getTransmitCount()
//                                         , publishModel.getTransmitInterval());

//                                 model.publish = publish;
//                             }

//                             element.models.add(model);
//                         }
//                     }

//                     if (ele.vendorNum != 0 && ele.vendorModels != null) {

//                         for (int modelId : ele.vendorModels) {
//                             model = new MeshStorage.Model();
//                             model.modelId = String.format("%08X", modelId);
//                             model.bind = new ArrayList<>();
//                             model.bind.add(appKeyIndex);
//                             element.models.add(model);
//                         }
//                     }
//                     node.elements.add(element);
//                 }
//             }
//         } else {

//             // 创建空的element对象， 用于同步element个数
//             for (int i = 0; i < deviceInfo.elementCnt; i++) {
//                 node.elements.add(new MeshStorage.Element());
//             }
//         }
//         node.netKeys = new ArrayList<>();
//         node.netKeys.add(new MeshStorage.NodeKey(0, false));
//         node.configComplete = true;
//         node.name = "Common Node";

//         //目前根据appKey列表是否存在判断设备是否绑定成功
//         if (deviceInfo.bindState == DeviceBindState.BOUND) {
//             node.appKeys = new ArrayList<>();
//             node.appKeys.add(new MeshStorage.NodeKey(0, false));
//         }

//         node.security = MeshSecurity.High.getDesc();

//         if (deviceInfo.schedulers != null) {
//             node.schedulers = new ArrayList<>();
//             for (Scheduler deviceScheduler : deviceInfo.schedulers) {
//                 node.schedulers.add(MeshStorage.NodeScheduler.fromScheduler(deviceScheduler));
//             }
//         }

//         return node;
//     }

    private void onUpdateMeshCompleted(MeshEvent event) {
        DeviceInfo deviceInfo = event.getDeviceInfo();
        if (D) Log.d(TAG, "onUpdateMeshCompleted");
        DeviceInfo local = getDeviceByMacAddress(deviceInfo.macAddress);
        if (local == null) {
            if (D) Log.d(TAG, "can't find device in devices of native");
            mConfigNodePromise.reject(new Exception("can't find device in devices of native"));
        };

        local.bindState = DeviceBindState.BOUND;
        local.nodeInfo = deviceInfo.nodeInfo;

        if (mConfigNodePromise != null) {
            WritableMap params = Arguments.createMap();

            // 来自 MeshController.java 中 type.equals(MeshEvent.EVENT_TYPE_KEY_BIND_SUCCESS) 处
            WritableArray nodeInfo = Arguments.createArray();
            byte[] nodeInfoArray = deviceInfo.nodeInfo.toVCNodeInfo();
            // TelinkLog.d("nodeInfoArray: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(nodeInfoArray, ":"));
            int nodeInfoWithoutCpsDataLength = 22;
            int nodeInfoValidLength = nodeInfoWithoutCpsDataLength + deviceInfo.nodeInfo.cpsDataLen;
            for (int i = 0; i < nodeInfoValidLength; i++) {
                nodeInfo.pushInt(nodeInfoArray[i]);
            }
            params.putArray("nodeInfo", nodeInfo);
            params.putInt("elementCnt", deviceInfo.elementCnt);
            params.putInt("type", deviceInfo.nodeInfo.cpsData.pid);
            WritableArray array = Arguments.createArray();
            byte[] dhmKey = deviceInfo.deviceKey;
            // TelinkLog.d("dhmKey: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(dhmKey, ":"));
            for (int i = 0; i < dhmKey.length; i++) {
                array.pushInt(dhmKey[i]);
            }
            params.putArray("dhmKey", array);

            mConfigNodePromise.resolve(params);
        }
        mConfigNodePromise = null;
    }

    private void onUpdateMeshFailure(MeshEvent event) {
        DeviceInfo deviceInfo = event.getDeviceInfo();
        if (D) Log.d(TAG, "onUpdateMeshFailure");
        if (mConfigNodePromise != null) {
            mConfigNodePromise.reject(new Exception("onUpdateMeshFailure"));
        }
        mConfigNodePromise = null;
    }

    private void onUpdateMeshFailure() {
        if (D) Log.d(TAG, "onUpdateMeshFailure");
        if (mConfigNodePromise != null) {
            mConfigNodePromise.reject(new Exception("onUpdateMeshFailure"));
        }
        mConfigNodePromise = null;
    }

    // private void onNError(final DeviceEvent event) {
    //     TelinkLightService.Instance().idleMode(true);
    //     TelinkLog.d("DeviceScanningActivity#onNError");
    //     sendEvent(DEVICE_STATUS_ERROR_N);
    // }

    // private void onDeviceStatusChanged(DeviceEvent event) {
    //     DeviceInfo deviceInfo = event.getArgs();
    //     switch (deviceInfo.status) {
    //         case LightAdapter.STATUS_CONNECTING:
    //             break;
    //         case LightAdapter.STATUS_LOGOUT:
    //             sendEvent(DEVICE_STATUS_LOGOUT);
    //             break;
    //         case LightAdapter.STATUS_UPDATE_MESH_COMPLETED:
    //             onUpdateMeshCompleted(deviceInfo);
    //             break;
    //         case LightAdapter.STATUS_UPDATE_MESH_FAILURE:
    //             onUpdateMeshFailure(deviceInfo);
    //             break;
    //         case LightAdapter.STATUS_ERROR_N:
    //             onNError(event);
    //             break;
    //         case LightAdapter.STATUS_OTA_PROGRESS:
    //             OtaDeviceInfo otaDeviceInfo = (OtaDeviceInfo) event.getArgs();
    //             WritableMap map = Arguments.createMap();
    //             map.putInt("otaMasterProgress", otaDeviceInfo.progress);
    //             sendEvent(DEVICE_STATUS_OTA_MASTER_PROGRESS, map);
    //             break;
    //         case LightAdapter.STATUS_OTA_COMPLETED:
    //             TelinkLog.i("ota master complete");
    //             sendEvent(DEVICE_STATUS_OTA_MASTER_COMPLETE);
    //             break;
    //         case LightAdapter.STATUS_OTA_FAILURE:
    //             TelinkLog.i("ota master fail");
    //             sendEvent(DEVICE_STATUS_OTA_MASTER_FAIL);
    //             break;
    //         default:
    //             break;
    //     }
    // }

    /**
     * 处理{@link OnlineStatusEvent#ONLINE_STATUS_NOTIFY}事件
     */
    private synchronized void onOnlineStatusNotify(OnlineStatusEvent event) {
        TelinkLog.i("MainActivity#onOnlineStatusNotify#Thread ID : " + Thread.currentThread().getId());
        List<OnlineStatusInfoParser.OnlineStatusInfo> infoList = OnlineStatusInfoParser.create().parseInfo(event.rawData);
        if (infoList != null) {
            WritableArray params = Arguments.createArray();
            for (OnlineStatusInfoParser.OnlineStatusInfo onlineStatusInfo : infoList) {
                if (onlineStatusInfo.status == null || onlineStatusInfo.status.length < 3) break;
                WritableMap map = Arguments.createMap();
                map.putInt("meshAddress", onlineStatusInfo.address);
                map.putInt("brightness", onlineStatusInfo.status[0]);
                map.putInt("colorTemp", onlineStatusInfo.status[1]);
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

    private synchronized void onMeshOffline(MeshEvent event) {
        onUpdateMeshFailure();
        sendEvent(MESH_OFFLINE);
    }

    private synchronized void onVendorResponse(NotificationEvent event) {
// Log.d(TAG, "onVendorResponse: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(event.getRawData(), ":"));
// Log.d(TAG, "onVendorResponse: " + event.getNotificationInfo().toString());
// 上面两个测试语句会得到如下信息
// onVendorResponse: F0:08:01:00:FF:00:E3:11:02:00
// onVendorResponse: NotificationInfo{srcAdr=0001, destAdr=00FF, opcode=0211E3, isVendor=true, params=00}

        NotificationInfo notificationInfo = event.getNotificationInfo();

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationInfo.srcAdr);
        params.putInt("opcode", notificationInfo.opcode);
        params.putArray("params", byteArray2WritableArray(notificationInfo.params));
        sendEvent(NOTIFICATION_VENDOR_RESPONSE, params);
    }

    private synchronized void onGetOnOffNotify(NotificationEvent event) {
// Log.d(TAG, "onGetOnOffNotify: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(event.getRawData(), ":"));
// Log.d(TAG, "onGetOnOffNotify: " + event.getNotificationInfo().toString());
// 上面两个测试语句会得到如下信息
// onGetOnOffNotify: F0:07:02:00:01:00:82:04:00
// onGetOnOffNotify: NotificationInfo{srcAdr=0002, destAdr=0001, opcode=000482, isVendor=false, params=00}

        NotificationInfo notificationInfo = event.getNotificationInfo();

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationInfo.srcAdr);
        params.putInt("onOff", notificationInfo.params.length == 1 ? notificationInfo.params[0] : notificationInfo.params[1]);
        sendEvent(NOTIFICATION_DATA_GET_ON_OFF, params);
    }

    private synchronized void onGetLevelNotify(NotificationEvent event) {
// Log.d(TAG, "onGetLevelNotify: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(event.getRawData(), ":"));
// Log.d(TAG, "onGetLevelNotify: " + event.getNotificationInfo().toString());
// 上面两个测试语句会得到如下信息
// onGetLevelNotify: F0:08:02:00:01:00:82:08:FF:7F
// onGetLevelNotify: NotificationInfo{srcAdr=0002, destAdr=0001, opcode=000882, isVendor=false, params=FF:7F}
// 本函数在此次测试中之所以会被自动调用 2 次，是因为该 device 中有两个 element ，所以还会得到如下第 2 次信息
// onGetLevelNotify: F0:08:03:00:01:00:82:08:FF:7F
// onGetLevelNotify: NotificationInfo{srcAdr=0003, destAdr=0001, opcode=000882, isVendor=false, params=FF:7F}

        NotificationInfo notificationInfo = event.getNotificationInfo();
        short status;
        // 是否带有目标值
        if (notificationInfo.params.length >= 4) {
            status = (short) ((notificationInfo.params[2] & 0xFF) | ((notificationInfo.params[3] & 0xFF) << 8));
        } else {
            status = (short) ((notificationInfo.params[0] & 0xFF) | ((notificationInfo.params[1] & 0xFF) << 8));
        }

        byte tarVal = mTelinkApplication.getMeshLib().level2Lum(status); // 测试得：上面 status 为 0x7FFF 时， level2Lum 会转换为 100

        WritableMap params = Arguments.createMap();
        // 如下这么折腾 element ，而且还可能会调用多次 sendEvent ，则还不如直接使用 onGetCtlNotify 更简洁
        // TelinkLog.d("lightness status val: " + tarVal + " -- " + status);
        for (DeviceInfo device : devices) {
            if (device.nodeInfo == null) {
                continue;
            }
            int deviceAdr = -1;
            int elementAddr = device.meshAddress;
            for (NodeInfo.Element element : device.nodeInfo.cpsData.elements) {
                if (elementAddr == notificationInfo.srcAdr) {
                    if (element.containModel(SigMeshModel.SIG_MD_LIGHTNESS_S.modelId)) {
                        params.putInt("brightness", tarVal);
                        deviceAdr = device.meshAddress;
                        break;
                    } else if (element.containModel(SigMeshModel.SIG_MD_LIGHT_CTL_TEMP_S.modelId)) {
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

    private synchronized void onGetLightnessNotify(NotificationEvent event) {
// Log.d(TAG, "onGetLightnessNotify: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(event.getRawData(), ":"));
// Log.d(TAG, "onGetLightnessNotify: " + event.getNotificationInfo().toString());
// 上面两个测试语句会得到如下信息
// onGetLightnessNotify: F0:08:02:00:01:00:82:4E:FF:FF
// onGetLightnessNotify: NotificationInfo{srcAdr=0002, destAdr=0001, opcode=004E82, isVendor=false, params=FF:FF}

        NotificationInfo notificationInfo = event.getNotificationInfo();
        int liStatus;
        if (notificationInfo.params.length >= 4) {
            liStatus = (notificationInfo.params[2] & 0xFF) | ((notificationInfo.params[3] & 0xFF) << 8);
        } else {
            liStatus = (notificationInfo.params[0] & 0xFF) | ((notificationInfo.params[1] & 0xFF) << 8);
        }

        int lightness = mTelinkApplication.getMeshLib().lightness2Lum(liStatus); // 测试得：上面 liStatus 为 0xFFFF 时， lightness2Lum 会转换为 100

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationInfo.srcAdr);
        params.putInt("brightness", lightness);
        sendEvent(NOTIFICATION_DATA_GET_LIGHTNESS, params);
    }

    private synchronized void onGetCtlNotify(NotificationEvent event) {
// Log.d(TAG, "onGetCtlNotify: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(event.getRawData(), ":"));
// Log.d(TAG, "onGetCtlNotify: " + event.getNotificationInfo().toString());
// 上面两个测试语句会得到如下信息
// onGetCtlNotify: F0:0A:02:00:01:00:82:60:FF:FF:20:4E
// onGetCtlNotify: NotificationInfo{srcAdr=0002, destAdr=0001, opcode=006082, isVendor=false, params=FF:FF:20:4E}

        NotificationInfo notificationInfo = event.getNotificationInfo();
        CtlStatusNotificationParser ctlParser = CtlStatusNotificationParser.create();
        CtlStatusNotificationParser.CtlInfo ctlInfo = ctlParser.parse(notificationInfo.params);
        if (ctlInfo == null) return;

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationInfo.srcAdr);
        params.putInt("brightness", ctlInfo.lum);
        params.putInt("colorTemp", ctlInfo.temp);
        sendEvent(NOTIFICATION_DATA_GET_CTL, params);
    }

    private synchronized void onGetTempNotify(NotificationEvent event) {
// Log.d(TAG, "onGetTempNotify: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(event.getRawData(), ":"));
// Log.d(TAG, "onGetTempNotify: " + event.getNotificationInfo().toString());
// 上面两个测试语句会得到如下信息
// onGetTempNotify: F0:0A:03:00:01:00:82:66:20:4E:00:00
// onGetTempNotify: NotificationInfo{srcAdr=0003, destAdr=0001, opcode=006682, isVendor=false, params=20:4E:00:00}

        NotificationInfo notificationInfo = event.getNotificationInfo();
        int tempStatus = (notificationInfo.params[0] & 0xFF) | ((notificationInfo.params[1] & 0xFF) << 8);
        int colorTemp = mTelinkApplication.getMeshLib().tempToTemp100(tempStatus); // 测试得：上面 tempStatus 为 0x4E20 时， tempToTemp100 会转换为 100

        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationInfo.srcAdr);
        params.putInt("colorTemp", colorTemp);
        sendEvent(NOTIFICATION_DATA_GET_TEMP, params);
    }

    // private synchronized void onGetDeviceState(NotificationEvent event) {
    //     byte[] data = event.getArgs().params;
    //     WritableMap params = Arguments.createMap();
    //     params.putInt("meshAddress", event.getArgs().src);
    //     switch (data[0]) {
    //         case NotificationEvent.DATA_GET_VERSION:
    //             params.putString("version", Strings.bytesToString(Arrays.copyOfRange(data, 1, 5)));
    //             sendEvent(NOTIFICATION_DATA_GET_VERSION, params);
    //             break;
    //         case NotificationEvent.DATA_GET_MESH_OTA_PROGRESS:
    //             params.putInt("OtaSlaveProgress", (int) data[1]);
    //             sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_PROGRESS, params);
    //             break;
    //         case NotificationEvent.DATA_GET_OTA_STATE:
    //             int otaState = data[1];
    //             switch (otaState) {
    //                 case NotificationEvent.OTA_STATE_IDLE:
    //                     TelinkLog.i("otaState: idle");
    //                     params.putString("otaState", "idle");
    //                     break;
    //                 case NotificationEvent.OTA_STATE_SLAVE:
    //                     TelinkLog.i("otaState: slave");
    //                     params.putString("otaState", "slave");
    //                     break;
    //                 case NotificationEvent.OTA_STATE_MASTER:
    //                     TelinkLog.i("otaState: master");
    //                     params.putString("otaState", "master");
    //                     break;
    //                 case NotificationEvent.OTA_STATE_ONLY_RELAY:
    //                     TelinkLog.i("otaState: onlyRelay");
    //                     params.putString("otaState", "onlyRelay");
    //                     break;
    //                 case NotificationEvent.OTA_STATE_COMPLETE:
    //                     TelinkLog.i("otaState: complete");
    //                     params.putString("otaState", "complete");
    //                     break;
    //                 default:
    //                     break;
    //             }
    //             sendEvent(NOTIFICATION_DATA_GET_OTA_STATE, params);
    //             break;
    //         case NotificationEvent.DATA_SET_OTA_MODE_NOTIFY:
    //             if (data[1] == 0) {
    //                 TelinkLog.i("setOtaModeRes: ok");
    //                 params.putString("setOtaModeRes", "ok");
    //             } else {
    //                 TelinkLog.i("setOtaModeRes: err");
    //                 params.putString("setOtaModeRes", "err");
    //             }
    //             sendEvent(NOTIFICATION_DATA_SET_OTA_MODE_RES, params);
    //             break;
    //         default:
    //             break;
    //     }
    // }

    @ReactMethod
    public void setNodeGroupAddr(boolean toDel, int meshAddress, int groupAddress, Promise promise) {
        mSetNodeGroupAddrType = toDel ? 1 : 0;
        mSetNodeGroupAddrDevice = this.getDeviceByMeshAddress(meshAddress);
        if (mSetNodeGroupAddrDevice == null) {
            promise.reject(new Exception("setSubscription device null"));
            mSetNodeGroupAddrDevice = null;
            return;
        }
        mSetNodeGroupAddrGroupAddr = groupAddress;
        mSetNodeGroupAddrPromise = promise;
        mSetNodeGroupAddrModelIndex = 0;
        setNextModel();
    }

    private void setNextModel() {
        if (mSetNodeGroupAddrModelIndex > models.length - 1) {
            if (mSetNodeGroupAddrPromise != null) {
                WritableArray params = Arguments.createArray();
                mSetNodeGroupAddrPromise.resolve(params);
            }
            mSetNodeGroupAddrDevice = null;
            mSetNodeGroupAddrPromise = null;
        } else {
            final int elementAddr = mSetNodeGroupAddrDevice.getTargetEleAdr(models[mSetNodeGroupAddrModelIndex].modelId);
            if (elementAddr == -1) {
                mSetNodeGroupAddrModelIndex++;
                setNextModel();
                return;
            }
            if (!mService.setSubscription(mSetNodeGroupAddrType, mSetNodeGroupAddrDevice.meshAddress, elementAddr, mSetNodeGroupAddrGroupAddr, models[mSetNodeGroupAddrModelIndex].modelId, true, TAG_CMD_SET_NODE_GROUP)) {
                if (mSetNodeGroupAddrPromise != null) {
                    mSetNodeGroupAddrPromise.reject(new Exception("setSubscription return false"));
                }
                mSetNodeGroupAddrDevice = null;
                mSetNodeGroupAddrPromise = null;
            }
        }
    }

    private synchronized void onCmdComplete(CommandEvent event) {
        MeshCommand meshCommand = event.getMeshCommand();
        if (meshCommand != null) {
            if (TAG_CMD_SET_NODE_GROUP.equals(meshCommand.tag)) {
                if (meshCommand.rspCnt >= 1) {
                    mSetNodeGroupAddrModelIndex++;
                    setNextModel();
                } else {
                    if (mSetNodeGroupAddrPromise != null) {
                        mSetNodeGroupAddrPromise.reject(new Exception("setSubscription rspCnt < 1"));
                    }
                    mSetNodeGroupAddrDevice = null;
                    mSetNodeGroupAddrPromise = null;
                    TelinkLog.e("set group sub error");
                }
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
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_TIME_S.modelId);
            if (elementAddr == -1) {
                elementAddr = meshAddress;
            }
        }
        mService.setTime(elementAddr, 0, time, offset, null);
    }

    @ReactMethod
    public void getTime(int meshAddress, int relayTimes, Promise promise) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_TIME_S.modelId);
            if (elementAddr == -1) {
                promise.reject(new Exception("GetTime no time model in device elements"));
                return;
            }
        } else {
            promise.reject(new Exception("GetTime device null"));
            return;
        }

        mGetTimePromise = promise;
        mService.getTime(meshAddress, 0, null);
    }

    private synchronized void onGetTimeNotify(NotificationEvent event) {
        byte[] data = event.getRawData();
// typedef struct{
//     u32 TAI_sec;     // 32bit is enough for 2000 ~ 2099 year
//     u8 TAI_sec_rsv;
//     u8 sub_sec;
//     u8 uncertainty;
//     u16 time_auth       :1;
//     u16 TAI_UTC_delta   :15;
//     u8 zone_offset;
// }time_status_t;
        TelinkLog.d("time: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(data, ":"));

        int taiSec = MeshUtils.bytes2Integer(Arrays.copyOfRange(data, 7, 11), ByteOrder.BIG_ENDIAN);
        TelinkLog.d("taiSec: " + taiSec);
        long sec = (long)taiSec + MeshUtils.TAI_OFFSET_SECOND;
        Calendar notificationInfo = Calendar.getInstance();
        notificationInfo.setTimeInMillis(sec * 1000);

        if (notificationInfo == null) {
            mGetTimePromise.reject(new Exception("GetTime return null"));
            return;
        }

        if (mGetTimePromise != null) {
            WritableMap params = Arguments.createMap();
            params.putString("time", notificationInfo.getTime().toString());
            mGetTimePromise.resolve(params);
        }
        mGetTimePromise = null;
    }

    @ReactMethod
    public void getAlarm(int meshAddress, int relayTimes, int alarmId, Promise promise) {
        int elementAddr = meshAddress;
        DeviceInfo device = this.getDeviceByMeshAddress(meshAddress);
        if (device != null) {
            elementAddr = device.getTargetEleAdr(SigMeshModel.SIG_MD_SCHED_S.modelId);
            if (elementAddr == -1) {
                promise.reject(new Exception("getAlarm no sched model in device elements"));
                return;
            }
        } else {
            promise.reject(new Exception("getAlarm device null"));
            return;
        }

        mGetAlarmPromise = promise;
        mService.getSchedulerAction(meshAddress, 0, alarmId, null);
    }

    private synchronized void onGetAlarmNotify(NotificationEvent event) {
        byte[] data = event.getRawData();
        //        F0:13:02:00:01:00:5F: 20:F9:FF:8C:FB:FE:1F:00:00:00: 00:00:00:00
        TelinkLog.d("alarm: " + com.telink.sig.mesh.util.Arrays.bytesToHexString(data, ":"));

        Scheduler scheduler = Scheduler.fromBytes(Arrays.copyOfRange(data, 7, 17));
        // Scheduler scheduler = Scheduler.fromBytes([
        //     data[7],
        //     data[8],
        //     data[9],
        //     data[10],
        //     data[11],
        //     data[12],
        //     data[13],
        //     data[14],
        //     data[15],
        //     data[16]
        // ]);
        if (scheduler == null) {
            mGetAlarmPromise.reject(new Exception("GetAlarm return null"));
            return;
        }

        Scheduler.Register register = scheduler.getRegister();
        if (mGetAlarmPromise != null) {
            WritableMap params = Arguments.createMap();
            params.putInt("alarmId", scheduler.getIndex());
            // params.putInt("type", notificationInfo.type.getValue());
            // params.putInt("status", notificationInfo.status.getValue());
            params.putInt("year", (int)register.getYear());
            params.putInt("month", (int)register.getMonth());
            // params.putInt("dayOrWeek", notificationInfo.getDayOrWeek());
            params.putInt("day", (int)register.getDay());
            params.putInt("hour", (int)register.getHour());
            params.putInt("minute", (int)register.getMinute());
            params.putInt("second", (int)register.getSecond());
            params.putInt("week", (int)register.getWeek());
            params.putInt("action", (int)register.getAction());
            params.putInt("transTime", (int)register.getTransTime());
            params.putInt("sceneId", register.getSceneId());
            mGetAlarmPromise.resolve(params);
        }
        mGetAlarmPromise = null;
    }

    private synchronized void onGetFirmwareInfo(NotificationEvent event) {
        /*
        u16 cid，  (vendor id)
        u16 pid,   (设备类型)
        u16 vid    (版本id)
         */
        final NotificationInfo notificationInfo = event.getNotificationInfo();
        if (notificationInfo.params.length < 6) {
            return;
        }
        WritableMap params = Arguments.createMap();
        params.putInt("meshAddress", notificationInfo.srcAdr);
        params.putString("version", Strings.bytesToString(Arrays.copyOfRange(notificationInfo.params, 4, 6)));
        sendEvent(NOTIFICATION_DATA_GET_VERSION, params);
    }

    @ReactMethod
    public void startMeshOTA(ReadableArray meshAddresses, ReadableArray firmware) {
        mService.startMeshOTA(readableArray2IntArray(meshAddresses), readableArray2ByteArray(firmware));
    }

    @ReactMethod
    public void pauseMeshOta() {
        mTelinkApplication.getMeshLib().pauseMeshOta();
    }

    @ReactMethod
    public void continueMeshOta() {
        mTelinkApplication.getMeshLib().continueMeshOta();
    }

    @ReactMethod
    public void stopMeshOTA(String tag) {
        mService.stopMeshOTA(tag);
    }

    private synchronized void onGetMeshOtaProgress(MeshOtaProgressEvent event) {
        WritableMap params = Arguments.createMap();
        params.putInt("OtaSlaveProgress", event.getProgress());
        sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_PROGRESS, params);
    }

    private synchronized void onGetMeshOtaApplyStatus(MeshOtaApplyStatusEvent event) {
        byte[] status = event.getStatus();
        if (status != null && status.length > 0) {
            WritableMap params = Arguments.createMap();
            params.putInt("meshAddress", event.getSrc());
            params.putString("status", status[0] == 0 ? "success" : "failure");
            sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_APPLY_STATUS, params);
        }
    }

    private synchronized void onGetMeshOtaFirmwareDistributionStatus(NotificationEvent event) {
        final NotificationInfo notificationInfo = event.getNotificationInfo();
        if (notificationInfo.params != null && notificationInfo.params.length > 0) {
            WritableMap params = Arguments.createMap();
            params.putInt("meshAddress", notificationInfo.srcAdr);
            if (notificationInfo.params[0] == 1) {
                params.putString("status", "start");
            } else if (notificationInfo.params[0] == 0) {
                params.putString("status", "stop");
            } else {
                params.putString("status", "error");
            }
            sendEvent(NOTIFICATION_DATA_GET_MESH_OTA_FIRMWARE_DISTRIBUTION_STATUS, params);
        }
    }

    @ReactMethod
    public void startOta(String mac, ReadableArray firmware, Promise promise) {
        mStartOtaPromise = promise;
        mService.startOta(mac, readableArray2ByteArray(firmware));
    }

    private synchronized void onGetOtaProgress(OtaEvent event) {
        OtaDeviceInfo otaDeviceInfo = event.getDeviceInfo();
        WritableMap params = Arguments.createMap();
        params.putInt("otaMasterProgress", otaDeviceInfo.progress);
        sendEvent(DEVICE_STATUS_OTA_MASTER_PROGRESS, params);
    }

    private void onLeScan(ScanEvent event) {
        AdvertisingDevice advDevice = event.advertisingDevice;
        BluetoothDevice btDevice = advDevice.device;
        // TelinkLog.w("name" + btDevice.getName());                       // null
        // TelinkLog.w("addr" + btDevice.getAddress());                    // AB:CD:4F:03:CA:80
        // TelinkLog.w("type" + btDevice.getType());                       // 0
        // TelinkLog.w("uuid" + btDevice.getUuids());                      // null
        // TelinkLog.w("desc" + btDevice.describeContents());              // 0
        // TelinkLog.w("bond" + btDevice.getBondState());                  // 10
        // TelinkLog.w("clas" + btDevice.getBluetoothClass().toString());  // 0
        // TelinkLog.w("hash" + btDevice.hashCode());                      // 1098112549

        WritableMap params = Arguments.createMap();
        params.putString("macAddress", btDevice.getAddress());
        // params.putString("deviceName", btDevice.getName());
        // params.putString("meshName", btDevice.describeContents());
        // params.putInt("meshAddress", deviceInfo.meshAddress);
        // params.putInt("meshUUID", btDevice.getUuids());
        // params.putInt("productUUID", btDevice.getType());
        // params.putInt("status", btDevice.getBondState());
        sendEvent(LE_SCAN, params);
    }

    /**
     * JS 层导入（别人分享来）的配置后，可以调用此函数
     */
    @ReactMethod
    public void replaceMeshSetting() {
        mService.idle(true);
        byte[] pvData = ProvisionDataGenerator.getProvisionData(mNetKey, 0, (byte)0, 0, mMeshAddressOfApp);
        mService.meshProvisionParSetDir(pvData, pvData.length);
        mService.setLocalAddress(mMeshAddressOfApp);
        List<byte[]> nodeList = new ArrayList<>();
        for (DeviceInfo node : devices) {
            nodeList.add(node.nodeInfo.toVCNodeInfo());
        }
        byte[][] nodeData = nodeList.toArray(new byte[][]{});
        mService.reattachNodes(nodeData);
        mService.resetAppKey(0, 0, mAppKey);
    }

    private ServiceConnection mServiceConnection = new ServiceConnection() {
        public void onServiceConnected(ComponentName className, IBinder rawBinder) {
            mService = MeshService.getInstance();
            if (mService != null) {
                mService.startMeshController(mTelinkApplication.getMeshLib());
                byte[] pvData = ProvisionDataGenerator.getProvisionData(mNetKey, 0, (byte)0, 0, mMeshAddressOfApp);
                mService.meshProvisionParSetDir(pvData, pvData.length);
                mService.setLocalAddress(mMeshAddressOfApp);
                mService.resetAppKey(0, 0, mAppKey);

                sendEvent(SERVICE_CONNECTED);
            }
        }

        public void onServiceDisconnected(ComponentName classname) {
            Log.d(TAG, "xxxxxxx onServiceDisconnected mService = null");

            mService = null;
            sendEvent(SERVICE_DISCONNECTED);
        }
    };

    /**
     * 事件处理方法
     *
     * @param event
     */
    @Override
    public void performed(Event<String> event) {
        switch (event.getType()) {
            case OnlineStatusEvent.ONLINE_STATUS_NOTIFY:
                this.onOnlineStatusNotify((OnlineStatusEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_VENDOR_RESPONSE:
                this.onVendorResponse((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_DEVICE_ON_OFF_STATUS:
                this.onGetOnOffNotify((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_DEVICE_LEVEL_STATUS:
                this.onGetLevelNotify((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_LIGHTNESS_STATUS_NOTIFY:
                this.onGetLightnessNotify((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_CTL_STATUS_NOTIFY:
                this.onGetCtlNotify((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_TEMP_STATUS_NOTIFY:
                this.onGetTempNotify((NotificationEvent) event);
                break;
            case CommandEvent.EVENT_TYPE_CMD_COMPLETE:
                this.onCmdComplete((CommandEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_TIME_STATUS:
                this.onGetTimeNotify((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_SCHEDULER_STATUS:
                this.onGetAlarmNotify((NotificationEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_MESH_OTA_FIRMWARE_INFO_STATUS:
                this.onGetFirmwareInfo((NotificationEvent) event);
                break;
            case MeshOtaEvent.EVENT_TYPE_PROGRESS_UPDATE:
                this.onGetMeshOtaProgress((MeshOtaProgressEvent) event);
                break;
            case MeshOtaEvent.EVENT_TYPE_APPLY_STATUS:
                this.onGetMeshOtaApplyStatus((MeshOtaApplyStatusEvent) event);
                break;
            case NotificationEvent.EVENT_TYPE_MESH_OTA_FIRMWARE_DISTRIBUTION_STATUS:
                this.onGetMeshOtaFirmwareDistributionStatus((NotificationEvent) event);
                break;
            case OtaEvent.EVENT_TYPE_OTA_SUCCESS:
                // mService.idle(false);
                if (mStartOtaPromise != null) {
                    mStartOtaPromise.resolve(true);
                }
                mStartOtaPromise = null;
                break;
            case OtaEvent.EVENT_TYPE_OTA_FAIL:
                // mService.idle(true);
                if (mStartOtaPromise != null) {
                    mStartOtaPromise.reject(new Exception("OTA_FAIL"));
                }
                mStartOtaPromise = null;
                break;
            case OtaEvent.EVENT_TYPE_OTA_PROGRESS:
                this.onGetOtaProgress((OtaEvent) event);
                break;
            // case DeviceEvent.STATUS_CHANGED:
            //     this.onDeviceStatusChanged((DeviceEvent) event);
            //     break;
            // case NotificationEvent.GET_DEVICE_STATE:
            //     onGetDeviceState((NotificationEvent) event);
            //     break;
            case MeshEvent.EVENT_TYPE_AUTO_CONNECT_LOGIN:
                // 这里在 login 后自动进行“设置时间信息”的操作，
                // 其实本来这些代码是当初移植时不知道具体用途而暂时遗留下来的，
                // 按说现在“设置时间信息”放在 JavaScript 代码中进行后这些代码就没有必要存在了，
                // 但是现在这些代码起到了一个额外的作用——
                // 在连接成功后能够让蓝牙灯爆闪一下以提醒用户连接成功，
                // 所以仍然保留了这些代码。
                // mHandler.postDelayed(new Runnable() {
                //     @Override
                //     public void run() {
                //         TelinkLightService.Instance().sendCommandNoResponse((byte) 0xE4, 0xFFFF, new byte[]{});
                //     }
                // }, 3 * 1000);

                // get all device on off status when auto connect success
                hasOnlineStatusNotifyRaw = MeshService.getInstance().getOnlineStatus();
                saveOrUpdateJS();

                // 以下代码已移动到 index.native.js 的 postConnected() 中，这样就不用在 ios 代码中也再重写一遍了
                // if (!hasOnlineStatusNotifyRaw) {
                //     // 如果后续从蓝牙设备固件代码中得知 telink 也实现了（应该实现了） sig mesh 协议中
                //     // model 之间关联功能，放到这里就是实现了亮度 modle 如果亮度为 <= 0 的话就会关联
                //     // 开关灯 model 为关灯状态，则此处可以不再使用 getOnOff 而只用 getCtl 等代替
                //     mService.getOnOff(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_DEVICE_ON_OFF_STATUS

                //     // 测试得：如果紧接着上面 getOnOff 后立即进行其它 get ，则只会触发 getOnOff 对应的 EVENT，因此需要延迟进行
                //     mHandler.postDelayed(new Runnable() {
                //         @Override
                //         public void run() {
                //             // 因为此处只会返回第一个 get 函数的结果，所以那些注释掉的 get 函数仅用于测试
                //             // mService.getLevel(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_DEVICE_LEVEL_STATUS
                //             // mService.getLightness(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_LIGHTNESS_STATUS_NOTIFY

                //             // 如 onGetLevelNotify() 中注释所说，使用 onGetCtlNotify() 更简洁
                //             mService.getCtl(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_CTL_STATUS_NOTIFY

                //             // mService.getTemperature(0xFFFF, 0, null); // 用于触发 EVENT_TYPE_TEMP_STATUS_NOTIFY
                //         }
                //     }, 1 * 1000); // 测试得：当延时为 100 时无法触发对应的 EVENT ，而 500 是可以的，保险起见，这里可以使用 1000
                // }

                WritableMap params = Arguments.createMap();
                params.putInt("connectMeshAddress", getDeviceByMacAddress(mService.getCurDeviceMac()).meshAddress);
                sendEvent(DEVICE_STATUS_LOGIN, params);
                break;
            case MeshEvent.EVENT_TYPE_DISCONNECTED:
                if (kickDirect) {
                    onKickOutFinish();
                }
                sendEvent(DEVICE_STATUS_LOGOUT);
                break;
            case NotificationEvent.EVENT_TYPE_KICK_OUT_CONFIRM:
                if (!kickDirect) {
                    onKickOutFinish();
                }
                break;
            case ScanEvent.DEVICE_FOUND:
                onLeScan((ScanEvent) event);
                break;
            case ScanEvent.SCAN_TIMEOUT:
                sendEvent(LE_SCAN_TIMEOUT);
                sendEvent(DEVICE_STATUS_LOGOUT);
                break;
            case MeshEvent.EVENT_TYPE_PROVISION_SUCCESS:
                onProvisionSuccess((MeshEvent) event);
                break;
            case MeshEvent.EVENT_TYPE_PROVISION_FAIL:
                onProvisionFail((MeshEvent) event);
                // startScan();
                break;
            case MeshEvent.EVENT_TYPE_KEY_BIND_SUCCESS:
                onUpdateMeshCompleted((MeshEvent) event);
                // startScan();
                break;
            case MeshEvent.EVENT_TYPE_KEY_BIND_FAIL:
                onUpdateMeshFailure((MeshEvent) event);
                // startScan();
                break;
            case MeshEvent.EVENT_TYPE_DEVICE_OFFLINE:
                this.onMeshOffline((MeshEvent) event);
                break;
        }
    }

    /*********************/
    /** Private methods **/
    /*********************/

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
