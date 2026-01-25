#!/bin/bash
# Bootstrap the self-hosted Vaisto compiler
#
# This script compiles all self-hosted components using the Elixir-based compiler,
# producing BEAM files that can then compile Vaisto code without Elixir.
#
# Compile order is determined by dependencies:
# 1. Leaf modules (no Vaisto imports)
# 2. Modules that depend on (1)
# 3. And so on...

set -e

cd "$(dirname "$0")/.."

OUTPUT_DIR="build/bootstrap"
mkdir -p "$OUTPUT_DIR"

echo "Bootstrapping self-hosted Vaisto compiler..."
echo "Output: $OUTPUT_DIR"
echo ""

# Compile function with explicit output name
# Module names use Elixir's capitalize convention: CLI -> Cli, not CLI
# If override_name is provided, copies source to temp file with that name first
compile() {
    local src="$1"
    local override_name="$2"
    local actual_src="$src"
    local name

    if [ -n "$override_name" ]; then
        # Copy source to temp file with desired name
        actual_src="/tmp/${override_name}.va"
        cp "$src" "$actual_src"
        name="$override_name"
    else
        name=$(basename "$src" .va)
    fi

    # Convert to Elixir-style module name: capitalize first, lowercase rest
    local first_char="$(echo ${name:0:1} | tr '[:lower:]' '[:upper:]')"
    local rest="$(echo ${name:1} | tr '[:upper:]' '[:lower:]')"
    local module_name="${first_char}${rest}"
    # BEAM files need Elixir. prefix to match module name
    local output_name="Elixir.${module_name}.beam"
    echo -n "  Compiling $src -> $output_name... "
    ./vaistoc "$actual_src" -o "$OUTPUT_DIR/$output_name" 2>&1 && echo "ok" || echo "FAILED"

    # Clean up temp file
    if [ -n "$override_name" ]; then
        rm -f "$actual_src"
    fi
}

# Phase 0: Standard library modules (no deps)
echo "Phase 0: Standard library"
compile std/State.va "State"
compile std/Regex.va "Regex"
compile std/String.va "String"

# Phase 1: Leaf modules (no Vaisto dependencies)
# Use unique names for submodules to avoid collisions
echo ""
echo "Phase 1: Leaf modules"
compile src/Vaisto/Lexer/Types.va "Lexertypes"
compile src/Vaisto/Parser/AST.va
compile src/Vaisto/Compiler/CoreEmitter.va

# Phase 2: TypeChecker support modules
echo ""
echo "Phase 2: TypeChecker support"
compile src/Vaisto/TypeChecker/Types.va "Tctypes"
compile src/Vaisto/TypeChecker/Core.va "Tccore"

# Phase 3: TypeChecker modules with internal deps
echo ""
echo "Phase 3: TypeChecker internal"
compile src/Vaisto/TypeChecker/Unify.va "Tcunify"
compile src/Vaisto/TypeChecker/Context.va "Tccontext"
compile src/Vaisto/TypeChecker/Errors.va "Tcerrors"

# Phase 4: Main modules
echo ""
echo "Phase 4: Main modules"
compile src/Vaisto/Lexer.va
compile src/Vaisto/Parser.va
compile src/Vaisto/TypeChecker.va

# Phase 5: Compiler and CLI
echo ""
echo "Phase 5: Compiler and CLI"
compile src/Vaisto/Compiler.va
compile src/Vaisto/CLI.va

echo ""
echo "Bootstrap complete!"
echo ""
echo "Compiled modules:"
ls -la "$OUTPUT_DIR"/*.beam 2>/dev/null | awk '{print "  " $NF}'

echo ""
echo "To test the self-hosted CLI:"
echo "  cd $OUTPUT_DIR && erl -pa . -noshell -eval \"'Elixir.Cli':main()\" -s init stop"
