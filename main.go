package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"foxygo.at/s/httpe"
)

var (
	// Semver holds the version exposed at /version and passed via linker flag on CI.
	Semver = "undefined"
	// CommitSha holds the commit exposed at /version and passed via linker flag on CI.
	CommitSha = "undefined"
)

func main() {
	fmt.Println("Listening on :8080 (accessible on http://localhost:8080)")
	if err := http.ListenAndServe(":8080", newHandler()); err != nil {
		log.Fatal(err)
	}
}

func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/version", httpe.Must(httpe.Get, Version))
	mux.Handle("/hello", httpe.Must(httpe.Get, Hello))
	return logHTTP(mux)
}

func Hello(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello World!")
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
