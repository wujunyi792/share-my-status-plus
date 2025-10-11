# Stage 1: Builder for Go application
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Install build dependencies
 RUN apk add --no-cache git bash

# Copy go.mod and go.sum first to leverage Docker cache
COPY backend/go.mod backend/go.sum ./

RUN go mod download

# Copy the entire source code
COPY backend/ ./

# Make build script executable and run it
RUN chmod +x build.sh && ./build.sh

# Stage 2: Final runtime image
FROM alpine:3.22.0

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata curl bash

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy the built output from builder stage
COPY --from=builder /app/output/ /app/

# Set proper ownership
RUN chown -R appuser:appgroup /app && \
    chmod +x /app/bootstrap.sh

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

# Run the application using bootstrap script
CMD ["/app/bootstrap.sh"]