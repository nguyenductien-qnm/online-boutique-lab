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
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
)

type httpMetrics struct {
	requests        *prometheus.CounterVec
	requestDuration *prometheus.HistogramVec
	excludedRoutes  map[string]struct{}
}

type metricsResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (w *metricsResponseWriter) WriteHeader(statusCode int) {
	if w.statusCode != 0 {
		return
	}
	w.statusCode = statusCode
	w.ResponseWriter.WriteHeader(statusCode)
}

func (w *metricsResponseWriter) Write(p []byte) (int, error) {
	if w.statusCode == 0 {
		w.WriteHeader(http.StatusOK)
	}
	return w.ResponseWriter.Write(p)
}

func registerHTTPMetrics(excludedRoutes ...string) mux.MiddlewareFunc {
	return newHTTPMetrics(prometheus.DefaultRegisterer, excludedRoutes...).middleware
}

func newHTTPMetrics(registerer prometheus.Registerer, excludedRoutes ...string) *httpMetrics {
	m := &httpMetrics{
		requests: prometheus.NewCounterVec(prometheus.CounterOpts{
			Namespace: "frontend",
			Subsystem: "http",
			Name:      "requests_total",
			Help:      "Total number of HTTP requests handled by the frontend.",
		}, []string{"method", "route", "status_code"}),
		requestDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Namespace: "frontend",
			Subsystem: "http",
			Name:      "request_duration_seconds",
			Help:      "Duration of frontend HTTP requests in seconds.",
			Buckets:   []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10},
		}, []string{"method", "route"}),
		excludedRoutes: make(map[string]struct{}, len(excludedRoutes)),
	}

	for _, route := range excludedRoutes {
		m.excludedRoutes[route] = struct{}{}
	}

	registerer.MustRegister(m.requests, m.requestDuration)
	return m
}

func (m *httpMetrics) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		routeTemplate := "unknown"
		if route := mux.CurrentRoute(r); route != nil {
			if template, err := route.GetPathTemplate(); err == nil {
				routeTemplate = template
			}
		}

		if _, excluded := m.excludedRoutes[routeTemplate]; excluded {
			next.ServeHTTP(w, r)
			return
		}

		start := time.Now()
		recorder := &metricsResponseWriter{ResponseWriter: w}
		next.ServeHTTP(recorder, r)
		if recorder.statusCode == 0 {
			recorder.statusCode = http.StatusOK
		}

		m.requests.WithLabelValues(
			r.Method,
			routeTemplate,
			strconv.Itoa(recorder.statusCode),
		).Inc()
		m.requestDuration.WithLabelValues(r.Method, routeTemplate).Observe(time.Since(start).Seconds())
	})
}
