package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"runtime"
	"time"

	"github.com/go-redis/redis/v8"
	_ "github.com/lib/pq"
)

// HealthResponse represents the structure of the health check response
type HealthResponse struct {
	Status      string            `json:"status"`
	Time        time.Time         `json:"time"`
	GoVersion   string            `json:"goVersion"`
	Environment string            `json:"environment"`
	Components  map[string]Status `json:"components"`
}

// Status represents the health status of a component
type Status struct {
	Status       string `json:"status"`
	ResponseTime string `json:"responseTime,omitempty"`
	Message      string `json:"message,omitempty"`
}

// Add health check handlers to your main application
func addHealthChecks(router *http.ServeMux) {
	// Basic health check - quick response for load balancers
	router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "UP"})
	})

	// Detailed health check - includes dependencies
	router.HandleFunc("/health/details", detailedHealthCheck)
}

// detailedHealthCheck provides detailed health information about the application and its dependencies
func detailedHealthCheck(w http.ResponseWriter, r *http.Request) {
	startTime := time.Now()

	// Initialize response
	healthResponse := HealthResponse{
		Status:      "UP",
		Time:        time.Now(),
		GoVersion:   runtime.Version(),
		Environment: os.Getenv("APP_ENV"),
		Components:  make(map[string]Status),
	}

	// Check database connection
	dbStatus := checkDatabaseHealth()
	healthResponse.Components["database"] = dbStatus
	if dbStatus.Status != "UP" {
		healthResponse.Status = "DOWN"
	}

	// Check Redis connection
	redisStatus := checkRedisHealth()
	healthResponse.Components["redis"] = redisStatus
	if redisStatus.Status != "DOWN" {
		healthResponse.Status = "DOWN"
	}

	// Check disk space
	diskStatus := checkDiskSpace()
	healthResponse.Components["disk"] = diskStatus
	if diskStatus.Status != "UP" {
		healthResponse.Status = "WARNING"
	}

	// Add overall response time
	responseTime := time.Since(startTime).String()
	healthResponse.Components["responseTime"] = Status{
		Status:  "UP",
		Message: responseTime,
	}

	// Set appropriate HTTP status code
	statusCode := http.StatusOK
	if healthResponse.Status == "DOWN" {
		statusCode = http.StatusServiceUnavailable
	} else if healthResponse.Status == "WARNING" {
		statusCode = http.StatusOK // Still return 200 but with warning in payload
	}

	// Return response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(healthResponse)

	// Log health check results
	log.Printf("Health check status: %s, Response time: %s", healthResponse.Status, responseTime)
}

// checkDatabaseHealth checks if the database connection is healthy
func checkDatabaseHealth() Status {
	startTime := time.Now()
	
	// Get database connection from your app's configuration
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		return Status{
			Status:  "DOWN",
			Message: "Failed to open database connection: " + err.Error(),
		}
	}
	defer db.Close()

	// Ping the database
	err = db.Ping()
	if err != nil {
		return Status{
			Status:  "DOWN",
			Message: "Failed to ping database: " + err.Error(),
		}
	}

	// Check connection pool stats
	stats := db.Stats()
	if stats.OpenConnections > 90 { // assuming max connections is 100
		return Status{
			Status:       "WARNING",
			ResponseTime: time.Since(startTime).String(),
			Message:      "High number of open connections: " + string(stats.OpenConnections),
		}
	}

	return Status{
		Status:       "UP",
		ResponseTime: time.Since(startTime).String(),
		Message:      "Database connection pool open connections: " + string(stats.OpenConnections),
	}
}

// checkRedisHealth checks if Redis is responsive
func checkRedisHealth() Status {
	startTime := time.Now()
	
	// Get Redis client from your app's configuration
	rdb := redis.NewClient(&redis.Options{
		Addr:     os.Getenv("REDIS_ADDR"),
		Password: os.Getenv("REDIS_PASSWORD"),
		DB:       0,
	})
	defer rdb.Close()

	// Ping Redis
	ctx := r.Context()
	_, err := rdb.Ping(ctx).Result()
	if err != nil {
		return Status{
			Status:  "DOWN",
			Message: "Failed to ping Redis: " + err.Error(),
		}
	}

	return Status{
		Status:       "UP",
		ResponseTime: time.Since(startTime).String(),
	}
}

// checkDiskSpace checks if there's sufficient disk space
func checkDiskSpace() Status {
	// This is a simplified example - in production you would use os.Stat
	// or a library like diskusage to check actual disk space
	
	// For demonstration:
	threshold := 90.0 // 90% usage threshold
	
	// Simulate checking disk space
	usagePercent := 75.0 // This would be calculated from actual usage
	
	if usagePercent > threshold {
		return Status{
			Status:  "WARNING", 
			Message: "Disk usage is high: " + string(usagePercent) + "%",
		}
	}
	
	return Status{
		Status:  "UP",
		Message: "Disk usage: " + string(usagePercent) + "%",
	}
}
