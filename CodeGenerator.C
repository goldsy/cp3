// Code Generator Source File.


#include "CodeGenerator.H"

using namespace std;


// Class ctor
CodeGenerator::CodeGenerator()
{
}


CodeGenerator::~CodeGenerator()
{
    // Close the file.
    if (target.is_open())
    {
        target.close();
    }
}


void CodeGenerator::init_out_file(char *target_filename)
{
    target.open(target_filename);
}
