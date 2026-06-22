#!/usr/bin/env python3
"""
Patch frontend/index.html to add:
  Module 1: MAC address <code> style (min 12px, transparent bg)
  Module 2: Batch management (nav, sections, modals, JS)
  Module 3: Login & user management (login overlay, auth flow, user mgmt section, JS)
"""

import re
import sys

HTML_PATH = "/Users/rowen/Library/Application Support/com.tencent.mac.marvis/MarvisData/User/oAN1i2aOEYkGz9HagvRPqmxjPWGE/workspace/conv_19e71aa05a4_bc36a7e30a99/hardware-test-system/frontend/index.html"

with open(HTML_PATH, "r", encoding="utf-8") as f:
    html = f.read()

# ========================
# Module 1: CSS for <code> in tables
# ========================
old_code_css = """.data-table td code {
            font-family: var(--font-mono);
            font-size: 10px;
            background: var(--color-surface-3);
            padding: 1px 4px;
            border-radius: 2px;
        }"""

new_code_css = """.data-table td code {
            font-family: var(--font-mono);
            font-size: max(12px, 10px);
            background: transparent;
            padding: 1px 4px;
            border-radius: 2px;
        }"""

if old_code_css in html:
    html = html.replace(old_code_css, new_code_css)
    print("[OK] Module 1: CSS updated")
else:
    print("[WARN] Module 1: target CSS block not found, skipping")

# ========================
# Module 2: Add batch nav item (after 仪表盘 nav-item, before 测试记录)
# ========================
old_nav = """                <button class="nav-item active" data-section="dashboard">
                    <i class="fas fa-tachometer-alt"></i> 仪表盘
                </button>
                <button class="nav-item" data-section="record">"""

new_nav = """                <button class="nav-item active" data-section="dashboard">
                    <i class="fas fa-tachometer-alt"></i> 仪表盘
                </button>
                <button class="nav-item" data-section="batches">
                    <i class="fas fa-boxes"></i> 批次管理
                </button>
                <button class="nav-item" data-section="record">"""

if old_nav in html:
    html = html.replace(old_nav, new_nav)
    print("[OK] Module 2: nav item added")
else:
    print("[WARN] Module 2: nav item target not found, trying alternate...")
    # Try alternate pattern
    old_nav2 = '<button class="nav-item active" data-section="dashboard">\n                    <i class="fas fa-tachometer-alt"></i> 仪表盘\n                </button>\n                <button class="nav-item" data-section="record">'
    if old_nav2 in html:
        html = html.replace(old_nav2, old_nav2.replace(
            '<button class="nav-item" data-section="record">',
            '<button class="nav-item" data-section="batches">\n                    <i class="fas fa-boxes"></i> 批次管理\n                </button>\n                <button class="nav-item" data-section="record">'
        ))
        print("[OK] Module 2: nav item added (alt)")
    else:
        print("[ERROR] Module 2: could not find nav insertion point")

# ========================
# Module 2: Add "系统设置" nav item (admin only, after 帮助文档 nav-item)
# ========================
# Find the settings nav item and make sure it exists; also add user management section reference
# The settings section already exists. We need to add a "用户管理" item visible only to admin.
# We'll add it via JS instead (simpler). For now just add the nav item in HTML with id="navUsers"
# Actually, let's add it in the 系统设置 section of the sidebar:
old_settings_nav = """                <button class="nav-item" data-section="settings">
                    <i class="fas fa-cog"></i> 系统配置
                </button>
                <button class="nav-item" data-section="help">"""

new_settings_nav = """                <button class="nav-item" data-section="settings">
                    <i class="fas fa-cog"></i> 系统配置
                </button>
                <button class="nav-item" data-section="users" id="navUsersItem" style="display:none;">
                    <i class="fas fa-users-cog"></i> 用户管理
                </button>
                <button class="nav-item" data-section="help">"""

if old_settings_nav in html:
    html = html.replace(old_settings_nav, new_settings_nav)
    print("[OK] Module 3: users nav item added")
else:
    print("[WARN] Module 3: settings nav insertion point not found")

# ========================
# Module 2: Add batch sections + login overlay + user mgmt section BEFORE </body>
# ========================
# Find the closing </body> tag and insert before it
# First, build the HTML blocks to insert

