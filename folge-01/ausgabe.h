/* Folge 1: Schalter und Hilfen für die sichtbaren Ausgaben. */
#ifndef AUSGABE_H
#define AUSGABE_H
#include <stdio.h>

extern int zeige_tokens;     /* -t: Token-Strom */
extern int zeige_schritte;   /* -r: jede Reduktion des Parsers */
extern int zeige_baum;       /* -d: Parse-Baum als Graphviz */
extern int zeilenfehler;     /* Lexer meldet Fehler in der aktuellen Zeile */

/* Parse-Baum für Graphviz: jeder Knoten bekommt eine Nummer. */
int  baum_blatt(const char *text);
int  baum_knoten(const char *regel, int k1, int k2, int k3);
void baum_ausgeben(int wurzel);

#endif
