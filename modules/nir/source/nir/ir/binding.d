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

import nir.ir.spirv.spv : StorageClass;

/**
    Different types of binding.
*/
enum NirBindingType : uint {
    unknown =           0x00000000U,
    stageInput =        0x00000001U,
    stageOutput =       0x00000002U,
    uniform =           0x00000003U,
    storage =           0x00000004U,
    texture =           0x00000005U,
    sampler =           0x00000006U,
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
    Gets the $(D NirBindingType) associated with a given $(D StorageClass)
    and $(D NirTypePointer).

    Params:
        storage =   The storage class to query.
        type =      In the case of uniforms, the type of the uniform.
    
    Returns:
        A non-zero $(D NirBindingType) on success,
        $(D NirBindingType.unknown) otherwise.
*/
pragma(inline, true)
NirBindingType toBindingType(StorageClass storage, NirTypePointer type = null) @nogc {
    switch(storage) with(StorageClass) {
        default:                return NirBindingType.unknown;
        case Input:             return NirBindingType.stageInput;
        case Output:            return NirBindingType.stageOutput;
        case StorageBuffer:     return NirBindingType.storage;
        case Uniform:
        case UniformConstant:
            if (type) {
                switch(type.elementType.kind) with(NirTypeKind) {
                    default:        return NirBindingType.uniform;
                    case image:     return NirBindingType.texture;
                    case sampler:   return NirBindingType.sampler;
                }
            }
            return NirBindingType.uniform;
    }
}