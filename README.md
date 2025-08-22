# 🚀 Deploy n8n on Oracle Cloud Free Tier

This guide helps you deploy [n8n](https://n8n.io) for free on Oracle Cloud using the Always Free Tier with an ARM-based VM.
You don’t need a domain name or SSL, but both can be added optionally for production use.

> **Production note**
> For a secure setup, it is highly recommended to run n8n behind an NGINX reverse proxy with HTTPS enabled. This protects the login cookie and other traffic. See [docs/nginx-ssl.md](docs/nginx-ssl.md) for instructions.

---

## 📦 Requirements

- A free Oracle Cloud account → [Sign up](https://www.oracle.com/cloud/free/)
- A private SSH key to access your VM
- Use of the **Always Free Tier** (ARM): VM.Standard.A1.Flex with:
  - 1 OCPU
  - 6 GB RAM
  - 50 GB block storage

When creating your Oracle Cloud account, you must provide a valid credit card for identity verification. You won't be charged as long as you stay within the Always Free tier.

This project uses the `VM.Standard.A1.Flex` instance type, which is part of the Always Free tier with the following limits:
- **4 OCPUs**
- **24 GB RAM**
- **2 VMs max per tenancy**

n8n will run comfortably within those limits.

---

## ☁️ Deploy to Oracle Cloud

You can use the button below to provision the instance and network infrastructure:

[![Deploy to Oracle Cloud](https://github.com/clementalo9/oke_A1/raw/main/images/Deploy2OCI.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/clementalo9/n8n_oci/archive/refs/heads/main.zip)

---
## 🛠️ Manual Deployment with Terraform

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](
  https://cloud.oracle.com/resourcemanager/stacks/create?region=home&zipUrl=https://github.com/vongrossi/n8n_oci/archive/refs/heads/main.zip
)


Terraform provisions the VM, installs Docker, and install n8n automatically via
[`scripts/install_n8n.sh`](scripts/install_n8n.sh). 

## 🔌 Ports Opened by Terraform

The Terraform stack creates a security list that allows inbound traffic on the following ports:

- **22** – SSH access to administer the VM.
- **80** – HTTP traffic, required if you plan to run a reverse proxy or obtain certificates with Certbot.
- **443** – HTTPS traffic once you configure SSL for n8n.
- **5678** – The n8n editor listens on this port.

You can review these rules in [`terraform/main.tf`](terraform/main.tf) inside the `oci_core_security_list` resource.

Once deployment completes, continue below to access your n8n editor.

If you want to connect via SSH to you VM, use the default **ubuntu** user and provide the private key you used during stack creation:

```bash
ssh -i /path/to/private/key ubuntu@YOUR_PUBLIC_IP
```

---

## 🌐 Access Your n8n Editor

- Go to your browser and open:

```
 http://YOUR_PUBLIC_IP:5678/setup
```

> On first run, connecting to `http://YOUR_PUBLIC_IP:5678/setup` allows you to create your own credentials.
> **Note:** During automatic deployment the script changes to the root user's home directory, so `docker-compose.yml` and the `n8n_data/` folder will be inside `/root`.

---

## 🔒 Optional: Enable HTTPS with a Custom Domain Name

By default, n8n is accessible via:

```
http://YOUR_PUBLIC_IP:5678
```

This is sufficient to work with n8n which does **not** require a domain name or reverse proxy. But for security reason, I strongly recommand the use of HTTPS (domain name required) and NGINX

See [`docs/nginx-ssl.md`](docs/nginx-ssl.md) for help with domain, NGINX setup, and HTTPS.


