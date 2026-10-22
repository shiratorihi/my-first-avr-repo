# My first AVR repo

## Introduction

This project is a collection of AVR bare-metal assembly development subprojects.
Each subproject is an individual example, as a hands-on practice or proof-of-concept.
All subprojects are made with ATmega328P microcontroller chip on a breadboard.

## Major contents of this repo

- CMakeLists.txt\
  _Configuration file of CMake for generating build system._
- .asm-lsp.toml\
  _Configuration file of asm-lsp._
- *.S\
  _Assembly source code of each subproject._
- makeall.sh\
  _Shell script for convenient incremental compilation._
- README.md\
  _This file._
- LICENSE\
  _MIT license declaration._

## Current Progress & Plan

### Completed

- blink.S
- four_digit.S

### In progress

- serial_prime.S

### Planned

- lcd1602.S
- raw_pcm.S
- ......

## Getting Started

### Hardware/Software Requirements

- `avr-gcc toolset`*
- `CMake >= version 3.10`**
- `USBasp programmer or any other supported programmer`***
- `avrdude`
- `ATmega328P chip`
- `Breadboard`
- `Electronic components of each project`

*I am using `avr-gcc16` but theoretically `avr-gcc9` should work, although not tested.\
**Similarly CMake of an older version should also work, still, not tested.\
***Any programmer that works with ATmega328P is OK, including Arduino UNO itself.
Just make sure to use corresponding `-c` option with avrdude.

### Building and flashing

Each subprojects can be individually build, for example `four_digit.S`:

1. Create a new directory for storing build output.
   You can choose any name you want, but make sure to start with 'build'
   to further work with `makeall.sh`:

        mkdir build_four_digit

2. Enter the directory, and use CMake to generate Makefile build system:

        cd build_four_digits && cmake -DSRC_FILE=four_digit.S ..

3. Build the project:

        make

4. Flashing `.hex` into microcontroller's flash:

        avrdude -p m328p -c usbasp -U flash:w:four_digit.hex:i

   You can add `-B 0.5` to speed up flash speed for a little bit.
   Change `-c usbasp` to your corresponding programmer,
   for example `-c Arduino` if you are not using USBasp.
