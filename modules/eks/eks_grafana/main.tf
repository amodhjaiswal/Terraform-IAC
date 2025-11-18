# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# S3 bucket for Loki logs
resource "aws_s3_bucket" "loki_logs" {
  count = var.create_monitoring ? 1 : 0
  
  bucket        = "${var.project_name}-${var.env_name}-loki-logs"
  force_destroy = true
  
  tags = {
    Name        = "${var.project_name}-${var.env_name}-loki-logs"
    Environment = var.env_name
    ManagedBy   = "terraform"
    Purpose     = "loki-logs-storage"
  }
}

resource "aws_s3_bucket_versioning" "loki_logs" {
  count = var.create_monitoring ? 1 : 0
  
  bucket = aws_s3_bucket.loki_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_logs" {
  count = var.create_monitoring ? 1 : 0
  
  bucket = aws_s3_bucket.loki_logs[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "loki_logs" {
  count = var.create_monitoring ? 1 : 0
  
  bucket = aws_s3_bucket.loki_logs[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  count = var.create_monitoring ? 1 : 0
  
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "monitoring"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.env_name
    }
  }
}

# EBS CSI Driver IAM Policy
resource "aws_iam_policy" "ebs_csi_policy" {
  count = var.create_monitoring ? 1 : 0
  
  name        = "${var.project_name}-${var.env_name}-ebs-csi-policy"
  description = "EBS CSI Driver policy for ${var.project_name}-${var.env_name}"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.env_name}-ebs-csi-policy"
    Environment = var.env_name
    ManagedBy   = "terraform"
  }
}

# EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_role" {
  count = var.create_monitoring ? 1 : 0
  
  name = "${var.project_name}-${var.env_name}-ebs-csi-driver-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.env_name}-ebs-csi-driver-role"
    Environment = var.env_name
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment" {
  count = var.create_monitoring ? 1 : 0
  
  role       = aws_iam_role.ebs_csi_role[0].name
  policy_arn = aws_iam_policy.ebs_csi_policy[0].arn
}

# EBS CSI Driver Addon
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.create_monitoring ? 1 : 0
  
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.35.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_role[0].arn
  resolve_conflicts_on_create = "OVERWRITE"
  
  tags = {
    Name        = "${var.project_name}-${var.env_name}-ebs-csi-addon"
    Environment = var.env_name
    ManagedBy   = "terraform"
  }
  
  depends_on = [aws_iam_role.ebs_csi_role]
}

# GP3 Storage Class
resource "kubernetes_storage_class" "gp3" {
  count = var.create_monitoring ? 1 : 0
  
  metadata {
    name = var.storage_class_name
    labels = {
      "app.kubernetes.io/name"       = "gp3-storage-class"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Retain"
  volume_binding_mode   = "Immediate"
  allow_volume_expansion = true
  
  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    encrypted  = "true"
    iopsPerGB  = "50"
    throughput = "125"
  }
  
  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Loki S3 IAM Policy
resource "aws_iam_policy" "loki_s3_policy" {
  count = var.create_monitoring ? 1 : 0
  
  name        = "${var.project_name}-${var.env_name}-loki-s3-policy"
  description = "S3 access policy for Loki"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.loki_logs[0].arn,
          "${aws_s3_bucket.loki_logs[0].arn}/*"
        ]
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.env_name}-loki-s3-policy"
    Environment = var.env_name
    ManagedBy   = "terraform"
  }
}

