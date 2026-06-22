<template>
  <div>
    <h1 class="page-title"><i class="fas fa-question-circle"></i> 帮助文档</h1>

    <div class="help-container">
      <div class="help-card">
        <h2 class="help-main-title">硬件测试记录系统使用指南</h2>

        <!-- 系统概述 -->
        <div class="help-section">
          <h3 class="help-section-title">系统概述</h3>
          <p>硬件测试记录系统是一套完整的硬件设备测试管理平台，用于管理测试批次、追踪设备状态、记录测试指标、处理故障设备及返厂流程。主要服务于硬件生产和质检团队。</p>
        </div>

        <!-- 仪表盘 -->
        <div class="help-section">
          <h3 class="help-section-title">1. 仪表盘</h3>
          <p><strong>功能概览：</strong>系统首页展示全局数据一览，包括总批次数、进行中批次、设备状态分布饼图、良品率统计、操作员工作量排名和每日测试趋势折线图。</p>
          <p><strong>使用说明：</strong></p>
          <ul class="help-list">
            <li>顶部 KPI 卡片实时反映系统关键指标</li>
            <li>设备状态分布饼图展示正常/故障/待处理设备比例</li>
            <li>良品率统计卡片支持按操作员筛选</li>
            <li>每日测试趋势图支持暗色/亮色主题自适应切换</li>
          </ul>
        </div>

        <!-- 批次管理 -->
        <div class="help-section">
          <h3 class="help-section-title">2. 批次管理</h3>
          <p><strong>核心流程：</strong>批次是设备管理的组织单位，每个批次关联一套测试标准，包含多台待测设备。</p>
          <div class="mermaid-block">
            <pre class="mermaid">
flowchart LR
    A[创建批次] --> B[选择测试标准]
    B --> C[设置开始/截止日期]
    C --> D[计划中]
    D --> E[进行中]
    E --> F{测试完成?}
    F -->|是| G[已完成]
    F -->|暂缓| H[暂停]
    H --> E
    G --> I[归档]
            </pre>
          </div>
          <p><strong>操作步骤：</strong></p>
          <ol class="help-list">
            <li>点击「新建批次」按钮，批次号自动生成（前缀可在系统设置配置）</li>
            <li>填写批次名称、选择测试标准</li>
            <li>批次状态流转：计划中 → 进行中 → 已完成（支持暂停/恢复）</li>
            <li>超期批次以红色高亮显示</li>
            <li>点击批次名称进入批次详情页</li>
          </ol>
          <p><strong>状态说明：</strong></p>
          <table class="help-table">
            <tr><th>状态</th><th>含义</th><th>可执行操作</th></tr>
            <tr><td>计划中</td><td>批次已创建，尚未开始测试</td><td>编辑、删除、开始</td></tr>
            <tr><td>进行中</td><td>设备正在测试</td><td>添加设备、标记完成、暂停</td></tr>
            <tr><td>暂停</td><td>测试暂时中断</td><td>恢复</td></tr>
            <tr><td>已完成</td><td>批次测试结束</td><td>查看、导出</td></tr>
          </table>
        </div>

        <!-- 批次详情与设备管理 -->
        <div class="help-section">
          <h3 class="help-section-title">3. 批次详情与设备管理</h3>
          <p><strong>功能：</strong>查看批次下的所有设备，支持单设备操作和批量操作。</p>
          <div class="mermaid-block">
            <pre class="mermaid">
