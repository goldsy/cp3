#include "ProcRec.H"


using namespace std;


// Class ctor.
ProcRec::ProcRec(
        string proc_name, 
        TypeRec *return_type, 
        list<VarRec *> *param_list, 
        bool is_forward
        )
{
    _proc_name = proc_name;
    _return_type = return_type;
    _param_list = param_list;
    _is_forward_decl = is_forward;
    _memory_loc = 0;
}


// Setters
void ProcRec::set_param_list(list<VarRec *> *source)
{
    _param_list = source;
}


void ProcRec::set_return_type(TypeRec *source)
{
    _return_type = source;
}


void ProcRec::set_is_forward(bool flag)
{
    _is_forward_decl = flag;
}


// Name getter.
string ProcRec::get_name()
{
    return _proc_name;
}

list<VarRec *>* ProcRec::get_param_list()
{
    return _param_list;
}


// Return type getter
TypeRec* ProcRec::get_return_type()
{
    return _return_type;
}


// 
bool ProcRec::get_is_forward()
{
    return _is_forward_decl;
}


// Checks if return type and params are structurally same.
bool ProcRec::equal(ProcRec *rhs)
{
    // Check if one is a proc and the other a function.
    if (((_return_type == 0) && (rhs->get_return_type() != 0))
            || ((_return_type != 0) && (rhs->get_return_type() == 0))
       )
    {
        return false;
    }

    // If both return a value make sure they are the same.
    if (_return_type && rhs->get_return_type())
    {
        if (!_return_type->equal(rhs->get_return_type()))
        {
            return false;
        }
    }

    list<VarRec *> *rhs_params = rhs->get_param_list();

    // Check for no vs some parameters.
    if (((rhs_params == 0) && (_param_list != 0))
            || ((rhs_params != 0) && (_param_list == 0)))
    {
        // One has params one doesn't.
        return false;
    }

    // They are either both null or not.
    if (rhs_params && _param_list)
    {
        if (rhs_params->size() != _param_list->size())
        {
            // Conflict in number
            return false;
        }

        list<VarRec *>::iterator iter;
        list<VarRec *>::iterator rhs_iter = rhs_params->begin();

        for(iter = _param_list->begin(); iter != _param_list->end(); ++iter)
        {
            if (!(*iter)->get_type()->equal((*rhs_iter)->get_type())) 
            {
                // Conflict in parameter type.
                return false;
            }

            // Already know list sizes are same so for will
            // protect rhs_iter from overrunning end.
            ++rhs_iter;
        }
    }

    return true;
}
