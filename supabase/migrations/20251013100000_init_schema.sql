--
-- PostgreSQL database dump
--



-- Dumped from database version 15.8
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: class_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.class_type AS ENUM (
    'morning',
    'evening',
    'private',
    'kids_group',
    'kids group'
);


--
-- Name: membership_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.membership_type AS ENUM (
    'single_class',
    'two_classes',
    'ten_classes',
    'single_monthly',
    'double_monthly'
);


--
-- Name: check_card_member_match(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_card_member_match() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card_member_id UUID;
BEGIN
  -- 如果没有指定会员卡，则跳过验证
  IF NEW.card_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- 获取会员卡所属的会员ID
  SELECT member_id INTO v_card_member_id
  FROM membership_cards
  WHERE id = NEW.card_id;
  
  -- 验证会员卡是否属于该会员
  IF v_card_member_id != NEW.member_id THEN
    RAISE EXCEPTION '会员卡不属于该会员
Membership card does not belong to this member';
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: check_card_validity(uuid, uuid, text, date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card RECORD;
  v_class_type class_type;
  v_is_private boolean;
  v_is_kids_group boolean;
  v_result jsonb;
  v_trainer_type text;
BEGIN
  -- 记录开始验证
  PERFORM log_debug(
    'check_card_validity',
    '开始验证会员卡',
    jsonb_build_object(
      'card_id', p_card_id,
      'member_id', p_member_id,
      'class_type', p_class_type,
      'check_in_date', p_check_in_date,
      'trainer_id', p_trainer_id
    )
  );

  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    -- 修复：使用枚举值比较而非文本比较
    v_is_private := (v_class_type = 'private'::class_type);
    -- 添加：检测是否为儿童团课
    v_is_kids_group := (v_class_type = 'kids group'::class_type);
  EXCEPTION WHEN OTHERS THEN
    PERFORM log_debug(
      'check_card_validity',
      '无效的课程类型',
      jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '无效的课程类型',
      'details', jsonb_build_object(
        'class_type', p_class_type,
        'error', SQLERRM
      )
    );
  END;

  -- 获取会员卡信息
  SELECT *
  INTO v_card
  FROM membership_cards
  WHERE id = p_card_id
  FOR UPDATE;

  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡不存在',
      jsonb_build_object(
        'card_id', p_card_id
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡不存在'
    );
  END IF;

  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡不属于该会员',
      jsonb_build_object(
        'card_member_id', v_card.member_id,
        'requested_member_id', p_member_id
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡不属于该会员'
    );
  END IF;

  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    PERFORM log_debug(
      'check_card_validity',
      '会员卡已过期',
      jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '会员卡已过期',
      'details', jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
  END IF;

  -- 修改：检查卡类型是否匹配课程类型，添加儿童团课支持
  IF (v_card.card_type = '私教课' AND NOT v_is_private) OR
     (v_card.card_type = '团课' AND v_is_private) OR
     (v_card.card_type = '儿童团课' AND NOT v_is_kids_group) OR
     (v_card.card_type != '儿童团课' AND v_is_kids_group) THEN
    PERFORM log_debug(
      'check_card_validity',
      '卡类型不匹配课程类型',
      jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', p_class_type,
        'is_private', v_is_private,
        'is_kids_group', v_is_kids_group
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '卡类型不匹配课程类型',
      'details', jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', p_class_type,
        'is_private', v_is_private,
        'is_kids_group', v_is_kids_group
      )
    );
  END IF;

  -- 检查私教课时是否足够
  IF v_card.card_type = '私教课' AND
     (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
    PERFORM log_debug(
      'check_card_validity',
      '私教课时不足',
      jsonb_build_object(
        'remaining_private_sessions', v_card.remaining_private_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '私教课时不足',
      'details', jsonb_build_object(
        'remaining_private_sessions', v_card.remaining_private_sessions
      )
    );
  END IF;

  -- 检查团课课时是否足够
  IF v_card.card_type = '团课' AND v_card.card_category = '课时卡' AND
     (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
    PERFORM log_debug(
      'check_card_validity',
      '团课课时不足',
      jsonb_build_object(
        'remaining_group_sessions', v_card.remaining_group_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '团课课时不足',
      'details', jsonb_build_object(
        'remaining_group_sessions', v_card.remaining_group_sessions
      )
    );
  END IF;

  -- 添加：检查儿童团课课时是否足够
  IF v_card.card_type = '儿童团课' AND
     (v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions <= 0) THEN
    PERFORM log_debug(
      'check_card_validity',
      '儿童团课课时不足',
      jsonb_build_object(
        'remaining_kids_sessions', v_card.remaining_kids_sessions
      )
    );
    RETURN jsonb_build_object(
      'is_valid', false,
      'reason', '儿童团课课时不足',
      'details', jsonb_build_object(
        'remaining_kids_sessions', v_card.remaining_kids_sessions
      )
    );
  END IF;

  -- 会员卡有效
  RETURN jsonb_build_object(
    'is_valid', true,
    'card_info', jsonb_build_object(
      'card_id', v_card.id,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'card_subtype', v_card.card_subtype,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions,
      'remaining_kids_sessions', v_card.remaining_kids_sessions
    )
  );
END;
$$;


--
-- Name: check_card_validity_detailed(uuid, uuid, text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_card_validity_detailed(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card RECORD;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡不存在',
      'details', jsonb_build_object('card_id', p_card_id)
    );
  END IF;
  
  -- 检查会员卡是否属于该会员
  IF v_card.member_id != p_member_id THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡不属于该会员',
      'details', jsonb_build_object(
        'card_member_id', v_card.member_id,
        'requested_member_id', p_member_id
      )
    );
  END IF;
  
  -- 检查会员卡是否过期
  IF v_card.valid_until IS NOT NULL AND v_card.valid_until < p_check_in_date THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '会员卡已过期',
      'details', jsonb_build_object(
        'valid_until', v_card.valid_until,
        'check_in_date', p_check_in_date
      )
    );
  END IF;
  
  -- 检查卡类型是否匹配课程类型
  IF (v_card.card_type = '团课' AND p_class_type = 'private') OR 
     (v_card.card_type = '私教课' AND p_class_type != 'private') THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '卡类型不匹配课程类型',
      'details', jsonb_build_object(
        'card_type', v_card.card_type,
        'class_type', p_class_type
      )
    );
  END IF;
  
  -- 检查团课课时卡课时是否足够
  IF v_card.card_type = '团课' AND v_card.card_category = '课时卡' AND
     (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '团课课时不足',
      'details', jsonb_build_object(
        'remaining_group_sessions', v_card.remaining_group_sessions
      )
    );
  END IF;
  
  -- 检查私教课时是否足够
  IF v_card.card_type = '私教课' AND
     (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN
    RETURN jsonb_build_object(
      'is_valid', FALSE,
      'reason', '私教课时不足',
      'details', jsonb_build_object(
        'remaining_private_sessions', v_card.remaining_private_sessions
      )
    );
  END IF;
  
  -- 会员卡有效
  RETURN jsonb_build_object(
    'is_valid', TRUE,
    'card_info', jsonb_build_object(
      'card_id', v_card.id,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'card_subtype', v_card.card_subtype,
      'valid_until', v_card.valid_until,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_private_sessions', v_card.remaining_private_sessions
    )
  );
END;
$$;


--
-- Name: check_duplicate_check_in(uuid, date, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 记录调用信息，但始终返回false
  PERFORM log_debug(
    'check_duplicate_check_in',
    '重复签到检查已被禁用，始终允许签到',
    jsonb_build_object(
      'member_id', p_member_id,
      'date', p_date,
      'class_type', p_class_type,
      'time_slot', p_time_slot
    )
  );
  
  -- 始终返回false，绝不阻止签到
  RETURN FALSE;
END;
$$;


--
-- Name: check_duplicate_check_in(uuid, date, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_check_in_date date, p_class_type text, p_ignore_is_1v2 boolean DEFAULT false, p_check_trainer boolean DEFAULT false) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 始终返回false，不阻止重复签到(保持现有行为)
    -- 但记录检测到的情况，使用文本比较
    IF EXISTS (
        SELECT 1
        FROM check_ins
        WHERE member_id = p_member_id
          AND check_in_date = p_check_in_date
          AND class_type::TEXT = p_class_type
          AND NOT is_extra
    ) THEN
        -- 记录检测到重复签到
        PERFORM log_debug(
            'check_duplicate_check_in', 
            '检测到重复签到', 
            jsonb_build_object(
                'member_id', p_member_id,
                'check_in_date', p_check_in_date,
                'class_type', p_class_type
            )
        );
        -- 但仍然返回false，允许签到
        RETURN false;
    END IF;
    
    RETURN false;
END;
$$;


--
-- Name: check_duplicate_check_in_bool(uuid, date, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_duplicate_check_in_bool(p_member_id uuid, p_date date, p_class_type text, p_time_slot text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := check_duplicate_check_in(p_member_id, p_date, p_class_type, p_time_slot);
  -- 返回是否有重复，但仅用于兼容旧代码，不阻止签到
  RETURN false; -- 总是返回false，允许重复签到
END;
$$;


--
-- Name: check_duplicate_membership_cards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_duplicate_membership_cards() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 检查是否已存在相同会员、相同卡类型和子类型的卡
    IF EXISTS (
        SELECT 1 FROM membership_cards 
        WHERE member_id = NEW.member_id 
        AND card_type = NEW.card_type 
        AND card_subtype = NEW.card_subtype
        AND id != NEW.id
    ) THEN
        RAISE EXCEPTION '会员已有相同类型和子类型的卡，请更新现有卡或选择不同的卡类型';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION check_duplicate_membership_cards(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.check_duplicate_membership_cards() IS '检查并防止插入或更新重复的会员卡';


--
-- Name: check_in_logging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_in_logging() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_member RECORD;
  v_card RECORD;
  v_trainer RECORD;
BEGIN
  -- Get member info
  SELECT name, email INTO v_member
  FROM members
  WHERE id = NEW.member_id;

  -- Get card info if exists
  SELECT id, card_type, card_category, card_subtype
  INTO v_card
  FROM membership_cards
  WHERE id = NEW.card_id;

  -- Get trainer info if exists
  SELECT name, type INTO v_trainer
  FROM trainers
  WHERE id = NEW.trainer_id;

  -- Log check-in details
  INSERT INTO check_in_logs (
    check_in_id,
    details,
    created_at
  ) VALUES (
    NEW.id,
    jsonb_build_object(
      'member_name', v_member.name,
      'member_email', v_member.email,
      'check_in_date', NEW.check_in_date,
      'time_slot', NEW.time_slot,
      'is_extra', NEW.is_extra,
      'is_private', NEW.is_private,
      'is_1v2', NEW.is_1v2,
      'card_id', NEW.card_id,
      'card_info', CASE WHEN v_card.id IS NOT NULL THEN 
        jsonb_build_object(
          'card_type', v_card.card_type,
          'card_category', v_card.card_category,
          'card_subtype', v_card.card_subtype
        )
      ELSE NULL END,
      'trainer_info', CASE WHEN v_trainer.name IS NOT NULL THEN
        jsonb_build_object(
          'name', v_trainer.name,
          'type', v_trainer.type
        )
      ELSE NULL END
    ),
    NOW()
  );

  RETURN NEW;
END;
$$;


--
-- Name: check_in_validation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_in_validation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_duplicate_check_in RECORD;
  v_time_slot_valid boolean;
BEGIN
  -- 验证时间段格式
  IF NEW.time_slot IS NULL OR NEW.time_slot = '' THEN
    RAISE EXCEPTION '时间段不能为空
Time slot cannot be empty';
  END IF;

  -- 验证时间段有效性
  SELECT validate_time_slot(NEW.time_slot, NEW.check_in_date, NEW.is_private) INTO v_time_slot_valid;
  IF NOT v_time_slot_valid THEN
    RAISE EXCEPTION '无效的时间段: %
Invalid time slot: %', NEW.time_slot, NEW.time_slot;
  END IF;

  -- 设置课程类型
  IF NEW.is_private THEN
    NEW.class_type := 'private'::class_type;
  ELSE
    -- 根据时间段判断是上午还是下午课程
    IF NEW.time_slot = '09:00-10:30' THEN
      NEW.class_type := 'morning'::class_type;
    ELSE
      NEW.class_type := 'evening'::class_type;
    END IF;
  END IF;

  -- 检查是否有重复签到（修改：考虑课程类型）
  -- 原来的代码会检查相同会员、日期、时间段和是否私教，现在我们修改为检查相同会员、日期、时间段和相同课程类型
  SELECT * INTO v_duplicate_check_in
  FROM check_ins
  WHERE member_id = NEW.member_id
    AND check_in_date = NEW.check_in_date
    AND time_slot = NEW.time_slot
    AND class_type = NEW.class_type
    AND id IS DISTINCT FROM NEW.id
  LIMIT 1;

  IF FOUND THEN
    IF NEW.is_private THEN
      RAISE EXCEPTION '今天已经在这个时间段签到过私教课
Already checked in for private class at this time slot today';
    ELSE
      RAISE EXCEPTION '今天已经在这个时间段签到过团课
Already checked in for group class at this time slot today';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: check_member_exists(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_member_exists(p_member_id uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_member RECORD;
BEGIN
  -- 允许会员ID为NULL的情况
  IF p_member_id IS NULL THEN
    -- 记录NULL会员ID的调用
    PERFORM log_debug(
      'check_member_exists',
      '访客签到 - 会员ID为NULL',
      jsonb_build_object(
        'member_id', NULL,
        'exists', false,
        'is_guest', true
      )
    );
    RETURN false; -- 返回false表示不是已存在会员
  END IF;

  -- 获取会员信息
  SELECT *
  INTO v_member
  FROM members
  WHERE id = p_member_id;

  -- 记录验证日志
  PERFORM log_debug(
    'check_member_exists',
    CASE WHEN FOUND THEN '会员验证成功' ELSE '会员不存在' END,
    jsonb_build_object(
      'member_id', p_member_id,
      'exists', FOUND,
      'details', CASE 
        WHEN FOUND THEN jsonb_build_object(
          'name', v_member.name,
          'email', v_member.email,
          'is_new_member', v_member.is_new_member,
          'created_at', v_member.created_at
        )
        ELSE NULL
      END
    )
  );

  RETURN FOUND;
END;
$$;


--
-- Name: check_monthly_card_daily_limit(uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_monthly_card_daily_limit(p_member_id uuid, p_card_id uuid, p_date date) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card RECORD;
  v_daily_check_ins INTEGER;
BEGIN
  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = p_card_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- 如果不是月卡，直接返回true
  IF v_card.card_type != '团课' OR v_card.card_category != '月卡' THEN
    RETURN TRUE;
  END IF;
  
  -- 获取当天非额外签到的次数
  SELECT COUNT(*) INTO v_daily_check_ins 
  FROM check_ins 
  WHERE member_id = p_member_id 
  AND check_in_date = p_date 
  AND NOT is_extra;
  
  -- 根据月卡类型检查每日签到次数限制
  IF v_card.card_subtype = '单次月卡' AND v_daily_check_ins >= 1 THEN
    RETURN FALSE;
  ELSIF v_card.card_subtype = '双次月卡' AND v_daily_check_ins >= 2 THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$;


--
-- Name: check_trainer_level_match(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_trainer_level_match(p_card_trainer_type text, p_trainer_type text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 如果会员卡要求高级教练，但实际教练是初级，返回false
  IF p_card_trainer_type = 'senior' AND p_trainer_type = 'jr' THEN
    RETURN FALSE;
  END IF;

  -- 其他情况都返回true
  RETURN TRUE;
END;
$$;


--
-- Name: check_valid_cards(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_valid_cards(p_member_id uuid, p_card_type text, p_current_card_id uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_existing_card_id UUID;
BEGIN
  -- 查找除了当前卡之外的其他有效卡
  SELECT id INTO v_existing_card_id
  FROM membership_cards
  WHERE member_id = p_member_id
    AND card_type = p_card_type
    AND id != COALESCE(p_current_card_id, '00000000-0000-0000-0000-000000000000'::UUID)
    AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
    AND (
      (card_type = '团课' AND (
        (card_category = '课时卡' AND remaining_group_sessions > 0) OR
        card_category = '月卡'
      )) OR
      (card_type = '私教课' AND remaining_private_sessions > 0)
    );

  -- 记录检查结果
  PERFORM log_debug(
    'check_valid_cards',
    '检查有效卡',
    jsonb_build_object(
      'member_id', p_member_id,
      'card_type', p_card_type,
      'current_card_id', p_current_card_id,
      'existing_card_id', v_existing_card_id,
      'has_valid_card', v_existing_card_id IS NOT NULL
    )
  );

  RETURN v_existing_card_id IS NULL;
END;
$$;


--
-- Name: convert_time_slot_to_class_type(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.convert_time_slot_to_class_type(p_time_slot text) RETURNS public.class_type
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN CASE 
    WHEN p_time_slot = '09:00-10:30' THEN 'morning'::class_type
    WHEN p_time_slot = '17:00-18:30' THEN 'evening'::class_type
    ELSE 'morning'::class_type  -- Default to morning for private classes
  END;
END;
$$;


--
-- Name: deduct_membership_sessions(uuid, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean DEFAULT false, p_is_1v2 boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card RECORD;
  v_class_type text;
  v_is_private boolean;
  v_is_kids_group boolean;
  v_deduct_sessions INTEGER;
BEGIN
  -- 锁定会员卡记录
  SELECT * INTO v_card 
  FROM membership_cards 
  WHERE id = p_card_id 
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '会员卡不存在';
  END IF;

  -- 使用传入的is_private参数
  v_is_private := COALESCE(p_is_private, false);
  
  -- 判断是否为儿童团课（支持多种格式）
  -- 使用LIKE操作符提高匹配灵活性
  v_is_kids_group := (p_class_type LIKE '%kids%' OR p_class_type LIKE '%儿童%');
  
  -- 记录课程类型
  v_class_type := p_class_type;

  -- 记录开始扣除课时
  PERFORM log_debug(
    'deduct_membership_sessions',
    '开始扣除课时',
    jsonb_build_object(
      'card_id', p_card_id,
      'class_type', p_class_type,
      'is_private', v_is_private,
      'is_kids_group', v_is_kids_group,
      'is_1v2', p_is_1v2,
      'card_type', v_card.card_type,
      'card_category', v_card.card_category,
      'remaining_private_sessions', v_card.remaining_private_sessions,
      'remaining_group_sessions', v_card.remaining_group_sessions,
      'remaining_kids_sessions', v_card.remaining_kids_sessions
    )
  );
  
  -- 私教课
  IF v_is_private AND v_card.card_type = '私教课' THEN
    -- 统一扣除1次课时（1对1和1对2都一样）
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_private_sessions < v_deduct_sessions THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '私教课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_private_sessions', v_card.remaining_private_sessions
        )
      );
      RAISE EXCEPTION '私教课时不足';
    END IF;
    
    -- 扣除私教课时
    UPDATE membership_cards 
    SET remaining_private_sessions = remaining_private_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
    -- 记录扣除课时完成
    PERFORM log_debug(
      'deduct_membership_sessions',
      '私教课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_private_sessions', v_card.remaining_private_sessions - v_deduct_sessions
      )
    );
  
  -- 儿童团课 - 优先判断是否是儿童团课，因为它是团课的特殊类型
  ELSIF v_is_kids_group AND (v_card.card_type = '儿童团课' OR v_card.card_type LIKE '%kids%') THEN
    -- 儿童团课扣除1次课时
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_kids_sessions IS NULL OR v_card.remaining_kids_sessions < v_deduct_sessions THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '儿童团课课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_kids_sessions', v_card.remaining_kids_sessions
        )
      );
      RAISE EXCEPTION '儿童团课课时不足';
    END IF;
    
    -- 扣除儿童团课课时
    UPDATE membership_cards 
    SET remaining_kids_sessions = remaining_kids_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
    -- 记录扣除课时完成
    PERFORM log_debug(
      'deduct_membership_sessions',
      '儿童团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_kids_sessions', v_card.remaining_kids_sessions - v_deduct_sessions
      )
    );
  
  -- 团课
  ELSIF NOT v_is_private AND NOT v_is_kids_group AND v_card.card_type = '团课' AND v_card.card_category = '课时卡' THEN
    -- 团课扣除1次课时
    v_deduct_sessions := 1;
    
    -- 检查剩余课时是否足够
    IF v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions < v_deduct_sessions THEN
      PERFORM log_debug(
        'deduct_membership_sessions',
        '团课课时不足',
        jsonb_build_object(
          'card_id', p_card_id,
          'remaining_group_sessions', v_card.remaining_group_sessions
        )
      );
      RAISE EXCEPTION '团课课时不足';
    END IF;
    
    -- 扣除团课课时
    UPDATE membership_cards 
    SET remaining_group_sessions = remaining_group_sessions - v_deduct_sessions
    WHERE id = p_card_id;
    
    -- 记录扣除课时完成
    PERFORM log_debug(
      'deduct_membership_sessions',
      '团课课时已扣除',
      jsonb_build_object(
        'card_id', p_card_id,
        'remaining_group_sessions', v_card.remaining_group_sessions - v_deduct_sessions
      )
    );
  
  -- 其他情况，记录但不扣除
  ELSE
    PERFORM log_debug(
      'deduct_membership_sessions',
      '未找到匹配的卡类型和课程类型组合，不扣除课时',
      jsonb_build_object(
        'card_id', p_card_id,
        'class_type', p_class_type,
        'is_private', v_is_private,
        'is_kids_group', v_is_kids_group,
        'card_type', v_card.card_type,
        'card_category', v_card.card_category
      )
    );
  END IF;
  
  -- 最终记录
  PERFORM log_debug(
    'deduct_membership_sessions',
    '扣除课时完成',
    jsonb_build_object(
      'card_id', p_card_id,
      'deducted_sessions', v_deduct_sessions,
      'remaining_private_sessions', CASE 
        WHEN v_is_private THEN v_card.remaining_private_sessions - v_deduct_sessions
        ELSE v_card.remaining_private_sessions
      END,
      'remaining_group_sessions', CASE
        WHEN NOT v_is_private AND NOT v_is_kids_group THEN v_card.remaining_group_sessions - v_deduct_sessions
        ELSE v_card.remaining_group_sessions
      END,
      'remaining_kids_sessions', CASE
        WHEN v_is_kids_group THEN v_card.remaining_kids_sessions - v_deduct_sessions
        ELSE v_card.remaining_kids_sessions
      END
    )
  );
END;
$$;


--
-- Name: delete_member(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_member(p_member_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- 调用级联删除函数
    PERFORM delete_member_cascade(p_member_id);
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;


--
-- Name: FUNCTION delete_member(p_member_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.delete_member(p_member_id uuid) IS '删除会员的API函数，供前端调用';


--
-- Name: delete_member_cascade(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_member_cascade(p_member_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 记录开始删除会员
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('delete_member_cascade', '开始删除会员及相关数据',
        jsonb_build_object(
            'member_id', p_member_id
        )
    );
    
    -- 删除会员的会员卡
    DELETE FROM membership_cards
    WHERE member_id = p_member_id;
    
    -- 删除会员的签到记录（会自动级联删除check_in_logs中的记录）
    DELETE FROM check_ins
    WHERE member_id = p_member_id;
    
    -- 最后删除会员记录
    DELETE FROM members
    WHERE id = p_member_id;
    
    -- 记录删除完成
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('delete_member_cascade', '会员及相关数据删除完成',
        jsonb_build_object(
            'member_id', p_member_id
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        -- 记录删除失败
        INSERT INTO debug_logs (function_name, message, details)
        VALUES ('delete_member_cascade', '删除会员失败',
            jsonb_build_object(
                'member_id', p_member_id,
                'error', SQLERRM,
                'error_detail', SQLSTATE
            )
        );
        RAISE;
END;
$$;


--
-- Name: FUNCTION delete_member_cascade(p_member_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.delete_member_cascade(p_member_id uuid) IS '级联删除会员及其相关数据，包括会员卡、签到记录和签到日志';


--
-- Name: detect_check_in_anomalies(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.detect_check_in_anomalies() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO check_in_anomalies (check_in_id, member_id, check_in_date, issue_type, description, valid_cards)
  SELECT 
    c.id,
    c.member_id,
    c.check_in_date,
    'Missing Valid Card',
    '会员有有效卡但被标记为额外签到',
    jsonb_agg(jsonb_build_object(
      'card_id', mc.id,
      'card_type', mc.card_type,
      'card_category', mc.card_category,
      'remaining_sessions', mc.remaining_group_sessions
    ))
  FROM check_ins c
  JOIN membership_cards mc ON c.member_id = mc.member_id
  WHERE 
    c.is_extra = true 
    AND c.is_private = false
    AND mc.card_type IN ('团课', 'group', 'class')
    AND (mc.remaining_group_sessions IS NULL OR mc.remaining_group_sessions > 0)
    AND (mc.valid_until IS NULL OR mc.valid_until >= c.check_in_date)
    AND NOT EXISTS (
      SELECT 1 FROM check_in_anomalies WHERE check_in_id = c.id
    )
  GROUP BY c.id, c.member_id, c.check_in_date;
END;
$$;


--
-- Name: find_member_for_checkin(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_member_for_checkin(p_name text, p_email text) RETURNS TABLE(member_id uuid, is_new boolean, needs_email boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_normalized_name text;
    v_normalized_email text;
    v_base_email text;
    v_email_username text;
    v_email_domain text;
    v_found boolean := false;
BEGIN
    -- Input validation
    IF TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Name cannot be empty';
    END IF;

    -- Normalize inputs
    v_normalized_name := LOWER(TRIM(p_name));
    v_normalized_email := LOWER(TRIM(p_email));

    -- 提取邮箱的用户名和域名部分
    IF v_normalized_email IS NOT NULL AND v_normalized_email LIKE '%@%' THEN
        v_email_username := SPLIT_PART(v_normalized_email, '@', 1);
        v_email_domain := SPLIT_PART(v_normalized_email, '@', 2);
        
        -- 处理邮箱别名 (user+tag@domain.com)
        IF v_email_username LIKE '%+%' THEN
            v_base_email := SPLIT_PART(v_email_username, '+', 1) || '@' || v_email_domain;
        ELSE
            v_base_email := v_normalized_email;
        END IF;
    ELSE
        v_base_email := v_normalized_email;
    END IF;

    -- 记录调试信息
    RAISE NOTICE 'Email matching: original=%, normalized=%, base=%', 
        p_email, v_normalized_email, v_base_email;

    -- 首先尝试使用精确匹配
    FOR member_id, is_new, needs_email IN
        SELECT
            m.id,
            m.is_new_member,
            false AS needs_email
        FROM members m
        WHERE LOWER(TRIM(m.name)) = v_normalized_name
        AND (
            -- 精确匹配邮箱
            LOWER(TRIM(m.email)) = v_normalized_email
            OR
            -- 如果提供了邮箱，尝试匹配基本邮箱（去除+标签部分）
            (v_normalized_email IS NOT NULL AND v_base_email != v_normalized_email AND v_base_email = LOWER(TRIM(m.email)))
            OR
            -- 反向匹配：数据库中存储的是带+的邮箱，而用户输入的是基本邮箱
            (v_normalized_email IS NOT NULL AND
             LOWER(TRIM(m.email)) LIKE '%+%@%' AND
             SPLIT_PART(SPLIT_PART(LOWER(TRIM(m.email)), '@', 1), '+', 1) || '@' || SPLIT_PART(LOWER(TRIM(m.email)), '@', 2) = v_normalized_email)
            OR
            -- 特殊情况：hongyi+jhholy@hotmail.com 与 jhholy@hotmail.com 匹配
            (v_normalized_email LIKE 'hongyi+%@hotmail.com' AND
             LOWER(TRIM(m.email)) = 'jhholy@hotmail.com')
            OR
            -- 特殊情况：jhholy@hotmail.com 与 hongyi+jhholy@hotmail.com 匹配
            (v_normalized_email = 'jhholy@hotmail.com' AND
             LOWER(TRIM(m.email)) LIKE 'hongyi+%@hotmail.com')
        )
    LOOP
        v_found := true;
        RETURN NEXT;
    END LOOP;

    -- 如果找到记录，直接返回
    IF v_found THEN
        RETURN;
    END IF;

    -- 如果没有找到精确匹配，但提供了邮箱，检查是否有同名会员
    IF v_normalized_email IS NOT NULL THEN
        RETURN QUERY
        SELECT
            NULL::uuid AS member_id,
            true AS is_new,
            EXISTS (
                SELECT 1 FROM members
                WHERE LOWER(TRIM(name)) = v_normalized_name
            ) AS needs_email;
        RETURN;
    END IF;

    -- 如果没有找到记录，返回null和true表示新会员
    RETURN QUERY SELECT NULL::uuid, true::boolean, false::boolean;
END;
$$;


--
-- Name: FUNCTION find_member_for_checkin(p_name text, p_email text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.find_member_for_checkin(p_name text, p_email text) IS 'Finds a member for check-in by name and email, with support for email aliases (user+tag@domain.com)';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    phone text,
    extra_check_ins integer DEFAULT 0 NOT NULL,
    is_new_member boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    daily_check_ins integer DEFAULT 0,
    last_check_in_date date
);


--
-- Name: TABLE members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.members IS 'Updated 2024-03-20: Fixed new member status for test members';


--
-- Name: find_members_without_cards(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_members_without_cards() RETURNS SETOF public.members
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT m.*
  FROM members m
  LEFT JOIN membership_cards c ON m.id = c.member_id
  WHERE c.id IS NULL;
END;
$$;


--
-- Name: find_valid_card_for_checkin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_valid_card_for_checkin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card_id UUID;
  v_card_count INTEGER;
  v_card_records RECORD;
  v_member_name TEXT;
  v_class_type TEXT;
  v_sql TEXT;
  v_is_private BOOLEAN := NEW.is_private;
  v_is_kids_group BOOLEAN := (NEW.class_type::TEXT IN ('kids_group', 'kids group'));
  v_is_normal_group BOOLEAN := (NEW.class_type::TEXT IN ('morning', 'evening') AND NOT NEW.is_private);
  -- 新增变量，用于记录卡类型匹配的详细信息
  v_match_details jsonb;
  v_all_cards jsonb;
BEGIN
  -- 跳过访客签到(member_id为NULL)或已指定会员卡
  IF NEW.member_id IS NULL OR NEW.card_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- 获取会员姓名用于日志
  SELECT name INTO v_member_name FROM members WHERE id = NEW.member_id;

  -- 记录函数开始执行
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('find_valid_card_for_checkin', '开始查找会员卡',
    jsonb_build_object(
      'member_id', NEW.member_id,
      'member_name', v_member_name,
      'check_in_date', NEW.check_in_date,
      'class_type', NEW.class_type,
      'is_private', v_is_private,
      'is_kids_group', v_is_kids_group,
      'is_normal_group', v_is_normal_group,
      'time_slot', NEW.time_slot
    )
  );

  -- 获取并记录所有可能匹配的会员卡，包括详细的字符长度和编码信息
  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'card_type', card_type,
    'card_type_length', length(card_type),
    'card_type_bytea', encode(convert_to(card_type, 'UTF8'), 'hex'),
    'card_category', card_category,
    'card_category_length', length(card_category),
    'card_category_bytea', encode(convert_to(card_category, 'UTF8'), 'hex'),
    'valid_until', valid_until,
    'remaining_group_sessions', remaining_group_sessions,
    'remaining_private_sessions', remaining_private_sessions,
    'remaining_kids_sessions', remaining_kids_sessions
  ))
  INTO v_all_cards
  FROM membership_cards
  WHERE member_id = NEW.member_id;

  -- 记录所有会员卡的详细信息
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('find_valid_card_for_checkin', '会员所有卡详细信息', v_all_cards);

  -- 记录即将执行的匹配条件
  IF v_is_private THEN
    v_match_details := jsonb_build_object(
      'match_type', '私教课卡',
      'expected_card_types', jsonb_build_array('私教课', 'private'),
      'require_remaining_sessions', true,
      'check_valid_until', true
    );
  ELSIF v_is_kids_group THEN
    v_match_details := jsonb_build_object(
      'match_type', '儿童团课卡',
      'expected_card_types', jsonb_build_array('儿童团课'),
      'require_remaining_sessions', true,
      'check_valid_until', true
    );
  ELSIF v_is_normal_group THEN
    v_match_details := jsonb_build_object(
      'match_type', '普通团课卡',
      'expected_card_types', jsonb_build_array('团课', 'group', 'class'),
      'expected_card_categories', jsonb_build_array('课时卡', 'session', '月卡', 'monthly'),
      'require_remaining_sessions', true,
      'check_valid_until', true
    );
  END IF;

  -- 记录匹配条件
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('find_valid_card_for_checkin', '卡类型匹配条件', v_match_details);

  -- 根据课程类型查找会员卡
  IF v_is_private THEN
    -- 查找私教课卡 - 兼容中英文卡类型
    SELECT id INTO v_card_id
    FROM membership_cards
    WHERE member_id = NEW.member_id
      AND (card_type = '私教课' OR card_type = 'private')
      AND (remaining_private_sessions IS NULL OR remaining_private_sessions > 0)
      AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)
    LIMIT 1;
  ELSIF v_is_kids_group THEN
    -- 查找儿童团课卡 - 保持原样，因为不常见其他命名
    SELECT id INTO v_card_id
    FROM membership_cards
    WHERE member_id = NEW.member_id
      AND card_type = '儿童团课'
      AND (remaining_kids_sessions IS NULL OR remaining_kids_sessions > 0)
      AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)
    LIMIT 1;
  ELSIF v_is_normal_group THEN
    -- 查找普通团课卡 - 兼容多种命名
    SELECT id INTO v_card_id
    FROM membership_cards
    WHERE member_id = NEW.member_id
      AND (card_type = '团课' OR card_type = 'group' OR card_type = 'class')
      AND ((card_category IN ('课时卡', 'session') AND (remaining_group_sessions IS NULL OR remaining_group_sessions > 0))
           OR card_category IN ('月卡', 'monthly'))
      AND (valid_until IS NULL OR valid_until >= NEW.check_in_date)
    LIMIT 1;
  END IF;

  -- 如果找到了卡，记录找到的具体会员卡信息
  IF v_card_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'id', id,
      'card_type', card_type,
      'card_type_length', length(card_type),
      'card_type_bytea', encode(convert_to(card_type, 'UTF8'), 'hex'),
      'card_category', card_category,
      'card_category_length', length(card_category),
      'card_category_bytea', encode(convert_to(card_category, 'UTF8'), 'hex'),
      'valid_until', valid_until,
      'remaining_group_sessions', remaining_group_sessions
    ) INTO v_match_details
    FROM membership_cards
    WHERE id = v_card_id;

    -- 记录匹配到的会员卡详细信息
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('find_valid_card_for_checkin', '匹配到的会员卡详细信息', v_match_details);
  END IF;

  -- 记录查找结果
  INSERT INTO debug_logs (function_name, message, details)
  VALUES ('find_valid_card_for_checkin',
    CASE WHEN v_card_id IS NOT NULL THEN '找到有效会员卡' ELSE '未找到有效会员卡' END,
    jsonb_build_object(
      'member_id', NEW.member_id,
      'card_id', v_card_id,
      'class_type', NEW.class_type,
      'is_private', v_is_private,
      'is_kids_group', v_is_kids_group,
      'is_normal_group', v_is_normal_group
    )
  );

  -- 设置卡ID和额外签到标记
  IF v_card_id IS NOT NULL THEN
    NEW.card_id := v_card_id;
    NEW.is_extra := false;
  ELSE
    NEW.is_extra := true;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: fix_member_extra_checkins(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fix_member_extra_checkins() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_member_id UUID;
    v_actual_count INTEGER;
    v_current_count INTEGER;
    v_updated_count INTEGER := 0;
BEGIN
    -- 记录开始修复
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'fix_member_extra_checkins',
        '开始修复会员额外签到计数',
        jsonb_build_object('timestamp', NOW())
    );
    
    -- 遍历所有会员
    FOR v_member_id, v_current_count IN 
        SELECT id, COALESCE(extra_check_ins, 0) 
        FROM members
    LOOP
        -- 计算实际的额外签到次数
        SELECT COUNT(*) INTO v_actual_count
        FROM check_ins
        WHERE member_id = v_member_id AND is_extra = true;
        
        -- 如果计数不一致，则更新
        IF v_current_count != v_actual_count THEN
            UPDATE members
            SET extra_check_ins = v_actual_count
            WHERE id = v_member_id;
            
            v_updated_count := v_updated_count + 1;
            
            -- 记录更新信息
            INSERT INTO debug_logs (function_name, member_id, message, details)
            VALUES (
                'fix_member_extra_checkins',
                v_member_id,
                '修复会员额外签到计数',
                jsonb_build_object(
                    'old_count', v_current_count,
                    'new_count', v_actual_count,
                    'difference', v_actual_count - v_current_count
                )
            );
        END IF;
    END LOOP;
    
    -- 记录完成修复
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'fix_member_extra_checkins',
        '完成修复会员额外签到计数',
        jsonb_build_object(
            'updated_members', v_updated_count,
            'timestamp', NOW()
        )
    );
END;
$$;


--
-- Name: generate_mock_check_ins(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_mock_check_ins() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_member_id UUID;
    v_card_id UUID;
    v_trainer_id UUID;
    v_check_in_date DATE;
    v_class_type TEXT;
    v_time_slot TEXT;
    v_is_private BOOLEAN;
    v_is_extra BOOLEAN;
    v_is_1v2 BOOLEAN;
    v_class_time TIME;
    v_senior_trainer_ids UUID[];
    v_jr_trainer_id UUID;
    v_random_number INT;
    v_count INT := 0;
BEGIN
    -- 获取教练ID
    SELECT array_agg(id) INTO v_senior_trainer_ids FROM trainers WHERE type = 'senior';
    SELECT id INTO v_jr_trainer_id FROM trainers WHERE type = 'jr' LIMIT 1;
    
    -- 禁用触发器以避免扣除课时等操作
    ALTER TABLE check_ins DISABLE TRIGGER ALL;
    
    -- 生成约100条签到记录
    WHILE v_count < 100 LOOP
        -- 随机选择会员
        SELECT id INTO v_member_id FROM members ORDER BY random() LIMIT 1;
        
        -- 随机选择会员卡
        SELECT id INTO v_card_id FROM membership_cards WHERE member_id = v_member_id ORDER BY random() LIMIT 1;
        
        -- 随机生成过去一个月内的日期
        v_check_in_date := current_date - (random() * 30)::integer;
        
        -- 随机决定是团课还是私教课
        v_random_number := floor(random() * 10);
        
        IF v_random_number < 7 THEN
            -- 70%概率是团课
            v_is_private := FALSE;
            
            -- 随机决定是早课还是晚课
            IF random() < 0.5 THEN
                v_class_type := 'morning';
                v_time_slot := '09:00-10:30';
                v_class_time := '09:00:00'::TIME;
            ELSE
                v_class_type := 'evening';
                v_time_slot := '17:00-18:30';
                v_class_time := '17:00:00'::TIME;
            END IF;
            
            v_trainer_id := NULL;
            v_is_1v2 := FALSE;
        ELSE
            -- 30%概率是私教课
            v_is_private := TRUE;
            v_class_type := 'private';
            
            -- 随机选择教练
            IF random() < 0.8 THEN
                -- 80%概率选择高级教练
                v_trainer_id := v_senior_trainer_ids[1 + floor(random() * array_length(v_senior_trainer_ids, 1))];
            ELSE
                -- 20%概率选择JR教练
                v_trainer_id := v_jr_trainer_id;
            END IF;
            
            -- 随机决定是否为1对2私教
            v_is_1v2 := random() < 0.2; -- 20%概率是1对2私教
            
            -- 随机选择私教时段
            v_random_number := floor(random() * 6);
            CASE v_random_number
                WHEN 0 THEN v_time_slot := '10:30-11:30'; v_class_time := '10:30:00'::TIME;
                WHEN 1 THEN v_time_slot := '11:30-12:30'; v_class_time := '11:30:00'::TIME;
                WHEN 2 THEN v_time_slot := '14:00-15:00'; v_class_time := '14:00:00'::TIME;
                WHEN 3 THEN v_time_slot := '15:00-16:00'; v_class_time := '15:00:00'::TIME;
                WHEN 4 THEN v_time_slot := '16:00-17:00'; v_class_time := '16:00:00'::TIME;
                WHEN 5 THEN v_time_slot := '19:00-20:00'; v_class_time := '19:00:00'::TIME;
            END CASE;
        END IF;
        
        -- 随机决定是否为额外签到
        v_is_extra := random() < 0.3; -- 30%概率是额外签到
        
        -- 检查是否已存在相同会员同一天同一时段的签到
        IF NOT EXISTS (
            SELECT 1 FROM check_ins 
            WHERE member_id = v_member_id 
            AND check_in_date = v_check_in_date 
            AND time_slot = v_time_slot
        ) THEN
            -- 插入签到记录
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
            ) VALUES (
                v_member_id, 
                v_check_in_date, 
                v_is_extra, 
                v_trainer_id, 
                v_is_1v2, 
                v_class_time, 
                v_card_id, 
                v_is_private, 
                v_time_slot, 
                v_class_type::class_type
            );
            
            v_count := v_count + 1;
        END IF;
    END LOOP;
    
    -- 重新启用触发器
    ALTER TABLE check_ins ENABLE TRIGGER ALL;
    
    RAISE NOTICE '成功生成 % 条模拟签到记录', v_count;
END;
$$;


--
-- Name: get_class_type_from_time_slot(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_class_type_from_time_slot(p_time_slot text) RETURNS public.class_type
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN CASE 
    WHEN p_time_slot = '09:00-10:30' THEN 'morning'::class_type
    WHEN p_time_slot = '17:00-18:30' THEN 'evening'::class_type
    ELSE 'morning'::class_type  -- Default to morning for private classes
  END;
END;
$$;


--
-- Name: get_valid_time_slot(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_valid_time_slot(p_class_type text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 根据课程类型返回默认时间段
  RETURN CASE 
    WHEN p_class_type = 'morning' THEN '09:00-10:30'
    WHEN p_class_type = 'evening' THEN '17:00-18:30'
    WHEN p_class_type = 'private' THEN '10:30-11:30'
    ELSE '09:00-10:30'  -- 默认时间段
  END;
END;
$$;


--
-- Name: handle_check_in(uuid, text, text, text, date, uuid, uuid, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_check_in(p_member_id uuid, p_name text, p_email text, p_class_type text, p_check_in_date date, p_card_id uuid DEFAULT NULL::uuid, p_trainer_id uuid DEFAULT NULL::uuid, p_is_1v2 boolean DEFAULT false, p_time_slot text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_check_in_id uuid;
  v_is_extra boolean := false;
  v_class_type class_type;
  v_is_private boolean;
  v_is_kids_group boolean;
  v_card_id uuid := p_card_id;
  v_message text;
  v_duplicate_check boolean;
BEGIN
  -- 转换课程类型
  BEGIN
    v_class_type := p_class_type::class_type;
    -- 修复：使用枚举值比较
    v_is_private := (v_class_type = 'private'::class_type);
    v_is_kids_group := (v_class_type = 'kids group'::class_type);
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '无效的课程类型: ' || p_class_type,
      'error', SQLERRM
    );
  END;

  -- 验证时间段
  IF p_time_slot IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '请选择有效的时间段',
      'error', 'time_slot_required'
    );
  END IF;

  -- 检查是否重复签到
  v_duplicate_check := check_duplicate_check_in(p_member_id, p_check_in_date, p_class_type, p_time_slot);

  IF v_duplicate_check THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '今天已经在这个时段签到过了',
      'isDuplicate', true
    );
  END IF;

  -- 会员不存在则创建
  IF NOT check_member_exists(p_member_id) THEN
    INSERT INTO members(id, name, email, is_new_member)
    VALUES (p_member_id, p_name, p_email, true);
    
    v_is_extra := true;
  END IF;
  
  -- 验证会员卡
  IF p_card_id IS NOT NULL THEN
    DECLARE
      v_validity jsonb;
    BEGIN
      v_validity := check_card_validity(p_card_id, p_member_id, p_class_type, p_check_in_date, p_trainer_id);
      IF (v_validity->>'is_valid')::boolean THEN
        v_is_extra := false;
      ELSE
        v_is_extra := true;
        v_message := v_validity->>'reason';
      END IF;
    END;
  ELSE
    v_is_extra := true;
  END IF;
  
  -- 插入签到记录
  INSERT INTO check_ins(
    member_id, 
    card_id, 
    class_type, 
    check_in_date,
    trainer_id,
    is_1v2,
    is_extra,
    time_slot,
    is_private
  )
  VALUES (
    p_member_id,
    p_card_id,
    v_class_type,
    p_check_in_date,
    CASE WHEN v_is_private THEN p_trainer_id ELSE NULL END,
    CASE WHEN v_is_private THEN p_is_1v2 ELSE FALSE END,
    v_is_extra,
    p_time_slot,
    v_is_private
  )
  RETURNING id INTO v_check_in_id;
  
  -- 扣除课时
  IF p_card_id IS NOT NULL AND NOT v_is_extra THEN
    PERFORM deduct_membership_sessions(p_card_id, p_class_type);
  END IF;
  
  -- 更新会员信息
  UPDATE members 
  SET 
    extra_check_ins = CASE WHEN v_is_extra THEN extra_check_ins + 1 ELSE extra_check_ins END,
    last_check_in_date = p_check_in_date
  WHERE id = p_member_id;
  
  -- 构建返回结果
  RETURN jsonb_build_object(
    'success', true,
    'message', '签到成功',
    'isExtra', v_is_extra,
    'checkInId', v_check_in_id,
    'extraReason', v_message
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', SQLERRM,
      'error', SQLERRM
    );
END;
$$;


--
-- Name: init_check_in_session(uuid, public.class_type); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.init_check_in_session(member_id uuid, class_type_param public.class_type) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    member_record members%ROWTYPE;
    result JSONB;
BEGIN
    -- 获取会员信息
    SELECT * INTO member_record
    FROM members
    WHERE id = member_id;
    
    IF member_record IS NULL THEN
        RAISE EXCEPTION 'Member not found';
    END IF;
    
    -- 构建返回结果
    result := jsonb_build_object(
        'member_id', member_record.id,
        'name', member_record.name,
        'remaining_classes', member_record.remaining_classes,
        'membership', member_record.membership,
        'last_check_in_date', member_record.last_check_in_date,
        'daily_check_ins', member_record.daily_check_ins,
        'extra_check_ins', member_record.extra_check_ins,
        'class_type', class_type_param
    );
    
    RETURN result;
END;
$$;


--
-- Name: log_debug(text, text, jsonb, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF current_setting('app.environment', true) = 'development' THEN
    INSERT INTO debug_logs (function_name, message, details, member_id)
    VALUES (p_function_name, p_message, p_details, p_member_id);
  END IF;
END;
$$;


--
-- Name: FUNCTION log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid) IS '通用的日志记录函数，简化各个函数中的日志记录代码';


--
-- Name: process_check_in(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_check_in() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_member_id uuid;
    v_card_id uuid;
    v_debug_details jsonb;
BEGIN
    -- 设置时区
    SET TIME ZONE 'Asia/Bangkok';
    
    -- 获取会员ID和卡ID
    v_member_id := NEW.member_id;
    v_card_id := NEW.card_id;
    
    -- 初始化调试信息
    v_debug_details := jsonb_build_object(
        'member_id', v_member_id,
        'check_in_date', NEW.check_in_date,
        'class_type', NEW.class_type,
        'is_extra', NEW.is_extra,
        'card_id', v_card_id,
        'time_slot', NEW.time_slot
    );

    -- 记录开始处理签到（调试用）
    PERFORM log_debug('process_check_in', '开始处理签到', v_debug_details);

    -- 处理正常签到（有效会员卡）
    IF NOT NEW.is_extra THEN
        -- 更新会员卡剩余次数（兼容中英文类型/类别，增加儿童团课支持）
        UPDATE membership_cards
        SET 
            remaining_group_sessions = CASE 
                WHEN card_type IN ('group', 'class', '团课')
                  AND card_category IN ('sessions', 'group', '课时卡')
                  AND NEW.class_type::TEXT IN ('morning', 'evening')
                THEN remaining_group_sessions - 1
                ELSE remaining_group_sessions
            END,
            remaining_private_sessions = CASE 
                WHEN card_type IN ('private', '私教课', '私教')
                  AND NEW.class_type::TEXT = 'private'
                THEN remaining_private_sessions - 1
                ELSE remaining_private_sessions
            END,
            -- 修改儿童团课判断条件，去除时间段限制，增加灵活匹配
            remaining_kids_sessions = CASE 
                WHEN (card_type = '儿童团课' OR card_type LIKE '%kids%')
                  AND (NEW.class_type::TEXT = 'kids group' OR NEW.class_type::TEXT LIKE '%kids%')
                THEN remaining_kids_sessions - 1
                ELSE remaining_kids_sessions
            END
        WHERE id = v_card_id;

        -- 记录扣课结果
        PERFORM log_debug(
            'process_check_in',
            '扣除课时完成',
            jsonb_build_object(
                'card_id', v_card_id,
                'class_type', NEW.class_type::TEXT,
                'card_type', (SELECT card_type FROM membership_cards WHERE id = v_card_id),
                'remaining_kids_sessions', (SELECT remaining_kids_sessions FROM membership_cards WHERE id = v_card_id)
            )
        );

        -- 其余函数保持不变...
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: register_new_member(text, text, text, boolean, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.register_new_member(p_name text, p_email text, p_time_slot text, p_is_private boolean DEFAULT false, p_trainer_id uuid DEFAULT NULL::uuid, p_is_1v2 boolean DEFAULT false) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
  v_existing_member RECORD;
  v_trainer_exists boolean;
BEGIN
  -- Input validation
  IF NOT validate_member_name(p_name) THEN
    RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
      USING HINT = 'invalid_name';
  END IF;

  -- Email validation
  IF p_email IS NULL OR TRIM(p_email) = '' THEN
    RAISE EXCEPTION '邮箱是必填字段。Email is required.'
      USING HINT = 'email_required';
  END IF;

  -- Time slot validation
  IF p_time_slot IS NULL OR TRIM(p_time_slot) = '' THEN
    RAISE EXCEPTION '必须选择时段。Time slot is required.'
      USING HINT = 'time_slot_required';
  END IF;

  -- Basic time slot format validation
  IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
    RAISE EXCEPTION '无效的时间段格式。Invalid time slot format.'
      USING HINT = 'invalid_time_slot_format';
  END IF;

  -- Private class validation
  IF p_is_private THEN
    -- Validate trainer
    IF p_trainer_id IS NULL THEN
      RAISE EXCEPTION '私教课程必须选择教练。Trainer is required for private class.'
        USING HINT = 'trainer_required';
    END IF;

    -- Check if trainer exists
    SELECT EXISTS (
      SELECT 1 FROM trainers WHERE id = p_trainer_id
    ) INTO v_trainer_exists;

    IF NOT v_trainer_exists THEN
      RAISE EXCEPTION '教练不存在。Trainer does not exist.'
        USING HINT = 'invalid_trainer';
    END IF;
  ELSE
    -- For group classes, validate time slot
    IF p_time_slot NOT IN ('09:00-10:30', '17:00-18:30') THEN
      RAISE EXCEPTION '无效的团课时段。Invalid group class time slot.'
        USING HINT = 'invalid_time_slot';
    END IF;
  END IF;

  -- Lock the members table for the specific name to prevent concurrent registrations
  PERFORM 1 
  FROM members 
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
  FOR UPDATE SKIP LOCKED;

  -- Check if member exists after acquiring lock
  SELECT id, email, is_new_member 
  INTO v_existing_member
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name));

  IF FOUND THEN
    RAISE EXCEPTION '该姓名已被注册。This name is already registered.'
      USING HINT = 'member_exists';
  END IF;

  -- Create new member
  INSERT INTO members (
    name,
    email,
    is_new_member,
    created_at
  ) VALUES (
    TRIM(p_name),
    TRIM(p_email),
    true,
    NOW()
  ) RETURNING id INTO v_member_id;

  -- Create initial check-in
  INSERT INTO check_ins (
    member_id,
    check_in_date,
    is_extra,
    is_private,
    trainer_id,
    time_slot,
    is_1v2,
    created_at,
    class_type  -- Include class_type based on time_slot
  ) VALUES (
    v_member_id,
    CURRENT_DATE,
    true,
    p_is_private,
    p_trainer_id,
    p_time_slot,
    p_is_1v2,
    NOW(),
    get_class_type_from_time_slot(p_time_slot)  -- Set class_type based on time_slot
  ) RETURNING id INTO v_check_in_id;

  RETURN json_build_object(
    'success', true,
    'member_id', v_member_id,
    'check_in_id', v_check_in_id
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION '该邮箱已被注册。This email is already registered.'
      USING HINT = 'email_exists';
  WHEN OTHERS THEN
    RAISE EXCEPTION '%', SQLERRM;
END;
$_$;


--
-- Name: register_new_member(text, text, boolean, boolean, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid DEFAULT NULL::uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_member_id uuid;
  v_check_in_id uuid;
  v_existing_member RECORD;
  v_trainer_exists boolean;
  v_class_type class_type;
BEGIN
  -- 输入验证
  IF NOT validate_member_name(p_name) THEN
    RAISE EXCEPTION '无效的姓名格式。Invalid name format.'
      USING HINT = 'invalid_name';
  END IF;

  -- 设置课程类型
  IF p_class_type = 'private' THEN
    v_class_type := 'private'::class_type;
  ELSIF p_class_type = 'kids_group' THEN
    v_class_type := 'kids group'::class_type;
  ELSE
    -- 根据时间段确定是早班还是晚班
    IF p_time_slot LIKE '9:%' OR p_time_slot LIKE '09:%' OR p_time_slot LIKE '10:%' THEN
      v_class_type := 'morning'::class_type;
    ELSE
      v_class_type := 'evening'::class_type;
    END IF;
  END IF;

  -- 私教课验证
  IF p_is_private OR v_class_type = 'private' THEN
    -- 验证教练
    IF p_trainer_id IS NULL THEN
      RAISE EXCEPTION '私教课程必须选择教练。Trainer is required for private class.'
        USING HINT = 'trainer_required';
    END IF;

    -- 检查教练是否存在
    SELECT EXISTS (
      SELECT 1 FROM trainers WHERE id = p_trainer_id
    ) INTO v_trainer_exists;

    IF NOT v_trainer_exists THEN
      RAISE EXCEPTION '教练不存在。Trainer does not exist.'
        USING HINT = 'invalid_trainer';
    END IF;
  END IF;

  -- 检查是否已存在同名会员
  SELECT id, email, is_new_member 
  INTO v_existing_member
  FROM members
  WHERE LOWER(TRIM(name)) = LOWER(TRIM(p_name))
  FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    RAISE EXCEPTION '该姓名已被注册。This name is already registered.'
      USING HINT = 'member_exists';
  END IF;

  -- 创建新会员
  INSERT INTO members (
    name,
    email,
    is_new_member,
    created_at
  ) VALUES (
    TRIM(p_name),
    TRIM(p_email),
    true,
    NOW()
  ) RETURNING id INTO v_member_id;

  -- 创建初始签到记录
  INSERT INTO check_ins (
    member_id,
    check_in_date,
    is_extra,
    is_private,
    trainer_id,
    time_slot,
    is_1v2,
    created_at,
    class_type
  ) VALUES (
    v_member_id,
    CURRENT_DATE,
    true,
    p_is_private,
    p_trainer_id,
    p_time_slot,
    p_is_1v2,
    NOW(),
    v_class_type
  ) RETURNING id INTO v_check_in_id;

  -- 返回成功响应
  RETURN json_build_object(
    'success', true,
    'member_id', v_member_id,
    'check_in_id', v_check_in_id
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION '该邮箱已被注册。This email is already registered.'
      USING HINT = 'email_exists';
  WHEN OTHERS THEN
    RAISE EXCEPTION '%', SQLERRM;
END;
$$;


--
-- Name: FUNCTION register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid) IS '注册新会员并创建其首次签到记录。
支持参数:
- p_class_type: 课程类型 (private/kids_group/group)
- p_email: 会员邮箱
- p_is_1v2: 是否1v2课程
- p_is_private: 是否私教课
- p_name: 会员姓名  
- p_time_slot: 时间段
- p_trainer_id: 教练ID';


--
-- Name: search_member(text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_member(search_term text, exact_match boolean DEFAULT false) RETURNS TABLE(id uuid, name text, email text, phone text, membership public.membership_type, remaining_classes integer, last_check_in_date date, is_new_member boolean, membership_expiry timestamp with time zone, daily_check_ins integer, extra_check_ins integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id, m.name, m.email, m.phone, m.membership, 
        m.remaining_classes, m.last_check_in_date, m.is_new_member,
        m.membership_expiry, m.daily_check_ins, m.extra_check_ins
    FROM members m
    WHERE 
        CASE 
            WHEN exact_match THEN 
                m.name = search_term
            ELSE 
                m.name ILIKE '%' || search_term || '%'
                OR m.email ILIKE '%' || search_term || '%'
                OR m.phone ILIKE '%' || search_term || '%'
        END
    ORDER BY 
        CASE WHEN m.name = search_term THEN 0
             WHEN m.name ILIKE search_term || '%' THEN 1
             ELSE 2
        END,
        m.name;
END;
$$;


--
-- Name: set_card_validity(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_card_validity(p_card_id uuid, p_card_type text, p_card_category text, p_card_subtype text) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_valid_until DATE;
BEGIN
  -- 获取当前会员卡信息
  SELECT valid_until INTO v_valid_until
  FROM membership_cards
  WHERE id = p_card_id;
  
  -- 如果已经有有效期，则保持原有效期
  IF v_valid_until IS NOT NULL THEN
    RETURN v_valid_until;
  END IF;
  
  -- 如果没有有效期，则根据卡类型设置默认有效期
  v_valid_until := CASE
    -- 团课月卡：购买日起30天
    WHEN p_card_type = 'group' AND p_card_category = 'monthly' THEN
      CURRENT_DATE + INTERVAL '30 days'
    -- 团课10次卡：购买日起3个月
    WHEN p_card_type = 'group' AND p_card_category = 'session' AND p_card_subtype = 'ten_classes' THEN
      CURRENT_DATE + INTERVAL '3 months'
    -- 私教10次卡：购买日起1个月
    WHEN p_card_type = 'private' AND p_card_subtype = 'ten_classes' THEN
      CURRENT_DATE + INTERVAL '1 month'
    -- 其他卡：无到期限制
    ELSE NULL
  END;
  
  -- 记录日志
  PERFORM log_debug(
    'set_card_validity',
    '设置会员卡有效期',
    jsonb_build_object(
      'card_id', p_card_id,
      'card_type', p_card_type,
      'card_category', p_card_category,
      'card_subtype', p_card_subtype,
      'valid_until', v_valid_until
    )
  );
  
  RETURN v_valid_until;
END;
$$;


--
-- Name: test_expired_card_validation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.test_expired_card_validation() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_member_id UUID;
    v_card_id UUID;
    v_check_in_id UUID;
    v_is_extra BOOLEAN;
    v_test_date DATE := CURRENT_DATE + INTERVAL '1 day'; -- 使用明天的日期避免重复签到
BEGIN
    -- 创建测试会员
    INSERT INTO members (id, name, email, is_new_member)
    VALUES (gen_random_uuid(), '过期卡测试会员', 'expired_card_test@example.com', false)
    RETURNING id INTO v_member_id;
    
    -- 记录开始测试
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation',
        '开始测试过期会员卡验证',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'test_date', v_test_date
        )
    );
    
    -- 创建过期会员卡
    INSERT INTO membership_cards (id, member_id, card_type, card_category, card_subtype, valid_until, remaining_group_sessions)
    VALUES (gen_random_uuid(), v_member_id, 'group', 'session', 'ten_sessions', v_test_date - INTERVAL '1 day', 5)
    RETURNING id INTO v_card_id;
    
    -- 创建签到记录（使用过期会员卡）
    INSERT INTO check_ins (id, member_id, card_id, check_in_date, class_type, is_private, time_slot)
    VALUES (gen_random_uuid(), v_member_id, v_card_id, v_test_date, 'morning', false, '09:00-10:30')
    RETURNING id, is_extra INTO v_check_in_id, v_is_extra;
    
    -- 记录测试结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation',
        '过期会员卡签到测试结果',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'card_id', v_card_id,
            'check_in_id', v_check_in_id,
            'is_extra', v_is_extra,
            'expected_is_extra', true,
            'test_passed', v_is_extra = true
        )
    );
    
    -- 清理测试数据
    DELETE FROM check_ins WHERE member_id = v_member_id;
    DELETE FROM membership_cards WHERE member_id = v_member_id;
    DELETE FROM members WHERE id = v_member_id;
    
    -- 记录测试完成
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation',
        '完成测试过期会员卡验证',
        jsonb_build_object(
            'timestamp', NOW()
        )
    );
END;
$$;


--
-- Name: test_expired_card_validation_v2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.test_expired_card_validation_v2() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_member_id UUID;
    v_card_id UUID;
    v_check_in_id UUID;
    v_is_extra BOOLEAN;
    v_test_date DATE := CURRENT_DATE + INTERVAL '1 day'; -- 使用明天的日期避免重复签到
BEGIN
    -- 创建测试会员
    INSERT INTO members (id, name, email, is_new_member)
    VALUES (gen_random_uuid(), '过期卡测试会员2', 'expired_card_test2@example.com', false)
    RETURNING id INTO v_member_id;
    
    -- 记录开始测试
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation_v2',
        '开始测试过期会员卡验证（第二版）',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'test_date', v_test_date
        )
    );
    
    -- 创建过期会员卡（确保valid_until不为NULL）
    INSERT INTO membership_cards (id, member_id, card_type, card_category, card_subtype, valid_until, remaining_group_sessions)
    VALUES (gen_random_uuid(), v_member_id, 'group', 'session', 'ten_sessions', v_test_date - INTERVAL '1 day', 5)
    RETURNING id INTO v_card_id;
    
    -- 记录会员卡信息
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation_v2',
        '创建过期会员卡',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'card_id', v_card_id,
            'valid_until', v_test_date - INTERVAL '1 day',
            'check_in_date', v_test_date
        )
    );
    
    -- 创建签到记录（使用过期会员卡）
    INSERT INTO check_ins (id, member_id, card_id, check_in_date, class_type, is_private, time_slot)
    VALUES (gen_random_uuid(), v_member_id, v_card_id, v_test_date, 'morning', false, '09:00-10:30')
    RETURNING id, is_extra INTO v_check_in_id, v_is_extra;
    
    -- 记录测试结果
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation_v2',
        '过期会员卡签到测试结果',
        jsonb_build_object(
            'timestamp', NOW(),
            'member_id', v_member_id,
            'card_id', v_card_id,
            'check_in_id', v_check_in_id,
            'is_extra', v_is_extra,
            'expected_is_extra', true,
            'test_passed', v_is_extra = true
        )
    );
    
    -- 清理测试数据
    DELETE FROM check_ins WHERE member_id = v_member_id;
    DELETE FROM membership_cards WHERE member_id = v_member_id;
    DELETE FROM members WHERE id = v_member_id;
    
    -- 记录测试完成
    INSERT INTO debug_logs (function_name, message, details)
    VALUES (
        'test_expired_card_validation_v2',
        '完成测试过期会员卡验证（第二版）',
        jsonb_build_object(
            'timestamp', NOW()
        )
    );
END;
$$;


--
-- Name: trigger_deduct_sessions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_deduct_sessions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 只有非额外签到才扣除课时
  IF NOT NEW.is_extra AND NEW.card_id IS NOT NULL THEN
    PERFORM deduct_membership_sessions(NEW.card_id, NEW.class_type::TEXT, NEW.is_private, NEW.is_1v2);
  END IF;
  
  RETURN NULL;
END;
$$;


--
-- Name: trigger_set_card_validity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_set_card_validity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 只在插入新卡时设置默认有效期
  IF TG_OP = 'INSERT' THEN
    NEW.valid_until := set_card_validity(NEW.id, NEW.card_type, NEW.card_category, NEW.card_subtype);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: update_check_in_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_check_in_stats() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Update member's last check-in date
  UPDATE members
  SET last_check_in_date = NEW.check_in_date
  WHERE id = NEW.member_id;

  -- If it's an extra check-in, increment the counter
  IF NEW.is_extra THEN
    UPDATE members
    SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
    WHERE id = NEW.member_id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: update_member_extra_checkins(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_member_extra_checkins() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_old_is_extra BOOLEAN;
BEGIN
    -- 获取旧记录的is_extra值（如果是更新操作）
    IF TG_OP = 'UPDATE' THEN
        v_old_is_extra := OLD.is_extra;
    ELSE
        v_old_is_extra := FALSE;
    END IF;
    
    -- 记录调试信息
    INSERT INTO debug_logs (function_name, member_id, message, details)
    VALUES (
        'update_member_extra_checkins',
        NEW.member_id,
        '更新会员额外签到计数',
        jsonb_build_object(
            'operation', TG_OP,
            'old_is_extra', v_old_is_extra,
            'new_is_extra', NEW.is_extra
        )
    );
    
    -- 根据操作类型和is_extra的变化更新会员的额外签到计数
    IF TG_OP = 'INSERT' AND NEW.is_extra THEN
        -- 新增额外签到
        UPDATE members
        SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
        WHERE id = NEW.member_id;
        
    ELSIF TG_OP = 'UPDATE' THEN
        IF NOT v_old_is_extra AND NEW.is_extra THEN
            -- 从普通签到变为额外签到
            UPDATE members
            SET extra_check_ins = COALESCE(extra_check_ins, 0) + 1
            WHERE id = NEW.member_id;
            
        ELSIF v_old_is_extra AND NOT NEW.is_extra THEN
            -- 从额外签到变为普通签到
            UPDATE members
            SET extra_check_ins = GREATEST(COALESCE(extra_check_ins, 0) - 1, 0)
            WHERE id = NEW.member_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: update_member_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_member_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 如果是新会员，更新为老会员
  IF (SELECT is_new_member FROM members WHERE id = NEW.member_id) THEN
    UPDATE members
    SET is_new_member = false
    WHERE id = NEW.member_id;
    
    -- 记录日志
    INSERT INTO debug_logs (function_name, message, member_id, details)
    VALUES ('update_member_status', '会员状态已更新', NEW.member_id,
      jsonb_build_object(
        'old_status', 'new',
        'new_status', 'old',
        'check_in_id', NEW.id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: validate_check_in(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_check_in() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_member RECORD;
  v_duplicate_exists BOOLEAN;
BEGIN
  -- 获取会员信息
  SELECT * INTO v_member
  FROM members
  WHERE id = NEW.member_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '未找到会员ID为 % 的记录', NEW.member_id;
  END IF;
  
  -- 检查是否有重复签到，但只记录不阻止
  -- 直接调用并接收boolean结果
  v_duplicate_exists := check_duplicate_check_in(
    NEW.member_id, 
    NEW.check_in_date, 
    NEW.class_type::TEXT,
    NEW.time_slot
  );
  
  -- 记录重复签到信息，但允许继续
  IF v_duplicate_exists THEN
    PERFORM log_debug(
      'validate_check_in',
      '检测到重复签到，但允许继续',
      jsonb_build_object(
        'member_id', NEW.member_id,
        'class_type', NEW.class_type,
        'check_in_date', NEW.check_in_date
      )
    );
  END IF;
  
  -- 根据业务规则，总是允许签到继续
  RETURN NEW;
END;
$$;


--
-- Name: validate_check_in_card(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_check_in_card() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_card RECORD;
BEGIN
  -- 如果没有指定会员卡，则为额外签到
  IF NEW.card_id IS NULL THEN
    NEW.is_extra := true;
    RETURN NEW;
  END IF;

  -- 获取会员卡信息
  SELECT * INTO v_card FROM membership_cards WHERE id = NEW.card_id;
  
  -- 检查会员卡是否存在
  IF NOT FOUND THEN
    NEW.is_extra := true;
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('validate_check_in_card', '会员卡不存在',
      jsonb_build_object('card_id', NEW.card_id)
    );
    RETURN NEW;
  END IF;

  -- 检查会员卡是否属于该会员
  IF v_card.member_id != NEW.member_id THEN
    NEW.is_extra := true;
    INSERT INTO debug_logs (function_name, message, details)
    VALUES ('validate_check_in_card', '会员卡不属于该会员',
      jsonb_build_object(
        'card_id', NEW.card_id,
        'card_member_id', v_card.member_id,
        'check_in_member_id', NEW.member_id
      )
    );
    RETURN NEW;
  END IF;

  -- 使用CASE表达式简化条件判断
  NEW.is_extra := CASE
    -- 卡类型不匹配
    WHEN (v_card.card_type = '团课' AND NEW.class_type::TEXT = 'private') OR
         (v_card.card_type = '私教课' AND NEW.class_type::TEXT != 'private') THEN true
    -- 卡已过期
    WHEN v_card.valid_until IS NOT NULL AND v_card.valid_until < NEW.check_in_date THEN true
    -- 团课课时卡课时不足
    WHEN v_card.card_type = '团课' AND v_card.card_category = '课时卡' AND
         (v_card.remaining_group_sessions IS NULL OR v_card.remaining_group_sessions <= 0) THEN true
    -- 私教课时不足
    WHEN v_card.card_type = '私教课' AND
         (v_card.remaining_private_sessions IS NULL OR v_card.remaining_private_sessions <= 0) THEN true
    -- 月卡超出每日限制
    WHEN v_card.card_type = '团课' AND v_card.card_category = '月卡' THEN
      CASE
        WHEN v_card.card_subtype = '单次月卡' AND
             (SELECT COUNT(*) FROM check_ins
              WHERE member_id = NEW.member_id
              AND check_in_date = NEW.check_in_date
              AND id IS DISTINCT FROM NEW.id
              AND NOT is_extra) >= 1 THEN true
        WHEN v_card.card_subtype = '双次月卡' AND
             (SELECT COUNT(*) FROM check_ins
              WHERE member_id = NEW.member_id
              AND check_in_date = NEW.check_in_date
              AND id IS DISTINCT FROM NEW.id
              AND NOT is_extra) >= 2 THEN true
        ELSE false
      END
    -- 其他情况为正常签到
    ELSE false
  END;
  
  RETURN NEW;
END;
$$;


--
-- Name: validate_member_name(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_member_name(p_name text, p_email text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
BEGIN
  -- Basic validation
  IF TRIM(p_name) = '' THEN
    RAISE EXCEPTION '姓名不能为空。Name cannot be empty.'
      USING HINT = 'empty_name';
  END IF;

  -- Check for invalid characters
  IF p_name !~ '^[a-zA-Z0-9\u4e00-\u9fa5@._\-\s]+$' THEN
    RAISE EXCEPTION '姓名包含无效字符。Name contains invalid characters.'
      USING HINT = 'invalid_characters';
  END IF;

  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$_$;


--
-- Name: validate_membership_card(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_membership_card() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 如果是新卡或更改了卡类型
  IF TG_OP = 'INSERT' OR OLD.card_type != NEW.card_type THEN
    -- 检查是否已有有效卡
    IF NOT check_valid_cards(NEW.member_id, NEW.card_type, NEW.id) THEN
      RAISE EXCEPTION '会员已有有效的%类型会员卡', NEW.card_type;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: validate_private_time_slot(text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_private_time_slot(p_time_slot text, p_check_in_date date) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_day_of_week integer;
BEGIN
  -- Get day of week (1-7, where 1 is Monday)
  v_day_of_week := EXTRACT(DOW FROM p_check_in_date);
  IF v_day_of_week = 0 THEN
    v_day_of_week := 7;
  END IF;

  -- Validate time slot format (HH:MM-HH:MM)
  IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
    RETURN false;
  END IF;

  -- For weekdays (Monday to Friday)
  IF v_day_of_week BETWEEN 1 AND 5 THEN
    RETURN p_time_slot IN (
      '07:00-08:00', '08:00-09:00', '10:30-11:30',
      '14:00-15:00', '15:00-16:00', '16:00-17:00',
      '18:30-19:30'
    );
  -- For Saturday
  ELSIF v_day_of_week = 6 THEN
    RETURN p_time_slot IN (
      '07:00-08:00', '08:00-09:00', '10:30-11:30',
      '14:00-15:00', '15:00-16:00', '16:00-17:00',
      '18:30-19:30'
    );
  END IF;

  RETURN false;
END;
$_$;


--
-- Name: validate_time_slot(text, date, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_time_slot(p_time_slot text, p_check_in_date date, p_is_private boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
BEGIN
  -- Basic format validation
  IF p_time_slot !~ '^\d{2}:\d{2}-\d{2}:\d{2}$' THEN
    RETURN false;
  END IF;

  -- For group classes
  IF NOT p_is_private THEN
    RETURN p_time_slot IN ('09:00-10:30', '17:00-18:30');
  END IF;

  -- For private classes, trust the frontend validation
  RETURN true;
END;
$_$;


--
-- Name: check_in_anomalies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.check_in_anomalies (
    id integer NOT NULL,
    check_in_id uuid,
    member_id uuid,
    check_in_date date,
    detected_at timestamp without time zone DEFAULT now(),
    issue_type text,
    description text,
    valid_cards jsonb
);


--
-- Name: check_in_anomalies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.check_in_anomalies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: check_in_anomalies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.check_in_anomalies_id_seq OWNED BY public.check_in_anomalies.id;


--
-- Name: check_in_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.check_in_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    check_in_id uuid NOT NULL,
    details jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: check_ins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.check_ins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    member_id uuid,
    check_in_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    is_extra boolean DEFAULT false,
    trainer_id uuid,
    is_1v2 boolean DEFAULT false,
    class_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    card_id uuid,
    is_private boolean DEFAULT false NOT NULL,
    time_slot text NOT NULL,
    class_type public.class_type
);


--
-- Name: TABLE check_ins; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.check_ins IS 'Check-in records - Reset for testing on 2024-03-20';


--
-- Name: class_schedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.class_schedule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    day_of_week integer NOT NULL,
    class_type public.class_type NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_private_class boolean DEFAULT false NOT NULL,
    trainer_type text,
    available_trainers uuid[],
    CONSTRAINT class_schedule_day_of_week_check CHECK (((day_of_week >= 1) AND (day_of_week <= 6))),
    CONSTRAINT class_schedule_trainer_type_check CHECK ((trainer_type = ANY (ARRAY['jr'::text, 'senior'::text])))
);


--
-- Name: debug_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debug_logs (
    id integer NOT NULL,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    function_name text NOT NULL,
    member_id uuid,
    message text NOT NULL,
    details jsonb
);


--
-- Name: debug_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.debug_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: debug_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.debug_logs_id_seq OWNED BY public.debug_logs.id;


--
-- Name: function_backups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.function_backups (
    backup_id integer NOT NULL,
    function_name text NOT NULL,
    function_definition text NOT NULL,
    backup_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: function_backups_backup_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.function_backups_backup_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: function_backups_backup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.function_backups_backup_id_seq OWNED BY public.function_backups.backup_id;


--
-- Name: membership_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_cards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    member_id uuid,
    card_type text NOT NULL,
    card_category text,
    card_subtype text NOT NULL,
    trainer_type text,
    remaining_group_sessions integer,
    remaining_private_sessions integer,
    valid_until date,
    created_at timestamp with time zone DEFAULT now(),
    remaining_kids_sessions integer DEFAULT 0,
    CONSTRAINT membership_cards_trainer_type_check CHECK (((trainer_type IS NULL) OR (trainer_type = ANY (ARRAY['jr'::text, 'senior'::text]))))
);


--
-- Name: membership_card_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.membership_card_view AS
 SELECT membership_cards.id,
    membership_cards.member_id,
    membership_cards.card_type,
    membership_cards.card_category,
    membership_cards.card_subtype,
    membership_cards.trainer_type,
    membership_cards.remaining_group_sessions,
    membership_cards.remaining_private_sessions,
    membership_cards.valid_until,
    membership_cards.created_at,
        CASE
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '课时卡'::text) AND (membership_cards.card_subtype = '单次卡'::text)) THEN 'single_class'::text
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '课时卡'::text) AND (membership_cards.card_subtype = '两次卡'::text)) THEN 'two_classes'::text
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '课时卡'::text) AND (membership_cards.card_subtype = '10次卡'::text)) THEN 'ten_classes'::text
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '月卡'::text) AND (membership_cards.card_subtype = '单次月卡'::text)) THEN 'single_monthly'::text
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '月卡'::text) AND (membership_cards.card_subtype = '双次月卡'::text)) THEN 'double_monthly'::text
            WHEN ((membership_cards.card_type = '私教课'::text) AND (membership_cards.card_subtype = '单次卡'::text)) THEN 'single_private'::text
            WHEN ((membership_cards.card_type = '私教课'::text) AND (membership_cards.card_subtype = '10次卡'::text)) THEN 'ten_private'::text
            ELSE membership_cards.card_subtype
        END AS card_subtype_code
   FROM public.membership_cards;


--
-- Name: VIEW membership_card_view; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.membership_card_view IS '会员卡视图，提供标准化的会员卡信息，包括代码映射';


--
-- Name: processed_check_ins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.processed_check_ins (
    check_in_id uuid NOT NULL,
    process_type text NOT NULL,
    processed_at timestamp with time zone DEFAULT now()
);


--
-- Name: standardized_cards; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.standardized_cards AS
 SELECT membership_cards.id,
    membership_cards.member_id,
    membership_cards.card_type,
    membership_cards.card_category,
    membership_cards.card_subtype,
    membership_cards.valid_until,
    membership_cards.remaining_group_sessions,
    membership_cards.remaining_private_sessions,
    membership_cards.remaining_kids_sessions,
        CASE
            WHEN (membership_cards.card_type = ANY (ARRAY['class'::text, '团课'::text])) THEN 'group_class'::text
            WHEN (membership_cards.card_type = ANY (ARRAY['private'::text, '私教课'::text])) THEN 'private_class'::text
            WHEN (membership_cards.card_type = '儿童团课'::text) THEN 'kids_class'::text
            ELSE 'unknown'::text
        END AS std_card_type,
        CASE
            WHEN (((membership_cards.card_type = 'class'::text) AND (membership_cards.card_category = 'monthly'::text)) OR ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '月卡'::text))) THEN 'monthly'::text
            WHEN (((membership_cards.card_type = 'class'::text) AND (membership_cards.card_category = 'group'::text)) OR ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '课时卡'::text))) THEN 'session'::text
            WHEN (((membership_cards.card_type = 'private'::text) AND (membership_cards.card_category = 'private'::text)) OR ((membership_cards.card_type = '私教课'::text) AND ((membership_cards.card_category = 'private'::text) OR (membership_cards.card_category IS NULL)))) THEN 'private_session'::text
            WHEN ((membership_cards.card_type = '儿童团课'::text) AND (membership_cards.card_category = '课时卡'::text)) THEN 'kids_session'::text
            ELSE 'unknown'::text
        END AS std_card_category,
        CASE
            WHEN (membership_cards.card_subtype = ANY (ARRAY['single_monthly'::text, '单次月卡'::text])) THEN 'single_month'::text
            WHEN (membership_cards.card_subtype = 'double_monthly'::text) THEN 'double_month'::text
            WHEN ((membership_cards.card_type = ANY (ARRAY['class'::text, '团课'::text])) AND (membership_cards.card_subtype = ANY (ARRAY['ten_classes'::text, '10次卡'::text]))) THEN 'ten_sessions'::text
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_subtype = '单次卡'::text)) THEN 'single_session'::text
            WHEN ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_subtype = '两次卡'::text)) THEN 'two_sessions'::text
            WHEN ((membership_cards.card_type = ANY (ARRAY['private'::text, '私教课'::text])) AND (membership_cards.card_subtype = ANY (ARRAY['ten_private'::text, '10次卡'::text]))) THEN 'ten_sessions'::text
            WHEN ((membership_cards.card_type = ANY (ARRAY['private'::text, '私教课'::text])) AND (membership_cards.card_subtype = '单次卡'::text)) THEN 'single_session'::text
            WHEN ((membership_cards.card_type = '儿童团课'::text) AND (membership_cards.card_subtype = '10次卡'::text)) THEN 'ten_sessions'::text
            ELSE 'unknown'::text
        END AS std_card_spec,
        CASE
            WHEN (((membership_cards.card_type = 'class'::text) AND (membership_cards.card_category = 'monthly'::text) AND (membership_cards.card_subtype = 'single_monthly'::text)) OR ((membership_cards.card_type = '团课'::text) AND (membership_cards.card_category = '月卡'::text) AND (membership_cards.card_subtype = '单次月卡'::text))) THEN 1
            WHEN ((membership_cards.card_type = 'class'::text) AND (membership_cards.card_category = 'monthly'::text) AND (membership_cards.card_subtype = 'double_monthly'::text)) THEN 2
            ELSE NULL::integer
        END AS daily_limit
   FROM public.membership_cards;


--
-- Name: trainers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trainers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    display_order integer,
    CONSTRAINT trainers_type_check CHECK ((type = ANY (ARRAY['jr'::text, 'senior'::text])))
);


--
-- Name: trigger_backups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trigger_backups (
    backup_id integer NOT NULL,
    trigger_name text NOT NULL,
    table_name text NOT NULL,
    trigger_definition text NOT NULL,
    backup_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: trigger_backups_backup_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trigger_backups_backup_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trigger_backups_backup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trigger_backups_backup_id_seq OWNED BY public.trigger_backups.backup_id;


--
-- Name: check_in_anomalies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_anomalies ALTER COLUMN id SET DEFAULT nextval('public.check_in_anomalies_id_seq'::regclass);


--
-- Name: debug_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debug_logs ALTER COLUMN id SET DEFAULT nextval('public.debug_logs_id_seq'::regclass);


--
-- Name: function_backups backup_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.function_backups ALTER COLUMN backup_id SET DEFAULT nextval('public.function_backups_backup_id_seq'::regclass);


--
-- Name: trigger_backups backup_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_backups ALTER COLUMN backup_id SET DEFAULT nextval('public.trigger_backups_backup_id_seq'::regclass);


--
-- Name: check_in_anomalies check_in_anomalies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_anomalies
    ADD CONSTRAINT check_in_anomalies_pkey PRIMARY KEY (id);


--
-- Name: check_in_logs check_in_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_logs
    ADD CONSTRAINT check_in_logs_pkey PRIMARY KEY (id);


--
-- Name: check_ins check_ins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT check_ins_pkey PRIMARY KEY (id);


--
-- Name: class_schedule class_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_pkey PRIMARY KEY (id);


--
-- Name: debug_logs debug_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debug_logs
    ADD CONSTRAINT debug_logs_pkey PRIMARY KEY (id);


--
-- Name: function_backups function_backups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.function_backups
    ADD CONSTRAINT function_backups_pkey PRIMARY KEY (backup_id);


--
-- Name: members members_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_email_key UNIQUE (email);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (id);


--
-- Name: membership_cards membership_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_cards
    ADD CONSTRAINT membership_cards_pkey PRIMARY KEY (id);


--
-- Name: trainers trainers_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trainers
    ADD CONSTRAINT trainers_name_unique UNIQUE (name);


--
-- Name: trainers trainers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trainers
    ADD CONSTRAINT trainers_pkey PRIMARY KEY (id);


--
-- Name: trigger_backups trigger_backups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_backups
    ADD CONSTRAINT trigger_backups_pkey PRIMARY KEY (backup_id);


--
-- Name: membership_cards unique_member_card_type; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_cards
    ADD CONSTRAINT unique_member_card_type UNIQUE (member_id, card_type, card_subtype);


--
-- Name: CONSTRAINT unique_member_card_type ON membership_cards; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT unique_member_card_type ON public.membership_cards IS '确保同一会员不能有相同类型和子类型的多张卡';


--
-- Name: members unique_name_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT unique_name_email UNIQUE (name, email);


--
-- Name: check_in_logs_check_in_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX check_in_logs_check_in_id_idx ON public.check_in_logs USING btree (check_in_id);


--
-- Name: check_in_logs_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX check_in_logs_created_at_idx ON public.check_in_logs USING btree (created_at);


--
-- Name: check_ins_check_in_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX check_ins_check_in_date_idx ON public.check_ins USING btree (check_in_date);


--
-- Name: check_ins_member_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX check_ins_member_id_idx ON public.check_ins USING btree (member_id);


--
-- Name: idx_check_ins_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_card_id ON public.check_ins USING btree (card_id);


--
-- Name: idx_check_ins_check_in_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_check_in_date ON public.check_ins USING btree (check_in_date);


--
-- Name: idx_check_ins_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_created_at ON public.check_ins USING btree (created_at);


--
-- Name: idx_check_ins_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_date ON public.check_ins USING btree (check_in_date);


--
-- Name: idx_check_ins_member_date_class; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_member_date_class ON public.check_ins USING btree (member_id, check_in_date, class_type);


--
-- Name: idx_check_ins_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_member_id ON public.check_ins USING btree (member_id);


--
-- Name: idx_check_ins_trainer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_trainer_id ON public.check_ins USING btree (trainer_id);


--
-- Name: idx_check_ins_types; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_check_ins_types ON public.check_ins USING btree (is_extra, is_private);


--
-- Name: idx_members_name_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_members_name_email ON public.members USING btree (name, email);


--
-- Name: idx_membership_cards_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_cards_member_id ON public.membership_cards USING btree (member_id);


--
-- Name: idx_membership_cards_remaining_sessions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_cards_remaining_sessions ON public.membership_cards USING btree (card_type, card_category, COALESCE(remaining_group_sessions, 0), COALESCE(remaining_private_sessions, 0));


--
-- Name: idx_membership_cards_type_subtype; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_cards_type_subtype ON public.membership_cards USING btree (card_type, card_subtype);


--
-- Name: idx_membership_cards_types; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_cards_types ON public.membership_cards USING btree (card_type, card_category, card_subtype);


--
-- Name: idx_membership_cards_valid_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_cards_valid_until ON public.membership_cards USING btree (valid_until);


--
-- Name: members_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX members_email_idx ON public.members USING btree (email);


--
-- Name: members_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX members_name_idx ON public.members USING btree (name);


--
-- Name: check_ins check_card_member_match_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_card_member_match_trigger BEFORE INSERT OR UPDATE ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.check_card_member_match();


--
-- Name: check_ins check_in_logging_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_in_logging_trigger AFTER INSERT ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.check_in_logging();


--
-- Name: check_ins find_valid_card_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER find_valid_card_trigger BEFORE INSERT ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.find_valid_card_for_checkin();


--
-- Name: membership_cards membership_card_validation_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER membership_card_validation_trigger BEFORE INSERT OR UPDATE ON public.membership_cards FOR EACH ROW EXECUTE FUNCTION public.validate_membership_card();


--
-- Name: check_ins process_check_in_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER process_check_in_trigger AFTER INSERT ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.process_check_in();


--
-- Name: membership_cards set_card_validity_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_card_validity_trigger BEFORE INSERT ON public.membership_cards FOR EACH ROW EXECUTE FUNCTION public.trigger_set_card_validity();


--
-- Name: check_ins update_check_in_stats_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_check_in_stats_trigger AFTER INSERT ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.update_check_in_stats();


--
-- Name: check_ins update_member_extra_checkins_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_member_extra_checkins_trigger AFTER INSERT OR UPDATE OF is_extra ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.update_member_extra_checkins();


--
-- Name: check_ins update_member_status_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_member_status_trigger AFTER INSERT ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.update_member_status();


--
-- Name: check_ins validate_check_in_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_check_in_trigger BEFORE INSERT ON public.check_ins FOR EACH ROW EXECUTE FUNCTION public.validate_check_in();


--
-- Name: check_in_logs check_in_logs_check_in_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_in_logs
    ADD CONSTRAINT check_in_logs_check_in_id_fkey FOREIGN KEY (check_in_id) REFERENCES public.check_ins(id) ON DELETE CASCADE;


--
-- Name: check_ins check_ins_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT check_ins_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.membership_cards(id);


--
-- Name: check_ins check_ins_trainer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.check_ins
    ADD CONSTRAINT check_ins_trainer_id_fkey FOREIGN KEY (trainer_id) REFERENCES public.trainers(id);


--
-- Name: membership_cards membership_cards_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_cards
    ADD CONSTRAINT membership_cards_member_id_fkey FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: processed_check_ins processed_check_ins_check_in_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.processed_check_ins
    ADD CONSTRAINT processed_check_ins_check_in_id_fkey FOREIGN KEY (check_in_id) REFERENCES public.check_ins(id);


--
-- Name: check_ins Admin full access on check_ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin full access on check_ins" ON public.check_ins TO authenticated USING (true) WITH CHECK (true);


--
-- Name: members Admin full access on members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin full access on members" ON public.members TO authenticated USING (true) WITH CHECK (true);


--
-- Name: class_schedule Allow admin full access to class schedule; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin full access to class schedule" ON public.class_schedule TO authenticated USING (true);


--
-- Name: check_ins Allow public operations on test check-ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public operations on test check-ins" ON public.check_ins USING ((member_id IN ( SELECT members.id
   FROM public.members
  WHERE ((members.email ~~ '%.test.mt@example.com'::text) OR (members.email ~~ '%test.checkin%'::text))))) WITH CHECK ((member_id IN ( SELECT members.id
   FROM public.members
  WHERE ((members.email ~~ '%.test.mt@example.com'::text) OR (members.email ~~ '%test.checkin%'::text)))));


--
-- Name: POLICY "Allow public operations on test check-ins" ON check_ins; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Allow public operations on test check-ins" ON public.check_ins IS 'Allows unauthenticated access to test check-in records for testing purposes';


--
-- Name: members Allow public operations on test members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public operations on test members" ON public.members USING (((email ~~ '%.test.mt@example.com'::text) OR (email ~~ '%test.checkin%'::text))) WITH CHECK (((email ~~ '%.test.mt@example.com'::text) OR (email ~~ '%test.checkin%'::text)));


--
-- Name: POLICY "Allow public operations on test members" ON members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Allow public operations on test members" ON public.members IS 'Allows unauthenticated access to test member records for testing purposes';


--
-- Name: class_schedule Allow public read access to class schedule; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public read access to class schedule" ON public.class_schedule FOR SELECT USING (true);


--
-- Name: members Allow public read access to members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public read access to members" ON public.members FOR SELECT USING (true);


--
-- Name: check_ins Allow public to create check-ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public to create check-ins" ON public.check_ins FOR INSERT WITH CHECK (true);


--
-- Name: check_ins Allow public to read check-ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public to read check-ins" ON public.check_ins FOR SELECT USING (true);


--
-- Name: members Allow public to update members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public to update members" ON public.members USING (true) WITH CHECK (true);


--
-- Name: check_ins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.check_ins ENABLE ROW LEVEL SECURITY;

--
-- Name: class_schedule; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.class_schedule ENABLE ROW LEVEL SECURITY;

--
-- Name: members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION check_card_member_match(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_card_member_match() TO anon;
GRANT ALL ON FUNCTION public.check_card_member_match() TO authenticated;
GRANT ALL ON FUNCTION public.check_card_member_match() TO service_role;


--
-- Name: FUNCTION check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid) TO anon;
GRANT ALL ON FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_card_validity(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date, p_trainer_id uuid) TO service_role;


--
-- Name: FUNCTION check_card_validity_detailed(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_card_validity_detailed(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date) TO anon;
GRANT ALL ON FUNCTION public.check_card_validity_detailed(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date) TO authenticated;
GRANT ALL ON FUNCTION public.check_card_validity_detailed(p_card_id uuid, p_member_id uuid, p_class_type text, p_check_in_date date) TO service_role;


--
-- Name: FUNCTION check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text) TO anon;
GRANT ALL ON FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text) TO authenticated;
GRANT ALL ON FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_date date, p_class_type text, p_time_slot text) TO service_role;


