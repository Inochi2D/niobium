/**
    Niobium Command Buffers.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.cmd;
import niobium.queue;
import niobium.device;
import niobium.surface;
import niobium.texture;
import numem;

/**
    A buffer of commands which can be sent to the GPU
    for processing.

    Note:
        Submitting a command buffer will invalidate it,
        this means that you cannot modify its state any
        longer. Once submitted it's safe to $(D release)
        the command buffer.
*/
abstract
class NioCommandBuffer : NioDeviceObject {
private:
@nogc:
    NioCommandQueue queue_;
    NioCommandEncoder encoder_;

protected:

    /**
        The currently active command encoder.
    */
    final @property NioCommandEncoder activeEncoder() => encoder_;

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
    */
    this(NioDevice device, NioCommandQueue queue) {
        super(device);
        this.queue_ = queue;
    }

public:

    /**
        The queue the buffer belongs to.
    */
    final @property NioCommandQueue queue() => queue_;

    /**
        Begins a new render pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Returns:
            A short lived $(D NioRenderCommandEncoder) on success,
            $(D null) on failure.
    */
    abstract NioRenderCommandEncoder beginRenderPass();

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        You may only make one presentation request
        per command buffer. Any extra present requests
        will be ignored.

        Params:
            drawable = The drawable to present.
    */
    abstract void present(NioDrawable drawable);

    /**
        Awaits the completion of the command buffer
        execution.
    */
    abstract void await();
}

/**
    A short-lived object which encodes commands into a
    $(D NioCommandBuffer). Only one $(D NioCommandEncoder)
    can be active at a time for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
abstract
class NioCommandEncoder : NuObject {
private:
@nogc:
    NioCommandBuffer cmdbuffer_;

protected:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        this.cmdbuffer_ = buffer;
    }

public:

    /**
        The command buffer the encoder is recording to.
    */
    final @property NioCommandBuffer commandBuffer() => cmdbuffer_;

    /**
        Ends the encoding pass, allowing a new pass to be
        begun from the parent command buffer.
    */
    abstract void endEncoding();
}

/**
    A short-lived object which encodes rendering commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
abstract
class NioRenderCommandEncoder : NioCommandEncoder {
protected:
@nogc:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        super(buffer);
    }

public:


}

/**
    A short-lived object which encodes transfer commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
abstract
class NioTransferCommandEncoder : NioCommandEncoder {
protected:
@nogc:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        super(buffer);
    }

public:

    /**
        Generates mipmaps for the given texture.

        Params:
            texture = The texture to generate mipmaps for.
    */
    void generateMipmaps(NioTexture texture);

    /**
        Copies the contents of the source texture
        into the destination texture.

        Params:
            src = The source texture.
            dst = The desination texture.
    */
    void copy(NioTexture src, NioTexture dst);
}