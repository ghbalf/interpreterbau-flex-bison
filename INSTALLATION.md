# Selbst ausprobieren: Windows, macOS, Linux

Es gibt zwei Wege:

- **A: Nur ausprobieren.** Ein fertiges Programm herunterladen und starten. Nichts wird installiert. Zum Entfernen löscht man den Ordner.
- **B: Selbst bauen.** Für alle, die am Code mitbasteln wollen. Dafür braucht man Flex, Bison und einen C-Compiler. Die Anleitung unten installiert sie so, dass sie an *einer* Stelle liegen und sich vollständig wieder entfernen lassen.

---

## A: Nur ausprobieren (fertiges Programm)

Die fertigen Programme liegen unter **[Releases](https://github.com/ghbalf/interpreterbau-flex-bison/releases)**. Nimm die ZIP-Datei für dein System:

| System | Datei |
|---|---|
| Windows 10/11 | `rechner-windows-x86_64.zip` |
| macOS (Apple-Chip und Intel) | `rechner-macos-universal.zip` |
| Linux | `rechner-linux-x86_64.zip` |

### Windows

1. ZIP-Datei herunterladen, mit Rechtsklick → **Alle extrahieren**.
2. Im entpackten Ordner auf `rechner.exe` doppelklicken.
3. Windows warnt beim ersten Start: „Der Computer wurde durch Windows geschützt“. Das liegt daran, dass das Programm nicht kostenpflichtig signiert ist. Klick auf **Weitere Informationen** → **Trotzdem ausführen**.
4. Ein schwarzes Fenster öffnet sich. Tipp `2*(3+4)` ein und drück Enter. Es erscheint `14`.
5. Beenden: Fenster schließen.

Die Schalter aus dem Video (`-t`, `-r`, `-s`) gehen in der Eingabeaufforderung: Im entpackten Ordner in die Adresszeile `cmd` tippen und Enter drücken, dann:

```
echo 2*(3+4) | rechner -t
```

**Wieder loswerden:** ZIP-Datei und entpackten Ordner löschen. Sonst wurde nichts verändert.

### macOS

1. ZIP-Datei herunterladen. Safari entpackt sie meist selbst in den Ordner **Downloads**.
2. Programm **Terminal** öffnen (Spotlight: ⌘ + Leertaste, „Terminal“).
3. Diese Zeilen eintippen:

```
cd ~/Downloads/rechner-macos-universal
xattr -d com.apple.quarantine rechner     # macOS-Sperre für Programme aus dem Netz aufheben
./rechner
```

4. `2*(3+4)` eintippen, Enter. Es erscheint `14`. Beenden mit **ctrl + D**.

**Wieder loswerden:** den Ordner `rechner-macos-universal` und die ZIP-Datei in den Papierkorb legen.

### Linux

```
cd ~/Downloads && unzip rechner-linux-x86_64.zip -d rechner && cd rechner
./rechner
```

**Wieder loswerden:** `rm -r ~/Downloads/rechner ~/Downloads/rechner-linux-x86_64.zip`

---

## B: Selbst bauen

Überall gleich am Ende: Im Ordner `folge-01` bauen und testen mit

```
make
./test.sh          # 16 Tests, alle "ok"
echo "2*(3+4)" | ./rechner
```

Genau diese Schritte laufen bei jeder Änderung automatisch auf Windows, macOS und Linux (GitHub Actions, Datei `.github/workflows/bauen.yml`). Wenn dort alles grün ist, funktioniert auch diese Anleitung.

### Windows: MSYS2 (alles in einem Ordner)

MSYS2 ist eine kleine Linux-artige Umgebung für Windows. Alles landet in `C:\msys64`. Windows selbst wird nicht verändert.

1. Installationsprogramm von **[msys2.org](https://www.msys2.org/)** herunterladen und mit den Vorgaben installieren (kostenlos).
2. Im Startmenü **MSYS2 UCRT64** öffnen (nicht „MSYS2 MSYS“).
3. Werkzeuge installieren (etwa 300 MB):

```
pacman -S --needed make flex bison git mingw-w64-ucrt-x86_64-gcc
```

4. Code holen und bauen:

```
git clone https://github.com/ghbalf/interpreterbau-flex-bison.git
cd interpreterbau-flex-bison/folge-01
make
./test.sh
```

**Wieder loswerden:** Windows-Einstellungen → **Apps** → **MSYS2** → **Deinstallieren**. Damit verschwindet `C:\msys64` mit allen Werkzeugen und dem Code. Falls der Ordner danach noch da ist, kann man ihn einfach löschen.

*Alternative für Fortgeschrittene:* WSL (ein echtes Ubuntu in Windows): `wsl --install -d Ubuntu` in einer Administrator-Eingabeaufforderung, danach weiter wie unter Linux. Wieder loswerden: `wsl --unregister Ubuntu`.

### macOS: Apple-Werkzeuge + Homebrew

macOS bringt Flex und einen C-Compiler mit, aber nur ein uraltes Bison (2.3 von 2006). Das neue Bison holen wir über Homebrew. Homebrew legt alles unter `/opt/homebrew` (Apple-Chip) bzw. `/usr/local` (Intel) ab.

1. Apple-Werkzeuge (Compiler, Make, Flex, Git). Oft schon vorhanden; sonst im Terminal:

```
xcode-select --install
```

2. Homebrew installieren, falls noch nicht da: Befehl von **[brew.sh](https://brew.sh/)** kopieren und im Terminal ausführen.
3. Bison installieren, Code holen und bauen:

```
brew install bison
git clone https://github.com/ghbalf/interpreterbau-flex-bison.git
cd interpreterbau-flex-bison/folge-01
make BISON="$(brew --prefix bison)/bin/bison"
./test.sh
```

Das `BISON=…` ist nötig, weil Homebrew sein Bison absichtlich nicht vor das alte von Apple stellt.

**Wieder loswerden:**

```
brew uninstall bison                          # nur Bison
rm -rf ~/interpreterbau-flex-bison            # der Code (Pfad anpassen, falls woanders)
```

Hast du Homebrew nur hierfür installiert, entfernt es dieser Befehl komplett (von brew.sh):

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
```

Die Apple-Werkzeuge nutzen viele Programme mit; die würde ich behalten. Wer sie trotzdem entfernen will: `sudo rm -rf /Library/Developer/CommandLineTools`.

### Linux: im Wegwerf-Container (nichts wird installiert)

Mit Docker oder Podman läuft alles in einem Container, der nach dem Befehl wieder verschwindet. Im Ordner `folge-01`:

```
docker run --rm -it -v "$PWD":/work -w /work ubuntu:24.04 \
  bash -c "apt-get update -qq && apt-get install -y -qq flex bison gcc make >/dev/null && make && ./test.sh"
```

(`podman` statt `docker` geht genauso.)

**Wieder loswerden:** `docker rmi ubuntu:24.04` entfernt das heruntergeladene Ubuntu-Abbild; `make clean` die gebauten Dateien im Ordner.

Ohne Container, direkt installiert (Debian/Ubuntu):

```
sudo apt install flex bison gcc make git
```

Wieder loswerden: `sudo apt remove flex bison && sudo apt autoremove` (GCC, Make und Git braucht das System oft selbst; die würde ich behalten).
