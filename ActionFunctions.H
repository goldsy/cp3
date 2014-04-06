// This file contains function used in the actions of the bison grammar file.
//
#ifndef ACTIONFUNCTIONS_H
#define ACTIONFUNCTIONS_H

#include "TypeRec.H"

// Function declarations.
bool is_int_or_boolean(TypeRec *rvalue);
bool are_int_or_boolean(TypeRec *lvalue, TypeRec *rvalue);
bool is_boolean(TypeRec *source);
bool is_int(TypeRec *rvalue);
bool are_int(TypeRec *lvalue, TypeRec *rvalue);

string fmt_int(int source);

#endif      /* ACTIONFUNCTIONS_H */
