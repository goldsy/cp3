#include <stdio.h>
#include <cstdlib>
#include <string>
#include <iostream>

#include "TypeRec.H"



// Class ctor.
TypeRec::TypeRec(
        string type_name, 
        I9Type base_type, 
        TypeRec *sub_type, 
        int size
    )
{
    _type_name = type_name;
    _base_type = base_type;
    _sub_type = sub_type;

    // Default the size to 1 which will be the size for the primitive types.
    _size = 1;
    _ignore_size = false;
}


// Class copy ctor.
TypeRec::TypeRec(
        TypeRec *source
        )
{
    _type_name = source->get_name(); 
    _base_type = source->get_base_type();

    // The primitive will have a null sub type.
    if (source->get_sub_type())
    {
        _sub_type = new TypeRec(source->get_sub_type());
    }
    else
    {
        _sub_type = 0;
    }

    _size = source->get_size();

    // Book keeping value.
    _ignore_size = false;
}

//void TypeRec::set_base_type(TypeRec *source)
//{
//    // Copy the ptr.
//    _base_type = source;
//}


void TypeRec::set_name(string name)
{
    _type_name = name;
}


void TypeRec::set_sub_type(TypeRec *source)
{
    // Copy the ptr.
    _sub_type = source;
}


void TypeRec::set_size(int size)
{
    _size = size;
}


// This function is designed to traverse to the bottom
// of a chain of arrays to set the underlying primitive
// type.
void TypeRec::set_primitive(TypeRec *source)
{
    if (_base_type != arrayI9)
    {
        printf("Attempted to set primitive on non-array type!");
        fflush(0);
        exit(1);
    }
    else if (_sub_type)
    {
        if (_sub_type->get_base_type() == arrayI9)
        {
            _sub_type->set_primitive(source);
        }
        else
        {
            printf("Attempted to set primitive on array with primitive!");
            fflush(0);
            exit(1);
        }
    }
    else
    {
        // This level's sub_type is null so set it
        // to the source
        _sub_type = source;
    }
}


string TypeRec::get_name()
{
    return _type_name;
}


I9Type TypeRec::get_base_type()
{
    return _base_type;
}


TypeRec* TypeRec::get_sub_type()
{
    return _sub_type;
}


int TypeRec::get_size()
{
    return _size;
}


// This function is designed to traverse to the bottom
// of a chain of arrays to get the underlying primitive
// type.
TypeRec* TypeRec::get_primitive()
{
    if (_base_type != arrayI9)
    {
        return 0;
    }
    else if (_sub_type)
    {
        if (_sub_type->get_base_type() == arrayI9)
        {
            return _sub_type->get_primitive();
        }
        else
        {
            return _sub_type;
        }
    }
    else
    {
        // This level's sub_type is null.
        return _sub_type;
    }
}


// This is the structural equivalence operator.
// Ignore array size is used when checking if array
// dimensions.
bool TypeRec::equal(TypeRec *rhs)
{
    // DEBUG
    // DEBUG
    // DEBUG
    // DEBUG
    //string temp;

    //if (rhs)
    //{
    //    temp = to_string() + rhs->to_string();
    //    cout << temp << endl;
    //    fflush(0);
    //}
    //else
    //{
    //    temp = to_string();
    //    cout << temp << endl;
    //    fflush(0);
    //}

    if ((_base_type == rhs->get_base_type())
            && (_ignore_size || (_size == rhs->get_size()))
       )
    {
        // The easy checks are the same so now check
        // the base type pointer.
        if ((_sub_type == 0)
                && (rhs->get_sub_type() == 0))
        {
            return true;
        }
        else if ((_sub_type != 0)
                && (rhs->get_sub_type() != 0))
        {
            // DEBUG
            // DEBUG
            // DEBUG
            //cout << "ABOUT TO RECURSE" << endl;

            return _sub_type->equal(rhs->get_sub_type());
        }
    }

    return false;
}


// Work around for c not liking default params.
bool TypeRec::equal_no_size(TypeRec *rhs)
{
    _ignore_size = true;
    bool return_val = equal(rhs);
    _ignore_size = false;

    return return_val;
}


// Determines if the base type of this type is array.
bool TypeRec::is_array()
{
    return (_base_type == arrayI9);
}


// Debug
string TypeRec::to_string()
{
    string temp;
    temp = " <<TypeName: ";
    temp += get_name();
    temp += "> <Base Type: ";

    switch (get_base_type())
    {
        case intI9:
            temp += "int";
            break;

        case stringI9:
            temp += "string";
            break;

        case booleanI9:
            temp += "bool";
            break;

        case arrayI9:
            temp += "Array[size: ";
            char tempArray[10];
            snprintf(tempArray, 10, "%d", get_size());
            temp += tempArray;
            temp += "]";
            break;

        case procI9:
            temp += "proc";
            break;

        case paramListI9:
            temp += "paramList";
            break;
    }

    temp += ">>"; 

    return temp;
}