flowchart TD
    A[批次详情页] --> B[添加设备]
    A --> C[批量操作]
    A --> D[设备列表操作]
    
    B --> B1[单个添加: 填写MAC/IP/状态]
    B --> B2[批量导入: 下载模板 → 上传Excel]
    
    C --> C1[批量改状态]
    C --> C2[批量改处置方式]
    C --> C3[批量改测试指标]
    C --> C4[批量删除]
    
    D --> D1[编辑设备信息]
    D --> D2[故障报备: 填写原因/处置/快递]
    D --> D3[删除设备]
    D --> D4[导出Excel]
            </pre>
          </div>
          <p><strong>添加设备：</strong></p>
          <ul class="help-list">
            <li><em>单个添加：</em>填写板卡MAC（必填）、无线MAC、IP地址，选择状态和测试时间</li>
            <li><em>批量导入：</em>切换到「批量导入」选项卡 → 下载模板 → 按格式填写 → 上传文件 → 预览确认 → 开始导入</li>
            <li><em>自定义编号模式：</em>输入非标准MAC格式时自动激活，无线MAC和IP自动设为「未知」</li>
          </ul>
          <p><strong>KPI 卡片：</strong>实时显示设备总数、正常数、故障数、待处理数及进度百分比。</p>
          <p><strong>动态指标列：</strong>根据批次的测试标准自动生成指标列，显示各设备测试结果。</p>
        </div>

        <!-- 设备管理（全局） -->
        <div class="help-section">
          <h3 class="help-section-title">4. 设备管理（全局视图）</h3>
          <p><strong>功能：</strong>跨批次查看所有设备，支持多维度筛选、批量操作和单个编辑。</p>
          <ul class="help-list">
            <li>搜索：支持按 MAC 地址、IP 地址搜索</li>
            <li>过滤：按状态（正常/故障/待处理）和批次筛选</li>
            <li>状态显示：正常（绿色）、故障（红色）、待处理（黄色）</li>
            <li>批量改状态、批量改处置、批量删除</li>
          </ul>
        </div>

        <!-- 故障管理 -->
        <div class="help-section">
          <h3 class="help-section-title">5. 故障管理</h3>
          <p><strong>功能：</strong>集中管理故障设备，记录处置方式和物流信息。</p>
          <div class="mermaid-block">
            <pre class="mermaid">
