# Folge 2: AST und Tree-Walker

*Begleitdokument zur zweiten Folge. Der Code liegt in diesem Ordner (`github-repo/folge-02/`). Alles hier Gezeigte ist gebaut und getestet (`make test`: 20 von 20 ok).*

## Die Frage dieser Folge

**Warum erst einen Baum bauen, wenn man doch gleich rechnen kann?**

In [Folge 1](../folge-01/) hat der Parser beim Reduzieren sofort gerechnet. Das geht gut, solange man nur ausrechnen will. Sobald man mit dem Programm mehr vorhat, braucht man etwas, das nach dem Parsen noch da ist: einen **Baum im Speicher**. Dann kann man ihn anzeigen, mehrfach auswerten, prüfen oder später in etwas anderes übersetzen (LLVM kommt in einer späteren Folge).

```
Folge 1:  Text ─Flex─▶ Tokens ─Bison─▶ (Parse-Baum, nur flüchtig) ─Rechnen─▶ 14
Folge 2:  Text ─Flex─▶ Tokens ─Bison─▶ AST (bleibt im Speicher) ─Tree-Walker─▶ 14
```

Lexer und Grammatik sind dieselben wie in Folge 1. Neu ist nur, was der Parser mit dem Ergebnis macht: Er baut **Knoten** statt zu rechnen.

## Der AST

AST heißt *abstract syntax tree*, auf Deutsch abstrakter Syntaxbaum. „Abstrakt“, weil alles fehlt, was nur zur Schreibweise gehört: Klammern, Kettenknoten, Zeilenende. Übrig bleibt die Struktur der Rechnung.

Begriffe: Jeder Punkt im Baum ist ein **Knoten**. Der oberste heißt **Wurzel**. Die Knoten direkt darunter sind seine **Kinder**.

In `ast.h`:

```c
typedef enum { ZAHL_KNOTEN, PLUS, MINUS, MAL, GETEILT, VORZEICHEN } Knotenart;

typedef struct Knoten {
    Knotenart art;
    int64_t wert;                  /* nur bei ZAHL_KNOTEN */
    struct Knoten *links, *rechts; /* VORZEICHEN hat nur links */
    int zeile, spalte;             /* Position für Fehlermeldungen */
} Knoten;
```

- Eine **Zahl** ist ein Blatt: Sie hat einen Wert und keine Kinder.
- **Plus, Minus, Mal, Geteilt** haben zwei Kinder (`links`, `rechts`).
- Das **Vorzeichen** (`-5`) hat nur ein Kind.
- **Klammern bekommen keinen Knoten.** Sie sagen dem Parser nur, wie er gruppieren soll. Ist der Baum gebaut, steckt diese Information in seiner Form.
- Jeder Knoten merkt sich seine Position (`zeile`, `spalte`). Darum kann der Rechner auch jetzt noch sagen, *wo* die Division durch null steht, obwohl der Parser längst fertig ist.

## Der Tree-Walker

Der **Tree-Walker** geht den Baum von der Wurzel aus ab und rechnet dabei. Das ist `auswerten` in `ast.c`, eine Rekursion: Um einen Knoten auszurechnen, rechnet man zuerst seine Kinder aus und verknüpft dann deren Ergebnisse.

Für `2*(3+4)`: Die Wurzel `*` fragt ihre beiden Kinder. Die `2` antwortet sofort. Das `+` fragt seinerseits `3` und `4`, antwortet `7`, und die Wurzel rechnet `2 * 7 = 14`.

Dieselbe Überlauf- und Divisionsprüfung wie in Folge 1 steckt jetzt hier, im Tree-Walker, nicht mehr im Parser.

## Neue Befehle

| Befehl | Was er tut |
|---|---|
| `--baum` | zeigt den AST als Text, danach das Ergebnis |
| `-d` | gibt den AST für Graphviz aus (statt zu rechnen) |
| `-r` | zeigt bei jeder Reduktion, welcher Knoten entsteht |

Weiter gibt es `-t` (Tokens) und `-s` (Bisons eigenes Protokoll) aus Folge 1.

### `--baum`

```
$ echo '2*(3+4)' | ./rechner --baum
*
├── 2
└── +
    ├── 3
    └── 4
14
```

Die Klammern sind verschwunden. Dass `3+4` zuerst gerechnet wird, steht in der Form: Das `+` hängt *unter* dem `*`.

Zum Vergleich ein Ausdruck, bei dem die Reihenfolge zählt:

```
$ echo '1-2-3' | ./rechner --baum
-
├── -
│   ├── 1
│   └── 2
└── 3
-4
```

Minus bindet nach links: `(1-2)-3`. Der innere Baum hängt links.

### `-r`: Welcher Knoten entsteht?

Aus Folge 1 kennt man `-r` als Reduktionsprotokoll. Jetzt steht rechts, was der Parser dabei tut:

```
$ echo '2*(3+4)' | ./rechner -r
reduziere  ausdruck → Zahl                    baue Zahl
reduziere  ausdruck → Zahl                    baue Zahl
reduziere  ausdruck → Zahl                    baue Zahl
reduziere  ausdruck → ausdruck + ausdruck     baue +
reduziere  ausdruck → ( ausdruck )            baue nichts, reicht weiter
reduziere  ausdruck → ausdruck * ausdruck     baue *
Ergebnis: 14
```

