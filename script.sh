#!/bin/sh

#######################################################
# npshaper v0.1
# Thanks to https://forum.dd-wrt.com/phpBB2/viewtopic.php?p=692003
# Custom changes for testing purpouses
#######################################################

# Wan link download speed in Kbits (set to 80%-90% of link capacity)
DOWNLOAD=33000
# Wan link upload speed in Kbits (set to 80%-90% of link capacity)
UPLOAD=8700

# Download burst size in Kbytes
D_BURST=1000
# Upload burst size in Kbytes
U_BURST=100

#
# Ports used by the torrent services
#
HOMESERVER_BITTORRENT_PORT1=51413
HOMESERVER_BITTORRENT_PORT2=51414

#######################################################

WAN=ptm0
LAN=br-lan

DEBUG=0

if [ "$1" = "start" ]
then

   echo "Starting..."
   
  [ $DEBUG -eq 1 ] && insmod ipt_LOG >&- 2>&-

   # Remove previous settings
   
   qos -6 stop
   qos -4 stop
   iptables -t mangle -F
   tc qdisc del dev $WAN root >&- 2>&- 
   tc qdisc del dev $LAN root >&- 2>&-   
   
   ##### WAN #####
   echo "Setting up Wan interface traffic classes..."
   tc qdisc add dev $WAN root handle 1: htb
     tc class add dev $WAN parent 1: classid 1:1 htb rate ${UPLOAD}kbit ceil ${UPLOAD}kbit burst ${U_BURST}k cburst ${U_BURST}k
       tc class add dev $WAN parent 1:1 classid 1:10 htb rate $(($UPLOAD*5/10))kbit ceil ${UPLOAD}kbit burst ${U_BURST}k cburst ${U_BURST}k prio 0
       tc class add dev $WAN parent 1:1 classid 1:20 htb rate $(($UPLOAD*3/10))kbit ceil ${UPLOAD}kbit burst ${U_BURST}k cburst ${U_BURST}k prio 1
       tc class add dev $WAN parent 1:1 classid 1:30 htb rate $(($UPLOAD*2/10))kbit ceil ${UPLOAD}kbit burst ${U_BURST}k cburst ${U_BURST}k prio 2
       tc class add dev $WAN parent 1:1 classid 1:40 htb rate $(($UPLOAD*1/10))kbit ceil ${UPLOAD}kbit burst ${U_BURST}k cburst ${U_BURST}k prio 3

   tc filter add dev $WAN parent 1: prio 1 protocol ip handle 1 fw flowid 1:10
   tc filter add dev $WAN parent 1: prio 2 protocol ip handle 2 fw flowid 1:20
   tc filter add dev $WAN parent 1: prio 3 protocol ip handle 3 fw flowid 1:30
   tc filter add dev $WAN parent 1: prio 4 protocol ip handle 4 fw flowid 1:40 
   
   ##### LAN #####
   echo "Setting up Lan interface traffic classes..."
   tc qdisc add dev $LAN root handle 1: htb
     tc class add dev $LAN parent 1: classid 1:1 htb rate ${DOWNLOAD}kbit ceil ${DOWNLOAD}kbit burst ${D_BURST}k cburst ${D_BURST}k
       tc class add dev $LAN parent 1:1 classid 1:10 htb rate $(($DOWNLOAD*5/10))kbit ceil ${DOWNLOAD}kbit burst ${D_BURST}k cburst ${D_BURST}k prio 0
       tc class add dev $LAN parent 1:1 classid 1:20 htb rate $(($DOWNLOAD*3/10))kbit ceil ${DOWNLOAD}kbit burst ${D_BURST}k cburst ${D_BURST}k prio 1
       tc class add dev $LAN parent 1:1 classid 1:30 htb rate $(($DOWNLOAD*2/10))kbit ceil ${DOWNLOAD}kbit burst ${D_BURST}k cburst ${D_BURST}k prio 2
       tc class add dev $LAN parent 1:1 classid 1:40 htb rate $(($DOWNLOAD*1/10))kbit ceil ${DOWNLOAD}kbit burst ${D_BURST}k cburst ${D_BURST}k prio 3
      
   
   tc filter add dev $LAN parent 1: prio 1 protocol ip handle 1 fw flowid 1:10
   tc filter add dev $LAN parent 1: prio 2 protocol ip handle 2 fw flowid 1:20
   tc filter add dev $LAN parent 1: prio 3 protocol ip handle 3 fw flowid 1:30
   tc filter add dev $LAN parent 1: prio 4 protocol ip handle 4 fw flowid 1:40
   
   ######################################## MARK CHAIN ##################################################
   
   echo "Setting up classification chains..."
   
   # Remove previous settings
   iptables -t mangle -F
   iptables -t mangle -X
   
   # Wan ('upload' traffic) classification chain
   iptables -t mangle -N wan_mark_chain
   iptables -t mangle -A POSTROUTING -o $WAN -j wan_mark_chain
   
   # Lan ('download' traffic) classification chain
   iptables -t mangle -N lan_mark_chain
   iptables -t mangle -A POSTROUTING -o $LAN -j lan_mark_chain
   
   # Restore any saved connection mark (connection already marked and tracked)
   iptables -t mangle -A wan_mark_chain -j CONNMARK --restore-mark
   iptables -t mangle -A ptm_mark_chain -j CONNMARK --restore-mark
   iptables -t mangle -A lan_mark_chain -j CONNMARK --restore-mark
   
   ### RULES BEGIN #####################################
   
   # DNS (outgoing) and VoIP queries - Express
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --dport 53 -j MARK --set-mark 1
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --dport 5060 -j MARK --set-mark 1
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --dport 50601 -j MARK --set-mark 1
   
   # HTTP and HTTPS traffic Bulk
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p tcp --match multiport --sport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p tcp --match multiport --dport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --match multiport --sport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --match multiport --dport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p tcp --match multiport --sport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p tcp --match multiport --dport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p udp --match multiport --sport 80,443 -j MARK --set-mark 3
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p udp --match multiport --dport 80,443 -j MARK --set-mark 3
   
   # Torrent traffic - LowBulk
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p tcp --sport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p tcp --dport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --sport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --dport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p tcp --sport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p tcp --dport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p udp --sport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p udp --dport $HOMESERVER_BITTORRENT_PORT1 -j MARK --set-mark 4
   
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p tcp --sport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p tcp --dport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --sport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -p udp --dport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p tcp --sport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p tcp --dport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p udp --sport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -p udp --dport $HOMESERVER_BITTORRENT_PORT2 -j MARK --set-mark 4
   
   ### RULES END #####################################
   
   # Save mark so we track the full connection
   iptables -t mangle -A wan_mark_chain -j CONNMARK --save-mark
   iptables -t mangle -A lan_mark_chain -j CONNMARK --save-mark
   
   # ACK packets and suck (connection control) - Express
   iptables -t mangle -A wan_mark_chain -p tcp -m length --length :128 --tcp-flags SYN,RST,ACK ACK -j MARK --set-mark 1
   iptables -t mangle -A lan_mark_chain -p tcp -m length --length :128 --tcp-flags SYN,RST,ACK ACK -j MARK --set-mark 1
   
   # ICMP (ping and such) - Express
   iptables -t mangle -A wan_mark_chain -p icmp -j MARK --set-mark 1
   iptables -t mangle -A lan_mark_chain -p icmp -j MARK --set-mark 1
   
   # TOS Minimize-Delay - Express
   iptables -t mangle -A wan_mark_chain -m tos --tos Minimize-Delay -j MARK --set-mark 1
   iptables -t mangle -A lan_mark_chain -m tos --tos Minimize-Delay -j MARK --set-mark 1
   
   # Default (anything else) - Normal
   iptables -t mangle -A wan_mark_chain -m mark --mark 0 -j MARK --set-mark 2
   iptables -t mangle -A lan_mark_chain -m mark --mark 0 -j MARK --set-mark 2

   ######################################################################################################
   
   echo "Setting up debugging..."
   
   [ $DEBUG -eq 1 ] && iptables -t mangle -A wan_mark_chain -m mark --mark 1 -j LOG --log-prefix wan_qos_express::
   [ $DEBUG -eq 1 ] && iptables -t mangle -A wan_mark_chain -m mark --mark 2 -j LOG --log-prefix wan_qos_normal::
   [ $DEBUG -eq 1 ] && iptables -t mangle -A wan_mark_chain -m mark --mark 3 -j LOG --log-prefix wan_qos_bulk::
   [ $DEBUG -eq 1 ] && iptables -t mangle -A wan_mark_chain -m mark --mark 4 -j LOG --log-prefix wan_qos_lowbulk::
   
   [ $DEBUG -eq 1 ] && iptables -t mangle -A lan_mark_chain -m mark --mark 1 -j LOG --log-prefix lan_qos_express::
   [ $DEBUG -eq 1 ] && iptables -t mangle -A lan_mark_chain -m mark --mark 2 -j LOG --log-prefix lan_qos_normal::
   [ $DEBUG -eq 1 ] && iptables -t mangle -A lan_mark_chain -m mark --mark 3 -j LOG --log-prefix lan_qos_bulk::
   [ $DEBUG -eq 1 ] && iptables -t mangle -A lan_mark_chain -m mark --mark 4 -j LOG --log-prefix lan_qos_lowbulk::
   
   echo "Setting up accounting..."
   
   iptables -t mangle -A wan_mark_chain -m mark --mark 1 -j RETURN
   iptables -t mangle -A wan_mark_chain -m mark --mark 2 -j RETURN
   iptables -t mangle -A wan_mark_chain -m mark --mark 3 -j RETURN
   iptables -t mangle -A wan_mark_chain -m mark --mark 4 -j RETURN
   
   iptables -t mangle -A lan_mark_chain -m mark --mark 1 -j RETURN
   iptables -t mangle -A lan_mark_chain -m mark --mark 2 -j RETURN
   iptables -t mangle -A lan_mark_chain -m mark --mark 3 -j RETURN
   iptables -t mangle -A lan_mark_chain -m mark --mark 4 -j RETURN
   
   echo "...OK, all done."

