package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

var (
	urlFlag    = flag.String("url", "", "URL to run integration tests against")
	apiKeyFlag = flag.String("api-key", "", "API key")
)

type AppTestSuite struct {
	suite.Suite
	baseURL string
	server  *httptest.Server
	apiKey  string

	origLogWriter io.Writer
	origSemver    string
	origCommitSha string
}

const (
	testSemver    = "v0.0.0-test"
	testCommitSha = "123456789abcdef"
)

func (s *AppTestSuite) SetupSuite() {
	s.baseURL = *urlFlag
	s.apiKey = *apiKeyFlag
	if s.baseURL == "" {
		s.origLogWriter = log.Writer()
		log.SetOutput(ioutil.Discard)

		s.origSemver = Semver
		s.origCommitSha = CommitSha
		Semver = testSemver
		CommitSha = testCommitSha

		s.server = httptest.NewServer(newHandler())
		s.baseURL = s.server.URL
		s.apiKey = config.APIKey
	}
}

func (s *AppTestSuite) TearDownSuite() {
	if s.server != nil {
		s.server.Close()
		log.SetOutput(s.origLogWriter)
		Semver = s.origSemver
		CommitSha = s.origCommitSha
	}
}

func TestApp(t *testing.T) {
	suite.Run(t, &AppTestSuite{})
}

func (s *AppTestSuite) TestRun() {
	t := s.T()
	payload := fmt.Sprintf(`{
		"apiKey":  "%s",
		"command": "printf 'Hello World!'"
	}`, s.apiKey)
	body, status := httpPost(t, s.baseURL+"/run", payload)
	require.Equal(t, http.StatusOK, status)
	require.Equal(t, "Hello World!", body)
}

func (s *AppTestSuite) TestRunErrJSON() {
	t := s.T()
	payload := `{ "BAD_JSON`
	_, status := httpPost(t, s.baseURL+"/run", payload)
	require.Equal(t, http.StatusBadRequest, status)
}

func (s *AppTestSuite) TestRunErrBadAPIKey() {
	t := s.T()
	payload := `{
		"apiKey":  "BAD-API-KEY",
		"command": "printf 'Hello World!'"
	}`
	_, status := httpPost(t, s.baseURL+"/run", payload)
	require.Equal(t, http.StatusUnauthorized, status)
}

func (s *AppTestSuite) TestRunErrMissingCommand() {
	t := s.T()
	payload := fmt.Sprintf(`{
		"apiKey":  "%s",
		"command": "exit 13"
	}`, s.apiKey)
	body, status := httpPost(t, s.baseURL+"/run", payload)
	require.Equal(t, http.StatusOK, status)
	require.Equal(t, "error: exit status 13\n", body)
}

func (s *AppTestSuite) TestVersion() {
	t := s.T()
	body, status := httpGet(t, s.baseURL+"/version")
	require.Equal(t, http.StatusOK, status)
	version := map[string]string{}
	err := json.Unmarshal([]byte(body), &version)
	require.NoError(t, err, body)
	semver := version["semver"]
	commitSha := version["commitSha"]
	require.NotEmpty(t, semver)
	require.NotEmpty(t, commitSha)
	require.NotEmpty(t, version["app"])
	require.NotEmpty(t, version["repoURL"])
	require.NotEqual(t, "undefined", semver)
	require.NotEqual(t, "undefined", commitSha)
	if s.server != nil {
		want := fmt.Sprintf(`{
			"app": "jcdc",
			"commitSha": "%s",
			"repoURL": "https://github.com/foxygoat/jcdc",
			"semver": "%s"
		}`, testCommitSha, testSemver)
		require.JSONEq(t, want, body)
	}
}

func (s *AppTestSuite) Test404() {
	t := s.T()
	body, status := httpGet(t, s.baseURL+"/missing")
	require.Equal(t, http.StatusNotFound, status)
	require.Equal(t, "404 page not found\n", body)
}

func httpGet(t *testing.T, url string) (string, int) {
	t.Helper()
	return httpDo(t, http.MethodGet, url, "")
}

func httpPost(t *testing.T, url, body string) (string, int) {
	t.Helper()
	return httpDo(t, http.MethodPost, url, body)
}

func httpDo(t *testing.T, method, url, body string) (string, int) {
	t.Helper()
	var bodyReader io.Reader
	if body != "" {
		bodyReader = strings.NewReader(body)
	}
	req, err := http.NewRequestWithContext(context.Background(), method, url, bodyReader)
	require.NoError(t, err)

	resp, err := http.DefaultClient.Do(req) //nolint:gosec, noctx
	require.NoErrorf(t, err, "cannot %s %s", method, url)
	defer func() {
		err := resp.Body.Close()
		require.NoError(t, err)
	}()
	b, err := ioutil.ReadAll(resp.Body)
	require.NoError(t, err, "cannot read body "+url)
	return string(b), resp.StatusCode
}
