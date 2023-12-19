import unittest
from testbench import X16TestBench
from testbench import Status

class SymbolTest(unittest.TestCase):
    e = None
    next_bank = 2
    next_offset = 0

    def __init__(self, *args, **kwargs):
        super(SymbolTest, self).__init__(*args, **kwargs)
        self.e = X16TestBench("./x16emu", ["-rom", "../build/custrom.bin"])
        self.e.importViceLabels("../build/basload-rom.sym")
        self.e.waitReady()

    def symbol_init(self):
        self.e.setRomBank(15)
        self.e.run(self.e.labels["symbol_init"])

    def set_file_buf(self, data):
        i = 0
        for c in data:
            self.e.setMemory(self.e.labels["file_buf"] + i, ord(c))
            i += 1

    def add_symbol(self, name, type, value):
        cs = 0
        for c in name:
            cs += ord(c)
            cs = cs & 255
        
        self.e.setRamBank(1)
        if self.e.getMemory(self.e.labels["symbol_buckets_bank"] + cs) == 0:
           self.e.setMemory(self.e.labels["symbol_buckets_bank"] + cs, self.next_bank)
           self.e.setMemory(self.e.labels["symbol_buckets_offset"] + cs, self.next_offset)
        else:
            prev_bank = self.e.getMemory(self.e.labels["symbol_buckets_bank"] + cs)
            prev_addr = self.e.getMemory(self.e.labels["symbol_buckets_offset"] + cs) * 32 + 0xa000

            while True:
                self.e.setRamBank(prev_bank)
                if self.e.getMemory(prev_addr+27) == 0:
                    self.e.setMemory(prev_addr+27, self.next_bank)
                    self.e.setMemory(prev_addr+28, self.next_offset)
                    break
                else:
                    prev_bank = self.e.getMemory(prev_addr+27)
                    prev_addr = self.e.getMemory(prev_addr+28) * 32 + 0xa000
        
        self.e.setRamBank(self.next_bank)
        addr = self.next_offset * 32 + 0xa000
        
        i = 0
        for c in name:
            self.e.setMemory(addr+i, ord(c))
            i += 1

        self.e.setMemory(addr+26, len(name))
        self.e.setMemory(addr+27,0)
        self.e.setMemory(addr+29,type)
        self.e.setMemory(addr+30,value & 255)
        self.e.setMemory(addr+31,value >> 8)

        self.next_offset += 1
        if self.next_offset > 255:
            next_offset = 0
            next_bank += 1
        
    def test_not_exist(self):
        # Setup
        self.symbol_init()

        # Run test
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.run(self.e.labels["symbol_find"])
        
        # Assertion
        self.assertEqual(self.e.getStatus() & Status.C, 1)

    def test_find_first(self):
        # Setup
        self.symbol_init()
        self.add_symbol("hello", 0, 100)

        # Run test
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.run(self.e.labels["symbol_find"])
        
        # Assertions
        self.assertEqual(self.e.getStatus() & Status.C, 0)
        self.assertEqual(self.e.getX(), 100)
        self.assertEqual(self.e.getY(), 0)

    def test_find_second(self):
        # Setup
        self.symbol_init()
        self.add_symbol("hello", 0, 100)
        self.add_symbol("helol", 0, 200)

        # Run test
        self.set_file_buf("helol")
        self.e.setX(0)
        self.e.setY(4)
        self.e.run(self.e.labels["symbol_find"])
        
        # Assertions
        self.assertEqual(self.e.getStatus() & Status.C, 0)
        self.assertEqual(self.e.getX(), 200)
        self.assertEqual(self.e.getY(), 0)

    def test_find_second_different_banks(self):
        # Setup
        self.symbol_init()
        self.add_symbol("hello", 0, 100)
        self.next_bank = 3
        self.add_symbol("helol", 0, 200)

        # Run test
        self.set_file_buf("helol")
        self.e.setX(0)
        self.e.setY(4)
        self.e.run(self.e.labels["symbol_find"])
        
        # Assertions
        self.assertEqual(self.e.getStatus() & Status.C, 0)
        self.assertEqual(self.e.getX(), 200)
        self.assertEqual(self.e.getY(), 0)

    def test_add_one_symbol(self):
        labels = self.e.labels

        # Checksum
        cs = 0
        for c in "hello":
            cs += ord(c)
            cs = cs & 255

        # Setup & run
        self.e.setMemory(labels["line_dstlin"], 1)
        self.e.setMemory(labels["line_dstlin"]+1, 0)
        self.symbol_init()
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.setA(0)
        self.e.setStatus(self.e.getStatus() & (255-Status.C))
        self.e.run(labels["symbol_add"])

        # Assertions
        self.assertEqual(self.e.getA(), 0)  # Response status
        self.assertEqual(self.e.getX(), 1)  # Value, low
        self.assertEqual(self.e.getY(), 0)  # Value, high
        
        self.e.setRamBank(1)
        self.assertEqual(self.e.getMemory(labels["symbol_buckets_bank"] + cs), 2)
        self.assertEqual(self.e.getMemory(labels["symbol_buckets_offset"]+ cs), 0)
        
        self.e.setRamBank(2)
        self.assertEqual(self.e.getMemory(0xa000+26), 5)    # Len
        self.assertEqual(self.e.getMemory(0xa000+27), 0)    # Next bank
        self.assertEqual(self.e.getMemory(0xa000+29), 0)    # Type
        self.assertEqual(self.e.getMemory(0xa000+30), 1)    # Value, low
        self.assertEqual(self.e.getMemory(0xa000+31), 0)    # Value, high
        
        i = 0
        name = ""
        while True:
            name += chr(self.e.getMemory(0xa000+i))
            i += 1
            if i == 5:
                break
        self.assertEqual(name, "hello")

    def test_add_two_symbols(self):
        labels = self.e.labels

        # Checksums
        cs1 = 0
        for c in "hello":
            cs1 += ord(c)
            cs1 = cs1 & 255

        cs2 = 0
        for c in "helol":
            cs2 += ord(c)
            cs2 = cs2 & 255

        # Setup & run 1
        self.symbol_init()

        self.e.setMemory(labels["line_dstlin"], 1)
        self.e.setMemory(labels["line_dstlin"] + 1, 0)
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.setA(1)
        self.e.setStatus(self.e.getStatus() & (255-Status.C))
        self.e.run(labels["symbol_add"])

        # Assertions 1
        self.assertEqual(self.e.getA(), 0)  # Response status
        self.assertEqual(self.e.getX(), 1)  # Value, low
        self.assertEqual(self.e.getY(), 0)  # Value, high
        self.e.setRamBank(1)
        self.assertEqual(self.e.getMemory(labels["symbol_buckets_bank"] + cs1), 2)
        self.assertEqual(self.e.getMemory(labels["symbol_buckets_offset"]+ cs1), 0)

        # Setup & run 2
        self.set_file_buf("helol")
        self.e.setX(0)
        self.e.setY(4)
        self.e.setA(1)
        self.e.setStatus(self.e.getStatus() & (255-Status.C))
        self.e.run(labels["symbol_add"])

        # Assertions 2
        self.assertEqual(self.e.getA(), 0)  # Response status
        self.assertEqual(self.e.getX(), 65)  # Value, low
        self.assertEqual(self.e.getY(), 0)  # Value, high
        
        self.e.setRamBank(1)
        self.assertEqual(self.e.getMemory(labels["symbol_buckets_bank"] + cs1), 2)
        self.assertEqual(self.e.getMemory(labels["symbol_buckets_offset"]+ cs1), 0)

        self.e.setRamBank(2)
        self.assertEqual(self.e.getMemory(0xa020+26), 5)    # Len
        self.assertEqual(self.e.getMemory(0xa020+27), 0)    # Next bank
        self.assertEqual(self.e.getMemory(0xa020+29), 1)    # Type
        self.assertEqual(self.e.getMemory(0xa020+30), 65)   # Value, low
        self.assertEqual(self.e.getMemory(0xa020+31), 0)    # Value, high

        # Setup & run 3
        self.set_file_buf("helol")
        self.e.setX(0)
        self.e.setY(4)
        self.e.run(self.e.labels["symbol_find"])

        # Assertions 3
        self.assertEqual(self.e.getStatus() & Status.C, 0)
        self.assertEqual(self.e.getX(), 65)  # Value, low
        self.assertEqual(self.e.getY(), 0)  # Value, high
        self.assertEqual(self.e.getA(), 1)  # Type

    def test_add_duplicates(self):
        labels = self.e.labels

        # Setup & run 1
        self.symbol_init()

        self.e.setMemory(labels["line_dstlin"], 1)
        self.e.setMemory(labels["line_dstlin"] + 1, 0)
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.setA(0)
        self.e.setStatus(self.e.getStatus() & (255-Status.C))
        self.e.run(labels["symbol_add"])

        # Setup & run 2
        self.e.setMemory(labels["line_dstlin"], 2)
        self.e.setMemory(labels["line_dstlin"] + 1, 0)
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.setA(0)
        self.e.setStatus(self.e.getStatus() & (255-Status.C)) # C=0, run duplicate symbol check
        self.e.run(labels["symbol_add"])

        # Assertions 2
        self.assertEqual(self.e.getA(), 1) # Response value 1 = duplicate symbol

        # Setup & run 3
        self.e.setMemory(labels["line_dstlin"], 2)
        self.e.setMemory(labels["line_dstlin"] + 1, 0)
        self.set_file_buf("hello")
        self.e.setX(0)
        self.e.setY(4)
        self.e.setA(0)
        self.e.setStatus(self.e.getStatus() | Status.C) # C=1, skip duplicate symbol check
        self.e.run(labels["symbol_add"])

        # Assertions 3
        self.assertEqual(self.e.getA(), 0) # Response value 0 = OK, as duplicate symbol check was disabled
        self.assertEqual(self.e.getMemory(labels["symbol_next_offset"]),2) # Ensure only two labels was added, and that one was ignored

if __name__ == '__main__':
    unittest.main()