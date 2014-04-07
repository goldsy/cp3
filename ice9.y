%{

#include <stdio.h>
#include <math.h>
#include <string>
#include <list>
#include <iostream>

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
%%

/* START */
program:
       defs stms0 { cg.emit(HALT, "END OF PROGRAM"); /* printf("%s\n", sm->knock_knock().c_str()); */ }
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
                printf("typeid ptr: %p  arraydims ptr: %p", static_cast<void *>($<type_rec>3), static_cast<void *>($<type_rec>4));
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
                VarRec *temp = new VarRec(*iter, target_type);

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
                if (is_int_or_boolean(target_type))
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

            $$ = new TypeRec("anonymous", arrayI9, $<type_rec>4, atoi($<str>2));
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
            if (in_proc_defn_flag)
            {
                // These variables need to be entered in table now.
                list<VarRec*> *scope_vars = $<var_rec_list>1;

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
                    }
                }
            }

            proc_var_rec_list = $<var_rec_list>1;

            $$ = $<var_rec_list>1;
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
                VarRec *temp = new VarRec(*id_iter, $<type_rec>3);
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
        // Set the in_proc_defn_flag = false;
        in_proc_defn_flag = false;

        // We've now exited the scope.
        sm->exit_scope();
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
            }
         }
         ;

