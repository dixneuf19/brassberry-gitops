// Command cnpg-restore-drill restores a CNPG cluster backed up with the
// barman-cloud plugin into a throwaway Cluster next to the source (latest
// base backup + archived WAL), compares exact per-table row counts with the
// live source, then deletes the drill Cluster.
//
// The drill Cluster declares no plugin, so it never archives WAL into the
// source's backup path. Nothing on the source is modified: it only gets read
// queries.
//
// Usage: go run ./scripts/cnpg-restore-drill [--keep] [--node NODE] [--timeout 30m] <namespace>/<cluster>
package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"maps"
	"os"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
)

const plugin = "barman-cloud.cloudnative-pg.io"

// set by the operator on every Cluster, never worth copying to the drill
var cnpgManagedParams = map[string]bool{
	"archive_mode": true, "archive_timeout": true, "dynamic_shared_memory_type": true,
	"full_page_writes": true, "log_destination": true, "log_directory": true,
	"log_filename": true, "log_rotation_age": true, "log_rotation_size": true,
	"log_truncate_on_rotation": true, "logging_collector": true, "max_parallel_workers": true,
	"max_replication_slots": true, "max_worker_processes": true, "shared_memory_type": true,
	"shared_preload_libraries": true, "ssl_max_protocol_version": true, "ssl_min_protocol_version": true,
	"wal_keep_size": true, "wal_level": true, "wal_log_hints": true,
	"wal_receiver_timeout": true, "wal_sender_timeout": true,
}

const countSQL = `
SELECT format('SELECT %L AS t, count(*) AS n FROM %I.%I', n.nspname || '.' || c.relname, n.nspname, c.relname)
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1`

var replayRe = regexp.MustCompile(`last completed transaction was at log time ([^"\\]+)`)

type obj = map[string]any

type sourceCluster struct {
	Metadata struct {
		Name      string `json:"name"`
		Namespace string `json:"namespace"`
	} `json:"metadata"`
	Spec struct {
		ImageName       string `json:"imageName,omitempty"`
		ImageCatalogRef obj    `json:"imageCatalogRef,omitempty"`
		Storage         struct {
			Size string `json:"size"`
		} `json:"storage"`
		Plugins []struct {
			Name       string            `json:"name"`
			Parameters map[string]string `json:"parameters"`
		} `json:"plugins"`
		PostgreSQL struct {
			Parameters             map[string]string `json:"parameters"`
			SharedPreloadLibraries []string          `json:"shared_preload_libraries"`
		} `json:"postgresql"`
		Affinity struct {
			NodeSelector map[string]string `json:"nodeSelector"`
		} `json:"affinity"`
	} `json:"spec"`
	Status struct {
		CurrentPrimary string `json:"currentPrimary"`
	} `json:"status"`
}

func drillManifest(src *sourceCluster, name, node string) (obj, error) {
	var objectStore, serverName string
	for _, p := range src.Spec.Plugins {
		if p.Name == plugin {
			objectStore = p.Parameters["barmanObjectName"]
			serverName = p.Parameters["serverName"]
		}
	}
	if objectStore == "" {
		return nil, fmt.Errorf("source cluster has no %s plugin, nothing to restore from", plugin)
	}
	if serverName == "" {
		serverName = src.Metadata.Name
	}
	params := map[string]string{}
	for k, v := range src.Spec.PostgreSQL.Parameters {
		if !cnpgManagedParams[k] {
			params[k] = v
		}
	}
	libs := src.Spec.PostgreSQL.SharedPreloadLibraries
	if libs == nil {
		libs = []string{}
	}
	spec := obj{
		"instances": 1,
		"enablePDB": false,
		"storage":   obj{"size": src.Spec.Storage.Size, "storageClass": "local-path"},
		"resources": obj{
			"requests": obj{"cpu": "250m", "memory": "256Mi"},
			"limits":   obj{"memory": "1Gi"},
		},
		"postgresql": obj{"parameters": params, "shared_preload_libraries": libs},
		"bootstrap":  obj{"recovery": obj{"source": "origin"}},
		// no "plugins" key: the drill must never archive WAL
		"externalClusters": []obj{{
			"name": "origin",
			"plugin": obj{
				"name":       plugin,
				"parameters": obj{"barmanObjectName": objectStore, "serverName": serverName},
			},
		}},
	}
	if src.Spec.ImageName != "" {
		spec["imageName"] = src.Spec.ImageName
	}
	if src.Spec.ImageCatalogRef != nil {
		spec["imageCatalogRef"] = src.Spec.ImageCatalogRef
	}
	selector := maps.Clone(src.Spec.Affinity.NodeSelector)
	if node != "" {
		if selector == nil {
			selector = map[string]string{}
		}
		selector["kubernetes.io/hostname"] = node
	}
	if len(selector) > 0 {
		spec["affinity"] = obj{"nodeSelector": selector}
	}
	return obj{
		"apiVersion": "postgresql.cnpg.io/v1",
		"kind":       "Cluster",
		"metadata": obj{
			"name":      name,
			"namespace": src.Metadata.Namespace,
			"labels":    obj{"drill.dixneuf19.fr/source": src.Metadata.Name},
		},
		"spec": spec,
	}, nil
}

