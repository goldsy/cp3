
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

        // Relative Location in memory.
        int _memory_loc;

        // Flag indicating if variable is used as a loop counter.
        bool _loop_counter_flag;

        // Const flag indicating a read-only variable. (Const or literal.)
        bool _const_flag;

        // Global flag indicating variable is stored in the global address space.
        bool _global_flag;

        // Flag indicating that 1) the underlying value is an int 
        // and 2) That the value at this location is an absolute address of
        // somewhere else in memory. It's type is the type of the object to which
        // it refers.
        bool _reference_flag;

        // String representation of the value.
        string _str_value;


    public:
        // Default ctor.
        VarRec( string var_name, 
                TypeRec *var_type, 
                bool global_flag = true, 
                bool const_flag = false, 
                string init_value = ""
                );

        // Class dtor.
        ~VarRec() { };

        // Getters
        string get_name();
        TypeRec* get_type();
        bool get_loop_counter_flag();
        bool is_const();
        string get_value();
        int get_memory_loc();
        bool is_global();
        int get_base_addr_reg();
        bool is_reference();


        // Setters
        void set_loop_counter_flag(bool flag);
        void set_const_flag(bool flag);
        void set_value(string str_value);
        void set_memory_loc(int mem_loc);
        void set_is_reference(bool flag);

        // Type equivalence operator
        //static void equiv(const VarRec &lVal, const VarRec &rVal);
};


//inline bool operator==(const VarRec &lhs, const VarRec &rhs) {
//    // TODO: If lhs.base == rhs.base
//    return false;
//}


#endif      /* VARREC_H */
