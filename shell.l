
/*
 *
 * CS-252
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
void stripChar(char* str, char c)
{
 	char *src, *dst;
    char qt = c;
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


[A-Za-z0-9\-][A-Za-z0-9\-]*  {
	yylval.string_val = strdup(yytext);
	//fprintf(stderr,"in regular word\n");
	return WORD;
}
[^ \t\n]*(\\[^\s])[^ \t\n]* {
	char* word = strdup(yytext);
	//fprintf(stderr, "word=%s\n", word);
	stripChar(word, '\\');
	yylval.string_val = word;
	return WORD;
}
[^ \t\n|\>\<\>>\>&\>>&][^ \t\n|\>\<\>>\>&\>>&]*  {
	
	yylval.string_val = strdup(yytext);
	//fprintf(stderr,"in regular word\n");
	return WORD;
}
\"(\\.|[^\\"])*\"  {
	//fprintf(stderr,"in quote stripper\n");
	char* word = strdup(yytext);
	stripChar(word, '"');
	yylval.string_val = word;
	return WORD;
}

. { 
	perror("notoken invoked");
	return NOTOKEN;	 
}
%%

