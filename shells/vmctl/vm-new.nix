{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "vm-new";
  runtimeInputs = with pkgs; [ openssh ssh-to-age ];
  text = ''
     set +o nounset
     set +o errexit
     if [ -z "$1" ]; then
         echo "Please provide the hostname you want to build."
         exit 1
     fi

     id=$(eval "nix eval .#nixosConfigurations.$1.config.vm.id" 2>&1)
     # shellcheck disable=SC2181
     if [ $? -ne 0 ]; then
         echo "The specified hostname could not be found."
         exit 1
     fi 

    echo "Found VM with ID $id, building..."
    nix build ".#nixosConfigurations.$1.config.formats.proxmox"

    echo "Copying result to proxmox image store..."
    cp "result" "/media/Backup/proxmox_images/template/iso/vzdump-qemu-$id-2024_06_01-10_00_00.vma.zst"

    echo "Importing VM $id..."
    # shellcheck disable=SC2029
    ssh proxmox "qmrestore /mnt/pve/proxmox_images/template/iso/vzdump-qemu-$id-2024_06_01-10_00_00.vma.zst $id --unique true"

    echo "Cleaning up..."
    # rm -f "/media/Backup/proxmox_images/template/iso/vzdump-qemu-$id-2024_06_01-10_00_00.vma.zst"
    rm "result"

    echo "Done!"
  '';
}