// rowCounts returns the exact row count of every table in every user
// database, keyed db/schema.table.
func rowCounts(ns, pod string) (map[string]int, error) {
	dbs, err := psql(ns, pod, "postgres", "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'")
	if err != nil {
		return nil, err
	}
	counts := map[string]int{}
	for _, db := range strings.Fields(dbs) {
		out, err := psql(ns, pod, db, countSQL)
		if err != nil {
			return nil, err
		}
		queries := slices.DeleteFunc(strings.Split(out, "\n"), func(q string) bool { return q == "" })
		if len(queries) == 0 {
			continue
		}
		out, err = psql(ns, pod, db, strings.Join(queries, " UNION ALL "))
		if err != nil {
			return nil, err
		}
		for line := range strings.Lines(out) {
			t, n, ok := strings.Cut(strings.TrimRight(line, "\n"), "\t")
			if !ok {
				continue
			}
			v, err := strconv.Atoi(n)
			if err != nil {
				return nil, fmt.Errorf("count for %s: %w", t, err)
			}
			counts[db+"/"+t] = v
		}
	}
	return counts, nil
}

// waitReady waits for the drill to be healthy and returns the last replayed
// transaction time. That time is only printed by the full-recovery job,
// which CNPG removes once the instance starts, so its logs are scraped while
// waiting.
func waitReady(ns, name string, timeout time.Duration) (string, error) {
	deadline := time.Now().Add(timeout)
	last, replayed := "", ""
	for time.Now().Before(deadline) {
		var c struct {
			Status struct {
				Phase          string `json:"phase"`
				ReadyInstances int    `json:"readyInstances"`
			} `json:"status"`
		}
		if err := getJSON(&c, "cluster", "-n", ns, name); err != nil {
			return "", err
		}
		if c.Status.Phase != last {
			log.Printf("drill phase: %s", c.Status.Phase)
			last = c.Status.Phase
		}
		out, _ := kubectl("", "logs", "-n", ns, "job/"+name+"-1-full-recovery", "--all-containers")
		if m := replayRe.FindAllStringSubmatch(out, -1); m != nil {
			replayed = strings.TrimSpace(m[len(m)-1][1])
		}
		if c.Status.ReadyInstances == 1 && c.Status.Phase == "Cluster in healthy state" {
			return replayed, nil
		}
		time.Sleep(5 * time.Second)
	}
	return "", fmt.Errorf("drill cluster not ready after %s (last phase: %s)", timeout, last)
}

func latestBackup(ns, cluster string) (string, error) {
	var list struct {
		Items []struct {
			Spec struct {
				Cluster struct {
					Name string `json:"name"`
				} `json:"cluster"`
			} `json:"spec"`
			Status struct {
				Phase     string `json:"phase"`
				StoppedAt string `json:"stoppedAt"`
			} `json:"status"`
		} `json:"items"`
	}
	if err := getJSON(&list, "backups.postgresql.cnpg.io", "-n", ns); err != nil {
		return "", err
	}
	latest := ""
	for _, b := range list.Items {
		if b.Spec.Cluster.Name == cluster && b.Status.Phase == "completed" && b.Status.StoppedAt > latest {
			latest = b.Status.StoppedAt
		}
	}
	return latest, nil
}

