# 🚀 Deploy n8n on Oracle Cloud Free Tier with HTTPS

This guide helps you deploy [n8n](https://n8n.io) for free on Oracle Cloud using the Always Free Tier with an ARM-based VM.
This deployment automatically configures n8n with Nginx as a reverse proxy, enabling HTTPS using a self-signed SSL certificate.

> **Security by Default**
> This setup prioritizes security by:
> - Running n8n behind an Nginx reverse proxy.
> - Enabling HTTPS (TLS) for all n8n traffic using a self-signed certificate.
> - Configuring n8n with secure cookie settings.
> - Restricting direct public access to the n8n application port.

---

## 📦 Requirements

- A free Oracle Cloud account → [Sign up](https://www.oracle.com/cloud/free/)
- A private SSH key to access your VM.
- **Terraform Variables**: You will need to provide `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD` during the Terraform deployment process. These will be the credentials to access your n8n instance.
- Use of the **Always Free Tier** (ARM): VM.Standard.A1.Flex with:
  - 1 OCPU
  - 6 GB RAM
  - 50 GB block storage (default, can be increased)

When creating your Oracle Cloud account, you must provide a valid credit card for identity verification. You won't be charged as long as you stay within the Always Free tier.

This project uses the `VM.Standard.A1.Flex` instance type, which is part of the Always Free tier with the following limits:
- **4 OCPUs**
- **24 GB RAM**
- **2 VMs max per tenancy**

n8n will run comfortably within those limits.

---

## ☁️ Deploy to Oracle Cloud

You can use the button below to provision the instance and network infrastructure:

[![Deploy to Oracle Cloud](https://github.com/clementalo9/oke_A1/raw/main/images/Deploy2OCI.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/pedrohbps/n8n_oci/archive/refs/heads/main.zip)

Terraform provisions the VM and associated network infrastructure. It then uses cloud-init with the [`scripts/install_n8n.sh`](scripts/install_n8n.sh) script to:
- Install Docker and Docker Compose.
- Install Nginx.
- Generate a self-signed SSL certificate.
- Configure Nginx as a reverse proxy for n8n, handling HTTPS.
- Create and run n8n via Docker Compose, using the credentials you provide as Terraform variables.

## 🔌 Ports Opened by Terraform

The Terraform stack creates a security list that allows inbound traffic on the following ports:

- **22 (SSH)**: For administrative access to the VM.
- **443 (HTTPS)**: For accessing your n8n instance via Nginx.

HTTP (port 80) and the direct n8n port (5678) are **not** publicly exposed for enhanced security. Nginx handles HTTP to HTTPS redirection internally if any HTTP request were to reach it (though port 80 is not open externally).

You can review these rules in [`terraform/main.tf`](terraform/main.tf) inside the `oci_core_security_list` resource.

If you want to connect via SSH to your VM, use the default **ubuntu** user and provide the private key you used during stack creation:

```bash
ssh -i /path/to/your/private_key ubuntu@YOUR_PUBLIC_IP
```

---

## 🌐 Access Your n8n Editor

Once the deployment is complete:

1.  Go to your browser and open:
    ```
    https://YOUR_PUBLIC_IP
    ```
2.  **SSL Certificate Warning**: Your browser will display a warning because the instance uses a self-signed SSL certificate. You will need to accept the warning (e.g., click "Advanced" then "Proceed to ...") to continue. For production use, replace this with a CA-issued certificate (see "Production Readiness" below).
3.  **Authentication**: You will be prompted for a username and password. Use the `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD` you provided during the Terraform deployment.

> **File Locations on VM**: The `install_n8n.sh` script runs in the `ubuntu` user's home directory (`/home/ubuntu`). You will find the `docker-compose.yml` file and the `n8n_data/` volume directory there. Nginx configurations are in `/etc/nginx/`. The self-signed SSL certificate and key are located in `/etc/nginx/ssl/`.

---

## 🔒 Important Security Notes & Production Readiness

*   **Terraform Credentials**: The `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD` variables you define for Terraform are sensitive. Manage them securely, especially if using CI/CD systems or shared Terraform configurations. Consider using a secrets manager.
*   **Self-Signed SSL Certificate**: The default setup uses a self-signed SSL certificate for HTTPS. This is fine for initial setup or private testing, but **it is crucial to replace it with a certificate from a trusted Certificate Authority (CA) for any production or public-facing deployment.** Browsers will show warnings for self-signed certificates, and they don't provide the same level of trust as CA-issued certificates.
    *   The installation script (`scripts/install_n8n.sh`) provides the paths to the self-signed certificate (`n8n.crt`) and key (`n8n.key`) within the Nginx configuration.
    *   To use a CA-issued certificate (e.g., from Let's Encrypt), you would typically:
        1.  Obtain a domain name and point it to your instance's public IP.
        2.  Use a tool like Certbot with Nginx to obtain and install an SSL certificate.
        3.  Update the `ssl_certificate` and `ssl_certificate_key` directives in the Nginx configuration (`/etc/nginx/sites-available/n8n`) to point to your new CA-issued certificate files.
        4.  Restart Nginx: `sudo systemctl restart nginx`.
    *   The existing [`docs/nginx-ssl.md`](docs/nginx-ssl.md) guide may offer helpful steps for setting up a custom domain and obtaining a CA certificate, though some Nginx setup steps are now automated by the main installation script.
*   **n8n Encryption Key**: For enhanced security of your n8n credentials, consider setting the `N8N_ENCRYPTION_KEY` environment variable in the `docker-compose.yml` file generated on the server. Ensure you back up this key securely.
*   **Regular Updates**: Keep your VM, Docker, Nginx, and n8n updated to patch security vulnerabilities.

---

## 🔧 Customizing the Deployment

*   **n8n Version**: The `docker-compose.yml` generated by the script uses `n8nio/n8n` which defaults to the latest stable version. You can specify a version tag (e.g., `n8nio/n8n:0.220.1`) if needed.
*   **Instance Shape & Storage**: Modify `terraform/main.tf` to change the instance shape or storage size if your needs differ (ensure you stay within Always Free tier limits if desired).
*   **Timezone**: The `GENERIC_TIMEZONE` environment variable for n8n is set to `Europe/Madrid` in `scripts/install_n8n.sh`. Change this to your preferred timezone.