# Loki IAM Role
resource "aws_iam_role" "loki_role" {
  count = var.create_monitoring ? 1 : 0
  
  name = "${var.project_name}-${var.env_name}-loki-s3-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:monitoring:loki-sa"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-${var.env_name}-loki-s3-role"
    Environment = var.env_name
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "loki_s3_policy_attachment" {
  count = var.create_monitoring ? 1 : 0
  
  role       = aws_iam_role.loki_role[0].name
  policy_arn = aws_iam_policy.loki_s3_policy[0].arn
}

# Loki Service Account
resource "kubernetes_service_account" "loki" {
  count = var.create_monitoring ? 1 : 0
  
  metadata {
    name      = "loki-sa"
    namespace = "monitoring"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.loki_role[0].arn
    }
    labels = {
      "app.kubernetes.io/name"       = "loki"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [
    kubernetes_namespace.monitoring,
    aws_iam_role.loki_role
  ]
}

# Loki Helm Release
resource "kubernetes_persistent_volume_claim" "promtail" {
  count = var.create_monitoring ? 1 : 0
  
  metadata {
    name      = "${var.project_name}-${var.env_name}-promtail-pvc"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "promtail"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3"
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
  
  depends_on = [kubernetes_storage_class.gp3]
}

resource "helm_release" "promtail" {
  count = var.create_monitoring ? 1 : 0
  
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.16.6"
  namespace  = var.namespace
  timeout    = 300
  
  create_namespace = false
  
  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://loki-gateway.${var.namespace}.svc.cluster.local/loki/api/v1/push"
          }
        ]
        scrape_configs = [
          {
            job_name = "kubernetes-pods"
            kubernetes_sd_configs = [
              {
                role = "pod"
              }
            ]
            relabel_configs = [
              {
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                action = "keep"
                regex = "true"
              },
              {
                source_labels = ["__meta_kubernetes_namespace"]
                target_label = "namespace"
              },
              {
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label = "pod"
              },
              {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                target_label = "container"
              },
              {
                source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
                target_label = "__path__"
                separator = "/"
                replacement = "/var/log/pods/*$1/*.log"
              }
            ]
          }
        ]
      }
      resources = {
        limits = {
          cpu = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu = "100m"
          memory = "128Mi"
        }
      }
      persistence = {
        enabled = true
        storageClassName = "gp3"
        size = "10Gi"
      }
    })
  ]
  
  depends_on = [
    helm_release.loki,
    kubernetes_persistent_volume_claim.promtail
  ]
}

