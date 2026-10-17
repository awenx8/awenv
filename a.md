1. enableWorkflows: false 是什么

   在 2.1.302 的 settings schema 里（我从二进制里提的 describe() 原文）：

   enableWorkflows: "Enable or disable the Workflows feature for this user.
   Unset = default by plan once the feature is available."

   Workflows = 动态多智能体编排：模型自己"写"一个 workflow 去并行拉起一批
   subagent。相关代码/键一起确认了：

   键: disableWorkflows: true
   作用: 同一功能的反向键（老写法），CLAUDE_CODE_DISABLE_WORKFLOWS 也能关
   ────────────────────────────────────────
   键: CLAUDE_CODE_WORKFLOWS=1
   作用: 环境变量强开
   ────────────────────────────────────────
   键: workflowSizeGuideline
   作用: 原文："small" aims for fewer than 5 agents, "medium" fewer than 10,
   "large" fewer than 50, "unrestricted" sends no guideline（unset 默认
   medium，Pro 计划 small）
   ────────────────────────────────────────
   键: workflowKeywordTriggerEnabled
   作用: 默认 true
   ────────────────────────────────────────
   键: skipWorkflowUsageWarning
   作用: 关掉用量告警
   ────────────────────────────────────────
   键: CLAUDE_CODE_WORKFLOW_SIZE_WARNING_AGENTS/TOKENS、_SUBAGENT_MODEL、_MAX_CON
   CURRENT_AGENTS
   作用: workflow 规模/模型/并发旋钮

   关掉后省掉的是：workflow 相关的系统提示片段 + workflow-authoring /
   plugin-authoring 这两个 skill 的列表条目 + 提示词里的 workflow
   引导语。量级大约 1–3K token，属于小头。（我没找到一个"workflow
   开启时"的会话去对照，所以这个数字是估计，不是实测。）

---

