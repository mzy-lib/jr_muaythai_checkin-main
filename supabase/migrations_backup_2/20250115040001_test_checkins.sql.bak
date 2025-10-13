-- 测试签到场景
DO $$
DECLARE
    v_check_in record;
    v_card_info record;
    v_stats record;
BEGIN
    RAISE NOTICE '开始测试签到场景...';
    
    -- 1. 测试有效团课课时卡签到
    RAISE NOTICE '测试场景1: 有效团课课时卡签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('11111111-1111-1111-1111-111111111111', 'morning', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员A团课签到结果: is_extra = %', v_check_in.is_extra;
    
    -- 查看会员卡剩余次数
    SELECT remaining_group_sessions INTO v_card_info 
    FROM membership_cards 
    WHERE member_id = '11111111-1111-1111-1111-111111111111';
    RAISE NOTICE '会员A团课卡剩余次数: %', v_card_info.remaining_group_sessions;

    -- 2. 测试有效团课月卡签到
    RAISE NOTICE '测试场景2: 有效团课月卡签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('22222222-2222-2222-2222-222222222222', 'morning', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员B团课签到结果: is_extra = %', v_check_in.is_extra;

    -- 3. 测试有效私教卡签到
    RAISE NOTICE '测试场景3: 有效私教卡签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('33333333-3333-3333-3333-333333333333', 'private', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员C私教签到结果: is_extra = %', v_check_in.is_extra;
    
    -- 查看私教卡剩余次数
    SELECT remaining_private_sessions INTO v_card_info 
    FROM membership_cards 
    WHERE member_id = '33333333-3333-3333-3333-333333333333';
    RAISE NOTICE '会员C私教卡剩余次数: %', v_card_info.remaining_private_sessions;

    -- 4. 测试团课课时卡用完签到
    RAISE NOTICE '测试场景4: 团课课时卡用完签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('44444444-4444-4444-4444-444444444444', 'morning', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员D团课签到结果: is_extra = %', v_check_in.is_extra;

    -- 5. 测试无卡会员签到
    RAISE NOTICE '测试场景5: 无卡会员签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('55555555-5555-5555-5555-555555555555', 'morning', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员E团课签到结果: is_extra = %', v_check_in.is_extra;

    -- 6. 测试私教卡用完签到
    RAISE NOTICE '测试场景6: 私教卡用完签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('66666666-6666-6666-6666-666666666666', 'private', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员F私教签到结果: is_extra = %', v_check_in.is_extra;

    -- 7. 测试团课月卡超次数签到（第二次签到）
    RAISE NOTICE '测试场景7: 团课月卡超次数签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('22222222-2222-2222-2222-222222222222', 'evening', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员B团课第二次签到结果: is_extra = %', v_check_in.is_extra;

    -- 8. 测试多卡会员团课签到
    RAISE NOTICE '测试场景8: 多卡会员团课签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('77777777-7777-7777-7777-777777777777', 'morning', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员G团课签到结果: is_extra = %', v_check_in.is_extra;
    
    -- 查看使用的会员卡
    SELECT card_type, card_category, card_subtype INTO v_card_info 
    FROM membership_cards 
    WHERE id = v_check_in.card_id;
    RAISE NOTICE '会员G团课使用的卡类型: % % %', v_card_info.card_type, v_card_info.card_category, v_card_info.card_subtype;

    -- 9. 测试多卡会员私教签到
    RAISE NOTICE '测试场景9: 多卡会员私教签到';
    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('77777777-7777-7777-7777-777777777777', 'private', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '会员G私教签到结果: is_extra = %', v_check_in.is_extra;
    
    -- 查看使用的会员卡和剩余次数
    SELECT card_type, card_category, remaining_private_sessions INTO v_card_info 
    FROM membership_cards 
    WHERE id = v_check_in.card_id;
    RAISE NOTICE '会员G私教使用的卡类型: % %，剩余次数: %', v_card_info.card_type, v_card_info.card_category, v_card_info.remaining_private_sessions;

    -- 查看额外签到统计
    SELECT extra_check_ins INTO v_stats 
    FROM members 
    WHERE id = '55555555-5555-5555-5555-555555555555';
    RAISE NOTICE '无卡会员E的额外签到次数: %', v_stats.extra_check_ins;

    -- 10. 测试新会员签到
    RAISE NOTICE '测试场景10: 新会员签到';
    INSERT INTO members (id, name, email, is_new_member)
    VALUES ('88888888-8888-8888-8888-888888888888', '测试新会员H', 'new_member_h@test.com', true);

    INSERT INTO check_ins (member_id, class_type, check_in_date)
    VALUES ('88888888-8888-8888-8888-888888888888', 'morning', CURRENT_DATE)
    RETURNING is_extra, card_id INTO v_check_in;
    RAISE NOTICE '新会员H签到结果: is_extra = %', v_check_in.is_extra;

    RAISE NOTICE '测试完成';
END $$; 