/* Folge 2: der abstrakte Syntaxbaum (AST).
 * Der Parser rechnet nicht mehr, er baut nur Knoten. Gerechnet wird danach,
 * wenn der Baum fertig ist: auswerten() geht ihn von der Wurzel aus ab. */
#ifndef AST_H
#define AST_H
#include <stdint.h>

typedef enum { ZAHL_KNOTEN, PLUS, MINUS, MAL, GETEILT, VORZEICHEN } Knotenart;

typedef struct Knoten {
    Knotenart art;
    int64_t wert;                  /* nur bei ZAHL_KNOTEN */
    struct Knoten *links, *rechts; /* VORZEICHEN hat nur links */
    int zeile, spalte;             /* Position für Fehlermeldungen */
} Knoten;

Knoten *neue_zahl(int64_t wert, int zeile, int spalte);
Knoten *neuer_knoten(Knotenart art, Knoten *links, Knoten *rechts, int zeile, int spalte);
void    baum_freigeben(Knoten *k);

int  auswerten(const Knoten *k, int64_t *ergebnis);   /* 1 = gut, 0 = Fehler (schon gemeldet) */
void baum_zeigen(const Knoten *wurzel);                /* --baum: als Text */
void baum_graphviz(const Knoten *wurzel);              /* -d: als Graphviz-Datei */

#endif
