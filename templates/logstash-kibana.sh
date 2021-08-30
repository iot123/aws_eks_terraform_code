#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
yum install -y wget net-tools unzip
##########-Installation-Node-Exporter-######################
setenforce 0 
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
mv node_exporter-*.*-amd64/node_exporter /usr/local/bin/

cat <<EOF>> /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter



cat <<EOF>> /opt/volume-attach.sh
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
file -s /dev/xvdf
mkfs -t xfs /dev/xvdf
yum install xfsprogs
mkdir /data
mount /dev/xvdf /data
sudo blkid | grep "xvdf" | awk -F "=" '{print $2}' | awk -F " " '{print $1}'
echo "UUID=`blkid | grep "xvdf" | awk -F "=" '{print $2}' | awk -F " " '{print $1}'`  /data  xfs  defaults,nofail  0  2" >> /etc/fstab
EOF

