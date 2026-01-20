# Vaisto

**Finnish for "intuition"** — a statically-typed Scheme for the BEAM.

## What is this?

Vaisto is a programming language that combines:
- **Scheme** — minimal s-expression syntax
- **ML/Rust** — Hindley-Milner type inference
- **Erlang** — BEAM runtime, OTP patterns

The insight: Rust's type system without ownership. BEAM's process isolation makes the borrow checker unnecessary. You get safety through the runtime, not the compiler fighting you.

## The Pitch

```scheme
; A typed process - seven lines
(process counter 0
  :increment (+ state 1)
  :get state)

; Supervision as syntax - three lines
(supervise :one_for_one
  (counter 0))
```

That's it. Fault-tolerant, typed, distributed-ready.

In Elixir, this would be ~50 lines across multiple modules. In Kubernetes, add YAML. In Vaisto, it's the code above.

## Status

**Very early.** This is a working skeleton:
- ✅ Parser (s-expressions → AST)
- ✅ Type checker (basic inference)
- ✅ Core Erlang emitter (AST → BEAM)
- ✅ LSP server (hover, diagnostics, symbols)
- ✅ VS Code extension
- 🚧 Full Hindley-Milner inference
- 🚧 Complete OTP mapping
- 🚧 REPL

## Installation

```bash
git clone <repo>
cd vaisto
mix deps.get
mix test
```

## Usage

```elixir
# In iex
iex> Vaisto.Parser.parse("(+ 1 2)")
{:call, :+, [1, 2]}

iex> Vaisto.Parser.parse("(+ 1 (* 2 3))")
{:call, :+, [1, {:call, :*, [2, 3]}]}
```

## Editor Support (VS Code)

Vaisto has an LSP server and VS Code extension for real-time type feedback.

### Quick Setup

```bash
# 1. Build the compiler
mix escript.build

# 2. Install the VS Code extension
cd editors/vscode
npm install
```

Then open `editors/vscode` in VS Code and press **F5** to launch the Extension Development Host. Open any `.va` file to get:

| Feature | Shortcut | What it does |
|---------|----------|--------------|
| **Hover** | Mouse over | Shows type: `(Int, Int) -> Int` |
| **Diagnostics** | Automatic | Red squiggles for type/parse errors |
| **Symbols** | `Cmd+Shift+O` | Jump to functions, types, processes |

### Example

```scheme
; test.va
(defn add [a :int b :int] :int
  (+ a b))

(let [x 42]
  (add x 1))  ; Hover here → (Int, Int) -> Int
```

### Configuration

If `vaistoc` isn't in your PATH, add to VS Code settings:

```json
{
  "vaisto.serverPath": "/path/to/vaisto/vaistoc"
}
```

## Compilation Pipeline

```
Vaisto source → AST → Type checker → Typed AST → Core Erlang → BEAM bytecode
```

1. **Parser**: text → AST
2. **Type checker**: AST → Typed AST (or error)
3. **Core Emitter**: Typed AST → Core Erlang
4. **Erlang compiler**: Core Erlang → BEAM bytecode

## Why?

Modern distributed systems need fault tolerance, but the languages that offer it (Erlang, Elixir) don't give you compile-time guarantees about your data shapes. You find out at runtime.

Meanwhile, the typed languages (Rust, Haskell) make concurrency hard.

Vaisto says: why not both?

## Design Principles

1. **Types without annotations** — inference handles it
2. **Supervision as syntax** — fault tolerance isn't a library
3. **Contracts across services** — if message types don't match, fail at compile time
4. **BEAM native** — processes, distribution, hot code reload

## The Vision

| Layer | Tool | Purpose |
|-------|------|---------|
| Language | Vaisto | Type-checked services |
| Runtime | Korva | Simple orchestration |
| Observability | AHTI | Causality correlation |
| Deployment | SYKLI | CI that understands |

## Related Work

- **LFE** — Lisp on BEAM, untyped
- **Gleam** — Typed on BEAM, not Lisp
- **Typed Racket** — Typed Scheme, not BEAM

Vaisto fills the gap: typed + Lisp + BEAM.

## Origin

Conceived January 2026, 3am Berlin, while waiting for family to fly home. Started as "learn Elixir methodically," became a language design through following intuition.

## License

MIT
