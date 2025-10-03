/**
    Niobium Vulkan Fences
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.sync.fence;
import niobium.vk.device;
import vulkan.core;
import vulkan.eh;
import numem;

public import niobium.sync : NioFence;

/**
    A GPU-local memory fence for tracking resource dependencies.
*/
class NioVkFence : NioFence {
private:
@nogc:
    // Handles
    VkEvent handle_;

    void setup() {
        auto nvkDevice = cast(NioVkDevice)device;
        auto createInfo = VkEventCreateInfo();
        vkCreateEvent(nvkDevice.vkDevice, &createInfo, null, &handle_);
    }

protected:

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override
    void onLabelChanged(string label) {
        auto vkDevice = (cast(NioVkDevice)device).vkDevice;

        import niobium.vk.device : setDebugName;
        vkDevice.setDebugName(VK_OBJECT_TYPE_EVENT, handle_, label);
    }

public:

    /**
        The native vulkan handle.
    */
    @property VkEvent handle() => handle_;

    /// Destructor
    ~this() {
        auto nvkDevice = cast(NioVkDevice)device;
        vkDestroyEvent(nvkDevice.vkDevice, handle_, null);
    }

    /**
        Creates a new $(D NioVkFence)
    */
    this(NioDevice device) {
        super(device);
        this.setup();
    }
}