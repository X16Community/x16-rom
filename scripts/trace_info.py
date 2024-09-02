#!/usr/bin/env python3

# Usage: trace_info.py <bank> <configfile> <listfile> <out relistfile> <out symbolsfile>
#   bank: bank to output trace info for
#   configfile: path to ld65 config file
#   listfile: path to program list file
#   out relistfile: path to relist file to be created
#   out symbolsfile: path to symbols file to be created
#
# This tool was designed to output trace info for X16 Edit and BASLOAD.

import sys
import re

# Global variables
memory_areas = {}   # Populated from ca65 config file
segments = {} # Populated from ca65 config file
bank = None # Holds the bank we're creating listings and symbols for
cur_bank = 0 # Holds the bank of the line that is currently parsed

# Regex
segmentParser = re.compile(r"^[\s]*.segment[\s]+[\"\'][\w]+[\"\']", re.IGNORECASE)
memoryDefintionParser = re.compile(r"memory[\s]*\{[^\}]*\}", re.IGNORECASE)
segmentDefinitionParser = re.compile(r"segments[\s]*\{[^\}]*\}", re.IGNORECASE)
configLineParser = re.compile(r"[\w]+[\s]*:[^;]*;", re.IGNORECASE)
hexnumParser = re.compile(r"^\$[0-9a-f]+$", re.IGNORECASE)
hexnumParser2 = re.compile(r"^0x[0-9a-f]+$", re.IGNORECASE)
decnumParser = re.compile(r"^[0-9]+$", re.IGNORECASE)
labelParser = re.compile(r"^[\s]*[a-z]+[a-z0-9]*\:", re.IGNORECASE)
procParser = re.compile(r"^[\s]*.proc[\s]+", re.IGNORECASE)

# Converts string to number
# Accepted formats: decimal numbers, hexadecimal numbers (0xn or $n)
def parseNum(str):
    h = hexnumParser.search(str)
    if h != None:
        return int(str[h.span()[0]+1:h.span()[1]], 16)

    h = hexnumParser2.search(str)
    if h != None:
        return int(str[h.span()[0]+2:h.span()[1]], 16)
    
    d = decnumParser.search(str)
    if d != None:
        return int(str[d.span()[0]:d.span()[1]])
    
    return None

# Parses the ca65 config file, extracting memory areas
# and memory segments
def parseConfig(config_path):
    # Read whole config file
    f = open(config_path, "r")
    conf = ""
    l = f.readline().upper()
    while l:
        conf = conf + l
        l = f.readline().upper()
    f.close()

    # Get memory areas
    mem_def = memoryDefintionParser.findall(conf)[0]
    mem_areas = configLineParser.findall(mem_def)
    for item in mem_areas:
        keyvalues = {}

        split_colon = item.split(":")
        name = split_colon[0].strip()

        split_comma = split_colon[1].split(",")
        for kv in split_comma:
            keyvalues[kv.split("=")[0].strip()] = kv.split("=")[1].strip()
        
        start = keyvalues["START"]
        keyvalues["curpos"] = parseNum(start)
        memory_areas[name] = keyvalues
    
    # Get memory segments
    seg_def = segmentDefinitionParser.findall(conf)[0]
    sgmts = configLineParser.findall(seg_def)
    for item in sgmts:
        keyvalues = {}
        
        split_colon = item.split(":")
        name = split_colon[0].strip()

        split_comma = split_colon[1].split(",")
        for kv in split_comma:
            keyvalues[kv.split("=")[0].strip()] = kv.split("=")[1].strip()
        
        segments[name] = keyvalues

# Parses a line of code and returns the name of a selected memory segment, or None
# It supports both the .segment directive, and the built-in shortcuts such as .CODE
def matchSegment(str):
    shortcuts = [".BSS", ".CODE", ".DATA", ".ZEROPAGE"]

    # Find .segment directive
    segment = segmentParser.findall(str)
    if len(segment) > 0:
        return segment[0].split()[1][1:-1].upper()
    
    else:
        # Find segment shortcut
        str = str.upper().strip()
        for item in shortcuts:
            if str.startswith(item):
                return item[1:]
    
    # No segment
    return None

# Returns label name found within the passed string, else None
def getLabel(str):
    l = labelParser.search(str)
    if l != None:
        return str[l.span()[0]:l.span()[1]-1].strip()

    l = procParser.search(str)
    if l != None:
        return str[l.span()[1]:].strip()

    return None

# Main worker, parses the original listings file, and outputs
# both a relist file and a symbols file
def parseCodeListing(listing_path, relist_path, symbols_path):
    f_in = open(listing_path, "r")
    f_relist = open(relist_path, "w")

    symbol_addresses = []
    symbol_names = []
    cur_offset = 0
    cursegment = None

    l = f_in.readline()
    while l:
        header = l[:11]
        disass = l[11:24]
        code = l[24:].rstrip()

        # Get possible memory segment selected on the line
        s = matchSegment(code)

        # A new segment is selected
        if s != None:
            # Remember current segment
            cursegment = s

            # Remember start of segment
            cur_offset = parseNum(memory_areas[segments[s]["LOAD"]]["START"])
            
            try:
                cur_bank = parseNum(memory_areas[segments[s]["LOAD"]]["BANK"])
            except:
                cur_bank = 0

            # The listings file will often show the address of the previous
            # segment. Replace that with the current position in the selected
            # segment.
            addr = memory_areas[segments[s]["LOAD"]]["curpos"]

            # Only output code if in the ROM area
            if addr >= 0xc000 and bank == cur_bank:
                f_relist.write("%0.6X a   " % addr + disass + code + "\n")
        
        # No segment was selected, output normal code
        elif cursegment != None:
            # Calculate absolute address
            addr = cur_offset + int(header[0:6], 16)
            
            # Remeber last address used in this segment
            memory_areas[segments[cursegment]["LOAD"]]["curpos"] = addr
            
            # Only output code if in the ROM area
            if addr >= 0xc000 and bank == cur_bank:
                f_relist.write("%0.6X a   " % addr + disass + code + "\n")

                # Store symbols
                label = getLabel(code)
                if label != None:
                    symbol_names.append(label)
                    symbol_addresses.append(addr)

        l = f_in.readline()

    f_in.close()
    f_relist.close()

    # Write symbols to file
    f_symbols = open(symbols_path, "w")
    
    f_symbols.write("uint16_t addresses_bank" + hex(bank).upper()[2:] + "[] = {")
    for a in symbol_addresses:
        f_symbols.write(hex(a) + ", ")
    f_symbols.write("\n};")

    f_symbols.write("\nchar *labels_bank" + hex(bank).upper()[2:] + "[] = {")
    for n in symbol_names:
        f_symbols.write("\"" + n + "\", ")
    f_symbols.write("\n};")
    
    f_symbols.close()

# Main
bank = parseNum(sys.argv[1])
parseConfig(sys.argv[2])
parseCodeListing(sys.argv[3], sys.argv[4], sys.argv[5])
