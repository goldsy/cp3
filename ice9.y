%{

#include <stdio.h>
#include <math.h>
#include <string>
#include <list>
#include <iostream>
#include <deque>

#include "ScopeMgr.H"
#include "TypeRec.H"
#include "VarRec.H"
#include "CodeGenerator.H"

using namespace std;

// Flag used to turn on some debug messages.
bool debugFlag = false;
bool tmDebugFlag = true;

extern int yynewlines;
extern char *yytext;

int yylex(void); /* function prototype */

void yyerror(const char *s)
{
  if ( *yytext == '\0' )
    fprintf(stderr, "line %d: %s near end of file\n",
	    yynewlines,s);
  else
    fprintf(stderr, "line %d: %s near %s\n",
	    yynewlines, s, yytext);
}

// Maximum +/- int size.
const long MAX_INT_I9_SIZE = 2147483647;

// Handles scoping.
ScopeMgr *sm = ScopeMgr::create();

// Emits the target code.
CodeGenerator cg;

// Loop block count used for determining if we are inside of
// a loop block (i.e. for determining legitimacy of break stmt).
int fa_count = 0;
int do_count = 0;

// Bookkeeping for proc definitions.
bool in_proc_defn_flag = false;

// Lists to handle ID lists.
list<string> *id_list = 0;
//deque<list<string> *> *id_list_stack = new deque<list<string> *>();
string proc_name;
TypeRec *proc_type = 0;
list<VarRec *> *proc_var_rec_list = 0;

// Deque to get the array dereference indexes up.
deque<VarRec *> array_deref_indexes;

// Stucture for back patching if statements.
typedef struct BkPatch {
    int test_reg_num;
    int line_num;
    string note;
} BkPatch;

deque<BkPatch> if_jump_next_q;
stack<deque<BkPatch> > if_jump_end_stack;


// Because of nesting there could be more than one queue of jump to ends.
// Because of breaks there could be more than one jump to end of do.
stack<deque<BkPatch> > dofa_jump_end_stack;

//stack<BkPatch> dofa_jump_top_stack;
stack<int> dofa_jump_top_stack;

// Line number to jump to in order to skip the proc definition.
int skip_proc_line;

// Line number where the proc starts. Book keeping thing while declaring the proc.
int proc_line_start;

// The current proc being declared. Makes it visible between rules.
ProcRec *curr_proc_rec;

// Stucture for back patching if statements.
typedef struct BkPatchProc {
    list<VarRec*> *param_list;
    VarRec* return_var;
    int line_num;
    int control_link;
    string note;
} BkPatchProc;

map<ProcRec *, deque<BkPatchProc> > proc_ar_backpatches;

stack<int> proc_return_stack;


// This function emits the code for the intial part of the AR.
void init_ar(ProcRec *target_proc, list<VarRec *> *called_params, VarRec *return_var,
    int control_link, string note, int bk_patch_line = -1)
{
    // Load future value of the FP into the stride register (its an available reg).
    cg.emit_load_value(STRIDE_REG, -target_proc->get_frame_size(), FP_REG,
        "Loading the next value of the FP to a register.", bk_patch_line);

    if (bk_patch_line != -1)
    {
        ++bk_patch_line;
    }

    // Emit the frame size into the AR.
    cg.emit_load_value(IMMED_REG, target_proc->get_frame_size(), ZERO_REG,
        "Load the frame size into the immediate reg.", bk_patch_line);

    if (bk_patch_line != -1)
    {
        ++bk_patch_line;
    }

    // Init the ar offset.
    int ar_offset = 1;

    // Frame size is always in position 1.
    cg.emit_store_mem(IMMED_REG, ar_offset, STRIDE_REG,
        "Store the frame size into the AR.", bk_patch_line);

    ++ar_offset;

    if (bk_patch_line != -1)
    {
        ++bk_patch_line;
    }


    // Emit the AC state into the AR.
    cg.emit_store_mem(AC_REG, ar_offset, STRIDE_REG,
        "Store the AC state into the AR.", bk_patch_line);

    ++ar_offset;

    if (bk_patch_line != -1)
    {
        ++bk_patch_line;
    }


    // Emit the Control Line/Return PC into the AR.
    cg.emit_load_value(IMMED_REG, control_link, ZERO_REG,
        "Load the control link into the immediate reg.", bk_patch_line);

    if (bk_patch_line != -1)
    {
        ++bk_patch_line;
    }

    cg.emit_store_mem(IMMED_REG, ar_offset, STRIDE_REG,
        "Store the Control Link/Return PC into the AR.", bk_patch_line);

    ++ar_offset;

    if (bk_patch_line != -1)
    {
        ++bk_patch_line;
    }


    // Emit each of the parameters.
    if (called_params)
    {
        int lhs;

        for (list<VarRec *>::iterator iter = called_params->begin();
             iter != called_params->end();
             ++iter
            )
        {
            // Assign the variable to a register.
            lhs = cg.assign_left_reg((*iter), (*iter)->get_memory_loc(), bk_patch_line);

            // All assignments take two instructions (by design).
            if (bk_patch_line != -1)
            {
                ++bk_patch_line;
                ++bk_patch_line;
            }

            // Emit the store.
            cg.emit_store_mem(lhs, ar_offset, STRIDE_REG,
                "Storing parameter value into AR.", bk_patch_line);

            if (bk_patch_line != -1)
            {
                ++bk_patch_line;
            }

            ++ar_offset;
        }
    }

    
    // Emit the return variable absolute address.
    if (return_var)
    {
        // Calculate the absolute address of the return variable.
        cg.emit_load_value(IMMED_REG, return_var->get_memory_loc(), 
            return_var->get_base_addr_reg(),
            "Load the address of the return var into the immediate reg.", 
            bk_patch_line);

        if (bk_patch_line != -1)
        {
            ++bk_patch_line;
        }

        
        // Emit the store of the address to the return var ref location.
        cg.emit_store_mem(IMMED_REG, ar_offset, STRIDE_REG,
            "Storing return varaible address into AR.", bk_patch_line);
    }
}


// This is a convenience function so that I don't mess up the not logic
// in all the places I need to check what scope I'm in.
bool is_global_scope()
{
    return (!in_proc_defn_flag);
}




%}
%code requires { #include "TypeRec.H" }
%code requires { #include "ActionFunctions.H" }
%code requires { #include <list> }
%code requires { #include <deque> }
%code requires { #include "VarRec.H" }
%code requires { #include "ScopeMgr.H" }

%union {
  int intt;
  char *str;
  TypeRec *type_rec;
  VarRec *var_rec;
  list<TypeRec *> *type_rec_list;
  list<string> *string_list;
  list<VarRec *> *var_rec_list;
  VarSymTable *var_sym_tbl;
  deque<list<string> *> *string_list_stack;
}

%token TK_IF
%token TK_FI
%token TK_ELSE
%token TK_DO
%token TK_OD
%token TK_FA
%token TK_AF
%token TK_TO
%token TK_PROC
%token TK_END
%token TK_RETURN
%token TK_FORWARD
%token TK_VAR
%token TK_TYPE
%token TK_BREAK
%token TK_EXIT
%token TK_TRUE
%token TK_FALSE
%token TK_WRITE
%token TK_WRITES
%token TK_READ
%token TK_BOX
%token TK_ARROW
%token TK_LPAREN
%token TK_RPAREN
%token TK_LBRACK
%token TK_RBRACK
%token TK_COLON
%token TK_SEMI
%token TK_ASSIGN
%token TK_QUEST
%token TK_COMMA
%token TK_PLUS
%token TK_MINUS
%token TK_STAR
%token TK_SLASH
%token TK_MOD
%token TK_EQ
%token TK_NEQ
%token TK_GT
%token TK_LT
%token TK_GE
%token TK_LE

%token <str> TK_SLIT
%token <str> TK_INT
%token <str> TK_ID

%start program

%nonassoc TK_EQ TK_NEQ TK_GT TK_LT TK_GE TK_LE
%left TK_PLUS TK_MINUS
%left TK_STAR TK_SLASH TK_MOD
%right TK_QUEST

%type <var_rec> exp
%type <var_rec_list> expx
%type <var_rec> lvalue
%type <type_rec> lvalue2
%type <string_list> idlist
%type <string_list> idlist2
%type <type_rec> typeid
%type <type_rec> arraydims
%type <type_rec> forward2
%type <var_rec_list> declist
%type <var_rec_list> declistx
%type <var_rec_list> declistx2
%type <type_rec> proc2
%type <intt> qjumpnext
%type <intt> elseif
%type <intt> elseifentry
%type <intt> ifend
%type <var_rec> faentry
%%

/* START */
program:
       proginit defs stms0 
        { 
            /* printf("%s\n", sm->knock_knock().c_str()); */ 
            cg.emit(HALT, "END OF PROGRAM"); 
        }
    ;

proginit:
        /* empty rule */
        {
            // Initialize the FP to point to the end of memory.
            cg.emit_load_mem(FP_REG, 0, ZERO_REG, "Initialize the FP to end of mem.");

            // Reserve locations 1-6 for regs 1-6 state storing machine state.
            // Quick and dirty machine state storage.
            cg.emit_init_int(0, "State storage 1.");
            cg.emit_init_int(0, "State storage 2.");
            cg.emit_init_int(0, "State storage 3.");
            cg.emit_init_int(0, "State storage 4.");
            cg.emit_init_int(0, "State storage 5.");
            cg.emit_init_int(0, "State storage 6.");
        }
        ;


/* *********************** */
defs:
    /* empty rule */
    | defs def
    ;

def:
   var
   | type
   | forward
   | proc
   ;


/* *********************** */
var:
   TK_VAR varlist TK_SEMI   /* No action/return here. */
   ;

varlist:
       idlist TK_COLON typeid arraydims varlist2
       {
            // First determine the type we are dealing with.
            TypeRec *target_type = 0;

            // ---------------------
            // DEBUG
            // ---------------------
            if (debugFlag)
            {
                printf("typeid ptr: %p  arraydims ptr: %p\n", static_cast<void *>($<type_rec>3), static_cast<void *>($<type_rec>4));
                fflush(0);
            }

            if ($<type_rec>4)
            {
                // Declaring an array of some type so set the 'typeid'
                // to the base of the array.
                target_type = $<type_rec>4;

                target_type->set_primitive($<type_rec>3);
            }
            else
            {
                // No array ctor.
                target_type = $<type_rec>3;
            }

            // Variable declarations of same name cannot exist in current
            // scope, but may in outer scopes.
            list<string>::iterator iter;

            for (iter = $<string_list>1->begin(); iter != $<string_list>1->end(); ++iter)
            {
                // Make sure that the ID isn't already in the current scope var list. (i.e. check the return on the insert.)
                VarRec *temp = new VarRec(*iter, target_type, is_global_scope());

                if (!sm->insert_var(temp))
                {
                    // The only insert failure is that the variable
                    // already exists in the current symbol table.
                    string errorMsg;
                    errorMsg = "Duplicate variable '";
                    errorMsg += *iter;
                    errorMsg += "' in this scope";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                // CODE GEN
                // CODE GEN
                // CODE GEN
                if (target_type->is_array())
                {
                    if (tmDebugFlag)
                    {
                        cg.emit_note("--------- BEGIN DECLARE ARRAY -----------");
                        }

                    // USE MEMORY LAYOUT of:
                    // # Dimensions
                    // 1 .. n Dimension Size
                    // These will be used for overrun checks.
                    deque<int> array_dims;

                    if (!target_type->get_array_dims(array_dims))
                    {
                        printf("The target array type didn't return any dimensions");
                        fflush(0);
                    }

                    // The allocated size will be 
                    // one for the absolute address in memory which will be
                    // used for pass by reference in procedures.
                    // plus one for the number of array dims
                    // plus one for *EACH* array dimension size.
                    // plus the the space needed to store the data

                    // The variable will get the address of the absolute address.
                    temp->set_memory_loc(cg.emit_init_int(0, 
                        "Declare space for var " + temp->get_name() + " of type " +
                        target_type->get_name()));

                    if (tmDebugFlag)
                    {
                        cg.emit_note("Memory Loc of " + temp->get_name() +
                            " is " + fmt_int(temp->get_memory_loc()));
                    }

                    // Load the absolute value into that memory location.
                    int base_addr_reg = temp->get_base_addr_reg();

//                    if (temp->is_global())
//                    {
//                        base_addr_reg = ZERO_REG;
//                    }
//                    else
//                    {
//                        base_addr_reg = FP_REG;
//                    }

                    // Load the absolute of the array into a register.
                    // We haven't actually allocated this space to it yet.
                    cg.emit_load_value(IMMED_REG, temp->get_memory_loc() + 1,
                        base_addr_reg, "Loading absolute address of array.");

                    // The immediate reg already has the target address + 1
                    // loaded in it so just use that to set the memory location.
                    cg.emit_store_mem(IMMED_REG, -1, IMMED_REG,
                        "Storing absolute memory loc in IMMED_REG to memory.");

                    // Allocate the number of dims.
                    cg.emit_init_int(array_dims.size(), 
                        "Declare space for array num of dims.");

                    int total_array_size = 1;

                    for (int index = 0; static_cast<unsigned int>(index) < array_dims.size(); ++index)
                    {
                        // Allocate the each dimension.
                        cg.emit_init_int(array_dims[index], 
                            "Declare space for array dims = " + 
                            fmt_int(array_dims[index]));

                        // Intermediate calculation for size of array.
                        total_array_size *= array_dims[index];
                    }

                    // Allocate enought space for all elements.
                    for (int i = 0; i < total_array_size; ++i)
                    {
                        // Allocate each data space.
                        cg.emit_init_int(0, 
                            "Declare space for array index " + 
                            fmt_int(i));
                    }


                    if (tmDebugFlag)
                    {
                        cg.emit_note("--------- END DECLARE ARRAY -----------");
                    }
                }
                else if (is_int_or_boolean(target_type))
                {
                    // Init space for the bool or int.
                    // Store the memory loc in the var. Init it to 0.
                    temp->set_memory_loc(cg.emit_init_int(0, 
                        "Declare space for var " + temp->get_name() + " of type " +
                        target_type->get_name()));

                    if (tmDebugFlag)
                    {
                        cg.emit_note("Memory Loc of " + temp->get_name() +
                            " is " + fmt_int(temp->get_memory_loc()));
                    }
                }
                else
                {
                    // Otherwise this is string type to allocate.
                    // TODO: FINISH STRING ALLOCATION.
                    // TODO: FINISH STRING ALLOCATION.
                    // TODO: FINISH STRING ALLOCATION.
                    // THINKING THAT THE SIZE WILL BE STORED RIGHT BEFORE THE STR.
                }
            }

            delete id_list;
            id_list = 0;
        }
       ;

varlist2:
        /* empty rule */
        | TK_COMMA varlist /* Since this rule calls varlist that
                            rule does all of the work. Nothing to
                            do here or to return from here. */
        ;

idlist:
      TK_ID idlist2 {
        // Add this ID to the list pasted back through idlist2.
        $<string_list>2->push_back($<str>1);
        $$ = $<string_list>2;
      }
      ;

idlist2:
       /* empty rule */
       {
            // First to be called.
            $$ = new list<string>();
       }
       | TK_COMMA TK_ID idlist2
       {
            // Add this ID to the list and return the list ptr.
            $<string_list>3->push_back($<str>2);
            $$ = $<string_list>3;
       }
       ;

typeid:
      TK_ID
      {
            // Lookup the type ID in the type symbol table.
            TypeRec *targetType = sm->lookup_type($<str>1);

            if (targetType)
            {
                $$ = targetType;
            }
            else
            {
                string errorMsg;
                errorMsg = "Undefined type '";
                errorMsg += $<str>1;
                errorMsg += "'";
                yyerror(errorMsg.c_str());
                exit(0);
            }
      }
      ;

arraydims:
         /* empty rule */
         {
            // The empty rule returns a null. This will be filled
            // in by the basic type where the arraydims is consumed.
            $$ = 0;
         }
         | TK_LBRACK TK_INT TK_RBRACK arraydims
         {
            // Construct an array type putting the return from
            // the sub-arraydims as the sub type.
            if (atoi($<str>2) < 1)
            {
                // Array size must be >= 1.
                string errorMsg;
                errorMsg = "Illegal array size. Must be between >= 1";
                yyerror(errorMsg.c_str());
                exit(0);
            }

            $$ = new TypeRec("@anonymous", arrayI9, $<type_rec>4, atoi($<str>2));
         }
         ;


/* *********************** */
type:
    TK_TYPE TK_ID TK_EQ typeid arraydims TK_SEMI
    {
        // Figure out if this is an already known type or if an array
        // type constructor was used.
        TypeRec *target_type = 0;

        if ($<type_rec>5)
        {
            // Declaring an array of some type so set the 'typeid'
            // to the base of the array.
            target_type = $<type_rec>5;
            target_type->set_primitive($<type_rec>4);
        }
        else
        {
            // No array. Make a copy so that we can change the name
            // of the type in the rec. Otherwise we'll change the
            // name on the typeid. Not it's key in the map but only
            // in the object which we don't use, but I'm afraid I'll
            // forget if I deviate and try to use it later.
            target_type = new TypeRec($<type_rec>4);
        }

        target_type->set_name($<str>2);

        if (!sm->insert_type(target_type))
        {
            string errorMsg;
            errorMsg = "Type '";
            errorMsg += $<str>2;
            errorMsg += "' was already declared in this scope.";
            yyerror(errorMsg.c_str());
            exit(0);
        }
    }
    ;


/* *********************** */
forward:
       TK_FORWARD TK_ID TK_LPAREN declist TK_RPAREN forward2
       {
            ProcRec *proc_rec = new ProcRec($<str>2, $<type_rec>6, $<var_rec_list>4, true);

            // Check that TK_ID isn't already in the proc symbol table.
            if (!sm->insert_proc(proc_rec))
            {
                string errorMsg;
                errorMsg = "Duplicate forward declaration for '";
                errorMsg += $<str>2;
                errorMsg += "'";
                yyerror(errorMsg.c_str());
                exit(0);
            }
       }
       ;

forward2:
        TK_SEMI
        {
            // Procedure - no return value.
            $$ = 0;
        }
        | TK_COLON typeid TK_SEMI
        {
            // Function - returns typeid.
            $$ = $<type_rec>2;
        }
        ;

declist:
       /* empty rule */
       {
            $$ = 0;
       }
       | declistx
       {
            // Returns the list of variables (i.e. param list) from declistx.
            list<VarRec*> *scope_vars = $<var_rec_list>1;

            if (in_proc_defn_flag)
            {
                // These variables need to be entered in table now.
                if (scope_vars)
                {
                    // Loop through each variable and add them to the var
                    // symbol table.
                    list<VarRec*>::iterator iter;

                    for (iter = scope_vars->begin(); iter != scope_vars->end(); ++iter)
                    {
                        // Attempt to insert each variable check for failure.
                        if( !sm->insert_var(*iter) )
                        {
                            string errorMsg;
                            errorMsg = "Duplicate parameter name '";
                            errorMsg += (*iter)->get_name();
                            errorMsg += "'";
                            yyerror(errorMsg.c_str());
                            exit(0);
                        }

                        // CODE GEN
                        // CODE GEN
                        // CODE GEN
                        // Each parameter will only ever take 1 location because
                        // arrays pass by reference. The relative offset needs to be
                        // recorded.
                        (*iter)->set_memory_loc(cg.get_frame_offset(1));
                    }
                }
            }

            proc_var_rec_list = scope_vars;

            $$ = scope_vars;
       }
       ;

declistx:
        idlist TK_COLON typeid declistx2
        {
            // Create new list and add ID list to it.
            list<VarRec *> *param_list = new list<VarRec*>();
            list<string>::iterator id_iter;
            //list<VarRec *>::iterator param_iter;

            for (id_iter = $<string_list>1->begin(); id_iter != $<string_list>1->end(); ++id_iter)
            {
                VarRec *temp = new VarRec(*id_iter, $<type_rec>3, is_global_scope());
                param_list->push_back(temp);
            }

            // If declistx2 is not null merge lists checking for dup names.
            list<VarRec*> *sub_param_list = $<var_rec_list>4;

            if (sub_param_list)
            {
                // Copy the sub list to this one.
                param_list->insert(param_list->end(), sub_param_list->begin(), sub_param_list->end());

                // Delete the list.  The pointers are now "owned" but the new list.
                delete sub_param_list;
            }

            // Return merged list.
            $$ = param_list;

            delete id_list;
            id_list = 0;
        }
        ;

declistx2:
         /* empty rule */ { $$ = 0; }
         | TK_COMMA declistx { $$ = $<var_rec_list>2; }
         ;


/* *********************** */
proc:
    TK_PROC TK_ID procentry TK_LPAREN declist TK_RPAREN proc2 prochelper procdefs stms0 TK_END
    {
        // CODE GEN
        // CODE GEN
        // CODE GEN

        int epilogue_line = cg.get_curr_line();

        // Proctection against a NULL param list.
        int num_params = 0;

        if ($<var_rec_list>5)
        {
           num_params = $<var_rec_list>5->size();
        }

        // -------------------------------------------------------------------
        // Set the frame size of the procedure.
        // NO VARIABLES CAN BE ALLOCATED AFTER THIS!!! But that should not
        // be a problem. We are just unwinding the AR here. It is needed
        // below to set the FP_REG back.
        // -------------------------------------------------------------------
        curr_proc_rec->set_frame_size(cg.reset_frame_offset());

        // -------------------------------------
        // Unwind the procs activation record.
        // -------------------------------------
        // Check if there is a Return value. If so copy it to the return location.
        if ($<type_rec>7)
        {
            VarRec *rtnVar = sm->lookup_var(proc_name);

            if (!rtnVar)
            {
                string errorMsg;
                errorMsg = "Proc said it has a return var, but none was found ";
                    //under " + proc_name.c_str();
                yyerror(errorMsg.c_str());
                exit(0);
            }
            
            // Load the value from the rtn variable.
            int target_reg = cg.assign_left_reg(rtnVar, rtnVar->get_memory_loc());

            // Store the reference variable in the return location.
            // To do that we need to load the memory location to immediate reg
            // then store to that memory location.

            // Skip locations for Frame Size, AC state, Return PC, and params.
            cg.emit_load_mem(IMMED_REG, (4 + num_params), FP_REG,
                    "Loading reference address for proc return.");

            cg.emit_store_mem(target_reg, 0, IMMED_REG,
                    "Returning value from proc to reference var.");
        }

        // Restore the previous AC state from memory.
        cg.emit_load_mem(AC_REG, 2, FP_REG, "Restoring AC to previous state.");

        // Tell the code generator to go back to the previous register assignments.
        // This technically could be done anyway to the end of this rule.
        cg.exit_scope();

        // Load Return PC to the IMMED_REG because we lose that ability after the
        // FP_REG is shifted back.
        cg.emit_load_mem(IMMED_REG, 3, FP_REG, 
            "Loading return PC before FP is unwound");


        // *Add* the frame size back to the FP_REG.
        cg.emit_load_value(FP_REG, curr_proc_rec->get_frame_size(), FP_REG,
            "Setting the FP back to the previous FP position.");

        // Set the PC to the return PC value.
        cg.emit_load_value(PC_REG, 0, IMMED_REG,
            "Setting the PC to the return PC value.");



        // ----------------------------------------
        // BACK PATCHING
        // ----------------------------------------

        // Back patch setting the frame pointer.
        cg.emit_load_value(FP_REG, -(curr_proc_rec->get_frame_size()), FP_REG,
            "Setting the FP to (FP_REG - " + 
            fmt_int(curr_proc_rec->get_frame_size()) + ")", proc_line_start);


        // Back Patch any Return statements.
        while (proc_return_stack.size() > 0)
        {
            // Back patch the return.
            cg.emit_load_value(PC_REG, epilogue_line, ZERO_REG,
                "Unconditional jump to proc epilogue (i.e. return)",
                proc_return_stack.top());

            proc_return_stack.pop();
        }


        // Back Patch the Unconditional jump to end of function.
        cg.emit_load_value(PC_REG, cg.get_curr_line(), ZERO_REG,
            "Setting jump over function declaration.", skip_proc_line);

        if (tmDebugFlag)
        {
            cg.emit_note("--------- END PROC DECLARATION ----------");
        }


        // Back Patch the AR Inits that couldn't be done because the frame size
        // was not yet known.
        map<ProcRec *, deque<BkPatchProc> >::iterator iter;

        iter = proc_ar_backpatches.find(curr_proc_rec);

        // If iter == end() then no AR back patches were queued for this proc.
        if (iter != proc_ar_backpatches.end())
        {
            while (iter->second.size() > 0)
            {
                BkPatchProc ar_patch = iter->second.back();

                init_ar(curr_proc_rec, ar_patch.param_list, ar_patch.return_var,
                    ar_patch.control_link, ar_patch.note, ar_patch.line_num);

                iter->second.pop_back();
            }

            // All back patches have been emitted. Toss the map entry.
            proc_ar_backpatches.erase(iter);
        }



        // --------------------------------------------
        // Semantic stuff.
        // --------------------------------------------
        // Set the in_proc_defn_flag = false;
        in_proc_defn_flag = false;

        // We've now exited the scope.
        sm->exit_scope();


        // NOTE: Do not delete!!!
        curr_proc_rec = 0;
    }
    ;

procentry:
         /* empty rule */
         {
            // Check if in_proc_defn_flag == true.
            if (in_proc_defn_flag)
            {
                // Error we are already in a proc definition.
                string errorMsg;
                errorMsg = "Cannot nest function definitions";
                yyerror(errorMsg.c_str());
                exit(0);
            }
            else
            {
                // Set the in_proc_defn_flag.
                in_proc_defn_flag = true;

                // Record the proc name.
                proc_name = $<str>0;

                // We've now entered a new scope.
                sm->enter_scope();

                // CODE GEN
                // CODE GEN
                // CODE GEN
                if (tmDebugFlag)
                {
                    cg.emit_note("--------- BEGIN PROC DECLARATION ----------");
                }

                // The CG enter_scope() is a logical construct for the compiler
                // not the runtime so it is used here just like the scope manager.
                cg.enter_scope();

                // Queue an unconditional jump to end of function.
                skip_proc_line = cg.get_curr_line();
                cg.reserve_lines(1);

                // Store the start line of the proc so the memory location
                // can be set in the prochelper rule. Don't want to jack up the
                // semantic stuff so won't try to create one here.
                proc_line_start = cg.get_curr_line();

                // Reserve a line to change the FP by this functions frame size.
                // It will be proc_line_start conveniently enough.
                cg.reserve_lines(1);

                // Reserve 3 locations for Frame Size, AC_REG state, PC_REG return.
                // These are logically created.  There is no variable for them
                // I will know that for any proc these will be in 1, 2, and 3.
                cg.get_frame_offset(3);
            }
         }
         ;

prochelper:
          /* empty rule */
          {
            // Stuff the return variable in the table.
            if ($<type_rec>0)
            {
                // We check the scope but it will always be local in a proc.
                VarRec *rtn_var = new VarRec(proc_name, $<type_rec>0, 
                    is_global_scope());

                // This needs to be treated as a reference variable.
                //rtn_var->set_is_reference(true);

                if ( !sm->insert_var(rtn_var) )
                {
                    string errorMsg;
                    errorMsg = "Duplicate variable name '";
                    errorMsg += proc_name;
                    errorMsg += "' for function return type";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                // CODE GEN
                // CODE GEN
                // CODE GEN

                // NOTE: There are two returns. The AR return reference and the
                //      local return variable. This reserves space for the former.
                //      The next reserves the space for the local.
                cg.get_frame_offset(1);

                // We need to reserve space for this variable.
                rtn_var->set_memory_loc(cg.emit_init_int(0, 
                    "Allocating space for return variable"));
            }

            ProcRec *stored_proc = sm->lookup_proc(proc_name);
            ProcRec *proc_rec = new ProcRec(proc_name, $<type_rec>0, proc_var_rec_list);

            if (stored_proc)
            {
                // A forward was declared for this proc.
                // Or we redefined the proc.
                if (!stored_proc->get_is_forward())
                {
                    // What is stored isn't a forward declaration
                    // so it has been redefined. ERROR!
                    // Redefinition of procedure name.
                    string errorMsg;
                    errorMsg = "Redefinition of procedure '";
                    errorMsg += proc_name;
                    errorMsg += "'";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                // Compare to forward ProcRec.
                if (!proc_rec->equal(stored_proc))
                {
                    // Definition conflicts with forward declaration.
                    string errorMsg;
                    errorMsg = "Definition of '";
                    errorMsg += proc_name;
                    errorMsg += "' conflicts with forward declaration";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                // Then replace param list with <declist> so names match.
                // Clean up the old stored list if it exists.
                list<VarRec *> *stored_params = stored_proc->get_param_list();

                if (stored_params)
                {
                    list<VarRec *>::iterator stored_iter;

                    for(stored_iter = stored_params->begin(); stored_iter != stored_params->end(); ++stored_iter)
                    {
                        delete (*stored_iter);
                    }

                    delete stored_params;
                }

                stored_proc->set_param_list(proc_rec->get_param_list());

                // The proc has now been defined.
                stored_proc->set_is_forward(false);

                // Swap to use the same ptr as a newly defined proc for 
                // code generation.
                delete proc_rec;
                proc_rec = stored_proc;
            }
            else
            {
                if (!sm->insert_proc(proc_rec))
                {
                    string errorMsg;
                    errorMsg = "Duplicate proc definition for '";
                    errorMsg += proc_name;
                    errorMsg += "'";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }
            }

            proc_var_rec_list = 0;

            // CODE GEN
            // CODE GEN
            // CODE GEN

            // Set the start line of the proc as determined in the procentry rule.
            proc_rec->set_memory_loc(proc_line_start);

            // Store the current proc rec we're working on so we can get to it
            // elsewhere.  They never nest.
            curr_proc_rec = proc_rec;
          }
          ;

proc2:
     /* empty rule */
     {
        // No return value.
        $$ = 0;
     }
     | TK_COLON typeid
     {
        // Return value.
        $$ = $<type_rec>2;
     }
     ;

procdefs:
        /* empty rule */
        | type procdefs
        | var procdefs
        ;

stms0:
     /* empty rule */
     {
        if (sm->is_undefined_procs())
        {
            // There are forward definitions never actually defined.
            string errorMsg;
            errorMsg = "There are undefined forward declarations.";
            yyerror(errorMsg.c_str());
            exit(0);
        }
     }
     | stms
     {
        if (sm->is_undefined_procs())
        {
            // There are forward definitions never actually defined.
            string errorMsg;
            errorMsg = "There are undefined forward declarations.";
            yyerror(errorMsg.c_str());
            exit(0);
        }
     }
     ;

stms:
    stm
    | stms stm

/* *********************** */
stm:
   if
   | do
   | fa
   | TK_BREAK TK_SEMI
    {
        // Make sure that we are in a loop.
        if ((fa_count < 1) && (do_count < 1))
        {
            // Not in a loop.
            string errorMsg;
            errorMsg = "Invalid use of 'break'. Not in a loop.";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // CODE GEN
        // CODE GEN
        // CODE GEN
        // BACK PATCH JUMP OVER END OF LOOP.
        if (tmDebugFlag)
        {
            cg.emit_note("Reserve line " + fmt_int(cg.get_curr_line()) + 
                " for BREAK - Unconditional jump to end of DO/FA block.");
        }

        BkPatch jump_to_end;

        // Get the test register for the exp variable.
        jump_to_end.test_reg_num = ZERO_REG;
        jump_to_end.line_num = cg.get_curr_line();
        jump_to_end.note = "Jump from 'break' to end of do/fa block.";

        dofa_jump_end_stack.top().push_back(jump_to_end);

        cg.reserve_lines(1);

        if (debugFlag)
        {
            printf("END OF TK_BREAK\n");
            fflush(0);
        }
    }
   | TK_EXIT TK_SEMI
    {
        // CODE GEN
        // CODE GEN
        // CODE GEN
        cg.emit(HALT, "EXIT PROGRAM"); 
    }
   | TK_RETURN TK_SEMI
    {
        // CODE GEN
        // CODE GEN
        // CODE GEN

        // Jump to end of function to return which must be back patched.
        // Reserve the line for the unconditional jump to the return block.
        if (is_global_scope())
        {
            // This is same as exit in global scope.
            cg.emit(HALT, "Return in global scope. Same as exit.");
        }
        else
        {
            proc_return_stack.push(cg.get_curr_line());
            cg.reserve_lines(1);
        }
    }
   | lvalue TK_ASSIGN exp TK_SEMI
    {
        // Check if lvalue is an array. Arrays are not assignable.
        TypeRec *lvalue_type = $<var_rec>1->get_type();

        if (lvalue_type->is_array())
        {
            // Array types are not assignable.
            string errorMsg;
            errorMsg = "Arrays cannot be l-values in assignments.";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // Check if lvalue type = exp type.
        if (!lvalue_type->equal($<var_rec>3->get_type()))
        {
            // Incompatible types in assignment.
            string errorMsg;
            errorMsg = "Incompatible types in assignments.";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // Should not be able to do this inside fa.
        if ($<var_rec>1->get_loop_counter_flag())
        {
            string errorMsg;
            errorMsg = "Variable is not assignable.";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // CODE GEN
        // CODE GEN
        // CODE GEN
        if (tmDebugFlag)
        {
            cg.emit_note("------- BEGIN ASSIGNMENT ---------");
        }

        if (is_int_or_boolean($<var_rec>1->get_type()))
        {
            // Bools and ints will have the same TM code.
            // Load lvalue into register if necessary.
            // Load exp into register if necessary.
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    
            cg.emit_load_value(lhs_reg, 0, rhs_reg, "Assignment of " +
                $<var_rec>3->get_name() + " to " + $<var_rec>1->get_name());

            // Dump the register back to memory.
            cg.spill_register(lhs_reg);
        }
        else
        {
            // Otherwise we are dealing with a string.
            // TODO: FINISH EMIT STRING ASSIGNMENT.
            cg.emit_note("TODO: FINISH EMIT STRING ASSIGNMENT.");
        }

        if (tmDebugFlag)
        {
            cg.emit_note("------- END ASSIGNMENT ---------");
        }

    }
   | TK_WRITE exp TK_SEMI
    {
        // exp must be a string or int.
        TypeRec *string_rec = sm->lookup_type("string");
        TypeRec *int_rec = sm->lookup_type("int");

        if (!string_rec->equal($<var_rec>2->get_type())
            && !int_rec->equal($<var_rec>2->get_type()))
        {
            // Type is not string or int.
            string errorMsg;
            errorMsg = "Invalid type: write expression must be string or int type";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // CODE GEN
        // CODE GEN
        // CODE GEN
        if (tmDebugFlag)
        {
            cg.emit_note("------- BEGIN WRITE ---------");
        }

        int rhs_reg = cg.assign_right_reg($<var_rec>2, $<var_rec>2->get_memory_loc());    

        if (is_int($<var_rec>2->get_type()))
        {
            // Write as an integer.
            cg.emit_io(OUT, rhs_reg, "Writing int value of var " + 
                $<var_rec>2->get_name());
            cg.emit(OUTNL, "Writing NL");
        }
        else
        {
            // TODO: EMIT STRING WRITE HERE
        }

        if (tmDebugFlag)
        {
            cg.emit_note("------- END WRITE ---------");
        }
    }
   | TK_WRITES exp TK_SEMI
    {
        // exp must be a string or int.
        TypeRec *string_rec = sm->lookup_type("string");
        TypeRec *int_rec = sm->lookup_type("int");

        if (!string_rec->equal($<var_rec>2->get_type())
            && !int_rec->equal($<var_rec>2->get_type()))
        {
            // Type is not string or int.
            string errorMsg;
            errorMsg = "Invalid type: writes expression must be string or int type";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // CODE GEN
        // CODE GEN
        // CODE GEN
        if (tmDebugFlag)
        {
            cg.emit_note("------- BEGIN WRITES ---------");
        }

        int rhs_reg = cg.assign_right_reg($<var_rec>2, $<var_rec>2->get_memory_loc());    

        if (is_int($<var_rec>2->get_type()))
        {
            // Write as an integer.
            cg.emit_io(OUT, rhs_reg, "Writing int value of var " + 
                $<var_rec>2->get_name());
        }
        else
        {
            // TODO: EMIT STRING WRITE*S* HERE
        }

        if (tmDebugFlag)
        {
            cg.emit_note("------- END WRITES ---------");
        }
    }
   | exp TK_SEMI
   | TK_SEMI
   ;

if:
  TK_IF ifentry exp qjumpnext TK_ARROW stms elseif ifend
  {
    // DEBUG
    if (debugFlag)
    {
        printf("IF JUMP NEXT LINE NUM %d\n", $<intt>4);
        printf("LINE NUM AT END OF COMPLETE IF STMT %d\n", $<intt>8);
    }

    // exp must be a bool.
    TypeRec *bool_rec = sm->lookup_type("bool");

    if (!bool_rec->equal($<var_rec>3->get_type()))
    {
        // Type is not boolean.
        string errorMsg;
        errorMsg = "Invalid type: if expression must be boolean type";
        yyerror(errorMsg.c_str());
        exit(0);
    }

    // All code emitted in sub-rules.
  }
  ;

ifentry:
    /* empty rule */
    {
        // We've entered another if block so push a another end queue onto
        // the stack.
        // Create a new queue of jump to end of if block.
        deque<BkPatch> if_jump_end_q;
        if_jump_end_stack.push(if_jump_end_q);

        if (tmDebugFlag)
        {
            cg.emit_note("------- BEGIN IF -------");
        }
    }
    ;

qjumpnext:
    /* empty rule */
    {
        // Reserve instructions for if test.
        if (tmDebugFlag)
        {
            cg.emit_note("RESERVE LINE " + fmt_int(cg.get_curr_line()) + 
                " FOR JUMP TO NEXT IF BLOCK.");
        }

        $$ = cg.get_curr_line();
        cg.reserve_lines(1);

        // Queue the jump to elseif or else block.
        BkPatch ifjump;

        ifjump.test_reg_num = cg.assign_left_reg($<var_rec>0, $<var_rec>0->get_memory_loc());
        ifjump.line_num = $$;
        ifjump.note = "Jump from if stmt to elseif, else or ifend.";

        if_jump_next_q.push_back(ifjump);
    }
    ;

qjumpend:
    /* empty rule */
    {
        // This rule is used to queue backpatches for jumping to the end
        // of the if stmt block.
        if (tmDebugFlag)
        {
            cg.emit_note("RESERVE LINE " + fmt_int(cg.get_curr_line()) + 
                " FOR JUMP TO END OF IF BLOCK.");
        }

        BkPatch jump_to_end;

        // This is an absolute jump so the test register is irrelevant.
        jump_to_end.test_reg_num = ZERO_REG;
        jump_to_end.line_num = cg.get_curr_line();
        jump_to_end.note = "Jump from if or elseif to end of if block.";

        if_jump_end_stack.top().push_back(jump_to_end);

        cg.reserve_lines(1);
    }
    ;

elseif:
    /* empty rule */
    {
        // Always return zero to indicate no instructions.
        printf("ELSEIF EMPTY LINE %d\n", cg.get_curr_line());
        $$ = 0;
    }
   | elseif TK_BOX qjumpend dqifjumpnext exp qjumpnext elseifentry TK_ARROW stms
    {
        // exp must be a bool.
        TypeRec *bool_rec = sm->lookup_type("bool");

        if (!bool_rec->equal($<var_rec>5->get_type()))
        {
            // Type is not boolean.
            string errorMsg;
            errorMsg = "Invalid type: if expression must be boolean type";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // CODE GEN
        // CODE GEN
        // CODE GEN
        $$ = cg.get_curr_line();
        printf("ELSEIF NESTED %d\n", $<intt>1);

    }
   ;

dqifjumpnext:
        /* empty rule */
    {
        // Process the jump next queue. I know I call it a queue and treat it
        // like a stack but the order doesn't matter.
        if (if_jump_next_q.size() > 0)
        {
            if (tmDebugFlag && (if_jump_next_q.size() > 1))
            {
                cg.emit_note("HEY JUMP NEXT QUEUE HAS SIZE " + 
                    fmt_int(if_jump_next_q.size()));
            }

            // Get the item (Really should only ever be one).
            BkPatch patch = if_jump_next_q.back();

            cg.emit_jump(JEQ, patch.test_reg_num, (cg.get_curr_line() - 
                patch.line_num - 1), PC_REG, patch.note, patch.line_num);

            // Remove the item.
            if_jump_next_q.pop_back();
        }
    }
    ;

elseifentry:
        /* empty rule */
    {
        $$ = cg.get_curr_line();
    }
    ;

ifend:
    qjumpend dqifjumpnext TK_FI
    {
        // No else statement so clear the jump next queue because the
        // preceding if or else if doesn't need to jump.
        // Return current line which is end of if stmt.
        $$ = cg.get_curr_line();

        // CODE GEN
        // CODE GEN
        // CODE GEN
        deque<BkPatch> if_jump_end_q = if_jump_end_stack.top();

        while (if_jump_end_q.size() > 0)
        {
            // Get the item (Really should only ever be one).
            BkPatch patch = if_jump_end_q.back();

            cg.emit_jump(JEQ, patch.test_reg_num, (cg.get_curr_line() - 
                patch.line_num - 1), PC_REG, patch.note, patch.line_num);

            // Remove the item.
            if_jump_end_q.pop_back();
        }

        // We're leaving this if block.
        if_jump_end_stack.pop();

        if (tmDebugFlag)
        {
            cg.emit_note("------------------- END IF -------------------");
        }
    }
   | TK_BOX TK_ELSE TK_ARROW qjumpend dqifjumpnext stms TK_FI
    {
        // Return current line which is end of if stmt.
        $$ = cg.get_curr_line();

        // CODE GEN
        // CODE GEN
        // CODE GEN
        // Back patch the end for every jump to end.
        deque<BkPatch> if_jump_end_q = if_jump_end_stack.top();

        while (if_jump_end_q.size() > 0)
        {
            // Get the item (Really should only ever be one).
            BkPatch patch = if_jump_end_q.back();

            cg.emit_jump(JEQ, patch.test_reg_num, (cg.get_curr_line() - 
                patch.line_num - 1), PC_REG, patch.note, patch.line_num);

            // Remove the item.
            if_jump_end_q.pop_back();
        }

        // We're leaving this if block.
        if_jump_end_stack.pop();
    }
   ;

do:
  TK_DO doentry dofaentry exp qdofajumpend TK_ARROW stms0 TK_OD
  {
    if (debugFlag)
    {
        printf("BEGINNING OF DO *RULE*\n");
        fflush(0);
    }

    // exp must be a bool.
    TypeRec *bool_rec = sm->lookup_type("bool");

    if (!bool_rec->equal($<var_rec>4->get_type()))
    {
        // Type is not boolean.
        string errorMsg;
        errorMsg = "Invalid type: do expression must be boolean type";
        yyerror(errorMsg.c_str());
        exit(0);
    }

    // Decrement the loop count. Leaving the do loop.
    --do_count;

    // CODE GEN
    // CODE GEN
    // CODE GEN

    if (debugFlag)
    {
        printf("JUST BEFORE TOP PATCH PROCESSING\n");
        fflush(0);
    }

    // Get the top line of the do (Will only ever be one).
    int top_line = dofa_jump_top_stack.top();

    //cg.emit_load_value(PC_REG, (top_line - cg.get_curr_line() - 1), PC_REG, 
    cg.emit_load_value(PC_REG, top_line, ZERO_REG, 
        "FA/DO jump back to top of loop.");

//    BkPatch top_patch = dofa_jump_top_stack.top();
//
//    cg.emit_jump(JEQ, top_patch.test_reg_num, (top_patch.line_num - 
//        cg.get_curr_line() - 1), PC_REG, top_patch.note, top_patch.line_num);

    // Remove the jump to top item.
    dofa_jump_top_stack.pop();

    if (debugFlag)
    {
        printf("GOT TO END OF JUMP TO TOP OF DO/FA\n");
        fflush(0);
    }

    // EMIT THE JUMP TO END*S* CODE HERE. MUST BE AFTER JUMP TO TOP.
    deque<BkPatch> do_jump_end_q = dofa_jump_end_stack.top();

    while (do_jump_end_q.size() > 0)
    {
        // Get the item (Really should only ever be one).
        BkPatch patch = do_jump_end_q.back();

        cg.emit_jump(JEQ, patch.test_reg_num, (cg.get_curr_line() - 
            patch.line_num - 1), PC_REG, patch.note, patch.line_num);

        // Remove the item.
        do_jump_end_q.pop_back();
    }

    cg.emit_note("----------- END DO -----------");

    // Leaving this do loop.
    dofa_jump_end_stack.pop();
  }
  ;

doentry:
       /* empty rule */
       {
            // No scope change, but need to track do's for break usage.
            ++do_count;

            if (tmDebugFlag)
                cg.emit_note("----------- BEGIN DO -----------");
       }
       ;

dofaentry:
       /* empty rule */
       {
            // ==================================================================
            // Shared queue by fa and do, but the count is needed for symantic
            // analysis so it can be sure the fa's and do's end in the right
            // order.
            // ==================================================================
            // CODE GEN
            // CODE GEN
            // CODE GEN
            // Push a jump to top on the jump to top stack.
//            BkPatch jump_to_top;
//
//            // This is an unconditional jump so the test register is always ZERO.
//            jump_to_top.test_reg_num = ZERO_REG;
//            jump_to_top.line_num = cg.get_curr_line();
//            jump_to_top.note = "Jump from do/fa end to top of do/fa block.";
//
//            dofa_jump_top_stack.push(jump_to_top);
//
//            cg.reserve_lines(1);
            dofa_jump_top_stack.push(cg.get_curr_line());

            cg.emit_note("Storing line " + fmt_int(cg.get_curr_line()) +
                " as top of do/fa loop.");

            // We've entered a new fa/do block.
            // Create a new queue of jump to end of do/fa.
            deque<BkPatch> dofa_jump_end_q;
            dofa_jump_end_stack.push(dofa_jump_end_q);

            if (debugFlag)
            {
                printf("END OF DOFAENTRY!\n");
                fflush(0);
            }
       }
       ;

qdofajumpend:
    /* empty rule */
    {
        if (debugFlag)
        {
            printf("BEGINNING OF QDOFAJUMPEND\n");
            fflush(0);
        }

        // This rule is used to queue backpatches for jumping to the end
        // of the do stmt block.
        if (tmDebugFlag)
        {
            cg.emit_note("RESERVE LINE " + fmt_int(cg.get_curr_line()) + 
                " FOR JUMP TO END OF DO/FA BLOCK.");
        }

        BkPatch jump_to_end;

        // Get the test register for the exp variable.
        jump_to_end.test_reg_num = cg.assign_left_reg($<var_rec>0, 
            $<var_rec>0->get_memory_loc());
        jump_to_end.line_num = cg.get_curr_line();
        jump_to_end.note = "Jump from do/fa to end of do/fa block.";

        dofa_jump_end_stack.top().push_back(jump_to_end);

        cg.reserve_lines(1);

        if (debugFlag)
        {
            printf("END OF QDOFAJUMPEND\n");
            fflush(0);
        }
    }
    ;

fa:
  TK_FA TK_ID faentry TK_ASSIGN exp TK_TO exp fainit TK_ARROW stms0 TK_AF
    {
//        TypeRec *int_rec = sm->lookup_type("int");
//
//        // Both expressions must be an int.
//        if (!int_rec->equal($<var_rec>5->get_type())
//            || !int_rec->equal($<var_rec>7->get_type()))
//        {
//            // Variable undefined.
//            string errorMsg;
//            errorMsg = "Invalid fa expression type. Expressions must be int";
//            yyerror(errorMsg.c_str());
//            exit(0);
//        }

        // CODE GEN
        VarRec *counter_var = $<var_rec>3;

        int lhs = cg.assign_left_reg(counter_var, counter_var->get_memory_loc());

        // Increment the counter.
        cg.emit_load_value(lhs, 1, lhs, "Increment FA counter.");

        // Dump the register back to memory.
        cg.spill_register(lhs);

        
        // Get the top line of the do (Will only ever be one).
        int top_line = dofa_jump_top_stack.top();

        cg.emit_load_value(PC_REG, top_line, ZERO_REG, 
            "FA jump back to top of loop.");

        // Remove the jump to top item.
        dofa_jump_top_stack.pop();


        // EMIT THE JUMP TO END*S* CODE HERE. MUST BE AFTER JUMP TO TOP.
        deque<BkPatch> do_jump_end_q = dofa_jump_end_stack.top();

        while (do_jump_end_q.size() > 0)
        {
            // Get the item (Really should only ever be one).
            BkPatch patch = do_jump_end_q.back();

            // Need to know if this is a break because it has to be unconditional jump.
            string break_marker("'break'");
            size_t found = patch.note.find(break_marker);

            if (found == string::npos)
            {
                // break was not found therefore this is a conditional jump.
                cg.emit_jump(JLT, patch.test_reg_num, (cg.get_curr_line() - 
                    patch.line_num - 1), PC_REG, patch.note, patch.line_num);
            }
            else
            {
                // This is a break, unconditional jump needed.
                cg.emit_jump(JEQ, patch.test_reg_num, (cg.get_curr_line() - 
                    patch.line_num - 1), PC_REG, patch.note, patch.line_num);
            }

            // Remove the item.
            do_jump_end_q.pop_back();
        }

        if (tmDebugFlag)
        {
            cg.emit_note("------- END FA --------");
        }

        // Leaving fa scope.
        --fa_count;

        sm->exit_scope();
        cg.exit_scope();

        // Leaving this fa loop.
        dofa_jump_end_stack.pop();
   }
   ;

faentry:
       /* empty rule */
       {
            sm->enter_scope();

            // CODE GEN
            cg.enter_scope();

            ++fa_count;

            VarRec *id_rec = new VarRec($<str>0, sm->lookup_type("int"),
                is_global_scope());

            // CODE GEN
            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN FA --------");
            }

            id_rec->set_memory_loc(cg.emit_init_int(0, 
                "Allocate FA loop variable."));

            id_rec->set_loop_counter_flag(true);
            sm->insert_var(id_rec);

            $$ = id_rec;
       }
       ;

fainit:
      /* empty rule */
    {
        TypeRec *int_rec = sm->lookup_type("int");

        VarRec *counter_var = $<var_rec>-4;
        VarRec *init_val = $<var_rec>-2;
        VarRec *until_val = $<var_rec>0;

        // Both expressions must be an int.
        if (!int_rec->equal(init_val->get_type())
            || !int_rec->equal(until_val->get_type()))
        {
            // Variable undefined.
            string errorMsg;
            errorMsg = "Invalid fa expression type. Expressions must be int";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // CODE GEN
        // CODE GEN
        // CODE GEN
        if (tmDebugFlag)
        {
            cg.emit_note("Initial value name: " + init_val->get_name());
            cg.emit_note("Until value name: " + until_val->get_name());
        }

        // Assign the counter varable to LHS.
        int lhs = cg.assign_left_reg(counter_var, counter_var->get_memory_loc());
        int rhs = cg.assign_right_reg(init_val, init_val->get_memory_loc());

        // Init counter.
        cg.emit_load_value(lhs, 0, rhs, "Inited FA counter to value of " +
            init_val->get_name());

        // Dump the register back to memory.
        cg.spill_register(lhs);

        // ---------------------------------------------------------------
        // This is same as dofaentry but it was too hard to reuse it here.
        // ---------------------------------------------------------------
        // This is the line we want to jump to when returning for the next check
        dofa_jump_top_stack.push(cg.get_curr_line());

        cg.emit_note("Storing line " + fmt_int(cg.get_curr_line()) +
            " as top of fa loop.");

        // We've entered a new fa block.
        // Create a new queue of jump to end of do/fa.
        deque<BkPatch> dofa_jump_end_q;
        dofa_jump_end_stack.push(dofa_jump_end_q);
        //---------------------------------------------------------------

        // UNTIL_VALUE - COUNTER
        lhs = cg.assign_right_reg(until_val, until_val->get_memory_loc());
        rhs = cg.assign_left_reg(counter_var, counter_var->get_memory_loc());

        cg.emit_math(SUB, IMMED_REG, lhs, rhs, "FA test.");

        // ---------------------------------------------------------------
        // This is same as dofajumpend rule, but again too hard to reuse.
        // ---------------------------------------------------------------
        if (tmDebugFlag)
        {
            cg.emit_note("RESERVE LINE " + fmt_int(cg.get_curr_line()) + 
                " FOR JUMP TO END OF DO/FA BLOCK.");
        }

        BkPatch jump_to_end;

        // Get the test register for the exp variable.
        jump_to_end.test_reg_num = IMMED_REG;
        jump_to_end.line_num = cg.get_curr_line();
        jump_to_end.note = "Jump from fa test to end of fa block.";

        dofa_jump_end_stack.top().push_back(jump_to_end);

        cg.reserve_lines(1);
    }
    ;


lvalue:
      TK_ID lvalue2    {
        // Lookup variable name in vars sym table.
        VarRec *targetVar = sm->lookup_var($<str>1);
        TypeRec *varType;

        if (!targetVar)
        {
            string errorMsg;
            errorMsg = "Undefined variable '";
            errorMsg += $<str>1;
            errorMsg += "'";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        varType = targetVar->get_type();

        // DEBUG
        if (debugFlag)
        {
            printf("ID [%s]\n", $1);
        }

        // If lvalue2 is not null check that TK_ID's array
        // dimensions are same. NOT bounds but number of recursive
        // arrays in the type. Assigning array contents in mass is
        // not legal so dereferenced array dims must be same as
        // type for variable (i.e. we have to get to a primitive or
        // alias to primitive).
        if ($<type_rec>2)
        {
            if (varType->get_base_type() != arrayI9)
            {
                string errorMsg;
                errorMsg = "Invalid type. Variable '";
                errorMsg += $<str>1;
                errorMsg += "' is not an array.";
                yyerror(errorMsg.c_str());
                exit(0);
            }

            // Construct a new VarRec pointing to dereferenced mem loc (TBD P3).
            // It's type will match the dereferenced type of TK_ID.
            TypeRec *derefType = targetVar->get_type();
            TypeRec *typeLocator = $<type_rec>2;

            do
            {
                // Check that deref type exists.
                if (derefType->get_base_type() != arrayI9)
                {
                    string errorMsg;
                    errorMsg = "Invalid type. Variable '";
                    errorMsg += $<str>1;
                    errorMsg += "' is not an array of that many dimensions.";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                derefType = derefType->get_sub_type();
                typeLocator = typeLocator->get_sub_type();

            } while (typeLocator);

            VarRec *newVarRec = new VarRec("anon_lvalue", derefType, 
                targetVar->is_global());

            // CODE GEN
            // CODE GEN
            // CODE GEN
            
            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN ARRAY DEREFERENCE --------");
            }

            // Need to init space for the new lvalue we created.
            newVarRec->set_memory_loc(cg.emit_init_int(0, 
                "Declare space for referenced array location."));

            // TODO: THIS IS GOING TO TAKE A BIT OF CODE COME BACK TO IT.
            // TODO: THIS IS GOING TO TAKE A BIT OF CODE COME BACK TO IT.
            // TODO: THIS IS GOING TO TAKE A BIT OF CODE COME BACK TO IT.
            // Emit code to do runtime array bounds overrun check.
            deque<int> source_array_dims;
            targetVar->get_type()->get_array_dims(source_array_dims);

            deque<int> deref_array_dims;
            derefType->get_array_dims(deref_array_dims);

            for (int index = 0; static_cast<unsigned int>(index) < deref_array_dims.size(); ++index)
            {
            }


            // Got lots of calculations to do so dump the resisters.
            // TODO: THIS MIGHT NOT BE NECESSARY.  TRY IT WITHOUT IT.
            cg.save_regs();

            // Mem loc has to be determined here for P3.
            // TODO: For now assume that we will always derefence to a primitive type.
            cg.emit_load_mem(IMMED_REG, targetVar->get_memory_loc(),
                targetVar->get_base_addr_reg(), 
                "Load the absolute address from memory.");

            // Skip the number of dimensions which is what is in the first loc.
            // and skip the first loc (i.e. first lock + num of dims).
            cg.emit_load_mem(LHS_REG, 0, IMMED_REG,
                "Loading number of dims.");

            cg.emit_math(ADD, IMMED_REG, LHS_REG, IMMED_REG,
                "Skipping dim sizes.");

            cg.emit_load_value(LHS_REG, 1, ZERO_REG,
                "Loading 1 for number of dims loc.");

            cg.emit_math(ADD, IMMED_REG, LHS_REG, IMMED_REG,
                "Skipping num of dims location.");

            // Work from right to left, process the indexes to get offset.
            // Set the index variable as the last one in the dereference chain.
            VarRec *index_var = array_deref_indexes.back();

            // Load the left most array dereference value.
            cg.emit_load_mem(LHS_REG, index_var->get_memory_loc(),
                index_var->get_base_addr_reg(),
                "Load the left most array dereference value.");

//            cg.emit_math(ADD, IMMED_REG, LHS_REG, IMMED_REG,
//                "Skipping to last array dimension.");
            // This intializes the AC.
            cg.emit_math(ADD, AC_REG, LHS_REG, ZERO_REG,
                "Skipping to last array dimension.");

            // Set STRIDE_REG to initial stride of 1.
            cg.emit_load_value(STRIDE_REG, 1, ZERO_REG, 
                "Init stride reg (3) with a 1.");

            array_deref_indexes.pop_back();

            int lookback_size_index = 1;

            while (array_deref_indexes.size() > 0)
            {
                cg.emit_load_mem(RHS_REG, -lookback_size_index, IMMED_REG,
                    "Load stride of previous array dim to RHS.");

                cg.emit_math(MUL, STRIDE_REG, RHS_REG, STRIDE_REG,
                    "Calc the stride of next array dim back.");

                VarRec *index_var = array_deref_indexes.back();

                // Load the next left most array dereference value.
                cg.emit_load_mem(LHS_REG, index_var->get_memory_loc(),
                    index_var->get_base_addr_reg(),
                    "Load the next left most array dereference value.");

                cg.emit_math(MUL, RHS_REG, LHS_REG, STRIDE_REG,
                    "Calc offset for next array dereg back.");

                cg.emit_math(ADD, AC_REG, RHS_REG, AC_REG,
                    "Add the offset from this dereference.");

                // SET THE RHS. WIDTH
                // DO THE WIDTH IN A WAY THAT CAN BE DONE THE SAME FOR THE RIGHTMOST
                // AND THE OTHERS.  MULTIPLY by 1's. MAYBE INIT SOME REGS with 1's.
                array_deref_indexes.pop_back();

                // Set the lookback index to look back another level.
                ++lookback_size_index;
            }

            cg.emit_math(ADD, IMMED_REG, IMMED_REG, AC_REG,
                "Add the total offset from dereference to the address.");

            cg.emit_store_mem(IMMED_REG, newVarRec->get_memory_loc(),
                newVarRec->get_base_addr_reg(),
                "Store the absolute address in the dereferenced variable loc.");

            // Mark this as a reference variable.
            newVarRec->set_is_reference(true);

            // Restore the registers we swept off earlier.
            cg.restore_regs();

            // Clear the index list
            array_deref_indexes.clear();

            $$ = newVarRec;

            if (tmDebugFlag)
            {
                cg.emit_note("------- END ARRAY DEREFERENCE --------");
            }
        }
        else
        {
            // This was not an array dereference just a basic
            // type so just return the variable record.
            $$ = targetVar;
        }
        }
      ;

lvalue2:
       /* empty rule */     { $$ = 0; }
      | TK_LBRACK exp TK_RBRACK lvalue2 
    {
        // Array dereference; exp must be int.
        if (!is_int($<var_rec>2->get_type()))
        {
            string errorMsg;
            errorMsg = "Invalid type. Int required for array dereference";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // Store the variable representing the array index.
        // NOTE: This doesn't need to be a stack because exp already
        //      ran by the time this rule runs so even in multiple dim
        //      arrays they should not collide.
        array_deref_indexes.push_front($<var_rec>2);

        // Construct an array type record.
        // The size is irrelevant. Only used for # of dims test.
        // The primitive subtype will be null which is ok too
        // because the lvalue.TK_ID lookup will determine the sub.
        $$ = new TypeRec("anonymous", arrayI9, $<type_rec>4, 1);
    }
    ;

exp:
   lvalue
   {
        $$ = $<var_rec>1;
   }
   | TK_INT
        {
            // Ints have a max size. Check it. Use long so not to
            // overflow the C int.
            if (atol($<str>1) > MAX_INT_I9_SIZE)
            {
                string errorMsg;
                errorMsg = "Integer values must be between -2147483648 and 2147483647";
                yyerror(errorMsg.c_str());
                exit(0);
            }

            // DEBUG
            //printf("RETURNING INT FROM %s (prt: %p)", $<str>1, static_cast<void *>(sm->lookup_type("int")));

            // Look up the int type.
            TypeRec *target_type = sm->lookup_type("int");
            $$ = new VarRec("@int_literal", target_type, is_global_scope(), true, $<str>1);


            // CODE GEN
            // CODE GEN
            // CODE GEN
            $$->set_memory_loc(cg.emit_init_int(atoi($$->get_value().c_str()), 
                "Storing int literal " + $$->get_value()));
        }
   | TK_TRUE    
    { 
        TypeRec *target_type = sm->lookup_type("bool");
        //$$ = new VarRec("@bool_literal_true", target_type, true, true, "1");
        $$ = new VarRec("@bool_literal_true", target_type, is_global_scope(), true, "1");


        // CODE GEN
        // CODE GEN
        // CODE GEN
        $$->set_memory_loc(cg.emit_init_int(atoi($$->get_value().c_str()), 
            "Storing bool literal true " + $$->get_value()));
    }
   | TK_FALSE
    { 
        TypeRec *target_type = sm->lookup_type("bool");
        //$$ = new VarRec("@bool_literal_false", target_type, true, true, "0");
        $$ = new VarRec("@bool_literal_false", target_type, is_global_scope(), true, "0");


        // CODE GEN
        // CODE GEN
        // CODE GEN
        $$->set_memory_loc(cg.emit_init_int(atoi($$->get_value().c_str()), 
            "Storing bool literal false " + $$->get_value()));
    }
   | TK_SLIT    
    { 
        TypeRec *target_type = sm->lookup_type("string");
        $$ = new VarRec("string_literal", target_type, is_global_scope(), true, $<str>1);

        // CODE GEN
        // CODE GEN
        // CODE GEN
        // TODO: DO STRINGS LATER. REMEMBER DROP SIZE BEFORE STRING CHARS.
    }
   | TK_READ    
    { 
        // THE READ PULLS AN INT THAT THE USER ENTERS.
        TypeRec *target_type = sm->lookup_type("int");

        $$ = new VarRec("@int_user_lit", target_type, is_global_scope(), true, "0");


        // CODE GEN
        // CODE GEN
        // CODE GEN
        // This will get the correct memory offset and keep the data call in sync.
        // Must be before the IN because they both use the IMMED_REG.
        $$->set_memory_loc(cg.emit_init_int(0, 
            "Storing bogus literal for READ value."));

        // Emit an IN and get a register to store it in.
        //int rhs_reg = cg.get_reg_assign($$);
        //cg.emit_io(IN, rhs_reg, "Read int from user.");
        cg.emit_io(IN, IMMED_REG, "Read int from user.");

        if (in_proc_defn_flag)
        {
            cg.emit_store_mem(IMMED_REG, $$->get_memory_loc(), FP_REG,
                "Storing immediate int to frame memory from user input.");
        }
        else
        {
            cg.emit_store_mem(IMMED_REG, $$->get_memory_loc(), ZERO_REG,
                "Storing immediate int to global memory from user input.");
        }
    }
   | TK_MINUS exp  
    {
        if (!is_int_or_boolean($<var_rec>2->get_type()))
        {
            // TYPE ERROR!
            yyerror("Incompatible type for unary minus");
            exit(0);
        }


        TypeRec *target_type = $<var_rec>2->get_type();

        // Need a return variable.
        VarRec *rtn_var = new VarRec("@unary_minus_return", target_type, 
            is_global_scope());

        // Get available register for -1 use.
//        VarRec *neg_one_var = new VarRec("@neg_one", target_type, true, "-1");

        // CODE GEN
        // CODE GEN
        // CODE GEN
        int rhs_reg = cg.assign_right_reg($<var_rec>2, $<var_rec>2->get_memory_loc());

        // Assign the return value to the accumulator.
        // Must not be assigned until the RHS regsiter is determined because it might
        // be the AC too, but that is okay.
        cg.assign_to_ac(rtn_var);

        // The implied neg one needs to be stored in memory.
//        neg_one_var->set_memory_loc(cg.emit_init_int(
//            atoi(neg_one_var->get_value().c_str()), 
//            "Storing neg one literal " + neg_one_var->get_value()));

//        int neg_one_reg = cg.get_reg_assign(neg_one_var);

        // To make this negative just create a -1 register and multiply.
//        cg.emit_load_value(neg_one_reg, -1, ZERO_REG, "Load -1 into register");
        cg.emit_load_value(IMMED_REG, -1, ZERO_REG, "Load -1 into immediate register");
        cg.emit_math(MUL, AC_REG, IMMED_REG, rhs_reg, "Unary minus op");
    }
   | TK_QUEST exp  
    {
        if (is_boolean($<var_rec>2->get_type())) {
            // Question returns an int type.
            TypeRec *target_type = sm->lookup_type("int");

            // Since true is 1 and false is 0 to convert to an int just
            // copy the variable but changine the type.
            // This value should be created in the same scope as the exp variable.
            $$ = new VarRec("quest_rtn_val", target_type, $<var_rec>2->is_global(), 
                true, $<var_rec>2->get_value());
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible type for unary question operator");
            exit(0);
        }


        // CODE GEN
        // CODE GEN
        // CODE GEN
        // NOTE: THIS IS A SEMANTIC CHANGE. MY ASSUMPTION IS THAT 
        //      TRUE (1) AND FALSE (0) WILL BECOME THE INT.
    }
   | TK_ID TK_LPAREN TK_RPAREN
        {
            // Parameter-less proc call.
            ProcRec *proc_target = sm->lookup_proc($<str>1);

            if (proc_target)
            {
                if (proc_target->get_param_list())
                {
                    // Param list not empty.
                    string errorMsg;
                    errorMsg = "Invalid parameter list for '";
                    errorMsg += $<str>1;
                    yyerror(errorMsg.c_str());
                    exit(0);
                }
                else
                {
                    // This might be null if proc (vs function) but
                    // the next level up will determine if that matters.
                    if (proc_target->get_return_type())
                    {
                        // The activation record will be created with this
                        // memory location to return the value in.
                        $$ = new VarRec("alias_rtn_val",
                            proc_target->get_return_type(),
                            is_global_scope());

                        // CODE GEN
                        // CODE GEN
                        // CODE GEN

                        // Must allocate space for this guy.
                        cg.emit_init_int(0, "Allocating space for return target.");
                    }
                    else
                    {
                        // There is no return value.
                        $$ = 0;
                    }
                }
            }
            else
            {
                // Proc call not found.
                string errorMsg;
                errorMsg = "Proc '";
                errorMsg += $<str>1;
                errorMsg += "' is not declared.";
                yyerror(errorMsg.c_str());
                exit(0);
            }


            // CODE GEN
            // CODE GEN
            // CODE GEN

            if (tmDebugFlag)
            {
                cg.emit_note("--------- BEGIN PARAMETERLESS PROC CALL ---------");
            }

            // Determine number of lines to reserve.
            // There are no parameters in this type of call.
            // Start with one for each of frame size, AC state, return PC.
            int skips = 5;

            // If there is a return value then it will take 2 instructions.
            if ($$)
            {
                skips += 2;
            }

            int bkpatch_line = cg.get_curr_line();

            cg.reserve_lines(skips);

            if (proc_target->get_frame_size() == 0)
            {
                // Either this is a recursive call or a forward that has not yet
                // been defined.
                // Defer the init of the frame until we know where to write to.
                BkPatchProc backpatch;

                backpatch.param_list = 0;
                backpatch.return_var = $$;
                backpatch.line_num = bkpatch_line;

                // Return PC will be one after the current line because the last
                // thing we will do after this is an LDA to "call" the function.
                backpatch.control_link = (cg.get_curr_line() + 1);
                backpatch.note = "Back patching a parameterless function.";

                // Use the map to determine if another back patch has been queued.
                map<ProcRec *, deque<BkPatchProc> >::iterator iter;

                iter = proc_ar_backpatches.find(proc_target);

                if (iter == proc_ar_backpatches.end())
                {
                    // No back patches have been queued. Create a new deque
                    // insert this one and move on.
                    deque<BkPatchProc> bplist;

                    bplist.push_back(backpatch);

                    proc_ar_backpatches.insert(make_pair(proc_target, bplist));
                }
                else
                {
                    // Add this one to the list.
                    iter->second.push_back(backpatch);
                }
            }
            else
            {
                // Now we need to back patch the lines we just skipped.
                init_ar(proc_target, 0, $$, (cg.get_curr_line() + 1),
                    "Already know the frame size of this parameterless call", 
                    bkpatch_line);
            }

            // Last thing to do is make the call to the function.
            cg.emit_load_value(PC_REG, proc_target->get_memory_loc(), ZERO_REG,
                "Calling function: " + proc_target->get_name());

            if (tmDebugFlag)
            {
                cg.emit_note("--------- END PARAMETERLESS PROC CALL ---------");
            }
        }
   | TK_ID TK_LPAREN expx TK_RPAREN
        {
            // Parametered proc call.
            ProcRec *proc_target = sm->lookup_proc($<str>1);

            if (proc_target)
            {
                list<VarRec *> *param_list = proc_target->get_param_list();
                list<VarRec *> *called_params = 0;

                if(!param_list)
                {
                    // Param list not empty.
                    string errorMsg;
                    errorMsg = "Invalid parameter list for ";
                    errorMsg += $<str>1;
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                called_params = $<var_rec_list>3;

                // Quick check on number of params.
                if (called_params->size() != param_list->size())
                {
                    // Called number of params doesn't match proc type.
                    string errorMsg;
                    errorMsg = "Invalid number of parameters for ";
                    errorMsg += $<str>1;
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                list<VarRec *>::iterator iter;
                list<VarRec *>::iterator param_iter = param_list->begin();

                // Make sure that the called types match the param
                // list types.
                for(iter = called_params->begin(); iter != called_params->end(); ++iter)
                {
                    if (!(*iter)->get_type()->equal((*param_iter)->get_type()))
                    {
                        // Param types do not match.
                        string errorMsg;
                        errorMsg = "Incompatible parameter type for ";
                        errorMsg += $<str>1;
                        yyerror(errorMsg.c_str());
                        exit(0);
                    }

                    // Already know list sizes are same so for will
                    // protect param_iter from overrunning end.
                    ++param_iter;
                }

                // This might be null if proc (vs function) but
                // the next level up will determine if that matters.
                if (proc_target->get_return_type())
                {
                    // The activation record will be created with this
                    // memory location to return the value in.
                    $$ = new VarRec("alias_rtn_val", proc_target->get_return_type(),
                        is_global_scope());

                    // CODE GEN
                    // CODE GEN
                    // CODE GEN

                    // Must allocate space for this guy.
                    cg.emit_init_int(0, "Allocating space for return target.");
                }
                else
                {
                    // There is no return value.
                    $$ = 0;
                }

                // CODE GEN
                // CODE GEN
                // CODE GEN

                if (tmDebugFlag)
                {
                    cg.emit_note("--------- BEGIN PARAMETERED PROC CALL ---------");
                }

                // Determine number of lines to reserve.
                // Start with one for loading future FP value.
                // Add 2 for storing frame size, 1 for AC state, 
                // and 2 for return PC. Total = 5.
                int skips = 5;

                // It takes 3 instructions to copy each parameter.
                skips += (called_params->size() * 3);

                // If there is a return value then it will take 2 instructions.
                if ($$)
                {
                    skips += 2;
                }

                int bkpatch_line = cg.get_curr_line();

                cg.reserve_lines(skips);

                if (proc_target->get_frame_size() == 0)
                {
                    // Either this is a recursive call or a forward that has not yet
                    // been defined.
                    // Defer the init of the frame until we know where to write to.
                    BkPatchProc backpatch;

                    backpatch.param_list = called_params;
                    backpatch.return_var = $$;
                    backpatch.line_num = bkpatch_line;

                    // Return PC will be one after the current line because the last
                    // thing we will do after this is an LDA to "call" the function.
                    backpatch.control_link = (cg.get_curr_line() + 1);
                    backpatch.note = "Back patching a parametered function.";

                    map<ProcRec *, deque<BkPatchProc> >::iterator iter;

                    iter = proc_ar_backpatches.find(proc_target);

                    if (iter == proc_ar_backpatches.end())
                    {
                        // No back patches have been queued. Create a new deque
                        // insert this one and move on.
                        deque<BkPatchProc> bplist;

                        bplist.push_back(backpatch);

                        proc_ar_backpatches.insert(make_pair(proc_target, bplist));
                    }
                    else
                    {
                        // Add this one to the list.
                        iter->second.push_back(backpatch);
                    }
                }
                else
                {
                    // Now we need to back patch the lines we just skipped.
                    init_ar(proc_target, called_params, $$, (cg.get_curr_line() + 1),
                        "Already know the frame size of this parametered call", 
                        bkpatch_line);

                    // The param list has been processed.
                    // The expx list contains pointers already maintined in
                    // the type symbol table so we can just throw the list
                    // away without concern for the pointers.
                    delete $<var_rec_list>3;
                }

                // Last thing to do is make the call to the function.
                cg.emit_load_value(PC_REG, proc_target->get_memory_loc(), ZERO_REG,
                    "Calling function: " + proc_target->get_name());

                if (tmDebugFlag)
                {
                    cg.emit_note("--------- END PARAMETERED PROC CALL ---------");
                }
            }
            else
            {
                // The expx list contains pointers already maintined in
                // the type symbol table so we can just throw the list
                // away without concern for the pointers.
                delete $<var_rec_list>3;

                // Proc call not found.
                string errorMsg;
                errorMsg = "Proc '";
                errorMsg += $<str>1;
                errorMsg += "' is not declared.";
                yyerror(errorMsg.c_str());
                exit(0);
            }
        }
   | exp TK_PLUS exp
    {
        if (are_int_or_boolean($<var_rec>1->get_type(), $<var_rec>3->get_type())) 
        {
            VarRec *rtn_var = new VarRec("addition_return", $<var_rec>1->get_type(), is_global_scope());

            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (is_int($<var_rec>1->get_type()))
            {
                // Do integer addition.
                cg.emit_math(ADD, AC_REG, lhs_reg, rhs_reg, "PLUS INT OP");
            }
            else
            {
                // Do boolean OR.
                if (tmDebugFlag)
                {
                    cg.emit_note("------- BEGIN BOOLEAN PLUS (OR) ---------");
                }

                cg.emit_math(ADD, AC_REG, lhs_reg, rhs_reg, "ADD to check bool OR.");

                // If false skip "then".
                cg.emit_jump(JEQ, AC_REG, 2, PC_REG,
                    "If BOOL == 0 skip next 2 lines.");

                // "Then" True = set return to 1.
                cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

                // Skip the "else" stmt.
                cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                    "Unconditional jump - skip else");

                // "Else" False = set return to 0.
                cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

                if (tmDebugFlag)
                {
                    cg.emit_note("------- END BOOLEAN PLUS (OR) ---------");
                }
            }

            $$ = rtn_var;
        }
        else 
        {
            // TYPE ERROR!
            yyerror("Incompatible types for binary plus operator");
            exit(0);
        }
    }
   | exp TK_MINUS exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) 
        {
            VarRec *rtn_var = new VarRec("subtr_return", $<var_rec>1->get_type(),
                is_global_scope());

            // Do integer subtraction.
            $$ = rtn_var;

            // CODE GEN
            // CODE GEN
            // CODE GEN
            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT SUBTRACTION ---------");
            }

            // Get rhs and lhs register assignments.
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            // Do integer subtraction.
            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "BINARY MINUS INT OP");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT SUBTRACTION ---------");
            }
        }
        else 
        {
            // TYPE ERROR!
            yyerror("Incompatible types for binary minus");
            exit(0);
        }
    }
   | exp TK_STAR exp
    {
        if (are_int_or_boolean($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            VarRec *rtn_var = new VarRec("starop_return", $<var_rec>1->get_type(),
                is_global_scope());

            // Get the exp register assignments.
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (is_int($<var_rec>1->get_type()))
            {
                // Do integer multiplication.
                cg.emit_math(MUL, AC_REG, lhs_reg, rhs_reg, "MULTIPLY INT OP");
            }
            else
            {
                // Do boolean AND.
                if (tmDebugFlag)
                {
                    cg.emit_note("------- BEGIN BOOLEAN PLUS (AND) ---------");
                }

                cg.emit_math(MUL, AC_REG, lhs_reg, rhs_reg, "MUL to check bool AND.");

                if (tmDebugFlag)
                {
                    cg.emit_note("------- END BOOLEAN PLUS (AND) ---------");
                }
            }

            $$ = rtn_var;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary multiplication operator");
            exit(0);
        }
    }
   | exp TK_SLASH exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            VarRec *rtn_var = new VarRec("division_return", $<var_rec>1->get_type(),
                is_global_scope());

            // Do integer division.
            $$ = rtn_var;

            // CODE GEN
            // CODE GEN
            // CODE GEN
            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT DIVISION ---------");
            }

            // Get rhs and lhs register assignments.
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            // Do integer division.
            cg.emit_math(DIV, AC_REG, lhs_reg, rhs_reg, "BINARY DIVISION INT OP");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT DIVISION ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for division operator");
            exit(0);
        }
    }
   | exp TK_MOD exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            VarRec *rtn_var = new VarRec("mod_return", $<var_rec>1->get_type(),
                is_global_scope());

            // Do integer modulus.
            $$ = rtn_var;

            // CODE GEN
            // CODE GEN
            // CODE GEN
            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT MOD ---------");
            }

            // Get the rhs and lhs register assignments.
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            // Do integer MOD.
            // 1. Do division with same values and save value.
            // 2. Multiply denominator by #1 result.
            // 3. Subtract #2 result from numerator.
            cg.emit_math(DIV, AC_REG, lhs_reg, rhs_reg, "MOD OP - Step 1 Do div.");
            cg.emit_math(MUL, AC_REG, AC_REG, rhs_reg, 
                "MOD OP - Step 2 Mul #1xDenom");
            cg.emit_math(SUB, AC_REG, lhs_reg, AC_REG, 
                "MOD OP - Step 3 Sub #2 from numerator.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT MOD ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for modulo operator");
            exit(0);
        }
    }
   | exp TK_EQ exp
    {
        if (are_int_or_boolean($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            // Equal comparison always returns boolean type.
            VarRec *rtn_var = new VarRec("EQ_return", sm->lookup_type("bool"),
                is_global_scope());

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT/BOOL EQUAL (==) ---------");
            }

            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "SUB to check equality.");

            // If difference != 0 skip "then".
            cg.emit_jump(JNE, AC_REG, 2, PC_REG,
                "If difference != 0 skip next 2 lines.");

            // "Then" values are same set return to 1.
            cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

            // Skip the "else" stmt.
            cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                "Unconditional jump - skip else");

            // "Else" values are different set return to 0.
            cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT/BOOL EQUAL (==) ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary comparison equal");
            exit(0);
        }
    }
   | exp TK_NEQ exp
    {
        if (are_int_or_boolean($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            // Not equal comparison always returns boolean type.
            VarRec *rtn_var = new VarRec("NEQ_return", sm->lookup_type("bool"),
                is_global_scope());

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT/BOOL NOT EQUAL (==) ---------");
            }

            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "SUB to check not equal.");

            // If difference == 0 skip "then".
            cg.emit_jump(JEQ, AC_REG, 2, PC_REG,
                "If difference == 0 skip next 2 lines.");

            // "Then" values are same set return to 1.
            cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

            // Skip the "else" stmt.
            cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                "Unconditional jump - skip else");

            // "Else" values are different set return to 0.
            cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT/BOOL NOT EQUAL (==) ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary comparison not equal");
            exit(0);
        }
    }
   | exp TK_GT exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            // Greater than comparison always returns boolean type.
            VarRec *rtn_var = new VarRec("GT_return", sm->lookup_type("bool"),
                is_global_scope());

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT GREATER THAN (>) ---------");
            }

            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "SUB to check greater than.");

            // If difference > 0 skip "then".
            cg.emit_jump(JGT, AC_REG, 2, PC_REG,
                "If difference > 0 skip next 2 lines.");

            // "Then" lhs <= rhs set return to 0.
            cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

            // Skip the "else" stmt.
            cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                "Unconditional jump - skip else");

            // "Else" lhs > rhs set return to 1.
            cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT GREATER THAN (>) ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary greater than operator");
            exit(0);
        }
    }
   | exp TK_LT exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            // Less than comparison always returns boolean type.
            VarRec *rtn_var = new VarRec("LT_return", sm->lookup_type("bool"),
                is_global_scope());

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT LESS THAN (<) ---------");
            }

            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "SUB to check less than.");

            // If difference < 0 skip "then".
            cg.emit_jump(JLT, AC_REG, 2, PC_REG,
                "If difference < 0 skip next 2 lines.");

            // "Then" lhs >= rhs set return to 0.
            cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

            // Skip the "else" stmt.
            cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                "Unconditional jump - skip else");

            // "Else" lhs > rhs set return to 1.
            cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT LESS THAN (>) ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary less than operator");
            exit(0);
        }
    }
   | exp TK_GE exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            // Greater than equal comparison always returns boolean type.
            VarRec *rtn_var = new VarRec("GE_return", sm->lookup_type("bool"),
                is_global_scope());

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT GREATER THAN EQ (>=) ---------");
            }

            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "SUB to check greater than.");

            // If difference >= 0 skip "then".
            cg.emit_jump(JGE, AC_REG, 2, PC_REG,
                "If difference >= 0 skip next 2 lines.");

            // "Then" lhs < rhs set return to 0.
            cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

            // Skip the "else" stmt.
            cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                "Unconditional jump - skip else");

            // "Else" lhs > rhs set return to 1.
            cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT GREATER THAN EQ (>=) ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary greater than or equal operator");
            exit(0);
        }
    }
   | exp TK_LE exp
    {
        if (are_int($<var_rec>1->get_type(), $<var_rec>3->get_type())) {
            // Less than or equal comparison always returns boolean type.
            VarRec *rtn_var = new VarRec("LE_return", sm->lookup_type("bool"),
                is_global_scope());

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.assign_left_reg($<var_rec>1, $<var_rec>1->get_memory_loc());
            int rhs_reg = cg.assign_right_reg($<var_rec>3, $<var_rec>3->get_memory_loc());    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT LESS THAN EQ (<=) ---------");
            }

            cg.emit_math(SUB, AC_REG, lhs_reg, rhs_reg, "SUB to check less than.");

            // If difference <= 0 skip "then".
            cg.emit_jump(JLE, AC_REG, 2, PC_REG,
                "If difference <= 0 skip next 2 lines.");

            // "Then" lhs > rhs set return to 0.
            cg.emit_load_value(AC_REG, 0, ZERO_REG, "Set return val to false 0.");

            // Skip the "else" stmt.
            cg.emit_jump(JEQ, ZERO_REG, 1, PC_REG, 
                "Unconditional jump - skip else");

            // "Else" lhs > rhs set return to 1.
            cg.emit_load_value(AC_REG, 1, ZERO_REG, "Set return val to true 1.");

            if (tmDebugFlag)
            {
                cg.emit_note("------- END INT LESS THAN EQ (<=) ---------");
            }
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary less than or equal operator");
            exit(0);
        }
    }
   | TK_LPAREN exp TK_RPAREN    
    { 
        // This signifies an immediate evaluation of all exps within these parens.
        $$ = $<var_rec>2; 
    }
   ;

