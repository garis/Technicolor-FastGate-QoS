# Technicolor-FastGate-QoS

What can it do:
* run multiple torrents client in multiple PCs with no upload limits
* run multiple upload speedtests in multiple PCs
* run a teamspeak session with no latency issue
* ...all at the same time

Note that this setup will manage only upload traffic since we can control each packet that will go on the internet link. The download is out of our control since we can only receive and we have no control of that

The file named 'qos' has 6 sections:

* `config label` types of traffic
* `config class` single QoS class
* `config classgroup` queue disciplines between classes
* `config interface` logical interfaces
* `config device` physical interfaces
* `config rule` QoS matching rules

Each `rule` match some specified traffic and marks it with a `label`

The `label` is used as trafficid and is a part of a `class` and can be think as a queue.

Each `class` is then part of a `classgroup` that form the QoS scheduling. 

A physical interface that need a QoS mechanism or an interface is linked with a `device` or a `interface` and linked to a `classgroup`
 
The example config file called `qos` is structured in the following parts:

+ 4 `label`:
  
  +  `LowP` low priority traffic identified with `trafficid 1`
  +  `NormalP` normal priority traffic identified with `trafficid 2`
  +  `HighP` high priority traffic identified with `trafficid 3`
  +  `VeryHighP` very high priority traffic identified with `trafficid4`

* 8 `class`: 4 for WAN/Internet traffic (`W_Q0`,`W_Q1`,`W_Q2`,`W_Q3`) and 4 for LAN/local (`L_Q0`,`L_Q1`,`L_Q2`,`L_Q3` for local traffic):
  
  * `W_Q0` lowest priority (=1) class linked to `LowP` with 0 minimum bit rate e 0 weight
  * `W_Q1` normal priority (=2) class linked to `NormalP` with a bit more weight and minimum bandwith
  * `W_Q2` high priority (=3) class linked to `HighP` with even a bit more weight and same minimum bandwith
  * `W_Q3` very high priority (=4) class linked to `VeryHighP` with a lot more weight and same minimum bandwith
  * `L_Q0`,`L_Q1`,`L_Q2`,`L_Q3` same as `W_Q0`,`W_Q1`,`W_Q2`,`W_Q3`

* 2 `classgroup`: one for WAN traffic and another for LAN traffic
  * `TO_WAN` uses the classes `W_Q0`,`W_Q1`,`W_Q2`,`W_Q3` with theirs options (priority, weight, label, etc) and uses `W_Q2` as the default traffic with the policy `sp_wrr` that stand for Strict Priority and Weighted Round Robin
  * `TO_LAN` same as `TO_WAN` but uses the classes `L_Q0`,`L_Q1`,`L_Q2`,`L_Q3`

* 2 `interface`:
  * `wan` uses the `classgroup` referred as `TO_WAN` and is enabled
  * same as `wan` but for `TO_LAN`

* 2 `device` that do the same thing as the `interface`, it's unclear the one needed...added both just to be sure
  
+ some `rule` to match SIP, ICMP, HTTP, HTTPS and torrent traffic and apply a somewhat good QoS.

The reasoning behind the rules are:
+ Everything is **high priority** traffic **BUT**:
  + SIP, ICMP and UDP is **very high priority** traffic
  + HTTP and HTTPS are **normal priority** traffic
  + Torrent is **low priority** traffic

This should cover a lot of cases with not too much rules... at least thats the hope.

## Details

#TODO#
