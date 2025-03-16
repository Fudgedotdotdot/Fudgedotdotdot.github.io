# Building phishing infrastructure with Terraform and Ansible



## Architecture / Design

Here's a diagram of the architecture. 

<p style="text-align: center;">
<img src="./imgs/design.drawio.svg">
</p>

We are using two separate servers for *redirector* and *evilginx2*, following the usual design for C2 infrastructure. This design prevents *Evilginx2* from being exposed directly on the Internet, and gives us the option to remplace the redirector in case the domain gets flagged without having to redeploy, reconfigure and retest the entire infrastructure.  




We'll see details on each segment later. 


## Terraform and Ansible

We'll use Terraform and Ansible to deploy this design, DevOps teams can't have all the fun. 


I'll skip the Terraform part because the setup will depend on the cloud provider you'll use. 

*Ensure that you configure the instances with an SSH key that is readily available on the machine where you'll be running Ansible.*

The most important part is to setup DNS correctly, in my DigitalOcean config, this looks like this:
```yaml
resource "digitalocean_domain" "domain" {
  name = var.domain_name
}

resource "digitalocean_record" "wildcard" {
  domain = digitalocean_domain.domain.id
  type   = "A"
  name   = "*"
  ttl = 1800
  value  = digitalocean_droplet.evilginx["redirector"].ipv4_address
}

resource "digitalocean_record" "a" {
  domain = digitalocean_domain.domain.id
  type   = "A"
  name   = "@"
  ttl = 1800
  value  = digitalocean_droplet.evilginx["redirector"].ipv4_address
}
```

This will ensure that the domain and subdomains will point to our redirector IP. Notice that we don't use the evilginx server IP or change the NS record. 




For Ansible, we'll discuss the directory structure here, and the details of the main tasks in the next chapters. 

```
.
├── evilginx2.yml
├── hosts.yml
├── redirector.yml
├── site.yml
└── roles
    ├── common
    │   ├── tasks
    │   │   ├── main.yml
    │   │   └── prerequisites.yml
    │   └── vars
    │       └── main.yml
    ├── evilginx
    │   ├── files
    │   │   ├── docker-compose.yml
    │   │   └── evilginx2
    │   │       └── config
    │   │           └── config.j2
    │   ├── tasks
    │   │   ├── firewall.yml
    │   │   ├── generate_certs.yml
    │   │   ├── main.yml
    │   │   ├── prerequisites.yml
    │   │   └── setup_evilginx2.yml
    │   └── vars
    │       └── main.yml
    └── redirector
        ├── files
        │   ├── caddy
        │   │   ├── caddy
        │   │   ├── Caddyfile.j2
        │   │   ├── caddy.service
        │   │   └── filters
        │   │       ├── bad_ips.caddy
        │   │       ├── bad_ua.caddy
        │   │       ├── headers_standard.caddy
        │   │       └── tls.caddy
        │   └── tunnels
        │       └── autossh_https_service.j2
        ├── tasks
        │   ├── firewall.yml
        │   ├── main.yml
        │   ├── setup_caddy.yml
        │   ├── ssh_portfwd.yml
        │   ├── start_caddy.yml
        │   └── webserver.yml
        └── vars
            └── main.yml
```

This recommended directory setup from Ansible helps manage servers with different roles. In this case, the site.xml imports the host playbooks : 
```yaml
- import_playbook: evilginx2.yml
- import_playbook: redirector.yml
```

Each playbook contains the host on which role tasks can be executed. 
```yaml
- hosts: evilginx
  roles:
    - common
    - evilginx
```
Here, we target evilginx hosts with the *common* and *evilginx* roles. In the tree command output above, we can see the *common*, *evilginx* and *redirector* roles. 

Every role directory contains: 
- **files** - for static or template files
- **tasks** - for ansible tasks
- **vars** - for role specific variables

In the task directory, the *main.yml* file will be executed by Ansible automatically. We can split tasks up and use `include_tasks` in *main.yml* to import them. 

```yaml
- include_tasks: prerequisites.yml
- include_tasks: generate_certs.yml
- include_tasks: setup_evilginx2.yml
- include_tasks: firewall.yml
```



This structure also means that we can either configure all the servers using *site.xml* or each individual hosts with their respective playbooks. 

```bash
ansible-playbook -u root -i hosts.yml site.yml
ansible-playbook -u root -i hosts.yml <evilginx2.yml or redirector.yml>
```

Finally, the *hosts.yml* file contains a list of IPs per role :
```yaml
redirector:
  hosts:
    164.92.212.233:
evilginx:
  hosts:
    164.92.210.139:
```




## Redirector