resource "helm_release" "loki" {
  count = var.create_monitoring ? 1 : 0
  
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.16.0"
  namespace  = var.namespace
  timeout    = 600
  
  create_namespace = false
  force_update     = true
  replace          = true
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  wait_for_jobs    = true
  
  values = [
    yamlencode({
      deploymentMode = "SingleBinary"
      loki = {
        auth_enabled = false
        server = {
          grpc_server_max_recv_msg_size = 104857600
          grpc_server_max_send_msg_size = 104857600
          log_level = "info"
        }
        memberlist = {
          join_members = ["loki-memberlist"]
        }
        commonConfig = {
          path_prefix = "/var/loki"
          replication_factor = 1
        }
        storage = {
          type = "s3"
          bucketNames = {
            chunks = aws_s3_bucket.loki_logs[0].bucket
            ruler = aws_s3_bucket.loki_logs[0].bucket
            admin = aws_s3_bucket.loki_logs[0].bucket
          }
          s3 = {
            region = var.region
            s3ForcePathStyle = false
            insecure = false
          }
        }
        storage_config = {
          aws = {
            region = var.region
            bucketnames = aws_s3_bucket.loki_logs[0].bucket
            s3forcepathstyle = false
            insecure = false
          }
          tsdb_shipper = {
            active_index_directory = "/var/loki/tsdb-index"
            cache_location = "/var/loki/tsdb-cache"
            cache_ttl = "24h"
          }
        }
        schemaConfig = {
          configs = [
            {
              from = "2024-04-01"
              store = "tsdb"
              object_store = "s3"
              schema = "v13"
              index = {
                prefix = "loki_index_"
                period = "24h"
              }
            }
          ]
        }
        ingester = {
          chunk_encoding = "snappy"
          lifecycler = {
            ring = {
              kvstore = {
                store = "memberlist"
              }
              replication_factor = 1
            }
          }
        }
        distributor = {
          ring = {
            kvstore = {
              store = "memberlist"
            }
          }
        }
        limits_config = {
          allow_structured_metadata = true
          volume_enabled = true
          retention_period = var.loki_retention_period
          reject_old_samples = true
          reject_old_samples_max_age = "168h"
          max_cache_freshness_per_query = "10m"
          split_queries_by_interval = "15m"
          query_timeout = "300s"
          ingestion_rate_mb = 50
          ingestion_burst_size_mb = 100
        }
        querier = {
          max_concurrent = 10
        }
        query_range = {
          align_queries_with_step = true
        }
        compactor = {
          working_directory = "/var/loki/compactor"
        }
        pattern_ingester = {
          enabled = true
        }
        tracing = {
          enabled = true
        }
      }
      
      # Chunks Cache (Memcached) Configuration
      chunksCache = {
        enabled = true
        replicas = 2
        resources = {
          limits = {
            cpu = "250m"
            memory = "1Gi"
          }
          requests = {
            cpu = "250m"
            memory = "1Gi"
          }
        }
        args = [
          "-m", "1024",
          "--extended=modern,track_sizes",
          "-I", "5m",
          "-c", "16384",
          "-v",
          "-u", "11211"
        ]
        exporter = {
          enabled = true
          resources = {
            limits = {
              cpu = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu = "50m"
              memory = "64Mi"
            }
          }
        }
      }
      
      singleBinary = {
        replicas = 2
        persistence = {
          enabled = true
          storageClass = "gp3"
          accessModes = ["ReadWriteOnce"]
          size = var.loki_storage_size
        }
        extraEnv = [
          {
            name = "AWS_STS_REGIONAL_ENDPOINTS"
            value = "regional"
          },
          {
            name = "AWS_DEFAULT_REGION"
            value = var.region
          },
          {
            name = "AWS_REGION"
            value = var.region
          },
          {
            name = "AWS_S3_FORCE_PATH_STYLE"
            value = "false"
          }
        ]
        resources = {
          requests = {
            cpu = "50m"
            memory = "256Mi"
          }
          limits = {
            cpu = "500m"
            memory = "1Gi"
          }
        }
      }
      chunksCache = {
        enabled = true
        replicas = 1
        resources = {
          requests = {
            cpu = "50m"
            memory = "256Mi"
          }
          limits = {
            cpu = "250m"
            memory = "512Mi"
          }
        }
        args = [
          "-m 512",
          "--extended=modern,track_sizes",
          "-I 5m",
          "-c 16384",
          "-v",
          "-u 11211"
        ]
        exporter = {
          enabled = true
          resources = {
            requests = {
              cpu = "25m"
              memory = "32Mi"
            }
            limits = {
              cpu = "50m"
              memory = "64Mi"
            }
          }
        }
      }
      resultsCache = {
        enabled = false
      }
      # Zero out other deployment modes
      backend = { replicas = 0 }
      read = { replicas = 0 }
      write = { replicas = 0 }
      gateway = { 
        enabled = true
        replicas = 1
        resources = {
          requests = {
            cpu = "25m"
            memory = "64Mi"
          }
          limits = {
            cpu = "100m"
            memory = "128Mi"
          }
        }
      }
      ingester = { replicas = 0 }
      querier = { replicas = 0 }
      queryFrontend = { replicas = 0 }
      queryScheduler = { replicas = 0 }
      distributor = { replicas = 0 }
      compactor = { replicas = 0 }
      indexGateway = { replicas = 0 }
      bloomCompactor = { replicas = 0 }
      bloomGateway = { replicas = 0 }
      minio = { enabled = false }
      test = { enabled = false }
      lokiCanary = { enabled = false }
      minio = { enabled = false }
      test = { enabled = false }
      lokiCanary = { enabled = false }
      serviceAccount = {
        create = false
        name = "loki-sa"
      }
      rbac = {
        create = true
        rules = [
          {
            apiGroups = [""]
            resources = ["pods", "services", "endpoints", "configmaps", "secrets"]
            verbs = ["get", "list", "watch"]
          },
          {
            apiGroups = [""]
            resources = ["nodes"]
            verbs = ["get", "list", "watch"]
          },
          {
            apiGroups = [""]
            resources = ["persistentvolumeclaims"]
            verbs = ["create", "delete", "get", "list", "watch"]
          }
        ]
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_service_account.loki,
    kubernetes_storage_class.gp3,
    aws_s3_bucket.loki_logs
  ]
}
# Prometheus PVC
resource "kubernetes_persistent_volume_claim" "prometheus" {
  count = var.create_monitoring ? 1 : 0
  
  metadata {
    name      = "${var.project_name}-${var.env_name}-prometheus-pvc"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "prometheus"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name
    
    resources {
      requests = {
        storage = var.prometheus_storage_size
      }
    }
  }
  
  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_storage_class.gp3
  ]
}

# Prometheus Helm Release
resource "helm_release" "prometheus" {
  count = var.create_monitoring ? 1 : 0
  
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.1.1"
  namespace  = var.namespace
  timeout    = 600
  
  create_namespace = false
  
  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class_name
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorSelector = {}
          serviceMonitorNamespaceSelector = {}
          ruleSelectorNilUsesHelmValues = false
          ruleSelector = {}
          ruleNamespaceSelector = {}
        }
      }
      grafana = {
        enabled = false
      }
      kubeStateMetrics = {
        enabled = true
      }
      nodeExporter = {
        enabled = true
      }
      prometheusNodeExporter = {
        enabled = true
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_persistent_volume_claim.prometheus
  ]
}

