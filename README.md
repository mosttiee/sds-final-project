[![Build Status](https://travis-ci.org/IBM/spring-boot-microservices-on-kubernetes.svg?branch=master)](https://travis-ci.org/IBM/spring-boot-microservices-on-kubernetes)

# Build and deploy Java Spring Boot microservices on Kubernetes

# HOW TO SETUP KUBERNETES CLUSTER ?

## What you need (must haves)
- 1xWiFi Router TP-Link TL WR841N
- 4xRaspberry Pi B+ (rasbian stretch lite for worker node)
- 4xSD Card
- 5xEthernet Cables
- 3xNotebook (ubuntu 18.04 for 2xmaster node and 1xHAproxy)

## Preparing the worker nodes
### Setup raspberry pi and set static IP
1.Download Etcher from "https://www.balena.io/etcher/" for burn the os image onto the microSD card.
2.Download image file for Raspberry Pi "http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/2019-04-08-raspbian-stretch-lite.zip" (we use rasbian stretch lite)
3.Insert microSD to your computer. Open program "balenaEtcher" select image "rasbian stretch lite" and click "Flash".
4.Put an empty file named ‘ssh’ (the file has no file extension or any content in) inside the SD card. This will allow us to ssh into the device out of the box. 
5.Insert the SD cards in the raspberry pi and power on the pis. And connect pi to the router for check IP.
6.Connect to your pi by command (x.x.x.x is IP of pi)
```
$ ssh pi@x.x.x.x
```
7.Type in 
```
$ raspi-config
``` 
It is a built in raspberry pi tool to configure the device.

8.Go to Network Options > Hostname. And change the hostname to anything you want. I named mine k8s-node-1, k8s-node-2, k8s-node-3 and k8s-node-4.
9.We will give our device a static ip so it keeps the ip between reboots. 
```
$ cat >> /etc/dhcpcd.conf
```
10.Paste the following code block 
```
interface eth0
static ip_address=x.x.x.y/24
static routers=x.x.x.1
static domain_name_servers=8.8.8.8
```

Where x.x.x is same as your device ip and y is the ip you want. I put 10,11,12 and 13 for each pi.

### Docker and Kubernetes setup
1. The main choices for a container environment are Docker and cri-o. We will user Docker, as cri-o requires a fair amount of extra work to enable for Kubernetes. As cri-o is open source the community seems to be heading towards its use The following command installs docker and sets the right permission.
```
curl -sSL get.docker.com | sh && \
sudo usermod pi -aG docker && \
newgrp docker
```
2. We need to then disable swap. Kubernetes requires swap to be disabled.
```
sudo dphys-swapfile swapoff && \
sudo dphys-swapfile uninstall && \
sudo update-rc.d dphys-swapfile remove
```
We can check swap disable was a success by the following command returning empty
```
sudo swapon --summary
```
3. Next we edit the /boot/cmdline.txt file. Add the following in the end of the file. This needs to be in the same line as all the other text in the file. Do not create a new file.
```
nano /boot/cmdline.txt
```

```
cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```
4. Reboot with 
```
sudo reboot
```
5. SSH in again. Edit the following file
```
nano /etc/apt/sources.list.d/kubernetes.list
```
add the following in the file
```
deb http://apt.kubernetes.io/ kubernetes-xenial main
```
add the key
```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
```
If it works, it will output OK
6. Update with new repo, which will download new repo information.
```
sudo apt-get update
```
7. Install kubeadm it will also install kubectl
```
sudo apt-get install -qy kubeadm
```

## Preparing HAproxy load balancer
1.Open ubuntu machine set the IP to “x.x.x.92”.
2.Update the machine
```
sudo apt-get update
sudo apt-get upgrade
```
3.Install HAProxy
```
sudo apt-get install haproxy
```
4. Configure HAProxy to load balance the traffic between the three Kubernetes master nodes.
```
sudo vim /etc/haproxy/haproxy.cfg
```
```
global
…
default
…
frontend kubernetes
bind x.x.x.92:6443
option tcplog
mode tcpdefault_backend kubernetes-master-nodes
backend Kubernetes-master-nodes
mode tcp
balance roundrobin
option tcp-check
server k8s-master-1 x.x.x.90:6443 check fall 2 rise 1
server k8s-master-2 x.x.x.91:6443 check fall 2 rise 1
```
5.Restart HAProxy.
```
sudo systemctl restart haproxy
```

## Generating the TLS certificates
1. SSH to the “x.x.x.90” machine.
2. Installing cfssl
```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssl*
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```
3. Create the certificate authority configuration file.
```
$ vim ca-config.json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
```
4. Create the certificate authority signing request configuration file.
```
$ vim ca-csr.json
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "IE",
    "L": "Cork",
    "O": "Kubernetes",
    "OU": "CA",
    "ST": "Cork Co."
  }
 ]
}
```
5. Generate the certificate authority certificate and private key.
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

## Preparing etcd clusters
1. Create the certificate signing request configuration file
```
$ vim kubernetes-csr.json
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "IE",
    "L": "Cork",
    "O": "Kubernetes",
    "OU": "Kubernetes",
    "ST": "Cork Co."
  }
 ]
}
```
2. Generate the certificate and private key.
```
$ cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-hostname=x.x.x.90, x.x.x.91, x.x.x.92,127.0.0.1,kubernetes.default \
-profile=kubernetes kubernetes-csr.json | \
cfssljson -bare kubernetes
```
3. Copy the certificate to each nodes
```
$ scp ca.pem kubernetes.pem kubernetes-key.pem [Username]@x.x.x.90:~
$ scp ca.pem kubernetes.pem kubernetes-key.pem [Username]@x.x.x.91:~
$ scp ca.pem kubernetes.pem kubernetes-key.pem [Username]@x.x.x.92:~
```
4. Installing etcd on each etcd node
```
$ sudo mkdir /etc/etcd /var/lib/etcd
$ sudo mv ~/ca.pem ~/kubernetes.pem ~/kubernetes-key.pem /etc/etcd
$ wget https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz
$ tar xvzf etcd-v3.3.9-linux-amd64.tar.gz
$ sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
```
5. Create an etcd systemd unit file on each etcd node.
x.x.x.y is current machine ip address
```
$ sudo vim /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
ExecStart=/usr/local/bin/etcd \
  --name x.x.x.y \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://10.10.40.90:2380 \
  --listen-peer-urls https://10.10.40.90:2380 \
  --listen-client-urls https://10.10.40.90:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://10.10.40.90:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster 10.10.40.90=https://10.10.40.90:2380,10.10.40.91=https://10.10.40.91:2380,10.10.40.92=https://10.10.40.92:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5


[Install]
WantedBy=multi-user.target
```
6. Reload the daemon configuration on each etcd node.
```
sudo systemctl daemon-reload
```
7. Enable etcd to start at boot time on each etcd node.
```
sudo systemctl enable etcd
```
8. Start etcd on each etcd node.
```
sudo systemctl start etcd
```

## Preparing the master nodes
### Instlling Docker,kubeadm,kubelet and kubectl.
1. Open ubuntu machine set the IP to “x.x.x.90” , “x.x.x.91”. and SSH to the machine.
2. Get administrator privileges.
```
$ sudo su
```
3. Add the Docker repository key.
```
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
```
4. Add the Docker repository
```
# add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
```
5. Update the list of packages.
```
# apt-get update
```
6. Install Docker 17.03.
```
# apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
```
7. Add the Google repository key.
```
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
```
8. Add the Google repository.
```
# vim /etc/apt/sources.list.d/kubernetes.list
```
Add the following
```
deb http://apt.kubernetes.io kubernetes-xenial main
```
9. Update the list of packages.
```
# apt-get update
```
10. Install kubelet,kubeadm and kubectl.
```
# apt-get install kubelet kubeadm kubectl
```
11. Disable the swap.
```
# swapoff -a
```
```
# sed -i '/ swap / s/^/#/' /etc/fstab
```

### Initializing the “x.x.x.90” master node
1. SSH to the “x.x.x.90” machine.
2. Create the configuration file for kubeadm.
```
$ vim config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: stable
apiServer:
  certSANs:
  - " x.x.x.92"
controlPlaneEndpoint: " x.x.x.92:6443"
etcd:
  external:
    endpoints:
    - https://x.x.x.90:2379
    - https://x.x.x.91:2379
    - https://x.x.x.92:2379
    caFile: /etc/etcd/ca.pem
    certFile: /etc/etcd/kubernetes.pem
    keyFile: /etc/etcd/kubernetes-key.pem
```
3. Initialize the machine as a master node.
```
sudo kubeadm init --config=config.yaml
```
4. Copy the certificates to the other masters.
```
sudo scp -r /etc/kubernetes/pki [Username]@x.x.x.91:~
```

### Initializing the “x.x.x.91” master node
1. SSH to the “x.x.x.91” machine.
2. Remove the apiserver.crt and apiserver.key.
```
rm ~/pki/apiserver.*
```
3. Move the certificates to the /etc/kubernetes directory.
```
sudo mv ~/pki /etc/kubernetes/
```
4. Initialize the machine as a master node.
```
sudo kubeadm join --token <token> <master-node-ip>:6443 --discovery-token-ca-cert-hash sha256:<sha256> --control-plane
```

## Worker nodes join master nodes.
1. From each worker node run
```
sudo kubeadm join --token <token> <master-node-ip>:6443 --discovery-token-ca-cert-hash sha256:<sha256>
```
2. After a few moments, run
```
kubectl get nodes
```

# HOW TO DEPLOY APPLICATION ?
Run this command.
```
./deploy.sh
```
