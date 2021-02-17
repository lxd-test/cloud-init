#cloud-config
write_files:
  - path: "/etc/consul_license.hclic"
    permissions: "0755"
    owner: "root:root"
    content: |
      ${license}
  - path: "/var/tmp/install-consul.sh"
    permissions: "0755"
    owner: "root:root"
    content: |
      #!/bin/bash -eux
      export DC=${dc}
      export IFACE=${iface}
      export COUNT=${consul_count}
      export RETRY_JOIN='${consul_server}'
      export WAN_JOIN='${consul_wan_join}'
      curl -sLo /tmp/consul.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/consul-server/consul.sh
      bash /tmp/consul.sh
      sleep 5
      consul license put @/etc/consul_license.hclic
runcmd:
  - systemctl restart systemd-resolved.service
  - bash /var/tmp/install-consul.sh
  - touch /tmp/file