# Grafana Helm Release
resource "helm_release" "grafana" {
  count = var.create_monitoring ? 1 : 0
  
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "8.5.1"
  namespace  = var.namespace
  
  create_namespace = false
  
  values = [
    yamlencode({
      adminPassword = var.grafana_admin_password
      service = {
        type = "ClusterIP"
        port = 80
      }
      persistence = {
        enabled = true
        size = var.grafana_storage_size
        storageClassName = var.storage_class_name
      }
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name = "Prometheus"
              type = "prometheus"
              url = "http://prometheus-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090"
              access = "proxy"
              isDefault = true
              jsonData = {
                timeInterval = "30s"
              }
            },
            {
              name = "Loki"
              type = "loki"
              url = "http://loki-gateway.${var.namespace}.svc.cluster.local"
              access = "proxy"
              jsonData = {
                maxLines = 1000
              }
            }
          ]
        }
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name = "default"
              orgId = 1
              folder = ""
              type = "file"
              disableDeletion = false
              editable = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }
      dashboards = {
        default = {
          node-exporter-full = {
            gnetId = 1860
            revision = 37
            datasource = "Prometheus"
          }
          kubernetes-cluster-monitoring = {
            gnetId = 15661
            revision = 12
            datasource = "Prometheus"
          }
          loki-logs = {
            gnetId = 13639
            datasource = "Loki"
          }
        }
      }
      sidecar = {
        dashboards = {
          enabled = false
        }
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.loki,
    helm_release.prometheus
  ]
}

# Cleanup resource
resource "null_resource" "monitoring_cleanup" {
  count = var.create_monitoring ? 1 : 0
  
  triggers = {
    namespace = var.namespace
    project_name = var.project_name
    env_name = var.env_name
  }
  
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "=== Starting Monitoring Cleanup ==="
      
      # Delete Helm releases
      helm uninstall grafana -n ${self.triggers.namespace} --ignore-not-found || true
      helm uninstall prometheus -n ${self.triggers.namespace} --ignore-not-found || true
      helm uninstall promtail -n ${self.triggers.namespace} --ignore-not-found || true
      helm uninstall loki -n ${self.triggers.namespace} --ignore-not-found || true
      
      # Delete PVCs
      kubectl delete pvc ${self.triggers.project_name}-${self.triggers.env_name}-grafana-pvc -n ${self.triggers.namespace} --ignore-not-found=true || true
      kubectl delete pvc ${self.triggers.project_name}-${self.triggers.env_name}-prometheus-pvc -n ${self.triggers.namespace} --ignore-not-found=true || true
      kubectl delete pvc ${self.triggers.project_name}-${self.triggers.env_name}-promtail-pvc -n ${self.triggers.namespace} --ignore-not-found=true || true
      
      # Wait for cleanup
      sleep 30
      
      echo "=== Monitoring Cleanup Completed ==="
    EOT
  }
  
  depends_on = [
    helm_release.grafana,
    helm_release.prometheus,
    helm_release.loki
  ]
}