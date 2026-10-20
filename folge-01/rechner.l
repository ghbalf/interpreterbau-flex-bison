/* Folge 1: Lexer des Rechners.
 * Zerlegt den Eingabetext in Tokens und merkt sich für jedes Token
 * Zeile und Spalte (yylloc). Im Modus -t werden die Tokens ausgegeben,
 * im Modus -d bekommt jedes Token einen Blattknoten im Parse-Baum. */
%{
#include <errno.h>
#include <stdlib.h>
#include "rechner.tab.h"
#include "ausgabe.h"

static int zeile = 1, spalte = 1;

/* Läuft vor jeder Regel: Position des aktuellen Tokens setzen.
 * Wie bei Bison üblich zeigt last_column HINTER das Token (exklusiv);
 * genauso zählt später auch LSP. */
#define YY_USER_ACTION                                  \
    yylloc.first_line = yylloc.last_line = zeile;       \
    yylloc.first_column = spalte;                       \
    yylloc.last_column = spalte + yyleng;                \
    spalte += yyleng;

static int token(int art, const char *name)
{
    yylval.knoten = baum_blatt(yytext[0] == '\n' ? "↵" : yytext);
    if (zeige_tokens)
        printf("%d:%d-%d  %-8s %s\n", yylloc.first_line, yylloc.first_column,
               yylloc.last_column - 1, name, yytext[0] == '\n' ? "\\n" : yytext);
    return art;
}
%}
%option noyywrap nodefault nounput noinput
%%
[0-9]+      {
                errno = 0;
                long long w = strtoll(yytext, NULL, 10);
                if (errno == ERANGE) {
                    fprintf(stderr, "%d:%d: Fehler: Zahl %s passt nicht in 64 Bit\n",
                            yylloc.first_line, yylloc.first_column, yytext);
                    w = 0;
                    zeilenfehler = 1;
                }
                int art = token(ZAHL, "ZAHL");
                yylval.wert = w;
                return art;
            }
[-+*/()]    { return token(yytext[0], "OP"); }
\n          { int art = token('\n', "ENDE"); zeile++; spalte = 1; return art; }
[ \t\r]+    ;
.           {
                fprintf(stderr, "%d:%d: Fehler: unbekanntes Zeichen '%s'\n",
                        yylloc.first_line, yylloc.first_column, yytext);
                zeilenfehler = 1;
            }
%%
