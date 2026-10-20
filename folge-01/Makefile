CFLAGS = -Wall -Wextra -O2
FLEX  ?= flex
BISON ?= bison

rechner: rechner.tab.c lex.yy.c ausgabe.h
	$(CC) $(CFLAGS) -o $@ rechner.tab.c lex.yy.c $(LDFLAGS)

rechner.tab.c rechner.tab.h: rechner.y
	$(BISON) -Wall -Wcounterexamples -d rechner.y

lex.yy.c: rechner.l rechner.tab.h
	$(FLEX) rechner.l

# Parse-Baum als Bild, z. B.: make baum AUSDRUCK="2*(3+4)"
AUSDRUCK ?= 2*(3+4)
baum: rechner
	echo "$(AUSDRUCK)" | ./rechner -d | dot -Tsvg -o parsebaum.svg
	echo "$(AUSDRUCK)" | ./rechner -d | dot -Tpng -o parsebaum.png

test: rechner
	./test.sh

clean:
	rm -f rechner rechner.exe rechner.tab.* lex.yy.c parsebaum.svg parsebaum.png

.PHONY: baum test clean
