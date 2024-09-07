layouts="99409 20409 809 41D 407 406 410 415 414 40E 40A 40B 416 405 40C 807 10409 425 80C 1009 40F 816 41A 41B 424 426 427 "

for layout in $layouts; do
	filename=$(ls klc/${layout}\ *.klc)
	echo $filename
	python3 klc_to_asm.py "$filename" asm/$layout.s asm/$layout.bin asm/$layout.bin.lzsa
	if [ $layout = 99409 ]; then
		python3 ja-jp_gen.py
		lzsa -f 2 -r --prefer-ratio asm/ja-jp.bin asm/ja-jp.bin.lzsa
		rm asm/ja-jp.bin
	fi
	lzsa -f 2 -r --prefer-ratio asm/$layout.bin asm/$layout.bin.lzsa
	rm asm/$layout.bin
done
