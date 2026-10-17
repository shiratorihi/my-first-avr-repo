cmake_minimum_required(VERSION 3.10)

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR avr)

# set(CMAKE_C_COMPILER avr-gcc)
# set(CMAKE_CXX_COMPILER avr-g++)
set(CMAKE_ASM_COMPILER avr-gcc)

project(avr_asm_test ASM)

set(MCU atmega328p)
set(F_CPU 8000000L)

set(CMAKE_BUILD_TYPE MinSizeRel)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_compile_options(
    -mmcu=${MCU}
    -DF_CPU=${F_CPU}
    -Wall
    -Wextra
    -mrelax
    # -ffunction-sections
    # -fdata-sections
    -g
)

set(SRC_FILE "main.S" CACHE STRING "Source files to build")
list(GET SRC_FILE 0 MAIN_SRC)
get_filename_component(TARGET_NAME ${MAIN_SRC} NAME_WE)

add_link_options(
    -mmcu=${MCU}
    -nostdlib
    -mrelax
    # -Wl,--gc-sections
    -Wl,-Map=${TARGET_NAME}.map
)

add_executable(${TARGET_NAME}.elf ${SRC_FILE})

add_custom_command(TARGET ${TARGET_NAME}.elf POST_BUILD
    COMMENT "Generating HEX and BIN files..."
    COMMAND avr-objcopy -O ihex -R .eeprom ${TARGET_NAME}.elf ${TARGET_NAME}.hex
    COMMAND avr-objcopy -O binary -R .eeprom ${TARGET_NAME}.elf ${TARGET_NAME}.bin
    COMMAND avr-size -C --mcu=${MCU} ${TARGET_NAME}.elf
)
