/**
    Niobium Vulkan Semaphores
    
    Copyright:
        Copyright © 2025, Kitsunebi Games
        Copyright © 2025, Inochi2D Project
    
    License:    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Authors:
        Luna Nielsen
*/
module niobium.vk.sync.semaphore;
import niobium.vk.device;
import vulkan.core;
import vulkan.eh;
import numem;

public import niobium.sync : NioSemaphore;

/**
    A GPU-local memory fence for tracking resource dependencies.
*/
class NioVkSemaphore : NioSemaphore {
private:
@nogc:
    // Handles
    VkSemaphore handle_;

    void setup() {
        auto nvkDevice = cast(NioVkDevice)device;
        auto semaphoreInfo = VkSemaphoreTypeCreateInfo(
            semaphoreType: VK_SEMAPHORE_TYPE_TIMELINE,
            initialValue: 0
        );
        auto createInfo = VkSemaphoreCreateInfo(
            pNext: &semaphoreInfo
        );
        vkCreateSemaphore(nvkDevice.handle, &createInfo, null, &handle_);
    }

    pragma(inline, true)
    ulong getValue() {
        auto nvkDevice = cast(NioVkDevice)device;
        ulong v;

        vkGetSemaphoreCounterValue(nvkDevice.handle, handle_, &v);
        return v;
    }

protected:

    /**
        Called when the label has been changed.

        Params:
            label = The new label of the device.
    */
    override
    void onLabelChanged(string label) {
        auto vkDevice = (cast(NioVkDevice)device).handle;

        import niobium.vk.device : setDebugName;
        vkDevice.setDebugName(VK_OBJECT_TYPE_SEMAPHORE, handle_, label);
    }

public:

    /**
        The current value of the semaphore.
    */
    override @property ulong value() => this.getValue();

    /**
        The native vulkan handle.
    */
    @property VkSemaphore handle() => handle_;

    /// Destructor
    ~this() {
        auto nvkDevice = cast(NioVkDevice)device;
        vkDestroySemaphore(nvkDevice.handle, handle_, null);
    }

    /**
        Creates a new $(D NioVkFence)
    */
    this(NioDevice device) {
        super(device);
        this.setup();
    }

    /**
        Signals the semaphore with the given value.

        Params:
            value = The value to signal with, must be greater 
                    than the current value.
        
        Returns:
            $(D true) if the operation succeeded,
            $(D false) otherwise.
    */
    override bool signal(ulong value) {
        auto nvkDevice = cast(NioVkDevice)device;
        auto signalInfo = VkSemaphoreSignalInfo(
            semaphore: handle_,
            value: value
        );
        return vkSignalSemaphore(nvkDevice.handle, &signalInfo) == VK_SUCCESS;
    }

    /**
        Awaits the semaphore getting signalled.

        Params:
            value =     The value to wait for
            timeout =   The timeout for the wait in miliseconds.
        
        Returns:
            $(D true) if the semaphore reached the given value,
            $(D false) otherwise (eg. it timed out.)
    */
    override
    bool await(ulong value, ulong timeout) {
        auto nvkDevice = cast(NioVkDevice)device;
        auto waitInfo = VkSemaphoreWaitInfo(
            semaphoreCount: 1,
            pSemaphores: &handle_,
            pValues: &value
        );
        return vkWaitSemaphores(nvkDevice.handle, &waitInfo, timeout) == VK_SUCCESS;
    }
}