# ImagePullBackOff And Image References

A container cannot start if the node cannot get its image. The pod is placed on a node, and then it waits. This is the last fault family of the module, and it has a different place for its evidence: the kubelet writes the pull error into the events, and the error text tells a wrong image reference from a missing credential. This part reads that text and fixes the Deployment `beacon`.

The commands need the playground as it starts: the Deployment `beacon` in `starfleet`, which uses an image tag that does not exist.

## Two statuses for one problem

An image reference has a registry, a repository and a tag, for example `ghcr.io/stefanprodan/podinfo:6.15.0`. The kubelet on the node asks the container runtime to pull it. If the pull fails, the pod shows `ErrImagePull` for the failed try and `ImagePullBackOff` while the kubelet waits before the next try. Like `CrashLoopBackOff`, the wait grows with each failure, up to 5 minutes. Both statuses mean the same thing, so read the events for the cause:

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
kubectl -n starfleet set image deployment/beacon beacon=ghcr.io/stefanprodan/podinfo:6.15.0
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

You can now read a pull failure and fix it: `not found` points to the reference, and `failed to authorize` points to a pull secret. Together with the three earlier families you now have a path from every common status to its evidence and its fix. The mission puts all four in front of you at once.

## Your mission: Fix Four Failing Workloads Lab

You can now find the cause of a `Pending` pod, a restart loop, an `OOMKilled` container and an `ImagePullBackOff`, and fix each one. The mission starts a cluster in which four workloads are broken in these four ways. You find each cause, fix it, and prove each fix with a `200` from `shuttle`. The grader rejects the fixes that only hide the fault, such as removing a probe or a memory limit.

Pause the playground first, so that only one cluster runs:

```sh
astrona stop ats-020-playground-050-01
```

Start the lab, and read the task:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-01/labs/lab-01
```

When you finish, submit your work for grading:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```

After the grader passes, remove the lab and start the playground again:

```sh
astrona destroy ats-020-lab-050-01
astrona start ats-020-playground-050-01
```

## Common pitfalls

> [!WARNING]
> - **Fixing the tag with `latest`.** It pulls, but the version is unknown. Use a tag that exists.
> - **Treating every pull error as a credential problem.** Read the text: `not found` is the reference, `failed to authorize` is the credential. A registry can answer `403` for a repository that does not exist.
> - **Editing the pod instead of the Deployment.** The image of a running pod cannot be changed this way. Change the pod template.
> - **Adding `imagePullSecrets` to the wrong object.** It belongs in the pod template, in the namespace of the pod.
