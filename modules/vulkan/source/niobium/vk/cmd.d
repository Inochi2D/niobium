/**
    Niobium Command Buffers.
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.cmd;
import niobium.vk.surface;
import niobium.vk.queue;
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
    VkCommandBuffer handle_;

    // State
    bool isRecording = true;

    void setup(NioVkCommandQueue queue) {
        this.queue_ = queue;
        this.handle_ = queue_.allocateCmdBuffer(VK_COMMAND_BUFFER_LEVEL_PRIMARY);

        auto beginInfo = VkCommandBufferBeginInfo();
        vkBeginCommandBuffer(handle_, &beginInfo);
    }

public:

    /**
        Handle of the command buffer.
    */
    @property VkCommandBuffer handle() => handle_;

    /**
        Vector of drawables to present.
    */
    weak_vector!NioVkDrawable toPresent;

    /**
        Completion fence, filled out during enqueue.
    */
    VkFence completionFence;

    /**
        Completion semaphore, filled out during enqueue.
    */
    VkSemaphore completionSemaphore;

    ~this() {
        toPresent.clear();
    }

    /**
        Constructs a new command buffer.

        Params:
            device = The device that "owns" this command buffer.
    */
    this(NioDevice device, NioVkCommandQueue queue) {
        super(device, queue);
        this.setup(queue);
    }

    /**
        Enqueues a presentation to happen after this
        command buffer finishes execution.

        Params:
            drawable = The drawable to present.
    */
    override void present(NioDrawable drawable) {
        if (!isRecording)
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
            nvkDrawable.queue = this.queue_;
            this.toPresent ~= nvkDrawable;
        }
    }

    /**
        Submits the command buffer to its queue.

        After submitting a command buffer you cannot
        modify it any further, nor submit it again.
    */
    override void submit() {
        if (!isRecording)
            return;
        this.end();
        queue.submit(this);
    }

    /**
        Awaits the completion of the command buffer
        execution.
    */
    override void await() {
        if (completionFence) {
            cast(void)vkWaitForFences(nvkDevice.vkDevice, 1, &completionFence, VK_TRUE, uint.max);
        }
    }

    /**
        Ends recording the command buffer, making
        it immutable.
    */
    void end() {
        if (isRecording) {
            this.isRecording = false;
            vkEndCommandBuffer(handle_);
        }
    }
}