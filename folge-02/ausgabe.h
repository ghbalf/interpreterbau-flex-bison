/* Folge 2: Schalter für die sichtbaren Ausgaben. */
#ifndef AUSGABE_H
#define AUSGABE_H

extern int zeige_tokens;     /* -t: Token-Strom */
extern int zeige_schritte;   /* -r: jede Reduktion des Parsers (und welcher Knoten entsteht) */
extern int zeige_baum;       /* --baum: der AST als Text */
extern int zeige_graphviz;   /* -d: der AST als Graphviz */
extern int zeilenfehler;     /* Lexer meldet Fehler in der aktuellen Zeile */

#endif