login_overlay = """
    <!-- 登录页面 -->
    <div id="loginOverlay" class="login-overlay">
        <div class="login-card">
            <div class="login-brand">
                <div class="login-icon"><i class="fas fa-microchip"></i></div>
                <h1>硬件测试记录系统</h1>
                <p class="login-subtitle">Hardware Test Record System</p>
            </div>
            <form id="loginForm" class="login-form">
                <div class="form-group">
                    <label class="form-label" for="loginUsername">用户名</label>
                    <input type="text" id="loginUsername" class="form-control" placeholder="请输入用户名" required autofocus>
                </div>
                <div class="form-group">
                    <label class="form-label" for="loginPassword">密码</label>
                    <input type="password" id="loginPassword" class="form-control" placeholder="请输入密码" required>
                </div>
                <div class="form-group" style="margin-top:12px;">
                    <button type="submit" class="btn btn-primary btn-lg" style="width:100%;">登录</button>
                </div>
                <div id="loginError" class="login-error" style="display:none;"></div>
            </form>
        </div>
    </div>
"""

batch_list_section = """
            <!-- 批次管理 -->
            <section id="batches" class="content-section">
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-boxes"></i> 批次管理
                        </h2>
                        <button class="btn btn-primary btn-sm" id="btnNewBatch">
                            <i class="fas fa-plus"></i> 新建批次
                        </button>
                    </div>
                    <div class="table-container">
                        <table class="data-table" id="batchesTable">
                            <thead>
                                <tr>
                                    <th>批次号</th>
                                    <th>描述</th>
                                    <th>操作员</th>
                                    <th>设备数</th>
                                    <th>状态</th>
                                    <th>创建时间</th>
                                    <th>操作</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                    <div class="table-footer">
                        <div class="pagination" id="batchesPagination"></div>
                    </div>
                </div>
            </section>

            <!-- 批次详情 -->
            <section id="batchDetail" class="content-section">
                <div class="card" id="batchInfoCard">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-box-open"></i> 批次详情: <span id="bdBatchNo"></span>
                        </h2>
                        <button class="btn btn-secondary btn-sm" id="btnBackToBatches">
                            <i class="fas fa-arrow-left"></i> 返回列表
                        </button>
                    </div>
                    <div class="batch-info-bar" id="batchInfoBar" style="display:flex;gap:16px;flex-wrap:wrap;padding:8px 0;">
                        <!-- filled by JS -->
                    </div>
                </div>
                <div class="card" style="margin-top:10px;">
                    <div class="card-header">
                        <h2 class="card-title"><i class="fas fa-server"></i> 批次设备列表</h2>
                        <button class="btn btn-primary btn-sm" id="btnAddDeviceToBatch">
                            <i class="fas fa-plus"></i> 添加设备
                        </button>
                    </div>
                    <div class="header-controls" style="margin:8px 0;">
                        <input type="text" id="batchDeviceSearch" class="form-control search-box" placeholder="搜索本批次设备...">
                        <select id="batchDeviceStatusFilter" class="form-control" style="min-width:120px;">
                            <option value="">所有状态</option>
                            <option value="normal">正常</option>
                            <option value="fault">故障</option>
                        </select>
                    </div>
                    <div class="table-container">
                        <table class="data-table" id="batchDevicesTable">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>板卡MAC</th>
                                    <th>无线MAC</th>
                                    <th>IP地址</th>
                                    <th>状态</th>
                                    <th>故障原因</th>
                                    <th>处置</th>
                                    <th>测试时间</th>
                                    <th>操作员</th>
                                    <th>操作</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                    <div class="table-footer">
                        <div class="pagination" id="batchDevicesPagination"></div>
                    </div>
                </div>
            </section>
"""

user_mgmt_section = """
            <!-- 用户管理 -->
            <section id="users" class="content-section">
                <div class="card">
                    <div class="card-header">
                        <h2 class="card-title">
                            <i class="fas fa-users-cog"></i> 用户管理
                        </h2>
                        <button class="btn btn-primary btn-sm" id="btnNewUser">
                            <i class="fas fa-user-plus"></i> 新建用户
                        </button>
                    </div>
                    <div class="table-container">
                        <table class="data-table" id="usersTable">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>用户名</th>
                                    <th>显示名</th>
                                    <th>角色</th>
                                    <th>状态</th>
                                    <th>创建时间</th>
                                    <th>操作</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </section>
"""

# Insert login overlay before <script src=...> or before </body>
# Find position before the main <script> tag that contains API_BASE_URL
script_marker = '<!-- 脚本 -->\n    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>\n    <script>'
if script_marker in html:
    insert_before = script_marker
    inserted = login_overlay + "\n" + batch_list_section + "\n" + user_mgmt_section + "\n"
    html = html.replace(script_marker, inserted + script_marker)
    print("[OK] Module 2/3: sections and login overlay inserted")
else:
    print("[ERROR] Module 2/3: could not find script marker for insertion")
    sys.exit(1)

