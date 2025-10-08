/**
    NIR Modules
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.ir.mod;
import nir.ir.atom;
import nir.ir.type;
import numem;

/**
    A NIR Module.
*/
class NirModule : NuRefCounted {
private:
@nogc:
    NirType[] types_;

public:

    /**
        The types currently registered within the module.
    */
    @property NirType[] types() => types_;

}

// /**
//     A NIR Module.
// */
// class NirModule : NuRefCounted {
// private:
// @nogc:
//     NirInstruction[] instructions_;

// public:

//     /**
//         The reported spirv version tag.
//     */
//     uint spirvVersion;

//     /**
//         The reported code generator.
//     */
//     uint generatorMagic;

//     /**
//         The reported schema.
//     */
//     uint schema;
    
//     /**
//         The instruction stream of the module.
//     */
//     final @property NirInstruction[] instructions() => instructions_;

//     /**
//         Creates a NirModule from a stream.
//     */
//     static NirModule fromStream(Stream stream) {
//         import nulib.collections.vector : weak_vector;
//         import nulib.io.stream.rw : StreamReader;

//         auto result = nogc_new!NirModule();
//         auto reader = nogc_new!StreamReader(stream);
//         auto magic = reader.readU32LE();

//         // Read instructions.
//         weak_vector!NirInstruction instrs;
//         if (magic == 0x07230203) {
//             result.spirvVersion = reader.readU32LE();       // SPIR-V Version
//             result.generatorMagic = reader.readU32LE();     // Generator Magic Bytes
//             stream.seek(4, SeekOrigin.relative);            // Skip bound count.
//             result.schema = reader.readU32LE();             // Instruction Schema

//             ptrdiff_t len = stream.length;
//             while(stream.tell < len) {
//                 NirInstruction instr;
//                 uint data = reader.readU32LE();

//                 // Parse opcode and operand length.
//                 instr.opcode = data | 0x0000FFFF;
//                 instr.operands = nu_malloca!uint(data >> 16);
//                 foreach(ref opr; instr.operands)
//                     opr = reader.readU32LE();

//                 instrs ~= instr;
//             }
//         } else {
//             result.spirvVersion = reader.readU32BE();       // SPIR-V Version
//             result.generatorMagic = reader.readU32BE();     // Generator Magic Bytes
//             stream.seek(4, SeekOrigin.relative);            // Skip bound count.
//             result.schema = reader.readU32BE();             // Instruction Schema

//             ptrdiff_t len = stream.length;
//             while(stream.tell < len) {
//                 NirInstruction instr;
//                 uint data = reader.readU32BE();

//                 // Parse opcode and operand length.
//                 instr.opcode = data | 0x0000FFFF;
//                 instr.operands = nu_malloca!uint(data >> 16);
//                 foreach(ref opr; instr.operands)
//                     opr = reader.readU32BE();

//                 instrs ~= instr;
//             }
//         }

//         result.instructions_ = instrs.take();
//         return result;
//     }

//     /**
//         Writes the module to a stream.

//         Params:
//             stream = The stream to write to.
//     */
//     void write(Stream stream) {
//         import nulib.io.stream.rw : StreamWriter;

//         auto writer = nogc_new!StreamWriter(stream);
        
//         writer.writeLE!uint(0x07230203);                        // Magic Bytes
//         writer.writeLE!uint(0x00010300);                        // SPIR-V Version
//         writer.writeLE!uint(45);                                // NUVK Magic Bytes
//         writer.writeLE!uint(cast(uint)instructions_.length);    // TODO: Fill out actual Result count.
//         writer.writeLE!uint(0x0BADF00D);                        // Instruction Schema, intentionally incompatible with SPIR-V
//         foreach(i, instr; instructions_) {
//             ushort opLength = cast(ushort)instr.operands.length;
//             uint opcode = cast(uint)(opLength << 16) | (instr.opcode & 0x0000FFFF);
//             writer.writeLE(opcode);
//             foreach(op; instr.operands)
//                 writer.writeLE(op);
//         }
//         nogc_delete(writer);
//     }
// }