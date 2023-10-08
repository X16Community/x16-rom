import sys

f = open(sys.argv[1])

c = f.read(1)
i = 0
print(".byt ", end='')
while c:
    print(ord(c), end='')
    i=i+1
    if i==30:
        print("\n.byt ", end='')
        i=0
    else:
        print(", ", end='')
    c = f.read(1)
print(" 0")