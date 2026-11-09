# ImagePullBackOff And Image References

An image-pull failure happens before the application starts. Inspect pod events and the image reference, repair the tag or access problem, and wait for the replacement to serve requests.

The commands need the playground as it starts: the Deployment `beacon` in `starfleet`, which uses an image tag that does not exist.

## Two statuses for one problem

An image reference has a registry, a repository and a tag, for example `ghcr.io/stefanprodan/podinfo:6.17.0`. The kubelet on the node asks the container runtime to pull it. If the pull fails, the pod shows `ErrImagePull` for the failed try and `ImagePullBackOff` while the kubelet waits before the next try. Like `CrashLoopBackOff`, the wait grows with each failure, up to 5 minutes. Both statuses mean the same thing, so read the events for the cause:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet describe pod -l app=beacon | sed -n '/State:/,/Ready:/p;/^Events/,$p'
```

```text
    State:          Waiting
      Reason:       ImagePullBackOff
    Ready:          False
Events:
  Type     Reason     Age                     From               Message
  ----     ------     ----                    ----               -------
  Normal   Scheduled  7m16s                   default-scheduler  Successfully assigned starfleet/beacon-87b6df55b-crnq7 to astro-ats-020-playground-050-01-control-plane
  Normal   Pulling    4m20s (x5 over 7m15s)   kubelet            spec.containers{beacon}: Pulling image "ghcr.io/stefanprodan/podinfo:6.15.99"
  Warning  Failed     4m20s (x5 over 7m15s)   kubelet            spec.containers{beacon}: Failed to pull image "ghcr.io/stefanprodan/podinfo:6.15.99": rpc error: code = NotFound desc = failed to pull and unpack image "ghcr.io/stefanprodan/podinfo:6.15.99": failed to resolve reference "ghcr.io/stefanprodan/podinfo:6.15.99": ghcr.io/stefanprodan/podinfo:6.15.99: not found
  Warning  Failed     4m20s (x5 over 7m15s)   kubelet            spec.containers{beacon}: Error: ErrImagePull
  Warning  Failed     2m11s (x20 over 7m14s)  kubelet            spec.containers{beacon}: Error: ImagePullBackOff
  Normal   BackOff    116s (x21 over 7m14s)   kubelet            spec.containers{beacon}: Back-off pulling image "ghcr.io/stefanprodan/podinfo:6.15.99"
```

The pod was scheduled, so the scheduler did its work. The kubelet tried to pull `podinfo:6.15.99` and the registry answered `not found`. The repository exists, but the tag `6.15.99` does not. A typo in the tag, a tag that was never pushed and a tag that was deleted all give this message. Compare the tag with the tags the project publishes, and use one that exists.

## Fix the reference

The image belongs to the pod template of the Deployment, so you change it there with `kubectl set image`. The container is named `beacon`, and the format is `<container>=<image>`:

```sh
kubectl -n starfleet set image deployment/beacon beacon=ghcr.io/stefanprodan/podinfo:6.17.0
kubectl -n starfleet rollout status deployment/beacon --timeout=90s
kubectl -n starfleet get pods -l app=beacon
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://beacon:9898/
```

```text
deployment.apps/beacon image updated
deployment "beacon" successfully rolled out
NAME                      READY   STATUS        RESTARTS   AGE
beacon-84d59856bb-8w7kw   1/1     Running       0          1s
beacon-87b6df55b-crnq7    0/1     Terminating   0          7m29s
200
```

The output of `rollout status` is shortened to its last line. The new pod is `Running`, the old pod with the broken tag is `Terminating`, and `shuttle` gets `200` from the Service. Do not fix the tag with `latest`. A moving tag gives a different image on a different day, and the version of the workload is no longer known.

## A missing credential looks different

The second common cause is a private registry. The kubelet needs credentials, and it takes them from a pull secret. A pull secret is a Secret of type `kubernetes.io/dockerconfigjson` that a pod names in `spec.imagePullSecrets`. Without it, the registry refuses the request, and the event text changes from `not found` to an authorization error. Start a throwaway pod with an image in a repository that the registry does not give out, and read the failure:

```sh
kubectl run privtest --image=ghcr.io/astrona-io/this-does-not-exist-private:1 --restart=Never
kubectl describe pod privtest | grep 'Failed to pull'
```

```text
  Warning  Failed     9s (x2 over 24s)  kubelet            spec.containers{privtest}: Failed to pull image "ghcr.io/astrona-io/this-does-not-exist-private:1": failed to pull and unpack image "ghcr.io/astrona-io/this-does-not-exist-private:1": failed to resolve reference "ghcr.io/astrona-io/this-does-not-exist-private:1": failed to authorize: failed to fetch anonymous token: unexpected status from GET request to https://ghcr.io/token?scope=repository%3Aastrona-io%2Fthis-does-not-exist-private%3Apull&service=ghcr.io: 403 Forbidden
```

The words `failed to authorize` and `403 Forbidden` point to credentials, not to the tag. Wait about 20 seconds before you run the second command, so that the event exists. The registry also answers `403` for a repository that does not exist at all, so a typo in the repository name can look like a credential problem. Check the spelling first. When the repository is private, the fix has two parts: create a Secret with `kubectl create secret docker-registry`, and name it in `imagePullSecrets` in the pod template of the Deployment. Then the Deployment creates a new pod that can pull the image.

Remove the throwaway pod:

```sh
kubectl delete pod privtest --now
```

```text
pod "privtest" deleted from default namespace
```

A `not found` event points to the image reference; `failed to authorize` points to registry credentials. The next lab isolates an image-reference failure so you can verify the repair through both pod readiness and an HTTP request.

## Your mission: Repair An Image Reference

The `beacon` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `beacon` are available for testing.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-050-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-10/labs/lab-04
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-050/module-10/labs/lab-04
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-050-01-04
astrona start ats-020-playground-050-01
```
