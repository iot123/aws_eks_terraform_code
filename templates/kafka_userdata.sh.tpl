#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sleep 1m
REGION="${aws_region}"
KAFKAVOLUME="${kafka_ebs_volume}"
DEVICE=/dev/xvdf
DIRECTORY=/data
INSTANCEID=$(curl -s "http://169.254.169.254/latest/meta-data/instance-id")

echo $KAFKAVOLUME 
echo $INSTANCEID

apt update -y 
apt install python -y && apt install python3-pip -y && pip install awscli && apt install awscli -y

# if the volume is available
if aws ec2 describe-volumes --volume-ids "$KAFKAVOLUME"  --region "$REGION" | grep -qi available; then
 # attach the volume
 aws ec2 attach-volume --volume-id "$KAFKAVOLUME" --device $DEVICE --instance-id "$INSTANCEID" --region "$REGION"
 sleep 10
 # wait until volume is attached
 n=0
 until [ $n -ge 5 ]
 do
  aws ec2 describe-volumes --volume-ids "$KAFKAVOLUME"  --region "$REGION" | grep -q attached && break
  echo "waiting $KAFKAVOLUME to be attached"
  ((n += 1))
  sleep 2
 done
 
 # if the volume is attached
 if aws ec2 describe-volumes --volume-ids "$KAFKAVOLUME"  --region "$REGION" | grep -q attached; then

  echo "Getting DEVICE from instance"
#  EC2_DEVICE=$(lsblk --output NAME,SERIAL | grep -i $(echo "$KAFKAVOLUME" | sed 's/[\._-]//g') | awk '{print "/dev/"$1}')
  EC2_DEVICE=$DEVICE
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
   touch /data/.KAFKAMASTER
  else
    echo "Directory exists skipping & mounting"
    mount "$EC2_DEVICE" $DIRECTORY 
  fi

  # check if .KAFKAMASTER file is present
  if [ -f "$DIRECTORY/.KAFKAMASTER" ]; then
   echo "$EC2_DEVICE is attached and mounted at $DIRECTORY"
   df -h $DIRECTORY
  else
   echo "Creating placeholder file"
   touch /data/.KAFKAMASTER
  fi
 else
  echo "A problem occurred, $KAFKAVOLUME is not attached 1"
 fi

elif aws ec2 describe-volumes --volume-ids "$KAFKAVOLUME"  --region "$REGION" | grep -q attached
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
  touch /data/.KAFKAMASTER
 
 else
    echo "Directory exists skipping & mounting"
    mount "$EC2_DEVICE" $DIRECTORY 
 fi

 # check if .NFSMASTER file is present
 if [ -f "$DIRECTORY/.KAFKAMASTER" ]; then
  echo "$EC2_DEVICE is attached and mounted at $DIRECTORY in elif"
  df -h $DIRECTORY
 else
  echo "Creating placeholder file in elif"
  touch /data/.KAFKAMASTER
 fi
else
 echo "A problem occurred, $KAFKAVOLUME is not attached 1"
fi


apt install openjdk-8-jdk -y
apt install zookeeperd -y
useradd -d /data/kafka -s /bin/bash kafka
cd /data; wget   https://www.apache.org/dist/kafka/2.7.0/kafka_2.13-2.7.0.tgz
sleep 10 
mkdir -p /data/kafka
tar -xf kafka_2.13-2.7.0.tgz -C /data/kafka --strip-components=1
chown -R kafka:kafka /data/kafka
cd /data/kafka 
sed -i '130i delete.topic.enable = true' config/server.properties
# #########################################################
#    # launch_index=$(echo -n $az | tail -c 1 | tr abcdef 123456)
#     launch_index=0
#     echo "127.0.0.1  $HOSTNAME" >> /etc/hosts
#     sed -i "s/broker.id=0/broker.id=$launch_index/g" /data/kafka/config/server.properties
#     sed -i "s/localhost:2181/zookeeper_ips/g" /data/kafka/config/server.properties
#     sed -i "s/127.0.0.1:2181/zookeeper_ips/g" /data/kafka/config/consumer.properties
# #########################################################
cd /lib/systemd/system 
touch zookeeper.service
echo "[Unit]" >> zookeeper.service
echo "Requires=network.target remote-fs.target" >> zookeeper.service
echo "After=network.target remote-fs.target" >> zookeeper.service

echo "[Service]" >> zookeeper.service
echo "Type=simple" >> zookeeper.service
echo "User=kafka" >> zookeeper.service
echo "ExecStart=/data/kafka/bin/zookeeper-server-start.sh /data/kafka/config/zookeeper.properties" >> zookeeper.service
echo "ExecStop=/data/kafka/bin/zookeeper-server-stop.sh" >> zookeeper.service
echo "Restart=on-abnormal" >> zookeeper.service

echo "[Install]" >> zookeeper.service 
echo "WantedBy=multi-user.target" >> zookeeper.service

touch kafka.service

echo "[Unit]"  >> kafka.service
echo "Requires=zookeeper.service" >> kafka.service
echo "After=zookeeper.service" >> kafka.service

echo "[Service]" >> kafka.service
echo "Type=simple" >> kafka.service
echo "User=kafka" >> kafka.service
echo "ExecStart=/bin/sh -c '/data/kafka/bin/kafka-server-start.sh /data/kafka/config/server.properties'" >> kafka.service
echo "ExecStop=/data/kafka/bin/kafka-server-stop.sh" >> kafka.service
echo "Restart=on-abnormal" >> kafka.service

echo "[Install]" >> kafka.service
echo "WantedBy=multi-user.target" >> kafka.service


########## KAFKA AUTHENTICATION SET UP ###############
# touch /data/kafka/config/jaas-kafka-server.conf
# echo "
# KafkaServer {
#     org.apache.kafka.common.security.plain.PlainLoginModule required
#     username="admin"
#     password="admin"
#     user_admin="admin"
#     user_alice="alice"
#     user_bob="bob"
#     user_breeze="breeze"
#     user_charlie="charlie";
# }; " > /data/kafka/config/jaas-kafka-server.conf
# echo "
#  authorizer.class.name=kafka.security.auth.SimpleAclAuthorizer
# listeners=SASL_PLAINTEXT://:9092
# security.inter.broker.protocol= SASL_PLAINTEXT
# sasl.mechanism.inter.broker.protocol=PLAIN
# sasl.enabled.mechanisms=PLAIN 
# super.users=User:admin " >> /data/kafka/config/server.properties 
 
      
# sed -i -e 's:exec $base_dir/kafka-run-class.sh $EXTRA_ARGS kafka.Kafka "$@":exec $base_dir/kafka-run-class.sh $EXTRA_ARGS -Djava.security.auth.login.config=$base_dir/../config/jaas-kafka-server.conf kafka.Kafka "$@":g' /data/kafka/bin/kafka-server-start.sh
############## START OF ZOOKEEPER AND KAFKA ###################
systemctl daemon-reload
systemctl start zookeeper
systemctl enable zookeeper
sleep 10
systemctl start kafka
systemctl enable kafka
