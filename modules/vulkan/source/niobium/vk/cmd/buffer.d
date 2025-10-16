/**
    Niobium Command Buffers.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.cmd.buffer;
import niobium.vk.cmd.queue;
import niobium.vk.resource;
import niobium.vk.surface;
import niobium.vk.device;
import niobium.cmd;
import niobium.queue;
import niobium.device;
import niobium.surface;
import vulkan.loader;
import vulkan.core;
import vulkan.eh;
import numem;
import nulib;
import nulib.threading.mutex;

public import niobium.cmd;
public import niobium.vk.cmd.txrencoder;
public import niobium.vk.cmd.renderencoder;

/**
    A buffer of commands which can be sent to the GPU
    for processing.

    Note:
        Unless a buffer is created to be persistent,
        submitting a command buffer will free it.
*/
class NioVkCommandBuffer : NioCommandBuffer {
private:
@nogc:
    __gshared float[4] __invisibleColor;

    // State
    bool isRecording_;
    Mutex encoderMutex_;

    // Handles
    VkDescriptorPool descriptorPool_;
    VkCommandBuffer handle_;

    VkDescriptorPool createPool() {
        auto nvkDevice = (cast(NioVkDevice)device);

        VkDescriptorPool pool;
        static const VkDescriptorPoolSize[] sizes = [
            VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, 8),
            VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_SAMPLER, 8),
            VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE, 8),
            VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 8),
        ];

        auto descPoolCreateInfo = VkDescriptorPoolCreateInfo(
            flags: VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT,
            maxSets: 8,
            poolSizeCount: cast(uint)sizes.length,
            pPoolSizes: sizes.ptr
        );

        vkCreateDescriptorPool(nvkDevice.handle, &descPoolCreateInfo, null, &pool);
        vkResetDescriptorPool(nvkDevice.handle, pool, 0);
        return pool;
    }

protected:

    /**
        Called by command encoders when encoding ends.
    */
    override
    void onEncodingEnd() {
        handle_.popDebugGroup();
    }

public:

    /**
        Whether the command buffer is still recording.
    */
    override @property bool isRecording() => isRecording_;

    /**
        Handle of the command buffer.
    */
    @property VkCommandBuffer handle() => handle_;

    /**
        Handle of the descriptor pool.
    */
    final @property VkDescriptorPool descriptorPool() => descriptorPool_;

    /**
        Completion fence.
    */
    VkFence fence;

    /**
        Completion semaphore.
    */
    VkSemaphore semaphore;

    /**
        Drawable to present after rendering the
        command buffer.
    */
    NioVkDrawable drawable;

    ~this() {
        auto vkDevice = (cast(NioVkDevice)queue.device).handle;
        vkDestroyDescriptorPool(vkDevice, descriptorPool_, null);

        nogc_delete(encoderMutex_);
    }

    /**
        Constructs a new command buffer.

        Params:
            queue =     The queue that "owns" this command buffer.
            buffer =    The vulkan command buffer
    */
    this(NioVkCommandQueue queue, VkCommandBuffer buffer) {
        super(queue);
        this.handle_ = buffer;
        this.encoderMutex_ = nogc_new!Mutex();
        this.descriptorPool_ = this.createPool();
    }

    /**
        Begins a new render pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Params:
            desc = Descriptor used to start the render pass

        Returns:
            A short lived $(D NioRenderCommandEncoder) on success,
            $(D null) on failure.
    */
    override NioRenderCommandEncoder beginRenderPass(NioRenderPassDescriptor desc) {
        encoderMutex_.lock();
        if (this.activeEncoder)
            return null;
        
        handle_.pushDebugGroup("Render Pass", __invisibleColor);
        this.activeEncoder = nogc_new!NioVkRenderCommandEncoder(this, desc);
        encoderMutex_.unlock();
        
        return cast(NioRenderCommandEncoder)activeEncoder;
    }

    /**
        Begins a new transfer pass.

        Note:
            Only one pass can be active at a time,
            attempting to create new passes will fail.
        
        Returns:
            A short lived $(D NioTransferCommandEncoder) on success,
            $(D null) on failure.
    */
    override NioTransferCommandEncoder beginTransferPass() {
        encoderMutex_.lock();
        if (this.activeEncoder)
            return null;
        
        handle_.pushDebugGroup("Transfer Pass", __invisibleColor);
        this.activeEncoder = nogc_new!NioVkTransferCommandEncoder(this);
        encoderMutex_.unlock();

        return cast(NioTransferCommandEncoder)activeEncoder;
    }

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        Params:
            drawable = The drawable to present.
    */
    override void present(NioDrawable drawable) {
        if (!isRecording_)
            return;
        
        if (this.drawable)
            return;

        if (auto nvkDrawable = cast(NioVkDrawable)drawable) {
            if (nvkDrawable.queue !is null)
                return;

            // Transition texture to presentable layout.
            auto nvkDrawTexture = cast(NioVkTexture)nvkDrawable.texture;
            if (nvkDrawTexture.layout != VK_IMAGE_LAYOUT_PRESENT_SRC_KHR) {
                auto imageBarrier = VkImageMemoryBarrier2(
                    srcStageMask: VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                    srcAccessMask: VK_ACCESS_2_MEMORY_WRITE_BIT,
                    dstStageMask: VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                    dstAccessMask: VK_ACCESS_2_MEMORY_WRITE_BIT | VK_ACCESS_2_MEMORY_READ_BIT,
                    oldLayout: nvkDrawTexture.layout,
                    newLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                    subresourceRange: VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS),
                    image: cast(VkImage)nvkDrawTexture.handle,
                );
                auto depInfo = VkDependencyInfo(
                    imageMemoryBarrierCount: 1,
                    pImageMemoryBarriers: &imageBarrier
                );
                vkCmdPipelineBarrier2(
                    handle_,
                    &depInfo
                );

                // Layout has been transitioned now.
                nvkDrawTexture.layout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
            }

            // Add to queue.
            nvkDrawable.queue = this.queue;
            this.drawable = nvkDrawable.retained();
        }
    }

    /**
        Awaits the completion of the command buffer
        execution.
    */
    override void await() {
        auto nvkDevice = cast(NioVkDevice)device;
        cast(void)vkWaitForFences(nvkDevice.handle, 1, &fence, VK_FALSE, ulong.max);
    }

    /**
        Begins recording into the command buffer.
    */
    NioVkCommandBuffer begin() {
        if (isRecording_)
            return this;

        auto beginInfo = VkCommandBufferBeginInfo();
        vkBeginCommandBuffer(handle_, &beginInfo);
        this.isRecording_ = true;
        return this;
    }

    /**
        Ends recording the command buffer, making
        it immutable.
    */
    void end() {
        if (!isRecording_)
            return;
        
        vkEndCommandBuffer(handle_);
        this.isRecording_ = false;
    }

    /**
        Resets this command buffer, allowing it to be reused.
    */
    void reset() {
        auto vkDevice = (cast(NioVkDevice)queue.device).handle;
        
        vkResetCommandBuffer(handle_, VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT);
        vkResetDescriptorPool(vkDevice, descriptorPool_, 0);
        vkResetFences(vkDevice, 1, &fence);
        if (drawable) {
            drawable.release();
            drawable = null;
        }
    }
}

