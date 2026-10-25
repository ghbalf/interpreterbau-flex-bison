/* Folge 2: Parser des Rechners.
 * Neu gegenüber Folge 1: Der Parser rechnet nicht mehr beim Reduzieren,
 * er baut einen AST (ast.h). Gerechnet wird erst, wenn die Zeile fertig
 * gelesen ist: auswerten() geht den Baum ab.
 *   --baum  der AST als Text, danach das Ergebnis
 *   -d      der AST als Graphviz-Datei
 *   -r      die Reduktionen, jetzt mit dem Knoten, der dabei entsteht */
%code requires {
#include "ast.h"
}
%{
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "ast.h"
#include "ausgabe.h"
#ifdef _WIN32                      /* Windows: Konsole auf UTF-8 (für „Überlauf“ und └──), isatty heißt dort _isatty */
#include <io.h>
#include <windows.h>
#define isatty _isatty
#define fileno _fileno
#else
#include <unistd.h>
#endif
int yylex(void);
void yyerror(const char *s);

int zeige_tokens, zeige_schritte, zeige_baum, zeige_graphviz;
static int fehler_gesamt;
int zeilenfehler;   /* vom Lexer gesetzt: Zeile hat einen Fehler, kein Ergebnis */

static void schritt(const char *regel, const char *knoten)
{
    if (zeige_schritte)
        printf("reduziere  %-36s baue %s\n", regel, knoten);
}

/* Zeile fertig gelesen: jetzt erst wird gerechnet. */
static void zeile_fertig(Knoten *baum)
{
    int64_t ergebnis;
    if (zeige_graphviz)
        baum_graphviz(baum);
    else {
        if (zeige_baum)
            baum_zeigen(baum);
        if (auswerten(baum, &ergebnis))
            printf(zeige_tokens || zeige_schritte ? "Ergebnis: %lld\n" : "%lld\n",
                   (long long)ergebnis);
        else
            fehler_gesamt++;
    }
    baum_freigeben(baum);
}
%}

%union {
    int64_t zahl;
    Knoten *knoten;
}
%define parse.error custom
%locations
%define parse.trace
%printer { fprintf(yyo, "%lld", (long long)$$); } <zahl>

%token ENDE 0 "Dateiende"
%token <zahl> ZAHL "Zahl"
%nterm <knoten> ausdruck
/* Bei Syntaxfehlern wirft Bison halbfertige Teilbäume weg; so werden sie freigegeben. */
%destructor { baum_freigeben($$); } <knoten>
%left '+' '-'
%left '*' '/'
%precedence NEG

%%
eingabe: %empty
       | eingabe zeile
       ;

zeile: '\n'           { zeilenfehler = 0; }
     | ausdruck '\n'   { if (zeilenfehler) { zeilenfehler = 0; fehler_gesamt++; baum_freigeben($1); }
                         else zeile_fertig($1); }
     | error '\n'      { yyerrok; zeilenfehler = 0; }
     ;

ausdruck: ZAHL                     { $$ = neue_zahl($1, @1.first_line, @1.first_column);
                                     schritt("ausdruck → Zahl", "Zahl"); }
        | ausdruck '+' ausdruck    { $$ = neuer_knoten(PLUS, $1, $3, @2.first_line, @2.first_column);
                                     schritt("ausdruck → ausdruck + ausdruck", "+"); }
        | ausdruck '-' ausdruck    { $$ = neuer_knoten(MINUS, $1, $3, @2.first_line, @2.first_column);
                                     schritt("ausdruck → ausdruck - ausdruck", "-"); }
        | ausdruck '*' ausdruck    { $$ = neuer_knoten(MAL, $1, $3, @2.first_line, @2.first_column);
                                     schritt("ausdruck → ausdruck * ausdruck", "*"); }
        | ausdruck '/' ausdruck    { $$ = neuer_knoten(GETEILT, $1, $3, @2.first_line, @2.first_column);
                                     schritt("ausdruck → ausdruck / ausdruck", "/"); }
        | '-' ausdruck %prec NEG   { $$ = neuer_knoten(VORZEICHEN, $2, NULL, @1.first_line, @1.first_column);
                                     schritt("ausdruck → - ausdruck", "- (Vorzeichen)"); }
        | '(' ausdruck ')'         { $$ = $2;   /* Klammern brauchen keinen Knoten: Die Form des Baums sagt schon alles */
                                     schritt("ausdruck → ( ausdruck )", "nichts, reicht weiter"); }
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

int main(int argc, char **argv)
{
    for (int i = 1; i < argc; i++) {
        if      (!strcmp(argv[i], "-t")) zeige_tokens = 1;
        else if (!strcmp(argv[i], "-r")) zeige_schritte = 1;
        else if (!strcmp(argv[i], "--baum")) zeige_baum = 1;
        else if (!strcmp(argv[i], "-d")) zeige_graphviz = 1;
        else if (!strcmp(argv[i], "-s")) yydebug = 1;   /* Bisons eigenes Protokoll (stderr) */
        else { fprintf(stderr, "Aufruf: %s [--baum] [-t] [-r] [-d] [-s] < eingabe\n", argv[0]); return 2; }
    }
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
#endif
    if (isatty(fileno(stdin)))          /* von Hand gestartet, z. B. per Doppelklick: kurz sagen, was geht */
        fprintf(stderr, "Rechner aus Folge 2. Ausdruck eingeben, z. B. 2*(3+4), dann Enter.\n"
#ifdef _WIN32
                        "Beenden: Strg+Z, dann Enter (oder Fenster schließen).\n");
#else
                        "Beenden: Strg+D.\n");
#endif
    setvbuf(stdout, NULL, _IOLBF, 0);   /* Ergebnisse und Fehler in richtiger Reihenfolge */
    yyparse();
    return fehler_gesamt ? 1 : 0;
}
