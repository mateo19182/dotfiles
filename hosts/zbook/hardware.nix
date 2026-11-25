# HP ZBook Ultra G1a 14" (AMD Strix Halo). Kernel 7.2+ has the ISP4 webcam driver.
{ inputs, lib, pkgs, ... }:
{
  imports = with inputs.nixos-hardware.nixosModules; [
    common-cpu-amd
    common-cpu-amd-pstate
    common-gpu-amd
    common-pc-laptop-ssd
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "uas"
      "sd_mod"
      "usbhid"
    ];
    initrd.kernelModules = [ "amdgpu" ];
    kernelModules = [ "kvm-amd" ];
    # Same as the current Arch install: wake from s2idle via the ACPI RTC alarm.
    kernelParams = [ "rtc_cmos.use_acpi_alarm=1" ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    amdgpu.initrd.enable = true;
    # ddcutil: external monitor brightness over DDC/CI.
    i2c.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
