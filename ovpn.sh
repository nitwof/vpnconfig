#!/bin/bash

DEFAULT_OVPN_PATH="./volumes/ovpn"
OVPN_PATH="${OVPN_PATH:-$DEFAULT_OVPN_PATH}"

ovpn_cmd () {
  docker run --rm -it \
    -v $OVPN_DATA:/etc/openvpn \
    kylemanna/openvpn \
    $@
}

case $1 in
  init)
    IP="$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')"
    IP="0.0.0.0"
    ovpn_cmd ovpn_genconfig -u "udp://$IP"
    ovpn_cmd ovpn_initpki
    ovpn_cmd bash -c '
      sed -i "/dhcp-option/s/^/# /g" /etc/openvpn.conf &&
      echo "push \"dhcp-option DNS pihole\"" >> /etc/openvpn.conf
    '
    ;;
  start)
    docker run -d \
      --name ovpn \
      -v $OVPN_PATH/openvpn:/etc/openvpn \
      --network="vpn-net" \
      -p 1194:1194/udp \
      --cap-add=NET_ADMIN \
      --restarts always \
      kylemanna/openvpn
    ;;
  stop)
    docker stop ovpn
    docker rm ovpn
    ;;
  cert-create)
    ovpn_cmd easyrsa build-client-full $2 nopass
    ;;
  cert-revoke)
    ovpn_cmd ovpn_revokeclient $2 remove
    ;;
  cert-get)
    ovpn_cmd ovpn_getclient $2 > "$2.ovpn"
  *)
    echo "Invalid subcommand. Use 'init', 'start', 'stop', 'cert-create', 'cert-revoke' or 'cert-get'"
    ;;
esac