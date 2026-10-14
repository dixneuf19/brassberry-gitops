package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

func kubectl(stdin string, args ...string) (string, error) {
	cmd := exec.Command("kubectl", args...)
	if stdin != "" {
		cmd.Stdin = strings.NewReader(stdin)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		return stdout.String(), fmt.Errorf("kubectl %s: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return stdout.String(), nil
}

func getJSON(out any, args ...string) error {
	raw, err := kubectl("", append(append([]string{"get"}, args...), "-o", "json")...)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(raw), out)
}

func psql(ns, pod, db, sql string) (string, error) {
	return kubectl("", "exec", "-n", ns, pod, "-c", "postgres", "--",
		"psql", "-d", db, "-XtAq", "-F", "\t", "-c", sql)
}
