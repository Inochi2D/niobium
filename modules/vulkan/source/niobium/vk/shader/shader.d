/**
    Niobium Vulkan Shader Infrastructure
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.shader.shader;
import niobium.vk.shader.table;
import niobium.vk.device;
import vulkan.core;
import nir.utils;
import numem;
import nulib;

public import niobium.shader;
public import nir.library; 
public import nir.types;

/**
    A vulkan shader.
*/
class NioVkShader : NioShader {
private:
@nogc:

    // State
    NioArgumentTable table_;
    NioVkShaderFunction[] functions_;
    NirShader shader_;

    // Handles
    VkShaderModule handle_;

    void setup(NirLibrary library) {
        auto nvkDevice = (cast(NioVkDevice)device);

        weak_vector!NioVkShaderFunction funcs;
        foreach(ref shader; library.shaders) {
            if (shader.type == NirShaderType.nir) {
                this.shader_ = NirShader(
                    name: nstring(shader.name).take(),
                    type: shader.type,
                    code: shader.code.nu_dup()
                );

                foreach(entrypoint; bytecode.getEntrypoints()) {
                    funcs ~= nogc_new!NioVkShaderFunction(device, this, entrypoint);
                }
                break;
            }
        }
        this.functions_ = funcs.take();

        auto createInfo = VkShaderModuleCreateInfo(
            codeSize: bytecode.length*4,
            pCode: bytecode.ptr,
        );
        vkCreateShaderModule(nvkDevice.handle, &createInfo, null, &handle_);
        this.table_ = nogc_new!NioArgumentTable();
    }

public:

    /**
        The shader bytecode.
    */
    final @property uint[] bytecode() => (cast(uint[])shader_.code);

    /**
        Vulkan-native handle.
    */
    final @property VkShaderModule handle() => handle_;

    /// Destructor
    ~this() {
        table_.release();
        nu_freea(shader_.name);
        nu_freea(shader_.code);
        
        auto nvkDevice = (cast(NioVkDevice)device);
        vkDestroyShaderModule(nvkDevice.handle, handle_, null);
    }

    /**
        Constructs a new shader from a Nir library.
    */
    this(NioDevice device, NirLibrary library) {
        super(device, library);
        this.setup(library);
    }

    /**
        Gets a named function from the shader.

        Params:
            name = The name of the function.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    override NioShaderFunction getFunction(string name) {
        foreach(func; functions_) {
            if (func.name == name)
                return func;
        }
        return null;
    }
}

/**
    A vulkan shader function.
*/
class NioVkShaderFunction : NioShaderFunction {
private:
@nogc:
    NioVkShader parent_;
    NirEntrypoint entrypoint_;

public:

    /**
        Vulkan-native handle.
    */
    final @property VkShaderModule handle() => parent_.handle;

    /**
        Name of the function
    */
    override @property string name() => entrypoint_.name;

    /**
        The shader stage this shader conforms to.
    */
    override @property NirShaderStage stage() => entrypoint_.stage;

    /// Destructor
    ~this() {
        parent_.release();
    }

    /**
        Constructs a new shader function.
    */
    this(NioDevice device, NioVkShader parent, NirEntrypoint entrypoint) {
        super(device);
        this.parent_ = parent.retained();
        this.entrypoint_ = entrypoint;
    }
}

/**
    Converts a $(D NirShaderStage) format to its $(D VkShaderStageFlags) equivalent.

    Params:
        stage = The $(D NirShaderStage)
    
    Returns:
        The $(D VkShaderStageFlags) equivalent.
*/
pragma(inline, true)
VkShaderStageFlags toVkShaderStageFlags(NirShaderStage stage) @nogc {
    final switch(stage) with(NirShaderStage) {
        case vertex:    return VK_SHADER_STAGE_VERTEX_BIT;
        case fragment:  return VK_SHADER_STAGE_FRAGMENT_BIT;
        case task:      return VK_SHADER_STAGE_TASK_BIT_EXT;
        case mesh:      return VK_SHADER_STAGE_MESH_BIT_EXT;
        case kernel:    return VK_SHADER_STAGE_COMPUTE_BIT;
    }
}