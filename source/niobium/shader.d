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
import niobium.device;
import nir.library;
import nir.types;
import numem;

/**
    A shader
*/
abstract
class NioShader : NioDeviceObject {
private:
@nogc:
    NirLibrary library_;

protected:

    /**
        The NIR Library attached to this shader.
    */
    final @property NirLibrary library() => library_;

    /**
        Constructs a new shader.

        Params:
            device =    The device that "owns" this shader.
            desc =      The descriptor usde to create the shader.
    */
    this(NioDevice device, NirLibrary library) {
        super(device);
        this.library_ = library.retained();
    }

public:

    /// Destructor
    ~this() {
        library_.release();
    }

    /**
        Gets a named function from the shader.

        Params:
            name = The name of the function.
        
        Returns:
            A $(D NioShaderFunction) on success,
            $(D null) otherwise.
    */
    abstract NioShaderFunction getFunction(string name);
}

/**
    A shader function.
*/
abstract
class NioShaderFunction : NioDeviceObject {
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
        Name of the function
    */
    abstract @property string name();

    /**
        The shader stage this shader conforms to.
    */
    abstract @property NirShaderStage stage();
}