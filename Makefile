# Version automatic by managing this -> minikube/deployment.yaml(.TEMPLATE)
#  ":=" expands immediately.
KUBERNETES_VERSION := v1.21.14
NAMESPACE          := hit-counter-app
DEPLOY_VERSION     := $(shell grep -E 'hit-counter-app:[0-9]' k8s/hit-counter-app/app-deploy.yaml.TEMPLATE | cut -d ':' -f 3)
DEPLOY_MAJOR       := $(shell echo "$(DEPLOY_VERSION)" | awk 'BEGIN{FS="."}{print $$1}')
DEPLOY_MINOR       := $(shell echo "$(DEPLOY_VERSION)" | awk 'BEGIN{FS="."}{print $$2}')
DEPLOY_PATCH       := $(shell (date "+%Y%m%d"))
DEPLOY_SUBPATCH    := $(shell (date "+%H%M"))
VERSION            := $(DEPLOY_MAJOR).$(DEPLOY_MINOR).$(DEPLOY_PATCH).$(DEPLOY_SUBPATCH)

###################################################
#  https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := default

.PHONY: default
default:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
###################################################
# Build functions
## Local (minikube) build

.PHONY: do-start
do-start:
	kubectl config use-context minikube # just to be sure we are deploying on local minikube cluster.
	@echo "Starting build of version: $(VERSION)"
	sleep 5

.PHONY: build-app
build-app:
	echo "VERSION:$(VERSION)" > Deployment.info
	# Manage the patch and sub-patch versions automatically.
	cat k8s/hit-counter-app/app-deploy.yaml.TEMPLATE | \
		sed -e "s/{{YMD}}/$(DEPLOY_PATCH)/" -e "s/{{TIME}}/$(DEPLOY_SUBPATCH)/" > k8s/hit-counter-app/app-deploy.yaml
	@eval $$(minikube docker-env) ;\
	docker build -t "balayadav/hit-counter-app:$(VERSION)" .

.PHONY: do-local
do-local: do-start build-app deploy-all ## Build and deploy to a local Minikube environment.
	@echo
	@echo "Done - Version: $(VERSION) - $$(date)"

.PHONY: deploy-redis-cluster
deploy-redis-cluster: ## Deploy only the redis-cluster for the app
	kubectl apply -f k8s/redis-cluster/
	sleep 30 ## Waiting for redis pods to be up and running ......
	echo "yes" | kubectl exec -it redis-cluster-0 -- redis-cli --cluster create --cluster-replicas 1 $$(kubectl get pods -l app=redis-cluster -o jsonpath='{range.items[*]}{.status.podIP}:6379 ');\
	sleep 30 ## Waiting for Redis cluster to be ready to accept the connections .....

.PHONY: deploy-app
deploy-app: ## Deploy only the hit-counter-app
	@eval $$(minikube docker-env) ;\
	kubectl apply -f k8s/hit-counter-app/

.PHONY: deploy-all
deploy-all: deploy-redis-cluster deploy-app ## Deploy a working hit-counter-app along with backing redis-db cluster

.PHONY: cleanup-app 
cleanup-app: ## Clean only the hit-counter-app
	kubectl delete -f k8s/hit-counter-app/

.PHONY: cleanup-redis-cluster
cleanup-redis-cluster: ## Clena only the redis-cluster
	kubectl delete -f k8s/redis-cluster/
	sleep 15 ## waiting for pods cleanup
	kubectl get pvc | awk '{print $$1}' | sed '1d' | xargs kubectl delete pvc
	sleep 5
	kubectl get pv | awk '{print $$1}' | sed '1d' | xargs kubectl delete pv

.PHONY: cleanup-all
cleanup-all: cleanup-app cleanup-redis-cluster  ## Cleaning up application and redis cluster



## local dev environment setup
.PHONY: rebuild-local-python
rebuild-local-python: whack-local-python local-python  ## (Re)build the required local Python environment.

.PHONY: local-python
local-python:
	@echo '### Building the Python virtual environment and installing packages.'
	pyenv install -s 3.9.5
	pyenv virtualenv -f 3.9.5 hit-counter-app-dev
	pyenv local hit-counter-app-dev
	pip install --upgrade pip
	pip install wheel pip-tools ply
	pip-compile requirements.in
	pip install -r requirements.saml.txt --no-cache-dir
	pip install -r requirements.txt --no-cache-dir

.PHONY: whack-local-python
whack-local-python:
	@echo '### Destroying the Python virtual environment.'
	rm -fv .python-version
	pyenv uninstall --force hit-counter-app-dev

.PHONY: dump-versions
.IGNORE: dump-versions
dump-versions:  ## Show the versions of all the significant things in the local environment.
	python --version
	pyenv version
	kubectl version --short
	minikube version | grep -v commit
	docker version | grep Version | head -1
