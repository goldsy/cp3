
#ifndef TYPEREC_H
#define TYPEREC_H



#include <string>
#include <list>


using namespace std;

// Ice9 enumerated base types.
//
// Primitives: int, string, boolean
// Type ctors: array, proc, paramList
enum I9Type{
    intI9 = 0,
    stringI9,
    booleanI9,
    arrayI9,
    procI9,
    paramListI9
};

// Constants to use for primitive ice9 types.
const string INT_I9 = "int";
const string BOOL_I9 = "bool";
const string STR_I9 = "string";


// Class to store type information.
class TypeRec {
    private:
        // Name of the type in the symbol table.
        string _type_name;

        // Base Ice 9 type. This will always be a primitive.
        I9Type _base_type;

        // Pointer to the sub-type if base type is a type ctor.
        TypeRec *_sub_type;

        // The size is used for array
        int _size;

        // Book keeping value.
        bool _ignore_size;

    public:
        // Default ctor.
        TypeRec(string type_name, I9Type base_type, TypeRec *sub_type = 0, int size = 1);

        // Copy ctor.
        TypeRec(TypeRec *source);

        // Class dtor.
        ~TypeRec() { };

        // Setters
        void set_name(string name);
        //void set_base_type(TypeRec *source);
        void set_sub_type(TypeRec *source);
        void set_size(int size);
        void set_primitive(TypeRec *source);

        // Getters
        string get_name();
        I9Type get_base_type();
        TypeRec* get_sub_type();
        int get_size();
        TypeRec* get_primitive();

        // Type equivalence operator
        bool equal(TypeRec *rhs);

        // Type equivalence ignoring size. Used for arrays.
        bool equal_no_size(TypeRec *rhs);

        // Determines if the base type of this type is array.
        bool is_array();

        // Debugging function.
        string to_string();
};


//inline bool TypeRec::operator==(const TypeRec &lhs, const TypeRec &rhs) {
//    // TODO: If lhs.base == rhs.base
//    return false;
//}


#endif      /* TYPEREC_H */
        
