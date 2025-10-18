/**
    Niobium Vulkan Render Pipeline
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.render.pipeline;
import niobium.vk.resource;
import niobium.vk.device;
import niobium.vk.shader;
import niobium.vk.shader.table;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;

public import niobium.pipeline;
public import niobium.vk.formats;
public import nir.library;
public import nir.types;
public import nir.ir.binding;
import niobium.vk.shader.shader;

/**
    A render pipeline that can be attached to a 
    $(D NioRenderCommandEncoder)
*/
class NioVkRenderPipeline : NioRenderPipeline {
private:
@nogc:
    // Handles
    VkPipeline handle_;
    VkPipelineLayout layout_;
    VkDescriptorSetLayout[] descriptorLayouts_;

    // Layout Info
    NioArgumentTable vertTable_;
    NioArgumentTable fragTable_;

    void setup(NioRenderPipelineDescriptor desc) {
        this.generateBindings(desc);
        this.layout_ = this.createLayout(desc);
        this.handle_ = this.createPipeline(desc, layout_);
    }

    void generateBindings(NioRenderPipelineDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);
        weak_vector!NirBinding allBindings;
        allBindings ~= (cast(NioVkShaderFunction)desc.vertexFunction).bindings;
        allBindings ~= (cast(NioVkShaderFunction)desc.fragmentFunction).bindings;

        // 2.   Filter bindings to remove overlapping bindings.
        weak_vector!NirBinding filteredBindings;
        outer: foreach(i, ref NirBinding binding; allBindings) {
            if (binding.bindingType <= NirBindingType.stageOutput)
                continue;

            foreach(ref NirBinding fbinding; filteredBindings) {
                bool isCompatible = 
                    (fbinding.stages & binding.stages) &&
                    fbinding.set == binding.set &&
                    fbinding.location == binding.location &&
                    fbinding.bindingType == binding.bindingType;

                if (isCompatible)
                    continue;
                
                filteredBindings ~= binding;
                continue outer;
            }
            filteredBindings ~= binding;
        }

        // 1.   Fill out the argument table and figure out the biggest set
        //      index, to be used for descriptor set generation.
        uint setCount = 0;
        this.vertTable_ = nogc_new!NioArgumentTable();
        this.fragTable_ = nogc_new!NioArgumentTable();
        foreach(i, ref NirBinding binding; allBindings) {
            if (binding.set+1 > setCount)
                setCount = binding.set+1;
            
            if (binding.stages & NirShaderStage.vertex)
                vertTable_.addBinding(binding.bindingType, NioArgumentBinding(binding.location, binding.set, binding.location));

            if (binding.stages & NirShaderStage.fragment)
                fragTable_.addBinding(binding.bindingType, NioArgumentBinding(binding.location, binding.set, binding.location));

        }

