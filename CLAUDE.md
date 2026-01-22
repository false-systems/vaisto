# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Vaisto?

Vaisto ("Finnish for intuition") is a statically-typed Scheme-like language that compiles to BEAM bytecode. It combines:
- S-expression syntax (minimal, parseable)
- Hindley-Milner type inference (ML/Rust-style safety without annotation tax)
- BEAM runtime (Erlang/Elixir ecosystem, fault tolerance, distribution)

The key insight: BEAM's process isolation makes Rust-style ownership unnecessary—you get safety through the runtime.

## Build Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/parser_test.exs

# Run a specific test by line number
mix test test/parser_test.exs:12

# Build the CLI compiler (escript)
mix escript.build

# Compile a .va file to BEAM
./vaistoc file.va

# Compile with specific output
./vaistoc file.va -o build/File.beam

# Evaluate an expression
./vaistoc --eval "(+ 1 2)"

# Build all .va files in directory
./vaistoc build src/ -o build/

# Start REPL
./vaistoc repl

# Start LSP server
./vaistoc lsp
```

## Architecture

### Compilation Pipeline

```
Vaisto source → Parser → AST → TypeChecker → Typed AST → CoreEmitter → BEAM bytecode
```

### Key Modules

| Module | Purpose |
|--------|---------|
| `Vaisto.Parser` | S-expression parser with location tracking. AST nodes are tuples with `%Loc{}` as final element |
| `Vaisto.TypeChecker` | HM-style type inference. Two-pass: collect signatures, then check bodies. Returns `{:ok, type, typed_ast}` |
| `Vaisto.TypeSystem.Core` | Type primitives: `{:tvar, id}`, `{:rvar, id}`, substitutions, `apply_subst/2` |
| `Vaisto.TypeSystem.Unify` | Unification algorithm with occurs check |
| `Vaisto.TypeSystem.Infer` | Algorithm W implementation for anonymous functions |
| `Vaisto.CoreEmitter` | Generates Core Erlang AST via `:cerl` module, compiles with `:compile.forms/2` |
| `Vaisto.Build` | Multi-file builds: dependency graph, topological sort, `.vsi` interface files |
| `Vaisto.Interface` | Module interface serialization for separate compilation |

### Type Representations

```elixir
:int, :float, :string, :bool, :any, :atom, :unit  # Primitives
{:tvar, id}                    # Type variable (inference)
{:rvar, id}                    # Row variable (row polymorphism)
{:fn, [arg_types], ret_type}   # Function type
{:list, elem_type}             # Homogeneous list
{:record, name, [{field, type}]}  # Product type
{:sum, name, [{ctor, [field_types]}]}  # ADT
{:row, [{field, type}], tail}  # Row type (tail is :closed or {:rvar, id})
{:pid, process_name, accepted_msgs}  # Typed PID
{:process, state_type, msg_types}    # Process type
```

### AST Conventions

Parser output always includes location as final tuple element:
```elixir
{:call, func, args, %Loc{}}
{:if, cond, then, else, %Loc{}}
{:defn, name, params, body, ret_type, %Loc{}}
```

Typed AST annotates with types:
```elixir
{:lit, :int, 42}               # Typed literal
{:var, name, type}             # Typed variable
{:call, func, typed_args, ret_type}  # Typed call
```

### Module System

```scheme
(ns MyModule)                  ; Declare module name
(import Std.List)              ; Import module
(import Std.List :as L)        ; Import with alias
(Std.List/fold xs 0 +)         ; Qualified call
```

Files in `std/` contain standard library modules (Result, Option, List operations).

## Language Features

### Core Constructs

```scheme
; Function definition with type annotations
(defn add [x :int y :int] :int (+ x y))

; Multi-clause functions (pattern matching)
(defn len
  [[] 0]
  [[h | t] (+ 1 (len t))])

; Algebraic data types
(deftype Result (Ok v) (Err e))
(deftype Point [x :int y :int])  ; Record

; Pattern matching
(match result
  [(Ok v) v]
  [(Err e) default])

; Process definition (typed GenServer-like)
(process counter 0
  :increment (+ state 1)
  :get state)

; Supervision
(supervise :one_for_one (counter 0))

; Erlang interop
(extern erlang:hd [(List :any)] :any)
```

### Design Decisions

- **No macros** — keeps type checking tractable and tooling possible
- **Typed PIDs** — `spawn` returns `(Pid ProcessName)`, `!` validates message types
- **Row polymorphism** — functions can require records with *at least* certain fields
- **Exhaustiveness checking** — match expressions on sum types must cover all variants

## Error Messages

Errors follow Rust's style: short, exact, with source context and actionable hints. Structured errors use `Vaisto.Error` with spans for rich formatting via `Vaisto.ErrorFormatter`.
