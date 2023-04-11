# Ansible Automation Platform 2 Infrastructure as Code Workflow Job

> This repo serves as the base framework to support IaC with ZTP via AAP2 Workflow Jobs.  You can find them in the `ansible/extra-playbooks` directory.

## Supporting Playbooks > Templates

- `pre-aj_set-survey-facts.yaml` - **Preflight Job, Set Survey Facts**
  Converts the human-friendly survey variables into other relevant facts for use in the automation.

- `pre-aj_preflight.yaml` - **Preflight Job, Pre-Flight Checks**
  Performs pre-flight checks to ensure the environment is ready for the automation.

- `pre-aj_setup-ipam.yaml` - **Preflight Job, Setup IPAM**
  Placeholder job that could be used to query something like a BlueCat, InfoBlox, etc system to request an IP or two.  Useful in IaC scenarios where you need to request an IP address or two for the cluster VIPs.  This step is also something that could be easily retooled and used to request a Load Balancer instead of VIPs from an F5 or similar.

- `pre-aj_setup-dns.yaml` - **Preflight Job, Setup DNS**
  Placeholder job that could be used to query something like a BlueCat, Windows AD DNS, etc system to request a DNS record or few, for instance to point to the IPs retrieved by the previous IPAM job.