        // 2.   Generate descriptor set layouts for each set.
        this.descriptorLayouts_ = nu_malloca!VkDescriptorSetLayout(setCount);
        foreach(i, ref layout; descriptorLayouts_) {
            weak_vector!VkDescriptorSetLayoutBinding setBindings;
            foreach(j, ref NirBinding binding; filteredBindings) {
                if (i != binding.set)
                    continue;

                setBindings ~= VkDescriptorSetLayoutBinding(
                    binding: binding.location,
                    descriptorType: binding.bindingType.toVkDescriptorType(),
                    descriptorCount: 1,
                    stageFlags: binding.stages.toVkShaderStage(),
                    pImmutableSamplers: null
                );
            }

            auto createInfo = VkDescriptorSetLayoutCreateInfo(
                bindingCount: cast(uint)setBindings.length,
                pBindings: setBindings.ptr
            );
            vkCreateDescriptorSetLayout(nvkDevice.handle, &createInfo, null, layout);
        }
    }

    VkPipelineLayout createLayout(NioRenderPipelineDescriptor desc) {
        auto nvkDevice = (cast(NioVkDevice)device);
        VkPipelineLayout layout;

        // TODO:    Calculate layout from shaders and create a argument table
        //          to emulate metal.
        auto createInfo = VkPipelineLayoutCreateInfo(
            setLayoutCount: cast(uint)descriptorLayouts_.length,
            pSetLayouts: descriptorLayouts_.ptr,
            pushConstantRangeCount: 0,
            pPushConstantRanges: null
        );
        vkEnforce(vkCreatePipelineLayout(nvkDevice.handle, &createInfo, null, layout));
        return layout;
    }

    VkPipeline createPipeline(NioRenderPipelineDescriptor desc, VkPipelineLayout layout) {
        auto nvkDevice = (cast(NioVkDevice)device);
        VkPipeline pipeline;

        auto shaderStages = this.validateStages(desc);
        auto vertexInputState = this.validateInputState(desc);
        auto rasterizationState = this.validateRasterState(desc);
        auto multisampleState = this.validateMultisampleState(desc);
        auto colorBlendState = this.validateBlendState(desc);
        auto renderInfo = this.validateRenderingInfo(desc);
        auto dynamicState = VkPipelineDynamicStateCreateInfo(
            dynamicStateCount: cast(uint)__nio_dynamic_state.length,
            pDynamicStates: __nio_dynamic_state.ptr
        );
        auto createInfo = VkGraphicsPipelineCreateInfo(
            pNext: &renderInfo,
            stageCount: cast(uint)shaderStages.length,
            pStages: shaderStages.ptr,
            pVertexInputState: &vertexInputState,
            pInputAssemblyState: null,
            pTessellationState: null,
            pViewportState: null,
            pRasterizationState: &rasterizationState,
            pMultisampleState: &multisampleState,
            pDepthStencilState: null,
            pColorBlendState: &colorBlendState,
            pDynamicState: &dynamicState,
            layout: layout
        );
        vkEnforce(vkCreateGraphicsPipelines(
            nvkDevice.handle,
            null,
            1,
            &createInfo,
            null,
            &pipeline
        ));
        return pipeline;
    }

    /// Validates the blending state.
    VkPipelineColorBlendStateCreateInfo validateBlendState(NioRenderPipelineDescriptor desc) {
        VkPipelineColorBlendAttachmentState[] colorStates = nu_malloca!VkPipelineColorBlendAttachmentState(desc.colorAttachments.length);

        // Convert attachments
        foreach(i, attachment; desc.colorAttachments) {
            colorStates[i] = VkPipelineColorBlendAttachmentState(
                blendEnable: cast(VkBool32)attachment.blending,
                srcColorBlendFactor: attachment.srcColorFactor.toVkBlendFactor(),
                dstColorBlendFactor: attachment.dstColorFactor.toVkBlendFactor(),
                colorBlendOp: attachment.colorOp.toVkBlendOp(),
                srcAlphaBlendFactor: attachment.srcAlphaFactor.toVkBlendFactor(),
                dstAlphaBlendFactor: attachment.dstAlphaFactor.toVkBlendFactor(),
                alphaBlendOp: attachment.alphaOp.toVkBlendOp(),
                colorWriteMask: VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
            );
        }

        return VkPipelineColorBlendStateCreateInfo(
            attachmentCount: cast(uint)colorStates.length,
            pAttachments: colorStates.ptr
        );
    }

    VkPipelineRenderingCreateInfo validateRenderingInfo(NioRenderPipelineDescriptor desc) {
        VkFormat[] colorFormats = nu_malloca!VkFormat(desc.colorAttachments.length);
        
        // Convert attachments
        foreach(i, attachmeent; desc.colorAttachments) {
            colorFormats[i] = attachmeent.format.toVkFormat();
        }

        return VkPipelineRenderingCreateInfo(
            viewMask: 0,
            colorAttachmentCount: cast(uint)colorFormats.length,
            pColorAttachmentFormats: colorFormats.ptr,
            depthAttachmentFormat: desc.depthFormat.toVkFormat(),
            stencilAttachmentFormat: desc.stencilFormat.toVkFormat(),
        );
    }

    /// Validates the multisample state.
    VkPipelineMultisampleStateCreateInfo validateMultisampleState(NioRenderPipelineDescriptor desc) {
        return VkPipelineMultisampleStateCreateInfo(
            rasterizationSamples: cast(VkSampleCountFlagBits)(1 >> desc.sampleCount),
            alphaToCoverageEnable: cast(VkBool32)desc.alphaToCoverage,
            alphaToOneEnable: cast(VkBool32)desc.alphaToOne,
        );
    }

    /// Validates the rasterization state.
    VkPipelineRasterizationStateCreateInfo validateRasterState(NioRenderPipelineDescriptor desc) {
        return VkPipelineRasterizationStateCreateInfo(
            rasterizerDiscardEnable: VK_FALSE,
            lineWidth: 1.0,
        ); 
    }

    /// Validates the vertex input state.
    VkPipelineVertexInputStateCreateInfo validateInputState(NioRenderPipelineDescriptor desc) {
        uint[] locations = nu_malloca!uint(desc.vertexDescriptor.bindings.length);
        VkVertexInputBindingDescription[] bindings = nu_malloca!VkVertexInputBindingDescription(desc.vertexDescriptor.bindings.length);
        VkVertexInputAttributeDescription[] attributes = nu_malloca!VkVertexInputAttributeDescription(desc.vertexDescriptor.attributes.length);

        // Convert bindings
        foreach(i, binding; desc.vertexDescriptor.bindings) {
            bindings[i].binding = cast(uint)i;
            bindings[i].inputRate = binding.rate.toVkVertexInputRate();
            bindings[i].stride = binding.stride;
        }

        // Convert attributes
        foreach(i, attrib; desc.vertexDescriptor.attributes) {
            attributes[i].binding = attrib.bufferIndex;
            attributes[i].format = attrib.format.toVkFormat();
            attributes[i].location = locations[attrib.bufferIndex]++;
            attributes[i].offset = attrib.offset;
        }
        
        return VkPipelineVertexInputStateCreateInfo(
            vertexBindingDescriptionCount: cast(uint)bindings.length,
            pVertexBindingDescriptions: bindings.ptr,
            vertexAttributeDescriptionCount: cast(uint)attributes.length,
            pVertexAttributeDescriptions: attributes.ptr,
        ); 
    }

    /// Validates the shader stages of the descriptor.
    VkPipelineShaderStageCreateInfo[2] validateStages(NioRenderPipelineDescriptor desc) {
        enforce(desc.vertexFunction, "No vertex function defined!");
        enforce(desc.fragmentFunction, "No fragment function defined!");
        enforce(desc.vertexFunction.stage == NirShaderStage.vertex, "vertexFunction is not a vertex function!");
        enforce(desc.fragmentFunction.stage == NirShaderStage.fragment, "fragmentFunction is not a fragment function!");

        VkPipelineShaderStageCreateInfo[2] shaderStages = [
            VkPipelineShaderStageCreateInfo(
                stage: VK_SHADER_STAGE_VERTEX_BIT,
                module_: (cast(NioVkShaderFunction)desc.vertexFunction).handle,
                pName: desc.vertexFunction.name.ptr,
                pSpecializationInfo: null,
            ),
            VkPipelineShaderStageCreateInfo(
                stage: VK_SHADER_STAGE_FRAGMENT_BIT,
                module_: (cast(NioVkShaderFunction)desc.fragmentFunction).handle,
                pName: desc.fragmentFunction.name.ptr,
                pSpecializationInfo: null,
            ),
        ];
        return shaderStages;
    }

