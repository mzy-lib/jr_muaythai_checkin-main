-- 生成模拟签到记录的SQL脚本
-- 此脚本将直接插入约100条签到记录，临时禁用所有签到表触发器

-- 开始事务
BEGIN;

-- 临时禁用所有签到表触发器
ALTER TABLE check_ins DISABLE TRIGGER deduct_sessions_trigger;
ALTER TABLE check_ins DISABLE TRIGGER update_member_status_trigger;
ALTER TABLE check_ins DISABLE TRIGGER check_card_member_match_trigger;
ALTER TABLE check_ins DISABLE TRIGGER find_valid_card_trigger;
ALTER TABLE check_ins DISABLE TRIGGER update_member_extra_checkins_trigger;
ALTER TABLE check_ins DISABLE TRIGGER validate_check_in_trigger;
ALTER TABLE check_ins DISABLE TRIGGER check_in_validation_trigger;
ALTER TABLE check_ins DISABLE TRIGGER check_in_logging_trigger;
ALTER TABLE check_ins DISABLE TRIGGER update_check_in_stats_trigger;

-- 清空临时表（如果存在）
DROP TABLE IF EXISTS temp_check_ins;

-- 创建临时表用于存储要插入的数据
CREATE TEMP TABLE temp_check_ins (
    member_id UUID,
    check_in_date DATE,
    is_extra BOOLEAN,
    trainer_id UUID,
    is_1v2 BOOLEAN,
    class_time TIME,
    card_id UUID,
    is_private BOOLEAN,
    time_slot TEXT,
    class_type TEXT
);

-- 插入团课签到记录（早课）
INSERT INTO temp_check_ins (member_id, check_in_date, is_extra, trainer_id, is_1v2, class_time, card_id, is_private, time_slot, class_type)
SELECT 
    m.id AS member_id,
    (CURRENT_DATE - (random() * 30)::integer) AS check_in_date,
    (random() > 0.7) AS is_extra,
    NULL AS trainer_id,
    FALSE AS is_1v2,
    '09:00:00'::TIME AS class_time,
    mc.id AS card_id,
    FALSE AS is_private,
    '09:00-10:30' AS time_slot,
    'morning' AS class_type
FROM 
    members m
    LEFT JOIN membership_cards mc ON m.id = mc.member_id AND mc.card_type = '团课'
ORDER BY random()
LIMIT 35;

-- 插入团课签到记录（晚课）
INSERT INTO temp_check_ins (member_id, check_in_date, is_extra, trainer_id, is_1v2, class_time, card_id, is_private, time_slot, class_type)
SELECT 
    m.id AS member_id,
    (CURRENT_DATE - (random() * 30)::integer) AS check_in_date,
    (random() > 0.7) AS is_extra,
    NULL AS trainer_id,
    FALSE AS is_1v2,
    '17:00:00'::TIME AS class_time,
    mc.id AS card_id,
    FALSE AS is_private,
    '17:00-18:30' AS time_slot,
    'evening' AS class_type
FROM 
    members m
    LEFT JOIN membership_cards mc ON m.id = mc.member_id AND mc.card_type = '团课'
ORDER BY random()
LIMIT 35;

-- 获取高级教练ID
WITH senior_trainers AS (
    SELECT id FROM trainers WHERE type = 'senior'
)
-- 插入私教签到记录（高级教练）
INSERT INTO temp_check_ins (member_id, check_in_date, is_extra, trainer_id, is_1v2, class_time, card_id, is_private, time_slot, class_type)
SELECT 
    m.id AS member_id,
    (CURRENT_DATE - (random() * 30)::integer) AS check_in_date,
    (random() > 0.7) AS is_extra,
    t.id AS trainer_id,
    (random() > 0.5) AS is_1v2, -- 50%概率是1对2私教
    CASE floor(random() * 6)
        WHEN 0 THEN '10:30:00'::TIME
        WHEN 1 THEN '11:30:00'::TIME
        WHEN 2 THEN '14:00:00'::TIME
        WHEN 3 THEN '15:00:00'::TIME
        WHEN 4 THEN '16:00:00'::TIME
        WHEN 5 THEN '19:00:00'::TIME
    END AS class_time,
    mc.id AS card_id,
    TRUE AS is_private,
    CASE floor(random() * 6)
        WHEN 0 THEN '10:30-11:30'
        WHEN 1 THEN '11:30-12:30'
        WHEN 2 THEN '14:00-15:00'
        WHEN 3 THEN '15:00-16:00'
        WHEN 4 THEN '16:00-17:00'
        WHEN 5 THEN '19:00-20:00'
    END AS time_slot,
    'private' AS class_type
