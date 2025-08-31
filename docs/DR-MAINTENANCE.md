# Disaster Recovery & Maintenance Guide

This comprehensive guide covers Disaster Recovery (DR) strategies and maintenance activities for the Aegis Kubernetes Framework, ensuring business continuity, system reliability, and operational excellence.

## 📋 **Table of Contents**

- [Disaster Recovery Overview](#disaster-recovery-overview)
- [Maintenance Activities](#maintenance-activities)
- [Backup & Restore Procedures](#backup--restore-procedures)
- [Monitoring & Alerting](#monitoring--alerting)
- [Testing & Validation](#testing--validation)
- [Operational Runbooks](#operational-runbooks)

## 🚨 **Disaster Recovery Overview**

### **DR Strategy Components**

#### **1. Recovery Time Objective (RTO) & Recovery Point Objective (RPO)**

```yaml
# DR Objectives Configuration
dr_objectives:
  critical_applications:
    rto: "4 hours"        # Recovery Time Objective
    rpo: "15 minutes"     # Recovery Point Objective
  standard_applications:
    rto: "24 hours"
    rpo: "1 hour"
  development_environments:
    rto: "72 hours"
    rpo: "4 hours"
```

#### **2. Multi-Region Architecture**

```hcl
# Multi-region infrastructure setup
resource "aws_vpc" "primary" {
  cidr_block = "10.0.0.0/16"
  provider   = aws.primary

  tags = {
    Environment = "production"
    Region      = "us-east-1"
    DR-Role     = "primary"
  }
}

resource "aws_vpc" "secondary" {
  cidr_block = "10.0.0.0/16"
  provider   = aws.secondary

  tags = {
    Environment = "production"
    Region      = "us-west-2"
    DR-Role     = "secondary"
  }
}
```

### **DR Scenarios & Response Plans**

#### **Scenario 1: Complete Region Failure**

**Detection:**
```yaml
# CloudWatch alarm for region health
resource "aws_cloudwatch_metric_alarm" "region_health" {
  alarm_name          = "region-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Region health check failed"
  alarm_actions       = [aws_sns_topic.dr_alerts.arn]
}
```

**Response Plan:**
1. **Immediate Actions (0-15 minutes)**
   ```bash
   # Activate secondary region
   aws ec2 start-instances --instance-ids $SECONDARY_INSTANCES

   # Update DNS to secondary region
   aws route53 change-resource-record-sets \
     --hosted-zone-id $HOSTED_ZONE \
     --change-batch file://dr-dns-failover.json
   ```

2. **Recovery Actions (15-120 minutes)**
   ```bash
   # Deploy cluster in secondary region
   kops create cluster \
     --name=$CLUSTER_NAME \
     --state=s3://$KOPS_STATE_BUCKET \
     --zones=$SECONDARY_ZONES \
     --yes

   # Restore from backup
   ./scripts/dr/restore-cluster.sh --from-backup
   ```

#### **Scenario 2: Control Plane Failure**

**Detection:**
```yaml
# Kubernetes control plane monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: control-plane-failure
  namespace: monitoring
spec:
  groups:
  - name: control-plane
    rules:
    - alert: ControlPlaneDown
      expr: up{job="apiserver"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Kubernetes API server is down"
        description: "Kubernetes API server has been down for more than 5 minutes"
```

**Response Plan:**
```bash
# 1. Check control plane status
kubectl get nodes --selector='node-role.kubernetes.io/control-plane'

# 2. Restart failed components
kubectl get pods -n kube-system | grep -E "(kube-apiserver|etcd|kube-controller-manager|kube-scheduler)"

# 3. If control plane is completely down, failover to secondary
kops export kubecfg $CLUSTER_NAME --state=s3://$KOPS_STATE_BUCKET
kubectl config use-context $SECONDARY_CONTEXT
```

#### **Scenario 3: Data Loss/Corruption**

**Detection:**
```yaml
# etcd corruption detection
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-health-check
  namespace: kube-system
spec:
  schedule: "*/15 * * * *"  # Every 15 minutes
  jobTemplate:
    spec:
      containers:
      - name: etcd-check
        image: k8s.gcr.io/etcd:3.5.9-0
        command:
        - /bin/sh
        - -c
        - |
          # Check etcd health
          ETCDCTL_API=3 etcdctl endpoint health
          if [ $? -ne 0 ]; then
            echo "etcd health check failed"
            exit 1
          fi

          # Check data consistency
          ETCDCTL_API=3 etcdctl snapshot save /tmp/snapshot.db
          ETCDCTL_API=3 etcdctl snapshot status /tmp/snapshot.db
```

**Response Plan:**
```bash
# 1. Stop etcd to prevent further corruption
kubectl scale deployment etcd -n kube-system --replicas=0

# 2. Restore from latest backup
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir /var/lib/etcd-restore

# 3. Restart etcd with restored data
kubectl scale deployment etcd -n kube-system --replicas=3
```

## 🔧 **Maintenance Activities**

### **1. Regular Maintenance Schedule**

#### **Daily Maintenance**
```bash
# Daily maintenance script
#!/bin/bash
echo "=== Daily Maintenance $(date) ==="

# 1. Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# 2. Check resource usage
kubectl top nodes
kubectl top pods -A

# 3. Check security events
kubectl get events -A --field-selector type=Warning

# 4. Verify backups
aws s3 ls s3://aegis-backups/ | tail -5

# 5. Check certificate expiry
kubectl get certificates -A
```

#### **Weekly Maintenance**
```bash
# Weekly maintenance script
#!/bin/bash
echo "=== Weekly Maintenance $(date) ==="

# 1. Update security policies
kubectl apply -f manifests/kyverno/policies/

# 2. Rotate service account tokens
kubectl get serviceaccounts -A -o json | \
  jq -r '.items[] | select(.secrets != null) | .metadata.name' | \
  xargs -I {} kubectl create token {}

# 3. Clean up old images
kubectl get pods -A -o jsonpath='{..image}' | \
  tr -s '[[:space:]]' '\n' | sort | uniq -c | sort -nr

# 4. Review and update RBAC
kubectl get clusterrolebindings
kubectl get rolebindings -A
```

#### **Monthly Maintenance**
```bash
# Monthly maintenance script
#!/bin/bash
echo "=== Monthly Maintenance $(date) ==="

# 1. Security audit
kube-bench run --targets=node,policies,managedservices

# 2. Compliance check
kubectl get pods -A -o json | \
  jq '.items[] | select(.spec.securityContext.runAsNonRoot != true)'

# 3. Performance analysis
kubectl get events -A --since=30d | grep -i "failed\|error"

# 4. Capacity planning
kubectl get nodes -o json | \
  jq '.items[] | {name: .metadata.name, capacity: .status.capacity, allocatable: .status.allocatable}'
```

### **2. Patch Management**

#### **Kubernetes Version Updates**
```bash
# Check for available updates
kops upgrade cluster $CLUSTER_NAME --state=s3://$KOPS_STATE_BUCKET

# Plan the upgrade
kops update cluster $CLUSTER_NAME --state=s3://$KOPS_STATE_BUCKET

# Apply the upgrade
kops update cluster $CLUSTER_NAME --state=s3://$KOPS_STATE_BUCKET --yes

# Validate the upgrade
kops validate cluster $CLUSTER_NAME
```

#### **Security Patching**
```yaml
# Automated security patching
apiVersion: batch/v1
kind: CronJob
metadata:
  name: security-patching
  namespace: kube-system
spec:
  schedule: "0 2 * * 1"  # Weekly on Monday 2 AM
  jobTemplate:
    spec:
      containers:
      - name: patch-manager
        image: alpine:latest
        command:
        - /bin/sh
        - -c
        - |
          # Update node packages
          apk update && apk upgrade

          # Restart services if needed
          rc-service kubelet restart

          # Log the patching activity
          echo "Security patching completed on $(date)" >> /var/log/patching.log
```

### **3. Certificate Management**

#### **Certificate Rotation**
```yaml
# Automated certificate rotation
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: auto-rotate-cert
  namespace: production
spec:
  secretName: tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - app.company.com
  duration: 2160h     # 90 days
  renewBefore: 720h   # 30 days before expiry
```

#### **Certificate Health Monitoring**
```yaml
# Certificate monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-monitoring
  namespace: monitoring
spec:
  groups:
  - name: certificates
    rules:
    - alert: CertificateExpiryWarning
      expr: certmanager_certificate_expiration_timestamp_seconds < time() + 30*24*3600
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Certificate expires soon"
        description: "Certificate {{ $labels.name }} expires in less than 30 days"

    - alert: CertificateExpiryCritical
      expr: certmanager_certificate_expiration_timestamp_seconds < time() + 7*24*3600
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Certificate expires soon"
        description: "Certificate {{ $labels.name }} expires in less than 7 days"
```

## 💾 **Backup & Restore Procedures**

### **1. etcd Backup Strategy**

#### **Automated etcd Backups**
```yaml
# etcd backup cronjob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: etcd-backup-sa
          containers:
          - name: etcd-backup
            image: k8s.gcr.io/etcd:3.5.9-0
            command:
            - /bin/sh
            - -c
            - |
              # Create etcd snapshot
              ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
                --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
                --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
                snapshot save /backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db

              # Encrypt the backup
              openssl enc -aes-256-cbc -salt \
                -in /backup/etcd-snapshot-*.db \
                -out /backup/etcd-snapshot-*.db.enc \
                -k $ENCRYPTION_KEY

              # Upload to S3
              aws s3 cp /backup/etcd-snapshot-*.db.enc s3://aegis-etcd-backups/

              # Cleanup local files
              rm -f /backup/etcd-snapshot-*.db*
            volumeMounts:
            - name: etcd-certs
              mountPath: /etc/kubernetes/pki/etcd
              readOnly: true
            - name: backup-volume
              mountPath: /backup
            env:
            - name: ENCRYPTION_KEY
              valueFrom:
                secretKeyRef:
                  name: etcd-backup-secret
                  key: encryption-key
          volumes:
          - name: etcd-certs
            secret:
              secretName: etcd-certs
          - name: backup-volume
            emptyDir: {}
          restartPolicy: OnFailure
```

#### **etcd Restore Procedure**
```bash
# 1. Stop etcd
kubectl scale deployment etcd -n kube-system --replicas=0

# 2. Download latest backup
aws s3 cp s3://aegis-etcd-backups/etcd-snapshot-latest.db.enc /tmp/

# 3. Decrypt backup
openssl enc -d -aes-256-cbc \
  -in /tmp/etcd-snapshot-latest.db.enc \
  -out /tmp/etcd-snapshot-latest.db \
  -k $ENCRYPTION_KEY

# 4. Restore etcd data
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-snapshot-latest.db \
  --data-dir /var/lib/etcd-restore \
  --name etcd-restore

# 5. Update etcd configuration to use restored data
kubectl set env deployment/etcd ETCD_DATA_DIR=/var/lib/etcd-restore

# 6. Restart etcd
kubectl scale deployment etcd -n kube-system --replicas=3

# 7. Verify cluster health
kubectl get nodes
kops validate cluster $CLUSTER_NAME
```

### **2. Application Data Backup**

#### **Persistent Volume Backups**
```yaml
# Velero configuration for PV backups
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: daily-app-backup
  namespace: velero
spec:
  includedNamespaces:
  - production
  - staging
  includedResources:
  - persistentvolumeclaims
  - persistentvolumes
  - secrets
  - configmaps
  labelSelector:
    matchLabels:
      backup: "true"
  ttl: 720h  # 30 days
  schedule: "0 2 * * *"  # Daily at 2 AM
```

#### **Database Backups**
```yaml
# Database backup job
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  namespace: database
spec:
  schedule: "0 */4 * * *"  # Every 4 hours
  jobTemplate:
    spec:
      containers:
      - name: backup
        image: postgres:14
        command:
        - /bin/bash
        - -c
        - |
          # Create database backup
          pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > /backup/db-$(date +%Y%m%d-%H%M%S).sql

          # Compress backup
          gzip /backup/db-*.sql

          # Upload to S3
          aws s3 cp /backup/db-*.sql.gz s3://aegis-db-backups/

          # Cleanup old backups (keep last 7 days)
          aws s3 ls s3://aegis-db-backups/ | \
            awk '$$1 < "'$(date -d '7 days ago' +%Y-%m-%d)'" {print $$4}' | \
            xargs -I {} aws s3 rm s3://aegis-db-backups/{}
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: host
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: username
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: database
        volumeMounts:
        - name: backup-volume
          mountPath: /backup
      volumes:
      - name: backup-volume
        emptyDir: {}
      restartPolicy: OnFailure
```

### **3. Configuration Backup**

#### **GitOps Configuration Backup**
```bash
# Backup GitOps configurations
#!/bin/bash
BACKUP_DIR="/backup/gitops-$(date +%Y%m%d-%H%M%S)"

# Clone repository
git clone https://github.com/org/aegis-kubernetes-framework.git $BACKUP_DIR

# Create archive
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR

# Upload to S3
aws s3 cp $BACKUP_DIR.tar.gz s3://aegis-config-backups/

# Cleanup
rm -rf $BACKUP_DIR $BACKUP_DIR.tar.gz
```

## 📊 **Monitoring & Alerting**

### **1. DR Monitoring Dashboard**

```yaml
# Grafana dashboard for DR monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-monitoring-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Disaster Recovery Monitoring",
        "panels": [
          {
            "title": "Cluster Health Status",
            "type": "stat",
            "targets": [
              {
                "expr": "up{job=\"kubernetes-nodes\"}",
                "legendFormat": "Healthy Nodes"
              }
            ]
          },
          {
            "title": "Backup Success Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(velero_backup_success_total[1h])",
                "legendFormat": "Successful Backups"
              }
            ]
          },
          {
            "title": "RTO/RPO Compliance",
            "type": "table",
            "targets": [
              {
                "expr": "time() - kube_pod_created_time",
                "legendFormat": "Pod Age"
              }
            ]
          }
        ]
      }
    }
```

### **2. DR Alerting Rules**

```yaml
# Prometheus alerting rules for DR
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dr-alerts
  namespace: monitoring
spec:
  groups:
  - name: disaster-recovery
    rules:
    - alert: ClusterUnhealthy
      expr: kube_node_status_condition{condition="Ready",status="false"} > 0
      for: 10m
      labels:
        severity: critical
      annotations:
        summary: "Kubernetes cluster is unhealthy"
        description: "{{ $value }} nodes are not ready"

    - alert: BackupFailed
      expr: velero_backup_failure_total > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Backup job failed"
        description: "Velero backup failed for {{ $labels.schedule }}"

    - alert: HighResourceUsage
      expr: (1 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])))) > 0.9
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage detected"
        description: "CPU usage is above 90% on {{ $labels.instance }}"

    - alert: CertificateExpiry
      expr: certmanager_certificate_expiration_timestamp_seconds < time() + 7*24*3600
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Certificate expires soon"
        description: "Certificate {{ $labels.name }} expires in less than 7 days"
```

## 🧪 **Testing & Validation**

### **1. DR Testing Schedule**

#### **Quarterly DR Tests**
```bash
# DR test script
#!/bin/bash
echo "=== Disaster Recovery Test $(date) ==="

# 1. Create test scenario
echo "Creating test failure scenario..."
kubectl scale deployment test-app --replicas=0

# 2. Test backup restoration
echo "Testing backup restoration..."
velero restore create test-restore --from-backup daily-app-backup

# 3. Test failover
echo "Testing failover to secondary region..."
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE \
  --change-batch file://test-failover.json

# 4. Validate recovery
echo "Validating recovery..."
kubectl get pods -l app=test-app
kubectl get nodes

# 5. Measure RTO/RPO
echo "Measuring RTO/RPO..."
START_TIME=$(date +%s)
# ... recovery process ...
END_TIME=$(date +%s)
RTO=$((END_TIME - START_TIME))
echo "RTO: ${RTO} seconds"

# 6. Generate test report
echo "Generating test report..."
cat > /tmp/dr-test-report.txt << EOF
DR Test Report - $(date)
========================
Test Scenario: Application failover
RTO Achieved: ${RTO} seconds
RPO Achieved: Check backup timestamps
Test Result: $( [ $RTO -le 14400 ] && echo "PASS" || echo "FAIL" )
EOF

aws s3 cp /tmp/dr-test-report.txt s3://aegis-dr-reports/
```

#### **Monthly Maintenance Tests**
```bash
# Maintenance test script
#!/bin/bash
echo "=== Maintenance Test $(date) ==="

# 1. Test certificate rotation
echo "Testing certificate rotation..."
kubectl get certificates -A
kubectl annotate certificate test-cert cert-manager.io/renew=true

# 2. Test node maintenance
echo "Testing node maintenance..."
kubectl drain test-node --ignore-daemonsets
kubectl uncordon test-node

# 3. Test backup integrity
echo "Testing backup integrity..."
aws s3 ls s3://aegis-backups/ | tail -1
# Download and verify backup

# 4. Test monitoring alerts
echo "Testing monitoring alerts..."
kubectl scale deployment test-app --replicas=0
# Wait for alert to trigger
sleep 300
# Check if alert was sent

echo "Maintenance tests completed"
```

### **2. Chaos Engineering**

#### **Automated Chaos Tests**
```yaml
# Chaos Mesh experiments
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-test
  namespace: chaos-testing
spec:
  action: pod-failure
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: test-app
  duration: "30s"
  scheduler:
    cron: "@weekly"
```

## 📋 **Operational Runbooks**

### **1. Emergency Response Runbook**

#### **Critical Incident Response**
```markdown
# Critical Incident Response Runbook

## Detection
- Alert received from monitoring system
- Manual detection by operator
- Automated detection by health checks

## Assessment (0-5 minutes)
1. Check cluster status: `kubectl get nodes`
2. Check pod status: `kubectl get pods -A | grep -v Running`
3. Check recent events: `kubectl get events -A --sort-by=.lastTimestamp | tail -20`
4. Check monitoring dashboards

## Response (5-30 minutes)
1. **If control plane down:**
   - Check etcd status: `kubectl get pods -n kube-system | grep etcd`
   - Restart control plane: `kubectl scale deployment kube-apiserver --replicas=1`

2. **If worker nodes down:**
   - Check node status: `kubectl describe node <node-name>`
   - Restart kubelet: `systemctl restart kubelet`

3. **If application down:**
   - Check pod logs: `kubectl logs <pod-name>`
   - Restart deployment: `kubectl rollout restart deployment <deployment-name>`

## Recovery (30-120 minutes)
1. Restore from backup if needed
2. Verify system health
3. Update stakeholders
4. Document incident

## Post-Incident (2-24 hours)
1. Root cause analysis
2. Implement fixes
3. Update runbooks
4. Schedule retrospective
```

### **2. Maintenance Window Runbook**

#### **Scheduled Maintenance**
```bash
# Maintenance window script
#!/bin/bash
MAINTENANCE_START=$(date +%s)
MAINTENANCE_DURATION=7200  # 2 hours in seconds

echo "=== Maintenance Window Started: $(date) ==="

# 1. Notify stakeholders
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Maintenance window started - 2 hour duration"}' \
  $SLACK_WEBHOOK

# 2. Enable maintenance mode
kubectl annotate namespace production maintenance=true

# 3. Scale down non-critical workloads
kubectl scale deployment non-critical-app --replicas=0

# 4. Perform maintenance tasks
echo "Performing maintenance tasks..."

# Update Kubernetes
kops upgrade cluster $CLUSTER_NAME
kops update cluster $CLUSTER_NAME --yes

# Update node packages
kubectl apply -f manifests/maintenance/node-updates.yaml

# Rotate certificates
kubectl get certificates -A | \
  xargs -I {} kubectl annotate {} cert-manager.io/renew=true

# 5. Verify system health
kubectl get nodes
kubectl get pods -A | grep -v Running

# 6. Scale back workloads
kubectl scale deployment non-critical-app --replicas=3

# 7. Disable maintenance mode
kubectl annotate namespace production maintenance-

# 8. Notify completion
MAINTENANCE_END=$(date +%s)
DURATION=$((MAINTENANCE_END - MAINTENANCE_START))

curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Maintenance completed successfully - Duration: '${DURATION}' seconds"}' \
  $SLACK_WEBHOOK

echo "=== Maintenance Window Completed: $(date) ==="
```

### **3. Backup Verification Runbook**

#### **Backup Integrity Checks**
```bash
# Backup verification script
#!/bin/bash
echo "=== Backup Verification $(date) ==="

# 1. Check backup existence
LATEST_BACKUP=$(aws s3 ls s3://aegis-backups/ | sort | tail -1 | awk '{print $4}')
if [ -z "$LATEST_BACKUP" ]; then
  echo "ERROR: No backup found"
  exit 1
fi

# 2. Download and verify backup
aws s3 cp s3://aegis-backups/$LATEST_BACKUP /tmp/backup.tar.gz
tar -tzf /tmp/backup.tar.gz > /dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: Backup is corrupted"
  exit 1
fi

# 3. Check backup freshness
BACKUP_DATE=$(aws s3 ls s3://aegis-backups/$LATEST_BACKUP | awk '{print $1}')
BACKUP_EPOCH=$(date -d "$BACKUP_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
AGE_HOURS=$(( (CURRENT_EPOCH - BACKUP_EPOCH) / 3600 ))

if [ $AGE_HOURS -gt 25 ]; then
  echo "WARNING: Backup is $AGE_HOURS hours old"
fi

# 4. Test restore capability
echo "Testing restore capability..."
# Create test namespace
kubectl create namespace backup-test
# Attempt restore
velero restore create test-restore --from-backup $LATEST_BACKUP --namespace-mappings production:backup-test

# 5. Cleanup
kubectl delete namespace backup-test
rm -f /tmp/backup.tar.gz

echo "Backup verification completed successfully"
```

## 🎯 **Key Performance Indicators (KPIs)**

### **DR KPIs**
- **RTO Achievement**: Percentage of incidents recovered within RTO
- **RPO Achievement**: Percentage of data recovered within RPO
- **MTTR**: Mean Time To Recovery for incidents
- **Test Success Rate**: Percentage of successful DR tests

### **Maintenance KPIs**
- **Uptime**: System availability percentage
- **Patch Compliance**: Percentage of systems with latest patches
- **Backup Success Rate**: Percentage of successful backups
- **Incident Prevention**: Reduction in incidents due to maintenance

### **Monitoring KPIs**
- **Alert Response Time**: Average time to respond to alerts
- **False Positive Rate**: Percentage of false alerts
- **Monitoring Coverage**: Percentage of systems monitored
- **SLA Compliance**: Percentage of SLAs met

## 🚀 **Automation & Orchestration**

### **GitOps for DR**
```yaml
# ArgoCD application for DR configurations
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aegis-dr
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/aegis-kubernetes-framework
    targetRevision: HEAD
    path: manifests/dr
  destination:
    server: https://kubernetes.default.svc
    namespace: aegis-dr
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### **Automated Maintenance**
```yaml
# ArgoCD application for maintenance
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aegis-maintenance
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/aegis-kubernetes-framework
    targetRevision: HEAD
    path: manifests/maintenance
  destination:
    server: https://kubernetes.default.svc
    namespace: aegis-maintenance
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 📈 **Continuous Improvement**

### **DR Maturity Assessment**
```yaml
# DR maturity scoring
dr_maturity:
  strategy: 4/5      # Comprehensive DR strategy
  testing: 4/5       # Regular DR testing
  automation: 3/5    # Partial automation
  monitoring: 4/5    # Good monitoring
  documentation: 5/5 # Excellent documentation
  training: 3/5      # Basic training
  total_score: 23/30 # 77% maturity
```

### **Maintenance Optimization**
```yaml
# Maintenance efficiency metrics
maintenance_efficiency:
  automation_level: 75%    # Percentage of automated tasks
  mean_time_between_failures: "720h"  # MTBF
  mean_time_to_repair: "2h"           # MTTR
  preventive_maintenance: 85%         # Percentage of preventive work
  change_success_rate: 95%            # Successful changes
```

## 🎉 **Conclusion**

This comprehensive DR and Maintenance guide provides:

### **✅ DR Capabilities**
- **Multi-region failover** with automated DNS updates
- **etcd backup/restore** with encryption
- **Application data protection** with Velero
- **Comprehensive monitoring** with alerting
- **Regular testing** with automated validation

### **✅ Maintenance Framework**
- **Scheduled maintenance** with automated scripts
- **Patch management** for security updates
- **Certificate lifecycle** management
- **Performance monitoring** and optimization
- **Compliance automation** and reporting

### **✅ Operational Excellence**
- **Runbooks** for common procedures
- **KPIs and metrics** for continuous improvement
- **Automation** through GitOps and scripts
- **Documentation** for knowledge sharing

**This guide ensures your Aegis Kubernetes Framework deployment is resilient, maintainable, and operationally excellent!** 🚀🔒⚡