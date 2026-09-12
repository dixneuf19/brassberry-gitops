# Derived data (no backup wanted)

Data the app rebuilds from its primary data or from the outside world. Backing it up
wastes space and, worse, hides the fact that the primary data is what matters.

| Data | App | Where | Rebuild how | Rebuild cost |
|---|---|---|---|---|
| Thumbnails, encoded videos | Immich | `tank/media/immich/{thumbs,encoded-video}` | Admin > Jobs > Generate thumbnails / Transcode | hours of CPU on the Pi cluster |
| CLIP / face models | Immich machine-learning | `local-path` 10Gi | downloaded on first start | minutes, needs internet |
| Smart search embeddings, face embeddings | Immich | inside Postgres, so they are backed up with it | Admin > Jobs > Smart search | hours, not free if using a paid API |
| Job queues | Immich Valkey | `nfs-jonbonas` 1Gi | restart | none |
| Search index | Karakeep Meilisearch | `nfs-client` 1Gi | Admin > Background jobs > Reindex | minutes |
| Next.js cache | Karakeep | emptyDir | restart | none |
| Metrics 30d | Prometheus | `local-path` on brassberry-27 | none, history is lost | accepted |
| Logs | Loki (deployed out of GitOps) | `local-path` on brassberry-25 | none | accepted |
| VPA recommendations, ArgoCD Redis cache, cert-manager certificates | platform | in cluster | recomputed / re-issued (Let's Encrypt rate limits apply) | minutes |
| Burrito plans and logs | burrito | S3, 90d lifecycle | next run | none |
| Torrent downloads, music rips | netflix, soundhoard | USB disks | re-download | time |

Rule: a ♻️ row in the README must name the rebuild path. If the rebuild path disappears
(API shut down, model no longer downloadable), the row moves to class B.
