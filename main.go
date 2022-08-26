package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// See https://docs.aws.amazon.com/lambda/latest/dg/golang-handler.html
import "github.com/aws/aws-lambda-go/lambda"

const postAnnotationsDocURL = "https://grafana.com/docs/grafana/latest/developers/http_api/annotations/#create-annotation"

// Can this get cleaned up to make it a map instead?

var requiredEnvs = [...]string{
	"GRAFANA_TOKEN",
	"GRAFANA_URL",
}

// TODO - change signature to return valid json

func HandleLambdaEvent(ctx context.Context, event json.RawMessage) error {

	// Generate current time for later use
	t := time.Now().UnixMilli()

	// Validate json
	if !json.Valid(event) {
		return fmt.Errorf("input not json")
	}

	// Set envs and validate their presence
	envs := make(map[string]string)
	for _, env := range requiredEnvs {
		v, ok := os.LookupEnv(env)
		if ok {
			envs[env] = v
		}
	}
	if len(requiredEnvs) != len(envs) {
		return fmt.Errorf("Required environment variables not set. Please ensure all of the following are set: %s\n", requiredEnvs)
	}

	// Attempt Unmarshal into PostAnnotationReq
	var par PostAnnotationReq
	/* TODO - leverage https://pkg.go.dev/encoding/json#Decoder.DisallowUnknownFields to throw errors when
	invalid fields are passed to the PostAnnotationReq. By default, these fields are ignored
	*/
	err := json.Unmarshal(event, &par)
	if err != nil {
		return err
	}

	// Assign time if it doesn't exist
	if par.TimeStart == 0 {
		par.TimeStart = t
	}

	// Validate GRAFANA_URL
	if _, err = url.Parse(envs["GRAFANA_URL"]); err != nil {
		return err
	}
	// TODO - Validate GRAFANA_TOKEN

	// Validate PostAnnotationReq
	if !par.IsValid() {
		return fmt.Errorf("Invalid request. Please ensure all fields in '%s' are set.\n", postAnnotationsDocURL)
	}

	// Handle Grafana logic
	return postAnnotationHandler(
		ctx,
		GrafanaAuth{
			URL:   envs["GRAFANA_URL"],
			Token: envs["GRAFANA_TOKEN"],
		},
		par,
	)
}

func main() {
	lambda.Start(HandleLambdaEvent)
}

// TODO - check exports

func postAnnotationHandler(ctx context.Context, grafana GrafanaAuth, par PostAnnotationReq) error {

	var apiPath = "/api/annotations"
	var method = "POST"

	// Join base url and api path
	// Need to add better handling in the future. go 1.19 has url.JoinPath
	u := fmt.Sprintf("%s/%s",
		strings.TrimRight(grafana.URL, "/"),
		strings.TrimLeft(apiPath, "/"),
	)

	client := http.DefaultClient

	// Build http request
	b, err := json.Marshal(par)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, method, u, bytes.NewReader(b))
	if err != nil {
		return err
	}

	// Set necessary headers
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", grafana.Token))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return err
	}

	// TODO - make this more appealing. Maybe return a json object in LambdaHandlerEvent
	// Handle response
	var respBody []byte
	_, err = resp.Body.Read(respBody)
	textResponse := fmt.Sprintf("%s. Message: %s\n", resp.Status, respBody)

	// Accept 2xx, throw errors otherwise. Always return/display response body
	if resp.StatusCode > 299 || resp.StatusCode < 200 {
		return fmt.Errorf(textResponse)

	} else {
		fmt.Println(textResponse)
	}

	return nil
}

// Support api token to start
// Basic auth and api key supported in the future

// auth.go
// https://grafana.com/docs/grafana/latest/developers/http_api/auth/
// Use Authorization header for api token or use api_key:Bearer@url

// annotate.go
// Assume all annotations are global

// The format for time and timeEnd should be epoch numbers in millisecond resolution.

// See https://github.com/grafana/grafana/blob/fe87ffdda0d388cf65a3eeafdbf92a5b1b621079/pkg/api/dtos/annotations.go#L5

type PostAnnotationReq struct {
	DashboardId  int64  `json:"dashboardId"`
	DashboardUID string `json:"dashboardUID,omitempty"`
	PanelId      int64  `json:"panelId,omitempty"`
	TimeEnd      int64  `json:"timeEnd,omitempty"`
	// required
	Tags      []string `json:"tags"`
	Text      string   `json:"text"`
	TimeStart int64    `json:"time"`
}

// IsValid Validate PostAnnotationReq prior to attempting to send to Grafana
func (PostAnnotationReq) IsValid() bool {
	/* TODO - implement this
	One could leverage the underlying Grafana API for validation, but this reduces Lambda time
	and feels like a better way to interact with a well-documented API
	*/
	return true
}

// Struct holding Grafana auth stuff. Will hold different credential types in the future. See some upstream api for reference

type GrafanaAuth struct {
	URL   string
	Token string
}
