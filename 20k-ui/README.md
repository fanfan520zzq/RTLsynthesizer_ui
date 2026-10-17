# 20k-ui status

This project targets GW2AR-LV18QN88C8/I7 (Tang Nano 20K).

Implemented RTL:
- three-page 800x480 UI renderer
- EC11 quadrature input, debounce, short press and long press
- parameter edit/display
- internal 48 kHz, 440 Hz test waveform
- 128-sample, 8-bin lightweight spectrum estimator
- 800x480 raster timing
- TMDS encoder/OSER10/ELVDS prototype path for RTL and Gowin synthesis

Hardware-critical qualification:
- HDMI pins and 27 MHz pin are copied from the official Nano 20K HDMI
  example: clock 4; TMDS pairs 33/34, 35/36, 37/38, 39/40. With Gowin
  V1.9.11.03 Education, `ELVDS_OBUF` plus `IO_TYPE=LVCMOS33D` is the
  combination that passes place-and-route; `LVDS25` is rejected for this
  GW2AR output in this tool version.
- The 27 MHz crystal and integer PLL settings generate a 166.500 MHz TMDS
  serial clock and a 33.300 MHz pixel clock (`27*37/6`, then `CLKDIV /5`).
  With 1056x525 timing this is about 60.065 Hz, within the 800x480/60 target.
  The checked-in wrapper uses Gowin `rPLL`, `CLKDIV`, `OSER10`, and
  `ELVDS_OBUF`, all verified by Gowin V1.9.11.03 Education.
- The SDC timing report recognizes the 27 MHz input, 166.500 MHz serial clock,
  and 33.300 MHz generated pixel clock. The current P&R still reports
  `PR1014` for generic routing of `clk_27m_d`; treat the build as tool-verified,
  not as a substitute for checking the physical board and display.
- The DVI/TMDS transmitter in this folder is an RTL/primitive prototype. For
  the final board build, use the Nano 20K DVI_TX_Top protected IP/example if
  required by the installed Gowin flow; do not substitute the Tang Mega 60K
  protected IP.
- EC11 is wired through J6 on the 3921 board: A=FPGA pin 73, B=74,
  KEY=75, VCC=J6-19 (+3V3), GND=J6-20. The three FPGA inputs are constrained
  as `LVCMOS33`, pull-up, Bank VCCIO 3.3 V. A module marked `5V` must not
  drive these pins at 5 V: power it from 3.3 V only when its circuit permits,
  otherwise level-shift A/B/KEY to 3.3 V.

Toolchain:

  Gowin V1.9.11.03 Education (64-bit)

RTL simulation:

  cd C:\Users\cp\Desktop\20k-ui
  iverilog -g2012 -DSIMULATION -o sim/tb_ui20k.vvp rtl/*.v sim/tb_ui20k.v
  vvp sim/tb_ui20k.vvp

Control logic simulation:

  iverilog -g2012 -s tb_controls -o sim/tb_controls.vvp rtl/ec11_input.v rtl/ui_state.v sim/tb_controls.v
  vvp sim/tb_controls.vvp

640x480 diagnostic timing simulation:

```powershell
  iverilog -g2012 -o sim/tb_diag_640x480.vvp rtl/video_timing_640x480.v rtl/colorbars_640x480.v sim/tb_diag_640x480.v
  vvp sim/tb_diag_640x480.vvp
```

A successful RTL simulation does not prove PLL, I/O-bank, HDMI signal integrity,
place-and-route timing, or monitor lock. Those require Gowin IDE and the real
board/display.

## HDMI diagnostic build

The folder also contains an independent 640x480@60 color-bar design. It uses
the same clock primitive, TMDS serializer, ELVDS output buffers, and pin
constraints as the UI, but removes the renderer and EC11 logic from the video
path. This separates a monitor/HDMI timing problem from a UI RTL problem.

From PowerShell:

```powershell
cd C:\Users\cp\Desktop\20k-ui
& "C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe" .\build_diag_640x480.tcl 2>&1 | Tee-Object .\build_diag_current.log
```

The diagnostic bitstream is:

```text
impl\pnr\diag_640x480.fs
```

The color bars are white, yellow, cyan, green, magenta, red, blue, and black,
each 80 active pixels wide. A display that locks to this image confirms the
27 MHz input, 126 MHz serial PLL, 25.2 MHz pixel clock, pin constraints,
OSER10 path, and differential HDMI output. The diagnostic top keeps EC11 pins
73/74/75 constrained but does not use them.

To rebuild the normal UI without relying on Gowin's default `project.fs`
basename, use:

```powershell
& "C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe" .\build_ui_800x480.tcl 2>&1 | Tee-Object .\build_ui_current.log
```

That output is:

```text
impl\pnr\ui_800x480.fs
```

Only program `diag_640x480.fs` for the cable/screen diagnosis. Return to
`ui_800x480.fs` after the color bars are confirmed. SRAM programming is
volatile; a power cycle requires programming the chosen `.fs` again.
