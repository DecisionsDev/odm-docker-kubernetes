
#  Deploy IBM Operational Decision Manager Standard on a Bluemix Kubernetes Cluster

Full story is described in this article: https://www.ibm.com/developerworks/library/mw-1706-feillet-bluemix/1706-feillet.html

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
This repository contains Kubernetes deployment descriptors to deploy an ODM Standard topology in your Bluemix cluster:
- [ODM Standard deployment descriptor for a Bluemix lite cluster](./odm-standard-bx-lite.yaml)
- [ODM Standard deployment descriptor for a Bluemix standard cluster](./odm-standard-bx-standard.yaml)

## Testing
This material has been tested with the following configuration:
- MacOS 10.12.4,
- Kubernetes
   - client 1.6.2
   - server 1.5.6
- Docker 17.03
- ODM 8.9.0

## Troubleshooting
* If your ODM services cannot be reached just after the creation of the deployment, you may wait for few minutes to have connectivity completed in the hosted cluster.
* If your microservice instance is not running properly, you may check the logs using
	* `kubectl logs <your-pod-name>`
* To delete a microservice
	* `kubectl delete -f manifests/<microservice-yaml-file>`
* To delete everything
	* `kubectl delete -f manifests`

## References

# License
[Apache 2.0](LICENSE)

