# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# if you located in China, you can use aliyun mirror to speed up
# RUN #sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# Install bash git dos2unix for TypeScript compiler
RUN apk add --no-cache bash git

# Install the pnpm line that still honors package.json pnpm settings.
RUN npm install -g pnpm@9

# Copy the frontend source code (excluding node_modules and build artifacts)
COPY frontend/ ./

# Install all dependencies
RUN pnpm install

# build the project
RUN pnpm run build

# Production image stage
FROM nginx:1.26-alpine

# if you located in China, you can use aliyun mirror to speed up
# RUN #sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# Install necessary tools for SSL configuration
RUN apk add --no-cache bash

# Copy build artifacts to nginx static directory
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