# ========================
# Module 2: Add batch create modal
# ========================
batch_create_modal = """
    <!-- 新建批次模态框 -->
    <div class="modal" id="batchCreateModal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 class="modal-title">新建批次</h3>
                <button class="modal-close" id="closeBatchCreateModal">&times;</button>
            </div>
            <div class="modal-body">
                <form id="batchCreateForm">
                    <div class="form-group">
                        <label class="form-label" for="bcBatchNo">批次号 <span class="required">*</span></label>
                        <input type="text" id="bcBatchNo" class="form-control" placeholder="如: BATCH-20250529-001" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label" for="bcDescription">批次描述</label>
                        <textarea id="bcDescription" class="form-control" rows="3" placeholder="可选：描述批次用途、项目等"></textarea>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button class="btn btn-secondary" id="cancelBatchCreate">取消</button>
                <button class="btn btn-primary" id="saveBatchCreate">创建批次</button>
            </div>
        </div>
    </div>
"""

# Insert before the closing </body>
html = html.replace("</body>", batch_create_modal + "\n</body>")

# ========================
# Module 3: Add user create/edit modal
# ========================
user_modal = """
    <!-- 用户管理模态框 -->
    <div class="modal" id="userModal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 class="modal-title" id="userModalTitle">新建用户</h3>
                <button class="modal-close" id="closeUserModal">&times;</button>
            </div>
            <div class="modal-body">
                <form id="userForm">
                    <input type="hidden" id="userId" value="">
                    <div class="form-group">
                        <label class="form-label" for="uUsername">用户名 <span class="required">*</span></label>
                        <input type="text" id="uUsername" class="form-control" placeholder="登录用户名" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label" for="uDisplayName">显示名</label>
                        <input type="text" id="uDisplayName" class="form-control" placeholder="显示名称">
                    </div>
                    <div class="form-group">
                        <label class="form-label" for="uPassword">密码 <span class="required">*</span></label>
                        <input type="password" id="uPassword" class="form-control" placeholder="请输入密码">
                        <div class="form-hint" id="userPwdHint">创建用户时必填；编辑时留空表示不修改</div>
                    </div>
                    <div class="form-group">
                        <label class="form-label" for="uRole">角色</label>
                        <select id="uRole" class="form-control">
                            <option value="tester">测试员 (tester)</option>
                            <option value="admin">管理员 (admin)</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label" for="uIsActive">状态</label>
                        <select id="uIsActive" class="form-control">
                            <option value="1">启用</option>
                            <option value="0">禁用</option>
                        </select>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button class="btn btn-secondary" id="cancelUserModal">取消</button>
                <button class="btn btn-primary" id="saveUserModal">保存</button>
            </div>
        </div>
    </div>
"""

html = html.replace("</body>", user_modal + "\n</body>")

# ========================
# Module 3: Add login CSS
# ========================
login_css = """
        /* Login Overlay */
        .login-overlay {
            position: fixed;
            inset: 0;
            background: var(--color-surface);
            z-index: 9999;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-overlay.hidden { display: none; }
        .login-card {
            background: var(--color-surface-2);
            border: 1px solid var(--color-border);
            border-radius: var(--radius-lg);
            padding: 32px 28px;
            min-width: 320px;
            max-width: 380px;
            width: 100%;
            box-shadow: var(--shadow-lg);
        }
        .login-brand {
            text-align: center;
            margin-bottom: 24px;
        }
        .login-icon {
            width: 48px; height: 48px;
            background: var(--color-primary);
            border-radius: var(--radius-md);
            display: inline-flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            font-size: 22px;
            margin-bottom: 12px;
        }
        .login-brand h1 {
            font-size: 18px;
            font-weight: 700;
            margin-bottom: 4px;
        }
        .login-subtitle {
            font-size: 11px;
            color: var(--color-text-3);
            font-family: var(--font-mono);
            letter-spacing: .04em;
        }
        .login-form .form-group { margin-bottom: 14px; }
        .login-error {
            margin-top: 10px;
            padding: 6px 10px;
            border-radius: var(--radius-sm);
            background: color-mix(in oklch, var(--color-error) 12%, transparent);
            color: var(--color-error);
            font-size: 12px;
            text-align: center;
        }
        /* Batch info bar */
        .batch-info-bar .bi-item {
            font-size: 12px;
            color: var(--color-text-2);
        }
        .batch-info-bar .bi-label {
            font-weight: 500;
            color: var(--color-text-3);
            margin-right: 3px;
        }
        /* Hide app container when not logged in */
        body:has(#loginOverlay:not(.hidden)) .app-container {
            display: none !important;
        }
"""

# Insert before </style> in head
html = html.replace("    </style>\n</head>", "    " + login_css + "    </style>\n</head>")

# ========================
# Now write the JS block
# We need to replace the entire <script> block (from <script> to </script> before </body>)
# Let's find and replace the JS section
# ========================

