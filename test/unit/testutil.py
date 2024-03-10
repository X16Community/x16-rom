#!/usr/bin/env python3

import subprocess

def assemble(source, prg):
    # Assemble the test into the output dir
    result = subprocess.run(['cl65', '-t', 'cx16', source, '-o', prg])
    result.check_returncode()


def run_tests(prg, emuargs=[]):
    with subprocess.Popen(['x16emu','-rom','build/x16/rom.bin','-testbench','-prg', prg] + emuargs,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE) as emu:

        rdy = ''
        while not rdy == 'RDY':
            rdy = emu.stdout.readline().decode().rstrip()

        emu.stdin.write("RUN 080d\n".encode())
        emu.stdin.flush()

        rdy = ''
        while not rdy == 'RDY':
            rdy = emu.stdout.readline().decode().rstrip()

        result = []

        for i in range(0x400,0x500):
            emu.stdin.write(f"RQM {i:04x}\n".encode())
            emu.stdin.flush()
            ans = emu.stdout.readline().decode().rstrip()
            result.append(int(ans, 16))

    return result

if __name__ == "__main__":
    print(f"{__file__} is not meant to be run directly.")