func run(target, node string, keep bool, timeout time.Duration) (bool, error) {
	ns, cluster, ok := strings.Cut(target, "/")
	if !ok {
		return false, errors.New("target must be <namespace>/<cluster>")
	}
	var src sourceCluster
	if err := getJSON(&src, "cluster", "-n", ns, cluster); err != nil {
		return false, err
	}
	primary := src.Status.CurrentPrimary
	name := fmt.Sprintf("%s-drill-%s", cluster, time.Now().Format("200601021504"))

	log.Printf("source %s/%s, primary %s", ns, cluster, primary)
	backup, err := latestBackup(ns, cluster)
	if err != nil {
		return false, err
	}
	log.Printf("latest completed base backup: %s", backup)
	archiver, err := psql(ns, primary, "postgres", "SELECT last_archived_wal, last_archived_time FROM pg_stat_archiver")
	if err != nil {
		return false, err
	}
	log.Printf("source archiver: %s", strings.TrimSpace(archiver))

	manifest, err := drillManifest(&src, name, node)
	if err != nil {
		return false, err
	}
	raw, err := json.Marshal(manifest)
	if err != nil {
		return false, err
	}
	started := time.Now()
	if _, err := kubectl(string(raw), "apply", "-f", "-"); err != nil {
		return false, err
	}
	log.Printf("created drill cluster %s/%s", ns, name)
	defer func() {
		if keep {
			log.Printf("--keep: delete later with: kubectl delete cluster -n %s %s", ns, name)
			return
		}
		if _, err := kubectl("", "delete", "cluster", "-n", ns, name, "--wait=true"); err != nil {
			log.Printf("cleanup: %v", err)
		}
		if _, err := kubectl("", "delete", "pvc", "-n", ns, "-l", "cnpg.io/cluster="+name, "--ignore-not-found"); err != nil {
			log.Printf("cleanup: %v", err)
		}
		log.Printf("deleted drill cluster %s", name)
	}()

	replayed, err := waitReady(ns, name, timeout)
	if err != nil {
		return false, err
	}
	if replayed == "" {
		replayed = "not logged"
	}
	log.Printf("recovered in %.0fs, last replayed transaction at %s", time.Since(started).Seconds(), replayed)

	srcCounts, err := rowCounts(ns, primary)
	if err != nil {
		return false, err
	}
	drillCounts, err := rowCounts(ns, name+"-1")
	if err != nil {
		return false, err
	}
	sum := func(m map[string]int) (n int) {
		for _, v := range m {
			n += v
		}
		return n
	}
	log.Printf("%d tables, %d rows in source, %d in drill", len(srcCounts), sum(srcCounts), sum(drillCounts))
	all := maps.Clone(srcCounts)
	maps.Copy(all, drillCounts)
	tables := slices.Sorted(maps.Keys(all))
	diffs := 0
	sameTables := true
	for _, t := range tables {
		s, inSrc := srcCounts[t]
		d, inDrill := drillCounts[t]
		if inSrc != inDrill {
			sameTables = false
		}
		if s != d || inSrc != inDrill {
			diffs++
			log.Printf("  differs: %s source=%v drill=%v", t, show(s, inSrc), show(d, inDrill))
		}
	}
	if diffs == 0 {
		log.Print("row counts match on every table")
	}
	pass := len(drillCounts) > 0 && sameTables
	result := "FAIL"
	if pass {
		result = "PASS"
	}
	log.Printf("RESULT: %s (%d table(s) differ, writes after the last archived WAL are expected)", result, diffs)
	return pass, nil
}

func show(n int, ok bool) string {
	if !ok {
		return "missing"
	}
	return strconv.Itoa(n)
}

func main() {
	log.SetFlags(log.Ltime)
	keep := flag.Bool("keep", false, "leave the drill Cluster running for inspection")
	node := flag.String("node", "", "pin the drill instance to this node (default: the source's nodeSelector)")
	timeout := flag.Duration("timeout", 30*time.Minute, "how long to wait for the recovery")
	flag.Usage = func() {
		fmt.Fprintln(flag.CommandLine.Output(), "usage: cnpg-restore-drill [flags] <namespace>/<cluster>")
		flag.PrintDefaults()
	}
	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(2)
	}
	pass, err := run(flag.Arg(0), *node, *keep, *timeout)
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
	if !pass {
		os.Exit(1)
	}
}
