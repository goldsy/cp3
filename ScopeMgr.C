#include "ScopeMgr.H"
#include <stdio.h>

ScopeMgr *ScopeMgr::_singleton = 0;

// Class ctor
ScopeMgr::ScopeMgr():
    _type_sym_tbl_stack(),
    _var_sym_tbl_stack(),
    _proc_sym_tbl_stack()
{
    // Init the global scope symbol tables.
    _type_sym_tbl_stack.push_front(new TypeSymTable());
    _var_sym_tbl_stack.push_front(new VarSymTable());
    _proc_sym_tbl_stack.push_front(new ProcSymTable());

    // Init the primitive types.
    // (int, string, bool)
    insert_type(new TypeRec("int", intI9));
    insert_type(new TypeRec("string", stringI9));
    insert_type(new TypeRec("bool", booleanI9));
    // Got some strange type error trying to use these
    // constants.
    //insert_type(new TypeRec(INT_I9, intI9));
    //insert_type(new TypeRec(STR_I9, stringI9));
    //insert_type(new TypeRec(BOOL_I9, booleanI9));
}


// Class dtor.
ScopeMgr::~ScopeMgr()
{
    // Clean up any symbol tables. This will at least
    // be the global symbol tables of each type.
    for(unsigned int i = 0; i < _type_sym_tbl_stack.size(); ++i)
    {
        delete _type_sym_tbl_stack[i];
    }

    for(unsigned int i = 0; i < _var_sym_tbl_stack.size(); ++i)
    {
        delete _var_sym_tbl_stack[i];
    }

    for(unsigned int i = 0; i < _proc_sym_tbl_stack.size(); ++i)
    {
        delete _proc_sym_tbl_stack[i];
    }

    _singleton = 0;
}


ScopeMgr* ScopeMgr::create()
{
    if (!_singleton)
    {
        _singleton = new ScopeMgr();
    }

    return _singleton;
}



//
void ScopeMgr::enter_scope()
{
    // When entering a new scope create a new symbol 
    // table for each of the types and push it onto
    // the stack.
    _type_sym_tbl_stack.push_front(new TypeSymTable());
    _var_sym_tbl_stack.push_front(new VarSymTable());
    // Procs are always in the global scope by EBNF.
    //_proc_sym_tbl_stack.push_front(new ProcSymTable());
}


// Pops the symbol table off of each stack.
// 
// Precondition:
//  This function is not called without having called
//  the enter_scope() function first.
void ScopeMgr::exit_scope()
{
    // When leaving a scope delete the symbol table
    // of each type and remove it from the stack.
    TypeSymTable *ttemp = _type_sym_tbl_stack.front();
    delete ttemp;
    _type_sym_tbl_stack.pop_front();

    VarSymTable *vtemp = _var_sym_tbl_stack.front();
    delete vtemp;
    _var_sym_tbl_stack.pop_front();

    // ALWAYS GLOBAL.
    //ProcSymTable *ptemp = _proc_sym_tbl_stack.front();
    //delete ptemp;
    //_proc_sym_tbl_stack.pop_front();
}


//
TypeRec* ScopeMgr::lookup_type(string target_name)
{
    TypeSymTable *symbols;
    TypeSymTable::iterator iter;

    // Because a deque was used the inner most symbol
    // table is always at the beginning of the deque.
    for(unsigned int i = 0; i < _type_sym_tbl_stack.size(); ++i)
    {
        symbols = _type_sym_tbl_stack[i];

        iter = symbols->find(target_name);

        if (iter != symbols->end())
        {
            // Found the type.
            return iter->second;
        }
    }

    // The target type was not found.
    return 0;
}


//
VarRec* ScopeMgr::lookup_var(string target_name)
{
    VarSymTable *symbols;
    VarSymTable::iterator iter;

    // Because a deque was used the inner most symbol
    // table is always at the beginning of the deque.
    for(unsigned int i = 0; i < _var_sym_tbl_stack.size(); ++i)
    {
        symbols = _var_sym_tbl_stack[i];

        iter = symbols->find(target_name);

        if (iter != symbols->end())
        {
            // Found the type.
            return iter->second;
        }
    }

    // The target type was not found.
    return 0;
}


//
ProcRec* ScopeMgr::lookup_proc(string target_name)
{
    ProcSymTable *symbols;
    ProcSymTable::iterator iter;

    // Because a deque was used the inner most symbol
    // table is always at the beginning of the deque.
    for(unsigned int i = 0; i < _proc_sym_tbl_stack.size(); ++i)
    {
        symbols = _proc_sym_tbl_stack[i];

        iter = symbols->find(target_name);

        if (iter != symbols->end())
        {
            // Found the type.
            return iter->second;
        }
    }

    // The target type was not found.
    return 0;
}


////
//TypeSymTable* get_type_table()
//{
//    // TODO: FINISH ME.
//    TypeSymTable dummy;
//    return dummy
//}
//
//
////
//VarSymTable* get_var_table()
//{
//    // TODO: FINISH ME.
//    return VarSymTable dummy();
//}
//
//
////
//ProcSymTable* get_proc_table()
//{
//    // TODO: FINISH ME.
//    return ProcSymTable dummy();
//}


//
bool ScopeMgr::insert_type(TypeRec *source)
{
    TypeSymTable *symbols;
    TypeSymTable::iterator iter;

    // First check if the source record is already in the current 
    // scope symbol table.  If it is then this is an error an 
    // error just return false and let the caller report the error.
    symbols = _type_sym_tbl_stack.front();

    iter = symbols->find(source->get_name());

    if (iter != symbols->end())
    {
        // The type name already exists.
        return false;
    }

    // Insert the type record into the table.
    symbols->insert(make_pair(source->get_name(), source));

    return true;
}


//
bool ScopeMgr::insert_var(VarRec *source)
{
    VarSymTable *symbols;
    VarSymTable::iterator iter;

    // First check if the source record is already in the current 
    // scope symbol table.  If it is then this is an error an 
    // error just return false and let the caller report the error.
    symbols = _var_sym_tbl_stack.front();

    iter = symbols->find(source->get_name());

    if (iter != symbols->end())
    {
        // The type name already exists.
        return false;
    }

    // Insert the type record into the table.
    symbols->insert(make_pair(source->get_name(), source));

    return true;
}


//
bool ScopeMgr::insert_proc(ProcRec *source)
{
    ProcSymTable *symbols;
    ProcSymTable::iterator iter;

    // First check if the source record is already in the current 
    // scope symbol table.  If it is then this is an error an 
    // error just return false and let the caller report the error.
    symbols = _proc_sym_tbl_stack.front();

    iter = symbols->find(source->get_name());

    if (iter != symbols->end())
    {
        // The type name already exists.
        return false;
    }

    // Insert the type record into the table.
    symbols->insert(make_pair(source->get_name(), source));

    return true;
}

string ScopeMgr::knock_knock()
{
    return "Whoe's there?";
}

//
bool ScopeMgr::is_undefined_procs()
{
    ProcSymTable *symbols;
    ProcSymTable::iterator iter;

    // Really there will only be one because procs are globally defined.
    // Because a deque was used the inner most symbol
    // table is always at the beginning of the deque.
    for(unsigned int i = 0; i < _proc_sym_tbl_stack.size(); ++i)
    {
        symbols = _proc_sym_tbl_stack[i];

        for (iter = symbols->begin(); iter != symbols->end(); ++iter)
        {
            if ((iter->second)->get_is_forward())
            {
                return true;
            }
        }
    }

    return false;
}
