The testbenches use VHDL-2008 and ModelSim Intel FPGA Edition. Put `vlib`, `vmap`, `vcom`, `vlog`, and `vsim` on PATH, then run:

```powershell
.\tests\run.ps1
.\tests\run.ps1 -RomDirectory 'path\to\MAME 0.257 ROMs (split)'
.\tests\run.ps1 -RomDirectory 'path\to\MAME 0.257 ROMs (split)' -Boot
```

Python 3.9 or later prepares the ROM packets directly from the three MRAs and checks their sizes and MD5 values. Supply `blaster.zip`, `blasterkit.zip`, and `blastero.zip`. ROMs and simulation output stay outside the checkout. Use `-OutputDirectory` to choose the output folder.

The dedicated 20-level set uses `releases/Blaster.mra`. The conversion kit and 30-level MRAs are in `releases/_alternatives/_Blaster`. ROM preparation searches nested locations under `releases`.

The short tests check ROM banking and download isolation, SC2 remapping and nibble masks, clip boundaries, mono/stereo audio, clock rates, and the sound CPU's RAM and PIA wiring. With ROMs present, the board test also checks the memory map, CMOS, input multiplexing, all 128 real blitter remap tables, scanline background colors, and erase behind. It places different colors at both visible edges and guard pixels outside them, checking that Blaster blanks the guards and legacy modes retain them. The sound ROM test boots the original sound CPU program and checks that three commands produce DAC samples.

The ROM test checks every byte of the twelve populated Blaster banks, both fixed-ROM windows, and the four empty banks in both Blaster modes. It also reloads and checks the complete program-ROM address range and aliases for each legacy mode. Legacy program ROMs share storage with Blaster's banked ROMs; selecting another game requires downloading its ROM packet, as on MiSTer. Empty Blaster banks return zero without allocating RAM. Downloads do not depend on the game selection arriving first.

The optional boot test runs the original main CPU with the ROM packet and captures raw video as PPM files. It presses Advance at frame 1800 to leave the fresh-CMOS message. It excludes the sound CPUs to stay within the Starter Edition simulation limit. This is a visual boot check, not an automated gameplay assertion, and can take a long time. `-Frames` changes the duration.

For faster boot and gameplay checks, run `run_verilator.py` under Linux or WSL with Python 3.9+, GHDL with synthesis support, Verilator, Make, and a C++ compiler:

```bash
python tests/run_verilator.py /path/outside/checkout/blaster-sim \
    --rom-directory '/path/to/MAME 0.257 ROMs (split)' \
    --ghdl /path/to/ghdl
```

This builds the VHDL SoC, including both sound CPUs, through GHDL's generated Verilog and links the original Verilog 6809. The C++ file only drives inputs and records outputs. `--sets blasterkit` selects just the conversion kit; the default runs all three variants. `--frames 2801` captures the first RAM test, factory message, attract screen, and gameplay after Advance, coin, start, fire, and joystick inputs. Captures are PPM video and stereo WAV audio. Review them visually; completing the run does not assert correct gameplay. Source hashes, tool versions, and logs are saved beside the output.

The driver inserts two coins because the 30-level set defaults to two coins per game. Coin presses last eight frames, with a one-second gap between them to allow the game's debounce logic to rearm.

For free play on hardware, set `Pricing Selection` to `9` in Game Adjustments, as listed in the [service manual](https://www.arcade-museum.com/manuals-videogames/B/Blaster.pdf#page=16), printed page 13. This is a CMOS service setting; the automated driver retains coin/start input checks.

To open Game Adjustments from attract mode, select `Auto Up` for `Auto Up / Manual Down` in the MRA's switch menu, then press and release Advance twice. The first press opens Bookkeeping; the second opens Game Adjustments. Select an item with the joystick and use Fire and Thrust to change its value. Press Advance to exit. Holding the mapped Auto Up button while pressing Advance provides the same input. With `Manual Down` selected, Advance enters diagnostics instead; ROM testing can leave the screen blank while it runs. These are the original ROM's menus and service inputs.

The [checkpoint support](https://verilator.org/guide/latest/simulating.html#save-restore) saves the complete model at frame 1900, after Advance and before the coin inputs. To repeat an input check with the same simulator binary and ROM packet, invoke the executable directly:

```bash
/path/to/output/obj_dir/Vblaster_sim /path/to/output/blastero.hex 9 \
    /path/to/output/repeat 2801 /path/to/output/blastero_1900.chk
```

Keep checkpoints outside the checkout with the ROMs: they contain the downloaded ROM data. Create fresh checkpoints after any FPGA source or tool change. The driver checks the packet path, packet contents, variant, and saved frame before resuming.

The GHDL path makes temporary equivalent substitutions for binary `std_match` patterns, the speech expression, and the native CPU's Verilog port spelling. It uses the same simulation RAM architectures as ModelSim. The generated Verilog and adapters stay outside the checkout; FPGA source remains unchanged. GHDL 6.0.0 and Verilator 5.052 were used for this path.

The simulation architectures for `dpram` and `gen_ram` use variable storage. This avoids the original dual-port model's resolved signal drivers and large array event overhead; Quartus still builds the original RAM entities. The script also makes an equivalent temporary expression change in `hc55564.vhd` for ModelSim 10.5b, which cannot parse the original slice of a converted value. These simulation files are not in `files.qip`.

Build the FPGA separately from unsandboxed PowerShell with the full project flow:

```powershell
quartus_sh --flow compile Arcade-Robotron
```