FROM 
    members m
    CROSS JOIN (SELECT id FROM trainers WHERE type = 'senior' ORDER BY random() LIMIT 1) t
    LEFT JOIN membership_cards mc ON m.id = mc.member_id AND mc.card_type = '私教课'
ORDER BY random()
LIMIT 20;

-- 获取JR教练ID
WITH jr_trainer AS (
    SELECT id FROM trainers WHERE type = 'jr' LIMIT 1
)
-- 插入私教签到记录（JR教练）
INSERT INTO temp_check_ins (member_id, check_in_date, is_extra, trainer_id, is_1v2, class_time, card_id, is_private, time_slot, class_type)
SELECT 
    m.id AS member_id,
    (CURRENT_DATE - (random() * 30)::integer) AS check_in_date,
    (random() > 0.7) AS is_extra,
    t.id AS trainer_id,
    (random() > 0.5) AS is_1v2, -- 50%概率是1对2私教
    CASE floor(random() * 6)
        WHEN 0 THEN '10:30:00'::TIME
        WHEN 1 THEN '11:30:00'::TIME
        WHEN 2 THEN '14:00:00'::TIME
        WHEN 3 THEN '15:00:00'::TIME
        WHEN 4 THEN '16:00:00'::TIME
        WHEN 5 THEN '19:00:00'::TIME
    END AS class_time,
    mc.id AS card_id,
    TRUE AS is_private,
    CASE floor(random() * 6)
        WHEN 0 THEN '10:30-11:30'
        WHEN 1 THEN '11:30-12:30'
        WHEN 2 THEN '14:00-15:00'
        WHEN 3 THEN '15:00-16:00'
        WHEN 4 THEN '16:00-17:00'
        WHEN 5 THEN '19:00-20:00'
    END AS time_slot,
    'private' AS class_type
FROM 
    members m
    CROSS JOIN (SELECT id FROM trainers WHERE type = 'jr' LIMIT 1) t
    LEFT JOIN membership_cards mc ON m.id = mc.member_id AND mc.card_type = '私教课'
ORDER BY random()
LIMIT 10;

-- 从临时表中插入到正式表，排除已存在的签到记录
INSERT INTO check_ins (
    member_id, 
    check_in_date, 
    is_extra, 
    trainer_id, 
    is_1v2, 
    class_time, 
    card_id, 
    is_private, 
    time_slot, 
    class_type
)
SELECT 
    t.member_id, 
    t.check_in_date, 
    t.is_extra, 
    t.trainer_id, 
    t.is_1v2, 
    t.class_time, 
    t.card_id, 
    t.is_private, 
    t.time_slot, 
    t.class_type::class_type
FROM 
    temp_check_ins t
WHERE 
    NOT EXISTS (
        SELECT 1 
        FROM check_ins c 
        WHERE c.member_id = t.member_id 
        AND c.check_in_date = t.check_in_date 
        AND c.time_slot = t.time_slot
    );

-- 获取插入的记录数
SELECT COUNT(*) AS inserted_records FROM check_ins;

-- 清理临时表
DROP TABLE temp_check_ins;

-- 重新启用所有签到表触发器
ALTER TABLE check_ins ENABLE TRIGGER deduct_sessions_trigger;
ALTER TABLE check_ins ENABLE TRIGGER update_member_status_trigger;
ALTER TABLE check_ins ENABLE TRIGGER check_card_member_match_trigger;
ALTER TABLE check_ins ENABLE TRIGGER find_valid_card_trigger;
ALTER TABLE check_ins ENABLE TRIGGER update_member_extra_checkins_trigger;
ALTER TABLE check_ins ENABLE TRIGGER validate_check_in_trigger;
ALTER TABLE check_ins ENABLE TRIGGER check_in_validation_trigger;
ALTER TABLE check_ins ENABLE TRIGGER check_in_logging_trigger;
ALTER TABLE check_ins ENABLE TRIGGER update_check_in_stats_trigger;

-- 提交事务
COMMIT; 