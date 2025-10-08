/**
    Basic utilities to work with raw NIR and SPIR-V
    bytecode streams.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.utils;
import nir.ir.atom;
import nir.library;
import nir.types;

/**
    Gets the next atom from a pointer.

    Params:
        slice = Slice to read from.
    
    Returns:
        A new atom that slices the pointer.
*/
NirAtom next(ref uint[] slice) @nogc {
    
    // Skip SPIR-V Header
    if (slice[0] == 0x07230203)
        slice = slice[5..$];

    uint opcode     = (slice[0] & 0x0000FFFF);
    uint oplength   = (slice[0] >> 16);
    NirAtom atom = NirAtom(
        opcode: opcode,
        operands: slice[1..oplength]
    );

    slice = slice[oplength..$];
    if (slice.length == 1) {
        slice = null;
    }
    return atom;
}

/**
    Represents a NIR Entrypoint.
*/
struct NirEntrypoint {
    string name;
    NirShaderStage stage;
}

/**
    Gets the entrypoint from the given NIR/SPIR-V bytecode stream.

    Params:
        stream = The instruction stream to look in.
    
    Returns:
        The entrypoint's name on success,
        $(D null) otherwise.
*/
NirEntrypoint[] getEntrypoints(uint[] stream) @nogc {
    import nulib.collections.vector : weak_vector;
    import nulib.string;
    
    uint[] read = stream;
    weak_vector!NirEntrypoint entrypoints;
    while(read.length > 0) {
        auto atom = read.next();
        if (atom.opcode == Op.OpEntryPoint) {
            entrypoints ~= NirEntrypoint(
                name: cast(string)fromStringz(cast(char*)&atom.operands[2]),
                stage: (cast(ExecutionModel)atom.operands[0]).toNirShaderStage()
            );
        }
    }
    return entrypoints.take();
}