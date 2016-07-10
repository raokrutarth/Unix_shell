
/*
 *
 * CS-252 Summer 2016
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
    unput(c);
}

%}

%%

\n 	{ return NEWLINE; }

[ \t] 	{ /* Discard spaces and tabs */ }	

">>&"   { return GREATGREATAND; }
">>"	{ return GREATGREAT; }
">&"	{ return GREATAND; 	}
">" 	{ return GREAT;	}
"<"		{ return LESS;	}
"|"		{ return PIPE;	}
"&"		{ return AMPERSAND;	}
[^ \t\n|\>\<\>>\>&\>>&]\"[^ \t\n|\>\<\>>\>&\>>&]*\"  {
	/* Assume that file names have only alpha chars */
	yylval.string_val = strdup(yytext);
	return WORD;
}
[^ \t\n|\>\<\>>\>&\>>&][^ \t\n|\>\<\>>\>&\>>&]*  {
	/* Assume that file names have only alpha chars */
	yylval.string_val = strdup(yytext);
	return WORD;
}


. { return NOTOKEN; /* gives a warning */ }
%%