# Build the new JS content (appended to existing JS)
new_js = """

        // ============ Auth State ============
        let currentUser = null;
        let currentBatchId = null;
        let batchDevicesCache = [];

        // ============ Auth Functions ============
        async function checkAuth() {
            try {
                const data = await apiCall('/auth/me');
                currentUser = data.user;
                onLoginSuccess();
            } catch (e) {
                // Not logged in, show login
                showLogin();
            }
        }

        function showLogin() {
            document.getElementById('loginOverlay').classList.remove('hidden');
            document.querySelector('.app-container').style.display = 'none';
        }

        function onLoginSuccess() {
            document.getElementById('loginOverlay').classList.add('hidden');
            document.querySelector('.app-container').style.display = '';
            // Show/hide admin-only items
            if (currentUser && currentUser.role === 'admin') {
                document.getElementById('navUsersItem').style.display = '';
            } else {
                document.getElementById('navUsersItem').style.display = 'none';
            }
            // Update header user info
            const headerSpans = document.querySelectorAll('.header-actions .user-info .operator-name');
            headerSpans.forEach(s => {
                s.textContent = '用户: ' + (currentUser ? currentUser.display_name || currentUser.username : 'Unknown');
            });
            // Add logout button if not present
            if (!document.getElementById('logoutBtn')) {
                const div = document.createElement('button');
                div.id = 'logoutBtn';
                div.className = 'btn btn-secondary btn-sm';
                div.innerHTML = '<i class="fas fa-sign-out-alt"></i> 退出';
                div.style.marginLeft = '6px';
                div.onclick = logout;
                document.querySelector('.header-actions').appendChild(div);
            }
            // Reload data
            loadDashboard();
            loadRecentDevices();
        }

        async function logout() {
            try { await apiCall('/auth/logout', 'POST'); } catch(e) {}
            currentUser = null;
            showLogin();
        }

        // ============ Login Form ============
        document.getElementById('loginForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            const username = document.getElementById('loginUsername').value.trim();
            const password = document.getElementById('loginPassword').value;
            const errDiv = document.getElementById('loginError');
            errDiv.style.display = 'none';
            try {
                const data = await apiCall('/auth/login', 'POST', { username, password });
                currentUser = data.user;
                document.getElementById('loginForm').reset();
                onLoginSuccess();
                showNotification('登录成功，欢迎 ' + data.user.display_name, 'success');
            } catch (error) {
                errDiv.textContent = '登录失败: ' + error.message;
                errDiv.style.display = 'block';
            }
        });

        // ============ Patch apiCall to handle 401 ============
        const _origApiCall = apiCall;
        // We'll wrap apiCall
        window.apiCall = async function(endpoint, method = 'GET', data = null) {
            const url = `${API_BASE_URL}${endpoint}`;
            const options = {
                method,
                headers: { 'Content-Type': 'application/json' },
            };
            if (data && method !== 'GET') {
                options.body = JSON.stringify(data);
            }
            try {
                const response = await fetch(url, options);
                if (response.status === 401) {
                    // Unauthorized, show login
                    currentUser = null;
                    showLogin();
                    throw new Error('请先登录');
                }
                const result = await response.json();
                if (!result.success) {
                    throw new Error(result.message || 'API 调用失败');
                }
                return result.data;
            } catch (error) {
                if (error.message === '请先登录') throw error;
                console.error('API 错误:', error);
                showNotification(`错误: ${error.message}`, 'error');
                throw error;
            }
        };

        // ============ Batch Management ============
        // Nav click for batches
        document.querySelector('.nav-item[data-section="batches"]').addEventListener('click', function() {
            setActiveNav('batches');
            loadBatches();
        });

        document.getElementById('btnNewBatch').addEventListener('click', function() {
            document.getElementById('batchCreateForm').reset();
            document.getElementById('batchCreateModal').classList.add('active');
        });
        document.getElementById('closeBatchCreateModal').addEventListener('click', () => document.getElementById('batchCreateModal').classList.remove('active'));
        document.getElementById('cancelBatchCreate').addEventListener('click', () => document.getElementById('batchCreateModal').classList.remove('active'));
        document.getElementById('saveBatchCreate').addEventListener('click', async function() {
            const batch_no = document.getElementById('bcBatchNo').value.trim();
            const description = document.getElementById('bcDescription').value.trim();
            if (!batch_no) { showNotification('请输入批次号', 'warning'); return; }
            try {
                await apiCall('/batches', 'POST', { batch_no, description, operator: currentUser ? currentUser.username : 'System' });
                showNotification('批次创建成功', 'success');
                document.getElementById('batchCreateModal').classList.remove('active');
                loadBatches();
            } catch(e) {}
        });

        async function loadBatches(page = 1) {
            try {
                const data = await apiCall(`/batches?page=${page}&per_page=20`);
                updateBatchesTable(data.items);
                updateBatchesPagination(data.total, data.page, data.per_page, data.total_pages);
            } catch(e) { console.error('加载批次失败', e); }
        }

        function updateBatchesTable(batches) {
            const tbody = document.querySelector('#batchesTable tbody');
            tbody.innerHTML = '';
            if (batches.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="empty-table"><i class="fas fa-box-open"></i><p>暂无批次记录</p></td></tr>';
                return;
            }
            batches.forEach(b => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td><code>${b.batch_no}</code></td>
                    <td>${b.description || '--'}</td>
                    <td>${b.operator}</td>
                    <td>${b.device_count || 0}</td>
                    <td><span class="status-badge ${b.status === 'active' ? 'status-normal' : 'status-pending'}">${b.status === 'active' ? '进行中' : '已完成'}</span></td>
                    <td>${formatDateTime(b.created_at)}</td>
                    <td class="actions-cell">
                        <button class="btn btn-sm btn-primary" onclick="enterBatch(${b.id}, '${b.batch_no.replace(/'/g, "\\'")}')">
                            <i class="fas fa-arrow-right"></i> 进入
                        </button>
                        <button class="btn btn-sm btn-secondary" onclick="editBatch(${b.id})">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-sm btn-error" onclick="deleteBatch(${b.id}, '${b.batch_no.replace(/'/g, "\\'")}')">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                `;
                tbody.appendChild(tr);
            });
        }

        function updateBatchesPagination(total, current, perPage, totalPages) {
            const pag = document.getElementById('batchesPagination');
            if (totalPages <= 1) { pag.innerHTML = ''; return; }
            let html = `<div class="pagination-info">显示 ${(current-1)*perPage+1}-${Math.min(current*perPage,total)} / ${total}</div><div class="pagination-controls">`;
            if (current > 1) html += `<button class="btn btn-sm btn-secondary" onclick="loadBatches(${current-1})">上一页</button>`;
            for (let i = Math.max(1,current-2); i <= Math.min(totalPages,current+2); i++) {
                html += i === current ? `<button class="btn btn-sm btn-primary" disabled>${i}</button>` : `<button class="btn btn-sm btn-secondary" onclick="loadBatches(${i})">${i}</button>`;
            }
            if (current < totalPages) html += `<button class="btn btn-sm btn-secondary" onclick="loadBatches(${current+1})">下一页</button>`;
            html += '</div>';
            pag.innerHTML = html;
        }

        async function enterBatch(id, batchNo) {
            currentBatchId = id;
            // Switch to batchDetail section
            setActiveNav('batches');  // keep batches nav active
            document.querySelectorAll('.content-section').forEach(s => s.classList.remove('active'));
            document.getElementById('batchDetail').classList.add('active');
            document.getElementById('bdBatchNo').textContent = batchNo;
            // Load batch info
            try {
                const b = await apiCall(`/batches/${id}`);
                const bar = document.getElementById('batchInfoBar');
                bar.innerHTML = `
                    <div class="bi-item"><span class="bi-label">批次号:</span>${b.batch_no}</div>
                    <div class="bi-item"><span class="bi-label">描述:</span>${b.description || '--'}</div>
                    <div class="bi-item"><span class="bi-label">操作员:</span>${b.operator}</div>
                    <div class="bi-item"><span class="bi-label">状态:</span>${b.status === 'active' ? '进行中' : '已完成'}</div>
                    <div class="bi-item"><span class="bi-label">设备数:</span>${b.device_count || 0}</div>
                `;
            } catch(e) {}
            loadBatchDevices(id);
        }

        document.getElementById('btnBackToBatches').addEventListener('click', function() {
            document.getElementById('batchDetail').classList.remove('active');
            document.getElementById('batches').classList.add('active');
            currentBatchId = null;
            loadBatches();
        });

        document.getElementById('btnAddDeviceToBatch').addEventListener('click', function() {
            // Open the single-form in record section, but with batch_id pre-set
            // We'll store currentBatchId and patch submitTestRecord
            setActiveNav('record');
            showNotification('请在测试记录表单中填写设备信息，将自动绑定到当前批次', 'info');
        });

        // Patch initNavigation to handle new sections
        // batchDeviceSearch & filter
        document.getElementById('batchDeviceSearch').addEventListener('input', debounce(() => { if(currentBatchId) loadBatchDevices(currentBatchId); }, 300));
        document.getElementById('batchDeviceStatusFilter').addEventListener('change', () => { if(currentBatchId) loadBatchDevices(currentBatchId); });

        async function loadBatchDevices(batchId, page = 1) {
            try {
                const search = document.getElementById('batchDeviceSearch').value;
                const status = document.getElementById('batchDeviceStatusFilter').value;
                let endpoint = `/batches/${batchId}/devices?page=${page}&per_page=20&sort_by=test_date&sort_order=desc`;
                if (search) endpoint += `&search=${encodeURIComponent(search)}`;
                if (status) endpoint += `&status=${status}`;
                const data = await apiCall(endpoint);
                updateBatchDevicesTable(data.items);
                updateBatchDevicesPagination(data.total, data.page, data.per_page, data.total_pages);
            } catch(e) { console.error('加载批次设备失败', e); }
        }

        function updateBatchDevicesTable(devices) {
            const tbody = document.querySelector('#batchDevicesTable tbody');
            tbody.innerHTML = '';
            if (devices.length === 0) {
                tbody.innerHTML = '<tr><td colspan="10" class="empty-table"><i class="fas fa-search"></i><p>本批次暂无设备记录</p></td></tr>';
                return;
            }
            devices.forEach(device => {
                const statusText = device.status === 'normal' ? '正常' : '故障';
                const statusClass = device.status === 'normal' ? 'status-normal' : 'status-fault';
                let dispositionText = '';
                let dispositionClass = '';
                if (device.fault_disposition === 'returned') {
                    dispositionText = '已返厂';
                    dispositionClass = 'status-returned';
                } else if (device.fault_disposition === 'pending') {
                    dispositionText = '待处理';
                    dispositionClass = 'status-pending';
                }
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${device.id}</td>
                    <td><code>${device.board_mac}</code></td>
                    <td><code>${device.wireless_mac}</code></td>
                    <td><code>${device.ip_address}</code></td>
                    <td><span class="status-badge ${statusClass}">${statusText}</span></td>
                    <td>${device.fault_reason || '--'}</td>
                    <td>${dispositionText ? `<span class="status-badge ${dispositionClass}">${dispositionText}</span>` : '--'}</td>
                    <td>${formatDateTime(device.test_date)}</td>
                    <td>${device.operator || '--'}</td>
                    <td class="actions-cell">
                        <button class="btn btn-sm btn-warning" onclick="toggleDeviceStatus(${device.id}, '${device.status}')"><i class="fas fa-exchange-alt"></i></button>
                        <button class="btn btn-sm btn-secondary" onclick="editDevice(${device.id})"><i class="fas fa-edit"></i></button>
                        <button class="btn btn-sm btn-error" onclick="deleteDeviceRow(${device.id})"><i class="fas fa-trash"></i></button>
                        ${device.status === 'fault' ? `<button class="btn btn-sm btn-warning" onclick="showFaultReportModal(${device.id})"><i class="fas fa-clipboard-list"></i></button>` : ''}
                    </td>
                `;
                tbody.appendChild(tr);
            });
        }

        function updateBatchDevicesPagination(total, current, perPage, totalPages) {
            const pag = document.getElementById('batchDevicesPagination');
            if (totalPages <= 1) { pag.innerHTML = ''; return; }
            let html = `<div class="pagination-info">显示 ${(current-1)*perPage+1}-${Math.min(current*perPage,total)} / ${total}</div><div class="pagination-controls">`;
            if (current > 1) html += `<button class="btn btn-sm btn-secondary" onclick="loadBatchDevices(currentBatchId, ${current-1})">上一页</button>`;
            for (let i = Math.max(1,current-2); i <= Math.min(totalPages,current+2); i++) {
                html += i === current ? `<button class="btn btn-sm btn-primary" disabled>${i}</button>` : `<button class="btn btn-sm btn-secondary" onclick="loadBatchDevices(currentBatchId, ${i})">${i}</button>`;
            }
            if (current < totalPages) html += `<button class="btn btn-sm btn-secondary" onclick="loadBatchDevices(currentBatchId, ${current+1})">下一页</button>`;
            html += '</div>';
            pag.innerHTML = html;
        }

        async function deleteBatch(id, batchNo) {
            if (!confirm(`确定要删除批次 "${batchNo}" 吗？关联的设备记录将解除绑定（不删除）。`)) return;
            try {
                await apiCall(`/batches/${id}`, 'DELETE');
                showNotification('批次已删除', 'success');
                loadBatches();
            } catch(e) {}
        }

        async function editBatch(id) {
            try {
                const b = await apiCall(`/batches/${id}`);
                const desc = prompt('修改批次描述:', b.description || '');
                if (desc === null) return;
                const status = prompt('修改状态 (active/completed):', b.status);
                if (!status) return;
                await apiCall(`/batches/${id}`, 'PUT', { description, status });
                showNotification('批次已更新', 'success');
                loadBatches();
            } catch(e) {}
        }

        // ============ Patch submitTestRecord to support batch_id ============
        const _origSubmitTestRecord = submitTestRecord;
        // We override submitTestRecord to inject batch_id
        window.submitTestRecord = async function() {
            const form = document.getElementById('testForm');
            const submitBtn = document.getElementById('submitForm');
            if (!form.checkValidity()) { form.reportValidity(); return; }
            const data = {
                board_mac: document.getElementById('boardMac').value.trim().toUpperCase(),
                wireless_mac: document.getElementById('wirelessMac').value.trim().toUpperCase(),
                ip_address: document.getElementById('ipAddress').value.trim(),
                status: document.getElementById('status').value,
                operator: document.getElementById('operator').value.trim() || 'System',
                test_date: document.getElementById('testDate').value,
                notes: document.getElementById('notes').value.trim(),
            };
            if (currentBatchId) data.batch_id = currentBatchId;
            if (data.status === 'fault') {
                data.fault_reason = document.getElementById('faultReason').value.trim();
                data.fault_disposition = document.getElementById('faultDisposition').value || null;
                if (data.fault_disposition === 'returned') {
                    data.return_date = document.getElementById('returnDate').value;
                    data.return_tracking = document.getElementById('returnTracking').value.trim();
                }
            }
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<div class="loading"></div> 保存中...';
            try {
                await apiCall('/devices', 'POST', data);
                showNotification('测试记录保存成功' + (currentBatchId ? ' (已绑定批次)' : ''), 'success');
                // record operator
                try { await apiCall('/operators', 'POST', { name: data.operator }); } catch(e) {}
                form.reset();
                document.getElementById('faultFields').style.display = 'none';
                document.getElementById('returnDateGroup').style.display = 'none';
                document.getElementById('returnTrackingGroup').style.display = 'none';
                const now = new Date();
                document.getElementById('testDate').value = new Date(now.getTime() - now.getTimezoneOffset()*60000).toISOString().slice(0,16);
                loadDashboard();
                loadRecentDevices();
                if (currentBatchId) loadBatchDevices(currentBatchId);
                else if (document.getElementById('devices').classList.contains('active')) loadDevices();
            } catch(e) {}
            finally { submitBtn.disabled = false; submitBtn.innerHTML = '<i class="fas fa-save"></i> 保存记录'; }
        };

        // Also patch submitBatch for batch_id
        window.submitBatch = async function() {
            const batchData = document.getElementById('batchData').value.trim();
            if (!batchData) { showNotification('请输入批量数据', 'warning'); return; }
            let items;
            try {
                items = JSON.parse(batchData);
                if (!Array.isArray(items)) throw new Error('数据必须是数组格式');
            } catch(e) { showNotification('JSON解析错误: ' + e.message, 'error'); return; }
            const submitBtn = document.getElementById('submitBatch');
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<div class="loading"></div> 导入中...';
            if (currentBatchId) {
                items = items.map(it => ({ ...it, batch_id: currentBatchId }));
            }
            try {
                const result = await apiCall('/devices/batch', 'POST', { items });
                showNotification(`批量导入完成: ${result.created}/${result.total}`, 'success');
                if (result.failed.length > 0) { console.warn('导入失败:', result.failed); }
                loadDashboard(); loadRecentDevices();
                if (currentBatchId) loadBatchDevices(currentBatchId);
                else if (document.getElementById('devices').classList.contains('active')) loadDevices();
            } catch(e) {}
            finally { submitBtn.disabled = false; submitBtn.innerHTML = '<i class="fas fa-upload"></i> 批量导入'; }
        };

        // ============ User Management ============
        document.getElementById('navUsersItem').addEventListener('click', function() {
            setActiveNav('users');
            loadUsers();
        });

        document.getElementById('btnNewUser').addEventListener('click', function() {
            document.getElementById('userModalTitle').textContent = '新建用户';
            document.getElementById('userForm').reset();
            document.getElementById('userId').value = '';
            document.getElementById('uPassword').required = true;
            document.getElementById('userPwdHint').textContent = '请输入密码';
            document.getElementById('userModal').classList.add('active');
        });
        document.getElementById('closeUserModal').addEventListener('click', () => document.getElementById('userModal').classList.remove('active'));
        document.getElementById('cancelUserModal').addEventListener('click', () => document.getElementById('userModal').classList.remove('active'));
        document.getElementById('saveUserModal').addEventListener('click', async function() {
            const id = document.getElementById('userId').value;
            const username = document.getElementById('uUsername').value.trim();
            const display_name = document.getElementById('uDisplayName').value.trim();
            const password = document.getElementById('uPassword').value;
            const role = document.getElementById('uRole').value;
            const is_active = document.getElementById('uIsActive').value === '1';
            if (!username) { showNotification('请输入用户名', 'warning'); return; }
            const payload = { username, display_name, role, is_active };
            if (password) payload.password = password;
            try {
                if (id) {
                    await apiCall(`/users/${id}`, 'PUT', payload);
                    showNotification('用户已更新', 'success');
                } else {
                    if (!password) { showNotification('请输入密码', 'warning'); return; }
                    payload.password = password;
                    await apiCall('/users', 'POST', payload);
                    showNotification('用户已创建', 'success');
                }
                document.getElementById('userModal').classList.remove('active');
                loadUsers();
            } catch(e) {}
        });

        async function loadUsers() {
            try {
                const data = await apiCall('/users');
                updateUsersTable(data);
            } catch(e) { console.error('加载用户失败', e); }
        }

        function updateUsersTable(users) {
            const tbody = document.querySelector('#usersTable tbody');
            tbody.innerHTML = '';
            if (!users || users.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="empty-table"><i class="fas fa-users"></i><p>暂无用户</p></td></tr>';
                return;
            }
            users.forEach(u => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${u.id}</td>
                    <td><code>${u.username}</code></td>
                    <td>${u.display_name || '--'}</td>
                    <td>${u.role === 'admin' ? '<span class="status-badge status-normal">管理员</span>' : '测试员'}</td>
                    <td>${u.is_active ? '<span class="status-badge status-normal">启用</span>' : '<span class="status-badge status-fault">禁用</span>'}</td>
                    <td>${formatDateTime(u.created_at)}</td>
                    <td class="actions-cell">
                        <button class="btn btn-sm btn-secondary" onclick="editUser(${u.id})"><i class="fas fa-edit"></i></button>
                        <button class="btn btn-sm btn-error" onclick="deleteUser(${u.id}, '${u.username.replace(/'/g, "\\'")}')"><i class="fas fa-trash"></i></button>
                    </td>
                `;
                tbody.appendChild(tr);
            });
        }

        async function editUser(id) {
            try {
                const users = await apiCall('/users');
                const u = users.find(x => x.id == id);
                if (!u) return;
                document.getElementById('userModalTitle').textContent = '编辑用户';
                document.getElementById('userId').value = u.id;
                document.getElementById('uUsername').value = u.username;
                document.getElementById('uDisplayName').value = u.display_name || '';
                document.getElementById('uPassword').value = '';
                document.getElementById('uPassword').required = false;
                document.getElementById('userPwdHint').textContent = '留空表示不修改密码';
                document.getElementById('uRole').value = u.role;
                document.getElementById('uIsActive').value = u.is_active ? '1' : '0';
                document.getElementById('userModal').classList.add('active');
            } catch(e) {}
        }

        async function deleteUser(id, username) {
            if (!confirm(`确定要删除用户 "${username}" 吗？（不能删除自己）`)) return;
            try {
                await apiCall(`/users/${id}`, 'DELETE');
                showNotification('用户已删除', 'success');
                loadUsers();
            } catch(e) {}
        }

        // ============ Helpers ============
        function setActiveNav(sectionId) {
            document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
            const nav = document.querySelector(`.nav-item[data-section="${sectionId}"]`);
            if (nav) nav.classList.add('active');
            document.querySelectorAll('.content-section').forEach(s => s.classList.remove('active'));
            const sec = document.getElementById(sectionId);
            if (sec) sec.classList.add('active');
        }

        // ============ Init: check auth on load ============
        // Override DOMContentLoaded to check auth first
        // We already have DOMContentLoaded listener; we need to make auth check run first
        // The simplest way: wrap the existing DOMContentLoaded logic in a function and call after auth
        // But we can't easily do that now that HTML is already written.
        // Instead, we rely on the fact that checkAuth() is called at the end of this script block.
"""

# Now we need to append the new JS before the closing </script> tag
# Find the position of the last </script> before </body>
# We need to insert before the Chart.js related closing or before the final </script>

# The original file ends with: 
#         const style = document.createElement('style');
#         style.textContent = `...`;
#         document.head.appendChild(style);
#     </script>
# </body>
# So we find the last </script> before </body> and insert before it

# Let's find the position of the style.textContent block and insert before the final </script>
# Actually, the simplest approach: append to the file before </body>

js_block = f"""
    <script>
{new_js}
        // Kick off: check auth on load
        checkAuth();
    </script>
"""

# Insert before </body>
if "</body>" in html:
    html = html.replace("</body>", js_block + "\n</body>")
    print("[OK] Module 2/3: JS block inserted")
else:
    print("[ERROR] </body> not found")

# Write back
with open(HTML_PATH, "w", encoding="utf-8") as f:
    f.write(html)

print("\n[DONE] All patches applied successfully!")
print(f"File written to: {HTML_PATH}")
