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
	t := time.Now()

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

	var par PostAnnotationReq

	/* TODO - leverage https://pkg.go.dev/encoding/json#Decoder.DisallowUnknownFields to throw errors when
	invalid fields are passed to the PostAnnotationReq. By default, these fields are discarded
	*/
	err := json.Unmarshal(event, &par)
	if err != nil {
		return err
	}

	err = par.setTimes(t)
	if err != nil {
		return err
	}

	// Validate GRAFANA_URL
	if _, err = url.Parse(envs["GRAFANA_URL"]); err != nil {
		return err
	}
	// TODO - Validate GRAFANA_TOKEN

	// Validate PostAnnotationReq
	if !par.isValid() {
		return fmt.Errorf("Invalid request. Please ensure all fields required by '%s' are set. Input: '%+v'\n", postAnnotationsDocURL, par)
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
		// TODO - there is no stdout, one needs to pass a response object to the lambda
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
	DashboardId  int64       `json:"dashboardId,omitempty"`
	DashboardUID string      `json:"dashboardUID,omitempty"`
	PanelId      int64       `json:"panelId,omitempty"`
	TimeEnd      interface{} `json:"timeEnd,omitempty"`
	// required
	Tags      []string    `json:"tags"`
	Text      string      `json:"text"`
	TimeStart interface{} `json:"time"`
}

// IsValid Validate PostAnnotationReq prior to attempting to send to Grafana
func (req *PostAnnotationReq) isValid() bool {
	/*
		One could leverage the underlying Grafana API for validation and that would reduce Lambda time,
		but this feels like a better way to interact with a well-documented API
	*/

	// TimeStart and TimeEnd start types start as interface{} but MUST end up int64 for the API call
	switch req.TimeStart.(type) {
	// It is fine that req.TimeStart  and req.TimeEnd have an underlying float64 type since
	//	the json representation of the underlying {}interface of type int64 (per setTime) will render correctly
	case float64:
	case int64:
	default:
		return false
	}
	switch req.TimeEnd.(type) {
	case nil:
	case float64:
	case int64:
	default:
		return false
	}

	return true
}

// GrafanaAuth Struct holding Grafana auth stuff. Will hold different credential types in the future. See some upstream api for reference
type GrafanaAuth struct {
	URL   string
	Token string
}

// set i as time-parsed int64 in UnixMilli
func setTime(i interface{}, s string) (t time.Time, err error) {
	// See https://pkg.go.dev/encoding/json#Unmarshal for available types on a Unmarshalled interface{}
	switch timeType := i.(type) {
	case float64:
		f, ok := i.(float64)
		if !ok {
			return time.UnixMilli(0), fmt.Errorf("Unable to convert '%v' into a float64 in field '%s'\n", f, s)
		}
		// Changing the {}interface to a different type is not necessary since the underlying type changes
		i = int64(f)
		t = time.UnixMilli(i.(int64))
	case string:
		t, err = time.Parse(time.RFC3339, i.(string))
		if err == nil {
			i = t.UnixMilli()
		}
	// err is handled in the calling function
	default:
		err = fmt.Errorf("input type '%s' on field '%s' not valid for parsing, please use RFC3339", timeType, s)
	}

	return t, err
}

// Handle time setting logic according to upstream Grafana docs. Handle string and int64 input in req
func (req *PostAnnotationReq) setTimes(t time.Time) error {
	var startErr, endErr error
	var startTime, endTime time.Time
	// Handle TimeStart, which needs to exist
	if req.TimeStart == nil {
		req.TimeStart = t.UnixMilli()
	} else {
		// This and endTime are set correctly because interface{} is always passed by reference
		startTime, startErr = setTime(req.TimeStart, "time")
	}
	// Handle TimeEnd, which does not need to exist
	if req.TimeEnd != nil {
		endTime, endErr = setTime(req.TimeEnd, "timeEnd")
	}

	// Return combined errors
	if startErr != nil || endErr != nil {
		// Wrapping errors may be preferred in the future
		return fmt.Errorf("%s; %s", startErr, endErr)
	}
	// Check for time consistency
	if startTime.After(endTime) {
		return fmt.Errorf("start time '%s' is after end time '%s'\n", startTime, endTime)
	}

	return nil
}
