// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
)

func TestHTTPMetricsMiddlewareUsesRouteTemplate(t *testing.T) {
	registry := prometheus.NewRegistry()
	metrics := newHTTPMetrics(registry, "/metrics", "/_healthz")
	router := mux.NewRouter()
	router.Use(metrics.middleware)
	router.HandleFunc("/product/{id}", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	})

	for _, path := range []string{"/product/one", "/product/two"} {
		request := httptest.NewRequest(http.MethodGet, path, nil)
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
	}

	got := counterValue(t, registry, "frontend_http_requests_total", map[string]string{
		"method":      http.MethodGet,
		"route":       "/product/{id}",
		"status_code": "503",
	})
	if got != 2 {
		t.Fatalf("request counter = %v, want 2", got)
	}
}

func TestHTTPMetricsMiddlewareExcludesInternalRoutes(t *testing.T) {
	registry := prometheus.NewRegistry()
	metrics := newHTTPMetrics(registry, "/metrics", "/_healthz")
	router := mux.NewRouter()
	router.Use(metrics.middleware)
	router.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	request := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	got := counterValue(t, registry, "frontend_http_requests_total", map[string]string{
		"method":      http.MethodGet,
		"route":       "/metrics",
		"status_code": "200",
	})
	if got != 0 {
		t.Fatalf("excluded request counter = %v, want 0", got)
	}
}

func counterValue(t *testing.T, registry *prometheus.Registry, name string, labels map[string]string) float64 {
	t.Helper()

	families, err := registry.Gather()
	if err != nil {
		t.Fatalf("gather metrics: %v", err)
	}
	for _, family := range families {
		if family.GetName() != name {
			continue
		}
		for _, metric := range family.GetMetric() {
			matched := true
			for key, value := range labels {
				found := false
				for _, label := range metric.GetLabel() {
					if label.GetName() == key && label.GetValue() == value {
						found = true
						break
					}
				}
				if !found {
					matched = false
					break
				}
			}
			if matched {
				return metric.GetCounter().GetValue()
			}
		}
	}
	return 0
}