expx:
    exp
    {
        // Create a new param variable list and stuff this param into it.
        list<VarRec *> *params = new list<VarRec *>();
        params->push_back($<var_rec>1);

        $$ = params;
    }
    | expx TK_COMMA exp
    {
        list<VarRec *> *params = $<var_rec_list>1;
        params->push_back($<var_rec>3);

        $$ = params;
    }
    ;
%%


int main(int argc, char* argv[])
{
    int tok;
    int spewTokens = 0;
    
    // Process the output file name.
    if (argc == 2)
    {
        // File name is argument 2 (index 1).
        cg.init_out_file(argv[1]);
    }
    else
    {
        // The file name was not specified.
        printf("USAGE: ice9 {target_file} < {source_file}");

        return 1;
    }

    if (spewTokens) {
        while (1) {
          tok = yylex();
          if (tok == 0) break;
          switch (tok) {
          case TK_ID:
            printf("ID  : \t\"%s\"\n", yylval.str);
            break;
          case TK_INT:
            //printf("ILIT:\t%d\n", yylval.intt);
            // Changed int to store as string.
            printf("ILIT:\t%s\n", yylval.str);
            break;
          default:
            printf("TOK : \t%d\n", tok);
          }
        }
    }
    else {
      // Where the real compile code starts.
      yyparse();
    }

    delete sm;

    return 0;
}
