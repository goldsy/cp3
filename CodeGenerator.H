// Code Generator Header File

#ifndef CODEGENERATOR_H
#define CODEGENERATOR_H


#include <string>
#include <iostream>
#include <fstream>


using namespace std;


// Class that will emit the machine code.
class CodeGenerator {
    private:
        // Out stream
        ofstream target;

    public:
        // Default ctor.
        CodeGenerator();

        // Class dtor to release resources.
        ~CodeGenerator();

        // Initializes the output file.
        void init_out_file(char *target_filename);

        // TODO: OTHER PUBLIC FUNCTIONS.
};

#endif      /* CODEGENERATOR_H */

