
#  Deploy IBM Operational Decision Manager Standard on a Bluemix Kubernetes Cluster

Full story is described in this article: to be defined

![Flow](../images/ODMinKubernetes-Flow.png)

## Testing
This tutorial has been tested on MacOS.

## Troubleshooting

* If your microservice instance is not running properly, you may check the logs using
	* `kubectl logs <your-pod-name>`
* To delete a microservice
	* `kubectl delete -f manifests/<microservice-yaml-file>`
* To delete everything
	* `kubectl delete -f manifests`

## References

# License
[Apache 2.0](LICENSE)

