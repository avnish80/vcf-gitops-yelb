#cloud-config
# Template only. Replace the two placeholders, then create the Secret by hand (see README step).
# Argo CD ignores this file because it is not .yaml.
hostname: gitlab
users:
  - default
chpasswd:
  expire: false
  users:
    - name: ubuntu
      password: __VM_PASSWORD__
      type: text
package_update: true
packages:
  - curl
  - ca-certificates
  - tzdata
  - openssh-server
  - perl
write_files:
  - path: /usr/local/sbin/mount-gitlab-data.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Find the empty second disk (the gitlab-data PVC), format it once, mount it at /var/opt/gitlab.
      set -euo pipefail
      MNT=/var/opt/gitlab
      mkdir -p "$MNT"
      if ! blkid -L gitlab-data >/dev/null 2>&1; then
        DISK=""
        for i in $(seq 1 60); do
          for d in $(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}'); do
            # skip any disk that already has partitions, a filesystem or a mount (the OS disk)
            if [ -z "$(lsblk -no FSTYPE,MOUNTPOINT "$d" | tr -d ' \n')" ] && [ "$(lsblk -no NAME "$d" | wc -l)" -eq 1 ]; then
              DISK="$d"; break
            fi
          done
          [ -n "$DISK" ] && break
          sleep 5
        done
        [ -n "$DISK" ] || { echo "gitlab-data disk not found" >&2; exit 1; }
        mkfs.ext4 -F -L gitlab-data "$DISK"
      fi
      grep -q 'LABEL=gitlab-data' /etc/fstab || echo 'LABEL=gitlab-data /var/opt/gitlab ext4 defaults,nofail 0 2' >> /etc/fstab
      mountpoint -q "$MNT" || mount "$MNT"
runcmd:
  - /usr/local/sbin/mount-gitlab-data.sh
  - curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
  - EXTERNAL_URL="http://gitlab.vks.example.com" GITLAB_ROOT_PASSWORD="__GITLAB_ROOT_PASSWORD__" apt-get install -y gitlab-ce
  - apt-get clean