Firstly, we'll configure Caddy as our reverse proxy, here's an example configuration that provides automatic SSL with wildcard support, IP and user-agent denylist and our reverse proxy. 
```yaml
*.{{ domain }}:443 {
	import ./filters/tls.caddy
	encode gzip
	header {
		import ./filters/headers_standard.caddy
	}
	handle {
		@ip_denylist {
		 	import ./filters/bad_ips.caddy
		}
		@ua_denylist {
		 	import ./filters/bad_ua.caddy
		}
		route @ip_denylist {
		 	file_server {
		 		root /var/www/html/{{ domain }}
		 	}
		}
		route @ua_denylist {
		 	file_server {
		 		root /var/www/html/{{ domain }}
		 	}
		}
		handle {
			reverse_proxy https://localhost:8000  {
				header_up Host {http.request.hostport}
				transport http {
					tls_server_name {http.request.hostport} # for SNI
					tls_trust_pool file ca.crt
				}
			}
		}
	}
}

{{ domain }}:443 {
	import ./filters/tls.caddy
	encode gzip
	header {
		import ./filters/headers_standard.caddy
	}
	file_server {
		root /var/www/html/{{ domain }}
	}
}
```
### Reverse Proxy
We need to add a few statements to the *reverse_proxy* option. 


> ***tls_server_name** sets the server name used when verifying the certificate received in the TLS handshake. By default, this will use the upstream address' host part. <p>
You only need to override this if your upstream address does not match the certificate the upstream is likely to use. For example if the upstream address is an IP address, then you would need to configure this to the hostname being served by the upstream server.<p>
A request placeholder may be used, in which case a clone of the HTTP transport config will be used on every request, which may incur a performance penalty.*


> ***trust_pool** configures the source of certificate authorities (CA) providing certificates against which to validate client certificates.*

If we don't set the *SNI* with **tls_server_name**, Evilginx2 receives the request like so: 

ADD CADDY EXAMPLE


We also need to set the **trust_pool** as we generate our own custom certificates in the **Evilginx2** chapter. 



```bash
[Unit]
Description=Forwarding localhost:8000 to remote localhost:8443
After=network-online.target

[Service]
Type=simple
User=root
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
ExecStart=autossh -M 0 -NC -o "ExitOnForwardFailure=yes" -o "ServerAliveInterval=10" -o "ServerAliveCountMax=3" -o "StrictHostKeyChecking=accept-new" -L 127.0.0.1:8000:127.0.0.1:8443 -i ~/.ssh/evilginx2-user evilginx2@{{ evilginx_ip }}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```












Here's part of the Ansible task that uploads the configuration file, and copies the CA cert generated on the evilginx host :
```yaml
- name: Upload Caddyfile
  template:
    src: ../files/caddy/Caddyfile.j2
    dest: /opt/caddy/Caddyfile
    owner: caddy
    group: caddy
    mode: '0644'

- name: Copy CA cert from evilginx
  delegate_to: "{{ groups['evilginx'][0] }}"
  ansible.builtin.slurp:
    src: "/root/certs/ca.crt"
  register: ca_cert

- name: Push CA cert to redirector
  ansible.builtin.copy:
      content: "{{ ca_cert.content | b64decode }}"
      dest: "/opt/caddy/{{ ca_cert.source | basename }}"
```
Since this task will run from the redirector role, we need to use *delegate_to* to target the evilginx host. 












### Fake website

We want to redirect unauthenticated, unwanted and overall mean IPs or user-agents that want our phishing engagements to fail to a fake website. 


```yml
- name: Create webroot directory
  ansible.builtin.file:
    path: /var/www/html/{{ domain }}
    state: directory
    owner: caddy
    group: caddy
    mode: '0744'

- name: Archive the content of the template website
  ansible.builtin.archive:
    path: "{{ role_path }}/files/template_website/{{ website }}/*"
    dest: "{{ role_path }}/files/template_website/{{ website }}.tar.gz"
  delegate_to: localhost

- name: Unarchive template website onto remote host
  ansible.builtin.unarchive:
    src: "{{ role_path }}/files/template_website/{{ website }}.tar.gz"
    dest: /var/www/html/{{ domain }}
    owner: caddy
    group: caddy

- name: Remove local website template archive
  file: 
    path: "../files/template_website/{{ website }}.tar.gz"
    state: absent
  delegate_to: localhost
```
Archiving the entire directory before upload is necessary, otherwise it takes Ansible too long to copy all the files. 






## Evilginx2



Evilginx2 has the option to redirect blacklisted Ips to an unauth URL, protecting your links. Using curl to make a HTTP request from an IP that is blacklisted will return a **200 OK** with this odd HTML body. 
```html
> GET / HTTP/1.1
> Host: academy.testing-domain.ch:8443
> User-Agent: curl/7.88.1
> Accept: */*
>
< HTTP/1.1 200 OK
< Cache-Control: no-cache, no-store
< Connection: close
< Content-Type: text/html
< Transfer-Encoding: chunked

<html><head><meta name='referrer' content='no-referrer'><script>top.location.href='https://www.youtube.com/watch?v=dQw4w9WgXcQ';</script></head><body></body></html>
```

Searching Google and Shodan for this HTML doesn't return any interesting results, but Github search finds this :


![github_search](./imgs/github_search.png)




We should change the code in *http_proxy.go* to return a 301 :

![redirect](./imgs/redirect.png)



Now this looks like a normal **301 Moved Permanently** :
```
> GET / HTTP/1.1
> Host: academy.testing-domain.ch:8443
> User-Agent: curl/7.88.1
> Accept: */*
>
< HTTP/1.1 301 Moved Permanently
< Cache-Control: no-cache, no-store
< Connection: close
< Content-Type: text/html
< Location: https://www.youtube.com/watch?v=dQw4w9WgXcQ
< Transfer-Encoding: chunked
```

