# Folge 1: Was ist ein Interpreter?

*Begleitdokument zum Video. Der Code liegt in diesem Ordner. Alles hier Gezeigte ist gebaut und getestet (`make test`: 16 von 16 ok).*

## Die Frage dieser Folge

Wie wird aus dem Text `2*(3+4)` die Zahl `14`?

Antwort in drei Schritten, und genau die zeigt das Video:

```
Text  ──Flex──▶  Tokens  ──Bison──▶  Parse-Baum  ──Rechnen──▶  14
```

## Schritt 1: Der Lexer zerlegt den Text in Tokens

Der Lexer (`rechner.l`) kennt keine Grammatik. Er schneidet den Text nur in Wörter und merkt sich für jedes, wo es stand.

```
$ echo "2*(3+4)" | ./rechner -t
1:1-1  ZAHL     2
1:2-2  OP       *
1:3-3  OP       (
1:4-4  ZAHL     3
1:5-5  OP       +
1:6-6  ZAHL     4
1:7-7  OP       )
1:8-8  ENDE     \n
Ergebnis: 14
```

**Position (Zeile:Spalte) von Anfang an:** Sie kommt aus `YY_USER_ACTION`, einem Makro, das Flex vor jeder Regel ausführt. Heute dient sie nur den Fehlermeldungen, später dem Trace, DWARF und dem LSP-Server (siehe ENTSCHEIDUNGEN.md).

## Schritt 2: Der Parser erkennt die Struktur

Der Parser (`rechner.y`) bekommt die Tokens und prüft sie gegen die Grammatik:

```
ausdruck: ZAHL
        | ausdruck '+' ausdruck
        | ausdruck '-' ausdruck
        | ausdruck '*' ausdruck
        | ausdruck '/' ausdruck
        | '-' ausdruck
        | '(' ausdruck ')'
```

Die Grammatik ist mehrdeutig (`1+2*3` ließe sich zweifach lesen). Die Präzedenz-Angaben `%left '+' '-'` und `%left '*' '/'` lösen das auf. Bison meldet mit `-Wall -Wcounterexamples` **keine Konflikte**.

**Der Kernmoment für das Video:** Ein LR-Parser baut von unten nach oben. Mit `-r` sieht man, in welcher Reihenfolge er „reduziert":

```
$ echo "2*(3+4)" | ./rechner -r
reduziere  ausdruck → Zahl                    = 2
reduziere  ausdruck → Zahl                    = 3
reduziere  ausdruck → Zahl                    = 4
reduziere  ausdruck → ausdruck + ausdruck     = 7
reduziere  ausdruck → ( ausdruck )            = 7
reduziere  ausdruck → ausdruck * ausdruck     = 14
Ergebnis: 14
```

Die `2` wird zuerst erkannt, aber erst ganz zum Schluss mit dem Rest multipliziert. Dazwischen liegt sie auf dem Parser-Stack und wartet. Das ist eine schöne Animation (siehe unten).

**Bison selbst zuschauen:** Mit `-s` schaltet der Rechner Bisons eingebautes Protokoll ein (`%define parse.trace`, `yydebug = 1`, Ausgabe auf stderr). Dort steht jeder Schritt: Token lesen, schieben, reduzieren, mit Position und Wert:

```
$ echo "2*(3+4)" | ./rechner -s 2>&1 >/dev/null | grep -E "^(Reading|Next|Shifting|->)"
...
Next token is token ')' (1.7: )
-> $$ = nterm ausdruck (1.4-6: 7)
Next token is token ')' (1.7: )
Shifting token ')' (1.7: )
-> $$ = nterm ausdruck (1.3-7: 7)
-> $$ = nterm ausdruck (1.1-7: 14)
...
```

Zwei Beobachtungen aus dem Protokoll, beide im Video zu sehen:

- **Die Vorausschau entscheidet.** Nach `3 + 4` liegt `ausdruck + ausdruck` auf dem Stapel. Ob reduziert wird, weiß Bison erst, wenn es das nächste Token kennt: Bei `*` müsste es schieben (Punkt vor Strich), bei `)` reduziert es.
- **Manchmal braucht Bison keine Vorausschau.** `ausdruck * ausdruck` wird sofort reduziert, ohne das Zeilenende zu lesen: Nichts, was danach kommen kann, bindet stärker als `*`. Bison nennt das „default reduction“.

**Positionen:** `1.4-6` heißt Zeile 1, Spalten 4 bis 6, also `3+4`. Intern speichert der Rechner die Endspalte wie bei Bison und LSP üblich *hinter* dem Token (`last_column` = 7); beim Drucken ziehen Bison und `-t` eins ab.

## Schritt 3: Der Parse-Baum und das Rechnen

Mit `-d` gibt der Rechner den vollständigen Parse-Baum für Graphviz aus:

```
make baum AUSDRUCK="2*(3+4)"      # erzeugt parsebaum.svg und parsebaum.png
```

