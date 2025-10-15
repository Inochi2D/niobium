/**
    Niobium Metal Render Pipeline
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.render.pipeline;
import niobium.mtl.resource;
import niobium.mtl.device;
import niobium.mtl.shader;
import niobium.mtl.formats;
import metal.renderpipeline;
import metal.vertexdescriptor;
import foundation;
import numem;
import nulib;
import nulib.math : min, max;

public import niobium.pipeline;

/**
    A render pipeline that can be attached to a 
    $(D NioRenderCommandEncoder)
*/
class NioMTLRenderPipeline : NioRenderPipeline {
private:
@nogc:

    // Handles
    MTLRenderPipelineState handle_;

    void setup(NioRenderPipelineDescriptor desc) {
        auto mtlDevice = cast(NioMTLDevice)device;
        MTLRenderPipelineDescriptor mtldesc = MTLRenderPipelineDescriptor.alloc.init;
        
        // Basic settings
        mtldesc.isAlphaToCoverageEnabled = desc.alphaToCoverage;
        mtldesc.isAlphaToOneEnabled = desc.alphaToOne;
        mtldesc.isRasterizationEnabled = desc.fragmentFunction !is null;
        mtldesc.rasterSampleCount = max(1, desc.sampleCount);

        // Functions
        mtldesc.vertexFunction = (cast(NioMTLShaderFunction)desc.vertexFunction).handle;
        mtldesc.fragmentFunction = (cast(NioMTLShaderFunction)desc.fragmentFunction).handle;

        // Vertex Descriptor
        foreach(i, attrib; desc.vertexDescriptor.attributes) {
            MTLVertexAttributeDescriptor attribdesc = MTLVertexAttributeDescriptor.alloc.init;
            attribdesc.bufferIndex = attrib.bufferIndex;
            attribdesc.offset = attrib.offset;
            attribdesc.format = attrib.format.toMTLVertexFormat();

            mtldesc.vertexDescriptor.attributes.set(attribdesc, i);
        }
        foreach(i, layout; desc.vertexDescriptor.bindings) {
            MTLVertexBufferLayoutDescriptor layoutdesc = MTLVertexBufferLayoutDescriptor.alloc.init;
            layoutdesc.stride = layout.stride;
            layoutdesc.stepFunction = layout.rate.toMTLVertexStepFunction();
            layoutdesc.stepRate = 1;

            mtldesc.vertexDescriptor.layouts.set(layoutdesc, i);
        }

        // Color attachments
        foreach(i, attachment; desc.colorAttachments) {
            MTLRenderPipelineColorAttachmentDescriptor attachdesc = mtldesc.colorAttachments.get(i);
            attachdesc.pixelFormat =                    attachment.format.toMTLPixelFormat();
            attachdesc.isBlendingEnabled =              attachment.blending;
            attachdesc.alphaBlendOperation =            attachment.alphaOp.toMTLBlendOperation();
            attachdesc.rgbBlendOperation =              attachment.colorOp.toMTLBlendOperation();
            attachdesc.sourceRGBBlendFactor =           attachment.srcColorFactor.toMTLBlendFactor();
            attachdesc.sourceAlphaBlendFactor =         attachment.srcAlphaFactor.toMTLBlendFactor();
            attachdesc.destinationRGBBlendFactor =      attachment.dstColorFactor.toMTLBlendFactor();
            attachdesc.destinationAlphaBlendFactor =    attachment.dstAlphaFactor.toMTLBlendFactor();

            // TODO: Multisample state
        }

        // Depth-stencil attachments.
        mtldesc.depthAttachmentPixelFormat = desc.depthFormat.toMTLPixelFormat();
        mtldesc.stencilAttachmentPixelFormat = desc.stencilFormat.toMTLPixelFormat();

        NSError error;
        this.handle_ = mtlDevice.handle.newRenderPipelineState(mtldesc, error);
        if (error) {
            string msg = error.toString();
            error.release();
            throw nogc_new!NuException(msg);
        }
        mtldesc.release();
    }

public:

    /**
        Underlying Metal handle.
    */
    final @property MTLRenderPipelineState handle() => handle_;

    /// Destructor
    ~this() {
        handle_.release();
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
    Converts a $(D NioBlendFactor) format to its $(D MTLBlendFactor) equivalent.

    Params:
        factor = The $(D NioBlendFactor)
    
    Returns:
        The $(D MTLBlendFactor) equivalent.
*/
pragma(inline, true)
MTLBlendFactor toMTLBlendFactor(NioBlendFactor factor) @nogc {
    final switch(factor) with(NioBlendFactor) {
        case zero:                  return MTLBlendFactor.Zero;
        case one:                   return MTLBlendFactor.One;
        case srcColor:              return MTLBlendFactor.SourceColor;
        case oneMinusSrcColor:      return MTLBlendFactor.OneMinusSourceColor;
        case srcAlpha:              return MTLBlendFactor.SourceAlpha;
        case oneMinusSrcAlpha:      return MTLBlendFactor.OneMinusSourceAlpha;
        case dstColor:              return MTLBlendFactor.DestinationColor;
        case oneMinusDstColor:      return MTLBlendFactor.OneMinusDestinationColor;
        case dstAlpha:              return MTLBlendFactor.DestinationAlpha;
        case oneMinusDstAlpha:      return MTLBlendFactor.OneMinusDestinationAlpha;
        case srcAlphaSaturate:      return MTLBlendFactor.SourceAlphaSaturated;
        case blendColor:            return MTLBlendFactor.BlendColor;
        case oneMinusBlendColor:    return MTLBlendFactor.OneMinusBlendColor;
        case blendAlpha:            return MTLBlendFactor.BlendAlpha;
        case oneMinusBlendAlpha:    return MTLBlendFactor.OneMinusBlendAlpha;
        case src1Color:             return MTLBlendFactor.Source1Color;
        case oneMinusSrc1Color:     return MTLBlendFactor.OneMinusSource1Color;
        case src1Alpha:             return MTLBlendFactor.Source1Alpha;
        case oneMinusSrc1Alpha:     return MTLBlendFactor.OneMinusSource1Alpha;
    }
}

/**
    Converts a $(D NioBlendOp) format to its $(D MTLBlendOperation) equivalent.

    Params:
        op = The $(D NioBlendOp)
    
    Returns:
        The $(D MTLBlendOperation) equivalent.
*/
pragma(inline, true)
MTLBlendOperation toMTLBlendOperation(NioBlendOp op) @nogc {
    final switch(op) with(NioBlendOp) {
        case add:               return MTLBlendOperation.Add;
        case subtract:          return MTLBlendOperation.Subtract;
    }
}

/**
    Converts a $(D NioVertexInputRate) format to its $(D MTLVertexStepFunction) equivalent.

    Params:
        rate = The $(D NioVertexInputRate)
    
    Returns:
        The $(D MTLVertexStepFunction) equivalent.
*/
pragma(inline, true)
MTLVertexStepFunction toMTLVertexStepFunction(NioVertexInputRate rate) @nogc {
    final switch(rate) with(NioVertexInputRate) {
        case perVertex:     return MTLVertexStepFunction.PerVertex;
        case perInstance:   return MTLVertexStepFunction.PerInstance;
    }
}