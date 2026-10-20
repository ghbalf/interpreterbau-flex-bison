/* Folge 1: Parser des Rechners.
 * Rechnet direkt beim Reduzieren (noch kein AST, der kommt in Folge 2).
 * Nebenbei entstehen zwei Sichtbarkeiten für das Video:
 *   -r  die Reihenfolge der Reduktionen (so baut ein LR-Parser von unten auf)
 *   -d  der vollständige Parse-Baum als Graphviz-Datei */
%code requires {
#include <stdint.h>
typedef struct { int64_t wert; int knoten; } Wert;
}
%{
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "ausgabe.h"
int yylex(void);
void yyerror(const char *s);

int zeige_tokens, zeige_schritte, zeige_baum;
static int fehler_gesamt;
int zeilenfehler;   /* vom Lexer gesetzt: Zeile hat einen Fehler, kein Ergebnis */

/* Laufzeitfehler mit Position melden und die Zeile verwerfen. */
#define LAUFZEITFEHLER(ort, ...) do {                                    \
        fprintf(stderr, "%d:%d: Fehler: ", (ort).first_line, (ort).first_column); \
        fprintf(stderr, __VA_ARGS__); fputc('\n', stderr);               \
        fehler_gesamt++; YYERROR; } while (0)

static void schritt(const char *regel, int64_t ergebnis)
{
    if (zeige_schritte)
        printf("reduziere  %-36s = %lld\n", regel, (long long)ergebnis);
}
%}

%define api.value.type {Wert}
%define parse.error custom
%locations
%define parse.trace
%printer { fprintf(yyo, "%lld", (long long)$$.wert); } ZAHL ausdruck

%token ENDE 0 "Dateiende"
%token ZAHL "Zahl"
%left '+' '-'
%left '*' '/'
%precedence NEG

%%
eingabe: %empty
       | eingabe zeile
       ;

zeile: '\n'           { zeilenfehler = 0; }
     | ausdruck '\n'   { if (zeilenfehler) { zeilenfehler = 0; fehler_gesamt++; }
                         else if (zeige_baum)
                             baum_ausgeben(baum_knoten("zeile", $1.knoten, $2.knoten, 0));
                         else if (!zeige_tokens && !zeige_schritte)
                             printf("%lld\n", (long long)$1.wert);
                         else
                             printf("Ergebnis: %lld\n", (long long)$1.wert); }
     | error '\n'      { yyerrok; zeilenfehler = 0; }
     ;

ausdruck: ZAHL                     { $$.wert = $1.wert;
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, 0, 0);
                                     schritt("ausdruck → Zahl", $$.wert); }
        | ausdruck '+' ausdruck    { if (__builtin_add_overflow($1.wert, $3.wert, &$$.wert))
                                         LAUFZEITFEHLER(@2, "Überlauf bei +");
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, $2.knoten, $3.knoten);
                                     schritt("ausdruck → ausdruck + ausdruck", $$.wert); }
        | ausdruck '-' ausdruck    { if (__builtin_sub_overflow($1.wert, $3.wert, &$$.wert))
                                         LAUFZEITFEHLER(@2, "Überlauf bei -");
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, $2.knoten, $3.knoten);
                                     schritt("ausdruck → ausdruck - ausdruck", $$.wert); }
        | ausdruck '*' ausdruck    { if (__builtin_mul_overflow($1.wert, $3.wert, &$$.wert))
                                         LAUFZEITFEHLER(@2, "Überlauf bei *");
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, $2.knoten, $3.knoten);
                                     schritt("ausdruck → ausdruck * ausdruck", $$.wert); }
        | ausdruck '/' ausdruck    { if ($3.wert == 0)
                                         LAUFZEITFEHLER(@3, "Division durch null");
                                     if ($1.wert == INT64_MIN && $3.wert == -1)
                                         LAUFZEITFEHLER(@2, "Überlauf bei /");
                                     $$.wert = $1.wert / $3.wert;
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, $2.knoten, $3.knoten);
                                     schritt("ausdruck → ausdruck / ausdruck", $$.wert); }
        | '-' ausdruck %prec NEG   { if ($2.wert == INT64_MIN)
                                         LAUFZEITFEHLER(@1, "Überlauf bei Vorzeichenwechsel");
                                     $$.wert = -$2.wert;
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, $2.knoten, 0);
                                     schritt("ausdruck → - ausdruck", $$.wert); }
        | '(' ausdruck ')'         { $$.wert = $2.wert;
                                     $$.knoten = baum_knoten("ausdruck", $1.knoten, $2.knoten, $3.knoten);
                                     schritt("ausdruck → ( ausdruck )", $$.wert); }
        ;
