/**
    Niobium Vulkan Transfer Encoders.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.mtl.cmd.txrencoder;
import niobium.mtl.resource;
import niobium.mtl.sync;
import niobium.mtl.cmd;
import foundation;
import metal.blitcommandencoder;
import metal.commandencoder;
import metal.commandbuffer;
import metal.types;
import numem;

/**
    A short-lived object which encodes transfer commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
class NioMTLTransferCommandEncoder : NioTransferCommandEncoder {
public:
@nogc:

    /// Destructor
    ~this() {
        handle.release();
    }

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        super(buffer);
        this.handle = mtlcmdbuffer.blitCommandEncoder();
    }

    /// Command Encoder Functions
    mixin MTLCommandEncoderFunctions!MTLBlitCommandEncoder;

    /**
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence = The fence to wait for.
    */
    override void waitForFence(NioFence fence) {
        handle.waitForFence((cast(NioMTLFence)fence).handle);
    }

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence = The fence to signal.
    */
    override void signalFence(NioFence fence) {
        handle.updateFence((cast(NioMTLFence)fence).handle);
    }

    /**
        Generates mipmaps for the destination texture,
        given that it's a color texture with mipmaps allocated.
    */
    override void generateMipmapsFor(NioTexture dst) {
        handle.generateMipmapsForTexture((cast(NioMTLTexture)dst).handle);
    }

    /**
        Fills the given buffer with the given value.

        Notes:
            The region defined will be clamped to the memory
            region of the buffer.

        Params:
            dst =       The desination buffer.
            value =     The value to write to the buffer.
    */
    override void fillBuffer(NioBuffer dst, uint value) {
        handle.fillBuffer((cast(NioMTLBuffer)dst).handle, NSRange(0, dst.size-(dst.size%4)), cast(ubyte)value);
    }

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
    override void fillBuffer(NioBuffer dst, ulong offset, ulong length, uint value) {
        handle.fillBuffer((cast(NioMTLBuffer)dst).handle, NSRange(offset, length-(length%4)), cast(ubyte)value);
    }

    /**
        Copies the data from a buffer to a texture.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination texture descriptor.
    */
    override void copy(NioBufferSrcInfo src, NioBufferDstInfo dst) {
        handle.copy(
            (cast(NioMTLBuffer)src.buffer).handle,
            src.offset,
            (cast(NioMTLBuffer)dst.buffer).handle,
            dst.offset,
            src.length
        );
    }

    /**
        Copies the data from a buffer to a texture.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination texture descriptor.
    */
    override void copy(NioBufferSrcInfo src, NioTextureDstInfo dst) {
        handle.copy(
            (cast(NioMTLBuffer)src.buffer).handle,
            src.offset,
            src.rowLength,
            0,
            MTLSize(src.extent.width, src.extent.height, src.extent.depth),
            (cast(NioMTLTexture)dst.texture).handle,
            dst.slice,
            dst.level,
            MTLOrigin(dst.origin.x, dst.origin.y, dst.origin.z)
        );
    }

    /**
        Copies the data from a texture to a buffer.

        Params:
            src =       The source texture descriptor.
            dst =       The destination buffer descriptor.
    */
    override void copy(NioTextureSrcInfo src, NioBufferDstInfo dst) {
        handle.copy(
            (cast(NioMTLTexture)src.texture).handle,
            src.slice,
            src.level,
            MTLOrigin(src.origin.x, src.origin.y, src.origin.z),
            MTLSize(src.extent.width, src.extent.height, src.extent.depth),
            (cast(NioMTLBuffer)dst.buffer).handle,
            dst.offset,
            dst.rowLength,
            0
        );
    }

    /**
        Copies the contents of the source texture
        into the destination texture.

        Params:
            src =       The source texture descriptor.
            dst =       The destination texture descriptor.
    */
    override void copy(NioTextureSrcInfo src, NioTextureDstInfo dst) {
        handle.copy(
            (cast(NioMTLTexture)src.texture).handle,
            src.slice,
            src.level,
            MTLOrigin(src.origin.x, src.origin.y, src.origin.z),
            MTLSize(src.extent.width, src.extent.height, src.extent.depth),
            (cast(NioMTLTexture)dst.texture).handle,
            dst.slice,
            dst.level,
            MTLOrigin(dst.origin.x, dst.origin.y, dst.origin.z)
        );
    }

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
    override void copy(NioTexture src, NioTexture dst) {
        handle.copy(
            (cast(NioMTLTexture)src).handle,
            (cast(NioMTLTexture)dst).handle
        );
    }
}