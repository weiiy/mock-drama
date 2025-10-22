-- 激活核心扩展：时间戳更新、UUID、向量
create extension if not exists moddatetime;
create extension if not exists "pgcrypto";
create extension if not exists vector;

-- 剧本主信息，由创作者或管理员维护
create table if not exists public.stories (
    id uuid primary key default gen_random_uuid(),
    author_user_id uuid references auth.users (id) on delete set null,
    slug text unique,
    title text not null,
    summary text,
    genre text,
    metadata jsonb not null default '{}'::jsonb,
    is_published boolean not null default false,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create trigger set_stories_updated_at
    before update on public.stories
    for each row execute procedure moddatetime(updated_at);

-- 剧本章节信息
create table if not exists public.chapters (
    id uuid primary key default gen_random_uuid(),
    story_id uuid not null references public.stories (id) on delete cascade,
    order_index integer not null,
    title text not null,
    synopsis text,
    ink_knot text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (story_id, order_index)
);

create trigger set_chapters_updated_at
    before update on public.chapters
    for each row execute procedure moddatetime(updated_at);

-- 每章内的局势定义
create table if not exists public.situations (
    id uuid primary key default gen_random_uuid(),
    chapter_id uuid not null references public.chapters (id) on delete cascade,
    situation_key text not null,
    description text,
    success_conditions jsonb,
    failure_conditions jsonb,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (chapter_id, situation_key)
);

create trigger set_situations_updated_at
    before update on public.situations
    for each row execute procedure moddatetime(updated_at);

-- 用户一次完整的互动剧本体验
create table if not exists public.chat_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    story_id uuid references public.stories (id) on delete set null,
    title text,
    synopsis text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create trigger set_chat_sessions_updated_at
    before update on public.chat_sessions
    for each row execute procedure moddatetime(updated_at);

-- 记录会话中的每条对话消息
create table if not exists public.chat_messages (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.chat_sessions(id) on delete cascade,
    role text not null check (role in ('system', 'user', 'assistant')),
    content text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now())
);

create index if not exists chat_messages_session_id_idx
    on public.chat_messages(session_id, created_at);

-- 保存每个局势在当前会话中的状态
create table if not exists public.situation_states (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.chat_sessions(id) on delete cascade,
    situation_key text not null,
    status text not null check (status in ('pending', 'in_progress', 'completed')),
    score numeric,
    summary text,
    updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists situation_states_session_key_uidx
    on public.situation_states(session_id, situation_key);

create trigger set_situation_states_updated_at
    before update on public.situation_states
    for each row execute procedure moddatetime(updated_at);

-- 记录系统判定、错误或分支决策等事件
create table if not exists public.session_logs (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.chat_sessions (id) on delete cascade,
    event_type text not null,
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now())
);

create index if not exists session_logs_session_id_idx
    on public.session_logs (session_id, created_at desc);

-- 长期记忆或向量检索记录，可作为 RAG 数据源
create table if not exists public.memory_records (
    id uuid primary key default gen_random_uuid(),
    session_id uuid references public.chat_sessions (id) on delete cascade,
    story_id uuid references public.stories (id) on delete cascade,
    title text,
    summary text,
    embedding vector(1536),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now())
);

create index if not exists memory_records_session_idx
    on public.memory_records (session_id);

create index if not exists memory_records_story_idx
    on public.memory_records (story_id);

-- 开启行级安全，保证用户数据隔离
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.situation_states enable row level security;
alter table public.session_logs enable row level security;
alter table public.memory_records enable row level security;

-- 用户仅能操作自己的会话
create policy "Users manage own chat sessions"
    on public.chat_sessions
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- 消息访问跟随所属会话
create policy "Users manage own chat messages"
    on public.chat_messages
    for all
    using (
        exists (
            select 1 from public.chat_sessions s
            where s.id = chat_messages.session_id
              and s.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.chat_sessions s
            where s.id = chat_messages.session_id
              and s.user_id = auth.uid()
        )
    );

-- 局势状态同样按照会话归属限制
create policy "Users manage own situation states"
    on public.situation_states
    for all
    using (
        exists (
            select 1 from public.chat_sessions s
            where s.id = public.situation_states.session_id
              and s.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.chat_sessions s
            where s.id = public.situation_states.session_id
              and s.user_id = auth.uid()
        )
    );

-- 仅会话拥有者可读写日志
create policy "Users manage own session logs"
    on public.session_logs
    for all
    using (
        exists (
            select 1 from public.chat_sessions s
            where s.id = public.session_logs.session_id
              and s.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.chat_sessions s
            where s.id = public.session_logs.session_id
              and s.user_id = auth.uid()
        )
    );

-- 记忆记录按会话或剧本归属进行权限控制
create policy "Users manage own memory records"
    on public.memory_records
    for all
    using (
        (session_id is null and story_id is null)
        or exists (
            select 1 from public.chat_sessions s
            where s.id = public.memory_records.session_id
              and s.user_id = auth.uid()
        )
        or exists (
            select 1 from public.stories st
            where st.id = public.memory_records.story_id
              and (st.author_user_id = auth.uid() or st.is_published)
        )
    )
    with check (
        (session_id is null and story_id is null)
        or exists (
            select 1 from public.chat_sessions s
            where s.id = public.memory_records.session_id
              and s.user_id = auth.uid()
        )
        or exists (
            select 1 from public.stories st
            where st.id = public.memory_records.story_id
              and st.author_user_id = auth.uid()
        )
    );
