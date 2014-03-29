# Makefile for ice9
#

# Compiler
CC	= g++

# Compiler Flags.
CFLAGS	= -g -Wall -pedantic

# Include the Flex library.
LIB	= -lfl

# List of source files.
SRC	= ice9.l ice9.y TypeRec.C VarRec.C ProcRec.C ScopeMgr.C

# The lexer object file.
LEXOBJ = ice9.yy.o

# Lexer test harness object files.
LEXTESTOBJS = lextest.o $(LEXOBJ)

# Object file list.
OBJ	= $(LEXOBJ) ice9.tab.o TypeRec.o VarRec.o ProcRec.o ScopeMgr.o ActionFunctions.o

# -----------------------------------------------------------
# Default Makefile rule. @ rule target. ^ set of dependent files. < first prerequisite.
ice9:	$(OBJ)
	$(CC) -o $@ $^ $(LIB)

# This generates the parser. Change to user code if bison not used.
#	bison --report=state -d -t -v -o $@ $<
ice9.tab.c: ice9.y
	bison -d -t -v -o $@ $<

# Run bison to create the parser from the .y file.
# -d tells bison to create token-type macros in the <>.tab.h file.
ice9.tab.h: ice9.y
	bison -d -o ice9.tab.c $<
	rm -f ice9.tab.c

# Compile the parser but do not link (-c option)
ice9.tab.o: ice9.tab.c
	$(CC) $(CFLAGS) -c $<


# Compile the supporting classes but do not link (-c option)
TypeRec.o: TypeRec.C TypeRec.H
	$(CC) $(CFLAGS) -c $<

VarRec.o: VarRec.C VarRec.H
	$(CC) $(CFLAGS) -c $<

ProcRec.o: ProcRec.C ProcRec.H
	$(CC) $(CFLAGS) -c $<

ScopeMgr.o: ScopeMgr.C ScopeMgr.H
	$(CC) $(CFLAGS) -c $<

ActionFunctions.o: ActionFunctions.C ActionFunctions.H
	$(CC) $(CFLAGS) -c $<


# Run flex on the .l file to get the lexer.
# Also inlcude the paser definitions (creation will be triggered.)
ice9.yy.c: ice9.l ice9.tab.h
	flex -o$@ $<

# Compile the lexer but do not link (-c option)
ice9.yy.o: ice9.yy.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f $(OBJ) ice9.output

cleanest:
	make clean
	rm -f ice9.tab.c ice9.yy.c ice9.tab.h ice9

tar:	p1.tar.gz

p1.tar.gz:	Makefile $(SRC)
	tar czvf $@ Makefile $(SRC)

# Create zip file to conform to submission instructions
# to submit a zip file.
zip:
	zip program $(SRC) lextest.c Makefile REFERENCES README compile.sh TypeRec.H VarRec.H ProcRec.H ScopeMgr.H ActionFunctions.H ActionFunctions.C

# Build rule for the lexer test harness.
lextest:	$(LEXTESTOBJS)
	$(CC) -o $@ $^ $(LIB)

lextest.o:	lextest.c
	$(CC) $(CFLAGS) -c $<

# -----------------------------------------------------------
# Makefile rule for Time Machine (TM)
tm:	tm.c
	gcc -o tm tm.c
