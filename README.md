# Interpreterbau mit Flex und Bison

Code und Begleitdokumente zur Videoserie „Interpreterbau mit Flex und Bison“ von Alfred.
Später kommt LLVM dazu.

Jede Folge hat einen eigenen Ordner mit lauffähigem Code und einem Begleitdokument (`README.md`) zum Nachlesen.

| Folge | Thema | Video | Ordner |
|---|---|---|---|
| 1 | Was ist ein Interpreter? Ein Rechner mit Flex und Bison | [YouTube](https://youtu.be/Ejb01tQOfRw) | [`folge-01/`](folge-01/) |
| 1.1 | Ganzzahlen im Computer (Extra-Video) | folgt | [`folge-01-1/`](folge-01-1/) |

## Selbst ausprobieren

Voraussetzung: Linux (oder WSL unter Windows) mit Flex, Bison, GCC und Make.
Unter Debian/Ubuntu: `sudo apt install flex bison gcc make`

```
git clone https://github.com/ghbalf/interpreterbau-flex-bison.git
cd interpreterbau-flex-bison/folge-01
make
echo "2*(3+4)" | ./rechner
```

## Wer hat das gemacht?

- **Idee, Stimme und Entscheidungen:** Alfred
- **Umsetzung, Animation und Code:** mit Niklaus (KI-Assistent, Claude)

Lizenz: MIT (siehe `LICENSE`).
