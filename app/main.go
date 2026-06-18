package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"time"
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := getenv("APP_PORT", "8080")
	appEnv := getenv("APP_ENV", "unknown")

	slog.Info("aplicação iniciando", "warmup_seconds", 10)
	time.Sleep(10 * time.Second)
	slog.Info("aplicação pronta", "port", port, "env", appEnv)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		slog.Info("request recebido", "method", r.Method, "path", r.URL.Path, "remote_addr", r.RemoteAddr)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Olá, DevOps!",
			"env":     appEnv,
			"port":    port,
		})
	})

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	slog.Info("servidor iniciado", "port", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		slog.Error("servidor encerrado com erro", "error", err)
		os.Exit(1)
	}
}
