// Code Generator Source File.


#include "CodeGenerator.H"
#include "ActionFunctions.H"
#include <sstream>

using namespace std;


// Defined in the bison file.
extern bool in_proc_defn_flag;


// Class ctor
CodeGenerator::CodeGenerator()
{
    _curr_line_num = 0;

    // Zero is reserved for the size of data.
    _next_data_addr = 1;

    // Sized to 6 because I want reg 0 as my 0 value register
    // and this will make sure indexes 1-3 align with register
    // numbers 1-3. Index zero will never be used.
    // Reg 4 - Reserve for storing immediates to memory.
    // Reg 5 - Accumulator
    // Reg 6 - Stack Ptr / Frame Ptr
    // Reg 7 - PC
    _reg_assign.resize(6);

    for (int index = 0; static_cast<unsigned int>(index) < _reg_assign.size(); ++index)
    {
        _reg_assign[index] = 0;
    }

    // TODO: GET RID OF THE REG ASSIGNMENT STUFF. ALWAYS SPILL.
    // Don't use register 0.
    _next_assignment = 1;

    // Set the initial variable offset for globals.
    //_offset_stack.push(INIT_FRAME_OFFSET);
    _next_frame_offset = INIT_FRAME_OFFSET;
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
    return get_fmt_line(_curr_line_num);
}


// This method just returns the line number.
string CodeGenerator::get_fmt_line(int line_num)
{
    ostringstream convert;
    convert << line_num;

    return (convert.str() + ": ");
}


// Skips over some lines so we can back patch later.
void CodeGenerator::reserve_lines(int num_lines)
{
    _curr_line_num += num_lines;
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
    //// Store the target data address. This is logical because TM does this for us.
    //int target_addr = _next_data_addr;

    ////
    //++_next_data_addr;

    //_output_file << ".DATA " << data << NOTE_PADDING << note;
    //_output_file << " [" << fmt_int(target_addr) << "]" << endl;

    //return target_addr;

    int target_addr_offset;

    if (in_proc_defn_flag)
    {
        // We're in a procedure, advancing through a frame.
        target_addr_offset = _next_frame_offset;
        ++_next_frame_offset;

        emit_load_immed(IMMED_REG, data, "Loading immediate to store in frame mem.");

        // Store the memory location defined by the offset and
        // the current frame pointer value.
        emit_store_mem(IMMED_REG, target_addr_offset, FP_REG, 
                "Storing immediate to frame memory.");
    }
    else
    {
        // Store the target data address. This is logical because TM does this for us.
        target_addr_offset = _next_data_addr;

        // Advance the global address.
        ++_next_data_addr;

        _output_file << ".DATA " << data << NOTE_PADDING << note;
        _output_file << " [" << fmt_int(target_addr_offset) << "]" << endl;
    }

    return target_addr_offset;
}


// This method emits the store string data instruction.
// It returns the index that the string is stored in.
// Precondition: The out file must be open for writing.
int CodeGenerator::emit_init_str(string data, string note)
{
    // TODO: DO SOMETHING LIKE THE INT INIT ABOVE.
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
        _output_file << "HALT 0,0,0";
    }
    else if (code == OUTNL)
    {
        _output_file << "OUTNL 0,0,0";
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
    _output_file << ",0,0";
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
        string note,
        int bk_patch_line
        )
{
    string fmt_code;

    if (code == JLT)
    {
        fmt_code = "JLT";
    }
    else if (code == JLE)
    {
        fmt_code = "JLE";
    }
    else if (code == JEQ)
    {
        fmt_code = "JEQ";
    }
    else if (code == JNE)
    {
        fmt_code = "JNE";
    }
    else if (code == JGE)
    {
        fmt_code = "JGE";
    }
    else if (code == JGT)
    {
        fmt_code = "JGT";
    }
    else
    {
        // Protect me from myself. :)
        error(code, "emit_jump()");
        return -1;
    }

    return emit_displacement_fmt(fmt_code, test_reg, lhs_value, 
            rhs_reg, note, bk_patch_line);
}


// Generic result, displacement, reg value formater.
int CodeGenerator::emit_displacement_fmt(
        string fmt_opcode, 
        int result_reg,
        int lhs_value, 
        int rhs_reg, 
        string note,
        int bk_patch_line)
{
    int target_line;

    if (bk_patch_line < 0)
    {
        target_line = get_curr_line();

        // Increment the line here because the back patch
        // case is only going back and filling in an unknown.
        // It already has moved past here.
        ++_curr_line_num;
    }
    else
    {
        target_line = bk_patch_line;
    }

    // ###: OPCODE r, d(s)
    _output_file << get_fmt_line(target_line);
    _output_file << fmt_opcode;
    _output_file << " " << result_reg;
    _output_file << ", " << lhs_value << "(" << rhs_reg << ")";

    _output_file << NOTE_PADDING << note;
    _output_file << endl;

    return target_line;
}


// This just emits a comment. No line number change.
void CodeGenerator::emit_note(string note)
{
    _output_file << "* " << note << endl;
}


// This reports errors.
void CodeGenerator::error(TmOp code, string funct)
{
    cerr << "Line: " << _curr_line_num << " - Invalid code [" <<
        code << "] provided to " << funct << endl;
}


// Determines if the specified variable is already loaded into a register.
int CodeGenerator::is_loaded(VarRec *source)
{
    int reg_assignment = 0;
    int index = 1;

    while ((reg_assignment == 0) && (static_cast<unsigned int>(index) < _reg_assign.size()))
    {
        if (_reg_assign[index] == source)
        {
            reg_assignment = index;
        }

        ++index;
    }

    return reg_assignment;
}


// This function returns the next register assignment. If necessary
// it spills before returning the register number and updates the vector.
int CodeGenerator::get_reg_assign(VarRec *source)
{
    int reg_assignment = is_loaded(source);

    if (!reg_assignment)
    {
        // Variable isn't already loaded. Find next register and
        // see if it needs to be spilled.
        if (_reg_assign[_next_assignment])
        {
            // Spill the value back to memory.
            emit_store_mem(_next_assignment, 
                    _reg_assign[_next_assignment]->get_memory_loc(), 
                    ZERO_REG,
                    "Spill register " + fmt_int(_next_assignment) + 
                        " back to memory loc: " + 
                        fmt_int(_reg_assign[_next_assignment]->get_memory_loc()));
        }

        // Only load from memory if it was stored in memory. The
        // temps won't (like the AC).
        // And in the case of the unary minus we mult. by -1 which is neither
        // in memory nor has a corresponding VarRec.
        if (source && source->get_memory_loc())
        {
            emit_load_mem(_next_assignment, source->get_memory_loc(), ZERO_REG,
                    "LOADING var " + source->get_name() + " to reg num " +
                    fmt_int(_next_assignment));
        }

        _reg_assign[_next_assignment] = source;
        reg_assignment = _next_assignment;
        advance_next_assignment();
    }

    return reg_assignment;
}


// Round robin the next assignment number.
void CodeGenerator::advance_next_assignment()
{
    ++_next_assignment;

    // This reserves first one and last two register numbers, but stores them in the
    // vector.
    if (static_cast<unsigned int>(_next_assignment) > (_reg_assign.size() - 3))
    {
        // Turn the corner.
        _next_assignment = 1;
    }
}


// Assign the source variable record to the accumulator.
void CodeGenerator::assign_to_ac(VarRec *source)
{
    _reg_assign[AC_REG] = source;
}

