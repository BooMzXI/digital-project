# Digital Project

A Verilog FPGA RPG demo for the **Digilent Nexys A7-100T** board. The project renders a pixel-art game over VGA and combines player movement, collectible items, form progression, minion AI, boss combat, health bars, and a victory screen.

## Features

- VGA output driven by a 25 MHz pixel clock
- Player movement with directional buttons
- Attack action and speed-boost switch
- Collectible items that change the player form and maximum health
- Up to 16 patrolling minions with attack and defeat states
- Boss AI, health tracking, attack warnings, and victory state
- Sprite and background rendering from ROM/memory assets
- Seven-segment display output for game status
- LED output for the walking animation FSM state
- Verilog simulation testbenches for logic and VGA behavior

## Hardware

- Digilent Nexys A7-100T
- VGA monitor and cable
- Vivado 2024.2 or a compatible Vivado release

The Vivado project targets the `xc7a100tcsg324-1` Artix-7 device and uses the Nexys A7-100T board definition.

## Controls

| Input | Action |
| --- | --- |
| `BTNU` | Move up |
| `BTND` | Move down |
| `BTNL` | Move left |
| `BTNR` | Move right |
| `BTNC` | Attack |
| `SW[0]` | Speed boost |
| `CPU_RESETN` | Reset the game |

Connect the board's VGA output to a monitor. The objective is to collect items, survive the minions, and defeat the boss.

## Project layout

```text
Final/
├── Final.xpr                         Vivado project
├── Final.srcs/sources_1/             Verilog design sources and memory assets
│   ├── .../lab08_top.v               Top-level FPGA module
│   ├── .../game_logic.v              Game subsystem wrapper
│   ├── .../player.v                  Player movement and health
│   ├── .../item_ctrl.v               Items and form progression
│   ├── .../minion_ctrl.v             Minion behavior
│   ├── .../boss_ctrl.v               Boss behavior and victory logic
│   ├── .../game_graphics.v           VGA rendering and ROM connections
│   └── .../game_timer.v              Seven-segment output
├── Final.srcs/constrs_1/             Nexys A7 pin constraints
└── Final.srcs/sim_1/                 Simulation testbenches
```

## Open and run in Vivado

1. Install Vivado and the Nexys A7-100T board files.
2. Open `Final/Final.xpr`.
3. Set `lab08_top` as the top module if Vivado does not select it automatically.
4. Confirm that `Final/Final.srcs/constrs_1/imports/constrs/lab08.xdc` is enabled.
5. Run **Synthesis**, **Implementation**, and **Generate Bitstream**.
6. Program the Nexys A7-100T with the generated bitstream.

The repository contains Vivado-generated files as well as the project sources. If Vivado reports stale generated artifacts, use **Reset Runs** and regenerate them from the project.

## Simulation

The simulation sources include testbenches for the game logic, VGA timing, walking FSM, and a full hierarchical visual verification flow. In Vivado, select a testbench under `Final/Final.srcs/sim_1/`, choose the appropriate simulation top, and run **Run Simulation**.

`tb_full_check.v` exercises multiple scenes, including the spawn screen, boss and minion attacks, movement/collision behavior, item collection, and the victory state. It writes captured frames as PPM files in the simulator's working directory.

## Notes

- The design uses a 100 MHz board clock and generates a 25 MHz VGA clock with `clk_gen.v`.
- VGA timing and rendering are implemented in the `vga_sync.v`, `vga_render.v`, and `game_graphics.v` modules.
- Pin assignments, VGA signals, buttons, switch, LEDs, and seven-segment outputs are defined in the Nexys A7 constraint file.