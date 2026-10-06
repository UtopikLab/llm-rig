# Driver + CUDA (Node 1 Inference)

- `install-cuda.sh` — NVIDIA **620.32.03** driver + **CUDA 13.0.2** (Ubuntu 26.04 LTS).

Run this **first** on `pf-host` — the driver and CUDA versions must match (the
package pins them together), so do not mix a different CUDA version with this
driver.

See [`../README.md`](../README.md) for the full run order.

When passing through a GPU (such as an NVIDIA Tesla P40) to a virtual machine in ESXi 8.x, standard default configurations often result in power-on errors (like `DevicePowerOn failed`) or driver error codes in the guest OS because of memory mapping and interrupt handling limitations.

To ensure the virtual machine boots successfully and the GPU initializes correctly without crashing or throwing errors, add or modify the following configuration parameters under the VM's **Edit Settings > VM Options > Advanced > Configuration Parameters**:

---

### Recommended Configuration Parameters

| Parameter Key | Recommended Value | Why It Is Needed |
| --- | --- | --- |
| **`pciPassthru.use64bitMMIO`** | `TRUE` | Forces ESXi to map the PCI device memory above the 4GB boundary, which is necessary for high-memory GPUs. |
| **`pciPassthru.64bitMMIOSizeGB`** | `64` *(or `32` / `128`)* | Allocates sufficient address space size for the card's memory bars. For a 24GB VRAM card like the Tesla P40, setting this to **`64`** gives enough room for both the frame buffer and memory-mapped I/O spaces. |
| **`pciPassthru0.msiEnabled`** | `FALSE` | Disables Message Signaled Interrupts (MSI) for the passed-through device. NVIDIA enterprise and data-center drivers on ESXi often experience interrupt loss, timeouts, or bugchecks if MSI is left enabled. *(Note: If you passed through multiple PCI devices or GPUs, you may need incrementing indices like `pciPassthru1.msiEnabled`)*. |
| **`hypervisor.cpuid.v0`** | `FALSE` | Hides the hypervisor signature from the guest OS, which helps prevent consumer/enterprise NVIDIA drivers from throwing error codes (such as Code 43 on Windows or initialization blocks on Linux). |

---

### Additional Best Practices

* **Reserve All Guest Memory:** Go to **Edit Settings > Resources**, and check **Reserve all guest memory (All locked)**. GPU passthrough typically requires the VM's entire RAM allocation to be pinned in physical host memory to prevent swapping out mapped memory blocks.
* **Remove or Disable Virtual Graphics:** Ensure that `svga.present` is set to `FALSE` if you are running a headless compute/inference VM, or leave the default display adapter minimal so it doesn't conflict with the discrete GPU.