fi

########################################

if [ "$1" = "status" ]
then
   echo "--- Current status ---"
   echo "--- WAN (Upload) ---"

   tc -s qdisc ls dev $WAN
   tc -s class ls dev $WAN
   echo ""
   echo "--- LAN (Download) ---"

   tc -s qdisc ls dev $LAN
   tc -s class ls dev $LAN
   echo ""
   echo "--- Classification chains ---"
   iptables -L -v -t mangle
   echo ""
fi

if [ "$1" = "stats" ]
then
   LAN_EXPRESS_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x1" | head -n 1 | awk '{print $1}'`
   LAN_NORMAL_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x2" | head -n 1 | awk '{print $1}'`
   LAN_BULK_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x3" | head -n 1 | awk '{print $1}'`
   LAN_LOWBULK_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x3" | head -n 1 | awk '{print $1}'`
   LAN_EXPRESS_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x1" | head -n 1 | awk '{print $2}'`
   LAN_NORMAL_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x2" | head -n 1 | awk '{print $2}'`
   LAN_BULK_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x3" | head -n 1 | awk '{print $2}'`
   LAN_LOWBULK_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x4" | head -n 1 | awk '{print $2}'`
   
   WAN_EXPRESS_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x1" | tail -n 1 | awk '{print $1}'`
   WAN_NORMAL_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x2" | tail -n 1 | awk '{print $1}'`
   WAN_BULK_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x3" | tail -n 1 | awk '{print $1}'`
   WAN_LOWBULK_PACKETS=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x4" | tail -n 1 | awk '{print $1}'`
   WAN_EXPRESS_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x1" | tail -n 1 | awk '{print $2}'`
   WAN_NORMAL_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x2" | tail -n 1 | awk '{print $2}'`
   WAN_BULK_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x3" | tail -n 1 | awk '{print $2}'`
   WAN_LOWBULK_BYTES=`iptables -L -v -n -t mangle | grep "RETURN" | grep "match 0x4" | tail -n 1 | awk '{print $2}'`
   
   echo "Traffic stats:"
   echo "D/U Class    Packets Bytes"
   echo "D   Express  $LAN_EXPRESS_PACKETS $LAN_EXPRESS_BYTES"
   echo "D   Normal   $LAN_NORMAL_PACKETS $LAN_NORMAL_BYTES"
   echo "D   Bulk     $LAN_BULK_PACKETS $LAN_BULK_BYTES"
   echo "D   LowBulk  $LAN_LOWBULK_PACKETS $LAN_LOWBULK_BYTES"
   echo "U   Express  $WAN_EXPRESS_PACKETS $WAN_EXPRESS_BYTES"
   echo "U   Normal   $WAN_NORMAL_PACKETS $WAN_NORMAL_BYTES"
   echo "U   Bulk     $WAN_BULK_PACKETS $WAN_BULK_BYTES"
   echo "U   LowBulk  $WAN_LOWBULK_PACKETS $WAN_LOWBULK_BYTES"
fi
