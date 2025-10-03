/**
    Niobium Vulkan Transfer Encoders.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.cmd.txrencoder;
import niobium.vk.cmd.buffer;
import niobium.vk.sync;
import niobium.vk.resource;
import niobium.cmd;
import vulkan.core;
import vulkan.eh;
import nulib.math : min, max;
import numem;

/**
    A short-lived object which encodes transfer commands 
    into a $(D NioCommandBuffer).
    Only one $(D NioCommandEncoder) can be active at a time 
    for a $(D NioCommandBuffer).

    To end encoding call $(D endEncoding).
*/
class NioVkTransferCommandEncoder : NioTransferCommandEncoder {
public:
@nogc:

    /**
        Constructs a new command encoder.
    */
    this(NioCommandBuffer buffer) {
        super(buffer);
    }

    /// Command Encoder Functions
    mixin VkCommandEncoderFunctions;

    /**
        Encodes a command which instructs the GPU
        to wait for the fence to be signalled before
        proceeding.

        Params:
            fence = The fence to wait for.
    */
    override void waitForFence(NioFence fence) {
        auto vkevent = (cast(NioVkFence)fence).handle;
        auto barrierInfo = VkMemoryBarrier2(
            srcStageMask: VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
            dstStageMask: VK_PIPELINE_STAGE_2_TRANSFER_BIT,
            dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
        );
        auto depInfo = VkDependencyInfo(
            memoryBarrierCount: 1,
            pMemoryBarriers: &barrierInfo
        );
        vkCmdWaitEvents2(
            vkcmdbuffer, 
            1, &vkevent,
            &depInfo
        );
    }

    /**
        Encodes a command which instructs the GPU
        to signal the fence.

        Params:
            fence = The fence to signal.
    */
    override void signalFence(NioFence fence) {
        auto vkevent = (cast(NioVkFence)fence).handle;
        auto barrierInfo = VkMemoryBarrier2(
            srcStageMask: VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT,
            dstStageMask: VK_PIPELINE_STAGE_2_TRANSFER_BIT,
            dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
        );
        auto depInfo = VkDependencyInfo(
            memoryBarrierCount: 1,
            pMemoryBarriers: &barrierInfo
        );
        vkCmdSetEvent2(
            vkcmdbuffer, 
            vkevent,
            &depInfo
        );
    }

    /**
        Generates mipmaps for the destination texture,
        given that it's a color texture with mipmaps allocated.
    */
    override void generateMipmapsFor(NioTexture dst) {
        if (dst.levels < 1)
            return;
        
        if (dst.format.toVkAspect() != VK_IMAGE_ASPECT_COLOR_BIT)
            return;
        
        auto nvkTexture = cast(NioVkTexture)dst;
        auto aspect = nvkTexture.format.toVkAspect;
        auto layers = dst.layers;
        this.transitionTextureTo(nvkTexture, VK_IMAGE_LAYOUT_GENERAL);

        VkOffset3D[2] srcOffsets = [VkOffset3D(0, 0, 0), VkOffset3D(dst.width, dst.height, dst.depth)];
        VkOffset3D[2] dstOffsets = [VkOffset3D(0, 0, 0), VkOffset3D(max(1, dst.width/2), max(1, dst.height/2), max(1, dst.depth/2))];
        VkImageBlit[] blits = nu_malloca!VkImageBlit(dst.levels-1);
        foreach(level, ref blit; blits) {
            blit = VkImageBlit(
                srcSubresource: VkImageSubresourceLayers(aspect, 0, 0, layers),
                srcOffsets: srcOffsets,
                dstSubresource: VkImageSubresourceLayers(aspect, cast(uint)level+1, 0, layers),
                dstOffsets: dstOffsets,
            );
            dstOffsets[1].x = max(1, dstOffsets[1].x/2);
            dstOffsets[1].y = max(1, dstOffsets[1].y/2);
            dstOffsets[1].z = max(1, dstOffsets[1].z/2);
        }

        vkCmdBlitImage(
            vkcmdbuffer, 
            nvkTexture.handle, VK_IMAGE_LAYOUT_GENERAL, 
            nvkTexture.handle, VK_IMAGE_LAYOUT_GENERAL,
            cast(uint)blits.length,
            blits.ptr,
            VK_FILTER_LINEAR
        );
        nu_freea(blits);
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
        auto vkBufferDst = (cast(NioVkBuffer)dst);
        vkCmdFillBuffer(vkcmdbuffer, vkBufferDst.handle, 0, VK_WHOLE_SIZE, value);
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
        auto vkBufferDst = (cast(NioVkBuffer)dst);
        ulong start = min(offset, vkBufferDst.size);
        ulong end = min(offset+length, vkBufferDst.size);
        ulong alignedEnd = end+(end%4);

        // Vulkan limits ¯\_(ツ)_/¯
        if (alignedEnd > vkBufferDst.size)
            end = alignedEnd <= vkBufferDst.size ? alignedEnd : VK_WHOLE_SIZE;

        vkCmdFillBuffer(vkcmdbuffer, vkBufferDst.handle, start, end-start, value);
    }

    /**
        Copies the data from a buffer to a texture.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination texture descriptor.
    */
    override void copy(NioBufferSrcInfo src, NioBufferDstInfo dst) {
        auto vkBufferSrc = (cast(NioVkBuffer)src.buffer);
        auto vkBufferDst = (cast(NioVkBuffer)dst.buffer);

        auto bufferInfo = VkBufferCopy2(
            srcOffset: src.offset,
            dstOffset: dst.offset,
            size: src.length
        );
        auto copyInfo = VkCopyBufferInfo2(
            srcBuffer: vkBufferSrc.handle,
            dstBuffer: vkBufferDst.handle,
            regionCount: 1, 
            pRegions: &bufferInfo
        );
        vkCmdCopyBuffer2(vkcmdbuffer, &copyInfo);
    }

