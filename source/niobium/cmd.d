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
import niobium.buffer;
import niobium.sync;
import niobium.types;
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

protected:

    /**
        The currently active command encoder.
    */
    NioCommandEncoder activeEncoder;

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
        Begins a new transfer pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Returns:
            A short lived $(D NioTransferCommandEncoder) on success,
            $(D null) on failure.
    */
    abstract NioTransferCommandEncoder beginTransferPass();

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

    /**
        Helper internal function to allow ending the command
        encoder.
    */
    final void finishEncoding() {
        if (cmdbuffer_.activeEncoder) {
            nogc_delete(cmdbuffer_.activeEncoder);
            cmdbuffer_.activeEncoder = null;
        }
    }

public:

    /**
        The command buffer the encoder is recording to.
    */
    final @property NioCommandBuffer commandBuffer() => cmdbuffer_;

    /**
        Pushes a debug group.

        Params:
            name = The name of the debug group
            color = The color of the debug group (optional)
    */
    abstract void pushDebugGroup(string name, float[4] color = [0, 0, 0, 1]);

    /**
        Pops the top debug group from the debug
        group stack.
    */
    abstract void popDebugGroup();

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
    Descriptor for a buffer-to-image copy operation.
*/
struct NioBufferSrcInfo {
    NioBuffer buffer;
    ulong offset = 0;
    ulong length;
    ulong bytesPerRow;
    NioExtent3D size = NioExtent3D(0, 0, 0);
}

/**
    Descriptor for a image-to-buffer copy operation.
*/
struct NioBufferDstInfo {
    NioBuffer buffer;
    ulong offset = 0;
    ulong bytesPerRow;
}

/**
    Descriptor for a texture copy operation.
*/
struct NioTextureSrcInfo {
    NioTexture texture;
    uint slice = 0;
    uint level = 0;
    NioOrigin3D origin = NioOrigin3D(0, 0, 0);
    NioExtent3D size;
}

/**
    Descriptor for a texture copy operation.
*/
struct NioTextureDstInfo {
    NioTexture texture;
    uint slice = 0;
    uint level = 0;
    NioOrigin3D origin = NioOrigin3D(0, 0, 0);
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
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence = The fence to wait for.
    */
    abstract void waitForFence(NioFence fence);

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence = The fence to signal.
    */
    abstract void signalFence(NioFence fence);

    /**
        Fills the given buffer with the given value.

        Params:
            dst =       The desination buffer.
            value =     The value to write to the buffer.
    */
    abstract void fillBuffer(NioBuffer dst, uint value);

    /**
        Fills the given buffer with the given value.

        Notes:
            The region defined will be clamped to the memory
            region of the buffer.

        Params:
            dst =       The desination buffer.
            offset =    The offset to start filling at, in bytes.
            length =    The length of the region to fill, in bytes.
            value =     The value to write to the buffer.
    */
    abstract void fillBuffer(NioBuffer dst, ulong offset, ulong length, uint value);

    /**
        Copies data from one buffer to another.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination buffer descriptor.
    */
    abstract void copy(NioBufferSrcInfo src, NioBufferDstInfo dst);

    /**
        Copies the data from a buffer to a texture.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination texture descriptor.
    */
    abstract void copy(NioBufferSrcInfo src, NioTextureDstInfo dst);

    /**
        Copies the data from a texture to a buffer.

        Params:
            src =       The source texture descriptor.
            dst =       The destination buffer descriptor.
    */
    abstract void copy(NioTextureSrcInfo src, NioBufferDstInfo dst);

    /**
        Copies the contents of the source texture
        into the destination texture.

        Params:
            src =       The source texture descriptor.
            dst =       The destination texture descriptor.
    */
    abstract void copy(NioTextureSrcInfo src, NioTextureDstInfo dst);

    /**
        Copies the contents of the source texture
        into the destination texture.

        Note:
            The smallest intersection between the 2 textures
            will be written to.

        Params:
            src = The source texture descriptor.
            dst = The desination descriptor.
    */
    abstract void copy(NioTexture src, NioTexture dst);
}