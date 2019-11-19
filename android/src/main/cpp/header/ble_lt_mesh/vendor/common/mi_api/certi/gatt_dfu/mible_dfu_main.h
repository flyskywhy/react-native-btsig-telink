/* Define to prevent recursive inclusion -------------------------------------*/

#ifndef __MI_DFU_MAIN_H__
#define __MI_DFU_MAIN_H__

/* Includes ------------------------------------------------------------------*/

#include "../../mible_type.h"

/* Exported define -----------------------------------------------------------*/

#define MIBLE_DFU_PROTOCAL_VERSION                              0x0001
#define MIBLE_DFU_FRAGMENT_SIZE                                 512

/* Exported types ------------------------------------------------------------*/

typedef struct {
    uint16_t conn_handle;
    uint16_t srv_handle;
    uint16_t ctrl_handle;
    uint16_t data_handle;
    uint16_t product_id;
    uint32_t flash_start;
    uint32_t flash_size;
} mible_dfu_init_t;

/* Exported constants --------------------------------------------------------*/
/* Exported functions --------------------------------------------------------*/

mible_status_t mible_dfu_init(mible_dfu_init_t * p_init);
mible_status_t mible_dfu_ctrl(uint8_t * buffer, uint16_t size);
mible_status_t mible_dfu_data(uint8_t * buffer, uint16_t size);
mible_status_t mible_dfu_upgrade(void);

#endif
