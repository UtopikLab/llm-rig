## Step 1: In the Ubuntu Installer GUI

   1. Select the Dell BOSS drive (/dev/sda) as your main installation target.
   2. Choose Use an entire disk and check the box to Set up this disk as an LVM group.
   3. Leave /dev/sdb (SSD RAID5) and /dev/nvme0n1 (NVMe) completely unformatted and unselected.
   4. Finish the installation and reboot into your new Ubuntu OS.

------------------------------
## Step 2: Post-Installation Terminal Setup
Once you boot into the server, the installer will have locked down your system disk (vg_system), leaving the other two arrays clean and ready. Open your terminal and run these commands to set up the rest of your layout:
## 1. Configure the NVMe Drive (/dev/nvme0n1)
```
# Wipe any accidental partition metadata from the installer wizard
sudo wipefs -a /dev/nvme0n1
# Create the Volume Group and Logical Volumes
sudo pvcreate /dev/nvme0n1
sudo vgcreate vg_nvme_local /dev/nvme0n1

sudo lvcreate -L 500G -n lv_kubelet vg_nvme_local
sudo lvcreate -L 1.3T -n lv_local_fast vg_nvme_local
# Format the volumes
sudo mkfs.ext4 -L k8s_kubelet /dev/vg_nvme_local/lv_kubelet
sudo mkfs.ext4 -L k8s_local_fast /dev/vg_nvme_local/lv_local_fast
```
## 2. Configure the SSD RAID5 Array (/dev/sdb)
```
# Wipe any accidental partition metadata
sudo wipefs -a /dev/sda
# Create the Volume Group and Logical Volume using 100% of the remaining space
sudo pvcreate /dev/sda
sudo vgcreate vg_data_ssd /dev/sda

sudo lvcreate -l 100%FREE -n lv_storage_standard vg_data_ssd
sudo mkfs.xfs -L k8s_ssd_pool /dev/vg_data_ssd/lv_storage_standard
```
## 3. Create Mount Points and Update Filesystem Table
```
# Create target paths
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /mnt/k8s-local-nvme
sudo mkdir -p /mnt/k8s-data-ssd
# Append mounts to /etc/fstab safely
sudo tee -a /etc/fstab <<EOF
/dev/vg_nvme_local/lv_kubelet       /var/lib/kubelet       ext4    defaults,noatime    0 2
/dev/vg_nvme_local/lv_local_fast    /mnt/k8s-local-nvme    ext4    defaults,noatime    0 2
/dev/vg_data_ssd/lv_storage_standard /mnt/k8s-data-ssd     xfs     defaults,noatime    0 2
EOF
# Mount everything immediately
sudo mount -a
```
Verify your final layout by running lsblk. You will see vg_system handling your OS tasks on the BOSS card, while your two new volume groups map directly to Kubernetes storage destinations.

* sdb (238.4G) is your Dell BOSS drive handling the host OS (/) and boot files.
* sda (1.9T) is your 3x SSD RAID5 array, successfully mounted to /mnt/k8s-data-ssd.
* nvme0n1 (1.9T) is your high-speed NVMe, mapped cleanly to /var/lib/kubelet and /mnt/k8s-local-nvme.
* sdc (29.7G) is your Dell Dual SD card module, which is correctly left completely unassigned and unmounted.

## One Critical Optimization Before Installing Kubernetes
Your sdb3 partition has 235.4G of space, but the Ubuntu installer only allocated 100G to your root partition (ubuntu--vg-ubuntu--lv).
Because /var/lib/containerd (where Docker/Containerd stores all downloaded container images and logs) lives on your root volume, you should expand this logical volume right now to use the remaining 135.4G of free space on your BOSS card.
Run these two commands to maximize your root partition space:
```
# Extend the Logical Volume to use 100% of the remaining free space in the volume group
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
# Resize the ext4 filesystem online without rebooting
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```
Verify the change by running df -h /. Your root (/) directory should now reflect approximately 235G of usable space, ensuring your node won't suffer from premature disk pressure errors when downloading large image layers.
Are you planning to run a single-node cluster (such as K3s or MicroK8s) on this machine, or is this the first node of a multi-node bare-metal cluster? Your answer will determine which Storage Class provisioner we configure next.

