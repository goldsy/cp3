
#ifndef VARREC_H
#define VARREC_H



#include <string>

#include "TypeRec.H"


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

        // Const flag indicating a read-only variable. (Const or literal.)
        bool _const_flag;

        // String representation of the value.
        string _str_value;


    public:
        // Default ctor.
        VarRec(string var_name, TypeRec *var_type, 
                bool const_flag = false, string init_value = "");

        // Class dtor.
        ~VarRec() { };

        // Getters
        string get_name();
        TypeRec* get_type();
        bool get_loop_counter_flag();
        bool is_const();
        string get_value();
        // TODO: getter for memory location???


        // Setters
        void set_loop_counter_flag(bool flag);
        void set_const_flag(bool flag);
        void set_value(string str_value);

        // TODO: setter for memory location???

        // Type equivalence operator
        //static void equiv(const VarRec &lVal, const VarRec &rVal);
};


//inline bool operator==(const VarRec &lhs, const VarRec &rhs) {
//    // TODO: If lhs.base == rhs.base
//    return false;
//}


#endif      /* VARREC_H */
