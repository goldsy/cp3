%{

#include <stdio.h>
#include <math.h>
#include <string>
#include <list>
#include <iostream>

#include "ScopeMgr.H"
#include "TypeRec.H"
#include "VarRec.H"

using namespace std;

// Flag used to turn on some debug messages.
bool debugFlag = false;

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

%right TK_QUEST
%left TK_STAR TK_SLASH TK_MOD
%left TK_PLUS TK_MINUS
%nonassoc TK_EQ TK_NEQ TK_GT TK_LT TK_GE TK_LE

%type <type_rec> exp
%type <type_rec_list> expx
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
       defs stms0 { /* printf("%s\n", sm->knock_knock().c_str()); */ }
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
            //printf("IN VAR\n");
            //fflush(0);

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
                //printf("STORING VAR: %s\n", iter->c_str());
                //fflush(0);

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
        // The ID list should not yet exist.
        // Create it and add this ID to it.
        // List will be destroyed when id list use is complete.
        //if (!id_list)
        //{
        //    id_list = new list<string>();
        //}

        //id_list->push_back($<str>1);
        //$$ = id_list;
        
        // Try #2
        // Always push back on list on top of stack.
        //id_list_stack->front()->push_back($<str>2);
        //$$ = id_list_stack;

        $<string_list>2->push_back($<str>1);
        $$ = $<string_list>2;
      }
      ;