public:

    /**
        Underlying Vulkan handle.
    */
    final @property VkPipeline handle() => handle_;

    /**
        Underlying Vulkan handle.
    */
    final @property VkPipelineLayout layout() => layout_;

    /**
        Underlying descriptor sets.
    */
    final @property VkDescriptorSetLayout[] descriptorLayouts() => descriptorLayouts_[0..$];

    /**
        Vertex argument table.
    */
    final @property NioArgumentTable vertexTable() => vertTable_;

    /**
        Fragment argument table.
    */
    final @property NioArgumentTable fragmentTable() => fragTable_;

    /// Destructor
    ~this() {
        auto nvkDevice = (cast(NioVkDevice)device);
        vkDestroyPipelineLayout(nvkDevice.handle, layout_, null);
        vkDestroyPipeline(nvkDevice.handle, handle_, null);
        
        foreach(desc; descriptorLayouts_)
            vkDestroyDescriptorSetLayout(nvkDevice.handle, desc, null);
        nu_freea(descriptorLayouts_);
        vertTable_.release();
        fragTable_.release();
    }

    /**
        Constructs a new pipeline.

        Params:
            device =    The device that "owns" this pipeline.
            desc =      Descriptor used to create the pipeline.
    */
    this(NioDevice device, NioRenderPipelineDescriptor desc) {
        super(device, desc);
        this.setup(desc);
    }
}

