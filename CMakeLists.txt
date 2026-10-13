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
    -ffunction-sections
    -fdata-sections
    -g
)

add_link_options(
    -mmcu=${MCU}
    -nostdlib
    -nostartfiles
    # -Wl,--gc-sections
)

add_executable(${PROJECT_NAME}.elf main.S)

add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
    COMMENT "Running Post-Build Process..."
    COMMAND avr-objcopy -O ihex ${PROJECT_NAME}.elf ${PROJECT_NAME}.hex
    COMMAND avr-objcopy -I ihex -O binary ${PROJECT_NAME}.hex ${PROJECT_NAME}.bin
    COMMAND avr-size -C --mcu=${MCU} ${PROJECT_NAME}.elf
)
