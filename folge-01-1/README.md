# Folge 1.1: Ganzzahlen im Computer

Begleitdokument zum Extra-Video „Ganzzahlen im Computer“ (Video folgt). Es gibt keinen neuen Code: Alle Beispiele laufen mit dem Rechner aus [`folge-01/`](../folge-01/).

**Die Frage dieser Folge:** Warum meldet unser Rechner bei `9223372036854775807+1` einen Fehler, und warum kann man `-9223372036854775808` nicht direkt hinschreiben?

## 1. Bits statt Ziffern

Ein Computer kennt keine Ziffern von 0 bis 9, nur Schalter: aus = 0, an = 1. Ein Schalter ist ein Bit.

Mit 4 Bit gibt es 2⁴ = 16 Muster. Jede Stelle hat einen Wert: 8, 4, 2, 1. Ohne Vorzeichen reichen die Muster von `0000` = 0 bis `1111` = 15.

## 2. Minuszahlen: das Zweierkomplement

Der Trick: Das vorderste Bit zählt nicht plus 8, sondern **minus 8**. Alles andere bleibt gleich.

| Muster | Rechnung | Wert |
|---|---|---|
| `0111` | 0 + 4 + 2 + 1 | 7 |
| `1000` | −8 + 0 + 0 + 0 | −8 |
| `1101` | −8 + 4 + 0 + 1 | −3 |
| `1111` | −8 + 4 + 2 + 1 | −1 |

Damit reichen 4 Bit von −8 bis 7. Es gibt keine „−0“, und Addieren funktioniert für Plus- und Minuszahlen auf dieselbe Weise. Im Video sieht man das als Zahlenrad mit 16 Feldern.

## 3. Der Überlauf

Auf dem Rad von 7 einen Schritt weiter: Man landet bei −8. Das ist der Überlauf.

Mit 64 Bit ist es genauso, nur größer. Die größte Zahl ist 2⁶³ − 1 = 9 223 372 036 854 775 807 (19 Stellen, gut 9 Trillionen). Plus eins, und die Grenze ist überschritten.

In C ist der Überlauf bei vorzeichenbehafteten Ganzzahlen (`int64_t`) **nicht festgelegt** (undefined behavior): Der Compiler darf annehmen, dass er nie passiert. Unser Rechner prüft deshalb vorher mit `__builtin_add_overflow` (GCC und Clang) und meldet einen Fehler, statt eine falsche Zahl auszugeben:

```
$ echo "9223372036854775807+1" | ./rechner
1:20: Fehler: Überlauf bei +
```

## 4. Die eine Zahl zu viel

Es gibt 8 Minuszahlen (−8 bis −1), aber nur 7 Pluszahlen (1 bis 7), denn die 0 belegt ein Muster der „positiven“ Hälfte. +8 gibt es nicht.

Darum geht das hier nicht:

```
$ echo "-9223372036854775808" | ./rechner
1:2: Fehler: Zahl 9223372036854775808 passt nicht in 64 Bit
```

Der Lexer sieht zwei Tokens: das Minus und die Zahl `9223372036854775808`. Und die ist um 1 zu groß. Mit einem kleinen Umweg klappt es:

```
$ echo "-9223372036854775807-1" | ./rechner
-9223372036854775808
```

In C wird das übrigens genauso gemacht. In `stdint.h` (glibc) steht, vereinfacht:

```c
#define INT64_MIN (-9223372036854775807L - 1)
```

**Zum Weiterdenken (nicht im Video):** Die Asymmetrie erzeugt auch den einzigen Überlauf bei einer Division. Die kleinste Zahl geteilt durch −1 ergäbe +9223372036854775808, und das passt nicht:

```
$ echo "(-9223372036854775807-1)/-1" | ./rechner
1:25: Fehler: Überlauf bei /
```

## 5. Kleine Zahlen in KI-Modellen

Das 4-Bit-Rad ist keine reine Übung. Ein Sprachmodell besteht aus Milliarden von Zahlen (Gewichten). Normalerweise braucht jede 16 Bit:

- 70 Milliarden × 16 Bit = 140 GB
- 70 Milliarden × 4 Bit = 35 GB

Das Verkleinern heißt **Quantisierung**. Bei 4 Bit hat jede Zahl nur noch die 16 Felder unseres Rads. Dazu kommt ein Maßstab (eine Kommazahl pro Gruppe von Gewichten), mit dem die kleinen Zahlen wieder groß gerechnet werden, zum Beispiel −3 × 0,02 = −0,06.

Es gibt sogar Modelle, die mit nur drei Werten auskommen: −1, 0 und 1, zum Beispiel BitNet b1.58 ([Ma u. a. 2024, „The Era of 1-bit LLMs“](https://arxiv.org/abs/2402.17764)).

## Wie geht es weiter?

In Folge 2 baut der Parser einen AST (abstrakten Syntaxbaum), und gerechnet wird erst, wenn der Baum fertig ist.
