package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"

	"foxygo.at/s/errs"
	"foxygo.at/s/httpe"
	"github.com/alecthomas/kong"
)

var (
	// Semver holds the version exposed at /version and passed via linker flag on CI.
	Semver = "undefined"
	// CommitSha holds the commit exposed at /version and passed via linker flag on CI.
	CommitSha = "undefined"
)

var config struct {
	APIKey string `help:"Secret API Key." env:"JCDC_API_KEY" required:""`
}

type payload struct {
	APIKey  string `json:"apiKey"`
	Command string `json:"command"` // e.g. kubecfg update https://github.com/foxygoat/foxtrot/..../ -A hostname=
}

func main() {
	kong.Parse(&config, kong.Description("JCDC Server"))
	fmt.Println("Listening on :8080 (accessible on http://localhost:8080)")
	if err := http.ListenAndServe(":8080", newHandler()); err != nil {
		log.Fatal(err)
	}
}

func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/version", httpe.Must(httpe.Get, Version))
	mux.Handle("/run", httpe.Must(httpe.Post, Run))
	return logHTTP(mux)
}

func Run(w http.ResponseWriter, r *http.Request) error {
	p := payload{}
	defer r.Body.Close() //nolint: errcheck
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		return errs.Errorf("%v: JSON parse error: %v", httpe.ErrBadRequest, err)
	}
	if p.APIKey != config.APIKey {
		return errs.Errorf("%v: bad API key", httpe.ErrUnauthorized)
	}

	cmd := exec.Command("/bin/sh", "-c", p.Command)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return errs.Errorf("%v: %v\n%s", httpe.ErrBadRequest, err, out)
	}
	_, _ = w.Write(out)
	return nil
}

func Version(w http.ResponseWriter, r *http.Request) error {
	version := map[string]string{
		"app":       "jcdc",
		"commitSha": CommitSha,
		"repoURL":   "https://github.com/foxygoat/jcdc",
		"semver":    Semver,
	}
	return json.NewEncoder(w).Encode(version)
}

func logHTTP(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ww := &responseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}
		h.ServeHTTP(ww, r)
		log.Printf("%d %-4s %s %s\n", ww.statusCode, r.Method, r.URL, r.RemoteAddr)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (w *responseWriter) WriteHeader(code int) {
	w.statusCode = code
	w.ResponseWriter.WriteHeader(code)
}
