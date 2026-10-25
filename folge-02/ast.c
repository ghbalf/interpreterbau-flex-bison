/* Folge 2: Knoten anlegen, auswerten (der Tree-Walker) und anzeigen. */
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"

static Knoten *anlegen(Knotenart art, int zeile, int spalte)
{
    Knoten *k = calloc(1, sizeof *k);
    if (!k) { perror("calloc"); exit(1); }
    k->art = art;
    k->zeile = zeile;
    k->spalte = spalte;
    return k;
}

Knoten *neue_zahl(int64_t wert, int zeile, int spalte)
{
    Knoten *k = anlegen(ZAHL_KNOTEN, zeile, spalte);
    k->wert = wert;
    return k;
}

Knoten *neuer_knoten(Knotenart art, Knoten *links, Knoten *rechts, int zeile, int spalte)
{
    Knoten *k = anlegen(art, zeile, spalte);
    k->links = links;
    k->rechts = rechts;
    return k;
}

void baum_freigeben(Knoten *k)
{
    if (!k) return;
    baum_freigeben(k->links);
    baum_freigeben(k->rechts);
    free(k);
}

/* ---- Der Tree-Walker ---- */

static int fehler(const Knoten *k, const char *text)
{
    fprintf(stderr, "%d:%d: Fehler: %s\n", k->zeile, k->spalte, text);
    return 0;
}

int auswerten(const Knoten *k, int64_t *ergebnis)
{
    int64_t links, rechts;

    if (k->art == ZAHL_KNOTEN) {
        *ergebnis = k->wert;
        return 1;
    }
    if (!auswerten(k->links, &links))
        return 0;
    if (k->art == VORZEICHEN) {
        if (links == INT64_MIN)
            return fehler(k, "Überlauf bei Vorzeichenwechsel");
        *ergebnis = -links;
        return 1;
    }
    if (!auswerten(k->rechts, &rechts))
        return 0;

    switch (k->art) {
    case PLUS:
        if (__builtin_add_overflow(links, rechts, ergebnis)) return fehler(k, "Überlauf bei +");
        return 1;
    case MINUS:
        if (__builtin_sub_overflow(links, rechts, ergebnis)) return fehler(k, "Überlauf bei -");
        return 1;
    case MAL:
        if (__builtin_mul_overflow(links, rechts, ergebnis)) return fehler(k, "Überlauf bei *");
        return 1;
    case GETEILT:
        if (rechts == 0)
            return fehler(k->rechts, "Division durch null");
        if (links == INT64_MIN && rechts == -1)
            return fehler(k, "Überlauf bei /");
        *ergebnis = links / rechts;
        return 1;
    default:
        return fehler(k, "unbekannter Knoten");
    }
}

/* ---- Anzeigen ---- */

static const char *zeichen(const Knoten *k)
{
    switch (k->art) {
    case PLUS:       return "+";
    case MINUS:      return "-";
    case MAL:        return "*";
    case GETEILT:    return "/";
    case VORZEICHEN: return "- (Vorzeichen)";
    default:         return "?";
    }
}

static void zeile_zeigen(const Knoten *k)
{
    if (k->art == ZAHL_KNOTEN) printf("%lld\n", (long long)k->wert);
    else                       printf("%s\n", zeichen(k));
}

/* einrueckung: was links vor den Kindern steht ("│   " oder "    " je Ebene) */
static void kinder_zeigen(const Knoten *k, char *einrueckung, size_t laenge)
{
    const Knoten *kinder[2] = { k->links, k->rechts };
    int anzahl = k->rechts ? 2 : (k->links ? 1 : 0);

    for (int i = 0; i < anzahl; i++) {
        int letztes = (i == anzahl - 1);
        printf("%s%s", einrueckung, letztes ? "└── " : "├── ");
        zeile_zeigen(kinder[i]);
        size_t neu = laenge + snprintf(einrueckung + laenge, 1024 - laenge, "%s",
                                       letztes ? "    " : "│   ");
        kinder_zeigen(kinder[i], einrueckung, neu);
        einrueckung[laenge] = '\0';
    }
}

void baum_zeigen(const Knoten *wurzel)
{
    char einrueckung[1024] = "";
    zeile_zeigen(wurzel);
    kinder_zeigen(wurzel, einrueckung, 0);
}

static int graphviz_knoten(const Knoten *k, int *nummer)
{
    int nr = ++*nummer;
    if (k->art == ZAHL_KNOTEN)
        printf("  n%d [label=\"%lld\", shape=box, style=filled, fillcolor=\"#ffe9a8\"];\n",
               nr, (long long)k->wert);
    else
        printf("  n%d [label=\"%s\", shape=circle];\n", nr, zeichen(k));
    if (k->links)  printf("  n%d -> n%d;\n", nr, graphviz_knoten(k->links, nummer));
    if (k->rechts) printf("  n%d -> n%d;\n", nr, graphviz_knoten(k->rechts, nummer));
    return nr;
}

void baum_graphviz(const Knoten *wurzel)
{
    int nummer = 0;
    printf("digraph ast {\n  ordering=out;\n  node [fontname=\"DejaVu Sans Mono\"];\n");
    graphviz_knoten(wurzel, &nummer);
    printf("}\n");
}
