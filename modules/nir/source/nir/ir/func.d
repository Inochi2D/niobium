/**
    NIR Compiler Type System
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.ir.func;
import nir.ir.type;
import nir.ir.atom;
import numem;

/**
    A function.
*/
class NirFunction : NirAtomObject {
private:
@nogc:
    NirTypeFunction type;
    NirAtomObject[] instructions_;

public:

    /**
        The return type of this function.
    */
    @property NirType returnType() => type.returnType;

    /**
        Creates a new function with the given type.

        Params:
            type = The type of the function.
    */
    this(NirTypeFunction type) {
        super(Op.OpFunction);
        this.type = type.retained();
    }
}