Gelbe Kästen sind Tokens (Blätter), Ellipsen sind Grammatikregeln.

In Folge 1 wird **direkt beim Reduzieren gerechnet**: Jede Regel rechnet ihr Ergebnis aus den Werten ihrer Kinder aus (`$$.wert = $1.wert * $3.wert`). Den Baum gibt es gar nicht als Datenstruktur im Speicher. Er entsteht nur in der Reihenfolge der Reduktionen.

**Brücke zu Folge 2:** Im Parse-Baum steckt viel Ballast: Klammern, Kettenknoten wie `ausdruck → 2`, das Zeilenende. Für das Rechnen braucht man nur `*(2, +(3, 4))`. Das ist der **AST**, und darum geht es in Folge 2.

## Einschub: Warum ist `7/2` gleich `3`?

Unser Rechner kennt nur ganze Zahlen (`int`, 64 Bit). Eine Division zweier ganzer Zahlen liefert wieder eine ganze Zahl: Der Rest wird **abgeschnitten**, nicht gerundet.

```
$ printf '7/2\n-7/2\n7/3\n' | ./rechner
3
-3
2
```

Bei negativen Zahlen wird **zur Null hin** abgeschnitten (`-7/2 = -3`, nicht `-4`). So machen es C (seit C99), C++ und C#, und genau das tut unser Rechner, weil er intern einfach C's `/` benutzt. Python dagegen rundet bei `//` nach unten und liefert `-4`, ein beliebter Stolperstein.

Wie die Zahlen im Speicher aussehen (Zweierkomplement) und warum es bei 64 Bit einen Überlauf gibt, zeigt das Extra-Video „Ganzzahlen im Computer“ (Folge 1.1).

## Was ein 64-Bit-`int` mit sich bringt (Stoff für eine Nebenbemerkung)

Alles ist getestet:

| Eingabe | Ergebnis | Warum |
|---|---|---|
| `7/2` | `3` | Ganzzahldivision |
| `-7/2` | `-3` | Es wird zur Null hin abgeschnitten, wie in C, C++ und C# |
| `9223372036854775807+1` | Fehler: Überlauf bei + | Wir fangen Überlauf ab, statt still falsch zu rechnen (`__builtin_add_overflow`) |
| `-9223372036854775808` | Fehler: Zahl passt nicht in 64 Bit | Wie in C: Das ist *Minus* angewandt auf `9223372036854775808`, und das passt nicht. |
| `-9223372036854775807-1` | `-9223372036854775808` | So schreibt man die kleinste Zahl |
| `(-9223372036854775807-1)/-1` | Fehler: Überlauf bei / | Der einzige Überlauf bei Division |
| `7/0` | Fehler: Division durch null | Mit Position der Null |

## Fehlerbehandlung: Weitermachen statt abbrechen

Der Parser meldet Fehler mit Position und auf Deutsch (`parse.error custom`), verwirft die kaputte Zeile (`error '\n'`) und rechnet ab der nächsten Zeile weiter:

```
$ printf '1+2*3\n2*(3+\n7/0\n-(4-6)/2\n' | ./rechner
7
2:6: Fehler: unerwartet '\n', erwartet Zahl oder '-' oder '('
3:3: Fehler: Division durch null
1
```

Das Format `Zeile:Spalte: Fehler: …` ist das gleiche wie bei gcc. Editoren wie VS Code erkennen es von Haus aus. Der Grundstein für den LSP-Server ist damit gelegt.

## Befehle zum Nachmachen

Voraussetzung: Linux (oder WSL unter Windows) mit Flex, Bison, GCC und Make; für die Baum-Bilder zusätzlich Graphviz. Unter Debian/Ubuntu: `sudo apt install flex bison gcc make graphviz`.

```
cd folge-01
make            # baut ./rechner
make test       # 16 Tests
echo "2*(3+4)" | ./rechner        # 14
echo "2*(3+4)" | ./rechner -t     # Tokens
echo "2*(3+4)" | ./rechner -r     # Reduktionen
echo "2*(3+4)" | ./rechner -s     # Bisons eigenes Protokoll (stderr)
make baum AUSDRUCK="1+2*3"        # Parse-Baum als Bild
```

## Dateien

- `rechner.l`: Lexer (52 Zeilen)
- `rechner.y`: Parser, Rechnen, Fehlermeldungen, Graphviz-Ausgabe (166 Zeilen)
- `ausgabe.h`: Schalter `-t`, `-r`, `-d` (`-s` steuert Bisons `yydebug`)
- `test.sh`: Regressionstests
- `Makefile`

## Wer hat das gemacht?

- **Idee, Stimme und Entscheidungen:** Alfred
- **Umsetzung, Animation und Code:** mit Niklaus (KI-Assistent, Claude)
- **Gebaut mit** Flex 2.6.4, Bison 3.8.2, GCC 13.3 und Manim 0.21
