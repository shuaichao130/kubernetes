#!/bin/bash
master=192.168.252.11
kubeadm config print init-defaults > new.yaml
sed -i "s/  advertiseAddress: 1.2.3.4/  advertiseAddress: $master/" new.yaml
sed -i "/  timeoutForControlPlane: 4m0s/i \ \ - $master" new.yaml
sed -i "/  - $master/i \ \ certSANs:" new.yaml
sed -i "s|  serviceSubnet: 10.96.0.0/12|  serviceSubnet: 172.16.0.0/16|" new.yaml
sed -i "/  serviceSubnet: 172.16.0.0\/16/i \ \ podSubnet: 192.168.0.0\/16" new.yaml
sed -i 's/kubernetesVersion: v1.20.0/kubernetesVersion: v1.20.7/' new.yaml
sed -i 's/imageRepository: k8s.gcr.io/imageRepository: registry.cn-hangzhou.aliyuncs.com\/google_containers/' new.yaml
kubeadm config images pull --config /root/new.yaml
sleep 10
kubeadm init --config /root/new.yaml --upload-certs
sleep 300
sed -i '$a export KUBECONFIG=/etc/kubernetes/admin.conf' /etc/profile
source /etc/profile
wget https://raw.githubusercontent.com/shuaichao130/kubernetes/main/calico-etcd.yaml
sed -i "s#etcd_endpoints: "http://<ETCD_IP>:<ETCD_PORT>"#etcd_endpoints: "https://$master:2379"#g" calico-etcd.yaml 
ETCD_CA=`cat /etc/kubernetes/pki/etcd/ca.crt | base64 | tr -d '\n'`
ETCD_CERT=`cat /etc/kubernetes/pki/etcd/server.crt | base64 | tr -d '\n'`
ETCD_KEY=`cat /etc/kubernetes/pki/etcd/server.key | base64 | tr -d '\n'`
sed -i "s@# etcd-key: null@etcd-key: ${ETCD_KEY}@g; s@# etcd-cert: null@etcd-cert: ${ETCD_CERT}@g; s@# etcd-ca: null@etcd-ca: ${ETCD_CA}@g" calico-etcd.yaml
sed -i 's#etcd_ca: ""#etcd_ca: "/calico-secrets/etcd-ca"#g; s#etcd_cert: ""#etcd_cert: "/calico-secrets/etcd-cert"#g; s#etcd_key: "" #etcd_key: "/calico-secrets/etcd-key" #g' calico-etcd.yaml
sed -i 's@# - name: CALICO_IPV4POOL_CIDR@- name: CALICO_IPV4POOL_CIDR@g; s@#   value: "172.168.0.0/16"@  value: '"${POD_SUBNET}"'@g' calico-etcd.yaml
sed -i 's/^ *# - name: CALICO_IPV4POOL_CIDR/            - name: CALICO_IPV4POOL_CIDR/' calico-etcd.yaml
sed -i 's|^ *#   value: "192.168.0.0/16"|              value: "192.168.0.0/16"|' calico-etcd.yaml
sleep 100
kubectl apply -f calico-etcd.yaml
