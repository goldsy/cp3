#include <stdio.h>

extern FILE *yyin, *yyout;
extern char *yytext;
extern int yynewlines;

int yylex(void);   /* function prototype */

void yyerror(char *s)
{
  if ( *yytext == '\0' )
    fprintf(stderr, "line %d: %s near end of file\n", 
	    yynewlines,s);
  else
    fprintf(stderr, "line %d: %s near %s\n",
	    yynewlines, s, yytext);
}


int main(int argc, char *argv[]) {
    ++argv, --argc;   /* skip over program name */

    if (argc > 0) {
        printf("argv[0]: %s\n", argv[0]);
        yyin = fopen(argv[0], "r");
    }
    else {
        yyin = stdin;
    }

    int typeId = yylex();

    while (typeId) {
        printf("Token: %d <value:> %s\n", typeId, yytext);
        typeId = yylex();
    }
}

