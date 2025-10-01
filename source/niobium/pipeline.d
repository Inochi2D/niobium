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
import niobium.resource;
import niobium.device;
import niobium.shader;

/**
    The different kinds of pipeline that may exist.
*/
enum NioPipelineKind : uint {

    /**
        Pipeline can be attached to render passes.
    */
    graphics =          0x00000001,

    /**
        Pipeline can be attached to compute passes.
    */
    compute =           0x00000002,

    /**
        Pipeline can be attached to transfer passes.
    */
    transfer =          0x00000003,
}

/**
    A pipeline which can be attached to a command buffer.
*/
abstract
class NioPipeline : NioResource {
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

    /**
        Which kind of pipeline this is.
    */
    abstract @property NioPipelineKind kind();
}