#cloud-config
write_files:
  - path: "/var/tmp/install-vault.sh"
    permissions: "0755"
    owner: "root:root"
    content: |
      #!/bin/bash -eux
      export DC=${dc}
      export IFACE=${iface}
      curl -sLo /tmp/vault.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/vault-dev-inmem/vault.sh
      bash /tmp/vault.sh
  - path: "/etc/vault_license.json"
    permissions: "0755"
    owner: "root:root"
    content: |
      {
        "text": "${license}"
      }
  - path: "/etc/systemd/system/vault-license.service"
    permissions: "0755"
    owner: "root:root"
    content: |
      [Unit]
      Description=License Vault
      After=vault.service

      [Service]
      ExecStart=/usr/bin/curl --header "X-Vault-Token: changeme" --request PUT --data @/etc/vault_license.json http://127.0.0.1:8200/v1/sys/license
      Type=oneshot
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
runcmd:
  - systemctl restart systemd-resolved.service
  - bash /var/tmp/install-vault.sh
  - bash sleep 10
  - systemctl enable vault-license.service
  - systemctl start vault-license.service
  - touch /tmp/file
