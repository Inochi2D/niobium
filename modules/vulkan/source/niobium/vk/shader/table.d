/**
    Argument tables for Vulkan shaders, allowing the semantics
    of Metal to be replicated in Vulkan.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.shader.table;
import niobium.pipeline;
import numem;
import nulib;

/**
    Argument types.
*/
enum NioArgumentType : uint {
    vertex          = 0x00000000U,
    uniform         = 0x00000001U,
    storage         = 0x00000002U,
    texture         = 0x00000003U,
    sampler         = 0x00000004U,
}

/**
    Binding slot for a shader.
*/
struct NioArgumentBinding {
    uint slot;
    uint bindingSlot;
    uint bindingLocation;
}

/**
    A table of the different binding points in a pipeline.
*/
class NioArgumentTable : NuRefCounted {
private:
@nogc:
    enum argumentTypeCount = __traits(allMembers, NioArgumentType).length;
    vector!(NioArgumentBinding)[argumentTypeCount] bindings;

    // Finds a binding within the table.
    ptrdiff_t findBinding(NioArgumentType type, uint slot) {
        foreach(i, binding; bindings[type])
            if (binding.slot == slot)
                return i;
        return -1;
    }

public:

    /**
        Adds a binding to the argument table.

        Params:
            type =      The type to add a binding for.
            binding =   The binding to add.
    */
    void addBinding(NioArgumentType type, NioArgumentBinding binding) {
        ptrdiff_t idx = this.findBinding(type, binding.slot);
        if (idx == -1) {
            bindings[type] ~= binding;
            return;
        }

        bindings[type][idx] = binding; 
    }

    /**
        Gets a binding from the table.

        Params:
            type = The type of binding to get
            slot = The slot to get for that binding.
    */
    NioArgumentBinding* getBinding(NioArgumentType type, uint slot) {
        ptrdiff_t idx = this.findBinding(type, slot);
        return idx >= 0 ? &bindings[type][idx] : null;
    }
}