from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from prepare_roms import prepare


def run(command, output, log):
    print(" ".join(str(arg) for arg in command), flush=True)
    with (output / log).open("w") as stream:
        process = subprocess.Popen(command, cwd=output, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            stream.write(line)
            stream.flush()
            if log.endswith("_boot.log"):
                print(line, end="", flush=True)
        if process.wait():
            raise RuntimeError(f"Command failed; see {output / log}")


def build(repo, output, ghdl, jobs):
    cpu = (repo / "rtl/williams_cpu.vhd").read_text()
    cpu = cpu.replace("std_match(video_address(5 downto 0),",
                      "match_pattern(std_logic_vector(video_address(5 downto 0)),")
    cpu = cpu.replace("std_match(", "match_pattern(")
    marker = "architecture Behavioral of williams_cpu is"
    function = """
    function match_pattern(value, pattern : std_logic_vector) return boolean is
        alias a : std_logic_vector(value'length - 1 downto 0) is value;
        alias b : std_logic_vector(pattern'length - 1 downto 0) is pattern;
    begin
        for i in a'range loop
            if b(i) /= '-' and a(i) /= b(i) then return false; end if;
        end loop;
        return true;
    end function;
"""
    if cpu.count(marker) != 1:
        raise ValueError("Cannot locate CPU architecture")
    (output / "williams_cpu.vhd").write_text(cpu.replace(marker, marker + function))
    speech = (repo / "rtl/hc55564.vhd").read_text()
    speech, count = re.subn(
        r"unsigned\(std_logic_vector\(\s*resize\(v_intfilter xor to_signed\(16#200#,\s*10\),\s*10\)\s*\)\)\(9 downto 4\)",
        'unsigned(v_intfilter(9 downto 4)) xor "100000"', speech)
    if count != 2:
        raise ValueError("Cannot adapt speech expressions")
    (output / "hc55564.vhd").write_text(speech)
    files = [repo / name for name in (
        "rtl/dpram.vhd", "tests/dpram_model.vhd", "rtl/gen_ram.vhd",
        "tests/gen_ram_model.vhd", "rtl/CEGen.vhd", "rtl/cpu68.vhd",
        "rtl/pia6821.vhd", "rtl/sc1.vhd", "rtl/williams_rom.vhd",
        "rtl/williams_ram.vhd", "rtl/williams_audio.vhd")]
    files += [output / "hc55564.vhd", repo / "rtl/williams_sound_board.vhd",
              output / "williams_cpu.vhd", repo / "rtl/williams_soc.vhd",
              repo / "tests/blaster_sim.vhd"]
    run([ghdl, "-a", "--std=08", "-fsynopsys", *map(str, files)], output, "analyze.log")
    print("Translating VHDL for Verilator", flush=True)
    with (output / "blaster_sim.v").open("w") as netlist, (output / "synthesis.log").open("w") as log:
        subprocess.run([ghdl, "--synth", "--std=08", "-fsynopsys", "--out=verilog",
                        "--no-formal", "blaster_sim"], cwd=output,
                       stdout=netlist, stderr=log, check=True)
    netlist = (output / "blaster_sim.v").read_text()
    if netlist.count(".Dout(cpu_dout)") != 1:
        raise ValueError("Cannot locate native 6809 output port")
    (output / "blaster_sim.v").write_text(netlist.replace(".Dout(cpu_dout)", ".DOut(cpu_dout)"))
    run(["verilator", "--cc", "--exe", "--build", "--savable", "-j", str(jobs), "--top-module",
         "blaster_sim", "-Wno-fatal", "--Mdir", "obj_dir", "-O3", "-CFLAGS", "-O3",
         str(repo / "tests/blaster_verilator.vlt"), "blaster_sim.v",
         str(repo / "rtl/mc6809is.v"), str(repo / "tests/blaster_verilator.cpp")],
        output, "compile.log")


def main():
    os.environ["LC_ALL"] = "C"
    parser = argparse.ArgumentParser(description="Run under Linux/WSL with GHDL and Verilator")
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--rom-directory", type=Path)
    parser.add_argument("--ghdl", default="ghdl")
    parser.add_argument("--jobs", type=int, default=min(8, os.cpu_count() or 1))
    parser.add_argument("--sets", nargs="+", choices=("blasterkit", "blaster", "blastero"),
                        default=["blasterkit", "blaster", "blastero"])
    parser.add_argument("--frames", type=int, default=2801)
    parser.add_argument("--build-only", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = args.output_directory.resolve()
    if output.is_relative_to(repo):
        raise ValueError("Keep ROMs and simulation output outside the checkout")
    if args.frames < 1 or args.jobs < 1:
        raise ValueError("Frames and jobs must be positive")
    output.mkdir(parents=True, exist_ok=True)
    ghdl = shutil.which(args.ghdl)
    if not ghdl:
        raise ValueError("GHDL is unavailable")
    if args.rom_directory:
        prepare(args.rom_directory, output)
    if not args.build_only:
        for name in args.sets:
            packet = output / (name + ".hex")
            if not packet.is_file():
                raise ValueError(f"Missing ROM packet: {packet}; supply --rom-directory")
    sources = sorted((repo / "rtl").glob("*.vhd")) + sorted((repo / "tests").glob("*"))
    sources += [repo / "rtl/mc6809is.v"]
    manifest = {
        "started": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "ghdl": subprocess.check_output([ghdl, "--version"], text=True),
        "verilator": subprocess.check_output(["verilator", "--version"], text=True),
        "sources": {str(path.relative_to(repo)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in sources if path.is_file()},
        "frames": args.frames, "sets": args.sets,
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    build(repo, output, ghdl, args.jobs)
    if not args.build_only:
        for name in args.sets:
            run([str(output / "obj_dir/Vblaster_sim"), str(output / (name + ".hex")),
                 "8" if name == "blasterkit" else "9", str(output / name), str(args.frames)],
                output, name + "_boot.log")
    manifest["finished"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    manifest["completed"] = "build" if args.build_only else "simulation"
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
