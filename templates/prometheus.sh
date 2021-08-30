#!/bin/bash
workspace="${workspace}"
env="${env}"
region="${region}"
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
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

#############################-INSTALLATION-OF-LATEST-AWS-CLI-##########
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
/usr/local/bin/aws --version


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


cat <<EOF>> /opt/prometheus.yml
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.

  - job_name: 'NFS-server-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: nfs-server-asg-${workspace}-${env}.*
      action: keep

  - job_name: 'Jumpbox-server-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: ${workspace}_${env}_jumpbox.*
      action: keep

  - job_name: 'k8s-worker-nodes-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: k8s_${workspace}_${env}_.*
      action: keep


  - job_name: 'k8s-cluster-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 8080
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: k8s_${workspace}_${env}_.*
      action: keep


  - job_name: 'Elasticsearch-server-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: ${workspace}_${env}_elasticsearch.*
      action: keep


  - job_name: 'Kafka-server-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: ${workspace}_${env}_kafka.*
      action: keep

  - job_name: 'Mongo-server-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: ${workspace}_${env}_mongo.*
      action: keep

  - job_name: 'Logstash-Kibana-server-monitoring'
    ec2_sd_configs:
    - region: ${region}
      port: 9100
    relabel_configs:
    # Only monitor instances with a Name starting with "dev-"
    - source_labels: [__meta_ec2_tag_Name]
      target_label: instance
      regex: ${workspace}_${env}_logstash-kibana.*
      action: keep
EOF
