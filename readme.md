# Note 
As of ~ May 2024 is k8s deplotment depricated, can't guaratee it will work. Charts are still released at [Fleetdm](https://github.com/fleetdm/fleet/tree/main/charts/fleet)/.

# Intro
Let's deploy *Fleetdm* into Kubernetes using *k3d*, setup agent into *Vagrant* vm and create *Github CI/CD* pipeline to manage Fleetdm recources.

# Prerequsities
K8s: install k3d, Helm and Kubectl.  
Vagrant: install Vagrant, Virtualbox (7.0.x. - newest compatible with Vagrant).  
CI/CD: install ngrok (exposing Fleetdm).

# Create environment
## k3d
k3d is a lightweight wrapper to run k3s (Rancher Lab’s minimal Kubernetes distribution) in Docker.  
Create k3d cluster:
```sh
k3d cluster create
```

List running cluster:
```sh
k3d cluster ls
```

Test cluster connection:
```sh
kubectl get nodes
```
```sh
NAME                       STATUS   ROLES                  AGE   VERSION
k3d-k3s-default-server-0   Ready    control-plane,master   13d   v1.27.4+k3s1
```

## Fleetdm
### MySQL
Install MySQL:
```sh
helm install fleet-database oci://registry-1.docker.io/bitnamicharts/mysql -f ./helm/mysql.values.yml
```

Watch running pod for MySQL:
``` sh
kubectl get pods -w |grep mysql
```
``` sh
fleet-database-mysql-0         1/1     Running   4 (3d12h ago)   13d
```

### Redis
Install Redis:
```sh
helm install fleet-cache oci://registry-1.docker.io/bitnamicharts/redis -f ./helm/redis.values.yml
```

Watch running pods for Redis:
```sh
kubectl get pods -w |grep redis
```
```sh
fleet-cache-redis-master-0     1/1     Running   4 (3d12h ago)   13d
fleet-cache-redis-replicas-0   1/1     Running   4 (3d12h ago)   13d
```

### SSL/TLS Certs 
For sake of example generate self-signed SSL/TLS certificate for i.e. hostname `hostname.contoso.org`.
``` sh
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout tls.key -out tls.crt -subj "/CN=hostname" \
  -addext "subjectAltName=DNS:hostname.contoso.org"
```

Create secret resource containing certificate into Kubernetes:
```sh
kubectl create secret tls fleet-tls --key=./tls.key --cert=./tls.crt
```

### Fleetdm
After running sucessfully running MySQL&Redis install Fleetdm. Wait for the MySQL migration job.
```sh
helm upgrade --install fleet fleet --repo https://fleetdm.github.io/fleet/charts --values ./helm/fleet.values.yml
```

Watch the status:
```sh
NAME                           READY   STATUS    RESTARTS        AGE
fleet-cache-redis-master-0     1/1     Running   4 (3d13h ago)   13d
fleet-database-mysql-0         1/1     Running   4 (3d13h ago)   13d
fleet-cache-redis-replicas-0   1/1     Running   4 (3d13h ago)   13d
fleet-6c87c9b9df-n2kdt         1/1     Running   6 (3d ago)      12d
```

Port-forward Fleetdm service:  
Use local IP address not `localhost` nor `127.0.0.1` to be able connect from vagrant vm.
```sh
kubectl port-forward --address "local_IP" svc/fleet 27017:8080
```

Now you should be able to access Fleet at `https://local_IP:27017`. Create an account and log in.

# Configure Fleetdm agent environment
## Create Vagrant vm
For configuration of lightweight, reproducible, and portable development environments it is handy to use [Hashicorp Vagrant](https://www.vagrantup.com/).
In this repo there is `vagrantfile`.   
Create vm (Ubuntu 20.04, 1GB RAM, 2 CPU):
```sh
vagrant up
```

Check status:
```sh
vagrant status
```
```sh
Current machine states:

default                   running (virtualbox)
```

Connect to the vm:
```sh
vagrant ssh default
```
or
```sh
ssh vagrant@127.0.0.1 -p 2222 -i .vagrant/machines/default/virtualbox/private_key
```

## Install Fleetctl
Install npm and Fleetctl inside Vagrant vm:
```sh
sudo apt update && apt install npm 
sudo npm install -g fleetctl
```

Generate Fleetdm install package:
```sh
sudo fleetctl package --type=deb --fleet-url=https://hostname.contoso.org:27017 --enroll-secret=YOUR_SECRET--fleet-certificate=PATH_TO_YOUR_CERTIFICATE/fleet.pem
```
`fleet.pem` certificate is just `tls.crt` cert or get certificate from Fleet UI (Hosts -> Add hosts -> Advanced -> Download your Fleet certificate).

Add hostanem to /etc/hosts:
```sh
echo "local_IP hostname.contoso.org" | sudo tee -a /etc/hosts
```

Install generated Fleetdm agent:
```sh 
sudo dpkg -i fleet-osquery_1.22.0_amd64.deb
```

Check status:
```sh
sudo systemctl status orbit.service
```
Congrats! The agent should be visible in the Fleet UI.

# CI/CD
Official docs repo from [Fleet](https://github.com/fleetdm/fleet-gitops).
## Forward Fleetdm 
Forward Fleetdm from local network to public using ngrok:
```sh
ngrok http https://local_IP:27017
```

Add Github Actions secrets: 
- `FLEET_API_TOKEN` (Fleet UI -> My account -> Get API token).
- `FLEET_GLOBAL_ENROLL_SECRET` (Fleet UI -> Manage enroll secret).
- `FLEET_SSO_METADATA` (Just random string without spaces).
- `FLEET_URL` (Public URL from ngrok).

Example will create 2 queries defined at `./lib/example_queries.yml` and few defined configurations at `./default.yml`.

Happy Hacking!