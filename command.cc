
/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "command.h"

SimpleCommand::SimpleCommand()
{
	// Creat available space for 5 arguments
	_numberOfAvailableArguments = 5;
	_numberOfArguments = 0;
	_arguments = (char **) malloc( _numberOfAvailableArguments * sizeof( char * ) );
}

void SimpleCommand::insertArgument( char * argument )
{
	if ( _numberOfAvailableArguments == _numberOfArguments  + 1 ) 
	{
		// Double the available space
		_numberOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments, _numberOfAvailableArguments * sizeof( char * ) );
	}	
	_arguments[ _numberOfArguments ] = argument;
	// Add NULL argument at the end
	_arguments[ _numberOfArguments + 1] = NULL;	
	_numberOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numberOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **) malloc( _numberOfSimpleCommands * sizeof( SimpleCommand * ) );
	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
}
void Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numberOfAvailableSimpleCommands == _numberOfSimpleCommands ) 
	{
		_numberOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands, _numberOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}	
	_simpleCommands[ _numberOfSimpleCommands ] = simpleCommand;
	_numberOfSimpleCommands++;
}
void Command:: clear()
{
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) 
	{
		for ( int j = 0; j < _simpleCommands[ i ]->_numberOfArguments; j ++ ) 
			free ( _simpleCommands[ i ]->_arguments[ j ] );		
		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}
	if ( _outFile ) 
		free( _outFile );

	if ( _inputFile ) 
		free( _inputFile );

	if ( _errFile ) 
		free( _errFile );

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
}

void Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");
	
	for ( int i = 0; i < _numberOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numberOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inputFile?_inputFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO");
	printf( "\n\n" );	
}

void Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numberOfSimpleCommands == 0 ) 
	{
		prompt();
		return;
	}
	// Print contents of Command data structure
	print();
	// Add execution here
	int std_in = dup(0);
	int std_out = dup(1);
	int fdin;
	if( _inputFile )
		fdin = open(_inputFile, O_RDONLY); 
	else
		fdin = dup(std_in);
	int fdout;
	int i, ret;
	for(i = 0; i < _numberOfSimpleCommands; i++ )
	{
		dup2(fdin, 0);
		close(fdin);
		// Setup i/o redirection
		if( i == _numberOfSimpleCommands-1 )
		{
			if( _outFile )
				fdout = open( _outFile, O_CREAT); //could O_APPEND for ">>" token
			else
				fdout = dup( std_out );
		}
		else
		{
			int fdpipe[2];
			pipe(fdpipe);
			fdout = fdpipe[1];
			fdin = fdpipe[0];
		}
		dup2(fdout, 1);
		close(fdout);
		// For every simple command fork a new process
		ret = fork();
		if( ret == 0)
		{
			execvp( _simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments );
			perror("execvp failed");
			_exit(1);
		}
	}
	dup2(std_in, 0);
	dup2(std_out, 1);
	close(std_in);
	close(std_out);

	if( !_background )
		waitpid(ret, NULL,  WUNTRACED | WCONTINUED);
	// Clear to prepare for next command
	clear();	
	// Print new prompt
	prompt();
}

// Shell implementation

void Command::prompt()
{
	if ( isatty(0) ) 
	{
  		printf("myshell>");
		fflush(stdout);
	}
	
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;
int yyparse(void);

main()
{
	Command::_currentCommand.prompt();
	yyparse();
}

