#ifndef SCOPEMGR_H
#define SCOPEMGR_H

#include <string>
#include <map>
#include <deque>

#include "TypeRec.H"
#include "VarRec.H"
#include "ProcRec.H"


using namespace std;

// These define the 3 symbol tables.
typedef map<string, TypeRec*> TypeSymTable;
typedef map<string, VarRec*> VarSymTable;
typedef map<string, ProcRec*> ProcSymTable;
// TODO: declare the type for the param list maybe if it something more than an stl list.
// TODO: declare the type for the param list maybe if it something more than an stl list.


// Class to store type information.
class ScopeMgr {
    private:
        // Default ctor.
        ScopeMgr();

        // -----------------
        // Data Members.
        // -----------------
        static ScopeMgr *_singleton;

        // Symbol table stacks.
        // NOTE: The deque makes the code simpler than using
        // a vector. Functions are similar.
        deque<TypeSymTable*> _type_sym_tbl_stack;
        deque<VarSymTable*> _var_sym_tbl_stack;
        deque<ProcSymTable*> _proc_sym_tbl_stack;

    public:
        // Create function to enforce Singleton.
        static ScopeMgr* create();

        // Class dtor.
        ~ScopeMgr();

        // Pseudo push pop functions.
        void enter_scope();
        void exit_scope();

        // Lookup functions for symbol tables.
        TypeRec* lookup_type(string target_name);
        VarRec* lookup_var(string target_name);
        ProcRec* lookup_proc(string target_name);

        // Gets the current scope symbol tables.
        // TODO: NOT SURE I NEED THESE.
        //TypeSymTable* get_type_table();
        //VarSymTable* get_var_table();
        //ProcSymTable* get_proc_table();

        // Inserts the into the symbol current symbol table.
        // NOTE: Won't need ptr to ptr because we won't ever
        //      need to change what the caller points to.
        bool insert_type(TypeRec *source);
        bool insert_var(VarRec *source);
        bool insert_proc(ProcRec *source);

        // DEBUG DEBUG DEBUG
        string knock_knock();

        bool is_undefined_procs();
};

#endif      /* SCOPEMGR_H */
