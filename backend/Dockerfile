# Stage 1: Builder for Go application
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git gcc libc-dev ca-certificates tzdata

# Copy go.mod and go.sum first to leverage Docker cache
COPY go.mod go.sum ./
RUN go mod download

# Copy the entire source code
COPY . .

# Build the Go application with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X main.version=1.0.0" -o share-my-status main.go

# Stage 2: Final runtime image
FROM alpine:3.22.0

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata curl

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy the built binary from builder stage
COPY --from=builder /app/share-my-status /app/share-my-status

# Copy configuration files if they exist
COPY --from=builder /app/.env.example /app/.env.example

# Set proper ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Set environment variables
ENV GIN_MODE=release
ENV TZ=Asia/Shanghai

# Run the application
CMD ["/app/share-my-status"]