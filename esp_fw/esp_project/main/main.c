#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>

#include "esp_system.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "esp_event.h"
#include "nvs_flash.h"
#include "esp_log.h"
#include "sdkconfig.h"


void vApplicationIdleHook( void );




/*
 * Init all tasks and subtasks
 *
 * @brief
 *
 * @return void
 */
static void init_system( void );
void init_system()
{

    ESP_ERROR_CHECK( nvs_flash_init() );


}


void app_main( void )
{
    init_system();

}

void vApplicationIdleHook( void ) {}
