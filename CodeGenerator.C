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
    // Reg 1 - LHS reg.
    // Reg 2 - RHS reg.
    // Reg 4 - Reserve for storing immediates to memory.
    // Reg 5 - Accumulator
    // Reg 6 - Stack Ptr / Frame Ptr
    // Reg 7 - PC
    vector<pair<VarRec *, int> > reg_assign;
    reg_assign.resize(6);

    for (int index = 0; static_cast<unsigned int>(index) < reg_assign.size(); ++index)
    {
        reg_assign[index] = make_pair(static_cast<VarRec *>(0), 0);
    }

    _reg_assign.push(reg_assign);

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
        target_addr_offset = get_frame_offset(1);

        emit_load_immed(IMMED_REG, data, "Step 1: Loading int to reg: " + note );

        // Store the memory location defined by the offset and
        // the current frame pointer value.
        emit_store_mem(IMMED_REG, target_addr_offset, FP_REG, 
                "Step 2: Storing to frame memory: " + note);
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

    int target_addr_offset;

    if (in_proc_defn_flag)
    {
//        // We're in a procedure, advancing through a frame.
//        target_addr_offset = get_frame_offset(1);
//
//        emit_load_immed(IMMED_REG, data, "Loading immediate to store in frame mem.");
//
//        // Store the memory location defined by the offset and
//        // the current frame pointer value.
//        emit_store_mem(IMMED_REG, target_addr_offset, FP_REG, 
//                "Storing immediate to frame memory.");
    }
    else
    {
        target_addr_offset = _next_data_addr;

        // Advance the next address by the size of the string.
        _next_data_addr += note.length();

        _output_file << ".DATA " << data << NOTE_PADDING << note << endl;
    }

    return target_addr_offset;
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
        string note,
        int bk_patch_line
        )
{
    return emit_displacement_fmt("LDA", result_reg, lhs_value, rhs_reg, 
            note, bk_patch_line);
}


// This emit is used to load from data memory to register.
int CodeGenerator::emit_load_mem(
        int result_reg,
        int lhs_value,
        int rhs_reg,
        string note,
        int bk_patch_line
        )
{
    return emit_displacement_fmt("LD", result_reg, lhs_value, rhs_reg, 
            note, bk_patch_line);
}


