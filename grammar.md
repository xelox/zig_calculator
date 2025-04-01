program         : statement-list  
statement-list  : (statement)*  
statement       : (declaration | assign-op | function-call) semicolon | if lpar bool-expr rpar block | while lpar bool-expr rpar block | block | empty  
block           : begin statement-list end  
declaration     : (let | let mut) var-id double-colon type assignment?  
type            : int | float | bool | string  
assign-op       : var-id assignment  
assignment      : equal-sign (expr | bool-expr | comptime-string)  
function-call   : function-id lpar argument-list rpar  
var-list        : var-id (colon var-id)*  
expr            : term ((plus | minus) term)*  
term            : factor ((mul | div)) factor)*  
factor          : (plus | minus) factor | var-id | comptime-number | lpar expr rpar  
comptime-number : comptime-float | comptime-integer  
bool-expr       : comparable (( == | != | >= | <= ) comparable)?  
comparable      : expr | bool-value (and | or) bool-value  
bool-value      : boolean | var-id | lpar bool-expr rpar  
  
  
AST.Node :  
    Block               (children: []const Node)  
    Declaration         (identifier: []const u8, type: enum, initialization: ?Node)  
    AssignOp            (identifier: []const u8, lhs: Node)  
    FunctionCall        (identifier: []const u8, arguments: []const Node)  
    IfBlock             (condition: Node, block: Block)  
    WhileBlock          (condition: Node, block: Block)  
    Var                 (identifier: []const u8)  
    ComptimeInt         (value: i64)  
    ComptimeFloat       (value: f64)  
    BinOp               (lhs: Node, op: enum, rhs: Node)  
    UnaryOp             (op: enum, operand: Node)  
    NoOp                ()  
