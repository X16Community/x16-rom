#!/usr/bin/env python3

import os
import testutil

# Determine the script directory
script_dir = os.path.dirname(__file__)

# Assemble the full path to the output directory
output_dir = os.path.join(script_dir, "../../../build/x16/test")

# Create the output directory if it doesn't yet exist
if not os.path.exists(output_dir):
    os.mkdir(output_dir)

test_source = os.path.join(script_dir, "ff6e-jsrfar.s")
test_prg = os.path.join(output_dir, "ff6e-jsrfar.prg")

testutil.assemble(test_source, test_prg)
res = testutil.run_tests(test_prg, ['-c816'])

TEST1_A = res[0]

TEST2_R = res[1] + (res[2] << 8) + (res[3] << 16)

TEST3_A = res[4]
TEST3_X = res[5]
TEST3_Y = res[6]

TEST4_A = res[7]
TEST4_X = res[8]
TEST4_Y = res[9]

TEST5_A = res[10]
TEST5_X = res[11] + (res[12] << 8)
TEST5_Y = res[13] + (res[14] << 8)

TEST6_A = res[15] + (res[16] << 8)
TEST6_X = res[17] + (res[18] << 8)
TEST6_Y = res[19] + (res[20] << 8)

TEST7_A = res[21] + (res[22] << 8)
TEST7_X = res[23] + (res[24] << 8)
TEST7_Y = res[25] + (res[26] << 8)

TEST8_A = res[27] + (res[28] << 8)
TEST8_X = res[29]
TEST8_Y = res[30]

TEST9_A = res[31]

print(f"ff6e-jsrfar (e) TEST1: ROM, ym_get_chip_type, expected 0 or 2, got: {TEST1_A}")

if not (TEST1_A == 0 or TEST1_A == 2):
    raise RuntimeError("TEST1 failed")

print(f"ff6e-jsrfar (e) TEST2: ROM, rdtim, expected 60, got: {TEST2_R}")

if not (TEST2_R == 60):
    raise RuntimeError("TEST2 failed")

print(f"ff6e-jsrfar (e) TEST3: BRAM, incr regs, expected 70, 165, 2, got: {TEST3_A}, {TEST3_X}, {TEST3_Y}")

if not (TEST3_A == 70 and TEST3_X == 165 and TEST3_Y == 2):
    raise RuntimeError("TEST3 failed")

print(f"ff6e-jsrfar (m=1,x=1) TEST4: BRAM, incr regs, expected 50, 150, 250, got: {TEST4_A}, {TEST4_X}, {TEST4_Y}")

if not (TEST4_A == 50 and TEST4_X == 150 and TEST4_Y == 250):
    raise RuntimeError("TEST4 failed")

print(f"ff6e-jsrfar (m=1,x=0) TEST5: BRAM, incr regs, expected 121, 1338, 42070, got: {TEST5_A}, {TEST5_X}, {TEST5_Y}")

if not (TEST5_A == 121 and TEST5_X == 1338 and TEST5_Y == 42070):
    raise RuntimeError("TEST5 failed")

print(f"ff6e-jsrfar (m=0,x=0) TEST6: BRAM, incr regs, expected 12346, 54322, 65433, got: {TEST6_A}, {TEST6_X}, {TEST6_Y}")

if not (TEST6_A == 12346 and TEST6_X == 54322 and TEST6_Y == 65433):
    raise RuntimeError("TEST6 failed")

print(f"ff6e-jsrfar (m=0,x=0) TEST7: ROM, extapi16 #0, expected 23432, got: {TEST7_A}")

if not (TEST7_A == 23432):
    raise RuntimeError("TEST7 failed")

print(f"ff6e-jsrfar (m=0,x=1) TEST8: ROM, extapi16 #0, expected 260, got: {TEST8_A}")

if not (TEST8_A == 260):
    raise RuntimeError("TEST8 failed")

print(f"ff6e-jsrfar (e) TEST9: RAM -> BRAM, fixed return, expected 255, got: {TEST9_A}")

if not (TEST9_A == 255):
    raise RuntimeError("TEST9 failed")