idlist2:
       /* empty rule */ 
       {
            // First to be called.
            //id_list = new list<string>();
            //$$ = id_list;

            // Try #2
            //id_list_stack->push_front(new list<string>());
            //$$ = id_list_stack;

            $$ = new list<string>();
       }
       | TK_COMMA TK_ID idlist2 
       {
            // Add this ID to the list and return the list ptr.
            //if (!id_list)
            //{
            //    id_list = new list<string>();
            //}

            //id_list->push_back($<str>2);
            //$$ = id_list;
            
            // Try #2
            // Always push back on list on top of stack.
            //id_list_stack->front()->push_back($<str>2);
            //$$ = id_list_stack;

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
            
       //     // Create the Proc Type.
       //     string temp_name = $<str>2;
       //     temp_name += "<proc>";
       //     TypeRec *procType = new TypeRec(temp_name, procI9);

       //     // Set the return type.
       //     procType->set_return_type($<type_rec>6);

       //     // Set the param list.
       //     procType->set_param_list($<var_rec_list>4);

       //     // Check that TK_ID isn't already in the type symbol table.
       //     if (sm->insert_type(procType))
       //     {
       //         string errorMsg;
       //         errorMsg = "Duplicate forward declaration for '";
       //         errorMsg += $<str>2; 
       //         errorMsg += "'";
       //         yyerror(errorMsg.c_str());
       //         exit(0);
       //     }
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
            //printf("IN DECLIST\n");
            //fflush(0);

            // Returns the list of variables (i.e. param list) from declistx.
            if (in_proc_defn_flag)
            {
                // These variables need to be entered in table now.
                list<VarRec*> *scope_vars = $<var_rec_list>1;

                //printf("SCOPE VARS: %p\n", static_cast<void*>(scope_vars));
                //fflush(0);

                if (scope_vars)
                {
                    // Loop through each variable and add them to the var
                    // symbol table.
                    list<VarRec*>::iterator iter;
                        //printf("INVALIDATION TEST: %lu\n", scope_vars->size());
                        //cout << "INVALIDATION TEST: " << scope_vars->size() << endl;

                    for (iter = scope_vars->begin(); iter != scope_vars->end(); ++iter)
                    {
                        //printf("ATTEMPTING TO STORE VAR: %s\n", (*iter)->get_name().c_str());
                        //fflush(0);

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
                        //printf("AFTER INSERT\n");
                        //fflush(0);
                        //printf("INVALIDATION TEST: %lu\n", scope_vars->size());
                        //fflush(0);
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
            //printf("IN DECLISTX\n");
            //fflush(0);

            // Create new list and add ID list to it.
            list<VarRec *> *param_list = new list<VarRec*>();
            list<string>::iterator id_iter;
            //list<VarRec *>::iterator param_iter;

            for (id_iter = $<string_list>1->begin(); id_iter != $<string_list>1->end(); ++id_iter)
            {
                //printf("STORING PARAM VAR: %s\n", id_iter->c_str());
                //fflush(0);

                // REMOVED DUP NAME VALIDATION.
                // NAMES NOT IMPORTANT UNTIL PROC DECLARATION.
                //param_iter = param_list->find(*id_iter);

                //if (param_iter != param_list->end())
                //{
                //    // Parameter name already exists.
                //    string errorMsg;
                //    errorMsg = "Duplicate paramter name '";
                //    errorMsg += *id_iter; 
                //    errorMsg += "'";
                //    yyerror(errorMsg.c_str());
                //    exit(0);
                //}
                VarRec *temp = new VarRec(*id_iter, $<type_rec>3);   
                param_list->push_back(temp);
            }

            // If declistx2 is not null merge lists checking for dup names.
            list<VarRec*> *sub_param_list = $<var_rec_list>4;

            if (sub_param_list)
            {
                // Copy the sub list to this one.
                param_list->insert(param_list->end(), sub_param_list->begin(), sub_param_list->end());

                // YOU JUST PAST THE PTRS YOU MORON!!!
                // Now cleanup the sub list.
                //list<VarRec *>::iterator sub_param_iter;

                //for (sub_param_iter = sub_param_list->begin(); sub_param_iter != sub_param_list->end(); ++sub_param_iter)
                //{
                //    // Delete each entries memory.
                //    delete *sub_param_iter;
                //}

                // Delete the list.
                delete sub_param_list;
            }

            // Return merged list.
            $$ = param_list;

            delete id_list;
            id_list = 0;
        }
        ;

declistx2:
         /* empty rule */ 
         { 
            //printf("IN DECLISTX2 NULL\n");
            //fflush(0);

            $$ = 0; 
         }
         | TK_COMMA declistx 
         { 
            //printf("IN DECLISTX2 RECURSE\n");
            //fflush(0);

            $$ = $<var_rec_list>2; 
         }
         ;


/* *********************** */
proc:
    TK_PROC TK_ID procentry TK_LPAREN declist TK_RPAREN proc2 prochelper procdefs stms0 TK_END
    {
//        ProcRec *stored_proc = sm->lookup_proc($<str>2);
//        ProcRec *proc_rec = new ProcRec($<str>2, $<type_rec>6, $<var_rec_list>4);
//
//        if (stored_proc)
//        {
//            // A forward was declared for this proc.
//            // Or we redefined the proc.
//            if (!stored_proc->get_is_forward())
//            {
//                // What is stored isn't a forward declaration
//                // so it has been redefined. ERROR!
//                // Redefinition of procedure name.
//                string errorMsg;
//                errorMsg = "Redefinition of procedure '";
//                errorMsg += $<str>2; 
//                errorMsg += "'";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
//
//            // Compare to forward ProcRec.
//            if (!proc_rec->equal(stored_proc))
//            {
//                // Definition conflicts with forward declaration.
//                string errorMsg;
//                errorMsg = "Definition of '";
//                errorMsg += $<str>2; 
//                errorMsg += "' conflicts with forward declaration";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
//
//            // Then replace param list with <declist> so names match.
//            // Clean up the old stored list if it exists.
//            list<VarRec *> *stored_params = stored_proc->get_param_list();
//            if (stored_params)
//            {
//                list<VarRec *>::iterator stored_iter;
//                
//                for(stored_iter = stored_params->begin(); stored_iter != stored_params->end(); ++stored_iter)
//                {
//                    delete (*stored_iter);
//                }
//
//                delete stored_params;
//            }
//
//            stored_proc->set_param_list(proc_rec->get_param_list());
//
//            // The proc has now been defined.
//            stored_proc->set_is_forward(false);
//        }
//        else
//        {
//            if (!sm->insert_proc(proc_rec))
//            {
//                string errorMsg;
//                errorMsg = "Duplicate proc definition for '";
//                errorMsg += $<str>2; 
//                errorMsg += "'";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
//        }






  //      // Lookup TK_ID in *Proc* Symbol Table. Cannot already exist.
  //      if (sm->lookup_proc($<str>2))
  //      {
  //          // Redefinition of procedure name.
  //          string errorMsg;
  //          errorMsg = "Redefinition of procedure '";
  //          errorMsg += $<str>2; 
  //          errorMsg += "'";
  //          yyerror(errorMsg.c_str());
  //          exit(0);
  //      }

  //      // Lookup TK_ID in *Type* Symbol Table.
  //      string temp_name = $<str>2;
  //      temp_name += "<proc>";
  //      TypeRec *target_type = sm->lookup_type(temp_name);

  //      if (target_type)
  //      {
  //          // Make sure that the type is a proc.
  //          // REMOVED THIS BECAUSE PROC NAMES SHOULD NOT INTERFERE WITH USER TYPE NAMES. ADDED THE <proc> to proc types.
  //          //if (target_type->get_base_type() != procI9)
  //          //{
  //          //    // Illegal reuse of name.
  //          //    string errorMsg;
  //          //    errorMsg = "Illegal redeclaration of '";
  //          //    errorMsg += $<str>2; 
  //          //    errorMsg += "'";
  //          //    yyerror(errorMsg.c_str());
  //          //    exit(0);
  //          //}

  //          // Make sure that the param types and return type match.
  //          TypeRec *return_type = target_type->get_return_type();

  //          // Check if one is a proc and the other a function.
  //          if (((return_type == 0) && ($<type_rec>6 != 0))
  //              || ((return_type != 0) && ($<type_rec>6 == 0)))
  //          {
  //              // Definition conflicts with forward declaration.
  //              string errorMsg;
  //              errorMsg = "Definition return value of '";
  //              errorMsg += $<str>2; 
  //              errorMsg += "' conflicts with forward declaration";
  //              yyerror(errorMsg.c_str());
  //              exit(0);
  //          }

  //          // If both return a value make sure they are the same.
  //          if (return_type && $<type_rec>6)
  //          {
  //              if (!return_type->equal($<type_rec>6))
  //              {
  //                  // Definition conflicts with forward declaration.
  //                  string errorMsg;
  //                  errorMsg = "Definition return value of '";
  //                  errorMsg += $<str>2; 
  //                  errorMsg += "' conflicts with forward declaration";
  //                  yyerror(errorMsg.c_str());
  //                  exit(0);
  //              }
  //          }

  //          // TODO Check the parameter list.
  //          list<VarRec *> *call_params = $<var_rec_list>4;
  //          list<VarRec *> *stored_params = target_type->get_param_list();

  //          // Check for no vs some parameters.
  //          if (((stored_params == 0) && (call_params != 0))
  //              || ((stored_params != 0) && (call_params == 0)))
  //          {
  //              // Definition conflicts with forward declaration.
  //              string errorMsg;
  //              errorMsg = "Definition parameter list of '";
  //              errorMsg += $<str>2; 
  //              errorMsg += "' conflicts with forward declaration";
  //              yyerror(errorMsg.c_str());
  //              exit(0);
  //          }

  //          // They are either both null or not.
  //          if (stored_params)
  //          {
  //              if (stored_params->size() != call_params->size())
  //              {
  //                  // Conflict in number
  //                  string errorMsg;
  //                  errorMsg = "Definition parameter list of '";
  //                  errorMsg += $<str>2; 
  //                  errorMsg += "' conflicts in quatity with forward declaration";
  //                  yyerror(errorMsg.c_str());
  //                  exit(0);
  //              }

  //              list<VarRec *>::iterator call_iter;
  //              list<VarRec *>::iterator stored_iter = stored_params.begin();

  //              for(call_iter = call_params->begin(); call_iter != call_params->end(); ++call_iter)
  //              {
  //                  if (!(*call_iter)->get_type()->equal((*stored_iter)->get_type())) 
  //                  {
  //                      // Conflict in parameter type.
  //                      string errorMsg;
  //                      errorMsg = "Definition parameter list of '";
  //                      errorMsg += $<str>2; 
  //                      errorMsg += "' conflicts in quatity with forward declaration";
  //                      yyerror(errorMsg.c_str());
  //                      exit(0);
  //                  }

  //                  // Already know list sizes are same so for will
  //                  // protect stored_iter from overrunning end.
  //                  ++stored_iter;
  //              }
  //          }

  //          // Then replace param list with <declist> so names match.
  //          // Clean up the old stored list if it exists.
  //          if (stored_params)
  //          {
  //              list<VarRec *>::iterator stored_iter;
  //              
  //              for(stored_iter = stored_params->begin(); stored_iter != stored_params->end(); ++stored_iter)
  //              {
  //                  delete (*stored_iter);
  //              }

  //              delete stored_params;
  //          }

  //          target_type->set_param_list(call_params);
  //      }
  //      else
  //      {
  //          // otherwise create Type for proc.
  //          string temp_name = $<str>2;
  //          temp_name += "<proc>";
  //          target_type = new TypeRec(temp_name, procI9);

  //          // Set the return type.
  //          target_type->set_return_type($<type_rec>6);

  //          // Set the param list.
  //          target_type->set_param_list($<var_rec_list>4);

  //          // Check that TK_ID isn't already in the type symbol table.
  //          if (sm->insert_type(target_type))
  //          {
  //              string errorMsg;
  //              errorMsg = "Duplicate proc declaration for '";
  //              errorMsg += $<str>2; 
  //              errorMsg += "'";
  //              yyerror(errorMsg.c_str());
  //              exit(0);
  //          }
  //      }



        // If this is a function define a VarRec in the name of the
        // function with type of return value.
//        if (stored_proc->get_return_type())
//        {
//            VarRec *rtn_var = new VarRec(stored_proc->get_name(), stored_proc->get_return_type());
//
//            if ( !sm->insert_var(rtn_var) )
//            {
//                string errorMsg;
//                errorMsg = "Duplicate variable name '";
//                errorMsg += stored_proc->get_name();
//                errorMsg += "' for function return type";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
//        }

        // Insert the proc parameters into the Var table.
        // This will catch duplicate names in the definition too.
//        list<VarRec*> *scope_vars = $<var_rec_list>4;
//
//        if (scope_vars)
//        {
//            // Loop through each variable and add them to the var
//            // symbol table.
//            list<VarRec*>::iterator iter;
//
//            for (iter = scope_vars->begin(); iter != scope_vars->end(); ++iter)
//            {
//                // Attempt to insert each variable check for failure.
//                if( !sm->insert_var(*iter) )
//                {
//                    string errorMsg;
//                    errorMsg = "Duplicate parameter name '";
//                    errorMsg += (*iter)->get_name();
//                    errorMsg += "'";
//                    yyerror(errorMsg.c_str());
//                    exit(0);
//                }
//            }
//        }

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
            //printf("IN PROC HELPER\n");
            //fflush(0);

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
                //printf("FOUND STORED PROC %s\n", proc_name.c_str());
                //fflush(0);

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

                //printf("ABOUT TO COMPARE STORED PROC TO DEFINED %s\n", proc_name.c_str());
                //fflush(0);

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
                //printf("FINISHED COMPARE STORED PROC TO DEFINED %s\n", proc_name.c_str());
                //fflush(0);


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
        if (!lvalue_type->equal($<type_rec>3))
        {
            // Incompatible types in assignment.
            string errorMsg;
            errorMsg = "Incompatible types in assignments.";
            yyerror(errorMsg.c_str());
            exit(0);
        }

        // TODO: Should not be able to do this inside fa.
        if ($<var_rec>1->get_loop_counter_flag())
        {
            string errorMsg;
            errorMsg = "Variable is not assignable.";
            yyerror(errorMsg.c_str());
            exit(0);
        }
   }
   | TK_WRITE exp TK_SEMI
    {
        // exp must be a string or int.
        TypeRec *string_rec = sm->lookup_type("string");
        TypeRec *int_rec = sm->lookup_type("int");

        if (!string_rec->equal($<type_rec>2)
            && !int_rec->equal($<type_rec>2))
        {
            // Type is not string or int.
            string errorMsg;
            errorMsg = "Invalid type: write expression must be string or int type";
            yyerror(errorMsg.c_str());
            exit(0);
        }
    }
   | TK_WRITES exp TK_SEMI
    {
        // exp must be a string or int.
        TypeRec *string_rec = sm->lookup_type("string");
        TypeRec *int_rec = sm->lookup_type("int");

        if (!string_rec->equal($<type_rec>2)
            && !int_rec->equal($<type_rec>2))
        {
            // Type is not string or int.
            string errorMsg;
            errorMsg = "Invalid type: writes expression must be string or int type";
            yyerror(errorMsg.c_str());
            exit(0);
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

    if (!bool_rec->equal($<type_rec>2))
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

        if (!bool_rec->equal($<type_rec>3))
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

    if (!bool_rec->equal($<type_rec>3))
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
//        // TK_ID must be a declared variable.
//        VarRec *id_rec = sm->lookup_var($<str>2);
//
//        if (!id_rec)
//        {
//            // Variable undefined.
//            string errorMsg;
//            errorMsg = "Undefined loop variable '";
//            errorMsg += $<str>2; 
//            errorMsg += "'";
//            yyerror(errorMsg.c_str());
//            exit(0);
//        }
//
//        // TK_ID must be an int and is therefore assignable. 
//        TypeRec *id_type = id_rec->get_type();
//        TypeRec *int_rec = sm->lookup_type("int");
//
//        if (!int_rec->equal(id_type))
//        {
//            // Loop variable type invalid.
//            string errorMsg;
//            errorMsg = "Invalid loop variable type '";
//            errorMsg += $<str>2; 
//            errorMsg += "'";
//            yyerror(errorMsg.c_str());
//            exit(0);
//        }

        TypeRec *int_rec = sm->lookup_type("int");

        // Both expressions must be an int.
        if (!int_rec->equal($<type_rec>5)
            || !int_rec->equal($<type_rec>7))
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
            //printf("IN FA ENTRY\n");
            //fflush(0);

            sm->enter_scope();
            ++fa_count;
            VarRec *id_rec = new VarRec($<str>0, sm->lookup_type("int"));
            id_rec->set_loop_counter_flag(true);
            sm->insert_var(id_rec);
            //printf("LEAVING FA ENTRY\n");
            //fflush(0);

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

            //TypeRec *newVarType = new TypeRec(derefType);
            VarRec *newVarRec = new VarRec("anon_lvalue", derefType);

            $$ = newVarRec;

//            // We have an array dereference.
//            // Push the primitive into the type constructed from
//            // the dereferece tokens.
//            TypeRec *varPrimitive = varType->get_primitive();
//            $<type_rec>2 ->set_primitive(varPrimitive);
//
//            // DEBUG
//            //printf("ABOUT TO CHECK ARRAY TYPE IN LVALUE. (Line: %d)\n", yynewlines);
//
//            // Check if the types are the same ignoring size.
//            if (!$<type_rec>2 ->equal_no_size(varType))
//            {
//                // Dereferencing [] does not match variable.
//                string errorMsg;
//                errorMsg = "Variable '";
//                errorMsg += $<str>1;
//                errorMsg += "' array dereference does not match number of array dimensions.";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
//
//            // The type is the underlying primitive that was
//            // dereferenced.
//            $$ = varPrimitive;
        }
        else
        {
            // This was not an array dereference just a basic
            // type so just return it.
            $$ = tempVar;
            //$$ = varType;
        }
        }
      ;

lvalue2:
       /* empty rule */     { $$ = 0; }
      | TK_LBRACK exp TK_RBRACK lvalue2 {
        // Array dereference; exp must be int.
        if (!is_int($<type_rec>2))
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
        $$ = $<var_rec>1->get_type(); 
   }
   | TK_INT     
        { 
            //printf("%s >>>> %ld\n", $<str>1, MAX_INT_I9_SIZE);
            //printf("%s\n", $<str>1);

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
            $$ = sm->lookup_type("int"); 
        }
   | TK_TRUE    { $$ = sm->lookup_type("bool"); }
   | TK_FALSE   { $$ = sm->lookup_type("bool"); }
   | TK_SLIT    { $$ = sm->lookup_type("string"); }
   | TK_READ    { $$ = sm->lookup_type("int"); }
   | TK_MINUS exp  {
        if (is_int_or_boolean($<type_rec>2)) {
            $$ = $<type_rec>2;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible type for unary minus");
            exit(0);
        }
        } 
   | TK_QUEST exp  {
        if (is_boolean($<type_rec>2)) {
            // Question returns an int type.
            $$ = sm->lookup_type("int");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible type for unary question operator");
            exit(0);
        }
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
                    $$ = proc_target->get_return_type();
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


// SWITCH TO ProcRec
//            // Look up name in the type symbol table.
//            TypeRec *target = sm->lookup_type($<str>1);
//
//            if (target)
//            {
//                // Check if the base type is proc.
//                if(target->get_base_type() != procI9)
//                {
//                    string errorMsg;
//                    errorMsg = $<str>1;
//                    errorMsg += "' is not callable.";
//                    yyerror(errorMsg.c_str());
//                    exit(0);
//                }
//                else if(target->get_param_list())
//                {
//                    // Param list not empty.
//                    string errorMsg;
//                    errorMsg = "Invalid parameter list for '";
//                    errorMsg += $<str>1; 
//                    yyerror(errorMsg.c_str());
//                    exit(0);
//                }
//                else
//                {
//                    // This might be null if proc (vs function) but
//                    // the next level up will determine if that matters.
//                    $$ = target->get_return_type();
//                }
//            }
//            else
//            {
//                // Proc call not found.
//                string errorMsg;
//                errorMsg = "Proc '";
//                errorMsg += $<str>1; 
//                errorMsg += "' is not declared.";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
        }
   | TK_ID TK_LPAREN expx TK_RPAREN
        {
            //printf("IN PROC CALL!!!!\n");
            //fflush(0);

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

                list<TypeRec *> *called_types = $<type_rec_list>3;

                // Quick check on number of params.
                if (called_types->size() != param_list->size())
                {
                    // Called number of params doesn't match proc type.
                    string errorMsg;
                    errorMsg = "Invalid number of parameters for ";
                    errorMsg += $<str>1; 
                    yyerror(errorMsg.c_str());
                    exit(0);
                }

                list<TypeRec *>::iterator iter;
                list<VarRec *>::iterator param_iter = param_list->begin();

                // Make sure that the called types match the param
                // list types.
                for(iter = called_types->begin(); iter != called_types->end(); ++iter)
                {
                    if (!(*iter)->equal((*param_iter)->get_type()))
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
                $$ = proc_target->get_return_type();
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
            delete $<type_rec_list>3;




// SWITCH TO ProcRec
//            // Look up name in the type symbol table.
//            TypeRec *target = sm->lookup_type($<str>1);
//
//            if (target)
//            {
//                // Check if the base type is proc.
//                if(target->get_base_type() != procI9)
//                {
//                    string errorMsg;
//                    errorMsg = "'";
//                    errorMsg += $<str>1;
//                    errorMsg += "' is not callable.";
//                    yyerror(errorMsg.c_str());
//                    exit(0);
//                }
//
//                list<VarRec *> *param_list = target->get_param_list();
//
//                if(!param_list)
//                {
//                    // Param list not empty.
//                    string errorMsg;
//                    errorMsg = "Invalid parameter list for ";
//                    errorMsg += $<str>1; 
//                    yyerror(errorMsg.c_str());
//                    exit(0);
//                }
//
//                list<TypeRec *> *called_types = $<type_rec_list>3;
//
//                // Quick check on number of params.
//                if (called_types->size() != param_list->size())
//                {
//                    // Called number of params doesn't match proc type.
//                    string errorMsg;
//                    errorMsg = "Invalid number of parameters for ";
//                    errorMsg += $<str>1; 
//                    yyerror(errorMsg.c_str());
//                    exit(0);
//                }
//
//                list<TypeRec *>::iterator iter;
//                list<VarRec *>::iterator param_iter = param_list->begin();
//
//                // Make sure that the called types match the param
//                // list types.
//                for(iter = called_types->begin(); iter != called_types->end(); ++iter)
//                {
//                    if (!(*iter)->equal((*param_iter)->get_type()))
//                    {
//                        // Param types do not match.
//                        string errorMsg;
//                        errorMsg = "Incompatible parameter type for ";
//                        errorMsg += $<str>1; 
//                        yyerror(errorMsg.c_str());
//                        exit(0);
//                    }
//                    
//                    // Already know list sizes are same so for will
//                    // protect param_iter from overrunning end.
//                    ++param_iter;
//                }
//
//                // This might be null if proc (vs function) but
//                // the next level up will determine if that matters.
//                $$ = target->get_return_type();
//            }
//            else
//            {
//                // Proc call not found.
//                string errorMsg;
//                errorMsg = "Proc '";
//                errorMsg += $<str>1; 
//                errorMsg += "' is not declared.";
//                yyerror(errorMsg.c_str());
//                exit(0);
//            }
//
//            // The expx list contains pointers already maintined in
//            // the type symbol table so we can just throw the list
//            // away without concern for the pointers.
//            delete $<type_rec_list>3;
        }
   | exp TK_PLUS exp    {
        if (are_int_or_boolean($<type_rec>1, $<type_rec>3)) {
            $$ = $<type_rec>1;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary plus operator");
            exit(0);
        }
        }
   | exp TK_MINUS exp   { 
        if (are_int($<type_rec>1, $<type_rec>3)) {
            $$ = $<type_rec>1;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary minus");
            exit(0);
        }
        }
   | exp TK_STAR exp    {
            // DEBUG
            //printf("STAR <ptr1: %p> <ptr2: %p>", static_cast<void *>($<type_rec>1), static_cast<void *>($<type_rec>3));
        if (are_int_or_boolean($<type_rec>1, $<type_rec>3)) {
            $$ = $<type_rec>1;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary multiplication operator");
            exit(0);
        }
        }
   | exp TK_SLASH exp {
        if (are_int($<type_rec>1, $<type_rec>3)) {
            $$ = $<type_rec>1;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for division operator");
            exit(0);
        }
        }
   | exp TK_MOD exp     {
        if (are_int($<type_rec>1, $<type_rec>3)) {
            $$ = $<type_rec>1;
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for modulo operator");
            exit(0);
        }
        }
   | exp TK_EQ exp      {
        if (are_int_or_boolean($<type_rec>1, $<type_rec>3)) {
            // Equal comparison always returns boolean type.
            $$ = sm->lookup_type("bool");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary comparison equal");
            exit(0);
        }
        }
   | exp TK_NEQ exp     {
        if (are_int_or_boolean($<type_rec>1, $<type_rec>3)) {
            // Equal comparison always returns boolean type.
            $$ = sm->lookup_type("bool");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary comparison not equal");
            exit(0);
        }
        }
   | exp TK_GT exp      {
        if (are_int($<type_rec>1, $<type_rec>3)) {
            // Greater than comparison always returns boolean type.
            $$ = sm->lookup_type("bool");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary greater than operator");
            exit(0);
        }
        }
   | exp TK_LT exp      {
        if (are_int($<type_rec>1, $<type_rec>3)) {
            // Less than comparison always returns boolean type.
            $$ = sm->lookup_type("bool");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary less than operator");
            exit(0);
        }
        }
   | exp TK_GE exp      {
        if (are_int($<type_rec>1, $<type_rec>3)) {
            // Greater than equal comparison always returns boolean type.
            $$ = sm->lookup_type("bool");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary greater than or equal operator");
            exit(0);
        }
        }
   | exp TK_LE exp      {
        if (are_int($<type_rec>1, $<type_rec>3)) {
            // Less than or equal comparison always returns boolean type.
            $$ = sm->lookup_type("bool");
        }
        else {
            // TYPE ERROR!
            yyerror("Incompatible types for binary less than or equal operator");
            exit(0);
        }
        }
   | TK_LPAREN exp TK_RPAREN    { $$ = $<type_rec>2; }
   ;

expx:
    exp
    {
        // Create a new type list and stuff this type into it.
        list<TypeRec *> *param_types = new list<TypeRec *>();
        param_types->push_back($<type_rec>1);

        $$ = param_types; 
    }
    | expx TK_COMMA exp
    { 
        list<TypeRec *> *param_types = $<type_rec_list>1;
        param_types->push_back($<type_rec>3);

        $$ = param_types; 
    }
    ;
%%


int main() {
  int tok;
  int spewTokens = 0;

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
