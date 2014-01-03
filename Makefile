runme: main.pas
	clear && fpc -Ciort -gl -vw -orunme main.pas

clean:
	rm *.o runme
