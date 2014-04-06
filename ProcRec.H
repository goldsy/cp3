
#ifndef PROCREC_H
#define PROCREC_H


#include <string>
#include <list>
#include "TypeRec.H"
#include "VarRec.H"


using namespace std;


// Class to store type information.
class ProcRec {
    private:
        // Name of the type in the symbol table.
        string _proc_name;

        // Base Ice 9 type.
        TypeRec *_return_type;

        // Param list used for proc/forwards.
        list<VarRec *> *_param_list;

        // Determines if a forward added it.
        bool _is_forward_decl;

        // Location in memory.
        int _memory_loc;


    public:
        // Default ctor.
        ProcRec(string proc_name, TypeRec *return_type, list<VarRec *> *param_list, bool is_forward = false);

        // Class dtor.
        ~ProcRec() { };

        // Setters
        void set_param_list(list<VarRec *> *source);
        void set_return_type(TypeRec *source);
        void set_is_forward(bool flag);

        // Getters
        string get_name();
        list<VarRec *>* get_param_list();
        TypeRec* get_return_type();
        bool get_is_forward();

        // Type equivalence operator
        bool equal(ProcRec *rhs);
};


#endif      /* PROCREC_H */
