// Code Generator Source File.


#include "CodeGenerator.H"

using namespace std;


// Class ctor
CodeGenerator::CodeGenerator()
{
    _curr_line_num = 0;
}


// Class dtor.
CodeGenerator::~CodeGenerator()
{
    // Close the file.
    if (_target.is_open())
    {
        _target.close();
    }
}


// This method initializes the outfile.
void CodeGenerator::init_out_file(char *target_filename)
{
    _target.open(target_filename);
}