    /**
        Copies the data from a buffer to a texture.

        Params:
            src =       The source buffer descriptor.
            dst =       The destination texture descriptor.
    */
    override void copy(NioBufferSrcInfo src, NioTextureDstInfo dst) {
        auto vkBufferSrc = (cast(NioVkBuffer)src.buffer);
        auto vkImageDst = (cast(NioVkTexture)dst.texture);

        this.transitionTextureTo(vkImageDst, VK_IMAGE_LAYOUT_GENERAL);

        auto bufferImageInfo = VkBufferImageCopy2(
            bufferOffset: src.offset,
            bufferRowLength: cast(uint)src.rowLength,
            imageSubresource: VkImageSubresourceLayers(vkImageDst.format.toVkAspect(), dst.level, dst.slice, 1),
            imageExtent: VkExtent3D(src.extent.width, src.extent.height, src.extent.depth)
        );
        auto copyInfo = VkCopyBufferToImageInfo2(
            srcBuffer: vkBufferSrc.handle,
            dstImage: vkImageDst.handle,
            dstImageLayout: vkImageDst.layout,
            regionCount: 1,
            pRegions: &bufferImageInfo
        );
        vkCmdCopyBufferToImage2(vkcmdbuffer, &copyInfo);
    }

    /**
        Copies the data from a texture to a buffer.

        Params:
            src =       The source texture descriptor.
            dst =       The destination buffer descriptor.
    */
    override void copy(NioTextureSrcInfo src, NioBufferDstInfo dst) {
        auto vkImageSrc = (cast(NioVkTexture)src.texture);
        auto vkBufferDst = (cast(NioVkBuffer)dst.buffer);

        auto bufferImageInfo = VkBufferImageCopy2(
            bufferOffset: dst.offset,
            bufferRowLength: cast(uint)dst.rowLength,
            imageSubresource: VkImageSubresourceLayers(vkImageSrc.format.toVkAspect(), src.level, src.slice, 1),
            imageExtent: VkExtent3D(src.extent.width, src.extent.height, src.extent.depth)
        );
        auto copyInfo = VkCopyImageToBufferInfo2(
            srcImage: vkImageSrc.handle,
            srcImageLayout: vkImageSrc.layout,
            dstBuffer: vkBufferDst.handle,
            regionCount: 1,
            pRegions: &bufferImageInfo
        );
        vkCmdCopyImageToBuffer2(vkcmdbuffer, &copyInfo);
    }

    /**
        Copies the contents of the source texture
        into the destination texture.

        Params:
            src =       The source texture descriptor.
            dst =       The destination texture descriptor.
    */
    override void copy(NioTextureSrcInfo src, NioTextureDstInfo dst) {
        auto vkImageSrc = (cast(NioVkTexture)src.texture);
        auto vkImageDst = (cast(NioVkTexture)dst.texture);

        auto imageInfo = VkImageCopy2(
            srcSubresource: VkImageSubresourceLayers(vkImageSrc.format.toVkAspect(), src.level, src.slice, 1),
            srcOffset: VkOffset3D(src.origin.x, src.origin.y, src.origin.z),
            dstSubresource: VkImageSubresourceLayers(vkImageDst.format.toVkAspect(), dst.level, dst.slice, 1),
            dstOffset: VkOffset3D(dst.origin.x, dst.origin.y, dst.origin.z),
            extent: VkExtent3D(src.extent.width, src.extent.height, src.extent.depth)
        );
        auto copyInfo = VkCopyImageInfo2(
            srcImage: vkImageSrc.handle, 
            srcImageLayout: vkImageSrc.layout, 
            dstImage: vkImageDst.handle,
            dstImageLayout: vkImageDst.layout, 
            regionCount: 1, 
            pRegions: &imageInfo
        );
        vkCmdCopyImage2(vkcmdbuffer, &copyInfo);
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
        auto vkImageSrc = (cast(NioVkTexture)src);
        auto vkImageDst = (cast(NioVkTexture)dst);
        auto layersToCopy = min(vkImageSrc.layers, vkImageDst.layers);
        auto extentToCopy = VkExtent3D(
            min(vkImageSrc.width, vkImageDst.width),
            min(vkImageSrc.height, vkImageDst.height),
            min(vkImageSrc.depth, vkImageDst.depth),
        );

        auto imageInfo = VkImageCopy2(
            srcSubresource: VkImageSubresourceLayers(vkImageSrc.format.toVkAspect(), 0, 0, layersToCopy),
            srcOffset: VkOffset3D(0, 0, 0),
            dstSubresource: VkImageSubresourceLayers(vkImageDst.format.toVkAspect(), 0, 0, layersToCopy),
            dstOffset: VkOffset3D(0, 0, 0),
            extent: extentToCopy
        );
        auto copyInfo = VkCopyImageInfo2(
            srcImage: vkImageSrc.handle, 
            srcImageLayout: vkImageSrc.layout, 
            dstImage: vkImageDst.handle,
            dstImageLayout: vkImageDst.layout, 
            regionCount: 1, 
            pRegions: &imageInfo
        );
        vkCmdCopyImage2(vkcmdbuffer, &copyInfo);
    }
}