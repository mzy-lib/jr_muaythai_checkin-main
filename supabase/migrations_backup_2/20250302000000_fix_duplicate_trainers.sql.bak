-- 修复重复的教练数据
-- 根据文档，我们应该只有7个教练：
-- JR类教练1名：JR
-- Senior类教练6名：Da, Ming, Big, Bas, Sumay, First

-- 添加唯一性约束，防止将来出现重复
ALTER TABLE trainers ADD CONSTRAINT IF NOT EXISTS trainers_name_unique UNIQUE (name);

-- 添加注释
COMMENT ON TABLE trainers IS '教练表，包含JR教练和高级教练';
COMMENT ON COLUMN trainers.id IS '教练ID，主键';
COMMENT ON COLUMN trainers.name IS '教练姓名，必须唯一';
COMMENT ON COLUMN trainers.type IS '教练类型，jr或senior';
COMMENT ON COLUMN trainers.notes IS '备注信息';
COMMENT ON COLUMN trainers.created_at IS '创建时间'; 