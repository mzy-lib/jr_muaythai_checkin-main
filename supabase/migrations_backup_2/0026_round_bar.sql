-- Add realistic test members with duplicate check
DO $$ 
BEGIN
  -- Active single daily monthly member (Chinese name with WeChat style)
  IF NOT EXISTS (SELECT 1 FROM members WHERE email = 'xiaofei.mt@example.com') THEN
    INSERT INTO members (name, email, membership, remaining_classes, membership_expiry, is_new_member, created_at)
    VALUES ('拳霸小飞@MT', 'xiaofei.mt@example.com', 'single_daily_monthly', 0, 
            CURRENT_DATE + INTERVAL '30 days', false, NOW());
  END IF;

  -- Active double daily monthly member (English style name)
  IF NOT EXISTS (SELECT 1 FROM members WHERE email = 'tiger.new@example.com') THEN
    INSERT INTO members (name, email, membership, remaining_classes, membership_expiry, is_new_member, created_at)
    VALUES ('Tiger Wong 2024', 'tiger.new@example.com', 'double_daily_monthly', 0,
            CURRENT_DATE + INTERVAL '30 days', false, NOW());
  END IF;

  -- Ten classes package with remaining classes (Mixed style name)
  IF NOT EXISTS (SELECT 1 FROM members WHERE email = 'bruce.lee@example.com') THEN
    INSERT INTO members (name, email, membership, remaining_classes, membership_expiry, is_new_member, created_at)
    VALUES ('李Bruce_Lee', 'bruce.lee@example.com', 'ten_classes', 5,
            NULL, false, NOW());
  END IF;

  -- Ten classes package with no remaining classes (WeChat style name)
  IF NOT EXISTS (SELECT 1 FROM members WHERE email = 'fighter88@example.com') THEN
    INSERT INTO members (name, email, membership, remaining_classes, membership_expiry, is_new_member, created_at)
    VALUES ('MT_Fighter88', 'fighter88@example.com', 'ten_classes', 0,
            NULL, false, NOW());
  END IF;

  -- Expired monthly member (Professional style name)
  IF NOT EXISTS (SELECT 1 FROM members WHERE email = 'mike.chen@example.com') THEN
    INSERT INTO members (name, email, membership, remaining_classes, membership_expiry, is_new_member, created_at)
    VALUES ('Coach Mike Chen', 'mike.chen@example.com', 'single_daily_monthly', 0,
            CURRENT_DATE - INTERVAL '5 days', false, NOW());
  END IF;

  -- New member without membership (Modern Chinese name with special chars)
  IF NOT EXISTS (SELECT 1 FROM members WHERE email = 'kl2024@example.com') THEN
    INSERT INTO members (name, email, membership, remaining_classes, membership_expiry, is_new_member, created_at)
    VALUES ('酷龙-KL2024', 'kl2024@example.com', NULL, 0,
            NULL, true, NOW());
  END IF;
END $$;