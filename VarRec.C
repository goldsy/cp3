#include "VarRec.H"


// Class ctor.
VarRec::VarRec(string var_name, TypeRec *var_type, bool const_flag)
{
    _var_name = var_name;
    _var_type = var_type;
    _loop_counter_flag = false;
    _const_flag = const_flag;
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


void VarRec::set_loop_counter_flag(bool flag)
{
    _loop_counter_flag = flag;
}


void VarRec::set_const_flag(bool flag)
{
    _const_flag = flag;
}
