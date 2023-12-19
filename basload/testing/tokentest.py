import unittest
from testbench import X16TestBench
from testbench import Status

class TokenTest(unittest.TestCase):
    e = None

    def __init__(self, *args, **kwargs):
        super(TokenTest, self).__init__(*args, **kwargs)
        self.e = X16TestBench("./x16emu", ["-rom", "../build/custrom.bin"])
        self.e.importViceLabels("../build/basload-rom.sym")
        self.e.waitReady()

    def token_init(self):
        self.e.setRomBank(15)
        self.e.setMemory(self.e.labels["rom_bank"], 15)
        self.e.run(self.e.labels["bridge_copy"])
        self.e.run(self.e.labels["token_init"])

    def set_file_buf(self, data):
        i = 0
        for c in data:
            self.e.setMemory(self.e.labels["file_buf"] + i, ord(c))
            i += 1

    def token_get(self, token):
        self.set_file_buf(token)
        self.e.setX(0)
        self.e.setY(len(token)-1)
        self.e.run(self.e.labels["token_get"])

    def test_standardtokens(self):
        # Setup
        labels = self.e.labels
        self.token_init()

        # END = 0x80
        self.token_get("END")
        self.assertEqual(self.e.getA(), 0x80)

        # FOR = 0x81
        self.token_get("FOR")
        self.assertEqual(self.e.getA(), 0x81)

        # NEXT = 0x82
        self.token_get("NEXT")
        self.assertEqual(self.e.getA(), 0x82)

        # DATA = 0x83
        self.token_get("DATA")
        self.assertEqual(self.e.getA(), 0x83)
        
        # INPUT# = 0x84
        self.token_get("INPUT#")
        self.assertEqual(self.e.getA(), 0x84)
        
        # INPUT = 0x85
        self.token_get("INPUT")
        self.assertEqual(self.e.getA(), 0x85)
        
        # DIM = 0x86
        self.token_get("DIM")
        self.assertEqual(self.e.getA(), 0x86)

        # READ = 0x87
        self.token_get("READ")
        self.assertEqual(self.e.getA(), 0x87)
        
        # LET = 0x88
        self.token_get("LET")
        self.assertEqual(self.e.getA(), 0x88)
        
        # GOTO = 0x89
        self.token_get("GOTO")
        self.assertEqual(self.e.getA(), 0x89)
        
        # RUN = 0x8a
        self.token_get("RUN")
        self.assertEqual(self.e.getA(), 0x8a)
        
        # IF = 0x8b
        self.token_get("IF")
        self.assertEqual(self.e.getA(), 0x8b)
        
        # RESTORE = 0x8c
        self.token_get("RESTORE")
        self.assertEqual(self.e.getA(), 0x8c)
        
        # GOSUB = 0x8d
        self.token_get("GOSUB")
        self.assertEqual(self.e.getA(), 0x8d)

        # RETURN = 0x8e
        self.token_get("RETURN")
        self.assertEqual(self.e.getA(), 0x8e)

        # REM = 0x8f
        self.token_get("REM")
        self.assertEqual(self.e.getA(), 0x8f)

        # STOP = 0x90
        self.token_get("STOP")
        self.assertEqual(self.e.getA(), 0x90)

        # ON = 0x91
        self.token_get("ON")
        self.assertEqual(self.e.getA(), 0x91)

        # WAIT = 0x92
        self.token_get("WAIT")
        self.assertEqual(self.e.getA(), 0x92)

        # LOAD = 0x93
        self.token_get("LOAD")
        self.assertEqual(self.e.getA(), 0x93)

        # SAVE = 0x94
        self.token_get("SAVE")
        self.assertEqual(self.e.getA(), 0x94)

        # VERIFY = 0x95
        self.token_get("VERIFY")
        self.assertEqual(self.e.getA(), 0x95)

        # DEF = 0x96
        self.token_get("DEF")
        self.assertEqual(self.e.getA(), 0x96)

        # POKE = 0x97
        self.token_get("POKE")
        self.assertEqual(self.e.getA(), 0x97)

        # PRINT# = 0x98
        self.token_get("PRINT#")
        self.assertEqual(self.e.getA(), 0x98)

        # PRINT = 0x99
        self.token_get("PRINT")
        self.assertEqual(self.e.getA(), 0x99)

if __name__ == '__main__':
    unittest.main()

