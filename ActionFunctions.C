// This file contains function used in the actions of the bison grammar file.
//
#include "TypeRec.H"
#include "ActionFunctions.H"
#include "ScopeMgr.H"
#include <stdio.h>
#include <sstream>

extern ScopeMgr *sm;
extern bool debugFlag;

//
bool is_int_or_boolean(TypeRec *rvalue)
{
    // Since procedures (vs functions) return no value
    // and proc calls are expressions therefore an
    // expression's type could be null. Check for it.
    // Didn't include below so that it is not too baked
    // into the code should I decide to change this design.
    // 
    // NOT NECESSARILY TRUE. CAN CATCH PROCEDURE CALL IN RULE.
    //if (!rvalue)
    //{
    //    return false;
    //}

    TypeRec *int_type = sm->lookup_type("int");
    TypeRec *bool_type = sm->lookup_type("bool");

    //if ((rvalue == sm->lookup_type("bool")) || (rvalue == sm->lookup_type("bool")))
    // Check if the value's type is structurally equivalent
    // to the int or bool primitive types.
    if ((rvalue->equal(int_type))
            || (rvalue->equal(bool_type))
       )
    {
        return true;
    }

    return false;
}


//
bool are_int_or_boolean(TypeRec *lvalue, TypeRec *rvalue)
{
    TypeRec *int_type = sm->lookup_type("int");
    TypeRec *bool_type = sm->lookup_type("bool");

    //if ((rvalue == sm->lookup_type("bool")) || (rvalue == sm->lookup_type("bool")))
    // Check if the value types are structurally equivalent
    // to the int or bool primitive types.
    // Kept the test separate for readability.
    if ((lvalue->equal(int_type))
            && (rvalue->equal(int_type))
       )
    {
        // DEBUG
        //printf("BOTH ARE INTEGERS!!!");
        return true;
    }
    else if ((lvalue->equal(bool_type))
            && (rvalue->equal(bool_type))
           )
    {
        // DEBUG
        //printf("BOTH ARE BOOLS!!!");
        return true;
    }

    return false;
}


bool is_boolean(TypeRec *rvalue)
{
    if (rvalue->equal(sm->lookup_type("bool")))
    {
        return true;
    }

    return false;
}


bool is_int(TypeRec *rvalue)
{
    if (rvalue->equal(sm->lookup_type("int")))
    {
        return true;
    }

    return false;
}


bool are_int(TypeRec *lvalue, TypeRec *rvalue)
{
    // TODO: DEBUG DEBUG DEBUG
    if (debugFlag)
    {
        printf("lvalue ptr: %p\n", static_cast<void *>(lvalue));
        printf("rvalue ptr: %p\n", static_cast<void *>(rvalue));
        printf("lookup(int) ptr: %p\n", static_cast<void *>(sm->lookup_type("int")));
        fflush(0);
    }

    TypeRec *int_type = sm->lookup_type("int");

    if (int_type->equal(lvalue) && int_type->equal(rvalue))
    {
        return true;
    }

    return false;
}


string fmt_int(int source)
{
    // Format an int into a string for debugging.
    ostringstream convert;
    convert << source;

    return convert.str();
}
