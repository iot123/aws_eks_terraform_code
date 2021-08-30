yum install -y amazon-efs-utils 
mkdir -p /home/ec2-user/nfs
sleep 5m
mount -t nfs nfs.${route53_hosted_zone_name}:/nfs /home/ec2-user/nfs
echo  "nfs.${route53_hosted_zone_name}:/nfs /home/ec2-user/nfs  nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" >> /etc/fstab

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
