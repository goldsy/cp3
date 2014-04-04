// Code Generator Source File.


#include "CodeGenerator.H"
#include <sstream>

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
    if (_output_file.is_open())
    {
        _output_file.close();
    }
}


// This method just returns the line number.
int CodeGenerator::get_curr_line()
{
    return _curr_line_num;
}


// This method just returns the line number.
string CodeGenerator::get_fmt_curr_line()
{
    ostringstream convert;
    convert << _curr_line_num;

    return (convert.str() + ": ");
}


// This method initializes the outfile.
void CodeGenerator::init_out_file(char *target_filename)
{
    _output_file.open(target_filename);
}


// This method emits the store int data instruction.
// It returns the index that the int is stored in.
// Precondition: The out file must be open for writing.
int CodeGenerator::emit_init_int(int data, string note)
{
    // Store the target data address. This is logical because TM does this for us.
    int target_addr = _next_data_addr;

    //
    ++_next_data_addr;

    _output_file << ".DATA " << data << NOTE_PADDING << note << endl;

    return target_addr;
}


// This method emits the store string data instruction.
// It returns the index that the string is stored in.
// Precondition: The out file must be open for writing.
int CodeGenerator::emit_init_str(string data, string note)
{
    // Store the target data address. This is logical because TM does this for us.
    int target_addr = _next_data_addr;

    // Advance the next address by the size of the string.
    _next_data_addr += note.length();

    _output_file << ".DATA " << data << NOTE_PADDING << note << endl;

    return target_addr;
}


// This emit is used for no register/value operations.
int CodeGenerator::emit(TmOp code, string note)
{
    int target_line = get_curr_line();

    _output_file << get_fmt_curr_line();

    if (code == HALT)
    {
        _output_file << "HALT";
    }
    else if (code == OUTNL)
    {
        _output_file << "OUTNL";
    }
    else
    {
        // Protect me from myself. :)
        error(code, "emit()");
        return -1;
    }

    _output_file << NOTE_PADDING << note;
    _output_file << endl;
    ++_curr_line_num;

    return target_line;
}


// This emit is used for the IO instructions. The only exception is the
// out newline OUTNL which is handled with parameterless emit.
int CodeGenerator::emit_io(TmOp code, int result_reg, string note)
{
    int target_line = get_curr_line();

    _output_file << get_fmt_curr_line();

    if (code == IN)
    {
        _output_file << "IN";
    }
    else if (code == OUT)
    {
        _output_file << "OUT";
    }
    else if (code == INB)
    {
        _output_file << "INB";
    }
    else if (code == OUTB)
    {
        _output_file << "OUTB";
    }
    else if (code == OUTC)
    {
        _output_file << "OUTC";
    }
    else
    {
        // Protect me from myself. :)
        error(code, "emit_io()");
        return -1;
    }

    _output_file << " " << result_reg;
    _output_file << NOTE_PADDING << note;
    _output_file << endl;

    ++_curr_line_num;

    return target_line;
}


// This emit is used for arithmetic operations.
int CodeGenerator::emit_math(
        TmOp code,
        int result_reg,
        int lhs_reg,
        int rhs_reg,
        string note
        )
{
    int target_line = get_curr_line();

    _output_file << get_fmt_curr_line();

    if (code == ADD)
    {
        _output_file << "ADD";
    }
    else if (code == SUB)
    {
        _output_file << "SUB";
    }
    else if (code == MUL)
    {
        _output_file << "MUL";
    }
    else if (code == DIV)
    {
        _output_file << "DIV";
    }
    else
    {
        // Protect me from myself. :)
        error(code, "emit_math()");
        return -1;
    }

    _output_file << " " << result_reg;
    _output_file << ", " << lhs_reg;
    _output_file << ", " << rhs_reg;
    _output_file << NOTE_PADDING << note;
    _output_file << endl;

    ++_curr_line_num;

    return target_line;
}


// This emit is used to load an immediate.
int CodeGenerator::emit_load_immed(int result_reg, int value, string note)
{
    // RHS register is ignored. Just use zero because a value is required.
    return emit_displacement_fmt("LDC", result_reg, value, 0, note);
}


// This emit is used to load value from reg + displacement.
int CodeGenerator::emit_load_value(
        int result_reg,
        int lhs_value,
        int rhs_reg,
        string note
        )
{
    //int target_line = get_curr_line();

    //_output_file << get_fmt_curr_line();

    //_output_file << "LDA";
    return emit_displacement_fmt("LDA", result_reg, lhs_value, rhs_reg, note);

    //_output_file << " " << result_reg << ", " << lhs_value << "("
    //    << rhs_reg << ")" << endl;

    //++_curr_line_num;

    //return target_line;
}


// This emit is used to load from data memory to register.
int CodeGenerator::emit_load_mem(
        int result_reg,
        int lhs_value,
        int rhs_reg,
        string note
        )
{
    return emit_displacement_fmt("LD", result_reg, lhs_value, rhs_reg, note);
}


// This emit is used to store to data memory from register.
int CodeGenerator::emit_store_mem(
        int result_reg,
        int lhs_value,
        int rhs_reg,
        string note
        )
{
    return emit_displacement_fmt("ST", result_reg, lhs_value, rhs_reg, note);
}


// This emit is used for jumps.
int CodeGenerator::emit_jump(
        TmOp code,
        int test_reg,
        int lhs_value,
        int rhs_reg,
        string note
        )
{
    int target_line = get_curr_line();

    _output_file << get_fmt_curr_line();

    if (code == JLT)
    {
        _output_file << "JLT";
    }
    else if (code == JLE)
    {
        _output_file << "JLE";
    }
    else if (code == JEQ)
    {
        _output_file << "JEQ";
    }
    else if (code == JNE)
    {
        _output_file << "JNE";
    }
    else if (code == JGE)
    {
        _output_file << "JGE";
    }
    else if (code == JGT)
    {
        _output_file << "JGT";
    }
    else
    {
        // Protect me from myself. :)
        error(code, "emit_jump()");
        return -1;
    }

    _output_file << " " << test_reg;
    _output_file << ", " << lhs_value << ", (" << rhs_reg << ")";

    _output_file << NOTE_PADDING << note;
    _output_file << endl;

    ++_curr_line_num;

    return target_line;
}


// Generic result, displacement, reg value formater.
int CodeGenerator::emit_displacement_fmt(string fmt_opcode, int result_reg,
        int lhs_value, int rhs_reg, string note)
{
    int target_line = get_curr_line();

    // ###: OPCODE r, d(s)
    _output_file << get_fmt_curr_line();
    _output_file << fmt_opcode;
    _output_file << " " << result_reg;
    _output_file << ", " << lhs_value << "(" << rhs_reg << ")";

    _output_file << NOTE_PADDING << note;
    _output_file << endl;

    ++_curr_line_num;

    return target_line;
}


// This reports errors.
void CodeGenerator::error(TmOp code, string funct)
{
    cerr << "Line: " << _curr_line_num << " - Invalid code [" <<
        code << "] provided to " << funct << endl;
}
