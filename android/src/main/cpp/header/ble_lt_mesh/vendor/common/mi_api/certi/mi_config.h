#ifndef __MI_CONFIG_H__
#define __MI_CONFIG_H__
#include <stdint.h>

#if defined(CUSTOMIZED_MI_CONFIG_FILE)
#include CUSTOMIZED_MI_CONFIG_FILE
#endif

/**
 * @note MIBLE_LIB_AND_DEVELOPER_FIRMWARE_VERSION
 *
 * The MIBLE SDK major, minor and revision MUST NOT be changed.
 * And DEVELOPER_VERSION will identify developer firmware version.
 * e.g. x.y.z_d
 */
#ifndef DEVELOPER_VERSION
#define DEVELOPER_VERSION       0001
#endif
#define MI_MESH_ENABLED 1
#define STR_VAL(str)  #str
#define CONCAT_VERSION(x,y,z,u) STR_VAL(x) "." STR_VAL(y) "." STR_VAL(z) "_" STR_VAL(u)
#if defined(MI_BLE_ENABLED)

#define MI_BLE_MAJOR            2
#define MI_BLE_MINOR            1
#define MI_BLE_REVISION         10

#define MIBLE_LIB_AND_DEVELOPER_VERSION CONCAT_VERSION(MI_BLE_MAJOR, MI_BLE_MINOR, MI_BLE_REVISION, DEVELOPER_VERSION)
#elif defined(MI_MESH_ENABLED)

#define MI_MESH_MAJOR           1
#define MI_MESH_MINOR           2
#define MI_MESH_REVISION        0

#define MIBLE_LIB_AND_DEVELOPER_VERSION CONCAT_VERSION(MI_MESH_MAJOR, MI_MESH_MINOR, MI_MESH_REVISION, DEVELOPER_VERSION)
#else
#error "No MI_BLE_ENABLED or MI_MESH_ENABLED is defined. Should add one of them to the preprocesser symbols."
#endif


#define MI_IOT_TELINK_MODE 		1
#if MI_IOT_TELINK_MODE
//#define PRODUCT_ID			   0x03b7//telink lab pid
//#define PRODUCT_ID			   0x0379//generic pid
#define PRODUCT_ID			   0x03b4//yeelight pid
#else
#define PRODUCT_ID             0x0379//silicon lab pid
#endif
#define DEMO_CER_MODE		0
#define FLASH_CER_MODE		1 
#if MI_IOT_TELINK_MODE
#define MI_CER_MODE 	FLASH_CER_MODE
#endif




/**
 * @note mibeacon object advertising configuration
 *
 * The mibeacon object is an adv message contains the status or event. BLE gateway
 * can receive the beacon message (by active scanning) and upload it to server for
 * triggering customized home automation scene.
 *
 * EVT_QUEUE_SIZE   : max num of objects can be concurrency advertising
 * ( actually, it will be sent one by one )
 * EVT_ADV_INTERVAL : the object adv interval
 * EVT_ADV_TIMEOUT_MS : the time one object will be continuously sent.
 */

#ifndef EVT_QUEUE_SIZE
#define EVT_QUEUE_SIZE         8
#endif

#ifndef EVT_ADV_INTERVAL_MS
#define EVT_ADV_INTERVAL_MS    100
#endif

#ifndef EVT_ADV_TIMEOUT_MS
#define EVT_ADV_TIMEOUT_MS     3000
#endif


/**
 * @note To support Secure Auth procedure MUST have mijia secure chip (MSC).
 *      NONE   : 0
 *      MJSC   : 1
 *      MJAC1  : 2
 *
 */
#ifndef HAVE_MSC
#define HAVE_MSC               0
#endif

#ifndef MI_SCHD_PROCESS_IN_MAIN_LOOP
#define MI_SCHD_PROCESS_IN_MAIN_LOOP    1
#endif

/* DEBUG */
#ifndef DEBUG_MIBLE
#define DEBUG_MIBLE            0
#define PRINT_MSC_INFO         0
#define PRINT_MAC              0
#define PRINT_DEV_PUBKEY       0
#define PRINT_ECDHE            0
#define PRINT_SHA256           0
#define PRINT_SIGN             0
#define PRINT_LTMK             0
#endif


#define DFU_NVM_START          0x4A000UL      /**< DFU Start Address */
#define DFU_NVM_END            0x7E800UL      /**< DFU End Address */

#define DEV_SK_FLASH_ADR 	   0x7f000
#endif  /* __MI_CONFIG_H__ */ 


