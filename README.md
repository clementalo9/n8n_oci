# n8n on Oracle Cloud (Always Free)

> One-click deployment of n8n on Oracle Cloud Free Tier.

[![Deploy to Oracle Cloud](https://github.com/clementalo9/oke_A1/blob/main/images/Deploy2OCI.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/clementalo9/n8n_oci/archive/refs/heads/main.zip)

## ✨ Features
- Runs on VM.Standard.A1.Flex (ARM, free tier)
- Public IP access on port 5678
- SSH access on port 22
- Basic auth enabled out of the box
- Deployable via Oracle Cloud Resource Manager or Terraform CLI

## 📝 Prerequisites
You must first create a free Oracle Cloud account here:
👉 https://www.oracle.com/cloud/free/

Oracle requires a valid credit card for identity verification, but as long as you stay in the Always Free tier, you will not be charged.

This project uses the `VM.Standard.A1.Flex` instance type, which is included in the Always Free tier with the following limits:
- **4 OCPUs**
- **24 GB RAM**
- **2 VMs max per tenancy**

n8n will run comfortably within those limits.

## 🚀 Quick Deploy (recommended)
Click the button above to deploy automatically in your Oracle tenancy.

1. Log into your Oracle Cloud account
2. Select your compartment
3. Launch the stack and follow the prompts
   (Resource Manager will ask for your `ssh_public_key`)

## 🔧 Manual Deployment
```bash
git clone https://github.com/clementalo9/n8n_oci.git
cd n8n_oci/terraform
terraform init
terraform apply
```

### Tenancy OCID
When running `terraform apply` manually, pass your tenancy OCID:

```bash
terraform apply -var "tenancy_ocid=<your-tenancy-ocid>"
```

Oracle Resource Manager sets this variable automatically when deploying via the console.

### Image
The stack automatically retrieves the latest **Ubuntu 22.04** image, so no image
OCID needs to be provided when deploying manually.

The provisioning script removes the default `opc` user if present so that only the
`ubuntu` account remains for SSH access.

## 🔐 Default Credentials
- Username: `admin`
- Password: `strongpassword`

> Change them in `docker-compose.yml` after first deployment.

### VM Credentials
The virtual machine uses the default `opc` user with SSH key authentication.
Provide your `ssh_public_key` when launching the stack to allow SSH access.

## 🌐 Accessing n8n
Go to `http://<your-instance-public-ip>:5678`

✅ Optional: You may configure a custom domain and SSL certificate with Certbot. While not required, it is strongly recommended for production.

## 📂 Structure
 - `terraform/`: OCI resources (VCN, subnet, instance)
 - `scripts/`: Cloud-init script with Docker + n8n setup
 - `backend/`: Express server for sending email and SMS notifications
 - `frontend/`: Example page using notifications.js to call the backend

## 🛡️ SSL/TLS (optional)
You need a domain name to use Let's Encrypt. We recommend [DuckDNS](https://www.duckdns.org) for a free domain name and simple DNS.

## 📜 License
MIT

---

## ✅ Final Check
- Ports 22, 80, 443 and 5678 must be open
- Public IP provided by OCI is sufficient to access the UI
- Domain + SSL optional but recommended for production
