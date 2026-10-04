from pathlib import Path
import argparse
import hashlib
import xml.etree.ElementTree as ET
import zipfile


def prepare(roms, output):
    repo = Path(__file__).resolve().parents[1]
    output = output.resolve()
    if output.is_relative_to(repo):
        raise ValueError("Keep ROM images outside the checkout")
    output.mkdir(parents=True, exist_ok=True)
    for name in ("Blaster (Conversion Kit)", "Blaster", "Blaster (30 Levels)"):
        document = ET.parse(repo / "releases" / (name + ".mra"))
        packet = document.find("rom[@index='0']")
        archives = []
        try:
            for archive in packet.attrib["zip"].split("|"):
                archives.append(zipfile.ZipFile(roms / archive))
            image = bytearray()
            for part in packet.findall("part"):
                if "crc" in part.attrib:
                    crc = int(part.attrib["crc"], 16)
                    found = next(( (z, i) for z in archives for i in z.infolist() if i.CRC == crc), None)
                    if found is None:
                        raise ValueError(f"Missing {part.attrib['name']} ({crc:08x})")
                    data = found[0].read(found[1])
                else:
                    data = bytes.fromhex(part.text or "")
                image.extend(data * int(part.attrib.get("repeat", "1"), 0))
            digest = hashlib.md5(image).hexdigest()
            if digest != packet.attrib["md5"] or len(image) != 0x60000:
                raise ValueError(f"Incorrect packet for {name}: {len(image)} bytes, {digest}")
            setname = document.findtext("setname")
            (output / (setname + ".hex")).write_text("".join(f"{b:02X}\n" for b in image), encoding="ascii")
            print(f"{setname}: {len(image)} bytes, MD5 {digest}")
        finally:
            for archive in archives:
                archive.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("rom_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    prepare(args.rom_directory, args.output_directory)
