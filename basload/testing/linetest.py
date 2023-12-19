import unittest
from testbench import X16TestBench
from testbench import Status

class LineTest(unittest.TestCase):
    e = None

    def __init__(self, *args, **kwargs):
        super(LineTest, self).__init__(*args, **kwargs)
        self.e = X16TestBench("./x16emu", ["-rom", "../build/custrom.bin"])
        self.e.importViceLabels("../build/basload-rom.sym")
        self.e.waitReady()

    def setup(self):
        self.e.setRomBank(15)
        self.e.setMemory(self.e.labels["rom_bank"], 15)
        self.e.run(self.e.labels["bridge_copy"])
        self.e.run(self.e.labels["token_init"])
        self.e.run(self.e.labels["symbol_init"])
        self.e.run(self.e.labels["line_init"])

    def set_file_buf(self, data):
        i = 0
        for c in data:
            self.e.setMemory(self.e.labels["file_buf"] + i, ord(c))
            i += 1
        
    def test_token(self):
        labels = self.e.labels
        
        self.setup()

        i=0
        while True:
            v = self.e.getMemory(labels["token_names"]+i)
            if v & 128 == 128:
                print(chr(v & (255-128)))
            else:
                print(chr(v), end="")
            i+=1
            if i>512: break

        self.set_file_buf("=" + chr(0))
        self.e.setX(0)
        self.e.setY(0)
        self.e.run(labels["token_get"])

if __name__ == '__main__':
    unittest.main()