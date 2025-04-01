# Unnamed Toy Language - WIP

This is a personal project to learn the Zig programming language and understand how interpreters work. I'm loosely following a guide from [Ruslan’s Blog](https://ruslanspivak.com/lsbasi-part1/) that builds an interpreter for Pascal using Python. However, instead of Python, I am implementing everything in Zig, and instead of Pascal, I am designing my own toy language.

## Goals

- Learn the fundamentals of compilers and interpreters.
- Gain hands-on experience with Zig.
- Design and implement a simple interpreted language from scratch.

## What I've Learned So Far

- **Lexing** – Understanding what a lexer is and how to build one.
- **Parsing** – Constructing a parser to analyze language syntax.
- **Abstract Syntax Trees (ASTs)** – Representing parsed code as a tree structure.
- **Grammars** – Reading and writing formal grammar definitions.
- **Interpreting** – Executing the parsed code by implementing an interpreter.

## Upcoming Topics

While I haven't implemented these yet, the guide introduces:

- **Semantic Analysis** – Ensuring program correctness beyond syntax.
- **Symbol Tables** – Managing variable and function definitions.

## Project Status

This project is still a work in progress, and I'm actively exploring new concepts. The design and features of the toy language are evolving as I learn.

## Running the Interpreter

Since this is an experimental learning project, there are no formal installation steps yet. However, if you'd like to explore the code:

1. Install [Zig](https://ziglang.org/download/)
2. Clone the repository:
   ```sh
   git clone <https://github.com/xelox/zig_interpreter.git>
   cd zig_interpreter
3. Run the interpreter:
    ```sh
    zig build run -- <test.toy>

## Notes

- This is probably never going to be a production-ready language.
- The implementation is experimental and subject to major changes.
- The code is open source but I do not accept contributions, suggestions however are welcome.