%%

/* Syntaxfehler auf Deutsch, mit Position und erwarteten Tokens. */
static int yyreport_syntax_error(const yypcontext_t *ctx)
{
    const YYLTYPE *ort = yypcontext_location(ctx);
    yysymbol_kind_t erwartet[5];
    int n = yypcontext_expected_tokens(ctx, erwartet, 5);
    yysymbol_kind_t gefunden = yypcontext_token(ctx);

    fprintf(stderr, "%d:%d: Fehler: unerwartet %s", ort->first_line, ort->first_column,
            gefunden == YYSYMBOL_YYEMPTY ? "Ende" : yysymbol_name(gefunden));
    for (int i = 0; i < n; i++)
        fprintf(stderr, "%s%s", i == 0 ? ", erwartet " : " oder ", yysymbol_name(erwartet[i]));
    fputc('\n', stderr);
    fehler_gesamt++;
    return 0;
}

void yyerror(const char *s) { fprintf(stderr, "Fehler: %s\n", s); fehler_gesamt++; }

/* ---- Parse-Baum für Graphviz ---- */
static char *baum_text;
static size_t baum_laenge;
static FILE *baum;
static int naechste_nummer;

static void baum_start(void)
{
    if (!baum) baum = open_memstream(&baum_text, &baum_laenge);
}

int baum_blatt(const char *text)
{
    if (!zeige_baum) return 0;
    baum_start();
    int nr = ++naechste_nummer;
    fprintf(baum, "  n%d [label=\"%s\", shape=box, style=filled, fillcolor=\"#ffe9a8\"];\n", nr, text);
    return nr;
}

int baum_knoten(const char *regel, int k1, int k2, int k3)
{
    if (!zeige_baum) return 0;
    baum_start();
    int nr = ++naechste_nummer;
    fprintf(baum, "  n%d [label=\"%s\"];\n", nr, regel);
    int kinder[] = { k1, k2, k3 };
    for (int i = 0; i < 3; i++)
        if (kinder[i]) fprintf(baum, "  n%d -> n%d;\n", nr, kinder[i]);
    return nr;
}

void baum_ausgeben(int wurzel)
{
    (void)wurzel;
    fflush(baum);
    printf("digraph parsebaum {\n  ordering=out;\n  node [fontname=\"DejaVu Sans Mono\"];\n%s}\n", baum_text);
    fclose(baum); free(baum_text);
    baum = NULL; baum_text = NULL; naechste_nummer = 0;
}

int main(int argc, char **argv)
{
    for (int i = 1; i < argc; i++) {
        if      (!strcmp(argv[i], "-t")) zeige_tokens = 1;
        else if (!strcmp(argv[i], "-r")) zeige_schritte = 1;
        else if (!strcmp(argv[i], "-d")) zeige_baum = 1;
        else if (!strcmp(argv[i], "-s")) yydebug = 1;   /* Bisons eigenes Protokoll (stderr) */
        else { fprintf(stderr, "Aufruf: %s [-t] [-r] [-d] [-s] < eingabe\n", argv[0]); return 2; }
    }
    setvbuf(stdout, NULL, _IOLBF, 0);   /* Ergebnisse und Fehler in richtiger Reihenfolge */
    yyparse();
    return fehler_gesamt ? 1 : 0;
}
