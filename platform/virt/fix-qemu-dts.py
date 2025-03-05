#! /usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
import getopt
import sys
from io import StringIO
PAGE_SIZE =  4096

def kic_defs(size):
    out = StringIO()
    print("""
        reserved-memory  {{
                #address-cells = <0x2>;
                #size-cells = <0x2>;
                ranges;
                reserved: pkvm_loader@0 {{
                        no-map;
                        compatible = "linux,pkvm-guest-firmware-memory";
                        reg = <0x0 0x{:x} 0x0 0x{:x}>;
                }};
        }};
        """.format(addr, (size + PAGE_SIZE -1) & ~(PAGE_SIZE -1)), file = out)

    return out.getvalue()

def ini_defs(addr, size):
    out = StringIO()
    print("""
          \tlinux,initrd-start = <0x{:x}>;
          \tlinux,initrd-end = <0x{:x}>;
          """.format(addr, addr + size), file = out)
    return out.getvalue();

argv = sys.argv[1:]

try:
    opts, args = getopt.getopt(argv, "KIi:o:s:a:")

except:
    print("Error")
kic = False
initfs = False
for opt, arg in opts:
    if opt in ['-K']:
        kic = True
    elif opt in ['-I']:
        initfs  = True
    elif opt in ['-i']:
        indts = arg
    elif opt in ['-o']:
        outdts = arg
    elif opt in ['-s']:
        size = int(arg)
    elif opt in ['-a']:
        addr = int(arg,16)

with open(outdts, 'w') as outfile:
    with open(indts, 'r') as infile:
        # Read each line in the file
        for line in infile:
            if (kic):
                if (line.find("virtio_mmio@a000000") >= 0):
                    outfile.write(kic_defs(size));
                outfile.write(line);

            if (initfs):
                outfile.write(line);
                if (line.find("chosen {") >= 0 ):
                    outfile.write(ini_defs(addr, size))

infile.close()