/**
    Converts a $(D NioBlendFactor) format to its $(D VkBlendFactor) equivalent.

    Params:
        factor = The $(D NioBlendFactor)
    
    Returns:
        The $(D VkBlendFactor) equivalent.
*/
pragma(inline, true)
VkBlendFactor toVkBlendFactor(NioBlendFactor factor) @nogc {
    final switch(factor) with(NioBlendFactor) {
        case zero:                  return VK_BLEND_FACTOR_ZERO;                
        case one:                   return VK_BLEND_FACTOR_ONE;                
        case srcColor:              return VK_BLEND_FACTOR_SRC_COLOR;                    
        case oneMinusSrcColor:      return VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR;                            
        case srcAlpha:              return VK_BLEND_FACTOR_SRC_ALPHA;                    
        case oneMinusSrcAlpha:      return VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;                            
        case dstColor:              return VK_BLEND_FACTOR_DST_COLOR;                    
        case oneMinusDstColor:      return VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;                            
        case dstAlpha:              return VK_BLEND_FACTOR_DST_ALPHA;                    
        case oneMinusDstAlpha:      return VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;                            
        case srcAlphaSaturate:      return VK_BLEND_FACTOR_SRC_ALPHA_SATURATE;                            
        case blendColor:            return VK_BLEND_FACTOR_CONSTANT_COLOR;                        
        case oneMinusBlendColor:    return VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR;                                
        case blendAlpha:            return VK_BLEND_FACTOR_CONSTANT_ALPHA;                        
        case oneMinusBlendAlpha:    return VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA;                                
        case src1Color:             return VK_BLEND_FACTOR_SRC1_COLOR;                    
        case oneMinusSrc1Color:     return VK_BLEND_FACTOR_ONE_MINUS_SRC1_COLOR;                            
        case src1Alpha:             return VK_BLEND_FACTOR_SRC1_ALPHA;                    
        case oneMinusSrc1Alpha:     return VK_BLEND_FACTOR_ONE_MINUS_SRC1_ALPHA;                            
    }
}

/**
    Converts a $(D NioBlendOp) format to its $(D VkBlendOp) equivalent.

    Params:
        op = The $(D NioBlendOp)
    
    Returns:
        The $(D VkBlendOp) equivalent.
*/
pragma(inline, true)
VkBlendOp toVkBlendOp(NioBlendOp op) @nogc {
    final switch(op) with(NioBlendOp) {
        case add:       return VK_BLEND_OP_ADD;
        case subtract:  return VK_BLEND_OP_SUBTRACT;
    }
}

/**
    Converts a $(D NioVertexInputRate) format to its $(D VkVertexInputRate) equivalent.

    Params:
        rate = The $(D NioVertexInputRate)
    
    Returns:
        The $(D VkVertexInputRate) equivalent.
*/
pragma(inline, true)
VkVertexInputRate toVkVertexInputRate(NioVertexInputRate rate) @nogc {
    final switch(rate) with(NioVertexInputRate) {
        case perVertex:     return VK_VERTEX_INPUT_RATE_VERTEX;
        case perInstance:   return VK_VERTEX_INPUT_RATE_INSTANCE;
    }
}

//
//          IMPLEMENTATION DETAILS.
//
private:
__gshared VkDynamicState[] __nio_dynamic_state = [

    // General
    VK_DYNAMIC_STATE_VIEWPORT_WITH_COUNT,
    VK_DYNAMIC_STATE_SCISSOR_WITH_COUNT,
    VK_DYNAMIC_STATE_PRIMITIVE_RESTART_ENABLE,
    VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY,

    // Blend Constants
    VK_DYNAMIC_STATE_BLEND_CONSTANTS,

    // Rendering Behaviour
    VK_DYNAMIC_STATE_POLYGON_MODE_EXT,
    VK_DYNAMIC_STATE_CULL_MODE,
    VK_DYNAMIC_STATE_FRONT_FACE,

    // Depth-Stencil Behaviour
    VK_DYNAMIC_STATE_STENCIL_REFERENCE,
    VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE,
    VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE,
    VK_DYNAMIC_STATE_DEPTH_COMPARE_OP,
    VK_DYNAMIC_STATE_DEPTH_BOUNDS_TEST_ENABLE,
    VK_DYNAMIC_STATE_STENCIL_TEST_ENABLE,
    VK_DYNAMIC_STATE_STENCIL_OP,
    VK_DYNAMIC_STATE_DEPTH_BOUNDS, 
    VK_DYNAMIC_STATE_DEPTH_BIAS_ENABLE,
    VK_DYNAMIC_STATE_DEPTH_BIAS,
    VK_DYNAMIC_STATE_DEPTH_CLAMP_ENABLE_EXT,
];