flowchart LR
    A[发现故障设备] --> B[故障报备]
    B --> C{选择处置方式}
    C -->|维修| D[记录维修状态]
    C -->|返厂| E[填写快递信息]
    C -->|报废| F[标记报废]
    E --> G[查询物流轨迹]
            </pre>
          </div>
          <p><strong>故障报备流程：</strong></p>
          <ol class="help-list">
            <li>在批次详情页点击故障图标（⚠）</li>
            <li>填写故障说明</li>
            <li>选择处置方式：维修 / 报废 / 返厂</li>
            <li>若选择「返厂」，填写快递公司和快递单号</li>
            <li>提交后可在故障管理页面查看和追踪</li>
          </ol>
          <p><strong>物流查询：</strong>配置快递100 API 密钥后（系统设置页），点击快递单号即可查询实时物流轨迹。</p>
        </div>

        <!-- 返厂管理 -->
        <div class="help-section">
          <h3 class="help-section-title">6. 返厂管理</h3>
          <p><strong>功能：</strong>管理设备返厂记录，自动关联故障设备和快递信息。</p>
          <ul class="help-list">
            <li>统计卡片展示：在途数量、已完成数量、异常数量</li>
            <li>点击快递单号可查询物流状态</li>
            <li>返厂记录与故障设备数据联动</li>
          </ul>
        </div>

        <!-- 测试标准管理 -->
        <div class="help-section">
          <h3 class="help-section-title">7. 测试标准管理</h3>
          <p><strong>功能：</strong>定义和管理测试标准及指标模板。每个标准可包含多个测试指标，创建批次时选择标准后自动应用。</p>
          <table class="help-table">
            <tr><th>指标类型</th><th>说明</th><th>示例</th></tr>
            <tr><td>pass-fail</td><td>通过/不通过</td><td>外观检查、通电测试</td></tr>
            <tr><td>numeric</td><td>数值范围</td><td>电压值、功率值</td></tr>
            <tr><td>range</td><td>范围</td><td>温度范围 -20~85℃</td></tr>
            <tr><td>string</td><td>文本描述</td><td>备注说明</td></tr>
          </table>
          <p>系统预置了四个默认标准：良品率测试、稳定性测试、压力测试、装壳测试。每个标准的指标包含标准值、单位和说明。</p>
        </div>

        <!-- 系统设置 -->
        <div class="help-section">
          <h3 class="help-section-title">8. 系统设置</h3>
          <p><strong>常规设置：</strong></p>
          <ul class="help-list">
            <li><em>系统名称 / 公司名称：</em>影响页面标题和导出文件信息</li>
            <li><em>默认测试人员：</em>新建设备时自动填充的操作员</li>
            <li><em>批次号前缀：</em>格式为 {前缀}-YYYYMMDD-{序号}，如 BAT-20260605-001</li>
            <li><em>每页显示条数：</em>列表分页大小</li>
            <li><em>操作员列表：</em>管理可用的操作员选项</li>
          </ul>
          <p><strong>快递100 配置：</strong>填写企业授权信息（Customer/Key/Secret），启用物流查询功能。</p>
        </div>

        <!-- 用户管理 -->
        <div class="help-section">
          <h3 class="help-section-title">9. 用户管理（管理员）</h3>
          <p>仅管理员可见。管理用户账号，支持创建、编辑、删除用户，分配角色（管理员/测试员），重置密码。</p>
        </div>

        <!-- 主题切换 -->
        <div class="help-section">
          <h3 class="help-section-title">10. 主题切换</h3>
          <p>侧边栏底部或顶部工具栏的主题图标可一键切换暗色/亮色主题，设置自动持久化，刷新后保持。</p>
        </div>

        <!-- 技术信息 -->
        <div class="help-section">
          <h3 class="help-section-title">技术信息</h3>
          <table class="help-table">
            <tr><th>层</th><th>技术栈</th></tr>
            <tr><td>前端</td><td>Vue 3 + Vite + Pinia + Vue Router + Chart.js + XLSX</td></tr>
            <tr><td>后端</td><td>Flask (Python) + MySQL 5.7 + Session 认证</td></tr>
            <tr><td>API</td><td>RESTful, Base: <code>http://127.0.0.1:8000/api</code></td></tr>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.help-container {
  max-width: 1000px;
}
.help-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: 32px;
  position: relative;
  overflow: hidden;
}
.help-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--color-primary), var(--color-success), transparent);
  opacity: 0.5;
}
.help-main-title {
  font-size: 20px;
  font-weight: 800;
  margin-bottom: 24px;
  background: linear-gradient(135deg, var(--color-primary), var(--color-accent));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.help-section {
  margin-bottom: 22px;
  padding-left: 16px;
  border-left: 3px solid var(--color-border);
  transition: border-color 0.3s ease;
}
.help-section:hover {
  border-color: var(--color-primary);
}
.help-section-title {
  font-size: 14px;
  font-weight: 700;
  color: var(--color-primary);
  margin-bottom: 8px;
  text-transform: uppercase;
  letter-spacing: 0.8px;
}
.help-section p {
  font-size: 13px;
  color: var(--color-text-2);
  line-height: 1.7;
  margin-bottom: 6px;
}
.help-list {
  font-size: 13px;
  color: var(--color-text-2);
  line-height: 1.8;
  margin: 6px 0 10px 16px;
  padding: 0;
}
.help-list li {
  margin-bottom: 4px;
}
.help-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
  margin: 10px 0;
  border-radius: var(--radius-sm);
  overflow: hidden;
  border: 1px solid var(--color-border);
}
.help-table th {
  background: var(--color-bg);
  padding: 8px 12px;
  text-align: left;
  font-weight: 600;
  color: var(--color-primary);
  font-size: 12px;
}
.help-table td {
  padding: 8px 12px;
  border-top: 1px solid var(--color-border-subtle);
  color: var(--color-text-2);
}
.mermaid-block {
  margin: 12px 0;
  padding: 14px;
  background: var(--color-bg);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border-subtle);
  overflow-x: auto;
}
.mermaid-block .mermaid {
  font-size: 12px;
  color: var(--color-text);
  white-space: pre;
  font-family: var(--font-mono);
  line-height: 1.6;
}
p code {
  font-family: var(--font-mono);
  font-size: 12px;
  background: rgba(var(--color-primary-rgb),0.08);
  padding: 2px 8px;
  border-radius: 4px;
  color: var(--color-primary);
  border: 1px solid var(--color-border-subtle);
}
</style>