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

    // State
    bool isRecording_;

    // Handles
    VkCommandBuffer handle_;

    /**
        Resets this command buffer, allowing it to be reused.
    */
    void reset() {
        if (isRecording_)
            return;
        
        vkResetCommandBuffer(handle_, VK_COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT);
        if (drawable) {
            drawable.reset();
            drawable = null;
        }
    }

public:

    /**
        Whether the command buffer is currently in the
        recording state.
    */
    @property bool isRecording() => isRecording_; 

    /**
        Handle of the command buffer.
    */
    @property VkCommandBuffer handle() => handle_;

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
    }

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
            buffer = The vulkan command buffer
    */
    this(NioVkCommandQueue queue, VkCommandBuffer buffer) {
        super(queue.device, queue);
        this.handle_ = buffer;
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
            auto nvkDrawTexture = cast(NioVkDrawableTexture)nvkDrawable.texture;
            if (nvkDrawTexture.layout != VK_IMAGE_LAYOUT_PRESENT_SRC_KHR) {
                nvkDrawTexture.layout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
                auto imageBarrier = VkImageMemoryBarrier2(
                    srcStageMask: VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                    srcAccessMask: VK_ACCESS_2_MEMORY_WRITE_BIT,
                    dstStageMask: VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                    dstAccessMask: VK_ACCESS_2_MEMORY_WRITE_BIT | VK_ACCESS_2_MEMORY_READ_BIT,
                    oldLayout: nvkDrawTexture.layout,
                    newLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                    subresourceRange: VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS),
                    image: nvkDrawTexture.vkImage,
                );
                auto depInfo = VkDependencyInfo(
                    imageMemoryBarrierCount: 1,
                    pImageMemoryBarriers: &imageBarrier
                );
                vkCmdPipelineBarrier2(
                    handle_,
                    &depInfo
                );
            }

            // Add to queue.
            nvkDrawable.queue = this.queue;
            this.drawable = nvkDrawable;
        }
    }

    /**
        Awaits the completion of the command buffer
        execution.
    */
    override void await() {
        auto nvkDevice = cast(NioVkDevice)device;
        if (fence) {
            cast(void)vkWaitForFences(nvkDevice.vkDevice, 1, &fence, VK_TRUE, ulong.max);
        }
    }

    /**
        Begins recording into the command buffer.
    */
    NioVkCommandBuffer begin() {
        if (isRecording_)
            return this;
        
        this.reset();

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
}