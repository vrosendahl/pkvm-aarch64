#! /usr/bin/python3
# SPDX-License-Identifier: GPL-2.0-only
import getopt
import sys
from io import StringIO


PAGE_SIZE =  4096
KIC_DTSI = "kic.dtsi"
G2G_DTSI = "g2g.dtsi"
INITRD_DTSI = "initrd.dtsi"

def kic_defs(addr, size):
    out = StringIO()
    print("""
    / {{
        reserved-memory  {{
            #address-cells = <0x2>;
            #size-cells = <0x2>;
            ranges;
            pkvmfw@{:x} {{
                no-map;
                compatible = "linux,pkvm-guest-firmware-memory";
                reg = <0x0 0x{:x} 0x0 0x{:x}>;
            }};
        }};
    }};
    """.format(addr, addr, (size + PAGE_SIZE -1) & ~(PAGE_SIZE -1)), file = out)

    return out.getvalue()

def g2g_defs(size):
    out = StringIO()
    print("""
    / {{
        reserved-memory  {{
            #address-cells = <0x2>;
            #size-cells = <0x2>;
            ranges;
            g2g_share {{
                no-map;
                compatible = "linux,pkvm-guest-shared-memory";
                size = <0 0x{:x}>;
                alignment = <0 0x1000>;
                buffers = <1 2 3 4>;
            }};
        }};
    }};
    """.format((size + PAGE_SIZE -1) & ~(PAGE_SIZE -1)), file = out)
    return out.getvalue()


def initrd_defs(addr, size):
    out = StringIO()
    print("""
    / {{
        chosen {{
            linux,initrd-start = <0x{:x}>;
            linux,initrd-end = <0x{:x}>;
        }};
    }};
    """.format(addr, addr + size), file = out)
    return out.getvalue();

argv = sys.argv[1:]

try:
    opts, args = getopt.gnu_getopt(argv, "d:s:S:a:")
except:
    print("Error")
    sys.exit()

for opt, arg in opts:
    if opt in ['-d']:
        dtsfile = arg
    elif opt in ['-s']:
        size = int(arg)
    elif opt in ['-S']:
        size = int(arg,16)
    elif opt in ['-a']:
        addr = int(arg,16)

if (args[0] == "KIC"):
    with open(KIC_DTSI,'w') as f:
        f.write(kic_defs(addr, size))
    with open(dtsfile,'a') as f:
        f.write('/include/ "{}"\n'.format(KIC_DTSI))
elif (args[0] == "G2G_SHARE"):
    with open(G2G_DTSI,'w') as f:
        f.write(g2g_defs(size))
    with open(dtsfile,'a') as f:
        f.write('/include/ "{}"\n'.format(G2G_DTSI))
elif (args[0] == "INITRD"):
    with open(INITRD_DTSI,'w') as f:
        f.write(initrd_defs(addr, size))
    with open(dtsfile,'a') as f:
        f.write('/include/ "{}"\n'.format(INITRD_DTSI))

