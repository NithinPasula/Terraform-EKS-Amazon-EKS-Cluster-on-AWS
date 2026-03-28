# Terraform EKS — Amazon EKS Cluster on AWS

Provision a production-ready **Amazon EKS cluster** on AWS using Terraform. This project automates the full stack: VPC networking, EKS control plane, managed node groups, IAM roles, and security groups — all declared as infrastructure-as-code.

---

## Architecture Overview

<img width="1440" height="1440" alt="image" src="https://github.com/user-attachments/assets/c1d00658-210f-46fc-b266-2ca4bff39953" />

---

## Prerequisites

Before getting started, ensure the following tools are installed on your local machine:

| Tool | Version | Link |
|------|---------|------|
| AWS CLI | v2.x | [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | >= 1.3.0 | [Install](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| kubectl | >= 1.27 | [Install](https://kubernetes.io/docs/tasks/tools/) |
| Git | latest | [Install](https://git-scm.com/) |

You will also need an **AWS account** with sufficient IAM permissions to create VPCs, EKS clusters, EC2 instances, IAM roles, and related resources.

---

## Repository Structure

```
terraform-eks/
├── main.tf            # Root module — providers and backend config
├── vpc.tf             # VPC, subnets, route tables, IGW, NAT Gateway
├── eks.tf             # EKS cluster and managed node group resources
├── iam.tf             # IAM roles and policy attachments
├── security-groups.tf # Security group rules for control plane and nodes
├── variables.tf       # Input variable declarations
├── outputs.tf         # Exported values (cluster endpoint, kubeconfig, etc.)
└── terraform.tfvars   # (Optional) Variable values — DO NOT commit secrets
```

---

## Terraform Resources Provisioned

### Networking (`vpc.tf`)
- **VPC** with a configurable CIDR block (default `10.0.0.0/16`)
- **Public subnets** across 2 Availability Zones with auto-assign public IP
- **Private subnets** across 2 Availability Zones for worker nodes
- **Internet Gateway** for public subnet egress
- **NAT Gateway** (in the public subnet) for private subnet egress
- **Route Tables** — public routes to IGW, private routes to NAT GW

### EKS Cluster (`eks.tf`)
- **EKS Control Plane** with a configurable Kubernetes version
- **Managed Node Group** using EC2 instances (e.g. `t3.medium`) in private subnets
- **Auto Scaling Group** for worker nodes with configurable min/max/desired counts
- **Launch Template** for node configuration

### IAM (`iam.tf`)
- **EKS Cluster Role** — allows the EKS service to manage AWS resources
- **EKS Node Role** — attached to worker EC2 instances
- **Managed Policy Attachments**:
  - `AmazonEKSClusterPolicy`
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEC2ContainerRegistryReadOnly`
  - `AmazonEKS_CNI_Policy`

### Security Groups (`security-groups.tf`)
- **Control Plane SG** — inbound from node SG on port 443, outbound to nodes
- **Node SG** — inbound from control plane and between nodes, outbound all
- **ALB SG** (optional) — HTTP/HTTPS from internet

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/NithinPasula/terraform-eks.git
cd terraform-eks
```

### 2. Configure AWS credentials

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (e.g. us-east-1), Output format (json)
```

### 3. Initialise Terraform

This downloads the required providers and modules.

```bash
terraform init
```

### 4. Review the plan

Inspect all resources that will be created before applying.

```bash
terraform plan
```

### 5. Apply the configuration

This will provision all AWS resources (~10–15 minutes).

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 6. Configure kubectl

Once the cluster is up, update your local kubeconfig:

```bash
aws eks update-kubeconfig \
  --region <your-region> \
  --name <your-cluster-name>
```

### 7. Verify the cluster

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Configuration

Edit `variables.tf` or create a `terraform.tfvars` file to customise the deployment:

```hcl
# terraform.tfvars

aws_region       = "us-east-1"
cluster_name     = "my-eks-cluster"
kubernetes_version = "1.29"

vpc_cidr         = "10.0.0.0/16"
public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

instance_type    = "t3.medium"
desired_capacity = 2
min_capacity     = 1
max_capacity     = 4
```

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region to deploy into |
| `cluster_name` | `eks-cluster` | Name of the EKS cluster |
| `kubernetes_version` | `1.29` | Kubernetes version |
| `vpc_cidr` | `10.0.0.0/16` | CIDR block for the VPC |
| `instance_type` | `t3.medium` | EC2 instance type for worker nodes |
| `desired_capacity` | `2` | Default number of worker nodes |
| `min_capacity` | `1` | Minimum nodes in Auto Scaling Group |
| `max_capacity` | `4` | Maximum nodes in Auto Scaling Group |

---

## Outputs

After a successful `terraform apply`, the following values are exported:

| Output | Description |
|--------|-------------|
| `cluster_name` | The name of the EKS cluster |
| `cluster_endpoint` | API server endpoint URL |
| `cluster_certificate_authority` | Base64-encoded CA certificate |
| `kubeconfig_command` | The `aws eks update-kubeconfig` command to run |
| `vpc_id` | ID of the created VPC |
| `node_group_arn` | ARN of the managed node group |

Retrieve outputs at any time:

```bash
terraform output
terraform output cluster_endpoint
```

---

## Destroying the Infrastructure

To tear down all provisioned resources:

```bash
terraform destroy
```

> **Warning:** This is irreversible. All data, nodes, and cluster state will be deleted.

---

## Cost Considerations

Running this configuration in `us-east-1` incurs the following approximate costs:

| Resource | Approximate Cost |
|----------|-----------------|
| EKS Control Plane | ~$0.10/hour ($72/month) |
| EC2 t3.medium × 2 | ~$0.10/hour total |
| NAT Gateway | ~$0.045/hour + data processing |
| EBS volumes (nodes) | ~$0.10/GB/month |

> Always run `terraform destroy` when the cluster is no longer needed to avoid unexpected charges.

---

## Troubleshooting

**Nodes not joining the cluster**  
Ensure the `aws-auth` ConfigMap is correctly configured. EKS managed node groups handle this automatically, but for self-managed nodes you may need to apply it manually.

**`kubectl` connection refused**  
Re-run `aws eks update-kubeconfig` and verify the `KUBECONFIG` environment variable is set, or that `~/.kube/config` has been updated.

**Terraform state errors**  
If you encounter state lock issues, check for a running `terraform` process or manually release the lock:
```bash
terraform force-unlock <LOCK_ID>
```

**IAM permission errors**  
Ensure your AWS user/role has `eks:*`, `ec2:*`, `iam:*`, and `elasticloadbalancing:*` permissions.

---

## Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-improvement`)
3. Commit your changes (`git commit -m 'Add feature'`)
4. Push to the branch (`git push origin feature/my-improvement`)
5. Open a Pull Request

---

## License

This project is open source. See [LICENSE](LICENSE) for details.

---

## References

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)
