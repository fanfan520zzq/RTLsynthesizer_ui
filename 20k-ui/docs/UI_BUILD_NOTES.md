# Nano 20K UI prototype notes

## Files

- `rtl/top_tang_nano_20k_ui.v`: top-level integration for the 27 MHz board
  clock, 800x480 timing, EC11, UI state, test waveform, eight visual spectrum
  bars and the existing `hdmi_tx` wrapper.
- `rtl/ui_renderer_800x480.v`: one-cycle RGB renderer with three pages,
  focus/edit state, labels, hexadecimal parameter values, dynamic triangle
  waveform and eight spectrum columns.
- `rtl/video_timing_800x480.v`: GitHub UI timing (1056x525,
  H=800+210+20+26, V=480+19+3+23, positive sync).
- `rtl/pll_800x480_template.v`: integer 27 MHz -> 166.5 MHz -> 33.3 MHz
  clock template. It must be regenerated or checked with Gowin IP Generator.
- `constraints/tang_nano_20k_ui.cst.template`: verified Nano HDMI pair
  locations and unassigned EC11 placeholders.
- `constraints/tang_nano_20k_ui.sdc.template`: timing template for the
  integer clock pair.

## Build and hardware caveats

The complete RTL set parses and elaborates under Icarus with `SIMULATION`.
That does not validate Gowin primitive parameters, placement/routing, HDMI
signal integrity, or a particular board revision.

The renderer uses `font_rom.v` and its `rtl/font_rom.hex` path. Ensure the
Gowin project working directory makes that relative path resolve, or define
`FONT_ROM_HEX` to an absolute/project-relative path in the synthesis settings.

Do not copy the Tang Mega 60K `DVI_TX_Top` primitive into this project. The
Nano 20K path uses the existing `hdmi_tx` wrapper and Nano-specific `OSER10`
and `ELVDS_OBUF` instances. The simulator uses behavioral branches only.

The EC11 module is marked `5V GND A B KEY` in the user's hardware. A/B/KEY
must be FPGA-safe 3.3 V signals. Power the board at 3.3 V only if its circuit
works at that voltage; otherwise insert level shifting. The checked-in
constraint template intentionally leaves these pins commented until the
physical connector and IO bank are confirmed.

The small spectrum block is an eight-bin, single-multiplier Goertzel-style
visualizer over 128 internal samples. It is deliberately not a full FFT and
has no audio input. The test source is a 48 kHz, 440 Hz triangle waveform.
