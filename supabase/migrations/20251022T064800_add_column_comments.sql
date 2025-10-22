-- 为 stories 表添加字段注释
comment on table public.stories is '剧本主表，记录剧本的基础信息';
comment on column public.stories.id is '剧本主键，UUID';
comment on column public.stories.author_user_id is '剧本作者（Supabase 用户 ID），允许为空';
comment on column public.stories.slug is '剧本唯一标识，用于路由或检索';
comment on column public.stories.title is '剧本标题';
comment on column public.stories.summary is '剧本概要描述';
comment on column public.stories.genre is '剧本类型或题材标签';
comment on column public.stories.metadata is '剧本额外配置信息（JSON）';
comment on column public.stories.is_published is '是否已发布，控制前端可见性';
comment on column public.stories.created_at is '创建时间（UTC）';
comment on column public.stories.updated_at is '最近更新时间（UTC）';

-- 为 chapters 表添加字段注释
comment on table public.chapters is '章节表，存储剧本章节信息';
comment on column public.chapters.id is '章节主键，UUID';
comment on column public.chapters.story_id is '所属剧本 ID';
comment on column public.chapters.order_index is '章节顺序，从 1 开始递增';
comment on column public.chapters.title is '章节标题';
comment on column public.chapters.synopsis is '章节简介';
comment on column public.chapters.ink_knot is '对应的 ink 节点名称，用于驱动剧情引擎';
comment on column public.chapters.metadata is '章节附加元数据（JSON）';
comment on column public.chapters.created_at is '创建时间（UTC）';
comment on column public.chapters.updated_at is '最近更新时间（UTC）';

-- 为 situations 表添加字段注释
comment on table public.situations is '局势表，定义章节内的关键局势或任务';
comment on column public.situations.id is '局势主键，UUID';
comment on column public.situations.chapter_id is '所属章节 ID';
comment on column public.situations.situation_key is '局势唯一键，供状态表引用';
comment on column public.situations.description is '局势描述或背景信息';
comment on column public.situations.success_conditions is '完成条件（JSON）';
comment on column public.situations.failure_conditions is '失败条件（JSON）';
comment on column public.situations.metadata is '局势额外配置（JSON）';
comment on column public.situations.created_at is '创建时间（UTC）';
comment on column public.situations.updated_at is '最近更新时间（UTC）';

-- 为 chat_sessions 表添加字段注释
comment on table public.chat_sessions is '用户会话表，记录一次完整的互动体验';
comment on column public.chat_sessions.id is '会话主键，UUID';
comment on column public.chat_sessions.user_id is '会话所属用户 ID';
comment on column public.chat_sessions.story_id is '关联的剧本 ID，可为空表示临时体验';
comment on column public.chat_sessions.title is '会话标题或玩家自定义名字';
comment on column public.chat_sessions.synopsis is '会话简介或当前进度摘要';
comment on column public.chat_sessions.created_at is '创建时间（UTC）';
comment on column public.chat_sessions.updated_at is '最近更新时间（UTC）';

-- 为 chat_messages 表添加字段注释
comment on table public.chat_messages is '对话消息表，存储系统、玩家与模型的消息';
comment on column public.chat_messages.id is '消息主键，UUID';
comment on column public.chat_messages.session_id is '所属会话 ID';
comment on column public.chat_messages.role is '消息角色（system/user/assistant）';
comment on column public.chat_messages.content is '消息正文内容';
comment on column public.chat_messages.metadata is '消息附加信息（JSON），如模型评分';
comment on column public.chat_messages.created_at is '消息创建时间（UTC）';

-- 为 situation_states 表添加字段注释
comment on table public.situation_states is '局势状态表，记录玩家在会话中的局势进度';
comment on column public.situation_states.id is '状态记录主键，UUID';
comment on column public.situation_states.session_id is '所属会话 ID';
comment on column public.situation_states.situation_key is '局势唯一键，对应 situations.situation_key';
comment on column public.situation_states.status is '状态（pending/in_progress/completed）';
comment on column public.situation_states.score is '分数或完成度评估';
comment on column public.situation_states.summary is '状态摘要或判定说明';
comment on column public.situation_states.updated_at is '最近更新时间（UTC）';

-- 为 session_logs 表添加字段注释
comment on table public.session_logs is '会话日志表，记录系统事件、判定和异常信息';
comment on column public.session_logs.id is '日志主键，UUID';
comment on column public.session_logs.session_id is '所属会话 ID';
comment on column public.session_logs.event_type is '事件类型标识';
comment on column public.session_logs.payload is '事件内容（JSON）';
comment on column public.session_logs.created_at is '记录时间（UTC）';

-- 为 memory_records 表添加字段注释
comment on table public.memory_records is '记忆记录表，可存储长时记忆或向量检索条目';
comment on column public.memory_records.id is '记忆主键，UUID';
comment on column public.memory_records.session_id is '关联会话 ID（可为空）';
comment on column public.memory_records.story_id is '关联剧本 ID（可为空）';
comment on column public.memory_records.title is '记忆标题或标签';
comment on column public.memory_records.summary is '记忆摘要';
comment on column public.memory_records.embedding is '向量表示（1536 维）';
comment on column public.memory_records.metadata is '附加元数据（JSON）';
comment on column public.memory_records.created_at is '创建时间（UTC）';
