
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
void stripQuotes(char* str)
{
 	char *src, *dst;
    char qt = '"';
    for (src = dst = str; *src != '\0'; src++) 
    {
        *dst = *src;
        if (*dst != qt) 
            dst++;
    }
    *dst = '\0';
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
\"[^ \t\n|\>\<\>>\>&\>>&]\"\"[^ \t\n|\>\<\>>\>&\>>&]*\"  {
	char* word = strdup(yytext);
	stripQuotes(word);
	yylval.string_val = word;
	return WORD;
}
[^ \t\n|\>\<\>>\>&\>>&][^ \t\n|\>\<\>>\>&\>>&]*  {
	
	yylval.string_val = strdup(yytext);
	fprintf(stderr,"^^^^^^^^^^^^^^^^^^^^");
	return WORD;
}


. { return NOTOKEN; /* gives a warning */ }
%%