/*
    Mixin template inserted into the different command encoders
    to make them conform to the NioCommandEncoder class interface.
*/
mixin template VkCommandEncoderFunctions() {
    import niobium.vk.device : pushDebugGroup, popDebugGroup;

    /**
        Helper which transitions textures into the requested layout.
    */
    protected
    final void transitionTextureTo(NioVkTexture texture, VkImageLayout layout) {
        if (texture.layout != layout) {
            auto imageBarrier = VkImageMemoryBarrier2(
                srcStageMask: VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                srcAccessMask: VK_ACCESS_2_MEMORY_WRITE_BIT,
                dstStageMask: VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                dstAccessMask: VK_ACCESS_2_MEMORY_WRITE_BIT | VK_ACCESS_2_MEMORY_READ_BIT,
                oldLayout: texture.layout,
                newLayout: layout,
                subresourceRange: VkImageSubresourceRange(texture.format.toVkAspect, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS),
                image: cast(VkImage)texture.handle,
            );
            auto depInfo = VkDependencyInfo(
                imageMemoryBarrierCount: 1,
                pImageMemoryBarriers: &imageBarrier
            );
            vkCmdPipelineBarrier2(
                vkcmdbuffer,
                &depInfo
            );
            texture.layout = layout;
        }
    }

    /**
        Command buffer.
    */
    protected @property NioVkCommandBuffer cmdbuffer() => (cast(NioVkCommandBuffer)commandBuffer);

    /**
        Vulkan command buffer.
    */
    protected @property VkCommandBuffer vkcmdbuffer() => (cast(NioVkCommandBuffer)commandBuffer).handle;

    /**
        Vulkan descriptor pool.
    */
    protected @property VkDescriptorPool vkdescpool() => (cast(NioVkCommandBuffer)commandBuffer).descriptorPool;

    /**
        Pushes a debug group.

        Params:
            name = The name of the debug group
            color = The color of the debug group (optional)
    */
    override void pushDebugGroup(string name, float[4] color) {
        vkcmdbuffer.pushDebugGroup(name, color);
    }

    /**
        Pops the top debug group from the debug
        group stack.
    */
    override void popDebugGroup() {
        vkcmdbuffer.popDebugGroup();
    }

    /**
        Ends the encoding pass, allowing a new pass to be
        begun from the parent command buffer.
    */
    override void endEncoding() {
        this.finishEncoding();
    }

    /**
        Inserts a barrier that ensures that subsequent commands 
        of type $(D afterStages) submitted to the command queue does 
        not proceed until the work in $(D beforeStages) completes.

        Params:
            afterStages =   A mask that defines the stages of work to wait for.
            beforeStages =  A mask that defines the work that must wait.
    */
    override void insertBarrier(NioPipelineStage afterStages, NioPipelineStage beforeStages) {
        import niobium.vk.sync : toVkPipelineStageFlags2;
        
        auto barrierInfo = VkMemoryBarrier2(
            srcStageMask: afterStages.toVkPipelineStageFlags2(),
            srcAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT,
            dstStageMask: beforeStages.toVkPipelineStageFlags2(),
            dstAccessMask: VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT
        );
        auto depInfo = VkDependencyInfo(
            memoryBarrierCount: 1,
            pMemoryBarriers: &barrierInfo
        );
        vkCmdPipelineBarrier2(vkcmdbuffer, &depInfo);
    }
}