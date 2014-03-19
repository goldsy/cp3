
#ifndef VARREC_H
#define VARREC_H



#include <string>

//#include "TypeRec.H"
class TypeRec;


using namespace std;


// Class to store type information.
class VarRec {
    private:
        // Name of the type in the symbol table.
        string _var_name;

        // Type of this varaible.
        TypeRec *_var_type;

        // TODO: Seems logical but shouldn't be needed for P2.
        int _memory_loc;

        // Flag indicating if variable is used as a loop counter.
        bool _loop_counter_flag;

    public:
        // Default ctor.
        VarRec(string var_name, TypeRec *var_type);

        // Class dtor.
        ~VarRec() { };

        // Getters
        string get_name();
        TypeRec* get_type();
        bool get_loop_counter_flag();
        // TODO: getter for memory location???


        // Setters
        void set_loop_counter_flag(bool flag);

        // TODO: setter for memory location???

        // Type equivalence operator
        //static void equiv(const VarRec &lVal, const VarRec &rVal);
};


//inline bool operator==(const VarRec &lhs, const VarRec &rhs) {
//    // TODO: If lhs.base == rhs.base
//    return false;
//}


#endif      /* VARREC_H */
