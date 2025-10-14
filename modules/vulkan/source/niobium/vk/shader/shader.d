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
import nir.ir.atom : NirAtom;
import vulkan.core;
import spirv.spv;
import nir.utils;
import numem;
import nulib;

public import niobium.shader;
public import nir.library; 
public import nir.ir.type;
public import nir.ir.binding;
public import nir.types;

/**
    A vulkan shader.
*/
class NioVkShader : NioShader {
private:
@nogc:

    // State
    SpirvModuleInfo moduleInfo_;
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

                this.moduleInfo_ = nogc_new!SpirvModuleInfo(bytecode);
                foreach(entrypoint; bytecode.getEntrypoints()) {
                    funcs ~= nogc_new!NioVkShaderFunction(device, this, entrypoint);
                }
                break;
            }
        }

        // Parse module and generate layout from it.
        this.functions_ = funcs.take();
        auto createInfo = VkShaderModuleCreateInfo(
            codeSize: bytecode.length*4,
            pCode: bytecode.ptr,
        );
        vkCreateShaderModule(nvkDevice.handle, &createInfo, null, &handle_);
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

    /**
        Information about the SPIR-V module.
    */
    final @property SpirvModuleInfo moduleInfo() => moduleInfo_;

    /// Destructor
    ~this() {
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

    vector!NirBinding bindings_;

    void setup() {
        foreach(i, ref NirBinding binding; parent_.moduleInfo.bindings) {
            if (binding.stages & entrypoint_.stage) {
                bindings_ ~= binding;
            }
        }
    }

public:

    /**
        Vulkan-native handle.
    */
    final @property VkShaderModule handle() => parent_.handle;

    /**
        Bindings associated with this function.
    */
    final @property NirBinding[] bindings() => bindings_[0..$];

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
        bindings_.clear();
        parent_.release();
    }

    /**
        Constructs a new shader function.
    */
    this(NioDevice device, NioVkShader parent, NirEntrypoint entrypoint) {
        super(device);
        this.parent_ = parent.retained();
        this.entrypoint_ = entrypoint;
        this.setup();
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

/**
    Converts a $(D NirBindingType) format to its $(D NirTypeKind) equivalent.

    Params:
        type = The $(D NirBindingType)
    
    Returns:
        The $(D NirTypeKind) equivalent.
*/
pragma(inline, true)
VkDescriptorType toVkDescriptorType(NirTypeKind kind) @nogc {
    switch(kind) with(NirTypeKind) {
        default:            return uint.max;
        case struct_:       return VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        case sampledImage:  return VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        case sampler:       return VK_DESCRIPTOR_TYPE_SAMPLER;
        case image:         return VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
    }
}

/**
    Class which manages binding and type info for a spirv/NIR module.
*/
class SpirvModuleInfo : NuObject {
private:
@nogc:
    weak_map!(uint, size_t) typeMap;
    vector!NirType types_;

    weak_map!(uint, size_t) bindingMap;
    vector!NirBinding bindings_;

    void parse(uint[] bytecode) {
        import spirv.reflection : getClass, OpClass;

        // 1.   Fetch all the relevant elements from the bytecode stream.
        //      We do this step first to make it easier to build type
        //      information, as these instructions may appear out of order.
        uint[] read = bytecode;
        weak_vector!NirAtom nirTypes_;
        weak_vector!NirAtom nirDecorations_;
        weak_vector!NirAtom nirEntrypoints_;
        weak_vector!NirAtom nirNames_;
        weak_vector!NirAtom nirVars_;
        while(read.length > 0) {
            NirAtom atom = read.next();
            switch((cast(Op)atom.opcode).getClass()) {
                case OpClass.typeDeclaration:
                    nirTypes_ ~= atom;
                    break;

                default:
                    switch((cast(Op)atom.opcode)) with(Op) {
                        default: break;
                        
                        case OpEntryPoint:
                            nirEntrypoints_ ~= atom;
                            break;

                        case OpDecorate:
                        case OpMemberDecorate:
                            nirDecorations_ ~= atom;
                            break;

                        case OpVariable:
                            nirVars_ ~= atom;
                            break;

                        case OpName:
                        case OpMemberName:
                            nirNames_ ~= atom;
                            break;
                    }
                    break;
            }
        }

        // 2.   Resolve all the types in a loop, only resolving types
        //      once prior required types are known.
        uint resolved = 0;
        uint attempts = 0;
        while(resolved < nirTypes_.length) {
            if (attempts > 100)
                throw nogc_new!NuException("Attempts ran out trying to solve shader types!");

            foreach(type; nirTypes_) {
                
                // Already resolved.
                if (type.operands[0] in typeMap)
                    continue;

                outer: switch(cast(Op)type.opcode) with(Op) {
                    case OpTypeVoid:
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeVoid();
                        resolved++;
                        break;
                    
                    case OpTypeBool:
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeBool();
                        resolved++;
                        break;

                    case OpTypeInt:
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeInt(cast(bool)type.operands[2], type.operands[1]);
                        resolved++;
                        break;

                    case OpTypeFloat:
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeFloat(type.operands[1]);
                        resolved++;
                        break;
                    
                    case OpTypeVector:

                        // Unresolvable, for now.
                        if (type.operands[1] !in typeMap) {
                            attempts++;
                            break;
                        }
                        
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeVector(
                            cast(NirTypeScalar)types_[typeMap[type.operands[1]]], 
                            type.operands[2]
                        );
                        resolved++;
                        break;
                    
                    case OpTypeMatrix:

                        // Unresolvable, for now.
                        if (type.operands[1] !in typeMap) {
                            attempts++;
                            break;
                        }
                        
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeMatrix(
                            cast(NirTypeVector)types_[typeMap[type.operands[1]]], 
                            type.operands[2]
                        );
                        resolved++;
                        break;
                    
                    case OpTypeStruct:
                        foreach(operand; type.operands[1..$]) {
                            
                            // Unresolvable, for now.
                            if (operand !in typeMap) {
                                attempts++;
                                break outer;
                            }
                        }

                        weak_vector!NirType members;
                        foreach(operand; type.operands[1..$]) {
                            members ~= types_[typeMap[operand]];
                        }
                        
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeStruct(
                            members[0..$]
                        );
                        resolved++;
                        break;
                    
                    case OpTypePointer:

                        // Unresolvable, for now.
                        if (type.operands[2] !in typeMap) {
                            attempts++;
                            break;
                        }
                        
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypePointer(
                            cast(StorageClass)type.operands[1],
                            types_[typeMap[type.operands[2]]]
                        );
                        resolved++;
                        break;
                    
                    case OpTypeImage:

                        // Unresolvable, for now.
                        if (type.operands[1] !in typeMap) {
                            attempts++;
                            break;
                        }

                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeImage(
                            types_[typeMap[type.operands[1]]],
                            cast(Dim)type.operands[2],
                            cast(bool)type.operands[4],
                            cast(bool)type.operands[5],
                            cast(ImageFormat)type.operands[7],
                        );
                        resolved++;
                        break;

                    case OpTypeSampler:
                        typeMap[type.operands[0]] = types_.length;
                        types_ ~= nogc_new!NirTypeSampler();
                        resolved++;
                        break;

                    default:
                        resolved++;
                        break;
                }
            }
        }

        // 3.   Resolve all of the variables into bindings.
        //      we needed the types for this given we need
        //      the storage class of the underlying pointers.
        foreach(var; nirVars_) {
            if (var.operands[0] !in typeMap)
                continue;

            bindingMap[var.operands[1]] = bindings_.length;
            bindings_ ~= NirBinding(
                type: types_[typeMap[var.operands[0]]],
                bindingType: (cast(StorageClass)var.operands[2]).toBindingType()
            );
        }

        // 4.   Resolve all the decorations.
        foreach(decor; nirDecorations_) {
            if (decor.operands[0] !in bindingMap)
                continue;

            auto decorType = cast(Decoration)decor.operands[1];
            auto target = &bindings_[bindingMap[decor.operands[0]]];
            
            switch(decorType) {
                default: break;

                case Decoration.DescriptorSet:
                    target.set = decor.operands[2];
                    break;
                
                case Decoration.Binding:
                case Decoration.Location:
                    target.location = decor.operands[2];
                    break;
            }
        }

        // 5.   Resolve the names of bindings.
        foreach(name; nirNames_) {
            if (name.operands[0] !in bindingMap)
                continue;
            
            auto target = &bindings_[bindingMap[name.operands[0]]];
            target.name = nstring(cast(const(char)*)&name.operands[1]).take();
        }

        // 6.   Resolve the usage of bindings.
        foreach(entrypoint; nirEntrypoints_) {
            this.discoverUsage(
                bytecode, 
                entrypoint.operands[1], 
                (cast(ExecutionModel)entrypoint.operands[0]).toNirShaderStage()
            );
        }
    }

    /// Discovers the usage of bindings recursively from the given function ID.
    void discoverUsage(uint[] bytecode, uint funcId, NirShaderStage stage, uint step = 0) {

        // 1.   Seek over to the function ID.
        uint[] read = bytecode;
        NirAtom atom = read.next();
        while(read.length > 0 && !(atom.opcode == Op.OpFunction && atom.operands[1] == funcId)) {
            atom = read.next();
        }

        // 2.   Iterate the opcodes until OpFunctionEnd.
        //      If OpLoad or OpStore is encountered, mark the pointer
        //      as used.
        while(read.length > 0 && !(atom.opcode == Op.OpFunctionEnd)) {
            atom = read.next();
            
            switch(atom.opcode) with(Op) {
                default: break;

                case OpLoad:
                    if (atom.operands[2] !in bindingMap)
                        continue;
                    
                    auto target = &bindings_[bindingMap[atom.operands[2]]];
                    target.stages |= stage;
                    break;

                case OpStore:
                    if (atom.operands[0] !in bindingMap)
                        continue;
                    
                    auto target = &bindings_[bindingMap[atom.operands[0]]];
                    target.stages |= stage;
                    break;
                
                case OpFunctionCall:

                    // Escape if recursion depth is getting ridiculous.
                    if (step > 10)
                        return;
                    
                    // Recurse into the function.
                    this.discoverUsage(bytecode, atom.operands[2], stage, step+1);
                    break;
            }
        }
    }

public:
    
    /**
        Types exposed by the shader.
    */
    final @property NirType[] types() => types_[0..$];
    
    /**
        Bindings exposed by the shader.
    */
    final @property NirBinding[] bindings() => bindings_[];

    /// Destructor
    ~this() {
        foreach(binding; bindings_) {
            nu_freea(binding.name);
        }
        bindings_.clear();
        types_.clear();
    }

    /**
        Constructs a new SpirvModuleInfo by parsing the contents
        of the shader bytecode.

        Params:
            bytecode = The bytecode to parse.
    */
    this(uint[] bytecode) {
        this.parse(bytecode);
    }
}