prochelper:
          /* empty rule */
          {
            // stuff the return variable in the table.
            if ($<type_rec>0)
            {
                VarRec *rtn_var = new VarRec(proc_name, $<type_rec>0);

                if ( !sm->insert_var(rtn_var) )
                {
                    string errorMsg;
                    errorMsg = "Duplicate variable name '";
                    errorMsg += proc_name;
                    errorMsg += "' for function return type";
                    yyerror(errorMsg.c_str());
                    exit(0);
                }
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
   }
   | TK_EXIT TK_SEMI
   | TK_RETURN TK_SEMI
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
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

            cg.emit_load_value(lhs_reg, 0, rhs_reg, "Assignment of " +
                $<var_rec>3->get_name() + " to " + $<var_rec>1->get_name());
        }
        else
        {
            // Otherwise we are dealing with a string.
            // TODO: FINISH STRING ASSIGNMENT.
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

        int rhs_reg = cg.get_reg_assign($<var_rec>2);    

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

        int rhs_reg = cg.get_reg_assign($<var_rec>2);    

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
  TK_IF exp TK_ARROW stms if2 if4
  {
    // exp must be a bool.
    TypeRec *bool_rec = sm->lookup_type("bool");

    if (!bool_rec->equal($<var_rec>2->get_type()))
    {
        // Type is not boolean.
        string errorMsg;
        errorMsg = "Invalid type: if expression must be boolean type";
        yyerror(errorMsg.c_str());
        exit(0);
    }
  }
  ;

if2:
   /* empty rule */
   | if2 TK_BOX exp TK_ARROW stms
      {
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
      }
   ;

if4:
   TK_FI
   | TK_BOX TK_ELSE TK_ARROW stms TK_FI
   ;

do:
  TK_DO doentry exp TK_ARROW stms0 TK_OD
  {
    // exp must be a bool.
    TypeRec *bool_rec = sm->lookup_type("bool");

    if (!bool_rec->equal($<var_rec>3->get_type()))
    {
        // Type is not boolean.
        string errorMsg;
        errorMsg = "Invalid type: do expression must be boolean type";
        yyerror(errorMsg.c_str());
        exit(0);
    }

    // Decrement the loop count. Leaving the do loop.
    --do_count;
  }
  ;

doentry:
       /* empty rule */
       {
            // No scope change, but need to track do's for break usage.
            ++do_count;
       }
       ;

fa:
  TK_FA TK_ID faentry TK_ASSIGN exp TK_TO exp TK_ARROW stms0 TK_AF
  {
        TypeRec *int_rec = sm->lookup_type("int");

        // Both expressions must be an int.
        if (!int_rec->equal($<var_rec>5->get_type())
            || !int_rec->equal($<var_rec>7->get_type()))
        {
            // Variable undefined.
            string errorMsg;
            errorMsg = "Invalid fa expression type. Expressions must be int";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // Leaving fa scope.
        --fa_count;

        sm->exit_scope();
  }
  ;

faentry:
       /* empty rule */
       {
            sm->enter_scope();
            ++fa_count;
            VarRec *id_rec = new VarRec($<str>0, sm->lookup_type("int"));
            id_rec->set_loop_counter_flag(true);
            sm->insert_var(id_rec);
       }
       ;

lvalue:
      TK_ID lvalue2    {
        // Lookup variable name in vars sym table.
        VarRec *tempVar = sm->lookup_var($<str>1);
        TypeRec *varType;

        if (!tempVar)
        {
            string errorMsg;
            errorMsg = "Undefined variable '";
            errorMsg += $<str>1;
            errorMsg += "'";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        varType = tempVar->get_type();

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
            TypeRec *derefType = tempVar->get_type();
            TypeRec *typeLocator = $<type_rec>2;

            // TODO: CLEANUP DEBUG STATEMENTS AFTER TESTING.
            //int temp = 1;
            // typeLocator will be null at primitive level.
            do
            {
                //printf("DO WHILE LOOP%s\n", typeLocator->to_string().c_str(), temp);
                //printf("DO WHILE LOOP %d\n", temp);
                //++temp;
                //fflush(0);

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

                // Mem loc has to be determined here for P3.
            } while (typeLocator);

            VarRec *newVarRec = new VarRec("anon_lvalue", derefType);

            $$ = newVarRec;
        }
        else
        {
            // This was not an array dereference just a basic
            // type so just return the variable record.
            $$ = tempVar;
        }
        }
      ;

lvalue2:
       /* empty rule */     { $$ = 0; }
      | TK_LBRACK exp TK_RBRACK lvalue2 {
        // Array dereference; exp must be int.
        if (!is_int($<var_rec>2->get_type()))
        {
            string errorMsg;
            errorMsg = "Invalid type. Int required for array dereference";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // Construct an array type record.
        // The size is irrelevant. Only used for # of dims test.
        // The primitive subtype will be null which is ok too
        // because the lvalue.TK_ID lookup will determine the sub.
        // TODO: For code gen the int is the index and is needed.
        //      I may need to add a new container class to handle
        //      passing values(s-lits, int-lits, var names, proc
        //      names)
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
            $$ = new VarRec("@int_literal", target_type, true, $<str>1);


            // CODE GEN
            // CODE GEN
            // CODE GEN
            $$->set_memory_loc(cg.emit_init_int(atoi($$->get_value().c_str()), 
                "Storing int literal " + $$->get_value()));
        }
   | TK_TRUE    
    { 
        TypeRec *target_type = sm->lookup_type("bool");
        $$ = new VarRec("@bool_literal_true", target_type, true, "1");


        // CODE GEN
        // CODE GEN
        // CODE GEN
        $$->set_memory_loc(cg.emit_init_int(atoi($$->get_value().c_str()), 
            "Storing bool literal true " + $$->get_value()));
    }
   | TK_FALSE
    { 
        TypeRec *target_type = sm->lookup_type("bool");
        $$ = new VarRec("@bool_literal_false", target_type, true, "0");


        // CODE GEN
        // CODE GEN
        // CODE GEN
        $$->set_memory_loc(cg.emit_init_int(atoi($$->get_value().c_str()), 
            "Storing bool literal false " + $$->get_value()));
    }
   | TK_SLIT    
    { 
        TypeRec *target_type = sm->lookup_type("string");
        $$ = new VarRec("string_literal", target_type, true, $<str>1);

        // CODE GEN
        // CODE GEN
        // CODE GEN
        // TODO: DO STRINGS LATER. REMEMBER DROP SIZE BEFORE STRING CHARS.
    }
   | TK_READ    
    { 
        // TODO: THE READ PULLS AN INT THAT THE USER ENTERS.  FIGURE THIS ONE OUT.
        //      FOR NOW JUST RETURN A KNOWN VALUE THAT CAN BE TESTED.
        //      ??? RUNTIME CHECK FOR INT ???
        TypeRec *target_type = sm->lookup_type("int");
        //      FOR NOW JUST RETURN A KNOWN VALUE THAT CAN BE TESTED.
        //      FOR NOW JUST RETURN A KNOWN VALUE THAT CAN BE TESTED.
        //      FOR NOW JUST RETURN A KNOWN VALUE THAT CAN BE TESTED.
        $$ = new VarRec("@int_literal", target_type, true, "0");


        // CODE GEN
        // CODE GEN
        // CODE GEN
        // Emit an IN and get a register to store it in.
        int rhs_reg = cg.get_reg_assign($$);
        cg.emit_io(IN, rhs_reg, "Read int from user.");
    }
   | TK_MINUS exp  
    {
        if (is_int_or_boolean($<var_rec>2->get_type())) {
            $$ = $<var_rec>2;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible type for unary minus");
            exit(0);
        }


        // CODE GEN
        // CODE GEN
        // CODE GEN
        // TODO: UNARY MINUS OP ON EXP MIGHT NOT CHANGE VALUE IN VARIABLE.
        // TODO: UNARY MINUS OP ON EXP MIGHT NOT CHANGE VALUE IN VARIABLE.
        // TODO: UNARY MINUS OP ON EXP MIGHT NOT CHANGE VALUE IN VARIABLE.
        int rhs_reg = cg.get_reg_assign($$);

        // Get available register for temp use.
        int neg_one_reg = cg.get_reg_assign(0);

        // To make this negative just create a -1 register and multiply.
        cg.emit_load_value(neg_one_reg, -1, ZERO_REG, "Load -1 into register");
        cg.emit_math(MUL, rhs_reg, neg_one_reg, rhs_reg, "Unary minus op");
    }
   | TK_QUEST exp  
    {
        if (is_boolean($<var_rec>2->get_type())) {
            // Question returns an int type.
            TypeRec *target_type = sm->lookup_type("int");

            // TODO: GIVE THIS SOME THOUGHT.
            // Since true is 1 and false is 0 to convert to an int just
            // copy the variable but changine the type.
            // TODO: CHECK OUT RETURN BY REFERENCE FOR RETURN VALUES IN FUNCTIONS.
            //      THE CONSTANT FLAG MIGHT NOT FLY AND CREATING A NEW VARIABLE MIGHT
            //      NOT EITHER.
            $$ = new VarRec("quest_rtn_val", target_type, true,
                $<var_rec>2->get_value());
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
                            proc_target->get_return_type());

                        // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED.
                        // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED.
                        // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED.
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
            // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED IF ONE.
            // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED IF ONE.
            // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED IF ONE.
        }
   | TK_ID TK_LPAREN expx TK_RPAREN
        {
            // Parametered proc call.
            ProcRec *proc_target = sm->lookup_proc($<str>1);

            if (proc_target)
            {
                list<VarRec *> *param_list = proc_target->get_param_list();

                if(!param_list)
                {
                    // Param list not empty.
                    string errorMsg;
                    errorMsg = "Invalid parameter list for ";
                    errorMsg += $<str>1;
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                list<VarRec *> *called_params = $<var_rec_list>3;

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
                    $$ = new VarRec("alias_rtn_val", proc_target->get_return_type());

                    // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED.
                    // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED.
                    // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED.
                }
                else
                {
                    // There is no return value.
                    $$ = 0;
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

            // The expx list contains pointers already maintined in
            // the type symbol table so we can just throw the list
            // away without concern for the pointers.
            delete $<var_rec_list>3;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED IF ONE.
            // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED IF ONE.
            // TODO: THE CALL NEEDS TO BE MADE AND RETURN VALUE PROPOGATED IF ONE.
        }
   | exp TK_PLUS exp
    {
        if (are_int_or_boolean($<var_rec>1->get_type(), $<var_rec>3->get_type())) 
        {
            VarRec *rtn_var = new VarRec("addition_return", $<var_rec>1->get_type());

            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("subtr_return", $<var_rec>1->get_type());

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
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("starop_return", $<var_rec>1->get_type());

            // Get the exp register assignments.
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("division_return", $<var_rec>1->get_type());

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
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("mod_return", $<var_rec>1->get_type());

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
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("EQ_return", sm->lookup_type("bool"));

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("NEQ_return", sm->lookup_type("bool"));

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

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
            VarRec *rtn_var = new VarRec("GT_return", sm->lookup_type("bool"));

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT GREATER THAN (==) ---------");
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
                cg.emit_note("------- END INT GREATER THAN (==) ---------");
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
            VarRec *rtn_var = new VarRec("LT_return", sm->lookup_type("bool"));

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT LESS THAN (==) ---------");
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
                cg.emit_note("------- END INT LESS THAN (==) ---------");
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
            VarRec *rtn_var = new VarRec("GE_return", sm->lookup_type("bool"));

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT GREATER THAN (==) ---------");
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
                cg.emit_note("------- END INT GREATER THAN (==) ---------");
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
            VarRec *rtn_var = new VarRec("LE_return", sm->lookup_type("bool"));

            $$ = rtn_var;


            // CODE GEN
            // CODE GEN
            // CODE GEN
            int lhs_reg = cg.get_reg_assign($<var_rec>1);
            int rhs_reg = cg.get_reg_assign($<var_rec>3);    

            // Assign the return value to the accumulator.
            // Must check this after getting the rhs and lhs assignments because
            // one of them may have been assigned to the AC.
            cg.assign_to_ac(rtn_var);

            if (tmDebugFlag)
            {
                cg.emit_note("------- BEGIN INT LESS THAN (==) ---------");
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
                cg.emit_note("------- END INT LESS THAN (==) ---------");
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
        // TODO: This signifies an immediate evaluation of all exps within these
        //      parens.
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
