# peertube

To reset the root password (do this after first deploy):

```sh
docker exec -it peertube /bin/bash
npm run reset-password -- -u root
```

## References

<https://framablog.org/2022/12/13/peertube-v5-the-result-of-5-years-handcrafting/>

<https://framablog.org/2022/11/29/to-understand-and-get-started-with-peertube-check-out-the-new-joinpeertube-org/>

<https://docs.joinpeertube.org/contribute-architecture>

<https://github.com/Chocobozzz/PeerTube/blob/develop/support/doc/docker.md>
