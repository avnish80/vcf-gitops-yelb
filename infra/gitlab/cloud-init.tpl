#cloud-config
# Template only. Replace the two placeholders, then create the Secret by hand.
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
runcmd:
  - curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
  - EXTERNAL_URL="http://gitlab.vks.example.com" GITLAB_ROOT_PASSWORD="__GITLAB_ROOT_PASSWORD__" apt-get install -y gitlab-ce
