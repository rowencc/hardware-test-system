-- 硬件测试记录系统数据库表结构
-- 使用 MySQL 5.7+ 或 MariaDB

CREATE DATABASE IF NOT EXISTS hardware_test_system 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE hardware_test_system;

-- 设备测试记录表
CREATE TABLE IF NOT EXISTS device_tests (
    id INT PRIMARY KEY AUTO_INCREMENT,
    board_mac VARCHAR(17) NOT NULL COMMENT '板卡MAC地址 (格式: XX:XX:XX:XX:XX:XX)',
    wireless_mac VARCHAR(17) NOT NULL COMMENT '无线MAC地址',
    ip_address VARCHAR(15) NOT NULL COMMENT '设备IP地址',
    status ENUM('normal', 'fault') NOT NULL DEFAULT 'normal' COMMENT '设备状态: normal-正常, fault-故障',
    fault_reason TEXT COMMENT '故障原因/现象 (仅当status=fault时填写)',
    fault_disposition ENUM('待返厂','返厂中','已返厂','pending','stored') NOT NULL DEFAULT 'pending' COMMENT '故障处置: 待返厂/返厂中/已返厂/pending-待处理/stored-已入库',
    return_date DATE COMMENT '返厂日期',
    return_tracking VARCHAR(100) COMMENT '返厂单号/追踪号',
    test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '测试时间',
    operator VARCHAR(50) COMMENT '测试操作员',
    notes TEXT COMMENT '备注',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_board_mac (board_mac),
    INDEX idx_status (status),
    INDEX idx_test_date (test_date),
    INDEX idx_fault_disposition (fault_disposition),
    UNIQUE KEY uk_mac_combo (board_mac, wireless_mac)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='设备测试记录表';

-- 测试统计表 (用于缓存统计结果)
CREATE TABLE IF NOT EXISTS test_statistics (
    id INT PRIMARY KEY AUTO_INCREMENT,
    stat_date DATE NOT NULL COMMENT '统计日期',
    total_tests INT DEFAULT 0 COMMENT '总测试数',
    normal_count INT DEFAULT 0 COMMENT '正常数',
    fault_count INT DEFAULT 0 COMMENT '故障数',
    returned_count INT DEFAULT 0 COMMENT '已返厂数',
    pending_count INT DEFAULT 0 COMMENT '待处理数',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_stat_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='测试统计表';

-- 系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    id INT PRIMARY KEY AUTO_INCREMENT,
    config_key VARCHAR(50) NOT NULL COMMENT '配置键',
    config_value TEXT COMMENT '配置值',
    description VARCHAR(200) COMMENT '配置描述',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统配置表';

-- 插入默认配置
INSERT INTO system_config (config_key, config_value, description) VALUES
('export_path', './exports', '导出文件存储路径'),
('default_operator', 'System', '默认操作员名称'),
('enable_auto_statistics', 'true', '是否启用自动统计'),
('retention_days', '365', '数据保留天数');

-- 创建视图: 设备状态概览
CREATE OR REPLACE VIEW device_overview AS
SELECT 
    DATE(test_date) as test_day,
    COUNT(*) as total_devices,
    SUM(CASE WHEN status = 'normal' THEN 1 ELSE 0 END) as normal_devices,
    SUM(CASE WHEN status = 'fault' THEN 1 ELSE 0 END) as fault_devices,
    SUM(CASE WHEN fault_disposition IN ('待返厂','返厂中','已返厂') THEN 1 ELSE 0 END) as returned_devices,
    SUM(CASE WHEN fault_disposition = 'pending' THEN 1 ELSE 0 END) as pending_devices
FROM device_tests
GROUP BY DATE(test_date)
ORDER BY test_day DESC;

-- 创建存储过程: 更新统计
DELIMITER //
CREATE PROCEDURE update_daily_statistics()
BEGIN
    INSERT INTO test_statistics (stat_date, total_tests, normal_count, fault_count, returned_count, pending_count)
    SELECT 
        CURDATE(),
        COUNT(*),
        SUM(CASE WHEN status = 'normal' THEN 1 ELSE 0 END),
        SUM(CASE WHEN status = 'fault' THEN 1 ELSE 0 END),
        SUM(CASE WHEN fault_disposition IN ('待返厂','返厂中','已返厂') THEN 1 ELSE 0 END),
        SUM(CASE WHEN fault_disposition = 'pending' THEN 1 ELSE 0 END)
    FROM device_tests
    WHERE DATE(test_date) = CURDATE()
    ON DUPLICATE KEY UPDATE
        total_tests = VALUES(total_tests),
        normal_count = VALUES(normal_count),
        fault_count = VALUES(fault_count),
        returned_count = VALUES(returned_count),
        pending_count = VALUES(pending_count);
END //
DELIMITER ;