Der Parser baut den Baum **von unten nach oben**: erst die Blätter, dann das `+`, zuletzt die Wurzel `*`. Bei der Klammer wird nichts gebaut, der Knoten für `3+4` wird nur weitergereicht.

### `-d`: der Baum als Bild

```
$ echo '2*(3+4)' | ./rechner -d
digraph ast {
  ordering=out;
  node [fontname="DejaVu Sans Mono"];
  n1 [label="*", shape=circle];
  n2 [label="2", shape=box, style=filled, fillcolor="#ffe9a8"];
  n1 -> n2;
  n3 [label="+", shape=circle];
  n4 [label="3", shape=box, style=filled, fillcolor="#ffe9a8"];
  n3 -> n4;
  n5 [label="4", shape=box, style=filled, fillcolor="#ffe9a8"];
  n3 -> n5;
  n1 -> n3;
}
```

Das ist eine Beschreibung, die [Graphviz](https://graphviz.org/) in ein Bild verwandelt. Mit installiertem Graphviz geht es in einem Schritt:

```
make baum AUSDRUCK="2*(3+4)"      # erzeugt ast.svg und ast.png
```

Operatoren sind Kreise, Zahlen gelbe Kästen. Vergleicht man das mit dem Parse-Baum aus Folge 1 (`make baum` dort), sieht man den Unterschied: Hier fehlen die Kettenknoten und die Klammern.

## Fehler bleiben, wie sie waren

Fehlermeldungen kommen unverändert mit Zeile und Spalte. Weil die Positionen im Knoten mitwandern, trifft auch eine Meldung aus dem Tree-Walker die richtige Stelle:

```
$ echo '7/0' | ./rechner
1:3: Fehler: Division durch null
```

Und bei einem Syntaxfehler wird der halbfertige Teilbaum wieder freigegeben (`%destructor` in `rechner.y`), es bleibt nichts im Speicher liegen. Das wurde mit dem AddressSanitizer geprüft.

## Tests

`test.sh` enthält 20 Tests:

- die 16 Tests aus Folge 1, **unverändert**: Von außen rechnet der Rechner genauso, nur innen läuft es jetzt über den Baum;
- 4 neue für `--baum`.

```
$ make test
...
ok    --baum 1-2-3
ok    --baum -(4-6)/2
ok    --baum 7/0
```

Der Test `--baum 7/0` prüft, was bei einem Fehler ausgegeben wird.

## Beziehung zu Folge 1

| | Folge 1 | Folge 2 |
|---|---|---|
| Lexer (`rechner.l`) | gleich | gleich |
| Grammatik | gleich | gleich |
| Aktion einer Regel | `$$ = $1 * $3` rechnet sofort | `$$ = neuer_knoten(MAL, $1, $3)` baut einen Knoten |
| Rechnen | im Parser | im Tree-Walker `auswerten` |
| Baum im Speicher | nein | ja (`ast.h`, `ast.c`) |

## Befehle zum Nachmachen

Voraussetzung wie in Folge 1: Linux (oder WSL unter Windows) mit Flex, Bison, GCC und Make; für die Bilder zusätzlich Graphviz. Unter Debian/Ubuntu: `sudo apt install flex bison gcc make graphviz`. Die Anleitung zum Selbstbauen unter Windows und macOS steht in [`INSTALLATION.md`](../INSTALLATION.md) (dort noch am Beispiel von `folge-01`, die Schritte sind für `folge-02` dieselben).

```
cd folge-02
make            # baut ./rechner
make test       # 20 Tests
echo "2*(3+4)" | ./rechner            # 14
echo "2*(3+4)" | ./rechner --baum     # Baum, dann 14
echo "2*(3+4)" | ./rechner -r         # Reduktionen mit Knoten
echo "2*(3+4)" | ./rechner -d         # Graphviz-Text
make baum AUSDRUCK="1+2*3"            # Baum als Bild
```

## Dateien

- `rechner.l`: Lexer (52 Zeilen, wie Folge 1)
- `rechner.y`: Parser, baut Knoten, Fehlermeldungen (145 Zeilen)
- `ast.h`, `ast.c`: Knoten, `auswerten`, `baum_zeigen`, `baum_graphviz` (25 + 151 Zeilen)
- `ausgabe.h`: Schalter `--baum`, `-t`, `-r`, `-d`, `-s`
- `test.sh`: Regressionstests
- `Makefile`

## Ausblick

**Folge 3** bringt Variablen in die Sprache. Dann reicht ein Baum allein nicht mehr: Der Tree-Walker braucht ein Gedächtnis dafür, welcher Name welchen Wert hat. Später kommt LLVM dazu, und der AST ist die Stelle, an der aus dem Baum Maschinencode wird.

## Wer hat das gemacht?

- **Idee, Stimme und Entscheidungen:** Alfred
- **Umsetzung, Animation und Code:** mit Niklaus (KI-Assistent, Claude)
- **Gebaut mit** Flex, Bison und GCC (Versionen siehe Folge 1)
