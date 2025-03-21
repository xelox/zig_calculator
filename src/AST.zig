const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenVariants = token_module.TokenVariants;

pub const Num = struct {
    token: Token,
    value: f64,
};

pub const Id = struct {
    token: Token,
    value: []u8,
};

pub const BinOp = struct {
    token: Token,
    left: Num,
    op: TokenVariants,
    right: Num,
};

pub const UnaryOp = struct {
    token: Token,
    op: TokenVariants,
    num: Num,
};

pub const AST = union {
    number: Num,
    identifier: Id,
    bin_op: BinOp,
    unary_op: UnaryOp,
};
