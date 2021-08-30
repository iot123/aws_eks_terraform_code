#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
#set -x
sleep 2m
REGION="${aws_region}"
NFSVOLUME="${nfs_ebs_volume}"
DEVICE=/dev/xvdf
DIRECTORY=/nfs
INSTANCEID=$(curl -s "http://169.254.169.254/latest/meta-data/instance-id")
VPC_CIDR="${vpc_cidr}"

echo $NFSVOLUME

# if [ $? -eq 0 ]; then
#  echo "AWS CLI already installed"
# else
 yum install python3 -y && yum install python3-pip -y  && yum install awscli -y && yum install net-tools -y
# fi

#setting custom prompt
cat << EOF | tee /etc/profile.d/ps1.sh
if [ "[\u@\h \W]\$ " ]; then
  PS1="[\e[36m\]\u\[\e[m\]\[\e[35m\]@\[\e[m\]\[\e[33m\]nfs-server\[\e[m\] \t \W]\\$ "
fi
EOF

# echo 'export PS1="[\e[36m\]\u\[\e[m\]\[\e[35m\]@\[\e[m\]\[\e[33m\]nfs-server\[\e[m\] \t \W]\\$ "' >> ~/.bashrc


# if the volume is available
if aws ec2 describe-volumes --volume-ids "$NFSVOLUME"  --region "$REGION" | grep -qi available; then
 # attach the volume
 aws ec2 attach-volume --volume-id "$NFSVOLUME" --device $DEVICE --instance-id "$INSTANCEID" --region "$REGION"
 sleep 10
 # wait until volume is attached
 n=0
 until [ $n -ge 5 ]
 do
  aws ec2 describe-volumes --volume-ids "$NFSVOLUME"  --region "$REGION" | grep -q attached && break
  echo "waiting $NFSVOLUME to be attached"
  ((n += 1))
  sleep 2
 done

 # if the volume is attached
 if aws ec2 describe-volumes --volume-ids "$NFSVOLUME"  --region "$REGION" | grep -q attached; then

  echo "Getting DEVICE from instance"
  EC2_DEVICE=$(lsblk --output NAME,SERIAL | grep -i $(echo "$NFSVOLUME" | sed 's/[\._-]//g') | awk '{print "/dev/"$1}')
  echo $EC2_DEVICE
  EC2_DEVICE=$DEVICE
  echo $EC2_DEVICE
  # create directory it not created before, then mount
  if [ ! -d "$DIRECTORY" ]; then
   echo "Making directory"
   mkdir $DIRECTORY -p
   mount "$EC2_DEVICE" $DIRECTORY 
   if [ $? -ne 0 ]; then
    echo "Creation partition"
    mkfs -t ext4 "$EC2_DEVICE"
    sleep 5
    mount "$EC2_DEVICE" $DIRECTORY 
    sleep 4
   fi
   #mount $EC2_DEVICE $DIRECTORY -t ext4
   sleep 3
   echo "Creating dummy file"
   touch /nfs/.NFSMASTER
  else
    echo "Directory exists skipping & mounting"
    mount "$EC2_DEVICE" $DIRECTORY 
  fi

  # check if .NFSMASTER file is present
  if [ -f "$DIRECTORY/.NFSMASTER" ]; then
   echo "$EC2_DEVICE is attached and mounted at $DIRECTORY"
   df -h $DIRECTORY
  else
   echo "Creating placeholder file"
   touch /nfs/.NFSMASTER
  fi
 else
  echo "A problem occurred, $NFSVOLUME is not attached 1"
 fi

elif aws ec2 describe-volumes --volume-ids "$NFSVOLUME"  --region "$REGION" | grep -q attached
then
 echo "Volume already attached"
 # create directory it not created before, then mount
 if [ ! -d "$DIRECTORY" ]; then
  echo "Making directory in elif"
  mkdir $DIRECTORY -p
  mount "$EC2_DEVICE" $DIRECTORY 
  if [ $? -ne 0 ]; then
   echo "Creation partition in elif"
   mkfs -t ext4 "$EC2_DEVICE"
   sleep 5
   mount "$EC2_DEVICE" $DIRECTORY 
   sleep 4
  fi
  #mount $EC2_DEVICE $DIRECTORY -t ext4
  sleep 3
  echo "Creating dummy file in elif"
  touch /nfs/.NFSMASTER
 
 else
    echo "Directory exists skipping & mounting"
    mount "$EC2_DEVICE" $DIRECTORY 
 fi

 # check if .NFSMASTER file is present
 if [ -f "$DIRECTORY/.NFSMASTER" ]; then
  echo "$EC2_DEVICE is attached and mounted at $DIRECTORY in elif"
  df -h $DIRECTORY
 else
  echo "Creating placeholder file in elif"
  touch /nfs/.NFSMASTER
 fi
else
 echo "A problem occurred, $NFSVOLUME is not attached 1"
fi



yum install nfs-utils libnfsidmap -y
file -s /dev/xvdf | grep ext4 && lsblk --fs | grep ext4
 if [ $? -eq 0 ]; then
  echo "EBS already formated"
 else
 mkfs -t ext4 /dev/xvdf
 fi
#mkfs -t ext4 /dev/xvdf
mount /dev/xvdf /nfs
start NFS service
echo "/nfs $VPC_CIDR(rw,sync,no_root_squash)" > /etc/exports
systemctl enable nfs-server
systemctl start nfs-server

yum update -yqq
touch /nfs/NFS_SERVER_SETUP_COMPLETED

yum install -y wget net-tools unzip
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
