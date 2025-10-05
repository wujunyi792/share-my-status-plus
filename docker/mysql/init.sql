-- Share My Status Database Initialization Script

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS share_my_status CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use the database
USE share_my_status;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    open_id VARCHAR(255) NOT NULL UNIQUE COMMENT 'Feishu OpenID',
    secret_key VARCHAR(255) NOT NULL UNIQUE COMMENT 'Client secret key for authentication',
    sharing_key VARCHAR(255) NOT NULL UNIQUE COMMENT 'Public sharing key for web access',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_open_id (open_id),
    INDEX idx_secret_key (secret_key),
    INDEX idx_sharing_key (sharing_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User management table';

-- Create status_snapshots table for real-time status storage
CREATE TABLE IF NOT EXISTS status_snapshots (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    snapshot_data JSON NOT NULL COMMENT 'Complete status snapshot in JSON format',
    event_type ENUM('system', 'music', 'activity', 'combined') NOT NULL DEFAULT 'combined',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL COMMENT 'Expiration time for short-term storage',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_expires_at (expires_at),
    INDEX idx_event_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Real-time status snapshots with short-term storage';

-- Create music_stats table for authorized music statistics
CREATE TABLE IF NOT EXISTS music_stats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    artist VARCHAR(256) NOT NULL,
    title VARCHAR(256) NOT NULL,
    album VARCHAR(256) DEFAULT '',
    play_count INT DEFAULT 1,
    first_played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    window_date DATE NOT NULL COMMENT 'Date for time window aggregation',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_track_date (user_id, artist, title, window_date),
    INDEX idx_user_id (user_id),
    INDEX idx_window_date (window_date),
    INDEX idx_artist (artist),
    INDEX idx_play_count (play_count DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Music statistics for authorized users';

-- Create cover_assets table for music cover management
CREATE TABLE IF NOT EXISTS cover_assets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cover_hash VARCHAR(64) NOT NULL UNIQUE COMMENT 'MD5 hash of cover image',
    asset JSON NOT NULL COMMENT 'Cover asset data including base64',
    reference_count INT DEFAULT 1 COMMENT 'Reference count for cleanup',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_cover_hash (cover_hash),
    INDEX idx_reference_count (reference_count),
    INDEX idx_last_accessed_at (last_accessed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Music cover assets with deduplication';

-- Create user_permissions table for privacy controls
CREATE TABLE IF NOT EXISTS user_permissions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    music_collection_enabled BOOLEAN DEFAULT FALSE COMMENT 'Allow music history collection',
    music_stats_enabled BOOLEAN DEFAULT FALSE COMMENT 'Allow music statistics',
    system_monitoring_enabled BOOLEAN DEFAULT TRUE COMMENT 'Allow system metrics collection',
    activity_tracking_enabled BOOLEAN DEFAULT TRUE COMMENT 'Allow activity tracking',
    public_sharing_enabled BOOLEAN DEFAULT TRUE COMMENT 'Allow public web sharing',
    authorized_at TIMESTAMP NULL COMMENT 'When user granted permissions',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User privacy and permission settings';

-- Create audit_logs table for security and compliance
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NULL,
    action VARCHAR(100) NOT NULL COMMENT 'Action performed',
    resource_type VARCHAR(50) NOT NULL COMMENT 'Type of resource affected',
    resource_id VARCHAR(255) NULL COMMENT 'ID of affected resource',
    ip_address VARCHAR(45) NULL COMMENT 'Client IP address',
    user_agent TEXT NULL COMMENT 'Client user agent',
    metadata JSON NULL COMMENT 'Additional action metadata',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_resource_type (resource_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail for security and compliance';

-- Insert default admin user (optional, for testing)
-- INSERT INTO users (open_id, secret_key, sharing_key) VALUES 
-- ('admin_test_user', 'test_secret_key_12345678901234567890', 'test_sharing_key_12345678901234567890')
-- ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Create cleanup event for expired snapshots
SET GLOBAL event_scheduler = ON;

DELIMITER $$
CREATE EVENT IF NOT EXISTS cleanup_expired_snapshots
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    DELETE FROM status_snapshots WHERE expires_at < NOW();
    DELETE FROM cover_assets WHERE reference_count <= 0 AND last_accessed_at < DATE_SUB(NOW(), INTERVAL 7 DAY);
END$$
DELIMITER ;

-- Grant necessary privileges
-- GRANT SELECT, INSERT, UPDATE, DELETE ON share_my_status.* TO 'share_user'@'%';
-- FLUSH PRIVILEGES;