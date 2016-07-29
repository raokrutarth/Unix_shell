#include <stdio.h>

int main()
{
	fprintf( stderr, "------------------------------------------\n");
	fprintf( stderr, "This is an error message printed to stderr\n");
	fprintf( stderr, "------------------------------------------\n");
	fprintf( stderr, "------------END OF ERROR MESSAGE----------\n\n");


	fprintf( stdout, "##########################################\n");
	fprintf( stdout, "This is an standard message printed to stdout\n");
	fprintf( stdout, "##########################################\n");
	fprintf( stdout, "############## END OF STANDARD MESSAGE ###\n\n");
	return 0;
}
