
/*
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
#include <sys/stat.h>
#include <vector>
#include <assert.h>

#include "command.h"
 extern "C" int debug_mode;

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
	//std::vector<int> backgroundProcesses; 
	_numberOfAvailableSimpleCommands = 1;
	//Valgrind: Address is 0 bytes after a block of size 0 alloc'd 
	_simpleCommands = (SimpleCommand **) malloc( _numberOfSimpleCommands * sizeof( SimpleCommand * ) );
	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
}
void Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numberOfAvailableSimpleCommands == _numberOfSimpleCommands ) 
	{
		_numberOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands, _numberOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
		assert(_simpleCommands != NULL);
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
	if ( _errFile != _outFile ) 
		free( _errFile );

	_numberOfSimpleCommands = 0;
	_outFile = 0;
	_inputFile = 0;
	_errFile = 0;
	_background = 0;
	_append= 0;
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
			printf("--%s-- \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background   Append        \n" );
	printf( "  ------------ ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
		_inputFile?_inputFile:"default", _errFile?_errFile:"default",
		_background?"YES":"NO", _append?"YES":"NO" );
	printf( "\n\n" );	
}
void Command::changeDir(char * dir)
{
	//printf( " cd target= %s\n", dir);
	int cd_ret = chdir(dir);
	if(cd_ret < 0 && dir) 
		fprintf(stderr, "No such file or directory\n"); 
	else if ( !dir)
		chdir(getenv("HOME"));
}
void Command::execute()
{
	// Don't do anything if there are no simple commands
	if ( _numberOfSimpleCommands == 0  && isatty(0) ) 
	{
		prompt();
		return;
	}
	// Print contents of Command data structure
	//print();
	// Add execution here
	int std_in = dup(0); //store default input 
	int std_out = dup(1); //store default output
	int std_err = dup(2); //store default error
	int fdin;
	if( _inputFile )
		fdin = open(_inputFile, O_RDONLY); //open specified input file to read 
	else
		fdin = dup(std_in); //otherwise keep stdin
	int fdout; //var to store the output fileObject
	int errout;
	int i, ret;
	int fdpipe[2];	
	for(i = 0; i < _numberOfSimpleCommands; i++ ) //go through each simple command
	{
		dup2(fdin, 0); //all inuput will now come from fdin. FileTable[0] = (whatever fdin is)
		close(fdin); // FileTable[0] points to fdin so remove initial link from FileTable 
		// Setup i/o redirection
		if( i == _numberOfSimpleCommands-1 )   //at last simple command
		{
			//printf("err=%s out=%s append=%d \n", _errFile, _outFile, _append);
			if( _outFile && _append)
				fdout = open( _outFile, O_RDWR|O_APPEND|O_CREAT, S_IWRITE|S_IREAD ); // [FullCommand] >> outfile
			else if( _outFile)
				fdout = open( _outFile, O_CREAT|O_RDWR|O_TRUNC, S_IWRITE|S_IREAD); // [FullCommand] > outfile
			else
				fdout = dup( std_out ); // [FullCommand] {_implicit_ > outfile}

			if( _errFile)
				errout = dup(fdout);
			else
				errout = dup(std_err); // [FullCommand] {_implicit_ > outfile}
			//printf("eroutr=%d fdout=%d append=%d \n", errout, fdout, _append);
			dup2(errout, 2);
			close(errout);
		}
		else
		{
			//setup pipes for redirection within [FullCommand] 
			pipe(fdpipe); //make a pipe
			//write "x" to fdpipe[1] and read "x" through fdpipe[0]
			fdout = fdpipe[1]; //store pipe output 
			fdin = fdpipe[0]; //store pipe input
		}
		dup2(fdout, 1); //make FileTable[1] = (whatever fileObject =fdout) 		
		close(fdout); //remove inital link to fdout. FileTable[1] already points to it
		
		//chdir can only change working directory for the current process.
		if ( strcmp(_simpleCommands[i]->_arguments[0], "cd") == 0 )
			changeDir( _simpleCommands[i]->_arguments[1] );
		else if ( strcmp(_simpleCommands[i]->_arguments[0], "exit") == 0 )
			exit(1);
		else if ( !strcmp( _simpleCommands[i]->_arguments[0], "setenv" ) )
		{
			 if ( setenv(_simpleCommands[i]->_arguments[1], _simpleCommands[i]->_arguments[2], 1) < 0)
			 	perror("setenv failed\n");
		}
		else if ( !strcmp( _simpleCommands[i]->_arguments[0], "unsetenv" ) )
		{
			 if ( unsetenv(_simpleCommands[i]->_arguments[1]) < 0)
			 	perror("unsetenv failed\n");
		}	
		else if ( !strcmp( _simpleCommands[i]->_arguments[0], "debug" ) )
		{
			if(_simpleCommands[i]->_arguments[1])
			{
				if( !strcmp(_simpleCommands[i]->_arguments[1], "on") )
					debug_mode = 1;
				else if (!strcmp(_simpleCommands[i]->_arguments[1], "off"))
					debug_mode = 0;
			}
			else
				perror("USAGE: debug <on/off>");
		}	 
		else // For every simple command fork a new process
		{
			ret = fork();
			if( ret == 0)
			{
				close(std_in);
				close(std_out); 
				close(std_err);
				//Valgrind: Invalid read of size 8	
				execvp( _simpleCommands[i]->_arguments[0], _simpleCommands[i]->_arguments );
				perror("execvp failed\n");				
				exit(1);
			}
		}
	}
	dup2(std_in, 0);
	dup2(std_out, 1);
	dup2(std_err, 2);
	close(std_in);
	close(std_out);
	close(std_err);

	if( !_background )
		waitpid(ret, NULL,  WUNTRACED | WCONTINUED);
	// else
	// 	backgroundProcesses.insert(ret);
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
  		printf("k_shell>");
		fflush(stdout);
	}	
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;
int yyparse(void);

void sigintHandler(int sig_num)
{
    signal(SIGINT, sigintHandler);
    printf("\nuse \"exit\" to terminate shell.");
    fflush(stdout);
}
void killzombie(int sig_num)
{
	// use busy waiting to wait till all children
	// processes have exited
	int child_id;
    while( (child_id = waitpid(-1, NULL, WNOHANG) ) > 0)
	{
		//check if child_id is in backgroundProcesses
		//if so, print "pid exited" and remove from backgroundProcesses
	}
}
int main ()
{
    signal(SIGINT, sigintHandler); //for ctrl-C 
	struct sigaction signalAction; 
	signalAction.sa_handler = killzombie;
	sigemptyset(&signalAction.sa_mask);
	signalAction.sa_flags = SA_RESTART;
	int error = sigaction(SIGCHLD, &signalAction, NULL); // for SIGCHILD
	if (error) 
	{
		perror("SIGCHILD failed");
		exit(-1);
	}
	Command::_currentCommand.prompt();
	yyparse();
	return 0;
}