2. 你这一轮实际固定开销的实测

   我从 ~/.claude/projects/-root-awenx8-ai-list/*.jsonl 的 api-request-shape
   记录里量的：

   ┌────────────────────────────────────────┬────────┬─────────────┐
   │ 块 │ 字符 │ ≈token    │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ tools（19 个工具的 JSON schema） │ 46,161 │ ~27.7K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ system[1]（agent 行为准则 + # Memory） │ 5,893 │ ~3.5K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ — 其中 # Memory                        │ 3,212 │ ~1.9K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ 环境块（# Environment + agent types） │ 5,402 │ ~3.2K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ — 其中 Available agent types（6 个） │ 4,509 │ ~2.7K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ skills 列表（7 个）                    │ ~2.5K │ ~1.5K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ gitStatus system-reminder │ 1,029 │ ~0.6K │
   ├────────────────────────────────────────┼────────┼─────────────┤
   │ 合计固定前缀 │        │ ~36.5K / 轮 │
   └────────────────────────────────────────┴────────┴─────────────┘

   单工具最大的：SendMessage 5,800 / AskUserQuestion 5,038 / ScheduleWakeup 5,017
   / EnterPlanMode 4,324 / CronCreate 4,322 / Agent 3,584 / Bash 3,061（字符）。

   所以 enableWorkflows 省的量，还不到 tools 那 27.7K 的十分之一。
   想真正省上下文，优先级应该反过来。

   另外提醒一句：你已经设了 CLAUDE_CODE_MAX_CONTEXT_TOKENS:
   256000，那是扩大窗口，不省；而 <total_tokens> 显示 15,000,000，说明你那个
   proxy 报了个很大的窗口。你在 token.sensenova.cn 上跑，如果 proxy 不吃
   cache_control（请求里确实带 prompt-caching-scope-2026-01-05），这 36.5K
   每一轮都是全价。

---

3. 其他能省系统上下文的配置（按收益排序）

   收益最大：砍工具 schema（~27.7K）

   配置: --tools Bash,Edit,Read,Write
   说明: CLI，schema 原文：Specify the list of available tools from the built-in
   set. Use "" to disable all tools, "default" to use all tools, or specify
   tool names。唯一能砍 27.7K 的开关
   ────────────────────────────────────────
   配置: --restricted
   说明: 原文：removes the built-in tools that run commands ... and WebFetch
   unless --tools names them, and ignores user, project and local settings
   files
   ────────────────────────────────────────
   配置: permissions.deny
   说明: 拒绝的工具不会下发给模型（顺带省 schema）
   ────────────────────────────────────────
   配置: MCP
   说明: mcpServers 保持为空、enableAllProjectMcpServers: false；MCP 还会带来
   server 注入的 prompt 文本
   ────────────────────────────────────────
   配置: CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH
   说明: 截断 MCP 工具描述（键已在二进制中确认）
   ────────────────────────────────────────
   配置: CLAUDE_CODE_SKIP_PLUGIN_MCP_SERVERS / _EXCEPT
   说明: 插件带的 MCP 服务器
   ────────────────────────────────────────
   配置: enableArtifact: false
   说明: 原文：Turn the Artifact tool on or off. Off in any of managed,
   --settings, or user settings wins。可省 Artifact +
   ArtifactComments/Data/Check 一组 schema
   ────────────────────────────────────────
   配置: CLAUDE_CODE_DISABLE_CRON
   说明: 省 CronCreate+CronDelete+CronList ≈ 5.1K 字符 ≈ 3K token
   ────────────────────────────────────────
   配置: CLAUDE_CODE_DISABLE_BACKGROUND_TASKS
   说明: 省 TaskStop

   砍 agent 类型（~2.7K）

   ┌──────────────────────────────────────────────────────┬──────────────────┐
   │ 配置 │ 说明 │
   ├──────────────────────────────────────────────────────┼──────────────────┤
   │ │ 关掉 Explore / │
   │ CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS │ Plan 两个 agent │
   │ │ 类型定义 │
   ├──────────────────────────────────────────────────────┼──────────────────┤
   │ │ 自定义 agent │
   │ 删 ~/.claude/agents/*.md │ 的定义会整段进 │
   │ │ Available agent │
   │ │ types            │
   ├──────────────────────────────────────────────────────┼──────────────────┤
   │ │ 它是唯一会自己带 │
   │ 你这里 claude-code-guide 单个就 ~700 token │ 4 个工具的 │
   │ │ agent            │
   ├──────────────────────────────────────────────────────┼──────────────────┤
   │ CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION、_MAX_CONCURRE │ 不省上下文，只限 │
   │ NT_SUBAGENTS │ 并发 │
   └──────────────────────────────────────────────────────┴──────────────────┘

   砍 skills 列表（你已经在用了）

   配置: skillOverrides: {"名字": "off"}
   说明: 你已关掉 9 个。/skills 里也能改
   ────────────────────────────────────────
   配置: disableBundledSkills
   说明: 原文片段：turned off with every other bundled skill by the
   disableBundledSkills setting or
   CLAUDE_CODE_DISABLE_BUNDLED_SKILLS。一把梭关所有内置 skill
   ────────────────────────────────────────
   配置: CLAUDE_CODE_DISABLE_BUNDLED_SKILLS
   说明: 同上，环境变量版
   ────────────────────────────────────────
   配置: CLAUDE_CODE_DISABLE_CLAUDE_API_SKILL / _DISABLE_CLAUDE_CODE_SKILL /
   _DISABLE_POLICY_SKILLS
   说明: 单个 skill 的 env 开关
   ────────────────────────────────────────
   配置: syncClaudeAiSkills: false
   说明: 原文：nothing more is downloaded, previously synced skills
   (~/.claude/skills/synced) can no longer be run, are hidden from every
   session
   ────────────────────────────────────────
   配置: syncClaudeAiPlugins: false / disablePluginDirectory
   说明: 插件 = skills + agents + MCP tools 三个来源一起加，你机器上有 2.6MB 的
   plugin-directory-cache-v2.json 但没启用

   砍注入的上下文块

   ┌─────────────────────────────┬───────────────────────────────────┬──────┐
   │            配置 │ 省什么 │ 量级 │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ CLAUDE_CODE_DISABLE_AUTO_ME │ # Memory 段（代码里和 # auto │ ~1.9 │
   │ MORY                        │ memory / disabled_by_env_var │ K    │
   │ │ 同段）                            │ │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ CLAUDE_CODE_DISABLE_CLAUDE_ │ CLAUDE.md 注入                    │ 视大 │
   │ MDS │ │ 小 │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ CLAUDE_CODE_DISABLE_GIT_INS │ git 指令/gitStatus reminder │ ~0.6 │
   │ TRUCTIONS │ │ K    │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ CLAUDE_CODE_TOTAL_TOKENS_RE │ 那几行 <total_tokens>...tokens    │ │
   │ MINDER（+ │ left</total_tokens>（现在每轮还额 │ 小 │
   │ _BUDGET、_AFTER_USER_TURN） │ 外追加一条 system 消息） │ │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ CLAUDE_CODE_DISABLE_ATTACHM │ 附件/@ 提及类注入 │ 视情 │
   │ ENTS                        │ │ 况 │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ CLAUDE_CODE_SIMPLE_SYSTEM_P │ 精简系统提示词（键在，语义按命名 │ 中大 │
   │ ROMPT │ 推断）                            │ │
   ├─────────────────────────────┼───────────────────────────────────┼──────┤
   │ --append-system-prompt │ 反方向，别加 │ —    │
   └─────────────────────────────┴───────────────────────────────────┴──────┘

   控"对话膨胀"（不是系统提示词，但更常先爆）

   ┌─────────────────────────────────────────┬────────────────────────────────┐
   │ 配置 │ 说明 │
   ├─────────────────────────────────────────┼────────────────────────────────┤
   │ autoCompact / │ 自动压缩阈值 │
   │ CLAUDE_CODE_AUTO_COMPACT_WINDOW │                                │
   ├─────────────────────────────────────────┼────────────────────────────────┤
   │ idleCompaction /                        │                                │
   │ CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS / │ 空闲时压缩 │
   │ CLAUDE_CODE_IDLE_THRESHOLD_MINUTES │                                │
   ├─────────────────────────────────────────┼────────────────────────────────┤
   │ bashOutputMaxChars / taskOutputMaxChars │                                │
   │ / │ 限制单次工具输出进上下文的量 │
   │ CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS │                                │
   ├─────────────────────────────────────────┼────────────────────────────────┤
   │ /compact、/clear                        │ 手动 │
   ├─────────────────────────────────────────┼────────────────────────────────┤
   │ │ 省输出侧 thinking │
   │ CLAUDE_CODE_DISABLE_THINKING / │ token（你请求里现在是 │
   │ _DISABLE_ADAPTIVE_THINKING │ "thinking":{"type":"adaptive"} │
   │ │ + max_tokens: 32000） │
   ├─────────────────────────────────────────┼────────────────────────────────┤
   │ CLAUDE_CODE_MAX_OUTPUT_TOKENS │ 压输出预算 │
   └─────────────────────────────────────────┴────────────────────────────────┘

---

4. 给你的建议
1. enableWorkflows: false 留着就行，但它不是重点。
2. 真正的杠杆是 --tools：把 Agent/Cron*/ScheduleWakeup/EnterPlanMode/AskUserQu
   estion/SendMessage/ReportFindings 这类你平时不用的去掉，一次能砍 15K+
   token。
3. disableBundledSkills 直接替代你那个 9 行的
   skillOverrides，除非你只想挑着关。
4. 你这套代理配置下，如果 cache_control 生效，固定前缀只在 cache miss
   时按全价算，省上下文的边际收益会打折；建议先用 /cost 或看 proxy 账单确认
   proxy 是否真支持缓存，再决定要不要激进裁剪。
