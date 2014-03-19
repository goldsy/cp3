%{
    // Definiions
%}
%{
#include <stdio.h>
#include "ice9.tab.h"

extern void yyerror(const char *s);
int yynewlines=1;

%}

%%

%{
    // Rules
%}

if      return TK_IF;
fi      return TK_FI;
else    return TK_ELSE;
do      return TK_DO;
od      return TK_OD;
fa      return TK_FA;
af      return TK_AF;
to      return TK_TO;
proc    return TK_PROC;
end     return TK_END;
return  return TK_RETURN;
forward return TK_FORWARD;
var     return TK_VAR;
type    return TK_TYPE;
break   return TK_BREAK;
exit    return TK_EXIT;
true    return TK_TRUE;
false   return TK_FALSE;
write   return TK_WRITE;
writes  return TK_WRITES;
read    return TK_READ;
"[]"    return TK_BOX;
"->"    return TK_ARROW;
"("     return TK_LPAREN;
")"     return TK_RPAREN;
"["     return TK_LBRACK;
"]"     return TK_RBRACK;
:       return TK_COLON;
;       return TK_SEMI;
:=      return TK_ASSIGN;
"?"     return TK_QUEST;
,       return TK_COMMA;
"+"     return TK_PLUS;
"-"     return TK_MINUS;
"*"     return TK_STAR;
"/"     return TK_SLASH;
"%"     return TK_MOD;
"="     return TK_EQ;
"!="    return TK_NEQ;
">"     return TK_GT;
"<"     return TK_LT;
">="    return TK_GE;
"<="    return TK_LE;

%{
    // Semantic difference between unary neg and binary minus.
    // "-"     return TK_NEG;
%}

[A-Za-z][A-Za-z0-9_]*  {
    yylval.str = strdup(yytext);
    //yylval.val = strdup(yytext);
    //yylval.length = yylen;
    return TK_ID; }
[0-9]+ {
    //yylval.intt = atoi(yytext);
    yylval.str = strdup(yytext);
    return TK_INT; }
\"[^"\n]*\" {
    yylval.str = strdup(yytext);
    //yylval.val = strdup(yytext);
    //yylval.length = yylen;
    return TK_SLIT; }
'[^'\n]*' {
    yylval.str = strdup(yytext);
    //yylval.val = strdup(yytext);
    //yylval.length = yylen;
    return TK_SLIT; }

[ \t]+  /* Consume whitespace */
#.*     /* Consume comments */

\n      { yynewlines++; }

.       { yyerror("Illegal character"); exit(1); }
%%