// This emit is used to store to data memory from register.
int CodeGenerator::emit_store_mem(
        int result_reg,
        int lhs_value,
        int rhs_reg,
        string note,
        int bk_patch_line
        )
{
    return emit_displacement_fmt("ST", result_reg, lhs_value, rhs_reg, 
            note, bk_patch_line);
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


// This emit is used to as a no operation.
int CodeGenerator::emit_noop(string note, int bk_patch_line)
{
    return emit_displacement_fmt("LDA", IMMED_REG, 0, IMMED_REG, note, bk_patch_line);
}


// This reports errors.
void CodeGenerator::error(TmOp code, string funct)
{
    cerr << "Line: " << _curr_line_num << " - Invalid code [" <<
        code << "] provided to " << funct << endl;
}


// This function assigns the specified variable to the left register.
// There is a check if the variable is assigne to the accumulator which
// preempts the assignment and just uses the AC.
int CodeGenerator::assign_left_reg(VarRec *source, int rel_addr,
        int bk_patch_line)
{
    // This function will load the value and store the values in the
    // register assignment stack.
    return assign_l_or_r_reg(LHS_REG, source, rel_addr, bk_patch_line);
}


// Convenience function.
int CodeGenerator::assign_right_reg(VarRec *source, int rel_addr,
        int bk_patch_line)
{
    // This function will load the value and store the values in the
    // register assignment stack.
    return assign_l_or_r_reg(RHS_REG, source, rel_addr, bk_patch_line);
}


// This function assigns the specified variable to the left or right register.
// There is a check if the variable is assigne to the accumulator which
// preempts the assignment and just uses the AC.
int CodeGenerator::assign_l_or_r_reg(int reg_num, VarRec *source, int rel_addr,
        int bk_patch_line)
{
    // NOTE: The advance BP line function leaves the value as -1 and
    //      advances all others but does not change the parameter.
    int target_reg;

    // If var assigned to the AC use that, otherwise assign to LHS/RHS register.
    if (_reg_assign.top()[AC_REG].first == source)
    {
        // Already loaded and assigned to AC.
        target_reg = AC_REG;

        // This is to keep the assignment of registers as always 2 instructions.
        emit_noop("NOOP: Filling assign to reg. Already assigned to AC (1)", 
                bk_patch_line);
        bk_patch_line = advance_back_patch_line(bk_patch_line);

        emit_noop("NOOP: Filling assign to reg. Already assigned to AC (2)", 
                bk_patch_line);
        bk_patch_line = advance_back_patch_line(bk_patch_line);
    }
    else
    {
        int base_addr_reg = ZERO_REG;

        // Determine if this variable is global or local.
        if (source->is_global())
        {
            base_addr_reg = ZERO_REG;
        }
        else
        {
            base_addr_reg = FP_REG;
        }

        emit_load_mem(reg_num, rel_addr, base_addr_reg,
                "LOADING var " + source->get_name() + " to reg num " +
                fmt_int(reg_num), bk_patch_line);
        bk_patch_line = advance_back_patch_line(bk_patch_line);

        // If this is a reference, add another load to get value pointed to
        // by the reference just loaded.
        // Arrays can only be passed by reference.
        if (source->is_reference() && !source->get_type()->is_array())
        {
            emit_note("Var " + source->get_name() + " is a reference.");

            // Don't need to advance BP line here.  Last instruction.
            emit_load_mem(reg_num, 0, reg_num,
                    "Loading value from reference location", bk_patch_line);
        }
        else
        {
            // This is to keep the assignment of registers as always 2 instructions.
            // Don't need to advance BP line here.  Last instruction.
            emit_noop("NOOP: Filling assign to reg.", bk_patch_line);
        }

        _reg_assign.top()[reg_num] = make_pair(source, rel_addr);

        target_reg = reg_num;
    }

    return target_reg;
}


//
int CodeGenerator::advance_back_patch_line(int curr_bp_line)
{
    if (curr_bp_line != -1)
    {
        ++curr_bp_line;
    }

    return curr_bp_line;
}


// Assign the source variable record to the accumulator.
void CodeGenerator::assign_to_ac(VarRec *source)
{
    _reg_assign.top()[AC_REG] = make_pair(source, 0);
}

// This method will spill the specified register back to memory.
void CodeGenerator::spill_register(int reg_num)
{
    // Get all of the info needed to get it back into memory.
    VarRec *target_var = _reg_assign.top()[reg_num].first;

    int target_offset = _reg_assign.top()[reg_num].second;

    // Check if this is a global or local variable.
    int base_addr_reg = target_var->get_base_addr_reg();
    string fmt_base_reg;

    // Determine if this variable is global or local.
    if (base_addr_reg == ZERO_REG)
    {
        fmt_base_reg = "ZERO_REG";
    }
    else if (base_addr_reg == FP_REG)
    {
        fmt_base_reg = "FP_REG";
    }
    else
    {
        fmt_base_reg = "**** ERROR: VAR SAID IT IS NEITHER A GLOBAL OR LOCAL ****";
    }

    if (target_var->is_reference())
    {
        emit_load_mem(IMMED_REG, target_offset, base_addr_reg,
                "Loading reference address.");

        emit_store_mem(reg_num, 0, IMMED_REG,
                "Spilling reference var: " + target_var->get_name() + 
                " to memory d= 0, address in IMMED reg.");
    }
    else
    {
        emit_store_mem(reg_num, target_offset, base_addr_reg,
                "Spilling var: " + target_var->get_name() + " to memory d=" +
                fmt_int(target_offset) + " " + fmt_base_reg);
    }
}


// This method returns the next frame offset and advances the frame offset
// by the size needed to store the desired information.
int CodeGenerator::get_frame_offset(int size)
{
    int target_offset = _next_frame_offset;

    _next_frame_offset += size;

    return target_offset;
}


void CodeGenerator::save_regs()
{
    // We reserved the first 6 mem locations to make this easy.
    // NOTE: Doesn't work for save state between frames.
    emit_store_mem(1, 1, ZERO_REG, "Save reg 1 state.");
    emit_store_mem(2, 2, ZERO_REG, "Save reg 2 state.");
    emit_store_mem(3, 3, ZERO_REG, "Save reg 3 state.");
    emit_store_mem(4, 4, ZERO_REG, "Save reg 4 state.");
    emit_store_mem(5, 5, ZERO_REG, "Save reg 5 state.");
    emit_store_mem(6, 6, ZERO_REG, "Save reg 6 state.");
}


void CodeGenerator::restore_regs()
{
    // We reserved the first 6 mem locations to make this easy.
    // NOTE: Doesn't work for save state between frames.
    emit_load_mem(1, 1, ZERO_REG, "Restore reg 1 state.");
    emit_load_mem(2, 2, ZERO_REG, "Restore reg 2 state.");
    emit_load_mem(3, 3, ZERO_REG, "Restore reg 3 state.");
    emit_load_mem(4, 4, ZERO_REG, "Restore reg 4 state.");
    emit_load_mem(5, 5, ZERO_REG, "Restore reg 5 state.");
    emit_load_mem(6, 6, ZERO_REG, "Restore reg 6 state.");
}


int CodeGenerator::reset_frame_offset()
{
    // Store the size.  The var points to the next available location.
    int temp = _next_frame_offset - 1;

    _next_frame_offset = INIT_FRAME_OFFSET;
    
    return temp;
}


void CodeGenerator::enter_scope()
{
    vector<pair<VarRec *, int> > reg_assign;
    reg_assign.resize(6);

    for (int index = 0; static_cast<unsigned int>(index) < reg_assign.size(); ++index)
    {
        reg_assign[index] = make_pair(static_cast<VarRec *>(0), 0);
    }

    _reg_assign.push(reg_assign);
}


void CodeGenerator::exit_scope()
{
    _reg_assign.pop();
}

