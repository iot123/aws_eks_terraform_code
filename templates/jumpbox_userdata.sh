#!/bin/bash
WORKSPACE="${workspace}"
ENV="${env}"
REGION="${region}"
route53_hosted_zone_name="${route53_hosted_zone_name}"
###############################-INSTALLATION-OF-LATEST-KUBECTL-##################
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubectl wget net-tools unzip

############################-INSTALLATION-OF-LATEST-AWS-AUTHENTICATOR-############
wget https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
openssl sha1 -sha256 aws-iam-authenticator
chmod +x ./aws-iam-authenticator
mkdir -p $HOME/bin && cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc

#############################-INSTALLATION-OF-LATEST-AWS-CLI-##########
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
/usr/local/bin/aws --version

##################################-MOUNT-NFS-###################################
yum install -y amazon-efs-utils
mkdir -p /home/ec2-user/nfs
sleep 10m
mount -t nfs nfs.${route53_hosted_zone_name}:/nfs /home/ec2-user/nfs
echo  "nfs.${route53_hosted_zone_name}:/nfs /home/ec2-user/nfs  nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" >> /etc/fstab

#########################################-INSTALL-NODE-EXPORTER-###################

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

setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
systemctl daemon-reload
systemctl start node_exporter

/usr/local/bin/aws eks --region $REGION update-kubeconfig --name $WORKSPACE-$ENV-cluster