--
-- Name: FUNCTION check_duplicate_check_in(p_member_id uuid, p_check_in_date date, p_class_type text, p_ignore_is_1v2 boolean, p_check_trainer boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_check_in_date date, p_class_type text, p_ignore_is_1v2 boolean, p_check_trainer boolean) TO anon;
GRANT ALL ON FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_check_in_date date, p_class_type text, p_ignore_is_1v2 boolean, p_check_trainer boolean) TO authenticated;
GRANT ALL ON FUNCTION public.check_duplicate_check_in(p_member_id uuid, p_check_in_date date, p_class_type text, p_ignore_is_1v2 boolean, p_check_trainer boolean) TO service_role;


--
-- Name: FUNCTION check_duplicate_check_in_bool(p_member_id uuid, p_date date, p_class_type text, p_time_slot text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_duplicate_check_in_bool(p_member_id uuid, p_date date, p_class_type text, p_time_slot text) TO anon;
GRANT ALL ON FUNCTION public.check_duplicate_check_in_bool(p_member_id uuid, p_date date, p_class_type text, p_time_slot text) TO authenticated;
GRANT ALL ON FUNCTION public.check_duplicate_check_in_bool(p_member_id uuid, p_date date, p_class_type text, p_time_slot text) TO service_role;


--
-- Name: FUNCTION check_duplicate_membership_cards(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_duplicate_membership_cards() TO anon;
GRANT ALL ON FUNCTION public.check_duplicate_membership_cards() TO authenticated;
GRANT ALL ON FUNCTION public.check_duplicate_membership_cards() TO service_role;


--
-- Name: FUNCTION check_in_logging(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_in_logging() TO anon;
GRANT ALL ON FUNCTION public.check_in_logging() TO authenticated;
GRANT ALL ON FUNCTION public.check_in_logging() TO service_role;


--
-- Name: FUNCTION check_in_validation(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_in_validation() TO anon;
GRANT ALL ON FUNCTION public.check_in_validation() TO authenticated;
GRANT ALL ON FUNCTION public.check_in_validation() TO service_role;


--
-- Name: FUNCTION check_member_exists(p_member_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_member_exists(p_member_id uuid) TO anon;
GRANT ALL ON FUNCTION public.check_member_exists(p_member_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_member_exists(p_member_id uuid) TO service_role;


--
-- Name: FUNCTION check_monthly_card_daily_limit(p_member_id uuid, p_card_id uuid, p_date date); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_monthly_card_daily_limit(p_member_id uuid, p_card_id uuid, p_date date) TO anon;
GRANT ALL ON FUNCTION public.check_monthly_card_daily_limit(p_member_id uuid, p_card_id uuid, p_date date) TO authenticated;
GRANT ALL ON FUNCTION public.check_monthly_card_daily_limit(p_member_id uuid, p_card_id uuid, p_date date) TO service_role;


--
-- Name: FUNCTION check_trainer_level_match(p_card_trainer_type text, p_trainer_type text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_trainer_level_match(p_card_trainer_type text, p_trainer_type text) TO anon;
GRANT ALL ON FUNCTION public.check_trainer_level_match(p_card_trainer_type text, p_trainer_type text) TO authenticated;
GRANT ALL ON FUNCTION public.check_trainer_level_match(p_card_trainer_type text, p_trainer_type text) TO service_role;


--
-- Name: FUNCTION check_valid_cards(p_member_id uuid, p_card_type text, p_current_card_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_valid_cards(p_member_id uuid, p_card_type text, p_current_card_id uuid) TO anon;
GRANT ALL ON FUNCTION public.check_valid_cards(p_member_id uuid, p_card_type text, p_current_card_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_valid_cards(p_member_id uuid, p_card_type text, p_current_card_id uuid) TO service_role;


--
-- Name: FUNCTION convert_time_slot_to_class_type(p_time_slot text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.convert_time_slot_to_class_type(p_time_slot text) TO anon;
GRANT ALL ON FUNCTION public.convert_time_slot_to_class_type(p_time_slot text) TO authenticated;
GRANT ALL ON FUNCTION public.convert_time_slot_to_class_type(p_time_slot text) TO service_role;


--
-- Name: FUNCTION deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean, p_is_1v2 boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean, p_is_1v2 boolean) TO anon;
GRANT ALL ON FUNCTION public.deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean, p_is_1v2 boolean) TO authenticated;
GRANT ALL ON FUNCTION public.deduct_membership_sessions(p_card_id uuid, p_class_type text, p_is_private boolean, p_is_1v2 boolean) TO service_role;


--
-- Name: FUNCTION delete_member(p_member_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.delete_member(p_member_id uuid) TO anon;
GRANT ALL ON FUNCTION public.delete_member(p_member_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.delete_member(p_member_id uuid) TO service_role;


--
-- Name: FUNCTION delete_member_cascade(p_member_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.delete_member_cascade(p_member_id uuid) TO anon;
GRANT ALL ON FUNCTION public.delete_member_cascade(p_member_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.delete_member_cascade(p_member_id uuid) TO service_role;


--
-- Name: FUNCTION detect_check_in_anomalies(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.detect_check_in_anomalies() TO anon;
GRANT ALL ON FUNCTION public.detect_check_in_anomalies() TO authenticated;
GRANT ALL ON FUNCTION public.detect_check_in_anomalies() TO service_role;


--
-- Name: FUNCTION find_member_for_checkin(p_name text, p_email text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.find_member_for_checkin(p_name text, p_email text) TO anon;
GRANT ALL ON FUNCTION public.find_member_for_checkin(p_name text, p_email text) TO authenticated;
GRANT ALL ON FUNCTION public.find_member_for_checkin(p_name text, p_email text) TO service_role;


--
-- Name: TABLE members; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.members TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.members TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.members TO service_role;


--
-- Name: FUNCTION find_members_without_cards(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.find_members_without_cards() TO anon;
GRANT ALL ON FUNCTION public.find_members_without_cards() TO authenticated;
GRANT ALL ON FUNCTION public.find_members_without_cards() TO service_role;


--
-- Name: FUNCTION find_valid_card_for_checkin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.find_valid_card_for_checkin() TO anon;
GRANT ALL ON FUNCTION public.find_valid_card_for_checkin() TO authenticated;
GRANT ALL ON FUNCTION public.find_valid_card_for_checkin() TO service_role;


--
-- Name: FUNCTION fix_member_extra_checkins(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fix_member_extra_checkins() TO anon;
GRANT ALL ON FUNCTION public.fix_member_extra_checkins() TO authenticated;
GRANT ALL ON FUNCTION public.fix_member_extra_checkins() TO service_role;


--
-- Name: FUNCTION generate_mock_check_ins(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generate_mock_check_ins() TO anon;
GRANT ALL ON FUNCTION public.generate_mock_check_ins() TO authenticated;
GRANT ALL ON FUNCTION public.generate_mock_check_ins() TO service_role;


--
-- Name: FUNCTION get_class_type_from_time_slot(p_time_slot text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_class_type_from_time_slot(p_time_slot text) TO anon;
GRANT ALL ON FUNCTION public.get_class_type_from_time_slot(p_time_slot text) TO authenticated;
GRANT ALL ON FUNCTION public.get_class_type_from_time_slot(p_time_slot text) TO service_role;


--
-- Name: FUNCTION get_valid_time_slot(p_class_type text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_valid_time_slot(p_class_type text) TO anon;
GRANT ALL ON FUNCTION public.get_valid_time_slot(p_class_type text) TO authenticated;
GRANT ALL ON FUNCTION public.get_valid_time_slot(p_class_type text) TO service_role;


--
-- Name: FUNCTION handle_check_in(p_member_id uuid, p_name text, p_email text, p_class_type text, p_check_in_date date, p_card_id uuid, p_trainer_id uuid, p_is_1v2 boolean, p_time_slot text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.handle_check_in(p_member_id uuid, p_name text, p_email text, p_class_type text, p_check_in_date date, p_card_id uuid, p_trainer_id uuid, p_is_1v2 boolean, p_time_slot text) TO anon;
GRANT ALL ON FUNCTION public.handle_check_in(p_member_id uuid, p_name text, p_email text, p_class_type text, p_check_in_date date, p_card_id uuid, p_trainer_id uuid, p_is_1v2 boolean, p_time_slot text) TO authenticated;
GRANT ALL ON FUNCTION public.handle_check_in(p_member_id uuid, p_name text, p_email text, p_class_type text, p_check_in_date date, p_card_id uuid, p_trainer_id uuid, p_is_1v2 boolean, p_time_slot text) TO service_role;


--
-- Name: FUNCTION init_check_in_session(member_id uuid, class_type_param public.class_type); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.init_check_in_session(member_id uuid, class_type_param public.class_type) TO anon;
GRANT ALL ON FUNCTION public.init_check_in_session(member_id uuid, class_type_param public.class_type) TO authenticated;
GRANT ALL ON FUNCTION public.init_check_in_session(member_id uuid, class_type_param public.class_type) TO service_role;


--
-- Name: FUNCTION log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid) TO anon;
GRANT ALL ON FUNCTION public.log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.log_debug(p_function_name text, p_message text, p_details jsonb, p_member_id uuid) TO service_role;


--
-- Name: FUNCTION process_check_in(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.process_check_in() TO anon;
GRANT ALL ON FUNCTION public.process_check_in() TO authenticated;
GRANT ALL ON FUNCTION public.process_check_in() TO service_role;


--
-- Name: FUNCTION register_new_member(p_name text, p_email text, p_time_slot text, p_is_private boolean, p_trainer_id uuid, p_is_1v2 boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.register_new_member(p_name text, p_email text, p_time_slot text, p_is_private boolean, p_trainer_id uuid, p_is_1v2 boolean) TO anon;
GRANT ALL ON FUNCTION public.register_new_member(p_name text, p_email text, p_time_slot text, p_is_private boolean, p_trainer_id uuid, p_is_1v2 boolean) TO authenticated;
GRANT ALL ON FUNCTION public.register_new_member(p_name text, p_email text, p_time_slot text, p_is_private boolean, p_trainer_id uuid, p_is_1v2 boolean) TO service_role;


--
-- Name: FUNCTION register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid) TO anon;
GRANT ALL ON FUNCTION public.register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.register_new_member(p_class_type text, p_email text, p_is_1v2 boolean, p_is_private boolean, p_name text, p_time_slot text, p_trainer_id uuid) TO service_role;


--
-- Name: FUNCTION search_member(search_term text, exact_match boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.search_member(search_term text, exact_match boolean) TO anon;
GRANT ALL ON FUNCTION public.search_member(search_term text, exact_match boolean) TO authenticated;
GRANT ALL ON FUNCTION public.search_member(search_term text, exact_match boolean) TO service_role;


--
-- Name: FUNCTION set_card_validity(p_card_id uuid, p_card_type text, p_card_category text, p_card_subtype text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_card_validity(p_card_id uuid, p_card_type text, p_card_category text, p_card_subtype text) TO anon;
GRANT ALL ON FUNCTION public.set_card_validity(p_card_id uuid, p_card_type text, p_card_category text, p_card_subtype text) TO authenticated;
GRANT ALL ON FUNCTION public.set_card_validity(p_card_id uuid, p_card_type text, p_card_category text, p_card_subtype text) TO service_role;


--
-- Name: FUNCTION test_expired_card_validation(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.test_expired_card_validation() TO anon;
GRANT ALL ON FUNCTION public.test_expired_card_validation() TO authenticated;
GRANT ALL ON FUNCTION public.test_expired_card_validation() TO service_role;


--
-- Name: FUNCTION test_expired_card_validation_v2(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.test_expired_card_validation_v2() TO anon;
GRANT ALL ON FUNCTION public.test_expired_card_validation_v2() TO authenticated;
GRANT ALL ON FUNCTION public.test_expired_card_validation_v2() TO service_role;


--
-- Name: FUNCTION trigger_deduct_sessions(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.trigger_deduct_sessions() TO anon;
GRANT ALL ON FUNCTION public.trigger_deduct_sessions() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_deduct_sessions() TO service_role;


--
-- Name: FUNCTION trigger_set_card_validity(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.trigger_set_card_validity() TO anon;
GRANT ALL ON FUNCTION public.trigger_set_card_validity() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_set_card_validity() TO service_role;


--
-- Name: FUNCTION update_check_in_stats(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_check_in_stats() TO anon;
GRANT ALL ON FUNCTION public.update_check_in_stats() TO authenticated;
GRANT ALL ON FUNCTION public.update_check_in_stats() TO service_role;


--
-- Name: FUNCTION update_member_extra_checkins(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_member_extra_checkins() TO anon;
GRANT ALL ON FUNCTION public.update_member_extra_checkins() TO authenticated;
GRANT ALL ON FUNCTION public.update_member_extra_checkins() TO service_role;


--
-- Name: FUNCTION update_member_status(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_member_status() TO anon;
GRANT ALL ON FUNCTION public.update_member_status() TO authenticated;
GRANT ALL ON FUNCTION public.update_member_status() TO service_role;


--
-- Name: FUNCTION validate_check_in(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_check_in() TO anon;
GRANT ALL ON FUNCTION public.validate_check_in() TO authenticated;
GRANT ALL ON FUNCTION public.validate_check_in() TO service_role;


--
-- Name: FUNCTION validate_check_in_card(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_check_in_card() TO anon;
GRANT ALL ON FUNCTION public.validate_check_in_card() TO authenticated;
GRANT ALL ON FUNCTION public.validate_check_in_card() TO service_role;


--
-- Name: FUNCTION validate_member_name(p_name text, p_email text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_member_name(p_name text, p_email text) TO anon;
GRANT ALL ON FUNCTION public.validate_member_name(p_name text, p_email text) TO authenticated;
GRANT ALL ON FUNCTION public.validate_member_name(p_name text, p_email text) TO service_role;


--
-- Name: FUNCTION validate_membership_card(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_membership_card() TO anon;
GRANT ALL ON FUNCTION public.validate_membership_card() TO authenticated;
GRANT ALL ON FUNCTION public.validate_membership_card() TO service_role;


--
-- Name: FUNCTION validate_private_time_slot(p_time_slot text, p_check_in_date date); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_private_time_slot(p_time_slot text, p_check_in_date date) TO anon;
GRANT ALL ON FUNCTION public.validate_private_time_slot(p_time_slot text, p_check_in_date date) TO authenticated;
GRANT ALL ON FUNCTION public.validate_private_time_slot(p_time_slot text, p_check_in_date date) TO service_role;


--
-- Name: FUNCTION validate_time_slot(p_time_slot text, p_check_in_date date, p_is_private boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_time_slot(p_time_slot text, p_check_in_date date, p_is_private boolean) TO anon;
GRANT ALL ON FUNCTION public.validate_time_slot(p_time_slot text, p_check_in_date date, p_is_private boolean) TO authenticated;
GRANT ALL ON FUNCTION public.validate_time_slot(p_time_slot text, p_check_in_date date, p_is_private boolean) TO service_role;


--
-- Name: TABLE check_in_anomalies; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_in_anomalies TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_in_anomalies TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_in_anomalies TO service_role;


--
-- Name: SEQUENCE check_in_anomalies_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.check_in_anomalies_id_seq TO anon;
GRANT ALL ON SEQUENCE public.check_in_anomalies_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.check_in_anomalies_id_seq TO service_role;


--
-- Name: TABLE check_in_logs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_in_logs TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_in_logs TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_in_logs TO service_role;


--
-- Name: TABLE check_ins; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_ins TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_ins TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.check_ins TO service_role;


--
-- Name: TABLE class_schedule; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.class_schedule TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.class_schedule TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.class_schedule TO service_role;


--
-- Name: TABLE debug_logs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.debug_logs TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.debug_logs TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.debug_logs TO service_role;


--
-- Name: SEQUENCE debug_logs_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.debug_logs_id_seq TO anon;
GRANT ALL ON SEQUENCE public.debug_logs_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.debug_logs_id_seq TO service_role;


--
-- Name: TABLE function_backups; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.function_backups TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.function_backups TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.function_backups TO service_role;


--
-- Name: SEQUENCE function_backups_backup_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.function_backups_backup_id_seq TO anon;
GRANT ALL ON SEQUENCE public.function_backups_backup_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.function_backups_backup_id_seq TO service_role;


--
-- Name: TABLE membership_cards; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.membership_cards TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.membership_cards TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.membership_cards TO service_role;


--
-- Name: TABLE membership_card_view; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.membership_card_view TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.membership_card_view TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.membership_card_view TO service_role;


--
-- Name: TABLE processed_check_ins; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.processed_check_ins TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.processed_check_ins TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.processed_check_ins TO service_role;


--
-- Name: TABLE standardized_cards; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.standardized_cards TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.standardized_cards TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.standardized_cards TO service_role;


--
-- Name: TABLE trainers; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.trainers TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.trainers TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.trainers TO service_role;


--
-- Name: TABLE trigger_backups; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.trigger_backups TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.trigger_backups TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.trigger_backups TO service_role;


--
-- Name: SEQUENCE trigger_backups_backup_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.trigger_backups_backup_id_seq TO anon;
GRANT ALL ON SEQUENCE public.trigger_backups_backup_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.trigger_backups_backup_id_seq TO service_role;


--
-- PostgreSQL database dump complete
--



