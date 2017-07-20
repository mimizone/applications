
The following explains how to deploy quickly a kubernetes cluster on Cloudwatt, using Heat templates.


Install the openstack clients.
It's python based so you can use virtualenv as well
```
pip install openstack
```

Clone my repository.
```
git clone git@github.com:mimizone/applications.git git.mimizone
```

set your openstack credentials (retrieve the openrc file from the Openstack UI)
```
source ./0750176991_Gezora-K8s_1-openrc.sh
```

start the installation by executing the fully automated script
```
cd git.mimizone/blueprint-kubernetes-ha/
./createit.sh
```

wait typically 10-15min....

once all the openstack resources are running, the kubernetes cluster is still in the process of being brought up.

You can ssh into any of the k8s instances in the meantime.
```
ssh -l core IPADDRESS -i ~/.ssh/SSHKEY)
```

You can list all the services. If everything is done, all lines should say `active running`
```
$ fleetctl list-units
UNIT				MACHINE				ACTIVE	SUB
pidalio-apiserver.service	6e9e493b.../84.39.46.59		active	running
pidalio-controller.service	7a51e56b.../84.39.45.154	active	running
pidalio-node.service		27fc703e.../84.39.46.66		active	running
pidalio-node.service		41b53e2c.../84.39.46.105	active	running
....
```

get the IP of the API server
```
core@ku-5lzjxv-zkyle3slbvgl-pcei63axrvfx-node-rgbcxkje4zds ~ $ fleetctl list-units | grep api
pidalio-apiserver.service	6e9e493b.../84.39.46.59		active	running
```

configure you local kubernetes client `kubectl` using the API Server IP from above (ex: 84.39.46.59)
the following makes this cluster the default one.
```
brew install kubectl
kubectl config set-cluster default-cluster --server=http://APISERVER_IP:8080
kubectl config set-credentials default-admin
kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system
```

the Heat template doesn't open the port 8080.
It has to be done in the UI or
```
security_group_id=`openstack stack resource show kube security_group -c physical_resource_id -f table | grep physical_resource_id | awk '{ print $4 }'`
openstack security group rule create --dst-port 8080 --protocol tcp --ingress $security_group_id
```

you can also open the ports to access the monitoring tools grafana and prometheus that are already installed and expose as services.
```
openstack security group rule create --dst-port 31000 --protocol tcp --ingress $security_group_id
openstack security group rule create --dst-port 30900 --protocol tcp --ingress $security_group_id
```

check you can connect to the kubernetes cluster
```
$ kubectl cluster-info
Kubernetes master is running at http://84.39.46.59:8080
KubeDNS is running at http://84.39.46.59:8080/api/v1/namespaces/kube-system/services/kube-dns/proxy
```
or
```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.1", GitCommit:"1dc5c66f5dd61da08412a74221ecc79208c2165b", GitTreeState:"clean", BuildDate:"2017-07-14T05:22:03Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"6", GitVersion:"v1.6.2+coreos.0", GitCommit:"79fee581ce4a35b7791fdd92e0fc97e02ef1d5c0", GitTreeState:"clean", BuildDate:"2017-04-19T23:13:34Z", GoVersion:"go1.7.5", Compiler:"gc", Platform:"linux/amd64"}
```

install the Kubernetes dashboard (it's not installed by default in older versions of k8s)
```
kubectl create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
```
and go to
http://APISERVER_IP:8080/ui/



configure grafana
go to http://APISERVER_IP:31000
configure the prometheus data source.
```
name: prometheus
Type: Prometheus
URL: http://prometheus.monitoring:9090
Access: proxy
```
add a few dashboards via the ID.
get them from the grafana.net web site
