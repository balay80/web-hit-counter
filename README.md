# web-hit-counter-app

## Foundational Technologies

* [Python](https://www.python.org/)
* [Flask](https://flask.palletsprojects.com/en/2.2.x/)
* [redis](https://docs.redis.com/latest/rs/clusters/)
* [k8s](https://kubernetes.io/)

This project builds a Docker container for deployment into Kubernetes.

## Deploying

### Dev Environment Setup

Requirements:

* pyenv and virtualenv
* kubectl
* minikube
* Docker and the docker service running

Versions known to work:

| *Package* | *Version* | *Github Binaries Links* |
| --- | --- | --- |
| kubectl | 1.22.1 | |
| python | 3.9.5 | via pyenv |
| minikube | 1.27.0 | <https://github.com/kubernetes/minikube/releases/tag/v1.13.1> |
| docker | 20.10.17 | |

### Build and deploy docker image to local minikube cluster

Make sure you have your local minikube cluster running.  
To build and deploy the docker image to the local minikube cluster run below make target.  
This will build the `hit-counter-app` and it will be available in your minikube's image cache.  
This `make target` will also update the `image version` in the k8s deployment manifest at `k8s/hit-counter-app/app-deploy.yaml` and will be deployed to minikube cluster from there itself.

```sh
make do-local
```

### Deploy hit-counter-app directly to your cluster (No need to build)

If you don't want to build the `hit-counter-app`, this app image is already published to the dockerhub public repository.  
Run belwo make target and it will pull the image from the remote dockerhub public repository and will deploy to your k8s cluster.

```sh
make deploy-all
```

### Access the hit-counter-app from browser

1. Access using minikube's native `minikube service <service-name>`

    If you are using the local minikube k8s cluster then run below command to expose the nodeport service, minikube will create a tunnel to your local sytem on random port and will launch application in the browser (this behaviour is on MAC with minikube and docker driver)

    ```sh
    ❯ minikube service hit-counter-app-nodeport-svc
    |-----------|------------------------------|-------------|---------------------------|
    | NAMESPACE |             NAME             | TARGET PORT |            URL            |
    |-----------|------------------------------|-------------|---------------------------|
    | default   | hit-counter-app-nodeport-svc |          80 | http://192.168.49.2:31614 |
    |-----------|------------------------------|-------------|---------------------------|
    🏃  Starting tunnel for service hit-counter-app-nodeport-svc.
    |-----------|------------------------------|-------------|------------------------|
    | NAMESPACE |             NAME             | TARGET PORT |          URL           |
    |-----------|------------------------------|-------------|------------------------|
    | default   | hit-counter-app-nodeport-svc |             | http://127.0.0.1:55718 |
    |-----------|------------------------------|-------------|------------------------|
    🎉  Opening service default/hit-counter-app-nodeport-svc in default browser...
    ❗  Because you are using a Docker driver on darwin, the terminal needs to be open to run it.

    ```

2. Access using k8s native `kubectl port-forward`

    Also you can use k8s native `kubectl port-forward` like below to access the app in the browser.
    Here were are port forwarding `nodeport` service's `port 80` on the localhost's `port 8080`  

    ```sh
    ❯ kubectl port-forward svc/hit-counter-app-nodeport-svc 8080:80
    Forwarding from 127.0.0.1:8080 -> 5000
    Forwarding from [::1]:8080 -> 5000
    ```

    Keep the terminal open and visit the browser and hit the url `http://localhost:8080/` .
    You should get the output like below and the counter should increase when you refresh or the URL again.

    ```sh
    Holla!, we have hit 142 times
    ```

3. If you are using minikube with virtualbox driver then you should also be able to access the Nodeport Service on `minikube` clusters node and nodeport service ip

   ```sh
    1. Get your minikube cluster node ip using below command
    
    ❯ minikube ip
    192.168.49.2
    
    2. Get nodeport service port / this port will be open on all the nodes of your cluster s
    ❯ k get svc
    NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)              AGE
    hit-counter-app-nodeport-svc   NodePort    10.110.57.180   <none>        80:31614/TCP         3h16m

    3. In browser hit the url `http://192.168.49.2:31614`
   ```

### Testing App's scalability, high availability

*Below are some basic tests, I may have missed a lot of important tests, if you have any in mind let me know*

Delete any of the application pod, replication controller should take care of spawing the replacement pod within few miliseconds

Delete any of the redis-cluster pod, application should be able to write the hit's in the database and count should always increase(writes are distributed accross masters in the cluster and replicated to slave's).  

Deleted pod should be replaced with the new pod with the same hostname within few miliseconds.
Hit counts shouldn't be lost.

### Cleanup

Below `make` target will cleanup all the deployed components from the cluster

```sh
make clean-all
```
