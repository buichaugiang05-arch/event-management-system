-- Website quản lý sự kiện và đăng ký tham dự
-- ERD v1 | MySQL 8.0+ | InnoDB | utf8mb4
-- Lưu ý: chạy trong database riêng của dự án.
-- Không lưu mật khẩu dạng văn bản thuần; PHP cần password_hash()/password_verify().

CREATE DATABASE IF NOT EXISTS event_management
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE event_management;

CREATE TABLE roles (
    role_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_code VARCHAR(30) NOT NULL UNIQUE,
    role_name VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL
) ENGINE=InnoDB;

CREATE TABLE users (
    user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NULL,
    status ENUM('active', 'inactive', 'locked') NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE user_roles (
    user_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user
      FOREIGN KEY (user_id) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role
      FOREIGN KEY (role_id) REFERENCES roles(role_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE categories (
    category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(120) NOT NULL UNIQUE,
    description VARCHAR(255) NULL,
    status ENUM('active', 'inactive') NOT NULL DEFAULT 'active'
) ENGINE=InnoDB;

CREATE TABLE events (
    event_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_id BIGINT UNSIGNED NULL,
    organizer_id BIGINT UNSIGNED NOT NULL,
    event_name VARCHAR(200) NOT NULL,
    description TEXT NULL,
    location VARCHAR(255) NOT NULL,
    start_at DATETIME NOT NULL,
    end_at DATETIME NOT NULL,
    registration_deadline DATETIME NULL,
    capacity INT UNSIGNED NOT NULL,
    status ENUM('draft', 'published', 'cancelled', 'completed') NOT NULL DEFAULT 'draft',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_events_capacity CHECK (capacity > 0),
    CONSTRAINT chk_events_time CHECK (end_at > start_at),
    CONSTRAINT fk_events_category
      FOREIGN KEY (category_id) REFERENCES categories(category_id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_events_organizer
      FOREIGN KEY (organizer_id) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_events_status_start (status, start_at),
    INDEX idx_events_category (category_id)
) ENGINE=InnoDB;

CREATE TABLE event_sessions (
    session_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id BIGINT UNSIGNED NOT NULL,
    session_title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    speaker_name VARCHAR(150) NULL,
    start_at DATETIME NOT NULL,
    end_at DATETIME NOT NULL,
    session_order INT UNSIGNED NOT NULL DEFAULT 1,
    CONSTRAINT chk_sessions_time CHECK (end_at > start_at),
    CONSTRAINT fk_sessions_event
      FOREIGN KEY (event_id) REFERENCES events(event_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_sessions_event_order (event_id, session_order)
) ENGINE=InnoDB;

CREATE TABLE registrations (
    registration_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    registration_status ENUM('registered', 'cancelled', 'attended', 'rejected') NOT NULL DEFAULT 'registered',
    registered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelled_at DATETIME NULL,
    note VARCHAR(500) NULL,
    CONSTRAINT uq_registration_event_user UNIQUE (event_id, user_id),
    CONSTRAINT fk_registrations_event
      FOREIGN KEY (event_id) REFERENCES events(event_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_registrations_user
      FOREIGN KEY (user_id) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_registrations_event_status (event_id, registration_status),
    INDEX idx_registrations_user_time (user_id, registered_at)
) ENGINE=InnoDB;

CREATE TABLE tickets (
    ticket_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    registration_id BIGINT UNSIGNED NOT NULL UNIQUE,
    ticket_code VARCHAR(60) NOT NULL UNIQUE,
    qr_token CHAR(64) NOT NULL UNIQUE,
    ticket_status ENUM('valid', 'used', 'revoked') NOT NULL DEFAULT 'valid',
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tickets_registration
      FOREIGN KEY (registration_id) REFERENCES registrations(registration_id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE checkins (
    checkin_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT UNSIGNED NOT NULL UNIQUE,
    checked_in_by BIGINT UNSIGNED NULL,
    checked_in_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    method ENUM('qr', 'manual') NOT NULL DEFAULT 'qr',
    note VARCHAR(255) NULL,
    CONSTRAINT fk_checkins_ticket
      FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_checkins_user
      FOREIGN KEY (checked_in_by) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE notifications (
    notification_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    recipient_id BIGINT UNSIGNED NOT NULL,
    event_id BIGINT UNSIGNED NULL,
    channel ENUM('in_app', 'email') NOT NULL DEFAULT 'in_app',
    subject VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    send_status ENUM('pending', 'sent', 'failed', 'read') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at DATETIME NULL,
    CONSTRAINT fk_notifications_recipient
      FOREIGN KEY (recipient_id) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_notifications_event
      FOREIGN KEY (event_id) REFERENCES events(event_id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_notifications_recipient_status (recipient_id, send_status, created_at)
) ENGINE=InnoDB;

-- Dữ liệu vai trò khởi tạo. Không tạo tài khoản quản trị mặc định ở đây.
INSERT INTO roles (role_code, role_name, description) VALUES
('ADMIN', 'Quản trị viên', 'Quản lý tài khoản, phân quyền và danh mục'),
('ORGANIZER', 'Ban tổ chức', 'Tạo và quản lý sự kiện'),
('ATTENDEE', 'Người tham dự', 'Tìm kiếm và đăng ký sự kiện');
