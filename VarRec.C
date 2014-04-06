#include <cstdio>
#include <cstdlib>

#include "VarRec.H"


// Class ctor.
VarRec::VarRec(
        string var_name, 
        TypeRec *var_type, 
        bool const_flag,
        string init_value
        )
{
    _var_name = var_name;
    _var_type = var_type;
    _loop_counter_flag = false;
    _const_flag = const_flag;
    _str_value = init_value;

    // This is the size of memory. Must never write here but using
    // zero allows for easy testing if it is set. Temp vars won't
    // have a value.
    _memory_loc = 0;
}


string VarRec::get_name()
{
    return _var_name;
}


TypeRec* VarRec::get_type()
{
    return _var_type;
}


bool VarRec::get_loop_counter_flag()
{
    return _loop_counter_flag;
}


bool VarRec::is_const()
{
    return _const_flag;
}


string VarRec::get_value()
{
    return _str_value;
}


int VarRec::get_memory_loc()
{
    return _memory_loc;
}


void VarRec::set_loop_counter_flag(bool flag)
{
    _loop_counter_flag = flag;
}


void VarRec::set_const_flag(bool flag)
{
    _const_flag = flag;
}


void VarRec::set_value(string str_value)
{
    if (_const_flag)
    {
        printf("Variable %s is a constant. Exiting...", _var_name.c_str());
        exit(0);
    }

    _str_value = str_value;
}


void VarRec::set_memory_loc(int mem_loc)
{
    _memory_loc = mem_loc;
}
