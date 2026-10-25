#!/bin/sh
# Folge 2: Regressionstests für den Rechner. Aufruf: ./test.sh (oder make test)
fehler=0
pruefe() {  # pruefe "Eingabe" "erwartete Ausgabe (stdout+stderr)"
    ist=$(printf '%s\n' "$1" | ./rechner 2>&1 | tr -d '\r')   # tr: Windows schreibt \r\n
    if [ "$ist" = "$2" ]; then echo "ok    $1"
    else echo "FEHLT $1"; echo "      erwartet: $2"; echo "      erhalten: $ist"; fehler=1; fi
}
pruefe "2*(3+4)"      "14"
pruefe "1+2*3"        "7"
pruefe "(1+2)*3"      "9"
pruefe "10-4-3"       "3"
pruefe "100/10/5"     "2"
pruefe "7/2"          "3"
pruefe "-7/2"         "-3"
pruefe "-(4-6)/2"     "1"
pruefe "--5"          "5"
pruefe "9223372036854775807" "9223372036854775807"
pruefe "7/0"          "1:3: Fehler: Division durch null"
pruefe "9223372036854775807+1" "1:20: Fehler: Überlauf bei +"
pruefe "99999999999999999999"  "1:1: Fehler: Zahl 99999999999999999999 passt nicht in 64 Bit"
pruefe "2*(3+"        "1:6: Fehler: unerwartet '\n', erwartet Zahl oder '-' oder '('"
pruefe "$(printf '$\n1+1')" "1:1: Fehler: unbekanntes Zeichen '\$'
2"
pruefe "$(printf '7/0\n1+1')" "1:3: Fehler: Division durch null
2"
# Neu in Folge 2: der AST mit --baum. Die Tests oben sind unverändert aus Folge 1:
# Von außen rechnet der Rechner genauso, nur innen erst über den Baum.
pruefe_baum() {  # pruefe_baum "Eingabe" "erwartete Ausgabe"
    ist=$(printf '%s\n' "$1" | ./rechner --baum 2>&1 | tr -d '\r')
    if [ "$ist" = "$2" ]; then echo "ok    --baum $1"
    else echo "FEHLT --baum $1"; echo "      erwartet:"; echo "$2"; echo "      erhalten:"; echo "$ist"; fehler=1; fi
}
pruefe_baum "2*(3+4)" "*
├── 2
└── +
    ├── 3
    └── 4
14"
pruefe_baum "1-2-3" "-
├── -
│   ├── 1
│   └── 2
└── 3
-4"
pruefe_baum "-(4-6)/2" "/
├── - (Vorzeichen)
│   └── -
│       ├── 4
│       └── 6
└── 2
1"
pruefe_baum "7/0" "/
├── 7
└── 0
1:3: Fehler: Division durch null"
exit $fehler
