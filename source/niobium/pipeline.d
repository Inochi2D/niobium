/**
    Niobium Pipelines
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.pipeline;
import niobium.pixelformat;
import niobium.vertexformat;
import niobium.resource;
import niobium.device;
import niobium.shader;

/**
    A render pipeline that can be attached to a 
    $(D NioComputeCommandEncoder)
*/
abstract
class NioComputePipeline : NioResource {
protected:
@nogc:

    /**
        Constructs a new pipeline.

        Params:
            device = The device that "owns" this pipeline.
    */
    this(NioDevice device) {
        super(device);
    }

public:
}

/**
    Describes a render pipeline.
*/
struct NioRenderPipelineDescriptor {

    /**
        Vertex shader stage function.
    */
    NioShaderFunction vertexFunction;

    /**
        Fragment shader stage function.
    */
    NioShaderFunction fragmentFunction;

    /**
        The layout and attributes of vertex data.
    */
    NioVertexDescriptor vertexDescriptor;

    /**
        Color attachments for the render pipeline
    */
    NioRenderPipelineAttachmentDescriptor[] colorAttachments;

    /**
        Format of the depth texture, may be $(D unknown).
    */
    NioPixelFormat depthFormat = NioPixelFormat.unknown;

    /**
        Format of the stencil texture, may be $(D unknown).
    */
    NioPixelFormat stencilFormat = NioPixelFormat.unknown;

    /**
        Whether alpha-to-coverage is enabled.
    */
    bool alphaToCoverage;

    /**
        The amount of multisample samples to use.
    */
    uint sampleCount;
}

/**
    Step function to apply for vertex attributes.
*/
enum NioVertexStepFunction {
    
    /**
        Vertex fetches a new attribute once, and uses
        it for the rest of the draw.
    */
    constant =          0x00000001U,
    
    /**
        Vertex fetches a new attribute per vertex.
    */
    perVertex =         0x00000002U,
    
    /**
        Vertex fetches a new attribute per instance.
    */
    perInstance =       0x00000003U,
    
    /**
        Vertex fetches a new attribute based on patch indices.
    */
    perPatch =          0x00000004U,
    
    /**
        Vertex fetches a new attribute based on 
        patch control point indices.
    */
    perPatchControl =   0x00000004U,
}

/**
    Descriptor used to define how vertex buffers are laid out.
*/
struct NioVertexDescriptor {

    /**
        Descriptors for every attribute in every buffer
        listed in $(D layout).
    */
    NioVertexAttributeDescriptor[] attributes;
    
    /**
        Descriptors for every vertex buffer attached
        to this pipeline.
    */
    NioVertexLayoutDescriptor[] layout;
}

/**
    Describes the format of a single attribute.
*/
struct NioVertexAttributeDescriptor {

    /**
        The format of the vertex data for this attribute.
    */
    NioVertexFormat format;

    /**
        The offset of this attribute into the vertex buffer, in bytes.
    */
    uint offset;

    /**
        The buffer this attribute applies to.
    */
    uint bufferIndex;
}

/**
    Describes the layout of a single vertex buffer.
*/
struct NioVertexLayoutDescriptor {
    NioVertexStepFunction step = NioVertexStepFunction.perVertex;
    uint rate = 0;

    /**
        The stride between each attribute iteration of the buffer.
    */
    uint stride;
}

/**
    Blending operations for fixed function blending.
*/
enum NioBlendOp : uint {

    /**
        Adds source and destination together.
    */
    add =           0x00000001U,
    
    /**
        Subtracts source from destination.
    */
    subtract =      0x00000002U,
}

/**
    Blending factors for fixed function blending.
*/
enum NioBlendFactor : uint {
    zero =                  0x00000000U,
    one =                   0x00000001U,
    srcColor =              0x00000002U,
    oneMinusSrcColor =      0x00000003U,
    srcAlpha =              0x00000004U,
    oneMinusSrcAlpha =      0x00000005U,
    dstColor =              0x00000006U,
    oneMinusDstColor =      0x00000007U,
    dstAlpha =              0x00000008U,
    oneMinusDstAlpha =      0x00000009U,
    srcAlphaSaturate =      0x0000000AU,
    blendColor =            0x0000000BU,
    oneMinusBlendColor =    0x0000000CU,
    blendAlpha =            0x0000000DU,
    oneMinusBlendAlpha =    0x0000000EU,
    src1Color =             0x0000000FU,
    oneMinusSrc1Color =     0x00000010U,
    src1Alpha =             0x00000011U,
    oneMinusSrc1Alpha =     0x00000012U,
}

/**
    Describes a color attachment of a render pipeline.
*/
struct NioRenderPipelineAttachmentDescriptor {

    /**
        Pixel format of the attachment.
    */
    NioPixelFormat format;

    /**
        Whether blending is enabled.
    */
    bool blending;

    /**
        Color blending operation
    */
    NioBlendOp colorOp;

    /**
        Alpha blending operation
    */
    NioBlendOp alphaOp;

    /**
        Source color blending factor
    */
    NioBlendFactor srcColorFactor;

    /**
        Source alpha blending factor
    */
    NioBlendFactor srcAlphaFactor;

    /**
        Destination color blending factor
    */
    NioBlendFactor dstColorFactor;

    /**
        Destination alpha blending factor
    */
    NioBlendFactor dstAlphaFactor;
}

/**
    A render pipeline that can be attached to a 
    $(D NioRenderCommandEncoder)
*/
abstract
class NioRenderPipeline : NioResource {
protected:
@nogc:

    /**
        Constructs a new pipeline.

        Params:
            device = The device that "owns" this pipeline.
    */
    this(NioDevice device) {
        super(device);
    }

public:
}