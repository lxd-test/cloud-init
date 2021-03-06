#cloud-config
write_files:
  - path: "/var/tmp/install-vault.sh"
    permissions: "0755"
    owner: "root:root"
    content: |
      #!/bin/bash
      export DC=${dc}
      export IFACE=${iface}
      export LAN_JOIN='${consul_server}'
      curl -sLo /tmp/consul.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/consul-client/consul.sh
      bash /tmp/consul.sh
      unset LAN_JOIN

      echo waiting for consul
      while ! consul catalog services ; do
        echo -n .
        sleep 2
      done

      export cluster_name=${dc}
      export key_name=${dc}
      curl -sLo /tmp/vault.sh https://raw.githubusercontent.com/kikitux/curl-bash/master/vault-ent/vault.sh
      bash /tmp/vault.sh
      sleep 5
      
      if [[ "$HOSTNAME" =~ "vault01" ]] ; then
        pushd /etc/vault.d/

        echo waiting for vault
        while ! curl http://127.0.0.1:8200/v1/sys/health ; do sleep 2 ; done
        sleep 5
        export initResult=$(VAULT_ADDR=http://127.0.0.1:8200 vault operator init -format=json -recovery-shares 1 -recovery-threshold 1 | tee init.json)
        export rootToken=$(echo $initResult | jq -r .root_token | tee rootToken)
        export recoveryKey=$(echo -n $initResult | jq -r '.recovery_keys_b64[0]' | tee recoveryKey)

        echo "X-Vault-Token: $rootToken" | tee rootTokenHeader
        #VAULT_TOKEN=$rootToken VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal $recoveryKey
        popd
      fi

      #replace IP of api and cluster for performance standby
      IP=`ip -f inet addr show $IFACE | sed -En -e 's/.*inet ([0-9.]+).*/\1/p'`
      sed -i -e "s/http:\/\/0.0.0.0/http:\/\/$IP/g" /etc/vault.d/server.hcl
      sed -i -e "s/https:\/\/0.0.0.0/https:\/\/$IP/g" /etc/vault.d/server.hcl
      service vault restart
  - path: "/etc/vault_license.json"
    permissions: "0640"
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
      ExecStartPre=/usr/bin/timeout 30 sh -c 'while ! /usr/bin/curl http://127.0.0.1:8200/v1/sys/health ; do sleep 2 ; done'
      ExecStart=/usr/bin/curl --header @/etc/vault.d/rootTokenHeader --request PUT --data @/etc/vault_license.json http://127.0.0.1:8200/v1/sys/license
      Type=oneshot
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
runcmd:
  - systemctl restart systemd-resolved.service
  - /var/tmp/install-vault.sh
  - systemctl enable vault-license.service
  - systemctl start vault-license.service
  - touch /tmp/file
