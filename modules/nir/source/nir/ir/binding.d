/**
    NIR Binding Introspection
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module nir.ir.binding;
import nir.ir.type;
import nir.library;
import nir.types;
import numem;

import spirv.spv : StorageClass;

/**
    Different types of binding.
*/
enum NirBindingType : uint {
    unknown =           0x00000000U,
    stageInput =        0x00000001U,
    stageOutput =       0x00000002U,
    uniform =           0x00000003U,
}

/**
    A binding
*/
struct NirBinding {
public:
@nogc:

    /**
        Mask of stages this binding is visible in.
    */
    NirShaderStage stages;

    /**
        The type of the binding.
    */
    NirBindingType bindingType;

    /**
        Type of the binding.
    */
    NirType type;

    /**
        Name of the binding, may be $(D null).
    */
    string name;

    /**
        Set of the binding, if uniform.
    */
    uint set;

    /**
        Location of the binding.
    */
    uint location;
}



/**
    Gets the $(D NirBindingType) associated with a given $(D StorageClass).

    Params:
        storage = The storage class to query.
    
    Returns:
        A non-zero $(D NirBindingType) on success,
        $(D NirBindingType.unknown) otherwise.
*/
NirBindingType toBindingType(StorageClass storage) @nogc {
    switch(storage) with(StorageClass) {
        default:                return NirBindingType.unknown;
        case Input:             return NirBindingType.stageInput;
        case Output:            return NirBindingType.stageOutput;
        case Uniform:           return NirBindingType.uniform;
        case UniformConstant:   return NirBindingType.uniform;
    }
}