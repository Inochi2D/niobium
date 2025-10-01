/**
    Niobium Shaders
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.shader;
import niobium.resource;
import niobium.device;

/**
    The different kinds of shader stages that a shader
    can apply to.
*/
enum NioShaderStage : uint {
    
    /**
        Vertex shader stage
    */
    vertex =            0x00000000U,
    
    /**
        Fragment shader stage
    */
    fragment =          0x00000001U,
    
    /**
        Compute kernel shader stage
    */
    kernel =            0x00000002U,
}

/**
    A shader
*/
abstract
class NioShader : NioResource {
protected:
@nogc:

    /**
        Constructs a new shader.

        Params:
            device = The device that "owns" this shader.
    */
    this(NioDevice device) {
        super(device);
    }

public:

    /**
        The shader stage this shader conforms to.
    */
    abstract @property NioShaderStage stage();

}