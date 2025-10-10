/**
    The smallest unit of a NIR instruction stream.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.ir.atom;
import spirv.reflection;
import nulib.io.stream;
import nulib;
import numem;

public import spirv.spv;

/**
    Represents an "atom" in the Niobium bytestream,
    a NIR module is made up of a stream of atoms.
*/
struct NirAtom {

    /**
        An opcode.
    */
    uint opcode;

    /**
        The operands of the instruction.
    */
    uint[] operands;
}

/**
    Reads $(D NirAtoms) from a stream.

    Params:
        stream = The stream to read the atoms from.
    
    Returns:
        The atoms in the stream, SPIR-V head stripped off;
        the stream is rewound to the position prior to this
        call on completion.
*/
NirAtom[] readAtoms(Stream stream) {
    import nulib.collections.vector : weak_vector;
    import nulib.io.stream.rw : StreamReader;

    auto start = stream.tell();

    weak_vector!NirAtom result;
    auto reader = nogc_new!StreamReader(stream);
    auto magic = reader.readU32LE();

    // Read instructions.
    if (magic == 0x07230203) {
        stream.seek(16, SeekOrigin.relative);

        ptrdiff_t len = stream.length;
        while(stream.tell < len) {
            NirAtom instr;
            uint data = reader.readU32LE();

            // Parse opcode and operand length.
            instr.opcode = data | 0x0000FFFF;
            instr.operands = nu_malloca!uint(data >> 16);
            foreach(ref opr; instr.operands)
                opr = reader.readU32LE();

            result ~= instr;
        }
    } else {
        stream.seek(16, SeekOrigin.relative);

        ptrdiff_t len = stream.length;
        while(stream.tell < len) {
            NirAtom instr;
            uint data = reader.readU32BE();

            // Parse opcode and operand length.
            instr.opcode = data | 0x0000FFFF;
            instr.operands = nu_malloca!uint(data >> 16);
            foreach(ref opr; instr.operands)
                opr = reader.readU32BE();

            result ~= instr;
        }
    }

    stream.seek(start);
    return result.take();
}

/**
    A high level wrapper over NIR Atoms.
*/
class NirAtomObject : NuRefCounted {
private:
@nogc:
    NirAtom atom;
    uint maxLength;

protected:

    /**
        Clears all operands from the atom.
    */
    void clearOperands() {
        nu_freea(atom.operands);
    }

    /**
        Adds a single operand to the atom.

        Params:
            operand = The operand to add.
    */
    void addOperand(uint operand) {
        atom.operands = atom.operands.nu_resize(atom.operands.length+1);
        atom.operands[$-1] = operand;
    }

    /**
        Adds multiple operands to the atom.

        Params:
            operands = The operands to add.
    */
    void addOperands(uint[] operands) {
        atom.operands = atom.operands.nu_resize(atom.operands.length+operands.length);
        atom.operands[$-operands.length..$] = operands[0..$];
    }

public:

    /**
        The opcode of the atom.
    */
    final @property Op opcode() => cast(Op)atom.opcode;

    /**
        The class of the atom's opcode
    */
    final @property OpClass opclass() => opcode.getClass();

    /**
        Whether the atom's opcode has a result.
    */
    final @property bool hasResult() => opcode.hasResult();

    /// Destructor
    ~this() {
        nu_freea(atom.operands);
    }

    /**
        Constructs a new Atom Object

        Params:
            atom = The atom to construct the object from.
    */
    this(NirAtom atom) {
        this.maxLength = (cast(Op)atom.opcode).getMaxLength();
        this.atom = NirAtom(
            opcode: atom.opcode,
            operands: atom.operands ? atom.operands.nu_dup() : null
        );
    }

    /**
        Constructs a new Atom Object

        Params:
            opcode = The opcode to construct the object from.
    */
    this(Op opcode) {
        this(NirAtom(opcode: opcode));
    }

    /**
        Validates the atom, ensuring its operands are within the accepted
        bounds.

        Returns:
            $(D true) if the atom validated successfully,
            $(D null) otherwise.
    */
    bool validate() {
        uint minLength = opcode.getMinLength();
        uint maxLength = opcode.getMaxLength();
        return (atom.operands.length >= minLength && atom.operands.length <= maxLength);
    }
}