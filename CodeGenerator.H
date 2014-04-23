// Code Generator Header File

#ifndef CODEGENERATOR_H
#define CODEGENERATOR_H


#include "VarRec.H"
#include <string>
#include <iostream>
#include <fstream>
#include <vector>
#include <stack>


using namespace std;

const string NOTE_PADDING = "\t\t\t";

// The register that will always contain the 0 value.
const int ZERO_REG = 0;
const int LHS_REG = 1; /* LHS register */
const int RHS_REG = 2; /* RHS register */
const int STRIDE_REG = 3; /* STRIDE register */
const int IMMED_REG = 4; /* Immediate register */
const int AC_REG = 5; /* Accumulator register */
const int FP_REG = 6; /* Frame Pointer register */
const int PC_REG = 7; /* Program Counter register */


// All variable offsets start at one.
const int INIT_FRAME_OFFSET = 1;


// Put all TM op codes in the same enum to ensure that numbers won't be reused
// between groupings even though each group will be handled separately to make
// the function parameter lists simpler.
enum TmOp {
    /* Ignores all registers */
    HALT = 0,   
    OUTNL,

    /* 1 register, register only instructions. */
    IN,         
    OUT,
    INB,
    OUTB,
    OUTC,

    /* 3 register, register only instructions. */
    ADD,
    SUB,
    MUL,
    DIV,

    /* 2 value (1 reg/1 displacement), register to memory instructions */
    LDC,        /* immediate */

    /* 3 value (2 register/1 displacement), register to memory instructions */
    LDA,        /* Load Direct - not from dMem */
    LD,         /* Load Indirect - Get value from dMem[d(s)] */

    /* 
     * 3 value (2 register/1 displacement and PC), 
     * register to memory JUMP instructions 
     * */
    JLT,
    JLE,
    JEQ,
    JNE,
    JGE,
    JGT
};

// Class that will emit the machine code.
class CodeGenerator {
    private:
        // Out stream
        ofstream _output_file;

        // Current line number.
        int _curr_line_num;

        // Current data index.
        int _next_data_addr;

        // Generic result, displacement, reg value formater.
        int emit_displacement_fmt(string fmt_code, int result_reg, 
                int lhs_value, int rhs_reg, string note, int bk_patch_line = -1);

        // Get the current output line number formatted for TM output.
        string get_fmt_line(int line_num);


        // Vector of VarRec ptrs for register assignment and spilling.
        stack<vector<pair<VarRec *, int> > > _reg_assign;

        // The stack will be used to keep track of the next available offset 
        // for the variables in either the global or within a proc.
        //stack<int> _offset_stack;
        int _next_frame_offset;


    public:
        // Default ctor.
        CodeGenerator();

        // Class dtor to release resources.
        ~CodeGenerator();

        // Get the current output line number.
        int get_curr_line();

        // Get the current output line number formatted for TM output.
        string get_fmt_curr_line();

        // Skips over some lines so we can back patch later.
        void reserve_lines(int num_lines);

        // Initializes the output file.
        void init_out_file(char *target_filename);

        // TODO: NEVER DEFINED. REMOVE AFTER TESTING.
        // Gets the addrs of the next available data location.
        //int get_next_data_addr();

        // Emits the store int data instruction.
        int emit_init_int(int data, string note);

        // Emits the store string data instruction.
        int emit_init_str(string data, string note);


        // This emit is used for no register/value operations.
        int emit(TmOp code, string note);

        // This emit is used for the IO instructions.
        int emit_io(TmOp code, int target_reg, string note);

        // This emit is used for arithmetic operations.
        int emit_math(TmOp code, int result_reg, int lhs_reg, 
                int rhs_reg, string note);

        // This emit is used to load an immediate.
        int emit_load_immed(int result_reg, int value, string note);

        // This emit is used to load value from reg + displacement.
        int emit_load_value(int result_reg, int lhs_value, int rhs_reg, 
                string note, int bk_patch_line = -1);

        // This emit is used to load from data memory to register.
        int emit_load_mem(int result_reg, int lhs_value, int rhs_reg, 
                string note, int bk_patch_line = -1);

        // This emit is used to store to data memory from result register.
        int emit_store_mem(int result_reg, int lhs_value, int rhs_reg, 
                string note, int bk_patch_line = -1);

        // This emit is used for jumps.
        int emit_jump(TmOp code, int test_reg, int lhs_value, 
                int rhs_reg, string note, int bk_patch_line = -1);

        // This just emits a comment. No line number change.
        void emit_note(string note);

        // This just emits a noop.
        int emit_noop(string note, int bk_patch_line = -1);

        // Report when something seriously went wrong.
        void error(TmOp code, string funct);


        // This function assigns the specified variable to the left register.
        // There is a check if the variable is assigne to the accumulator which
        // preempts the assignment and just uses the AC.
        int assign_left_reg(VarRec *source, int rel_addr = 0, 
                int bk_patch_line = -1);

        // Same assign_left_req() function except it does it for the right.
        int assign_right_reg(VarRec *source, int rel_addr = 0, 
                int bk_patch_line = -1);

        // Common call for assign left or assign right.
        int assign_l_or_r_reg(int reg_num, VarRec *source, int rel_addr,
                int bk_patch_line = -1);


        // Advances the bk_patch line number of valid.
        // For use in functions with more than one back patch instruction.
        int advance_back_patch_line(int curr_bp_line);


        // This method assigns the specified variable record to the AC register.
        void assign_to_ac(VarRec *source);

        // This method will spill the variable back to memory.
        void spill_register(int reg_num);

        // Method to get the next available frame offset and advance the offset.
        int get_frame_offset(int size);

        // Saves the register states for quick and dirty calculations.
        void save_regs();

        // Restores the register states after quick and dirty calculations.
        void restore_regs();

        // This method resets the frame offset.
        int reset_frame_offset();

        // Pushes a new inited register assignment vector on the stack.
        void enter_scope();

        // Pops the register assignment vector off of the stack.
        void exit_scope();
};

#endif      /* CODEGENERATOR_H */

